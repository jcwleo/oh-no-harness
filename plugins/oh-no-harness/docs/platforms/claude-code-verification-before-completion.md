# Verification Before Completion Claude Code Adapter

<ADAPTER_CONTRACT>
This adapter binds the Verification Before Completion core to Claude Code.
The core owns every semantic decision; this file owns only host invocation
and lifecycle mechanics. If they conflict, the core wins. The generated
core plus this adapter is sufficient: longer platform, shared, and agent
documents are optional maintenance context, never a runtime prerequisite.
</ADAPTER_CONTRACT>

## Role Dispatch

Dispatch `verifier` and risk-gated `code-reviewer` through the exposed
Task, Agent, Workflow `agent()`, or subagent primitive with the plugin
agents (`oh-no-harness:<agent>`; manual mention
`@agent-oh-no-harness:<agent>`). Dispatch is trigger-loaded — dispatch only
after the core's trigger fires. Each packet carries: the exact claim;
evidence scope (changed files, AC-ID ledger reference, commands); expected
output (evidence mapping, verdict, findings); and the no-edit instruction
for read-only roles. A notification, timeout, or empty wait result is not
a final status; capture the result, then close or clean up the completed
subagent when the host exposes that mechanism. If a plugin-scoped agent is
unavailable, embed the matching `agents/<agent>.md` prompt into the
available subagent mechanism; with no subagent primitive, verify inline
and record the fallback reason.

## Cross-Host Consult Channel

A named-THOROUGH paired `code-reviewer` dispatches the current-host
reviewer and the `code-reviewer-codex` transport with identical packets;
the consult is read-only, foreground, one hop, returning the actual
opposite-host result. On opposite-host unavailability run the same-host
parallel fallback and record it. The `verifier` is never paired.
