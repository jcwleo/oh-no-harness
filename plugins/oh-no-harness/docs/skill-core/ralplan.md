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

The host agent operates the planning roles through the active platform runtime
document. The user does not need to pick Planner or Plan-Reviewer manually; the
user approves the plan, requests changes, chooses the next workflow step, or
approves direction changes when a role finds one. Ralph execution is
parallel-capable for
eligible isolated roles that can provide decision-changing evidence; do not
split the handoff into a separate "parallel Ralph" option.

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
3. Read `docs/shared/execution-modes.md` and
   `docs/shared/worktree-isolation.md` so the plan can set a required Ralph
   execution profile and worktree policy.
4. Complete `planner` to create `Planner draft v1` from the requirements source,
   Analyst or gap-check output, and repository evidence.
5. Complete `plan-reviewer` only after `Planner draft v1` exists. Apply the
   two-pass review, verdict mapping, no-replacement rule, and severity/disposition
   requirements from `## Plan Review Contract`.
6. On ITERATE, complete `planner` revision per `## Planner Revision Contract`.
   On REJECT, escalate to the user immediately; REJECT does not consume a loop.
7. Re-review only on blocking findings, per `## Re-Review Rules`; otherwise
   record `Re-review: not required (no blocking findings)`.
8. Stop after at most 2 loops. If feedback would change approved requirements,
   record it as a requested direction change; if loop 2 ends without APPROVE,
   pause for explicit user direction instead of silently advancing past blocking
   review findings.
9. Save the final reflected plan under `.oh-no/plans/` with a
   `Next skill: oh-no-harness:<name>` header field.
10. For direct `ralplan`, present the plan to the user with the Plan Approval
   Brief format below. When running under `ultrawork`, write the plan plus the
   Ultrawork internal approval record instead, unless a pause condition requires
   user review.
11. For direct `ralplan`, mark the plan `pending approval` until the user
   explicitly approves the plan content.
12. After direct plan approval, run the Next Skill Handoff below to ask which
   next skill to invoke. Only invoke the chosen skill through the current
   platform's skill mechanism after the user answers. Skip the question when
   running under `ultrawork`.

Use real role subagents for the consensus roles on subagent-capable hosts.
Planner and Plan-Reviewer are not decorative labels; the planning quality bar
comes from the Planner/Reviewer context separation plus the ordered two-pass
structure inside the single reviewer context (architecture lens first, then the
quality-gate lens applied to the plan and to the pass-1 findings). Run them
inline only when the platform cannot dispatch subagents, the host policy does
not authorize dispatch, or the role lacks a concrete input artifact, isolated
responsibility, or expected output. Record the inline fallback reason in the
plan.

Use the active platform runtime document's dispatch rules for Planner and
Plan-Reviewer. They are sequential, never parallel. Record the trigger as
`Planning
dispatch: natural-dispatch`, `Planning dispatch: explicit-user-request`, or
`Planning dispatch: inline-fallback`; `natural-dispatch` means
host-authorized proactive dispatch, not a weak preference to stay inline.

When a role is inline, write a separate inline role block with the draft id and
fallback reason instead of collapsing the role into the planner's narrative.

Analyst -> Planner -> Plan-Reviewer is the strictly sequential role order
unless Analyst is satisfied by an approved interview spec. Plan-Reviewer runs
only after the Planner draft exists. Do not run these roles in parallel.
This sequential rule governs the three distinct roles. It does not forbid
cross-host review: once the Planner draft exists, the current-host and
opposite-host INSTANCES of the same Plan-Reviewer role may run concurrently and
be synthesized into one verdict per `docs/shared/cross-host-review.md`
(falling back to the Same-Host Parallel Fallback when the opposite host is
unavailable). That is two instances of one reviewer role, not
Analyst/Planner/Plan-Reviewer in parallel.

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
- Contract surface most likely to be missed:
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
- Goal:
- Scope:
- Non-goals:
- Minimal viable approach:
- Rejected speculative complexity:
- Files/modules likely affected:
- Contract surface:
- Task sequence:
- TDD expectations:
- Test case design:
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

