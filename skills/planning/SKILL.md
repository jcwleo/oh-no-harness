---
name: planning
description: "Create an executable implementation plan from a spec or clear request. Integrates Superpowers-style writing-plans with RALPLAN-style consensus review through basic mode and --ral mode."
when_to_use: "Use after a clear request or approved spec when the next step is an executable task plan; use --ral for high-risk, broad, architectural, or disputed trade-off planning."
argument-hint: "[--ral] [spec-or-request]"
arguments: [mode, target]
---

# planning

Planning turns a spec or clear request into executable tasks. It must not modify product source code. Its output should be complete enough that an executor with little repository context can implement task-by-task without guessing.

## Sizing and anti-overplanning

Use the smallest planning surface that preserves correctness:

- Small, clear, low-risk edits may use an inline checklist instead of a persisted plan artifact.
- Standard multi-step or multi-file work should create a plan artifact.
- Use `--ral` only when consensus review is useful: security/auth, migrations, public API changes, architectural boundaries, broad refactors, data-loss risk, or unresolved tradeoffs.
- Keep tasks small enough to verify independently. A practical default is 3-7 tasks; if there are more, split into milestones.
- Do not add roles, artifacts, or review loops that do not reduce risk for the current task.

`--ral` is a planning mode, not a clarify mode. Use `planning --ral` only after the desired outcome is clear enough to plan; if the outcome is still unclear, return to `clarify` first, using `clarify --deep` only for high-risk ambiguity.

## Hard gate

Planning does not implement, edit product source, scaffold code, run mutation-oriented setup, or start execution. It may inspect files, map code paths, and write/update the plan artifact. Execution begins only after handoff to `ralph` or an explicitly requested execution lane.

## Role passes

- Basic `planning`: `planner` owns the plan. Use `explore` first when repo facts are missing. Use `test-engineer` when test shape, RED/GREEN proof, or alternate verification is non-obvious.
- `planning --ral`: run `planner -> architect -> critic` in that order. Add `analyst` before the loop for hidden requirements when ambiguity remains. Add `test-engineer` before final approval for high-risk test strategy.
- Do not use extra role passes just because they exist; each pass should reduce a concrete risk or uncertainty.

If native subagents are unavailable, perform these as current-session role passes using the same order.

## Common intake

Before writing tasks:

1. Read the source spec, design, user request, or checklist.
2. Inspect repository facts needed to plan accurately: file layout, existing patterns, tests, configs, public interfaces, and recent relevant changes.
3. Identify whether the input is too broad. If it contains independent subsystems, split into milestones or separate plans, each producing working, testable software on its own.
4. Preserve traceability from `AC-*`, `INV-*`, `DEC-*`, and open risks into task IDs.
5. Decide whether worktree isolation is required before execution:
   - inspect dirty state before deciding;
   - required when the current checkout has unrelated dirty work, the user or other agents may work in parallel, tasks are long-lived, branches may diverge, or file ownership may overlap;
   - if dirty changes are part of the current task, plan an explicit carry-forward step by commit, patch, or another named transfer; do not let a new clean worktree drop required changes;
   - optional for small, single-lane, low-risk edits;
   - not needed for read-only planning/review.
6. Record plan metadata: `Mode: basic | ral`, `Size: inline-checklist | artifact-plan | milestone`, `Worktree isolation: required | optional | not needed`, source spec path or `inline`, and status.

## Modes

### Basic mode

Use `planning` for normal implementation planning. Produce a plan with:

- Requirements summary tied to `AC-*` and `INV-*` IDs.
- File and module map: exact paths/modules likely touched, relevant tests, and patterns to follow.
- Task list with stable IDs: `T-001`, `T-002`, ...
- For each task: objective, owned files/modules, linked `AC-*` or `INV-*`, implementation notes, test-first or verification-first step, commands, expected output, dependencies, and rollback notes when relevant.
- Worktree isolation decision: dirty-change classification, recommended branch name, suggested path, baseline command, helper resolution or manual fallback, and whether execution must start in an isolated worktree.
- Risk and mitigation notes.
- Exact verification commands.

### `--ral` mode

Use `planning --ral` when the work is high-risk, broad, architectural, or likely to benefit from adversarial review.

`--ral` is a superset of basic planning. It must include every basic-plan field plus:

- RALPLAN-DR summary:
  - 3-5 principles.
  - Top decision drivers.
  - At least two viable options with bounded pros and cons, unless only one option is valid.
  - Explicit invalidation rationale when only one option remains.
