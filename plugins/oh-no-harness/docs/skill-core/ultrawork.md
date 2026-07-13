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

Do not use when the task is a small concrete fix whose contract surface,
baseline or smoke evidence, and verification command are already clear. Use
direct implementation or `ralph` if persistence is needed.

## Required Reading

Read always-active owners before execution and triggered owners immediately
before their dependent gates. A path reference here is a pointer, not a
substitute for reading. If a listed file cannot be read, record the blocker
instead of proceeding past the gate that depends on it.

| Contract | Class | Trigger / timing |
|---|---|---|
| `docs/shared/execution-modes.md` | always | before carrying the Direction Contract and execution profile |
| `docs/shared/worktree-isolation.md` | always | before automatic worktree execution |
| `docs/shared/ralph-subagent-policy.md` | triggered | before phase-agent dispatch or maker-verifier independence |
| `docs/shared/cross-host-review.md` | triggered | only when a named THOROUGH risk selects paired Final Validation review |

## Artifact Discovery

Before asking new questions, check:

```text
.oh-no/specs/
.oh-no/plans/
```

If a relevant approved interview spec exists, use it as the approved requirement source and move to planning.

Carry its Direction Contract and AC IDs unchanged through the plan, Ralph
session, review/verifier packets, and final report. Each phase records only its
delta and evidence; it must not reinterpret the primary goal, non-goals,
constraints, or protected assumptions. A phase that needs a direction change
pauses for explicit user approval.

If a relevant consensus plan exists, it may skip interview and planning only when it is approved (explicit user approval of its Plan Approval Brief, or a recorded ultrawork automatic-approval source from a prior run — a passing Findings Ledger Gate alone is quality evidence, not approval) and matches the current request's scope; record the skip reason and source artifact path per the Loop Contract, then move to execution. A merely relevant plan without approval evidence or with mismatched scope goes through the planning gate instead.

If the existing plan lacks an execution profile, read
`docs/shared/execution-modes.md` and set the missing profile before execution.

Write transient orchestration notes under:

```text
.oh-no/sessions/{sessionId}/ultrawork.md
```

Ultrawork establishes the chain session directory at `start_or_resume`;
downstream skills in the same run reuse it.

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
- Any scope change, missing authority artifact, failed worktree gate, or failed
  verification transitions to `paused_for_user`, `scope_change_pending_approval`,
  or `blocked`, not silent continuation.
- QA failures transition to `systematic-debugging`, then back to
  `execution_handoff` or `final_validation` only after root-cause evidence.

Heartbeat contents:

- Record phase, goal/story, authoritative state path, last checkpoint, next
  action, blocker/status, worktree, verification, checker, and stop condition.
- Write a heartbeat at phase boundaries, long waits, compaction/handoff, scope
  changes, and before the final report. No timer, daemon, or background
  heartbeat.

Resume precedence:

Newest user instructions outrank saved state. After that, trust the
authoritative Markdown state at `.oh-no/sessions/{sessionId}/ultrawork.md`, its
referenced specs/plans and Ralph artifacts, then Git worktree/merge evidence.
Logs, apps, metrics, and connector data are evidence only. On conflict,
doctor/status records the mismatch and pauses before editing or merging.

State authority:

- Markdown at `.oh-no/sessions/{sessionId}/ultrawork.md` is authoritative for v1.
- No JSON state artifact in v1; any future JSON must be derived and
  non-authoritative.

Doctor/status gate semantics:

- Run at entry, resume, pre-execution, pre-merge, and pre-final.
- Output `PASS`, `WARN`, or `BLOCKED` after checking artifact freshness,
  worktree/merge state, verification, stale docs, custom-agent readiness, and
  validator drift.
- `BLOCKED` stops before edits, merge, or final claim. `WARN` may continue only
  when acceptance evidence is unaffected.

Checker outputs:

- Record role, reviewed artifact or diff, findings, evidence status, follow-up,
  verdict when applicable, dispatch/fallback mode, and lifecycle status.