When the opposite host is available, run this review as cross-host review per
`docs/shared/cross-host-review.md`: the current-host and opposite-host instances
each run the full two-pass review on the same draft in parallel, and the main
agent synthesizes their findings into one verdict (APPROVE only when zero
blocking findings remain across the merged set; cross-host findings never
silently override the approved direction). Otherwise use the Same-Host Parallel
Fallback with a fallback note when the opposite host is unavailable.

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
- Plan review independence mode: cross-host | same-host-parallel-fallback | inline-fallback (reason)

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

The plan is also invalid if the plan review's independence mode is missing or
non-compliant per `docs/shared/cross-host-review.md`
`## Recording the Independence Mode`: a recorded `cross-host` or
`same-host-parallel-fallback` mode, or an explicit `inline-fallback` with reason,
is required before the approval brief.

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
- semantic-model case when relevant: the state machine or lifecycle,
  parser or grammar, protocol or handshake, ordering, idempotency, caching,
  persistence, migration, or concurrency rule that could be misunderstood
  (this is the contract-aware form of an edge, boundary, or regression case)
- adversarial case: why the chosen test would fail for a plausible wrong
  implementation, including wrong-surface fixes, self-confirming tests, or
  broad-command-only evidence
- baseline or regression case when relevant: the nearby existing behavior that
  should stay fixed
- evidence mapping: which acceptance criterion each test proves

Reject shallow test designs that would pass against the old broken behavior,
only check command exit status, only check marker strings, snapshot broad output
without behavioral assertions, mock away the behavior under test, or assert
implementation details instead of user-visible behavior or public contracts.
Also reject designs whose tests would pass after implementing the change on the
wrong public, caller, or verifier-facing surface.

When TDD does not apply, still provide a verification design that avoids the
same shallow checks and explains why RED/GREEN is not practical.

## Plan File Requirements

Every plan must include:

- a `Next skill: oh-no-harness:<name>` header field naming the recommended next skill (default `oh-no-harness:ralph`)
- goal
- scope and non-goals
- acceptance criteria and any blocking or pending-approval gaps
- minimal viable approach
- rejected speculative complexity, or `none`
- for `LIGHT` execution profile, the minimal viable approach may be a single
  sentence and rejected speculative complexity may be `none` when the task is
  trivially scoped; `STANDARD` and `THOROUGH` plans must justify both fields
  explicitly
- files to create or modify
- contract surface to preserve or change, with source and uncertainty
- task sequence
- test case design quality: must-fail, must-pass, negative/forbidden when
  relevant, semantic-model/adversarial coverage when relevant, baseline or
  regression coverage when relevant, and evidence mapping
- consensus loop log showing Analyst -> Planner -> Plan-Reviewer in order,
  including draft/review/revision ids and `Re-review scope: delta | full` when
  re-review ran
- planning dispatch mode showing whether consensus roles ran as subagents or
  inline fallback
- findings ledger with each Plan-Reviewer finding's lens, severity, disposition,
  and plan-section pointer when accepted
- evidence that accepted feedback is reflected in the final plan body
- execution profile
- worktree policy
- parallel subagent dispatch plan, or the fallback reason if no role can be
  safely isolated
- verification commands
- rollout or recovery notes when risk warrants them
- approval status

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

## Execution Profile

Before presenting a plan, set the execution profile by applying the Execution
Mode Decision Prompt from `docs/shared/execution-modes.md`.

Every plan that recommends `ralph` must include the canonical execution profile
fields from `docs/shared/execution-modes.md`. Keep the complete field set at the
approval boundary in the `Execution profile recap:` block below; if an earlier
plan section needs to discuss the profile, summarize it instead of duplicating
the field list.

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

End every Plan Approval Brief with `Execution profile recap:` immediately before `Approval needed`. This block is the required complete profile for approval, so do not duplicate the same field list earlier in the brief unless a platform or user-requested artifact requires it.

Choose the mode using the LIGHT/STANDARD/THOROUGH definitions and *Typical
signals* in `docs/shared/execution-modes.md`: LIGHT for small isolated work
provable without a durable PRD loop, STANDARD for localized bounded-risk changes,
THOROUGH for security/data/permission/public-contract/release-critical or
multi-subsystem work.

