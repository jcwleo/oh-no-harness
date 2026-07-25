---
name: test-driven-development
description: Use when the user explicitly requests TDD, test-first, or RED-GREEN-REFACTOR, or an already-selected workflow enters its internal TDD gate; ordinary implementation remains Ralph.
argument-hint: "<explicit TDD/test-first change>"
---

# Test Driven Development

Write the test first. Watch it fail. Write the smallest production change that makes it pass. Refactor only after green.

## Software Development Stage

Test Driven Development is the internal mid-loop discipline for behavior-change work inside implementation and bug-fix execution.

Use it inside `ralph`, `systematic-debugging`, or `ultrawork` before changing production behavior. It is not a requirements, planning, cleanup, or final-verification substitute.

## Top-Level Routing Boundary

Do not use this skill as the top-level route for ordinary implementation
requests such as "add this feature", "fix this bug", "refactor this module",
or "implement this behavior". This is not a top-level implementation skill.
Use `ralph` for those concrete implementation requests so execution mode,
worktree isolation, review, cleanup, verification, and final reporting stay
attached to the work.

Use this skill as a top-level entry only when:

- the user explicitly asked for TDD, test-first, RED/GREEN/REFACTOR, or
  "write the failing test first"
- an already-selected workflow (`ralph`, `systematic-debugging`, or
  `ultrawork`) reaches its internal TDD gate

Direct-edit-eligible mutations are inert and never reach this skill;
other small concrete edits route through `ralph`, which may apply its STANDARD
small-task carve-out; there is no
separate direct edit path that reaches this skill outside a workflow or an
explicit user TDD request.

After the cycle completes, return control to `ralph`, `systematic-debugging`,
or `ultrawork`. Do not continue as a substitute for `ralph`.

## When To Use

Use before editing production code for:

- new features
- bug fixes
- behavior changes
- refactors that should preserve behavior

Exceptions require explicit user approval or a documented reason:

- docs-only changes
- config-only changes
- generated code
- throwaway prototypes
- no practical test harness exists yet

If a test harness is missing, write a verification plan before changing behavior.
A missing practical harness permits a documented TDD exception plus existing
real-surface, bounded manual, or residual-risk evidence; it does not authorize
new durable test infrastructure or production seams unless the user separately
approves that scope.

## Iron Law

No behavior-changing production code without a failing test first.

If production behavior was changed before a failing test existed, do not treat later tests as TDD evidence. Either restart the behavior change from a failing test or document explicit user approval to continue without TDD.

## Execution Ownership

Inside a dispatch-capable caller, assign one stable `Executor assignment ID`
to each observable behavior and keep its repository work-product writes across
RED, GREEN, and REFACTOR. Continue the same executor session when the host
supports it; a transport rebind may use one call per assigned mutation step
but must preserve and echo that assignment ID while each Packet ID remains
unique. Do not split one behavior's RED and GREEN writes across assignments.

The caller remains the orchestrator: it observes and records RED/GREEN results,
updates `.oh-no` evidence, validates the executor envelope, and decides every
gate. `Mutation status: complete` is not TDD or AC acceptance. Inline writes
are only a recorded LIGHT-tiny or dispatch-unavailable fallback inherited from
the caller's execution policy.

## Required Cycle

For each behavior:

For this cycle, one behavior means one observable contract change from the
approved Direction Contract, not each internal branch, helper, or condition.
Coupled internal conditions that serve one observable outcome may share one
minimal RED; independent user-visible outcomes remain separate cycles.

1. RED: the assigned executor writes one minimal test that states the desired
   behavior.
2. Verify RED: the caller runs the test and confirms it fails for the expected
   reason.
3. GREEN: the same executor writes the smallest production change that can
   pass that test.
4. Verify GREEN: the caller runs the test and confirms it passes.
5. REFACTOR: the same executor cleans names, duplication, and structure only
   after green.
6. Verify GREEN again: the caller reruns the relevant check after refactor.
7. Repeat for the next behavior.

Do not batch independent observable behaviors into one RED step. If the test
name joins independent user-visible outcomes with "and", split the test; do not
split solely because one outcome depends on coupled internal conditions.

