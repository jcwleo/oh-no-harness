# Defense in depth

After a root-cause fix, additional guards may be appropriate. The
rule: guards must not hide the cause, and they must not become the
only defense.

## When to add a guard

- The same class of bug could occur in adjacent code paths.
- The cause is partially external (third-party API, race, hardware)
  and a typed failure improves recoverability.
- A regression test exists at the unit level and a higher-level
  invariant check would catch the same class of bug under different
  inputs.

## When NOT to add a guard

- Instead of fixing the root cause. A blanket `try/except` around the
  buggy call "to be safe" is suppression, not defense in depth.
- To paper over a violated invariant. Fix the invariant; do not log
  and continue.
- To absorb authorization/auth/secrets failures. Those must surface,
  not be swallowed. See
  `tests/acceptance/scenarios/08-planted-bug-swallowed-exception.md`.

## Layering

Defense layers should be independent:

1. The primary fix at the root cause.
2. A narrow assertion or contract check at the call boundary.
3. A higher-level invariant check (balance reconciliation,
   state-machine sanity, schema validation).

Each layer should fail loudly. If layer 2 silently masks layer 1, the
guard is suppression, not defense.

## How the harness responds

- `debug` records each guard added beyond the root-cause fix and
  why.
- `code-reviewer` evaluates guards under the same severity taxonomy
  as the primary fix.
- `verify` checks that the root-cause fix has its own RED/GREEN
  evidence; a guard that prevents the symptom is not a substitute.

## Cross-references

- `docs/oh-no/techniques/root-cause-tracing.md` — the cause-pinning
  contract that defense-in-depth complements, not replaces.
- `docs/oh-no/techniques/regression-proof.md` — the evidence
  required for the root-cause fix itself.
