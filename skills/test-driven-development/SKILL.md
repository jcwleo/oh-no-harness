---
name: test-driven-development
description: Use when implementing a feature, bugfix, behavior change, regression fix, or behavior-preserving refactor before editing production code or changing observable behavior.
argument-hint: "<feature, bugfix, refactor, or behavior change>"
---

# Test Driven Development

Write the test first. Watch it fail. Write the smallest production change that makes it pass. Refactor only after green.

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

## Iron Law

No behavior-changing production code without a failing test first.

If production behavior was changed before a failing test existed, do not treat later tests as TDD evidence. Either restart the behavior change from a failing test or document explicit user approval to continue without TDD.

## Required Cycle

For each behavior:

1. RED: write one minimal test that states the desired behavior.
2. Verify RED: run the test and confirm it fails for the expected reason.
3. GREEN: write the smallest production change that can pass that test.
4. Verify GREEN: run the test and confirm it passes.
5. REFACTOR: clean names, duplication, and structure only after green.
6. Verify GREEN again: rerun the relevant check after refactor.
7. Repeat for the next behavior.

Do not batch several behaviors into one RED step. If the test name needs "and", split the test.

## RED Requirements

A valid RED test:

- tests real behavior, not implementation details
- has a clear behavior-focused name
- fails because the behavior is missing or wrong
- does not fail because of typos, broken imports, invalid setup, or missing fixtures
- uses mocks only when real dependencies are impractical

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

When this skill is used from `ralph`, record TDD evidence in:

```text
.oh-no/sessions/{sessionId}/verification.md
```

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