If the execution mode is unclear after repository exploration, choose the higher
credible mode and list the uncertainty under risks or open questions. Do not
hide a mode-changing uncertainty inside a casual assumption.

## Plan Approval Brief

After the consensus plan is written, stop and get user confirmation before execution.

Show the user a concise implementation overview, not just the plan path. The brief must include:

- plan path
- goal and scope summary
- text diagram of the implementation structure or flow
- numbered task sequence
- key files or modules affected
- minimal viable approach and any rejected speculative complexity
- acceptance criteria alignment and any insufficient measurable evidence
- validation check when measurable evidence influenced the plan
- TDD expectations for behavior-changing tasks
- selected Ralph execution mode and why that mode is enough
- consensus loop summary, including Analyst findings, Plan-Reviewer verdicts,
  draft/review/revision ids, and the full findings ledger
  (finding -> severity -> disposition -> section pointer) so every disposition
  is visible at approval time
- worktree policy, including whether direct Ralph should use automatic task
  worktree execution or Ultrawork should also merge back to the integration
  checkout
- parallel subagent dispatch plan for the default Ralph handoff, including
  isolated roles/scopes and any fallback reason
- verification commands or evidence plan
- major risks, assumptions, and open questions
- a final `Execution profile recap` immediately before the approval question
- explicit approval status

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
- Who validates success: {user | maintainer | caller | test suite | operator | customer | other}
- Success signal: {observable proof}
- Failure signal: {observable miss or regression}
- Insufficient evidence: {checks or outputs that are useful but insufficient}
- Contract surface: {public, caller, verifier, prompt, hook, schema, CLI, UI, or other surface to preserve/change}
- Scope boundary most likely to be misunderstood: {boundary}
- Source/confidence: {source and confirmed|inferred|open}

Validation check:
{Use `docs/shared/validation-check.md` when measurable evidence influenced the
plan. Summarize evidence used, supported outcome, proof and gap, recurring risk,
similar-work expectation, excluded case-specific details, added process cost,
and completion claim.}

Structure:
```text
{text diagram}
```

Tasks:
1. {task with expected files/modules}
2. {task with expected files/modules}

TDD:
{which tasks require RED/GREEN/REFACTOR and which are exceptions}

Test case design:
- Must-fail before implementation: {case and expected RED reason, or documented exception}
- Must-pass after implementation: {case}
- Negative/forbidden behavior: {case, or "not relevant" with reason}
- Semantic/adversarial: {semantic model, wrong-surface or wrong-implementation check, or "not relevant" with reason}
- Baseline/regression: {existing behavior guard, or "not relevant" with reason}
- Evidence mapping: {test case -> acceptance criterion}

Parallel subagent dispatch:
{Default Ralph dispatch plan: one line per independent role/scope with platform invocation, start timing, owned scope, dependencies, and integration owner; or a concrete fallback reason if no eligible role can be isolated}

Consensus loop:
Analyst -> Planner -> Plan-Reviewer: {completed in order, with one-line disposition for each}
- Requirements source: {approved interview spec | user request | PRD/ticket}
- Analyst: {satisfied by approved interview spec | completed | inline fallback with reason}
- Planner draft v1: {completed, with source/path}
- Plan review v1: {APPROVE|ITERATE|REJECT}
- Planner revision v2: {not needed, or accepted/rejected/deferred feedback reflected in plan body}
- Plan review v2: {not needed | APPROVE|ITERATE|REJECT, with Re-review scope: delta | full}
- Re-review: {not required (no blocking findings) | completed}
- Plan review independence mode: {cross-host | same-host-parallel-fallback | inline-fallback (reason)}

Findings ledger:
- {finding id} -> {blocking|non-blocking} -> {accepted-reflected (section: <pointer>) | rejected (reason) | deferred (reason) | direction-change-pending-user-approval}

Worktree policy:
{Use `docs/shared/worktree-isolation.md` as the source of truth. Summarize the
selected policy, location, artifact handoff requirement, and any explicit
fallback.}

Verification:
{commands or evidence plan}

Risks and open questions:
{short list, or "None blocking"}

