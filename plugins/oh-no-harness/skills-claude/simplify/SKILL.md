---
name: simplify
description: Review changed code for reuse, simplification, efficiency, and altitude cleanups, then apply behavior-preserving fixes after implementation approval.
argument-hint: "[<target>]"
---

# Simplify for Claude Code

This is the Claude Code-facing public skill wrapper.

Claude Code also has a built-in `/simplify` skill. Direct plugin invocation
uses this Oh No Harness wrapper, while Ralph-internal cleanup should use the
host built-in `/simplify` when that built-in route is available. Both routes
must preserve the same cleanup contract from `../../docs/skill-core/simplify.md`.

Follow this order:

1. Read and follow `../../docs/skill-core/simplify.md`.
2. Apply Claude Code platform rules from `../../docs/platforms/claude-code.md`.
3. Preserve the core skill's artifact paths, approval gates, role boundaries,
   worktree rules, TDD rules, verification rules, and output contract.
4. Use the available Claude Code skill, question, task, agent, or subagent
   mechanisms only when the active host exposes them.

Do not apply another platform's invocation syntax.
