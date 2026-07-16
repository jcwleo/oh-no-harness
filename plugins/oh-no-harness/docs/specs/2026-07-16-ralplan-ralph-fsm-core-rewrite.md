# Ralplan/Ralph FSM Core Rewrite (Behavior-Preserving)

Status: draft — pending user approval. Nothing in this spec is shipped
behavior. This spec defines the contract for rewriting the `ralplan` and
`ralph` skill cores in the style pioneered by `ralplan-v2`: self-contained,
FSM-structured, adapter-composed prompts — while preserving the public skill
names, routing, workflow semantics, and safety gates of the current v1
implementation.

Supersedes nothing. Complements
`2026-07-14-ralph-v2-greenfield-rewrite-plan.md`: the state-model ideas from
that proposal (single snapshot, phase/outcome split, evidence invalidation)
are absorbed here into the existing `ralph` skill instead of shipping a
separate public `ralph-v2`.

## 1. Goal

Rewrite `docs/skill-core/ralplan.md` and `docs/skill-core/ralph.md` so that:

1. Each core is **self-sufficient**: no runtime `Required Reading` of
   `docs/shared/*` documents. Every load-bearing rule lives in the core (or
   its platform adapter). Shared documents become optional maintenance
   rationale, exactly as `ralplan-v2` section 2 already declares.
2. Each core is **FSM-structured**: named phases, named invocation outcomes,
   one transition table, per-state sections with a uniform template
   (Owner / Input / Actions / Exit guard / Transitions / Persist).
3. Each run maintains **one visible state snapshot** under
   `.oh-no/sessions/` so pause/resume and compaction recovery never depend on
   working memory.
4. Generated wrappers compose as **core + exactly one host adapter** using the
   existing `SELF_CONTAINED_ADAPTER_SKILLS` mechanism in
   `scripts/generate-skill-wrappers.py` (currently `{"ralplan-v2"}`).
5. Every load-bearing rule carries a **stable rule ID** (`[R4]`, `[E7]`)
   inline, and validators grep rule IDs plus short canonical stems instead of
   full prose sentences, so future wording edits do not break validation.

## 2. Non-Goals

- No public skill rename. `/ralplan` and `/ralph` keep their names, command
  wrappers, manifests, and SessionStart routing entries.
- No routing change. Automatic routing and Ultrawork chaining are untouched.
- No hook architecture change. `hooks/ralph-platform-adapter` keeps its
  matcher; only injected wording is updated to the new core vocabulary.
- No new public skill and no `ralph-v2` registration.
- No deletion of `docs/shared/*` in this effort. Other skills (`interview`,
  `ultrawork`, `using-oh-no-harness`, agent cores) still reference them.
  Retirement is a separate follow-up once no runtime consumer remains.
- No hidden state ledger, daemon, or keyword automation. Snapshots are
  visible Markdown the model reads and writes, consistent with AGENTS.md.
- No workflow-semantics change. Every gate below is the current shipped
  behavior, restructured — not redesigned. Any intentional behavior change
  found during rewrite must be surfaced to the user first, not folded in.

## 3. Invariants To Preserve

These are the behavior-preservation acceptance criteria. Each gets an inline
ID marker in the rewritten cores and a validator check (section 8).

### 3.1 Ralplan invariants (R-series)

