---
name: simplify
description: Review changed code for reuse, simplification, efficiency, and altitude cleanups, then apply behavior-preserving fixes after implementation approval.
argument-hint: "[<target>]"
---

# Simplify

Simplify is the post-implementation quality cleanup stage. It reviews changed
code for reuse, simplification, efficiency, and altitude issues, then applies
behavior-preserving fixes.

It is a skill, not an agent. In Oh No Harness, `ralph` uses it after the
selected mode's required review is satisfied and before final verification. On
Claude Code, Ralph must use Claude Code's built-in `simplify` skill when
available. On Codex, Oh No Harness provides this `simplify` skill so the same
cleanup gate exists.

This is quality cleanup, not bug hunting. Use `code-reviewer` or the host's
code-review workflow for correctness bugs.

## Software Development Stage

Simplify is the post-implementation cleanup stage.

Use it after behavior is locked and the review required by the caller has passed
or has been recorded as not needed. It should improve reuse, clarity,
maintainability, and efficiency without changing behavior, adding scope, or
replacing implementation review.

## Agent Roles

This skill requires four cleanup role passes. Always launch the Reuse,
Simplification, Efficiency, and Altitude review passes as independent
subagents in parallel through the active platform's approved subagent or task
mechanism when dispatch is available. Do not collapse this into a single
undifferentiated review; the separated viewpoints are part of the skill's value.
On Codex, the `CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION` SessionStart
context is the standing explicit user request for this cleanup delegation; do
not ask another approval question merely to launch these four subagents.
On Codex, these cleanup roles use exact registered custom-agent types rather
than the generic `oh-no-<role>` pattern:

| Cleanup angle | Codex `agent_type` |
|---|---|
| Reuse | `oh-no-cleanup-reuse` |
| Simplification | `oh-no-cleanup-simplification` |
| Efficiency | `oh-no-cleanup-efficiency` |
| Altitude | `oh-no-cleanup-altitude` |

Each Codex cleanup dispatch must call `spawn_agent` with the matching
`agent_type` above and must include `Codex agent type: <agent_type>` in the
worker message. The worker-message line is only an audit marker; it does not
replace the actual `agent_type` argument on the `spawn_agent` tool call. Do not
satisfy this requirement with a generic/default worker, prompt-embedded role
instructions, or an untyped cleanup worker while the registered custom agent is
accepted by the host.
If the active host cannot dispatch subagents, preserve the same four role
boundaries as separate inline fallback blocks and record the dispatch-unavailable
reason before continuing. If a cleanup change needs additional independent
evidence after the fixes, return that need to the caller so `verifier` or
`code-reviewer` can review the result after the cleanup pass.

## When To Use

Use for changed code that works but needs a quality pass before delivery:

- new code re-implements helpers the codebase already has
- logic can be simplified without changing behavior
- independent work is run sequentially or redundant work is repeated
- startup, hot paths, or tests do unnecessary I/O or computation
- fixes sit at the wrong altitude, such as fragile special cases on top of
  shared infrastructure
- Speculative abstraction, configuration, or generalization is not required by
  the current behavior
- comments, wrappers, or test details obscure the intended behavior

Do not use when the requested change is functional behavior, a broad refactor, or a rewrite without a behavior lock.

## Required Behavior Lock

Before editing, establish one of:

- passing tests that cover the changed surface
- a focused verification command
- a manual acceptance checklist
- a clear before/after behavior description when no command exists

If no behavior lock exists, create a verification plan first and state the risk.

## Maintainability Debt Boundary

Simplify may fix behavior-preserving cleanup inside the reviewed diff, but it
must not hide correctness, scope, security, or architecture concerns inside a
cleanup pass. When a finding points to maintainability debt that cannot be fixed
without changing behavior, widening scope, changing public contracts, or
touching sensitive behavior, record it as deferred reviewer work instead of
patching around it.

Classify every nontrivial finding as:

```text
Maintainability finding:
- Type: behavior-preserving cleanup | reviewer follow-up | out-of-scope
- Evidence:
- Cost if ignored:
- Safe cleanup action:
- Reviewer needed: none | code-reviewer | security-reviewer | architect | verifier
```

Use `reviewer follow-up` for brittle coupling, unclear ownership, hidden state,
cross-boundary special cases, fragile tests, risky generated changes, or cleanup
that would require a behavior decision.

