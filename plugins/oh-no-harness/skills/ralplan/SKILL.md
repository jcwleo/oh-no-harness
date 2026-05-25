---
name: ralplan
description: Use when broad, risky, architecture-sensitive, cross-file, multi-step, or unclear work needs consensus implementation planning before coding.
argument-hint: "[--subagents] <task, spec path, or plan request>"
---

# Ralplan

Ralplan is the public consensus planning entry point.

It owns the consensus planning workflow directly and keeps planning separate from execution. Ralplan has no basic planning mode. Every invocation runs the consensus workflow; if the task is too small for consensus planning, use `ralph` or a direct small edit path instead.

## Software Development Stage

Ralplan is the design and implementation-planning stage for LLM software development.

Use it after `interview` has produced an approved spec, or when the user already gave a clear but broad engineering task. Ralplan should decide scope, sequencing, file ownership, TDD expectations, verification, rollout, and risk handling before `ralph` executes.

## Goal

Create a concrete implementation plan that is drafted by Planner, reviewed by Architect, reviewed by Critic, and revised by Planner until the accepted feedback is reflected in the plan body before execution begins.

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

- the work is broad or ambiguous
- the implementation touches several files or subsystems
- architecture tradeoffs are likely
- acceptance criteria are not yet testable
- the user asks for planning before implementation
- a downstream execution skill needs a plan first

Do not use when the task is a single obvious edit with clear acceptance criteria.

## Required Flow

1. Dispatch `explore` subagent when repository context is needed. Exploration
   may run before the consensus loop, but it does not replace any consensus
   role.
2. Apply `## Requirements Source And Analyst Gate`. If an approved `interview`
   spec already covers the needed requirements, record `Analyst: satisfied by
   approved interview spec`; otherwise complete `analyst` before Planner drafts.
3. Read `docs/shared/execution-modes.md` and
   `docs/shared/worktree-isolation.md` so the plan can set a required Ralph
   execution profile and worktree policy.
4. Complete `planner` to create `Planner draft v1` from the requirements source,
   Analyst or gap-check output, and repository evidence.
5. Complete `architect` only after `Planner draft v1` exists. Architect reviews
   that exact draft and returns `Architect review v1`; Architect does not create
   a replacement plan.
6. Complete `critic` only after `Architect review v1` exists. Critic reviews the
   same Planner draft plus the matching Architect review and returns
   `Critic review v1`.
7. When Architect or Critic requires changes, complete `planner` revision.
   Planner must turn accepted feedback into `Planner revision v2`, record
   feedback disposition, and update the plan body instead of only appending
   comments.
8. Repeat the full review loop for every revision:
   `Planner revision vN -> Architect review vN -> Critic review vN`. Stop when
   Critic approves or five complete loops have run. If Architect or Critic
   feedback would change the approved interview spec, user-approved plan
   direction, scope, non-goals, or acceptance criteria, record it as a requested
   direction change and ask for explicit user approval before incorporating it.
   If Critic still rejects after the fifth loop, present the plan to the user
   with `pending approval` status, the unresolved Critic findings, and an
   explicit request to accept the residual concerns, revise scope, or stop. Do
   not silently advance past blocking critic feedback.
9. Save the final reflected plan under `.oh-no/plans/` with a
   `Next skill: oh-no-harness:<name>` header field.
10. Present the plan to the user with the Plan Approval Brief format below.
11. Mark the plan `pending approval` unless the user explicitly approves execution.
12. After plan approval, run the Next Skill Handoff below to ask which next skill to invoke. Only invoke the chosen skill through the current platform's skill mechanism after the user answers. Skip the question only when running under `autopilot`.

On platforms without subagent support or without host authorization to call
subagents, perform each role inline and record the inline fallback reason in the
plan. On Claude Code, use separate role agents for Planner, Architect, and Critic
when plugin agents or task agents are available; they are sequential, never
parallel. On Codex, use `spawn_agent` for planning roles only when the host tool
policy and user wording authorize subagents, for example `ralplan --subagents`,
`ralplan with subagents`, `use subagents`, `delegate the planning roles`, or
`run planner/architect/critic as subagents`. When a Codex planning role is
dispatched, embed the matching `agents/<role>.md` prompt content in the spawned-agent message. When a role is inline, write a separate inline role block
with the draft id and fallback reason instead of collapsing the role into the
planner's narrative.

