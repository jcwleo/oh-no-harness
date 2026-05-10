---
name: debug
description: "Investigate a bug, failing test, regression, or runtime error from concrete evidence before proposing or applying a fix."
---

# debug

Debugging starts from evidence, not guesses. The default outcome is a root-cause fix, not a temporary workaround.

## Use when

- A test, build, runtime path, or user flow fails.
- Logs, stack traces, screenshots, or reproduction steps are available.
- A fix is risky without understanding the real code path.

## Role passes

- `explore`: map the relevant files, symbols, logs, tests, and reachable code path.
- `debugger`: owns root-cause analysis and hypothesis testing.
- `test-engineer`: defines the regression proof when the failure needs a durable test or reproduction check.
- `executor` or `ralph`: applies the fix only after the cause is understood or a clearly labeled mitigation is required.

If native subagents are unavailable, perform the same role passes in the current session.

## Process

1. Capture the exact symptom and expected behavior.
2. Find the concrete failing path: logs, stack trace, test output, or runtime branch.
3. Inspect the current implementation before proposing causes.
4. Form the smallest falsifiable hypothesis.
5. If the cause is still ambiguous, add targeted diagnostic logging, tracing, assertions, or a reproduction script to make it observable.
6. Reproduce or explain why reproduction is unavailable.
7. Apply the smallest root-cause fix when implementation is requested.
8. Remove or gate temporary diagnostics before completion unless they are intentional observability.
9. Verify the fix with a targeted regression check.

## Output

For investigation-only work, return:

- Confirmed cause
- Evidence with file or command references
- Reachability notes
- Risk level
- Suggested next action when requested

For fix work, hand off to `ralph` or continue with the same evidence-first loop and finish with `verify`.

## Completion integrity

Do not cut corners. Inspect required evidence directly, do not use placeholders or cherry-picked results, and report blockers or verification gaps instead of pretending completion. Follow the bootstrap completion-integrity rule.

## Guardrails

- Do not infer from stale design docs when live code is available.
- Do not widen scope beyond the failing path unless evidence requires it.
- Do not remove tests to make a failure disappear.
- Do not paper over symptoms with sleeps, retries, catch-all fallbacks, disabled checks, or broad guards unless explicitly documented as a temporary mitigation.
- If a temporary mitigation is unavoidable for safety, label it as such, keep it reversible, and continue tracking the root-cause fix.
- Diagnostic logs must be targeted, safe for secrets/PII, and removed or gated before final completion unless intentionally retained.
