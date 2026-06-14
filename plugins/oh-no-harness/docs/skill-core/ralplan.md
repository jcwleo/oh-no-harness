---
name: ralplan
description: Use when broad, risky, architecture-sensitive, cross-file, multi-step, or unclear work needs consensus implementation planning before coding.
argument-hint: "<task, spec path, or plan request>"
---

# Ralplan

Ralplan is the public consensus planning entry point.

It owns the consensus planning workflow directly and keeps planning separate from execution. Ralplan has no basic planning mode. Every invocation runs the consensus workflow; if the task is too small for consensus planning, use `ralph` or a direct small edit path instead.

## Software Development Stage

Ralplan is the design and implementation-planning stage for LLM software development.

Use it after `interview` has produced an approved spec, or when the user already gave clear requirements for a broad engineering task. Ralplan should decide scope, sequencing, file ownership, TDD expectations, verification, rollout, and risk handling before `ralph` executes.

## Goal

Create a concrete implementation plan that is drafted by Planner, reviewed by Plan-Reviewer through both the architecture and quality-gate lenses, and revised by Planner until the accepted feedback is reflected in the plan body before execution begins.

The host agent operates the planning roles through the active platform wrapper.
The user does not need to pick Planner or Plan-Reviewer manually; the user
approves the plan, requests changes, chooses the next workflow step, or approves
direction changes when a role finds one. Ralph execution defaults to using
eligible parallel subagents aggressively; do not split the handoff into a
separate "parallel Ralph" option.

## Artifacts

Use durable plan files under:

```text
.oh-no/plans/{slug}.md
```

For transient planning notes, use:

```text
.oh-no/sessions/{sessionId}/planning.md
```

If there is no session id, use a timestamped directory under `.oh-no/sessions/`.

## When To Use

Use when:

- requirements are clear enough to plan, but the implementation path is broad
- the implementation touches several files or subsystems
- architecture tradeoffs are likely
- acceptance criteria exist but need to be mapped to tasks, tests, and evidence
- the user asks for planning before implementation
- a downstream execution skill needs a plan first

Do not use when user intent, scope, or acceptance criteria are still vague; use
`interview` first. Do not use when the task is a single obvious edit with clear
acceptance criteria.

## Required Flow

1. Dispatch `explore` subagent when repository context is needed. Exploration
   may run before the consensus loop, but it does not replace any consensus
   role. When the request spans independent subsystems, dispatch one `explore`
   subagent per subsystem in one batch instead of a single serial exploration.
2. Apply `## Requirements Source And Analyst Gate`. If an approved `interview`
   spec already covers the needed requirements, record `Analyst: satisfied by
   approved interview spec`; otherwise complete `analyst` before Planner drafts.
3. Apply `## Development Requirements Carryover And Gap Check` before Planner
   drafts. Carry forward approved interview coverage when present; otherwise run
   an Analyst gap check limited to plan-relevant development requirements.
4. Read `docs/shared/execution-modes.md`,
   `docs/shared/finite-delivery-contract.md`, and
   `docs/shared/worktree-isolation.md` so the plan can set a required Ralph
   execution profile, finite delivery contract, and worktree policy.
5. Complete `planner` to create `Planner draft v1` from the requirements source,
   Analyst or gap-check output, and repository evidence.
6. Complete `plan-reviewer` only after `Planner draft v1` exists. Plan-Reviewer
   reviews that exact draft in two ordered passes (architecture lens, then
   quality-gate lens applied to the draft and to its own pass-1 findings) and
   returns `Plan review v1` with per-finding lens, reviewer-owned severity
   (`blocking | non-blocking`), and a verdict from `APPROVE | ITERATE | REJECT`;
   Plan-Reviewer does not create a replacement plan.
7. Apply the verdict mapping from `## Plan Review Contract`. On ITERATE,
   complete `planner` revision per `## Planner Revision Contract`: Planner
   must turn accepted feedback into `Planner revision v2` and update the plan
   body instead of only appending comments. On REJECT, escalate to the user
   immediately; REJECT does not consume a loop.
