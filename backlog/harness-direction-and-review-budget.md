# TODO: Direction-Preserving Review And Complexity Budgets

- Status: TODO
- Backlog: `backlog/`
- Scope: Oh No Harness workflow and role prompts
- Goal: keep validation proportional to the requested product change and stop
  review machinery from becoming a second implementation.

## Problem

A narrow change that reused Ralph's existing verified-disjoint eligibility grew
into a large formal protocol, Git oracle, state matrix, and duplicate fixture
system. Review findings repeatedly requested more proof machinery, while the
original user outcome was only:

- reuse the existing Ralph disjoint decision;
- allow eligible outer executor agents to overlap;
- keep every inner companion invocation foreground and single-shot;
- keep failure recovery, fallback, commit, and integration serial;
- verify with the required non-live checks and real live lanes.

Oh No Harness amplified the expansion through THOROUGH planning, repeated review,
and exhaustive evidence gates. The primary failure was proportionality: tests and
review became a new architecture instead of evidence for the existing one.

## Required Prompt Changes

### 1. Direction Lock

Add a shared rule to `using-oh-no-harness`, `ralplan`, `ralph`, reviewer prompts,
and verifier guidance:

```text
The user's goal and non-goals are the highest-level contract. Planning, tests,
review, and verification are subordinate evidence. Do not introduce a scheduler,
state machine, protocol, oracle, or abstraction that is not required by the
requested product behavior. Treat that as scope expansion and pause before doing
it.
```

Reviewers must first check whether a proposed finding preserves this direction.
When observable behavior can be checked through an existing test or live lane,
they should not require a duplicate formal model.

### 2. Complexity Budget

Add an explicit budget to plans and Ralph execution:

- Record the initial expected changed files and approximate diff size.
- Reuse an existing semantic owner instead of creating a second eligibility or
  lifecycle model.
- Do not implement the same invariant independently in runtime policy, parser,
  fixture builder, and validator.
- Trigger a mandatory simplify/re-scope decision when total diff exceeds twice
  the estimate or test/verification code exceeds roughly three times the product
  change.
- A budget breach stops further fixture/oracle expansion. It does not authorize a
  larger budget automatically.

The exact numeric defaults may be tuned, but every execution must have a visible
stop threshold.

### 3. Evidence Proportionality

Use the smallest credible evidence stack:

1. Static checks for source/generated/validator consistency.
2. Focused non-live tests for observable routing and lifecycle boundaries.
3. Existing live lanes for actual host scheduling, foreground completion, and
   fallback behavior.

Do not make a synthetic transcript parser reproduce the complete runtime or Git
semantics when the live harness can observe the required outcome directly.
Keep one semantic owner and one independent observer.

### 4. Review Topology

Recommended defaults:

- LIGHT: parent review only; no independent reviewer unless a risk trigger fires.
- STANDARD: one self-host code reviewer, then one verifier if completion evidence
  needs independent confirmation.
- THOROUGH: two reviewers only for a genuinely new concurrency model, security
  boundary, destructive migration, data-loss risk, or similarly high-impact
  change.
- Re-review the changed delta and affected behavior, not the entire design from
  scratch.
- After two blocking review rounds, stop adding proof machinery. Run a direction
  and complexity reset before continuing.

Self-host-only review remains a valid user constraint independent of review count.

### 5. Reviewer Guardrails

Update `plan-reviewer` and `code-reviewer` prompts:

- Separate required product correctness from optional hardening.
- A reviewer may block for a demonstrated behavioral or safety failure.
- A reviewer should not block merely because a more formal proof could exist.
- When validation code is larger or more complex than the feature, recommend
  deletion/reuse before proposing another fixture layer.
- Findings that change the approved architecture or scope require explicit user
  approval rather than automatic implementation.

### 6. Verifier Guardrails

The verifier should audit the accepted behavior and evidence, not demand a new
verification architecture. Missing required live evidence blocks completion;
additional speculative proof does not become required solely because it is
possible.

### 7. Routing Adjustment

Clarify in `using-oh-no-harness`:

- A concrete change that reuses an existing scheduler, eligibility decision, or
  lifecycle normally routes to Ralph STANDARD.
- Concurrency-related wording alone does not force `ralplan` or THOROUGH.
- Escalate only when the task introduces a new concurrency model or changes the
  existing semantic owner.

## Stop Rules

During execution, stop and return to the minimal user outcome when any condition
is met:

- review has completed two blocking cycles;
- diff or test-to-product ratio exceeds the recorded budget;
- a test requires a new product-like state machine or protocol;
- reviewer requests conflict with approved non-goals;
- validation work no longer changes the ship/block decision;
- the same invariant is being implemented for a third time.

The next action is simplify, reuse, or explicit user approval for a scope change,
not another automatic proof layer.

## Acceptance Criteria For This TODO

