---
name: auto-routing
description: Use when the user wants to manage Oh No Harness session toggles, such as turning automatic skill-selection guidance on or off, checking routing status, making the bootstrap prompt more or less assertive across sessions, or turning the Codex executor delegation toggle on or off.
argument-hint: "[on|off|status | codex-executor on|off|status]"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Auto Routing for Codex

This generated file is the Codex-facing runtime skill document. Codex should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/auto-routing.md`
- `../../docs/platforms/codex-runtime.md`
- `../../docs/platforms/codex-auto-routing.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/auto-routing.md

# Auto Routing

Auto Routing is the manager of the Oh No Harness **session toggles**. It manages
two independent, session-scoped preferences stored in the same `config.json`:
the `autoRouting` skill-selection toggle described here, and the `codexExecutor`
executor-delegation toggle described under Codex Executor Delegation Toggle
below. Both are read at bootstrap/session-start.

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
  Its assigned RED, GREEN, REFACTOR, focused-fix, and cleanup mutations may be
  delegated; caller-run checks, verification, review, and merge stay with the
  native independent roles.
- **Eligibility unchanged.** Existing Ralph eligibility remains the sole gate.
  An already-admitted disjoint executor batch may overlap only at the outer
  `executor-codex` agent layer; each inner companion call remains foreground.
  Ineligible, unknown, or unsafe work stays serial, and fallback and integration
  remain caller-owned and sequential.
- **Best-effort confinement, not a guarantee.** Delegated writes are scoped
  best-effort to the task worktree. The executor transport returns raw Codex
  output; the caller owns the escape-DETECTION guard, derives the worktree diff,
  and halts before merge on an unexpected protected-target change. This is
  DETECTION, not prevention, and is not a sandbox guarantee.
- Manage it with `oh-no-config codex-executor on|off|status` (see Commands), then
  restart or clear the session so the bootstrap re-fires (see Response Rules).
  Whether the toggle produces a runtime effect depends on the active platform
  (see Platform Behavior and the platform runtime document).

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

Stored shape (both toggles are independent sibling keys):

```json
{
  "autoRouting": {
    "enabled": true
  },
  "codexExecutor": {
    "enabled": false
  }
}
```

`codexExecutor` defaults to OFF (`enabled: false`). Writing one toggle must
preserve the sibling toggle's value; never clobber `autoRouting` when changing
`codexExecutor`, or vice versa.

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
- When changing either toggle, preserve the sibling toggle's value; do not clobber
  `autoRouting` or `codexExecutor` when writing the other.
- If Bash is unavailable, explain the config file shape without claiming the setting changed.
- Do not invoke workflow skills from this configuration skill.

## Source: docs/platforms/codex-runtime.md

# Codex Runtime Rules

This compact platform section is embedded in generated Codex-facing skill
documents.

## Skill Loading

Codex-facing public skills live under `skills/`. Generated
`skills/<skill>/SKILL.md` files compose the matching skill core, this compact
runtime section, and any Codex skill-specific overlay such as
`docs/platforms/codex-<skill>.md`.

## User Approval And Prompting

Ask approval, preference, scope, or next-step questions directly in the Codex
conversation. Keep prompts outcome-first: state the desired outcome,
acceptance criteria, non-goals or side effects, expected evidence, and output
shape before detailed steps.

Use compact final answers unless the active skill requires a plan, review, or
verification report. Preserve durable state in written artifacts before long
work, compaction, or handoff.

## Role Dispatch

Dispatch only after the active skill's trigger fires, then read
`docs/platforms/codex.md` `## Role Dispatch` for the full host contract. Use
`spawn_agent(agent_type="oh-no-<role>", ...)` first with `fork_turns="none"`
(omitting it defaults to a full-history fork, which rejects a custom
`agent_type`), do not combine it with `fork_context=true`, and use generic
prompt embedding only after the custom agent is actually rejected. The task packet carries scope, ownership, expected
output, and lifecycle.

Every dispatched result is a dependency: `wait_agent` must reach final status,
the caller captures and uses the output, and only then performs lifecycle
cleanup. Timeout, empty output, or "No agents completed yet" is not final; do
not close, redo inline, or use missing output as evidence.

## Generic Role Prompt Fallback

After confirmed custom-agent unavailability, embed
`docs/agent-core/<role>.md`; see the full platform doc for the fallback shape.

## Cross-Host Consult Channel

This channel is trigger-loaded, not embedded in every workflow decision. When a
named THOROUGH paired-review or Fusion Rescue trigger fires, read and apply
`docs/platforms/codex.md` `## Cross-Host Consult Channel` before dispatch. Until
then, do not preload opposite-host invocation details.

## Source: docs/platforms/codex-auto-routing.md

# Codex Auto Routing Rules

This platform overlay is source content for the generated Codex-facing
`auto-routing` runtime document, after the shared core and
`docs/platforms/codex-runtime.md`.

Codex native skill loading remains the primary routing surface. The
`auto-routing` skill can preserve the config file shape and explain the
preference, but it does not add forced routing to Codex SessionStart.

If a Codex-facing SessionStart hook runs, it must stay compact and must not
embed full skill core bodies.

The `codexExecutor` toggle behaves the same way as auto-routing on Codex: its
state is stored and explained here, but it adds NO Codex SessionStart block.
Codex native skill loading is unchanged, and on the Codex host the delegated
executor role behaves as the native `oh-no-executor` — delegation-to-Codex is a
no-op there. The `oh-no-config codex-executor on|off|status` verbs still read and
write the stored preference for portability, but they do not inject a delegation
block on Codex.
