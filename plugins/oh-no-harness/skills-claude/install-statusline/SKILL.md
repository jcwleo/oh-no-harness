---
name: install-statusline
description: User-invoked setup action that installs the Oh No Harness developer statusline into the user's Claude Code settings. Run it explicitly with the slash command; it is never auto-invoked by the model.
argument-hint: "[check]"
disable-model-invocation: true
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Install Statusline for Claude Code

This generated file is the Claude Code-facing runtime skill document. Claude Code slash commands should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/install-statusline.md`
- `../../docs/platforms/claude-code-runtime.md`
- `../../docs/platforms/claude-code-install-statusline.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/install-statusline.md

# Install Statusline

Install Statusline is a user-invoked setup action. It installs a developer-focused
Claude Code statusline (working directory, git branch/status, model and reasoning
effort, context-window gauge, and rate-limit gauges) into the user's
`~/.claude` configuration so a freshly set up Claude Code environment gets the
same statusline.

This skill is **human-invoke-only**. It is never auto-invoked by the model: its
frontmatter sets `disable-model-invocation: true`, and it is intentionally left
out of the SessionStart routing map. Only an explicit
`/oh-no-harness:install-statusline` from the user runs it.

It is **Claude Code-only**: it configures Claude Code's `statusLine` setting and
ships no Codex variant.

## Software Development Stage

Install Statusline is a one-time environment-setup action, not a software
development stage. It should not gather requirements, plan, edit project code,
debug failures, clean code, or verify completion. It does not invoke workflow
skills.

## When To Use

Use only when the user explicitly asks to install or set up the Oh No Harness
developer statusline, typically on a new machine or a fresh `~/.claude`.

Do not use it as part of any automated workflow. There is no model-driven trigger
for this skill.

## What Gets Installed

- The statusline script is copied to `~/.claude/statusline-command.sh`.
- The user's `~/.claude/settings.json` `statusLine` key is set to:

```json
{
  "type": "command",
  "command": "bash ~/.claude/statusline-command.sh",
  "refreshInterval": 3
}
```

All other keys in `settings.json` are preserved. The change takes effect within a
few seconds (the statusline refreshes on `refreshInterval`); a new session or
`/clear` guarantees it.

## Install Procedure

The bundled installer does the deterministic file work; this skill orchestrates
the safe-by-default flow and owns the conflict decision.

1. Locate the bundled installer at `<plugin-root>/scripts/install-statusline`
   (the active platform runtime overlay names the concrete plugin-root path).
2. Run it in check mode first: `"<plugin-root>/scripts/install-statusline" check`.
   It prints a `STATUS:` line describing the current state without changing
   anything:
   - `STATUS: not-installed` — no statusLine configured yet.
   - `STATUS: installed-outdated` — our statusLine is configured but the script
     is missing or differs from the bundled payload.
   - `STATUS: installed-matching` — already installed and current.
   - `STATUS: conflict` — a *different* statusLine is already configured.
