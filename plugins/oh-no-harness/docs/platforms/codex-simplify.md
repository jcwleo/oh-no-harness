# Codex Simplify Rules

This platform overlay is source content for the generated Codex-facing
`simplify` runtime document, after the shared core and
`docs/platforms/codex-runtime.md`.

## Cleanup Dispatch

On Codex, the `CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION` SessionStart
context is the standing explicit user request for Simplify cleanup delegation.
Do not ask another approval question merely to launch eligible cleanup
subagents.

Launch the four cleanup passes via Codex `spawn_agent` with
`fork_turns="none"` following the shared core's one batch before waiting
dispatch rule; if Codex subagent dispatch is unavailable, use the core's
inline labeled-block fallback. The core owns the
batch, inline-fallback, and fallback-reason rules; do not restate them here.
