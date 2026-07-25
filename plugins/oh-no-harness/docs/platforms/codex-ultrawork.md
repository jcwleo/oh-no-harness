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

Derive every name from the actual Ultrawork role and phase; for example:

```text
spawn_agent(task_name="ultrawork_planner_planning_1", agent_type="oh-no-planner", message=<self-contained packet>, fork_turns="none")
```

Use role-correct unique equivalents for other or sibling phase dispatches. Only
an actual unknown/unavailable `agent_type` rejection confirms the
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

## Review Pair Modes

Every dispatched Final Validation `code-reviewer` review runs as one
perspective-diverse pair. STANDARD uses two Codex reviewers and records
`same-host-perspective-pair`; this is intentional same-host review, so no
fallback reason is required. A fired named THOROUGH trigger selects cross-host
review when available, or `same-host-parallel-fallback` when the opposite host
is unavailable; record the required fallback reason.

The two review legs receive redacted packets identical except the single `Assigned perspective:` line.

## Cross-Host Consult Channel

A fired named THOROUGH Final Validation trigger starts one Codex
`code-reviewer` and one transport-owner reviewer making exactly one foreground
Claude call (`claude --print --model opus --permission-mode dontAsk
--no-session-persistence`). A launch notice, background acknowledgement, or
empty output is unavailable evidence; on opposite-host unavailability run
`same-host-parallel-fallback` and record the required fallback reason.

## Worktree Commands

Use ordinary `git worktree add .oh-no/worktrees/<task-slug> -b <branch>`
from the integration checkout; inspect task changes with
`git -C .oh-no/worktrees/<task-slug> status`. Remove the worktree only
after integration and post-merge verification complete.
