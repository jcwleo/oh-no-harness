# Codex Platform Rules

This platform document is the longer Codex maintenance reference. Generated
Codex-facing skill documents embed the compact
`docs/platforms/codex-runtime.md` section instead.

## Skill Loading

Codex-facing public skills live under `skills/`. Files in
`skills/<skill>/SKILL.md` are generated runtime documents composed from the
matching `docs/skill-core/<skill>.md` file,
`docs/platforms/codex-runtime.md`, and any Codex skill-specific overlay such as
`docs/platforms/codex-<skill>.md`.

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

This file carries extended OpenAI guidance for Codex maintainers. The compact
runtime-sized rules copied into generated skill documents live in
`docs/platforms/codex-runtime.md`. The longer provider reference lives in
`docs/providers/openai.md`, but generated Codex-facing runtime skill documents
do not include provider docs as an extra runtime source.

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
skills, approved plan handoffs, or general user-requested subagent work outside
a selected skill, use the registered custom agent first. If the host recognizes
or accepts
`oh-no-<role>`, call
`spawn_agent(agent_type="oh-no-<role>", ...)`. Do not choose built-in
`explorer`, `worker`, `default`, or a prompt-embedded generic subagent for an Oh
No Harness role while the matching registered custom agent is available.
Do not infer custom-agent unavailability from rendered schema text, display
comments, or uncertainty. Generic/default fallback is allowed only inside an
active Oh No Harness workflow or explicit user-requested subagent task after an
actual `agent_type="oh-no-<role>"` attempt is rejected as unknown or unavailable
and the confirmed fallback reason is recorded. No-skill read-only repository
lookups must stay inline and must not use generic/default fallback.

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

There is no no-skill subagent exception. The Codex SessionStart block named
`CODEX_ONLY_OH_NO_READONLY_EXPLORATION_INLINE_BOUNDARY` keeps simple read-only
repository fact lookup prompts inline when no active Oh No Harness workflow or
explicit user-requested subagent task exists. Eligible inline work includes
locating logic, tracing a symbol, identifying related tests, or summarizing an
existing file/config path. This no-skill lane must not call `spawn_agent`,
`wait_agent`, or `close_agent`; if independent role work would be useful, first
select the relevant Oh No Harness skill or get an explicit subagent request,
then follow that active workflow policy. It does not authorize planning,
debugging, implementation, review (security lens included), scenario QA,
completion verification, ambiguous-requirements work, or file edits. It must
not read or reproduce secrets unless the user explicitly asks for that
sensitive lookup, and credential values must be redacted in any output.

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
for a running or pending subagent merely because it is slow. Once a role is
dispatched, its assigned scope, role, and expected output become a workflow
dependency. The caller must wait until every in-scope dispatched subagent reaches
a final status, capture its result, and use that result in synthesis,
implementation, review, verification, or an explicit blocked/abandoned record
before advancing past the dependent step or claiming completion. While waiting,
continue only genuinely non-overlapping local work. Do not redo the delegated
work inline, do not spawn a duplicate replacement, and do not let the parent
agent's own inline analysis substitute for the subagent result merely because
the subagent is slow. Close
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
the host cannot recognize the custom agent. Outside an active workflow or
explicit user-requested subagent task, no-skill read-only repository lookup must
stay inline even when registered `oh-no-*` agents are available.
The generated `oh-no-explore` template sets `sandbox_mode = "read-only"` so the
read-only exploration role does not rely on prompt text alone for write
isolation when it is dispatched by an active workflow or explicit subagent
request.

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
