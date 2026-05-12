---
name: ralplan
description: Use when broad, risky, architecture-sensitive, cross-file, multi-step, or unclear work needs an implementation plan, execution strategy, sequencing, tradeoff review, or user approval before coding.
argument-hint: "<task, spec path, or plan request>"
---

# Ralplan

Ralplan is the public consensus planning entry point.

It owns the consensus planning workflow directly and keeps planning separate from execution.

## Software Development Stage

Ralplan is the design and implementation-planning stage for LLM software development.

Use it after `interview` has produced an approved spec, or when the user already gave a clear but broad engineering task. Ralplan should decide scope, sequencing, file ownership, TDD expectations, verification, rollout, and risk handling before `ralph` executes.

## Goal

Create a concrete implementation plan that survives Analyst, Planner, Architect, and Critic review before execution begins.

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

1. Dispatch `explore` subagent when repository context is needed.
2. Dispatch `analyst` subagent to identify hidden requirements, risks, constraints, and open questions before the planner drafts.
3. Read `docs/shared/execution-modes.md` so the plan can set a required Ralph execution profile.
4. Dispatch `planner` subagent to draft the plan.
5. Dispatch `architect` subagent to review feasibility, sequencing, architecture fit, tradeoffs, execution mode, and antithesis.
6. Dispatch `critic` subagent only after Architect completes.
7. Dispatch `planner` subagent to revise with accepted feedback.
8. Repeat until Critic approves or five complete loops have run.
9. Save the plan under `.oh-no/plans/` with a `Next skill: oh-no-harness:<name>` header field.
10. Present the plan to the user with the Plan Approval Brief format below.
11. Mark the plan `pending approval` unless the user explicitly approves execution.
12. After plan approval, run the Next Skill Handoff below to ask which next skill to invoke. Only invoke the chosen skill through the current platform's skill mechanism after the user answers. Skip the question only when running under `autopilot`.

On platforms without subagent support, or when the user has not authorized subagent dispatch on Codex per `using-oh-no-harness`, perform each role inline and record the exception in the plan.

Architect and Critic are sequential. Do not run them in parallel.

## Planning Quality Bar

The plan must be concrete enough for `ralph` to execute without inventing scope.

Before presenting the plan, check that it includes:

- explicit in-scope and out-of-scope boundaries
- files, modules, commands, or investigation targets where known
- acceptance criteria that can be verified
- TDD expectations for each behavior-changing task
- an `Execution profile` that sets the required overall Ralph mode and task-level modes
- sequencing constraints and dependency order
- risks, assumptions, and unresolved questions
- Architect and Critic feedback with disposition: accepted, rejected, deferred, or blocking

Do not hide blocking uncertainty inside assumptions. If an unresolved question changes architecture, product behavior, data handling, security, or delivery scope, mark the plan `pending approval` and ask before execution.

## Plan File Requirements

Every plan must include:

- a `Next skill: oh-no-harness:<name>` header field naming the recommended next skill (default `oh-no-harness:ralph`)
- goal
- scope and non-goals
- files to create or modify
- task sequence
- acceptance criteria
- execution profile
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
- TDD expectations for behavior-changing tasks
- selected Ralph execution mode and why that mode is enough
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

Execution profile:
Overall Ralph mode: {LIGHT|STANDARD|THOROUGH}
Verification tier: {LIGHT|STANDARD|THOROUGH}
Agent policy: {inline-only|targeted-subagents|full-review-set}
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

Verification:
{commands or evidence plan}

Risks and open questions:
{short list, or "None blocking"}

Execution profile recap:
- Overall Ralph mode: {LIGHT|STANDARD|THOROUGH}
- Why this mode is enough: {one sentence}
- Verification tier: {LIGHT|STANDARD|THOROUGH}
- Agent policy: {inline-only|targeted-subagents|full-review-set}
- Cleanup policy: {not-needed|conditional|required}
- Task sizing: {short task-mode summary}
- Escalation triggers: {short list or "None expected"}

Approval needed:
Choose `ralph`, `autopilot`, request changes, or leave the plan pending.
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
- `oh-no-harness:autopilot` — orchestrate execution, QA, and final validation end-to-end
- request plan changes — go back and revise the plan
- stop with the plan pending approval

End the question with "Which approach?".

Do not invoke any next skill until the user has answered. When the user picks one, invoke that skill through the current platform's skill mechanism with the plan path as the task definition.

### Autopilot exception

If you were invoked from `autopilot`, complete Phase 1 (plan content approval still runs as a content-approval gate), but skip Phase 2's option-list question and return control to autopilot, which will move the workflow to its execute phase.

## Agent Roles

Ralplan uses these roles directly.

This table governs *agent role* dispatch only — workflow-skill chaining (`ralph`, `autopilot`) still goes through `## Next Skill Handoff` HARD-GATE. On Claude Code, dispatch the consensus roles below as separate subagents when the active platform and plan risk call for it. On Codex, follow the `using-oh-no-harness` Codex policy.

| Agent | Dispatch (when) |
|---|---|
| `explore` | Dispatch `explore` subagent to gather repository facts when codebase context is needed. |
| `analyst` | Dispatch `analyst` subagent to identify hidden requirements, risks, constraints, and open questions. |
| `planner` | Dispatch `planner` subagent to draft and revise the implementation plan. |
| `architect` | Dispatch `architect` subagent to review feasibility, architecture fit, sequencing, and tradeoffs. |
| `critic` | Dispatch `critic` subagent to review quality only after Architect completes. |

Architect and Critic remain sequential. Do not run them in parallel.

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
