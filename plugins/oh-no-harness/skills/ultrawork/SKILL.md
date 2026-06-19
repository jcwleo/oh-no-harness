---
name: ultrawork
description: Use when the user asks for autonomous or end-to-end delivery of a broad goal, feature, fix, project task, or vague request that may span interview, planning, execution, QA, cleanup, and validation.
argument-hint: "<goal, spec path, plan path, or broad delivery request>"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Ultrawork for Codex

This generated file is the Codex-facing runtime skill document. Codex should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/ultrawork.md`
- `../../docs/platforms/codex.md`

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

## Source: docs/platforms/codex.md

# Codex Platform Rules

This platform section is source content for generated Codex-facing runtime
skill documents.

## Skill Loading

Codex-facing public skills live under `skills/`. Files in
`skills/<skill>/SKILL.md` are generated runtime documents composed from the
matching `docs/skill-core/<skill>.md` file, this Codex platform file, and any
Codex skill-specific overlay such as `docs/platforms/codex-<skill>.md`.

## User Approval

When a core skill asks for approval, preference, scope, or next-step selection,
ask the user directly in the current Codex conversation. Present options as
actions the host agent will take. Do not tell the user to run a command manually
when the skill handoff expects the host agent to invoke the next skill.

## Auto Routing

The `auto-routing` skill can explain and preserve the config file shape in
Codex, but it does not add forced routing to Codex SessionStart. Codex native
skill loading remains the primary routing surface. If Codex-facing
SessionStart hooks run, they must stay compact and must not embed full skill
core bodies.

## OpenAI-Aligned Prompting

This file carries the runtime-sized OpenAI guidance for Codex. The longer
maintenance reference lives in `docs/providers/openai.md`, but generated
Codex-facing runtime skill documents do not include provider docs as an extra
runtime source.

For OpenAI/Codex models, keep prompts outcome-first:

- state the desired outcome, acceptance criteria, non-goals or side effects,
  and expected evidence before detailed steps
- keep tool and role instructions close to the place where the tool or role is
  used
- specify output shape for plans, reviews, verification, and final reports
- use compact final answers unless the active skill requires an evidence log or
  approval brief
- preserve durable state in written artifacts before long work, compaction, or
  handoff

When the host exposes reasoning or verbosity controls, use the lightest setting
that can produce credible evidence. Raise effort for broad planning, deep code
review, hard debugging, or multi-agent integration; lower it for small,
mechanical, or already-isolated work.

## Role Dispatch

Codex role dispatch is host-policy controlled. Use `spawn_agent` only when the
current host tool definition exposes it, the active skill permits dispatch, and
the role has an isolated read-only scope, disjoint write ownership, or an
independent review or verification responsibility.

When dispatching an Oh No Harness role in any Codex context, including active
skills, approved plan handoffs, SessionStart-authorized read-only exploration,
or general user-requested subagent work outside a selected skill, use the
registered custom agent first. If the host recognizes or accepts
`oh-no-<role>`, call
`spawn_agent(agent_type="oh-no-<role>", ...)`. Do not choose built-in
`explorer`, `worker`, `default`, or a prompt-embedded generic subagent for an Oh
No Harness role while the matching registered custom agent is available.
Do not infer custom-agent unavailability from rendered schema text, display
comments, or uncertainty. Generic/default fallback is allowed only inside an
active Oh No Harness workflow or explicit user-requested subagent task after an
actual `agent_type="oh-no-<role>"` attempt is rejected as unknown or unavailable
and the confirmed fallback reason is recorded. The no-skill read-only
exploration lane below must not use generic/default fallback.

Do not combine `agent_type = "oh-no-<role>"` with `fork_context = true` or any
full-history fork request. Codex full-history forks inherit the parent agent
configuration and cannot be used with a custom role agent type. Put the required
scope, constraints, and evidence context in the spawned-agent message instead.
Use one spawn payload shape only: prompt/message or items, never both.

Explicit user or plan wording such as `subagent`, `spawn`, `delegate`,
`parallel agents`, `parallel subagents`, or `one agent per` is sufficient when
the host permits dispatch. A user standing preference, approved plan profile, or
active Oh No Harness skill policy to use eligible subagents proactively is also
workflow-level authorization, so the user does not need to repeat literal
subagent wording on every Ralph step. Eligibility still depends on isolation and
decision-changing value, not authorization alone.

When the Codex SessionStart context includes
`CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION`, treat that standing
authorization as the explicit user request for Oh No Harness sub-agents,
delegation, and parallel agent work in the current session. Do not ask a
separate per-run approval question merely to use eligible subagents inside an
active Oh No Harness workflow.

When the user, plan, or skill states a standing preference to maximize
subagents, treat that as explicit authorization for eligible isolated roles
inside the active workflow. Keep Codex host-policy limits, but do not require
the user to repeat literal subagent wording on every step. Do not dispatch a
role whose output would not change the implementation, review, verification, or
ship/block decision.

When no explicit request, standing preference, approved plan trigger, or active
skill dispatch policy exists, do not spawn Codex subagents merely because a role
could be named. Keep the role inline and record the fallback reason when the
core skill requires it.

The only no-skill exception is the Codex SessionStart block named
`CODEX_ONLY_OH_NO_READONLY_EXPLORATION_DELEGATION`. It authorizes one
exploration subagent for simple read-only repository fact lookup prompts such as
locating logic, tracing a symbol, identifying related tests, or summarizing an
existing file/config path. It does not authorize planning, debugging,
implementation, review (security lens included), scenario QA, completion
verification, ambiguous-requirements work, or file edits. It must not read or
reproduce secrets unless the user explicitly asks for that sensitive lookup, and
credential values must be redacted in subagent output. This no-skill lane may
dispatch only the registered read-only `oh-no-explore` custom agent when the
current host recognizes it; if that agent is unavailable, answer inline instead
of falling back to a generic or prompt-embedded subagent. If `agent_type =
"oh-no-explore"` is rejected as unknown or unavailable, do not retry with a
generic subagent for this lane. When this lane spawns `oh-no-explore`, use
`wait_agent` as the next lifecycle tool for that receiver, repeated until it
returns that receiver with final status `completed`, before calling
`close_agent`; a timeout, empty wait, or no-completion result is not captured
evidence. `close_agent` output is not a substitute for the required wait result
and must not be the first result capture. The forbidden order is `spawn_agent`
then `close_agent`. Even if `close_agent` returns output, that output is not
valid first result capture. If you will not call `wait_agent` first, do not
spawn; perform the lookup inline.

For approved `ralplan` handoffs to ordinary `oh-no-harness:ralph`, treat
`Parallel trigger: approved-plan-handoff` as dispatch authorization for
eligible isolated roles. Do not require a separate `ralph with parallel
subagents` option when the plan already lists roles whose output can change the
implementation, review, verification, or ship/block decision.

For `ralplan`, Planner and Plan-Reviewer keep sequential role boundaries:
Planner produces the draft, then Plan-Reviewer reviews that draft. Dispatch them
as sequential subagents when the active host supports dispatch and independent
context can improve planning or review; otherwise keep separate inline role
blocks. A re-review dispatch happens only when blocking findings require a
Planner revision.

After `wait_agent` returns a final status for any Codex-dispatched role,
capture the output and any changed-file set before cleanup. A timeout, empty
wait result, or "No agents completed yet" result is not a final status and is
not permission to close the subagent. Hard rule: MUST NOT call `close_agent`
for a running or pending subagent merely because it is slow. Leave the subagent
running, wait longer when its result is still needed, continue with
non-overlapping local work, or record the role as pending or blocked. Close
without a captured final result only when the user explicitly cancels or stops
that subagent, the task scope invalidates the work, the spawn was duplicate or
mis-scoped, or continuing creates a safety, security, or filesystem risk. Record
that close as cancelled or abandoned and never use missing output as completion
evidence. When no further input is needed for a completed, failed, cancelled,
user-cancelled, scope-invalidated, or unsafe subagent, call `close_agent` and
record the result.

When dispatch is unavailable, keep the same role boundary inline and record the
fallback reason when the core skill requires it.

## Optional Named Custom Agents

Oh No Harness Codex custom-agent templates are installed in user scope by
default with `scripts/install-codex-agents`. User scope means
`$CODEX_HOME/agents` when `CODEX_HOME` is set, otherwise
`$HOME/.codex/agents`. Project scope means `.codex/agents`.

Custom agents are standalone TOML files under those `agents/` directories; they
are not defined inside `config.toml`. Codex `[agents]` config entries are global
subagent settings, not individual Oh No Harness role definitions.
Generated Codex custom-agent descriptions stay role-only. Their
`developer_instructions` provide the stable role contract, while the
`spawn_agent` message supplies the current story scope, acceptance criteria,
contract surface, baseline guard, expected output, and lifecycle.

Codex `SessionStart` runs a best-effort user-scope quiet ensure with
`scripts/install-codex-agents --scope user --ensure --quiet`. It installs
missing generated files and refreshes stale generated files without adding
success output to the session context. If installation fails or an unmarked user
file blocks ensure, SessionStart keeps running and adds only a compact fallback
warning.

When a Codex Ralph prompt is detected, the Ralph platform adapter repeats the
same quiet ensure as a fallback before injecting dispatch guidance. Generated
files include the installed plugin version marker, so a later plugin update can
refresh stale `oh-no-*` agent definitions during SessionStart or Ralph fallback
without requiring a repeated user prompt. If ensure fails or an unmarked user
file blocks it, record the ensure failure but do not treat that failure alone
as permission for generic prompt-embedded fallback. Continue with
`agent_type = "oh-no-<role>"` if the current host recognizes that custom agent;
use generic prompt-embedded fallback only after confirmed custom-agent
unavailability and record that fallback reason.

Files ensured on disk are not the same thing as same-session named-agent
availability. Use `agent_type = "oh-no-<role>"` whenever the current Codex host
recognizes that registered custom agent. Inside an active Oh No Harness
workflow, use the generic prompt-embedded fallback below or built-in `explorer`
only after the host returns `unknown agent_type` or an equivalent explicit
rejection for `oh-no-<role>`, or the user-scope templates are unavailable and
the host cannot recognize the custom agent. Outside an active workflow, the
no-skill read-only exploration lane must stay inline unless registered
`oh-no-explore` is available.
The generated `oh-no-explore` template sets `sandbox_mode = "read-only"` so the
no-skill exploration lane does not rely on prompt text alone for write
isolation.

The generated templates pin `gpt-5.5` and a per-agent
`model_reasoning_effort` so custom-agent role files do not depend on
inheriting a user-specific model layer.

When the active Codex host recognizes a registered custom agent, `agent_type =
"oh-no-<role>"` is the required path for Oh No Harness role dispatch. If the
host returns an unknown `agent_type`, or if the user-scope templates are not
installed and the host cannot recognize the agent, fall back to the
prompt-embedded dispatch contract below and record the confirmed fallback
reason. Do not infer unavailability from memory, stale examples, display names,
rendered schema comments, or uncertainty about the schema.

Custom-agent dispatch must pass context through the message and leave
full-history forking disabled. If a role truly needs the entire parent history,
keep that role inline or use a host-supported non-custom fork path and record the
fallback reason. Do not send both message and items in one spawn request.

## Role Prompt Embedding

When using generic Codex agent types, read the matching
`docs/agent-core/<role>.md` file and embed that platform-neutral prompt body in
the spawned-agent message. Do not rely on the role name alone unless the
registered `oh-no-<role>` custom agent supplies the role developer
instructions.

If `docs/agent-core/<role>.md` is unavailable but `agents/<role>.md` exists,
strip the Claude Code YAML frontmatter before embedding. Claude-only
frontmatter such as `tools`, `model`, `background`, `isolation`, or `color` is
metadata for Claude Code and must not be included in Codex spawned-agent prompt
content.

Every generic Codex role dispatch must include:

```text
Agent prompt source: docs/agent-core/<role>.md
Agent prompt content:
<matching docs/agent-core/<role>.md prompt content>
```
