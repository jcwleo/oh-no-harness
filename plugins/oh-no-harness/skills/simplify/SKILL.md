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
5. This skill prefers four parallel cleanup subagents. If Codex subagent
   dispatch is unavailable, preserve the same four cleanup role boundaries as
   separate inline fallback blocks and record the fallback reason.
   Call `spawn_agent` with the exact registered custom agent for each cleanup
   role when the host accepts it: Reuse uses `agent_type =
   "oh-no-cleanup-reuse"`, Simplification uses `agent_type =
   "oh-no-cleanup-simplification"`, Efficiency uses `agent_type =
   "oh-no-cleanup-efficiency"`, and Altitude uses `agent_type =
   "oh-no-cleanup-altitude"`. Do not use a generic/default worker for these
   cleanup roles unless that exact `agent_type` call was rejected as unknown or
   unavailable and the fallback reason is recorded. Writing `Codex agent type:
   ...` in the worker message is only an audit marker; it does not replace the
   actual `agent_type` argument on `spawn_agent`.
6. When the Codex SessionStart context includes the Oh No Harness standing
   subagent authorization, treat it as the explicit user request for this
   skill's Reuse, Simplification, Efficiency, and Altitude subagents. Do not ask
   for additional per-run subagent approval.

Do not apply another platform's invocation syntax.
