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

Derive every name from the actual verification role and audit lens; for
example:

```text
spawn_agent(task_name="verification_before_completion_verifier_audit_1", agent_type="oh-no-verifier", message=<self-contained packet>, fork_turns="none")
```

Roles are `verifier` and `code-reviewer`; use role-correct unique equivalents
for other or sibling audits. Only an actual
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

9. When a `code-reviewer` was dispatched, record `single-reviewer` for the
   default one full-role Codex review, or `perspective-pair` plus the fired
   named trigger and `same-host-perspective-pair` / `cross-host` /
   `same-host-parallel-fallback`; only the fallback requires a reason. Missing
   review topology is a named ledger gap, not a pass.

| `verifier` | map the claim to evidence and run or inspect the required checks; scenario lens for user-facing flows; dispatched only on a named V4 trigger, and then a single self-host independent pass, never a cross-host or same-host pair |
| `code-reviewer` | review behavior-affecting code or workflow prompt changes when risk warrants it; security lens for auth, data, file system, network, secrets, or policy-sensitive changes; ONE full-role instance by default, escalating to a perspective-diverse pair only on the named trigger that also selects cross-host escalation (cross-host merge: merged findings) |

Pair-specific mechanics apply ONLY when that named trigger actually fired; with
no fired trigger, spawn exactly one full-role reviewer. When it did fire:
The two review legs receive redacted packets identical except the single `Assigned perspective:` line.

## Cross-Host Consult Channel

This channel opens ONLY after a named THOROUGH `code-reviewer` trigger actually
fires; absent that trigger there is no second leg to consult. A fired trigger
starts one Codex reviewer and
one transport-owner making exactly one foreground Claude call. A launch notice,
background acknowledgement, or empty output is unavailable evidence; on
opposite-host unavailability run `same-host-parallel-fallback` and record the
required fallback reason. An explicitly selected pair keeps strict fallback
semantics. The `verifier` is never paired.
