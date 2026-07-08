---
name: auto-routing
description: Use when the user wants to manage Oh No Harness session toggles, such as turning automatic skill-selection guidance on or off, checking routing status, making the bootstrap prompt more or less assertive across sessions, turning the Codex executor delegation toggle on or off, or turning same-host review mode on or off.
argument-hint: "[on|off|status | codex-executor on|off|status | same-host-review on|off|status]"
---

# Auto Routing

Auto Routing is the manager of the Oh No Harness **session toggles**. It manages
three independent, session-scoped preferences stored in the same `config.json`:
the `autoRouting` skill-selection toggle described here, the `codexExecutor`
executor-delegation toggle described under Codex Executor Delegation Toggle
below, and the `sameHostReview` same-host review toggle described under
Same-Host Review Toggle below. All three are read at bootstrap/session-start.

Auto Routing (the `autoRouting` toggle) controls whether a supported platform
bootstrap hook adds stronger skill-selection guidance to `using-oh-no-harness`.

It does not add hidden runtime routing. It only changes persistent user preference for the SessionStart prompt.

## Software Development Stage

Auto Routing is a workflow-entry configuration stage, not a software development stage.

Use it to make future sessions more likely to choose the right skill before work starts. It should not gather requirements, plan, edit code, debug failures, clean code, or verify completion.

## When To Use

Use when the user asks to:

- enable, turn on, activate, or make skill routing more automatic
- disable, turn off, deactivate, or make skill routing quieter
- check current auto-routing status
- preserve stronger or weaker routing behavior across plugin updates
- enable or disable delegating the executor role's implementation work to Codex
  (the `codexExecutor` toggle)
- check current codex-executor delegation status
- enable or disable same-host review for the shared review/consult channel
  (the `sameHostReview` toggle)
- check current same-host-review status

Do not use as a substitute for skill selection inside the current session — for choosing a workflow skill in the current turn, read and follow `using-oh-no-harness`.

## Platform Behavior

Apply the active platform runtime document before changing settings. Some
platforms support persistent bootstrap routing; others can only explain the
setting and leave runtime behavior unchanged.

When the active platform supports persistent bootstrap routing, changes take
effect on the next bootstrap or session-start event, such as a new session, app
restart, clear/reset command, or compaction. Existing session context is not
rewritten.

## Codex Executor Delegation Toggle

The `codexExecutor` toggle is the second session toggle this skill manages. When
ON, and on a platform whose bootstrap supports delegation, Oh No Harness
delegates the **executor role's implementation work to Codex** instead of the
native `oh-no-harness:executor`, for every executor dispatch path (ralph,
ultrawork, systematic-debugging).

Shared facts (all platforms):

- **Default OFF.** Delegation is opt-in; with the toggle OFF the native
  `oh-no-harness:executor` runs and nothing changes.
- **Executor role only.** When ON, only the executor role is re-bound to Codex.
  RED authoring, verification, review, and merge stay with the native
  independent roles.
- **Serial-forced.** With delegation ON, disjoint executor batches are
  serial-forced — they run one at a time, not in parallel, in this version.
- **Best-effort confinement, not a guarantee.** Delegated writes are scoped
  best-effort to the task worktree, and a Claude-side escape-DETECTION net watches
  for and halts on an unexpected write outside that scope. This is
  DETECTION, not prevention, and is not a sandbox guarantee.
- Manage it with `oh-no-config codex-executor on|off|status` (see Commands), then
  restart or clear the session so the bootstrap re-fires (see Response Rules).
  Whether the toggle produces a runtime effect depends on the active platform
  (see Platform Behavior and the platform runtime document).

## Same-Host Review Toggle

The `sameHostReview` toggle is the third session toggle this skill manages.
Default OFF. When ON, it selects same-host review for the shared cross-host
review roles (`plan-reviewer`, `code-reviewer`, `debugger`) and the Fusion
Rescue opposite-host consult; the calling skill records
`same-host-parallel-selected`.

