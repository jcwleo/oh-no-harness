# OpenCode Simplify Rules

This overlay follows the shared Simplify core and the OpenCode runtime.

When the core selects combined depth, run one combined read-only pass. When it
selects four-viewpoint depth, issue four `task` calls in one assistant turn,
each with `subagent_type: oh-no-explore` and exactly one self-contained angle:
Reuse, Simplification, Efficiency, or Altitude. The direct user form is
`@oh-no-explore`.

Foreground task returns are the waits and results. If background mode is
available, wait for automatic completion notifications; do not poll, inspect a
partial batch as final, duplicate work, or redo it inline. Capture all four
results before synthesis. If task dispatch is unavailable, use the core's
labeled inline fallback and record the reason. Accepted cleanup mutation uses
`oh-no-executor` under the core's executor-default rule.
