# Codex Simplify Rules

This platform overlay is source content for the generated Codex-facing
`simplify` runtime document, after the shared core and
`docs/platforms/codex-runtime.md`.

## Cleanup Dispatch

On Codex, the `CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION` SessionStart
context is the standing explicit user request for Simplify cleanup delegation.
Do not ask another approval question merely to launch eligible cleanup
subagents.

Use Codex subagent dispatch when the active Codex host exposes it and the
cleanup pass is worth isolating. For diffs above the small-diff gate, launch the
Reuse, Simplification, Efficiency, and Altitude cleanup subagents as one
eligible batch before waiting for any result. For a small diff, launch one
cleanup subagent only when it provides useful context separation; otherwise keep
the single cleanup pass inline with all four labeled sections.

If Codex subagent dispatch is unavailable, unsafe, or not useful, preserve the
same cleanup role boundary inline and record the fallback reason required by the
shared core.
