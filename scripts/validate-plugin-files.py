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
        "Role: {explore|executor|plan-reviewer|verifier|code-reviewer}",
        "adapter deciding whether the invocation is a registered custom agent",
        "Platform invocation: {active adapter invocation syntax}",
        "MUST NOT be used to close a running or pending subagent",
    ),
    "ralplan": (
        "eligible isolated subagents when they add decision-changing evidence",
        "Parallel trigger: approved-plan-handoff",
        "ordinary `oh-no-harness:ralph` choice is the parallel-capable execution",
        "keep sequential role boundaries",
        "parallel subagent dispatch plan",
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
        "scripts/install-codex-agents --scope user --ensure --quiet",
        "Files ensured on disk are not the same thing as same-session named-agent",
        'sandbox_mode = "read-only"',
        "## Role Prompt Embedding",
        "Agent prompt source: docs/agent-core/<role>.md",
        "Claude-only",
    ),
    "codex-runtime.md": (
        "# Codex Runtime Rules",
        "compact platform section is embedded in generated Codex-facing skill",
        "## Skill Loading",
        "docs/platforms/codex-<skill>.md",
        "## User Approval And Prompting",
        "outcome-first",
        "## Role Dispatch",
        "spawn_agent",
        'spawn_agent(agent_type="oh-no-<role>", ...)',
        "Do not infer custom-agent\nunavailability",
        "fork_context=true",
        "workflow-level\nauthorization",
        "eligible isolated subagents",
        "wait_agent",
        "become a\nworkflow dependency",
        "Wait until every in-scope dispatched subagent reaches final\nstatus",
        "Do not redo delegated work inline",
        "Never use missing output\nas completion evidence",
        "## Generic Role Prompt Fallback",
        "docs/agent-core/<role>.md",
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
        "Workflow `agent()`",
        "oh-no-harness:<role>",
        "Promise.all",
        "final status",
        "close or\nclean up the completed subagent",
        "Parallel trigger: approved-plan-handoff",
        "embedding the matching `agents/<role>.md`",
        "record the fallback reason",
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
        "Worktree policy",
        "Worktree location",
        "docs/shared/worktree-isolation.md",
        ".oh-no/worktrees/<task-slug>",
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
        "Worktree policy",
        "direct-automatic-worktree",
        "automatic-worktree-merge",
        "registered Git worktree",
        ".oh-no/worktrees/<task-slug>",
        "plain directories",
    ),
    "plan-reviewer": (
        "Worktree policy",
        "registered project-local Git worktree execution plus merge",
        "automatic registered Git worktree execution",
        "registered project-local worktree execution and merge responsibility",
        ".oh-no/worktrees/<task-slug>",
        "invalid substitutes",
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
    "diff-budget gate",
    "What would force escalation while working",
    "Worktree policy",
    "Worktree location",
    "Worktree decision",
)
VERIFICATION_TIER_SHARED_MARKERS = (
    "# Verification Tiers",
    "docs/shared/validation-check.md",
    "Measurable evidence is diagnostic evidence",
    "Every tier uses acceptance-to-evidence mapping",
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
        "## Execution Profile",
        "## Test Case Design Quality",
        "Overall Ralph mode",
        "Task sizing",
        "Execution profile recap",
        "Validation check",
        "immediately before `Approval needed`",
        "Ralph must follow this profile",
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
        "plan-reviewer",
        "verifier",
        "code-reviewer",
    ),
    "ultrawork": (
        "explore",
        "analyst",
        "planner",
        "plan-reviewer",
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
        "plan-reviewer",
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
EXECUTION_MODE_AGENT_MARKERS = {
    "planner": (
        "execution profile",
        "task sizing",
        "story risk check",
        "acceptance criteria alignment",
        "Validation check",
        "verification budget",
        "diff-budget",
    ),
    "plan-reviewer": (
        "Ralph execution profile",
        "too light, too heavy",
        "execution profile recap",
        "Risk Check Before Completion",
        "acceptance criteria",
        "diff-budget scope review",
    ),
    "executor": (
        "assigned Ralph execution mode",
        "Execution mode followed",
    ),
    "verifier": (
        "selected execution mode",
        "Execution mode compliance",
        "Acceptance-to-evidence mapping status",
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

SIMPLICITY_SCOPE_SKILL_MARKERS = {
    "ralplan": (
        "minimal viable approach",
        "rejected speculative complexity",
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
    # Cleanup always runs the four role passes in parallel — no diff-size gate,
    # no single-combined-pass shortcut. These markers guard that contract so it
    # cannot be silently reverted to a gated/single-pass form.
    "always runs all four labeled viewpoints",
    "no single-combined-pass shortcut and no diff-size gate",
    "Run the four passes in parallel",
    "active platform's Simplify dispatch authorization",
    "standing authorization for eligible skill-local delegation",
    "dispatch-unavailable",
    "Launch four independent cleanup subagents in parallel",
    "the review always runs all four cleanup role passes regardless of diff size",
    "in one batch before",
    "run the same four passes inline as four separate labeled blocks",
    "Capture all four cleanup pass results",
    "close or clean up each completed cleanup subagent",
)
SIMPLIFY_WRAPPER_MARKERS = (
    "oh-no-harness-generated-skill-wrapper",
    "Source order:",
    "../../docs/skill-core/simplify.md",
)
SIMPLICITY_SCOPE_AGENT_MARKERS = {
    "planner": (
        "smallest approach",
        "Rejected speculative complexity",
    ),
    "plan-reviewer": (
        "Simplest sufficient approach assessment",
        "speculative abstraction",
        "untraceable changes",
        "senior-engineer overcomplication check",
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
        "acceptance criteria",
        "success signal",
        "insufficient proofs",
        "validation-check",
    ),
    "plan-reviewer": (
        "acceptance criteria coverage",
        "internal shortcut",
        "validation-check",
        "convenient signal",
        "claims without user approval",
        "Validation check",
    ),
}
VALIDATION_CHECK_AGENT_MARKERS = {
    "planner": (
        "docs/shared/validation-check.md",
        "case-specific result",
    ),
    "plan-reviewer": (
        "validation coverage",
        "justified only by metric movement",
        "Validation check",
        "metric movement as the acceptance criteria",
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
APPROVED_DIRECTION_AGENT_MARKERS = {
    "plan-reviewer": (
        "approved interview spec",
        "user-approved plan direction",
        "Direction-preservation findings",
        "do not replace it with your own direction",
    ),
}
RALPLAN_CONSENSUS_MARKERS = (
    "## Direction Preservation Gate",
    "## Test Case Design Quality",
    "## Acceptance Criteria Contract",
    "Ralplan has no basic planning mode",
    "## Requirements Source And Analyst Gate",
    "## Planner Draft Contract",
    "## Plan Review Contract",
    "## Planner Revision Contract",
    "## Re-Review Rules",
    "## Findings Ledger Gate",
    "Planner draft v1",
    "Plan review v1",
    "Planner revision v2",
    "Plan review v2",
    "Analyst -> Planner -> Plan-Reviewer",
    "APPROVE | ITERATE | REJECT",
    "blocking | non-blocking",
    "Findings ledger:",
    "Re-review scope: delta | full",
    "Re-review: not required (no blocking findings)",
    "Worst-case consensus role dispatch chain: 6 (explore, analyst, Planner draft v1, Plan review v1, Planner revision v2, Plan review v2).",
    "The plan is invalid if it contains only Planner output",
    "if Plan-Reviewer is skipped",
    "accepted feedback is logged but not reflected in the final plan body",
    "lacks a plan-section pointer",
    "consensus loop log showing Analyst -> Planner -> Plan-Reviewer in order",
    "requested direction change",
    "do not incorporate the new direction into the plan unless the user explicitly",
    "must-fail-before-implementation",
    "must-pass-after-implementation",
    "negative or forbidden-behavior case",
    "edge, boundary, or regression case",
    "only check marker strings",
)
RALPLAN_FORBIDDEN_SPLIT_OPTION_MARKERS = (
    "`oh-no-harness:ralph` with `parallel subagents`",
    "Run ralph with parallel subagents",
    "parallel-subagent Ralph option",
    "choose `ralph`, `ralph with parallel subagents`, or `ultrawork`",
    "including how to explicitly approve it on",
)
RALPLAN_AGENT_CONTRACT_MARKERS = {
    "planner": (
        "Planner Draft Contract",
        "Planner Revision Contract",
        "Feedback disposition for every Plan-Reviewer finding",
        "Accepted feedback must be reflected in the plan body",
        "smallest meaningful test set",
        "must-fail before implementation",
        "acceptance criteria alignment",
    ),
    "plan-reviewer": (
        "Plan Review Contract",
        "Reviewed draft:",
        "must not produce a replacement plan",
        "APPROVE | ITERATE | REJECT",
        "reject when accepted feedback is only logged",
        "AI-slop",
        "would pass against the old broken behavior",
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
    "tiny direct edit path",
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
        "`openai/codex-plugin-cc`",
        "`/codex:rescue`",
        "`codex:codex-rescue`",
        "Codex consult must run synchronously",
        "Pass `--wait` to force foreground",
        "do not let it run as a detached background job",
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
    for index, line in enumerate(lines):
        if line.strip() == heading:
            start = index + 1
            break
    if start is None:
        return ""

    end = len(lines)
    for index in range(start, len(lines)):
        stripped = lines[index].strip()
        if stripped.startswith("## ") and stripped != heading:
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
        for wrapper_root in (CODEX_SKILL_ROOT, CLAUDE_SKILL_ROOT):
            wrapper_path = root / wrapper_root / skill / "SKILL.md"
            wrapper_body = read_text(wrapper_path)
            for marker in SIMPLIFY_WRAPPER_MARKERS:
                if not has_required_marker(wrapper_body, marker):
                    die(f"{wrapper_path} is missing required Simplify-Wrapper marker: {marker!r}")
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

    expected_model = "sonnet" if agent == "explore" else "inherit"
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
    if agent in APPROVED_DIRECTION_AGENT_MARKERS:
        for marker in APPROVED_DIRECTION_AGENT_MARKERS[agent]:
            if marker not in body:
                die(f"{path} is missing required Approved-Direction agent marker: {marker!r}")
    if agent in WORKTREE_AGENT_MARKERS:
        for marker in WORKTREE_AGENT_MARKERS[agent]:
            if marker not in body:
                die(f"{path} is missing required Worktree agent marker: {marker!r}")
    if agent in RALPLAN_AGENT_CONTRACT_MARKERS:
        for marker in RALPLAN_AGENT_CONTRACT_MARKERS[agent]:
            if marker not in body:
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
    if data["model"] != "gpt-5.5":
        die(f"{path} model={data['model']!r}, expected 'gpt-5.5'")
    expected_reasoning_effort = "medium" if agent == "explore" else "xhigh"
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
        'model = "gpt-5.5"',
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


def assert_cross_host_review_contract(root: Path) -> None:
    # D1: governance content-marker for the neutral shared cross-host-review doc,
    # so it cannot be silently gutted or drift from the fusion-rescue mechanism.
    path = root / "docs" / "shared" / "cross-host-review.md"
    text = read_text(path)
    for marker in (
        "# Cross-Host Review",
        "## Cross-Host Consult Channel",
        "run the review on BOTH the current host and the opposite host",
        "degrade to current-host-only",
        "require-cross-host",
        "Recursion Guard (Cross-Host Hop Scope)",
        "one cross-host hop",
        "requested-direction-change: yes",
    ):
        if not has_required_marker(text, marker):
            die(f"{path} is missing required Cross-Host-Review marker: {marker!r}")

    # D2: runtime-doc Cross-Host Consult Channel cross-leak hygiene. Each runtime
    # doc's channel section must carry only its own outbound-to-opposite-host
    # invocation, mirroring the fusion-rescue overlay cross-leak guard.
    platform_root = root / "docs" / "platforms"
    heading = "## Cross-Host Consult Channel"

    codex_channel = markdown_section(read_text(platform_root / "codex-runtime.md"), heading)
    if not codex_channel:
        die(f"{platform_root / 'codex-runtime.md'} is missing required {heading!r} section")
    if not has_required_marker(codex_channel, "`${CLAUDE_BIN:-claude}`"):
        die(f"codex-runtime.md {heading!r} must carry the Codex-to-Claude argument vector")
    for marker in ("openai/codex-plugin-cc", "`/codex:rescue`"):
        if marker in codex_channel:
            die(f"codex-runtime.md {heading!r} contains opposite-host (Claude-side) consult marker: {marker!r}")

    claude_channel = markdown_section(read_text(platform_root / "claude-code-runtime.md"), heading)
    if not claude_channel:
        die(f"{platform_root / 'claude-code-runtime.md'} is missing required {heading!r} section")
    if not has_required_marker(claude_channel, "`/codex:rescue`"):
        die(f"claude-code-runtime.md {heading!r} must carry the Claude-to-Codex consult invocation")
    for marker in ("`${CLAUDE_BIN:-claude}`", "`--permission-mode`", "`dontAsk`"):
        if marker in claude_channel:
            die(f"claude-code-runtime.md {heading!r} contains opposite-host (Codex-side) consult marker: {marker!r}")


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
            "/codex:rescue",
            "--allowedTools",
            "codex-companion.mjs",
            "permission_denials",
            "forwarded Codex output is unavailable",
            "OH_NO_CODEX_RESCUE_RETURN_OK",
            "OH_NO_CLAUDE_FUSION_RESCUE_CODEX_OK",
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


def main() -> None:
    if len(sys.argv) not in (2, 3):
        die("usage: validate-plugin-files.py <marketplace-root> [plugin-root]")

    marketplace_root = Path(sys.argv[1]).resolve()
    if len(sys.argv) == 3:
        root = Path(sys.argv[2]).resolve()
    else:
        nested = marketplace_root / "plugins" / PLUGIN_NAME
        root = nested if nested.exists() else marketplace_root

    assert_generated_skill_wrappers(marketplace_root, root)
    assert_generated_agent_wrappers(marketplace_root, root)
    for skill in ALL_SKILLS:
        assert_skill(root, skill)
    for skill in COMMAND_WRAPPERS:
        assert_command(root, skill)
    for agent in AGENTS:
        assert_agent(root, agent)
        assert_codex_agent_template(root, agent)
    assert_codex_agent_installer(root)
    assert_execution_mode_contract(root)
    assert_verification_tier_contract(root)
    assert_validation_check_contract(root)
    assert_cross_host_review_contract(root)
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
