# Claude Code Simplify Rules

This platform overlay is source content for the generated Claude Code-facing
`simplify` runtime document, after the shared core and
`docs/platforms/claude-code-runtime.md`.

## Cleanup Dispatch

Run the four cleanup passes in parallel: prefer Workflow `Promise.all` when
available; otherwise issue all four background Task or Agent requests before
inspecting or summarizing results. Each request gets exactly one angle: Reuse,
Simplification, Efficiency, or Altitude. If dispatch is unavailable, use the
shared core's inline labeled-block fallback (the core owns the fallback-reason
rule).