| ID | Invariant | Current source |
|---|---|---|
| R1 | Requirements direction is user-owned; only a user-confirmed direction change alters the Direction Contract. Role proposals that change it are `requested-direction-change: yes` and require explicit approval. | ralplan.md `## Direction Preservation Gate`; execution-modes.md `## Direction Contract` |
| R2 | The plan body is Planner-owned. Plan-Reviewer reviews and blocks; it never produces a replacement plan. | ralplan.md `## Agent Roles`, `## Plan Review Contract` |
| R3 | Plan-Reviewer reviews the exact Planner draft (id + body), not a recap. Architecture pass then quality-gate pass, in one dispatch. | ralplan.md `## Planner Draft Contract`, `## Plan Review Contract` |
| R4 | APPROVE freezes the exact reviewed draft. Non-blocking findings are optional follow-ups causing no mutation, dispatch, or re-review. Any required body change yields ITERATE instead. | ralplan.md `## Plan Review Contract` |
| R5 | On ITERATE, Planner classifies every blocker (`accepted`/`rejected`/`deferred`/`direction-change`) before any mutation or new draft id. Rejected/deferred/direction-change block v2 until the user resolves them. | ralplan.md `## Planner Revision Contract` |
| R6 | Maximum two loops (draft/revision vN + review vN). REJECT escalates immediately and consumes no loop. After loop 2 without APPROVE, pause for user direction. | ralplan.md `## Re-Review Rules` |
| R7 | Review v2 is a delta closure review (dispositions, changed sections, affected dependencies) receiving the full plan; full-depth re-review only for a named material change. A v2-first blocker carries `Why first raised now`. | ralplan.md `## Re-Review Rules` |
| R8 | A blocker needs a basis (`AC ID | safety invariant | Direction Contract field | applicable mandatory gate`), exact draft pointer, material consequence, and smallest sufficient correction. Preferences and optional stronger proof are non-blocking. Review v1 returns one consolidated set. | ralplan.md `## Plan Review Contract` |
| R9 | Roles are strictly sequential: Analyst (or approved-spec satisfaction) -> Planner -> Plan-Reviewer. Only a named THOROUGH paired-review trigger runs two reviewer instances; STANDARD uses one; LIGHT may record review not-required with a concrete reason. | ralplan.md `## Required Flow`, `## Plan Review Contract` |
| R10 | Mode (LIGHT/STANDARD/THOROUGH) is selected by active semantic risk, lightest credible first. Category words (`concurrency`, `generated`) and host capability alone never escalate. | execution-modes.md `## Ownership`, decision prompt |
| R11 | Vague intent routes to `interview`; a single obvious edit with clear ACs routes to `ralph`. Ralplan never implements production code and writes only under `.oh-no/`. | ralplan.md `## When To Use`; ralplan-v2 §1 |
| R12 | Direct execution requires the single combined 4-choice approval gate (approve-and-run Ralph / approve-and-run Ultrawork / request changes / leave pending), HARD-GATE: no workflow skill invocation before an explicit approve-and-run choice. `Which approach?` closes the prompt. | ralplan.md `## Next Skill Handoff` |
| R13 | Under Ultrawork, the direct prompt is replaced by an internal approval record (`ultrawork automatic approval`) only when planning gates passed and no pause condition fired (unresolved disposition, non-waivable gate, changed scope, missing profile, ambiguity, or explicit manual-review request). | ralplan.md `### Ultrawork exception` |
| R14 | Ralplan owns the authoritative execution profile; a plan that recommends Ralph carries one complete profile (mode, tier, artifact/agent policy, parallel trigger, worktree policy/location, cleanup policy, task sizing, escalation triggers). `Parallel trigger: approved-plan-handoff` marks the ordinary parallel-capable Ralph handoff. | ralplan.md `## Execution Profile`; execution-modes.md `## Artifact Fields` |
| R15 | The Active Plan Contract is compiled once (mode- and trigger-aware) and the identical block goes to Planner and every reviewer instance. Reviewer missing-field blocking is limited to active rows. Inactive rows are omitted, not emitted as `not applicable` ceremony. | ralplan.md `## Active Plan Contract` |
| R16 | Recorded state only: an unrecorded in-memory conclusion cannot authorize a transition; state, verdicts, dispositions, and approval status are persisted before pause or handoff. | ralplan-v2 §3 (adopted); ralplan.md Findings Ledger Gate (partial) |
| R17 | Behavior-change test design: one must-fail-before RED case failing against old broken behavior, one must-pass-after GREEN case; risk-activated negative/edge/regression cases only; reject wrong-surface/marker-only/mock-away tests; compact TDD exceptions allowed. Stack recommendation trigger presents 2-3 options with one default. | ralplan.md `## Test Case Design Quality`, `## Active Plan Contract` |
| R18 | External anchors (short tokens only): section headings `Plan Approval Brief`, `Next Skill Handoff`, `Execution profile`, `Findings Ledger`; the anchored output line `Reviewed draft: v<N>` (both hosts' live parsers regex `^Reviewed draft:`); the closing question `Which approach?`. The Active Plan Contract keeps a canonical activation table and the caps line `LIGHT=11; STANDARD=24; THOROUGH=26` (re-baselining needs explicit user approval). Everything longer is NOT preserved verbatim — validators are re-anchored to compact stems instead (section 8 policy). | validate-plugin-files.py:3898-4147; ultrawork.md:64,269,435 |
| R19 | Agent-core boundary: `plan-reviewer.md`, `planner.md`, `plan-reviewer-codex.md` are not rewritten here, and plan-reviewer stays Ralplan-only (no other skill dispatches it). Validator markers that today require identical long sentences in both the ralplan core and agent cores (`APPROVE freezes...`, `Blocking basis: <...>`, `disposition-only user-decision packet`) are split: the agent-core side keeps its current text; the ralplan-core side is checked via rule ID + short stem (`APPROVE freezes`, `Blocking basis:`, `disposition-only`). | validate-plugin-files.py:3999-4106 |

### 3.2 Ralph invariants (E-series)

| ID | Invariant | Current source |
|---|---|---|
| E1 | Copy the approved Direction Contract without reinterpretation before editing. If execution would change it, stop for explicit approval instead of silently rescoping. Plan/AC infeasibility routes back to the user or `ralplan` (options presented, never auto-invoked). | ralph.md `## Input Hardening`, loop step 9 |
| E2 | An execution mode is recorded before any file change, from the source priority: approved ralplan profile > explicit user instruction > interview LIGHT hint > Ralph-derived (decision prompt). Do not de-escalate below an approved plan's mode without user approval. | ralph.md `## Required Execution Mode`; execution-modes.md |
| E3 | HARD-GATE: no source edit until a `Worktree decision` is recorded, one of the allowed enum values. Direct Ralph defaults to a registered git worktree under `.oh-no/worktrees/<task-slug>` (never clone/cp/plain dir); the LIGHT direct-checkout carve-out requires all five named conditions; mid-run escalation stops edits until re-decided. Artifact access (`.oh-no` plan/spec) is preserved when moving into a worktree. | ralph.md `## Worktree Isolation Gate`; worktree-isolation.md |
| E4 | TDD: behavior-changing work requires RED (fails against old behavior) before implementation and GREEN before story completion; bug fixes need a reproduction; refactors need characterization; exceptions are documented compactly. Ralph invokes TDD internally — concrete implement requests are not routed to the TDD skill. | ralph.md loop step 6, `## TDD Task Shape` (via ralplan), tdd routing contract |
| E5 | Scope trace: every changed file and meaningful line maps to the concrete request, approved spec/plan/story, a test/AC/verification requirement, now-unused code removal, or locked behavior-preserving cleanup. Out-of-scope findings become residual risk/follow-ups, not diff growth. | ralph.md `## Scope Trace Gate` |
| E6 | Parallel dispatch only for disjoint write scopes with no inter-dependency, no split RED/GREEN order, clear ownership, and integration owner; full eligible batch created before waiting; per-executor scope check before integration; caller owns lifecycle (timeout/empty wait is never a final result; never close a slow pending subagent). | ralph.md `## Parallel Subagent Policy`; ralph-subagent-policy.md |
| E7 | Review-then-verify: the mode-gated code-review stage completes (or a compliant `not-required` is recorded) before the single independent self-host verifier starts; a verifier spawned early is stale, recorded as discarded, and rerun. The verifier is never the maker and never a pair. Review Gate dependency graph fields are recorded. | ralph.md `## Review Gate` |
| E8 | Review topology is mode-gated: LIGHT direct-diff allowed; STANDARD one reviewer, or `not-required (STANDARD small carve-out: <reason>)` when all carve-out conditions hold (provisional until the actual-diff recheck; invalidation restores single-reviewer review); THOROUGH paired review only for a named risk. One original review + one focused re-check is the cap; a second unresolved blocking round requires rescope or user direction. | ralph.md `## Review Gate`; execution-modes.md carve-out |
| E9 | Evidence freshness: mutation invalidates intersecting evidence — stories whose acceptance depended on changed files are re-verified; cleanup that changes files reruns relevant verification; a success status (exit 0, HTTP 2xx, "done" log) without the observable effect is missing evidence; broad suites run once after stabilization with recorded rerun reasons; real-surface direct evidence for STANDARD/THOROUGH behavior changes; secrets/PII redacted before evidence is written. | ralph.md `## Verification Budget Policy`, loop step 8 |
| E10 | Budget gates: the cumulative Process Budget Gate stops for rescope on 2x handwritten diff, ~3x supporting-test ratio, a second unresolved blocking review round, or a third reimplementation of the same invariant; the Diff-Budget Gate runs exactly once after all stories and before review, expanding into the scope review only past thresholds. A budget breach never authorizes automatic expansion. | ralph.md `## Process Budget Gate`, `## Diff-Budget Gate` |
| E11 | Completion ledger (HARD-GATE): the run is invalid unless the reviewer pass, independent verifier pass, simplify, and verification-before-completion are each individually recorded as satisfied or compliant not-required; `verification.md` is the canonical AC-to-evidence ledger; per-story evidence (AC mapping, contract surface, baseline guard, story risk check) is recorded or a missing-evidence blocker named; missing review topology is a named ledger gap; LIGHT/carve-out compaction rules apply as written. | ralph.md `## Persistence Rule`, `## Input Hardening` |
| E12 | Cleanup is trigger-gated after the behavior lock and required review: LIGHT/STANDARD quick scan first, `simplify` only on candidates or uncertainty; THOROUGH four viewpoints only for a named trigger; post-cleanup verification and focused review when structure changed. | ralph.md `## Cleanup And Final Verification` |
| E13 | A direct-Ralph automatic worktree is not complete while work sits in the worktree: merge-back + post-merge verification, or the branch/PR handoff is reported; failure leaves the worktree intact and reports the blocker. Ultrawork worktrees return control to Ultrawork for integration. | ralph.md `## Worktree Isolation Gate`; worktree-isolation.md |
| E14 | Resume reconstructs from artifacts, never memory: recompute incomplete stories from recorded status, re-confirm mode and worktree decision, treat the in-flight story as unverified, and re-verify completed stories whose dependencies diverged. | ralph.md `## Resume Protocol` |
| E15 | Ralph is terminal: no workflow skill auto-invocation after the final report. Mid-loop internal skills (TDD, simplify, VBC, systematic-debugging, fusion-rescue) are part of the documented loop, not chaining events. Debugging/rescue escalation ladder: one systematic-debugging pass + one further fix per root cause, then fusion-rescue or `blocked`/`failed_verification`. | ralph.md `## Final Handoff`, loop step 9 |
| E16 | Delegated Codex executor boundary (when SessionStart rebinds executor to `executor-codex`): transport-only role, batch eligibility unchanged, caller-owned escape guard with protected-target capture before/after, sequential fallback and integration. | ralph.md `## Codex Executor Delegation Boundary`; ralph-subagent-policy.md |
| E17 | External anchors (short tokens only): heading `## Cleanup And Final Verification` (ultrawork reachability resolves through the ralph edge); output line `Review phases: plan=<n>; implementation-code=<n>; focused-recheck=<n>; independent-verifier=<n>`; the Worktree decision enum values; the interview direct-entry LIGHT rule. Longer pinned prose is re-anchored to stems, not preserved. | check-skill-reachability.py:149; validate-plugin-files.py:4132 |

## 4. Target FSM Design

### 4.1 Shared conventions

- **Phase** = where the run is; **Outcome** = how this invocation ended.
  They are disjoint sets (adopted from the ralph-v2 proposal).
- Every state section uses one template:
  `Owner / Input / Actions / Exit guard / Transitions / Persist`.
- `STOP` semantics (from ralplan-v2 §13): record outcome `PAUSED` with the
  blocked transition, evidence, and unblock condition — never a silent exit.
- Conflict priority (from ralplan-v2 §0):
  `user decision > requirements/Direction Contract > Active Plan Contract >
  fired core gate > exact draft > role findings`.
- Snapshots live in the existing session directory convention
  (`.oh-no/sessions/{sessionId}/`), reusing the chain session directory when
  one exists. No new top-level artifact locations.

### 4.2 Ralplan FSM

Phases:

```text
ROUTE -> REQUIREMENTS -> DRAFT -> REVIEW -> APPROVAL
```

Outcomes:

```text
ROUTED_INTERVIEW | ROUTED_RALPH | HANDOFF_RALPH | HANDOFF_ULTRAWORK |
RETURN_ULTRAWORK | PAUSED
```

Transition table (normative; each guard cites its rule IDs):

| From | Guard | To |
|---|---|---|
| ROUTE | intent/scope/ACs materially unclear [R11] | outcome ROUTED_INTERVIEW |
| ROUTE | single obvious edit with clear ACs [R11] | outcome ROUTED_RALPH |
| ROUTE | plannable request | REQUIREMENTS |
| REQUIREMENTS | source + Analyst status recorded (approved spec satisfies Analyst) [R1] | DRAFT |
| REQUIREMENTS | gap changes product intent/architecture/data/security/delivery [R1] | outcome PAUSED |
| DRAFT | Planner draft vN complete against the Active Plan Contract [R2, R15] | REVIEW |
| REVIEW | LIGHT no-review reason recorded [R9] | APPROVAL |
| REVIEW | verdict APPROVE [R4] | APPROVAL |
| REVIEW | verdict ITERATE, all blockers accepted, loop budget left [R5, R6] | DRAFT |
| REVIEW | verdict ITERATE with rejected/deferred/direction-change disposition [R5] | outcome PAUSED |
| REVIEW | verdict REJECT [R6] | outcome PAUSED |
| REVIEW | loop 2 ends without APPROVE [R6] | outcome PAUSED |
| APPROVAL | direct: user selects approve-and-run [R12] | outcome HANDOFF_RALPH / HANDOFF_ULTRAWORK |
| APPROVAL | direct: user requests changes (approval freeze invalidated) [R4, R12] | DRAFT |
| APPROVAL | direct: user leaves pending [R12] | outcome PAUSED |
| APPROVAL | ultrawork: internal approval conditions hold [R13] | outcome RETURN_ULTRAWORK |
| APPROVAL | ultrawork: any pause condition fires [R13] | outcome PAUSED |

Direction change at any phase: record `requested-direction-change: yes`,
pause for approval, and start a new planning run after approval [R1].

Snapshot (`.oh-no/sessions/{sessionId}/planning.md`):

```yaml
run: <id>; type: direct-ralplan | ultrawork
phase: ROUTE | REQUIREMENTS | DRAFT | REVIEW | APPROVAL
outcome: null | <outcome>
mode: LIGHT | STANDARD | THOROUGH
source: <path/summary>; analyst: satisfied-by-spec | completed | gap-check | blocked
contract: <active-plan-contract id>
draft: v<N>; plan: .oh-no/plans/<slug>.md
review: loop <0|1|2>; topology; verdict; blockers with dispositions
approval: pending | approved-direct | approved-ultrawork
```

### 4.3 Ralph FSM

Phases:

```text
PREPARE -> EXECUTE -> REVIEW -> FINALIZE
```

FINALIZE internal checkpoints (kept inside one phase to bound the top-level
machine): `CLEANUP -> RECHECK -> INTEGRATE -> COMPLETION_AUDIT`.

Outcomes:

```text
COMPLETE | PAUSED | RETURN_TO_PLAN
```

Transition table:

| From | Guard | To |
|---|---|---|
| PREPARE | Direction Contract copied, mode + profile recorded, worktree decision recorded, PRD/session scaffolded per artifact policy [E1, E2, E3] | EXECUTE |
| PREPARE | requirements too vague / non-LIGHT interview spec without plan unconfirmed [E1] | outcome RETURN_TO_PLAN |
| PREPARE | worktree blocked / environment blocker [E3] | outcome PAUSED |
| EXECUTE | ready story exists | EXECUTE (story loop: RED -> implement -> GREEN -> scope/budget recheck [E4, E5, E10]) |
| EXECUTE | all required stories pass with fresh evidence [E9] | REVIEW |
| EXECUTE | plan/AC infeasible as written [E1] | outcome RETURN_TO_PLAN |
| EXECUTE | debugging ladder exhausted [E15] | outcome PAUSED |
| REVIEW | diff-budget gate run once; review topology satisfied; blockers resolved or recorded; verifier ran after review completion [E7, E8, E10] | FINALIZE |
| REVIEW | blocking findings within budget [E8] | EXECUTE (focused fix + focused re-check only) |
| REVIEW | second unresolved blocking round [E8, E10] | outcome PAUSED |
| FINALIZE | cleanup + post-cleanup verification + integration/merge-back + VBC + completion ledger all satisfied [E9, E11, E12, E13] | outcome COMPLETE |
| FINALIZE | merge/post-merge verification fails [E13] | outcome PAUSED |
| any | user stop / direction change required [E1] | outcome PAUSED |

Snapshot (`.oh-no/sessions/{sessionId}/execution.md` — additive; `prd.json`,
`progress.md`, `verification.md` keep their current roles, and
`verification.md` remains the canonical AC-to-evidence ledger [E11]):

```yaml
run: <id>
phase: PREPARE | EXECUTE | REVIEW | FINALIZE
checkpoint: null | CLEANUP | RECHECK | INTEGRATE | COMPLETION_AUDIT
outcome: null | COMPLETE | PAUSED | RETURN_TO_PLAN
plan: <path>; approval: <status/source>; profile: <mode/tier/policies>
worktree: <decision>; <location>
stories: <id: status/passes summary — detail stays in prd.json>
review: <topology; verdict; verifier-after-reviewer: yes|no|not-required>
budgets: <process-budget status; diff-budget: pending|run>
freshness: <stale evidence list after last mutation>
```

The snapshot is a resume index, not a second ledger: it points into
`prd.json`/`verification.md` rather than duplicating their rows (E11 keeps a
single evidence owner).

## 5. Handoff Package (Ralplan -> Ralph)

Keep every existing `Execution profile` field name (other consumers —
`ultrawork`, `interview`, execution-modes fixtures — depend on them). Add one
`Plan identity` block so admission is checkable:

```text
Plan identity:
- Plan path: .oh-no/plans/<slug>.md
- Planner draft id: v<N>
- Reviewed draft id: v<N> | not-reviewed (LIGHT: <reason>)
- Approval status: approved-direct | approved-ultrawork | pending
- Approval source: user approve-and-run | ultrawork automatic approval
```

Ralph PREPARE admission [E1, E2]: refuse to edit when the plan identity is
missing for a claimed approved-plan handoff, approval status is `pending`, or
the profile is incomplete — route back per the transition table instead of
silently deriving a lighter mode.

## 6. Composition Change

1. Add `ralplan` and `ralph` to `SELF_CONTAINED_ADAPTER_SKILLS` in
   `scripts/generate-skill-wrappers.py` and mirror the set in
   `scripts/validate-plugin-files.py`.
2. Create required adapters (the generator fails without them):
   - `docs/platforms/claude-code-ralplan.md`, `docs/platforms/codex-ralplan.md`
   - `docs/platforms/claude-code-ralph.md`, `docs/platforms/codex-ralph.md`
     (these two exist today as overlays; they are rewritten into full
     adapters in the ralplan-v2 style: `<ADAPTER_CONTRACT>` header, host
     invocation/lifecycle only, core wins on conflict).
3. Wrappers become `core + one adapter`; the common
   `codex-runtime.md`/`claude-code-runtime.md` documents are no longer
   composed into these two skills (same as ralplan-v2 today). Any rule from
   the runtime docs that ralplan/ralph actually depend on (dispatch syntax,
   skill-invocation mechanics, approval-question mechanics) moves into the
   adapters. Verified runtime-doc dependencies that must land in the
   adapters because reachability currently resolves them from the composed
   runtime doc: `Cross-Host Consult Channel` (ralplan BOTH), `trigger-loaded`
   (ralplan + ralph BOTH), and `Dispatch only after the active skill's
   trigger fires` (ralplan CODEX).
4. `AGENTS.md` note updated: the self-contained exception grows from
   "`ralplan-v2` is the narrow exception" to naming the three self-contained
   skills.

### 6.1 Shared-doc absorption map

| Shared doc | ralplan core absorbs | ralph core absorbs | Doc fate (this effort) |
|---|---|---|---|
| execution-modes.md | Direction Contract schema; mode definitions + selection rules [R10]; execution profile schema [R14]; STANDARD small-carve-out declaration rules | mode behaviors; carve-out eligibility + invalidation [E8]; process budgets [E10]; escalation/de-escalation [E2] | kept (interview/ultrawork/using- still read it) |
| worktree-isolation.md | profile policy values only [R14] | full decision enum + defaults + LIGHT carve-out + merge-back + artifact handoff [E3, E13] | kept (ultrawork, executor agent-core still read it) |
| ralph-subagent-policy.md | dispatch-eligibility summary for planning roles [R9] | dispatch decision; batch rule; lifecycle; isolation contract; safe/forbidden parallel; integration; delegated Codex boundary [E6, E7, E16] | kept (ultrawork, simplify, VBC, systematic-debugging, hook still read it) |
| verification-tiers.md | — | tier minimums; verification budget; evidence redaction [E9] | kept (VBC, verifier agent-core still read it) |
| validation-check.md | trigger + template stub [R17 adjunct] | trigger + template stub [E9 adjunct] | kept |
| cross-host-review.md | paired-review contract essentials [R9] | paired-review + independence-mode recording [E8] | kept (agent cores still read it) |
| agent-tiers.md | — | one-paragraph tier-selection rule | kept |
| failure-taxonomy.md | — | story-risk-check category list [E5 adjunct] | kept |

"Absorbs" means the core states the rule **compactly** in its own words with
its rule ID — the decision rule and its guard conditions, never the source
doc's examples, signal lists, or rationale (section 7.0). The core declares
(ralplan-v2 §2 pattern): external documents may add rationale but are never a
runtime prerequisite and cannot override the core.

## 7. Rewrite Method

### 7.0 Compression policy (governing rule)

Carry **load-bearing rules only**. A clause earns a place in the new core
only if deleting it would change an outcome (a transition, a gate verdict, an
artifact field, or a user-visible prompt). Everything else — rationale,
detection examples, edge-case narration, restated definitions, per-mode prose
that a matrix row already covers — stays out; maintenance docs keep it.
Duplicated statements of one rule collapse into the single rule-ID definition
plus table references. Size targets (soft, but a miss requires a reason):
ralplan core ≤ 300 lines (now 500), ralph core ≤ 400 lines (now 742), and
each composed wrapper strictly smaller than its current composition.

For each skill, in order:

1. Draft the new core from this spec's FSM + invariant tables (not by
   editing the old prose incrementally).
