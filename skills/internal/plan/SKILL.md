---
name: internal-plan
description: Use when ralplan needs its internal consensus planning workflow.
user-invocable: false
---

# Internal Consensus Plan

This is the internal planning workflow behind `ralplan`. Prefer using `ralplan` directly unless you are maintaining Oh No Harness itself.

## Goal

Create a concrete implementation plan that survives Analyst, Planner, Architect, and Critic review before execution begins.

## Agent Roles

| Agent | Use |
|---|---|
| `explore` | Gather codebase facts, relevant files, commands, and constraints. |
| `analyst` | Identify hidden requirements, risks, stakeholders, and open questions. |
| `planner` | Draft the initial plan and revise it after review. |
| `architect` | Check feasibility, architecture fit, sequencing, antithesis, and tradeoffs. |
| `critic` | Gate plan quality after Architect completes. |

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

## Consensus Loop

1. Use `explore` when repository context is needed.
2. Use `analyst` to identify hidden requirements, risks, constraints, and open questions.
3. Use `planner` to draft the plan.
4. Use `architect` to review feasibility, sequencing, architecture fit, tradeoffs, and antithesis.
5. Use `critic` only after Architect completes.
6. Use `planner` to revise with accepted feedback.
7. Repeat until Critic approves or five complete loops have run.
8. Output the final plan as `pending approval` unless the user has already explicitly approved execution.

Architect and Critic are sequential. Do not run them in parallel.

## Plan Requirements

Every plan must include:

- goal
- scope and non-goals
- files to create or modify
- task sequence
- acceptance criteria
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

## Approval

Without explicit user approval, planning stops with a pending plan.

After approval, use one of these next skills:

- `ralph` for concrete execution with verification and cleanup
- `autopilot` for larger end-to-end orchestration

Do not implement directly from this internal planning skill unless the user explicitly changes the task scope.

## Output

Return:

- Plan path.
- Consensus loop summary.
- Architect concerns and disposition.
- Critic verdict and disposition.
- Approval status.
- Recommended next skill.
