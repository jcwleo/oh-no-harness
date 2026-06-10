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
| `verifier` | Map the claim to evidence and run or inspect the required checks; apply the scenario lens to validate user-facing flows or scenario coverage. |
| `code-reviewer` | Review behavior-affecting code or workflow prompt changes when risk warrants it; apply the security lens to auth, data, file system, network, secrets, or policy-sensitive changes. |

On subagent-capable hosts, dispatch `verifier` by default for nontrivial
completion claims so evidence mapping stays independent from the implementation
thread. Add a `code-reviewer` subagent (security lens included) when the
changed scope, selected verification tier, or user-facing risk warrants it;
`verifier` applies its scenario lens when user-facing behavior changed.
Inline verification is appropriate only for tiny direct checks with no
context-separation benefit or when dispatch is unavailable; record that fallback
or no-benefit reason before making the claim.

On Codex, when SessionStart injects
`CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION`, treat that block as the
standing explicit user request for the default `verifier` and risk-gated
`code-reviewer` roles in this skill. Do not ask for per-run subagent approval
before dispatching those evidence or review roles when the claim is nontrivial
or risk warrants them.

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
6. Complete the Risk Check Before Completion below.
7. Report skipped checks and residual risk.

If no meaningful command exists, inspect the changed files and write a manual verification checklist instead of implying automated confidence.

When measurable evidence influenced the work, also apply
`docs/shared/validation-check.md`. Treat that evidence as a diagnostic
signal, not as the acceptance criteria.

## Acceptance-To-Evidence Mapping

Do not treat a command list as proof by itself. Before claiming completion,
map each acceptance criterion or requested behavior to concrete evidence:

```text
Acceptance-to-evidence mapping:
- Criterion:
  - Evidence:
  - Coverage strength: direct | indirect | manual | missing
  - Gap or residual risk:
```

Direct evidence is a focused test, scenario, or inspection that would fail if
the requested behavior were absent or wrong. Indirect evidence, broad suites,
lint, typecheck, formatting, and compile checks are useful support, but they do
not replace direct acceptance evidence for behavior-changing work.

## Risk Check Before Completion

Before final completion, actively look for the most likely way local green
evidence could still miss the real user, maintainer, or uncovered behavior.
Keep the questions category-level and requirements-driven instead of
case-specific.

Record:

```text
Risk check before completion:
- Acceptance criteria covered by direct evidence:
- Acceptance criteria only covered indirectly:
- Likely edge case a skeptical maintainer would test:
- Adjacent subsystem or public contract most likely affected:
- One more useful failing test I would write if time allowed:
- Completion claim:
```

The completion claim should distinguish:

- complete with direct evidence
- locally verified with explicit residual risk
- blocked or incomplete because evidence is missing

## Validation Check

For evidence-informed work, record:

```text
Validation check:
- Evidence used:
- Recurring software engineering failure mode:
- User or maintainer outcome:
- Acceptance signal:
- Why this should apply to similar work:
- Case-specific details deliberately excluded:
- Added process cost or risk:
- Completion claim:
```

Reject completion claims whose only support is metric movement, unseen-check
guessing, task-name-specific guidance, or a measurable metric that does not match the
real user, maintainer, operator, or public contract.

## Evidence Rules

- A previous run is not fresh evidence unless no file or dependency changed since that run.
- A passing lint check does not prove tests pass.
- A passing unit test does not prove a user-facing flow works when the acceptance criteria require the flow.
- A broad suite pass does not prove a new semantic contract unless the new
  behavior is directly represented in that suite.
- For behavior-changing work, verify RED/GREEN/REFACTOR evidence or a documented TDD exception.
- When an agent reports success, inspect the changed files or artifacts before repeating the claim.

## Output

Return:

- Claim verified.
- Evidence used.
- Commands or inspections performed.
- Acceptance criteria status.
- Acceptance-to-evidence mapping.
- Risk check before completion and completion claim.
- Validation check and risk from metric-only evidence when applicable.
- Skipped checks and reason.
- Residual risk.

## Next Skill Handoff

None — this is the final evidence gate. Return the result to the caller (`ralph`, `autopilot`, or direct invocation). Do not chain to another workflow skill.
