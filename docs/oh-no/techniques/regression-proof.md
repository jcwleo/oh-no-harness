# Regression proof

A bug fix is incomplete without proof that the bug is fixed. The
canonical proof is:

1. **RED** — a check fails for the bug's exact symptom on the unfixed
   code.
2. **GREEN** — the same check passes on the fixed code, with no other
   simultaneous changes that could be the real cause.

Anything weaker is an evidence gap. Record the gap; do not rebrand it.

## What counts as a regression proof

- A failing test that exercises the original input/path and was
  observed RED before the fix.
- A failing assertion or contract check on the unfixed code path.
- A reproducer script with deterministic input that produced the
  symptom.

A passing test alone is **not** a regression proof. A green CI run on
the fix branch is not a regression proof unless the same suite was
RED on the unfixed parent commit.

## The minimum-evidence record

Capture in the verify report:

- The failing command and its RED output (file:line, stack, assertion
  diff, exit code).
- The fixed command and its GREEN output.
- The commit boundary or revert/apply pair that produced the
  RED → GREEN transition.

If RED-state cannot be reproduced (heisenbug, environmental flake,
external dependency removed), record it as an evidence gap and
recommend a hardening follow-up rather than claiming GREEN.

## Acceptable substitutes

- Migration safety: forward + rollback test rather than RED/GREEN.
- Distributed/race conditions: a contract or invariant check rather
  than a deterministic reproducer.
- External integrations: a recorded mock interaction or a contract
  test rather than a live reproduction.

Each substitute is named in the plan and re-stated in the verify
report. Substituted regression proofs land as PARTIAL by default; only
upgrade to VERIFIED with a written reason.

## Cross-references

- `docs/oh-no/techniques/test-first.md` — when the failing test
  exists *before* the fix, this contract is satisfied by construction.
- `skills/verify/SKILL.md` — the verify report's evidence hierarchy.
