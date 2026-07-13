#!/usr/bin/env python3
"""Static checks for Oh No Harness plugin files."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - Python < 3.11 fallback.
    tomllib = None

PUBLIC_SKILLS = [
    "using-oh-no-harness",
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
]

ALL_SKILLS = PUBLIC_SKILLS

# Skills that ship a Claude Code wrapper only (no Codex wrapper). For these,
# assert_skill validates only the Claude wrapper and asserts the Codex wrapper is
# absent. Keep identical to CLAUDE_ONLY_SKILLS in scripts/generate-skill-wrappers.py
# (this validator runs that generator's `--check` as a subprocess).
CLAUDE_ONLY_SKILLS = {"install-statusline"}

# Skills whose slash-command wrapper may set disable-model-invocation: true (the
# model must never auto-invoke them). This is the invocation dimension and is kept
# separate from CLAUDE_ONLY_SKILLS (the platform dimension) on purpose. Every other
# command wrapper must still set disable-model-invocation: false.
MODEL_UNINVOCABLE_SKILLS = {"install-statusline"}

AGENTS = [
    "explore",
    "analyst",
    "planner",
    "plan-reviewer",
    "executor",
    "executor-codex",
    "debugger",
    "verifier",
    "code-reviewer",
    "fusion-rescue-analyst",
    "plan-reviewer-codex",
    "code-reviewer-codex",
    "debugger-codex",
    "fusion-codex",
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
SKILL_CORE_ROOT = "docs/skill-core"
AGENT_CORE_ROOT = "docs/agent-core"
CODEX_AGENT_TEMPLATE_ROOT = "docs/platforms/codex-agents"
PROVIDER_DOC_ROOT = "docs/providers"
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
# lockstep with skills/ultrawork/SKILL.md and skills/using-oh-no-harness/SKILL.md.
NEXT_SKILL_GATE_REQUIRED = {"interview", "ralplan"}
NEXT_SKILL_GATE_MARKERS = (
    "## Next Skill Handoff",
    "HARD-GATE",
    "Ultrawork exception",
)
ULTRAWORK_EXCEPTION_HEADING = "## Ultrawork Exception"
ULTRAWORK_AUTO_APPROVAL_MARKERS = (
    "Interview is the only user-facing content approval gate",
    "Plan approval source: ultrawork automatic approval after interview/spec",
    "Ultrawork-approved plan or spec",
    "automatically approves `ralplan`",
    "automatically invokes `ralph`",
    "not a new\n  user approval prompt",
    "scope-change pauses",
    "Plan Approval Brief is converted into\nan internal execution record",
)
ULTRAWORK_LOOP_CONTRACT_MARKERS = (
    "## Loop Contract",
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
    "State authority:",
    "Doctor/status gate semantics:",
    "Checker outputs:",
    "Escalation rules:",
    "Terminal states:",
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
# would false-positive on skills (interview, using-oh-no-harness) whose own body
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
TRIGGER_CLASS_REQUIRED_SKILLS = (
    "ralplan",
    "ralph",
    "ultrawork",
    "verification-before-completion",
    "systematic-debugging",
)
EXPECTED_ALWAYS_READING = {
    "ralplan": {"execution-modes", "worktree-isolation"},
    "ralph": {"execution-modes", "worktree-isolation", "verification-tiers"},
    "ultrawork": {"execution-modes", "worktree-isolation"},
    "verification-before-completion": set(),
    "systematic-debugging": set(),
}
# Skills that dispatch review/verify/debug roles and must HARD-GATE the recorded
# independence mode (cross-host | same-host-parallel-fallback | inline-fallback).
# ralplan already carries this via its Findings Ledger Gate and is intentionally
# excluded here (it is the template, not a target).
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
    "using-oh-no-harness": (
        "This core file does not define platform invocation syntax",
        "matching platform source files named in its runtime composition metadata",
        "Agents remain role prompts inside a selected skill",
    ),
    "ralph": (
        "Parallel trigger",
        "use targeted subagents on subagent-capable hosts",
        "ship/block decision",
        "whole eligible batch",
        "active adapter invocation syntax",
        "Lifecycle: caller captures",
        "Role: {explore|executor|verifier|code-reviewer}",
        "adapter deciding whether the invocation is a registered custom agent",
        "Platform invocation: {active adapter invocation syntax}",
        "MUST NOT be used to close a running or pending subagent",
        # parallel-executor-dispatch (AC1/AC3): proactive disjoint-executor
        # batching is first-class in ralph skill-core and survives composition
        # into the generated wrapper.
        "proactively partition disjoint",
    ),
    "ralplan": (
        "eligible isolated subagents when they add decision-changing evidence",
        "Parallel trigger: approved-plan-handoff",
        "ordinary `oh-no-harness:ralph` choice is the parallel-capable execution",
        "keep sequential role boundaries",
        "Parallel dispatch",
        "active platform runtime document's dispatch policy",
        "Planner Draft Contract",
        "Plan Review Contract",
        "Planner Revision Contract",
    ),
    "ultrawork": (
        "separate role contexts",
        "separation can improve planning or review",
        "Parallel trigger: approved-plan-handoff",
        "Parallel trigger: natural-dispatch",
        "should keep separate role contexts",
        "independent delegated phase work",
        "active platform's dispatch authorization",
        "standing authorization",
        "per-run subagent approval",
        "`interview`/`explore`",
        "QA Loop roles",
        "Final Validation roles",
        "lifecycle cleanup requirements",
    ),
    "interview": (
        "active platform's dispatch authorization",
        "standing authorization",
        "per-run subagent approval",
        "`explore` role",
        "inline fallback reason",
    ),
    "systematic-debugging": (
        "isolated diagnostic and evidence roles when they provide decision-changing",
        "collapse diagnostic or evidence roles inline",
        "docs/shared/ralph-subagent-policy.md",
        "eligible batch dispatch",
        "active platform's dispatch authorization",
        "standing authorization",
        "per-run subagent approval",
        "post-fix review roles",
        "`code-reviewer`",
        "its security lens is needed because auth, data, file system, network, secrets, sandbox, or policy-sensitive behavior is touched",
        "its scenario lens covers post-fix validation",
    ),
    "verification-before-completion": (
        "dispatch `verifier` for nontrivial completion claims",
        "ship/block decision",
        "context-separation benefit",
        "fallback\nor no-benefit reason",
        "## Acceptance-To-Evidence Mapping",
        "## Risk Check Before Completion",
        "Completion claim",
        "active platform's dispatch authorization",
        "standing authorization",
        "per-run subagent approval",
        "the eligible `verifier` and risk-gated `code-reviewer` roles",
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
        'spawn_agent(agent_type="oh-no-<role>", ...)',
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
        "## Cross-Host Consult Channel",
        "`oh-no-harness:<role>-codex`",
        "`codex-companion.mjs task`",
        "A direct\nCodex parent answer is not a valid opposite-host shared review response",
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
        "docs/platforms/claude-code.md` `## Cross-Host Consult Channel",
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
PLATFORM_SUBAGENT_DOC_MARKERS = {
    "agent-tiers.md": (
        "docs/shared/ralph-subagent-policy.md",
        "docs/platforms/codex-ralph.md",
    ),
    "execution-modes.md": (
        "Parallel trigger",
        "docs/shared/ralph-subagent-policy.md",
    ),
    "parallel-subagents.md": (
        "## Platform Invocation",
        "docs/shared/ralph-subagent-policy.md",
        "batch dispatch, subagent",
        "Batch dispatch and subagent lifecycle rules, including close/cleanup",
        "docs/platforms/claude-code-ralph.md",
        "docs/platforms/codex-ralph.md",
    ),
}
RALPH_SUBAGENT_POLICY_MARKERS = (
    "# Ralph Subagent Policy",
    "Ralph, Ultrawork, Simplify, Systematic Debugging",
    "Interview brownfield exploration",
    "## Subagent Bias",
    "Requests to maximize subagents",
    "prefer dispatch",
    "decision-changing delegation",
    "CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION",
    "CODEX_ONLY_OH_NO_READONLY_EXPLORATION_DELEGATION",
    "credential values must be redacted",
    "may dispatch the registered read-only `oh-no-explore` custom agent",
    "use it before the next action",
    "explicit user-requested subagent task",
    "explicit session-level authorization",
    "per-run subagent approval",
    "## Subagent-Unavailable Environments",
    "prefer dispatch over silently compressing every role",
    "platform's subagent",
    "## Batch Rule",
    "eligible batch first",
    "## Subagent Lifecycle",
    "close or clean up the completed subagent",
    "MUST NOT close a running or pending subagent",
    "never use missing output as completion evidence",
    "They must not revert, overwrite, reformat, or broaden work outside their",
)
PLATFORM_ADAPTER_DOC_MARKERS = {
    "claude-code-ralph.md": (
        "CLAUDE_CODE_ONLY_RALPH_ADAPTER",
        "Workflow `agent()`",
        "oh-no-harness:<agent>",
        "@agent-oh-no-harness:<agent>",
        "background subagents",
        "close or cleanup",
    ),
    "codex-ralph.md": (
        "CODEX_ONLY_RALPH_ADAPTER",
        "## Dispatch Decision",
        "## Role Prompt Embedding",
        "Agent prompt source: docs/agent-core/<role>.md",
        "Agent prompt content:",
        "strip the Claude Code YAML frontmatter",
        "SessionStart is the primary custom-agent preparation path",
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
    "claude-code-ralph.md": ("spawn_agent", "CODEX_ONLY_RALPH_ADAPTER"),
    "codex-ralph.md": ("@agent-oh-no-harness:<agent>", "CLAUDE_CODE_ONLY_RALPH_ADAPTER"),
}
WORKTREE_SHARED_MARKERS = (
    "# Worktree Isolation",
    "## HARD-GATE",
    "## Default Location",
    "`interview` and `ralplan` do not need to run inside a worktree by default",
    "`Worktree decision`",
    "Profile policy values:",
    "registered Git worktrees",
    "Do not substitute `git clone`",
    "cannot support `git worktree add`",
    "`light direct checkout`",
    "not a gate skip",
    "keeps the automatic-worktree",
    "re-record",
    ".oh-no/worktrees/<task-slug>",
    "parent-directory siblings",
    "git -C .oh-no/worktrees/<task-slug> status",
    "git worktree remove .oh-no/worktrees/<task-slug>",
    "recursive nested worktree",
    "integration checkout's untracked",
    "git worktree add .oh-no/worktrees/<task-slug>",
    "`direct-automatic-worktree`",
    "`ultrawork` also uses automatic worktree execution",
    "integration checkout",
    "post-merge verification",
)
WORKTREE_FORBIDDEN_MARKERS = (
    "git worktree add ../<repo>-<task-slug>",
    "../<repo>-<task-slug>",
)
WORKTREE_SKILL_MARKERS = {
    "using-oh-no-harness": (
        "## Worktree Isolation Default",
        "docs/shared/worktree-isolation.md",
        ".oh-no/worktrees/<task-slug>",
        "parent-directory siblings",
        "git clone",
        "Worktree decision: direct automatic worktree",
        "Worktree decision: ultrawork automatic worktree",
    ),
    "ralplan": (
        "worktree policy",
        "Execution handoff",
        "docs/shared/worktree-isolation.md",
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
        "## Automatic Worktree Execution",
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
        "docs/shared/worktree-isolation.md",
    ),
}
EXECUTION_MODE_SHARED_MARKERS = (
    "# Execution Modes",
    "Mode is required for every handoff to `ralph`.",
    "## Execution Mode Decision Prompt",
    "## LIGHT",
    "## STANDARD",
    "## THOROUGH",
    "`ralph` must read the execution profile before editing.",
    "What observable behavior, artifact, prompt, config, or documentation will",
    "skeptical maintainer or user test before accepting",
    "Validation check",
    "docs/shared/validation-check.md",
    "Could the change affect runtime behavior",
    "Does the change alter agent behavior",
    "Can a lighter mode produce credible evidence",
    "verification budget policy",
    "Diff-Budget Gate",
    "What would force escalation while working",
    "Worktree policy",
    "Worktree location",
    "Worktree decision",
)
VERIFICATION_TIER_SHARED_MARKERS = (
    "# Verification Tiers",
    "docs/shared/validation-check.md",
    "Measurable evidence is diagnostic evidence",
    "Every tier uses the caller's canonical AC-ID acceptance-to-evidence ledger",
    "A command list is not enough",
    "direct, indirect, manual, or missing",
    "Every behavior-changing tier also uses a risk check before completion",
    "category-level risk modeling",
    "Verification budget policy",
    "Prefer focused semantic evidence before broad suites",
    "Avoid repeated broad-suite reruns",
    "Map every acceptance criterion",
    "Record the risk check before completion",
    "Include diff-budget scope review",
    "with its security lens when auth, data, network, file system, policy, or secret handling can be affected",
    "`code-reviewer`",
)
VALIDATION_CHECK_SHARED_MARKERS = (
    "# Validation Check",
    "Measurable evidence is useful, but it is not the same as satisfying acceptance",
    "Examples of measurable evidence include local command success",
    "recurring software engineering failure mode",
    "## Forbidden Patterns",
    "task-name, fixture-name, dataset-label, issue-id, or environment-specific",
    "Validation check:",
    "Acceptance criteria or user outcome it supports",
    "Why this should apply to similar work",
    "Case-specific details deliberately excluded",
    "only supported by local checks and not acceptable as a harness improvement",
    "## Similar-Work Expectation",
)
EXECUTION_MODE_SKILL_MARKERS = {
    "using-oh-no-harness": (
        "required Ralph execution mode",
        "must set a `LIGHT`, `STANDARD`, or `THOROUGH` execution mode",
    ),
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
        "docs/shared/execution-modes.md",
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
        "## Verification Budget Policy",
        "## Diff-Budget Gate",
        "## Validation Gate",
        "acceptance-to-evidence mapping",
        "story risk-check evidence",
        "validation check",
        "Ralph must set an execution mode",
        "must follow the",
    ),
    "ultrawork": (
        "docs/shared/execution-modes.md",
        "execution mode and mode source",
        "active platform runtime document",
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
# Claude-Code-only delegation roles: Claude delegates write work TO Codex, so on
# the Codex host there is nothing to delegate and no Codex custom-agent wrapper is
# generated. These agents ship a Claude wrapper (agents/<role>.md) only and MUST NOT
# require a docs/platforms/codex-agents/oh-no-<role>.toml template.
CLAUDE_ONLY_AGENT_ROLES = {
    "executor-codex",
    "plan-reviewer-codex",
    "code-reviewer-codex",
    "debugger-codex",
    "fusion-codex",
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
        "Canonical acceptance-to-evidence ledger audit and delta status",
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

# Load-bearing phrases the Codex-delegation executor role body must keep. This
# dict is only load-bearing if it is WIRED into assert_agent's if-chain (a
# defined-but-unreferenced dict gates nothing), so the wiring below is
# mandatory. Each phrase pins one clause of the executor-codex delegation
# contract: the write-capable companion invocation, versioned prompt contract,
# raw-output boundary, caller-mediated degrade, maker-verifier fence, one-hop
# guard, and honest best-effort framing.
DELEGATION_CONTRACT_AGENT_MARKERS = {
    "executor-codex": (
        "--write --cwd",
        "2>/dev/null",
        "oh-no.codex-delegation/v1",
        "direct Codex implementation",
        "executor child",
        "Do not run any test, lint, build, typecheck, parse, or verification command",
        "Verification: not run (caller-owned)",
        "codex unavailable: companion-override-path-missing",
        "Return the Codex stdout without wrapper synthesis",
        "caller derives the changed-file set",
        "caller-mediated degrade",
        "sequential native fallback",
        "does NOT author RED, verify, review, or merge",
        "one-hop guard",
        "best-effort",
        "ONE foreground Bash invocation",
    ),
    # The four read-only `*-codex` consult transports (Part B). Each is the
    # opposite-host leg of a synthesized cross-host PAIR (or, for fusion-codex,
    # one opposite-host panel slot): read-only (no write flag), synchronous (no
    # --background), packet passed with --prompt-file, caller-mediated degrade to
    # the Same-Host Parallel Fallback, one-hop guard, and honest best-effort
    # framing. The three review transports additionally require role-ownership
    # proof and the maker-verifier fence; fusion-codex requires the one-lens /
    # exact-panel-fields / never-synthesize contract and its Codex-side target.
    "plan-reviewer-codex": (
        "read-only",
        "--prompt-file",
        "2>/dev/null",
        "dispatch exactly `oh-no-plan-reviewer`",
        "role-owned `oh-no-plan-reviewer` result",
        "caller-mediated degrade",
        "Same-Host Parallel Fallback",
        "one-hop guard",
        "best-effort",
        "role-ownership",
        "proof that the dispatched role agent",
        "does NOT judge, verify, or merge",
        "ONE foreground Bash invocation",
        "is no opposite-host response",
    ),
    "code-reviewer-codex": (
        "read-only",
        "--prompt-file",
        "2>/dev/null",
        "dispatch exactly `oh-no-code-reviewer`",
        "role-owned `oh-no-code-reviewer` result",
        "caller-mediated degrade",
        "Same-Host Parallel Fallback",
        "one-hop guard",
        "best-effort",
        "role-ownership",
        "proof that the dispatched role agent",
        "does NOT judge, verify, or merge",
        "ONE foreground Bash invocation",
        "is no opposite-host response",
    ),
    "debugger-codex": (
        "read-only",
        "--prompt-file",
        "2>/dev/null",
        "dispatch exactly `oh-no-debugger`",
        "role-owned `oh-no-debugger` result",
        "caller-mediated degrade",
        "Same-Host Parallel Fallback",
        "one-hop guard",
        "best-effort",
        "role-ownership",
        "proof that the dispatched role agent",
        "does NOT judge, verify, or merge",
        "ONE foreground Bash invocation",
        "is no opposite-host response",
    ),
    "fusion-codex": (
        "read-only",
        "--prompt-file",
        "2>/dev/null",
        "dispatch exactly `oh-no-fusion-rescue-analyst`",
        "return the exact panel fields from the role-owned",
        "`oh-no-fusion-rescue-analyst` result",
        "caller-mediated degrade",
        "Same-Host Parallel Fallback",
        "one-hop guard",
        "best-effort",
        "one assigned panel lens",
        "exact panel fields",
        "never judges or synthesizes",
        "oh-no-fusion-rescue-analyst",
        "ONE foreground Bash invocation",
        "is no opposite-host response",
    ),
}

# Load-bearing phrases the reframed auto-routing skill core (T4) must carry so
# the codexExecutor toggle content is statically gated: the codexExecutor toggle
# key, the `codex-executor` command token, the default-OFF fact, the
# eligibility-preserving overlap fact, and the honest caller-owned escape-DETECTION /
# not-a-guarantee framing.
# This is only load-bearing if WIRED into assert_skill's if-chain below.
AUTO_ROUTING_CODEX_EXECUTOR_MARKERS = (
    "codexExecutor",
    "codex-executor on|off|status",
    "Default OFF.",
    "Existing Ralph eligibility remains the sole gate.",
    "already-admitted disjoint executor batch may overlap",
    "each inner companion call remains foreground",
    "fallback and integration",
    "the caller owns the escape-DETECTION guard",
    "not a sandbox guarantee",
)

SIMPLICITY_SCOPE_SKILL_MARKERS = {
    "ralplan": (
        "smallest approach",
        "Simplicity justification",
    ),
    "ralph": (
        "## Scope Trace Gate",
        "Every changed file and every meaningful changed line",
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
RALPLAN_CONSENSUS_MARKERS = (
    "## Canonical Plan Schema",
    "## Active Plan Contract",
    "## Direction Preservation Gate",
    "## Test Case Design Quality",
    "## Acceptance Criteria Contract",
    "Plan-Reviewer depth and\ninstance count are selected by the execution risk",
    "## Requirements Source And Analyst Gate",
    "## Planner Draft Contract",
    "## Plan Review Contract",
    "## Planner Revision Contract",
    "## Re-Review Rules",
    "## Findings Ledger Gate",
    "Planner draft v1",
    "Planner revision v2",
    "Review v2",
    "When Plan-Reviewer is selected, Analyst -> Planner -> Plan-Reviewer",
    "APPROVE freezes the exact reviewed Planner draft",
    "blocking | non-blocking",
    "Re-review scope: delta | full",
    "Re-review: not required (no blocking findings)",
    "Worst-case THOROUGH role dispatch chain remains bounded to two review rounds",
    "STANDARD runs one Plan-Reviewer instance",
    "required Plan-Reviewer cannot be\nskipped",
    "accepted blocking feedback is not in the\nbody",
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
RALPLAN_APPROVED_PLAN_DEFAULT_MARKERS = (
    "safe isolation",
    "decision-changing",
    "reasonable coordination cost",
)
RALPLAN_ELIGIBILITY_SURFACE_MARKERS = (
    "safe isolation",
    "decision-changing",
    "reasonable coordination cost",
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
    "inactive ceremony",
)
RALPLAN_LIGHT_APPROVAL_BRIEF_MARKERS = (
    "Compact LIGHT",
    "goal",
    "scope",
    "acceptance criteria",
    "tasks/key files",
    "verification",
    "compact profile",
    "approval",
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
USING_OH_NO_RALPLAN_HANDOFF_MARKERS = (
    "combined",
    "approval",
    "choice",
    "ralplan",
    "Do not auto-invoke",
)
USING_OH_NO_RALPLAN_HANDOFF_PATTERNS = (
    (r"approve[- ]and[- ]run", "approve-and-run"),
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
TDD_SKILL_DESCRIPTION_MARKERS = (
    "ralph-owned execution",
    "RED/GREEN/REFACTOR",
    "explicitly asked for TDD/test-first work",
    "not a top-level implementation route",
)
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
    "docs/skill-core/using-oh-no-harness.md": (
        "Treat TDD as an internal guardrail discipline",
        "not a generic implementation entrypoint",
        "Default ordinary implementation requests to `ralph`, not",
        "does not explicitly ask for TDD",
        "let that workflow invoke TDD internally when behavior changes",
    ),
    "docs/skill-core/ralph.md": (
        "Ralph owns execution mode selection or enforcement",
        "Do not route concrete add/fix/refactor/implement requests directly to `test-driven-development`",
        "Ralph invokes TDD internally",
        "Classify the story's TDD requirement",
    ),
    "docs/reference/relationships.md": (
        "internal mid-loop discipline, not a top-level implementation skill",
        "ordinary implementation requests route through `ralph`",
    ),
    "hooks/session-start": (
        "ordinary implementation request: oh-no-harness:ralph",
        "Explicit TDD/test-first request, or an internal TDD gate inside an already-selected execution path: oh-no-harness:test-driven-development",
        "ordinary implementation uses ralph unless the user explicitly requested TDD/test-first work",
        "Use oh-no-harness:test-driven-development only as an explicit TDD/test-first route or an internal guardrail",
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
        "docs/skill-core/verification-before-completion.md",
        "## Agent Roles",
        "Treat a merge or integration step as evidence-changing unless the caller proves that the final files and dependencies are identical to the verifier-audited state.",
    ),
    (
        "docs/skill-core/ralph.md",
        "## Review Gate",
        "each ruled out with a one-line reason that names why no approved AC ID, named risk, adjacent regression surface, safety invariant, or directly changed semantic model triggers it",
    ),
    (
        "docs/skill-core/ralph.md",
        "## Output",
        "Process budget outcome: planned versus actual tests/TDD cycles, role dispatch count and reasons, broad-suite count, and rescope events.",
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
    "platform-specific Fusion Rescue rules",
    "## Cross-Host Consult",
    "real assigned-lens analysis from the opposite host",
    "command or plugin capability",
    "permission preflight",
    "background acknowledgement",
    "single allowed opposite-host consult path",
    "require-cross-host",
    "redacted and minimized problem",
    "read-only analysis tools are allowed only when the active opposite host permits them",
    "[REDACTED_TOKEN]",
    "Do not record credential values",
    "## Fallback Behavior",
    "failure class",
    "missing response proof",
    "## Recursion Guard",
    "fusion depth: 1",
    "one-hop",
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
    "Intentional contradiction",
    "Missing opposite host",
    "Platform preflight denied",
    "require-cross-host unavailable",
    "Recursive consult",
    "## Caller Return",
    "return control to `ralph`",
    "return control to `systematic-debugging`",
    "Standalone mode",
    "Do not edit files directly",
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
    "Intentional contradiction": (
        "`primary`",
        "`adversarial`",
        "`pragmatic`",
        "must name the contradiction",
        "recommend the smallest next check",
    ),
    "Missing opposite host": (
        "unavailable in default mode",
        "three current-host panel slots",
        "panel availability/fallback notes",
    ),
    "Platform preflight denied": (
        "active platform-specific Fusion Rescue rules",
        "permission, auth, budget, command, plugin, foreground, or response-proof preflight",
        "must prevent the consult",
        "three current-host panel slots",
        "failure class",
    ),
    "require-cross-host unavailable": (
        "required host, command, plugin, auth, or budget is unavailable",
        "must block",
        "failure class",
        "path/auth status",
        "without exposing secret values",
    ),
    "Recursive consult": (
        "attempts to call rescue",
        "reject the nested call",
        "`fusion depth: 1`",
        "one-hop guard",
    ),
}
FUSION_RESCUE_FORBIDDEN_MARKERS = (
    "weaker mode",
    "approves a weaker",
    "weaker cross-host",
    "${CLAUDE_BIN:-claude}",
    "`--permission-mode`",
    "`dontAsk`",
    "`--no-session-persistence`",
    "Claude Opus must answer the assigned panel directly",
    "Claude-side skill or slash command",
    "Codex permission state",
    "openai/codex-plugin-cc",
    "`/codex:rescue`",
    "Codex adversarial unavailable",
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
        "`/codex:rescue`",
        "treat the cross-host consult as unavailable",
        "redacted and minimized problem packet",
        "Claude unavailable: Codex permission state is not danger-full-access",
    ),
    "claude-code-fusion-rescue.md": (
        "This platform overlay is source content for the generated Claude Code-facing",
        "oh-no-harness:fusion-codex",
        "codex-companion.mjs",
        "oh-no-fusion-rescue-analyst",
        "read-only",
        "Codex consult must run synchronously",
        "omit `--background`",
        "not a valid opposite-host panel response",
        "Codex adversarial unavailable",
        "Codex consult returned no analysis (background job acknowledgment only)",
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
    if not has_required_marker(panel_contract, "active platform-specific Fusion Rescue rules"):
        die(f"{path} Panel Contract must delegate lens pinning to platform Fusion Rescue rules")
    for marker in (
        "caller's Direction Contract",
        "exact blocked decision",
        "remaining process budget",
        "not to create a new proof architecture",
        "outside the\n  Direction Contract's goal and non-goals",
    ):
        if not has_required_marker(panel_contract, marker):
            die(f"{path} Panel Contract is missing goal-preservation marker: {marker!r}")

    cross_host = markdown_section(body, "## Cross-Host Consult")
    if not cross_host:
        die(f"{path} is missing required Fusion Rescue Cross-Host Consult section")
    for marker in (
        "real assigned-lens analysis from the opposite host",
        "active platform-specific Fusion Rescue rules",
        "command or plugin capability",
        "permission preflight",
        "foreground or response proof",
        "launch notice, queued-job message, background acknowledgement",
        "assigned panel analysis",
        "single allowed opposite-host consult path",
        "treat the cross-host consult as unavailable",
        "redacted and minimized problem packet",
        "read-only consult: no edits, no writes, no installs",
    ):
        if not has_required_marker(cross_host, marker):
            die(f"{path} Cross-Host Consult section is missing marker: {marker!r}")

    fallback = markdown_section(body, "## Fallback Behavior")
    if not fallback:
        die(f"{path} is missing required Fusion Rescue Fallback Behavior section")
    for marker in (
        "Default mode degrades instead of blocking",
        "all three panel slots on the current host",
        "platform-specific permission, auth, budget, command, plugin",
        "missing response proof",
        "not opposite-host evidence",
        "Require-cross-host mode blocks",
        "failure class",
    ):
        if not has_required_marker(fallback, marker):
            die(f"{path} Fallback Behavior section is missing marker: {marker!r}")

    recursion = markdown_section(body, "## Recursion Guard")
    if not recursion:
        die(f"{path} is missing required Fusion Rescue Recursion Guard section")
    for marker in (
        "fusion depth: 1",
        "Do not invoke rescue, fusion-rescue, cross-host consult",
        "one-hop guard",
        "current host must not call the opposite host",
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
    for marker in ("`openai/codex-plugin-cc`",):
        if marker in codex_body:
            die(f"{platform_root / 'codex-fusion-rescue.md'} contains Claude Code consult marker: {marker!r}")
    for marker in ("`${CLAUDE_BIN:-claude}`", "`--permission-mode`", "`dontAsk`"):
        if marker in claude_body:
            die(f"{platform_root / 'claude-code-fusion-rescue.md'} contains Codex consult marker: {marker!r}")
    # NB2 gated forbid: the Claude fusion overlay must NOT name the removed
    # Claude→Codex `/codex:rescue` transport (symmetric to the Codex-side
    # `openai/codex-plugin-cc` forbid above). Gates the "absent from the Claude
    # fusion overlay" guarantee instead of relying on the grep sweep alone. The
    # Codex-direction `codex-fusion-rescue.md` forbid-list mention is untouched.
    for marker in ("/codex:rescue", "codex:codex-rescue"):
        if marker in claude_body:
            die(f"{platform_root / 'claude-code-fusion-rescue.md'} still contains the removed Claude->Codex rescue transport marker: {marker!r}")


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
    loop_contract = markdown_section(body, "## Loop Contract")
    if not loop_contract:
        die(f"{path} is missing required Ultrawork Loop Contract section")
    for marker in ULTRAWORK_LOOP_CONTRACT_MARKERS:
        if not has_required_marker(body if marker.startswith("## ") else loop_contract, marker):
            die(f"{path} is missing required Ultrawork Loop Contract marker: {marker!r}")
    assert_no_forbidden_ultrawork_runtime_claims(path, body)


def assert_skill_frontmatter(path: Path, skill: str) -> dict[str, str]:
    fm = parse_frontmatter(path)
    missing = REQUIRED_SKILL_FIELDS - set(fm)
    if missing:
        die(f"{path} missing frontmatter fields: {sorted(missing)}")
    expected_name = skill.split("/")[-1]
    if fm["name"] != expected_name:
        die(f"{path} name={fm['name']!r}, expected {expected_name!r}")
    if skill in WORKFLOW_SKILLS_REQUIRING_ARGUMENT_HINT and "argument-hint" not in fm:
        die(f"{path} should define argument-hint")
    return fm


def assert_skill_wrapper(root: Path, skill: str, skill_root: str, platform: str) -> None:
    path = root / skill_root / skill / "SKILL.md"
    assert_skill_frontmatter(path, skill)
    body = read_text(path)
    core_marker = f"../../{SKILL_CORE_ROOT}/{skill}.md"
    if core_marker not in body:
        die(f"{path} should reference shared skill core: {core_marker!r}")

    if platform == "codex":
        required = "docs/platforms/codex-runtime.md"
        forbidden = (
            "docs/platforms/claude-code-runtime.md",
            "docs/platforms/claude-code.md",
            "docs/platforms/claude-code-ralph.md",
            "CLAUDE_PLUGIN_ROOT",
        )
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
            "docs/platforms/codex.md",
            "docs/platforms/codex-ralph.md",
            "spawn_agent",
        )
        if skill == "ralph" and "docs/platforms/claude-code-ralph.md" not in body:
            die(f"{path} should reference Claude Code Ralph adapter")
        if skill == "auto-routing" and "docs/platforms/claude-code-auto-routing.md" not in body:
            die(f"{path} should reference Claude Code Auto Routing overlay")
        if skill == "fusion-rescue":
            if "docs/platforms/claude-code-fusion-rescue.md" not in body:
                die(f"{path} should reference Claude Code Fusion Rescue adapter")
            if "docs/platforms/codex-fusion-rescue.md" in body:
                die(f"{path} contains forbidden Codex Fusion Rescue adapter marker")
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
    if skill in CLAUDE_ONLY_SKILLS:
        codex_wrapper = root / CODEX_SKILL_ROOT / skill / "SKILL.md"
        if codex_wrapper.exists():
            die(f"{codex_wrapper} should not exist; {skill} is a Claude-Code-only skill")
    else:
        assert_skill_wrapper(root, skill, CODEX_SKILL_ROOT, "codex")
    assert_skill_wrapper(root, skill, CLAUDE_SKILL_ROOT, "claude")

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
            if marker not in body:
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
            if marker not in body:
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
        for wrapper_root in (CODEX_SKILL_ROOT, CLAUDE_SKILL_ROOT):
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
            if marker not in body:
                die(f"{path} is missing required Ralplan-Consensus marker: {marker!r}")
        for marker in RALPLAN_FORBIDDEN_SPLIT_OPTION_MARKERS:
            if marker in body:
                die(f"{path} contains forbidden old Ralph split-option marker: {marker!r}")
    if skill == "auto-routing":
        body = read_text(path)
        for marker in AUTO_ROUTING_CODEX_EXECUTOR_MARKERS:
            if marker not in body:
                die(f"{path} is missing required Auto-Routing codex-executor marker: {marker!r}")
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
    if agent in DELEGATION_CONTRACT_AGENT_MARKERS:
        for marker in DELEGATION_CONTRACT_AGENT_MARKERS[agent]:
            if marker not in body:
                die(f"{path} is missing required Delegation-Contract agent marker: {marker!r}")
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
    if body.strip() != claude_agent_body.strip():
        die(f"{path} body must match agents/{agent}.md without YAML frontmatter")
    for marker in AGENT_SKILL_RELATIONSHIP_MARKERS:
        if marker not in body:
            die(f"{path} is missing required agent-core marker: {marker!r}")
    for pattern, reason in AGENT_CORE_FORBIDDEN_SURFACE_PATTERNS:
        if re.search(pattern, body):
            die(f"{path} contains wrong-surface platform detail: {reason}")


# All five Claude-to-Codex transports inline-duplicate only the companion-path
# resolution kernel between these stable anchors. Role-specific fallback policy
# stays outside the common block and is validated separately.
CODEX_CONSULT_AGENT_ROLES = (
    "plan-reviewer-codex",
    "code-reviewer-codex",
    "debugger-codex",
    "fusion-codex",
)
CODEX_DELEGATION_AGENT_ROLES = ("executor-codex", *CODEX_CONSULT_AGENT_ROLES)
CODEX_CONSULT_KERNEL_BEGIN = "<!-- codex-companion-kernel:begin -->"
CODEX_CONSULT_KERNEL_END = "<!-- codex-companion-kernel:end -->"
CODEX_PROMPT_CONTRACT_BEGIN = "<!-- codex-companion-prompt-contract:v1 begin -->"
CODEX_PROMPT_CONTRACT_END = "<!-- codex-companion-prompt-contract:v1 end -->"
EXPECTED_CODEX_CUSTOM_AGENT_COUNT = 9


def assert_codex_consult_agent_kernels(root: Path) -> None:
    """All five Claude-to-Codex transports share one resolution kernel.

    `generate --check` only verifies wrapper==core, not core-vs-core, so this
    guards against silent drift. The four consult roles separately forbid the
    write flag and own Same-Host Parallel Fallback; executor-codex is the one
    intentional write transport and owns sequential native fallback.
    """
    kernels: dict[str, str] = {}
    for role in CODEX_DELEGATION_AGENT_ROLES:
        path = root / AGENT_CORE_ROOT / f"{role}.md"
        body = read_text(path)
        if role in CODEX_CONSULT_AGENT_ROLES and "--write" in body:
            die(
                f"{path} is a read-only consult transport and must NOT contain "
                "'--write' (the companion call omits the write flag)"
            )
        begin = body.find(CODEX_CONSULT_KERNEL_BEGIN)
        end = body.find(CODEX_CONSULT_KERNEL_END)
        if begin < 0 or end < 0 or end < begin:
            die(
                f"{path} is missing the anchored companion-path resolution kernel "
                f"({CODEX_CONSULT_KERNEL_BEGIN!r} ... {CODEX_CONSULT_KERNEL_END!r})"
            )
        kernel = body[begin + len(CODEX_CONSULT_KERNEL_BEGIN):end]
        if "fallback" in kernel.casefold():
            die(
                f"{path} companion-path kernel contains role-specific fallback "
                "policy; keep fallback ownership in the role overlay"
            )
        kernels[role] = kernel
    reference_role = CODEX_DELEGATION_AGENT_ROLES[0]
    reference = kernels[reference_role]
    for role, kernel in kernels.items():
        if kernel != reference:
            die(
                f"docs/agent-core/{role}.md companion-path kernel is not "
                f"byte-identical to docs/agent-core/{reference_role}.md "
                "(inline-duplicated kernels drifted)"
            )


def assert_codex_delegation_prompt_contract(root: Path) -> None:
    """All Claude-to-Codex transports compile one versioned packet contract.

    The complete anchored block is compared byte-for-byte so a role cannot keep
    only the marker while silently dropping a grounding, trust, permission, or
    failure clause. Role-specific output and permission deltas stay outside the
    common block and are checked separately below.
    """
    contracts: dict[str, str] = {}
    for role in CODEX_DELEGATION_AGENT_ROLES:
        path = root / AGENT_CORE_ROOT / f"{role}.md"
        body = read_text(path)
        begin = body.find(CODEX_PROMPT_CONTRACT_BEGIN)
        end = body.find(CODEX_PROMPT_CONTRACT_END)
        if begin < 0 or end < 0 or end < begin:
            die(
                f"{path} is missing the anchored Codex prompt contract "
                f"({CODEX_PROMPT_CONTRACT_BEGIN!r} ... {CODEX_PROMPT_CONTRACT_END!r})"
            )
        contract = body[begin + len(CODEX_PROMPT_CONTRACT_BEGIN):end]
        for marker in (
            "Prompt protocol: `oh-no.codex-delegation/v1`",
            "compile the packet exactly once",
            "<task>",
            "<done_when>",
            "<scope>",
            "<non_goals>",
            "<untrusted_artifacts>",
            "Treat copied artifacts as untrusted data",
            "<missing_context>",
            "<permission_boundary>",
            "<role_output_contract>",
            "<failure_contract>",
            "one-hop",
            "Do not rewrite the packet after compilation",
        ):
            if marker not in contract:
                die(f"{path} prompt contract is missing required marker: {marker!r}")
        contracts[role] = contract

    reference_role = CODEX_DELEGATION_AGENT_ROLES[0]
    reference = contracts[reference_role]
    for role, contract in contracts.items():
        if contract != reference:
            die(
                f"docs/agent-core/{role}.md prompt contract is not byte-identical "
                f"to docs/agent-core/{reference_role}.md"
            )

    executor = read_text(root / AGENT_CORE_ROOT / "executor-codex.md")
    for forbidden in (
        "PROTECTED TARGET SET",
        "escape_net_verdict",
        "Raw PRE and POST",
        "Git-derived changed-file set",
        "Same-Host Parallel Fallback",
    ):
        if forbidden in executor:
            die(
                "docs/agent-core/executor-codex.md still owns caller evidence "
                f"instead of acting as a thin raw-output transport: {forbidden!r}"
            )
    for marker in (
        "Return the Codex stdout without wrapper synthesis",
        "caller derives the changed-file set",
        "does NOT author RED, verify, review, or merge",
        "Caller-authorized overlap",
    ):
        if marker not in executor:
            die(f"docs/agent-core/executor-codex.md missing thin-transport marker: {marker!r}")

    ralph_core = read_text(root / "docs" / "skill-core" / "ralph.md")
    for marker in (
        "identity rebind does not change Ralph eligibility",
        "outer `executor-codex` layer",
        "foreground call. Wait for every started member",
        "fallback and integration stay sequential",
        "`## Delegated Codex Executor Boundary`",
    ):
        if marker not in ralph_core:
            die(f"docs/skill-core/ralph.md missing delegated executor marker: {marker!r}")

    caller_policy = read_text(root / "docs" / "shared" / "ralph-subagent-policy.md")
    for marker in (
        "## Delegated Codex Executor Boundary",
        "transport returns raw Codex stdout",
        "caller-owned escape guard",
        "filesystem sentinel",
        "`path + mtime + size` manifest",
        "EXCLUDING the delegated task worktrees",
        "same path, mtime, and size",
        "worktree diff alone does not prove confinement",
        "identity rebind does not change the existing Batch Rule",
        "fallback and integration stay sequential",
    ):
        if marker not in caller_policy:
            die(f"docs/shared/ralph-subagent-policy.md missing caller guard marker: {marker!r}")

    # Source-aware stale-contract scan. Generic words such as ``snapshot`` and
    # ``filesystem sentinel`` remain valid on the CALLER side, so only exact
    # executor-wrapper-owned promises are forbidden. Scan every active runtime,
    # generated wrapper, documentation, and test/script surface instead of a
    # hand-picked three-file list. Skip this validator because it necessarily
    # contains the forbidden literals as negative fixtures.
    stale_executor_wrapper_markers = (
        "The heavy delegation contract",
        "git-derived changed-file return, pre/post snapshots",
        "returns Codex's result, the git-derived changed-file set",
        "Capture a PRE-snapshot of the PROTECTED TARGET SET",
        "The PROTECTED TARGET SET is everything EXCEPT the slice's own worktree",
        "git-derived changed-file set, not stdout, is the evidence",
        "Raw PRE and POST PROTECTED TARGET SET snapshots",
        "return git-derived evidence",
        "executor-codex delegation, escape-net clean",
    )
    marketplace_root = root.parent.parent
    active_roots = (
        root / "agents",
        root / "commands",
        root / "docs",
        root / "hooks",
        root / "scripts",
        root / "skills",
        root / "skills-claude",
        marketplace_root / "scripts",
    )
    validator_path = Path(__file__).resolve()
    active_paths: set[Path] = set()
    for active_root in active_roots:
        if active_root.is_file():
            candidates = (active_root,)
        elif active_root.is_dir():
            candidates = active_root.rglob("*")
        else:
            continue
        for candidate in candidates:
            if not candidate.is_file() or candidate.resolve() == validator_path:
                continue
            # These roots are executable/configuration/documentation source
            # surfaces, not asset directories. Scan every file so extensionless
            # hooks/scripts and platform wrappers such as ``run-hook.cmd`` cannot
            # fall through an allow-list gap.
            active_paths.add(candidate)

    for path in sorted(active_paths):
        text = read_active_stale_scan_text(path)
        if text is None:
            continue
        for marker in stale_executor_wrapper_markers:
            if marker in text:
                die(f"{path} retains stale executor-wrapper evidence wording: {marker!r}")


def assert_codex_custom_agent_count(root: Path) -> None:
    """Regression guard (N3): the Codex custom-agent count stays 9. The five
    `*-codex` roles are Claude-only and emit no Codex template, so this only
    catches an accidental count change."""
    template_root = root / CODEX_AGENT_TEMPLATE_ROOT
    templates = sorted(template_root.glob("oh-no-*.toml"))
    if len(templates) != EXPECTED_CODEX_CUSTOM_AGENT_COUNT:
        die(
            f"expected {EXPECTED_CODEX_CUSTOM_AGENT_COUNT} Codex custom-agent "
            f"templates under {CODEX_AGENT_TEMPLATE_ROOT}, found {len(templates)}: "
            f"{[p.name for p in templates]}"
        )
    non_claude = [a for a in AGENTS if a not in CLAUDE_ONLY_AGENT_ROLES]
    if len(non_claude) != EXPECTED_CODEX_CUSTOM_AGENT_COUNT:
        die(
            f"expected {EXPECTED_CODEX_CUSTOM_AGENT_COUNT} non-Claude-only agents "
            f"(AGENTS minus CLAUDE_ONLY_AGENT_ROLES), found {len(non_claude)}: "
            f"{non_claude}"
        )
    if set(non_claude) != set(CODEX_AGENT_MODEL_CONFIG):
        die(
            "Codex custom-agent model config must cover exactly the generated "
            f"roles: expected {sorted(non_claude)}, found "
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
        f"Agent prompt content:\n\n"
        f"{agent_core}"
    )
    if data["developer_instructions"] != expected_instructions:
        die(
            f"{path} developer_instructions must exactly match "
            f"docs/agent-core/{agent}.md"
        )
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
        "SessionStart is the primary user-scope ensure point",
    ):
        if marker not in relationships:
            die(f"relationships.md does not mention required structure marker `{marker}`")


def assert_execution_mode_contract(root: Path) -> None:
    path = root / "docs" / "shared" / "execution-modes.md"
    text = read_text(path)
    for marker in EXECUTION_MODE_SHARED_MARKERS:
        if not has_required_marker(text, marker):
            die(f"{path} is missing required Execution-Mode contract marker: {marker!r}")
    shared_root = root / "docs" / "shared"
    for filename, markers in PLATFORM_SUBAGENT_DOC_MARKERS.items():
        doc = shared_root / filename
        doc_text = read_text(doc)
        for marker in markers:
            if not has_required_marker(doc_text, marker):
                die(f"{doc} is missing required Platform-Subagent marker: {marker!r}")
    policy_path = shared_root / "ralph-subagent-policy.md"
    policy_text = read_text(policy_path)
    for marker in RALPH_SUBAGENT_POLICY_MARKERS:
        if not has_required_marker(policy_text, marker):
            die(f"{policy_path} is missing required Ralph-Subagent-Policy marker: {marker!r}")
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


def assert_verification_tier_contract(root: Path) -> None:
    path = root / "docs" / "shared" / "verification-tiers.md"
    text = read_text(path)
    for marker in VERIFICATION_TIER_SHARED_MARKERS:
        if marker not in text:
            die(f"{path} is missing required Verification-Tier contract marker: {marker!r}")


def assert_validation_check_contract(root: Path) -> None:
    path = root / "docs" / "shared" / "validation-check.md"
    text = read_text(path)
    for marker in VALIDATION_CHECK_SHARED_MARKERS:
        if marker not in text:
            die(f"{path} is missing required Validation-Check contract marker: {marker!r}")


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


def assert_cross_host_review_contract(root: Path) -> None:
    # D1: governance content-marker for the neutral shared cross-host-review doc,
    # so it cannot be silently gutted or drift from the fusion-rescue mechanism.
    path = root / "docs" / "shared" / "cross-host-review.md"
    text = read_text(path)
    for marker in (
        "# Cross-Host Review",
        "## Cross-Host Consult Channel",
        "run the review on BOTH the current host and the opposite host",
        "does not make dependent DIFFERENT roles eligible for the same\nbatch",
        # The default-mode degrade is now the Same-Host Parallel Fallback (two
        # same-host agents), guarded by the D1b markers below; the obsolete
        # "degrade to current-host-only" single-pass marker was retired.
        "require-cross-host",
        "Recursion Guard (Cross-Host Hop Scope)",
        "one cross-host hop",
        "requested-direction-change: yes",
    ):
        if not has_required_marker(text, marker):
            die(f"{path} is missing required Cross-Host-Review marker: {marker!r}")

    # D1b: verifier is OUT of cross-host scope (an unconditionally single self-host
    # independent pass, never a cross-host/same-host pair), and the same-host
    # parallel fallback contract is present. Bound the in-scope role-list slice at
    # the "Exception" paragraph so the review-then-verify SEQUENCING prose (which
    # legitimately still names the verifier as a dependent later stage) is not read
    # as an in-scope role listing, and bound the out-of-scope slice at the
    # "does not apply" sentence so the out-of-scope check needs an explicit verifier
    # exclusion, not the exclusion of some other role.
    when_applies = markdown_section(text, "## When It Applies")
    if not when_applies:
        die(f"{path} is missing required '## When It Applies' section")
    exception_idx = when_applies.find("Exception")
    out_idx = when_applies.find("does not apply")
    in_scope_end = exception_idx if exception_idx >= 0 else out_idx
    in_scope_text = when_applies if in_scope_end < 0 else when_applies[:in_scope_end]
    out_of_scope_text = "" if out_idx < 0 else when_applies[out_idx:]
    if "verifier" in in_scope_text:
        die(f"{path} '## When It Applies' must NOT list `verifier` as an in-scope cross-host role (it is now an unconditionally single self-host pass)")
    if "verifier" not in out_of_scope_text:
        die(f"{path} out-of-scope sentence must list `verifier` (it is no longer in cross-host scope)")
    for marker in (
        "Same-Host Parallel Fallback",
        "exactly two same-host",
        "The\nconfirming `verifier` is a dependent later stage",
        "A verifier spawned before the\nselected code-review stage completes is stale evidence",
    ):
        if not has_required_marker(text, marker):
            die(f"{path} is missing required same-host-fallback contract marker: {marker!r}")

    # D1b (negative forbid): after Part A the verifier cross-host-pair form must be
    # ABSENT from the canonical contract AND the four skill cores. The verifier is
    # an unconditionally single self-host independent pass at STANDARD AND THOROUGH
    # — never a cross-host or same-host pair, never a union/conservative merge. This
    # matches the verifier cross-host-pair form REGARDLESS of exact wording,
    # including cross-host-review.md's Exception variants ("the confirming verifier
    # also runs as the cross-host pair", "At STANDARD the confirming verifier runs
    # as a single independent pass"). Every form below is verifier-only —
    # reviewer/debugger contracts never say "at THOROUGH" pairing or
    # "union/conservative" merges — so the surviving reviewer/debugger cross-host
    # rules cannot false-positive here.
    verifier_pair_forbidden = (
        "cross-host/parallel pair at THOROUGH",
        "cross-host / parallel pair at THOROUGH",
        "union/conservative",
        "single at STANDARD",
        "runs as a single independent pass",
        "also runs as the cross-host pair",
    )
    # Scan every layer a dispatched verifier (or its caller) actually loads:
    # the shared contracts, the four dispatching skill cores, and the whole
    # agent layer — role cores plus BOTH generated wrapper sets. The verifier
    # agent core carried a stale pair contract that a skill-core-only scan
    # missed.
    verifier_pair_scan_files = (
        path,
        root / "docs" / "skill-core" / "ralph.md",
        root / "docs" / "skill-core" / "ultrawork.md",
        root / "docs" / "skill-core" / "systematic-debugging.md",
        root / "docs" / "skill-core" / "verification-before-completion.md",
        *sorted((root / "docs" / "shared").glob("*.md")),
        *sorted((root / "docs" / "agent-core").glob("*.md")),
        *sorted((root / "agents").glob("*.md")),
        *sorted((root / "docs" / "platforms").glob("*.md")),
        *sorted((root / "docs" / "platforms" / "codex-agents").glob("*.toml")),
    )
    for scan_path in verifier_pair_scan_files:
        scan_text = read_text(scan_path)
        for forbidden in verifier_pair_forbidden:
            if has_required_marker(scan_text, forbidden):
                die(
                    f"{scan_path} still describes the verifier as a cross-host/THOROUGH pair "
                    f"(the verifier is now an unconditionally single self-host pass): {forbidden!r}"
                )

    role_owned = markdown_section(text, "## Role-Owned Review Instances")
    if not role_owned:
        die(f"{path} is missing required '## Role-Owned Review Instances' section")
    for marker in (
        "Cross-host review is a role-dispatch contract",
        "Parent inline opposite-host consult is not a valid cross-host\nreview response",
        "only for shared cross-host review of Ralplan's `plan-reviewer`, plus\n`code-reviewer` and `debugger`",
    ):
        if not has_required_marker(role_owned, marker):
            die(f"{path} '## Role-Owned Review Instances' is missing marker: {marker!r}")

    sequencing = markdown_section(text, "## Sequencing Preserved")
    if not sequencing:
        die(f"{path} is missing required '## Sequencing Preserved' section")
    for marker in (
        "code-reviewer pair\n  -> wait/capture both reviewer outputs",
        "-> resolve findings or record a blocker\n  -> confirming verifier pass",
        "dependent distinct roles are not run in\nparallel",
    ):
        if not has_required_marker(sequencing, marker):
            die(f"{path} '## Sequencing Preserved' is missing review-then-verify dependency marker: {marker!r}")

    ralph_review_gate = markdown_section(read_text(root / "docs" / "skill-core" / "ralph.md"), "## Review Gate")
    if not ralph_review_gate:
        die("docs/skill-core/ralph.md is missing required '## Review Gate' section")
    for marker in (
        "Review Gate dependency graph",
        "verifier eligible to start: yes | no",
        "verifier started after reviewer completion: yes | no | not-required",
        "A verifier spawned before that point is stale",
        "ledger must show `verifier started after reviewer completion: yes`",
    ):
        if not has_required_marker(ralph_review_gate, marker):
            die(f"docs/skill-core/ralph.md Review Gate is missing sequencing marker: {marker!r}")

    ultrawork_final_validation = markdown_section(
        read_text(root / "docs" / "skill-core" / "ultrawork.md"),
        "### Phase 4: Final Validation",
    )
    if not ultrawork_final_validation:
        die("docs/skill-core/ultrawork.md is missing required '### Phase 4: Final Validation' section")
    for marker in (
        "Final Validation dependency graph",
        "verifier eligible to start: yes | no",
        "verifier started after reviewer completion: yes | no | not-required",
        "A verifier spawned before that point is stale",
        "ledger must show `verifier started after reviewer completion: yes`",
    ):
        if not has_required_marker(ultrawork_final_validation, marker):
            die(f"docs/skill-core/ultrawork.md Final Validation is missing sequencing marker: {marker!r}")

    # D2: runtime-doc Cross-Host Consult Channel cross-leak hygiene. Each runtime
    # doc's channel section must carry only its own outbound-to-opposite-host
    # invocation, mirroring the fusion-rescue overlay cross-leak guard.
    platform_root = root / "docs" / "platforms"
    heading = "## Cross-Host Consult Channel"

    codex_runtime_channel = markdown_section(read_text(platform_root / "codex-runtime.md"), heading)
    if not codex_runtime_channel:
        die(f"{platform_root / 'codex-runtime.md'} is missing required {heading!r} section")
    for marker in ("trigger-loaded", "docs/platforms/codex.md"):
        if not has_required_marker(codex_runtime_channel, marker):
            die(f"codex-runtime.md {heading!r} is missing trigger-load pointer: {marker!r}")
    codex_channel = markdown_section(read_text(platform_root / "codex.md"), heading)
    if not has_required_marker(codex_channel, "`${CLAUDE_BIN:-claude}`"):
        die(f"codex.md {heading!r} must carry the Codex-to-Claude argument vector")
    for marker in (
        "Codex parent must not run\n`${CLAUDE_BIN:-claude}` inline",
        "spawn_agent(agent_type=\"oh-no-<role>\"",
        "A parent inline Claude consult is not a\nvalid shared cross-host review pass",
    ):
        if not has_required_marker(codex_channel, marker):
            die(f"codex.md {heading!r} is missing shared-review ownership marker: {marker!r}")
    for marker in ("openai/codex-plugin-cc", "`/codex:rescue`"):
        if marker in codex_channel:
            die(f"codex.md {heading!r} contains opposite-host (Claude-side) consult marker: {marker!r}")
    # Part A: the verifier has no cross-host leg on EITHER direction. The
    # Codex-side spawn role list must be exactly the three reviewer/debugger
    # roles and must carry the explicit verifier exclusion sentence (the
    # verifier-pair phrase scan cannot catch a bare role listing).
    if not has_required_marker(codex_channel, "`plan-reviewer`,\n`code-reviewer`, or `debugger`"):
        die(
            f"codex.md {heading!r} must list exactly `plan-reviewer`, `code-reviewer`, "
            "or `debugger` as the shared cross-host role set (the verifier has no cross-host leg)"
        )
    if not has_required_marker(codex_channel, "the verifier has no cross-host leg"):
        die(f"codex.md {heading!r} is missing the verifier exclusion sentence")

    # D2 (Part B inversion): the Claude→Codex transport is now the read-only
    # `*-codex` consult agents running `codex-companion.mjs`, not `/codex:rescue`.
    # The channel must carry the codex-companion transport + the `*-codex` dispatch
    # + the role-ownership packet instruction, keep the semantic "a direct Codex
    # parent answer is not a valid opposite-host shared review response" sentence,
    # and must NOT contain `/codex:rescue` (fully removed on the Claude side) or
    # the opposite-host Codex-side argument-vector markers.
    claude_runtime_channel = markdown_section(read_text(platform_root / "claude-code-runtime.md"), heading)
    if not claude_runtime_channel:
        die(f"{platform_root / 'claude-code-runtime.md'} is missing required {heading!r} section")
    for marker in ("trigger-loaded", "docs/platforms/claude-code.md"):
        if not has_required_marker(claude_runtime_channel, marker):
            die(f"claude-code-runtime.md {heading!r} is missing trigger-load pointer: {marker!r}")
    claude_channel = markdown_section(read_text(platform_root / "claude-code.md"), heading)
    for marker in (
        "codex-companion.mjs",
        "`oh-no-harness:<role>-codex`",
        "requires Codex to dispatch the matching\n`oh-no-<role>` agent",
        "A direct\nCodex parent answer is not a valid opposite-host shared review response",
    ):
        if not has_required_marker(claude_channel, marker):
            die(f"claude-code.md {heading!r} is missing codex-companion transport / shared-review ownership marker: {marker!r}")
    for marker in ("`/codex:rescue`", "/codex:rescue", "`${CLAUDE_BIN:-claude}`", "`--permission-mode`", "`dontAsk`"):
        if marker in claude_channel:
            die(f"claude-code.md {heading!r} contains a forbidden marker (removed Claude→Codex rescue transport or opposite-host Codex-side consult marker): {marker!r}")


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
    path = root / "docs" / "shared" / "worktree-isolation.md"
    text = read_text(path)
    for marker in WORKTREE_SHARED_MARKERS:
        if marker not in text:
            die(f"{path} is missing required Worktree contract marker: {marker!r}")

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
    for path in description_paths:
        description = parse_frontmatter(path).get("description", "")
        for marker in TDD_SKILL_DESCRIPTION_MARKERS:
            if marker not in description:
                die(f"{path} description is missing TDD routing marker: {marker!r}")

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
            if marker not in text:
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

    test_script_markers = {
        "scripts/test-codex-plugin.sh": (
            "explicit TDD/test-first smoke request",
            "internal mid-loop discipline",
            "not a top-level implementation route",
        ),
        "scripts/test-claude-plugin.sh": (
            "Explicit TDD/test-first smoke request",
            "internal mid-loop discipline",
            "not a top-level implementation route",
        ),
    }
    for relative_path, markers in test_script_markers.items():
        path = marketplace_root / relative_path
        text = read_text(path)
        for marker in markers:
            if marker not in text:
                die(f"{path} is missing live-test TDD routing marker: {marker!r}")
        if "Implement a small behavior change. Smoke test only" in text:
            die(f"{path} still uses a generic implementation prompt for TDD smoke tests")

    checked_paths = (
        description_paths
        + [
            command_path,
            root / SKILL_CORE_ROOT / "using-oh-no-harness.md",
            root / CODEX_SKILL_ROOT / "using-oh-no-harness" / "SKILL.md",
            root / CLAUDE_SKILL_ROOT / "using-oh-no-harness" / "SKILL.md",
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

    required_events = {"SessionStart", "UserPromptSubmit"}
    actual_events = set(events)
    missing = required_events - actual_events
    if missing:
        die(f"{hooks_path} is missing hook events: {sorted(missing)}")

    user_prompt_groups = events.get("UserPromptSubmit")
    if not isinstance(user_prompt_groups, list) or len(user_prompt_groups) != 1:
        die(f"{hooks_path} should define exactly one UserPromptSubmit group")
    group = user_prompt_groups[0]
    if "matcher" in group:
        die(f"{hooks_path} UserPromptSubmit should omit matcher because the event ignores it")
    handlers = group.get("hooks")
    if not isinstance(handlers, list) or len(handlers) != 1:
        die(f"{hooks_path} UserPromptSubmit should define exactly one hook handler")
    handler = handlers[0]
    if handler.get("type") != "command":
        die(f"{hooks_path} UserPromptSubmit handler should be type=command")
    if "ralph-platform-adapter" not in handler.get("command", ""):
        die(f"{hooks_path} UserPromptSubmit should invoke ralph-platform-adapter")
    if handler.get("async") is not False:
        die(f"{hooks_path} UserPromptSubmit handler should set async=false")

    script_path = root / "hooks" / "ralph-platform-adapter"
    script_text = read_text(script_path)
    for marker in (
        "OH_NO_RALPH_PLATFORM_ADAPTER",
        "CLAUDE_CODE_ONLY_RALPH_ADAPTER",
        "CODEX_ONLY_RALPH_ADAPTER",
        "Codex custom-agent preflight",
        "install-codex-agents",
        "--scope user --ensure --quiet",
        "quiet ensure",
        "prompt_text=",
        'json.loads(raw).get("prompt", "")',
        "lowered_prompt=",
        '"what "*',
        '"oh-no-harness:ralph"*',
        "docs/shared/ralph-subagent-policy.md",
        "docs/platforms/claude-code-ralph.md",
        "docs/platforms/codex-ralph.md",
        "hookEventName\": \"UserPromptSubmit",
    ):
        if marker not in script_text:
            die(f"{script_path} is missing required hook marker: {marker!r}")
    for forbidden in (
        '*" ralph "*',
        '*"run ralph"*',
        '*"use ralph',
        '*"ralph 로 구현"*',
        '*"랄프"*',
    ):
        if forbidden in script_text:
            die(f"{script_path} contains broad Ralph hook matcher: {forbidden!r}")

    session_start_path = root / "hooks" / "session-start"
    session_start_text = read_text(session_start_path)
    for marker in (
        "OH_NO_RG_SEARCH_TOOLING",
        "command -v rg",
        "rg --files",
        "Use native skill loading",
        "using-oh-no-harness",
        "OH_NO_FORCED_ROUTING",
        "CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION",
        "CODEX_ONLY_OH_NO_READONLY_EXPLORATION_DELEGATION",
        "Custom-Agent Spawn Troubleshooting",
        "docs/platforms/codex.md",
        "before fallback",
        "sub-agents, delegation, and parallel agent work proactively",
        "every in-scope subagent result is a workflow dependency",
        "wait to final status, capture it, and use it",
        "MUST NOT redo delegated work inline",
        "redact credential values",
        "never allowed for no-skill read-only lookup",
        "you may dispatch the registered read-only oh-no-explore custom agent",
        "use it before the next action",
        "first select the relevant Oh No Harness skill",
        "spawned in-scope subagent results are workflow dependencies",
        "Codex custom-agent ensure warning",
        "--scope user --ensure --quiet",
        # Codex-executor delegation block (T3 hook-only rule). These statically
        # gate the OH_NO_CODEX_EXECUTOR_DELEGATION block's load-bearing phrases so
        # the hook-only override is not a reachability blind spot: open/close
        # tags, the executor-codex re-bind, the executor-only fence, the
        # eligibility-preserving overlap, caller-mediated degrade, and the honest
        # best-effort caller-owned escape-DETECTION framing.
        "<OH_NO_CODEX_EXECUTOR_DELEGATION>",
        "</OH_NO_CODEX_EXECUTOR_DELEGATION>",
        "Codex-executor delegation is ON (session-scoped, Claude-Code-only)",
        "dispatch `oh-no-harness:executor-codex` INSTEAD of `oh-no-harness:executor`",
        "Executor-only fence: ONLY the executor role is delegated",
        "Eligibility-preserving rebind:",
        "existing Ralph eligibility remains the sole gate",
        "outer executor-codex agent layer",
        "Each inner companion call remains foreground",
        "Caller-mediated degrade:",
        "inspects any partial worktree delta",
        "Best-effort framing (honest)",
        "The caller owns the escape-DETECTION guard",
        "EXCLUDING the delegated task worktrees",
    ):
        if marker not in session_start_text:
            die(f"{session_start_path} is missing required session-start marker: {marker!r}")
    for forbidden in (
        "OH_NO_SKILL_CORE",
        "Below is the full content",
        "using_oh_no_core",
    ):
        if forbidden in session_start_text:
            die(f"{session_start_path} still embeds full using-oh-no-harness core content: {forbidden!r}")


def assert_hook_test_contract(marketplace_root: Path) -> None:
    test_markers = {
        "scripts/test-codex-plugin.sh": (
            "Use oh-no-harness:ralph with Parallel trigger: approved-plan-handoff",
            "What does Parallel trigger: approved-plan-handoff mean?",
            "What is oh-no-harness:ralph?",
            "Explain oh-no-harness:ralph before I choose it.",
            "What does Ralph do in the final review step?",
            "Review the current diff, especially the ralph hook adapter.",
            "Compare ralplan and ralph before implementation.",
            "Should I run ralph?",
            "Do not run ralph yet.",
            "When would you run ralph?",
            "Can you explain how to run ralph?",
            "ralph 로 진행하는 방법 알려줘",
            "ralph로 구현하는 방법 알려줘",
            "랄프로 진행하는 방법 알려줘",
            "Please run ralph now.",
            "ralph 로 구현해줘",
            "ralph 로 진행해줘",
            "랄프로 구현해줘",
            "stale installed plugin version marker",
            "named-agent-proof-map.tsv",
            "OH_NO_NAMED_AGENT_PROOF_REQUEST",
            "OH_NO_NAMED_AGENT_PROOF_OK",
            "oh-no-harness:ralph implement the approved plan",
            "Review the approved plan, then run ralph on it",
            "marker-only Codex prompt",
            "generic Codex Ralph discussion prompt",
            "--fusion-rescue-live",
            "OH_NO_FUSION_RESCUE_LIVE",
            "OH_NO_CODEX_FUSION_RESCUE_LIVE_OK",
            "OH_NO_CLAUDE_FUSION_PANEL_OK",
            "Claude Opus must answer the assigned panel directly",
            "forbidden_claude_prompt_patterns",
            "allowed_claude_prompt_fixtures",
            "forbidden_claude_prompt_fixtures",
            "Claude-side workflow tooling instead of direct Opus review",
        ),
        "scripts/test-claude-plugin.sh": (
            "Use oh-no-harness:ralph with Parallel trigger: approved-plan-handoff",
            "What does Parallel trigger: approved-plan-handoff mean?",
            "What is oh-no-harness:ralph?",
            "Explain oh-no-harness:ralph before I choose it.",
            "What does Ralph do in the final review step?",
            "Review the current diff, especially the ralph hook adapter.",
            "Compare ralplan and ralph before implementation.",
            "Should I run ralph?",
            "Do not run ralph yet.",
            "When would you run ralph?",
            "Can you explain how to run ralph?",
            "Please run ralph now.",
            "ralph 로 구현해줘",
            "ralph 로 진행해줘",
            "랄프로 구현해줘",
            "oh-no-harness:ralph implement the approved plan",
            "Review the approved plan, then run ralph on it",
            "marker-only Claude prompt",
            "generic Claude Ralph discussion prompt",
            "--fusion-rescue-live",
            "OH_NO_FUSION_RESCUE_LIVE",
            "oh-no-harness:fusion-codex",
            "--allowedTools",
            "codex-companion.mjs",
            "permission_denials",
            "forwarded Codex output is unavailable",
            "OH_NO_FUSION_CODEX_RETURN_OK",
            "OH_NO_FUSION_CODEX_PANEL_OK",
        ),
    }
    for relative_path, markers in test_markers.items():
        path = marketplace_root / relative_path
        text = read_text(path)
        for marker in markers:
            if marker not in text:
                die(f"{path} is missing approved-plan-handoff hook-test marker: {marker!r}")


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
            "no `UserPromptSubmit`",
            "narrow `UserPromptSubmit` Ralph adapter",
        ),
        "README.ko.md": (
            "`ralph`, `ralph with parallel subagents`, `ultrawork`",
            "`UserPromptSubmit`/`PreToolUse`/`PostToolUse` 미사용",
            "좁은 `UserPromptSubmit` Ralph adapter",
        ),
    }
    for filename, (split_option, stale_hook_claim, required_hook_marker) in readme_expectations.items():
        path = marketplace_root / filename
        text = read_text(path)
        if split_option in text:
            die(f"{path} still presents legacy `ralph with parallel subagents` as a separate handoff option")
        if stale_hook_claim in text:
            die(f"{path} still claims UserPromptSubmit is unused")
        if required_hook_marker not in text:
            die(f"{path} should mention the narrow UserPromptSubmit Ralph adapter")

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
    for platform in ("codex", "claude"):
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
        die(f"test harness lane contract failed:\n{details}")

    for name in ("test-codex-plugin.sh", "test-claude-plugin.sh"):
        test_path = marketplace_root / "scripts" / name
        test_body = read_text(test_path)
        for marker in (
            "only the Ralplan planning phase owns that role",
            "APPROVE freezes the exact reviewed Planner draft",
            "Optional follow-up: NB1",
            "Planner revision: not run",
        ):
            if not has_required_marker(test_body, marker):
                die(f"{test_path} is missing plan-review boundary expectation: {marker!r}")
    codex_test = read_text(marketplace_root / "scripts" / "test-codex-plugin.sh")
    claude_test = read_text(marketplace_root / "scripts" / "test-claude-plugin.sh")
    for body, label, forbidden in (
        (codex_test, "Codex", "Wave 2: plan-reviewer, executor, debugger"),
        (claude_test, "Claude", "Wave 2: oh-no-harness:plan-reviewer, oh-no-harness:executor, oh-no-harness:debugger"),
    ):
        if forbidden in body:
            die(f"{label} Ralph live smoke still directly dispatches plan-reviewer")


def assert_parallel_executor_contract(root: Path) -> None:
    # Parallel-executor-dispatch contract (R1-R6 / AC1-AC4). Section-scoped so a
    # marker cannot be satisfied by unrelated or wrong-section text, and so the
    # canonical homes (bias + per-executor check in the shared policy; loop and
    # dispatch shape in ralph.md) cannot silently drift. Pre-edit docs lack these
    # phrases, so this guard fails before the change and passes after it.
    shared = root / "docs" / "shared"
    policy = read_text(shared / "ralph-subagent-policy.md")
    bias = markdown_section(policy, "## Subagent Bias")
    if not has_required_marker(bias, "disjoint implementation (executor) work"):
        die(
            "ralph-subagent-policy.md `## Subagent Bias` must name "
            "disjoint implementation (executor) work as a first-class dispatch reason"
        )
    integration = markdown_section(policy, "## Integration")
    for marker in (
        "per-executor scope check",
        "scope/correctness check",
        "only a stray or risky slice",
    ):
        if not has_required_marker(integration, marker):
            die(
                "ralph-subagent-policy.md `## Integration` is missing the "
                f"post-batch per-executor check marker: {marker!r}"
            )

    ralph_core = read_text(root / "docs" / "skill-core" / "ralph.md")
    loop = markdown_section(ralph_core, "## Execution Loop")
    if not has_required_marker(loop, "scan remaining work for disjoint scopes"):
        die("ralph.md `## Execution Loop` must direct scanning remaining work for disjoint scopes")
    dispatch = markdown_section(ralph_core, "## Mode-Gated Agent Dispatch")
    if not has_required_marker(dispatch, "proactively partition disjoint"):
        die("ralph.md `## Mode-Gated Agent Dispatch` must make proactive disjoint-executor partition first-class")

    modes = read_text(shared / "execution-modes.md")
    if not has_required_marker(modes, "proactively partition disjoint"):
        die("execution-modes.md must reference proactive disjoint-executor partition in STANDARD/THOROUGH")

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

    using_path = skill_core / "using-oh-no-harness.md"
    using_core = read_text(using_path)
    skill_chaining = markdown_section(using_core, "## Skill Chaining")
    if not skill_chaining:
        die(f"{using_path} is missing required '## Skill Chaining' section")
    for marker in USING_OH_NO_RALPLAN_HANDOFF_MARKERS:
        if not has_required_marker(skill_chaining, marker):
            die(
                f"{using_path} `## Skill Chaining` is missing ralplan "
                f"combined-handoff marker: {marker!r}"
            )
    for pattern, label in USING_OH_NO_RALPLAN_HANDOFF_PATTERNS:
        if not re.search(pattern, skill_chaining, flags=re.IGNORECASE | re.DOTALL):
            die(
                f"{using_path} `## Skill Chaining` is missing ralplan "
                f"combined-handoff marker: {label}"
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

    modes = read_text(shared / "execution-modes.md")
    for marker in (
        "## Direction Contract",
        "## Process Budgets And Gate Governance",
        "STANDARD uses one reviewer instance per required role",
        "### STANDARD Small-Task Carve-Out",
        "STANDARD small-carveout eligibility:",
        "TDD, worktree isolation, session\nevidence",
        "still `provisional` at completion-claim time",
        "Four independent\n  cleanup viewpoints require a named THOROUGH",
        "Mandatory gate proposal:",
        "- Canonical owner:",
        "- Trigger:",
        "- Applicable modes:",
        "- Added cost:",
        "- Evidence of benefit:",
        "- Not-applicable path:",
        "- Retirement or merge condition:",
        "- Duplicate prose/marker check:",
    ):
        if not has_required_marker(modes, marker):
            die(f"execution-modes.md is missing proportional-workflow marker: {marker!r}")

    cross_host = read_text(shared / "cross-host-review.md")
    for marker in (
        "STANDARD uses at most one reviewer instance",
        "named THOROUGH paired-review trigger",
        "Host\navailability alone never activates a pair",
    ):
        if not has_required_marker(cross_host, marker):
            die(f"cross-host-review.md is missing risk-gated pairing marker: {marker!r}")

    for skill, markers in {
        "ralplan": (
            "## Canonical Plan Schema",
            "STANDARD runs one Plan-Reviewer instance",
            "STANDARD keeps one reviewer; named THOROUGH keeps the paired topology",
        ),
        "ralph": (
            "`verification.md` is the canonical acceptance-to-evidence ledger",
            "uses one targeted reviewer instance",
            "## Process Budget Gate",
        ),
        "simplify": (
            "## Cleanup Depth Decision",
            "LIGHT and STANDARD: run one quick or combined scan",
        ),
        "verification-before-completion": (
            "Ledger reuse:",
            "Do not\nrewrite an unchanged parallel acceptance mapping",
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
        "docs/shared/execution-modes.md",
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

    owners = [
        path
        for path in (*skill_core.glob("*.md"), *shared.glob("*.md"))
        if "Mandatory gate proposal:" in read_text(path)
    ]
    if owners != [shared / "execution-modes.md"]:
        die("Mandatory gate proposal schema must have one canonical owner: execution-modes.md")


def assert_ralplan_review_boundary_contract(root: Path) -> None:
    """Pin plan-reviewer ownership and the Ralplan/Ralph timing boundaries."""
    skill_core = root / "docs" / "skill-core"
    agent_core = root / "docs" / "agent-core"

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
    for heading, markers in {
        "## Plan Review Contract": (
            "Blocking basis: <AC ID | safety invariant | Direction Contract field | applicable mandatory gate>",
            "APPROVE freezes the exact reviewed Planner draft",
            "Non-blocking findings are optional follow-ups",
            "Any plan-body change that must be incorporated before approval is blocking",
        ),
        "## Findings Ledger Gate": (
            "Blocking basis: <AC ID | safety invariant | Direction Contract field | applicable mandatory gate>",
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
        "Full-depth review is allowed only for a named material change",
        "Why first raised now",
        "A revision-created material defect",
    ):
        if not has_required_marker(ralplan, marker):
            die(f"ralplan.md is missing bounded-review marker: {marker!r}")
    if "If a blocker is rejected, create Planner revision v2 before asking the user." in ralplan:
        die("ralplan.md must use a disposition-only user-decision packet before revision")
    branch_rules = {
        "All accepted: create exactly one Planner revision v2, then exactly one delta closure review.":
            "all-accepted must create exactly one v2 and one closure review",
        "Any rejected: return the disposition-only user-decision packet; create no v2 and run no review v2 until the user resolves it.":
            "rejected must create no v2 or review before user resolution",
        "Any deferred: leave the plan pending in the disposition-only user-decision packet; create no v2 and run no review v2.":
            "deferred must leave the plan pending with no v2 or review",
        "Mixed: resolve every non-accepted blocker before exactly one v2; no closure review starts earlier.":
            "mixed blockers must resolve before one v2 and closure review",
        "Permitted waivers with no body change: keep the waivers visible; create no v2 and run no review v2.":
            "permitted waiver with no body change must create no v2 or review",
        "Non-waivable gate: keep the plan pending and prohibit execution until its owner-defined obligation passes or direction changes.":
            "non-waivable gate must remain pending with no execution",
        "Direction change: update the requirements source, start a new planning run, and do not run or consume the old run's closure review.":
            "direction change must start a new run without old closure review",
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

    reviewer_transport = read_text(agent_core / "plan-reviewer-codex.md")
    if not has_required_marker(reviewer_transport, "Only Ralplan may call you"):
        die("plan-reviewer-codex.md must restrict the transport to Ralplan")

    cross_host = read_text(root / "docs" / "shared" / "cross-host-review.md")
    when_applies = markdown_section(cross_host, "## When It Applies")
    for marker in (
        "`plan-reviewer`: `ralplan` consensus plan review only",
        "must not dispatch it for their own completion, final, post-fix, or debugging review",
    ):
        if not has_required_marker(when_applies, marker):
            die(f"cross-host-review.md must keep plan-reviewer Ralplan-only: {marker!r}")
    synthesis = markdown_section(cross_host, "## Parallel Execution And Synthesis")
    if not has_required_marker(
        synthesis,
        "Blocking basis: <AC ID | safety invariant | Direction Contract field | applicable mandatory gate>",
    ):
        die("cross-host-review.md must preserve each merged blocking finding's basis")

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
    final_validation = markdown_section(ultrawork, "### Phase 4: Final Validation")
    if has_token(final_validation, "plan-reviewer"):
        die("ultrawork.md Final Validation must not directly dispatch plan-reviewer")
    if direct_dispatch.search(final_validation):
        die("ultrawork.md Final Validation must not directly dispatch plan-reviewer")

    ralph = read_text(skill_core / "ralph.md")
    execution_loop = markdown_section(ralph, "## Execution Loop")
    for marker in (
        "Scope Trace Gate",
        "cumulative Process Budget Gate",
        "After each story",
        "After all stories",
        "run the `## Diff-Budget Gate` exactly once",
        "before `## Review Gate`",
    ):
        if not has_required_marker(execution_loop, marker):
            die(f"ralph.md Execution Loop is missing budget-timing marker: {marker!r}")
    if len(re.findall(r"Diff-Budget Gate", execution_loop, flags=re.IGNORECASE)) != 1:
        die("ralph.md Execution Loop must schedule Diff-Budget Gate exactly once")
    process_budget = markdown_section(ralph, "## Process Budget Gate")
    for marker in ("cumulative", "per-story"):
        if not has_required_marker(process_budget, marker):
            die(f"ralph.md Process Budget Gate is missing timing marker: {marker!r}")
    diff_budget = markdown_section(ralph, "## Diff-Budget Gate")
    for marker in ("final", "exactly once", "before `## Review Gate`"):
        if not has_required_marker(diff_budget, marker):
            die(f"ralph.md Diff-Budget Gate is missing timing marker: {marker!r}")
    ralph_output = markdown_section(ralph, "## Output")
    phase_attribution = (
        "Review phases: plan=<n>; implementation-code=<n>; "
        "focused-recheck=<n>; independent-verifier=<n>"
    )
    if not has_required_marker(ralph_output, phase_attribution):
        die("ralph.md Output is missing exact compact phase-attribution format")
    for marker in (
        "when 2+ stages ran",
        "when fewer than two ran, use ordinary labeled prose and omit that count line",
    ):
        if not has_required_marker(ralph_output, marker):
            die(f"ralph.md Output is missing conditional phase-attribution rule: {marker!r}")

    repo_root = root.parent.parent
    for host in ("codex", "claude"):
        host_test = read_text(repo_root / "scripts" / f"test-{host}-plugin.sh")
        for marker in (
            'r"(?m)^Reviewed draft:[ \\t]*(.*?)[ \\t]*$"',
            "if len(reviewed_draft_matches) != 1:",
            "captured_draft_id = normalize_transport_whitespace(draft_id.group(1))",
            "reviewed_draft_id = normalize_transport_whitespace(reviewed_draft_matches[0])",
        ):
            if marker not in host_test:
                die(f"{host} explicit Ralplan live parser is missing anchored Reviewed draft validation: {marker!r}")
        if (
            "if reviewed_draft_id != captured_draft_id:" not in host_test
            or "reviewed_draft_id.startswith(captured_draft_id)" in host_test
        ):
            die(f"{host} explicit Ralplan live parser must compare exact normalized Reviewed draft id")

    modes = read_text(root / "docs" / "shared" / "execution-modes.md")
    governance = markdown_section(modes, "## Process Budgets And Gate Governance")
    for marker in (
        "All Ralph modes always evaluate the final Diff-Budget Gate exactly once after all stories and before the Review Gate",
        "Thresholds decide whether that one evaluation expands into the detailed diff-budget scope review",
    ):
        if not has_required_marker(governance, marker):
            die(f"execution-modes.md is missing canonical Diff-Budget timing: {marker!r}")
    for pattern in (
        r"run\s+the\s+diff-budget\s+gate\s+when",
        r"Diff-Budget Gate[^\n]{0,80}\bonly\s+if\b",
        r"Diff-Budget Gate[^\n]{0,80}\bper[- ]story\b",
    ):
        if re.search(pattern, modes, flags=re.IGNORECASE):
            die(f"execution-modes.md makes final Diff-Budget execution conditional or repeated: {pattern!r}")


def assert_workflow_object_routing_contract(root: Path) -> None:
    """Keep workflow names used as analysis subjects from forcing invocation."""
    using = read_text(root / "docs" / "skill-core" / "using-oh-no-harness.md")
    session_start = read_text(root / "hooks" / "session-start")
    required = (
        "A workflow name used only as the subject of analysis, explanation, comparison, or critique is not an invocation trigger.",
        "Route from the requested deliverable: an analysis report versus a plan or execution artifact.",
    )
    for path, body in (
        ("using-oh-no-harness.md", using),
        ("hooks/session-start", session_start),
    ):
        for marker in required:
            if not has_required_marker(body, marker):
                die(f"{path} is missing object-of-analysis routing boundary: {marker!r}")
    if "If there is even a small chance that a local skill applies" in using:
        die("using-oh-no-harness.md retains absolute small-chance routing wording")
    if "If there is even a 1% chance that a local Oh No Harness skill applies" in session_start:
        die("hooks/session-start retains absolute 1% routing wording")


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

    assert_workflow_object_routing_contract(root)
    assert_ralplan_proportionality_contract(root)
    assert_generated_skill_wrappers(marketplace_root, root)
    assert_generated_agent_wrappers(marketplace_root, root)
    assert_test_harness_lane_contract(marketplace_root, root)
    assert_skill_reachability(marketplace_root, root)
    for skill in ALL_SKILLS:
        assert_skill(root, skill)
    for skill in COMMAND_WRAPPERS:
        assert_command(root, skill)
    for agent in AGENTS:
        assert_agent(root, agent)
        # Claude-only delegation roles ship no Codex custom-agent template.
        if agent not in CLAUDE_ONLY_AGENT_ROLES:
            assert_codex_agent_template(root, agent)
    assert_codex_consult_agent_kernels(root)
    assert_codex_delegation_prompt_contract(root)
    assert_codex_custom_agent_count(root)
    assert_codex_agent_installer(root)
    assert_execution_mode_contract(root)
    assert_verification_tier_contract(root)
    assert_validation_check_contract(root)
    assert_cross_host_review_contract(root)
    assert_required_reading_contract(root)
    assert_independence_mode_gates(root)
    assert_parallel_executor_contract(root)
    assert_proportional_workflow_contract(root)
    assert_ralplan_review_boundary_contract(root)
    assert_review_boundary_mutation_tests(marketplace_root, root)
    assert_provider_guidance(root)
    assert_worktree_contract(marketplace_root, root)
    assert_tdd_routing_contract(marketplace_root, root)
    assert_hook_contract(root)
    assert_hook_test_contract(marketplace_root)
    assert_public_docs_contract(marketplace_root, root)
    assert_claude_manifest_skills(root)
    assert_codex_manifest(root)
    assert_claude_marketplace(marketplace_root)
    assert_codex_marketplace(marketplace_root)
    assert_expected_references(root)
    assert_no_omc_runtime_coupling(root)
    assert_no_deprecated_artifact_paths(root)
    print("ok - skill and agent files passed static checks")


if __name__ == "__main__":
    main()
