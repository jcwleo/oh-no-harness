# Test-first

The harness defaults to test-first for behavior changes, bug fixes, and
refactors. The point is not dogma; the point is that *failing first*
proves the test exercises the change.

## When test-first applies

- Behavior change in production code (new feature, behavior tweak,
  contract change).
- Bug fix where the bug is reproducible.
- Refactor whose goal is "no behavior change" — existing tests must
  cover the surface, or new tests must land before the refactor
  touches the implementation.

## When alternate verification is acceptable

Test-first is not always achievable. Acceptable substitutes, in
preference order:

1. Type checks for purely typeshape changes.
2. Build/lint/static analysis when the change has no runtime path.
3. Integration smoke runs that exercise the changed flow end-to-end.
4. Recorded manual reproduction with command output.
5. Explicitly documented evidence gap, with the reason and the
   compensating risk in the plan and verify report.

The plan must record which substitute is used and why. `verify` reads
that record and reconciles. Substitutes are not failures; an
unrecorded substitute is.

## The failing-first check

Before claiming GREEN:

- The failing test (or RED command) must have been observed failing
  for the targeted reason. A test that was added but never observed
  failing is a partial regression proof, not a full one.
- The minimum reproduction lives next to the test, not in chat
  scrollback or the agent's memory.

If RED was never observed, mark the regression proof PARTIAL in the
verify report with a one-line reason. Do not retroactively rewrite
the test until it "would have" failed.

## Anti-patterns

- Production code first, then a test that always passes (mark this as
  a regression-proof gap, not as RED → GREEN).
- Tests-after-implementation written from the diff. They can anchor
  behavior but they are not regression proof unless the prior failure
  was reproduced first.
- `pytest.skip` / `xfail` / commented-out assertions used to "fix" a
  flaky test instead of tracing the underlying race.

## Cross-references

- `docs/oh-no/techniques/regression-proof.md` for the RED/GREEN
  evidence contract that test-first feeds.
- `docs/oh-no/techniques/testing-anti-patterns.md` for the patterns
  `code-reviewer` flags during review.
