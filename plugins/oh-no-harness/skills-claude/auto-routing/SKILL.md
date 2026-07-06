---
name: auto-routing
description: Use when the user wants to manage Oh No Harness session toggles, such as turning automatic skill-selection guidance on or off, checking routing status, making the bootstrap prompt more or less assertive across sessions, or turning the Codex executor delegation toggle on or off.
argument-hint: "[on|off|status | codex-executor on|off|status]"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Auto Routing for Claude Code

This generated file is the Claude Code-facing runtime skill document. Claude Code slash commands should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/auto-routing.md`
- `../../docs/platforms/claude-code-runtime.md`
- `../../docs/platforms/claude-code-auto-routing.md`

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

From Claude Code, the current-host main agent consults Codex only by dispatching
the dedicated read-only consult agent `oh-no-harness:<role>-codex` for the
assigned opposite-host leg, where `<role>` is `plan-reviewer`, `code-reviewer`,
or `debugger` for shared cross-host review, or `fusion` for a Fusion Rescue panel
slot. That consult agent resolves the Codex companion path and runs one
synchronous, read-only `codex-companion.mjs task` call: it omits the write flag
so the companion sandbox is read-only (best-effort, not a guarantee — see the
consult agent cores), and it never runs the call as a detached background job. If the companion is unavailable or unresolvable, treat the
opposite host as unavailable; in default mode the calling skill applies the
shared cross-host contract's Same-Host Parallel Fallback
(`docs/shared/cross-host-review.md`), and require-cross-host mode blocks. Name the
failure class and the current-host fallback.

The consult must return Codex's actual assigned analysis synchronously. The
`codex-companion.mjs` call passes the scoped, redacted packet with `--prompt-file`
and must not run in the background. A response that only acknowledges a queued or
background job — text that a task started in the background with a status command
for a job id — is not a valid opposite-host response; treat it as no Codex
response and degrade (default) or block (require-cross-host). Do not poll status
or fetch a deferred result to compensate; the consult call itself must return the
analysis.

For shared cross-host review, the packet the `oh-no-harness:<role>-codex` agent
sends must instruct Codex to dispatch the matching `oh-no-<role>` role agent for
the assigned opposite-host pass, where `<role>` is `plan-reviewer`,
`code-reviewer`, or `debugger`. Codex must wait for that dispatched role agent and
return its assigned role result, and the consult agent must require role-ownership
proof that the dispatched role agent — not a parent inline Codex answer — produced
it. A direct Codex parent answer is not a
valid opposite-host shared review response. If Codex cannot dispatch the matching
role agent, or the role-ownership proof is missing, treat the opposite host as
unavailable in default mode or block in require-cross-host mode; do not accept
inline Codex parent analysis as the cross-host pass. Role ownership is best-effort
— there is no host selector that forces it — so it is required and proven, not
assumed.

Fusion Rescue panel slots remain governed by the Fusion Rescue panel contract;
the role-agent requirement above applies only to shared cross-host review. The
`oh-no-harness:fusion-codex` panel slot dispatches `oh-no-fusion-rescue-analyst`
for one assigned lens (see `docs/platforms/claude-code-fusion-rescue.md`).

The outbound packet must request only the assigned analysis and must forbid the
opposite host from invoking further rescue, another workflow skill, or any
host-to-host call back to Claude Code or a third host (one cross-host hop).
Redact secrets before sending; on failure record only the failure class and
companion/path/auth status, never secret values.

## Source: docs/platforms/claude-code-auto-routing.md

# Claude Code Auto Routing Rules

This platform overlay is source content for the generated Claude Code-facing
`auto-routing` runtime document, after the shared core and
`docs/platforms/claude-code-runtime.md`.

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

The `codexExecutor` toggle uses the same script with the `codex-executor`
subcommand:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" codex-executor status
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" codex-executor on
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" codex-executor off
```

On Claude Code, the shared core's bootstrap/session-start timing applies as the
`SessionStart` event, and the clear/reset command is `/clear`.

When the `codexExecutor` toggle is ON, the codex-executor delegation block is
injected via `SessionStart` on Claude Code only. That injected block re-binds the
executor role and dispatches `oh-no-harness:executor-codex` in place of
`oh-no-harness:executor`. Turning the toggle on or off takes effect only after
the `SessionStart` event re-fires (a new session or `/clear`).
