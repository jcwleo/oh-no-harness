# TODO: Pin-Depth Gaps from the 2026-07-29 Backlog Follow-Up Run

- Status: TODO
- Platform: platform-neutral (validator + reachability scripts; one Claude-branch
  placement concern).
- Backlog: `backlog/`
- Origin: found by the review round on `14e833e` (the run that closed
  [Ralplan reduction coverage gaps](./ralplan-reduction-coverage-gaps.md) and part of
  [Subagent dispatch model fidelity](./dispatch-model-fidelity.md)). All four were
  **reproduced by a subagent running an actual mutation probe**, not inferred from
  reading. **None is a defect in what shipped** — each is a place where a *future*
  edit would go unnoticed. Same category as the predecessor item: durability gaps,
  not delivery gaps.

## N-1 — Claude-only clause placement is ungated

`host_plan_boundary_problems` (`scripts/validate-plugin-files.py:4978-5025`) is
clause-*specific*, not general: it pins the `Host-plan boundary:` label and
`EnterPlanMode`, and forbids those two tokens from the bootstrap, the forced-routing
block, and the Codex-only blocks. It says nothing about Claude-only clauses as a
class.

**Reproduced**: moving the Model-fidelity rule verbatim out of the Claude
orchestration block and into the `OH_NO_BOOTSTRAP` block keeps **all four gates
green** — and leaks a Claude-only instruction into the Codex branch, since the
bootstrap is injected on both hosts.

The shipped placement is correct; the true Codex branch carries none of the
Claude-only markers. What is missing is anything that keeps it correct.

Smallest correction: add `"Model fidelity: every role dispatch"` to the token tuple
in the exclusion loop already present at `validate-plugin-files.py:5011-5020` — the
loop that walks bootstrap, forced-routing, and every `CODEX_ONLY_*` block. No new
mechanism, one string.

## N-2 — AC-5's paragraph is unguarded, and the stated reason for that was wrong

**Reproduced**: deleting AC-5's whole paragraph from
`docs/platforms/codex.md` leaves **all four gates green**.

The plan justified leaving it unguarded by claiming no enforcement mechanism was
possible. That is inaccurate. The accurate statement is narrower: `codex.md` composes
into no *wrapper*, so `check-skill-reachability.py` cannot see it — reachability is
the wrong tool. But a mechanism that reads that exact file already exists and already
fails closed today: `PLATFORM_RULE_DOC_MARKERS["codex.md"]`
(`scripts/validate-plugin-files.py:334`, enforced at 2280-2285).

Worth fixing the reasoning as well as the gap; "no mechanism is possible" is the kind
of claim that suppresses the next person's search.

Smallest correction: add one marker string to that tuple.

## N-3 — AC-3's anchor pins the topic sentence, not the carve-out

The reachability anchor added for AC-3 is `Delta fields are role-scoped`, which is the
paragraph's *first* sentence.

**Reproduced**: whole-paragraph deletion is caught, but an **in-place inversion is
not**. Rewriting the closing safety sentence so `Worktree decision and location`
becomes nullable for a `code-reviewer` packet leaves **all four gates green**, because
the anchored topic sentence is untouched.

That carve-out is load-bearing: `Worktree decision and location` is the only delta
field carrying the target tree, and nulling it is what produces either a blocked
review or — worse — a silent empty-diff approval evaluated against the main checkout
instead of the worktree.

Smallest correction: a second anchor on `is always populated for both`.

## N-4 — nothing prevents re-introducing the duplication AC-4 removed

**Reproduced**: re-adding the paragraph AC-4 deleted, verbatim, leaves **all four
gates green**.

`ralph.md` has no obligation-count detector analogous to the audited caps
`ralplan.md` has. The `rg -c waived docs/skill-core/ralph.md` = 4 check recorded as a
compensating control was a **one-time executor evidence step**, not a mechanism — it
runs only when someone chooses to run it, and nothing re-runs it.

This is the weakest of the four in the sense that re-introduced duplication is a cost
regression rather than a correctness one, but it is also the one most likely to
happen, since the deleted text reads as helpful.

Correction: a duplication or obligation-count detector for `ralph.md` on the
`ralplan.md` pattern. Larger than the other three — this one is not a one-string fix.

## Separately: pre-existing, not introduced by `14e833e`

With **forced routing enabled**, the max-configured SessionStart branch measures
**7825 characters, above the 6600 cap**. This is not a regression from `14e833e`: the
baseline was **7840**, and the change reduces it by the same **-15** it reduces the
routing-off branch by (6579 -> 6564, which is within cap and is the number the run's
in-suite assertion checks).

The reason it goes unreported is that the in-suite cap assertion **only covers the
routing-off branch**. So the cap is enforced on one branch and merely documented on
the other.

Recorded here for visibility rather than as part of this item's fix set — deciding
what the routing-on cap should even *be* is a separate question from widening the
assertion to measure it.

**Re-measured 2026-07-29 at `1c789b2`** (max-configured fixture: `schema_version=2`,
`proxy=yes`, `secondary_top_model=haiku`, 6 top-tier models, 9 roles at
`gpt-5.6-terra,max`; routing toggled with `oh-no-config on`, not a conf key):

| Branch | Length | vs 6600 cap | In-suite assertion |
|---|---|---|---|
| routing off | 6561 | +39 slack | covered (`test-claude-plugin.sh:4508`) |
| routing on | **7822** | **-1222 over** | not covered |

So the overage is 1222 characters, not the ~1225 implied above, and routing-off
slack is 39. The two candidate fixes remain: pin a separate routing-on cap near
the measured value (bounds future growth, does not shrink anything), or compress
the ~1250-character `OH_NO_FORCED_ROUTING` block itself (shrinks it, but that
block governs per-turn routing behavior, so compressing it is a behavior change).
Picking between them is a user decision, not a mechanical one.

A separate diet pass over the diversity block was investigated and **cancelled**:
`top_tier_models` is only 59 characters of the 454-character block and is actively
consumed by `docs/platforms/claude-code-fusion-rescue.md` for panel identity plus
the hook's own `secondary_top_model` validation, so removing it would break the
fusion-rescue contract. The bootstrap/orchestration duplication that pass targeted
was already gone.

## Sequencing note

N-1, N-2, and N-3 are one additive string each and share the shape of the predecessor
item: do them in one pass and re-record the board once at the end. The current
baseline they would move off is **codex 240 / claude 287** reachable rules and **89**
rejected mutation cases.

N-4 is a different size and should not be bundled with them.
