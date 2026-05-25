---
name: autopilot
description: Use when the user asks for autonomous or end-to-end delivery of a broad goal, feature, fix, project task, or vague request that may span interview, planning, execution, QA, cleanup, and validation.
argument-hint: "<goal, spec path, plan path, or broad delivery request>"
---

# Autopilot

Autopilot is a written orchestration checklist for moving from idea to verified result with retained Oh No Harness skills.

Each phase is chosen explicitly from this Markdown workflow. There is no hidden next-step selector.

## Software Development Stage

Autopilot is the end-to-end orchestration stage for LLM software development.

Use it when one request should drive the full sequence: `interview` for requirements, `ralplan` for planning, `ralph` for execution, QA/debugging, cleanup, final verification, and report.

## When To Use

Use when:

- the task spans interview, planning, implementation, and validation
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

If a relevant interview spec exists, use it as the approved requirement source and move to planning.

If a relevant consensus plan exists, skip interview and planning, then move to execution.

If the existing plan lacks an execution profile, read
`docs/shared/execution-modes.md` and set the missing profile before execution.

Write transient orchestration notes under:

```text
.oh-no/sessions/{sessionId}/autopilot.md
```

## Agent Roles

Autopilot normally reaches most roles by reading and following `interview`, `ralplan`, and `ralph`. Inline phase handling is the fallback, not the default. Dispatch each phase's listed agents as separate subagents on subagent-capable platforms according to Ralph's selected execution mode, `## Mode-Gated Agent Dispatch`, `docs/shared/ralph-subagent-policy.md`, and the host policy in `using-oh-no-harness`. On Claude Code, use the Ralph hook-injected Claude adapter or `docs/platforms/claude-code-ralph.md`, prefer plugin agents such as `oh-no-harness:<agent>`, and use background subagents for independent read-only or review scopes. On Codex, use the Ralph hook-injected Codex adapter or `docs/platforms/codex-ralph.md`, and use `spawn_agent` only when the current host tool definition allows dispatch and the active phase has isolated work that benefits from context-window separation, independent evidence, or latency reduction. Every Codex phase-agent dispatch must embed the matching `agents/<role>.md` prompt content with `Agent prompt source: agents/<role>.md` and `Agent prompt content:`. Explicit user or plan wording is sufficient when the host permits dispatch; natural dispatch is allowed only on hosts whose tool definition permits it. The phase boundaries below still hold either way.

| Phase | Agents |
|---|---|
| Interview | Follow `interview`; dispatch `explore` for brownfield facts when needed. Do not add planning or review agents to this stage. |
| Plan | Follow `ralplan`; dispatch `explore` when context is needed, then complete `analyst` -> `planner` -> `architect` -> `critic` in that order. Architect always completes before Critic. The plan must set the Ralph execution profile and include the four role outputs or inline role blocks. |
| Execute | Follow `ralph`; dispatch or inline `explore`, `executor`, `verifier`, and review agents according to the approved execution mode, plan, platform policy, and risk. |
| QA Loop | Dispatch `debugger`, `verifier`, and `qa-tester`; use `systematic-debugging` before fixes. |
| Final Validation | Dispatch `architect`, `code-reviewer`, `security-reviewer`, and `qa-tester` when risk requires; finish through `verification-before-completion`. |

When inline work can run in parallel, read `docs/shared/parallel-subagents.md` and use the same ownership and integration rules as `ralph`. If the user invoked autopilot with `parallel`, `subagents`, `spawn`, `delegate`, or `one agent per` language, preserve that phrase in the Ralph handoff as an explicit dispatch signal. If the plan selects natural dispatch instead, preserve `Parallel trigger: natural-dispatch` in the Ralph handoff only on hosts whose tool definition permits natural dispatch.

## Phases

### Phase 0: Interview

If the request is vague, read and follow `interview` as the next skill, then resume from the resulting spec.

If the request already has a clear spec, record the spec path and move to planning.

### Phase 1: Plan

Read and follow `ralplan` unless an approved or relevant plan already exists.

The plan remains pending approval unless the user has already approved execution.

### Phase 2: Execute

Read and follow `ralph` with the approved plan or spec.

Execution must preserve Ralph's selected execution mode, PRD or compact artifact policy, verification, review, cleanup, and final report requirements.

If execution is handled inline instead of through `ralph`, first read `docs/shared/execution-modes.md`, set the required `LIGHT`, `STANDARD`, or `THOROUGH` execution mode, then apply Ralph's mode-gated loop. Apply Ralph's TDD gate before behavior-changing production edits: read and follow `test-driven-development`, record RED/GREEN/REFACTOR evidence, and document any approved exception.

## Automatic Worktree Execution

For write-capable execution, read and follow
`docs/shared/worktree-isolation.md`. Autopilot does not ask the one-time direct
Ralph worktree question because the user has delegated end-to-end orchestration.

Before editing files, Autopilot must:

1. Create or select a task worktree.
2. Record `Worktree decision: autopilot automatic worktree`.
3. Preserve access to the approved `.oh-no` spec, plan, or PRD in the task
   worktree by copying the relevant artifact, recording an absolute artifact
   path, or quoting the approved task definition.

After the implementation passes verification in the task worktree, Autopilot
must merge the completed work into the integration checkout, run post-merge
verification, and record whether the worktree was cleaned up or left for
inspection.

If worktree creation, merge, or post-merge verification fails, report the blocker
instead of silently editing the original checkout.

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
- execution mode and mode source
- Worktree decision, integration checkout, post-merge verification, and cleanup
  status
- phases completed
- files changed
- commands run
- review and cleanup status
- residual risk

## Vague Request Signals

Start with `interview` when the prompt lacks:

- target files or subsystem
- acceptance criteria
- user or caller impact
- verification command
- constraints
- concrete examples

## Autopilot Exception

Autopilot is the only context that may invoke `interview`, `ralplan`, or `ralph` without the per-step transition question those skills normally require. The user opted into orchestration when they invoked autopilot, so each phase boundary moves automatically once the prior phase's content gate is satisfied.

Content-approval gates inside the sub-skills still run:

- `interview` still has the user review the spec.
- `ralplan` still has the user approve the plan.
- `ralph` still runs `verification-before-completion` before any final completion claim.

What autopilot skips is only the "which next skill?" question between phases. It does not skip content review, plan approval, verification, or final evidence gates.

Under autopilot, content gates pause the workflow and forward the sub-skill's user-facing review request verbatim — `interview`'s Phase 1 spec review and `ralplan`'s Plan Approval Brief both surface to the user as written. Autopilot does not auto-approve, paraphrase, or revise on the user's behalf. It advances to the next phase only after the user explicitly approves the spec, plan, or final-evidence claim.

If the user invokes `interview`, `ralplan`, or `ralph` directly without going through autopilot, the per-step Next Skill Handoff in those skills is required.

## Output

Return:

- Active artifact paths.
- Phase status.
- Skills used in order.
- Verification evidence.
- Final result or blocker.
