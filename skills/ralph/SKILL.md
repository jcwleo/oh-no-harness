---
name: ralph
description: "Execute a clear spec, plan, checklist, or focused task until implementation is verified, spec-compliant, and reviewed."
when_to_use: "Use when the target is already clear enough to implement from a spec, plan, checklist, or focused task and the work should be carried through verification."
argument-hint: "[spec|plan|task-id]"
arguments: [target]
---

# ralph

Ralph is the execution loop. It implements only after a clear target exists and it does not claim completion without fresh evidence, spec compliance, and review.

## Argument intake

Treat `$ARGUMENTS` as the raw execution target. The named `$target` argument is a convenience alias for a spec path, plan path, task ID, checklist, or focused task text. Prefer `$ARGUMENTS` when the target contains spaces, flags, or multiple references.

## Required target

Start only when at least one of these exists:

- A spec artifact
- A plan artifact
- A concrete checklist
- A focused task with clear files and acceptance criteria

If the target is vague, return to `clarify` or `planning`.

## Worktree isolation

Before mutation-heavy execution, decide whether to work in an isolated git worktree. Use isolation when:

- the current checkout is dirty or has unrelated user work;
- multiple tasks, agents, or humans may work concurrently;
- planned file ownership may overlap or branches may diverge;
- the plan marks `Worktree isolation: required`;
- the user explicitly requests conflict isolation.

Before creating the worktree, inspect the dirty diff. If dirty changes are unrelated, leave them in the current checkout. If dirty changes are part of the current task, carry them deliberately into the execution branch by commit, patch, or another explicit transfer step before editing; do not silently omit them by starting from a clean base.

Preferred setup:

```sh
scripts/worktree-start <branch-name>
```

Helper resolution order: project-local `scripts/worktree-start`, installed oh-no harness helper when its plugin/bundle path is available, then manual fallback. If the helper is unavailable, manually follow the same contract: choose `.worktrees/` first, then `worktrees/`, verify project-local worktree directories are gitignored, create a dedicated branch, run setup, and verify a clean baseline before editing. Record the worktree path and baseline result in the progress artifact. If baseline verification fails, report the failure and do not mix baseline failures with new implementation claims.

## Execution loop

For every task or checklist item:

1. Read the relevant spec and plan sections before the task.
2. Select the next `T-*` task or focused checklist item.
3. Confirm linked `AC-*`, `INV-*`, `DEC-*`, risks, owned files, dependencies, and verification commands.
4. If the plan includes TDD or verification-first work, follow its RED -> GREEN -> REFACTOR sequence. Do not replace it with tests-after unless the plan explicitly allows alternate evidence.
5. Implement the smallest coherent change inside the task ownership boundary.
6. Run the task's verification command and read the output.
7. Record progress for long work.
8. Run task-level review in this order when review is needed:
   1. Spec compliance review: `verifier` or `critic` checks linked `AC-*` and `INV-*` first.
   2. Code quality review: `code-reviewer` checks maintainability, security, regressions, and style after spec compliance is acceptable.
9. Fix any failed verification or review finding and repeat the same task until it passes or is explicitly blocked.
10. Continue to the next task only after required checks for the current task are resolved.

## Role passes

Use these roles according to the task shape:

- `executor`: implements assigned tasks and owns source changes.
- `debugger`: diagnoses failures, flaky behavior, or unclear root cause before fixes.
- `test-engineer`: defines or reviews test-first and regression evidence when test shape is non-trivial.
- `verifier`: checks `AC-*` and `INV-*` compliance before completion.
- `code-reviewer`: reviews quality, security, maintainability, and hidden regressions after spec compliance.
- `architect`: reviews architecture-sensitive or broad changes before final completion.

Default order for normal work: `executor -> verifier`; add `debugger`, `test-engineer`, `code-reviewer`, or `architect` only when their risk area applies. If both `verifier` and `code-reviewer` apply, spec compliance comes before code quality review. If native subagents are unavailable, run the same role passes in-session.

## Fresh-lane strategy

If the host supports native subagents and tasks have disjoint file ownership, Ralph may use fresh executor lanes. Keep default concurrency at three lanes or fewer.

