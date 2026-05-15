# Codex Ralph Adapter

CODEX_ONLY_RALPH_ADAPTER

Use this adapter only on Codex. Do not apply it on Claude Code or other
platforms.

## Explicit Trigger

Codex must not start subagents merely because Ralph is active. Codex should use
subagents only when the current user request or approved plan explicitly asks
for subagents, delegation, or parallel agent work.

Treat these phrases as explicit triggers:

- `subagent`
- `spawn`
- `delegate`
- `parallel agents`
- `parallel subagents`
- `one agent per`
- `ralph with parallel subagents`

When no explicit trigger is present, Ralph must perform roles inline and record
`Parallel trigger: none`.

## Invocation

When a trigger is present, use Codex `spawn_agent`.

Prefer:

- `explorer` for read-heavy repository exploration
- `worker` for scoped implementation with a disjoint write set
- `default` for specialized reviews, QA, security, verification, or critique
  when embedding the role prompt is clearer than a built-in type

Spawn every independent non-blocking agent in the eligible batch before calling
`wait_agent`. Do not spawn one agent, wait, then spawn the rest.

## Ralph Prompt Shape

Every Codex Ralph dispatch should include:

```text
Role: <explore|executor|verifier|code-reviewer|security-reviewer|qa-tester>
Codex agent type: <explorer|worker|default>
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
