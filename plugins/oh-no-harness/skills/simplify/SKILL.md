---
name: simplify
description: Review changed code for reuse, simplification, efficiency, and altitude cleanups, then apply behavior-preserving fixes after implementation approval.
argument-hint: "[<target>]"
---

# Simplify for Codex

This is the Codex-facing public skill wrapper.

Follow this order:

1. Read and follow `../../docs/skill-core/simplify.md`.
2. Apply Codex platform rules from `../../docs/platforms/codex.md`.
3. Preserve the core skill's artifact paths, approval gates, role boundaries,
   worktree rules, TDD rules, verification rules, and output contract.
4. Use only the invocation syntax authorized by the active Codex host.
5. This skill's cleanup review is gated by diff size: a small diff selects
   one cleanup subagent reporting four labeled sections; otherwise it
   requires four parallel cleanup subagents.
   The four labeled sections are Reuse, Simplification, Efficiency, and
   Altitude. If Codex subagent dispatch is unavailable, record the fallback
   reason; above the gate, preserve the same four cleanup role boundaries as
   separate inline fallback blocks, while a small diff falls back to a single
   inline pass that still reports the four labeled sections.
6. When the Codex SessionStart context includes the Oh No Harness standing
   subagent authorization, treat it as the explicit user request for this
   skill's Reuse, Simplification, Efficiency, and Altitude subagents. Do not ask
   for additional per-run subagent approval.

Do not apply another platform's invocation syntax.
