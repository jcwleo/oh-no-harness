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