Scope: it only controls the review/consult channel. It never re-binds the
executor role; `sameHostReview` and `codexExecutor` are independent toggles.

State is per host. Claude Code uses its plugin-data config path; Codex uses the
XDG config path resolved by the host-aware `config_dir` logic in
`scripts/oh-no-config`, not a co-installed Claude config. On Codex, runtime
effect requires plugin hooks enabled. Changes take effect at the next
SessionStart event. An explicit `require-cross-host` request in the current user
message wins over the stored toggle.

## Configuration

The setting is stored outside the plugin cache so updates do not overwrite it.

Preferred location when the active platform provides plugin data:

```text
<platform-plugin-data>/config.json
```

The bundled `scripts/oh-no-config` script resolves the data directory; the
platform runtime document names the plugin root.

Fallback location when no platform plugin-data directory exists:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/oh-no-harness/config.json
```

Stored shape (three toggles are independent sibling keys):

```json
{
  "autoRouting": {
    "enabled": true
  },
  "codexExecutor": {
    "enabled": false
  },
  "sameHostReview": {
    "enabled": false
  }
}
```

`codexExecutor` and `sameHostReview` default to OFF (`enabled: false`). Writing
one toggle must preserve the other two keys' values; never clobber
`autoRouting`, `codexExecutor`, or `sameHostReview` when changing another.

## Commands

When Bash is available, use the bundled script instead of editing config by hand.

When the active platform runtime document exposes the plugin root:

```bash
"<plugin-root>/scripts/oh-no-config" status
"<plugin-root>/scripts/oh-no-config" on
"<plugin-root>/scripts/oh-no-config" off
```

If the plugin root is not exposed, locate the installed script first according
to the active platform runtime document.

```bash
script="$(find <platform-plugin-cache> -path '*/oh-no-harness/*/scripts/oh-no-config' -print -quit)"
"$script" status
```

The same script manages the `codexExecutor` toggle through the `codex-executor`
subcommand, mirroring the auto-routing verbs:

```bash
"<plugin-root>/scripts/oh-no-config" codex-executor status
"<plugin-root>/scripts/oh-no-config" codex-executor on
"<plugin-root>/scripts/oh-no-config" codex-executor off
```

It also manages the `sameHostReview` toggle through the `same-host-review`
subcommand, mirroring the same verbs:

```bash
"<plugin-root>/scripts/oh-no-config" same-host-review status
"<plugin-root>/scripts/oh-no-config" same-host-review on
"<plugin-root>/scripts/oh-no-config" same-host-review off
```

## Response Rules

- For `on`, enable the setting, report the config path, and tell the user to
  restart or clear the active platform session before expecting the new behavior.
- For `off`, disable the setting, report the config path, and tell the user to
  restart or clear the active platform session before expecting the new behavior.
- For `status`, report whether auto-routing is on or off and where the setting is stored.
- For `codex-executor on`, enable the `codexExecutor` toggle, report the config
  path, and tell the user to restart or clear the active platform session before
  the delegation takes effect — the bootstrap re-fires on the next session-start.
- For `codex-executor off`, disable the `codexExecutor` toggle, report the config
  path, and tell the user to restart or clear the session before the change takes
  effect.
- For `codex-executor status`, report whether codex-executor delegation is on or
  off and where the setting is stored.
- For `same-host-review on`, enable the `sameHostReview` toggle, report the
  config path, and tell the user to restart or clear the active platform session
  before same-host review takes effect.
- For `same-host-review off`, disable the `sameHostReview` toggle, report the
  config path, and tell the user to restart or clear the session before the
  change takes effect.
- For `same-host-review status`, report whether same-host review is on or off and
  where the setting is stored.
- When changing any toggle, preserve the other two keys' values; do not clobber
  `autoRouting`, `codexExecutor`, or `sameHostReview` when writing another.
- If Bash is unavailable, explain the config file shape without claiming the setting changed.
- Do not invoke workflow skills from this configuration skill.