- Maker roles do not self-approve; inline checker fallback is still checker
  output. At STANDARD and THOROUGH on subagent-capable hosts, an inline check by
  the maker, or by the agent that accepted the maker's output, does not satisfy
  the independent verifier audit under the carve-out in
  `docs/shared/ralph-subagent-policy.md`; dispatch an independent `verifier`.

Escalation rules:

- Ambiguous requirements -> user or `interview`.
- Direction or scope conflict -> user or `ralplan`.
- Failing checks or unknown root cause -> `systematic-debugging`.
- Public contract, security, or packaging execution risk -> `code-reviewer` or
  `verifier`; a plan-direction conflict routes back through `ralplan`.
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
active platform runtime document. For the `ralplan` phase, Planner and
Plan-Reviewer are sequential and should keep separate role contexts; dispatch
them as subagents when the active host supports dispatch and the separation can
improve planning or review quality. Plan-Reviewer runs as a single review dispatch;
re-review only when blocking findings require it. The phase boundaries below
still hold either way.

Apply the active platform's dispatch authorization for eligible Ultrawork phase
agents without per-run subagent approval when that standing authorization is
present. Do not pause Ultrawork only to ask whether subagents may be used. Apply
the authorization to the phase-owned roles below: `interview`/`explore` for
brownfield facts, `ralplan` planning roles, `ralph` execution and review roles,
QA Loop roles, and Final Validation roles. Preserve all content gates, spec
review, Ultrawork's internal plan approval record, final evidence, role
isolation, fallback reasons, and lifecycle cleanup requirements.
Eligibility still depends on whether the role can change quality, risk,
latency, or context management enough to justify dispatch; final narrow
re-checks may stay inline when they have equal evidence. This inline allowance
does not extend to the independent verifier audit under the carve-out in
`docs/shared/ralph-subagent-policy.md`: at STANDARD and THOROUGH on
subagent-capable hosts, when the proving tests or implementation were authored
or accepted by the same agent, that audit is not inline-eligible and must be
dispatched to an independent `verifier` (record the fallback reason if the host
cannot dispatch).

| Phase | Agents |
|---|---|
| Interview | Follow `interview`; dispatch `explore` for brownfield facts when needed. Do not add planning or review agents to this stage. |
| Plan | Follow `ralplan`; dispatch `explore` when context is needed, then complete `analyst` -> `planner` and the risk-gated Plan-Reviewer stage in order. STANDARD uses one reviewer; a pair requires a named THOROUGH risk. |
| Execute | Follow `ralph`; dispatch isolated `explore`, `executor`, `verifier`, and review agents according to the approved execution mode, plan, platform policy, and risk; inline only for documented subagent-unavailable or unsafe-to-isolate cases. |
| QA Loop | Follow `systematic-debugging` for failure investigation; it owns `debugger` dispatch per its own contract. Dispatch `verifier` (scenario lens for user-facing flows). |
| Final Validation | Add one targeted `code-reviewer` only for additional orchestration risk not already covered by Ralph. Paired review requires a named THOROUGH trigger. Dispatch one independent `verifier` when the maker-verifier carve-out applies. |

When independent delegated phase work can run in parallel, or when inline
fallback role blocks need the same isolation plan, read
`docs/shared/ralph-subagent-policy.md`.
Use the same ownership and integration rules as `ralph`. If the approved plan
selects `Parallel trigger: approved-plan-handoff`, preserve that trigger in the
Ralph handoff and treat it as the parallel-capable execution path for eligible
isolated roles. If
the user invoked ultrawork with `parallel`, `subagents`, `spawn`, `delegate`, or
`one agent per` language outside an approved plan profile, preserve that phrase
as an explicit dispatch signal. Preserve `Parallel trigger: natural-dispatch`
only for direct Ralph execution when the host permits proactive dispatch and the
active skill policy itself authorizes eligible isolated roles.

## Automatic Worktree Execution