8. Re-review only on blocking findings, per `## Re-Review Rules`. After
   `Planner revision v2`, complete `plan-reviewer` again and record
   `Plan review v2` with its re-review scope. On the non-blocking-only path,
   Planner incorporates the accepted feedback with ledger pointers and writes
   `Re-review: not required (no blocking findings)`; do not dispatch a
   re-review on that path.
9. Stop after at most 2 loops; loop N = Planner draft/revision vN + Plan
   review vN. If Plan-Reviewer feedback would change the approved interview
   spec, user-approved plan direction, scope, non-goals, or acceptance
   criteria, record it as a requested direction change and ask for explicit
   user approval before incorporating it. If loop 2 ends without APPROVE,
   present the plan to the user with `pending approval` status, the unresolved
   findings, and an explicit request to accept the residual concerns, revise
   scope, or stop. Do not silently advance past blocking review findings.
10. Save the final reflected plan under `.oh-no/plans/` with a
   `Next skill: oh-no-harness:<name>` header field.
11. Present the plan to the user with the Plan Approval Brief format below.
12. Mark the plan `pending approval` until the user explicitly approves the plan
   content. Plan content approval does not bypass the Next Skill Handoff unless
   running under `ultrawork`.
13. After plan approval, run the Next Skill Handoff below to ask which next skill to invoke. Only invoke the chosen skill through the current platform's skill mechanism after the user answers. Skip the question only when running under `ultrawork`.

Use real role subagents for the consensus roles on subagent-capable hosts.
Planner and Plan-Reviewer are not decorative labels; the planning quality bar
comes from the Planner/Reviewer context separation plus the ordered two-pass
structure inside the single reviewer context (architecture lens first, then the
quality-gate lens applied to the plan and to the pass-1 findings). Run them
inline only when the platform cannot dispatch subagents, the host policy does
not authorize dispatch, or the role lacks a concrete input artifact, isolated
responsibility, or expected output. Record the inline fallback reason in the
plan.

Use the active platform wrapper's dispatch rules for Planner and Plan-Reviewer.
They are sequential, never parallel. Record the trigger as `Planning
dispatch: natural-dispatch`, `Planning dispatch: explicit-user-request`, or
`Planning dispatch: inline-fallback`; `natural-dispatch` means
host-authorized proactive dispatch, not a weak preference to stay inline.

When a role is inline, write a separate inline role block with the draft id and
fallback reason instead of collapsing the role into the planner's narrative.

Analyst -> Planner -> Plan-Reviewer is the strictly sequential role order
unless Analyst is satisfied by an approved interview spec. Plan-Reviewer runs
only after the Planner draft exists. Do not run these roles in parallel.

Worst-case consensus role dispatch chain: 6 (explore, analyst, Planner draft v1, Plan review v1, Planner revision v2, Plan review v2).

## Requirements Source And Analyst Gate

Use the most specific approved requirements source available:

- approved `interview` spec
- approved user-provided PRD, issue, or ticket
- current user request plus repository evidence

If an approved `interview` spec covers goal, scope, non-goals, constraints,
risks, and acceptance criteria, do not repeat a full Analyst pass. Record:

```text
Analyst: satisfied by approved interview spec
Requirements source: <path or summary>
Gap check: none blocking
```

If any of those fields are missing, inconsistent, or materially affect
architecture, product behavior, data handling, security, or delivery scope, run
Analyst or a limited Analyst gap check before Planner drafts. The Analyst output
must feed the Planner draft; it must not replace the Planner draft.

## Development Requirements Carryover And Gap Check

Ralplan does not repeat the full interview. It checks that development
requirements that affect planning, verification, or Ralph execution are visible
before Planner drafts.

Use the taxonomy and carryover record in
`docs/shared/development-requirements-coverage.md`.

Use the strongest available source:

- If an approved `interview` spec includes `Development requirements coverage`,
  carry forward the relevant required items, not-applicable calls, and accepted
  assumptions into the plan.
- If the requirements source is a PRD, ticket, current user request, or older
  interview spec without that block, run Analyst or a limited Analyst gap check.
  Keep the check plan-relevant and use repository evidence when facts are
  inspectable.
- Do not ask every category as a user question. Ask only when an inferred answer
  would change behavior, architecture, data handling, security posture, delivery
  scope, public support claims, or the smallest credible proof.