- Sequential role passes:
  1. Planner creates or revises the plan.
  2. Architect reviews architecture, tradeoffs, the strongest counterargument, and synthesis path when possible.
  3. Critic checks principle-option consistency, fair alternatives, missing risks, risk mitigation clarity, testability, and concrete verification steps.
- Re-review loop: if Architect or Critic rejects or finds material gaps, Planner revises the plan, then Architect and Critic review again in order. Stop only when the plan is approved or the remaining disagreement is explicitly recorded as a planning risk.
- ADR:
  - Decision
  - Drivers
  - Alternatives considered
  - Why chosen
  - Consequences
  - Follow-ups

Architect and Critic are sequential. Critic reviews the plan only after Architect feedback is incorporated or explicitly addressed.

## Task granularity

Tasks must be bite-sized and executable in order:

- Prefer one behavior, module boundary, or verification target per task.
- Each task should leave the system in a buildable or at least clearly checkpointed state.
- Avoid giant tasks like "implement backend" or vague tasks like "add tests".
- Include enough local context for an executor to work without rereading the whole repository: exact paths, symbols, APIs, fixtures, commands, and linked IDs.
- Do not write placeholders such as `TBD`, `similar to previous task`, `etc.`, `write tests as needed`, or `handle edge cases` without naming the actual behavior or evidence.

## Root-cause planning

For bugfixes, regressions, flaky behavior, and unexpected implementation failures, the plan must include a root-cause step before the fix step. Do not plan a temporary workaround unless the user explicitly asks for a mitigation-first path or production safety requires a reversible stopgap.

If the cause cannot be proven from existing tests, logs, or code paths, include targeted diagnostic logging, tracing, assertions, or reproduction scripts that will make the cause observable. The plan must also say whether that instrumentation is removed before completion or intentionally kept as production observability.

## TDD and alternate verification

For behavior changes, bugfixes, and refactors, include a test-first step when practical:

1. RED: identify or add a failing test, assertion, fixture, reproduction script, or command that proves the missing/buggy behavior.
2. Verify RED: run the target check and record the expected failure signal.
3. GREEN: implement the smallest change that passes.
4. Verify GREEN: rerun the target check and relevant adjacent checks.
5. REFACTOR: simplify while keeping the checks green.

When test-first work is not practical, the plan must say why and define alternate verification evidence such as static checks, rendered output, fixture comparison, manual smoke path, script output, or file inspection.

## Plan artifact

For persisted plans, write the plan to:

```text
docs/oh-no/plans/YYYY-MM-DD-<slug>-plan.md
```

Use `templates/plan.md` as the preferred structure. If the task is small enough for an inline checklist, still preserve `AC-*`/`INV-*` traceability in the final summary.

## Plan self-review

Before handoff, review the plan with fresh eyes:

- Coverage: every in-scope `AC-*` and `INV-*` has at least one task or verification entry.
- Placeholder scan: no `TBD`, vague `etc.`, missing commands, or `similar to previous` shortcuts.
- File map consistency: file paths, symbols, API names, task dependencies, and test names agree across the plan.
- Scope discipline: unrelated refactors are excluded; necessary cleanup is tied to a task and acceptance ID.
- Verification adequacy: each task has a check, and the final verification path can prove the claims.
- RAL mode: Architect and Critic feedback is incorporated or explicitly rejected with rationale.

Fix plan defects inline before handoff.

## Completion integrity

Do not cut corners. Inspect required evidence directly, do not use placeholders or cherry-picked results, and report blockers or verification gaps instead of pretending completion. Follow the bootstrap completion-integrity rule.

## Guardrails

- Do not edit product source code in `planning`.
- Do not start execution without a clear target.
- Do not drop `AC-*` or `INV-*` traceability from the source spec.
- Do not hide unresolved assumptions; record them as plan risks or return to `clarify`.
- If implementation would require a scope change, update the spec decision log or return to `clarify`.

## Handoff

Hand off to `ralph` with the spec path, plan path, mode, remaining risks, first task ID, role-pass needs, and exact verification commands. If the user asks to skip planning after a plan exists, still provide the plan path and first executable checkpoint rather than implementing inside `planning`.

When worktree isolation is required, include the exact setup command in the handoff when the helper is available, for example:

```sh
scripts/worktree-start feature/<slug> --baseline 'scripts/validate-skills'
```

If project-local `scripts/worktree-start` is not available, say whether to use the installed oh-no harness helper or the manual `git worktree add` fallback. If dirty changes are relevant to the task, include the explicit carry-forward step before execution begins.
