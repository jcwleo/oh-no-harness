---
name: fusion-rescue
description: Use when a hard problem needs bounded three-panel rescue analysis, optional cross-host consultation, adversarial critique, fallback-aware synthesis, or escalation from Ralph/systematic-debugging after ordinary analysis stalls.
argument-hint: "<problem, failed plan, bug, decision, or blocked workflow>"
---

# Fusion Rescue for Claude Code

This is the Claude Code-facing public skill wrapper.

Follow this order:

1. Read and follow `../../docs/skill-core/fusion-rescue.md`.
2. Apply Claude Code platform rules from `../../docs/platforms/claude-code.md`.
3. Preserve the core skill's panel contract, cross-host fallback rules,
   recursion guard, caller return-control, and output contract.
4. Use only the invocation syntax authorized by the active Claude Code host. If
   a platform capability is unavailable, keep the same panel boundary inline and
   record the fallback reason when the core skill requires it.

Do not apply another platform's invocation syntax.
