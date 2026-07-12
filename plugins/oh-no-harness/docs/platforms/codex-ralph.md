# Codex Ralph Adapter

CODEX_ONLY_RALPH_ADAPTER

Use this adapter only on Codex. Do not apply it on Claude Code or other
platforms.

## Dispatch Decision

Ralph is parallel-capable on Codex when the host exposes `spawn_agent`. Codex
must still respect host policy and isolation rules: use subagents when the
current Codex host tool definition permits dispatch and Ralph's selected
execution mode, agent policy, task risk, and scope isolation make delegation
useful for context-window management, independent evidence, latency, or a
ship/block decision.

Explicit user or plan phrases that are sufficient dispatch signals include:

- `subagent`
- `spawn`
- `delegate`
- `parallel agents`
- `parallel subagents`
- `one agent per`
- `ralph with parallel subagents` (legacy wording; do not require this separate
  option)

Explicit subagent phrases are not required for approved `ralplan` handoffs: the
ordinary `oh-no-harness:ralph` choice should preserve
`Parallel trigger: approved-plan-handoff` and use the plan's dispatch profile as
authorization for every eligible isolated role. They are also not required when
the user has stated a standing preference to maximize subagents or when the
active Oh No Harness skill policy records proactive eligible dispatch as
workflow-level authorization for a concrete isolated scope. When no
dispatch-worthy role or scope exists, or when host policy does not authorize dispatch, Ralph must
perform roles inline and record `Parallel trigger: none`. When dispatch is
selected by an active skill dispatch policy without a ralplan handoff or direct
subagent wording, record `Parallel trigger: natural-dispatch` only if the host
permits proactive dispatch; otherwise record the explicit standing preference,
approved profile, or fallback reason.

A standing user or plan preference to maximize subagents is an explicit dispatch
signal for the whole eligible Ralph run. Use it to dispatch isolated roles when they provide decision-changing benefit within Codex host-policy limits, especially read-heavy exploration, test/log analysis, verification, QA, security, code review, other independent review roles, and disjoint implementation (executor) work in STANDARD/THOROUGH when write scopes are non-overlapping per `docs/shared/ralph-subagent-policy.md`. It is not a command
to spawn roles whose output would not change the implementation, review,
verification, or ship/block decision.

When Ralph reaches cleanup on Codex, use the Oh No Harness `simplify` skill.
Apply `docs/platforms/codex-simplify.md` through the generated Codex Simplify
runtime document.

## Invocation

When dispatch is selected, use Codex `spawn_agent`.

Codex SessionStart is the primary custom-agent preparation path. It runs
`scripts/install-codex-agents --scope user --ensure --quiet` so missing
generated `oh-no-*` agents install and stale ones refresh quietly; the Codex
Ralph adapter repeats the same best-effort user-scope ensure as a fallback.
Installed files carry the plugin version marker (so they refresh after a plugin
update without the user re-requesting installation) and pin the role-specific
5.6 model plus `model_reasoning_effort` so they do not depend on a user-specific
model config. Explore uses Terra at `medium`; analyst and executor use Sol at
`high`; the remaining Codex custom agents use Sol at `xhigh`. If ensure fails,
named custom-agent dispatch stays the default
whenever the host still recognizes `agent_type = "oh-no-<role>"`; record the
ensure failure and use the generic prompt-embedded fallback only after confirmed
custom-agent unavailability.

Use this dispatch order:

- `oh-no-<role>` when Oh No Harness Codex custom agents are installed in user
  scope and the current host recognizes that `agent_type`. This is required for
  Oh No Harness role dispatch, not just preferred.
- `explorer` for read-heavy repository exploration
- `worker` for scoped implementation with a disjoint write set
- `default` for specialized reviews, QA, security, verification, or critique
  when embedding the role prompt is clearer than a built-in type

Use `explorer`, `worker`, or `default` for an Oh No Harness role only when the
host rejects `oh-no-<role>` as unknown or unavailable, or the work is not an Oh
No Harness role. Record the fallback reason. Do not claim custom agents are
unavailable without a failed `spawn_agent(agent_type="oh-no-<role>", ...)`
attempt or an equivalent current host rejection. Do not infer unavailability
from rendered schema text, display comments, or missing shown parameters; the
first check is the actual `agent_type` call.