Analyst, Planner, Architect, and Critic are strictly sequential in that order
unless Analyst is satisfied by an approved interview spec. Architect and Critic
are sequential. Do not run them in parallel.

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

## Planner Draft Contract

Planner owns the draft plan and every revision. The first Planner output is
`Planner draft v1`.

Planner draft v1 must include:

```text
Planner draft v1:
- Draft id: v1
- Requirements source:
- Analyst status: satisfied by approved interview spec | completed | gap check completed
- Goal:
- Scope:
- Non-goals:
- Minimal viable approach:
- Rejected speculative complexity:
- Files/modules likely affected:
- Task sequence:
- TDD expectations:
- Execution profile:
- Worktree policy:
- Verification plan:
- Risks/open questions:
```

Architect and Critic review the Planner draft. They do not replace it. Planner
must keep the plan body as the source of truth and use the consensus log only as
evidence of review and revision.

## Architect Review Contract

Architect reviews a specific Planner draft and returns structured review
feedback. Architect must not produce a replacement plan.

Architect input must include:

```text
- Planner draft id: vN
- Full Planner draft or plan path:
- Requirements source:
```

Architect output must include:

```text
Architect review vN:
- Reviewed draft: vN
- Verdict: approve | changes_requested | blocking | requested_direction_change
- Architecture fit:
- Sequencing concerns:
- Strongest antithesis:
- Tradeoff tension:
- Required changes:
- Optional improvements:
- Execution profile concerns:
- Worktree policy concerns:
- Direction-change requests:
```

Architect may improve the plan only inside the approved direction. Direction
changes must stay unincorporated until the user approves them.

## Critic Review Contract

Critic reviews the same Planner draft plus the matching Architect review. Critic
does not run before Architect and does not review a draft version Architect has
not reviewed.

Critic input must include:

```text
- Planner draft id: vN
- Architect review for draft id: vN
- Full Planner draft or plan path:
```

Critic output must include:

```text
Critic review vN:
- Reviewed draft: vN
- Architect review consumed: yes
- Verdict: APPROVE | ITERATE | REJECT
- Blocking issues:
- Overcomplexity/speculative abstraction check:
- Acceptance criteria quality:
- Verification weakness:
- Missing feedback disposition:
- Evidence required for approval:
```

Critic must reject when Architect feedback is ignored without disposition, when
accepted feedback is only logged and not reflected in the plan body, when
verification cannot prove the acceptance criteria, or when speculative
complexity is not tied to current requirements.

## Planner Revision Contract

When Architect or Critic returns `changes_requested`, `blocking`, `ITERATE`, or
`REJECT`, Planner revises the draft before any further Architect or Critic pass.

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

## Consensus Order Gate

Before saving a plan, presenting a Plan Approval Brief, or asking for execution
approval, verify that the consensus loop has visible evidence for all required
roles, draft ids, review ids, and revision ids in order:

```text
Consensus loop:
- Analyst: satisfied by approved interview spec | completed | inline fallback with reason | dispatched completed
- Planner draft v1: completed | inline fallback with reason | dispatched completed
- Architect review v1: completed after Planner draft v1 | inline fallback with reason | dispatched completed
- Critic review v1: APPROVE | ITERATE | REJECT after Architect review v1
- Planner revision v2: not needed | completed from Architect/Critic feedback
- Architect review v2: not needed | completed after Planner revision v2
- Critic review v2: not needed | APPROVE | ITERATE | REJECT
```

The plan is invalid if it contains only Planner output, if Planner drafts before
Analyst finishes when Analyst is required, if Architect is skipped, or if Critic
runs before Architect. The plan is invalid if Architect or Critic only add comments instead of reviewing a specific Planner draft, if Critic reviews a draft
that Architect did not review, if accepted feedback is logged but not reflected
in the final plan body, or if Planner revision skips the
`Planner revision vN -> Architect review vN -> Critic review vN` loop. If a
platform cannot dispatch one of these roles, keep the same role boundary inline
and record the platform, role, missing capability or authorization, draft id, and
fallback reason. Do not move to the approval brief until the gate passes or the
plan is explicitly marked `pending approval` with the blocking role-order issue.

