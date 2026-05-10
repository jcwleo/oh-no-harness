---
name: debug
description: "Investigate a bug, failing test, regression, or runtime error from concrete evidence before proposing or applying a fix."
when_to_use: "Use for bugs, failing tests, regressions, runtime errors, flaky behavior, pasted logs, or unexplained symptoms where root cause should be established before fixing."
argument-hint: "[symptom|failing-command|log]"
arguments: [evidence]
---

# debug

Debugging starts from evidence, not guesses. The default outcome is a root-cause fix, not a temporary workaround.

## Argument intake

Treat `$ARGUMENTS` as the raw symptom, failing command, log reference, or reproduction hint. The named `$evidence` argument is a convenience alias for the same user-provided text; prefer `$ARGUMENTS` when preserving exact command lines or pasted error fragments matters.

## Use when

- A test, build, runtime path, or user flow fails.
- Logs, stack traces, screenshots, or reproduction steps are available.
- A fix is risky without understanding the real code path.
- Previous fixes failed or produced new symptoms.

## Hard gate

Do not propose or apply a fix until Phase 1 root-cause investigation has produced evidence for what is failing and why. If a temporary mitigation is required for safety, label it as mitigation, keep it reversible, and continue tracking the root-cause fix.

## Worktree and mutation safety

Read-only diagnosis may inspect the current checkout. Before adding diagnostic files, reproduction scripts, assertions, or code fixes, check the plan/progress artifact and current checkout state. If worktree isolation is marked `required`, the checkout has unrelated work, or another lane may edit concurrently, do mutation-heavy debugging inside the assigned worktree or create one through helper resolution (`scripts/worktree-start` when project-local, installed oh-no helper when available, otherwise manual `git worktree add`). If dirty changes are relevant to the bug or fix, carry them deliberately into the worktree instead of starting from a clean base that omits them. Record the worktree path, branch, and baseline result with the debugging evidence. Do not mix failures from the main checkout with claims about a worktree fix.

## Role passes

- `explore`: map the relevant files, symbols, logs, tests, and reachable code path.
- `debugger`: owns root-cause analysis and hypothesis testing.
- `test-engineer`: defines the regression proof when the failure needs a durable test or reproduction check.
- `executor` or `ralph`: applies the fix only after the cause is understood or a clearly labeled mitigation is required.

If native subagents are unavailable, perform the same role passes in the current session.

## Four-phase process

### Phase 1: Root-cause investigation

Before fixes:

1. Capture the exact symptom, expected behavior, environment, command/user flow, and newest evidence.
2. Read stack traces, logs, test output, and error messages completely.
3. Reproduce the failure or explain exactly why reproduction is unavailable.
4. Inspect the live implementation path before relying on design docs or memory.
5. Trace backward from the failure to the first wrong value, wrong branch, missing call, race, config mismatch, or external boundary.
6. If the cause is not observable, add targeted diagnostic logging, tracing, assertions, or a reproduction script to make it observable.
7. Record evidence as file paths, line references, commands, log snippets, or runtime observations.

Exit Phase 1 only when there is a concrete failing component/path and a reason it fails.

### Phase 2: Pattern analysis

Before changing code:

1. Find nearby working patterns, reference implementations, tests, config, API contracts, and conventions.
2. Read the relevant pattern completely enough to avoid cargo-culting partial code.
3. Compare the failing path against the working pattern: what is different, missing, inverted, stale, unordered, rounded, cached, raced, or misconfigured?
4. Identify whether the requested fix belongs in the failing local path, shared abstraction, caller, data contract, test fixture, or configuration.

Skip unrelated refactors. Pattern analysis exists to make the smallest correct fix obvious.

### Phase 3: Hypothesis and testing

1. State the smallest falsifiable hypothesis: "I think X is the root cause because Y evidence shows Z."
2. Choose one minimal diagnostic or code change that can confirm or refute the hypothesis.
3. Do not stack multiple speculative fixes before checking evidence.
4. If the hypothesis fails, remove or abandon the failed change, update the evidence, and form a new hypothesis.
5. If two or more fix attempts fail, stop and re-run Phase 1/2; if three or more fail or symptoms keep moving, escalate to architecture/pattern review instead of adding another patch.

### Phase 4: Implementation

When the root cause is confirmed:

1. Confirm whether implementation must happen in a worktree, and switch to the assigned/created worktree before mutation when required.
2. Create or identify a regression proof when practical. For bug fixes, prefer a failing test, reproduction script, assertion, fixture comparison, or command that shows the original symptom.
3. Apply the smallest root-cause fix, not a symptom mask.
4. Run the targeted regression proof and relevant adjacent checks in the same checkout/worktree where the fix was applied.
5. Remove or gate temporary diagnostics unless intentionally retained as observability.
6. Record the evidence connecting cause to fix, including the checkout/worktree path.
7. Hand off to `ralph` for implementation work when the fix spans multiple files/tasks, and finish with `verify` before claiming completion.

## Output

For investigation-only work, return:

- Confirmed cause, or `not yet confirmed` with the precise missing evidence.
- Evidence with file, line, command, log, or runtime references.
- Reachability notes: whether the failing path is actually exercised.
- Pattern comparison: what the working path does differently, when relevant.
- Risk level and suggested next action when requested.

For fix work, hand off to `ralph` or continue with the same evidence-first loop and finish with `verify`.

## Completion integrity

Do not cut corners. Inspect required evidence directly, do not use placeholders or cherry-picked results, and report blockers or verification gaps instead of pretending completion. Follow the bootstrap completion-integrity rule.

## Guardrails

- Do not infer from stale design docs when live code is available.
- Do not widen scope beyond the failing path unless evidence requires it.
- Do not remove tests to make a failure disappear.
- Do not paper over symptoms with sleeps, retries, catch-all fallbacks, disabled checks, broad guards, or silent fallbacks unless explicitly documented as a temporary mitigation.
- Do not make multiple speculative changes before testing the hypothesis.
- If a temporary workaround is unavoidable for safety, label it as such, keep it reversible, and continue tracking the root-cause fix.
- Diagnostic logs must be targeted, safe for secrets/PII, and removed or gated before final completion unless intentionally retained.
