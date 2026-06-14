---
name: ultrawork
description: Use when the user asks for autonomous or end-to-end delivery of a broad goal, feature, fix, project task, or vague request that may span interview, planning, execution, QA, cleanup, and validation.
argument-hint: "<goal, spec path, plan path, or broad delivery request>"
---

# Ultrawork

Ultrawork is a Markdown-first loop-engineering workflow for moving from idea to
verified result with retained Oh No Harness skills.

Each phase is chosen explicitly from this Markdown workflow. There is no hidden next-step selector.

## Software Development Stage

Ultrawork is the end-to-end orchestration stage for LLM software development.

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
.oh-no/sessions/{sessionId}/ultrawork.md
```

## Loop Contract

Ultrawork is the foreground orchestration loop around the existing skill chain.
It does not replace `ralplan` or `ralph`: the planning gate uses `ralplan`, and
the execution handoff uses `ralph`.

Loop phases:

```text
start_or_resume
  -> requirements_gate
  -> planning_gate
  -> worktree_gate
  -> execution_handoff
  -> qa_loop
  -> final_validation
  -> report
```

- Existing approved specs or plans may skip earlier phases only when the skip
  reason and source artifact are recorded.
- Every path to `worktree_gate` or `execution_handoff` must first create or
  confirm an execution profile. Source edits are blocked until the profile
  exists and is recorded in the Ultrawork state.
- Any scope change, missing authority artifact, failed worktree gate, or failed
  verification transitions to `paused` or `blocked`, not silent continuation.
- QA failures transition to `systematic-debugging`, then back to
  `execution_handoff` or `final_validation` only after root-cause evidence.

Heartbeat contents:

- Heartbeat id, timestamp or sequence number, phase, active goal or story,
  authoritative state path, last completed checkpoint, next intended action,
  blocker/status, worktree state, verification state, checker state, and
  stop-condition state.
- Cadence: phase entry, phase exit, before and after long tool or subagent
  waits, before compaction or handoff, after user input that changes scope, and
  before the final report.
- No timer, daemon, or background heartbeat.

Resume precedence:

1. Newest user instruction, pause, cancel, or scope change.
2. Authoritative Markdown state at `.oh-no/sessions/{sessionId}/ultrawork.md`.
3. Approved spec or plan paths referenced by that Markdown state.
4. Ralph session artifacts referenced by that state.
5. Git worktree, branch, merge, and verification evidence.
6. Logs, apps, metrics, or host connector data as evidence only, never state
   authority.
7. On conflict, doctor/status records the mismatch and pauses before editing or
   merging.

State authority:

- Markdown at `.oh-no/sessions/{sessionId}/ultrawork.md` is authoritative for v1.
- No JSON state artifact in v1.
- If JSON is ever added later, it must be derived and non-authoritative;
  mismatch recovery regenerates JSON from Markdown or pauses.

Doctor/status gate semantics:

- Runs at entry, resume, pre-execution, pre-merge, and pre-final.
- Outputs `PASS`, `WARN`, or `BLOCKED`.
- Checks missing or stale artifacts, invalid worktree, unmerged worktree,
  missing verification, stale README/docs against behavior, custom-agent
  readiness, and validator drift.
- `BLOCKED` stops before edits, merge, or final claim. `WARN` may continue only
  when acceptance evidence is unaffected.

Checker outputs:

- Every checker records role, reviewed artifact or diff, findings, acceptance
  evidence status, required follow-up, verdict when applicable,
  fallback/dispatch mode, and lifecycle cleanup status.
- Maker roles do not self-approve. Inline checker fallback must still be
  labeled as checker output.

Escalation rules:

- Ambiguous requirements -> user or `interview`.
- Direction or scope conflict -> user or `ralplan`.
- Failing checks or unknown root cause -> `systematic-debugging`.
- Public contract, security, or packaging risk -> `plan-reviewer`,
  `code-reviewer`, or `verifier`.
- Missing worktree or verification evidence -> `blocked` until resolved.

Terminal states:

- `succeeded_merged_verified_reported`
- `succeeded_left_worktree_for_inspection`
- `paused_for_user`
- `blocked`
- `cancelled`
- `failed_verification`
- `scope_change_pending_approval`

## Agent Roles

Ultrawork normally reaches most roles by reading and following `interview`,
`ralplan`, and `ralph`. Inline phase handling is the fallback, not the default.
Dispatch each phase's listed agents as separate subagents on subagent-capable
platforms according to Ralph's selected execution mode, `## Mode-Gated Agent
Dispatch`, `docs/shared/ralph-subagent-policy.md`, and the host policy from the
active platform wrapper. For the `ralplan` phase, Planner and Plan-Reviewer
are sequential but must still run as separate subagents when the active host
supports dispatch so each role keeps independent context. Plan-Reviewer runs as
a single review dispatch; re-review only when blocking findings require it. The
phase boundaries below still hold either way.

On Codex, when SessionStart injects
`CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION`, treat that block as the
standing explicit user request for eligible Ultrawork phase agents without
per-run subagent approval. Do not pause Ultrawork only to ask whether subagents
may be used. Apply the authorization to the phase-owned roles below:
`interview`/`explore` for brownfield facts, `ralplan` planning roles, `ralph`
execution and review roles, QA Loop roles, and Final Validation roles. Preserve
all content gates, spec review, plan approval, final evidence, role isolation,
fallback reasons, and lifecycle cleanup requirements.

| Phase | Agents |
|---|---|
| Interview | Follow `interview`; dispatch `explore` for brownfield facts when needed. Do not add planning or review agents to this stage. |
| Plan | Follow `ralplan`; dispatch `explore` when context is needed, then complete `analyst` -> `planner` -> `plan-reviewer` in that order. The plan must set the Ralph execution profile and include the three role outputs or inline role blocks. |
| Execute | Follow `ralph`; dispatch isolated `explore`, `executor`, `verifier`, and review agents according to the approved execution mode, plan, platform policy, and risk; inline only for documented subagent-unavailable or unsafe-to-isolate cases. |
| QA Loop | Dispatch `debugger` and `verifier` (scenario lens for user-facing flows); use `systematic-debugging` before fixes. |
| Final Validation | Dispatch `plan-reviewer`, `code-reviewer` (security lens included), and `verifier` (scenario lens) when risk requires; finish through `verification-before-completion`. |

When independent delegated phase work can run in parallel, or when inline
fallback role blocks need the same isolation plan, read
`docs/shared/ralph-subagent-policy.md`; `docs/shared/parallel-subagents.md` is
only a short pointer back to that policy.
Use the same ownership and integration rules as `ralph`. If the approved plan
selects `Parallel trigger: approved-plan-handoff`, preserve that trigger in the
Ralph handoff and treat it as the default parallel-capable execution path. If
the user invoked ultrawork with `parallel`, `subagents`, `spawn`, `delegate`, or
`one agent per` language outside an approved plan profile, preserve that phrase
as an explicit dispatch signal. Preserve `Parallel trigger: natural-dispatch`
only for direct Ralph execution when the host permits proactive dispatch and the
active skill policy itself authorizes eligible isolated roles.

## Execution Profile Gate

Ultrawork must create or confirm an execution profile before any write-capable
execution, worktree creation for execution, source edit, or `ralph` handoff.
This gate applies even when the starting request is concrete enough to skip
interview questions or when execution will be handled inline instead of through
the public `ralph` wrapper.

Valid profile sources:

1. An approved `ralplan` plan with the full `Execution profile` fields from
   `docs/shared/execution-modes.md`.
2. A relevant existing plan whose missing profile is completed by reading
   `docs/shared/execution-modes.md` and recording the derived profile before
   execution.
3. A direct-execution sizing pass for a concrete task, produced by reading
   `docs/shared/execution-modes.md`, answering the Execution Mode Decision
   Prompt, and recording `Mode source: derived by Ultrawork`.

The recorded profile must include overall Ralph mode, verification tier,
artifact policy, agent policy, parallel trigger, worktree policy and location,
cleanup policy, task sizing, and escalation triggers. If any required field is
missing, the doctor/status gate is `BLOCKED`; do not continue by treating
`ultrawork` itself as an implicit execution mode.

## Automatic Worktree Execution

For write-capable execution, read and follow
`docs/shared/worktree-isolation.md`. Ultrawork's distinct responsibility is
end-to-end orchestration: it uses a registered Git worktree under
`.oh-no/worktrees/<task-slug>` automatically and then merges the completed work
back into the integration checkout. `git clone`, `cp -R`, and plain directories
are not valid substitutes.

Before editing files, Ultrawork must:

1. Create or select a registered Git worktree under
   `.oh-no/worktrees/<task-slug>` using `git worktree add`.
2. Record `Worktree decision: ultrawork automatic worktree`.
3. Preserve access to the approved `.oh-no` spec, plan, or PRD in the task
   worktree by copying the relevant artifact, recording an absolute artifact
   path, or quoting the approved task definition.

After the implementation passes verification in the task worktree, Ultrawork
must merge the completed work into the integration checkout, run post-merge
verification, and record whether the worktree was cleaned up or left for
inspection.

If worktree creation, merge, or post-merge verification fails, report the blocker
instead of silently editing the original checkout.

## Phases

### Phase 0: Interview

If the request is vague, read and follow `interview` as the next skill, then resume from the resulting spec.

If the request already has a clear spec, record the spec path and move to planning.

Interview is the only user-facing content approval gate for new Ultrawork work.
Before leaving this phase, make sure the requirements source is explicit: either
the user approved the interview spec, an existing approved spec or plan was
found, or the original request is already concrete enough to plan without
inventing product intent.

### Phase 1: Plan

Read and follow `ralplan` unless an approved or relevant plan already exists or
the task is concrete enough for direct execution. Regardless of route, complete
the `## Execution Profile Gate` before leaving this phase.

