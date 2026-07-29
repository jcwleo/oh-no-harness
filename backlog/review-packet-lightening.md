# TODO: Review Packet Lightening (plan review and code review)

- Status: **OPEN — partially delivered** by `14e833e` on local `main` (not pushed,
  not released). Two of the three measured harness-side contributors are addressed;
  the negative-path rule-out obligation remains open. See
  [Delivery status](#delivery-status).
- Platform: platform-neutral (skill cores + role cores), with adapter overlays
  touched only where the packet composition rules live per host.
- Backlog: `backlog/`
- Origin: measured during the 2026-07-28 ralplan reduction run. A plan-review leg
  ran **54 minutes / 118 tool calls** on a review of a *plan document* — no code,
  no tests. The caller-written packet, not the harness, was the dominant cost
  driver in that instance; the harness contributes the rest by mandating packet
  content that duplicates the role core.

## Diagnosis

The user's framing, which is the sharpest statement of the problem:

> 리뷰의 목적은 우리가 작성한 리뷰가 원하는 요구사항을 잘 반영한 구현 계획에 대한
> 것인데 조금 벗어난 리뷰까지 다 반영해버리거나 찾게되면 오래걸리는 것 같아.

That is, a review packet that enumerates investigation avenues converts a bounded
question ("does this plan satisfy the stated requirements?") into an unbounded
search. Every extra `Focus especially on …` item is read as a mandatory
investigation, and each investigation costs tool calls whether or not it yields a
finding.

This is the same failure the Opus 5 prompting guide describes for
over-verification: explicit step-by-step verification instructions cause the model
to verify more than the task needs. The fix is symmetric — specify the *outcome
and the boundary*, not the route.

## Approved removal principles

Confirmed with the user. Remove from review packets:

1. **Investigation-path instructions** — "check X, then grep Y, then confirm Z."
   The reviewer chooses its own route; the packet states what must hold.
2. **Content already in the role core** — anything `docs/agent-core/plan-reviewer.md`
   or `docs/agent-core/code-reviewer.md` already instructs. Repeating it in the
   packet costs context and adds no constraint.
3. **Full restatements of constraints** — the constraint set belongs in one place;
   the packet points at it rather than reproducing it.

**KEEP:** incident context. When a prior run failed a specific way (e.g. the
run-1 reviewers that wrote repository files despite a plain read-only
instruction), naming that incident in the packet demonstrably changed behavior in
the next run. That is a load-bearing packet element, not filler.

## Suspected harness-side contributors (to verify before editing)

Plan review — caller-caused weight dominates, so the harness fix is mostly about
*permitting* a lighter packet and capping enumerated focus items.

Code review — harness-caused weight is real and measurable:

- `docs/skill-core/ralph.md:505-521` demands a **15-field assignment delta** of the
  `code-reviewer`, including four executor-only fields (`Executor assignment ID`,
  `TDD responsibility`, `Worktree decision`, `Coordination`) that a reviewer
  cannot act on.
- `docs/skill-core/ralph.md:837-842` requires a **written rule-out reason per
  negative-path scenario even when no trigger fires** — a guaranteed-cost
  obligation with no corresponding signal.
- The LIGHT reviewer waiver is restated **5×** (`ralph.md` lines 214, 726, 736,
  761, 789), which is the AC-4 duplicate-instruction pattern in a different file.

> **Line references in this section are stale.** AC-3 and AC-4 of `14e833e` both
> edited `ralph.md`, shifting everything after roughly line 211. Treat 505-521,
> 837-842, and 214/726/736/761/789 as filing-time coordinates only, and re-locate
> by content before acting. They are deliberately not renumbered here — guessing
> new numbers would just re-stale them on the next `ralph.md` edit.

## Delivery status

**Addressed by `14e833e`:**

- The 15-field packet weight — addressed by AC-3, but **not** by cutting fields.
  A paragraph after the delta template now role-scopes five inert fields:
  `Executor assignment ID` and `TDD responsibility` bind the executor lane, and
  `Platform invocation`, `Lifecycle`, and `Coordination` are caller-side dispatch
  mechanics, all sent as `not applicable` with a one-clause reason in a
  `code-reviewer` packet. A `verifier` packet keeps `TDD responsibility` populated
  for behavior-changing work. `Worktree decision and location` stays populated for
  every role — it is the only field carrying the target tree. Anchored on
  `Delta fields are role-scoped`.
  Note this is a *different* fix shape than this item proposed: the field count is
  unchanged, the per-role obligation is what dropped.
- The LIGHT-waiver duplication — reduced by AC-4. The two zero-pin restatements
  were deleted, `no fix-manifest step` was carried forward into the surviving
  sentence and anchored. `rg -c waived docs/skill-core/ralph.md` went 6 -> 4.

**Still open, and deliberately excluded from that plan:**

- The negative-path rule-out obligation, which lives in the role core at
  `docs/agent-core/code-reviewer.md:53-58`: probe the applicable negative-path
  scenarios "when their triggers hold, **or rule each out with a one-line reason**
  naming why no AC ID, named risk, adjacent regression surface, safety invariant,
  or changed semantic model triggers it." That is the guaranteed-cost,
  no-corresponding-signal obligation this item was filed about, and it is
  untouched. Any fix here changes the role core, so it needs its own scope
  decision and baseline.

## Constraints carried from the reduction work

- Edit generation **sources** only; regenerate with both generator scripts from the
  repo root.
- Any validator expectation that changes must be **re-homed, never deleted**.
  Pinned-anchor loss is blocking.
- The obligation-count caps in `ralplan.md` are enforced as an **upper bound** via
  regex + dict equality (`validate-plugin-files.py:4519-4532`) with per-mode
  **set unions**, not row sums (`:4553`). Removing a LIGHT-active `;`-item changes
  a derived count and will trip a gate — check before cutting.
- `ralph.md` was explicitly a **non-goal** of the ralplan reduction plan. Touching
  it here is in scope for *this* item, but it is a fresh scope decision and needs
  its own baseline measurement first.

## Sequencing note

Do not merge this into the ralplan reduction run. It is a separate scope decision
by the user's own instruction, and `ralph.md` edits in particular would breach that
run's recorded rescope threshold.

Honoured: the `ralph.md` edits above landed in the *later* `14e833e` run, as its own
scoped ACs, not inside the ralplan reduction run. The remaining `code-reviewer.md`
change needs the same treatment — its own scope decision, not a fold-in.

One durability caveat carried out of `14e833e`: nothing prevents the duplication AC-4
removed from being re-added, because `ralph.md` has no obligation-count detector
analogous to `ralplan.md`'s audited caps. See
[Pin-depth gaps](./pin-depth-gaps-20260729.md), N-4.