For write-capable execution, read and follow
`docs/shared/worktree-isolation.md`. Ultrawork's distinct responsibility is
end-to-end orchestration: it uses a registered Git worktree under
`.oh-no/worktrees/<task-slug>` automatically and then merges the completed work
back into the integration checkout. `git clone`, `cp -R`, and plain directories
are not valid substitutes.

worktree_gate: no source file edit until a `Worktree decision` is recorded per `docs/shared/worktree-isolation.md` (the canonical gate lives in that shared doc; the numbered steps below are Ultrawork's own responsibilities under it).

Before editing files, Ultrawork must:

1. Create or select a registered Git worktree under
   `.oh-no/worktrees/<task-slug>` using `git worktree add`.
2. Record `Worktree decision: ultrawork automatic worktree`.
3. Preserve access to the approved `.oh-no` spec, plan, or PRD in the task
   worktree by copying the relevant artifact, recording an absolute artifact
   path, or quoting the approved task definition.

After the implementation passes verification in the task worktree, Ultrawork must
merge it back into the integration checkout, run post-merge verification, and
record cleanup-or-left-for-inspection, per `docs/shared/worktree-isolation.md`. If
worktree creation, merge, or post-merge verification fails, report the blocker
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

requirements_gate: planning must not start until the requirements source is recorded.

### Phase 1: Plan

Read and follow `ralplan` unless an approved plan already exists per the
Artifact Discovery approval-evidence rule.

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

Read and follow `ralph` with the Ultrawork-approved plan or spec. Treat the
ordinary `ralph` execution handoff as approved by Ultrawork; do not ask the user
for a second implementation approval after Phase 1 unless a pause condition from
the planning phase was triggered.

Execution must preserve Ralph's selected execution mode, PRD or compact artifact policy, verification, review, cleanup, and final report requirements.

Inline execution is a documented fallback, permitted only when the host cannot
load or execute the `ralph` skill; record that fallback reason in the session
ledger (an explicit user instruction always overrides). When executing
inline under that fallback, first read `docs/shared/execution-modes.md`, set
the required `LIGHT`, `STANDARD`, or `THOROUGH` execution mode, then apply
Ralph's mode-gated loop. Apply Ralph's TDD gate before behavior-changing
production edits: read and follow `test-driven-development`, record
RED/GREEN/REFACTOR evidence, and document any approved exception.

### Phase 3: QA Loop

When Phase 2 executes through `ralph`, Ralph owns story-level verification,
mode-gated review, cleanup, and `verification-before-completion`. Ultrawork's
QA loop is the orchestration-level layer around that result: investigate failed
commands, integration problems, merge problems, or scenario gaps that remain
after Ralph's task-worktree evidence.

Run build, lint, test, or scenario checks relevant to the repository when they
are needed to validate the orchestrated result, especially after worktree
integration or when Ralph reports a blocker.

Dispatch:

- `systematic-debugging` (skill, not agent) for root-cause investigation of
  failures before fixes; it owns `debugger` dispatch per its own contract
  (one STANDARD debugger, or a named THOROUGH pair, plus its hypothesis ledger)
  — do not dispatch a raw `debugger` outside that flow
- `verifier` subagent for evidence packaging and, via its scenario lens,
  user-facing flows

Repeat until checks pass or a blocking reason is documented.

### Phase 4: Final Validation

Final Validation does not repeat Ralph's required internal gates when Ralph has
already completed them. Dispatch the additional orchestration-level review
subagents warranted by integration, merge, public-contract, security, or
cross-phase risk, and — at STANDARD and THOROUGH on subagent-capable hosts —
always dispatch an independent `verifier` when execution produced or changed
proving tests or the implementation/tests were authored or accepted by the same
agent, regardless of extra orchestration risk (record the fallback reason if the
host cannot dispatch):

- `code-reviewer` for execution correctness, maintainability, regression risk,
  and architecture-sensitive implementation concerns, with its security lens
  for security-sensitive behavior
- `verifier`: required as an independent pass (acceptance-to-evidence mapping +
  adversarial test-genuineness audit) under the carve-out in
  `docs/shared/ralph-subagent-policy.md` when the proving tests/implementation
  were authored or accepted by the same agent; plus its scenario lens for
  user-facing behavior
- STANDARD records `single-reviewer`; the STANDARD small-task carve-out is a
  direct-Ralph path and does not apply to Ultrawork validation. Use cross-host
  review or the Same-Host Parallel Fallback only for a named THOROUGH
  paired-review trigger. The `verifier` remains one self-host pass.

Review-then-verify order: run the selected code-review stage first, then the
confirming independent `verifier` pass (never the maker). This mirrors Ralph.

Before dispatching Final Validation review roles, write the dependency graph into
the session ledger:

```text
Final Validation dependency graph:
- code-reviewer topology: not-required | single-reviewer | paired-thorough
- code-reviewer pass: pending | complete | blocked | not-required
- code-reviewer synthesis captured: yes | no | not-required
- blocking reviewer findings: resolved | blocking | none | not-reviewed
- verifier eligible to start: yes | no
- verifier started after reviewer completion: yes | no | not-required
- early verifier discarded and rerun: yes | no | not-applicable
```

`verifier eligible to start` is `yes` only after the selected code-review stage
has completed (or a compliant fallback/not-required reason is recorded), the
caller has captured the review output or pair synthesis, and blocking findings are either
resolved or recorded as blocking. A verifier spawned before that point is stale
evidence for Final Validation, must be recorded as discarded, and must be rerun
after the reviewer dependency is satisfied before it can count as the
independent verifier pass. When both code-reviewer and verifier are required,
the Final Validation ledger must show
`verifier started after reviewer completion: yes` or the verifier pass is stale
and does not count.

If execution was handled inline instead of through `ralph`, apply Ralph's
mode-gated review, cleanup, baseline guard, review-loop budget, and final
evidence requirements here before reporting success.

### Phase 5: Report

<HARD-GATE>
The run is invalid if the session ledger does not show each required phase gate satisfied, named individually: requirements_gate, planning_gate (Plan approval source recorded per Phase 1), worktree_gate, execution mode, verification, reviewer pass, independent verifier pass, simplify/cleanup, and VBC (or a recorded not-required reason for each). A silently omitted step is a named ledger gap, not a pass. Each dispatched reviewer pass records `single-reviewer` for STANDARD or a named THOROUGH pair topology; an inline fallback requires a reason. Missing review topology is a named ledger gap, not a pass. The single verifier pass is governed by the maker-verifier carve-out and sequencing field. When both code-reviewer and verifier are required, the ledger must show `verifier started after reviewer completion: yes` or the verifier pass is stale and does not count.
Run `verification-before-completion` before any completion claim or final report.
</HARD-GATE>

Before writing the final report, read and follow `verification-before-completion`
for the final delivery claim unless Ralph already ran it for the same final
claim and no integration, merge, or orchestration-level evidence changed after
that point. If post-Ralph evidence changed, run it again against the final
orchestrated result.

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

## Ultrawork Exception

Ultrawork is the only context that may invoke `interview`, `ralplan`, or `ralph` without the per-step transition question those skills normally require. The user opted into orchestration when they invoked ultrawork, so each phase boundary moves automatically once the prior phase's content gate is satisfied.

Content gates inside the sub-skills still run, but Ultrawork owns the approval
handling after requirements are clear:

- `interview` still has the user review the spec when the request is vague or
  product intent is missing. Ultrawork does not auto-approve the interview spec.
- After the user approves the interview spec, or when the starting request is
  already concrete enough to plan, Ultrawork automatically approves `ralplan`
  output that satisfies the required planning gates.
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

If the user invokes `interview`, `ralplan`, or `ralph` directly without going through ultrawork, the per-step Next Skill Handoff in those skills is required.

## Output

Return:

- Active artifact paths.
- Phase status.
- Skills used in order.
- Verification evidence.
- Final result or blocker.
