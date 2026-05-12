---
name: autopilot
description: Use when the user asks for autonomous or end-to-end delivery of a broad goal, feature, fix, project task, or vague request that may span deep-interview, planning, execution, QA, cleanup, and validation.
argument-hint: "<goal, spec path, plan path, or broad delivery request>"
---

# Autopilot

Autopilot is a written orchestration checklist for moving from idea to verified result with retained Oh No Harness skills.

Each phase is chosen explicitly from this Markdown workflow. There is no hidden next-step selector.

## Software Development Stage

Autopilot is the end-to-end orchestration stage for LLM software development.

Use it when one request should drive the full sequence: `deep-interview` for requirements, `ralplan` for planning, `ralph` for execution, QA/debugging, cleanup, final verification, and report.

## When To Use

Use when:

- the task spans deep-interview, planning, implementation, and validation
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

If a relevant deep-interview spec exists, use it as the approved requirement source and move to planning.

If a relevant consensus plan exists, skip deep-interview and planning, then move to execution.

Write transient orchestration notes under:

```text
.oh-no/sessions/{sessionId}/autopilot.md
```

## Agent Roles

Autopilot normally reaches most roles by reading and following `deep-interview`, `ralplan`, and `ralph`. Inline phase handling is the fallback, not the default. Dispatch each phase's listed agents as separate subagents on subagent-capable platforms (Claude Code Task tool, Codex `spawn_agent` when authorized per `using-oh-no-harness`), per `ralph`'s `## Subagent Dispatch Default`. The phase boundaries below still hold either way.

| Phase | Agents |
|---|---|
| Deep Interview | Follow `deep-interview`; dispatch `explore` for brownfield facts when needed. Do not add planning or review agents to this stage. |
| Plan | Follow `ralplan`; dispatch `explore` when context is needed, then `analyst`, `planner`, `architect`, and `critic`. Architect always completes before Critic. |
| Execute | Follow `ralph`; dispatch `explore`, `executor`, `verifier`, and review agents according to the approved plan and risk. |
| QA Loop | Dispatch `debugger`, `verifier`, and `qa-tester`; use `systematic-debugging` before fixes. |
| Final Validation | Dispatch `architect`, `code-reviewer`, `security-reviewer`, and `qa-tester` when risk requires; finish through `verification-before-completion`. |

When inline work can run in parallel, read `docs/shared/parallel-subagents.md` and use the same ownership and integration rules as `ralph`.

## Phases

### Phase 0: Deep Interview

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

Dispatch:

- `systematic-debugging` (skill, not agent) for root-cause investigation before fixes
- `debugger` subagent for failures
- `verifier` subagent for evidence packaging
- `qa-tester` subagent for user-facing flows

Repeat until checks pass or a blocking reason is documented.

### Phase 4: Final Validation

Dispatch the appropriate review subagents for the risk:

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

## Autopilot Exception

Autopilot is the only context that may invoke `deep-interview`, `ralplan`, or `ralph` without the per-step transition question those skills normally require. The user opted into orchestration when they invoked autopilot, so each phase boundary moves automatically once the prior phase's content gate is satisfied.

Content-approval gates inside the sub-skills still run:

- `deep-interview` still has the user review the spec.
- `ralplan` still has the user approve the plan.
- `ralph` still runs `verification-before-completion` before any final completion claim.

What autopilot skips is only the "which next skill?" question between phases. It does not skip content review, plan approval, verification, or final evidence gates.

If the user invokes `deep-interview`, `ralplan`, or `ralph` directly without going through autopilot, the per-step Next Skill Handoff in those skills is required.

## Output

Return:

- Active artifact paths.
- Phase status.
- Skills used in order.
- Verification evidence.
- Final result or blocker.
