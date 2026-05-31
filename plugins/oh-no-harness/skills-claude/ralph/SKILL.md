---
name: ralph
description: Use when implementing or executing an approved plan, PRD, spec, story list, ticket, or concrete task with acceptance criteria, required verification, or multiple implementation steps.
argument-hint: "<approved plan, PRD path, spec path, or concrete task>"
---

# Ralph for Claude Code

This is the Claude Code-facing public skill wrapper.

Follow this order:

1. Read and follow `../../docs/skill-core/ralph.md`.
2. Apply Claude Code platform rules from `../../docs/platforms/claude-code.md`.
3. Preserve the core skill's artifact paths, approval gates, role boundaries,
   worktree rules, TDD rules, verification rules, and output contract.
- Also apply `../../docs/platforms/claude-code-ralph.md` for Ralph-specific role dispatch.

4. Use the available Claude Code skill, question, task, agent, or subagent
   mechanisms only when the active host exposes them. If a platform capability
   is unavailable, keep the core role boundary inline and record the fallback
   reason when the core skill requires it.

Do not apply another platform's invocation syntax.
