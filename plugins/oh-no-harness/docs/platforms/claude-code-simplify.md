# Claude Code Simplify Rules

This platform overlay is source content for the generated Claude Code-facing
`simplify` runtime document, after the shared core and
`docs/platforms/claude-code-runtime.md`.

## Cleanup Dispatch

Cleanup always runs the four cleanup role passes in parallel. Prefer Workflow
`Promise.all` for the four-pass cleanup path when available; otherwise issue all
four background Task or Agent requests before inspecting or summarizing task
results. Each request gets exactly one angle: Reuse, Simplification, Efficiency,
or Altitude.

If Claude Code subagent dispatch is unavailable, preserve the same four cleanup
role passes inline as four labeled blocks and record the fallback reason required
by the shared core.
