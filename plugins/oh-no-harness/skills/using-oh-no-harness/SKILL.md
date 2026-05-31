---
name: using-oh-no-harness
description: Use when starting a session with Oh No Harness, deciding whether a local skill applies, selecting between interview, planning, execution, debugging, TDD, cleanup, or verification skills, handling a request that may need one, or asking a clarification question.
argument-hint: "[task, question, or routing need]"
---

# Using Oh No Harness for Codex

This is the Codex-facing public skill wrapper.

Follow this order:

1. Read and follow `../../docs/skill-core/using-oh-no-harness.md`.
2. Apply Codex platform rules from `../../docs/platforms/codex.md`.
3. Preserve the core skill's artifact paths, approval gates, role boundaries,
   worktree rules, TDD rules, verification rules, and output contract.
4. Use only the invocation syntax authorized by the active Codex host. If a
   platform capability is unavailable, keep the core role boundary inline and
   record the fallback reason when the core skill requires it.

Do not apply another platform's invocation syntax.