Before Planner draft v1, record the shared
`Development requirements carryover:` shape from
`docs/shared/development-requirements-coverage.md`.

If a required category is unresolved and would change behavior, data handling,
security posture, runtime or release handling, compatibility, external-service
contracts, or verification proof, mark the plan `pending approval` instead of
hiding the gap in assumptions.

## Acceptance Criteria Contract

Ralplan must keep the plan aligned to the acceptance criteria that will validate
the work in practice. The plan may refine verification, sequencing, and
implementation strategy, but it must not silently replace the user's success
criteria with a test, broad suite, dashboard number, local command, or internal
shortcut.

When measurable evidence influenced the request, apply
`docs/shared/validation-check.md`. The plan must treat that evidence as a
diagnostic signal and map the proposed improvement to a recurring software
engineering failure mode, not to a case-specific result.

Before Planner draft v1, record:

```text
Acceptance criteria:
- Who validates success:
- Success signal:
- Failure signal:
- Insufficient evidence:
- Scope boundary most likely to be misunderstood:
- Source: approved interview spec | approved PRD/ticket | user request | analyst gap check
- Confidence: confirmed | inferred | open
```

If the acceptance criteria are missing, contradictory, or only inferred for a
decision that changes behavior, architecture, data handling, security posture,
or delivery scope, the plan must mark that gap as blocking or pending approval
instead of hiding it in assumptions.

## Planner Draft Contract

Planner owns the draft plan and every revision. The first Planner output is
`Planner draft v1`.

Planner draft v1 must include:

```text
Planner draft v1:
- Draft id: v1
- Requirements source:
- Analyst status: satisfied by approved interview spec | completed | gap check completed
- Acceptance criteria:
- Development requirements carryover:
- Goal:
- Scope:
- Non-goals:
- Minimal viable approach:
- Rejected speculative complexity:
- Files/modules likely affected:
- Task sequence:
- TDD expectations:
- Test case design:
- Compatibility baseline:
- Runtime stability baseline:
- Executable contract probes:
- Validation check:
- Execution profile:
- Worktree policy:
- Planning dispatch:
- Verification plan:
- Risks/open questions:
```

Plan-Reviewer reviews the Planner draft. It does not replace it. Planner must
keep the plan body as the source of truth and use the consensus log only as
evidence of review and revision.

## Plan Review Contract

Plan-Reviewer reviews a specific Planner draft in one dispatch with two ordered
passes: pass 1 applies the architecture lens (feasibility, fit, sequencing,
tradeoffs, strongest antithesis); pass 2 applies the quality-gate lens to the
draft and to its own pass-1 findings. Plan-Reviewer
must not produce a replacement plan.

Plan-Reviewer input must include:

```text
- Planner draft id: vN
- Full Planner draft or plan path:
- Requirements source:
```

Plan-Reviewer output must include:

```text
Plan review vN:
- Reviewed draft: vN
- Architecture findings:
  - <finding id> | lens: architecture | severity: blocking | non-blocking | requested-direction-change: yes (when applicable)
- Quality-gate findings:
  - <finding id> | lens: quality-gate | severity: blocking | non-blocking | requested-direction-change: yes (when applicable)
- Verdict: APPROVE | ITERATE | REJECT
- Evidence required for approval:
```

The verdict is derived from the findings, not chosen freely: APPROVE iff zero
blocking findings; ITERATE iff >= 1 blocking finding on a salvageable draft;
REJECT only for direction-level or unsalvageable failure, escalated to the user
immediately without consuming a loop.

Finding severity is reviewer-owned; Planner may never reclassify it.
Plan-Reviewer must reject when accepted feedback is only logged and not
reflected in the plan body, when test case designs are AI-slop or would pass
against the old broken behavior, when verification cannot prove the acceptance
criteria, or when speculative complexity is not tied to current requirements.
Plan-Reviewer may improve the plan only inside the approved direction.
Direction changes must stay unincorporated until the user approves them.

## Planner Revision Contract