3. Act on the status:
   - `installed-matching`: report that nothing needs to change and stop.
   - `not-installed` or `installed-outdated`: run
     `"<plugin-root>/scripts/install-statusline" apply` (no prompt needed — this
     is the harness's own statusline).
   - `conflict`: show the user the existing `statusLine.command`, then ASK whether
     to back up and replace it. Only on an explicit yes, run
     `"<plugin-root>/scripts/install-statusline" apply --replace`, which
     timestamp-backs-up the existing script and `settings.json` before replacing.
     On no, make no change and report that the existing statusline was kept.
4. Report exactly what changed (files written, backups created, the `settings.json`
   keys that were preserved) and that the statusline refreshes within a few
   seconds.

## Safety Rules

- The installer requires `jq`. If `jq` is absent it refuses with a clear error,
  exits non-zero, and leaves `settings.json` byte-unchanged. Relay that to the
  user; do not hand-edit the JSON as a workaround.
- If `settings.json` is present but not valid JSON, the installer refuses and
  leaves the file unchanged. Relay that; do not overwrite it.
- Never replace an existing different statusLine without the user's explicit
  approval and a backup.
- Do not invoke workflow skills from this setup skill.

## Source: docs/platforms/claude-code-runtime.md

# Claude Code Runtime Rules

This compact platform section is embedded in generated Claude Code-facing skill
documents.

## Skill Loading

Claude Code-facing public skills live under `skills-claude/`. Generated
`skills-claude/<skill>/SKILL.md` files compose the matching skill core, this
compact runtime section, and any Claude Code skill-specific overlay such as
`docs/platforms/claude-code-<skill>.md`. Slash commands must delegate to the
matching generated skill document.

## User Approval, Tasks, And Prompting

Use the host's structured question tool when available for approval,
preference, scope, or next-step selection; otherwise ask one focused plain-text
question and wait. Present options as actions the host agent will take.

When a core skill has a multi-phase approval handoff and the host exposes task
tracking, create one task per phase and complete them sequentially.

Keep Claude prompts explicit and sectioned: state scope, non-goals,
constraints, approval gates, expected evidence, and output format. Preserve
long-running context in artifacts before compaction, task handoff, or subagent
dispatch.

## Role Dispatch

Use the available Task, Agent, Workflow `agent()`, or subagent mechanism for
role dispatch. Prefer plugin-scoped agents named `oh-no-harness:<role>` when
the host lists them.

For independent read-only, review, verification, QA, security, or exploration
work, request background subagents and start the whole independent batch before
waiting for any one result. When a skill requires an atomic same-phase batch,
prefer Workflow `Promise.all` if available; otherwise do not inspect or
summarize early task results until the full intended batch has been requested.

After a Claude Code subagent reaches final status, capture the output and any
changed-file set before cleanup. When no further input is needed, close or
clean up the completed subagent with the mechanism exposed by the host; if none
is available, record that fallback.

For approved `ralplan` handoffs to ordinary `oh-no-harness:ralph`, treat
`Parallel trigger: approved-plan-handoff` as dispatch authorization for
eligible isolated roles. Do not require a separate `ralph with parallel
subagents` option when the plan already lists roles whose output can change the
implementation, review, verification, or ship/block decision.

If plugin-scoped agents are unavailable, keep the same role boundary by
embedding the matching `agents/<role>.md` prompt into the available subagent
mechanism. If no dispatch mechanism is available, keep the role inline and
record the fallback reason when the core skill requires it.

## Cross-Host Consult Channel

This is the shared cross-host consult mechanism used by Fusion Rescue and by
cross-host review (`docs/shared/cross-host-review.md`). On Claude Code the
opposite host is Codex. This section carries only the Claude-to-Codex
invocation; the activation, synthesis, and recursion-guard semantics live in the
calling skill core and the shared doc.

From Claude Code, consult Codex only through an available, explicitly loaded
`openai/codex-plugin-cc` capability, surfaced as `/codex:rescue` when that plugin
is installed. If the capability is unavailable, treat the opposite host as
unavailable; in default mode the calling skill applies the shared cross-host
contract's Same-Host Parallel Fallback (`docs/shared/cross-host-review.md`), and
require-cross-host mode blocks. Name the failure class and the current-host
fallback.

The consult must run synchronously and return Codex's actual assigned analysis.
Pass `--wait` to force foreground execution, for example `/codex:rescue --wait`,
and request read-only Codex behavior; do not let it run as a detached background
job and do not authorize write-capable edits for an analysis-only consult. A
response that only acknowledges a queued or background job — text that a task
started in the background with a status command for a job id — is not a valid
opposite-host response; treat it as no Codex response and degrade (default) or
block (require-cross-host). Do not poll status or fetch a deferred result to
compensate; the consult call itself must return the analysis.

The outbound prompt must request only the assigned analysis and must forbid the
opposite host from invoking further rescue, another workflow skill, or any
host-to-host call back to Claude Code or a third host (one cross-host hop).
Redact secrets before sending; on failure record only the failure class and
capability/path/auth status, never secret values.

## Source: docs/platforms/claude-code-install-statusline.md

# Claude Code Install Statusline Rules

This platform overlay is source content for the generated Claude Code-facing
`install-statusline` runtime document, after the shared core and
`docs/platforms/claude-code-runtime.md`.

The statusline installs into Claude Code's user settings at `~/.claude`.

When `CLAUDE_PLUGIN_ROOT` is set, run the bundled installer directly:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/install-statusline" check
"${CLAUDE_PLUGIN_ROOT}/scripts/install-statusline" apply
"${CLAUDE_PLUGIN_ROOT}/scripts/install-statusline" apply --replace
```

If the plugin root is not exposed, locate the installed script first:

```bash
script="$(find ~/.claude/plugins -path '*/oh-no-harness/*/scripts/install-statusline' -print -quit)"
"$script" check
```

For the `conflict` case, ask the user with the host's structured question tool
(`AskUserQuestion`) before replacing: show the existing
`statusLine.command`, and offer "back up and replace" versus "keep existing". Only
run `apply --replace` after an explicit choice to replace.

The statusline reads Claude Code's statusLine JSON input, including `.effort.level`
for the model reasoning effort. The change takes effect on the next
`refreshInterval` tick; `/clear` or a new session guarantees it.
