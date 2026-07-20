# Systematic Debugging Codex Adapter

<ADAPTER_CONTRACT>
This adapter binds the Systematic Debugging core to Codex. The core owns
every semantic decision; this file owns only host invocation and lifecycle
mechanics. If they conflict, the core wins. The generated core plus this
adapter is sufficient: longer platform, shared, and agent documents are
optional maintenance context, never a runtime prerequisite.
</ADAPTER_CONTRACT>

## Role Dispatch

Dispatch is trigger-loaded — dispatch only after the core's trigger fires.
If `spawn_agent` is exposed, make the actual registered-agent call first:

```text
spawn_agent(agent_type="oh-no-<role>", message=<self-contained packet>,
            fork_turns="none")
```

Roles are `debugger`, `explore`, `executor`, `verifier`, and
`code-reviewer`. Only an actual unknown/unavailable `agent_type` rejection
confirms the custom role cannot be used; then use a generic agent with the
matching `docs/agent-core/<role>.md` prompt embedded and record the
fallback. One payload shape per spawn; no `fork_context`. Pass the core-defined
role envelope and debugging delta unchanged. Spawn parallel hypothesis
debuggers as one batch before `wait_agent`. A timeout, empty wait, or queued acknowledgement is not
final — never close a running or pending subagent merely because it is
slow, and never use missing output as completion evidence. Close a
completed receiver only if the host exposes a close primitive; if none
exists, closure is host-managed — record that and continue.

## Re-Homed Core Pair Rules

| `debugger` | one instance to reproduce, identify root cause, and recommend the minimal fix; a paired cross-host or same-host investigation ONLY for a named THOROUGH uncertainty or repeated-failure trigger |
| `verifier` | confirm the fix and package evidence; scenario lens for user-facing flows; an unconditionally single self-host independent pass, never a cross-host or same-host pair — required when the proving tests or fix were authored or accepted by the same agent |
| `code-reviewer` | post-fix when the changed code is nontrivial, shared, workflow-affecting, or maintainability-sensitive, or its security lens is needed because auth, data, file system, network, secrets, sandbox, or policy-sensitive behavior is touched; cross-host merge: merged findings |

STANDARD uses one dispatched reviewer or debugger instance; a pair requires
a named THOROUGH trigger, with same-host parallel fallback recorded when the
opposite host is unavailable.

Do not emit the Output below until every dispatched review records topology:
`single-reviewer` for STANDARD, or a named THOROUGH pair with `cross-host` /
`same-host-parallel-fallback`; an inline fallback requires a reason.
Missing review topology is a named ledger gap, not a pass.

## Cross-Host Consult Channel

A named-THOROUGH paired `debugger` or post-fix `code-reviewer` starts one
Codex role and one transport-owner making exactly one foreground Claude
call with the identical redacted packet. A launch notice, background
acknowledgement, or empty output is unavailable evidence; on opposite-host
unavailability run the same-host parallel fallback and record it.
