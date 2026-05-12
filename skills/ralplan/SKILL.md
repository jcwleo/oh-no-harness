---
name: ralplan
description: Use when broad, risky, architecture-sensitive, cross-file, multi-step, or unclear work needs an implementation plan, execution strategy, sequencing, tradeoff review, or user approval before coding.
argument-hint: "<task, spec path, or plan request>"
---

# Ralplan

Ralplan is the public consensus planning entry point.

It wraps `skills/internal/plan/SKILL.md` and keeps planning separate from execution.

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

1. Read `skills/internal/plan/SKILL.md`.
2. Follow the consensus planning workflow.
3. Ensure Architect completes before Critic begins.
4. Save the plan under `.oh-no/plans/` with a `Next skill: oh-no-harness:<name>` header field.
5. Present the plan to the user with the Plan Approval Brief format below.
6. Mark the plan `pending approval` unless the user explicitly approves execution.
7. After plan approval, run the Next Skill Handoff below to ask which next skill to invoke. Only invoke the chosen skill via the Skill tool after the user answers. Skip the question only when running under `autopilot`.

## Planning Quality Bar

The plan must be concrete enough for `ralph` to execute without inventing scope.

Before presenting the plan, check that it includes:

- explicit in-scope and out-of-scope boundaries
- files, modules, commands, or investigation targets where known
- acceptance criteria that can be verified
- TDD expectations for each behavior-changing task
- sequencing constraints and dependency order
- risks, assumptions, and unresolved questions
- Architect and Critic feedback with disposition: accepted, rejected, deferred, or blocking

Do not hide blocking uncertainty inside assumptions. If an unresolved question changes architecture, product behavior, data handling, security, or delivery scope, mark the plan `pending approval` and ask before execution.

## Plan Approval Brief

After the consensus plan is written, stop and get user confirmation before execution.

Show the user a concise implementation overview, not just the plan path. The brief must include:

- plan path
- goal and scope summary
- text diagram of the implementation structure or flow
- numbered task sequence
- key files or modules affected
- TDD expectations for behavior-changing tasks
- verification commands or evidence plan
- major risks, assumptions, and open questions
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

Do not invoke any next skill until the user has answered. When the user picks one, invoke that skill via the Skill tool with the plan path as the task definition.

### Autopilot exception

If you were invoked from `autopilot`, complete Phase 1 (plan content approval still runs as a content-approval gate), but skip Phase 2's option-list question and return control to autopilot, which will move the workflow to its execute phase.

## Agent Roles

Ralplan uses these roles through `skills/internal/plan/SKILL.md`:

| Agent | Use |
|---|---|
| `explore` | Gather repository facts when codebase context is needed. |
| `analyst` | Identify hidden requirements, risks, constraints, and open questions. |
| `planner` | Draft and revise the implementation plan. |
| `architect` | Review feasibility, architecture fit, sequencing, and tradeoffs. |
| `critic` | Review quality only after Architect completes. |

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
- Consensus status.
- Plan approval brief.
- Approval status.
- Recommended next skill for execution.