When Plan-Reviewer returns `ITERATE` (at least one blocking finding), Planner
revises the draft before any further review pass. Planner may never reclassify
reviewer-owned finding severity; a blocking finding stays blocking until a
later `Plan review vN` clears it with APPROVE or the user explicitly waives it.

Planner revision output must include:

```text
Planner revision vN:
- From draft: vN-1
- New draft: vN
- Accepted feedback:
- Rejected feedback with reason:
- Deferred feedback with reason:
- Direction-change feedback waiting for user approval:
- Sections changed:
```

Accepted feedback must be reflected in the plan body. If feedback is rejected or
deferred, Planner must give a concrete reason tied to approved scope,
constraints, or direction-preservation rules. A revision is invalid if it only
adds comments while leaving the plan body unchanged.

When a review returns only non-blocking findings, Planner incorporates the
accepted feedback, records each disposition in the findings ledger with a
plan-section pointer, and writes
`Re-review: not required (no blocking findings)`. Do not dispatch a re-review
on this path; the calling skill enforces the findings-ledger pointer
requirement instead.

## Re-Review Rules

Re-reviews run only when the previous `Plan review vN` returned ITERATE
(blocking findings). Re-reviews are delta reviews by default:

- The re-reviewer always receives the full revised plan; `delta` scopes review
  depth/focus (changed sections + findings ledger first), not the input.
- The reviewer may escalate to a full-depth review with a stated reason; the
  escalation right exists because the full plan is in hand.
- Record `Re-review scope: delta | full` with the re-review.
- Max 2 loops; loop N = Planner draft/revision vN + Plan review vN. REJECT
  escalates to the user immediately and does not consume a loop. After loop 2
  without APPROVE, present the plan as `pending approval` with the unresolved
  findings.

## Findings Ledger Gate

Before saving a plan, presenting a Plan Approval Brief, or asking for execution
approval, verify that the consensus loop has visible evidence for all required
roles, draft ids, review ids, and revision ids in order, and that every review
finding has a recorded disposition:

```text
Consensus loop:
- Analyst: satisfied by approved interview spec | completed | inline fallback with reason | dispatched completed
- Planner draft v1: completed | inline fallback with reason | dispatched completed
- Plan review v1: APPROVE | ITERATE | REJECT after Planner draft v1
- Planner revision v2: not needed | completed from blocking findings
- Plan review v2: not needed | APPROVE | ITERATE | REJECT, with Re-review scope: delta | full
- Re-review: not required (no blocking findings) | completed

Findings ledger:
- <finding id> | lens: architecture | quality-gate | severity: blocking | non-blocking | disposition: accepted-reflected (section: <pointer>) | rejected (reason) | deferred (reason) | direction-change-pending-user-approval
```

The plan is invalid if it contains only Planner output, if Planner drafts before
Analyst finishes when Analyst is required, if Plan-Reviewer is skipped, or if a
review does not name a specific Planner draft id. The plan is invalid if
accepted feedback is logged but not reflected in the final plan body, if any
review finding is missing from the findings ledger, or if an accepted finding
lacks a plan-section pointer. Blocking findings require a matching
`Plan review vN+1` APPROVE or an explicit user waiver. On the
non-blocking-only path no re-review runs, so the calling skill checks the
pointer requirement directly: every accepted finding must carry a plan-section
pointer before the approval brief. If a platform cannot dispatch one of these
roles, keep the same role boundary inline and record the platform, role,
missing capability or authorization, draft id, and fallback reason. Do not move
to the approval brief until the gate passes or the plan is explicitly marked
`pending approval` with the blocking issue.

## Direction Preservation Gate

Plan-Reviewer improves the plan inside the approved direction. It must not
silently override the approved interview spec, user-approved plan direction,
scope, non-goals, or acceptance criteria.

If Plan-Reviewer believes the approved direction is unsafe, infeasible,
internally inconsistent, or materially suboptimal:

- record the finding as `blocking` with `requested-direction-change: yes`
- keep the current approved direction visible
- do not incorporate the new direction into the plan unless the user explicitly
  approves the direction change
- if approval is missing, mark the plan `pending approval` and present the
  direction-change request in the Plan Approval Brief

Planner may accept Plan-Reviewer feedback only when the feedback preserves the
approved direction or when the user has explicitly approved the direction
change.

