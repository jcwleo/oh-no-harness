---
name: planning
description: "Create an executable implementation plan from a spec or clear request. Use --ral for a consensus plan with RALPLAN-DR, Architect, Critic, and ADR."
---

# planning

Planning turns a spec or clear request into executable tasks. It must not modify product source code.

## Sizing and anti-overplanning

Use the smallest planning surface that preserves correctness:

- Small, clear, low-risk edits may use an inline checklist instead of a persisted plan artifact.
- Standard multi-step or multi-file work should create a plan artifact.
- Use `--ral` only when consensus review is useful: security/auth, migrations, public API changes, architectural boundaries, broad refactors, data-loss risk, or unresolved tradeoffs.
- Keep tasks small enough to verify independently. A practical default is 3-7 tasks; if there are more, split into milestones.
- Do not add roles, artifacts, or review loops that do not reduce risk for the current task.

## Role passes

- Basic `planning`: `planner` owns the plan. Use `explore` first when repo facts are missing. Use `test-engineer` when test shape or regression proof is non-obvious.
- `planning --ral`: run `planner -> architect -> critic` in that order. Add `analyst` before the loop for hidden requirements when ambiguity remains. Add `test-engineer` before final approval for high-risk test strategy.
- Do not use extra role passes just because they exist; each pass should reduce a concrete risk or uncertainty.

If native subagents are unavailable, perform these as current-session role passes using the same order.

## Modes

### Basic mode

Use `planning` for normal implementation planning. Produce a plan with:

- Requirements summary
- File and module map
- Task list with stable IDs: `T-001`, `T-002`, ...
- For each task: objective, owned files, linked `AC-*` or `INV-*`, implementation notes, tests, expected output, and dependencies
- Risk and rollback notes
- Verification commands

### `--ral` mode

Use `planning --ral` when the work is high-risk, broad, architectural, or likely to benefit from adversarial review.

`--ral` is a superset of basic planning. It must include every basic-plan field plus:

- RALPLAN-DR summary:
  - Principles
  - Decision drivers
  - Viable options with bounded pros and cons
  - Explicit invalidation rationale when only one option remains
- Sequential role passes:
  1. Planner creates or revises the plan.
  2. Architect reviews architecture, tradeoffs, and the strongest counterargument.
  3. Critic checks consistency, missing risks, and testability.
- ADR:
  - Decision
  - Drivers
  - Alternatives considered
  - Why chosen
  - Consequences
  - Follow-ups

Architect and Critic are sequential. Critic reviews the plan after Architect feedback is incorporated or explicitly addressed.

## Root-cause planning

For bugfixes, regressions, flaky behavior, and unexpected implementation failures, the plan must include a root-cause step before the fix step. Do not plan a temporary workaround unless the user explicitly asks for a mitigation-first path or production safety requires a reversible stopgap.

If the cause cannot be proven from existing tests, logs, or code paths, include targeted diagnostic logging, tracing, assertions, or reproduction scripts that will make the cause observable. The plan must also say whether that instrumentation is removed before completion or intentionally kept as production observability.

## TDD and alternate verification

For behavior changes, bugfixes, and refactors, include a test-first step when practical:

1. RED: identify or add a failing test, assertion, fixture, or reproducible check.
2. GREEN: implement the smallest change that passes.
3. REFACTOR: simplify while preserving the passing check.

When test-first work is not practical, the plan must say why and define alternate verification evidence such as static checks, rendered output, fixture comparison, manual smoke path, or script output.

## Plan artifact

For persisted plans, write the plan to:

```text
docs/oh-no/plans/YYYY-MM-DD-<slug>-plan.md
```

Use `templates/plan.md` as the preferred structure. If the task is small enough for an inline checklist, still preserve `AC-*`/`INV-*` traceability in the final summary.

## Completion integrity

Do not cut corners. Inspect required evidence directly, do not use placeholders or cherry-picked results, and report blockers or verification gaps instead of pretending completion. Follow the bootstrap completion-integrity rule.

## Guardrails

- Do not edit product source code in `planning`.
- Do not start execution without a clear target.
- Do not drop `AC-*` or `INV-*` traceability from the source spec.
- If implementation would require a scope change, update the spec decision log or return to `clarify`.

## Handoff

Hand off to `ralph` with the spec path, plan path, remaining risks, and exact verification commands.
