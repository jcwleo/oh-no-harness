#!/usr/bin/env python3
"""Static checks for Oh No Harness plugin files."""

from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - Python < 3.11 fallback.
    tomllib = None

PUBLIC_SKILLS = [
    "interview",
    "ralplan",
    "ralph",
    "ultrawork",
    "auto-routing",
    "test-driven-development",
    "simplify",
    "verification-before-completion",
    "systematic-debugging",
    "fusion-rescue",
    "install-statusline",
    "configure-subagents",
]

WORKFLOW_ROUTING_SKILLS = [
    "interview",
    "ralplan",
    "ralph",
    "ultrawork",
    "auto-routing",
    "test-driven-development",
    "simplify",
    "verification-before-completion",
    "systematic-debugging",
    "fusion-rescue",
]
ROUTING_DESCRIPTION_PATTERNS = {
    "interview": ((r"vague|broad|ambiguous|requirement-light|missing", r"requirements?|constraints?|acceptance criteria|user intent"), (r"requirements? discovery", r"(before|not).*(implementation planning|planning|execution)"), {"ralplan", "ralph"}),
    "ralplan": ((r"requirements?.*(known|clear|sufficient)|known-enough|sufficiently known", r"broad|risky|architecture-sensitive|cross-file|multi-step|strategy-unclear"), (r"not .*(still-vague|vague|discovery)", r"not .*execution-ready"), {"interview", "ralph"}),
    "ralph": ((r"approved plan|prd|spec|ticket|concrete", r"usable acceptance|acceptance criteria|acceptance contract"), (r"explicit .*test-first|explicit tdd|test-first intent", r"unknown root cause|root-cause investigation|debugging"), {"test-driven-development", "systematic-debugging"}),
    "ultrawork": ((r"explicit|explicitly", r"autonomous|end-to-end"), (r"not .*small.*(execution-ready|task)",), {"interview", "ralplan", "ralph"}),
    "auto-routing": ((r"enable|disable|status|turn .* on|turn .* off", r"future-session|across sessions|routing-guidance"), (r"configuration only", r"not .*current-turn.*(selection|workflow)"), set()),
    "test-driven-development": ((r"explicit(?:ly)? .*tdd|explicit(?:ly)? .*test-first|test-first intent", r"red[-/]green[-/]refactor", r"already-selected|internal .*gate"), (r"ordinary implementation", r"ralph"), {"ralph"}),
    "simplify": ((r"behavior-locked|behavior lock", r"changed diff|diff", r"post-implementation", r"pre-review"), (r"not .*initial implementation", r"correctness|root-cause"), set()),
    "verification-before-completion": ((r"imminent|about to|final status", r"complete|fixed|passing|ready|safe", r"evidence|gate"), (r"not .*implementation",), set()),
    "systematic-debugging": ((r"observed|failure|failing|regression|flake|unexpected", r"unknown root cause|investigation"), (r"known-cause", r"ralph|execution-ready fix"), {"ralph"}),
    "fusion-rescue": ((r"explicit.*(rescue|multi-agent synthesis)|hard problem.*stalled|stalled.*ordinary",), (r"not .*first-pass", r"not .*routine"), {"ralph", "systematic-debugging"}),
}

ALL_SKILLS = PUBLIC_SKILLS

ALL_RUNTIME_PLATFORMS = frozenset({"claude", "codex", "opencode"})
SKILL_AVAILABILITY = {
    skill: ALL_RUNTIME_PLATFORMS for skill in WORKFLOW_ROUTING_SKILLS
}
SKILL_AVAILABILITY.update(
    {
        "install-statusline": frozenset({"claude"}),
        "configure-subagents": frozenset({"claude", "opencode"}),
    }
)
SELF_CONTAINED_ADAPTER_SKILLS = {
    "interview",
    "ralplan",
    "ralph",
    "systematic-debugging",
    "ultrawork",
    "verification-before-completion",
}

# Skills whose slash-command wrapper may set disable-model-invocation: true (the
# model must never auto-invoke them). This is the invocation dimension and is kept
# separate from SKILL_AVAILABILITY (the platform dimension) on purpose. Every other
# command wrapper must still set disable-model-invocation: false.
MODEL_UNINVOCABLE_SKILLS = {"install-statusline", "configure-subagents"}

AGENTS = [
    "explore",
    "analyst",
    "planner",
    "plan-reviewer",
    "executor",
    "debugger",
    "verifier",
    "code-reviewer",
    "fusion-rescue-analyst",
]

REQUIRED_AGENT_FIELDS = {"name", "description", "tools", "model", "color"}
CLAUDE_AGENT_DESCRIPTION_PREFIX = (
    "Use proactively inside active Oh No Harness workflows"
)
CLAUDE_AGENT_COLORS = {
    "red",
    "blue",
    "green",
    "yellow",
    "purple",
    "orange",
    "pink",
    "cyan",
}
REQUIRED_SKILL_FIELDS = {"name", "description"}
REQUIRED_COMMAND_FIELDS = {"description", "argument-hint"}
WORKFLOW_SKILLS_REQUIRING_ARGUMENT_HINT = set(PUBLIC_SKILLS)
COMMAND_WRAPPERS = PUBLIC_SKILLS
COMMAND_DELEGATION_MARKER = (
    "Read the file at `${{CLAUDE_PLUGIN_ROOT}}/skills-claude/{skill}/SKILL.md` using the Read tool "
    "and follow its instructions exactly."
)
PLUGIN_NAME = "oh-no-harness"
MARKETPLACE_PLUGIN_PATH = f"./plugins/{PLUGIN_NAME}"
CODEX_SKILL_ROOT = "skills"
CLAUDE_SKILL_ROOT = "skills-claude"
OPENCODE_SKILL_ROOT = "skills-opencode"
SKILL_ROOTS = {
    "codex": CODEX_SKILL_ROOT,
    "claude": CLAUDE_SKILL_ROOT,
    "opencode": OPENCODE_SKILL_ROOT,
}
SKILL_CORE_ROOT = "docs/skill-core"
AGENT_CORE_ROOT = "docs/agent-core"
CODEX_AGENT_TEMPLATE_ROOT = "docs/platforms/codex-agents"
PROVIDER_DOC_ROOT = "docs/providers"
OPENCODE_SKILLS = [*WORKFLOW_ROUTING_SKILLS, "configure-subagents"]
OPENCODE_CONFIGURE_TOOL = "oh_no_configure_subagents"
OPENCODE_MODEL_CATALOG_TOOL = "oh_no_get_model_catalog"
OPENCODE_AGENT_ROOT = "opencode/generated"
OPENCODE_ALLOWED_SKILL_FIELDS = {"name", "description"}
OPENCODE_FORBIDDEN_WRAPPER_PATTERNS = (
    (r"\bspawn_agent\s*\(", "Codex spawn_agent invocation"),
    (r"\bwait_agent\b", "Codex wait_agent invocation"),
    (r"\bclose_agent\b", "Codex close_agent invocation"),
    (r"\bagent_type\s*=", "Codex agent_type invocation"),
    (r"\bfork_context\s*=", "Codex fork_context invocation"),
    (r"\bTask\s*\(", "Claude Task invocation"),
    (r"\bWorkflow\s+`agent\(\)`", "Claude Workflow agent invocation"),
    (r"@agent-[A-Za-z0-9:_-]+", "Claude agent mention invocation"),
    (r"\bCLAUDE_PLUGIN_ROOT\b", "Claude plugin-root runtime variable"),
    (r"\brequire-cross-host\b", "Codex cross-host strict-mode term"),
    (r"\bmodel-diversity-pair\b", "Claude model-diversity strict-mode term"),
    (
        r"docs/platforms/(?:codex|claude-code)(?:-[a-z0-9-]+)?\.md",
        "another host's runtime document",
    ),
    (r"\bskills-claude/", "Claude skill runtime path"),
)
AGENT_CORE_FORBIDDEN_SURFACE_PATTERNS = (
    (r"\bspawn_agent\s*\(", "Codex spawn_agent invocation belongs in platform docs or dispatch packets"),
    (r"\bwait_agent\b", "Codex wait_agent lifecycle syntax belongs in platform docs or dispatch packets"),
    (r"\bclose_agent\b", "Codex close_agent lifecycle syntax belongs in platform docs or dispatch packets"),
    (r"\bagent_type\s*=", "Codex agent_type syntax belongs in platform docs or dispatch packets"),
    (r"\bfork_context\s*=", "Codex fork_context syntax belongs in platform docs"),
    (r"@agent-[A-Za-z0-9:_-]+", "Claude @agent mention syntax belongs in platform docs"),
    (r"\bTask,\s*Agent,\s*Workflow\b", "Claude Task/Agent/Workflow syntax belongs in platform docs"),
    (r"\bWorkflow\s+`agent\(\)`", "Claude Workflow agent() syntax belongs in platform docs"),
    (r"\bYAML frontmatter\b", "Claude YAML frontmatter belongs in generated agents docs"),
    (r"\bTOML\b", "Codex TOML custom-agent details belong in platform docs or generated templates"),
    (r"\bmodel_reasoning_effort\b", "Codex model metadata belongs in generated templates"),
    (r"\bsandbox_mode\b", "Codex sandbox metadata belongs in generated templates"),
    (r"\bdocs/platforms/codex-agents\b", "Codex generated-template paths belong in platform docs"),
)

# Skills whose body must declare a Next Skill Handoff section. The markers are
# structural: the heading tags the section, "HARD-GATE" tags the negative
# framing that forbids auto-invocation, and "Ultrawork exception" tags the
# escape hatch documented for ultrawork orchestration. Keep this contract in
# lockstep with interview.md, ralplan.md, and the Ultrawork exception owners.
NEXT_SKILL_GATE_REQUIRED = {"interview", "ralplan"}
NEXT_SKILL_GATE_MARKERS = (
    "## Next Skill Handoff",
    "HARD-GATE",
    "Ultrawork exception",
)
ULTRAWORK_EXCEPTION_HEADING = "## Ultrawork Exception"
# Re-anchored to the FSM core (2026-07-16 rewrite): the auto-approval
# narration now lives once (U4/U13); stems below survive that single home.
ULTRAWORK_AUTO_APPROVAL_MARKERS = (
    "Interview is the only user-facing content approval gate",
    "Plan approval source: ultrawork automatic approval after interview/spec",
    "Ultrawork-approved plan or spec",
    "automatically approved for execution",
    "moves automatically once the prior phase's content gate is satisfied",
    "scope-change pauses",
    "do not pause for a separate Plan Approval Brief",
)
ULTRAWORK_LOOP_CONTRACT_MARKERS = (
    "planning gate uses `ralplan`",
    "execution handoff uses `ralph`",
    "start_or_resume",
    "requirements_gate",
    "planning_gate",
    "worktree_gate",
    "execution_handoff",
    "qa_loop",
    "final_validation",
    "Heartbeat contents:",
    "Resume precedence:",
    "authoritative",
    "Doctor/status gate semantics",
    "Checker outputs",
    "Escalation routes",
    ".oh-no/sessions/{sessionId}/ultrawork.md",
    "No timer, daemon, or background heartbeat",
    "No JSON state artifact in v1",
    "PASS",
    "WARN",
    "BLOCKED",
    "Maker roles do not self-approve",
    "succeeded_merged_verified_reported",
    "succeeded_left_worktree_for_inspection",
    "paused_for_user",
    "failed_verification",
    "scope_change_pending_approval",
)
ULTRAWORK_FORBIDDEN_RUNTIME_PATTERNS = (
    r"\brequires?\b.{0,80}\b(daemon|controller|tmux|mcp|telemetry)\b",
    r"\bmust\b.{0,80}\b(run|start|create|use)\b.{0,80}\b(daemon|controller|tmux|mcp|telemetry)\b",
    r"\b(runtime|background)\b.{0,80}\b(daemon|controller)\b",
    r"\b(json)\b.{0,80}\b(authoritative|authority)\b",
    r"\b(authoritative|authority)\b.{0,80}\b(json)\b",
    r"\bhook-enforced continuation\b",
    r"\bomc keyword detector\b",
    r"\bbridge hook\b",
)
ULTRAWORK_RUNTIME_GUARDRAIL_TERMS = (
    "no ",
    "not ",
    "without ",
    "does not ",
    "do not ",
    "must not ",
    "non-authoritative",
    "never ",
)

# The read-contract applies to ANY skill-core that references a docs/shared
# contract: such a core must declare every docs/shared/<name>.md it references in
# a `## Required Reading` section. The in-scope set is DERIVED at check time from
# the cores that actually reference docs/shared (not a hardcoded allowlist), so a
# future skill-core that starts referencing a shared doc cannot silently escape
# the parity check. The parity invariant is scoped to the skill-core SOURCE body,
# NOT the composed wrapper: the platform runtime doc composes
# docs/shared/cross-host-review.md into every wrapper, so a wrapper-scoped check
# would false-positive on a skill (interview) whose own body
# does not reference it.
#
# Stable strong-contract substring that must appear (whitespace-normalized) in
# every `## Required Reading` section so the wording cannot be silently weakened.
REQUIRED_READING_CONTRACT_MARKER = (
    "A path reference here is a pointer, not a substitute for reading"
)
REQUIRED_READING_BLOCKER_MARKER = (
    "record the blocker instead of proceeding past the gate that depends on it"
)
# ralplan left this set with the 2026-07-16 self-contained FSM rewrite; its
# core forbids a Required Reading section entirely (see
# assert_required_reading_contract's SELF_CONTAINED_ADAPTER_SKILLS branch).
# All former members left this set with the 2026-07 self-contained FSM
# rewrites; their cores forbid a Required Reading section entirely (see
# assert_required_reading_contract's SELF_CONTAINED_ADAPTER_SKILLS branch).
TRIGGER_CLASS_REQUIRED_SKILLS = ()
EXPECTED_ALWAYS_READING: dict[str, set[str]] = {}
# Skills that dispatch review/verify/debug roles and must HARD-GATE the recorded
# independence mode (same-host-perspective-pair | cross-host |
# same-host-parallel-fallback | inline-fallback).
# ralplan carries its own equivalent in the Findings Ledger Gate, pinned under
# that heading in REVIEW_BOUNDARY_SECTION_MARKERS, and is excluded here.
INDEPENDENCE_MODE_GATE_MARKER = (
    "Missing review topology is a named ledger gap"
)
INDEPENDENCE_MODE_GATE_SKILLS = (
    "ralph",
    "ultrawork",
    "verification-before-completion",
    "systematic-debugging",
)

ROLE_POLICY_MARKERS = {
    "ralph": "## Mode-Gated Agent Dispatch",
    "ralplan": "Dispatch (when)",
    "interview": "## Agent Roles",
    "systematic-debugging": "## Agent Roles",
    "ultrawork": "## Agent Roles",
}
PLATFORM_SUBAGENT_MARKERS = {
    "ralph": (
        "Parallel trigger",
        "use targeted subagents on subagent-capable hosts",
        "ship/block decision",
        "whole eligible batch",
        "active adapter invocation syntax",
        "Lifecycle: caller waits for and captures",
        "Role: {explore|executor|verifier|code-reviewer}",
        "adapter deciding whether the invocation is a registered custom agent",
        "Platform invocation: {active adapter invocation syntax}",
        "host-specific cleanup",
        # parallel-executor-dispatch (AC1/AC3): proactive disjoint-executor
        # batching is first-class in ralph skill-core and survives composition
        # into the generated wrapper.
        "proactively partition disjoint",
    ),
    "ralplan": (
        "eligible isolated subagents when they add decision-changing evidence",
        "Parallel trigger: approved-plan-handoff",
        "ordinary `oh-no-harness:ralph` choice preserves the plan path",
        "sequential role boundaries",
        "Parallel dispatch",
        "active platform adapter",
        "Planner Draft Contract",
        "Plan Review Contract",
        "Planner Revision Contract",
    ),
    # Re-anchored to the FSM core (2026-07-16 rewrite): dispatch bias +
    # standing authorization live once under ## Agent Roles.
    "ultrawork": (
        "checker independence requires a separate\ncontext",
        "Parallel trigger: approved-plan-handoff",
        "Parallel trigger: natural-dispatch",
        "keeps phase noise out",
        "active platform's dispatch authorization",
        "without per-run subagent approval",
        "do not pause\nUltrawork only to ask whether subagents may be used",
        "lifecycle cleanup are never skipped",
    ),
    "interview": (
        "active platform's dispatch authorization",
        "standing authorization",
        "per-run subagent approval",
        "Dispatch `explore` by default",
        "fallback reason",
    ),
    # Re-anchored to the FSM cores (2026-07-17 rewrite): dispatch bias +
    # standing authorization live once under each core's ## Agent Roles.
    "systematic-debugging": (
        "Dispatch diagnostic and evidence roles by default",
        # 2026-07-30: the anti-collapse floor is now need-based rather than
        # absolute, and it no longer treats mutation as a stricter lane.
        "Do not collapse a role inline merely",
        "One need test covers diagnostic,",
        "active platform's dispatch authorization",
        "standing authorization",
        "per-run subagent approval",
        "post-fix review roles",
        "`code-reviewer`",
        "its security lens is needed because auth, data, file system, network, secrets, sandbox, or policy-sensitive behavior is touched",
        "scenario lens for user-facing flows",
    ),
    "verification-before-completion": (
        # 2026-07-29: nontriviality is no longer a verifier trigger; dispatch is
        # gated on the named V4 triggers.
        "Dispatch `verifier` only when a named V4 trigger fires; nontriviality alone is\nnot one",
        "ship/block decision",
        "separate-context independent `verifier` audit",
        "`dispatch-unavailable` as a blocker",
        "## Acceptance-To-Evidence Mapping",
        "## Risk Check Before Completion",
        "Completion claim",
        "active platform's dispatch authorization",
        "standing authorization",
        "per-run subagent approval",
    ),
}
PLATFORM_RULE_DOC_MARKERS = {
    "codex.md": (
        "# Codex Platform Rules",
        "## Skill Loading",
        "## User Approval",
        "## Auto Routing",
        "## OpenAI-Aligned Prompting",
        "docs/providers/openai.md",
        "outcome-first",
        "## Role Dispatch",
        "spawn_agent",
        "wait_agent",
        "close_agent",
        "capture the output and any changed-file set before cleanup",
        "general user-requested subagent work outside a selected skill",
        'spawn_agent(agent_type="oh-no-<role>", ...)',
        "Do not infer unavailability from",
        "do not treat that failure alone as permission for generic prompt-embedded fallback",
        "use generic prompt-embedded fallback only after confirmed custom-agent unavailability",
        '"No agents completed yet" result is not a final status',
        "MUST NOT call `close_agent` for a running or pending subagent",
        "become a workflow\ndependency",
        "must wait until every in-scope dispatched subagent reaches\na final status",
        "do not let the parent\nagent's own inline analysis substitute for the subagent result",
        "never use missing output as completion evidence",
        "CODEX_ONLY_OH_NO_READONLY_EXPLORATION_DELEGATION",
        "simple read-only repository fact lookup prompts",
        "may dispatch the registered read-only `oh-no-explore` custom agent",
        "credential values must be redacted",
        "as many as the lookup needs and not capped at one",
        "explicit user-requested subagent task",
        "Custom agents are standalone TOML files",
        "not defined inside `config.toml`",
        "## Custom-Agent Spawn Troubleshooting",
        "hidden or unavailable `agent_type` selector",
        "reserved `collaboration.spawn_agent` schema mismatch",
        "unknown agent type",
        "Provide either message or items, but not both",
        "thread or concurrency limit",
        "hide_spawn_agent_metadata = false",
        'tool_namespace = "agents"',
        "restart Codex and open a new task",
        "Do not edit the user's Codex config automatically",
        "scripts/install-codex-agents --scope user --ensure --quiet",
        "Files ensured on disk are not the same thing as same-session named-agent",
        'sandbox_mode = "read-only"',
        "## Role Prompt Embedding",
        "Agent prompt source: docs/agent-core/<role>.md",
        "Claude-only",
        "## Cross-Host Consult Channel",
        'spawn_agent(agent_type="oh-no-<role>", ...)',
        "`${CLAUDE_BIN:-claude}`",
        "A parent inline Claude consult is not a\nvalid shared cross-host review pass",
    ),
    "codex-runtime.md": (
        "# Codex Runtime Rules",
        "compact platform section is embedded in generated Codex-facing skill",
        "## Skill Loading",
        "docs/platforms/codex-<skill>.md",
        "## User Approval And Prompting",
        "outcome-first",
        "## Role Dispatch",
        "Dispatch only after the active skill's trigger fires",
        "docs/platforms/codex.md",
        'spawn_agent(task_name="ralplan_planner_draft_01", agent_type="oh-no-planner"',
        "fork_context=true",
        "wait_agent",
        "Every dispatched result is a dependency",
        "No agents completed yet",
        "do not close, redo inline, or use missing output as evidence",
        "## Generic Role Prompt Fallback",
        "docs/agent-core/<role>.md",
        "trigger-loaded",
        "docs/platforms/codex.md` `## Cross-Host Consult Channel",
    ),
    "claude-code.md": (
        "# Claude Code Platform Rules",
        "## Skill Loading",
        "skills-claude/",
        "## User Approval",
        "## Auto Routing",
        "CLAUDE_PLUGIN_ROOT",
        "## Task Tracking",
        "## Anthropic-Aligned Prompting",
        "docs/providers/anthropic.md",
        "sectioned",
        "## Role Dispatch",
        "Workflow `agent()`",
        "oh-no-harness:<role>",
        "close or clean\nup the completed subagent",
        "record that fallback",
        "## Model Diversity Pair",
        "identical except the single `Assigned perspective:` line",
        "Assigned perspective",
        "serial dispatch-wait-dispatch",
        "<OH_NO_MODEL_DIVERSITY>",
        "model-diversity-pair",
        "primary leg is\nunoverridden",
        "explicit NATIVE model override",
        "same-model-parallel-fallback",
        "require-model-diversity",
        "transition to PAUSED",
    ),
    "claude-code-runtime.md": (
        "# Claude Code Runtime Rules",
        "compact platform section is embedded in generated Claude Code-facing skill",
        "skills-claude/",
        "docs/platforms/claude-code-<skill>.md",
        "## User Approval, Tasks, And Prompting",
        "structured question tool",
        "task\ntracking",
        "explicit and sectioned",
        "## Role Dispatch",
        "Dispatch only after the active skill's trigger fires",
        "docs/platforms/claude-code.md",
        "oh-no-harness:<role>",
        "whole independent batch before\nwaiting",
        "capture every final result",
        "approved-plan handoff is dispatch authorization",
        "embedded-role fallback",
        "trigger-loaded",
        "## Model Diversity Pair",
        # CR-1 cross-host (M3.2): this shared mechanism dispatches an
        # already-selected pair and must never select topology or assert that
        # every dispatched review is a pair.
        "governs only how an ALREADY-SELECTED pair is dispatched; it never selects review\ntopology itself",
        "The active core or skill owns that selection",
        "never to every dispatched review",
        "identical except the single `Assigned perspective:` line",
        "Assigned perspective",
        "serial dispatch-wait-dispatch",
        "<OH_NO_MODEL_DIVERSITY>",
        "declared-frontmatter primary",
        "explicit NATIVE model override",
        "same-model-parallel-fallback",
        "require-model-diversity",
    ),
}
PROVIDER_DOC_MARKERS = {
    "openai.md": (
        "# OpenAI Provider Prompt Guidance",
        "maintenance reference",
        "company-scoped, not model-scoped",
        "docs/platforms/codex-runtime.md",
        "https://developers.openai.com/api/docs/guides/latest-model",
        "https://developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide",
        "https://developers.openai.com/codex/concepts/subagents",
        "https://developers.openai.com/codex/subagents",
        "not defined\n  inside `config.toml`",
        "SessionStart ensure",
        'sandbox_mode = "read-only"',
        "Do not create model-named provider files",
    ),
    "anthropic.md": (
        "# Anthropic Provider Prompt Guidance",
        "maintenance reference",
        "company-scoped, not model-scoped",
        "docs/platforms/claude-code-runtime.md",
        "https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-8",
        "https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices",
        "https://code.claude.com/docs/en/sub-agents",
        "Do not create model-named provider files",
    ),
}
# agent-tiers.md and parallel-subagents.md were retired 2026-07-17 (no
# remaining consumers after the self-contained FSM rewrites).
# All docs/shared subjects retired 2026-07-17.
PLATFORM_SUBAGENT_DOC_MARKERS: dict[str, tuple[str, ...]] = {}
PLATFORM_ADAPTER_DOC_MARKERS = {
    "claude-code-ralph.md": (
        "CLAUDE_CODE_ONLY_RALPH_ADAPTER",
        "Workflow `agent()`",
        "oh-no-harness:<agent>",
        "@agent-oh-no-harness:<agent>",
        "Claude agent: oh-no-harness:<agent>",
        "background subagents",
        "serial dispatch-wait-dispatch",
        "close or cleanup",
    ),
    "codex-ralph.md": (
        "CODEX_ONLY_RALPH_ADAPTER",
        "## Dispatch Decision",
        "## Role Prompt Embedding",
        "Agent prompt source: docs/agent-core/<role>.md",
        "Agent prompt content:",
        "strip the Claude Code YAML frontmatter",
        "SessionStart is the sole automatic custom-agent preparation path",
        "scripts/install-codex-agents --scope user --ensure --quiet",
        'sandbox_mode = "read-only"',
        "This is required for",
        "failed `spawn_agent(agent_type=\"oh-no-<role>\", ...)` attempt",
        '"No agents completed yet"',
        "MUST NOT call",
        "never use missing output as completion evidence",
        "spawn_agent",
        "wait_agent",
        "close_agent",
        "Parallel trigger: approved-plan-handoff",
        "Parallel trigger: none",
        "Parallel trigger: natural-dispatch",
    ),
}
PLATFORM_ADAPTER_FORBIDDEN_MARKERS = {
    "claude-code-ralph.md": (
        "spawn_agent",
        "CODEX_ONLY_RALPH_ADAPTER",
        "Role: oh-no-harness:<agent>",
    ),
    "codex-ralph.md": ("@agent-oh-no-harness:<agent>", "CLAUDE_CODE_ONLY_RALPH_ADAPTER"),
}
CODEX_TYPED_SPAWN_SOURCES = (
    "codex-runtime.md",
    "codex-interview.md",
    "codex-ralplan.md",
    "codex-ralph.md",
    "codex-systematic-debugging.md",
    "codex-ultrawork.md",
    "codex-verification-before-completion.md",
)
CODEX_TASK_NAME_POLICY_OWNER = "codex.md"
CODEX_TASK_NAME_POLICY_MARKERS = (
    "^[a-z0-9_]+$",
    "deterministic sibling uniqueness",
    "The child rollout should record the expected `agent_role`",
    "A matching task name alone is not role-ownership proof",
)
WORKTREE_FORBIDDEN_MARKERS = (
    "git worktree add ../<repo>-<task-slug>",
    "../<repo>-<task-slug>",
)
WORKTREE_SKILL_MARKERS = {
    "ralplan": (
        "worktree policy",
        "Execution handoff",
        "Ralph owns the actual worktree",
    ),
    "ralph": (
        "## Worktree Isolation Gate",
        "<HARD-GATE>",
        ".oh-no/worktrees/<task-slug>",
        "git worktree add .oh-no/worktrees/<task-slug>",
        "parent workspace directory",
        "git clone",
        "worktreeLocation",
        "Worktree decision and location",
        "Worktree decision: direct automatic worktree",
        "Worktree decision: light direct checkout",
        "re-record",
        "Worktree decision: ultrawork automatic worktree",
        "integration checkout and post-merge verification",
    ),
    "ultrawork": (
        "### WORKTREE",
        ".oh-no/worktrees/<task-slug>",
        "using `git worktree add`",
        "not valid substitutes",
        "Worktree decision: ultrawork automatic worktree",
        "post-merge verification",
    ),
}
WORKTREE_AGENT_MARKERS = {
    "planner": (
        "supplied execution handoff",
        "worktree",
        "Active plan contract",
    ),
    "plan-reviewer": (
        "supplied execution profile and worktree policy",
        "consistency",
        "Active plan contract",
    ),
    "executor": (
        "Worktree decision",
        "caller's\n  dispatch packet",
    ),
}
EXECUTION_MODE_SKILL_MARKERS = {
    "interview": (
        "## Execution Sizing Hint",
        "## Socratic Interview Method",
        "## Question Routing",
        "## Answer Capture",
        "## Dialectic Rhythm Guard",
        "## Spec Closure Gate",
        "Acceptance criteria:",
        "Goal restatement:",
        "Provisional Ralph mode",
        "## Interview Milestones",
        "## Refine Confirmation",
        "## Hidden-Assumption Persona Check",
        "## Breadth And Question Tactics",
        "Machine-consumable requirements for Standard and Deep",
        "`ready` must hold for 2 consecutive rounds",
        "Quick mode is exempt and keeps current behavior",
        "at most 3 candidate hidden-assumption questions",
    ),
    "ralplan": (
        "## Active Plan Contract",
        "## Execution Profile",
        "## Test Case Design Quality",
        "Mode: LIGHT | STANDARD | THOROUGH",
        "Process and diff budget",
        "one complete profile",
        "Validation check",
        "It owns verification tier",
        "approve-and-run Ralph",
    ),
    "ralph": (
        "## Required Execution Mode",
        "## Mode-Gated Agent Dispatch",
        "## Verification Contract and Test Necessity Gate",
        "## Diff-Budget Gate",
        "## Validation Gate",
        "acceptance-to-evidence mapping",
        "story risk-check evidence",
        "validation check",
        "Ralph must set an execution mode",
        "must follow the",
    ),
    "ultrawork": (
        "mode and mode source",
        "active platform's dispatch authorization",
    ),
}
SKILL_REQUIRED_AGENT_ROLES = {
    "interview": ("explore",),
    "ralplan": ("explore", "analyst", "planner", "plan-reviewer"),
    "ralph": (
        "explore",
        "executor",
        "verifier",
        "code-reviewer",
    ),
    "ultrawork": (
        "explore",
        "analyst",
        "planner",
        "executor",
        "debugger",
        "verifier",
        "code-reviewer",
    ),
    "systematic-debugging": (
        "debugger",
        "explore",
        "executor",
        "verifier",
        "code-reviewer",
    ),
    "verification-before-completion": (
        "verifier",
        "code-reviewer",
    ),
    "fusion-rescue": (
        "fusion-rescue-analyst",
    ),
}
SKILLS_WITHOUT_REQUIRED_AGENT_DEPENDENCY: set[str] = set()
AGENT_SKILL_RELATIONSHIP_MARKERS = (
    "## Skill Relationship",
    "not a public workflow skill",
    "calling skill",
)
READ_ONLY_CODEX_AGENT_ROLES = {
    "explore",
    "verifier",
    "code-reviewer",
    "fusion-rescue-analyst",
}
CODEX_AGENT_MODEL_CONFIG = {
    "explore": ("gpt-5.6-terra", "medium"),
    "analyst": ("gpt-5.6-sol", "high"),
    "planner": ("gpt-5.6-sol", "xhigh"),
    "plan-reviewer": ("gpt-5.6-sol", "xhigh"),
    "executor": ("gpt-5.6-sol", "high"),
    "debugger": ("gpt-5.6-sol", "xhigh"),
    "verifier": ("gpt-5.6-sol", "xhigh"),
    "code-reviewer": ("gpt-5.6-sol", "xhigh"),
    "fusion-rescue-analyst": ("gpt-5.6-sol", "xhigh"),
}
EXECUTION_MODE_AGENT_MARKERS = {
    "planner": (
        "Active plan contract",
        "execution handoff",
        "active mode or trigger",
        "AC-mapped tasks",
        "verifier-facing contract",
    ),
    "plan-reviewer": (
        "Active plan contract",
        "supplied execution profile",
        "Active plan contract row fired",
        "material failure of an active AC",
        "user's success signal",
    ),
    "executor": (
        "assigned Ralph execution mode",
        "Execution mode followed",
    ),
    "verifier": (
        "selected execution mode",
        "Execution mode compliance",
        "Canonical acceptance-to-evidence ledger audit and proposed delta status",
        "Risk check before completion status",
        "Validation check",
        "Verification budget and diff-budget status",
        "heavier Ralph execution mode",
    ),
    "code-reviewer": (
        "execution mode escalation",
        "Safety Trigger Checklist",
    ),
}

# The five Claude-only companion transports and their delegation toggle were
# retired. Their former inventory/TOML/kernel/prompt checks are replaced by the
# exact Claude-agent inventory, model-diversity hook/adapter contracts, and the
# preserved nine-role Codex TOML contract below.

