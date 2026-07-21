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
same statusline. In the same pass it also installs a matching
**subagent statusline** (`subagentStatusLine`) that renders each running
subagent's row with its status, resolved model and reasoning effort,
context-usage gauge, elapsed time, and description — using the same visual
language as the main statusline.

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

Everything installs into the config directory this Claude Code binary actually
reads — `CLAUDE_CONFIG_DIR` when set, otherwise `~/.claude` — so a relocated
config directory is respected instead of always writing to `~/.claude`. The paths
below use `~/.claude` for the common case; substitute the resolved config dir
when `CLAUDE_CONFIG_DIR` is set (the installed command values then carry that
absolute path).

- The statusline script is copied to `<config-dir>/statusline-command.sh`, and
  the subagent statusline script to `<config-dir>/subagent-statusline-command.sh`.
- The `settings.json` `statusLine` and `subagentStatusLine` keys are set to:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh",
    "refreshInterval": 3
  },
  "subagentStatusLine": {
    "type": "command",
    "command": "bash ~/.claude/subagent-statusline-command.sh"
  }
}
```

All other keys in `settings.json` are preserved. The change takes effect within a
few seconds (the statusline refreshes on `refreshInterval`); a new session or
`/clear` guarantees it.

The subagent statusline rows require Claude Code v2.1.205+ to show a per-task
model and context gauge (those fields are omitted for a task whose model isn't
resolved yet, and the row degrades to `inherit` plus a raw token count). When a
task also carries a flat `effort` value (for example `high`), it's shown right
after the model; a task without that field keeps the existing model/context
output unchanged.

When a dispatched subagent task starts its description with the canonical marker
`[oh-no-harness:<role>]`, the subagent statusline shows that role (for example
`oh-no-harness:explore`) in the row's leading slot instead of a generic host
label such as `local_agent`, and hides the marker from the shown description.
Unmarked tasks keep the host-provided name or type and their description as-is.

## Install Procedure

The bundled installer does the deterministic file work; this skill orchestrates
the safe-by-default flow and owns the conflict decision.

1. Locate the bundled installer at `<plugin-root>/scripts/install-statusline`
   (the active platform runtime overlay names the concrete plugin-root path).
2. Run it in check mode first: `"<plugin-root>/scripts/install-statusline" check`.
   It prints a `STATUS:` line describing the current state without changing
   anything:
   - `STATUS: not-installed` — neither statusLine nor subagentStatusLine is
     configured yet.
   - `STATUS: installed-outdated` — our lines are configured but a bundled script
     is missing or differs, or an older install predates the subagentStatusLine
     slot. A plain `apply` brings it current.
   - `STATUS: installed-matching` — both lines already installed and current.
   - `STATUS: conflict` — a *different* statusLine or subagentStatusLine is
     already configured.
3. Act on the status:
   - `installed-matching`: report that nothing needs to change and stop.
   - `not-installed` or `installed-outdated`: run
     `"<plugin-root>/scripts/install-statusline" apply` (no prompt needed — this
     is the harness's own statusline).
   - `conflict`: show the user the existing conflicting command (`statusLine.command`
     and/or `subagentStatusLine.command`), then ASK whether to back up and replace
     it. Only on an explicit yes, run
     `"<plugin-root>/scripts/install-statusline" apply --replace`, which
     timestamp-backs-up the existing scripts and `settings.json` before replacing.
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

Dispatch only after the active skill's trigger fires, then read
`docs/platforms/claude-code.md` `## Role Dispatch` for the full host contract.
Prefer `oh-no-harness:<role>`, request the whole independent batch before
waiting, capture every final result, and clean up only after integration. An
approved-plan handoff is dispatch authorization for eligible isolated roles;
plugin-agent unavailability uses the documented embedded-role fallback.

## Model Diversity Pair

This mechanism is trigger-loaded, not embedded in every workflow decision. For
any dispatched `plan-reviewer` or `code-reviewer` pair (every dispatched review),
or a named THOROUGH `debugger` pair, both legs MUST be requested in a single
batch: issue both subagent tool calls in the same assistant turn (or with
`Background: yes` for both) BEFORE waiting on either result; a serial
dispatch-wait-dispatch sequence is not a valid pair. The two legs' packet bodies
MUST be identical except the single `Assigned perspective:` line (Lens A on the
primary leg, Lens B on the diversity leg); leg identity (`primary` vs
`diversity`) is carried ONLY by the host dispatch metadata (the description field
and the model override), never inside the packet text. Read the role's concrete
stored primary and validated secondary top-tier model from the session
`<OH_NO_MODEL_DIVERSITY>` block. The primary leg is
unoverridden and uses the declared-frontmatter primary; the
secondary leg carries an explicit NATIVE model override. Claim
`model-diversity-pair` only when the primary is not `host-default` and the
secondary differs from it. Otherwise default to two independent same-model
instances as `same-model-parallel-fallback` with the reason recorded; an
explicit `require-model-diversity` demand transitions to PAUSED when the
diversity leg is unavailable. Fusion Rescue uses its Claude Code overlay's
three-panel assignment instead of this two-leg shape.

## Source: docs/platforms/claude-code-install-statusline.md

# Claude Code Install Statusline Rules

This platform overlay is source content for the generated Claude Code-facing
`install-statusline` runtime document, after the shared core and
`docs/platforms/claude-code-runtime.md`.

The statusline installs into the config directory this Claude Code binary reads:
`CLAUDE_CONFIG_DIR` when set, otherwise `~/.claude`. The bundled installer
resolves this itself; do not hardcode `~/.claude`.

When `CLAUDE_PLUGIN_ROOT` is set, run the bundled installer directly:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/install-statusline" check
"${CLAUDE_PLUGIN_ROOT}/scripts/install-statusline" apply
"${CLAUDE_PLUGIN_ROOT}/scripts/install-statusline" apply --replace
```

If the plugin root is not exposed, locate the installed script first:

```bash
script="$(find "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins" -path '*/oh-no-harness/*/scripts/install-statusline' -print -quit)"
"$script" check
```

For the `conflict` case, ask the user with the host's structured question tool
(`AskUserQuestion`) before replacing: show the existing
`statusLine.command`, and offer "back up and replace" versus "keep existing". Only
run `apply --replace` after an explicit choice to replace.

The statusline reads Claude Code's statusLine JSON input, including `.effort.level`
for the model reasoning effort. The change takes effect on the next
`refreshInterval` tick; `/clear` or a new session guarantees it.
