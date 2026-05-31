---
name: ai-slop-cleaner
description: Use when AI-generated code, generated tests, or assistant-written diffs need behavior-preserving cleanup after implementation approval, before review, or before final delivery.
argument-hint: "<files, paths, or changed-file scope>"
---

# AI Slop Cleaner

This skill removes AI-generated code slop without changing behavior.

It is a skill, not an agent. In Oh No Harness, `ralph` lists it as the next skill to use after reviewer approval and before final verification. Users may also use it directly.

## Software Development Stage

AI Slop Cleaner is the post-implementation cleanup stage.

Use it after behavior is locked and functional review has passed. It should improve clarity and remove AI residue without changing behavior, adding scope, or replacing implementation review.

## Agent Roles

This skill has no required agent dependency. If a cleanup change needs independent evidence, return that need to the caller so `verifier` or `code-reviewer` can review the result after the cleanup pass.

## When To Use

Use for code that works but shows signs of AI-generated residue:

- over-explained comments
- duplicate helpers
- defensive branches that cannot happen
- generic naming
- unnecessary wrappers
- speculative abstractions or configuration options not required by current
  behavior
- broad try/catch blocks that hide errors
- stale comments
- test code that asserts implementation details rather than behavior
- inconsistent style compared with nearby code

Do not use when the requested change is functional behavior, a broad refactor, or a rewrite without a behavior lock.

## Required Behavior Lock

Before editing, establish one of:

- passing tests that cover the changed surface
- a focused verification command
- a manual acceptance checklist
- a clear before/after behavior description when no command exists

If no behavior lock exists, create a verification plan first and state the risk.

## Scope

When called by `ralph`, limit cleanup to files changed in the current Ralph session.

When called directly, limit cleanup to the target files or paths named by the user.

Do not expand scope because nearby code looks messy.

## Cleanup Order

1. Identify behavior lock and target files.
2. Classify slop smells by file.
3. Delete unnecessary code before renaming or reshaping.
4. Merge duplicated helpers only when call sites stay clear.
5. Simplify branching only when behavior remains equivalent.
6. Remove stale comments and replace only comments that explain non-obvious constraints.
7. Run the behavior lock again.
8. Report changed files, removed slop classes, commands run, and residual risk.

## Smell Catalog

| Smell | Cleanup |
|---|---|
| Redundant comments | Delete comments that restate code. Keep comments that explain constraints. |
| One-use wrappers | Inline unless the wrapper names a real concept. |
| Duplicate helpers | Consolidate only when signatures and semantics truly match. |
| Generic names | Rename to domain terms already used nearby. |
| Speculative abstraction | Inline or remove abstractions, configuration, or generalization that current behavior does not need. |
| Speculative branches | Delete unreachable branches when the invariant is already enforced. |
| Catch-all handling | Narrow or remove if it hides actionable failures. |
| Test overfitting | Prefer behavior assertions over implementation detail assertions. |

## Output

Return:

- Behavior lock used.
- Files changed.
- Slop categories removed.
- Verification commands and results.
- Any skipped cleanup and why.

## Next Skill Handoff

None — this is a post-implementation mid-loop skill. Return control to the caller (`ralph` or direct invocation). If the cleanup pass changed structure, tests, or control flow, recommend `code-reviewer` or `verifier` to the caller; do not invoke them yourself.