- A small concrete task can route directly to Ralph STANDARD without mandatory
  interview or consensus planning.
- Plans record direction lock, complexity budget, and evidence budget.
- STANDARD defaults to no more than one independent code review plus one verifier.
- THOROUGH review requires an explicit risk reason.
- Reviewers distinguish blocking behavioral failures from optional hardening.
- Two blocking review rounds trigger a scope reset instead of further fixture
  expansion.
- Live behavior is verified by live lanes when required; synthetic tests do not
  replace required live evidence.
- Generated skill and agent wrappers remain derived outputs after source prompt
  changes.

## Non-Goals

- Removing Oh No Harness workflow gates entirely.
- Weakening safety checks for destructive, security-sensitive, or data-loss work.
- Eliminating TDD, independent review, or verification when risk justifies them.
- Adding a hidden controller, persistent state ledger, or automatic mode daemon.

## Additional Backlog: Live TC Semantics And Oracle Cleanup

### Problem

The Claude and Codex live suites still mix three different kinds of evidence:

1. deterministic runtime facts from tool and lifecycle events;
2. stable machine-protocol tokens used for attribution or termination;
3. model-generated natural-language summaries.

Several lanes correctly prove dispatch, concurrency, foreground completion,
read-only boundaries, role ownership, wait/close order, file ownership, and
RED-to-GREEN behavior from runtime events, but then fail again when the final
answer omits an exact phrase such as `started-concurrently: yes` or does not
repeat every Direction Contract noun in every role packet. This can classify a
semantically correct run as a behavior regression and encourages the prompt
bloat this backlog is intended to remove.

The same audit found two broader coverage gaps:

- `natural` role-worker lanes name the required roles, worker messages, and
  markers in the prompt, so they prove guided role lifecycle rather than natural
  role selection.
- deep-live plus deterministic reachability proves that linked owners are
  reachable and that the model can report their contents, but it does not prove
  that a triggered Required Reading owner was actually read immediately before
  the dependent runtime gate.

### TC Classification Rule

Classify every live assertion before deciding whether it is gating:

- **Runtime fact:** tool call, role identity, call count, start/complete order,
  peak in-flight count, wait-before-close, foreground/background state,
  permission boundary, file/hash/diff evidence, real command result. Keep these
  strict and derive them from events or artifacts.
- **Protocol token:** stable role-ownership, one-hop, terminator, or transport
  marker needed to disambiguate a valid machine response. Keep only the minimum
  tokens that cannot be proven from runtime events.
- **Natural-language summary:** explanatory headings, prose such as
  `started-concurrently: yes`, repeated field names, or synonyms already proven
  by events. Treat these as non-gating diagnostics unless the user-facing text
  itself is the contract under test.

Do not require a model-generated sentence to reconfirm a runtime fact already
proved by the event stream.

### P0: Prove Triggered Required Reading At Runtime

Add causal runtime cases for every trigger-class owner that affects dispatch or
a completion gate:

1. With the trigger absent, prove the owner is not preloaded.
2. Fire the named trigger and capture a Read event for the exact owner.
3. Prove the Read event occurs before the first dependent dispatch or gate.
4. Make the owner unavailable in a disposable fixture and prove the dependent
   action is blocked rather than guessed from memory.

Keep deterministic reachability as the static source-link check, but do not
describe it as proof that runtime reading occurred.

### P0: Split Guided Lifecycle From Natural Routing

Rename existing prompts that prescribe `Role: ...`, worker counts, worker
messages, or exact role markers to `guided-role-lifecycle-live`. They remain
useful for checking host capability, role registration, lifecycle, and cleanup.

Add separate natural-routing cases whose user prompt contains only:

- the user goal or failure symptom;
- relevant risk and scope constraints;
- the expected user-visible outcome.

The natural prompt must not name roles, agents, workers, dispatch, marker lines,
or expected role counts. Judge the selected roles from the event trace, including
the absence of roles that the mode and triggers do not justify.

### P0: Preserve Plan-Reviewer Independence

Remove `Verdict: APPROVE`, `none blocking`, and instructions to ignore reviewer
improvements from ralplan sequential and natural smoke prompts. Those fixtures
currently ask an independent reviewer to rubber-stamp the draft and can fail
when the strengthened reviewer correctly returns `ITERATE`.

The strict contract should be:

- Planner completes before Plan-Reviewer starts.
- Plan-Reviewer receives the exact captured planner draft identity/content.
- The verdict is role-owned and may be `APPROVE` or `ITERATE`.
- Blocking findings are preserved for the caller; they are not overwritten to
  satisfy the smoke fixture.
- Re-review occurs only when the real workflow rule calls for it.

### P1: Use Role-Specific Direction Contract Projections

Do not copy every Direction Contract phrase into every leaf packet. Require the
smallest role-specific projection:

- executor: story/AC ID, owned scope, forbidden scope, applicable non-goals,
  permission boundary, and verification ownership;
