# Claude Code Ralph Adapter

CLAUDE_CODE_ONLY_RALPH_ADAPTER

<ADAPTER_CONTRACT>
This adapter binds the Ralph core to Claude Code. The core owns every
semantic decision; this file owns only host invocation and lifecycle
mechanics. If they conflict, the core wins. The generated core plus this
adapter is sufficient: longer platform, shared, and agent documents are
optional maintenance context, never a runtime prerequisite. Do not apply it
on Codex or other platforms.
</ADAPTER_CONTRACT>

## Invocation

When Ralph dispatches a role, use Claude Code's Task, Agent, Workflow
`agent()`, or subagent mechanism with the plugin-scoped agents from
`agents/`. Use `oh-no-harness:<agent>` as the agent name when the tool lists
plugin agents; when explicit prompt text or a user-facing manual mention is
needed, use `@agent-oh-no-harness:<agent>`. Dispatch is trigger-loaded —
dispatch only after the active skill's trigger fires.

An approved `ralplan` handoff to ordinary `oh-no-harness:ralph` is the
default parallel-capable execution path: treat
`Parallel trigger: approved-plan-handoff` as authorization for every
eligible isolated role in the approved plan, without a separate "parallel
subagents" choice. Authorization is not a command to dispatch roles whose
output would not change the implementation, review, verification, or
ship/block decision.

For independent read-only, review, verification, QA, security, or
exploration work — and for disjoint implementation (executor) work in
STANDARD/THOROUGH when write scopes are non-overlapping — request background
subagents and start the whole independent batch before waiting for any one
result.

If a plugin-scoped agent is unavailable, keep the same role boundary by
embedding the matching `agents/<agent>.md` prompt into the available Claude
Code subagent mechanism.

## Dispatch Packet Additions

Add to the core dispatch packet:

```text
Role: oh-no-harness:<agent>
Background: <yes for independent work, no when sequential>
```

## Lifecycle

After each background subagent reaches a final status, capture its result
and changed-file set. When no further input is needed, close or clean up
that completed subagent with the Claude Code mechanism exposed by the host;
if the host does not expose explicit close or cleanup, record that no close
mechanism was available. A notification, timeout, or empty wait result is
not a final status.

## Cross-Host Consult Channel

Paired THOROUGH review on Claude Code dispatches the current-host
`code-reviewer` and the `code-reviewer-codex` transport with identical
packets; the Codex consult is read-only, foreground, one hop, and returns
the actual opposite-host result. On opposite-host unavailability run the
same-host parallel fallback and record it.

## Cleanup

When Ralph reaches the CLEANUP checkpoint on Claude Code, use the host
built-in `simplify` skill when available as the cleanup contract.
