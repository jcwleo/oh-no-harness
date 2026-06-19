# Claude Code Ralph Adapter

CLAUDE_CODE_ONLY_RALPH_ADAPTER

Use this adapter only on Claude Code. Do not apply it on Codex or other
platforms.

When Ralph reaches cleanup on Claude Code, invoke the generated Oh No Harness
Claude Code Simplify runtime document (`skills-claude/simplify/SKILL.md`) as
the cleanup contract. Do not route Ralph-internal cleanup to a host built-in
`/simplify` skill, because that route may not load the Oh No Harness cleanup
contract for the current plugin version.

## Invocation

When Ralph dispatches a role, use Claude Code's Task, Agent, Workflow `agent()`,
or subagent mechanism with the plugin-scoped agents from `agents/`.

An approved `ralplan` handoff to ordinary `oh-no-harness:ralph` is the default
parallel-capable execution path. Treat `Parallel trigger:
approved-plan-handoff` as authorization to use every eligible isolated role in
the approved plan; do not require a separate `ralph with parallel subagents`
choice. Authorization is not a command to dispatch roles whose output would not
change the implementation, review, verification, or ship/block decision.

Use `oh-no-harness:<agent>` as the agent name when the tool lists plugin agents.
When explicit prompt text or a user-facing manual mention is needed, use
`@agent-oh-no-harness:<agent>`.

For independent read-only, review, verification, QA, security, or exploration
work, request background subagents and start the whole independent batch before
waiting for any one result.

After each background subagent reaches a final status, capture its result and
changed-file set. When no further input is needed, close or clean up that
completed subagent with the Claude Code mechanism exposed by the host. If the
host does not expose explicit close or cleanup, record that no close mechanism
was available.

If a plugin-scoped agent is unavailable, keep the same role boundary by
embedding the matching `agents/<agent>.md` prompt into the available Claude Code
subagent mechanism.

## Ralph Prompt Shape

Every Claude Code Ralph dispatch should include:

```text
Role: oh-no-harness:<agent>
Story/task: <id and title>
Scope: <owned files/directories, or read-only areas>
Do not touch: <other agents' scopes>
Expected output: <patch, findings, evidence, or test result>
Verification responsibility: <command/evidence>
Background: <yes for independent work, no when sequential>
Lifecycle: caller captures the result, integrates or records it, then closes or
cleans up this completed subagent when the host exposes that mechanism
Coordination: You are not alone in the codebase. Do not revert or overwrite
other agents' work. Stay inside your assigned scope.
```

## Batch Discipline

For an eligible independent batch, issue all Claude Code subagent requests
before waiting. After they return, integrate their outputs in Ralph and run the
verification required by the selected execution mode. Close or clean up each
completed subagent after its output has been captured and no further input is
needed.