SIMPLICITY_SCOPE_SKILL_MARKERS = {
    "ralplan": (
        "smallest approach",
        "Simplicity justification",
    ),
    "ralph": (
        "## Mutation Manifest and Expansion Gate",
        "actual changed paths and meaningful changed lines",
        "speculative abstraction",
    ),
    "simplify": (
        "Speculative abstraction",
        "## Maintainability Debt Boundary",
        "reviewer follow-up",
    ),
}
SIMPLIFY_PARALLEL_MARKERS = (
    "## Cleanup Depth Decision",
    "Reuse, Simplification, Efficiency, and Altitude are review viewpoints",
    "LIGHT and STANDARD: run one quick or combined scan",
    "THOROUGH with a named safety, broad-diff, multi-system, or high-maintainability",
    "Cleanup depth: combined | four-viewpoint",
    "do not create cleanup work",
    "launch the four independent cleanup subagents in one batch",
    "dispatch-unavailable reason",
)
SIMPLIFY_WRAPPER_MARKERS = (
    "oh-no-harness-generated-skill-wrapper",
    "Source order:",
    "../../docs/skill-core/simplify.md",
)
SIMPLIFY_FORBIDDEN_MARKERS = (
    "always runs all four labeled viewpoints",
    "no single-combined-pass shortcut and no diff-size gate",
    "the review always runs all four cleanup role passes regardless of diff size",
)
SIMPLICITY_SCOPE_AGENT_MARKERS = {
    "planner": (
        "smallest executable",
        "justify new abstraction",
    ),
    "plan-reviewer": (
        "simplest sufficient approach",
        "speculative abstraction",
        "smallest AC-sufficient correction",
    ),
    "executor": (
        "Scope trace summary",
        "Match the surrounding code style",
    ),
    "code-reviewer": (
        "untraceable changes",
        "drive-by formatting",
        "Practical Maintainability Gate",
        "unclear ownership",
    ),
}
ACCEPTANCE_CRITERIA_AGENT_MARKERS = {
    "analyst": (
        "acceptance criteria",
        "success and failure signals",
        "useful but insufficient proof",
    ),
    "planner": (
        "Direction Contract and AC IDs",
        "verifier-facing contract",
        "wrong-surface behavior",
        "validation",
    ),
    "plan-reviewer": (
        "active AC",
        "user's success signal",
        "wrong-surface tests",
        "Direction Contract and AC IDs",
        "requested-direction-change: yes",
        "validation",
    ),
}
VALIDATION_CHECK_AGENT_MARKERS = {
    "planner": (
        "Apply validation",
        "active mode or trigger",
    ),
    "plan-reviewer": (
        "Active plan contract row fired",
        "material failure of an active AC",
    ),
    "verifier": (
        "Validation check",
        "Measurable evidence is diagnostic evidence",
    ),
    "code-reviewer": (
        "changes justified only by",
        "metric movement",
        "Risk from metric-only evidence",
    ),
}
SAFETY_REVIEW_AGENT_MARKERS = {
    "code-reviewer": (
        "Safety Trigger Checklist",
        "destructive operations",
        "filesystem traversal",
        "shell execution",
        "network egress",
        "credential",
        "user data",
    ),
}
# review-scope-discipline: every Bash-wielding analysis/review role must stay
# bounded to its assigned work and must not turn into a system-wide security or
# penetration sweep against real sensitive files. Checked whitespace-tolerant
# (has_required_marker) so a wrapped marker still matches.
REVIEW_SCOPE_DISCIPLINE_MARKERS = {
    agent: (
        "system-wide security or penetration",
        "clearly synthetic placeholder path",
    )
    for agent in ("code-reviewer", "debugger", "verifier", "plan-reviewer", "explore")
}
APPROVED_DIRECTION_AGENT_MARKERS = {
    "plan-reviewer": (
        "approved direction",
        "Direction Contract and AC IDs",
        "requested-direction-change: yes",
        "do not substitute your preferred direction",
    ),
}
# Re-anchored to the FSM core (2026-07-16 rewrite): rule-ID / compact stems,
# never full prose sentences, so wording edits do not break validation.
RALPLAN_CONSENSUS_MARKERS = (
    "single canonical schema",
    "## Active Plan Contract",
    "requested-direction-change: yes",
    "## Test Case Design Quality",
    "supporting evidence, not a replacement outcome",
    "selected by the execution risk",
    "## Requirements Source And Analyst Gate",
    "## Planner Draft Contract",
    "## Plan Review Contract",
    "## Planner Revision Contract",
    "## Findings Ledger Gate",
    "Planner draft v1",
    "Planner revision v2",
    "Analyst -> Planner -> Plan-Reviewer",
    "APPROVE freezes the exact reviewed Planner draft",
    "blocking | non-blocking",
    # Review topology is risk-selected: STANDARD and ordinary THOROUGH each keep
    # ONE required full-role reviewer; only the named paired-review trigger
    # escalates to the perspective-diverse pair.
    "STANDARD -> one required Plan-Reviewer",
    "THOROUGH -> one required full-role Plan-Reviewer instance by default",
    "ONLY the named THOROUGH\n            paired-review trigger",
    "required Plan-Reviewer cannot be skipped",
    "accepted blocking feedback is not in the body",
    "accepted section pointer",
    "requested direction change without explicit approval",
    "must-fail-before-implementation",
    "must-pass-after-implementation",
    "negative or forbidden-behavior case",
    "edge, boundary, or regression case",
    "only check marker strings",
    "product-like state machine",
)
RALPLAN_FORBIDDEN_SPLIT_OPTION_MARKERS = (
    "`oh-no-harness:ralph` with `parallel subagents`",
    "Run ralph with parallel subagents",
    "parallel-subagent Ralph option",
    "choose `ralph`, `ralph with parallel subagents`, or `ultrawork`",
    "including how to explicitly approve it on",
)
RALPLAN_APPROVAL_BRIEF_FORBIDDEN_MARKERS = (
    "text diagram",
    "{text diagram}",
)
# The full three-part eligibility test (safe isolation, decision-changing
# value, reasonable coordination cost) is defined once in ## Execution
# Profile; Plan File Requirements and the Approval Brief reference it instead
# of restating it (single-definition rule from the 2026-07-16 FSM rewrite).
RALPLAN_APPROVED_PLAN_DEFAULT_MARKERS = (
    "Dispatch-eligibility test",
    "safe isolation",
    "decision-changing",
    "reasonable coordination cost",
)
RALPLAN_ELIGIBILITY_SURFACE_MARKERS = (
    "dispatch-eligibility test",
)
RALPLAN_ELIGIBILITY_SURFACE_FORBIDDEN_MARKERS = (
    "no role can be safely isolated",
    "no eligible role can be isolated",
)
RALPLAN_LIGHT_PLAN_FILE_MARKERS = (
    "Compact LIGHT",
    "must still preserve",
    "goal",
    "scope",
    "non-goals",
    "acceptance criteria",
    "tasks",
    "key files",
    "verification",
    "compact execution profile",
    "approval status",
    "may omit",
    "inactive review",
    "rollout ceremony",
)
# The compact-LIGHT item list is defined once in ## Plan File Requirements;
# the Approval Brief references it instead of restating it (single-definition
# rule from the 2026-07-16 FSM rewrite).
RALPLAN_LIGHT_APPROVAL_BRIEF_MARKERS = (
    "Compact LIGHT",
    "same items",
    "## Plan File Requirements",
    "Omit inactive sections",
)
RALPLAN_DIRECT_HANDOFF_REQUIRED_PATTERNS = (
    (r"approve[- ]and[- ]run.{0,120}\bralph\b", "approve-and-run Ralph"),
    (r"approve[- ]and[- ]run.{0,120}\bultrawork\b", "approve-and-run Ultrawork"),
    (r"\brequest(?:\s+plan)?\s+changes\b", "request changes"),
    (r"\bleave\s+(?:it\s+|the\s+plan\s+)?pending\b", "leave pending"),
)
RALPLAN_DIRECT_HANDOFF_REQUIRED_MARKERS = (
    "Do NOT invoke",
)
RALPLAN_DIRECT_HANDOFF_FORBIDDEN_MARKERS = (
    "two phases",
    "### Phase 1",
    "### Phase 2",
    "Phase 1:",
    "Phase 2:",
)
MANDATORY_GATE_RALPLAN_HANDOFF_ROW_MARKERS = (
    "combined",
    "approval",
    "choice",
)
MANDATORY_GATE_RALPLAN_HANDOFF_ROW_PATTERNS = (
    (r"approve[- ]and[- ]run", "approve-and-run"),
    (r"automatic[- ]invocation|auto[- ]invoke", "automatic invocation"),
)
RALPLAN_AGENT_CONTRACT_MARKERS = {
    "planner": (
        "Active plan contract",
        "plan body as the source of truth",
        "classify every blocking finding",
        "before assigning a new draft id or mutating the plan body",
        "disposition-only user-decision packet",
        "smallest tests",
        "APPROVE freezes the exact reviewed draft",
    ),
    "plan-reviewer": (
        "Active plan contract",
        "exact draft id",
        "never produce a replacement plan",
        "APPROVE | ITERATE | REJECT",
        "Material-blocker predicate",
        "unsupported false rejection",
        "pass against old behavior",
        "Architecture findings",
        "Quality-gate findings",
    ),
}
TDD_COMMAND_DESCRIPTION_MARKERS = (
    "explicit TDD/test-first",
    "RED/GREEN/REFACTOR",
    "ordinary implementation routes through ralph",
)
TDD_CORE_ROUTING_MARKERS = (
    "internal mid-loop discipline",
    "not a top-level implementation skill",
    "Use `ralph` for those concrete implementation requests",
    "explicitly asked for TDD",
    "already-selected workflow",
    "no\nseparate direct edit path",
    "return control to `ralph`, `systematic-debugging`",
    "Do not continue as a substitute for `ralph`",
)
TDD_ROUTING_DOC_MARKERS = {
    "docs/skill-core/ralph.md": (
        "Ralph owns execution mode selection or enforcement",
        "Do not route concrete add/fix/refactor/implement requests directly to `test-driven-development`",
        "Ralph invokes TDD internally",
        "Classify the story's TDD requirement",
    ),
}
TDD_FORBIDDEN_DOC_MARKERS = (
    "Use when implementing a feature, bugfix",
    "Any behavior-changing edit",
    "동작이 바뀌는 모든 수정",
    "Use RED/GREEN/REFACTOR for behavior-changing work.",
    "About to make a behavior-changing production edit: oh-no-harness:test-driven-development",
    "behavior-changing edits go through test-driven-development",
    "direct implementation path",
    "<feature, bugfix, refactor, or behavior change>",
)
TDD_SCOPE_SECTION_MARKERS = (
    (
        "docs/skill-core/test-driven-development.md",
        "## Required Cycle",
        "For this cycle, one behavior means one observable contract change from the approved Direction Contract, not each internal branch, helper, or condition. Coupled internal conditions that serve one observable outcome may share one minimal RED; independent user-visible outcomes remain separate cycles.",
    ),
    (
        "docs/skill-core/test-driven-development.md",
        "## Required Cycle",
        "Do not batch independent observable behaviors into one RED step. If the test name joins independent user-visible outcomes with \"and\", split the test; do not split solely because one outcome depends on coupled internal conditions.",
    ),
    (
        "docs/skill-core/test-driven-development.md",
        "## Proportional Test Boundary",
        "Add negative, boundary, semantic-model, concurrency, resume, adversarial, or baseline cases only when an AC ID, named safety/risk trigger, adjacent regression surface, or safety invariant requires them.",
    ),
    (
        "docs/skill-core/test-driven-development.md",
        "## Proportional Test Boundary",
        "If no approved admission source exists, record the proposed extra case as `not relevant` with the reason and do not implement it.",
    ),
    (
        "docs/skill-core/test-driven-development.md",
        "## When To Use",
        "A missing practical harness permits a documented TDD exception plus existing real-surface, bounded manual, or residual-risk evidence; it does not authorize new durable test infrastructure or production seams unless the user separately approves that scope.",
    ),
    (
        "docs/skill-core/verification-before-completion.md",
        "## Risk Check Before Completion",
        "The \"one more useful failing test\" field is non-blocking residual-risk documentation. Do not implement it or use it to block completion unless it maps to an unmet AC ID or an approved named risk; otherwise record it as `not relevant` with the reason.",
    ),
    (
        # 2026-07-17 FSM rewrite: the merge-step rule is invariant V5.
        "docs/skill-core/verification-before-completion.md",
        "## Invariants",
        "A merge or integration step is evidence-changing unless the caller proves the final files and dependencies are identical to the verifier-audited state.",
    ),
    (
        "docs/skill-core/ralph.md",
        "## Review Gate",
        "each ruled out with a one-line reason that names why no approved AC ID, named risk, adjacent regression surface, safety invariant, or directly changed semantic model triggers it",
    ),
    (
        "docs/skill-core/ralph.md",
        "## Output",
        "Process anomaly outcome: planned versus actual tests/TDD cycles, role dispatch reasons, broad-suite runs, and rescope events; no count authorizes or proves work.",
    ),
)
TDD_SCOPE_SECTION_FORBIDDEN_MARKERS = (
    (
        "docs/skill-core/test-driven-development.md",
        "## Required Cycle",
        "Every internal branch, helper, or condition requires its own RED cycle.",
    ),
    (
        "docs/skill-core/test-driven-development.md",
        "## When To Use",
        "A missing practical harness authorizes creating durable test infrastructure or production seams.",
    ),
)

FUSION_RESCUE_SKILL_MARKERS = (
    "## Panel Contract",
    "exactly three default panel slots",
    "primary",
    "adversarial",
    "pragmatic",
    "active platform rules",
    "## Platform-Defined Consult",
    "Only where the active platform rules define an opposite-host consult path",
    "Without such a platform rule, no opposite-host consult is attempted or required",
    "## Fallback Behavior",
    "three independent same-model panel instances",
    "strict mode transitions to PAUSED",
    "## Recursion Guard",
    "fusion depth: 1",
    "exactly that one call and no other host call",
    "## Judge And Synthesis",
    "current host main agent",
    "consensus",
    "contradictions",
    "unique insights",
    "blind spots",
    "recommended next action",
    "confidence and why",
    "panel availability/fallback notes",
    "## Semantic Scenario Checks",
    "Three-panel shape",
    "Intentional contradiction",
    "Diversity unavailable",
    "Recursive consult",
    "## Caller Return",
    "return control to `ralph`",
    "return control to\n`systematic-debugging`",
    "Standalone mode",
    "Do not edit files\ndirectly",
)
FUSION_RESCUE_PANEL_LENSES = ("primary", "adversarial", "pragmatic")
FUSION_RESCUE_SYNTHESIS_FIELDS = (
    "consensus",
    "contradictions",
    "unique insights",
    "blind spots",
    "recommended next action",
    "confidence and why",
    "panel availability/fallback notes",
    "fusion depth: 1",
)
FUSION_RESCUE_SCENARIO_MARKERS = {
    "Three-panel shape": (
        "exactly three same-role panels",
        "same packet\n  shape",
        "distinct assigned lenses",
        "run in parallel",
    ),
    "Intentional contradiction": (
        "`primary`",
        "`adversarial`",
        "`pragmatic`",
        "must name the contradiction",
        "recommend the smallest next check",
    ),
    "Diversity unavailable": (
        "platform-defined fallback",
        "disclose the reason",
        "strict mode must PAUSE",
    ),
    "Recursive consult": (
        "attempts to call rescue",
        "reject the nested call",
        "`fusion depth: 1`",
        "Same-host\n  read-only subagents",
    ),
}
# B4a: concrete panel-model policy belongs only to platform adapters. This list
# protects the neutral core from silently regaining Claude's configuration terms.
FUSION_RESCUE_CORE_FORBIDDEN_MODEL_MARKERS = (
    "top-tier",
    "panel-default",
    "secondary_top_model",
    "model-diversity-pair",
    "same-model-parallel-fallback",
    "require-model-diversity",
    "explicit NATIVE model override",
    "declared-frontmatter primary",
)
FUSION_RESCUE_FORBIDDEN_MARKERS = (
    "weaker mode",
    "approves a weaker",
    "${CLAUDE_BIN:-claude}",
    "`--permission-mode`",
    "`dontAsk`",
    "`--no-session-persistence`",
    "Claude Opus must answer the assigned panel directly",
    "Claude-side skill or slash command",
    "Codex permission state",
    "openai/codex-plugin-cc",
    "`/codex:rescue`",
)
FUSION_RESCUE_PLATFORM_DOC_MARKERS = {
    "codex-fusion-rescue.md": (
        "This platform overlay is source content for the generated Codex-facing",
        "Codex remains responsible for the `adversarial` lens when Codex is available",
        "assign exactly one\nnon-adversarial panel slot",
        "`${CLAUDE_BIN:-claude}`",
        "current Codex permission state is exactly `danger-full-access`",
        "Codex permission preflight confirms `danger-full-access`",
        "argument vector",
        "`--print`",
        "`--model`",
        "`opus`",
        "`--permission-mode`",
        "`dontAsk`",
        "Do not specify a Claude tools override by default",
        "its own permitted tools to perform the read-only analysis",
        "not by stripping tools from the consult",
        "`--no-session-persistence`",
        "Claude Opus must answer the assigned panel directly",
        "Claude-side skill or slash command",
        "`/oh-no-harness:fusion-rescue`",
        "treat the cross-host consult as unavailable",
        "redacted and minimized problem packet",
        "Claude unavailable: Codex permission state is not danger-full-access",
        "require-cross-host",
    ),
    "claude-code-fusion-rescue.md": (
        "This platform overlay is source content for the generated Claude Code-facing",
        "## Model Diversity Panels",
        "exactly three same-role `fusion-rescue-analyst` panels in parallel",
        "All three panel identities MUST be members of the block's resolved top-tier list",
        "explicit NATIVE model override",
        "declared-frontmatter primary",
        "otherwise it is the first NATIVE entry of the top-tier list",
        "assign exactly two panels the explicit NATIVE secondary override",
        "assign exactly one panel a distinct top-tier identity",
        "Degenerate configured case",
        "3 × panel-default (top-tier)",
        "same-model-parallel-fallback",
        "require-model-diversity",
        "transitions to PAUSED",
        "Unconfigured case",
        "## No Opposite-Host Consult",
        "Claude Code defines no opposite-host consult path for Fusion Rescue",
    ),
}


