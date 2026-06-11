---
name: simplify
description: Review changed code for reuse, simplification, efficiency, and altitude cleanups, then apply behavior-preserving fixes after implementation approval.
argument-hint: "[<target>]"
---

# Simplify for Claude Code

This is the Claude Code-facing public skill wrapper.

Claude Code also has a built-in `/simplify` skill. This wrapper keeps the
Oh No Harness plugin-namespaced route aligned with the same cleanup contract;
Ralph must use the host built-in `/simplify` when it is available.

Follow this order:

1. Read and follow `../../docs/skill-core/simplify.md`.
2. Apply Claude Code platform rules from `../../docs/platforms/claude-code.md`.
3. Preserve the core skill's artifact paths, approval gates, role boundaries,
   worktree rules, TDD rules, verification rules, and output contract.
4. Use the available Claude Code skill, question, task, agent, or subagent
   mechanisms only when the active host exposes them.
5. This skill's cleanup review is gated by diff size: a small diff selects
   one cleanup subagent reporting four labeled sections; otherwise it
   requires four parallel cleanup subagents.
   The four labeled sections are Reuse, Simplification, Efficiency, and
   Altitude. If Claude Code task or subagent dispatch is unavailable, record
   the fallback reason; above the gate, preserve the same four cleanup role
   boundaries as separate inline fallback blocks, while a small diff falls
   back to a single inline pass that still reports the four labeled sections.

Do not apply another platform's invocation syntax.
