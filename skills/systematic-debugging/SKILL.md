---
name: systematic-debugging
description: Use when a bug, failing test, failing command, regression, flaky behavior, build failure, install failure, hook failure, unexpected output, or unknown root cause needs investigation before fixes.
argument-hint: "<failure, command, bug report, or unexpected behavior>"
---

# Systematic Debugging

Find the root cause before changing behavior.

This skill is the direct debugging entry point for failures that do not need the full `ralph` execution loop.

## When To Use

Use for:

- failing tests, builds, installs, hooks, or smoke checks
- regressions and unexpected behavior
- flaky or environment-sensitive behavior
- performance or integration failures
- repeated unsuccessful fixes

Do not use for greenfield feature work. Use `ralplan` or `ralph` when the task is broader than a bounded failure.

## Agent Roles

Dispatch the listed subagents in the order shown. Inline execution is the exception per `ralph`'s `## Subagent Dispatch Default` (no subagent support, explicit user opt-out, or a verifier-tier single-line check).

| Agent | Dispatch (when) |
|---|---|
| `debugger` | Dispatch `debugger` subagent to reproduce the failure, identify root cause, and recommend the minimal fix. |
| `explore` | Dispatch `explore` subagent to gather codebase facts, related call sites, working examples, and commands. |
| `executor` | Dispatch `executor` subagent to apply the minimal fix only after root cause and reproduction evidence exist. |
| `verifier` | Dispatch `verifier` subagent to confirm the fix and package evidence. |
| `architect` | Dispatch `architect` subagent to reassess direction after repeated failed fixes or architecture-level coupling. |

## Debugging Flow

1. Capture the exact failure command, input, environment, or user-visible symptom.
2. Reproduce the failure, or explain why it cannot be reproduced yet.
3. Read the relevant error output, logs, stack trace, and changed files.
4. Find the closest working example in the same codebase.
5. State one root-cause hypothesis with evidence.
6. Test the hypothesis with the smallest diagnostic step.
7. For behavior fixes, read and follow `test-driven-development` to create a failing reproduction test before changing production code.
8. Apply the minimal fix with `executor` or inline work.
9. Run the reproduction check, relevant regression checks, and `verification-before-completion` before claiming the failure is fixed.

## Stop Conditions

Stop and ask or escalate to `architect` when:

- the failure cannot be reproduced and more data is needed from the user
- three different fix attempts failed
- the apparent fix requires broad architecture or API changes
- the investigation exposes product behavior, data handling, security, or delivery-scope ambiguity

## Anti-Patterns

- Changing code before reproducing or locating the failure.
- Fixing the stack-trace line when the bad value originated elsewhere.
- Bundling cleanup or refactors with a bug fix.
- Adding broad retries, catch-all handlers, or sleeps without evidence.
- Treating a later passing test as TDD evidence when no failing reproduction was observed first.

## Output

Return:

- Failure reproduced or reproduction blocker.
- Root cause and evidence.
- Reproduction test or documented exception.
- Fix summary.
- Verification commands and results.
- Residual risk.
