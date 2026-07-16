# Ultrawork Claude Code Adapter

<ADAPTER_CONTRACT>
This adapter binds the Ultrawork core to Claude Code. The core owns every
semantic decision; this file owns only host invocation and lifecycle
mechanics. If they conflict, the core wins. The generated core plus this
adapter is sufficient: longer platform, shared, and agent documents are
optional maintenance context, never a runtime prerequisite.
</ADAPTER_CONTRACT>

## Sub-Skill Invocation

Invoke `interview`, `ralplan`, and `ralph` through the host skill
mechanism with the artifact path as context; never ask the user to type a
command. The sub-skill's own generated wrapper is its source of truth —
do not restate its rules in the handoff prompt.

## Phase-Agent Dispatch

Dispatch phase agents through the exposed Task, Agent, Workflow `agent()`,
or subagent primitive with the plugin agents from `agents/`
(`oh-no-harness:<agent>`; manual mention `@agent-oh-no-harness:<agent>`).
Dispatch is trigger-loaded — dispatch only after the active phase's trigger
fires. Batch independent background agents before waiting; a notification,
timeout, or empty wait result is not a final status. Capture each result
and changed-file set, then close or clean up the completed subagent when
the host exposes that mechanism; record when no close mechanism exists. If
a plugin-scoped agent is unavailable, embed the matching `agents/<agent>.md`
prompt into the available subagent mechanism.

## Cross-Host Consult Channel

A named-THOROUGH Final Validation pair dispatches the current-host
`code-reviewer` and the `code-reviewer-codex` transport with identical
packets; the Codex consult is read-only, foreground, one hop, and returns
the actual opposite-host result. On opposite-host unavailability run the
same-host parallel fallback and record it.

## Worktree Commands

Use ordinary `git worktree add .oh-no/worktrees/<task-slug> -b <branch>`
from the integration checkout; inspect task changes with
`git -C .oh-no/worktrees/<task-slug> status`. Remove the worktree only
after integration and post-merge verification complete.