2. Diff against the old core section-by-section; recover any load-bearing
   rule not yet mapped to an invariant ID (update section 3 of this spec if
   one is found — that is a spec gap, not a silent addition).
3. Write the adapters.
4. Port validators (section 8) in the same change set.
5. Regenerate wrappers; run the full static gate.

Ralplan ships first (own PR); Ralph second (own PR, checkpoint-by-checkpoint
commits per phase); doc-reference cleanup and README updates third.

## 8. Validator Migration Map

Every consumer of the current prose must be ported atomically with each core
rewrite. Known coupling points (verified against the current tree):

`scripts/validate-plugin-files.py` — every constant/assertion carrying
ralplan/ralph anchors, re-anchored to rule IDs + compact stems (never full
sentences):

- `SELF_CONTAINED_ADAPTER_SKILLS` (~41) — add both skills.
- `EXPECTED_ALWAYS_READING` + `TRIGGER_CLASS_REQUIRED_SKILLS` (~205) —
  remove ralplan/ralph (no Required Reading section remains); the
  all-upfront-wording tripwire (~2640) retargets or retires for these two.
- `ROLE_POLICY_MARKERS`, `PLATFORM_SUBAGENT_MARKERS`,
  `SIMPLICITY_SCOPE_SKILL_MARKERS`, `EXECUTION_MODE_SKILL_MARKERS`,
  `WORKTREE_SKILL_MARKERS`, `SKILL_REQUIRED_AGENT_ROLES`,
  `NEXT_SKILL_GATE_REQUIRED` — ralplan/ralph entries re-anchored.