Inside Ultrawork, the `ralplan` plan is automatically approved for execution
once the plan satisfies Ralplan's consensus, direction-preservation, execution
profile, and test-quality gates. Record
`Plan approval source: ultrawork automatic approval after interview/spec`.
Do not pause for a separate Plan Approval Brief after the requirements source is
approved or already concrete. Pause only on a pause condition: changed approved
scope, a blocking product decision or blocking ambiguity, conflict with the
approved requirements source (for example the interview spec), a missing
execution profile, or an explicit user request to review the plan manually.

### Phase 2: Execute

Before execution, confirm that the Ultrawork state contains a complete execution
profile from `## Execution Profile Gate`. If it does not, return to Phase 1 or
record `blocked: missing execution profile`; do not edit files, create an
execution worktree, or run inline implementation.

Read and follow `ralph` with the Ultrawork-approved plan or spec. Treat the
ordinary `ralph` execution handoff as approved by Ultrawork; do not ask the user
for a second implementation approval after Phase 1 unless a pause condition from
the planning phase was triggered.

Execution must preserve Ralph's selected execution mode, PRD or compact artifact policy, verification, review, cleanup, and final report requirements.

If execution is handled inline instead of through `ralph`, first read `docs/shared/execution-modes.md`, set the required `LIGHT`, `STANDARD`, or `THOROUGH` execution mode, then apply Ralph's mode-gated loop. Apply Ralph's TDD gate before behavior-changing production edits: read and follow `test-driven-development`, record RED/GREEN/REFACTOR evidence, and document any approved exception.

