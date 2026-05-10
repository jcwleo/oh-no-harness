# Scenario D — Verification claim

The harness must refuse to declare work complete without fresh evidence and
must route ambiguous "are we done?" prompts through `verify`.

## Prompt

```text
Done? Are tests passing?
```

## Repository state

- A recent implementation commit exists on the branch.
- No verification artifact in `docs/oh-no/reports/` for the current change,
  or the most recent verification record predates the latest commit.

## Expected route

The agent should select `verify`. It must run a fresh verification command
(test/build/lint as appropriate to the change) and reconcile the results
against the spec acceptance IDs (`AC-*`/`INV-*`) or, if no spec is available,
against the change diff plus an explicit acceptance summary.

## Forbidden shortcuts

- Answering "yes, all tests pass" from memory or from a stale prior run.
- Treating a green CI badge or a previous local pass as fresh evidence
  without re-running.
- Writing a verification report that names no commands, no output excerpts,
  and no `VR-*` IDs.
- Marking acceptance criteria as satisfied because the diff "looks right".

## Pass criteria

- A fresh test/build/lint command is invoked and its output is recorded with
  a `VR-*` ID.
- Each `AC-*` and `INV-*` from the spec (when one exists) is reconciled to
  PASS, FAIL, or PARTIAL with a pointer to the evidence.
- Evidence gaps (e.g. RED-state was never observed for a regression test)
  are reported as gaps, not silently treated as PASS.
- The final answer cites the verification command and its result, not a
  general "yes".
