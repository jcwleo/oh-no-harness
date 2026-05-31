---
name: test-driven-development
description: Use when implementing a feature, bugfix, behavior change, regression fix, or behavior-preserving refactor before editing production code or changing observable behavior.
argument-hint: "<feature, bugfix, refactor, or behavior change>"
---

# Test Driven Development for Codex

This is the Codex-facing public skill wrapper.

Follow this order:

1. Read and follow `../../docs/skill-core/test-driven-development.md`.
2. Apply Codex platform rules from `../../docs/platforms/codex.md`.
3. Preserve the core skill's artifact paths, approval gates, role boundaries,
   worktree rules, TDD rules, verification rules, and output contract.
4. Use only the invocation syntax authorized by the active Codex host. If a
   platform capability is unavailable, keep the core role boundary inline and
   record the fallback reason when the core skill requires it.

Do not apply another platform's invocation syntax.