Execution profile recap:
- Overall Ralph mode: {LIGHT|STANDARD|THOROUGH}
- Why this mode is enough: {one sentence}
- Mode source: ralplan
- Verification tier: {LIGHT|STANDARD|THOROUGH}
- Artifact policy: {compact|session-verification|full-prd-session}
- Agent policy: {inline-only|targeted-subagents|full-review-set}
- Parallel trigger: {approved-plan-handoff|explicit-user-request|natural-dispatch|none}
- Worktree policy: {direct-automatic-worktree|automatic-worktree-merge|not-applicable}
- Worktree location: {.oh-no/worktrees/<task-slug>|not-applicable}
- Cleanup policy: {not-needed|conditional|required}
- Task sizing: {short task-mode summary}
- Escalation triggers: {short list or "None expected"}

Approval needed:
Approve this plan, request changes, or leave it pending. After plan approval, I
will ask which workflow the host agent should invoke next.
````

Use a simple text diagram when it helps the user understand the structure. Examples:

```text
Input/request
  -> Spec or requirements
  -> Task 1: data/model changes
  -> Task 2: service or behavior changes
  -> Task 3: UI/API integration
  -> Verification: tests, lint, scenario checks
  -> Review and cleanup
```

or:

```text
Component A
  -> shared helper
  -> Component B
  -> tests
```

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

- `oh-no-harness:ralph` (recommended) — execute the approved plan task-by-task with eligible isolated subagents when they add decision-changing evidence, plus verification, review, cleanup, and final report
- `oh-no-harness:ultrawork` — orchestrate execution, QA, and final validation end-to-end
- request plan changes — go back and revise the plan
- stop with the plan pending approval

The ordinary `oh-no-harness:ralph` choice is the parallel-capable execution
handoff when the approved plan lists eligible isolated roles. Preserve the plan path plus
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

If you were invoked from `ultrawork`, do not present the user-facing Plan
Approval Brief as a normal approval prompt. Complete the planning quality gates,
write the plan and an internal approval record such as
`Plan approval source: ultrawork automatic approval after interview/spec`, then
return control to ultrawork. Pause for the user only when the plan reveals a
documented Ultrawork pause condition: changed approved scope, a blocking product
decision or ambiguity, conflict with the approved requirements source, missing
execution profile, or an explicit user request to review the plan manually.

## Agent Roles

Ralplan uses these roles directly.

This table governs *agent role* dispatch only — workflow-skill chaining
(`ralph`, `ultrawork`) still goes through `## Next Skill Handoff` HARD-GATE. Use
the active platform runtime document's dispatch policy. Planner and
Plan-Reviewer must keep sequential role boundaries because Planner owns the
draft and
Plan-Reviewer reviews that exact draft. Dispatch them as sequential subagents
on subagent-capable hosts when independent context can improve planning or
review quality; otherwise run the roles inline while preserving the same role
blocks and record the inline fallback reason and the subagent-unavailable
condition from `docs/shared/ralph-subagent-policy.md`.
Ralph's own dispatch reads `docs/shared/ralph-subagent-policy.md` plus the
active platform adapter.

| Agent | Dispatch (when) |
|---|---|
| `explore` | Dispatch `explore` subagent to gather repository facts when codebase context is needed. When the request spans independent subsystems, dispatch one `explore` subagent per independent subsystem in one batch. |
| `analyst` | Dispatch `analyst` subagent to identify hidden requirements, risks, constraints, and open questions unless an approved `interview` spec satisfies the Analyst gate. |
| `planner` | Dispatch `planner` subagent to create `Planner draft v1` and any `Planner revision vN`. Planner owns the plan body and feedback disposition. |
| `plan-reviewer` | Dispatch `plan-reviewer` subagent to review the exact Planner draft using the two-pass `## Plan Review Contract`. It may block on overcomplication, speculative scope, or accepted feedback not reflected in the plan body, and must not produce a replacement plan. Cross-host review runs per the `## Plan Review Contract`. |

Analyst/Planner/Plan-Reviewer stay strictly sequential per the rule above — Plan-Reviewer only after the Planner draft exists. Cross-host runs two instances of the one reviewer role, not the three roles (see `docs/shared/cross-host-review.md`).

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
- Plan approval brief.
- Approval status.
- Recommended next skill for execution.
