---
name: install-statusline
description: User-invoked setup action that installs the Oh No Harness developer statusline into the user's Claude Code settings. Run it explicitly with the slash command; it is never auto-invoked by the model.
argument-hint: "[check]"
disable-model-invocation: true
---

# Install Statusline

Install Statusline is a user-invoked setup action. It installs a developer-focused
Claude Code statusline (working directory, git branch/status, model and reasoning
effort, context-window gauge, and rate-limit gauges) into the user's
`~/.claude` configuration so a freshly set up Claude Code environment gets the
same statusline. In the same pass it also installs a matching
**subagent statusline** (`subagentStatusLine`) that renders each running
subagent's row with its status, resolved model, context-usage gauge, elapsed
time, and description — using the same visual language as the main statusline.

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
resolved yet, and the row degrades to `inherit` plus a raw token count).

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
