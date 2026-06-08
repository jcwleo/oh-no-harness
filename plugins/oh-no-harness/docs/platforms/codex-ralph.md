# Codex Ralph Adapter

CODEX_ONLY_RALPH_ADAPTER

Use this adapter only on Codex. Do not apply it on Claude Code or other
platforms.

## Dispatch Decision

Ralph is parallel-capable by default on Codex when the host exposes
`spawn_agent`. Codex must still respect host policy and isolation rules: use
subagents when the current Codex host tool definition permits dispatch and
Ralph's selected execution mode, agent policy, task risk, and scope isolation
make delegation useful for context-window management, independent evidence, or
latency.

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
active Oh No Harness skill policy records dispatch-by-default as workflow-level
authorization for a concrete isolated scope. When no dispatch-worthy role or
scope exists, or when host policy does not authorize dispatch, Ralph must
perform roles inline and record `Parallel trigger: none`. When dispatch is
selected by an active skill dispatch policy without a ralplan handoff or direct
subagent wording, record `Parallel trigger: natural-dispatch` only if the host
permits proactive dispatch; otherwise record the explicit standing preference,
approved profile, or fallback reason.

A standing user or plan preference to maximize subagents is an explicit dispatch
signal for the whole eligible Ralph run. Use it to dispatch isolated roles as
much as possible within Codex host-policy limits, especially read-heavy
exploration, test/log analysis, verification, QA, security, code review, and
other independent review roles.

## Invocation

When dispatch is selected, use Codex `spawn_agent`.

Codex SessionStart is the primary custom-agent preparation path. It runs
`scripts/install-codex-agents --scope user --ensure --quiet` so missing
generated `oh-no-*` agents are installed and stale generated files refresh
without adding success noise to every prompt.

The Codex Ralph adapter repeats the same best-effort user-scope quiet ensure as
a fallback before this point. The installed files carry the plugin version
marker, so stale generated agents can refresh after a plugin update without
requiring the user to ask for agent installation again. Generated templates
also pin `gpt-5.5` / `model_reasoning_effort = "xhigh"` so they do not depend
on inheriting a user-specific model config. If ensure fails, named custom-agent
dispatch is optional; record the failure and use the generic prompt-embedded
fallback.

Prefer:

- `oh-no-<role>` when Oh No Harness Codex custom agents are installed in user
  scope and the current host recognizes that `agent_type`
- `explorer` for read-heavy repository exploration
- `worker` for scoped implementation with a disjoint write set
- `default` for specialized reviews, QA, security, verification, or critique
  when embedding the role prompt is clearer than a built-in type

The generated `oh-no-explore` custom-agent template sets
`sandbox_mode = "read-only"`. Other Oh No Harness role templates inherit the
active host sandbox and must still be scoped by the Ralph dispatch contract.

Spawn every independent non-blocking agent in the eligible batch before calling
`wait_agent`. Do not spawn one agent, wait, then spawn the rest.

After `wait_agent` returns a final status, capture the result and inspect any
changed-file set. When no more input is needed for that subagent and the host
exposes `close_agent`, call `close_agent` for the completed agent. If
`close_agent` reports that the agent was already closed or unavailable, record
that result instead of retrying. If the host does not expose explicit close,
record that closure is host-managed or unavailable.

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
spawned-agent message must include:

```text
Agent prompt source: docs/agent-core/<role>.md
Agent prompt content:
<paste the matching docs/agent-core/<role>.md prompt content>
```

## Prompt Shape

Every registered custom-agent role dispatch should include:

```text
Role: <explore|analyst|planner|architect|critic|executor|debugger|verifier|code-reviewer|security-reviewer|qa-tester>
Codex agent type: oh-no-<role>
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

When using a registered `oh-no-<role>` custom agent, the TOML
`developer_instructions` already supplies the role prompt body. Keep the task
prompt focused on story, scope, expected output, verification, and lifecycle;
if the host rejects that `agent_type`, retry only through the generic
prompt-embedded path and record the fallback.

Every generic Codex role dispatch should include the same task shape plus the
embedded role prompt:

```text
Role: <explore|analyst|planner|architect|critic|executor|debugger|verifier|code-reviewer|security-reviewer|qa-tester>
Codex agent type: <explorer|worker|default>
Agent prompt source: docs/agent-core/<role>.md
Agent prompt content:
<matching docs/agent-core/<role>.md prompt content>
```

For `worker` tasks, give each agent an explicit ownership boundary. For
read-only reviewers, state that they must not edit files.
