---
name: using-oh-no-harness
description: Use when starting a session with Oh No Harness, deciding whether a local skill applies, selecting between interview, planning, Ralph execution, debugging, cleanup, or verification, and recognizing TDD as an internal guardrail.
argument-hint: "[task, question, or routing need]"
---

# Using Oh No Harness for Claude Code

This is the Claude Code-facing public skill wrapper.

Follow this order:

1. Read and follow `../../docs/skill-core/using-oh-no-harness.md`.
2. Apply Claude Code platform rules from `../../docs/platforms/claude-code.md`.
3. Preserve the core skill's artifact paths, approval gates, role boundaries,
   worktree rules, TDD rules, verification rules, and output contract.
4. Use the available Claude Code skill, question, task, agent, or subagent
   mechanisms only when the active host exposes them. If a platform capability
   is unavailable, keep the core role boundary inline and record the fallback
   reason when the core skill requires it.

Do not apply another platform's invocation syntax.