## Planning Quality Bar

The plan must be concrete enough for `ralph` to execute without inventing scope.

Before presenting the plan, check that it includes:

- explicit in-scope and out-of-scope boundaries
- acceptance criteria alignment: who validates success, success signal, failure
  signal, insufficient proofs, likely misunderstood boundary, source, and
  confidence
- development requirements carryover from the approved interview spec, or a
  limited Analyst gap check with planning implications and pending-approval gaps
- the smallest approach that can satisfy the acceptance criteria
- any added abstraction, configurability, dependency, or generalization justified by a current requirement
- files, modules, commands, or investigation targets where known
- acceptance criteria that can be verified
- TDD expectations for each behavior-changing task
- a smallest meaningful test set for each changed behavior, not an exhaustive
  matrix
- an `Execution profile` that sets the required overall Ralph mode and task-level modes
- a `Worktree policy` from `docs/shared/worktree-isolation.md`
- sequencing constraints and dependency order
- risks, assumptions, and unresolved questions
- the final reflected plan body after accepted Plan-Reviewer feedback
- Analyst findings or `satisfied by approved interview spec`, Planner draft and
  revision ids, and Plan review ids with a findings ledger recording each
  finding's lens, severity, and disposition
- any Plan-Reviewer finding that would change approved direction, scope,
  non-goals, or acceptance criteria, with explicit user-approval status

Do not hide blocking uncertainty inside assumptions. If an unresolved question changes architecture, product behavior, data handling, security, or delivery scope, mark the plan `pending approval` and ask before execution.

## Test Case Design Quality

Test case design belongs in `ralplan`; implementation and RED/GREEN execution
belong in `ralph`.

For every behavior-changing task, design the smallest meaningful test set that
can prove the acceptance criteria and catch the likely regression. Do not create
exhaustive test matrices.

A credible test case design should include:

- must-fail-before-implementation case: what should fail against the current or
  broken behavior, and the expected RED failure reason
- must-pass-after-implementation case: the behavior that must pass after the
  minimal implementation
- negative or forbidden-behavior case when relevant: what must not happen
- edge, boundary, or regression case when relevant: the likely break point or
  old failure mode that should stay fixed
- contract-risk probes from `docs/shared/finite-delivery-contract.md` when
  relevant: compatibility baseline, runtime stability probe, executable
  contract probe, existing fixture/docs/golden preference, and public
  change-stream negative/noise proof
- evidence mapping: which acceptance criterion each test proves

Reject shallow test designs that would pass against the old broken behavior,
only check command exit status, only check marker strings, snapshot broad output
without behavioral assertions, mock away the behavior under test, or assert
implementation details instead of user-visible behavior or public contracts.

When TDD does not apply, still provide a verification design that avoids the
same shallow checks and explains why RED/GREEN is not practical.

## Plan File Requirements

Every plan must include the compact field groups below:

- Header: `Next skill: oh-no-harness:<name>` and approval status.
- Requirements contract: goal, scope, non-goals, acceptance criteria, blocking
  or pending-approval gaps, and `Development requirements carryover`.
- Approach contract: minimal viable approach, rejected speculative complexity,
  files or modules, task sequence, and rollout or recovery notes when risk
  warrants them. `LIGHT` plans may keep this terse; `STANDARD` and `THOROUGH`
  plans must justify the approach and rejected complexity.
- Test and verification contract: test case design quality, TDD exceptions,
  verification commands, and acceptance-to-evidence mapping.
- Consensus contract: consensus loop log showing Analyst -> Planner ->
  Plan-Reviewer in order, planning dispatch mode, draft/review/revision ids,
  `Re-review scope: delta | full` when used, findings ledger disposition, and
  evidence that accepted feedback is reflected in the final plan body.
- Execution contract: execution profile, worktree policy, and parallel subagent
  dispatch plan or fallback reason.

## TDD Task Shape

For each task that changes production behavior, include explicit test-driven steps:

1. Write the failing test selected from the approved test case design.
2. Run it and confirm the expected failure.
3. Write the minimal implementation.
4. Run the test and confirm it passes.
5. Refactor only after green.
6. Rerun the relevant verification after refactor.