- `assert_ralplan_proportionality_contract` (~3625),
  `assert_ralplan_review_boundary_contract` (~3898) — re-anchor (R4-R8,
  R15, R18 guards); the branch-matrix mutation meanings survive as stems.
- `assert_parallel_executor_contract`, `assert_worktree_contract`,
  `assert_tdd_routing_contract`, `assert_independence_mode_gates`,
  `assert_execution_mode_contract` — re-anchor ralplan/ralph stems only;
  shared-doc and other-skill markers unchanged.
- New: `assert_fsm_contract(skill)` — verify the phase set, outcome set, one
  transition table, every transition guard citing at least one rule ID, and
  every R/E rule ID defined exactly once.

`scripts/check-skill-reachability.py`:

- All `ralplan` (22) and `ralph` (~24) required phrases re-anchored. Policy:
  each entry becomes `("[R6]", BOTH)`-style ID checks plus a short stem
  (e.g. `"at most 2 loops"`), so the invariant stays grep-able without
  freezing full sentences. Phrases that today resolve through shared-doc
  path references (e.g. `authored or accepted by the same agent`,
  `the implementing or accepting agent is not sufficient`) must resolve in
  the core body after absorption.
- `SKILL_REFERENCES` edges for ralplan/ralph reviewed: the `ralph ->
  simplify` edge stays (cleanup handoff remains a real skill reference).
