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

_Verbs in this table are descriptive; the Consensus Loop below is the dispatch-driving contract._

<!-- keep verbs descriptive; the Consensus Loop drives dispatch. see scripts/validate-plugin-files.py DISPATCH_DEFAULT_REQUIRED. -->

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

1. Dispatch `explore` subagent when repository context is needed.
2. Dispatch `analyst` subagent to identify hidden requirements, risks, constraints, and open questions.
3. Dispatch `planner` subagent to draft the plan.
4. Dispatch `architect` subagent to review feasibility, sequencing, architecture fit, tradeoffs, and antithesis.
5. Dispatch `critic` subagent only after Architect completes.
6. Dispatch `planner` subagent to revise with accepted feedback.
7. Repeat until Critic approves or five complete loops have run.
8. Output the final plan as `pending approval` unless the user has already explicitly approved execution.

On platforms without subagent support, or when the user has not authorized subagent dispatch on Codex per `using-oh-no-harness`, perform each role inline and record the exception in the plan.

Architect and Critic are sequential. Do not run them in parallel.

## Plan Requirements

Every plan must include:

- a `Next skill: oh-no-harness:<name>` header field naming the recommended next skill (default `oh-no-harness:ralph`)
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

After approval, follow `ralplan`'s Next Skill Handoff: ask the user which next skill to invoke (recommended `ralph`, alternative `autopilot`, request plan changes, or stop). Do not invoke any next skill until the user answers. The autopilot exception applies the same way as in `ralplan`: when invoked from `autopilot`, skip the per-step question and return control to autopilot.

Do not implement directly from this internal planning skill unless the user explicitly changes the task scope.

## Output

Return:

- Plan path.
- Consensus loop summary.
- Architect concerns and disposition.
- Critic verdict and disposition.
- Approval status.
- Recommended next skill.
