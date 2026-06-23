# Codex Simplify Rules

This platform overlay is source content for the generated Codex-facing
`simplify` runtime document, after the shared core and
`docs/platforms/codex-runtime.md`.

## Cleanup Dispatch

On Codex, the `CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION` SessionStart
context is the standing explicit user request for Simplify cleanup delegation.
Do not ask another approval question merely to launch eligible cleanup
subagents.

Cleanup always runs the four cleanup role passes in parallel. When the active
Codex host exposes subagent dispatch, launch the Reuse, Simplification,
Efficiency, and Altitude cleanup subagents as one eligible batch before waiting
for any result.

If Codex subagent dispatch is unavailable, preserve the same four cleanup role
passes inline as four labeled blocks and record the fallback reason required by
the shared core.
