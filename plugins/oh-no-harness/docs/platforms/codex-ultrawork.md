# Ultrawork Codex Adapter

<ADAPTER_CONTRACT>
This adapter binds the Ultrawork core to Codex. The core owns every
semantic decision; this file owns only host invocation and lifecycle
mechanics. If they conflict, the core wins. The generated core plus this
adapter is sufficient: longer platform, shared, and agent documents are
optional maintenance context, never a runtime prerequisite.
</ADAPTER_CONTRACT>

## Sub-Skill Invocation

Invoke `interview`, `ralplan`, and `ralph` through the installed Codex
skill mechanism with the artifact path as context; never ask the user to
type a command. The sub-skill's own generated wrapper is its source of
truth — do not restate its rules in the handoff prompt.

## Phase-Agent Dispatch

Dispatch is trigger-loaded — dispatch only after the active phase's trigger
fires. The Codex SessionStart block
`CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION` is the standing
session-level authorization for eligible phase-owned roles; do not ask for
per-run subagent approval to satisfy it. If `spawn_agent` is exposed, make
the actual registered-agent call first:

```text
spawn_agent(agent_type="oh-no-<role>", message=<self-contained packet>,
            fork_turns="none")
```

Only an actual unknown/unavailable `agent_type` rejection confirms the
custom role cannot be used; then use a generic agent with the matching
`docs/agent-core/<role>.md` prompt embedded and record the fallback. One
payload shape per spawn; no `fork_context`. Pass the core-defined role envelope
and phase delta unchanged. Spawn the whole independent batch before
`wait_agent`. A timeout, empty
wait, or "No agents completed
yet" is not final — never close a running or pending subagent merely
because it is slow, and never use missing output as completion evidence.
Call `close_agent` only after capturing a final result, and only when the
host exposes it; if no close primitive exists, closure is host-managed —
record that and continue.

## Cross-Host Consult Channel

A named-THOROUGH Final Validation pair starts one Codex `code-reviewer`
and one transport-owner reviewer making exactly one foreground Claude call
with the identical redacted packet
(`claude --print --model opus --permission-mode dontAsk
--no-session-persistence`). A launch notice, background acknowledgement,
or empty output is unavailable evidence; on opposite-host unavailability
run the same-host parallel fallback and record it.

## Worktree Commands

Use ordinary `git worktree add .oh-no/worktrees/<task-slug> -b <branch>`
from the integration checkout; inspect task changes with
`git -C .oh-no/worktrees/<task-slug> status`. Remove the worktree only
after integration and post-merge verification complete.
