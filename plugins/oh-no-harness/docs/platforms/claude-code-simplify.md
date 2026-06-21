# Claude Code Simplify Rules

This platform overlay is source content for the generated Claude Code-facing
`simplify` runtime document, after the shared core and
`docs/platforms/claude-code-runtime.md`.

## Cleanup Dispatch

For diffs above the small-diff gate, prefer Workflow `Promise.all` for the
four-pass cleanup path when available. Otherwise, issue all four background Task
or Agent requests before inspecting or summarizing task results. Each request
gets exactly one angle: Reuse, Simplification, Efficiency, or Altitude.

For a small diff, use one cleanup subagent with all four angles only when the
active host exposes an appropriate mechanism and the separation is useful. If
Claude Code subagent dispatch is unavailable, preserve the same cleanup role
boundary inline and record the fallback reason required by the shared core.
