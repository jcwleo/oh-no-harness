---
name: auto-routing
description: Use when the user wants to manage Oh No Harness session toggles, such as turning automatic skill-selection guidance on or off, checking routing status, making the bootstrap prompt more or less assertive across sessions, turning the Codex executor delegation toggle on or off, or turning same-host review mode on or off.
argument-hint: "[on|off|status | codex-executor on|off|status | same-host-review on|off|status]"
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

Codex role dispatch is host-policy controlled. Use `spawn_agent` only when the
host exposes it, the active skill permits dispatch, and the role has isolated
read-only scope, disjoint write ownership, or an independent review or
verification responsibility.

For Oh No Harness roles, use the registered custom agent first:
`spawn_agent(agent_type="oh-no-<role>", ...)`. Generic fallback is allowed only
inside an active Oh No Harness workflow or explicit user-requested subagent
task after an actual `agent_type="oh-no-<role>"` attempt is rejected as unknown
or unavailable, and the fallback reason is recorded. Do not infer custom-agent
unavailability from rendered schema text, display comments, or uncertainty.

Do not combine `agent_type="oh-no-<role>"` with `fork_context=true` or any
full-history fork request. Pass the current scope, constraints, expected output,
and lifecycle in the spawned-agent message, using one payload shape only.

The Codex SessionStart standing authorization, a user standing preference, an
approved plan profile, or an active Oh No Harness skill policy is workflow-level
authorization for eligible isolated subagents. Do not ask another per-run
approval question only to dispatch those roles. Dispatch only when the result
can change implementation, review, verification, latency, context management,
or the ship/block decision.

After `wait_agent` returns a final status, capture the output and any
changed-file set before cleanup. A timeout, empty wait, or "No agents completed
yet" result is not final and is not permission to close the subagent. Once a
role is dispatched, its assigned scope, role, and expected output become a
workflow dependency. Wait until every in-scope dispatched subagent reaches final
status, capture its result, and use that result in synthesis, implementation,
review, verification, or an explicit blocked/abandoned record before advancing
past the dependent step or claiming completion. While waiting, continue only
genuinely non-overlapping local work. Do not redo delegated work inline, spawn
a duplicate replacement, or let parent inline analysis substitute for the
subagent result merely because the subagent is slow. Never use missing output
as completion evidence.

Close or clean up a subagent without a captured final result only when the user
explicitly cancels or stops that subagent, the task scope invalidates the work,
the spawn was duplicate or mis-scoped, or continuing creates a safety, security,
or filesystem risk. Record that close as cancelled or abandoned.

## Generic Role Prompt Fallback

When generic Codex agent types are used after confirmed custom-agent
unavailability, embed the matching `docs/agent-core/<role>.md` prompt body in
the spawned-agent message. If only `agents/<role>.md` exists, strip Claude Code
YAML frontmatter before embedding.

## Cross-Host Consult Channel

This is the shared cross-host consult mechanism used by Fusion Rescue and by
cross-host review (`docs/shared/cross-host-review.md`). On Codex the opposite
host is Claude Code. This section carries only the Codex-to-Claude invocation;
the activation, synthesis, and recursion-guard semantics live in the calling
skill core and the shared doc.

When the session context carries the same-host review toggle block, skip the
opposite-host preflight and consult entirely; do not probe availability. The
calling skill then runs its own same-host path — the Same-Host Parallel pair for
the review roles (`plan-reviewer`, `code-reviewer`, `debugger`), or the normal
local panels for Fusion Rescue — and records `same-host-parallel-selected`.

From Codex, consult Claude Code through `${CLAUDE_BIN:-claude}` only when the
active Codex permission state is exactly `danger-full-access`. If the state is
missing, unknown, `read-only`, `workspace-write`, or anything else, do not call
Claude: treat the opposite host as unavailable; in default mode the calling skill
applies the shared cross-host contract's Same-Host Parallel Fallback
(`docs/shared/cross-host-review.md`), and require-cross-host mode blocks while
naming the failure class and the current-host fallback.

For shared cross-host review, the Codex parent must not run
`${CLAUDE_BIN:-claude}` inline. After the preflight confirms
`danger-full-access`, dispatch the matching Codex role subagent with
`spawn_agent(agent_type="oh-no-<role>", ...)` for the opposite-host consult
owner, where `<role>` is `plan-reviewer`, `code-reviewer`, or `debugger`.
The `verifier` has no cross-host leg: it stays an unconditionally single
self-host pass on whichever host runs it (`docs/shared/cross-host-review.md`).
The spawned role subagent receives the redacted role packet, performs
the single Claude consult through this channel, and returns the assigned role
analysis. The Codex parent waits for that subagent, captures its result, closes
or records lifecycle cleanup, and only then synthesizes. A parent inline Claude
consult is not a valid shared cross-host review pass. If the role subagent cannot
be dispatched, treat the opposite host as unavailable in default mode or block in
require-cross-host mode; do not fall back to a parent inline Claude call.

Fusion Rescue is separate: its Codex-specific panel overlay may assign a
`fusion-rescue-analyst` panel subagent to own the Claude consult. The paragraph
above applies only to shared cross-host review roles.

When the `danger-full-access` preflight confirms, build the Claude command as an
argument vector, not shell string interpolation: `${CLAUDE_BIN:-claude}`,
`--print`, `--model`, `opus`, `--permission-mode`, `dontAsk`,
`--no-session-persistence`, then the redacted prompt packet, unless the user
supplied a different Claude model. Do not strip Claude's tools by default; Claude
may need its own read-only tools to produce the assigned analysis. The read-only
boundary is enforced by the redacted packet and host permissions, not by
removing tools.

The consult must return Claude's actual assigned analysis synchronously. A launch
notice, queued-job message, background acknowledgement, or status pointer is not
a valid opposite-host response; treat it as unavailable. The Claude prompt must
request only the assigned analysis and must forbid file edits, writes, installs,
mutating commands, nested rescue, and any host-to-host ping-pong back to Codex or
a third host (one cross-host hop). Redact secrets before sending; on failure
record only the failure class and command/path/auth status, never secret values.

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

Unlike `autoRouting` and `codexExecutor`, the `sameHostReview` toggle DOES inject
`<OH_NO_SAME_HOST_REVIEW>` on Codex when plugin hooks are enabled. Without plugin
hooks, `oh-no-config same-host-review on|off|status` stores state but has no
Codex runtime effect. Config state is per-host: Codex reads the XDG path
`${XDG_CONFIG_HOME:-$HOME/.config}/oh-no-harness/config.json`, not a co-installed
Claude Code plugin-data config.

Non-Claude/non-Codex hosts (for example Cursor) receive the block best-effort via
the shared SessionStart envelope and may co-resolve config with a Claude install.