For bug fixes, require a reproduction test before the fix. For
behavior-preserving refactors, require characterization or regression coverage
before refactoring. If the test would pass on the old behavior, it is not a
valid TDD case unless the task is pure characterization.

If TDD does not apply, the plan must say why: docs-only, config-only, generated code, throwaway prototype, no practical test harness, or explicit user instruction.

For stateful, lifecycle, cache, session, workflow, parser, scheduler,
persistence, or state-machine behavior, the test design must name the relevant
transition invariant: initialize or enter, mutate or observe, transition or
clean up, reenter or retry, and stale-state/leakage expectation. Do not rely on
only first-use happy-path tests for these tasks.

For compatibility baseline, runtime stability baseline, executable contract
probe, existing-fixture-first, and public change-stream negative/noise proof,
use `docs/shared/finite-delivery-contract.md` as the source of truth. A named
risk without its required probe makes the plan incomplete unless it is explicitly
`not-runnable` with residual risk or a blocker.

## Execution Profile

Before presenting a plan, set the execution profile by applying the Execution
Mode Decision Prompt from `docs/shared/execution-modes.md`.

Every plan that recommends `ralph` must include:

```text
Execution profile:
- Overall Ralph mode: LIGHT | STANDARD | THOROUGH
- Mode source: ralplan
- Verification tier: LIGHT | STANDARD | THOROUGH
- Artifact policy: compact | session-verification | full-prd-session
- Agent policy: inline-only | targeted-subagents | full-review-set
- Parallel trigger: approved-plan-handoff | explicit-user-request | natural-dispatch | none
- Worktree policy: direct-automatic-worktree | automatic-worktree-merge | not-applicable
- Worktree location: .oh-no/worktrees/<task-slug> | not-applicable
- Integration responsibility: direct Ralph leaves task worktree/branch | Ultrawork merges back | not-applicable
- Cleanup policy: not-needed | conditional | required
- Finite delivery contract: canonical fields from `docs/shared/execution-modes.md`
- Task sizing:
  - T1: LIGHT | STANDARD | THOROUGH - reason
- Escalation triggers:
```

The overall Ralph mode is the highest mode needed by any task or cross-task
risk, but task sizing should still mark lighter subtasks when they can be
executed with less process. Ralph must follow this profile during execution.

For plans that recommend direct `ralph`, default to
`Parallel trigger: approved-plan-handoff` and an agent policy of
`targeted-subagents` or `full-review-set` whenever at least one Ralph role can be
isolated by file ownership, read-only scope, review role (security lens
included), verification role (scenario QA lens included), or test/log analysis.
Use `inline-only` and
`Parallel trigger: none` only when the plan documents that no dispatch-worthy
role exists, the active platform cannot dispatch, or the work is unsafe to
isolate under `docs/shared/ralph-subagent-policy.md`.

End every Plan Approval Brief with a single `Execution profile recap:` block
immediately before `Approval needed`. The full plan file keeps the canonical
execution profile; the user-facing brief should not repeat the full profile
earlier.

Use `LIGHT` only when direct implementation and light verification can prove the
acceptance criteria without durable PRD tracking. Use `STANDARD` for localized
behavior, prompt, skill, config, or workflow changes with bounded risk. Use
`THOROUGH` for security, data, permissions, public contracts, release-critical
surfaces, broad architecture changes, or multi-subsystem work.

If the execution mode is unclear after repository exploration, choose the higher
credible mode and list the uncertainty under risks or open questions. Do not
hide a mode-changing uncertainty inside a casual assumption.

## Plan Approval Brief

After the consensus plan is written, stop and get user confirmation before execution.

Show the user a concise implementation overview, not just the plan path. The
brief must preserve the plan's approval contract without duplicating the full
plan body. Include only:

- Plan path, `Status: pending approval`, and `Next skill`.
- Goal, scope, non-goals, minimal viable approach, rejected speculative
  complexity, key files or modules, and task sequence.
- Acceptance summary: who validates success, success signal, failure signal,
  and any useful-but-insufficient evidence.
