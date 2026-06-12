---
name: ultrawork
description: Use when the user asks for autonomous or end-to-end delivery of a broad goal, feature, fix, project task, or vague request that may span interview, planning, execution, QA, cleanup, and validation.
argument-hint: "<goal, spec path, plan path, or broad delivery request>"
---

# Ultrawork for Codex

This is the Codex-facing public skill wrapper.

Follow this order:

1. Read and follow `../../docs/skill-core/ultrawork.md`.
2. Apply Codex platform rules from `../../docs/platforms/codex.md`.
3. Preserve the core skill's artifact paths, approval gates, role boundaries,
   worktree rules, TDD rules, verification rules, and output contract.
4. Use only the invocation syntax authorized by the active Codex host. If a
   platform capability is unavailable, keep the core role boundary inline and
   record the fallback reason when the core skill requires it.
5. When the Codex SessionStart context includes the Oh No Harness standing
   subagent authorization, treat it as the explicit user request for eligible
   Ultrawork phase roles including `explore`, `planner`, `verifier`, QA, and
   review roles. Do not ask for additional per-run subagent approval.

Do not apply another platform's invocation syntax.