Do not use `fork_context = true` or a full-history fork with
`agent_type = "oh-no-<role>"`. Custom Ralph roles must receive the relevant
plan, scope, ownership, and evidence context in the spawn message, using one
payload shape only: prompt/message or items, never both. If a role cannot run
without the whole parent history, keep it inline or record a non-custom fallback
that the host explicitly supports.

The generated `oh-no-explore` custom-agent template sets
`sandbox_mode = "read-only"`. Other Oh No Harness role templates inherit the
active host sandbox and must still be scoped by the Ralph dispatch contract.

Spawn every independent non-blocking agent in the eligible batch before calling
`wait_agent`. Do not spawn one agent, wait, then spawn the rest.

After `wait_agent` returns a final status, capture the result and inspect any
changed-file set. A timeout, empty wait result, or "No agents completed yet" is
not a final status and is not result capture. Do not close a running subagent
merely because it is slow. Hard rule: MUST NOT call `close_agent` for a running
or pending Ralph subagent after timeout, no-completion, or empty wait output —
leave it running, wait longer when its result is needed, continue
non-overlapping work, or record the role as pending or blocked. Close without a
captured final result only when the user explicitly cancels or stops that
subagent, the task scope invalidates the work, the spawn was duplicate or
mis-scoped, or continuing creates a safety, security, or filesystem risk; record
that close as cancelled or abandoned and never use missing output as completion
evidence. When no more input is needed for a completed, failed, cancelled,
user-cancelled, scope-invalidated, or unsafe subagent and the host exposes
`close_agent`, call it. If `close_agent` reports the agent was already closed or
unavailable, record that instead of retrying. If the host exposes no explicit
close, record that closure is host-managed or unavailable.

## Role Prompt Embedding

Codex display names are not stable role identifiers. Registered Oh No Harness
custom-agent names and the dispatch message are the source of truth.

When using a generic Codex agent type, read the matching
`docs/agent-core/<role>.md` file and embed that platform-neutral prompt body in
the spawned agent message. Do not rely on the role name alone unless the
registered `oh-no-<role>` custom agent supplies the role developer
instructions. The embedded or registered prompt must preserve the role's
`Skill Relationship`, `Responsibilities`, `Operating Rules`, and `Output`
sections so the spawned agent receives the same behavioral contract as the
Claude Code plugin-scoped agent.

If `docs/agent-core/<role>.md` is unavailable but `agents/<role>.md` exists,
strip the Claude Code YAML frontmatter before embedding. Claude-only
frontmatter such as `tools`, `model`, `background`, `isolation`, or `color` is
metadata for Claude Code and must not be included in Codex spawned-agent prompt
content.

If the role is handled inline, keep the same role boundary in the caller's
notes. If the role is dispatched with a generic Codex agent type, the
spawned-agent message must embed the role prompt using the generic shape in
Prompt Shape below.

## Prompt Shape

Every role dispatch should include this task shape:

```text
Role: <explore|analyst|planner|plan-reviewer|executor|debugger|verifier|code-reviewer>
Codex agent type: oh-no-<role>   # or <explorer|worker|default> for the generic fallback
Story/task: <id and title>
Scope: <owned files/directories, or read-only areas>
Do not touch: <other agents' scopes>
Expected output: <patch, findings, evidence, or test result>
Verification responsibility: <command/evidence>
Lifecycle: caller captures the result, integrates or records it, then calls
close_agent for this completed subagent when the host exposes close_agent
Coordination: You are not alone in the codebase. Do not revert or overwrite
other agents' work. Stay inside your assigned scope.
```

For a registered `oh-no-<role>` custom agent, the TOML `developer_instructions`
already supplies the role prompt body, so keep the task prompt focused on the
fields above. For a generic `explorer`/`worker`/`default` fallback, add the
embedded role prompt:

```text
Agent prompt source: docs/agent-core/<role>.md
Agent prompt content:
<matching docs/agent-core/<role>.md prompt content>
```

If the host rejects `oh-no-<role>`, retry only through this generic
prompt-embedded path and record the fallback. For `worker` tasks, give each
agent an explicit ownership boundary; for read-only reviewers, state that they
must not edit files.
