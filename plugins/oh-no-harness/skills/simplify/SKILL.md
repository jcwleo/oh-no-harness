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

Do not apply another platform's invocation syntax.
