# Verification Before Completion Codex Adapter

<ADAPTER_CONTRACT>
This adapter binds the Verification Before Completion core to Codex. The
core owns every semantic decision; this file owns only host invocation and
lifecycle mechanics. If they conflict, the core wins. The generated core
plus this adapter is sufficient: longer platform, shared, and agent
documents are optional maintenance context, never a runtime prerequisite.
</ADAPTER_CONTRACT>

## Role Dispatch

Dispatch is trigger-loaded — dispatch only after the core's trigger fires.
If `spawn_agent` is exposed, make the actual registered-agent call first:

```text
spawn_agent(agent_type="oh-no-<role>", message=<self-contained packet>,
            fork_turns="none")
```

Roles are `verifier` and `code-reviewer`. Only an actual
unknown/unavailable `agent_type` rejection confirms the custom role cannot
be used; then use a generic agent with the matching
`docs/agent-core/<role>.md` prompt embedded and record the fallback. One
payload shape per spawn; no `fork_context`. Pass the core-defined role envelope
and verification delta unchanged. A timeout, empty wait, or queued acknowledgement
is not final — never close
a running or pending subagent merely because it is slow, and never use
missing output as completion evidence. If no separate agent context exists,
inline verification is allowed only when the core does not require an
independent audit; otherwise report the `dispatch-unavailable` blocker so the
caller remains blocked/PAUSED. Close a completed receiver only if the host
exposes a close primitive; if none exists, closure is host-managed — record
that and continue.

## Re-Homed Core Pair Rules

9. When a `code-reviewer` was dispatched, record `single-reviewer` for
   STANDARD, or the named THOROUGH pair trigger plus `cross-host` /
   `same-host-parallel-fallback`; an inline fallback requires a reason.
   Missing review topology is a named ledger gap, not a pass.

| `verifier` | map the claim to evidence and run or inspect the required checks; scenario lens for user-facing flows; an unconditionally single self-host independent pass, never a cross-host or same-host pair |
| `code-reviewer` | review behavior-affecting code or workflow prompt changes when risk warrants it; security lens for auth, data, file system, network, secrets, or policy-sensitive changes; one instance for STANDARD, a pair only for a named THOROUGH trigger (cross-host merge: merged findings) |

## Cross-Host Consult Channel

A named-THOROUGH paired `code-reviewer` starts one Codex reviewer and one
transport-owner making exactly one foreground Claude call with the
identical redacted packet. A launch notice, background acknowledgement, or
empty output is unavailable evidence; on opposite-host unavailability run
the same-host parallel fallback and record it. The `verifier` is never
paired.
