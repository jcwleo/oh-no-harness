# TODO: Ralplan Reduction — Two Regression-Coverage Gaps

- Status: **CLOSED** — delivered by `14e833e` on local `main` (not pushed, not
  released) as that run's AC-1. All four anchors below, including the two in
  "Related gap", are now in `REQUIRED["ralplan"]` as `BOTH`-scoped entries:
  `not to the plan body`, ``recorded as `single-reviewer` ``,
  `paired topology valid`, `with no further review`. Retained as the historical
  record of what the gaps were and how they were found.
- Platform: platform-neutral (both reachability platforms).
- Backlog: `backlog/`
- Origin: found by the diversity-leg reviewer during the 2026-07-28/29 ralplan Opus 5
  reduction run, and independently reproduced by the caller before being deferred.
  Both are **durability gaps, not delivery gaps** — the shipped behavior is correct;
  what is missing is a gate that notices if someone later removes it.

## Why deferred rather than fixed in that run

Each fix is one additive `BOTH`-scoped anchor in `check-skill-reachability.py`
`REQUIRED["ralplan"]`. Additive-only, removes no assertion — but it moves the
reachability counts off **codex 234 / claude 281**, and 234/281 is the number AC-1's
proving evidence is recorded against in that run's ledger. Changing it retroactively
would invalidate a recorded proof for no delivery benefit. The user chose to record
these instead.

**Correction (2026-07-29):** this section originally predicted the new counts as
`236/283`. That figure counted only the two anchors under `## N-1` / `## N-2` and
omitted the two from "Related gap" below. The measured post-delivery board is
**codex 240 / claude 287** — four anchors, and the ralplan-scoped anchors were not
the only additions in `14e833e`. Use 240/287; `236/283` is superseded.

## N-1 — AC-2 has no regression coverage at all

AC-2 moved the finding→fix mapping RECORD out of the plan body into the snapshot
ledger and Plan Approval Brief, keeping the accepted CHANGE in the body.

**Reproduced**: reverting AC-2 completely at the source — putting the four-part record
instruction back into `## Planner Revision Contract` and dropping `applied change` from
the ledger's field list — and regenerating leaves **all four gates green**
(validator ok, reachability 234/281, 86 rejected mutations).

AC-2 retired no pin, so nothing was deleted; the gap is that it added none either. A
side effect worth recording: this falsifies that run's plan at T5.2, which claimed AC-1
was "the one AC whose success and total omission are indistinguishable under the gate."
AC-2 is in the same category and, absent this fix, stays there.

Smallest correction: one additive `BOTH` anchor on a distinctive fragment of the
relocation sentence — e.g. `not to the plan body` — following exactly the pattern AC-1
already uses.

**Delivered** in `14e833e` exactly as proposed: `("not to the plan body", BOTH)`.

## N-2 — the `single-reviewer` token is pinned nowhere

AC-3 made STANDARD dispatch one required Plan-Reviewer **recorded as
`single-reviewer`**, and T6's Codex lane repair keys on that token *literally*:
`test-codex-plugin.sh:4053` tests `"single-reviewer" in parent_review_lower`.

**Reproduced**: removing the token from both `docs/skill-core/ralplan.md` and
`docs/platforms/codex-ralplan.md` and regenerating leaves **all four gates green** —
silently restoring the exact fail-closed-against-correct-behavior bug T6 exists to fix.

The existing reachability entry `("`single-reviewer` for a STANDARD debugger", CODEX)`
belongs to systematic-debugging, not ralplan, so it does not cover this.

Smallest correction: one additive ralplan anchor on the token in its ralplan context.

**Delivered** in `14e833e`: ``("recorded as `single-reviewer`", BOTH)``, scoped to
ralplan and distinct from the pre-existing systematic-debugging entry.

## Related gap from the same review, same category

The independent verifier flagged two AC-4 sub-changes as **unguarded by any gate**:
`paired topology valid` (now topology-conditional) appears only in the two adapter
docs and in no script, and the deleted R6 duplicate was likewise unpinned. Both
behaviors are correct as shipped; nothing prevents a future reduction pass from
deleting either outright with a green board. Worth folding into the same pass, since
the fix shape is identical.

**Delivered** in `14e833e`, both halves: `("paired topology valid", BOTH)` and
`("with no further review", BOTH)`.

## Sequencing note

Do all of these in one pass, and re-record the reachability baseline once at the end
rather than per-anchor. Anyone touching `REQUIRED["ralplan"]` should also know the
LIGHT obligation union in `ralplan.md` sits at **exactly 11/11 with zero slack** by
design — unrelated to these anchors, but the adjacent trap in the same file.

Followed as written: all four anchors landed in one pass and the baseline was
re-recorded once, at **codex 240 / claude 287**.

## Successor item

The same review round that closed this item surfaced four fresh durability gaps of
exactly this category, recorded in
[Pin-depth gaps](./pin-depth-gaps-20260729.md). This file stays closed; that one
carries the follow-up.
