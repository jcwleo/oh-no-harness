# Codex Ralph Adapter

CODEX_ONLY_RALPH_ADAPTER

Use this adapter only on Codex. Do not apply it on Claude Code or other
platforms.

## Dispatch Decision

Codex must not start subagents merely because Ralph is active. `spawn_agent`
availability is host-policy controlled. Use subagents only when the current
Codex host tool definition permits dispatch and Ralph's selected execution mode,
agent policy, task risk, and scope isolation make delegation useful for
context-window management, independent evidence, or latency.

Explicit phrases are sufficient dispatch signals:

- `subagent`
- `spawn`
- `delegate`
- `parallel agents`
- `parallel subagents`
- `one agent per`
- `ralph with parallel subagents`

They are not required only on hosts whose tool definition permits natural
dispatch and when the active skill policy already allows it for a concrete
isolated scope. When no dispatch-worthy role or scope exists, or when host policy
does not authorize dispatch, Ralph must perform roles inline and record
`Parallel trigger: none`. When dispatch is selected without an explicit user or
plan trigger on a host that allows natural dispatch, record
`Parallel trigger: natural-dispatch`.

A standing user or plan preference to maximize subagents is an explicit dispatch
signal for the whole eligible Ralph run. Use it to dispatch isolated roles as
much as possible within Codex host-policy limits, especially read-heavy
exploration, test/log analysis, verification, QA, security, code review, and
other independent review roles.

## Invocation

When dispatch is selected, use Codex `spawn_agent`.

Prefer:

- `explorer` for read-heavy repository exploration
- `worker` for scoped implementation with a disjoint write set
- `default` for specialized reviews, QA, security, verification, or critique
  when embedding the role prompt is clearer than a built-in type

Spawn every independent non-blocking agent in the eligible batch before calling
`wait_agent`. Do not spawn one agent, wait, then spawn the rest.

## Role Prompt Embedding

Codex display names are not stable role identifiers. The dispatch message is
the source of truth.

Before every Codex `spawn_agent` call for an Oh No Harness role, read the
matching `agents/<role>.md` file and embed that prompt content in the spawned
agent message. Do not rely on the role name alone. The embedded prompt must
preserve the role's `Skill Relationship`, `Responsibilities`, `Operating
Rules`, and `Output` sections so the spawned agent receives the same behavioral
contract as the Claude Code plugin-scoped agent.

If the role is handled inline, keep the same role boundary in the caller's
notes. If the role is dispatched, the spawned-agent message must include:

```text
Agent prompt source: agents/<role>.md
Agent prompt content:
<paste the matching agents/<role>.md prompt content>
```

## Prompt Shape

Every Codex role dispatch should include:

```text
Role: <explore|analyst|planner|architect|critic|executor|debugger|verifier|code-reviewer|security-reviewer|qa-tester>
Codex agent type: <explorer|worker|default>
Agent prompt source: agents/<role>.md
Agent prompt content:
<matching agents/<role>.md prompt content>
Story/task: <id and title>
Scope: <owned files/directories, or read-only areas>
Do not touch: <other agents' scopes>
Expected output: <patch, findings, evidence, or test result>
Verification responsibility: <command/evidence>
Coordination: You are not alone in the codebase. Do not revert or overwrite
other agents' work. Stay inside your assigned scope.
```

For `worker` tasks, give each agent an explicit ownership boundary. For
read-only reviewers, state that they must not edit files.
