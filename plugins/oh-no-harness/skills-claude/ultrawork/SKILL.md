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
- `../../docs/platforms/claude-code.md`

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
- Any scope change, missing authority artifact, failed worktree gate, or failed
  verification transitions to `paused` or `blocked`, not silent continuation.
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
  output.

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
re-checks may stay inline when they have equal evidence.

| Phase | Agents |
|---|---|
| Interview | Follow `interview`; dispatch `explore` for brownfield facts when needed. Do not add planning or review agents to this stage. |
| Plan | Follow `ralplan`; dispatch `explore` when context is needed, then complete `analyst` -> `planner` -> `plan-reviewer` in that order. The plan must set the Ralph execution profile and include the three role outputs or inline role blocks. |
| Execute | Follow `ralph`; dispatch isolated `explore`, `executor`, `verifier`, and review agents according to the approved execution mode, plan, platform policy, and risk; inline only for documented subagent-unavailable or unsafe-to-isolate cases. |
| QA Loop | Dispatch `debugger` and `verifier` (scenario lens for user-facing flows); use `systematic-debugging` before fixes. |
| Final Validation | Dispatch `plan-reviewer`, `code-reviewer` (security lens included), and `verifier` (scenario lens) only for additional orchestration-level risk not already covered by Ralph's satisfied gates. |

When independent delegated phase work can run in parallel, or when inline
fallback role blocks need the same isolation plan, read
`docs/shared/ralph-subagent-policy.md`; `docs/shared/parallel-subagents.md` is
only a short pointer back to that policy.
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

If execution is handled inline instead of through `ralph`, first read `docs/shared/execution-modes.md`, set the required `LIGHT`, `STANDARD`, or `THOROUGH` execution mode, then apply Ralph's mode-gated loop. Apply Ralph's TDD gate before behavior-changing production edits: read and follow `test-driven-development`, record RED/GREEN/REFACTOR evidence, and document any approved exception.

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

- `systematic-debugging` (skill, not agent) for root-cause investigation before fixes
- `debugger` subagent for failures
- `verifier` subagent for evidence packaging and, via its scenario lens,
  user-facing flows

Repeat until checks pass or a blocking reason is documented.

### Phase 4: Final Validation

Final Validation does not repeat Ralph's required internal gates when Ralph has
already completed them. Dispatch only the additional orchestration-level review
subagents warranted by integration, merge, public-contract, security, or
cross-phase risk:

- `plan-reviewer` for architecture-sensitive changes
- `code-reviewer` for correctness and maintainability, with its security lens
  for security-sensitive behavior
- `verifier` with its scenario lens for user-facing behavior

If execution was handled inline instead of through `ralph`, apply Ralph's
mode-gated review, cleanup, baseline guard, review-loop budget, and final
evidence requirements here before reporting success.

### Phase 5: Report

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

## Source: docs/platforms/claude-code.md

# Claude Code Platform Rules

This platform section is source content for generated Claude Code-facing
runtime skill documents.

## Skill Loading

Claude Code-facing public skills live under `skills-claude/`. Files in
`skills-claude/<skill>/SKILL.md` are generated runtime documents composed from
the matching `docs/skill-core/<skill>.md` file, this Claude Code platform file,
and any Claude Code skill-specific overlay such as
`docs/platforms/claude-code-<skill>.md`.

Claude slash commands must delegate to `skills-claude/<skill>/SKILL.md` so the
model sees the generated Claude Code runtime document for that skill.

## User Approval

When asking the user for approval, preference, scope, or next-step selection,
use the available structured question tool when the host exposes one. Prefer one
focused question at a time. For option questions, provide a small set of
mutually exclusive choices and put the recommended option first when there is a
clear recommendation.

If a structured question tool is unavailable, ask in plain text and wait for the
user's answer. Present options as actions the host agent will take. Do not tell
the user to run a command manually when the skill handoff expects the host agent
to invoke the next skill.

## Task Tracking

When a core skill has a multi-phase approval handoff and the host exposes task
tracking, create one task per phase and complete them sequentially. Do not
collapse content approval and next-step selection into one hidden step.

## Auto Routing

The `auto-routing` skill controls whether the Claude Code SessionStart hook adds
stronger skill-selection guidance to `using-oh-no-harness`.

Preferred config location:

```text
$HOME/.claude/plugins/data/<oh-no-harness-*>/config.json
```

When `CLAUDE_PLUGIN_ROOT` is set, use:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" status
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" on
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" off
```

Changes take effect on the next Claude Code `SessionStart`, such as a new
session, app restart, `/clear`, or compaction.

## Anthropic-Aligned Prompting

This file carries the runtime-sized Anthropic guidance for Claude Code. The
longer maintenance reference lives in `docs/providers/anthropic.md`, but
generated Claude Code-facing runtime skill documents do not include provider
docs as an extra runtime source.

For Anthropic/Claude models, keep instructions explicit and sectioned:

- state scope, non-goals, constraints, approval gates, and expected evidence in
  stable headings or tagged sections
- avoid relying on implication; say what the agent may do, must not do, and must
  ask before changing
- give one focused user question at a time when approval or direction is needed
- preserve long-running context in artifacts before compaction, task handoff, or
  subagent dispatch
- keep final answers concise unless the active skill requires a structured plan,
  review, or verification report

When the host exposes extended thinking or effort controls, use higher effort
for agentic coding, architecture review, plan critique, and ambiguous debugging.
Use lower effort for small, already-bounded edits.

## Role Dispatch

Claude Code subagent descriptions are delegation metadata. Generated
`agents/*.md` descriptions may keep the `Use proactively` trigger so Claude can
select useful role agents, but they must bind that proactivity to active Oh No
Harness workflows and caller-owned approval and handoff gates. The agent body
contains the stable role contract; the Task, Agent, or Workflow prompt supplies
the current story scope, acceptance criteria, contract surface, baseline guard,
expected output, and lifecycle.

Use the available Task, Agent, Workflow `agent()`, or subagent mechanism for
role dispatch. Prefer plugin-scoped agents named `oh-no-harness:<role>` when
the host lists them.

For independent read-only, review, verification, QA, security, or exploration
work, request background subagents and start the whole independent batch before
waiting for any one result.
When a skill requires an atomic same-phase batch, prefer Workflow `Promise.all`
if available; direct Task or Agent background notifications may arrive before
the model has emitted later task requests, so do not inspect or summarize those
results until the full intended batch has been requested.

After a Claude Code subagent reaches a final status, capture the output and any
changed-file set before cleanup. When no further input is needed, close or clean
up the completed subagent with the mechanism exposed by the host; if none is
available, record that fallback.

For approved `ralplan` handoffs to ordinary `oh-no-harness:ralph`, treat
`Parallel trigger: approved-plan-handoff` as dispatch authorization for
eligible isolated roles. Do not require a separate `ralph with parallel
subagents` option when the plan already lists roles whose output can change the
implementation, review, verification, or ship/block decision.

If plugin-scoped agents are unavailable, keep the same role boundary by
embedding the matching `agents/<role>.md` prompt into the available subagent
mechanism. If no dispatch mechanism is available, keep the role inline and
record the fallback reason when the core skill requires it.
