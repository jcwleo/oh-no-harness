---
name: ralplan
description: Use when broad, risky, architecture-sensitive, cross-file, multi-step, or unclear work needs consensus implementation planning before coding.
argument-hint: "[--subagents] <task, spec path, or plan request>"
---

# Ralplan for Codex

This is the Codex-facing public skill wrapper.

Follow this order:

1. Read and follow `../../docs/skill-core/ralplan.md`.
2. Apply Codex platform rules from `../../docs/platforms/codex.md`.
3. Preserve the core skill's artifact paths, approval gates, role boundaries,
   worktree rules, TDD rules, verification rules, and output contract.
4. Use only the invocation syntax authorized by the active Codex host. If a
   platform capability is unavailable, keep the core role boundary inline and
   record the fallback reason when the core skill requires it.

Do not apply another platform's invocation syntax.
