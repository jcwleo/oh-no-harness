---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, passing, implemented, verified, ready for review, safe to deliver, or when summarizing final status after edits or tests.
argument-hint: "<claim, task, plan, or changed-file scope>"
---

# Verification Before Completion

Do not claim success without fresh evidence.

This skill is both a standalone lightweight final gate and the final evidence gate inside `ralph` and `autopilot`. When those stronger workflows are active, use this skill to verify the final claim without weakening their PRD, review, cleanup, or QA requirements.

## Software Development Stage

Verification Before Completion is the final evidence stage.

Use it after implementation, debugging, cleanup, and relevant review are done, immediately before claiming the work is complete, fixed, passing, ready, or safe to deliver.

## When To Use

Use before saying that:

- a task is complete
- a bug is fixed
- tests, lint, build, install, or smoke checks pass
- a plugin, skill, hook, or agent is ready
- a branch or artifact is ready for user review

Do not use as a substitute for `ralph` when the work needs PRD tracking, cleanup, and review loops.

## Agent Roles

| Agent | Use |
|---|---|
| `verifier` | Map the claim to evidence and run or inspect the required checks. |
| `code-reviewer` | Review behavior-affecting code or workflow prompt changes when risk warrants it. |
| `security-reviewer` | Review auth, data, file system, network, secrets, or policy-sensitive changes. |
| `qa-tester` | Validate user-facing flows or scenario coverage. |

On subagent-capable hosts, dispatch `verifier` by default for nontrivial
completion claims so evidence mapping stays independent from the implementation
thread. Add `code-reviewer`, `security-reviewer`, or `qa-tester` subagents when
the changed scope, selected verification tier, or user-facing risk warrants
them. Inline verification is appropriate only for tiny direct checks with no
context-separation benefit or when dispatch is unavailable; record that fallback
or no-benefit reason before making the claim.

On Codex, when SessionStart injects
`CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION`, treat that block as the
standing explicit user request for the default `verifier` and risk-gated
`code-reviewer`, `security-reviewer`, and `qa-tester` roles in this skill. Do
not ask for per-run subagent approval before dispatching those evidence or
review roles when the claim is nontrivial or risk warrants them.

When any verification role is dispatched, apply the active platform's role
prompt and dispatch requirements before the claim, evidence scope, expected
output, and no-edit instruction for read-only review roles.

## Required Gate

Before making a completion claim:

1. State the exact claim to verify.
2. Identify the command, artifact, diff inspection, or checklist that can prove it.
3. Run or inspect the evidence fresh in the current work pass.
4. Read the output and exit status.
5. Compare evidence to acceptance criteria.
6. Report skipped checks and residual risk.

If no meaningful command exists, inspect the changed files and write a manual verification checklist instead of implying automated confidence.

## Evidence Rules

- A previous run is not fresh evidence unless no file or dependency changed since that run.
- A passing lint check does not prove tests pass.
- A passing unit test does not prove a user-facing flow works when the acceptance criteria require the flow.
- For behavior-changing work, verify RED/GREEN/REFACTOR evidence or a documented TDD exception.
- When an agent reports success, inspect the changed files or artifacts before repeating the claim.

## Output

Return:

- Claim verified.
- Evidence used.
- Commands or inspections performed.
- Acceptance criteria status.
- Skipped checks and reason.
- Residual risk.

## Next Skill Handoff

None — this is the final evidence gate. Return the result to the caller (`ralph`, `autopilot`, or direct invocation). Do not chain to another workflow skill.