## Direction Preservation Gate

Architect and Critic improve the plan inside the approved direction. They must
not silently override the approved interview spec, user-approved plan direction,
scope, non-goals, or acceptance criteria.

If Architect or Critic believes the approved direction is unsafe, infeasible,
internally inconsistent, or materially suboptimal:

- record the concern as `blocking` or `requested direction change`
- keep the current approved direction visible
- do not incorporate the new direction into the plan unless the user explicitly
  approves the direction change
- if approval is missing, mark the plan `pending approval` and present the
  direction-change request in the Plan Approval Brief

Planner may accept Architect or Critic feedback only when the feedback preserves
the approved direction or when the user has explicitly approved the direction
change.

## Planning Quality Bar

The plan must be concrete enough for `ralph` to execute without inventing scope.

Before presenting the plan, check that it includes:

- explicit in-scope and out-of-scope boundaries
- the smallest approach that can satisfy the acceptance criteria
- any added abstraction, configurability, dependency, or generalization justified by a current requirement
- files, modules, commands, or investigation targets where known
- acceptance criteria that can be verified
- TDD expectations for each behavior-changing task
- an `Execution profile` that sets the required overall Ralph mode and task-level modes
- a `Worktree policy` from `docs/shared/worktree-isolation.md`
- sequencing constraints and dependency order
- risks, assumptions, and unresolved questions
- the final reflected plan body after accepted Architect and Critic feedback
- Analyst findings or `satisfied by approved interview spec`, Planner draft and
  revision ids, Architect review ids, and Critic review ids with disposition:
  accepted, rejected, deferred, requested direction change, or blocking
- any Architect or Critic request that would change approved direction, scope,
  non-goals, or acceptance criteria, with explicit user-approval status

Do not hide blocking uncertainty inside assumptions. If an unresolved question changes architecture, product behavior, data handling, security, or delivery scope, mark the plan `pending approval` and ask before execution.

## Plan File Requirements

Every plan must include:

- a `Next skill: oh-no-harness:<name>` header field naming the recommended next skill (default `oh-no-harness:ralph`)
- goal
- scope and non-goals
- minimal viable approach
- rejected speculative complexity, or `none`
- for `LIGHT` execution profile, the minimal viable approach may be a single
  sentence and rejected speculative complexity may be `none` when the task is
  trivially scoped; `STANDARD` and `THOROUGH` plans must justify both fields
  explicitly
- files to create or modify
- task sequence
- acceptance criteria
- consensus loop log showing Analyst -> Planner -> Architect -> Critic in order,
  including draft/review/revision ids
- feedback disposition showing which Architect and Critic findings were accepted,
  rejected, deferred, or blocked as requested direction changes
- evidence that accepted feedback is reflected in the final plan body
- execution profile
- worktree policy
- parallel subagent dispatch plan, or `none`
- verification commands
- rollout or recovery notes when risk warrants them
- approval status

## TDD Task Shape

For each task that changes production behavior, include explicit test-driven steps:

1. Write the failing test.
2. Run it and confirm the expected failure.
3. Write the minimal implementation.
4. Run the test and confirm it passes.
5. Refactor only after green.
6. Rerun the relevant verification after refactor.

For bug fixes, require a reproduction test before the fix. For behavior-preserving refactors, require characterization or regression coverage before refactoring.

If TDD does not apply, the plan must say why: docs-only, config-only, generated code, throwaway prototype, no practical test harness, or explicit user instruction.

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
- Parallel trigger: none | natural-dispatch | explicit-user-request | approved-plan-handoff
- Worktree policy: ask-once-default | automatic-worktree-merge | not-applicable
- Cleanup policy: not-needed | conditional | required
- Task sizing:
  - T1: LIGHT | STANDARD | THOROUGH - reason
