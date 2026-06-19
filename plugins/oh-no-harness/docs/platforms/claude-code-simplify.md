# Claude Code Simplify Rules

This platform overlay is source content for the generated Claude Code-facing
`simplify` runtime document, after the shared core and
`docs/platforms/claude-code.md`.

## Ralph Cleanup Route

Direct Oh No Harness plugin invocation and Ralph-internal cleanup both use this
generated Claude Code Simplify runtime document. Do not route Ralph-internal
cleanup to a host built-in `/simplify` skill, because that route may not load
the Oh No Harness cleanup contract for the current plugin version.

## Cleanup Dispatch

For diffs above the small-diff gate, prefer Workflow `Promise.all` for the
four-pass cleanup path when available. Otherwise, issue all four background Task
or Agent requests before inspecting or summarizing task results. Each request
gets exactly one angle: Reuse, Simplification, Efficiency, or Altitude.

For a small diff, use one cleanup subagent with all four angles only when the
active host exposes an appropriate mechanism and the separation is useful. If
Claude Code subagent dispatch is unavailable, preserve the same cleanup role
boundary inline and record the fallback reason required by the shared core.