def die(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        die(f"missing file: {path}")


def read_active_stale_scan_text(path: Path):
    try:
        data = path.read_bytes()
    except FileNotFoundError:
        die(f"missing file: {path}")
    if b"\x00" in data:
        return None
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError as exc:
        die(f"{path} is not valid UTF-8 for active stale-contract scan: {exc}")


def has_required_marker(text: str, marker: str) -> bool:
    if marker in text:
        return True
    if not re.search(r"\s", marker):
        return False
    normalized_text = re.sub(r"\s+", " ", text).strip()
    normalized_marker = re.sub(r"\s+", " ", marker).strip()
    return normalized_marker in normalized_text


def parse_frontmatter(path: Path) -> dict[str, str]:
    text = read_text(path)
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        die(f"{path} is missing YAML frontmatter")

    frontmatter: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            return frontmatter
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            die(f"{path} has unsupported frontmatter line: {line}")
        key, value = line.split(":", 1)
        frontmatter[key.strip()] = value.strip().strip('"')

    die(f"{path} has unterminated YAML frontmatter")


def strip_frontmatter(text: str, path: Path) -> str:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        die(f"{path} is missing YAML frontmatter")
    for index, line in enumerate(lines[1:], start=1):
        if line.strip() == "---":
            return "\n".join(lines[index + 1 :]).strip() + "\n"
    die(f"{path} has unterminated YAML frontmatter")


def markdown_section(text: str, heading: str) -> str:
    lines = text.splitlines()
    start = None
    heading_level = None
    heading_match = re.match(r"^(#{1,6})\s+\S", heading.strip())
    if heading_match:
        heading_level = len(heading_match.group(1))
    for index, line in enumerate(lines):
        if line.strip() == heading:
            start = index + 1
            break
    if start is None:
        return ""

    end = len(lines)
    for index in range(start, len(lines)):
        stripped = lines[index].strip()
        match = re.match(r"^(#{1,6})\s+\S", stripped)
        if match and heading_level is not None and len(match.group(1)) <= heading_level:
            end = index
            break
    return "\n".join(lines[start:end])


def markdown_bullet_block(section: str, label: str) -> str:
    lines = section.splitlines()
    start = None
    prefix = f"- {label}:"
    for index, line in enumerate(lines):
        if line.startswith(prefix):
            start = index
            break
    if start is None:
        return ""

    end = len(lines)
    for index in range(start + 1, len(lines)):
        if lines[index].startswith("- "):
            end = index
            break
    return "\n".join(lines[start:end])


def assert_fusion_rescue_contract(path: Path, body: str) -> None:
    for marker in FUSION_RESCUE_FORBIDDEN_MARKERS:
        if marker in body:
            die(f"{path} contains forbidden Fusion Rescue weak-consult marker: {marker!r}")

    panel_contract = markdown_section(body, "## Panel Contract")
    if not panel_contract:
        die(f"{path} is missing required Fusion Rescue Panel Contract section")
    lens_matches = re.findall(r"^\d+\.\s+`([^`]+)`:", panel_contract, flags=re.MULTILINE)
    if tuple(lens_matches) != FUSION_RESCUE_PANEL_LENSES:
        die(
            f"{path} must define exactly these Fusion Rescue panel lenses in order: "
            f"{FUSION_RESCUE_PANEL_LENSES!r}; found {tuple(lens_matches)!r}"
        )
    if not has_required_marker(panel_contract, "owned entirely by the active platform rules"):
        die(f"{path} Panel Contract must delegate panel-model policy to platform rules")
    for marker in FUSION_RESCUE_CORE_FORBIDDEN_MODEL_MARKERS:
        if marker in body:
            die(f"{path} contains adapter-owned panel-model policy: {marker!r}")
    for marker in (
        "caller's Direction Contract",
        "exact blocked decision",
        "remaining process budget",
        "not to create a new proof architecture",
        "outside the\n  Direction Contract's goal and non-goals",
    ):
        if not has_required_marker(panel_contract, marker):
            die(f"{path} Panel Contract is missing goal-preservation marker: {marker!r}")

    consult = markdown_section(body, "## Platform-Defined Consult")
    if not consult:
        die(f"{path} is missing required Fusion Rescue Platform-Defined Consult section")
    for marker in (
        "Only where the active platform rules define an opposite-host consult path",
        "platform owns the\nconsult mechanism",
        "Without such a platform rule, no\nopposite-host consult is attempted or required",
        "read-only, bounded to one assigned lens",
        "launch notice, queued-job message, background\nacknowledgement",
        "not a panel result",
    ):
        if not has_required_marker(consult, marker):
            die(f"{path} Platform-Defined Consult section is missing marker: {marker!r}")

    fallback = markdown_section(body, "## Fallback Behavior")
    if not fallback:
        die(f"{path} is missing required Fusion Rescue Fallback Behavior section")
    for marker in (
        "active platform owns panel-model assignment",
        "three independent same-model panel instances",
        "platform-defined\nfallback assignment",
        "record the reason",
        "strict mode transitions to PAUSED",
        "instead of silently degrading",
        "evidence and unblock details",
    ):
        if not has_required_marker(fallback, marker):
            die(f"{path} Fallback Behavior section is missing marker: {marker!r}")

    recursion = markdown_section(body, "## Recursion Guard")
    if not recursion:
        die(f"{path} is missing required Fusion Rescue Recursion Guard section")
    for marker in (
        "fusion depth: 1",
        "Do not invoke rescue, fusion-rescue, another workflow skill, or another host",
        "Same-host read-only subagents and read-only tools are allowed",
        "exactly that one call and no other host call",
        "applies\ntransitively to same-host read-only subagents",
    ):
        if not has_required_marker(recursion, marker):
            die(f"{path} Recursion Guard section is missing marker: {marker!r}")

    synthesis = markdown_section(body, "## Judge And Synthesis")
    if not synthesis:
        die(f"{path} is missing required Fusion Rescue Judge And Synthesis section")
    if "The current host main agent is the judge" not in synthesis:
        die(f"{path} Judge And Synthesis must keep the current host as judge")
    if not has_required_marker(synthesis, "must not only concatenate"):
        die(f"{path} Judge And Synthesis must reject concatenation-only output")
    for marker in (
        "remaining process budget",
        "Direction Contract",
        "new\nproof architecture",
    ):
        if not has_required_marker(synthesis, marker):
            die(f"{path} Judge And Synthesis is missing goal-preservation marker: {marker!r}")
    for field in FUSION_RESCUE_SYNTHESIS_FIELDS:
        if not has_required_marker(synthesis, field):
            die(f"{path} Judge And Synthesis is missing required field: {field!r}")

    scenarios = markdown_section(body, "## Semantic Scenario Checks")
    if not scenarios:
        die(f"{path} is missing required Fusion Rescue Semantic Scenario Checks section")
    for label, markers in FUSION_RESCUE_SCENARIO_MARKERS.items():
        scenario_block = markdown_bullet_block(scenarios, label)
        if not scenario_block:
            die(f"{path} Semantic Scenario Checks is missing scenario: {label!r}")
        for marker in markers:
            if not has_required_marker(scenario_block, marker):
                die(
                    f"{path} Semantic Scenario Checks scenario {label!r} "
                    f"is missing marker: {marker!r}"
                )

    caller_return = markdown_section(body, "## Caller Return")
    if not caller_return:
        die(f"{path} is missing required Fusion Rescue Caller Return section")
    for marker in (
        "Standalone mode returns analysis and recommendations only",
        "Do not edit files directly",
        "return control to `ralph`",
        "Ralph remains responsible",
        "return control to `systematic-debugging`",
        "Systematic Debugging remains responsible",
    ):
        if not has_required_marker(caller_return, marker):
            die(f"{path} Caller Return section is missing marker: {marker!r}")


def assert_fusion_rescue_platform_contracts(root: Path) -> None:
    platform_root = root / "docs" / "platforms"
    for filename, markers in FUSION_RESCUE_PLATFORM_DOC_MARKERS.items():
        path = platform_root / filename
        body = read_text(path)
        for marker in markers:
            if not has_required_marker(body, marker):
                die(f"{path} is missing required Fusion-Rescue platform marker: {marker!r}")

    codex_body = read_text(platform_root / "codex-fusion-rescue.md")
    claude_body = read_text(platform_root / "claude-code-fusion-rescue.md")
    for marker in ("model-diversity-pair", "require-model-diversity", "panel-default"):
        if marker in codex_body:
            die(f"{platform_root / 'codex-fusion-rescue.md'} contains Claude model-diversity policy: {marker!r}")
    for marker in (
        "`${CLAUDE_BIN:-claude}`",
        "`--permission-mode`",
        "`dontAsk`",
        "codex-companion",
        "require-cross-host",
    ):
        if marker in claude_body:
            die(f"{platform_root / 'claude-code-fusion-rescue.md'} contains retired cross-host consult policy: {marker!r}")


def is_guardrail_line(line: str) -> bool:
    lowered = line.lower()
    return any(term in lowered for term in ULTRAWORK_RUNTIME_GUARDRAIL_TERMS)


def assert_no_forbidden_ultrawork_runtime_claims(path: Path, body: str) -> None:
    for line_number, line in enumerate(body.splitlines(), start=1):
        if is_guardrail_line(line):
            continue
        for pattern in ULTRAWORK_FORBIDDEN_RUNTIME_PATTERNS:
            if re.search(pattern, line, flags=re.IGNORECASE):
                die(
                    f"{path}:{line_number} contains forbidden Ultrawork runtime "
                    f"dependency/authority claim matching {pattern!r}: {line.strip()!r}"
                )


def assert_ultrawork_loop_contract(path: Path, body: str) -> None:
    # The 2026-07-16 FSM rewrite folded ## Loop Contract into Invariants,
    # Heartbeat, and the State Machine; the loop-bearing stems now anchor
    # against the whole core body under those three required sections.
    for heading in ("## Invariants", "## Heartbeat", "## State Machine"):
        if not markdown_section(body, heading).strip():
            die(f"{path} is missing required Ultrawork section: {heading!r}")
    for marker in ULTRAWORK_LOOP_CONTRACT_MARKERS:
        if not has_required_marker(body, marker):
            die(f"{path} is missing required Ultrawork Loop Contract marker: {marker!r}")
    assert_no_forbidden_ultrawork_runtime_claims(path, body)


def assert_skill_frontmatter(
    path: Path, skill: str, platform: str | None = None
) -> dict[str, str]:
    fm = parse_frontmatter(path)
    missing = REQUIRED_SKILL_FIELDS - set(fm)
    if missing:
        die(f"{path} missing frontmatter fields: {sorted(missing)}")
    expected_name = skill.split("/")[-1]
    if fm["name"] != expected_name:
        die(f"{path} name={fm['name']!r}, expected {expected_name!r}")
    if platform == "opencode":
        if set(fm) != OPENCODE_ALLOWED_SKILL_FIELDS:
            die(
                f"{path} OpenCode frontmatter fields must be exactly "
                f"{sorted(OPENCODE_ALLOWED_SKILL_FIELDS)!r}; actual={sorted(fm)!r}"
            )
        return fm
    if skill in WORKFLOW_SKILLS_REQUIRING_ARGUMENT_HINT and "argument-hint" not in fm:
        die(f"{path} should define argument-hint")
    dmi = fm.get("disable-model-invocation")
    if skill in MODEL_UNINVOCABLE_SKILLS:
        if dmi != "true":
            die(
                f"{path} should set disable-model-invocation: true "
                f"({skill} must never be model-invocable)"
            )
    elif dmi == "true":
        die(
            f"{path} unexpectedly disables model invocation for model-invocable skill {skill}"
        )
    return fm


def assert_model_uninvocable_skill_mutation_guards(root: Path) -> None:
    # ralplan-v2 retired 2026-07-17. install-statusline and configure-subagents
    # are the remaining model-uninvocable skills. Their Claude sources must keep
    # exactly one disable-model-invocation marker,
    # and the frontmatter guard must reject a core/wrapper mutation that drops it.
    for skill in sorted(MODEL_UNINVOCABLE_SKILLS):
        paths = (
            root / SKILL_CORE_ROOT / f"{skill}.md",
            root / CLAUDE_SKILL_ROOT / skill / "SKILL.md",
        )
        for source in paths:
            text = read_text(source)
            marker = "disable-model-invocation: true\n"
            if text.count(marker) != 1:
                die(f"{source} must contain exactly one {marker.strip()!r} marker")
            with tempfile.TemporaryDirectory() as temp_dir:
                mutated = Path(temp_dir) / source.name
                mutated.write_text(text.replace(marker, "", 1), encoding="utf-8")
                try:
                    assert_skill_frontmatter(mutated, skill)
                except SystemExit:
                    continue
                die(
                    "Model-uninvocable invocation guard accepted a core/wrapper "
                    "mutation without disable-model-invocation: true "
                    f"({source})"
                )


def assert_skill_wrapper(root: Path, skill: str, skill_root: str, platform: str) -> None:
    path = root / skill_root / skill / "SKILL.md"
    assert_skill_frontmatter(path, skill, platform)
    body = read_text(path)
    core_marker = f"../../{SKILL_CORE_ROOT}/{skill}.md"
    if platform != "opencode" and core_marker not in body:
        die(f"{path} should reference shared skill core: {core_marker!r}")

    if platform == "codex":
        required = "docs/platforms/codex-runtime.md"
        child_packet_floor = "docs/platforms/codex-child-packet-floor.md"
        forbidden = (
            "docs/platforms/claude-code-runtime.md",
            "docs/platforms/claude-code.md",
            "docs/platforms/claude-code-ralph.md",
            "CLAUDE_PLUGIN_ROOT",
        )
        if child_packet_floor not in body:
            die(f"{path} should reference Codex child-packet floor: {child_packet_floor!r}")
        if skill in SELF_CONTAINED_ADAPTER_SKILLS:
            required = f"docs/platforms/codex-{skill}.md"
            forbidden += ("docs/platforms/codex-runtime.md",)
        if skill == "ralph" and "docs/platforms/codex-ralph.md" not in body:
            die(f"{path} should reference Codex Ralph adapter")
        if skill == "auto-routing" and "docs/platforms/codex-auto-routing.md" not in body:
            die(f"{path} should reference Codex Auto Routing overlay")
        if skill == "fusion-rescue":
            if "docs/platforms/codex-fusion-rescue.md" not in body:
                die(f"{path} should reference Codex Fusion Rescue adapter")
            if "docs/platforms/claude-code-fusion-rescue.md" in body:
                die(f"{path} contains forbidden Claude Code Fusion Rescue adapter marker")
    elif platform == "claude":
        required = "docs/platforms/claude-code-runtime.md"
        forbidden = (
            "docs/platforms/codex-runtime.md",
            "docs/platforms/codex-child-packet-floor.md",
            "docs/platforms/codex.md",
            "docs/platforms/codex-ralph.md",
            "spawn_agent",
        )
        if skill in SELF_CONTAINED_ADAPTER_SKILLS:
            required = f"docs/platforms/claude-code-{skill}.md"
            forbidden += ("docs/platforms/claude-code-runtime.md",)
        if skill == "ralph" and "docs/platforms/claude-code-ralph.md" not in body:
            die(f"{path} should reference Claude Code Ralph adapter")
        if skill == "auto-routing" and "docs/platforms/claude-code-auto-routing.md" not in body:
            die(f"{path} should reference Claude Code Auto Routing overlay")
        if skill == "fusion-rescue":
            if "docs/platforms/claude-code-fusion-rescue.md" not in body:
                die(f"{path} should reference Claude Code Fusion Rescue adapter")
            if "docs/platforms/codex-fusion-rescue.md" in body:
                die(f"{path} contains forbidden Codex Fusion Rescue adapter marker")
    elif platform == "opencode":
        if skill == "configure-subagents":
            source_paths = ["docs/platforms/opencode-configure-subagents.md"]
        else:
            source_paths = [f"{SKILL_CORE_ROOT}/{skill}.md"]
            if skill in SELF_CONTAINED_ADAPTER_SKILLS:
                source_paths.append(f"docs/platforms/opencode-{skill}.md")
            else:
                source_paths.append("docs/platforms/opencode-runtime.md")
                overlay = root / "docs" / "platforms" / f"opencode-{skill}.md"
                if overlay.exists():
                    source_paths.append(f"docs/platforms/opencode-{skill}.md")

        actual_sources = re.findall(r"^## Source: (.+)$", body, flags=re.MULTILINE)
        if actual_sources != source_paths:
            die(
                f"{path} OpenCode source composition mismatch: "
                f"expected={source_paths!r} actual={actual_sources!r}"
            )
        expected_source_list = [f"../../{source}" for source in source_paths]
        for source in expected_source_list:
            if f"- `{source}`" not in body:
                die(f"{path} is missing OpenCode Source order marker: {source!r}")
        if skill != "configure-subagents" and core_marker not in body:
            die(f"{path} should reference shared skill core: {core_marker!r}")
        if skill in SELF_CONTAINED_ADAPTER_SKILLS:
            required = f"docs/platforms/opencode-{skill}.md"
            if "docs/platforms/opencode-runtime.md" in body:
                die(f"{path} self-contained OpenCode wrapper must not embed common runtime")
        elif skill == "configure-subagents":
            required = "docs/platforms/opencode-configure-subagents.md"
            for forbidden_source in (
                core_marker,
                "docs/platforms/opencode-runtime.md",
            ):
                if forbidden_source in body:
                    die(
                        f"{path} standalone OpenCode setup wrapper contains forbidden "
                        f"composition source: {forbidden_source!r}"
                    )
        else:
            required = "docs/platforms/opencode-runtime.md"
        forbidden = ()
        for pattern, reason in OPENCODE_FORBIDDEN_WRAPPER_PATTERNS:
            if re.search(pattern, body):
                die(f"{path} contains forbidden {reason}: pattern={pattern!r}")
    else:
        die(f"unknown platform for wrapper validation: {platform}")

    if required not in body:
        die(f"{path} should reference platform rules: {required!r}")
    if "oh-no-harness-generated-skill-wrapper" not in body:
        die(f"{path} should be a generated runtime skill wrapper")
    if "DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write" not in body:
        die(f"{path} should include generated skill wrapper regeneration marker")
    for marker in forbidden:
        if marker in body:
            die(f"{path} contains forbidden cross-platform wrapper marker: {marker!r}")


def assert_skill(root: Path, skill: str) -> None:
    available = SKILL_AVAILABILITY[skill]
    for platform, skill_root in SKILL_ROOTS.items():
        wrapper = root / skill_root / skill / "SKILL.md"
        if platform in available:
            assert_skill_wrapper(root, skill, skill_root, platform)
        elif wrapper.exists():
            die(f"{wrapper} should not exist; {skill} is unavailable on {platform}")

    path = root / SKILL_CORE_ROOT / f"{skill}.md"
    assert_skill_frontmatter(path, skill)
    if skill in NEXT_SKILL_GATE_REQUIRED:
        body = read_text(path)
        for marker in NEXT_SKILL_GATE_MARKERS:
            if marker not in body:
                die(f"{path} is missing required Next-Skill-Gate marker: {marker!r}")
    if skill == "ultrawork":
        body = read_text(path)
        if ULTRAWORK_EXCEPTION_HEADING not in body:
            die(f"{path} is missing required heading: {ULTRAWORK_EXCEPTION_HEADING!r}")
        for marker in ULTRAWORK_AUTO_APPROVAL_MARKERS:
            if not has_required_marker(body, marker):
                die(f"{path} is missing required Ultrawork auto-approval marker: {marker!r}")
        assert_ultrawork_loop_contract(path, body)
    if skill in ROLE_POLICY_MARKERS:
        body = read_text(path)
        marker = ROLE_POLICY_MARKERS[skill]
        if marker not in body:
            die(f"{path} is missing required role-policy marker: {marker!r}")
    if skill in EXECUTION_MODE_SKILL_MARKERS:
        body = read_text(path)
        for marker in EXECUTION_MODE_SKILL_MARKERS[skill]:
            if not has_required_marker(body, marker):
                die(f"{path} is missing required Execution-Mode marker: {marker!r}")
    if skill in SKILL_REQUIRED_AGENT_ROLES:
        body = read_text(path)
        agent_roles_section = markdown_section(body, "## Agent Roles")
        if not agent_roles_section:
            die(f"{path} is missing required Agent Roles section")
        for role in SKILL_REQUIRED_AGENT_ROLES[skill]:
            if not has_token(agent_roles_section, role):
                die(f"{path} Agent Roles section is missing required role reference: {role!r}")
    if skill in SKILLS_WITHOUT_REQUIRED_AGENT_DEPENDENCY:
        body = read_text(path)
        agent_roles_section = markdown_section(body, "## Agent Roles")
        if "no required agent dependency" not in agent_roles_section:
            die(f"{path} Agent Roles section should explicitly declare no required agent dependency")
    if skill in SIMPLICITY_SCOPE_SKILL_MARKERS:
        body = read_text(path)
        for marker in SIMPLICITY_SCOPE_SKILL_MARKERS[skill]:
            if marker not in body:
                die(f"{path} is missing required Simplicity-Scope marker: {marker!r}")
    if skill == "simplify":
        body = read_text(path)
        for marker in SIMPLIFY_PARALLEL_MARKERS:
            if not has_required_marker(body, marker):
                die(f"{path} is missing required Simplify-Parallel marker: {marker!r}")
        for forbidden in SIMPLIFY_FORBIDDEN_MARKERS:
            if has_required_marker(body, forbidden):
                die(f"{path} still contains retired small-diff-gate language: {forbidden!r}")
        for platform in sorted(SKILL_AVAILABILITY[skill]):
            wrapper_root = SKILL_ROOTS[platform]
            wrapper_path = root / wrapper_root / skill / "SKILL.md"
            wrapper_body = read_text(wrapper_path)
            for marker in SIMPLIFY_WRAPPER_MARKERS:
                if not has_required_marker(wrapper_body, marker):
                    die(f"{wrapper_path} is missing required Simplify-Wrapper marker: {marker!r}")
            for forbidden in SIMPLIFY_FORBIDDEN_MARKERS:
                if has_required_marker(wrapper_body, forbidden):
                    die(f"{wrapper_path} still contains retired small-diff-gate language: {forbidden!r}")
    if skill in PLATFORM_SUBAGENT_MARKERS:
        body = read_text(path)
        for marker in PLATFORM_SUBAGENT_MARKERS[skill]:
            if not has_required_marker(body, marker):
                die(f"{path} is missing required Platform-Subagent marker: {marker!r}")
    if skill == "ralplan":
        body = read_text(path)
        for marker in RALPLAN_CONSENSUS_MARKERS:
            if not has_required_marker(body, marker):
                die(f"{path} is missing required Ralplan-Consensus marker: {marker!r}")
        for marker in RALPLAN_FORBIDDEN_SPLIT_OPTION_MARKERS:
            if marker in body:
                die(f"{path} contains forbidden old Ralph split-option marker: {marker!r}")
    if skill in WORKTREE_SKILL_MARKERS:
        body = read_text(path)
        for marker in WORKTREE_SKILL_MARKERS[skill]:
            if marker not in body:
                die(f"{path} is missing required Worktree marker: {marker!r}")
    if skill == "fusion-rescue":
        body = read_text(path)
        for marker in FUSION_RESCUE_SKILL_MARKERS:
            if not has_required_marker(body, marker):
                die(f"{path} is missing required Fusion-Rescue marker: {marker!r}")
        assert_fusion_rescue_contract(path, body)
        assert_fusion_rescue_platform_contracts(root)


def assert_command(root: Path, skill: str) -> None:
    path = root / "commands" / f"{skill}.md"
    fm = parse_frontmatter(path)
    missing = REQUIRED_COMMAND_FIELDS - set(fm)
    if missing:
        die(f"{path} missing frontmatter fields: {sorted(missing)}")
    dmi = fm.get("disable-model-invocation")
    if skill in MODEL_UNINVOCABLE_SKILLS:
        if dmi != "true":
            die(
                f"{path} should set disable-model-invocation: true "
                f"({skill} must never be model-invocable)"
            )
    elif dmi != "false":
        die(f"{path} should set disable-model-invocation: false")

    skill_fm = parse_frontmatter(root / CLAUDE_SKILL_ROOT / skill / "SKILL.md")
    if fm["argument-hint"] != skill_fm.get("argument-hint"):
        die(
            f"{path} argument-hint should mirror {CLAUDE_SKILL_ROOT}/{skill}/SKILL.md. "
            f"expected={skill_fm.get('argument-hint')!r} actual={fm['argument-hint']!r}"
        )

    body = read_text(path)
    expected_marker = COMMAND_DELEGATION_MARKER.format(skill=skill)
    for marker in (expected_marker, "## User Input", "$ARGUMENTS"):
        if marker not in body:
            die(f"{path} is missing required command delegation marker: {marker!r}")


def assert_exact_claude_agent_inventory(root: Path) -> None:
    """Reject missing roles, extra wrappers, and retired companion reintroduction."""
    agents_root = root / "agents"
    if not agents_root.is_dir():
        die(f"missing Claude agent directory: {agents_root}")
    expected = {f"{agent}.md" for agent in AGENTS}
    actual = {path.name for path in agents_root.iterdir()}
    if actual != expected:
        die(
            f"{agents_root} exact-set mismatch: expected={sorted(expected)!r} "
            f"actual={sorted(actual)!r}"
        )


def assert_agent(root: Path, agent: str) -> None:
    path = root / "agents" / f"{agent}.md"
    fm = parse_frontmatter(path)
    missing = REQUIRED_AGENT_FIELDS - set(fm)
    if missing:
        die(f"{path} missing frontmatter fields: {sorted(missing)}")
    extra = set(fm) - REQUIRED_AGENT_FIELDS
    if extra:
        die(f"{path} contains unsupported Claude agent frontmatter fields: {sorted(extra)}")
    if fm["name"] != agent:
        die(f"{path} name={fm['name']!r}, expected {agent!r}")
    if fm["color"] not in CLAUDE_AGENT_COLORS:
        die(
            f"{path} color={fm['color']!r}, expected one of {sorted(CLAUDE_AGENT_COLORS)}"
        )

    expected_model = {
        "explore": "sonnet",
        "analyst": "opus",
        "executor": "opus",
    }.get(agent, "inherit")
    if fm.get("model") != expected_model:
        die(f"{path} model={fm.get('model')!r}, expected {expected_model!r}")

    body = read_text(path)
    agent_body = strip_frontmatter(body, path)
    assert_agent_core(root, agent, agent_body)
    description = fm["description"]
    if not description.startswith(CLAUDE_AGENT_DESCRIPTION_PREFIX):
        die(
            f"{path} description should start with "
            f"{CLAUDE_AGENT_DESCRIPTION_PREFIX!r} to encourage bounded Claude Code delegation"
        )
    if "caller owns approval and handoff gates" not in description:
        die(f"{path} description must preserve caller-owned approval and handoff gates")
    for marker in AGENT_SKILL_RELATIONSHIP_MARKERS:
        if marker not in body:
            die(f"{path} is missing required agent-skill boundary marker: {marker!r}")
    if agent in EXECUTION_MODE_AGENT_MARKERS:
        for marker in EXECUTION_MODE_AGENT_MARKERS[agent]:
            if marker not in body:
                die(f"{path} is missing required Execution-Mode agent marker: {marker!r}")
    if agent in SIMPLICITY_SCOPE_AGENT_MARKERS:
        for marker in SIMPLICITY_SCOPE_AGENT_MARKERS[agent]:
            if marker not in body:
                die(f"{path} is missing required Simplicity-Scope agent marker: {marker!r}")
    if agent in ACCEPTANCE_CRITERIA_AGENT_MARKERS:
        for marker in ACCEPTANCE_CRITERIA_AGENT_MARKERS[agent]:
            if marker not in body:
                die(f"{path} is missing required Acceptance Criteria agent marker: {marker!r}")
    if agent in VALIDATION_CHECK_AGENT_MARKERS:
        for marker in VALIDATION_CHECK_AGENT_MARKERS[agent]:
            if marker not in body:
                die(f"{path} is missing required Validation-Check agent marker: {marker!r}")
    if agent in SAFETY_REVIEW_AGENT_MARKERS:
        for marker in SAFETY_REVIEW_AGENT_MARKERS[agent]:
            if marker not in body:
                die(f"{path} is missing required Safety-Review agent marker: {marker!r}")
    if agent in REVIEW_SCOPE_DISCIPLINE_MARKERS:
        for marker in REVIEW_SCOPE_DISCIPLINE_MARKERS[agent]:
            if not has_required_marker(body, marker):
                die(f"{path} is missing required Review-Scope-Discipline marker: {marker!r}")
    if agent in APPROVED_DIRECTION_AGENT_MARKERS:
        for marker in APPROVED_DIRECTION_AGENT_MARKERS[agent]:
            if not has_required_marker(body, marker):
                die(f"{path} is missing required Approved-Direction agent marker: {marker!r}")
    if agent in WORKTREE_AGENT_MARKERS:
        for marker in WORKTREE_AGENT_MARKERS[agent]:
            if not has_required_marker(body, marker):
                die(f"{path} is missing required Worktree agent marker: {marker!r}")
    if agent in RALPLAN_AGENT_CONTRACT_MARKERS:
        for marker in RALPLAN_AGENT_CONTRACT_MARKERS[agent]:
            if not has_required_marker(body, marker):
                die(f"{path} is missing required Ralplan-Agent-Contract marker: {marker!r}")


def assert_agent_core(root: Path, agent: str, claude_agent_body: str) -> None:
    path = root / AGENT_CORE_ROOT / f"{agent}.md"
    body = read_text(path)
    if body.lstrip().startswith("---"):
        die(f"{path} must not contain Claude Code YAML frontmatter")
    expected_agent_body = (
        "<!-- Generated from docs/agent-core; do not edit by hand. -->\n"
        f"<!-- Source: plugins/oh-no-harness/docs/agent-core/{agent}.md -->\n"
        "<!-- Run: python3 scripts/generate-agent-wrappers.py --write -->\n\n"
        f"{body}"
    )
    if expected_agent_body.strip() != claude_agent_body.strip():
        die(f"agents/{agent}.md body must compose docs/agent-core/{agent}.md only")
    for marker in AGENT_SKILL_RELATIONSHIP_MARKERS:
        if marker not in body:
            die(f"{path} is missing required agent-core marker: {marker!r}")
    for pattern, reason in AGENT_CORE_FORBIDDEN_SURFACE_PATTERNS:
        if re.search(pattern, body):
            die(f"{path} contains wrong-surface platform detail: {reason}")


EXPECTED_CODEX_CUSTOM_AGENT_COUNT = 9

# Companion kernel/prompt-contract equivalence was intentionally removed with
# the transports. Exact Claude inventory rejects their reintroduction; surviving
# role envelopes remain covered by assert_agent/assert_orchestration_ownership_contract.


def assert_codex_custom_agent_count(root: Path) -> None:
    """Regression guard: the Codex host keeps exactly its nine native roles."""
    template_root = root / CODEX_AGENT_TEMPLATE_ROOT
    templates = sorted(template_root.glob("oh-no-*.toml"))
    if len(templates) != EXPECTED_CODEX_CUSTOM_AGENT_COUNT:
        die(
            f"expected {EXPECTED_CODEX_CUSTOM_AGENT_COUNT} Codex custom-agent "
            f"templates under {CODEX_AGENT_TEMPLATE_ROOT}, found {len(templates)}: "
            f"{[p.name for p in templates]}"
        )
    if len(AGENTS) != EXPECTED_CODEX_CUSTOM_AGENT_COUNT:
        die(
            f"expected {EXPECTED_CODEX_CUSTOM_AGENT_COUNT} shared native agents, "
            f"found {len(AGENTS)}: {AGENTS}"
        )
    if set(AGENTS) != set(CODEX_AGENT_MODEL_CONFIG):
        die(
            "Codex custom-agent model config must cover exactly the generated "
            f"roles: expected {sorted(AGENTS)}, found "
            f"{sorted(CODEX_AGENT_MODEL_CONFIG)}"
        )


def parse_codex_agent_template(path: Path, text: str) -> dict[str, str]:
    if tomllib is not None:
        try:
            data = tomllib.loads(text)
        except tomllib.TOMLDecodeError as exc:
            die(f"{path} is not valid TOML: {exc}")
        return data

    match = re.fullmatch(
        r'(?:#[^\n]*\n|\s*\n)*'
        r'name = "([^"\n]*)"\n'
        r'description = "([^"\n]*)"\n'
        r'model = "([^"\n]*)"\n'
        r'model_reasoning_effort = "([^"\n]*)"\n'
        r'(?:sandbox_mode = "([^"\n]*)"\n)?'
        r'developer_instructions = """\n'
        r'(.*)'
        r'"""\n?',
        text,
        re.DOTALL,
    )
    if not match:
        die(f"{path} is not valid strict Codex custom-agent template TOML")
    data = {
        "name": match.group(1),
        "description": match.group(2),
        "model": match.group(3),
        "model_reasoning_effort": match.group(4),
        "developer_instructions": match.group(6),
    }
    if match.group(5) is not None:
        data["sandbox_mode"] = match.group(5)
    return data


def assert_codex_agent_template(root: Path, agent: str) -> None:
    path = root / CODEX_AGENT_TEMPLATE_ROOT / f"oh-no-{agent}.toml"
    text = read_text(path)
    data = parse_codex_agent_template(path, text)
    for key in ("name", "description", "model", "model_reasoning_effort", "developer_instructions"):
        if key not in data:
            die(f"{path} is missing TOML field: {key}")
        if not isinstance(data[key], str):
            die(f"{path} TOML field {key} must be a string")
    allowed_keys = {
        "name",
        "description",
        "model",
        "model_reasoning_effort",
        "developer_instructions",
    }
    if agent in READ_ONLY_CODEX_AGENT_ROLES:
        allowed_keys.add("sandbox_mode")
    extra_keys = set(data) - allowed_keys
    if extra_keys:
        die(f"{path} contains unsupported Codex custom-agent TOML fields: {sorted(extra_keys)}")
    if data["name"] != f"oh-no-{agent}":
        die(f"{path} name={data['name']!r}, expected 'oh-no-{agent}'")
    if not data["description"].startswith(f"Oh No Harness {agent} role:"):
        die(f"{path} description must be a role-only Oh No Harness description")
    for forbidden in ("Use proactively", "approval gate", "handoff gate"):
        if forbidden in data["description"]:
            die(f"{path} description contains non-role metadata: {forbidden!r}")
    expected_model, expected_reasoning_effort = CODEX_AGENT_MODEL_CONFIG[agent]
    if data["model"] != expected_model:
        die(f"{path} model={data['model']!r}, expected {expected_model!r}")
    if data["model_reasoning_effort"] != expected_reasoning_effort:
        die(
            f"{path} model_reasoning_effort={data['model_reasoning_effort']!r}, "
            f"expected {expected_reasoning_effort!r}"
        )
    sandbox_mode = data.get("sandbox_mode")
    if agent in READ_ONLY_CODEX_AGENT_ROLES:
        if sandbox_mode != "read-only":
            die(f"{path} sandbox_mode={sandbox_mode!r}, expected 'read-only'")
    elif sandbox_mode is not None:
        die(f"{path} should not set sandbox_mode for non-read-only agent")
    agent_core = read_text(root / AGENT_CORE_ROOT / f"{agent}.md")
    expected_instructions = (
        f"Agent prompt source: docs/agent-core/{agent}.md\n"
        "Agent prompt content:\n\n"
        f"{agent_core}"
    )
    if data["developer_instructions"] != expected_instructions:
        die(f"{path} developer_instructions must compose docs/agent-core/{agent}.md only")
    for marker in (
        "oh-no-harness-generated-codex-agent",
        f'name = "oh-no-{agent}"',
        'description = "Oh No Harness',
        f'model = "{expected_model}"',
        f'model_reasoning_effort = "{expected_reasoning_effort}"',
        'developer_instructions = """',
        "Generated from docs/agent-core; do not edit by hand.",
        "python3 scripts/generate-agent-wrappers.py --write",
        f"Source: plugins/oh-no-harness/docs/agent-core/{agent}.md",
        f"Agent prompt source: docs/agent-core/{agent}.md",
        "## Skill Relationship",
        "## Responsibilities",
        "## Operating Rules",
        "## Output",
    ):
        if marker not in text:
            die(f"{path} is missing required Codex custom-agent marker: {marker!r}")
    if agent in READ_ONLY_CODEX_AGENT_ROLES and 'sandbox_mode = "read-only"' not in text:
        die(f"{path} is missing read-only sandbox marker")
    for forbidden in ("Agent prompt source: agents/", "\ntools:", "\nmodel:", "\ncolor:"):
        if forbidden in text:
            die(f"{path} contains Claude-only or stale agent marker: {forbidden!r}")


def assert_codex_agent_installer(root: Path) -> None:
    path = root / "scripts" / "install-codex-agents"
    text = read_text(path)
    for marker in (
        "#!/bin/sh",
        "oh-no-harness-generated-codex-agent",
        "oh-no-harness-installed-plugin-version",
        "manifest_path=",
        "plugin_version=",
        "render_agent()",
        'scope="user"',
        "--scope user|project",
        "Default: user.",
        "${CODEX_HOME:-}",
        "--dry-run",
        "--force",
        "--ensure",
        "--quiet",
        "--remove",
        "git rev-parse --show-toplevel",
        ".codex/agents",
        "skip unmarked",
        "skip non-regular",
        "template directory not found",
    ):
        if marker not in text:
            die(f"{path} is missing required Codex agent installer marker: {marker!r}")


def assert_expected_references(root: Path) -> None:
    relationships = read_text(root / "docs/reference/relationships.md")
    for skill in PUBLIC_SKILLS:
        if not has_token(relationships, skill):
            die(f"relationships.md does not mention skill `{skill}`")
    for agent in AGENTS:
        if not has_token(relationships, agent):
            die(f"relationships.md does not mention agent `{agent}`")
    for marker in (
        "docs/agent-core/<role>.md",
        "scripts/generate-skill-wrappers.py",
        "scripts/generate-agent-wrappers.py",
        "scripts/install-codex-agents",
        "docs/platforms/codex-agents/*.toml",
        "--scope user --ensure --quiet",
        "SessionStart is the sole automatic user-scope ensure point",
    ):
        if marker not in relationships:
            die(f"relationships.md does not mention required structure marker `{marker}`")


def _spawn_agent_keyword_arguments(text: str) -> list[dict[str, str]]:
    opening = {"(": ")", "[": "]", "{": "}", "<": ">"}
    calls: list[dict[str, str]] = []
    covered_until = 0
    for match in re.finditer(r"\bspawn_agent\s*\(", text):
        if match.start() < covered_until:
            continue
        stack, quote, escaped, end = [")"], None, False, None
        for index in range(match.end(), len(text)):
            character = text[index]
            if quote is not None:
                if escaped:
                    escaped = False
                elif character == "\\":
                    escaped = True
                elif character == quote:
                    quote = None
                continue
            if character in {'"', "'", "`"}:
                quote = character
            elif character in opening:
                stack.append(opening[character])
            elif character == stack[-1]:
                stack.pop()
                if not stack:
                    end = index
                    break
        if end is None:
            break
        covered_until = end + 1

        body = text[match.end():end]
        segments, stack = [], []
        quote, escaped, start = None, False, 0
        for index, character in enumerate(body):
            if quote is not None:
                if escaped:
                    escaped = False
                elif character == "\\":
                    escaped = True
                elif character == quote:
                    quote = None
                continue
            if character in {'"', "'", "`"}:
                quote = character
            elif character in opening:
                stack.append(opening[character])
            elif stack and character == stack[-1]:
                stack.pop()
            elif character == "," and not stack:
                segments.append(body[start:index])
                start = index + 1
        segments.append(body[start:])

        arguments: dict[str, str] = {}
        for segment in segments:
            keyword = re.match(r"\s*([A-Za-z_]\w*)\s*=(?!=)(.*)\Z", segment, re.DOTALL)
            if keyword:
                arguments[keyword.group(1)] = keyword.group(2).strip()
        calls.append(arguments)
    return calls


def assert_codex_task_name_contract(root: Path) -> None:
    platform_root = root / "docs" / "platforms"
    field_checks = {
        "task_name": lambda arguments: "task_name" in arguments,
        "agent_type": lambda arguments: bool(re.fullmatch(r'"oh-no-[^"]+"', arguments.get("agent_type", ""))),
        "message": lambda arguments: "message" in arguments,
        'fork_turns="none"': lambda arguments: arguments.get("fork_turns") == '"none"',
    }
    problems: list[str] = []

    def validate_task_names(
        filename: str,
        calls: list[dict[str, str]],
        target: list[str] = problems,
    ) -> None:
        concrete_names: list[str] = []
        for arguments in calls:
            raw_name = arguments.get("task_name")
            if raw_name is None:
                continue
            literal = re.fullmatch(r'(["\'])(.*)\1', raw_name, re.DOTALL)
            if not literal:
                target.append(f"codex-task-name-literal: {filename} task_name must be a quoted literal: {raw_name!r}")
                continue
            task_name = literal.group(2)
            concrete_names.append(task_name)
            if not re.fullmatch(r"[a-z0-9_]+", task_name):
                target.append(f"codex-task-name-grammar: {filename} has invalid task_name {task_name!r}")
            placeholders = sorted({part for part in task_name.split("_") if part in {"workflow", "role", "phase", "lens"}})
            if "<" in task_name or ">" in task_name or placeholders:
                target.append(f"codex-task-name-placeholder: {filename} task_name {task_name!r} contains placeholders")
            agent_type = re.fullmatch(r'"oh-no-([a-z0-9-]+)"', arguments.get("agent_type", ""))
            if "agent_type" in arguments and not task_name.rsplit("_", 1)[-1].isdigit():
                target.append(f"codex-task-name-ordinal: {filename} task_name {task_name!r} lacks a stable ordinal")
            if agent_type:
                role = agent_type.group(1).replace("-", "_")
                if not re.search(rf"(?:^|_){re.escape(role)}(?:_|$)", task_name):
                    target.append(f"codex-task-name-role: {filename} task_name {task_name!r} does not encode role {role!r}")
        duplicates = sorted({name for name in concrete_names if concrete_names.count(name) > 1})
        if duplicates:
            target.append(f"codex-task-name-duplicate: {filename} repeats sibling/example identities {duplicates!r}")

    placeholder_fixture = _spawn_agent_keyword_arguments(
        'spawn_agent(task_name="<deterministic_unique_identifier>", agent_type="oh-no-planner", '
        'message={"decoy": "spawn_agent(task_name=\'workflow_role_phase\')", "comparison": "a==b"}, '
        'fork_turns="none")'
    )
    fixture_problems: list[str] = []
    validate_task_names("angle-placeholder-fixture", placeholder_fixture, fixture_problems)
    if not all(any(marker in problem for problem in fixture_problems) for marker in (
        "codex-task-name-grammar", "codex-task-name-placeholder", "codex-task-name-ordinal", "codex-task-name-role"
    )):
        problems.append(f"codex-task-name-fixture: angle placeholder did not fail closed: {fixture_problems!r}")
    valid_fixture_problems: list[str] = []
    validate_task_names(
        "concrete-nested-decoy-fixture",
        _spawn_agent_keyword_arguments(
            'spawn_agent(task_name="ralplan_planner_draft_01", agent_type="oh-no-planner", '
            'message={"decoy": "spawn_agent(task_name=\'<workflow_role_phase>\')", "comparison": "a==b"}, '
            'fork_turns="none")'
        ),
        valid_fixture_problems,
    )
    if valid_fixture_problems:
        problems.append(f"codex-task-name-fixture: concrete nested/quoted/== fixture failed: {valid_fixture_problems!r}")

    expected_typed = set(CODEX_TYPED_SPAWN_SOURCES)
    actual_typed = {
        path.name
        for path in platform_root.glob("codex*.md")
        if path.name != CODEX_TASK_NAME_POLICY_OWNER
        and any(field_checks["agent_type"](arguments) for arguments in
                _spawn_agent_keyword_arguments(read_text(path)))
    }
    if actual_typed != expected_typed:
        problems.append(
            "codex-spawn-inventory: typed executable source inventory mismatch: "
            f"expected={sorted(expected_typed)!r} actual={sorted(actual_typed)!r}"
        )

    for filename in CODEX_TYPED_SPAWN_SOURCES:
        calls = [
            arguments for arguments in
            _spawn_agent_keyword_arguments(read_text(platform_root / filename))
            if field_checks["agent_type"](arguments)
        ]
        if any(all(check(arguments) for check in field_checks.values()) for arguments in calls):
            continue
        closest = max(
            calls or [{}],
            key=lambda arguments: sum(check(arguments) for check in field_checks.values()),
        )
        missing = [
            field for field, check in field_checks.items()
            if not check(closest)
        ]
        problems.append(
            f"codex-spawn-pair: {platform_root / filename} must keep task_name, "
            "agent_type, message, and fork_turns=\"none\" in one custom-role "
            f"spawn_agent call; closest call missing={missing!r}"
        )

    simplify_path = platform_root / "codex-simplify.md"
    simplify_calls = _spawn_agent_keyword_arguments(read_text(simplify_path))
    untyped_fields = ("task_name", "message", 'fork_turns="none"')
    if not any(
        all(field_checks[field](arguments) for field in untyped_fields)
        and not field_checks["agent_type"](arguments)
        for arguments in simplify_calls
    ):
        problems.append(
            f"codex-untyped-task-name: {simplify_path} must keep task_name, message, "
            "and fork_turns=\"none\" in one spawn_agent call while omitting agent_type"
        )

    owner_path = platform_root / CODEX_TASK_NAME_POLICY_OWNER
    owner_body = read_text(owner_path)
    if not any(
        all(field_checks[field](arguments) for field in ("task_name", "agent_type"))
        for arguments in _spawn_agent_keyword_arguments(owner_body)
    ):
        problems.append(
            f"codex-maintenance-pair: {owner_path} must show task_name + agent_type "
            "in one spawn_agent example"
        )
    missing_owner = [
        marker for marker in CODEX_TASK_NAME_POLICY_MARKERS
        if not has_required_marker(owner_body, marker)
    ]
    if missing_owner:
        problems.append(
            f"codex-task-name-owner: {owner_path} is missing canonical naming/role-proof "
            f"markers: {missing_owner!r}"
        )
    for filename in (*CODEX_TYPED_SPAWN_SOURCES, "codex-simplify.md", CODEX_TASK_NAME_POLICY_OWNER):
        validate_task_names(filename, _spawn_agent_keyword_arguments(read_text(platform_root / filename)))
    if problems:
        die("Codex V2 task_name contract failures:\n- " + "\n- ".join(problems))


def assert_execution_mode_contract(root: Path) -> None:
    # docs/shared/* retired 2026-07-17: the mode/subagent semantics live in the
    # self-contained skill cores, already pinned by their own marker sets.
    platform_root = root / "docs" / "platforms"
    for filename, markers in PLATFORM_RULE_DOC_MARKERS.items():
        doc = platform_root / filename
        doc_text = read_text(doc)
        for marker in markers:
            if not has_required_marker(doc_text, marker):
                die(f"{doc} is missing required Platform-Rules marker: {marker!r}")
    for filename, markers in PLATFORM_ADAPTER_DOC_MARKERS.items():
        doc = platform_root / filename
        doc_text = read_text(doc)
        for marker in markers:
            if not has_required_marker(doc_text, marker):
                die(f"{doc} is missing required Platform-Adapter marker: {marker!r}")
        for marker in PLATFORM_ADAPTER_FORBIDDEN_MARKERS[filename]:
            if marker in doc_text:
                die(f"{doc} contains forbidden cross-platform adapter marker: {marker!r}")


# assert_verification_tier_contract / assert_validation_check_contract were
# retired 2026-07-17 with docs/shared: tier and validation semantics are
# pinned inside ralph.md / verification-before-completion.md marker sets.


def assert_required_reading_contract(root: Path) -> None:
    """Layer 1 read-contract: any skill-core that references a docs/shared
    contract must declare every docs/shared/<name>.md it references in a
    `## Required Reading` section (S_ref subset of S_declared), each declared
    file must exist, and the strong-contract wording must be present. The
    in-scope set is DERIVED from the cores that actually reference docs/shared
    (not a hardcoded allowlist), so a future referencing core cannot silently
    escape. Scoped to the skill-core SOURCE body only. Accumulates all problems
    and dies once so a RED run names every offending skill-core."""
    shared_ref = re.compile(r"docs/shared/([a-z0-9-]+)\.md")
    classified_row = re.compile(
        r"\|\s*`docs/shared/([a-z0-9-]+)\.md`\s*\|\s*(always|triggered)\s*\|\s*([^|]+)\|"
    )
    problems: list[str] = []
    for skill in ALL_SKILLS:
        path = root / SKILL_CORE_ROOT / f"{skill}.md"
        body = read_text(path)
        referenced = set(shared_ref.findall(body))
        section = markdown_section(body, "## Required Reading")
        if skill in SELF_CONTAINED_ADAPTER_SKILLS:
            # Self-contained cores invert this contract: shared docs are
            # rationale-only, never a runtime prerequisite, so a Required
            # Reading section is forbidden and references stay non-normative.
            if section.strip():
                problems.append(
                    f"{path}: self-contained core must not declare a "
                    f"'## Required Reading' runtime dependency section"
                )
            continue
        if not referenced and not section.strip():
            continue  # no shared-doc dependency and no section -> nothing to enforce
        if not section.strip():
            problems.append(
                f"{path}: references "
                f"{sorted('docs/shared/%s.md' % n for n in referenced)} but has "
                f"no '## Required Reading' section"
            )
            continue
        if not has_required_marker(section, REQUIRED_READING_CONTRACT_MARKER):
            problems.append(
                f"{path}: '## Required Reading' is missing the strong-contract "
                f"marker {REQUIRED_READING_CONTRACT_MARKER!r}"
            )
        if not has_required_marker(section, REQUIRED_READING_BLOCKER_MARKER):
            problems.append(
                f"{path}: '## Required Reading' is missing the blocker clause "
                f"{REQUIRED_READING_BLOCKER_MARKER!r}"
            )
        declared = set(shared_ref.findall(section))
        undeclared = referenced - declared
        if undeclared:
            problems.append(
                f"{path}: '## Required Reading' must declare every docs/shared "
                f"doc the body references; undeclared: "
                f"{sorted(f'docs/shared/{name}.md' for name in undeclared)}"
            )
        for name in sorted(declared):
            shared_path = root / "docs" / "shared" / f"{name}.md"
            if not shared_path.exists():
                problems.append(
                    f"{path}: '## Required Reading' declares "
                    f"docs/shared/{name}.md which does not exist on disk"
                )
        if skill in TRIGGER_CLASS_REQUIRED_SKILLS:
            rows = {
                name: (classification, timing.strip())
                for name, classification, timing in classified_row.findall(section)
            }
            if set(rows) != declared:
                problems.append(
                    f"{path}: every Required Reading contract must have exactly "
                    f"one table row with class always|triggered; declared={sorted(declared)}, "
                    f"classified={sorted(rows)}"
                )
            always = {name for name, (classification, _) in rows.items() if classification == "always"}
            expected_always = EXPECTED_ALWAYS_READING[skill]
            if always != expected_always:
                problems.append(
                    f"{path}: always-read owners drifted; expected "
                    f"{sorted(expected_always)}, got {sorted(always)}"
                )
            for name, (classification, timing) in rows.items():
                timing_lower = timing.lower()
                if classification == "triggered" and not any(
                    token in timing_lower for token in ("before", "when", "only when")
                ):
                    problems.append(
                        f"{path}: triggered docs/shared/{name}.md lacks pre-gate trigger timing"
                    )
        if skill in ("ralplan", "ralph"):
            for forbidden in (
                "read every shared contract listed",
                "read every listed contract up front",
                "every shared contract listed in `## Required Reading` before working",
            ):
                if forbidden.lower() in body.lower():
                    problems.append(
                        f"{path}: still carries all-upfront Required Reading wording: {forbidden!r}"
                    )
    if problems:
        die(
            "Required Reading read-contract failed for "
            f"{len(set(p.split(':')[0] for p in problems))} skill-core file(s):\n  - "
            + "\n  - ".join(problems)
        )


def assert_independence_mode_gates(root: Path) -> None:
    """Layer 2: each review/verify-dispatching skill-core must HARD-GATE the
    recorded independence mode so an unlabelled single inline pass is a named
    ledger gap (mirrors ralplan's already-correct Findings Ledger Gate).
    The marker must appear INSIDE a `<HARD-GATE>...</HARD-GATE>` block, not in
    ordinary prose, so a future edit cannot demote the clause out of the gate
    while still passing this check. Accumulates problems and dies once."""
    gate_re = re.compile(r"<HARD-GATE>(.*?)</HARD-GATE>", re.DOTALL)
    problems: list[str] = []
    for skill in INDEPENDENCE_MODE_GATE_SKILLS:
        path = root / SKILL_CORE_ROOT / f"{skill}.md"
        body = read_text(path)
        gate_text = "\n".join(gate_re.findall(body))
        if not gate_text:
            problems.append(f"{path}: has no <HARD-GATE> block to carry the independence-mode clause")
            continue
        if not has_required_marker(gate_text, INDEPENDENCE_MODE_GATE_MARKER):
            problems.append(
                f"{path}: the independence-mode clause "
                f"{INDEPENDENCE_MODE_GATE_MARKER!r} must appear inside a "
                f"<HARD-GATE> block"
            )
    if problems:
        die(
            "Independence-mode HARD-GATE missing/misplaced in "
            f"{len(problems)} skill-core file(s):\n  - " + "\n  - ".join(problems)
        )


def assert_provider_guidance(root: Path) -> None:
    provider_root = root / PROVIDER_DOC_ROOT
    if not provider_root.is_dir():
        die(f"{provider_root} should exist for company-scoped provider guidance")

    expected = set(PROVIDER_DOC_MARKERS)
    actual = {path.name for path in provider_root.glob("*.md")}
    if actual != expected:
        die(
            f"{provider_root} should contain only company-scoped provider docs. "
            f"expected={sorted(expected)!r} actual={sorted(actual)!r}"
        )

    for filename, markers in PROVIDER_DOC_MARKERS.items():
        doc = provider_root / filename
        doc_text = read_text(doc)
        for marker in markers:
            if marker not in doc_text:
                die(f"{doc} is missing required Provider-Guidance marker: {marker!r}")


def assert_worktree_contract(marketplace_root: Path, root: Path) -> None:
    # docs/shared/worktree-isolation.md retired 2026-07-17; the decision table
    # lives in ralph.md, pinned by WORKTREE_SKILL_MARKERS.

    forbidden_scan_paths = list(root.rglob("*.md"))
    forbidden_scan_paths.extend(marketplace_root.glob("README*.md"))
    forbidden_scan_paths.extend((marketplace_root / "scripts").glob("test-*.sh"))
    for scan_path in forbidden_scan_paths:
        scan_text = read_text(scan_path)
        for marker in WORKTREE_FORBIDDEN_MARKERS:
            if marker in scan_text:
                die(f"{scan_path} contains forbidden old Worktree guidance: {marker!r}")


def assert_tdd_routing_contract(marketplace_root: Path, root: Path) -> None:
    description_paths = [
        root / SKILL_CORE_ROOT / "test-driven-development.md",
        root / CODEX_SKILL_ROOT / "test-driven-development" / "SKILL.md",
        root / CLAUDE_SKILL_ROOT / "test-driven-development" / "SKILL.md",
    ]
    command_path = root / "commands" / "test-driven-development.md"
    command_description = parse_frontmatter(command_path).get("description", "")
    for marker in TDD_COMMAND_DESCRIPTION_MARKERS:
        if marker not in command_description:
            die(f"{command_path} description is missing TDD command routing marker: {marker!r}")

    tdd_core_path = root / SKILL_CORE_ROOT / "test-driven-development.md"
    tdd_core = read_text(tdd_core_path)
    for marker in TDD_CORE_ROUTING_MARKERS:
        if marker not in tdd_core:
            die(f"{tdd_core_path} is missing TDD routing boundary marker: {marker!r}")

    for relative_path, markers in TDD_ROUTING_DOC_MARKERS.items():
        path = root / relative_path
        text = read_text(path)
        for marker in markers:
            if not has_required_marker(text, marker):
                die(f"{path} is missing TDD routing contract marker: {marker!r}")

    readme_markers = {
        "README.md": "ordinary implementation routes through Ralph",
        "README.ko.md": "일반 구현은 Ralph로 라우팅합니다",
    }
    for filename, marker in readme_markers.items():
        path = marketplace_root / filename
        if not path.exists():
            continue
        text = read_text(path)
        if "test-driven-development" in text and marker not in text:
            die(f"{path} is missing README TDD/Ralph routing marker: {marker!r}")

    for relative_path in ("scripts/test-codex-plugin.sh", "scripts/test-claude-plugin.sh"):
        path = marketplace_root / relative_path
        text = read_text(path)
        for marker in ("test-driven-development", "create-red-first", "direct_invariant_for_skill()"):
            if marker not in text:
                die(f"{path} is missing direct TDD invariant marker: {marker!r}")

    checked_paths = (
        description_paths
        + [
            command_path,
            root / SKILL_CORE_ROOT / "ralph.md",
            root / "docs" / "reference" / "relationships.md",
            root / "hooks" / "session-start",
            marketplace_root / "README.md",
            marketplace_root / "README.ko.md",
        ]
    )
    for path in checked_paths:
        if not path.exists():
            continue
        text = read_text(path)
        for marker in TDD_FORBIDDEN_DOC_MARKERS:
            if marker in text:
                die(f"{path} contains forbidden legacy TDD routing marker: {marker!r}")

    for relative_path, heading, marker in TDD_SCOPE_SECTION_MARKERS:
        path = root / relative_path
        section = markdown_section(read_text(path), heading)
        if not has_required_marker(section, marker):
            die(
                f"{path} section {heading!r} is missing proportional "
                f"TDD/Ralph marker: {marker!r}"
            )

    for relative_path, heading, marker in TDD_SCOPE_SECTION_FORBIDDEN_MARKERS:
        path = root / relative_path
        section = markdown_section(read_text(path), heading)
        if has_required_marker(section, marker):
            die(
                f"{path} section {heading!r} contains forbidden "
                f"scope-expanding marker: {marker!r}"
            )


def assert_hook_contract(root: Path) -> None:
    hooks_path = root / "hooks" / "hooks.json"
    try:
        hooks = json.loads(read_text(hooks_path))
    except json.JSONDecodeError as exc:
        die(f"{hooks_path} is not valid JSON: {exc}")

    events = hooks.get("hooks")
    if not isinstance(events, dict):
        die(f"{hooks_path} should define a hooks object")

    required_events = {"SessionStart"}
    actual_events = set(events)
    if actual_events != required_events:
        missing = required_events - actual_events
        extra = actual_events - required_events
        die(f"{hooks_path} has unexpected hook events: missing={sorted(missing)} extra={sorted(extra)}")

    session_start_path = root / "hooks" / "session-start"
    session_start_text = read_text(session_start_path)
    # Negative guard first: the retired absolute rule delegated every read-only
    # lookup, however small. It must not come back under the proportional
    # contract, and it would otherwise surface only as a missing-marker error.
    for forbidden in (
        "never performs exploration, investigation, analysis, or repository "
        "work-product mutation inline when a role subagent can do it",
        "never performs exploration, investigation, or analysis inline",
    ):
        if forbidden in session_start_text:
            die(
                f"{session_start_path} restores the retired absolute never-inline "
                f"read-only rule: {forbidden!r}"
            )
    for marker in (
        "OH_NO_RG_SEARCH_TOOLING",
        "command -v rg",
        "rg --files",
        "Use native skill loading",
        "No-route lane",
        "Direct-edit lane",
        "OH_NO_FORCED_ROUTING",
        "CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION",
        "CODEX_ONLY_OH_NO_READONLY_EXPLORATION_DELEGATION",
        "Custom-Agent Spawn Troubleshooting",
        "docs/platforms/codex.md",
        "before fallback",
        "sub-agents, delegation, and parallel agent work proactively",
        "every in-scope subagent result is a workflow dependency",
        "wait to final status, capture it, and use it",
        "explicit cancel, invalidation, duplicate/mis-scope, or safety stop",
        "MUST NOT redo delegated work inline",
        "redact credential values",
        "never allowed for no-skill read-only lookup",
        "you may dispatch the registered read-only oh-no-explore custom agent",
        "use it before the next action",
        "first select the relevant Oh No Harness skill",
        "spawned in-scope subagent results are workflow dependencies",
        "Codex custom-agent ensure warning",
        "--scope user --ensure --quiet",
        # The retired delegation block is replaced by an always-injected,
        # configuration-derived Claude model-diversity block.
        "DEFAULT_TOP_TIER_MODELS=\"fable opus\"",
        "DIVERSITY_PREF_SCHEMA_VERSION=2",
        "DIVERSITY_SECONDARY_TOP_MODEL=\"\"",
        "DIVERSITY_PLAN_REVIEWER_PRIMARY=\"host-default\"",
        "DIVERSITY_CODE_REVIEWER_PRIMARY=\"host-default\"",
        "DIVERSITY_DEBUGGER_PRIMARY=\"host-default\"",
        "DIVERSITY_FUSION_RESCUE_ANALYST_PRIMARY=\"host-default\"",
        "scripts/oh-no-config\" path",
        "subagent-models.conf",
        "<OH_NO_MODEL_DIVERSITY>",
        "top_tier_models=%s",
        "secondary_top_model=%s",
        "effective_primaries=plan-reviewer:%s code-reviewer:%s debugger:%s fusion-rescue-analyst:%s",
        "unoverridden dispatch uses the stored primary",
        "explicit NATIVE override with secondary_top_model",
        "strict mode pauses when no valid secondary",
        "</OH_NO_MODEL_DIVERSITY>",
        "model_diversity_block=\"$(model_diversity_policy)\"",
        # Configure-subagents best-effort reapply block (Claude-Code branch only).
        # Statically gate the SessionStart drift-repair wiring so it cannot
        # silently regress, and so it stays sanitized (a wrapped notice, never
        # credentials, keeping the SessionStart JSON valid). The exit status is
        # captured explicitly (no `|| true`); success and failure both emit a
        # FIXED credential-free notice, never the subprocess's raw output.
        "scripts/configure-subagents",
        "reapply --quiet",
        "OH_NO_SUBAGENT_CONFIG_NOTICE",
        "subagent_reapply_rc=$?",
        "could not reapply your saved subagent model configuration",
        # Model-fidelity rule (Claude-branch orchestration block only): every role
        # dispatch runs on its configured model, with a lane-general carve-out for
        # prescribed model-diversity legs and panels. Pinned verbatim because the
        # regressions here are polarity/scope flips that reuse the same tokens.
        "Model fidelity: every role dispatch",
        "carries no per-call model value",
        "the sole exception is a prescribed model-diversity leg or panel",
        "MUST carry the explicit NATIVE override",
        # 2026-07-30: ONE need test covers every non-review role, repository
        # work-product mutation included. Pinned verbatim because both extremes
        # regress by reusing the same tokens: an absolute never-inline rule
        # over-delegates a two-tool-call edit, and deleting the test licenses
        # unrecorded inline maker work.
        "One need test governs every non-review role, repository work-product mutation included",
        "dispatches a role subagent when sizeable, genuinely independent, or parallelizable",
        "a bounded lookup or edit finishable in a handful of tool calls may run inline",
        "with a recorded reason and, for an edit, a scoped diff check",
        "Use one subagent where one suffices, not several; keep spawn counts low",
        # Review independence is the ONE exemption. Kept as separate markers so
        # relaxing maker dispatch can never leak into collapsing a fired review
        # or audit trigger into the turn that produced the work.
        "Review independence is exempt from the need test",
        "always runs in a separate context, never inline",
        "never folded into the turn that produced the work",
        "Convenience, a small diff, or time pressure never collapses it",
    ):
        if marker not in session_start_text:
            die(f"{session_start_path} is missing required session-start marker: {marker!r}")

    diversity_function = re.search(
        r"model_diversity_policy\(\) \{(?P<body>.*?)\n\}",
        session_start_text,
        flags=re.DOTALL,
    )
    if not diversity_function:
        die(f"{session_start_path} is missing model_diversity_policy")
    diversity_body = diversity_function.group("body")
    if len([line for line in diversity_body.splitlines() if line.strip()]) > 35:
        die(f"{session_start_path} model-diversity block builder is no longer compact")
    for marker in (
        "DIVERSITY_TOP_TIER_MODELS=\"$DEFAULT_TOP_TIER_MODELS\"",
        "prefs_file=\"$(dirname \"$config_path\")/subagent-models.conf\"",
        "if load_model_diversity_prefs \"$prefs_file\"; then :; fi",
        "printf '<OH_NO_MODEL_DIVERSITY>\\n'",
        "printf '</OH_NO_MODEL_DIVERSITY>'",
    ):
        if marker not in diversity_body:
            die(f"{session_start_path} model-diversity block shape is missing: {marker!r}")
    if session_start_text.count("model_diversity_block=\"$(model_diversity_policy)\"") != 1:
        die(f"{session_start_path} must compute the diversity block exactly once")
    claude_branch = session_start_text[session_start_text.find('elif [ -n "${CLAUDE_PLUGIN_ROOT:-}"') :]
    if "${model_diversity_block}${subagent_config_notice}" not in claude_branch:
        die(f"{session_start_path} must inject the diversity block in the Claude SessionStart branch")

    for forbidden in (
        "OH_NO_SKILL_CORE",
        "OH_NO_CODEX_EXECUTOR_DELEGATION",
        "Below is the full content",
        "using_oh_no_core",
    ):
        if forbidden in session_start_text:
            die(f"{session_start_path} still embeds retired router core content: {forbidden!r}")


def assert_hook_test_contract(marketplace_root: Path) -> None:
    """Require deterministic hook/config tests and inert deferred Fusion parsers."""
    codex_path = marketplace_root / "scripts" / "test-codex-plugin.sh"
    codex_text = read_text(codex_path)
    for marker in (
        "OH_NO_CODEX_FUSION_RESCUE_LIVE_OK",
        "OH_NO_CLAUDE_FUSION_PANEL_OK",
        "def fusion_launcher_proof",
    ):
        if marker not in codex_text:
            die(f"{codex_path} is missing deferred Fusion marker: {marker!r}")

    claude_path = marketplace_root / "scripts" / "test-claude-plugin.sh"
    claude_text = read_text(claude_path)
    for marker in (
        "direct_invariant_for_skill()",
        "run_configure_subagents_offline_test()",
        "run_marketplace_isolation_offline_test()",
        "run_claude_state_isolation_offline_test()",
        "oh-no-claude-hook-cap",
    ):
        if marker not in claude_text:
            die(f"{claude_path} is missing retained deterministic test marker: {marker!r}")

    configure_test_path = marketplace_root / "scripts" / "test-configure-subagents.sh"
    configure_test = read_text(configure_test_path)
    for marker in (
        "OH_NO_CONFIG_DIR", "CLAUDE_PLUGIN_DATA", "CLAUDE_CONFIG_DIR",
        "XDG_CONFIG_HOME", "<OH_NO_MODEL_DIVERSITY>", "DEFAULT_TOP_TIER_MODELS",
        "secondary_top_model", "top_tier_models", "degenerate", "no preferences",
        "no secondary",
    ):
        if marker not in configure_test:
            die(f"{configure_test_path} is missing deterministic resolver/diversity fixture marker: {marker!r}")

def assert_public_docs_contract(marketplace_root: Path, root: Path) -> None:
    plugin_agents = read_text(root / "AGENTS.md")
    if "Do not reintroduce `team`, `ultrawork`" in plugin_agents:
        die(
            f"{root / 'AGENTS.md'} still forbids `ultrawork`; the public skill "
            "surface should treat ultrawork as the renamed former autopilot workflow"
        )
    if "`ultrawork` is the renamed former `autopilot`" not in plugin_agents:
        die(f"{root / 'AGENTS.md'} should clarify that ultrawork is the renamed former autopilot")

    readme_expectations = {
        "README.md": (
            "`ralph`, `ralph with parallel subagents`, or `ultrawork`",
            "compact `SessionStart` bootstrap is the only plugin hook",
            "no `UserPromptSubmit`, `PreToolUse`, or `PostToolUse` hook",
            ("narrow `UserPromptSubmit` Ralph adapter", "Ralph adapter hook"),
        ),
        "README.ko.md": (
            "`ralph`, `ralph with parallel subagents`, `ultrawork`",
            "`SessionStart` 부트스트랩이 유일한 플러그인 훅",
            "`UserPromptSubmit`, `PreToolUse`, `PostToolUse` 훅은 사용하지 않습니다",
            ("좁은 `UserPromptSubmit` Ralph adapter", "Ralph adapter 훅"),
        ),
    }
    for filename, (split_option, sole_hook_marker, absent_hook_marker, forbidden_hook_markers) in readme_expectations.items():
        path = marketplace_root / filename
        text = read_text(path)
        if split_option in text:
            die(f"{path} still presents legacy `ralph with parallel subagents` as a separate handoff option")
        if sole_hook_marker not in text or absent_hook_marker not in text:
            die(f"{path} should state that SessionStart is the only plugin hook and that prompt/tool hooks are absent")
        for forbidden_hook_marker in forbidden_hook_markers:
            if forbidden_hook_marker in text:
                die(f"{path} still claims a Ralph prompt adapter hook exists: {forbidden_hook_marker!r}")

    # B5: Claude users configure native model diversity; they are not instructed
    # to install a Codex companion plugin for paired reviews or Fusion Rescue.
    diversity_docs = {
        "README.md": ("model diversity",),
        "README.ko.md": ("model diversity", "모델 다양성"),
    }
    for filename, diversity_terms in diversity_docs.items():
        path = marketplace_root / filename
        text = read_text(path)
        claude_section = markdown_section(text, "### Claude Code")
        for forbidden in (
            "openai/codex-plugin-cc",
            "claude plugin install codex@openai-codex",
            "cross-host review pairs and Fusion Rescue's Codex panel lens",
            "cross-host review 쌍과 Fusion Rescue의 Codex 패널 렌즈",
        ):
            if forbidden.lower() in claude_section.lower():
                die(f"{path} still tells Claude users to install/use the Codex companion for review pairs or Fusion Rescue")
        lowered = claude_section.lower()
        if not any(term.lower() in lowered for term in diversity_terms):
            die(f"{path} Claude Code section must mention the model-diversity mechanism")
        for marker in ("configure-subagents", "same-model", "require-model-diversity"):
            if marker not in lowered:
                die(f"{path} Claude Code diversity guidance is missing {marker!r}")

    contributing_path = root / "CONTRIBUTING.md"
    contributing = read_text(contributing_path)
    if "Fusion Rescue cross-host live validation" in contributing:
        die(f"{contributing_path} must not describe Claude Fusion Rescue validation as cross-host")

    design_spec_path = root / "docs/specs/2026-05-11-oh-no-harness-design.md"
    design_spec = read_text(design_spec_path)
    for heading in ("## Non-Goals", "## Migration Rules From OMC"):
        section = f"\n{markdown_section(design_spec, heading)}\n"
        if "\n- `ultrawork`\n" in section:
            die(
                f"{design_spec_path} still treats public `ultrawork` as removed "
                f"inside {heading}; it should remove only legacy OMC ultrawork behavior"
            )
    if "legacy OMC `ultrawork` behavior/state machinery" not in design_spec:
        die(f"{design_spec_path} should distinguish public ultrawork from legacy OMC behavior")


def assert_claude_manifest_skills(root: Path) -> None:
    path = root / ".claude-plugin/plugin.json"
    try:
        manifest = json.loads(read_text(path))
    except json.JSONDecodeError as exc:
        die(f"{path} is not valid JSON: {exc}")

    expected = [f"./{CLAUDE_SKILL_ROOT}/{skill}/" for skill in PUBLIC_SKILLS]
    actual = manifest.get("skills")
    if actual != expected:
        die(
            f"{path} skills array should list public skill directories in order. "
            f"expected={expected!r} actual={actual!r}"
        )
    if manifest.get("commands") != "./commands/":
        die(f"{path} should declare commands='./commands/' for Claude slash-command wrappers")


def assert_claude_marketplace(root: Path) -> None:
    path = root / ".claude-plugin/marketplace.json"
    try:
        manifest = json.loads(read_text(path))
    except json.JSONDecodeError as exc:
        die(f"{path} is not valid JSON: {exc}")

    plugins = manifest.get("plugins")
    if not isinstance(plugins, list):
        die(f"{path} should define a plugins array")

    matches = [plugin for plugin in plugins if plugin.get("name") == PLUGIN_NAME]
    if len(matches) != 1:
        die(f"{path} should define exactly one {PLUGIN_NAME} plugin entry")

    source = matches[0].get("source")
    if source != MARKETPLACE_PLUGIN_PATH:
        die(
            f"{path} {PLUGIN_NAME} source should point to "
            f"{MARKETPLACE_PLUGIN_PATH!r}, actual={source!r}"
        )


def assert_codex_marketplace(root: Path) -> None:
    path = root / ".agents/plugins/marketplace.json"
    try:
        manifest = json.loads(read_text(path))
    except json.JSONDecodeError as exc:
        die(f"{path} is not valid JSON: {exc}")

    plugins = manifest.get("plugins")
    if not isinstance(plugins, list):
        die(f"{path} should define a plugins array")

    matches = [plugin for plugin in plugins if plugin.get("name") == PLUGIN_NAME]
    if len(matches) != 1:
        die(f"{path} should define exactly one {PLUGIN_NAME} plugin entry")

    entry = matches[0]
    source = entry.get("source")
    if source != {"source": "local", "path": MARKETPLACE_PLUGIN_PATH}:
        die(
            f"{path} {PLUGIN_NAME} source should point to "
            f"{MARKETPLACE_PLUGIN_PATH!r}, actual={source!r}"
        )
    if entry.get("policy", {}).get("installation") != "AVAILABLE":
        die(f"{path} {PLUGIN_NAME} should be installable with policy.installation=AVAILABLE")
    if entry.get("policy", {}).get("authentication") != "ON_INSTALL":
        die(f"{path} {PLUGIN_NAME} should use policy.authentication=ON_INSTALL")


def assert_codex_manifest(root: Path) -> None:
    path = root / ".codex-plugin/plugin.json"
    try:
        manifest = json.loads(read_text(path))
    except json.JSONDecodeError as exc:
        die(f"{path} is not valid JSON: {exc}")

    if manifest.get("skills") != f"./{CODEX_SKILL_ROOT}/":
        die(f"{path} should declare skills='./{CODEX_SKILL_ROOT}/'")
    if manifest.get("hooks") != "./hooks/hooks.json":
        die(f"{path} should declare hooks='./hooks/hooks.json' for Codex plugin hooks")


def has_token(text: str, token: str) -> bool:
    return re.search(rf"(^|[^A-Za-z0-9_-]){re.escape(token)}([^A-Za-z0-9_-]|$)", text) is not None


def assert_no_omc_runtime_coupling(root: Path) -> None:
    forbidden = [
        r"\bTask\(",
        r"\bSkill\(",
    ]
    checked_paths = (
        list((root / CODEX_SKILL_ROOT).glob("**/*.md"))
        + list((root / CLAUDE_SKILL_ROOT).glob("**/*.md"))
        + list((root / SKILL_CORE_ROOT).glob("*.md"))
        + list((root / "agents").glob("*.md"))
        + list((root / "commands").glob("*.md"))
    )
    for path in checked_paths:
        text = read_text(path)
        for pattern in forbidden:
            if re.search(pattern, text, flags=re.IGNORECASE):
                die(f"{path} contains forbidden OMC-style runtime coupling pattern: {pattern}")


def assert_no_deprecated_artifact_paths(root: Path) -> None:
    checked_paths = (
        list((root / CODEX_SKILL_ROOT).glob("**/*.md"))
        + list((root / CLAUDE_SKILL_ROOT).glob("**/*.md"))
        + list((root / SKILL_CORE_ROOT).glob("*.md"))
        + list((root / "agents").glob("*.md"))
        + list((root / "commands").glob("*.md"))
        + [
            root / "README.md",
            root / "AGENTS.md",
            root / "docs/reference/migration-from-omc.md",
            root / "docs/reference/relationships.md",
        ]
    )
    for path in checked_paths:
        text = read_text(path)
        if "docs/oh-no" in text:
            die(f"{path} contains deprecated artifact path `docs/oh-no`; use `.oh-no/specs`, `.oh-no/plans`, or `.oh-no/sessions`")


def shell_assignment(text: str, name: str, path: Path) -> str:
    match = re.search(rf'(?m)^{re.escape(name)}="([^"]*)"$', text)
    if not match:
        die(f"{path} is missing shell assignment {name}")
    return match.group(1)


def assert_config_resolver_contract(root: Path) -> None:
    """Pin the one canonical preference/config directory resolution order."""
    config_path = root / "scripts" / "oh-no-config"
    config_text = read_text(config_path)
    function = re.search(r"config_dir\(\) \{(?P<body>.*?)\n\}", config_text, flags=re.DOTALL)
    if not function:
        die(f"{config_path} is missing config_dir()")
    body = function.group("body")
    ordered = (
        'OH_NO_CONFIG_DIR',
        'CLAUDE_CONFIG_DIR',
        '${HOME}/.claude/plugins/data',
        '*oh-no-harness*',
        'XDG_CONFIG_HOME',
        '${HOME}/.config/oh-no-harness',
    )
    positions = [body.find(marker) for marker in ordered]
    if any(position < 0 for position in positions) or positions != sorted(positions):
        die(f"{config_path} config_dir() resolution order drifted: {list(zip(ordered, positions))!r}")
    if "Deliberately do NOT\n  # honor CLAUDE_PLUGIN_DATA" not in config_text:
        die(f"{config_path} must document explicit CLAUDE_PLUGIN_DATA rejection")
    if "${CLAUDE_PLUGIN_DATA" in config_text or "$CLAUDE_PLUGIN_DATA" in config_text:
        die(f"{config_path} must not consult CLAUDE_PLUGIN_DATA")

    configurator_path = root / "scripts" / "configure-subagents"
    configurator = read_text(configurator_path)
    for marker in (
        'OH_NO_CONFIG="${SCRIPT_DIR}/oh-no-config"',
        'path="$("$OH_NO_CONFIG" path 2>/dev/null)"',
        'dirname "$path"',
    ):
        if marker not in configurator:
            die(f"{configurator_path} must delegate config resolution through oh-no-config path: {marker!r}")

    hook_path = root / "hooks" / "session-start"
    hook = read_text(hook_path)
    hook_invocation = 'config_path="$("${OH_NO_PLUGIN_ROOT}/scripts/oh-no-config" path 2>/dev/null)"'
    if hook_invocation not in hook or 'prefs_file="$(dirname "$config_path")/subagent-models.conf"' not in hook:
        die(f"{hook_path} must resolve diversity preferences through oh-no-config path")
    for duplicated_resolver_marker in ("CLAUDE_CONFIG_DIR", "XDG_CONFIG_HOME", ".claude/plugins/data"):
        if duplicated_resolver_marker in hook:
            die(f"{hook_path} must not duplicate the config directory resolver: {duplicated_resolver_marker!r}")


def assert_configure_subagents_contract(root: Path) -> None:
    # Reachability gates the human-facing skill; this contract gates the runtime
    # transaction, exact role inventory, schema split, and diversity preferences.
    script = root / "scripts" / "configure-subagents"
    if not script.exists():
        die(f"{script} is missing; configure-subagents needs its runtime configurator")
    if not (script.stat().st_mode & 0o111):
        die(f"{script} must be executable")
    script_text = read_text(script)

    roles_match = re.search(r"ROLES=\((?P<body>.*?)\n\)", script_text, flags=re.DOTALL)
    if not roles_match:
        die(f"{script} is missing the canonical ROLES array")
    roles = roles_match.group("body").split()
    if roles != AGENTS:
        die(f"{script} ROLES must exactly match AGENTS order: expected={AGENTS!r} actual={roles!r}")

    for token in (
        "fable", "opus", "sonnet", "haiku",
        "gpt-5.6-sol", "gpt-5.6-terra",
        "max", "xhigh", "high", "medium",
        "secondary_top_model", "top_tier_models",
        "PREF_SCHEMA_VERSION=2", "JOURNAL_SCHEMA_VERSION=1",
        'in_list "$secondary" "$NATIVE_MODELS"',
        'in_list "$secondary" "$resolved_top_tier"',
    ):
        if token not in script_text:
            die(f"{script} is missing required configure-subagents contract token {token!r}")
    if "codex-agents" in script_text:
        die(f"{script} must not reference the Codex custom-agent TOML directory")

    hook_path = root / "hooks" / "session-start"
    hook_text = read_text(hook_path)
    wizard_default = shell_assignment(script_text, "DEFAULT_TOP_TIER_MODELS", script)
    hook_default = shell_assignment(hook_text, "DEFAULT_TOP_TIER_MODELS", hook_path)
    if wizard_default != hook_default:
        die(
            "DEFAULT_TOP_TIER_MODELS drifted between configure-subagents and "
            f"SessionStart: wizard={wizard_default!r} hook={hook_default!r}"
        )

    core_path = root / SKILL_CORE_ROOT / "configure-subagents.md"
    core_text = read_text(core_path)
    proxy_at = core_text.find("CLIProxyAPI")
    agents_at = core_text.find("Configure these 9 agents one at a time")
    if proxy_at == -1 or agents_at == -1 or proxy_at > agents_at:
        die(f"{core_path} must ask the CLIProxyAPI question before per-agent selection")
    for marker in (
        "top_tier_models",
        "secondary_top_model",
        "offer only the native aliases",
        "never GPT",
        "all 9 agents and the\n   diversity settings change in one all-or-nothing transaction",
        "No file is written before\n   that confirmation",
    ):
        if not has_required_marker(core_text, marker):
            die(f"{core_path} is missing diversity/configuration marker: {marker!r}")

    assert_config_resolver_contract(root)


def read_json_object(path: Path) -> dict[str, object]:
    try:
        value = json.loads(read_text(path), object_pairs_hook=dict)
    except json.JSONDecodeError as exc:
        die(f"{path} is not valid JSON: {exc}")
    if not isinstance(value, dict):
        die(f"{path} must contain a JSON object")
    return value


def assert_exact_opencode_skill_inventory(root: Path) -> None:
    skills_root = root / OPENCODE_SKILL_ROOT
    if not skills_root.is_dir():
        die(f"missing OpenCode skill directory: {skills_root}")
    expected = set(OPENCODE_SKILLS)
    actual = {path.name for path in skills_root.iterdir()}
    if actual != expected:
        die(
            f"{skills_root} exact-set mismatch: expected={sorted(expected)!r} "
            f"actual={sorted(actual)!r}"
        )
    for skill in OPENCODE_SKILLS:
        wrapper = skills_root / skill / "SKILL.md"
        if not wrapper.is_file():
            die(f"missing OpenCode skill wrapper: {wrapper}")


def assert_opencode_main_prompt_contract(root: Path) -> None:
    path = root / "docs" / "platforms" / "opencode-main-agent.md"
    text = read_text(path)
    normalized_prompt = re.sub(r"\s+", " ", text).strip()

    def require_clauses(
        heading: str, required_clauses: dict[str, tuple[str, ...]]
    ) -> str:
        section = markdown_section(text, heading)
        if not section:
            die(f"{path} is missing OpenCode primary-prompt section: {heading}")
        normalized_section = re.sub(r"\s+", " ", section).strip()
        for concept, clauses in required_clauses.items():
            if not all(clause in normalized_section for clause in clauses):
                die(f"{path} is missing OpenCode {heading} concept: {concept}")
        return section

    require_clauses("## Bootstrap Boundaries", {
        "skill use, object of analysis, and deliverable boundary": (
            "Use OpenCode's native `skill` tool to load the relevant Oh No Harness skill when it applies.",
            "A workflow name used only as the subject of analysis, explanation, comparison, or critique is not an invocation trigger; route from the requested deliverable.",
        ),
        "complete no-route lane": (
            "No-route lane: answer directly when the request neither creates nor changes repository work products nor claims their completion.",
            "This includes research, conceptual or codebase questions, status reports, and version-control or environment housekeeping over already-written changes.",
        ),
        "no-route investigation": (
            "No-route means no workflow transition, not no investigation.",
        ),
        "tool inspection before repository facts": (
            "Before any repository-specific factual claim, inspect relevant source-of-truth evidence with tools, even when no file is named.",
        ),
        "named-file and unread-code discipline": (
            "Read every relevant named file before answering and do not speculate about unread code.",
        ),
        "non-evidence lookup aids": (
            "Injected summaries, memory, naming, and internal knowledge may guide lookup but are not repository evidence.",
        ),
        "active runtime distinction": (
            "Claims about active behavior require inspecting loaded runtime or configuration separately from checkout source; when that evidence cannot be inspected, label the claim unverified rather than assert it.",
        ),
        "observed evidence and citations": (
            "Ground material repository claims in observed tool output; include relevant paths or lines when useful.",
        ),
        "proportional investigation routing": (
            "Use direct read/search for a bounded question with a known location; route an uncertain, cross-file, or sizeable investigation to `oh-no-explore`.",
        ),
        "bounded evidence stop": (
            "Stop when enough directly relevant evidence supports the answer or no next lookup is likely to materially change it; report remaining uncertainty.",
        ),
        "direct-edit boundary": (
            "Direct-edit lane: use a direct edit plus scoped diff check only when all are true: one obvious file; private, inert, non-consumed, non-operational prose, comment, or formatting; not generated, or its generation source is edited and regenerated and validated in the same action; no public contract, security, or permission surface.",
            "If any condition fails or becomes false, load `ralph`.",
        ),
        "caller-owned workflow state": (
            "The main agent owns conversation flow, `.oh-no` state, gates, synthesis, and workflow transitions.",
            "STANDARD and THOROUGH repository work-product mutations use `oh-no-executor`; inline mutation is limited to a recorded LIGHT-tiny or confirmed dispatch-unavailable fallback.",
        ),
    })
    require_clauses("## Child Packet Floor", {
        "self-contained child packets": (
            "Every role packet is proportional, self-contained English and states:",
            "purpose and desired outcome; exact `oh-no-<role>` target",
            "exact target and revision plus result/revision binding",
            "scope, permissions, ownership, and non-goals",
            "contract and acceptance criteria",
            "required evidence, output envelope, and return owner",
            "stop and escalation conditions",
        ),
        "initial independent-context withholding": (
            "Initial independent review, verification, and debugging packets withhold maker conclusions, expected verdicts, sibling output, preferred causes, and confidence rankings.",
            "Disclose prior work later only as neutral exact actions, state, and raw outcomes for audit or clarification.",
        ),
    })
    require_clauses("## Orchestration", {
        "non-review need test": (
            "One need test governs every non-review role: dispatch with `task` when the work is sizeable, genuinely independent, or parallelizable; a bounded lookup or edit finishable in a handful of tool calls may run inline with a recorded reason and, for an edit, a scoped diff check. Use one role where one suffices.",
        ),
        "mandatory separate review contexts": (
            "Review independence is exempt from the need test. A fired trigger for `oh-no-code-reviewer`, `oh-no-plan-reviewer`, `oh-no-verifier`, or a `oh-no-fusion-rescue-analyst` panel always uses a separate `task` context.",
            "A small diff, convenience, or time pressure never makes it inline.",
        ),
        "workflow-internal roles and unmatched defaults": (
            "Planner, Plan-Reviewer, and Fusion Rescue panels remain workflow-internal.",
            "Outside a selected workflow, default unmatched read-only work to `oh-no-explore` and mutation to `oh-no-executor`.",
        ),
    })
    for clause, concept in (
        ("Role map:", "static role catalog"),
    ):
        if clause.lower() in normalized_prompt.lower():
            die(f"{path} retains forbidden OpenCode prompt content: {concept}")

    require_clauses("## Planning Boundary", {
        "no extra host planning pass": (
            "Do not switch to OpenCode's primary `plan` agent or add a separate host planning pass around Ralph-eligible execution unless the user explicitly requests that host mode.",
            "No-route housekeeping remains direct.",
        ),
    })
    for clause, concept in (
        ("concrete execution contract goes to `ralph`", "concrete-work positive mapping"),
        ("vague work goes to `interview`", "vague-work positive mapping"),
        ("broad or strategy-unclear work with known requirements goes to `ralplan`", "broad-work positive mapping"),
    ):
        if clause.lower() in normalized_prompt.lower():
            die(f"{path} retains forbidden OpenCode prompt content: {concept}")

    require_clauses("## Models And Concurrency", {
        "configured and inherited model behavior": (
            "A configured role uses its stored provider/model ID; an unconfigured role inherits the current primary model.",
            "Never claim model diversity without distinct runtime-proven model identities.",
        ),
        "bounded concurrent result consumption": (
            "Run at most five subagents concurrently.",
            "Use foreground completion as the normal wait, and consume every result.",
        ),
        "background completion and no duplicate work": (
            "If background mode is available, rely on its completion notification; never poll, duplicate a slow task, or redo delegated work inline.",
            "Dependent roles remain sequential.",
        ),
    })
    for clause, concept in (
        ("Each `task` dispatch uses exact `subagent_type: oh-no-<role>` and carries no per-call model value.", "task schema mechanics"),
        ("Issue independent `task` calls in one assistant turn", "same-turn independent task instruction"),
    ):
        if clause.lower() in normalized_prompt.lower():
            die(f"{path} retains forbidden OpenCode prompt content: {concept}")

    require_clauses("## Models And Concurrency", {
        "approval-gated skill chaining": (
            "When the active skill presents a Next Skill Handoff, use `question`, wait for approval, then load the selected skill with `skill`; otherwise stop at the current skill's outcome.",
        ),
    })


def assert_opencode_generated_agents(root: Path) -> None:
    path = root / OPENCODE_AGENT_ROOT / "agents.json"
    agents = read_json_object(path)
    expected_names = ["oh-no", *(f"oh-no-{role}" for role in AGENTS)]
    if list(agents) != expected_names:
        die(
            f"{path} agent inventory/order mismatch: expected={expected_names!r} "
            f"actual={list(agents)!r}"
        )

    main = agents["oh-no"]
    if not isinstance(main, dict):
        die(f"{path} oh-no primary must be an object")
    for forbidden_field in ("tools", "model"):
        if forbidden_field in main:
            die(f"{path} oh-no must not define {forbidden_field!r}")
    if set(main) != {
        "description", "mode", "prompt", "permission"
    }:
        die(f"{path} oh-no primary must use description/mode/prompt/permission only")
    if main.get("mode") != "primary":
        die(f"{path} oh-no must be the one primary agent")
    assert_opencode_main_prompt_contract(root)
    main_source = read_text(root / "docs" / "platforms" / "opencode-main-agent.md")
    if main.get("prompt") != main_source:
        die(f"{path} oh-no prompt must exactly equal docs/platforms/opencode-main-agent.md")
    expected_main_permission = {
        "question": "allow",
        "task": {
            "*": "deny",
            **{f"oh-no-{role}": "allow" for role in AGENTS},
        },
        OPENCODE_MODEL_CATALOG_TOOL: "ask",
        OPENCODE_CONFIGURE_TOOL: "ask",
    }
    if main.get("permission") != expected_main_permission:
        die(
            f"{path} oh-no permission must allow questions, preserve bounded task "
            "topology, and ask before the custom configurator tool"
        )
    main_permission = main["permission"]
    if not isinstance(main_permission, dict) or not isinstance(
        main_permission.get("task"), dict
    ):
        die(f"{path} oh-no task permission must be an ordered object")
    expected_task_order = ["*", *(f"oh-no-{role}" for role in AGENTS)]
    if list(main_permission["task"]) != expected_task_order:
        die(f"{path} oh-no task permission must order deny-all before exact role allows")

    bounded_task = {
        "*": "deny",
        "oh-no-explore": "allow",
        "oh-no-analyst": "allow",
    }
    for role in AGENTS:
        name = f"oh-no-{role}"
        agent = agents[name]
        if not isinstance(agent, dict):
            die(f"{path} {name} must be an object")
        if "tools" in agent:
            die(f"{path} {name} must use permission, not tools")
        if "model" in agent:
            die(f"{path} {name} must not define a default model")
        if set(agent) != {
            "description", "mode", "prompt", "permission"
        }:
            die(f"{path} {name} must use description/mode/prompt/permission only")
        if agent.get("mode") != "subagent":
            die(f"{path} {name} must use mode='subagent'")
        expected_prompt = read_text(root / AGENT_CORE_ROOT / f"{role}.md")
        if agent.get("prompt") != expected_prompt:
            die(f"{path} {name} prompt must exactly equal {AGENT_CORE_ROOT}/{role}.md")

        expected_permission: dict[str, object] = {}
        if role not in {"planner", "executor"}:
            expected_permission["edit"] = "deny"
        expected_permission["task"] = (
            bounded_task if role in {"debugger", "verifier"} else "deny"
        )
        if role in {
            "analyst",
            "planner",
            "plan-reviewer",
            "code-reviewer",
            "fusion-rescue-analyst",
        }:
            expected_permission["bash"] = "deny"
        expected_permission[OPENCODE_MODEL_CATALOG_TOOL] = "deny"
        expected_permission[OPENCODE_CONFIGURE_TOOL] = "deny"
        if agent.get("permission") != expected_permission:
            die(
                f"{path} {name} permission mismatch: "
                f"expected={expected_permission!r} actual={agent.get('permission')!r}"
            )
        if role in {"debugger", "verifier"}:
            task_permission = agent["permission"]["task"]
            if list(task_permission) != ["*", "oh-no-explore", "oh-no-analyst"]:
                die(
                    f"{path} {name} task permission must order deny-all before "
                    "the two bounded role allows"
                )

    primary_count = sum(
        isinstance(agent, dict) and agent.get("mode") == "primary"
        for agent in agents.values()
    )
    if primary_count != 1:
        die(f"{path} must contain exactly one primary agent; actual={primary_count}")


def assert_opencode_generated_commands(root: Path) -> None:
    path = root / OPENCODE_AGENT_ROOT / "commands.json"
    commands = read_json_object(path)
    if list(commands) != OPENCODE_SKILLS:
        die(
            f"{path} command inventory/order mismatch: expected={OPENCODE_SKILLS!r} "
            f"actual={list(commands)!r}"
        )
    for skill in OPENCODE_SKILLS:
        command = commands[skill]
        if not isinstance(command, dict) or set(command) != {
            "description", "agent", "template"
        }:
            die(f"{path} {skill} must use description/agent/template only")
        expected_template = (
            f"Load the `{skill}` skill and follow it exactly. Preserve and pass "
            "through the user's raw arguments unchanged:\n\n$ARGUMENTS"
        )
        if skill == "configure-subagents":
            expected_template = (
                "Load the `configure-subagents` skill and follow it exactly. This "
                "command is interactive only; never treat arguments as confirmation "
                "or as a bypass of its apply gate. Preserve and pass through the "
                "user's raw arguments unchanged:\n\n$ARGUMENTS"
            )
        expected = {
            "description": f"Run the Oh No Harness {skill} skill.",
            "agent": "oh-no",
            "template": expected_template,
        }
        if command != expected:
            die(f"{path} {skill} command contract mismatch")
    configure_template = commands["configure-subagents"]["template"]
    if "never treat arguments as confirmation or as a bypass of its apply gate" not in configure_template:
        die(f"{path} configure-subagents command exposes an apply bypass")


def assert_opencode_runtime_contract(root: Path) -> None:
    package_path = root / "package.json"
    package = read_json_object(package_path)
    manifest_versions = {
        read_json_object(root / rel).get("version")
        for rel in (".claude-plugin/plugin.json", ".codex-plugin/plugin.json")
    }
    if len(manifest_versions) != 1 or package.get("version") not in manifest_versions:
        die(f"{package_path} version must match both marketplace manifests")
    expected_package = {
        "name": "oh-no-harness",
        "version": package["version"],
        "description": (
            "Markdown-first coding workflow harness for OpenCode with 10 workflow "
            "skills and 9 role agents."
        ),
        "type": "module",
        "main": "./opencode/index.js",
        "exports": "./opencode/index.js",
        "bin": {"oh-no-harness": "./opencode/setup.js"},
        "files": [
            "opencode/",
            "skills-opencode/",
            "LICENSE",
            "NOTICE.md",
            "README.ko.md",
            "README.md",
        ],
        "repository": {
            "type": "git",
            "url": "git+https://github.com/jcwleo/oh-no-harness.git",
            "directory": "plugins/oh-no-harness",
        },
        "homepage": "https://github.com/jcwleo/oh-no-harness#readme",
        "bugs": {"url": "https://github.com/jcwleo/oh-no-harness/issues"},
        "license": "MIT",
        "keywords": [
            "opencode",
            "plugin",
            "skills",
            "planning",
            "tdd",
            "debugging",
            "verification",
            "coding-workflow",
        ],
        "dependencies": {"jsonc-parser": "3.3.1"},
        "publishConfig": {"access": "public"},
    }
    if package != expected_package:
        die(f"{package_path} does not match the public OpenCode package contract")

    opencode_root = root / "opencode"
    required_files = {
        "index.js",
        "preferences.js",
        "preference-writer.js",
        "model-catalog.js",
        "configure-opencode-subagents",
        "setup.js",
    }
    for filename in required_files:
        path = opencode_root / filename
        if not path.is_file():
            die(f"missing OpenCode package file: {path}")

    generated_root = opencode_root / "generated"
    generated_files = {path.name for path in generated_root.iterdir()}
    if generated_files != {"agents.json", "commands.json"}:
        die(
            f"{generated_root} exact-set mismatch: expected=['agents.json', 'commands.json'] "
            f"actual={sorted(generated_files)!r}"
        )

    index_path = opencode_root / "index.js"
    index = read_text(index_path)
    for marker in (
        'new URL("./generated/agents.json", import.meta.url)',
        'new URL("./generated/commands.json", import.meta.url)',
        'new URL("../skills-opencode", import.meta.url)',
        'const CONFIGURE_TOOL = "oh_no_configure_subagents"',
        "tool: {",
        "[CONFIGURE_TOOL]: {",
        "[MODEL_CATALOG_TOOL]: {",
        "args: CONFIGURE_TOOL_ARGS",
        "await context.ask({",
        "permission: CONFIGURE_TOOL",
        'patterns: ["*"]',
        "validateCatalogAssignments(requested, catalog)",
        "writePreferenceAssignments(assignments)",
        "config.agent =",
        "config.command =",
        "config.skills =",
        'config.default_agent = "oh-no"',
        "config.subagent_depth = 2",
        "build: { ...existingAgents.build, disable: true }",
        "plan: { ...existingAgents.plan, disable: true }",
        "applyPackagePermissions(packageAgents, config.permission, existingAgents)",
    ):
        if marker not in index:
            die(f"{index_path} is missing OpenCode plugin contract marker: {marker!r}")
    for forbidden in (
        '"shell.env"',
        "OH_NO_OPENCODE_PLUGIN_ROOT",
        "CONFIGURATOR_BASH_PATTERN",
        "configure-opencode-subagents*",
        "tool.schema",
        'from "zod"',
    ):
        if forbidden in index:
            die(f"{index_path} retains forbidden shell/Bash/Zod configurator surface: {forbidden!r}")
    if index.count('type: "string"') != 5 or not all(
        marker in index
        for marker in ("pattern: MODEL_SCHEMA_PATTERN", "pattern: VARIANT_SCHEMA_PATTERN")
    ):
        die(f"{index_path} custom tool must use the legacy plain JSON-schema property shape")

    permission_ceiling_markers = (
        "function concretePermissionAction(permission, tool, target)",
        'if (tool.includes("*") || tool.includes("?"))',
        'throw new TypeError("Permission evaluation requires a concrete tool name")',
        "if (candidate !== undefined) action = candidate",
        "function finitePackageAction(packageAction, permissions, tool, target)",
        "function collectRestrictions(groups, permission)",
        'if (action !== "ask" && action !== "deny") return',
        "function restrictivePermission(permissions)",
        'if (action === "ask") targets.set(pattern, "deny")',
        "function applyPackagePermissions(packageAgents, globalPermission, existingAgents)",
        'const primaryPermission = existingAgents["oh-no"]?.permission',
        "const rolePermission = existingAgents[name]?.permission",
        "const permission = restrictivePermission([...agentCeilings, packagePermission])",
        "[globalPermission, primaryPermission, rolePermission]",
        "finitePackageAction(",
        "applyExactRestriction(",
    )
    for marker in permission_ceiling_markers:
        if marker not in index:
            die(
                f"{index_path} must inherit global permission natively, preserve restrictive "
                "primary/role patterns, and ceiling finite package permissions without "
                f"symbolic policy synthesis: missing {marker!r}"
            )
    apply_at = index.find(
        "applyPackagePermissions(packageAgents, config.permission, existingAgents)"
    )
    publish_at = index.find("config.agent =")
    if apply_at == -1 or publish_at == -1 or apply_at > publish_at:
        die(
            f"{index_path} must apply host ceilings before publishing package agents"
        )

    preferences_path = opencode_root / "preferences.js"
    preferences = read_text(preferences_path)
    role_match = re.search(
        r"export const ROLES = Object\.freeze\(\[(?P<body>.*?)\]\);",
        preferences,
        flags=re.DOTALL,
    )
    if not role_match:
        die(f"{preferences_path} is missing the canonical ROLES array")
    roles = re.findall(r'"([a-z0-9-]+)"', role_match.group("body"))
    if roles != AGENTS:
        die(f"{preferences_path} ROLES mismatch: expected={AGENTS!r} actual={roles!r}")
    for marker in (
        "opencode-subagent-models.conf",
        "schema_version=1",
        "schema_version=2",
        "DEFAULT_VARIANT",
        "VARIANT_SCHEMA_PATTERN",
        "OH_NO_CONFIG_DIR",
        "XDG_CONFIG_HOME",
        "path.isAbsolute(candidate)",
        "stats.isSymbolicLink()",
        "O_NOFOLLOW",
        "export function isSecureConfigDirectory(stats)",
        "(stats.mode & 0o022) !== 0",
        "stats.uid === process.getuid()",
        "export function sameDirectoryIdentity(first, second)",
        "first.dev === second.dev && first.ino === second.ino",
    ):
        if marker not in preferences:
            die(f"{preferences_path} is missing preference contract marker: {marker!r}")

    catalog_path = opencode_root / "model-catalog.js"
    catalog = read_text(catalog_path)
    for marker in (
        'export const MODEL_CATALOG_TOOL = "oh_no_get_model_catalog"',
        "MODEL_CATALOG_PAGE_SIZE = 40",
        "client.config.providers({ query: { directory } })",
        "primary_model",
        "model?.variants",
        "validateCatalogAssignments",
        'query.mode === "providers"',
        'query.mode !== "models"',
        "next_cursor",
        'status: "catalog-unavailable"',
    ):
        if marker not in catalog:
            die(f"{catalog_path} is missing model-catalog contract marker: {marker!r}")

    writer_path = opencode_root / "preference-writer.js"
    writer = read_text(writer_path)
    for marker in (
        'platform !== "win32"',
        "constants.O_DIRECTORY",
        "constants.O_NOFOLLOW",
        "normalizeModelAssignments(value)",
        "async function ensureConfigDirectory(directory)",
        "async function destinationIsSafe(file)",
        "async function openConfigDirectory(directory, syncDirectory)",
        "isSecureConfigDirectory(stats)",
        "sameDirectoryIdentity(stats, pathStats)",
        "async function directoryPathStillMatches(directory, openedStats)",
        "sameDirectoryIdentity(openedStats, stats)",
        "async function writeLockOwner(lock, owner)",
        "constants.O_EXCL |",
        "await handle.sync()",
        "async function readLockOwner(lock)",
        "value.uid !== currentUid",
        'value.host !== hostname()',
        'error?.code === "ESRCH"',
        "async function reclaimStaleLock(lock, directoryHandle, syncDirectory)",
        "constants.O_CREAT |",
        "await rename(lock, quarantine)",
        "sameDirectoryIdentity(state.lockStats, acquisition.lockStats)",
        "await rename(temporary, destination)",
        "published = true",
        'status: published ? "indeterminate-durability" : "write-failed"',
        "preferences were published, but directory durability could not be confirmed",
        "Node has no portable openat/renameat API",
        "not group/world writable",
    ):
        if marker not in writer:
            die(f"{writer_path} is missing preference-writer marker: {marker!r}")
    destination_section = writer[
        writer.find("async function destinationIsSafe"):
        writer.find("async function openConfigDirectory")
    ]
    if "constants.O_NOFOLLOW" not in destination_section or "await open(file" not in destination_section:
        die(f"{writer_path} must open an existing destination with no-follow semantics")
    owner_open = re.search(
        r"async function writeLockOwner.*?await open\(\s*ownerPath,\s*(?P<flags>.*?)\s*,\s*0o600\s*,?\s*\)",
        writer,
        flags=re.DOTALL,
    )
    if not owner_open or not all(
        marker in owner_open.group("flags")
        for marker in ("constants.O_EXCL", "constants.O_NOFOLLOW")
    ):
        die(f"{writer_path} must create lock owner metadata with exclusive no-follow flags")
    reclaim_section = writer[
        writer.find("async function reclaimStaleLock"):
        writer.find("async function acquirePreferenceLock")
    ]
    if not all(
        marker in reclaim_section
        for marker in (
            "constants.O_EXCL",
            "constants.O_NOFOLLOW",
            "await guardHandle.sync()",
            "await rename(lock, quarantine)",
        )
    ):
        die(f"{writer_path} must serialize stale reclaim through a durable guard and quarantine")
    temporary_open = re.search(
        r"await open\(\s*temporary,\s*(?P<flags>.*?)\s*,\s*0o600\s*,?\s*\)",
        writer,
        flags=re.DOTALL,
    )
    if not temporary_open or not all(
        marker in temporary_open.group("flags")
        for marker in ("constants.O_EXCL", "constants.O_NOFOLLOW")
    ):
        die(f"{writer_path} must create the temporary destination with exclusive no-follow flags")

    helper_path = opencode_root / "configure-opencode-subagents"
    if not (helper_path.stat().st_mode & 0o111):
        die(f"{helper_path} must be executable")
    helper = read_text(helper_path)
    for marker in (
        'if (command !== "check" || args.length !== 0)',
        "readPreferenceState()",
        "STATUS: ${state.status}",
    ):
        if marker not in helper:
            die(f"{helper_path} is missing read-only status marker: {marker!r}")
    for forbidden in ("writePreferenceAssignments", "rename(", "mkdir(", 'command === "apply"'):
        if forbidden in helper:
            die(f"{helper_path} read-only command contains write/apply surface: {forbidden!r}")

    setup_path = opencode_root / "setup.js"
    if not (setup_path.stat().st_mode & 0o111):
        die(f"{setup_path} must be executable")
    setup = read_text(setup_path)
    for marker in (
        "Usage: oh-no-harness setup [--check]",
        'const PACKAGE_NAME = "oh-no-harness"',
        "OPENCODE_CONFIG_DIR",
        "XDG_CONFIG_HOME",
        'path.join(homedir(), ".config", "opencode")',
        'const CONFIG_FILENAMES = ["config.json", "opencode.json", "opencode.jsonc"]',
        "directory = await realpath(requested)",
        "refusing symbolic-link config",
        "parse(text, errors, { allowTrailingComma: true })",
        'config field \'plugin\' must be an array',
        "effectivePlugins.some(isHarnessPlugin)",
        'await backupHandle.writeFile(previousText, "utf8")',
        "constants.O_NOFOLLOW",
        "constants.O_EXCL",
        "await handle.sync()",
        "await assertDestinationUnchanged(file, previousStats)",
        "await assertSourcesUnchanged(sources)",
        "await assertDirectoryUnchanged(directory, openedDirectoryStats)",
        "await rename(temporary, file)",
        "RESTART REQUIRED: quit and restart OpenCode",
        "run /configure-subagents to choose exact subagent models and variants",
    ):
        if marker not in setup:
            die(f"{setup_path} is missing setup CLI contract marker: {marker!r}")

    legacy_package_path = opencode_root / "package.json"
    if legacy_package_path.exists():
        die(f"{legacy_package_path} must not shadow the public package metadata")


def assert_opencode_configure_subagents_contract(root: Path) -> None:
    source_path = root / "docs" / "platforms" / "opencode-configure-subagents.md"
    wrapper_path = root / OPENCODE_SKILL_ROOT / "configure-subagents" / "SKILL.md"
    command_path = root / OPENCODE_AGENT_ROOT / "commands.json"
    gate_marker = "Continue only when the current user request explicitly asks to configure"
    for path in (source_path, wrapper_path):
        text = read_text(path)
        gate_at = text.find(gate_marker)
        gate_end = text.find("</HARD-GATE>")
        operational_at = text.find("## Available Models")
        if gate_at == -1 or gate_end == -1 or operational_at == -1:
            die(f"{path} is missing the explicit-current-user OpenCode setup hard gate")
        if not gate_at < gate_end < operational_at:
            die(
                f"{path} must place the explicit-current-user hard gate before "
                "question/tool/write instructions"
            )
        for operational_marker in (
            "Call `oh_no_get_model_catalog` exactly once",
            "Provider model lists are paginated",
            "exact returned `next_cursor`",
            "Use `question` to configure all nine roles",
            "Show a final table",
            "After explicit `Apply`",
            "Invoke `",
            'Invoke "',
        ):
            marker_at = text.find(operational_marker)
            if marker_at != -1 and marker_at < gate_end:
                die(
                    f"{path} places operational setup instructions before the "
                    f"explicit-current-user hard gate: {operational_marker!r}"
                )
        for marker in (
            "before calling `question`, `oh_no_get_model_catalog`,",
            "`oh_no_configure_subagents`, or writing anything",
            "Prior conversation, inferred preference, workflow entry, and",
            "another agent's recommendation are not authorization",
            "After explicit `Apply`",
            "`Cancel` stops with no",
            "call `oh_no_configure_subagents` exactly once",
            "all 18 required properties",
            "Do not use Bash, a subprocess, `opencode models`",
            "There are no fast, balanced, deep, preset, or quality profiles",
            "`Apply`, `Edit roles`, or `Cancel`",
        ):
            if not has_required_marker(text, marker):
                die(f"{path} is missing OpenCode setup gate/apply marker: {marker!r}")
        if text.count("call `oh_no_configure_subagents` exactly once") != 1:
            die(f"{path} must contain exactly one custom-tool call instruction")
        for role in AGENTS:
            if text.count(f'"{role}": "<provider/model-id>"') != 1:
                die(f"{path} must pass exactly one {role!r} custom-tool property")
            if text.count(f'"{role}-variant": "<variant-or-default>"') != 1:
                die(f"{path} must pass exactly one {role!r} variant property")
        for forbidden in (
            "OH_NO_OPENCODE_PLUGIN_ROOT",
            '"${OH_NO_OPENCODE_PLUGIN_ROOT}',
            "argument array",
            "starting any subprocess",
        ):
            if forbidden in text:
                die(f"{path} retains forbidden helper/subprocess setup syntax: {forbidden!r}")

    commands = read_json_object(command_path)
    configure = commands.get("configure-subagents")
    if not isinstance(configure, dict):
        die(f"{command_path} is missing configure-subagents")
    template = configure.get("template")
    if not isinstance(template, str) or "bypass of its apply gate" not in template:
        die(f"{command_path} configure-subagents command must expose no apply bypass")
    for forbidden in (
        "OH_NO_OPENCODE_PLUGIN_ROOT",
        "configure-opencode-subagents",
        "apply\n",
        "`apply`",
        "Apply or Cancel",
    ):
        if forbidden in template:
            die(
                f"{command_path} configure-subagents command exposes operational "
                f"apply syntax: {forbidden!r}"
            )


def assert_opencode_contract(root: Path) -> None:
    assert_exact_opencode_skill_inventory(root)
    for skill in OPENCODE_SKILLS:
        assert_skill_wrapper(root, skill, OPENCODE_SKILL_ROOT, "opencode")
    assert_opencode_generated_agents(root)
    assert_opencode_generated_commands(root)
    assert_opencode_runtime_contract(root)
    assert_opencode_configure_subagents_contract(root)



def assert_generated_agent_wrappers(marketplace_root: Path, root: Path) -> None:
    script_candidates = [
        marketplace_root / "scripts" / "generate-agent-wrappers.py",
        root.parent.parent / "scripts" / "generate-agent-wrappers.py",
    ]
    if len(root.parents) >= 3:
        script_candidates.append(root.parents[2] / "scripts" / "generate-agent-wrappers.py")
    script = next((candidate for candidate in script_candidates if candidate.exists()), None)
    if script is None:
        searched = ", ".join(str(candidate) for candidate in script_candidates)
        die(f"generate-agent-wrappers.py is missing; searched: {searched}")
    result = subprocess.run(
        [sys.executable, str(script), "--plugin-root", str(root), "--check"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        details = "\n".join(
            part
            for part in (result.stdout.strip(), result.stderr.strip())
            if part
        )
        die(f"generated agent wrappers are stale:\n{details}")


def assert_generated_skill_wrappers(marketplace_root: Path, root: Path) -> None:
    script_candidates = [
        marketplace_root / "scripts" / "generate-skill-wrappers.py",
        root.parent.parent / "scripts" / "generate-skill-wrappers.py",
    ]
    if len(root.parents) >= 3:
        script_candidates.append(root.parents[2] / "scripts" / "generate-skill-wrappers.py")
    script = next((candidate for candidate in script_candidates if candidate.exists()), None)
    if script is None:
        searched = ", ".join(str(candidate) for candidate in script_candidates)
        die(f"generate-skill-wrappers.py is missing; searched: {searched}")
    result = subprocess.run(
        [sys.executable, str(script), "--plugin-root", str(root), "--check"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        details = "\n".join(
            part
            for part in (result.stdout.strip(), result.stderr.strip())
            if part
        )
        die(f"generated skill wrappers are stale:\n{details}")


def assert_skill_reachability(marketplace_root: Path, root: Path) -> None:
    """Deterministic deep-smoke: each skill's load-bearing workflow rules must be
    reachable in its composed wrapper plus the docs/sub-skills it references, on
    both platforms. Replaces flaky live-model phrase grepping as the gate."""
    script_candidates = [
        marketplace_root / "scripts" / "check-skill-reachability.py",
        root.parent.parent / "scripts" / "check-skill-reachability.py",
    ]
    if len(root.parents) >= 3:
        script_candidates.append(root.parents[2] / "scripts" / "check-skill-reachability.py")
    script = next((candidate for candidate in script_candidates if candidate.exists()), None)
    if script is None:
        searched = ", ".join(str(candidate) for candidate in script_candidates)
        die(f"check-skill-reachability.py is missing; searched: {searched}")
    for platform in ("codex", "claude", "opencode"):
        result = subprocess.run(
            [sys.executable, str(script), "--platform", platform, "--plugin-root", str(root)],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            details = "\n".join(
                part for part in (result.stdout.strip(), result.stderr.strip()) if part
            )
            die(f"skill reachability check failed ({platform}):\n{details}")


def assert_opencode_mutation_tests(marketplace_root: Path, root: Path) -> None:
    script = marketplace_root / "scripts" / "test-opencode-static-contract.py"
    if not script.exists():
        die(f"{script} is missing; OpenCode static contracts need mutation coverage")
    result = subprocess.run(
        [
            sys.executable,
            str(script),
            "--marketplace-root",
            str(marketplace_root),
            "--plugin-root",
            str(root),
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        details = "\n".join(
            part for part in (result.stdout.strip(), result.stderr.strip()) if part
        )
        die(f"OpenCode static mutation tests failed:\n{details}")


def assert_opencode_preference_tests(marketplace_root: Path) -> None:
    script = marketplace_root / "scripts" / "test-opencode-preferences.mjs"
    if not script.exists():
        die(f"{script} is missing; OpenCode preference hardening needs a focused gate")
    try:
        result = subprocess.run(
            ["node", str(script)],
            cwd=marketplace_root,
            capture_output=True,
            text=True,
        )
    except OSError as exc:
        die(f"unable to run focused OpenCode preference tests: {exc}")
    if result.returncode != 0:
        details = "\n".join(
            part for part in (result.stdout.strip(), result.stderr.strip()) if part
        )
        die(f"focused OpenCode preference tests failed:\n{details}")


def assert_test_harness_lane_contract(marketplace_root: Path, root: Path) -> None:
    script_candidates = [
        marketplace_root / "scripts" / "test-harness-lane-contract.py",
        root.parent.parent / "scripts" / "test-harness-lane-contract.py",
    ]
    script = next((candidate for candidate in script_candidates if candidate.exists()), None)
    if script is None:
        searched = ", ".join(str(candidate) for candidate in script_candidates)
        die(f"test-harness-lane-contract.py is missing; searched: {searched}")
    result = subprocess.run(
        [sys.executable, str(script), "--marketplace-root", str(marketplace_root), "--plugin-root", str(root)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        details = "\n".join(part for part in (result.stdout.strip(), result.stderr.strip()) if part)
        die(f"test harness lane contract failed:\n{details}")

    obsolete = (
        "--deep-live", "--parallel-live", "--ralplan-live", "--named-agents-live",
        "--simplify-live", "--natural-session-start-live", "--worktree-live",
        "--model-diversity-live", "--parallel-executor-live", "--live-hook-only",
    )
    for host in ("claude", "codex"):
        path = marketplace_root / "scripts" / f"test-{host}-plugin.sh"
        text = read_text(path)
        leftovers = [flag for flag in obsolete if flag in text]
        if leftovers:
            die(f"{path} retains retired live-suite options: {leftovers}")
        for marker in ("direct_invariant_for_skill()", "direct_prompt_for_skill()", "Invariant:", "forbidden project mutation"):
            if marker not in text:
                die(f"{path} is missing direct-smoke contract marker: {marker!r}")

def assert_direct_dispatch_compatibility_contract(root: Path) -> None:
    """Keep direct role dispatch proportional without weakening repository safety."""
    role_contracts = {
        "executor": (
            "target role",
            "exact target revision/diff fingerprint",
            "scope/permissions/non-goals",
            "mutation authorization",
            "contract/AC or direct behavior lock",
            "expected evidence/output",
            "stop/escalation",
        ),
        "verifier": (
            "target role",
            "exact target revision/diff fingerprint",
            "scope/permissions/non-goals",
            "contract/AC or verification claim",
            "expected evidence/output",
            "stop/escalation",
        ),
        "code-reviewer": (
            "target role",
            "exact target revision/diff fingerprint",
            "scope/permissions/non-goals",
            "contract/AC or review basis",
            "expected evidence/output",
            "stop/escalation",
        ),
    }
    for role, required in role_contracts.items():
        path = root / AGENT_CORE_ROOT / f"{role}.md"
        body = read_text(path)
        for marker in required:
            if not has_required_marker(body, marker):
                die(f"{path} direct-dispatch safety contract is missing {marker!r}")
        for marker in (
            "Workflow-specific IDs are required only when the selected workflow delta requires them",
            "preserve and echo every supplied ID",
        ):
            if not has_required_marker(body, marker):
                die(f"{path} direct-dispatch compatibility contract is missing {marker!r}")
        if "require Packet ID, Run/session ID, Story/task ID" in body:
            die(f"{path} hard-requires workflow IDs for direct dispatch")
        for output_marker in (
            "Packet ID: <echo when supplied | not supplied — direct workflow>",
            "Run/session ID: <echo when supplied | not supplied — direct workflow>",
            "Story/task ID: <echo when supplied | not supplied — direct workflow>",
        ):
            if output_marker not in body:
                die(f"{path} does not preserve optional workflow identity: {output_marker!r}")


def assert_codex_child_packet_floor_contract(root: Path) -> None:
    """Pin the hook-disabled Codex native-skill caller floor."""
    floor_path = root / "docs" / "platforms" / "codex-child-packet-floor.md"
    floor = read_text(floor_path)
    for marker in (
        "# Codex Child Packet Floor",
        "hook-disabled native-skill fallback",
        "main caller",
        "proportional self-contained English packet",
        "target role",
        "exact target/revision",
        "result/revision binding",
        "scope/permissions/non-goals",
        "contract/acceptance",
        "expected evidence/output",
        "stop/escalation",
        "Workflow-specific IDs and deltas come from the selected skill",
        "withhold maker conclusions, expected verdicts, sibling outputs, and preferred root-cause hypotheses",
    ):
        if not has_required_marker(floor, marker):
            die(f"{floor_path} is missing Codex child-packet floor marker: {marker!r}")
    for marker in (
        "Global Context Capsule",
        "Receiver Preflight",
        "Packet ID:",
        "Run/session ID:",
        "Story/task ID:",
    ):
        if marker in floor:
            die(f"{floor_path} contains receiver-schema or workflow-ID marker: {marker!r}")

    generator_path = root.parent.parent / "scripts" / "generate-skill-wrappers.py"
    generator = read_text(generator_path)
    for marker in (
        'CODEX_CHILD_PACKET_FLOOR = "docs/platforms/codex-child-packet-floor.md"',
        "child_packet_paths",
        "source_paths = [core_path, *child_packet_paths, *overlay_paths]",
    ):
        if marker not in generator:
            die(f"{generator_path} is missing Codex child-packet composition marker: {marker!r}")
    common_runtime_composition = (
        "source_paths = [core_path, *child_packet_paths, "
        "plugin_root / platform.platform_doc, *overlay_paths]"
    )
    if not re.search(
        r"source_paths\s*=\s*\[\s*core_path,\s*\*child_packet_paths,\s*"
        r"plugin_root\s*/\s*platform\.platform_doc,\s*\*overlay_paths,?\s*\]",
        generator,
    ):
        die(
            f"{generator_path} is missing Codex child-packet composition marker: "
            f"{common_runtime_composition!r}"
        )

    for skill in WORKFLOW_ROUTING_SKILLS:
        wrapper_path = root / CODEX_SKILL_ROOT / skill / "SKILL.md"
        wrapper = read_text(wrapper_path)
        for marker in (
            "../../docs/platforms/codex-child-packet-floor.md",
            "## Source: docs/platforms/codex-child-packet-floor.md",
            "# Codex Child Packet Floor",
        ):
            if wrapper.count(marker) != 1:
                die(f"{wrapper_path} must contain one hook-disabled caller floor marker: {marker!r}")
        runtime_marker = "docs/platforms/codex-runtime.md"
        if skill in SELF_CONTAINED_ADAPTER_SKILLS:
            if runtime_marker in wrapper:
                die(f"{wrapper_path} must keep the common Codex runtime excluded")
        elif runtime_marker not in wrapper:
            die(f"{wrapper_path} must retain the common Codex runtime")

    for skill in WORKFLOW_ROUTING_SKILLS:
        wrapper_path = root / CLAUDE_SKILL_ROOT / skill / "SKILL.md"
        if "codex-child-packet-floor.md" in read_text(wrapper_path):
            die(f"{wrapper_path} must not include the Codex-only child-packet floor")


def assert_ralph_live_heading_references(root: Path) -> None:
    """Reject references to Ralph headings retired by the gate consolidation."""
    paths = (
        root / "docs" / "skill-core" / "ralph.md",
        root / "docs" / "specs" / "2026-07-16-ralplan-ralph-fsm-core-rewrite.md",
        root / CODEX_SKILL_ROOT / "ralph" / "SKILL.md",
        root / CLAUDE_SKILL_ROOT / "ralph" / "SKILL.md",
    )
    for path in paths:
        body = read_text(path)
        for marker in ("Scope Trace Gate", "Verification Budget Policy"):
            if marker in body:
                die(f"{path} retains retired Ralph heading reference: {marker!r}")


def assert_child_packet_ownership_contract(root: Path) -> None:
    """Pin caller-owned child packets and role-only generated prompts."""
    common_path = root / AGENT_CORE_ROOT / "_global-context-capsule.md"
    if common_path.exists():
        die(f"{common_path} must be absent; child-packet construction is caller-owned")

    generator_path = root.parent.parent / "scripts" / "generate-agent-wrappers.py"
    generator = read_text(generator_path)
    for marker in (
        "COMMON_AGENT_CORE",
        "read_common_agent_core",
        "compose_agent_body",
        "_global-context-capsule.md",
        "Common source:",
        "Agent prompt common source:",
    ):
        if marker in generator:
            die(f"{generator_path} retains forbidden common-fragment composition: {marker!r}")
    for marker in (
        "body = read_agent_core(plugin_root, meta.role)",
        "Generated from docs/agent-core; do not edit by hand.",
        "Source: plugins/oh-no-harness/docs/agent-core/",
        "Agent prompt source: docs/agent-core/",
    ):
        if marker not in generator:
            die(f"{generator_path} is missing role-only generation marker: {marker!r}")

    hook_path = root / "hooks" / "session-start"
    hook = read_text(hook_path)
    bootstrap_start = hook.find("bootstrap_policy='")
    bootstrap_end = hook.find('\n\nauto_routing_policy=""', bootstrap_start)
    if bootstrap_start < 0 or bootstrap_end < 0:
        die("child-packet floor: cannot locate unconditional OH_NO_BOOTSTRAP")
    bootstrap = hook[bootstrap_start:bootstrap_end]
    floor_markers = (
        "Child packet floor",
        "caller sends a proportional self-contained English packet",
        "purpose/outcome",
        "target role",
        "repo mutation/review/verify",
        "exact target/revision + result/revision binding",
        "scope/permissions/non-goals",
        "contract/acceptance",
        "evidence/output",
        "stop/escalation",
        "Initial independent review/verify/debug",
        "withholds maker conclusions, expected verdicts, sibling output, preferred causes",
        "disclose only later for audit/clarification",
    )
    for marker in floor_markers:
        if not has_required_marker(bootstrap, marker):
            die(f"child-packet floor: unconditional OH_NO_BOOTSTRAP is missing {marker!r}")
    if hook.count("Child packet floor:") != 1:
        die("child-packet floor must have exactly one common SessionStart source owner")
    for marker in (
        "Global Context Capsule",
        "Capsule delta",
        "_global-context-capsule.md",
        "## Full Capsule",
        "## Receiver Preflight",
    ):
        if marker in hook:
            die(f"{hook_path} retains former receiver-schema marker: {marker!r}")

    former_prompt_markers = (
        "# Global Context Capsule",
        "## Full Capsule",
        "## Receiver Preflight",
        "Every new child receives a full Global Context Capsule",
        "Context status: blocked",
        "_global-context-capsule.md",
    )
    role_headings = {
        "explore": "# Explore Agent",
        "analyst": "# Analyst Agent",
        "planner": "# Planner Agent",
        "plan-reviewer": "# Plan Reviewer Agent",
        "executor": "# Executor Agent",
        "debugger": "# Debugger Agent",
        "verifier": "# Verifier Agent",
        "code-reviewer": "# Code Reviewer Agent",
        "fusion-rescue-analyst": "# Fusion Rescue Analyst Agent",
    }
    for agent in AGENTS:
        core_path = root / AGENT_CORE_ROOT / f"{agent}.md"
        core = read_text(core_path)
        claude_path = root / "agents" / f"{agent}.md"
        claude = read_text(claude_path)
        codex_path = root / CODEX_AGENT_TEMPLATE_ROOT / f"oh-no-{agent}.toml"
        codex = read_text(codex_path)
        for prompt_path, prompt in ((core_path, core), (claude_path, claude), (codex_path, codex)):
            for marker in former_prompt_markers:
                if marker in prompt:
                    die(f"{prompt_path} retains former shared receiver contract: {marker!r}")
        role_heading = role_headings[agent]
        if claude.count(role_heading) != 1 or codex.count(role_heading) != 1:
            die(f"generated prompt for {agent} must contain its role core exactly once")
        for marker in (
            "Generated from docs/agent-core; do not edit by hand.",
            f"Source: plugins/oh-no-harness/docs/agent-core/{agent}.md",
            "python3 scripts/generate-agent-wrappers.py --write",
        ):
            if claude.count(marker) != 1:
                die(f"{claude_path} role provenance must appear once: {marker!r}")
        for marker in (
            "# Generated from docs/agent-core; do not edit by hand.",
            f"# Source: plugins/oh-no-harness/docs/agent-core/{agent}.md",
            "# Run: python3 scripts/generate-agent-wrappers.py --write",
            f"Agent prompt source: docs/agent-core/{agent}.md",
        ):
            if codex.count(marker) != 1:
                die(f"{codex_path} role provenance must appear once: {marker!r}")

    ralph_path = root / "docs" / "skill-core" / "ralph.md"
    ralph = read_text(ralph_path)
    for heading, markers in {
        "## Execution Loop": (
            "one bounded task and the minimal inseparable AC-ID set",
            "main caller builds",
            "self-contained English packet",
            "adds only Ralph's assignment delta",
            "role prompts do not reconstruct omitted caller context",
        ),
        "## Parallel Subagent Policy": (
            "main caller owns each complete child packet",
            "common caller floor",
            "use English instruction prose",
            "add only the Ralph delta",
            "same-child follow-up must explicitly restate every changed target",
            "initial `code-reviewer` packet",
            "withhold maker conclusions, expected verdicts, and sibling outputs",
            "initial `verifier` packet",
            "independent evidence design",
            "later audit phase discloses accepted review findings or a fix manifest",
            "audit obligations, not proof",
            "Ralph-specific assignment delta",
            "Packet ID:",
            "Executor assignment ID:",
        ),
        "## Mutation Manifest and Expansion Gate": (
            "change kind",
            "semantic obligation",
            "causal generated outputs",
            "stops before editing and returns an `Expansion request`",
            "affected packet fields",
            "requested-direction-change: yes | no",
            # 2026-07-29: an approved expansion must be routed by owner, bound to
            # a new manifest revision, and reflected in the snapshot BEFORE any
            # mutation; direction-class expansion is never caller-approvable.
            "Expansion: none | requested | approved@<revision id> | rejected",
            "Approval owner and routing",
            "Ralph MUST pause and return to the user, or to `ralplan` for a plan-level\nchange",
            "BEFORE any\nmutation",
            "Revised-manifest binding",
            "Mutation under a superseded manifest revision is out-of-scope work",
            # CR-3: the approval owner is persisted, and any named risk needing
            # broader authority routes through pause/return, not self-approval.
            "its named approval owner",
            "An expansion\nwhose approval owner is unrecorded is unapproved.",
            "That list is illustrative, not exhaustive: ANY named or approved risk",
            "routes through the same pause/return rather than caller\nself-approval",
            "When ownership is unclear, fail closed to the user",
            "Expansion status: approved@<revision id> -> incorporated before mutation",
            "never proceeds on\nan assumed approval",
        ),
        "## Verification Contract and Test Necessity Gate": (
            "focused RED behavior/command and expected old failure",
            "GREEN behavior/command and required observation",
            "Map every new or changed test to an assigned AC ID or change-introduced independent failure mode",
            "why existing evidence is insufficient",
            "duplicate variants",
            "implementation-detail-only assertions",
            "combination explosion",
            "unapproved helper/framework/fixture expansion",
            "stop adding tests",
        ),
        "## Executor Assignment Completion Stop": (
            "Stop the current executor assignment",
            "manifest is satisfied",
            "mapped verification is green and fresh",
            "local to that bounded assignment, not final run completion",
        ),
        "## Review Gate": (
            "Reviewer packets are blind to maker conclusions",
            "verifier first records its evidence design",
            "Accepted findings and fix manifests are audit obligations, not proof",
            "complete manifest fingerprint",
            "semantic RED/GREEN",
            "Test Necessity mapping",
        ),
        "## Completion Stop": (
            "Record final run Completion Stop only after mutation-capable cleanup",
            # Trigger-gated since 2026-07-29: the final verifier is required only
            # when the Review Gate predicate fires.
            "any triggered final verifier",
            "exact final complete manifest fingerprint",
            "Any later mutation invalidates this final stop",
        ),
    }.items():
        section = markdown_section(ralph, heading)
        if not section:
            die(f"{ralph_path} is missing child-packet ownership section: {heading!r}")
        for marker in markers:
            if not has_required_marker(section, marker):
                die(f"{ralph_path} {heading} is missing child-packet marker: {marker!r}")
    for marker in ("Global Context Capsule", "Capsule delta", "affected capsule fields"):
        if marker in ralph:
            die(f"{ralph_path} retains former receiver-schema marker: {marker!r}")

    ordered_headings = (
        "## Executor Assignment Completion Stop",
        "## Cleanup And Final Verification",
        "## Review Gate",
        "## Finalize Checkpoints",
        "## Completion Stop",
        "## Resume Protocol",
    )
    heading_positions = []
    for heading in ordered_headings:
        matches = list(re.finditer(rf"^{re.escape(heading)}$", ralph, flags=re.MULTILINE))
        if len(matches) != 1:
            die(f"{ralph_path} final run Completion Stop ordering requires exactly one {heading!r}")
        heading_positions.append(matches[0].start())
    if heading_positions != sorted(heading_positions):
        die(f"{ralph_path} final run Completion Stop ordering is invalid")

    debugging_path = root / "docs" / "skill-core" / "systematic-debugging.md"
    debugging = read_text(debugging_path)
    for marker in (
        "initial packet is symptom-first",
        "raw reproduction, expected and actual behavior, environment",
        "without a preferred cause or fix",
        "sibling conclusions",
        "later clarification",
        "neutral exact action, state, and raw outcome",
        "initial debugger packet contains the raw reproduction",
    ):
        if not has_required_marker(debugging, marker):
            die(f"{debugging_path} is missing symptom-first disclosure marker: {marker!r}")

    role_independence = {
        "plan-reviewer": (
            "Reach your own verdict from the exact draft",
            "initial review must not use an expected verdict or sibling review output",
            # 2026-08-07: authored implementation detail is blockable only by
            # named category, and never by brevity or style.
            "Detect authored implementation detail that belongs to the executor",
            "detail volume satisfies no basis in the",
            "never for brevity, prose style, or\n  non-constraint ordering",
            "an infeasible or materially required order still\n  blocks under an existing basis",
        ),
        "planner": (
            # 2026-08-07: the manifest is a ceiling, not a floor to elaborate
            # past; a task leaving only transcription is too detailed.
            "Respect the authored-detail boundary",
            "it is a ceiling, not a floor",
            "leaves the executor only transcription is too detailed",
        ),
        "code-reviewer": (
            "Derive findings independently from the exact contract and diff",
            "initial review must not use an expected verdict or sibling review output",
        ),
        "verifier": (
            "First design the required evidence",
            "without using maker conclusions or an expected verdict",
            "obligations to audit, never as proof",
        ),
        "debugger": (
            "Begin independently from the raw reproduction",
            "Form your own hypotheses before using any preferred cause",
            "exact action, state, and raw outcome as evidence",
        ),
        "executor": (
            "when any safety-critical field is missing, stale, contradictory, or misrouted",
            "bounded Ralph assignment",
            "Mutation Manifest",
            "Verification Contract",
            "Test Necessity Gate",
            "Executor Assignment Completion Stop",
            "affected packet fields",
            # 2026-08-07: the manifest bounds authorized paths, never how the
            # obligation is met; authored detail from a read-only planning role
            # is prediction the executor re-derives against current code.
            "how each\n  obligation is met is yours",
            "Report the drift when authored detail\n  contradicts the repository",
        ),
    }
    for agent, markers in role_independence.items():
        path = root / AGENT_CORE_ROOT / f"{agent}.md"
        body = read_text(path)
        for marker in markers:
            if not has_required_marker(body, marker):
                die(f"{path} is missing role-specific ownership marker: {marker!r}")

    script_pattern = re.compile(r"[Ѐ-ӿ؀-ۿᄀ-ᇿ぀-ヿ㐀-鿿가-힯]")
    language_surfaces = (
        (hook_path, bootstrap),
        (ralph_path, "\n".join(markdown_section(ralph, heading) for heading in (
            "## Execution Loop", "## Parallel Subagent Policy",
            "## Mutation Manifest and Expansion Gate",
            "## Verification Contract and Test Necessity Gate",
            "## Executor Assignment Completion Stop", "## Completion Stop",
        ))),
        (debugging_path, debugging),
        *tuple(
            (root / AGENT_CORE_ROOT / f"{agent}.md", read_text(root / AGENT_CORE_ROOT / f"{agent}.md"))
            for agent in role_independence
        ),
    )
    for path, surface in language_surfaces:
        for line in surface.splitlines():
            if script_pattern.search(line):
                die(f"{path} contains non-English child instruction prose: {line!r}")

def assert_orchestration_ownership_contract(root: Path) -> None:
    """Source-only guards for orchestration ownership and role envelopes.

    This intentionally avoids generated wrappers so mutation tests fail on the
    changed source contract rather than on expected wrapper staleness.
    """
    skill_core = root / "docs" / "skill-core"
    agent_core = root / "docs" / "agent-core"
    platforms = root / "docs" / "platforms"

    def require(path: Path, body: str, markers: tuple[str, ...], label: str) -> None:
        for marker in markers:
            if not has_required_marker(body, marker):
                die(f"{path} is missing {label}: {marker!r}")

    ralph_path = skill_core / "ralph.md"
    ralph = read_text(ralph_path)
    light_eligibility = markdown_section(
        ralph, "### LIGHT Eligibility — Risk Gate, Soft Size Screen"
    )
    require(
        ralph_path,
        light_eligibility,
        (
            "`unknown = excluded (fail closed)`",
            "a new dependency, dependency pin,\nor lockfile",
            "generated files or generation\ninputs",
            "materiality of the controlled VALUE",
        ),
        "LIGHT hard exclusion contract",
    )
    require(
        ralph_path,
        light_eligibility,
        (
            "behavior-LIGHT gets NO TDD-exception escape",
            "If RED is infeasible, reclassify\nto STANDARD or THOROUGH",
        ),
        "LIGHT behavior RED/GREEN no-exception contract",
    )
    require(
        ralph_path,
        light_eligibility,
        (
            "Size alone\nNEVER grants LIGHT",
            "`D ? direct-edit : T ? THOROUGH : L ? LIGHT : STANDARD`",
            "the exclusion gate runs regardless of size",
        ),
        "LIGHT size-never-shortcuts-eligibility contract",
    )
    require(
        ralph_path,
        light_eligibility,
        (
            "an exclusion becoming present-or-unknown",
            "the edit set growing past a cohesive localized scope",
        ),
        "LIGHT eligibility escalation contract",
    )
    require(
        ralph_path,
        light_eligibility,
        (
            "There is NO size-bound entry in this hard exclusion UNION",
            "No hard numeric file-count or line-count bound exists anywhere in this eligibility gate",
            "There is NO hard file-count or line-count cap",
        ),
        "LIGHT no-hard-cap contract",
    )
    hard_numeric_light_bound_patterns = (
        r"\b\d+\s+(?:changed\s+|handwritten\s+)?(?:files?|lines?)\b",
        r"\b(?:files?|lines?)\s*(?:<=|>=|<|>|=|:)\s*\d+\b",
    )
    for pattern in hard_numeric_light_bound_patterns:
        if re.search(pattern, light_eligibility, flags=re.IGNORECASE):
            die(
                f"{ralph_path} violates LIGHT no-hard-cap contract: "
                f"hard numeric file/line eligibility bound matches {pattern!r}"
            )
    require(
        ralph_path,
        markdown_section(ralph, "## Invariants"),
        (
            "main agent is the orchestrator",
            "sole owner of `.oh-no` state",
            "REVIEW-to-EXECUTE focused fixes",
            "Role result enums are caller gate inputs",
        ),
        "executor-default orchestration contract",
    )
    require(
        ralph_path,
        markdown_section(ralph, "## Execution Run Snapshot"),
        (
            "dispatch lifecycle change",
            "Active dispatches:",
            "Packet ID; host handle; role; scope; pending|final|abandoned",
            "Mark it `final` only after those caller-owned intake steps complete",
            "Packet ID remains the compact reference",
            "diff-budget <pending | passed@<fingerprint> | stale>",
        ),
        "active-dispatch and revision-bound snapshot contract",
    )
    require(
        ralph_path,
        markdown_section(ralph, "## Resume Protocol"),
        (
            "Reconcile every `pending` Active dispatch entry",
            "before redispatching overlapping scope",
            "Never redispatch overlapping work while the prior entry remains pending",
        ),
        "active-dispatch resume reconciliation",
    )
    require(
        ralph_path,
        markdown_section(ralph, "## State Machine"),
        (
            # The no-blocker exit now has two compliant shapes: no verifier
            # trigger fired, or a triggered pass bound to the reviewed revision.
            "reviewer verdict approve (or compliant not-required) and either no verifier trigger fired (compliant not-required) or verifier pass / accepted pass-with-residual-risk bound to the reviewed revision",
            "reviewer verdict blocking-findings",
            "EXECUTE-fix (exactly one executor-owned focused fix; no reviewer re-dispatch)",
            "fix manifest maps every accepted blocking finding ID",
            "verifier pass (or accepted pass-with-residual-risk) binds to the FIXED revision",
            "TRIGGERED independent verifier has no separate context",
            "reviewer or verifier verdict is `blocked`",
        ),
        "caller-owned FSM transition contract",
    )
    require(
        ralph_path,
        markdown_section(ralph, "## Execution Loop"),
        (
            "assign one stable `Executor assignment ID`",
            "Dispatch `executor` for repository work-product mutation",
            "main agent mutates only its `.oh-no` state",
        ),
        "executor-default execution-loop contract",
    )
    # 2026-07-29: the cap-5 ceiling needs a matching floor, or a small bounded
    # lookup gets fanned out across several redundant subagents.
    require(
        ralph_path,
        markdown_section(ralph, "## Execution Loop"),
        (
            "one `explore` when one covers the question",
            "never split a small\n   bounded lookup into multiple dispatches",
        ),
        "one-when-one-suffices explore floor",
    )
    mode_dispatch = markdown_section(ralph, "## Mode-Gated Agent Dispatch")
    require(
        ralph_path,
        mode_dispatch,
        (
            "main agent is the orchestrator, not the default maker",
            # 2026-07-30: one need test replaces the per-mode absolute. Both
            # halves are pinned because either polarity regresses by reusing the
            # same tokens: dropping the need test forces a subagent onto a
            # two-tool-call edit, and dropping the executor default silently
            # licenses unrecorded inline maker work.
            "One need test governs every non-review role in every mode",
            "sizeable, genuinely\nindependent, or parallelizable",
            "finishes in a handful of tool calls",
            "`executor` is the DEFAULT owner of\nrepository work-product mutation",
            "Mode never decides the need test by itself",
            "An unrecorded inline mutation is non-compliant in every\nmode",
            "executor-default trigger",
            "does not require a parallel trigger",
            "Mutation fallback: LIGHT-tiny",
            "Mutation fallback: dispatch-unavailable",
            "waives only reviewer dispatch",
            "A frozen `none` remains `none`",
            "does not disable sequential executor ownership",
        ),
        "executor-default orchestration contract",
    )
    require(
        ralph_path,
        mode_dispatch,
        (
            # 2026-07-30: permitting inline mutation opened a maker path with no
            # stated obligations, which would have made "this edit is small" a
            # way to opt out of the manifest, scope, and test-necessity gates.
            # Pinned verbatim: the contract clause, the packet-fold carve-out,
            # the diff confirmation, and the manifest-exit promotion each regress
            # independently, and the last one has no Expansion-request substitute
            # because an inline edit has no child to address.
            "Inline mutation changes WHO edits, never WHAT the edit owes",
            "applies UNCHANGED to an inline edit",
            "Only\nthe packet-shaped fields fold inward",
            "confirm it with a diff scoped to the intended paths",
            "Leaving the Mutation\nManifest ENDS inline eligibility",
            "reclassify to a dispatched `executor` BEFORE any further\nedit",
            "a smaller edit never buys a weaker contract",
        ),
        "inline-mutation executor-contract inheritance",
    )
    require(
        ralph_path,
        mode_dispatch,
        (
            # Review independence is the ONE exemption from the need test. It is
            # pinned separately so relaxing maker dispatch can never leak into
            # collapsing a fired review or audit trigger inline.
            "Review independence is the one exemption from the need test",
            "ALWAYS runs in a\nseparate context and NEVER inline",
            "its value is independence rather\nthan throughput",
            "Size, convenience, and time pressure never collapse a fired\nreview or audit trigger",
            "only confirmed dispatch-unavailability does",
            "FAIL-CLOSED",
        ),
        "review-independence need-test exemption contract",
    )
    packet = markdown_section(ralph, "## Parallel Subagent Policy")
    require(
        ralph_path,
        packet,
        (
            "Dispatch a single agent when one covers the work",
            "scale out only\nacross genuinely independent targets",
            "a small bounded lookup is never split\ninto multiple dispatches",
            # The cap-5 ceiling and batch-before-wait rules stay intact alongside
            # the new floor.
            "Cap a concurrent `executor` batch at up to 5 disjoint",
        ),
        "one-when-one-suffices batch floor",
    )
    require(
        ralph_path,
        packet,
        (
            "main caller owns each complete child packet",
            "common caller floor\nfrom SessionStart when enabled or the native platform wrapper fallback",
            "add only the Ralph delta",
            "same-child follow-up must explicitly restate every changed target",
            "Ralph-specific assignment delta",
            "Packet ID:",
            "distinct from run/session and story/task ids",
            "Run/session ID:",
            "Story/task ID:",
            "Executor assignment ID:",
            "stable across one executor assignment or TDD cycle",
            "Execution mode:",
            "Worktree decision and location:",
            "Direction Contract source and binding:",
            "AC IDs:",
            "Plan/PRD and read-only artifact pointers:",
            ".oh-no state stays main-owned",
            "TDD responsibility:",
            "Platform invocation: {active adapter invocation syntax}",
            "Lifecycle: caller waits for and captures",
            "Coordination:",
            "Assigned review perspective:",
            # 2026-07-29: the executor's scope contract travels in the packet, so
            # a bounded assignment cannot be dispatched without its manifest,
            # verification contract, admitted tests, stop, and expansion state.
            "Mutation Manifest:",
            "Verification Contract:",
            "Test Necessity Decisions:",
            "Assignment completion contract:",
            "Expansion authority:",
            "Expansion status:",
        ),
        "caller-owned child packet and Ralph assignment-delta contract",
    )
    require(
        ralph_path,
        packet,
        (
            "Result intake remains caller-owned",
            "Require exact identity and revision echoes",
            "stable `Executor assignment ID` for executor results",
            "Reject stale or misrouted results",
            "verifier\nthe freshness owner for the fixed revision",
        ),
        "stale/misrouted result guard",
    )
    cleanup = markdown_section(ralph, "## Cleanup And Final Verification")
    require(
        ralph_path,
        cleanup,
        (
            "LIGHT/STANDARD run a caller-owned quick diff scan; never load, invoke, or dispatch `simplify`, even when actual candidates or candidate uncertainty remain.",
            "Record `simplify`: not-required (mode: LIGHT|STANDARD).",
            "THOROUGH alone may load or invoke `simplify`, and only when actual candidates or candidate uncertainty remain.",
            "four independent viewpoints only for a named safety or\nbroad-diff trigger.",
        ),
        "THOROUGH-only Simplify cleanup policy",
    )
    simplify_path = skill_core / "simplify.md"
    simplify = read_text(simplify_path)
    require(
        simplify_path,
        simplify,
        (
            "When called by `ralph`, Simplify may be loaded or invoked only for eligible THOROUGH cleanup after Ralph's quick diff scan finds actual candidates or candidate uncertainty remains.",
            "Direct Simplify use remains independently selected by its own behavior lock and Cleanup Depth Decision.",
            "When a named THOROUGH trigger\nselects four-viewpoint depth",
        ),
        "Ralph-only THOROUGH Simplify handoff policy",
    )
    for platform, marker in (
        (
            "codex-ralph.md",
            "Only after the core selects eligible THOROUGH cleanup with actual candidates or candidate uncertainty may Codex load the `simplify` skill through the generated Codex Simplify runtime document.",
        ),
        (
            "claude-code-ralph.md",
            "Only after the core selects eligible THOROUGH cleanup with actual candidates or candidate uncertainty may Claude Code load the host built-in `simplify` skill as the cleanup contract.",
        ),
    ):
        path = platforms / platform
        require(
            path,
            read_text(path),
            (marker, "LIGHT/STANDARD do not load the Simplify path and retain the core's explicit mode-based not-required record."),
            "THOROUGH-only Simplify platform cleanup policy",
        )
    require(
        ralph_path,
        cleanup,
        (
            "post-cleanup review inspection",
            "apply whenever a code-review stage runs, under `single-reviewer` or\n`perspective-pair`",
            "proceeds\ndirectly from CLEANUP/RECHECK to its verifier decision under",
            "when no\ntrigger fires it proceeds to FINALIZE with caller-owned evidence",
        ),
        "LIGHT cleanup-to-verifier topology contract",
    )
    review = markdown_section(ralph, "## Review Gate")
    require(
        ralph_path,
        review,
        (
            "Overall verdict",
            "blocking finding IDs",
            "reviewed revision binding",
            "Verification verdict",
            "verified revision binding",
            "Reviewer approval of the fixed revision is NOT required and MUST NOT be requested",
            "the verifier pass (or accepted pass-with-residual-risk) binds to the FIXED revision with a per-finding resolution audit",
            "blocking reviewer findings: none | fix-applied (manifest mapped) | blocking",
            "verifier bound revision: reviewed | fixed",
            "either role's `blocked` verdict pauses",
            "A triggered audit MUST run in a separate context",
            "Independent\nverifier: dispatch-unavailable",
            "transition to PAUSED",
            "cannot\ncount as a triggered independent audit",
            "focused `executor` assignment",
            "reviewer never applies the fix or advances the FSM",
        ),
        "review-to-executor ownership contract",
    )
    # 2026-07-29: the verifier is no longer mandatory per mode/same-maker. One
    # canonical named-trigger predicate is the sole selector, so pin the
    # predicate and its explicit non-triggers instead of the retired
    # "LIGHT always needs a verifier" wording.
    require(
        ralph_path,
        review,
        (
            "### Independent Verifier Trigger Predicate",
            "This predicate is the ONLY authority that selects the independent `verifier`",
            "an accepted blocking review finding was fixed",
            "Explicit NON-TRIGGERS",
            "the selected execution mode, including THOROUGH; task size",
            "accepted by the same agent; a `code-reviewer` having run, or not run; and\ncompletion being imminent",
            "Independent verifier: not-required (no trigger fired: <reason>)",
        ),
        "canonical verifier trigger-predicate contract",
    )
    require(
        ralph_path,
        review,
        (
            "not-required (LIGHT: code review waived)",
            "a verifier joins that path only when the predicate fires",
        ),
        "LIGHT reviewer-waived + trigger-gated verifier contract",
    )
    # A triggered audit still cannot be satisfied inline or by an absent host.
    require(
        ralph_path,
        review,
        (
            "A triggered audit MUST run in a separate context",
            "they cannot\ncount as a triggered independent audit",
        ),
        "triggered verifier independence contract",
    )
    # Guard the superseded mandatory-verifier polarity from returning, and guard
    # the new predicate from being weakened back into a mode/maker default.
    for forbidden in (
        "run also requires that independent verifier audit",
        "the verifier is NEVER waived in LIGHT",
        "authored or accepted by the same agent, an\nindependent",
        "required at STANDARD/THOROUGH when the proving tests",
    ):
        if forbidden in review:
            die(
                f"{ralph_path} violates canonical verifier trigger-predicate "
                f"contract (retired mandatory-verifier wording): {forbidden!r}"
            )
    persistence = markdown_section(ralph, "## Persistence Rule")
    require(
        ralph_path,
        persistence,
        (
            # 2026-07-30: completion is evidence-bound, not mode-bound. Every
            # mutation shows either dispatch evidence or ONE recorded inline
            # reason; silence is not a completion path in any mode.
            "every repository work-product mutation shows dispatched-executor evidence, or\n"
            "  one recorded inline fallback reason (LIGHT-tiny or dispatch-unavailable) per\n"
            "  inline edit; an unrecorded inline mutation cannot complete in any mode",
        ),
        "mutation-evidence completion contract",
    )
    require(
        ralph_path,
        persistence,
        (
            # A fired trigger still fails closed; an unfired one must name its
            # compliant reason rather than silently omitting the verifier row.
            "compliantly not-required",
            "`not-required (no trigger fired: <reason>)` is recorded",
            "For a fired trigger,\n  `dispatch-unavailable` is a blocker",
            "cannot satisfy completion",
            "Diff-Budget is `passed@<current stabilized fingerprint>`",
        ),
        "required verifier fail-closed completion contract",
    )
    # M4 item 2 (2026-07-29): compaction is proportional to what actually ran, not
    # to the tier. ANY run may compact the four criteria into one line when all
    # four are compliant not-required / mode-based not-required / no-candidate /
    # no-trigger records; an entry
    # that actually ran or blocked stays individual with its own evidence.
    require(
        ralph_path,
        persistence,
        (
            "the required reviewer pass, the independent verifier pass, simplify, and verification-before-completion",
            "ANY run may compact the four named criteria into one combined ledger line when",
            "EVERY part is a compliant not-required / mode-based not-required / no-candidate / no-trigger record with\nits reason",
            "nothing was actually dispatched or run for any of the four",
            "one of the four actually ran or blocked, that entry stays individual with its own\nevidence",
        ),
        "proportional completion-ledger compaction contract",
    )
    if "A LIGHT run with no behavior change may compact the four named criteria" in persistence:
        die(
            f"{ralph_path} violates proportional completion-ledger compaction "
            "contract: retains the LIGHT-only compaction restriction"
        )
    for forbidden in (
        "Implement inline or dispatch `executor`",
        "| EXECUTE (focused fix + focused re-check only) |",
    ):
        if forbidden in ralph:
            die(f"{ralph_path} retains forbidden inline-maker wording: {forbidden!r}")

    # 2026-07-29: the completion audit reads evidence; nearing the end of a run
    # must not become a licence to dispatch, rerun, or grow proof.
    require(
        ralph_path,
        markdown_section(ralph, "## Completion Stop"),
        (
            "The COMPLETION_AUDIT is EVIDENCE-ONLY",
            "reuses\nfresh revision-bound evidence",
            "Imminent completion is NOT a trigger",
            "MUST NOT dispatch a role, rerun a passing check, or add a test merely because\nthe run is about to finish",
            "only name a missing-evidence blocker when a\nrequired row is actually stale, missing, or conflicting",
        ),
        "evidence-only completion-audit contract",
    )

    executor_path = agent_core / "executor.md"
    executor = read_text(executor_path)
    require(
        executor_path,
        executor,
        (
            "Result: implemented | blocked | failed",
            "Mutation status: none | partial | complete",
            "Packet ID: <echo when supplied | not supplied — direct workflow>",
            "Run/session ID: <echo when supplied | not supplied — direct workflow>",
            "Story/task ID: <echo when supplied | not supplied — direct workflow>",
            "Executor assignment ID: <echo when supplied | not supplied — direct workflow>",
            "stable Executor assignment ID across one TDD cycle",
            "Target revision/diff fingerprint received",
            "Result revision/diff fingerprint",
            "Structured change manifest",
            "not story completion, AC acceptance",
            "never collapse, abbreviate",
            # 2026-07-29: `implemented` may never ride along with an unfinished
            # mutation, so a partial result cannot be reported as completion.
            "ONLY\npaired with `Mutation status: complete`",
            "is a contract violation",
            "a partial mutation\nis `blocked` or `failed`, never completion",
        ),
        "executor result envelope",
    )
    require(
        executor_path,
        executor,
        (
            "when any safety-critical field is missing, stale, contradictory, or misrouted",
            "`.oh-no` paths as read-only inputs",
            "caller owns all `.oh-no` state updates",
            "direct non-Ralph caller",
            "explicit work location",
        ),
        "executor identity/state boundary",
    )

    # The retired delegated-executor transport had a raw-output envelope check.
    # Its still-meaningful identity/revision boundary is now covered above against
    # the surviving executor role; exact inventory rejects transport reintroduction.

    # CR-1 (2026-07-29): the Codex adapters are host mechanics only and must not
    # re-home a pair-by-default topology that contradicts the core default.
    for adapter_name, adapter_markers in {
        "codex-ralph.md": (
            "ONE full-role code-reviewer on Codex when review is required",
            "recorded as single-reviewer",
            "ONLY a\n            named security, data,",
            "Pair-specific mechanics apply ONLY when that named pair trigger actually fired",
            "An explicitly selected pair keeps strict fallback",
        ),
        "codex-ralplan.md": (
            "ONE required full-role Plan-Reviewer instance on Codex by default",
            "recorded as single-reviewer",
            "paired-review\n            trigger escalates to the perspective-diverse Plan-Reviewer pair",
            "Pair-specific mechanics apply ONLY when that named paired-review trigger",
            "An explicitly selected pair keeps strict fallback",
        ),
        "codex-verification-before-completion.md": (
            "record `single-reviewer` for the\n   default one full-role Codex review",
            "ONE full-role instance by default, escalating to a perspective-diverse pair only on the named trigger",
            "Pair-specific mechanics apply ONLY when that named trigger actually fired",
            "An explicitly selected pair keeps strict fallback",
        ),
    }.items():
        adapter_path = platforms / adapter_name
        adapter_body = read_text(adapter_path)
        require(
            adapter_path,
            adapter_body,
            adapter_markers,
            "codex adapter single-reviewer default contract",
        )
        for forbidden in (
            "one perspective-diverse code-reviewer pair when review is required",
            "one perspective-diverse Plan-Reviewer pair, unconditionally",
            "every dispatched review runs as a perspective-diverse pair",
        ):
            if forbidden in adapter_body:
                die(
                    f"{adapter_path} violates codex adapter single-reviewer default "
                    f"contract (retired pair-by-default wording): {forbidden!r}"
                )

    # CR-1 cross-host (M3.1): the Claude adapters' Model Diversity Pair mechanics
    # are pair-only. They must not re-home pair-by-default dispatch, and the
    # ordinary single-reviewer path must stay explicit (one stored-primary
    # reviewer, no diversity leg).
    for adapter_name, role_name in (
        ("claude-code-ralph.md", "code-reviewer"),
        ("claude-code-ralplan.md", "plan-reviewer"),
        ("claude-code-verification-before-completion.md", "code-reviewer"),
    ):
        adapter_path = platforms / adapter_name
        adapter_body = read_text(adapter_path)
        require(
            adapter_path,
            adapter_body,
            (
                "This section applies ONLY when the core selected `perspective-pair` after a",
                f"dispatch exactly ONE full-role `{role_name}` using the declared stored",
                "with NO diversity leg, NO model override, and no",
                "Once a pair is actually selected,",
                # Pair mechanics must survive intact once a pair IS selected.
                "requested in a single batch",
                "model-diversity-pair",
                "same-model-parallel-fallback",
                "require-model-diversity",
                "transition to PAUSED",
            ),
            "claude adapter pair-only diversity contract",
        )
        for forbidden in (
            "For any dispatched `code-reviewer` pair (every dispatched review)",
            "For the THOROUGH `plan-reviewer` pair (every dispatched THOROUGH review)",
        ):
            if forbidden in adapter_body:
                die(
                    f"{adapter_path} violates claude adapter pair-only diversity "
                    f"contract (retired pair-by-default wording): {forbidden!r}"
                )

    # CR-1 cross-host (M3.2): the SHARED Claude runtime doc feeds many generated
    # skills, so a pair-by-default phrase here leaks into all of them.
    shared_runtime_path = platforms / "claude-code-runtime.md"
    shared_runtime = read_text(shared_runtime_path)
    if "(every dispatched review)" in shared_runtime:
        die(
            f"{shared_runtime_path} violates shared runtime pair-only diversity "
            "contract: retains retired '(every dispatched review)' wording"
        )

    # V-1 (failed-verification correction): the Codex Ultrawork adapter implements
    # only the core-selected topology and must not re-home a pair-by-default
    # Final Validation review.
    codex_ultrawork_path = platforms / "codex-ultrawork.md"
    codex_ultrawork = read_text(codex_ultrawork_path)
    require(
        codex_ultrawork_path,
        codex_ultrawork,
        (
            "implements only the topology the core already selected; it never\nselects topology itself",
            "the default in STANDARD and THOROUGH alike — dispatches exactly ONE full-role",
            "records `single-reviewer`",
            "ONLY after the core's named paired-review trigger fired",
            # Pair mechanics must survive once a pair IS selected.
            "Once a pair is actually selected, spawn both legs before waiting",
            "same-host-perspective-pair",
            "same-host-parallel-fallback",
            "`require-cross-host` pauses",
        ),
        "codex ultrawork single-reviewer default contract",
    )
    for forbidden in (
        "Every dispatched Final Validation `code-reviewer` review runs as one",
        "STANDARD uses two Codex reviewers",
    ):
        if forbidden in codex_ultrawork:
            die(
                f"{codex_ultrawork_path} violates codex ultrawork single-reviewer "
                f"default contract (retired pair-by-default wording): {forbidden!r}"
            )

    # 2026-07-29: the planning read-only roles carry the same one-when-one-suffices
    # floor as Ralph, so a single question does not fan out to five subagents. The
    # separate-context Plan-Reviewer rationale is unaffected.
    ralplan_path = skill_core / "ralplan.md"
    require(
        ralplan_path,
        markdown_section(read_text(ralplan_path), "## Agent Roles"),
        (
            "one instance when one covers the question",
            "one instance when one covers the gaps",
            "one per genuinely independent subsystem (up to 5), batched",
            "one per genuinely independent requirement or risk area (up to 5), batched",
        ),
        "one-when-one-suffices planning-role floor",
    )
    # Interview's brownfield `explore` row carries the same floor; its inline
    # too-small-to-separate carve-out is unaffected.
    interview_path = skill_core / "interview.md"
    require(
        interview_path,
        markdown_section(read_text(interview_path), "## Agent Roles"),
        (
            "one instance when one covers the question",
            "one per genuinely independent subsystem (up to 5), batched",
        ),
        "one-when-one-suffices planning-role floor",
    )
    # 2026-07-30: the floor lives in the `explore` ROLE ROW of every core that
    # dispatches it, not only in surrounding prose. Ralph's execution loop and
    # systematic-debugging's prose already carried it, so the row was the one
    # place a reader could consult and see no bound at all.
    debugging_explore_path = skill_core / "systematic-debugging.md"
    require(
        debugging_explore_path,
        markdown_section(read_text(debugging_explore_path), "## Agent Roles"),
        (
            "one instance when one covers the question",
            "one per genuinely independent subsystem (up to 5), batched",
        ),
        "one-when-one-suffices explore-row floor",
    )
    require(
        ralph_path,
        markdown_section(ralph, "## Agent Roles"),
        (
            "one instance when one covers the question",
            "genuinely independent read-only targets as one parallel batch (up to 5)",
        ),
        "one-when-one-suffices explore-row floor",
    )
    # Ralplan's optional-role inline fallback must admit the need-based reason,
    # not only host-unavailability and structural ineligibility. Without it a
    # small bounded planning lookup had no compliant inline path.
    require(
        ralplan_path,
        read_text(ralplan_path),
        ("the work is too\nsmall to benefit from context separation",),
        "planning-role need-based inline reason",
    )

    # V-2 / V-3: topology is risk-selected, never mode-selected, and a named
    # trigger decides whether the pair exists (not merely its diversity).
    for stale_path, stale_label in (
        (skill_core / "ultrawork.md", "ultrawork"),
        (skill_core / "ralplan.md", "ralplan"),
    ):
        stale_body = read_text(stale_path)
        for forbidden in ("mode-selected topology", "Topology by mode"):
            if forbidden in stale_body:
                die(
                    f"{stale_path} retains stale mode-selected review topology "
                    f"wording ({stale_label}): {forbidden!r}"
                )
    if "selects only escalated platform diversity" in read_text(skill_core / "ultrawork.md"):
        die(
            "ultrawork.md retains stale 'selects only escalated platform diversity' "
            "wording: the named trigger selects whether the pair exists, then its diversity"
        )

    # CR-2 (2026-07-29): Ultrawork Final Validation follows the same trigger-gated
    # verifier predicate and single-reviewer default as the cores it composes.
    ultrawork_final_validation_body = markdown_section(
        read_text(skill_core / "ultrawork.md"), "### FINAL_VALIDATION"
    )
    require(
        skill_core / "ultrawork.md",
        ultrawork_final_validation_body,
        (
            "it runs as ONE full-role `code-reviewer` by default and records\n`single-reviewer`",
            "ONLY a named security, data, destructive, public-contract,",
            "Reviewer count is never a quality proxy",
            "`verification-before-completion`'s V4 trigger predicate fires",
            "are explicit NON-triggers",
            "Independent verifier: not-required (no trigger fired: <reason>)",
            "reuse the\nfresh revision-bound evidence instead of re-proving it",
            "- code-reviewer topology: not-required | single-reviewer | perspective-pair",
            "- verifier trigger: none | <named V4 trigger>",
        ),
        "ultrawork trigger-gated Final Validation contract",
    )
    for forbidden in (
        "having been authored or accepted by the same agent, require the audit",
        "it runs as the perspective-diverse pair and records",
    ):
        if forbidden in ultrawork_final_validation_body:
            die(
                "ultrawork.md violates ultrawork trigger-gated Final Validation "
                f"contract: {forbidden!r}"
            )

    # CR-3 (2026-07-29): completion criteria bind an approved expansion to its
    # revised manifest ID and reissued packet, not the retired capsule term.
    if "current capsule" in ralph:
        die(
            f"{ralph_path} violates expansion manifest-revision completion "
            "contract: retains retired 'current capsule' terminology"
        )
    require(
        ralph_path,
        markdown_section(ralph, "## Persistence Rule"),
        (
            "records its approval owner, was approved, and was bound to a revised Mutation",
            "Manifest ID recorded in the snapshot and reissued to the executor as",
            "`Expansion status: approved@<revision id> -> incorporated before mutation`",
        ),
        "expansion manifest-revision completion contract",
    )

    reviewer_path = agent_core / "code-reviewer.md"
    reviewer = read_text(reviewer_path)
    require(
        reviewer_path,
        reviewer,
        (
            "Overall verdict: approve | blocking-findings | blocked",
            "Reviewed revision/diff fingerprint:",
            "Blocking finding IDs:",
            "Packet ID: <echo when supplied | not supplied — direct workflow>",
            "verdict is caller input",
            "never collapses, abbreviates",
        ),
        "code-reviewer verdict/revision envelope",
    )
    # 2026-07-29: blocking requires a demonstrated CURRENT material failure, and
    # a single reviewer owns the whole role while a paired leg owns depth without
    # suppressing an obvious out-of-perspective blocker.
    require(
        reviewer_path,
        reviewer,
        (
            "only when you can demonstrate a\n  material failure in the CURRENT change",
            "A speculative or plausible FUTURE regression, absent\n  a demonstrated current failure, is non-blocking",
            "With NO `Assigned perspective:` line you are the single reviewer: run the\ncomplete role across both ordered lenses",
            "OWN DEPTH on\nyour assigned perspective",
            "Still report any obvious material blocker you\nnotice outside your perspective",
            "never a\npass filter that suppresses a real blocker",
            "A dispatched review is ONE full-role reviewer by default",
        ),
        "code-reviewer demonstrated-failure and single/paired depth contract",
    )
    if "blocking when they can plausibly create" in reviewer:
        die(
            f"{reviewer_path} retains the retired speculative future-regression "
            "blocking route"
        )

    verifier_path = agent_core / "verifier.md"
    verifier = read_text(verifier_path)
    require(
        verifier_path,
        verifier,
        (
            "Verification verdict: pass | pass-with-residual-risk | fail | blocked",
            "Verified revision/diff fingerprint:",
            "Packet ID: <echo when supplied | not supplied — direct workflow>",
            "Unconditionally read-only",
            "No assignment or tool availability creates a write exception",
            "mutate any file",
            "proposed ledger delta",
            "never collapse, abbreviate",
        ),
        "verifier read-only verdict/revision envelope",
    )
    for forbidden in (
        "unless explicitly assigned by the current skill",
        "Fill missing/stale audit status",
    ):
        if forbidden in verifier:
            die(f"{verifier_path} contains verifier read-only loophole: {forbidden!r}")
    if "verifier" not in READ_ONLY_CODEX_AGENT_ROLES:
        die("verifier read-only contract is not host-enforced in Codex metadata")

    plan_reviewer_path = agent_core / "plan-reviewer.md"
    plan_reviewer = read_text(plan_reviewer_path)
    require(
        plan_reviewer_path,
        plan_reviewer,
        (
            "Unconditionally read-only",
            "No assignment or tool availability creates a write exception",
            "generator's `--write`",
        ),
        "plan-reviewer read-only review envelope",
    )
    # 2026-07-29: pass 2 is a draft-oriented quality gate, not a self-audit of
    # pass-1 conclusions; single vs. paired depth mirrors the code reviewer.
    require(
        plan_reviewer_path,
        plan_reviewer,
        (
            "quality-gate pass over the draft. Both passes examine the draft; the\nquality-gate pass does NOT re-audit your own pass-1 conclusions",
            "Examine the DRAFT for weak evidence, direction drift, and overcomplication",
            "Do not re-verify, re-litigate, or restate your pass-1 conclusions",
            "With NO `Assigned perspective:` line you are the single reviewer: run the\ncomplete two-pass role",
            "OWN DEPTH on your assigned\nperspective",
            "Still report any obvious material blocker you notice outside\nyour perspective",
            "A dispatched review is ONE required reviewer instance running the complete\ntwo-pass role by default",
        ),
        "plan-reviewer draft-oriented quality gate and single/paired depth contract",
    )
    for forbidden in (
        "Re-examine pass 1 for rubber-stamping",
        "quality-gate pass over the draft and your pass-1 conclusions",
    ):
        if forbidden in plan_reviewer:
            die(
                f"{plan_reviewer_path} retains the retired pass-1 self-recheck: "
                f"{forbidden!r}"
            )
    for forbidden in (
        "unless explicitly assigned by the current skill",
        "may run the generator",
    ):
        if forbidden in plan_reviewer:
            die(
                f"{plan_reviewer_path} contains plan-reviewer read-only loophole: {forbidden!r}"
            )

    ralplan_path = skill_core / "ralplan.md"
    ralplan = read_text(ralplan_path)
    require(
        ralplan_path,
        markdown_section(ralplan, "## Execution Profile"),
        (
            "For repository work-product mutation, `Agent policy: inline-only` is valid",
            "STANDARD/THOROUGH repository work-product mutation plans",
            "executor ownership survives even when `Parallel trigger: none`",
            "`none` means no concurrent batch, not inline mutation",
            "Ralph remains the execution orchestrator",
        ),
        "Ralplan inline-only/executor ownership contract",
    )
    require(
        ralplan_path,
        markdown_section(ralplan, "## Next Skill Handoff"),
        (
            "preserves the plan path and\n  the exact frozen `Parallel trigger` value",
            "When that value is\n  `approved-plan-handoff`",
            "`none` preserves sequential\n  executor ownership without authorizing a concurrent batch",
        ),
        "Ralplan frozen parallel-trigger handoff contract",
    )
    if "otherwise use `inline-only` and\n`none`" in ralplan:
        die(f"{ralplan_path} retains stale inline-only fallback semantics")

    simplify_path = skill_core / "simplify.md"
    simplify = read_text(simplify_path)
    require(
        simplify_path,
        markdown_section(simplify, "## Phase 1 - Review"),
        ("read-only discovery", "do not edit repository work product or\n`.oh-no` state"),
        "simplify read-only discovery ownership",
    )
    require(
        simplify_path,
        markdown_section(simplify, "## Phase 2 - Apply The Fixes"),
        (
            "dispatch one scoped `executor` assignment",
            "executor's required envelope",
            "behavior lock plus accepted\ncleanup finding IDs",
            "Mutation fallback: LIGHT-tiny",
            "Mutation fallback: dispatch-unavailable",
            "`.oh-no` state and finding dispositions remain caller-owned",
        ),
        "simplify executor-apply ownership",
    )
    if "fix each remaining\nbehavior-preserving cleanup directly" in simplify:
        die(f"{simplify_path} retains direct cleanup mutation")

    tdd_path = skill_core / "test-driven-development.md"
    tdd = read_text(tdd_path)
    require(
        tdd_path,
        markdown_section(tdd, "## Execution Ownership"),
        (
            "one stable `Executor assignment ID`",
            "RED, GREEN, and REFACTOR",
            "preserve and echo that assignment ID",
            "each Packet ID remains\nunique",
            "caller remains the orchestrator",
            "updates `.oh-no` evidence",
            "Mutation status: complete` is not TDD or AC acceptance",
        ),
        "persistent TDD executor ownership",
    )

    debugging_path = skill_core / "systematic-debugging.md"
    debugging = read_text(debugging_path)
    require(
        debugging_path,
        debugging,
        (
            "confirmed repository work-product\n    fixes dispatch `executor`",
            "Apply the minimal fix through `executor` by default",
            "Mutation fallback: LIGHT-tiny",
            "Mutation fallback:\n   dispatch-unavailable",
            "executor-default minimal fix",
            "target role's\nrequired identity/result envelope",
            "initial debugger packet contains the raw reproduction",
            "withholds the caller's\npreferred cause or fix and all sibling conclusions",
            "Executor fix packets may include the independently\nconfirmed root cause",
        ),
        "systematic-debugging executor-default ownership",
    )
    if "`executor` subagent when the write scope is\n   isolated, otherwise inline" in debugging:
        die(f"{debugging_path} retains isolation-optional executor ownership")

    # M4 item 1 (2026-07-29): systematic-debugging follows the same proportionality
    # policy as Ralph/VBC — one named-trigger predicate selects the post-fix
    # verifier (same authorship is an explicit NON-trigger), and post-fix review is
    # ONE full-role instance unless a named high-risk trigger buys the pair.
    require(
        debugging_path,
        debugging,
        (
            "### Independent Verifier Trigger Predicate",
            "This predicate is the ONLY authority that selects the post-fix `verifier`",
            "an accepted blocking review finding was fixed",
            "Explicit NON-TRIGGERS",
            "the proving reproduction tests or fix having been authored or\naccepted by the same agent",
            "Independent verifier: not-required (no trigger fired: <reason>)",
            "the verifier is a single\nself-host independent pass, never a pair",
            "ONE full-role instance by default, escalating to a perspective-diverse pair only on the named high-risk trigger",
            "is ONE full-role instance by\ndefault, recorded `single-reviewer`",
            "Reviewer count is never\na quality proxy",
            "records `single-reviewer` by default, or `perspective-pair` plus\nits named firing trigger",
        ),
        "systematic-debugging trigger-gated review and verifier contract",
    )
    for forbidden in (
        "required when the proving tests or fix were authored or accepted by the same agent",
        "when dispatched, runs as the perspective-diverse pair",
        "always runs as the\nperspective-diverse pair",
        "code-reviewer records `perspective-pair` with the active platform's pair-mode",
    ):
        if forbidden in debugging:
            die(
                f"{debugging_path} violates systematic-debugging trigger-gated "
                f"review and verifier contract (retired wording): {forbidden!r}"
            )

    # The two systematic-debugging adapters implement only the core-selected
    # topology; neither may re-home a pair-by-default or same-maker verifier rule.
    debug_codex_path = platforms / "codex-systematic-debugging.md"
    debug_codex = read_text(debug_codex_path)
    require(
        debug_codex_path,
        debug_codex,
        (
            "spawns exactly ONE full-role Codex reviewer, recorded as single-reviewer",
            "Pair-specific mechanics apply ONLY when that named pair trigger actually fired",
            "dispatched only on a named trigger from the core's verifier predicate",
            "An explicitly selected pair keeps strict fallback",
            "The `verifier` is never paired.",
            # Pair mechanics must survive intact once a pair IS selected.
            "same-host-perspective-pair",
            "same-host-parallel-fallback",
        ),
        "codex systematic-debugging single-reviewer default contract",
    )
    for forbidden in (
        "Every dispatched post-fix `code-reviewer` review\ninstead runs as an intentional same-host perspective pair",
        "required when the proving tests or fix were authored or accepted by the same agent",
    ):
        if forbidden in debug_codex:
            die(
                f"{debug_codex_path} violates codex systematic-debugging "
                f"single-reviewer default contract (retired wording): {forbidden!r}"
            )
    debug_claude_path = platforms / "claude-code-systematic-debugging.md"
    debug_claude = read_text(debug_claude_path)
    require(
        debug_claude_path,
        debug_claude,
        (
            "This section applies ONLY when the core selected `perspective-pair` after a",
            "dispatch exactly ONE\nfull-role `code-reviewer` using the declared stored primary",
            "with NO diversity\nleg, NO model override, and no `Assigned perspective:` line",
            "Once a pair is actually selected,",
            # Pair mechanics must survive intact once a pair IS selected.
            "requested in a single batch",
            "model-diversity-pair",
            "same-model-parallel-fallback",
            "require-model-diversity",
            "transition to PAUSED",
        ),
        "claude systematic-debugging pair-only diversity contract",
    )
    if "(every dispatched review)" in debug_claude:
        die(
            f"{debug_claude_path} violates claude systematic-debugging pair-only "
            "diversity contract: retains retired '(every dispatched review)' wording"
        )

    ultrawork_path = skill_core / "ultrawork.md"
    ultrawork = read_text(ultrawork_path)
    require(
        ultrawork_path,
        ultrawork,
        (
            "When Ralph is unavailable",
            "repository mutation still dispatches `executor` by\n    default under Ralph's need test",
            "a fired review or audit trigger is\n    exempt from the need test and never runs inline",
            "Ralph-unavailable fallback",
            "Ultrawork still owns `.oh-no` state and gate decisions",
            "inline mutation is only a recorded\nLIGHT-tiny or dispatch-unavailable fallback",
            "target role's required identity/result envelope",
            "phase, source plan/spec, and phase-owned\nscope",
            "`dispatch-unavailable` blocker and pause",
            "inline evidence cannot satisfy it",
        ),
        "Ultrawork Ralph-unavailable executor ownership",
    )
    ultrawork_final_validation = markdown_section(ultrawork, "### FINAL_VALIDATION")
    # Check the retired order-free phrasing first so a revert reports the exact
    # regression instead of a generic missing-marker message.
    forbidden = r"independent `verifier` pass when it covers\s+the final orchestrated revision"
    if re.search(forbidden, ultrawork, flags=re.IGNORECASE):
        die(
            f"{ultrawork_path} retains order-free Ralph verifier reuse wording: {forbidden!r}"
        )
    # Pin the whole mutually exclusive decision verbatim, not its keywords: the
    # `only when all hold ... ; otherwise dispatch one fresh` shape is what stops
    # the paragraph from reading as an unconditional fresh dispatch plus an
    # optional reuse offer, and the full early/stale sentence is what stops a
    # token-preserving flip ("remains valid", "even when none hold").
    require(
        ultrawork_path,
        ultrawork_final_validation,
        (
            "A fired trigger is satisfied through exactly one of two\nmutually exclusive paths.",
            "Reuse Ralph's independent `verifier` pass only when\nall hold: it covers the same final claim and revision, it was an independent\ndispatch, it ran after the selected Final Validation code-review stage completed\nor that review is compliantly not-required, and no file, dependency, or evidence\nchanged since that pass; otherwise dispatch one fresh self-host `verifier` pass.",
            "If Ultrawork dispatches its own `code-reviewer`, Ralph's prior verifier is\nearly/stale by construction, so reuse is unavailable and the fresh self-host\n`verifier` pass runs after reviewer synthesis and any fix manifest, bound to the\nreviewed/fixed revision.",
            "verifier source: fresh | reused@<ralph ledger entry + revision binding>",
        ),
        "Ultrawork mutually exclusive verifier reuse contract",
    )

    vbc_path = skill_core / "verification-before-completion.md"
    vbc = read_text(vbc_path)
    require(
        vbc_path,
        vbc,
        (
            "separate-context independent `verifier` audit",
            "target role's required identity/result envelope",
            "standalone invocation",
            "adapters pass that packet\nunchanged",
            "`dispatch-unavailable` as a blocker",
            "return blocked/PAUSED",
            "inline command reruns cannot satisfy the audit",
        ),
        "verification-before-completion independent-audit contract",
    )
    # 2026-07-29: the audit is trigger-gated, and fresh revision-bound evidence
    # is reused rather than re-proven just because a claim is imminent.
    require(
        vbc_path,
        vbc,
        (
            "An independent `verifier` audit is required only when a named trigger\n    fires",
            "reviewer presence, and imminent completion are explicit NON-triggers",
            "Fresh revision-bound reviewer, verifier, and command evidence is reused as\n    recorded",
            "Completion imminence alone never justifies a rerun, an added\n    test, or a fresh dispatch",
            "Dispatch `verifier` only when a named V4 trigger fires; nontriviality alone is\nnot one",
            "Independent verifier: not-required (no trigger fired: <reason>)",
            "ONE full-role instance by default",
        ),
        "verification-before-completion trigger-gated verifier and evidence-reuse contract",
    )
    if "authored or accepted by the current agent, an\n    independent" in vbc:
        die(
            f"{vbc_path} retains the retired same-maker mandatory-verifier rule"
        )
    for adapter_name in (
        "claude-code-verification-before-completion.md",
        "codex-verification-before-completion.md",
    ):
        adapter_path = platforms / adapter_name
        require(
            adapter_path,
            read_text(adapter_path),
            (
                "core-defined role envelope",
                "verification delta unchanged",
                "core does not require an independent audit",
                "`dispatch-unavailable` blocker",
                "blocked/PAUSED",
            ),
            "verification-before-completion adapter fail-closed contract",
        )

    for adapter_name in ("claude-code-ralph.md", "codex-ralph.md"):
        adapter_path = platforms / adapter_name
        adapter = read_text(adapter_path)
        require(
            adapter_path,
            markdown_section(adapter, "## Executor-Default Trigger"),
            (
                "STANDARD/THOROUGH repository work-product mutation",
                "Parallel trigger: none",
                "controls concurrency, not sequential executor ownership",
                "REVIEW-to-EXECUTE focused fixes",
                "LIGHT-tiny or dispatch-unavailable fallback",
            ),
            "Ralph adapter executor-default trigger",
        )
    for adapter_name in ("claude-code-simplify.md", "codex-simplify.md"):
        adapter_path = platforms / adapter_name
        require(
            adapter_path,
            read_text(adapter_path),
            ("combined depth", "one combined pass", "four-viewpoint depth", "before waiting"),
            "Simplify platform pass shape",
        )
    codex_adapter = read_text(platforms / "codex-ralph.md")
    require(
        platforms / "codex-ralph.md",
        codex_adapter,
        (
            'Spawn with `fork_turns="none"`',
            "host exposes `close_agent`",
            "MUST NOT call `close_agent` for a running or pending",
        ),
        "Codex lifecycle preservation",
    )

    hook_path = root / "hooks" / "session-start"
    hook = read_text(hook_path)
    bootstrap_sentence = (
        "Orchestration default: main agents own .oh-no state/gates; "
        "STANDARD/THOROUGH repository mutations use executors, except recorded "
        "LIGHT-tiny or dispatch-unavailable inline fallback."
    )
    bootstrap_start = hook.find("bootstrap_policy='")
    forced_start = hook.find('auto_routing_policy=""')
    if bootstrap_start < 0 or forced_start < 0 or forced_start <= bootstrap_start:
        die(f"{hook_path} cannot locate unconditional bootstrap_policy")
    bootstrap_block = hook[bootstrap_start:forced_start]
    if bootstrap_sentence not in bootstrap_block or hook.count(bootstrap_sentence) != 1:
        die(f"{hook_path} must place one orchestration sentence in unconditional bootstrap_policy")
    codex_policy_blocks = {
        "CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION": re.search(
            r"<CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION>.*?</CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION>",
            hook,
            flags=re.DOTALL,
        ),
        "CODEX_ONLY_OH_NO_READONLY_EXPLORATION_DELEGATION": re.search(
            r"<CODEX_ONLY_OH_NO_READONLY_EXPLORATION_DELEGATION>.*?</CODEX_ONLY_OH_NO_READONLY_EXPLORATION_DELEGATION>",
            hook,
            flags=re.DOTALL,
        ),
    }
    for block_name, match in codex_policy_blocks.items():
        if not match or match.group(0).count('fork_turns="none"') != 1:
            die(f"{hook_path} must place one fork_turns=none rule in {block_name}")
    if hook.count('fork_turns="none"') != 2:
        die(f"{hook_path} must keep fork_turns=none only in the two Codex dispatch authorization blocks")

    cross_host_path = platforms / "cross-host-review.md"
    cross_host = read_text(cross_host_path)
    if "docs/shared/ralph-subagent-policy.md" in cross_host:
        die(f"{cross_host_path} retains stale ralph-subagent-policy reference")
    require(
        cross_host_path,
        cross_host,
        (
            "docs/skill-core/ralph.md",
            "## Mode-Gated Agent Dispatch",
            "existing exact result envelope",
            "<host>:<finding-id>",
            "never satisfies Ralplan's required Plan-Reviewer",
        ),
        "current Ralph core owner reference",
    )
    # M4 item 3 (2026-07-29): these two hand-maintained references must state the
    # shipped contract — single-reviewer default, pair only on a named trigger,
    # verifier only on its named trigger predicate (single self-host when fired).
    require(
        cross_host_path,
        cross_host,
        (
            "is ONE full-role instance\nby default and records `single-reviewer`",
            "A perspective-diverse pair exists only after the calling skill\nrecords its named high-risk or paired-review trigger",
            "it never creates a pair",
            "A `verifier` is a dependent later stage that exists\nonly when the calling skill's named verifier trigger predicate fires",
            "are explicit NON-triggers",
            "not-required (no trigger fired: <reason>)",
            "A triggered `verifier` is always a\nsingle self-host independent pass",
        ),
        "cross-host reference proportional review contract",
    )
    for forbidden in (
        "Every dispatched `code-reviewer` review, and every dispatched THOROUGH\n`plan-reviewer` review, uses a\nperspective-diverse pair",
        "the ordinary dispatched review\nstill runs its perspective pair as `same-host-perspective-pair`",
        "The confirming `verifier` is an unconditionally",
        "the intentional STANDARD same-host pair",
        "every dispatched post-fix `code-reviewer` uses a perspective pair",
    ):
        if forbidden in cross_host:
            die(
                f"{cross_host_path} violates cross-host reference proportional "
                f"review contract (retired pair-by-default wording): {forbidden!r}"
            )
    claude_reference_path = platforms / "claude-code.md"
    claude_reference = read_text(claude_reference_path)
    require(
        claude_reference_path,
        claude_reference,
        (
            "Load this section only after the active core actually SELECTED a pair",
            "It never applies to every dispatched review",
            "the default one full-role\n`single-reviewer` uses the declared stored primary with no diversity leg and no\nmodel override",
            "A `verifier` is never paired.",
        ),
        "claude reference proportional review contract",
    )
    if "(every dispatched review)" in claude_reference:
        die(
            f"{claude_reference_path} violates claude reference proportional review "
            "contract: retains retired '(every dispatched review)' wording"
        )

    generator_path = root.parent.parent / "scripts" / "generate-agent-wrappers.py"
    generator = read_text(generator_path)
    verifier_meta = re.search(
        r'role="verifier"(?P<body>.*?)(?=\n\s*AgentMetadata\()',
        generator,
        flags=re.DOTALL,
    )
    if not verifier_meta or 'codex_sandbox_mode="read-only"' not in verifier_meta.group("body"):
        die(f"{generator_path} must host-enforce verifier read-only Codex metadata")
    code_reviewer_meta = re.search(
        r'role="code-reviewer"(?P<body>.*?)(?=\n\s*AgentMetadata\()',
        generator,
        flags=re.DOTALL,
    )
    if "code-reviewer" not in READ_ONLY_CODEX_AGENT_ROLES:
        die("code-reviewer read-only contract is not host-enforced in Codex validation metadata")
    if not code_reviewer_meta or 'codex_sandbox_mode="read-only"' not in code_reviewer_meta.group("body"):
        die(f"{generator_path} must host-enforce code-reviewer read-only Codex metadata")


def assert_parallel_executor_contract(root: Path) -> None:
    # Parallel-executor-dispatch contract (R1-R6 / AC1-AC4). Section-scoped so a
    # marker cannot be satisfied by unrelated or wrong-section text, and so the
    # canonical homes (bias + per-executor check in the shared policy; loop and
    # dispatch shape in ralph.md) cannot silently drift. Pre-edit docs lack these
    # phrases, so this guard fails before the change and passes after it.
    # docs/shared/ralph-subagent-policy.md retired 2026-07-17: the dispatch
    # bias and per-executor integration check live in the ralph core.
    ralph_policy = read_text(root / "docs" / "skill-core" / "ralph.md")
    for marker in (
        "per-executor scope check",
        "only a stray or risky slice",
    ):
        if not has_required_marker(ralph_policy, marker):
            die(f"ralph.md is missing the per-executor integration marker: {marker!r}")
    ralph_core = read_text(root / "docs" / "skill-core" / "ralph.md")
    loop = markdown_section(ralph_core, "## Execution Loop")
    if not has_required_marker(loop, "scan remaining STANDARD/THOROUGH work for disjoint scopes"):
        die("ralph.md `## Execution Loop` must direct scanning remaining work for disjoint scopes")
    dispatch = markdown_section(ralph_core, "## Mode-Gated Agent Dispatch")
    if not has_required_marker(dispatch, "proactively partition disjoint"):
        die("ralph.md `## Mode-Gated Agent Dispatch` must make proactive disjoint-executor partition first-class")

    platforms = root / "docs" / "platforms"
    for adapter in ("claude-code-ralph.md", "codex-ralph.md"):
        if not has_required_marker(
            read_text(platforms / adapter), "disjoint implementation (executor) work"
        ):
            die(f"{adapter} must list disjoint implementation (executor) work as eligible for a background batch")


def assert_ralplan_proportionality_contract(root: Path) -> None:
    """Guard ralplan's compact approval path and combined execution handoff."""
    skill_core = root / "docs" / "skill-core"
    ralplan_path = skill_core / "ralplan.md"
    ralplan = read_text(ralplan_path)

    plan_requirements = markdown_section(ralplan, "## Plan File Requirements")
    if not plan_requirements:
        die(f"{ralplan_path} is missing required '## Plan File Requirements' section")
    compact_light_plan_match = re.search(
        r"Compact LIGHT plans.*?(?=\n\n|$)",
        plan_requirements,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if not compact_light_plan_match:
        die(
            f"{ralplan_path} `## Plan File Requirements` is missing the "
            "compact LIGHT plan contract"
        )
    compact_light_plan = compact_light_plan_match.group(0)
    for marker in RALPLAN_LIGHT_PLAN_FILE_MARKERS:
        if not has_required_marker(compact_light_plan, marker):
            die(
                f"{ralplan_path} `## Plan File Requirements` is missing "
                f"compact LIGHT plan marker: {marker!r}"
            )
    for marker in RALPLAN_ELIGIBILITY_SURFACE_MARKERS:
        if not has_required_marker(plan_requirements, marker):
            die(
                f"{ralplan_path} `## Plan File Requirements` dispatch fallback "
                f"is missing eligibility marker: {marker!r}"
            )
    for forbidden in RALPLAN_ELIGIBILITY_SURFACE_FORBIDDEN_MARKERS:
        if has_required_marker(plan_requirements, forbidden):
            die(
                f"{ralplan_path} `## Plan File Requirements` still contains "
                f"isolation-only fallback wording: {forbidden!r}"
            )

    brief = markdown_section(ralplan, "## Plan Approval Brief")
    if not brief:
        die(f"{ralplan_path} is missing required '## Plan Approval Brief' section")
    for forbidden in RALPLAN_APPROVAL_BRIEF_FORBIDDEN_MARKERS:
        if has_required_marker(brief, forbidden):
            die(
                f"{ralplan_path} `## Plan Approval Brief` still contains "
                f"retired text-diagram marker: {forbidden!r}"
            )
    for marker in RALPLAN_LIGHT_APPROVAL_BRIEF_MARKERS:
        if not has_required_marker(brief, marker):
            die(
                f"{ralplan_path} `## Plan Approval Brief` is missing "
                f"compact LIGHT approval marker: {marker!r}"
            )
    for marker in RALPLAN_ELIGIBILITY_SURFACE_MARKERS:
        if not has_required_marker(brief, marker):
            die(
                f"{ralplan_path} `## Plan Approval Brief` dispatch fallback "
                f"is missing eligibility marker: {marker!r}"
            )
    for forbidden in RALPLAN_ELIGIBILITY_SURFACE_FORBIDDEN_MARKERS:
        if has_required_marker(brief, forbidden):
            die(
                f"{ralplan_path} `## Plan Approval Brief` still contains "
                f"isolation-only fallback wording: {forbidden!r}"
            )

    execution_profile = markdown_section(ralplan, "## Execution Profile")
    if not execution_profile:
        die(f"{ralplan_path} is missing required '## Execution Profile' section")
    for marker in RALPLAN_APPROVED_PLAN_DEFAULT_MARKERS:
        if not has_required_marker(execution_profile, marker):
            die(
                f"{ralplan_path} `## Execution Profile` approved-plan "
                f"default is missing marker: {marker!r}"
            )

    handoff = markdown_section(ralplan, "## Next Skill Handoff")
    if not handoff:
        die(f"{ralplan_path} is missing required '## Next Skill Handoff' section")
    for marker in RALPLAN_DIRECT_HANDOFF_REQUIRED_MARKERS:
        if not has_required_marker(handoff, marker):
            die(
                f"{ralplan_path} `## Next Skill Handoff` is missing "
                f"no-auto-invocation marker: {marker!r}"
            )
    for pattern, label in RALPLAN_DIRECT_HANDOFF_REQUIRED_PATTERNS:
        if not re.search(pattern, handoff, flags=re.IGNORECASE | re.DOTALL):
            die(
                f"{ralplan_path} `## Next Skill Handoff` is missing "
                f"combined approval option: {label}"
            )
    for forbidden in RALPLAN_DIRECT_HANDOFF_FORBIDDEN_MARKERS:
        if has_required_marker(handoff, forbidden):
            die(
                f"{ralplan_path} `## Next Skill Handoff` still contains "
                f"retired two-phase wording: {forbidden!r}"
            )

    gate_inventory_path = root / "docs" / "reference" / "mandatory-gate-inventory.md"
    gate_inventory = read_text(gate_inventory_path)
    ralplan_row = ""
    for line in gate_inventory.splitlines():
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if cells and cells[0] == "HG-ralplan-handoff":
            ralplan_row = " | ".join(cells)
            break
    if not ralplan_row:
        die(f"{gate_inventory_path} is missing HG-ralplan-handoff inventory row")
    for marker in MANDATORY_GATE_RALPLAN_HANDOFF_ROW_MARKERS:
        if not has_required_marker(ralplan_row, marker):
            die(
                f"{gate_inventory_path} HG-ralplan-handoff row is missing "
                f"combined-gate marker: {marker!r}"
            )
    for pattern, label in MANDATORY_GATE_RALPLAN_HANDOFF_ROW_PATTERNS:
        if not re.search(pattern, ralplan_row, flags=re.IGNORECASE | re.DOTALL):
            die(
                f"{gate_inventory_path} HG-ralplan-handoff row is missing "
                f"combined-gate marker: {label}"
            )


def assert_proportional_workflow_contract(root: Path) -> None:
    """Guard the lightweight steady-state topology and gate-accretion budget."""
    shared = root / "docs" / "shared"
    skill_core = root / "docs" / "skill-core"

    # docs/shared retired 2026-07-17: proportionality semantics are pinned in
    # the self-contained ralph core.
    ralph_body = read_text(skill_core / "ralph.md")
    for marker in (
        "### STANDARD Small-Task Carve-Out",
        "size alone is never sufficient",
        "`Status: provisional`",
        "provisional` at completion-claim time",
    ):
        if not has_required_marker(ralph_body, marker):
            die(f"ralph.md is missing proportional-workflow marker: {marker!r}")

    for skill, markers in {
        "ralplan": (
            "single canonical schema",
            # Risk-selected topology: STANDARD and ordinary THOROUGH each keep
            # ONE required full-role reviewer, and the pair stays reachable only
            # through its named trigger. Both halves are pinned so neither the
            # single-reviewer default nor the triggered pair can be dropped.
            "STANDARD -> one required Plan-Reviewer",
            "THOROUGH -> one required full-role Plan-Reviewer instance by default",
            "selects one perspective-diverse Plan-Reviewer",
            "Reviewer count is never a quality proxy",
        ),
        "ralph": (
            "`verification.md` is the canonical acceptance-to-evidence",
            "ONE full-role `code-reviewer` for behavior-affecting or workflow",
            "Reviewer count is never a quality proxy",
            "## Process Budget Gate",
        ),
        "simplify": (
            "## Cleanup Depth Decision",
            "LIGHT and STANDARD: run one quick or combined scan",
        ),
        "verification-before-completion": (
            "Reuse the caller's canonical ledger",
            "never rewrite an unchanged parallel acceptance mapping",
        ),
    }.items():
        body = read_text(skill_core / f"{skill}.md")
        for marker in markers:
            if not has_required_marker(body, marker):
                die(f"{skill}.md is missing proportional-workflow marker: {marker!r}")

    ultrawork = read_text(skill_core / "ultrawork.md")
    if "dual-host default" in ultrawork:
        die("ultrawork.md still encodes the retired debugger pair-by-default policy")

    # Each existing hard gate has one metadata row in the canonical owner. A
    # count-only baseline is insufficient because a maintainer could add a gate
    # and merely increment the counter without recording its trigger or cost.
    expected_gate_ids = {
        "interview": ("HG-interview-handoff",),
        "ralplan": ("HG-ralplan-handoff",),
        "ralph": ("HG-ralph-worktree", "HG-ralph-persistence"),
        "ultrawork": ("HG-ultrawork-report",),
        "verification-before-completion": ("HG-vbc-evidence",),
        "systematic-debugging": ("HG-debug-output",),
    }
    gate_inventory_path = root / "docs" / "reference" / "mandatory-gate-inventory.md"
    gate_inventory = read_text(gate_inventory_path)
    for marker in (
        "# Mandatory Gate Inventory",
        "runtime skills do not preload this registry",
    ):
        if not has_required_marker(gate_inventory, marker):
            die(f"{gate_inventory_path} is missing inventory contract marker: {marker!r}")

    inventory_rows = {}
    for line in gate_inventory.splitlines():
        if not line.startswith("| HG-"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) != 9 or any(not cell for cell in cells):
            die(
                f"{gate_inventory_path} rows require Gate ID plus "
                "all eight governance fields"
            )
        gate_id = cells[0]
        if gate_id in inventory_rows:
            die(f"{gate_inventory_path} has duplicate hard-gate inventory id: {gate_id}")
        inventory_rows[gate_id] = cells[1:]

    expected_inventory_ids = {
        gate_id for gate_ids in expected_gate_ids.values() for gate_id in gate_ids
    }
    if set(inventory_rows) != expected_inventory_ids:
        die(
            f"{gate_inventory_path} hard-gate inventory mismatch: "
            f"expected={sorted(expected_inventory_ids)!r} "
            f"actual={sorted(inventory_rows)!r}"
        )

    for skill, gate_ids in expected_gate_ids.items():
        expected = len(gate_ids)
        actual = read_text(skill_core / f"{skill}.md").count("<HARD-GATE>")
        if actual != expected:
            die(
                f"{skill}.md hard-gate count changed ({expected} -> {actual}); "
                "add a complete canonical inventory row and update the reviewed gate-id baseline"
            )

    gate_registry = root / "docs" / "reference" / "mandatory-gate-inventory.md"
    owners = [
        path
        for path in skill_core.glob("*.md")
        if "Mandatory gate proposal:" in read_text(path)
    ]
    if owners:
        die("Mandatory gate proposal schema must not leak into skill cores; "
            f"its canonical owner is {gate_registry}")


def assert_ralplan_review_boundary_contract(root: Path) -> None:
    """Pin plan-reviewer ownership and the Ralplan/Ralph timing boundaries."""
    skill_core = root / "docs" / "skill-core"
    agent_core = root / "docs" / "agent-core"
    platforms = root / "docs" / "platforms"

    ralplan = read_text(skill_core / "ralplan.md")
    active_contract = markdown_section(ralplan, "## Active Plan Contract")
    for marker in (
        "Always required",
        "Mode-required",
        "Trigger-required",
        "Explicitly not applicable",
        "Reviewer entitlement",
        "missing-field blocking is limited to the active fields above",
    ):
        if not has_required_marker(active_contract, marker):
            die(f"ralplan.md Active Plan Contract is missing marker: {marker!r}")
    approved_caps = {"LIGHT": 11, "STANDARD": 24, "THOROUGH": 26}
    cap_match = re.search(
        r"Audited deduplicated baseline caps:\s*LIGHT=(\d+);\s*"
        r"STANDARD=(\d+);\s*THOROUGH=(\d+)",
        active_contract,
    )
    if not cap_match:
        die("ralplan.md Active Plan Contract is missing audited obligation baseline caps")
    recorded_caps = dict(zip(approved_caps, (int(value) for value in cap_match.groups())))
    if recorded_caps != approved_caps:
        die(
            "ralplan.md audited obligation baseline caps changed: "
            f"expected={approved_caps!r} actual={recorded_caps!r}"
        )

    table_match = re.search(
        r"Canonical activation table:\n\n(?P<table>(?:\|[^\n]*\|\n)+)",
        active_contract,
    )
    if not table_match:
        die("ralplan.md Active Plan Contract is missing canonical activation table")
    activation_fixtures = {
        "always": {"LIGHT", "STANDARD", "THOROUGH"},
        "implementation plan": {"LIGHT", "STANDARD", "THOROUGH"},
        "STANDARD or THOROUGH": {"STANDARD", "THOROUGH"},
        "behavior change or named regression/safety risk": {"STANDARD", "THOROUGH"},
        "selected roles/review, or LIGHT no-review": {"LIGHT", "STANDARD", "THOROUGH"},
        "THOROUGH or operational/migration/public-contract risk": {"THOROUGH"},
        "greenfield + open stack + recommendation requested": set(),
        "measurable evidence influenced request": set(),
        "agent policy not `inline-only`": {"STANDARD", "THOROUGH"},
        "migration, data/security/destructive, concurrency/lifecycle, or public/release trigger": {"THOROUGH"},
        "named THOROUGH paired-review trigger": {"THOROUGH"},
    }
    derived_obligations = {mode: set() for mode in approved_caps}
    for line in table_match.group("table").splitlines()[2:]:
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) != 4:
            die(f"ralplan.md canonical activation row must have four cells: {line!r}")
        _, activation, projection, _ = cells
        active_modes = activation_fixtures.get(activation)
        if active_modes is None:
            die(f"ralplan.md canonical activation is not fixture-audited: {activation!r}")
        obligations = [item.strip() for item in projection.split(";") if item.strip()]
        if not obligations:
            die(f"ralplan.md canonical active projection is empty: {line!r}")
        for mode in active_modes:
            derived_obligations[mode].update(obligations)
    for mode, obligations in derived_obligations.items():
        active = len(obligations)
        baseline = approved_caps[mode]
        if active > baseline:
            die(
                "ralplan.md derived active obligation count exceeds audited baseline: "
                f"{mode} {active}>{baseline}"
            )
    # 2026-08-07: Ralph consumes the plan's manifest through this row, so the
    # projection must carry every element ralph.md requires. A dropped element
    # reopens the Expansion-Gate mismatch that let planners over-author detail.
    scope_trace_row = next(
        (
            line
            for line in table_match.group("table").splitlines()
            if line.startswith("| Minimal scope trace |")
        ),
        "",
    )
    if not scope_trace_row:
        die("ralplan.md canonical activation table is missing the Minimal scope trace row")
    scope_trace_cells = [cell.strip() for cell in scope_trace_row.strip().strip("|").split("|")]
    if len(scope_trace_cells) != 4:
        die("ralplan.md Minimal scope trace row must have four cells")
    # The plan projection cell is the only surface Ralph consumes; a marker
    # living in the reviewer-entitlement cell would not supply the manifest.
    # LIGHT plans must inherit the manifest too; narrowing this activation would
    # silently drop it for LIGHT, the exact regression this row prevents.
    if scope_trace_cells[1] != "always":
        die(
            "ralplan.md Minimal scope trace activation must stay 'always' so LIGHT "
            f"plans still inherit the Mutation Manifest: {scope_trace_cells[1]!r}"
        )
    scope_trace = scope_trace_cells[2]
    for element in (
        "Mutation Manifest Ralph inherits",
        "each authorized path with its change kind",
        "semantic obligation",
        "AC/safety basis",
        "causal generated outputs or `none`",
        "contract surfaces",
    ):
        if not has_required_marker(scope_trace, element):
            die(f"ralplan.md Minimal scope trace must own the manifest element: {element!r}")
    for heading, markers in {
        "## Plan Review Contract": (
            "Blocking basis: <AC ID | safety invariant | Direction Contract field | applicable mandatory gate>",
            "APPROVE freezes the exact reviewed Planner draft",
            "Non-blocking findings are optional follow-ups",
            "Any plan-body change that must be incorporated before approval is blocking",
            "Plan-Reviewer: dispatch-unavailable",
            "transition to\nPAUSED",
            "inline review cannot satisfy the required pass",
            "LIGHT\nno-review carve-out remains unchanged",
            "each required\nreviewer instance runs the complete two-pass role",
            # 2026-08-07: detail volume satisfies no R8 basis, so an
            # authored-detail finding must stay non-blocking unless the detail
            # is itself wrong under an existing basis.
            "violation is non-blocking on its own",
            "never on detail volume [R8]",
        ),
        "## Agent Roles": (
            "generic separate subagent",
        ),
        # 2026-08-07: planning roles are read-only, so authored implementation
        # detail is unverified prediction that displaces executor judgment and
        # inflates the single allowed review pass. The plan owns the manifest
        # ceiling; the executor owns how each obligation is met.
        "### Authored-Detail Boundary": (
            "The plan owns what must change, why, where, and what proves it done",
            "executor owns how, reading the actual code at execution time",
            "Mutation Manifest\nRalph inherits, and it is the ceiling",
            "literal replacement text, diffs, or patch bodies for a target",
            "step-by-step edit routes",
            "as a constraint with its basis, never as authored\nreplacement text",
            "leaves the executor no decision beyond transcription",
        ),
        "## Findings Ledger Gate": (
            "Missing review topology, or topology that\ndoes not satisfy the selected mode and fired trigger, is a blocker rather than\na pass",
            # Stem: the ledger row must reference the blocker's basis; the full
            # canonical enum lives once in ## Plan Review Contract above.
            "blocking basis",
        ),
    }.items():
        section = markdown_section(ralplan, heading)
        if not section:
            die(f"ralplan.md is missing required section: {heading!r}")
        for marker in markers:
            if not has_required_marker(section, marker):
                die(f"ralplan.md {heading} is missing review-boundary marker: {marker!r}")
    plan_review = markdown_section(ralplan, "## Plan Review Contract")
    revision = markdown_section(ralplan, "## Planner Revision Contract")
    for adapter_name in ("claude-code-ralplan.md", "codex-ralplan.md"):
        adapter_path = platforms / adapter_name
        adapter = read_text(adapter_path)
        for marker in (
            "generic",
            "required Plan-Reviewer",
            "dispatch-unavailable",
            "PAUSED",
            "inline",
        ):
            if not has_required_marker(adapter, marker):
                die(f"{adapter_path} is missing required Plan-Reviewer fail-closed marker: {marker!r}")

    review_skills = (
        "ralplan",
        "ralph",
        "ultrawork",
        "verification-before-completion",
        "systematic-debugging",
    )
    amended_packet_identity = "identical except the single `Assigned perspective:` line"
    codex_redacted_packet_identity = (
        "The two review legs receive redacted packets identical except the single "
        "`Assigned perspective:` line."
    )
    for skill in review_skills:
        claude_path = platforms / f"claude-code-{skill}.md"
        claude_adapter = read_text(claude_path)
        for marker in (amended_packet_identity, "Assigned perspective"):
            if not has_required_marker(claude_adapter, marker):
                die(f"{claude_path} is missing amended review-packet marker: {marker!r}")
        if has_required_marker(claude_adapter, "packet bodies MUST be byte-identical"):
            die(f"{claude_path} retains forbidden byte-identical review-packet wording")

        codex_path = platforms / f"codex-{skill}.md"
        codex_adapter = read_text(codex_path)
        for marker in (
            codex_redacted_packet_identity,
            "Assigned perspective",
            "same-host-perspective-pair",
            "same-host-parallel-fallback",
        ):
            if not has_required_marker(codex_adapter, marker):
                die(f"{codex_path} is missing perspective-pair marker: {marker!r}")
    forbidden_approval_mutations = (
        r"after\s+APPROVE[^\n]{0,120}\b(?:revise|mutate|change|incorporate|apply)\b",
        r"\b(?:incorporate|apply)\b[^\n]{0,80}\bnon-blocking\b[^\n]{0,80}\b(?:Planner draft|plan body)\b",
        r"\bnon-blocking\b[^\n]{0,80}\b(?:must|required)\b[^\n]{0,40}\b(?:incorporat|apply|mutat|revis)",
    )
    for pattern in forbidden_approval_mutations:
        if re.search(pattern, f"{plan_review}\n{revision}", flags=re.IGNORECASE):
            die(f"ralplan.md contradicts APPROVE/non-blocking draft freeze: {pattern!r}")

    reviewer = read_text(agent_core / "plan-reviewer.md")
    for marker in (
        "Ralplan planning-review role only",
        "Blocking basis: <AC ID | safety invariant | Direction Contract field | applicable mandatory gate>",
        "APPROVE freezes the exact reviewed Planner draft",
    ):
        if not has_required_marker(reviewer, marker):
            die(f"plan-reviewer.md is missing Ralplan-only marker: {marker!r}")
    for marker in (
        "unsupported false rejection is also a contract failure",
        "exact draft pointer",
        "material consequence",
        "smallest sufficient correction",
        "reviewer entitlement to active fields",
        "smallest AC-sufficient correction",
    ):
        if not has_required_marker(reviewer, marker):
            die(f"plan-reviewer.md is missing calibrated-blocker marker: {marker!r}")
    for forbidden in (
        "Require every draft to include rollout telemetry even when the Active plan contract omits it.",
        "Block on preferred future-proofing even without an active AC or safety basis.",
    ):
        if forbidden in reviewer:
            die(
                "plan-reviewer.md violates reviewer entitlement to active fields"
                if "rollout" in forbidden
                else "plan-reviewer.md violates smallest AC-sufficient correction"
            )
    if "A false approval is worse than a false rejection" in reviewer:
        die("plan-reviewer.md permits unsupported false rejection")

    for marker in (
        "disposition-only user-decision packet",
        "exactly one final Planner revision v2",
        "finding→fix mapping",
    ):
        if not has_required_marker(ralplan, marker):
            die(f"ralplan.md is missing single-round review marker: {marker!r}")
    for forbidden in ("delta closure review", "## Re-Review Rules"):
        if has_required_marker(ralplan, forbidden):
            die(f"ralplan.md retains forbidden single-round review marker: {forbidden!r}")
    if "If a blocker is rejected, create Planner revision v2 before asking the user." in ralplan:
        die("ralplan.md must use a disposition-only user-decision packet before revision")
    branch_rules = {
        "All accepted: create exactly one final Planner revision v2; run no further review — the Plan Approval Brief surfaces each accepted finding→fix mapping for the user.":
            "all-accepted must create exactly one final v2 with a finding→fix mapping and no further review",
        "Any rejected: return the disposition-only user-decision packet; create no v2 until the user resolves it.":
            "rejected must create no v2 before user resolution",
        "Any deferred: leave the plan pending in the disposition-only user-decision packet; create no v2.":
            "deferred must leave the plan pending with no v2",
        "Mixed: resolve every non-accepted blocker before exactly one v2.":
            "mixed blockers must resolve before one v2",
        "Permitted waivers with no body change: keep the waivers visible; create no v2.":
            "permitted waiver with no body change must create no v2",
        "Non-waivable gate: keep the plan pending and prohibit execution until its owner-defined obligation passes or direction changes.":
            "non-waivable gate must remain pending with no execution",
        "Direction change: update the requirements source, start a new planning run.":
            "direction change must start a new run",
    }
    for marker, failure in branch_rules.items():
        if not has_required_marker(revision, marker):
            die(f"ralplan.md branch matrix {failure}")

    planner = read_text(agent_core / "planner.md")
    for marker in (
        "classify every blocking finding",
        "before assigning a new draft id or mutating the plan body",
        "disposition-only user-decision packet",
    ):
        if not has_required_marker(planner, marker):
            die(f"planner.md is missing blocker-disposition marker: {marker!r}")

    # The deleted review transport's Ralplan-only fence is replaced by the
    # surviving plan-reviewer core plus the direct-dispatch scan below.

    direct_dispatch = re.compile(
        r"^(?![^\n]*\b(?:do not|must not|never)\b)[^\n]*"
        r"\b(?:dispatch|invoke|run|use|add)\b[^\n]{0,100}\bplan-reviewer\b",
        flags=re.IGNORECASE | re.MULTILINE,
    )
    for skill in ("ralph", "systematic-debugging", "simplify", "verification-before-completion"):
        body = read_text(skill_core / f"{skill}.md")
        roles = markdown_section(body, "## Agent Roles")
        if re.search(r"^\|\s*`plan-reviewer`\s*\|", roles, flags=re.MULTILINE):
            die(f"{skill}.md Agent Roles must not directly dispatch plan-reviewer")
        if direct_dispatch.search(body):
            die(f"{skill}.md must not directly dispatch plan-reviewer outside Ralplan")

    ultrawork = read_text(skill_core / "ultrawork.md")
    final_validation = markdown_section(ultrawork, "### FINAL_VALIDATION")
    if has_token(final_validation, "plan-reviewer"):
        die("ultrawork.md Final Validation must not directly dispatch plan-reviewer")
    if direct_dispatch.search(final_validation):
        die("ultrawork.md Final Validation must not directly dispatch plan-reviewer")

    ralph = read_text(skill_core / "ralph.md")
    for marker in (
        "ONE full-role `code-reviewer` for behavior-affecting or workflow",
        "escalates to one perspective-diverse pair",
        "Reviewer approval of the fixed revision is NOT required and MUST NOT be requested",
        "the verifier pass (or accepted pass-with-residual-risk) binds to the FIXED revision with a per-finding resolution audit",
        "verifier bound revision: reviewed | fixed",
    ):
        if not has_required_marker(ralph, marker):
            die(f"ralph.md is missing fixed-revision completion marker: {marker!r}")
    for forbidden in (
        "focused re-check",
        "focused-recheck",
        "run a focused review when cleanup changed",
    ):
        if has_required_marker(ralph, forbidden):
            die(f"ralph.md retains forbidden second-review marker: {forbidden!r}")
    execution_loop = markdown_section(ralph, "## Execution Loop")
    for marker in (
        "Mutation Manifest",
        "cumulative Process Budget Gate",
        "After each story",
        "After all stories",
        "run the `## Diff-Budget Gate` once for the current",
        "stabilized revision",
        "before `## Review Gate`",
    ):
        if not has_required_marker(execution_loop, marker):
            die(f"ralph.md Execution Loop is missing budget-timing marker: {marker!r}")
    if len(re.findall(r"Diff-Budget Gate", execution_loop, flags=re.IGNORECASE)) != 1:
        die("ralph.md Execution Loop must schedule one Diff-Budget Gate per stabilized revision")
    process_budget = markdown_section(ralph, "## Process Budget Gate")
    for marker in ("cumulative", "per-story"):
        if not has_required_marker(process_budget, marker):
            die(f"ralph.md Process Budget Gate is missing timing marker: {marker!r}")
    diff_budget = markdown_section(ralph, "## Diff-Budget Gate")
    for marker in (
        "pending | passed@<fingerprint> |\nstale",
        "current stabilized revision",
        "record `passed@<fingerprint>`",
        "later material mutation marks the result `stale`",
        "returns the gate to\n`pending`",
        "before entering REVIEW",
        "before INTEGRATE and COMPLETION_AUDIT",
    ):
        if not has_required_marker(diff_budget, marker):
            die(f"ralph.md Diff-Budget Gate is missing revision-bound marker: {marker!r}")
    ralph_output = markdown_section(ralph, "## Output")
    phase_attribution = (
        "Review phases: plan=<n>; implementation-code=<n>; "
        "independent-verifier=<n>"
    )
    if not has_required_marker(ralph_output, phase_attribution):
        die("ralph.md Output is missing exact compact phase-attribution format")
    for marker in (
        "when 2+ stages ran",
        "when fewer than two ran, use ordinary labeled prose and omit that count line",
    ):
        if not has_required_marker(ralph_output, marker):
            die(f"ralph.md Output is missing conditional phase-attribution rule: {marker!r}")

    # docs/shared retired 2026-07-17: the canonical Diff-Budget timing lives
    # in ralph.md and is asserted above; guard only against the conditional
    # phrasing regressing inside the ralph core.
    ralph_modes = read_text(root / "docs" / "skill-core" / "ralph.md")
    for pattern in (
        r"run\s+the\s+diff-budget\s+gate\s+when",
        r"Diff-Budget Gate[^\n]{0,80}\bonly\s+if\b",
        r"Diff-Budget Gate[^\n]{0,80}\bper[- ]story\b",
    ):
        if re.search(pattern, ralph_modes, flags=re.IGNORECASE):
            die(f"ralph.md makes final Diff-Budget execution conditional or repeated: {pattern!r}")


def routing_hook_blocks(root: Path) -> tuple[str, str, str, list[str]]:
    hook_path = root / "hooks" / "session-start"
    hook = read_text(hook_path)
    problems: list[str] = []

    bootstrap_start = hook.find("bootstrap_policy='")
    bootstrap_end = hook.find('\n\nauto_routing_policy=""', bootstrap_start)
    if bootstrap_start < 0 or bootstrap_end < 0:
        problems.append("hook-shape: cannot locate unconditional bootstrap_policy")
        bootstrap = ""
    else:
        bootstrap = hook[bootstrap_start + len("bootstrap_policy='") : bootstrap_end]
        if bootstrap.endswith("'"):
            bootstrap = bootstrap[:-1]

    forced_match = re.search(
        r"auto_routing_policy='\s*(<OH_NO_FORCED_ROUTING>.*?</OH_NO_FORCED_ROUTING>)'",
        hook,
        flags=re.DOTALL,
    )
    if forced_match is None:
        problems.append("hook-shape: cannot locate Claude OH_NO_FORCED_ROUTING block")
        forced = ""
    else:
        forced = forced_match.group(1)
    return hook, bootstrap, forced, problems


def claude_orchestration_block(hook: str) -> tuple[str, list[str]]:
    """Return the always-on Claude OH_NO_MAIN_AGENT_ORCHESTRATION block body."""
    match = re.search(
        r"claude_code_orchestration_policy='\s*"
        r"(<OH_NO_MAIN_AGENT_ORCHESTRATION>.*?</OH_NO_MAIN_AGENT_ORCHESTRATION>)'",
        hook,
        flags=re.DOTALL,
    )
    if match is None:
        return "", ["hook-shape: cannot locate Claude OH_NO_MAIN_AGENT_ORCHESTRATION block"]
    return match.group(1), []


# Exact canonical clauses of the Claude-only host-plan boundary. These are
# pinned verbatim (whitespace-normalized) rather than matched by keyword, so a
# polarity flip such as "never auto-wrap" -> "always wrap" fails even though it
# reuses every original token. Each clause carries one load-bearing decision.
HOST_PLAN_CANONICAL_CLAUSES = (
    (
        "no automatic host planning wrapper",
        "never auto-wrap Ralph-eligible Oh No Harness execution in EnterPlanMode "
        "or a host planning pass",
    ),
    (
        "host plan mode requires explicit user request",
        "host plan mode needs explicit user request",
    ),
    (
        "usable approved/concrete execution contract runs Ralph directly",
        "Usable approved/concrete execution contract goes straight to Ralph",
    ),
    (
        "vague or plan-only work routes upstream",
        "vague or plan-only work routes upstream to Oh No Harness planning",
    ),
    (
        "no-route housekeeping stays direct",
        "no-route housekeeping stays direct",
    ),
)


def host_plan_boundary_problems(root: Path) -> list[str]:
    """Pin the host-plan boundary clauses to the Claude orchestration block only.

    This is exact canonical contract pinning, not semantic parsing: each clause
    of HOST_PLAN_CANONICAL_CLAUSES must appear verbatim (whitespace-normalized)
    inside the always-on Claude orchestration block, the boundary label and
    EnterPlanMode must each appear exactly once in the hook, and neither may
    leak into the cross-platform bootstrap, the optional forced-routing block,
    or any Codex-only block. Verbatim pinning is what makes a token-preserving
    polarity flip fail.
    """
    hook, bootstrap, forced, problems = routing_hook_blocks(root)
    orchestration, block_problems = claude_orchestration_block(hook)
    problems.extend(block_problems)

    label = "Host-plan boundary:"
    if orchestration and not has_required_marker(orchestration, label):
        problems.append(
            f"host-plan: Claude OH_NO_MAIN_AGENT_ORCHESTRATION is missing {label!r}"
        )
    if hook.count(label) != 1:
        problems.append(
            f"host-plan: {label!r} must appear exactly once in hooks/session-start "
            f"(found {hook.count(label)})"
        )
    if hook.count("EnterPlanMode") != 1:
        problems.append(
            "host-plan: 'EnterPlanMode' must appear exactly once in hooks/session-start "
            f"(found {hook.count('EnterPlanMode')})"
        )

    codex_blocks = re.findall(
        r"<CODEX_ONLY_[A-Z_]+>.*?</CODEX_ONLY_[A-Z_]+>", hook, flags=re.DOTALL
    )
    for name, block in (
        ("unconditional OH_NO_BOOTSTRAP", bootstrap),
        ("Claude OH_NO_FORCED_ROUTING", forced),
        *(("Codex-only block", block) for block in codex_blocks),
    ):
        for token in (label, "EnterPlanMode"):
            if token in block:
                problems.append(f"host-plan: {name} must not carry {token!r}")

    for name, clause in HOST_PLAN_CANONICAL_CLAUSES:
        if not has_required_marker(orchestration, clause):
            problems.append(
                f"host-plan: canonical clause altered or missing ({name}): {clause!r}"
            )
    return problems


def workflow_object_routing_problems(root: Path) -> list[str]:
    hook, bootstrap, forced, problems = routing_hook_blocks(root)
    required = (
        "A workflow name used only as the subject of analysis, explanation, comparison, or critique is not an invocation trigger.",
        "Route from the requested deliverable: an analysis report versus a plan or execution artifact.",
    )
    for marker in required:
        if not has_required_marker(bootstrap, marker):
            problems.append(
                f"object-owner: unconditional OH_NO_BOOTSTRAP is missing {marker!r}"
            )
        if has_required_marker(forced, marker):
            problems.append(
                f"object-owner: Claude forced block duplicates unconditional owner {marker!r}"
            )
        if hook.count(marker) != 1:
            problems.append(
                f"object-owner: {marker!r} must appear exactly once in hooks/session-start"
            )
    for marker in (
        "If there is even a small chance that a local skill applies",
        "If there is even a 1% chance that a local Oh No Harness skill applies",
    ):
        if marker in hook:
            problems.append(f"object-owner: hooks/session-start retains absolute routing wording {marker!r}")
    return problems


def assert_routing_layer_contract(marketplace_root: Path, root: Path) -> None:
    """Accumulate the target description-owned routing contract in one RED report."""
    problems: list[str] = []
    workflow_names = set(WORKFLOW_ROUTING_SKILLS)

    for skill in WORKFLOW_ROUTING_SKILLS:
        source_path = root / SKILL_CORE_ROOT / f"{skill}.md"
        source_text = read_text(source_path)
        description_lines = [line for line in source_text.splitlines() if line.startswith("description:")]
        description = parse_frontmatter(source_path).get("description", "")
        lowered = description.lower()
        if len(description_lines) != 1:
            problems.append(f"description:{skill}: description must be one YAML line")
        if not description.startswith("Use when "):
            problems.append(f"description:{skill}: description must begin with 'Use when'")
        if len(description) > 360:
            problems.append(f"description:{skill}: description exceeds 360 code points ({len(description)})")
        positive_patterns, boundary_patterns, adjacent_names = ROUTING_DESCRIPTION_PATTERNS[skill]
        positive_matches = [re.search(pattern, lowered) for pattern in positive_patterns]
        boundary_matches = [re.search(pattern, lowered) for pattern in boundary_patterns]
        missing_positive = [pattern for pattern, match in zip(positive_patterns, positive_matches) if match is None]
        missing_boundary = [pattern for pattern, match in zip(boundary_patterns, boundary_matches) if match is None]
        if missing_positive:
            problems.append(f"description:{skill}: missing positive trigger semantics {missing_positive!r}")
        if missing_boundary:
            problems.append(f"description:{skill}: missing adjacent-boundary semantics {missing_boundary!r}")
        present_positive = [match.start() for match in positive_matches if match is not None]
        present_boundary = [match.start() for match in boundary_matches if match is not None]
        if present_positive and present_boundary and min(present_positive) > min(present_boundary):
            problems.append(f"description:{skill}: positive trigger must precede its exclusion/boundary")
        mentioned = sorted(name for name in workflow_names - {skill} if name in lowered)
        if len(mentioned) > 2:
            problems.append(f"description:{skill}: adjacent boundary names too many workflows {mentioned!r}")
        non_adjacent = sorted(set(mentioned) - adjacent_names)
        if non_adjacent:
            problems.append(f"description:{skill}: names non-adjacent workflows {non_adjacent!r}")
        for forbidden in ("using-oh-no-harness", "choose the right skill", "hard enforcement", "guarantees invocation"):
            if forbidden in lowered:
                problems.append(f"description:{skill}: contains forbidden routing wording {forbidden!r}")

        for wrapper_root in (CODEX_SKILL_ROOT, CLAUDE_SKILL_ROOT):
            wrapper_path = root / wrapper_root / skill / "SKILL.md"
            if not wrapper_path.exists():
                problems.append(f"parity:{skill}: missing generated wrapper {wrapper_path}")
                continue
            wrapper_description = parse_frontmatter(wrapper_path).get("description", "")
            if wrapper_description != description:
                problems.append(
                    f"parity:{skill}: {wrapper_root} description differs from source byte-for-byte"
                )

    retired_paths = (
        root / SKILL_CORE_ROOT / "using-oh-no-harness.md",
        root / "commands" / "using-oh-no-harness.md",
        root / CODEX_SKILL_ROOT / "using-oh-no-harness",
        root / CLAUDE_SKILL_ROOT / "using-oh-no-harness",
    )
    for path in retired_paths:
        if path.exists():
            problems.append(f"retired-inventory: retired public router remains present: {path}")

    manifest_path = root / ".claude-plugin" / "plugin.json"
    try:
        manifest_skills = json.loads(read_text(manifest_path)).get("skills")
    except json.JSONDecodeError as exc:
        problems.append(f"retired-inventory: invalid Claude manifest JSON: {exc}")
    else:
        expected_manifest = [f"./{CLAUDE_SKILL_ROOT}/{skill}/" for skill in PUBLIC_SKILLS]
        if manifest_skills != expected_manifest:
            problems.append(
                "retired-inventory: Claude manifest must expose exactly 12 target skills "
                f"in order; actual={manifest_skills!r}"
            )

    generator_path = marketplace_root / "scripts" / "generate-skill-wrappers.py"
    generator_match = re.search(r"PUBLIC_SKILLS\s*=\s*\[(.*?)\n\]", read_text(generator_path), flags=re.DOTALL)
    generator_skills = re.findall(r'"([a-z0-9-]+)"', generator_match.group(1)) if generator_match else []
    if generator_skills != PUBLIC_SKILLS:
        problems.append(
            f"retired-inventory: generator PUBLIC_SKILLS drifted: {generator_skills!r}"
        )

    for script_name, expected in (
        ("test-claude-plugin.sh", PUBLIC_SKILLS),
        ("test-codex-plugin.sh", WORKFLOW_ROUTING_SKILLS),
    ):
        script_path = marketplace_root / "scripts" / script_name
        match = re.search(
            r"PUBLIC_SKILLS=\(\n(?P<body>.*?)\n\)",
            read_text(script_path),
            flags=re.DOTALL,
        )
        actual = [line.strip() for line in match.group("body").splitlines() if line.strip()] if match else []
        if actual != expected:
            problems.append(
                f"retired-inventory: {script_name} PUBLIC_SKILLS expected={expected!r} actual={actual!r}"
            )

    reachability_path = marketplace_root / "scripts" / "check-skill-reachability.py"
    reachability = read_text(reachability_path)
    if re.search(r'^\s*"using-oh-no-harness"\s*:\s*\[', reachability, flags=re.MULTILINE):
        problems.append("retired-inventory: reachability still declares the retired router")

    hook, bootstrap, forced, hook_problems = routing_hook_blocks(root)
    problems.extend(hook_problems)
    for marker in ("No-route lane", "Direct-edit lane", "Skill chaining remains explicit: if a skill presents Next Skill Handoff, ask before invoking the next workflow skill."):
        if marker not in bootstrap:
            problems.append(f"hook-bootstrap: missing retained global lane {marker!r}")
    bootstrap_lower = bootstrap.lower()
    for label, pattern in (
        ("no-route repository-work-product exclusion", r"does not (create|change|create or change).*repository work products"),
        ("no-route completion-claim exclusion", r"does not claim (their )?completion|no completion claim"),
        ("direct-edit one-file predicate", r"one obvious file"),
        ("direct-edit private predicate", r"private"),
        ("direct-edit inert predicate", r"inert"),
        ("direct-edit non-consumed predicate", r"not consumed|non-consumed"),
        ("direct-edit non-generated predicate", r"not generated|non-generated"),
        ("direct-edit generated-source regeneration/validation predicate", r"generation source(?=[^.]*regenerat)(?=[^.]*validat)"),
        ("direct-edit non-operational predicate", r"non-operational"),
        ("direct-edit non-public-contract predicate", r"no .*public-contract|non-public-contract"),
        ("direct-edit Ralph fallback", r"if any condition (fails|is false|becomes false).*ralph"),
    ):
        if not re.search(pattern, bootstrap_lower):
            problems.append(f"hook-bootstrap: missing/weak {label}")
    for surface in ("executable", "test", "build", "ci", "hook", "generated", "security", "permission", "public-contract", "dependency", "lockfile", "ignore", "attribute", "schema", "migration", "operational-command"):
        if surface not in bootstrap_lower:
            problems.append(f"hook-bootstrap: direct-edit exclusions omit {surface!r}")
    routed_names = re.findall(r"\b(?:interview|ralplan|ralph|ultrawork|auto-routing|test-driven-development|simplify|verification-before-completion|systematic-debugging|fusion-rescue)\b", bootstrap_lower)
    if any(name != "ralph" for name in routed_names) or routed_names.count("ralph") != 1:
        problems.append(f"hook-bootstrap: positive destination catalog detected; only one Ralph fallback is allowed, got {routed_names!r}")
    for marker in (
        "Routing reminder:",
        "using-oh-no-harness",
        "Use oh-no-harness:test-driven-development only as an explicit TDD/test-first route",
    ):
        if marker in bootstrap:
            problems.append(f"hook-bootstrap: unconditional bootstrap retains {marker!r}")

    forced_lower = forced.lower()
    if "routing map" in forced_lower or forced_lower.count("oh-no-harness:") > 1:
        problems.append("hook-forced: Claude block retains an exhaustive positive destination catalog")
    if "installed skill descriptions" not in forced_lower:
        problems.append("hook-forced: Claude block must consult installed skill descriptions")
    for marker in (
        "explicit end-to-end",
        "active failure",
        "explicit test-first",
        "most upstream incomplete prerequisite",
    ):
        if marker not in forced_lower:
            problems.append(f"hook-forced: missing essential precedence marker {marker!r}")
    before = forced_lower.find("before")
    for action in ("respond", "explor", "edit", "clarif", "claiming completion"):
        index = forced_lower.find(action)
        if before < 0 or index < before:
            problems.append(
                f"hook-forced: routing must occur before action marker {action!r}"
            )
    for marker in ("instruction priority", "if a user instruction conflicts"):
        if marker not in forced_lower:
            problems.append(f"hook-forced: missing instruction/user precedence marker {marker!r}")
    if (
        'if [ "$is_claude_code" = true ] && "${OH_NO_PLUGIN_ROOT}/scripts/oh-no-config" is-enabled' not in hook
        or hook.count("<OH_NO_FORCED_ROUTING>") != 1
    ):
        problems.append("asymmetry: forced routing must remain Claude-only and singular")

    claude_auto = read_text(root / "docs/platforms/claude-code-auto-routing.md").lower().replace("`", "")
    codex_auto = read_text(root / "docs/platforms/codex-auto-routing.md").lower().replace("`", "")
    if "description" not in claude_auto or not re.search(r"next.{0,40}sessionstart", claude_auto):
        problems.append("asymmetry: Claude auto-routing guidance must bind descriptions to the next SessionStart")
    for marker in (
        "native skill loading remains the primary routing surface",
        "does not add forced routing",
        "does not change current routing semantics",
    ):
        if marker not in codex_auto:
            problems.append(f"asymmetry: Codex guidance is missing {marker!r}")

    problems.extend(workflow_object_routing_problems(root))
    problems.extend(host_plan_boundary_problems(root))
    if problems:
        die(
            f"routing-layer target contract failed with {len(problems)} issue(s):\n  - "
            + "\n  - ".join(problems)
        )


def assert_workflow_object_routing_contract(root: Path) -> None:
    """Keep the unconditional bootstrap as sole object-of-analysis policy owner."""
    problems = workflow_object_routing_problems(root)
    problems.extend(host_plan_boundary_problems(root))
    if problems:
        die("workflow object routing contract failed:\n  - " + "\n  - ".join(problems))


def assert_review_boundary_mutation_tests(marketplace_root: Path, root: Path) -> None:
    script = marketplace_root / "scripts" / "test-review-boundary-contract.py"
    result = subprocess.run(
        [sys.executable, str(script), "--plugin-root", str(root)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        details = "\n".join(
            part for part in (result.stdout.strip(), result.stderr.strip()) if part
        )
        die(f"review-boundary mutation tests failed:\n{details}")


# FSM-core structural contract (2026-07-16 rewrite). For each self-contained
# FSM skill core: the phase set, outcome set, and rule-ID definitions must be
# present exactly as baselined, every rule ID is defined exactly once inside
# the ## Invariants block, and the state-machine table cites rule IDs so a
# guard cannot silently drop its invariant reference.
FSM_CONTRACTS = {
    "ralplan": {
        "phases": ("ROUTE", "REQUIREMENTS", "DRAFT", "REVIEW", "APPROVAL"),
        "outcomes": (
            "ROUTED_INTERVIEW",
            "ROUTED_RALPH",
            "HANDOFF_RALPH",
            "HANDOFF_ULTRAWORK",
            "RETURN_ULTRAWORK",
            "PAUSED",
        ),
        "rule_ids": ("R1", "R2", "R3", "R4", "R5", "R6", "R8", "R9", "R10", "R15", "R16"),
        "transition_targets": {
            "ROUTE": ("outcome:ROUTED_INTERVIEW", "outcome:ROUTED_RALPH", "phase:REQUIREMENTS"),
            "REQUIREMENTS": ("outcome:PAUSED", "phase:DRAFT"),
            "DRAFT": ("phase:APPROVAL", "phase:REVIEW"),
            "REVIEW": (
                "outcome:PAUSED", "outcome:PAUSED", "outcome:PAUSED",
                "phase:APPROVAL", "phase:APPROVAL", "phase:DRAFT",
            ),
            "APPROVAL": ("outcome:*",),
        },
        "min_guard_citations": 6,
    },
    "ralph": {
        "phases": ("PREPARE", "EXECUTE", "REVIEW", "FINALIZE"),
        "outcomes": ("COMPLETE", "PAUSED", "RETURN_TO_PLAN"),
        "rule_ids": (
            "E1", "E2", "E3", "E4", "E5", "E6", "E7", "E8",
            # E16 was the retired delegated-executor companion boundary. Its
            # replacement is the exact inventory + SessionStart diversity contract.
            "E9", "E10", "E11", "E12", "E13", "E14", "E15", "E17",
        ),
        "transition_targets": {
            "PREPARE": ("outcome:PAUSED", "outcome:RETURN_TO_PLAN", "phase:EXECUTE"),
            "EXECUTE": (
                "outcome:PAUSED", "outcome:RETURN_TO_PLAN", "phase:EXECUTE", "phase:REVIEW",
            ),
            "REVIEW": (
                "outcome:PAUSED", "outcome:PAUSED", "phase:EXECUTE",
                "phase:FINALIZE", "phase:FINALIZE",
            ),
            "FINALIZE": ("outcome:COMPLETE", "outcome:PAUSED"),
            "any": ("outcome:PAUSED",),
        },
        "min_guard_citations": 10,
    },
    "interview": {
        "phases": ("ROUTE", "CONTEXT", "INTERVIEW", "CLOSURE", "APPROVAL"),
        "outcomes": (
            "ROUTED_DIRECT",
            "HANDOFF_RALPLAN",
            "HANDOFF_RALPH",
            "HANDOFF_ULTRAWORK",
            "RETURN_ULTRAWORK",
            "PAUSED",
        ),
        "rule_ids": (
            "I1", "I2", "I3", "I4", "I5", "I6", "I7", "I8",
            "I9", "I10", "I11", "I12", "I13", "I15", "I16",
        ),
        "transition_targets": {
            "ROUTE": ("outcome:ROUTED_DIRECT", "phase:CONTEXT"),
            "CONTEXT": ("phase:INTERVIEW",),
            "INTERVIEW": ("outcome:PAUSED", "phase:CLOSURE"),
            "CLOSURE": ("phase:APPROVAL", "phase:INTERVIEW"),
            "APPROVAL": (
                "outcome:*", "outcome:PAUSED", "outcome:RETURN_ULTRAWORK",
                "phase:CLOSURE", "phase:INTERVIEW",
            ),
        },
        "min_guard_citations": 8,
    },
    "ultrawork": {
        "phases": (
            "START_OR_RESUME",
            "REQUIREMENTS",
            "PLANNING",
            "WORKTREE",
            "EXECUTION",
            "QA",
            "FINAL_VALIDATION",
            "REPORT",
        ),
        "outcomes": (
            "succeeded_merged_verified_reported",
            "succeeded_left_worktree_for_inspection",
            "paused_for_user",
            "blocked",
            "cancelled",
            "failed_verification",
            "scope_change_pending_approval",
        ),
        "rule_ids": (
            "U1", "U2", "U3", "U4", "U5", "U6", "U7", "U8", "U9",
            "U10", "U11", "U12", "U13", "U14", "U16", "U17",
        ),
        "transition_targets": {
            "START_OR_RESUME": ("phase:REQUIREMENTS",),
            "REQUIREMENTS": ("phase:PLANNING", "phase:REQUIREMENTS"),
            "PLANNING": ("outcome:paused_for_user", "phase:WORKTREE"),
            "WORKTREE": ("outcome:blocked", "phase:EXECUTION"),
            "EXECUTION": (
                "outcome:scope_change_pending_approval", "phase:PLANNING", "phase:QA",
            ),
            "QA": ("outcome:blocked,failed_verification", "phase:FINAL_VALIDATION", "phase:QA"),
            "FINAL_VALIDATION": ("phase:QA", "phase:REPORT"),
            "REPORT": (
                "outcome:succeeded_left_worktree_for_inspection,succeeded_merged_verified_reported",
            ),
            "any": ("outcome:cancelled,paused_for_user,scope_change_pending_approval",),
        },
        "min_guard_citations": 10,
    },
}


def parse_fsm_rows(path: Path, machine: str) -> list[tuple[str, str, str]]:
    rows: list[tuple[str, str, str]] = []
    for line in machine.splitlines():
        if not line.strip().startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if cells == ["Phase", "Exit guard", "Next"]:
            continue
        if cells and all(re.fullmatch(r"-+", cell) for cell in cells):
            continue
        if len(cells) != 3:
            die(f"{path} state-machine row must have exactly three cells: {line!r}")
        source, guard, target = cells
        if not source or not guard or not target:
            die(f"{path} state-machine row has an empty phase, guard, or target: {line!r}")
        rows.append((source, guard, target))
    if not rows:
        die(f"{path} state machine has no transition rows")
    return rows


def normalized_fsm_target(path: Path, contract: dict, target: str) -> str:
    clean = target.replace("`", "").strip()
    phases = set(contract["phases"])
    outcomes = set(contract["outcomes"])
    if clean.lower().startswith("outcome "):
        found = sorted(
            outcome
            for outcome in outcomes
            if re.search(rf"(?<![A-Za-z0-9_]){re.escape(outcome)}(?![A-Za-z0-9_])", clean)
        )
        if found:
            return "outcome:" + ",".join(found)
        if "HANDOFF_*" in clean or clean.lower().startswith("outcome per "):
            return "outcome:*"
        die(f"{path} state-machine target names no declared outcome: {target!r}")

    match = re.match(r"([A-Za-z_][A-Za-z0-9_]*)", clean)
    if not match:
        die(f"{path} state-machine target is not parseable: {target!r}")
    first = match.group(1)
    if first in phases:
        return f"phase:{first}"
    if first in outcomes:
        return f"outcome:{first}"
    die(f"{path} state-machine target starts with undeclared phase/outcome: {target!r}")


def assert_fsm_contract(root: Path, skill: str) -> None:
    contract = FSM_CONTRACTS[skill]
    path = root / SKILL_CORE_ROOT / f"{skill}.md"
    body = read_text(path)

    invariants = markdown_section(body, "## Invariants")
    if not invariants.strip():
        die(f"{path} is missing required '## Invariants' section")
    defined_rule_ids = re.findall(r"^([REIU]\d+)\.", invariants, flags=re.MULTILINE)
    expected_rule_ids = set(contract["rule_ids"])
    if set(defined_rule_ids) != expected_rule_ids:
        die(
            f"{path} invariant rule inventory drifted: "
            f"expected={sorted(expected_rule_ids)!r} actual={sorted(set(defined_rule_ids))!r}"
        )
    for rule_id in contract["rule_ids"]:
        definitions = defined_rule_ids.count(rule_id)
        if definitions != 1:
            die(
                f"{path} must define rule {rule_id} exactly once in "
                f"'## Invariants' (found {definitions})"
            )

    machine = markdown_section(body, "## State Machine")
    if not machine.strip():
        die(f"{path} is missing required '## State Machine' section")
    snapshot_headings = {
        "ralplan": "## Planning Run Snapshot",
        "ralph": "## Execution Run Snapshot",
        "interview": "## Interview Run Snapshot",
        "ultrawork": "## Heartbeat",
    }
    snapshot = markdown_section(body, snapshot_headings[skill])
    for phase in contract["phases"]:
        if not re.search(rf"\b{phase}\b", machine) or not re.search(rf"\b{phase}\b", snapshot):
            die(f"{path} state machine/snapshot is missing phase: {phase}")
    for outcome in contract["outcomes"]:
        if not re.search(rf"\b{outcome}\b", body):
            die(f"{path} is missing outcome: {outcome}")

    transition_rows = parse_fsm_rows(path, machine)
    transition_targets: dict[str, list[str]] = {}
    for source, guard, target in transition_rows:
        if source != "any" and source not in contract["phases"]:
            die(f"{path} state-machine row starts from undeclared phase: {source!r}")
        cited_rules = set(re.findall(r"\b[REIU]\d+\b", f"{guard} {target}"))
        unknown_rules = sorted(cited_rules - expected_rule_ids)
        if unknown_rules:
            die(
                f"{path} state-machine row cites undefined invariant IDs: "
                f"source={source!r} target={target!r} unknown={unknown_rules!r}"
            )
        transition_targets.setdefault(source, []).append(
            normalized_fsm_target(path, contract, target)
        )

    normalized_actual = {
        source: tuple(sorted(targets))
        for source, targets in transition_targets.items()
    }
    normalized_expected = {
        source: tuple(sorted(targets))
        for source, targets in contract["transition_targets"].items()
    }
    if normalized_actual != normalized_expected:
        die(
            f"{path} normalized state-machine transition graph drifted: "
            f"expected={normalized_expected!r} actual={normalized_actual!r}"
        )

    guard_citations = len(re.findall(r"\[(?:R|E|I|U)\d+(?:,\s*(?:R|E|I|U)\d+)*\]", machine))
    if guard_citations < contract["min_guard_citations"]:
        die(
            f"{path} state-machine guards cite too few rule IDs "
            f"({guard_citations} < {contract['min_guard_citations']})"
        )


def find_marketplace_root(start: Path) -> Path:
    start = start.resolve()
    for candidate in (start, *start.parents):
        if (
            (candidate / "scripts" / "test-codex-plugin.sh").exists()
            and (candidate / "scripts" / "test-claude-plugin.sh").exists()
            and (candidate / "scripts" / "release").exists()
        ):
            return candidate
    return start


def main() -> None:
    if len(sys.argv) not in (2, 3):
        die("usage: validate-plugin-files.py <marketplace-root> [plugin-root]")

    requested_root = Path(sys.argv[1]).resolve()
    marketplace_root = find_marketplace_root(requested_root)
    if len(sys.argv) == 3:
        root = Path(sys.argv[2]).resolve()
    else:
        nested = requested_root / "plugins" / PLUGIN_NAME
        root = nested if nested.exists() else requested_root

    assert_exact_claude_agent_inventory(root)
    assert_public_docs_contract(marketplace_root, root)
    assert_routing_layer_contract(marketplace_root, root)
    assert_child_packet_ownership_contract(root)
    assert_direct_dispatch_compatibility_contract(root)
    assert_codex_child_packet_floor_contract(root)
    assert_ralph_live_heading_references(root)
    assert_orchestration_ownership_contract(root)
    assert_ralplan_proportionality_contract(root)
    for fsm_skill in FSM_CONTRACTS:
        assert_fsm_contract(root, fsm_skill)
    assert_generated_skill_wrappers(marketplace_root, root)
    assert_generated_agent_wrappers(marketplace_root, root)
    assert_opencode_contract(root)
    assert_opencode_preference_tests(marketplace_root)
    assert_opencode_mutation_tests(marketplace_root, root)
    assert_test_harness_lane_contract(marketplace_root, root)
    assert_review_boundary_mutation_tests(marketplace_root, root)
    assert_skill_reachability(marketplace_root, root)
    for skill in ALL_SKILLS:
        assert_skill(root, skill)
    assert_model_uninvocable_skill_mutation_guards(root)
    for skill in COMMAND_WRAPPERS:
        assert_command(root, skill)
    for agent in AGENTS:
        assert_agent(root, agent)
        assert_codex_agent_template(root, agent)
    assert_codex_custom_agent_count(root)
    assert_codex_agent_installer(root)
    assert_codex_task_name_contract(root)
    assert_execution_mode_contract(root)
    assert_required_reading_contract(root)
    assert_independence_mode_gates(root)
    assert_parallel_executor_contract(root)
    assert_proportional_workflow_contract(root)
    assert_ralplan_review_boundary_contract(root)
    assert_provider_guidance(root)
    assert_worktree_contract(marketplace_root, root)
    assert_tdd_routing_contract(marketplace_root, root)
    assert_hook_contract(root)
    assert_hook_test_contract(marketplace_root)
    assert_claude_manifest_skills(root)
    assert_codex_manifest(root)
    assert_claude_marketplace(marketplace_root)
    assert_codex_marketplace(marketplace_root)
    assert_expected_references(root)
    assert_no_omc_runtime_coupling(root)
    assert_no_deprecated_artifact_paths(root)
    assert_configure_subagents_contract(root)
    print("ok - skill and agent files passed static checks")


if __name__ == "__main__":
    main()
