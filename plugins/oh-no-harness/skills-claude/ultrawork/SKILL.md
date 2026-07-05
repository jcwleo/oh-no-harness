---
name: ultrawork
description: Use when the user asks for autonomous or end-to-end delivery of a broad goal, feature, fix, project task, or vague request that may span interview, planning, execution, QA, cleanup, and validation.
argument-hint: "<goal, spec path, plan path, or broad delivery request>"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Ultrawork for Claude Code

This generated file is the Claude Code-facing runtime skill document. Claude Code slash commands should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/ultrawork.md`
- `../../docs/platforms/claude-code-runtime.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/ultrawork.md

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

Before acting on any gate below that routes a decision through a shared
contract, read that contract. A path reference here is a pointer, not a
substitute for reading: do not apply one of these rules from memory when this
skill hands a decision to it. If a listed file cannot be read, record the
blocker instead of proceeding past the gate that depends on it.

- `docs/shared/execution-modes.md` — the Ralph execution profile the plan must carry.
- `docs/shared/worktree-isolation.md` — the automatic worktree plus merge-back gate.
- `docs/shared/ralph-subagent-policy.md` — phase-agent dispatch and isolation.
- `docs/shared/cross-host-review.md` — Final Validation cross-host review and the independence-mode recording rule.

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
| Plan | Follow `ralplan`; dispatch `explore` when context is needed, then complete `analyst` -> `planner` -> `plan-reviewer` in that order. The plan must set the Ralph execution profile and include the three role outputs or inline role blocks. |
| Execute | Follow `ralph`; dispatch isolated `explore`, `executor`, `verifier`, and review agents according to the approved execution mode, plan, platform policy, and risk; inline only for documented subagent-unavailable or unsafe-to-isolate cases. |
| QA Loop | Follow `systematic-debugging` for failure investigation; it owns `debugger` dispatch per its own contract. Dispatch `verifier` (scenario lens for user-facing flows). |
| Final Validation | Dispatch `plan-reviewer` and `code-reviewer` (security lens included) for additional orchestration-level risk not already covered by Ralph's satisfied gates. Dispatch `verifier` as an independent pass — required at STANDARD and THOROUGH on subagent-capable hosts whenever execution produced or changed proving tests, or the implementation/tests were authored or accepted by the same agent, per the carve-out in `docs/shared/ralph-subagent-policy.md` (record the fallback reason if the host cannot dispatch); otherwise (scenario lens) only for additional orchestration-level risk. When the opposite host is available, run `plan-reviewer` and `code-reviewer` as cross-host review per `docs/shared/cross-host-review.md` (current-host + opposite-host instances synthesized; otherwise use the Same-Host Parallel Fallback); the `verifier` is the confirming pass per the Review-then-verify order below — an unconditionally single self-host independent pass (never a cross-host or same-host pair). |

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

Read and follow `ralplan` unless an approved or relevant plan already exists.

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
  (dual-host default, hypothesis ledger) — do not dispatch a raw `debugger`
  outside that flow
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

- `plan-reviewer` for architecture-sensitive changes
- `code-reviewer` for correctness and maintainability, with its security lens
  for security-sensitive behavior
- `verifier`: required as an independent pass (acceptance-to-evidence mapping +
  adversarial test-genuineness audit) under the carve-out in
  `docs/shared/ralph-subagent-policy.md` when the proving tests/implementation
  were authored or accepted by the same agent; plus its scenario lens for
  user-facing behavior
- When the opposite host is available, run `plan-reviewer` and `code-reviewer`
  as cross-host review per `docs/shared/cross-host-review.md` (current-host +
  opposite-host instances synthesized into one result; otherwise use the
  Same-Host Parallel Fallback with a fallback note); the `verifier` is the
  confirming pass per the Review-then-verify order below — an unconditionally
  single self-host independent pass (never a cross-host or same-host pair)
- Record each code-review pass's independence mode per
  `docs/shared/cross-host-review.md` `## Recording the Independence Mode` (for
  `plan-reviewer` and `code-reviewer`); the single self-host `verifier` confirming
  pass is governed by the maker-verifier carve-out and the `verifier started after
  reviewer completion` sequencing field, not the independence-mode enum

Review-then-verify order: run the `code-reviewer` pair first, then the confirming
independent `verifier` pass (never the maker), per the canonical contract in
`docs/shared/cross-host-review.md` `## When It Applies` Exception and the bullets
above. This mirrors `ralph`'s Review Gate.

Before dispatching Final Validation review roles, write the dependency graph into
the session ledger:

```text
Final Validation dependency graph:
- code-reviewer pair: pending | complete | blocked | not-required
- code-reviewer synthesis captured: yes | no | not-required
- blocking reviewer findings: resolved | blocking | none | not-reviewed
- verifier eligible to start: yes | no
- verifier started after reviewer completion: yes | no | not-required
- early verifier discarded and rerun: yes | no | not-applicable
```

`verifier eligible to start` is `yes` only after the code-reviewer pair has
completed (or a compliant fallback/not-required reason is recorded), the caller
has captured and synthesized reviewer outputs, and blocking findings are either
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
The run is invalid if the session ledger does not show each required phase gate satisfied, named individually: requirements_gate, planning_gate (Plan approval source recorded per Phase 1), worktree_gate, execution mode, verification, reviewer pass, independent verifier pass, simplify/cleanup, and VBC (or a recorded not-required reason for each). A silently omitted step is a named ledger gap, not a pass. Each dispatched reviewer pass must also record its independence mode (`cross-host`, `same-host-parallel-fallback`, or `inline-fallback` with reason) per `docs/shared/cross-host-review.md`; a dispatched pass with no recorded independence mode is a named ledger gap, not a pass. The single self-host verifier pass is governed by the maker-verifier carve-out and the sequencing field above, not the independence-mode enum. When both code-reviewer and verifier are required, the ledger must show `verifier started after reviewer completion: yes` or the verifier pass is stale and does not count.
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