Fresh-lane rules:

- Use parallel lanes only when file/module ownership is disjoint.
- Shared files, shared types, migrations, global config, lockfiles, or cross-cutting APIs require a single owner lane.
- When lanes must run concurrently and could affect the same checkout state, give each lane its own isolated worktree or serialize the work.
- Give each executor the full task text, relevant spec/plan excerpts, owned files, verification commands, and constraints; do not make a worker rediscover the whole plan.
- Tell each executor they are not alone in the codebase, must not revert others' edits, and must report shared-file conflicts upward.
- Each lane must self-check, then pass spec compliance review, then code quality review when required.
- If a lane is blocked, decide whether to answer the blocker, narrow scope, return to planning, or reassign; do not stack speculative fixes.

Host mapping:

- Claude Code: dispatch bounded role passes through native subagents/Task using the generated Claude `agents/*.md` definitions when available.
- Codex: dispatch bounded role passes with `spawn_agent` and Codex custom-agent TOML definitions when installed; otherwise use the markdown role prompt in the current session.
- Do not assume Codex plugin installation automatically installs custom agents; skills and current-session role passes remain the reliable fallback.

When subagents are unavailable, run the same sequence as current-session role passes.

## Progress artifact

For long work or context-window-sized tasks, update:

```text
docs/oh-no/runs/YYYY-MM-DD-<slug>-progress.md
```

Use `templates/progress.md` as the preferred structure. Include:

- Current task state
- Worktree path and branch, when isolation is used
- Completed `T-*` items
- Changed files
- Verification commands and results
- Spec compliance review status
- Code quality review status when applicable
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

If the root cause is not observable, add targeted diagnostic logging, tracing, assertions, or a reproduction script to expose it. Keep diagnostic output narrow and safe: avoid secrets, PII, noisy hot-path logs, and permanent debug spam. Before completion, remove the instrumentation or gate it behind an intentional debug/observability switch and document why it remains. See `docs/oh-no/techniques/root-cause-tracing.md` and `docs/oh-no/techniques/diagnostic-logging.md` for the bounded contract.

Record the evidence that connects cause to fix in the progress artifact or final summary.

## SDD discipline

SDD means spec-driven development. The spec is the source of truth across long tasks and context compaction.

- If code conflicts with the spec, do not silently change code first.
- For small corrections, update the spec decision log and continue.
- For major scope changes, return to `clarify` or `planning --ral`.
- The final verifier checks `AC-*` and `INV-*` fulfillment, not only test pass status.
- Spec compliance review must happen before code quality review; quality cannot excuse missing requirements.

## Final verification and review

Before final completion:

1. Rebuild the claim list from spec, plan, progress, user requirements, and changed files.
2. Run the smallest fresh checks that prove all claims; read the output.
3. Confirm no required `AC-*` or `INV-*` is `PARTIAL` or `MISSING`.
4. Run `verify` or an equivalent verifier pass.
5. Run `code-reviewer` for substantive code changes, and `architect` for architecture-sensitive changes.
6. Fix findings and rerun affected checks before claiming completion.

## Completion gate

Completion requires:

- All planned tasks complete or explicitly deferred with user-visible risk.
- Fresh verification evidence for every completed claim.
- Spec compliance review completed for linked `AC-*` and `INV-*`.
- Code quality/security review completed when substantive code changed.
- No `PARTIAL` or `MISSING` required acceptance criteria.
- Reviewer or verifier sign-off.
- A concise final summary with changed files, commands, outcomes, and remaining risks.

Do not claim completion from confidence alone.

## Finalization handoff

Ralph does not finalize branches or worktrees. If the task explicitly
asks for branch/worktree finalization after the completion gate passes,
hand off to `verify`, which owns the finalization protocol (merge
locally, push/create PR, keep as-is, or discard with typed
confirmation). Do not merge, push, delete branches, or remove worktrees
from inside the execution loop.

## Completion integrity

Do not cut corners. Inspect required evidence directly, do not use placeholders or cherry-picked results, and report blockers or verification gaps instead of pretending completion. Follow the bootstrap completion-integrity rule.