- `ultrawork` transitively depends on the two rewritten cores: its required
  phrases `at most 2 loops` (via the ralplan edge) and `## Cleanup And Final
  Verification` (via the ralph edge) must keep resolving. Ultrawork's own
  entries are not otherwise touched.
- Runtime-doc-sourced phrases for these two skills (`Cross-Host Consult
  Channel`, `trigger-loaded`, `Dispatch only after the active skill's
  trigger fires`) re-resolve from the new adapters after composition drops
  the runtime docs.

`scripts/test-review-boundary-contract.py`:

- All mutations against `docs/skill-core/ralplan.md` re-targeted to the new
  body. The mutation *meanings* are unchanged: deleting the APPROVE freeze,
  the disposition-before-mutation rule, the loop cap, the delta-closure
  rule, or the blocker-basis requirement must each still fail validation.

`hooks/ralph-platform-adapter`:

- Matcher unchanged. The injected context references
  `docs/shared/ralph-subagent-policy.md` and the platform adapter paths
  (`docs/platforms/{codex,claude-code}-ralph.md`); after E6 absorption the
  shared-policy pointer is updated to name the ralph core as the policy
  owner, and the adapter paths keep working (same filenames, new adapter
  content). Injected reminder wording stays compact — it must not grow to
  restate absorbed rules.