- Development requirements carryover summary: required planning inputs,
  accepted assumptions to preserve, and pending-approval gaps from
  `docs/shared/development-requirements-coverage.md`.
- Verification summary: TDD or exception, smallest meaningful tests, required
  commands or inspections, validation check status when measurable evidence
  influenced the plan, and risks/open questions.
- Finite delivery contract summary from
  `docs/shared/finite-delivery-contract.md`: source/status, baseline guard,
  required evidence, review-loop budget, deliverable diff hygiene, and ship
  gate. Detailed canonical fields stay in the plan file.
- Consensus summary: Analyst -> Planner -> Plan-Reviewer status, final verdict,
  and any blocking, waived, or direction-change findings. Detailed findings
  ledger stays in the plan file.
- Worktree policy, integration responsibility, and parallel subagent dispatch
  plan or fallback reason.
- A final compact `Execution profile recap` immediately before `Approval needed`.

Use this shape:

````markdown
Plan: .oh-no/plans/{slug}.md
Status: pending approval
Next skill: oh-no-harness:{recommended-next-skill}

Goal:
{one or two sentences}

Scope:
{in scope}
Not in scope:
{out of scope}

Minimal viable approach:
{smallest approach that satisfies the acceptance criteria}
Rejected speculative complexity:
{unneeded abstraction, configurability, dependency, or generalization, or "None"}

Acceptance criteria:
{who validates success, success signal, failure signal, and useful-but-insufficient evidence}

Development requirements carryover:
{required planning inputs, accepted assumptions to preserve or escalate, pending approval gaps}

Tasks:
1. {task with expected files/modules}
2. {task with expected files/modules}

Verification:
{TDD or exception, smallest meaningful tests, required commands or inspections,
validation check status when measurable evidence influenced the plan, and risks}

Finite delivery contract summary:
{source/status, baseline guard, required evidence, review-loop budget,
deliverable diff hygiene, ship gate; detailed fields live in the plan file}

Consensus loop:
{Analyst -> Planner -> Plan-Reviewer status, final verdict, and any blocking,
waived, or direction-change findings; detailed ledger lives in the plan file}

Worktree and dispatch:
{direct Ralph leaves task worktree/branch for review unless integration is
explicitly approved, Ultrawork merges back when selected, or not applicable;
parallel subagent dispatch plan or fallback reason}

Risks and open questions:
{short list, or "None blocking"}

Execution profile recap:
- Overall Ralph mode: {LIGHT|STANDARD|THOROUGH}
- Verification tier: {LIGHT|STANDARD|THOROUGH}
- Agent policy: {inline-only|targeted-subagents|full-review-set}
- Parallel trigger: {approved-plan-handoff|explicit-user-request|natural-dispatch|none}
- Worktree policy: {direct-automatic-worktree|automatic-worktree-merge|not-applicable}
- Worktree location: {.oh-no/worktrees/<task-slug>|not-applicable}
- Integration responsibility: {direct Ralph leaves task worktree/branch|Ultrawork merges back|not-applicable}
- Cleanup policy: {not-needed|conditional|required}
- Finite delivery contract: {source/status summary; full canonical fields live in the plan file}
- Task sizing: {short task-mode summary}

Approval needed:
Approve this plan, request changes, or leave it pending. After plan approval, I
will ask which workflow the host agent should invoke next.
````

End the brief with a direct plan-content approval question. Do not ask the user
to choose the next workflow until the plan content is approved.

Approval choices should be:

- approve the plan content
- request plan changes
- stop with the plan pending approval

## Next Skill Handoff

<HARD-GATE>
Do NOT invoke `ralph`, `ultrawork`, or any other workflow skill after presenting the plan until the user has explicitly approved the plan AND chosen the next step. Skill chaining in Oh No Harness is approval-gated, not automatic.
</HARD-GATE>

This handoff has two phases. On platforms with task tracking, create one task
per phase below and complete them sequentially. Do not collapse them into a
single response or skip the user-confirmation phases.

### Phase 1: Plan content approval

The Plan Approval Brief above is the user-facing review request. Wait for the user's explicit approval of the plan content before proceeding to Phase 2. If the user requests changes, revise the plan and re-present the brief. Keep the plan marked `pending approval` until the user approves.

