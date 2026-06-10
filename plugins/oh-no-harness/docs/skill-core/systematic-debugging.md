---
name: systematic-debugging
description: Use when a bug, failing test, failing command, regression, flaky behavior, build failure, install failure, hook failure, unexpected output, or unknown root cause needs investigation before fixes.
argument-hint: "<failure, command, bug report, or unexpected behavior>"
---

# Systematic Debugging

Find the root cause before changing behavior.

This skill is the direct debugging entry point for failures that do not need the full `ralph` execution loop.

## Software Development Stage

Systematic Debugging is the failure-investigation and repair stage.

Use it when tests, builds, runtime behavior, installs, hooks, or user reports show a concrete failure. It should establish reproduction and root cause before returning to implementation or verification.

## When To Use

Use for:

- failing tests, builds, installs, hooks, or smoke checks
- regressions and unexpected behavior
- flaky or environment-sensitive behavior
- performance or integration failures
- repeated unsuccessful fixes

Do not use for greenfield feature work. Use `ralplan` or `ralph` when the task is broader than a bounded failure.

## Agent Roles

Use the listed roles as the failure requires. On subagent-capable hosts, dispatch
isolated diagnostic and evidence roles by default so logs, traces, and exploratory
output do not pollute the main thread. The default flow is diagnostic first
(`debugger` and, when context is missing, `explore`), then the minimal fix
(`executor` subagent when the write scope is isolated, otherwise inline with a
recorded reason), then evidence (`verifier`). `plan-reviewer` is a
conditional escalation role, not a required final step: use it immediately when
three fix attempts fail, architecture-level coupling appears, or the apparent
fix would change broad APIs, product behavior, data handling, security, or
delivery scope. Dispatch is governed by the active skill's platform policy and
Ralph's `## Mode-Gated Agent Dispatch` when this debugging pass is inside Ralph.
For direct debugging outside Ralph, apply `docs/shared/ralph-subagent-policy.md`
and `docs/shared/parallel-subagents.md` for role isolation, fallback reasons, and
eligible batch dispatch.

On Codex, when SessionStart injects
`CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION`, treat that block as the
standing explicit user request for this skill's diagnostic, fix, evidence, and
post-fix review roles. Do not ask for per-run subagent approval before
dispatching `debugger`, `explore`, isolated `executor`, `verifier`,
conditional `plan-reviewer`, or warranted post-fix review roles. Use inline fallback
only when dispatch is unavailable, unsafe to isolate, or too small to benefit,
and record the fallback reason.

Respect the active platform wrapper for dispatch versus inline execution. Do not
collapse diagnostic or evidence roles inline when the host can dispatch them
with an isolated scope. When any listed role is dispatched, apply the active platform's role prompt and
dispatch requirements before the task-specific failure, scope, expected output,
and verification responsibility.

| Agent | Dispatch (when) |
|---|---|
| `debugger` | Dispatch `debugger` subagent to reproduce the failure, identify root cause, and recommend the minimal fix. |
| `explore` | Dispatch `explore` subagent to gather codebase facts, related call sites, working examples, and commands. |
| `executor` | Dispatch `executor` subagent to apply the minimal fix only after root cause and reproduction evidence exist. |
| `verifier` | Dispatch `verifier` subagent to confirm the fix and package evidence. |
| `plan-reviewer` | Dispatch `plan-reviewer` subagent as a conditional escalation to reassess direction after three failed fix attempts, when architecture-level coupling is exposed, or before broad API/product/data/security/scope changes. |
| `code-reviewer` | Dispatch `code-reviewer` post-fix when the changed code is nontrivial, shared, workflow-affecting, or maintainability-sensitive. |
| `security-reviewer` | Dispatch `security-reviewer` post-fix when auth, data, file system, network, secrets, sandbox, or policy-sensitive behavior is touched. |
| `qa-tester` | Dispatch `qa-tester` post-fix when the failure affects user-facing flows, scenarios, or acceptance criteria. |

## Debugging Flow

1. Capture the exact failure command, input, environment, or user-visible symptom.
2. Reproduce the failure, or explain why it cannot be reproduced yet.
3. Read the relevant error output, logs, stack trace, and changed files.
4. Find the closest working example in the same codebase.
5. State one root-cause hypothesis with evidence.
6. Test the hypothesis with the smallest diagnostic step.
7. For behavior fixes, read and follow `test-driven-development` to create a failing reproduction test before changing production code.
8. Apply the minimal fix with `executor` when the write scope is isolated; use inline work only with a recorded reason.
9. Dispatch warranted post-fix review roles when the changed scope or risk requires them.
10. Run the reproduction check, relevant regression checks, and `verification-before-completion` before claiming the failure is fixed.

## Stop Conditions

Stop and ask or escalate to `plan-reviewer` when:

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

## Next Skill Handoff

None — this is a failure-investigation mid-loop skill. After verification, return the result to the caller (`ralph`, `autopilot`, or direct invocation). Do not chain to another workflow skill.