## Proportional Test Boundary

One minimal RED/GREEN case per changed behavior is the default. Add negative,
boundary, semantic-model, concurrency, resume, adversarial, or baseline cases
only when an AC ID, named safety/risk trigger, adjacent regression surface, or
safety invariant requires them. A reviewer may identify a verification hole; it
may not demand an exhaustive matrix merely because stronger proof is imaginable.

If no approved admission source exists, record the proposed extra case as `not
relevant` with the reason and do not implement it.

Tests remain evidence under the AC-bearing product story. Do not turn test
infrastructure into a separate product story unless the user requested it as an
outcome. Do not build a product-like state machine, scheduler, protocol
simulator, Git oracle, duplicate parser, fixture factory, or full runtime model
solely to verify the implementation. When the smallest credible test would need
that machinery, prefer an existing real-surface lane or record a bounded manual
or residual-risk check.

## RED Requirements

A valid RED test:

- tests real behavior, not implementation details
- has a clear behavior-focused name
- fails because the behavior is missing or wrong
- does not fail because of typos, broken imports, invalid setup, or missing fixtures
- uses mocks only when real dependencies are impractical
- is not tautological: a test that only asserts a mock was called, pins a
  constant, or cannot fail under any plausible regression is self-confirming, not
  RED evidence

If the test passes immediately, it is not RED. Change the test or choose a behavior that is not already covered.

If the test errors before reaching the behavior, fix the test setup and rerun until it fails for the expected reason.

## GREEN Requirements

GREEN means:

- the new test passes
- the relevant existing checks still pass
- the implementation is the smallest reasonable change
- no unrelated refactor or extra feature was added

If another check fails, fix it before moving on.

## Refactor Rule

Refactor only after GREEN.

Allowed refactors:

- remove duplication
- improve names
- extract helpers
- align with nearby patterns

Not allowed during refactor:

- new behavior
- new scope
- unrelated cleanup
- speculative abstraction

After refactoring, rerun the relevant GREEN check.

## Bug Fix Integration

For a bug fix, first write a test that reproduces the bug.

The RED evidence must show the original symptom or a minimal equivalent. A fix without a reproduction test is not TDD unless the user explicitly approves the exception.

## Refactor Integration

For behavior-preserving refactors, first add or identify characterization tests that lock the existing behavior.

Run those tests before refactoring, then rerun them after each meaningful refactor step.

## Evidence To Record

When this skill is used from a session-scoped workflow (`ralph`, `ultrawork`, or
`systematic-debugging` operating in a session), record TDD evidence in:

```text
.oh-no/sessions/{sessionId}/verification.md
```

When invoked top-level with no session (an explicit user TDD request), record
the same RED/GREEN/REFACTOR evidence inline in the final report or completion
claim instead.

Record:

- story id
- test file and test name
- RED command and expected failure summary
- GREEN command and pass summary
- post-refactor command and pass summary
- any approved exception and reason

## Common Rationalizations

| Rationalization | Response |
|---|---|
| "I will test after." | Tests after code do not prove the test would have caught the missing behavior. |
| "This is too small." | Small behavior still needs a guard if it can regress. |
| "Manual testing is faster." | Manual checks are not repeatable evidence. |
| "The existing code has no tests." | Add the smallest useful test around the changed surface. |
| "The test is hard to write." | Hard to test often means unclear interface or excess coupling. Simplify the design or ask for help. |
| "I already wrote the code." | Later tests are not RED evidence. Restart or document explicit user approval. |

## Completion Checklist

Before claiming the behavior is complete:

- RED was observed for each new or changed behavior.
- Each RED failure matched the expected missing behavior.
- GREEN was observed after the minimal implementation.
- Refactor happened only after GREEN.
- Relevant checks were rerun after refactor.
- Exceptions were explicitly approved or documented.

## Next Skill Handoff

None — this is an internal mid-loop discipline. Return control to the caller skill (`ralph`, `systematic-debugging`, or `ultrawork`) once the cycle is complete or an exception is recorded. Do not continue as a substitute for `ralph`.