- reviewer: primary goal, applicable architectural/safety non-goals, acceptance
  mapping, and scope-drift check;
- verifier: AC IDs, acceptance-to-evidence mapping, evidence ownership, and
  skipped/residual-risk reporting;
- Ralph session and final report: complete Direction Contract and final
  direction-delta status.

Prefer stable AC IDs and structured fields over substring checks for nouns such
as `state machine`, `Git oracle`, `single-shot`, or `serial`. A leaf packet fails
only when an applicable requirement is absent or contradicted, not because an
irrelevant full-contract phrase was omitted.

### P1: Remove Duplicate Final-Prose Gates

For cross-host review, Fusion Rescue, VBC, systematic-debugging, fallback, and
parallel executor lanes:

- derive concurrency, foreground completion, read-only state, role ownership,
  topology, and review-then-verify order from runtime events;
- generate the test summary from the parser-owned evidence instead of asking the
  model to restate it verbatim;
- retain one minimal success/terminator token only when needed to prove the main
  agent reached synthesis;
- downgrade missing explanatory headings or synonym variance to a diagnostic.

### P1: Replace Fusion Keyword Counts With Decision Evidence

Do not define meaningful panel analysis as the presence of a minimum number of
keywords such as `ci`, `retry`, `quarantine`, `root-cause`, `release`, or `risk`.
Instead require each panel to return a structured hypothesis, evidence,
assumption under test, failure mode, recommendation, confidence, and
confidence-changing evidence. The synthesis must reference the actual panel
results, preserve contradictions, and explain why the recommendation follows
from evidence.

### P2: Label And Schedule Capability Matrices Separately

Exact role-count and wait-before-close checks remain valid for explicit
capability matrices such as all-role parallel and four-angle simplify lanes.
Do not use those matrices as evidence that a normal LIGHT or STANDARD workflow
should launch every role. Keep them targeted or release/nightly where practical,
and use separate proportionality lanes to prove that unnecessary roles, paired
review, TDD, or cleanup passes do not start without their trigger.

### Assertions That Must Remain Strict

- write/background flags and permission denials;
- actual companion invocation count and one-hop boundaries;
- role identity and machine role-ownership tokens;
- start, completion, wait, close, and dependency order;
- no pending worker at completion;
- secret and credential redaction checks;
- file ownership, protected-target snapshots, hashes, and escape guards;
- RED-file preservation and real RED-to-GREEN command evidence;
- forbidden fallback, extra host hop, or unauthorized role dispatch;
- deterministic hook, config, manifest, wrapper, and reachability output.

### Acceptance Criteria For TC Cleanup

- A semantically correct run cannot fail only because a redundant explanatory
  phrase is missing from the final answer.
- An actual write-boundary, lifecycle, ordering, role-ownership, or scope
  violation still fails deterministically.
- Existing guided role tests are named and documented as guided capability or
  lifecycle tests.
- Natural-routing prompts contain no prescribed role, worker, agent, marker, or
  role-count instructions.
- Plan-Reviewer smoke tests accept independent findings and do not prescribe an
  approval verdict.
- Triggered Required Reading has an event-order test proving read-before-gate and
  a missing-owner case proving fail-closed behavior.
- Direction Contract checks use full-contract ownership at the session/final
  boundaries and role-specific projections for leaf packets.
- Fusion analysis quality cannot pass through keyword stuffing alone.
- Lane documentation separates static reachability, guided lifecycle, natural
  routing, runtime behavior, and final-prose diagnostics.
- The cleanup reduces duplicated transcript-oracle logic instead of adding a
  second parser or fixture system.

### Suggested TC Cleanup Order

1. Inventory every live assertion as runtime fact, protocol token, or natural
   prose.
2. Fix ralplan forced-approval fixtures and the known Direction Contract
   substring false positive.
3. Remove redundant cross-host/fusion final-prose gates while preserving event
   and permission checks.
4. Split guided lifecycle lanes from real natural-routing lanes.
5. Add triggered Required Reading causal event-order cases.
6. Replace Fusion keyword-count heuristics with structured decision evidence.
7. Update `docs/reference/test-harness-lanes.md` and lane-contract validation so
   names and claimed evidence match what each lane actually proves.
8. Run focused static/non-live checks, then the affected Claude and Codex live
   lanes; do not rerun unrelated expensive matrices without a changed contract.

## Suggested Implementation Order

1. Add Direction Lock, Complexity Budget, and Stop Rules to shared skill cores.
2. Reduce the default review topology by execution mode.
3. Add reviewer and verifier proportionality clauses.
4. Align plan/session templates with visible budgets and review-round count.
5. Add focused prompt-contract tests for the new guardrails.
6. Regenerate wrappers and run existing validator, reachability, non-live, and
   targeted live checks without creating a new formal oracle.
