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
