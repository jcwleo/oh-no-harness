---
name: test-driven-development
description: Use inside ralph-owned execution to enforce RED/GREEN/REFACTOR before behavior-changing production edits, or when explicitly asked for TDD/test-first work; not a top-level implementation route.
argument-hint: "<explicit TDD/test-first change>"
---

# Test Driven Development for Claude Code

This is the Claude Code-facing public skill wrapper.

Follow this order:

1. Read and follow `../../docs/skill-core/test-driven-development.md`.
2. Apply Claude Code platform rules from `../../docs/platforms/claude-code.md`.
3. Preserve the core skill's artifact paths, approval gates, role boundaries,
   worktree rules, TDD rules, verification rules, and output contract.
4. Use the available Claude Code skill, question, task, agent, or subagent
   mechanisms only when the active host exposes them. If a platform capability
   is unavailable, keep the core role boundary inline and record the fallback
   reason when the core skill requires it.

Do not apply another platform's invocation syntax.