- Escalation triggers:
```

The overall Ralph mode is the highest mode needed by any task or cross-task
risk, but task sizing should still mark lighter subtasks when they can be
executed with less process. Ralph must follow this profile during execution.

End every Plan Approval Brief with a separate `Execution profile recap:` block
immediately before `Approval needed`. This final recap is required even when the
same profile already appears earlier in the plan. The goal is to keep the
selected Ralph mode visible at the exact approval boundary.

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

Show the user a concise implementation overview, not just the plan path. The brief must include:

- plan path
- goal and scope summary
- text diagram of the implementation structure or flow
- numbered task sequence
- key files or modules affected
- minimal viable approach and any rejected speculative complexity
- TDD expectations for behavior-changing tasks
- selected Ralph execution mode and why that mode is enough
- consensus loop summary, including Analyst findings, Architect disposition,
  Critic verdict, draft/review/revision ids, and Planner feedback disposition
- worktree policy, including whether direct Ralph should ask once or Autopilot
  should use automatic worktree execution
- parallel subagent dispatch plan, including how to explicitly approve it on Codex
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

Execution profile:
Overall Ralph mode: {LIGHT|STANDARD|THOROUGH}
Verification tier: {LIGHT|STANDARD|THOROUGH}
Agent policy: {inline-only|targeted-subagents|full-review-set}
Parallel trigger: {none|natural-dispatch|explicit-user-request|approved-plan-handoff}
Worktree policy: {ask-once-default|automatic-worktree-merge|not-applicable}
Cleanup policy: {not-needed|conditional|required}
Task sizing: {short task-mode summary}

Structure:
```text
{text diagram}
```

Tasks:
1. {task with expected files/modules}
2. {task with expected files/modules}

TDD:
{which tasks require RED/GREEN/REFACTOR and which are exceptions}

Parallel subagent dispatch:
{None, or one line per independent role/scope with platform invocation, start timing, owned scope, dependencies, and integration owner}

Consensus loop:
Analyst -> Planner -> Architect -> Critic: {completed in order, with one-line disposition for each}
- Requirements source: {approved interview spec | user request | PRD/ticket}
- Analyst: {satisfied by approved interview spec | completed | inline fallback with reason}
- Planner draft v1: {completed, with source/path}
- Architect review v1: {verdict and required changes}
- Critic review v1: {APPROVE|ITERATE|REJECT}
- Planner revision v2: {not needed, or accepted/rejected/deferred feedback reflected in plan body}

Worktree policy:
{Direct Ralph asks once before creating or using a task worktree; Autopilot automatically uses a task worktree and merges back to the integration checkout; or not applicable for read-only work. Include artifact handoff requirements for approved .oh-no specs/plans.}

Verification:
{commands or evidence plan}

Risks and open questions:
{short list, or "None blocking"}

Execution profile recap:
- Overall Ralph mode: {LIGHT|STANDARD|THOROUGH}
- Why this mode is enough: {one sentence}
- Verification tier: {LIGHT|STANDARD|THOROUGH}
- Agent policy: {inline-only|targeted-subagents|full-review-set}
- Parallel trigger: {none|natural-dispatch|explicit-user-request|approved-plan-handoff}
- Worktree policy: {ask-once-default|automatic-worktree-merge|not-applicable}
- Cleanup policy: {not-needed|conditional|required}
- Task sizing: {short task-mode summary}
- Escalation triggers: {short list or "None expected"}

Approval needed:
Choose `ralph`, `ralph with parallel subagents`, `autopilot`, request changes,
or leave the plan pending. For Codex parallel execution, reply with:
"Run ralph with parallel subagents. Spawn one agent per independent task, wait
for all agents, then integrate and verify."
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

End the brief with a direct approval question. Do not begin implementation until the user approves.

Approval choices should be:

- approve execution with `ralph`
- approve execution with `ralph with parallel subagents` when the plan lists independent scopes and the extra token cost is acceptable
- approve orchestration with `autopilot`
- request plan changes
- stop with the plan pending approval

## Next Skill Handoff

<HARD-GATE>
Do NOT invoke `ralph`, `autopilot`, or any other workflow skill after presenting the plan until the user has explicitly approved the plan AND chosen the next step. Skill chaining in Oh No Harness is approval-gated, not automatic.
</HARD-GATE>

This handoff has two phases. On platforms with task tracking (Claude Code `TodoWrite` / `TaskCreate`), create one task per phase below and complete them sequentially. Do not collapse them into a single response or skip the user-confirmation phases.

### Phase 1: Plan content approval

The Plan Approval Brief above is the user-facing review request. Wait for the user's explicit approval of the plan content before proceeding to Phase 2. If the user requests changes, revise the plan and re-present the brief. Keep the plan marked `pending approval` until the user approves.

### Phase 2: Next skill choice

Ask the user which next skill to invoke. On Claude Code, ask through `AskUserQuestion`. Use this option shape:

- `oh-no-harness:ralph` (recommended) — execute the approved plan task-by-task with verification, review, cleanup, and final report
- `oh-no-harness:ralph` with `parallel subagents` — execute with Ralph and explicitly authorize parallel subagent dispatch for the independent scopes listed in the plan
- `oh-no-harness:autopilot` — orchestrate execution, QA, and final validation end-to-end
- request plan changes — go back and revise the plan
- stop with the plan pending approval

End the question with "Which approach?".

Do not invoke any next skill until the user has answered. When the user picks one, invoke that skill through the current platform's skill mechanism with the plan path as the task definition. If the user picks the parallel-subagent Ralph option, preserve the phrase `parallel subagents` in the Ralph invocation as an explicit dispatch signal; if the plan selects natural dispatch, preserve `Parallel trigger: natural-dispatch`.

### Autopilot exception

If you were invoked from `autopilot`, complete Phase 1 (plan content approval still runs as a content-approval gate), but skip Phase 2's option-list question and return control to autopilot, which will move the workflow to its execute phase.

## Agent Roles

Ralplan uses these roles directly.

This table governs *agent role* dispatch only — workflow-skill chaining (`ralph`, `autopilot`) still goes through `## Next Skill Handoff` HARD-GATE. On Claude Code, dispatch the consensus roles below as separate subagents when plugin agents or task agents are available. On Codex, `spawn_agent` availability is host-policy controlled: use it only when the user or active plan explicitly authorizes subagents, for example `ralplan --subagents`, `ralplan with subagents`, `use subagents`, `delegate the planning roles`, or `run planner/architect/critic as subagents`. Each Codex spawn must embed the matching `agents/<role>.md` prompt content in the spawned-agent message. Otherwise run the roles inline while preserving the same role blocks and record the inline fallback reason. Ralph's own dispatch reads `docs/shared/ralph-subagent-policy.md` plus the active platform adapter.

