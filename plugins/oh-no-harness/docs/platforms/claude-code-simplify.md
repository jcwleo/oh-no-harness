# Claude Code Simplify Rules

This platform overlay is source content for the generated Claude Code-facing
`simplify` runtime document, after the shared core and
`docs/platforms/claude-code-runtime.md`.

## Cleanup Dispatch

When the core selects combined depth, run one combined pass. When it selects
four-viewpoint depth, prefer Workflow `Promise.all` when available; otherwise
issue all four background Task or Agent requests before waiting or inspecting
results. Each request gets exactly one angle: Reuse, Simplification, Efficiency, or Altitude. These are read-only discovery workers: dispatch each as `oh-no-harness:explore` — Task and Agent set `subagent_type: oh-no-harness:explore`, a Workflow `agent()` call sets `agentType: "oh-no-harness:explore"`. If dispatch is unavailable, use the shared core's inline labeled-block fallback; the core owns selection and fallback semantics.
