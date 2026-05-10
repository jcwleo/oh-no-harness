---
name: ralph
description: "Execute a clear spec, plan, checklist, or focused task until implementation is verified and reviewed."
---

# ralph

Ralph is the execution loop. It implements only after a clear target exists and it does not claim completion without fresh evidence.

## Required target

Start only when at least one of these exists:

- A spec artifact
- A plan artifact
- A concrete checklist
- A focused task with clear files and acceptance criteria

If the target is vague, return to `clarify` or `planning`.

## Execution loop

1. Read the relevant spec and plan sections before each task.
2. Select the next `T-*` task or focused checklist item.
3. Confirm linked `AC-*` and `INV-*` IDs.
4. Implement the smallest coherent change.
5. Run the task's verification command and read the output.
6. Record progress for long work.
7. Run reviewer/verifier role passes before final completion.
8. Fix any failed verification or review finding and repeat.

## Role passes

Use these roles according to the task shape:

- `executor`: implements assigned tasks and owns source changes.
- `debugger`: diagnoses failures, flaky behavior, or unclear root cause before fixes.
- `test-engineer`: defines or reviews test-first and regression evidence when test shape is non-trivial.
- `verifier`: checks `AC-*` and `INV-*` compliance before completion.
- `code-reviewer`: reviews quality, security, maintainability, and hidden regressions after spec compliance.
- `architect`: reviews architecture-sensitive or broad changes before final completion.

Default order for normal work: `executor -> verifier`; add `debugger`, `test-engineer`, `code-reviewer`, or `architect` only when their risk area applies. If native subagents are unavailable, run the same role passes in-session.

## Progress artifact

For long work or context-window-sized tasks, update:

```text
docs/oh-no/runs/YYYY-MM-DD-<slug>-progress.md
```

Use `templates/progress.md` as the preferred structure. Include:

- Current task state
- Completed `T-*` items
- Changed files
- Verification commands and results
- Spec conflicts or decision-log updates
- Remaining work

## Resume and context-window protocol

On resume, after compaction, or when context may be stale:

1. Read the source spec first.
2. Read the plan second.
3. Read the latest progress artifact third.
4. Reconstruct remaining `T-*`, `AC-*`, and `INV-*` IDs from artifacts, not memory.
5. Continue from the first incomplete task.
6. If memory conflicts with artifacts, trust artifacts and record the discrepancy.
7. If artifacts are missing for long work, create or repair the progress artifact before continuing.

## Root-cause implementation discipline

When implementation hits a failure, regression, flaky test, or unexpected runtime behavior, diagnose the root cause before fixing. Do not hide the symptom with retries, sleeps, broad catches, fallback branches, disabled checks, or other temporary workarounds unless the plan explicitly calls for a reversible mitigation.

If the root cause is not observable, add targeted diagnostic logging, tracing, assertions, or a reproduction script to expose it. Keep diagnostic output narrow and safe: avoid secrets, PII, noisy hot-path logs, and permanent debug spam. Before completion, remove the instrumentation or gate it behind an intentional debug/observability switch and document why it remains.

Record the evidence that connects cause to fix in the progress artifact or final summary.

## SDD discipline

SDD means spec-driven development. The spec is the source of truth across long tasks and context compaction.

- If code conflicts with the spec, do not silently change code first.
- For small corrections, update the spec decision log and continue.
- For major scope changes, return to `clarify` or `planning --ral`.
- The final verifier checks `AC-*` and `INV-*` fulfillment, not only test pass status.

## Fresh-lane strategy

If the host supports native subagents and tasks have disjoint file ownership, Ralph may use fresh executor lanes. Keep default concurrency at three lanes or fewer. If lanes share files, global config, migrations, or types, use a single owner lane instead.

Host mapping:

- Claude Code: dispatch bounded role passes through native subagents/Task using the generated Claude `agents/*.md` definitions when available.
- Codex: dispatch bounded role passes with `spawn_agent` and Codex custom-agent TOML definitions when installed; otherwise use the markdown role prompt in the current session.
- Do not assume Codex plugin installation automatically installs custom agents; skills and current-session role passes remain the reliable fallback.

When subagents are unavailable, run the same sequence as current-session role passes.

## Completion gate

Completion requires:

- All planned tasks complete or explicitly deferred.
- Fresh verification evidence for every completed claim.
- No `PARTIAL` or `MISSING` required acceptance criteria.
- Reviewer or verifier sign-off.
- A concise final summary with changed files, commands, outcomes, and remaining risks.

Do not claim completion from confidence alone.

## Completion integrity

Do not cut corners. Inspect required evidence directly, do not use placeholders or cherry-picked results, and report blockers or verification gaps instead of pretending completion. Follow the bootstrap completion-integrity rule.
