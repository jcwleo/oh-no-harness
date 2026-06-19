---
name: using-oh-no-harness
description: Use when starting a session with Oh No Harness, deciding whether a local skill applies, selecting between interview, planning, Ralph execution, fusion rescue, debugging, cleanup, or verification, and recognizing TDD as an internal guardrail.
argument-hint: "[task, question, or routing need]"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Using Oh No Harness for Codex

This generated file is the Codex-facing runtime skill document. Codex should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/using-oh-no-harness.md`
- `../../docs/platforms/codex.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/using-oh-no-harness.md

# Using Oh No Harness

Oh No Harness is a lightweight skill harness. Generated platform-specific public
skill documents compose this shared core with the active platform rules from
`docs/platforms/`.

## Software Development Stage

Using Oh No Harness is the workflow-entry and routing stage.

Use it before software work starts to decide whether the request needs `interview`, `ralplan`, `ralph`, `fusion-rescue`, debugging, cleanup, verification, or a direct small edit. Treat TDD as an internal guardrail discipline unless the user explicitly asks for TDD or test-first work.

## Core Rule

Before any response or action, including clarification questions, check whether a local Oh No Harness skill could apply.

If there is even a small chance that a local skill applies, read that skill before responding and follow it directly. If the selected skill turns out not to apply, say so briefly and continue with the next best path.

Needing more context is not a reason to skip skill selection. It is often the signal that `interview`, `ralplan`, `systematic-debugging`, or another local skill should be read first.

The available public skills are:

- `interview`: clarify vague product, design, or engineering requests into an approved spec.
- `ralplan`: create a consensus implementation plan before execution.
- `ralph`: execute a concrete PRD or approved plan until acceptance criteria and verification are satisfied.
- `ultrawork`: orchestrate interview, planning, execution, QA, and final validation for larger end-to-end work.
- `auto-routing`: toggle stronger SessionStart skill-selection guidance for users who want it.
- `test-driven-development`: internal guardrail discipline for RED/GREEN/REFACTOR before behavior-changing production edits; not a generic implementation entrypoint.
- `simplify`: review changed code for reuse, simplification, efficiency, and altitude cleanup while preserving behavior.
- `verification-before-completion`: verify evidence before claiming work is complete, fixed, passing, or ready.
- `systematic-debugging`: investigate bugs, failing commands, regressions, and unexpected behavior before fixing.
- `fusion-rescue`: run bounded three-panel rescue analysis with mandatory adversarial critique and fallback-aware synthesis when a hard problem stalls.

## Recommended Development Flow

For LLM software development, prefer this order when the request is not already a small, concrete edit:

1. `using-oh-no-harness`: route the request and choose the right workflow surface.
2. `interview`: discover requirements, constraints, users, acceptance criteria, and brownfield facts for vague or requirement-light work.
3. `ralplan`: turn the approved spec or clear task into an implementation plan, sequencing, TDD expectations, required Ralph execution mode, risk handling, and verification strategy.
4. `ralph`: set or read the required execution mode, then execute the approved plan or concrete PRD according to that mode.
5. `test-driven-development`: run inside `ralph`, `systematic-debugging`, `ultrawork`, or an explicitly chosen tiny direct edit path before behavior-changing production edits and bug fixes.
6. `systematic-debugging`: enter whenever a failing command, regression, flaky result, or unknown root cause blocks progress.
7. `fusion-rescue`: escalate only when the selected workflow's ordinary analysis or debugging path stalls and independent panel synthesis could change the next action.
8. `simplify`: clean reuse, simplification, efficiency, and altitude issues only after behavior is locked and required review is satisfied or recorded as not needed.
9. `verification-before-completion`: check fresh evidence before any final "done", "fixed", "passing", or "ready" claim.

`ultrawork` is the opt-in end-to-end orchestration lane over the same
`interview` -> `ralplan` -> `ralph` stages. Use it when the user delegates the
loop to the agent; Ultrawork records its internal approvals and only pauses for
the user when a documented pause condition or unclear requirements require it.

Small concrete tasks may skip `interview` and `ralplan`, but `ralph` still
must set a `LIGHT`, `STANDARD`, or `THOROUGH` execution mode before editing and
must follow the relevant TDD, debugging, cleanup, and verification gates for
that mode.

Default ordinary implementation requests to `ralph`, not
`test-driven-development`. If a request says add, fix, refactor, or implement
and does not explicitly ask for TDD, test-first, RED/GREEN/REFACTOR, or a
failing test first, select `ralph` for concrete implementation (or
`systematic-debugging` when failure/root-cause investigation is still needed)
and let that workflow invoke TDD internally when behavior changes.