Live tests (`scripts/test-claude-plugin.sh`, `scripts/test-codex-plugin.sh`):

- Ralplan/Ralph live-lane prompt fixtures and expected-marker greps
  re-anchored in the same PR as each core.

## 9. Acceptance Criteria

The rewrite is done when all of the following hold:

1. `python3 scripts/validate-plugin-files.py .` passes, including the new
   FSM contract checks and all ported assertions.
2. `generate-skill-wrappers.py --check` and `generate-agent-wrappers.py
   --check` pass; regenerated wrapper diffs touch only the rewritten skills.
3. `check-skill-reachability.py` passes on both platforms with ralplan and
   ralph resolving every required rule from the wrapper alone (no
   shared-doc reachability needed for these two skills).
4. Zero runtime `Required Reading` in the two cores; zero
   `docs/shared/` load-bearing references (rationale links allowed only in a
   non-normative "Maintenance references" footer).
5. Mutation checks: deleting any single R/E rule definition, any transition
   guard, or the outcome/phase split fails validation.
6. Every invariant in section 3 is traceable: rule ID present in the core,
   covered by at least one validator or mutation check.
7. Offline install smokes pass
   (`scripts/test-claude-plugin.sh`, `scripts/test-codex-plugin.sh`).
8. Live comparison (budget-gated, opt-in): same fixture prompts produce the
   same mode selection, review topology, approval-gate shape, and handoff
   profile as the pre-rewrite baseline, with reduced prompt tokens and no
   increase in dispatch count.
