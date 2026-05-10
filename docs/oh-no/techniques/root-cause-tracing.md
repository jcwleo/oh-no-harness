# Root-cause tracing

Bug fixes default to root-cause fixes. The rules below feed `debug`'s
four-phase process and `code-reviewer`'s root-cause discipline check.

## Symptom vs. cause

- **Symptom** — what the user or test sees: assertion failure, 500
  response, wrong number, NPE.
- **Cause** — the rule, contract, state, or invariant that was
  violated to produce the symptom.

A symptom can have many causes. A fix that addresses one cause does
not necessarily fix the bug; if the symptom can recur via a different
cause, the cause has not been pinned.

## Shortest reproduction first

Before forming hypotheses, build the smallest input/command that
reliably produces the symptom. If the reproduction is
non-deterministic, record the steady-state vs. failure-state delta
(concurrency level, input shape, environment, build hash, time of
day).

Do not attempt a fix until at least the *symptom* is reproducible on
demand. A fix on an unreproducible bug is a guess.

## Evidence ladder

Climb in order; do not skip rungs:

1. The failing command's exit code and last 50 lines of output.
2. The failing test's assertion message, file:line, and the relevant
   value diff.
3. The narrowest log/trace that covers the failing call.
4. Targeted instrumentation when 1–3 are insufficient. See
   `docs/oh-no/techniques/diagnostic-logging.md`.
5. Reading the implementation under test and any callers that build
   the failing input.

## Hypothesis table

Maintain at least three plausible causes before fixing. For each:

| Hypothesis | Mechanism that produces the symptom | Disproof check | Result |
| --- | --- | --- | --- |

Only skip to fix after one cause is confirmed and the others are
eliminated. A fix on a single un-eliminated hypothesis is a guess.

## Eliminate, don't just confirm

If you cannot run a check that would *disprove* a hypothesis, treat
the hypothesis as "open" and continue tracing. Confirmation bias
reads "the symptom went away" as proof of cause; in fact, the symptom
may have moved.

## Cross-references

- `skills/debug/SKILL.md` — the four-phase process this technique
  feeds.
- `docs/oh-no/techniques/regression-proof.md` — the RED/GREEN
  evidence that confirms the cause is pinned.
- `docs/oh-no/techniques/defense-in-depth.md` — when to add guards
  beyond the root-cause fix without hiding it.