### Phase 3: QA Loop

Run build, lint, test, or scenario checks relevant to the repository.

Dispatch:

- `systematic-debugging` (skill, not agent) for root-cause investigation before fixes
- `debugger` subagent for failures
- `verifier` subagent for evidence packaging and, via its scenario lens,
  user-facing flows

Repeat until checks pass or a blocking reason is documented.

### Phase 4: Final Validation

Dispatch the appropriate review subagents for the risk:

- `plan-reviewer` for architecture-sensitive changes
- `code-reviewer` for correctness and maintainability, with its security lens
  for security-sensitive behavior
- `verifier` with its scenario lens for user-facing behavior

### Phase 5: Report

Before writing the final report, read and follow `verification-before-completion` for the final delivery claim.

Write a final report with:

- spec or plan path
- session directory
- execution mode and mode source
- execution profile source and required fields from
  `docs/shared/execution-modes.md`
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

## Ultrawork Exception

Ultrawork is the only context that may invoke `interview`, `ralplan`, or `ralph` without the per-step transition question those skills normally require. The user opted into orchestration when they invoked ultrawork, so each phase boundary moves automatically once the prior phase's content gate is satisfied.

Content gates inside the sub-skills still run, but Ultrawork owns the approval
handling after requirements are clear:

- `interview` still has the user review the spec when the request is vague or
  product intent is missing. Ultrawork does not auto-approve the interview spec.
- After the user approves the interview spec, or when the starting request is
  already concrete enough to plan, Ultrawork automatically approves `ralplan`
  output that satisfies the required planning gates and includes a complete
  execution profile.
- Ultrawork then automatically invokes `ralph` with that Ultrawork-approved
  plan or spec and treats the implementation handoff as approved.
- `ralph` still runs `verification-before-completion` before any final
  completion claim, but that final evidence gate is verification, not a new
  user approval prompt.

Ultrawork skips the "which next skill?" question between phases and the separate
`ralplan` plan-approval prompt after requirements are approved. It does not skip
interview/spec approval when requirements are unclear, planning quality gates,
scope-change pauses, verification, or final evidence.

Under ultrawork, `interview`'s Phase 1 spec review still surfaces to the user
when an interview was needed. `ralplan`'s Plan Approval Brief is converted into
an internal execution record unless it reveals a pause condition: changed
approved scope, a blocking product decision or blocking ambiguity, conflict
with the approved requirements source (for example the interview spec), a
missing execution profile, or an explicit user request to review the plan
manually.
When no pause condition exists, record the plan approval source and continue
directly into `ralph`.

If Ultrawork skips `ralplan` because the task is already concrete enough for
direct execution, it still must record `Mode source: derived by Ultrawork` with
the full execution profile before Phase 2.

If the user invokes `interview`, `ralplan`, or `ralph` directly without going through ultrawork, the per-step Next Skill Handoff in those skills is required.

## Output

Return:

- Active artifact paths.
- Phase status.
- Skills used in order.
- Execution profile source, mode, verification tier, agent policy, worktree
  policy, cleanup policy, task sizing, and escalation triggers.
- Verification evidence.
- Final result or blocker.