The host agent, not the user, operates the workflow. The active generated
runtime skill document composes the selected skill core, invokes any allowed
role agents, writes artifacts, and runs verification. The user should only need
to approve stage outputs, choose a clearly named next workflow step, or correct
direction when the agent asks.

When describing the staged workflow, call the requirements-discovery stage `interview`, not a generic clarify phase.

## Worktree Isolation Default

For write-capable coding work, apply `docs/shared/worktree-isolation.md` before
editing source files.

`interview` and `ralplan` do not need to run inside a worktree by default because
they produce pre-execution artifacts. The worktree gate starts at execution:
direct `ralph` creates or selects a registered Git worktree under
`.oh-no/worktrees/<task-slug>` by default, records
`Worktree decision: direct automatic worktree`, and does not edit files until
that decision is visible.
Automatic task worktrees should stay inside the project rather than appearing as
parent-directory siblings unless an explicit fallback is recorded. Do not treat
`git clone`, `cp -R`, or a plain directory as a valid Ralph task worktree.

`ultrawork` is the orchestration exception because it also owns integration back
into the original checkout. When it reaches write-capable execution, it records
`Worktree decision: ultrawork automatic worktree`, creates or selects a task
registered Git worktree under `.oh-no/worktrees/<task-slug>`, executes there,
merges into the integration checkout, and runs post-merge verification.

## Interview Gate

Before asking the user a clarification, scope, preference, or approval question:

1. Check whether the question exists because the request is broad, vague, ambiguous, or missing requirements, constraints, acceptance criteria, or user intent. If yes, read and follow `interview` first.
2. Check whether the question exists because the implementation strategy, sequencing, architecture, risk, or tradeoff is unclear. If yes, read and follow `ralplan` first.
3. Check whether the question exists because a failing command, regression, flaky behavior, or unknown root cause is blocking progress. If yes, read and follow `systematic-debugging` first.
4. Check whether the question exists because ordinary `ralph` or `systematic-debugging` analysis has stalled and a bounded adversarial panel could change the next action. If yes, read and follow `fusion-rescue` first.
5. Check whether the question is part of an already-selected workflow skill. If yes, ask it through that skill's rules.

Do not ask raw clarification questions for vague work before reading `interview`, unless the user explicitly tells you not to use the skill.

## Skill Chaining

Skill chaining is explicit Markdown guidance, not hidden automation.

When a skill defines a `Next Skill Handoff`, you MUST present the handoff to the user and wait for an explicit choice before invoking the next workflow skill. Present the options as actions the host agent will take, not commands the user must run manually. Do not auto-invoke the next workflow skill, even when a single recommended choice is named. The user's answer is the trigger.

Workflow skills (`interview`, `ralplan`) currently define this handoff; `ralph` is terminal and defines only a `Final Handoff` with no next-skill question. The recommended path is `interview → ralplan → ralph`, but each transition is a distinct user-confirmed step.

Internal mid-loop skills used inside an already-invoked workflow skill - for example `test-driven-development`, `fusion-rescue`, `simplify`, `verification-before-completion`, and `systematic-debugging` invoked from inside `ralph`'s execution loop - are part of that skill's documented procedure and do not require a separate per-step transition question.

The single exception is `ultrawork`. When the user invokes `ultrawork`,
ultrawork may move between `interview`, `ralplan`, and `ralph` without the
per-step transition question. If requirements are unclear, `interview` spec
review still surfaces to the user. Once the requirements source is approved or
already concrete, `ralplan` plan approval is handled as an Ultrawork internal
approval record unless a documented pause condition appears. Final-completion
verification still runs before any completion claim.

If the user overrides any recommendation, follow the user's instruction unless it would violate safety or repository constraints.

## Platform Notes

This core file does not define platform invocation syntax. Use the active
generated public skill document, which already composes this core with the
matching platform source files named in its runtime composition metadata.

When a skill names an agent role, adapt the role through the active platform
file. Agents remain role prompts inside a selected skill, not workflow
entrypoints: an agent can recommend another role or workflow skill to the
caller, but it does not own artifact gates, approval gates, or next-skill
handoffs.

## Artifact Paths

Use `.oh-no/specs/` for generated specs.

Use `.oh-no/plans/` for generated plans.

Use `.oh-no/sessions/` for transient session artifacts.

Use `.oh-no/worktrees/` for project-local Ralph and Ultrawork task worktrees.

Do not use legacy harness artifact paths.

## No Hidden Orchestration

Oh No Harness does not include an automatic mode controller or external state ledger.

If a workflow requires persistence, the persistence requirement lives in the skill text and in written artifacts.

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
