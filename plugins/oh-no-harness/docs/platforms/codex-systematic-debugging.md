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

Derive every name from the actual debugging role and hypothesis or phase; for
example:

```text
spawn_agent(task_name="systematic_debugging_debugger_hypothesis_1", agent_type="oh-no-debugger", message=<self-contained packet>, fork_turns="none")
```

Roles are `debugger`, `explore`, `executor`, `verifier`, and `code-reviewer`;
use role-correct unique equivalents for other or sibling dispatches. Only an
actual unknown/unavailable `agent_type` rejection
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

| `debugger` | exactly one instance per independently testable eligible hypothesis in one complete batch; one sequential instance when fan-out is ineligible; a paired cross-host or same-host investigation ONLY for one named THOROUGH uncertainty when fan-out is not active |
| `verifier` | confirm the fix and package evidence; scenario lens for user-facing flows; dispatched only on a named trigger from the core's verifier predicate, and then a single self-host independent pass, never a cross-host or same-host pair |
| `code-reviewer` | post-fix when the changed code is nontrivial, shared, workflow-affecting, or maintainability-sensitive, or its security lens is needed because auth, data, file system, network, secrets, sandbox, or policy-sensitive behavior is touched; ONE full-role instance on Codex by default, escalating to a perspective-diverse pair only on the named trigger that also selects cross-host escalation (cross-host merge: merged findings) |

STANDARD dispatches one `debugger` per independently testable eligible
hypothesis in the complete batch, or one sequential debugger when fan-out is
ineligible. Only when fan-out is inactive may a named THOROUGH trigger select a
cross-host or same-host debugger pair for one named uncertainty; never multiply
that pair across hypotheses. A dispatched post-fix `code-reviewer` review
spawns exactly ONE full-role Codex reviewer, recorded as single-reviewer.
Pair-specific mechanics apply ONLY when that named pair trigger actually fired;
it then runs as an intentional same-host perspective pair recorded
`same-host-perspective-pair`, with no fallback reason. When the opposite host is
unavailable for a triggered pair, record `same-host-parallel-fallback` and the
required fallback reason. An explicitly selected pair keeps strict fallback
semantics.

Report every result, but do not classify it as passing until every dispatched review records topology:
an eligible debugger batch records `hypothesis-fanout:<count>`; use
`single-reviewer` for a sequential STANDARD debugger and for the default
one full-role Codex post-fix review; use
`perspective-pair` plus `same-host-perspective-pair`, `cross-host`, or
`same-host-parallel-fallback` only for a triggered post-fix `code-reviewer` pair
or a triggered
THOROUGH debugger pair. An inline fallback requires a reason. Missing review
topology is a named ledger gap, not a pass. The `verifier` is never paired.

The two review legs receive redacted packets identical except the single `Assigned perspective:` line.

## Cross-Host Consult Channel

This channel opens ONLY after a named THOROUGH pair trigger actually fires;
absent that trigger there is no second leg to consult. When hypothesis fan-out is
inactive, a fired named THOROUGH paired `debugger`
trigger starts one Codex role and one transport-owner making exactly one
foreground Claude call. A fired post-fix `code-reviewer` pair trigger likewise
starts one Codex role and one transport-owner making exactly one foreground
Claude call. A launch notice, background acknowledgement, or empty output is
unavailable evidence; on opposite-host unavailability run
`same-host-parallel-fallback` and record the required fallback reason.