## Source: docs/platforms/claude-code-runtime.md

# Claude Code Runtime Rules

This compact platform section is embedded in generated Claude Code-facing skill
documents.

## Skill Loading

Claude Code-facing public skills live under `skills-claude/`. Generated
`skills-claude/<skill>/SKILL.md` files compose the matching skill core, this
compact runtime section, and any Claude Code skill-specific overlay such as
`docs/platforms/claude-code-<skill>.md`. Slash commands must delegate to the
matching generated skill document.

## User Approval, Tasks, And Prompting

Use the host's structured question tool when available for approval,
preference, scope, or next-step selection; otherwise ask one focused plain-text
question and wait. Present options as actions the host agent will take.

When a core skill has a multi-phase approval handoff and the host exposes task
tracking, create one task per phase and complete them sequentially.

Keep Claude prompts explicit and sectioned: state scope, non-goals,
constraints, approval gates, expected evidence, and output format. Preserve
long-running context in artifacts before compaction, task handoff, or subagent
dispatch.

## Role Dispatch

Use the available Task, Agent, Workflow `agent()`, or subagent mechanism for
role dispatch. Prefer plugin-scoped agents named `oh-no-harness:<role>` when
the host lists them.

For independent read-only, review, verification, QA, security, or exploration
work, request background subagents and start the whole independent batch before
waiting for any one result. When a skill requires an atomic same-phase batch,
prefer Workflow `Promise.all` if available; otherwise do not inspect or
summarize early task results until the full intended batch has been requested.

After a Claude Code subagent reaches final status, capture the output and any
changed-file set before cleanup. When no further input is needed, close or
clean up the completed subagent with the mechanism exposed by the host; if none
is available, record that fallback.

For approved `ralplan` handoffs to ordinary `oh-no-harness:ralph`, treat
`Parallel trigger: approved-plan-handoff` as dispatch authorization for
eligible isolated roles. Do not require a separate `ralph with parallel
subagents` option when the plan already lists roles whose output can change the
implementation, review, verification, or ship/block decision.

If plugin-scoped agents are unavailable, keep the same role boundary by
embedding the matching `agents/<role>.md` prompt into the available subagent
mechanism. If no dispatch mechanism is available, keep the role inline and
record the fallback reason when the core skill requires it.

## Cross-Host Consult Channel

This is the shared cross-host consult mechanism used by Fusion Rescue and by
cross-host review (`docs/shared/cross-host-review.md`). On Claude Code the
opposite host is Codex. This section carries only the Claude-to-Codex
invocation; the activation, synthesis, and recursion-guard semantics live in the
calling skill core and the shared doc.

From Claude Code, the current-host main agent consults Codex only by dispatching
the dedicated read-only consult agent `oh-no-harness:<role>-codex` for the
assigned opposite-host leg, where `<role>` is `plan-reviewer`, `code-reviewer`,
or `debugger` for shared cross-host review, or `fusion` for a Fusion Rescue panel
slot. That consult agent resolves the Codex companion path and runs one
synchronous, read-only `codex-companion.mjs task` call: it omits the write flag
so the companion stays read-only, and it never runs the call as a detached
background job. If the companion is unavailable or unresolvable, treat the
opposite host as unavailable; in default mode the calling skill applies the
shared cross-host contract's Same-Host Parallel Fallback
(`docs/shared/cross-host-review.md`), and require-cross-host mode blocks. Name the
failure class and the current-host fallback.

The consult must return Codex's actual assigned analysis synchronously. The
`codex-companion.mjs` call passes the scoped, redacted packet with `--prompt-file`
and must not run in the background. A response that only acknowledges a queued or
background job — text that a task started in the background with a status command
for a job id — is not a valid opposite-host response; treat it as no Codex
response and degrade (default) or block (require-cross-host). Do not poll status
or fetch a deferred result to compensate; the consult call itself must return the
analysis.

For shared cross-host review, the packet the `oh-no-harness:<role>-codex` agent
sends must instruct Codex to dispatch the matching `oh-no-<role>` role agent for
the assigned opposite-host pass, where `<role>` is `plan-reviewer`,
`code-reviewer`, or `debugger`. Codex must wait for that dispatched role agent and
return its assigned role result, and the consult agent must require role-ownership
proof that the dispatched role agent — not a parent inline Codex answer — produced
it. A direct Codex parent answer is not a
valid opposite-host shared review response. If Codex cannot dispatch the matching
role agent, or the role-ownership proof is missing, treat the opposite host as
unavailable in default mode or block in require-cross-host mode; do not accept
inline Codex parent analysis as the cross-host pass. Role ownership is best-effort
— there is no host selector that forces it — so it is required and proven, not
assumed.

Fusion Rescue panel slots remain governed by the Fusion Rescue panel contract;
the role-agent requirement above applies only to shared cross-host review. The
`oh-no-harness:fusion-codex` panel slot dispatches `oh-no-fusion-rescue-analyst`
for one assigned lens (see `docs/platforms/claude-code-fusion-rescue.md`).

The outbound packet must request only the assigned analysis and must forbid the
opposite host from invoking further rescue, another workflow skill, or any
host-to-host call back to Claude Code or a third host (one cross-host hop).
Redact secrets before sending; on failure record only the failure class and
companion/path/auth status, never secret values.
