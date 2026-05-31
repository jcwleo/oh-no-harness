# Claude Code Platform Rules

Use this file only from Claude Code-facing skill wrappers.

## Skill Loading

Claude Code-facing public skills live under `skills-claude/`. Each wrapper
applies the matching `docs/skill-core/<skill>.md` file as the shared workflow
source of truth, then applies this Claude Code platform file.

Claude slash commands must delegate to `skills-claude/<skill>/SKILL.md` so the
model sees this platform wrapper before the shared core.

## User Approval

When asking the user for approval, preference, scope, or next-step selection,
use the available structured question tool when the host exposes one. Prefer one
focused question at a time. For option questions, provide a small set of
mutually exclusive choices and put the recommended option first when there is a
clear recommendation.

If a structured question tool is unavailable, ask in plain text and wait for the
user's answer. Present options as actions the host agent will take. Do not tell
the user to run a command manually when the skill handoff expects the host agent
to invoke the next skill.

## Task Tracking

When a core skill has a multi-phase approval handoff and the host exposes task
tracking, create one task per phase and complete them sequentially. Do not
collapse content approval and next-step selection into one hidden step.

## Auto Routing

The `auto-routing` skill controls whether the Claude Code SessionStart hook adds
stronger skill-selection guidance to `using-oh-no-harness`.

Preferred config location:

```text
$HOME/.claude/plugins/data/<oh-no-harness-*>/config.json
```

When `CLAUDE_PLUGIN_ROOT` is set, use:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" status
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" on
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" off
```

Changes take effect on the next Claude Code `SessionStart`, such as a new
session, app restart, `/clear`, or compaction.

## Anthropic-Aligned Prompting

This file carries the runtime-sized Anthropic guidance for Claude Code. The
longer maintenance reference lives in `docs/providers/anthropic.md`, but Claude
Code-facing skill wrappers do not load provider docs as an extra runtime layer.

For Anthropic/Claude models, keep instructions explicit and sectioned:

- state scope, non-goals, constraints, approval gates, and expected evidence in
  stable headings or tagged sections
- avoid relying on implication; say what the agent may do, must not do, and must
  ask before changing
- give one focused user question at a time when approval or direction is needed
- preserve long-running context in artifacts before compaction, task handoff, or
  subagent dispatch
- keep final answers concise unless the active skill requires a structured plan,
  review, or verification report

When the host exposes extended thinking or effort controls, use higher effort
for agentic coding, architecture review, plan critique, and ambiguous debugging.
Use lower effort for small, already-bounded edits.

## Role Dispatch

Use the available Task, Agent, Workflow `agent()`, or subagent mechanism for
role dispatch. Prefer plugin-scoped agents named `oh-no-harness:<role>` when
the host lists them.

For independent read-only, review, verification, QA, security, or exploration
work, request background subagents and start the whole independent batch before
waiting for any one result.

If plugin-scoped agents are unavailable, keep the same role boundary by
embedding the matching `agents/<role>.md` prompt into the available subagent
mechanism. If no dispatch mechanism is available, keep the role inline and
record the fallback reason when the core skill requires it.

For `ralph`, also apply `docs/platforms/claude-code-ralph.md`.
