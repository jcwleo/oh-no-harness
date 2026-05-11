---
name: autopilot
description: Use when the user asks for autonomous or end-to-end delivery of a broad goal, feature, fix, project task, or vague request that may span clarification, planning, execution, QA, cleanup, and validation.
argument-hint: "<goal, spec path, plan path, or broad delivery request>"
---

# Autopilot

Autopilot is a written orchestration checklist for moving from idea to verified result with retained Oh No Harness skills.

Each phase is chosen from this Markdown workflow. There is no automatic next-step selector.

## When To Use

Use when:

- the task spans clarification, planning, implementation, and validation
- the user asks for autonomous delivery
- existing specs or plans can drive execution
- the work is too broad for a single direct edit

Do not use when the task is a small concrete fix. Use direct implementation or `ralph` if persistence is needed.

## Artifact Discovery

Before asking new questions, check:

```text
.oh-no/specs/
.oh-no/plans/
```

If a relevant deep-interview spec exists, use it as the clarified requirement and move to planning.

If a relevant consensus plan exists, skip clarification and planning, then move to execution.

Write transient orchestration notes under:

```text
.oh-no/sessions/{sessionId}/autopilot.md
```

## Agent Roles

Autopilot normally reaches most roles by reading and following `deep-interview`, `ralplan`, and `ralph`. When a phase is handled inline on the current platform, preserve these role boundaries:

| Phase | Agents |
|---|---|
| Clarify | `analyst`, `architect`, and `explore` when codebase facts are needed. |
| Plan | `planner`, `architect`, and `critic`; Architect always completes before Critic. |
| Execute | `executor`, with scope and scrutiny chosen from `docs/shared/agent-tiers.md`. |
| QA | `debugger`, `verifier`, and `qa-tester`. |
| Final validation | `architect`, `code-reviewer`, `security-reviewer`, and `qa-tester` when risk requires. |

When inline work can run in parallel, read `docs/shared/parallel-subagents.md` and use the same ownership and integration rules as `ralph`.

## Phases

### Phase 0: Clarify

If the request is vague, read and follow `deep-interview` as the next skill, then resume from the resulting spec.

If the request already has a clear spec, record the spec path and move to planning.

### Phase 1: Plan

Read and follow `ralplan` unless an approved or relevant plan already exists.

The plan remains pending approval unless the user has already approved execution.

### Phase 2: Execute

Read and follow `ralph` with the approved plan or spec.

Execution must preserve Ralph's PRD, verification, review, cleanup, and final report requirements.

If execution is handled inline instead of through `ralph`, apply Ralph's TDD gate before behavior-changing production edits: read and follow `test-driven-development`, record RED/GREEN/REFACTOR evidence, and document any approved exception.

### Phase 3: QA Loop

Run build, lint, test, or scenario checks relevant to the repository.

Use:

- `systematic-debugging` for root-cause investigation before fixes
- `debugger` for failures
- `verifier` for evidence packaging
- `qa-tester` for user-facing flows

Repeat until checks pass or a blocking reason is documented.

### Phase 4: Final Validation

Use the appropriate review set for risk:

- `architect` for architecture-sensitive changes
- `code-reviewer` for correctness and maintainability
- `security-reviewer` for security-sensitive behavior
- `qa-tester` for user-facing behavior

### Phase 5: Report

Before writing the final report, read and follow `verification-before-completion` for the final delivery claim.

Write a final report with:

- spec or plan path
- session directory
- phases completed
- files changed
- commands run
- review and cleanup status
- residual risk

## Vague Request Signals

Start with `deep-interview` when the prompt lacks:

- target files or subsystem
- acceptance criteria
- user or caller impact
- verification command
- constraints
- concrete examples

## Output

Return:

- Active artifact paths.
- Phase status.
- Skills used in order.
- Verification evidence.
- Final result or blocker.
