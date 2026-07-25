# Codex Simplify Rules

This platform overlay is source content for the generated Codex-facing
`simplify` runtime document, after the shared core and
`docs/platforms/codex-runtime.md`.

## Cleanup Dispatch

On Codex, the `CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION` SessionStart
context is the standing explicit user request for Simplify cleanup delegation.
Do not ask another approval question merely to launch eligible cleanup
subagents.

When the core selects combined depth, run one combined pass. When it selects
four-viewpoint depth, use intentionally untyped `spawn_agent(task_name="simplify_reuse", message=<self-contained Reuse packet>, fork_turns="none")`; use that same three-field form with self-contained viewpoint messages and task names `simplify_simplification`, `simplify_efficiency`, and `simplify_altitude`, never passing `agent_type`, then launch
all four before waiting only when the host limit permits four; otherwise launch
three, wait and capture them, then launch the remaining viewpoint. If Codex
subagent dispatch is unavailable, use the core's inline labeled-block fallback.
The core owns selection, inline-fallback, and fallback-reason semantics.