## Scope

When called by `ralph`, limit cleanup to files changed in the current Ralph session.

When called directly, limit cleanup to the target files or paths named by the user.

Do not expand scope because nearby code looks messy.

If a PR number, branch name, or file path was passed as an argument, review that
target instead of the default diff.

## Phase 0 - Gather The Diff

Run `git diff @{upstream}...HEAD` to get the unified diff under review. If
there is no upstream, use the smallest credible fallback such as
`git diff main...HEAD`, `git diff master...HEAD`, or `git diff HEAD~1`.

If there are uncommitted changes, or the range diff is empty, also run
`git diff HEAD` and include working-tree changes in scope. Treat this diff as
the review scope.

## Phase 1 - Review

Launch four independent cleanup subagents in parallel, in one batch before
waiting for any result. Pass each subagent the review diff and assign exactly
one angle: Reuse, Simplification, Efficiency, or Altitude. Use the active
platform's approved mechanism, such as Claude Code's Task tool or Codex
subagent dispatch when available. For Codex, SessionStart standing authorization
means this skill may use sub-agents, delegation, and parallel agent work
proactively for these cleanup roles without per-run approval. Use the registered
custom agents `oh-no-cleanup-reuse`, `oh-no-cleanup-simplification`,
`oh-no-cleanup-efficiency`, and `oh-no-cleanup-altitude` when the Codex host
recognizes them. This means each Codex `spawn_agent` call sets the exact
matching `agent_type` and includes a `Codex agent type: ...` line in the worker
message. A message marker without the matching tool `agent_type` is still a
generic/default worker and is not an acceptable Codex cleanup dispatch. The
caller owns lifecycle: after each cleanup subagent result is captured, close or
clean up the completed subagent using the active platform mechanism.

Do not degrade these four review angles into one generic inline pass. If
subagent dispatch is unavailable, run Reuse, Simplification, Efficiency, and
Altitude as four separate inline fallback blocks with the same assigned scope,
expected output, and fallback reason.

Each pass returns findings with `file`, `line`, a one-line `summary`, and the
concrete cost: what is duplicated, wasted, fragile, or harder to maintain.
Each pass must also classify whether the finding is behavior-preserving cleanup,
reviewer follow-up, or out-of-scope under the `Maintainability Debt Boundary`.

### Reuse

Flag new code that re-implements something the codebase already has. Search
shared utilities and files adjacent to the change, and name the existing helper
or local pattern to use instead.

### Simplification

Flag unnecessary complexity the diff adds: redundant or derivable state,
copy-paste with slight variation, deep nesting, dead code left behind, or
Speculative abstraction. Name the simpler behavior-preserving form.

### Efficiency

Flag wasted work the diff introduces: redundant computation or repeated I/O,
independent operations run sequentially, or blocking work added to startup,
tests, or hot paths. Name the cheaper behavior-preserving alternative.

### Altitude

Check that each change is implemented at the right depth, not as a fragile
bandaid. Special cases layered on shared infrastructure are a sign the fix is
not deep enough. Prefer generalizing the underlying mechanism over adding
special cases, but skip anything that would change intended behavior or exceed
the reviewed scope.

## Phase 2 - Apply The Fixes

Wait for all four cleanup subagents to complete. Capture every result, close or
clean up each completed cleanup subagent, deduplicate findings that point at the
same line or mechanism, then fix each remaining behavior-preserving cleanup
directly.

Skip any finding whose fix would change intended behavior, require changes well
outside the reviewed diff, or that is a false positive. Note the skip rather
than debating it.

Run the behavior lock again after cleanup. If cleanup changed structure, tests,
or control flow, return that need to the caller so `code-reviewer` or
`verifier` can inspect the result.

## Output

Return:

- Behavior lock used.
- Files changed.
- Review angles run.
- Cleanup findings fixed.
- Reviewer follow-up findings and owner.
- Findings skipped and why.
- Verification commands and results.
- Residual risk.

## Next Skill Handoff

None - this is a post-implementation mid-loop skill. Return control to the caller (`ralph` or direct invocation). If the cleanup pass changed structure, tests, or control flow, recommend `code-reviewer` or `verifier` to the caller; do not invoke them yourself.
