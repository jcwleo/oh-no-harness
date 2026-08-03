# Ralplan OpenCode Adapter

<ADAPTER_CONTRACT>
This adapter binds the Ralplan core to OpenCode. The core owns semantic
decisions; this file owns approvals, dispatch, waits, result intake, and
handoffs. The generated core plus this adapter is self-contained.
</ADAPTER_CONTRACT>

## Dispatch

Use `task` with exact `subagent_type: oh-no-<role>` for `explore`, `analyst`,
`planner`, and `plan-reviewer`; direct user mentions are `@oh-no-<role>`.
Dispatch only at the core phase that selected the role. Every packet contains
run/phase, role, exact bounded task, requirements source, Direction Contract,
Active Plan Contract, scope/non-goals, required output, dependency/return owner,
and the exact draft ID plus full draft or path when applicable.

Analyst, Planner, and Plan-Reviewer are sequential. Foreground `task` return is
the wait and final result: capture and validate it before changing phase. A
timeout, error, background-start notice, or empty output is not a usable result.
For background tasks, wait for the automatic completion notification; do not
poll, duplicate, or replace pending work inline.

If an optional role is unavailable, use the core's visibly separate inline
fallback and record it. A required Plan-Reviewer must remain independent: role
unavailability records `dispatch-unavailable` and transitions PAUSED rather
than substituting an inline review.

## Review Topology And Models

The core alone selects topology. `single-reviewer` dispatches one full-role
`oh-no-plan-reviewer` with no assigned lens. A selected perspective pair issues
two reviewer tasks in one assistant turn with identical packets except the
single `Assigned perspective:` line, then captures both before synthesis.

OpenCode provides no per-task model override. A configured reviewer uses its
stored provider/model ID; an unconfigured reviewer inherits the invoking
primary model. Two calls to `oh-no-plan-reviewer` are independent contexts but
are not proof of model diversity. Record `same-model-perspective-pair`; if
strict model diversity was explicitly required, PAUSE and report that distinct
model identities cannot be guaranteed by this binding.

## Approval Handoff

Use one `question` call for the core's four combined Next Skill Handoff choices.
After explicit approve-and-run, load `ralph` or `ultrawork` through `skill` with
the exact frozen plan and execution profile. Under Ultrawork, return the
approved artifact and control without another approval prompt.