| Agent | Dispatch (when) |
|---|---|
| `explore` | Dispatch `explore` subagent to gather repository facts when codebase context is needed. |
| `analyst` | Dispatch `analyst` subagent to identify hidden requirements, risks, constraints, and open questions unless an approved `interview` spec satisfies the Analyst gate. |
| `planner` | Dispatch `planner` subagent to create `Planner draft v1` and any `Planner revision vN`. Planner owns the plan body and feedback disposition. |
| `architect` | Dispatch `architect` subagent to review the exact Planner draft for feasibility, architecture fit, sequencing, and tradeoffs. Architect does not produce a replacement plan. |
| `critic` | Dispatch `critic` subagent to review the exact Planner draft plus matching Architect review only after Architect completes. Critic applies the senior-engineer overcomplication check and may block on speculative abstraction, configurability, dependencies, broad refactors not tied to current acceptance criteria, or accepted feedback that is only logged instead of reflected in the plan body. |

Analyst, Planner, Architect, and Critic remain sequential in that order unless
Analyst is satisfied by an approved `interview` spec. Architect and Critic remain
sequential. Do not run them in parallel.

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
- Architect concerns and disposition.
- Critic verdict and disposition.
- Execution profile.
- Plan approval brief.
- Approval status.
- Recommended next skill for execution.