### Phase 2: Next skill choice

Ask the user which workflow the host agent should invoke next through the active
platform's approval mechanism. Use this option shape:

- `oh-no-harness:ralph` (recommended) — execute the approved plan task-by-task with default eligible parallel subagents, verification, review, cleanup, and final report
- `oh-no-harness:ultrawork` — orchestrate execution, QA, and final validation end-to-end
- request plan changes — go back and revise the plan
- stop with the plan pending approval

The ordinary `oh-no-harness:ralph` choice is the default parallel-capable
execution handoff. Preserve the plan path plus
`Parallel trigger: approved-plan-handoff` in the Ralph invocation so Ralph
treats the approved plan's dispatch plan as authorization to use every eligible
isolated subagent role. Do not ask for a second "parallel subagents" approval
unless the user explicitly requested inline-only execution and later changes
their mind.

End the question with "Which approach?".

Do not invoke any next skill until the user has answered. The user is approving
the host agent's next action, not being asked to run the command manually. When
the user picks one, invoke that skill through the current platform's skill
mechanism with the plan path as the task definition. For the Ralph option,
preserve `Parallel trigger: approved-plan-handoff` when the approved plan has an
eligible dispatch plan. Preserve `Parallel trigger: natural-dispatch` only for
direct Ralph execution without a ralplan handoff when the host permits
proactive dispatch and the active skill policy itself authorizes eligible
isolated roles.

### Ultrawork exception

If you were invoked from `ultrawork`, complete Phase 1 (plan content approval still runs as a content-approval gate), but skip Phase 2's option-list question and return control to ultrawork, which will move the workflow to its execute phase.

## Agent Roles

Ralplan uses these roles directly.

This table governs *agent role* dispatch only — workflow-skill chaining
(`ralph`, `ultrawork`) still goes through `## Next Skill Handoff` HARD-GATE. Use
the active platform wrapper's dispatch policy. Planner and Plan-Reviewer must
run as sequential subagents on subagent-capable hosts because they benefit
from independent context windows. Otherwise run the roles inline while
preserving the same role blocks and record the inline fallback reason and the
subagent-unavailable condition from `docs/shared/ralph-subagent-policy.md`.
Ralph's own dispatch reads `docs/shared/ralph-subagent-policy.md` plus the
active platform adapter.

| Agent | Dispatch (when) |
|---|---|
| `explore` | Dispatch `explore` subagent to gather repository facts when codebase context is needed. When the request spans independent subsystems, dispatch one `explore` subagent per independent subsystem in one batch. |
| `analyst` | Dispatch `analyst` subagent to identify hidden requirements, risks, constraints, and open questions unless an approved `interview` spec satisfies the Analyst gate. |
| `planner` | Dispatch `planner` subagent to create `Planner draft v1` and any `Planner revision vN`. Planner owns the plan body and feedback disposition. |
| `plan-reviewer` | Dispatch `plan-reviewer` subagent to review the exact Planner draft in two ordered passes: architecture lens (feasibility, fit, sequencing, tradeoffs, strongest antithesis), then quality-gate lens applied to the draft and to its own pass-1 findings. Plan-Reviewer applies the senior-engineer overcomplication check, may block on speculative abstraction, configurability, dependencies, broad refactors not tied to current acceptance criteria, or accepted feedback that is only logged instead of reflected in the plan body, and does not produce a replacement plan. |

Analyst, Planner, and Plan-Reviewer remain sequential in that order unless
Analyst is satisfied by an approved `interview` spec. Plan-Reviewer runs only
after the Planner draft exists. Do not run them in parallel.

## Concrete Request Signals

A request is probably concrete enough for execution when it includes at least one of:

- file path
- failing command
- issue or ticket reference
- function, class, or symbol name
- acceptance criteria
- exact test command
- code block
- numbered implementation steps

If these are absent and the user is asking for execution, prefer this planning skill before execution.

## Output

Return:

- Plan path.
- Consensus loop summary.
- Plan-Reviewer findings and disposition, as the findings ledger.
- Execution profile.
- Finite delivery contract.
- Plan approval brief.
- Approval status.
- Recommended next skill for execution.
