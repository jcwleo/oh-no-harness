---
name: ai-slop-cleaner
description: Use when AI-generated code, generated tests, or assistant-written diffs need behavior-preserving cleanup after implementation approval, before review, or before final delivery.
argument-hint: "<files, paths, or changed-file scope>"
---

# AI Slop Cleaner for Codex

This is the Codex-facing public skill wrapper.

Follow this order:

1. Read and follow `../../docs/skill-core/ai-slop-cleaner.md`.
2. Apply Codex platform rules from `../../docs/platforms/codex.md`.
3. Preserve the core skill's artifact paths, approval gates, role boundaries,
   worktree rules, TDD rules, verification rules, and output contract.
4. Use only the invocation syntax authorized by the active Codex host. If a
   platform capability is unavailable, keep the core role boundary inline and
   record the fallback reason when the core skill requires it.

Do not apply another platform's invocation syntax.