9. Public surface unchanged: skill names, command wrappers, manifests,
   SessionStart routing map, and hook matcher are byte-identical except for
   documented wording updates inside the hook's injected text.

## 10. Relationship To Ralplan-v2 / Ralph-v2

- `ralplan-v2` stays a registered explicit-only preview during this effort
  and serves as the structural reference. After the rewritten `ralplan`
  stabilizes, a separate decision retires or repurposes the preview.
- The `2026-07-14` ralph-v2 greenfield proposal is absorbed: its snapshot,
  phase/outcome split, pending-mutation and evidence-invalidation ideas land
  here (sections 4.3, E9, E14). No separate public `ralph-v2` is planned
  while this effort is active. Its known internal inconsistency (worktree
  enum vs PREPARE always-create) is resolved here by E3's decision table.

## 11. Risks And Mitigations

| Risk | Mitigation |
|---|---|
| Silent loss of a load-bearing rule during compression | Section 3 is the checklist; rewrite method step 2 requires a section-by-section diff; mutation tests pin each rule ID |
| Validator drift breaks CI mid-rewrite | Core + validator changes land in the same PR; `--check` gates before each commit |
| Duplicated worktree/mode rules diverge between the two cores | Ownership split: ralplan records *requirements* (profile), ralph owns *decisions* (worktree/dispatch); neither copies the other's normative text |
| Other skills regress when shared docs stop being read by ralplan/ralph | Shared docs are not modified in this effort; only the two cores stop *requiring* them |
| Live behavior drift despite green static checks | Acceptance criterion 8: budget-gated live baseline comparison on both hosts before merge |
| Rule-ID markers become the new brittle grep targets | IDs are definitional anchors, not prose; validators check ID presence + short stems, never full sentences |
