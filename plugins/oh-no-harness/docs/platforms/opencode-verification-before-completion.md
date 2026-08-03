# Verification Before Completion OpenCode Adapter

<ADAPTER_CONTRACT>
This adapter binds the Verification Before Completion core to OpenCode. The
core owns semantic decisions; this file owns approvals, dispatch, waits, result
intake, and handoffs. The generated core plus this adapter is self-contained.
</ADAPTER_CONTRACT>

## Independent Audit

Only after the core's named trigger fires, call `task` with exact
`subagent_type: oh-no-verifier`; risk-gated review uses
`subagent_type: oh-no-code-reviewer`. Direct user forms are
`@oh-no-verifier` and `@oh-no-code-reviewer`. Pass the core role envelope and
verification delta unchanged, including claim, acceptance mapping, exact
revision, evidence freshness, scope, output envelope, and stop conditions.

Foreground `task` return is the wait and final result. If background mode is
used, wait for the automatic completion notification; do not poll, duplicate,
or substitute inline work. Capture and bind the result to the audited revision
before making a completion claim. If a required independent context is
unavailable, record `dispatch-unavailable` and return blocked/PAUSED. Inline
verification is allowed only when the core does not require independence.

## Review Topology And Models

One full-role reviewer is the default. Only a core-selected perspective pair
issues two `oh-no-code-reviewer` tasks in one assistant turn, with identical
packets except `Assigned perspective:`, and captures both before synthesis. The
verifier is never paired.

OpenCode has no per-task model override. Configured roles use their stored
provider/model IDs; unconfigured roles inherit the primary model. Same-role
tasks prove independent contexts, not model diversity. Record a selected pair
as `same-model-perspective-pair`; strict model-diversity demand PAUSES.

## Questions And Return

Use `question` only when the core requires user acceptance of residual risk or
an unblock decision, and wait for the answer. This is a final evidence gate:
return the revision-bound result to its caller or report the standalone result.
Do not load a next workflow skill.
