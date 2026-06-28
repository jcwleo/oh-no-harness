---
name: systematic-debugging
description: Use when a bug, failing test, failing command, regression, flaky behavior, build failure, install failure, hook failure, unexpected output, or unknown root cause needs investigation before fixes.
argument-hint: "<failure, command, bug report, or unexpected behavior>"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Systematic Debugging for Claude Code

This generated file is the Claude Code-facing runtime skill document. Claude Code slash commands should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/systematic-debugging.md`
- `../../docs/platforms/claude-code-runtime.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/systematic-debugging.md

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

Use the listed roles as the failure requires. On subagent-capable hosts, use
isolated diagnostic and evidence roles when they provide decision-changing
evidence, context separation, or latency benefit so logs, traces, and
exploratory output do not pollute the main thread. The normal flow is diagnostic first
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

Apply the active platform's dispatch authorization for this skill's diagnostic,
fix, evidence, and post-fix review roles. Do not ask for per-run subagent
approval when the active platform already supplies standing authorization for
eligible `debugger`, `explore`, isolated `executor`, `verifier`, conditional
`plan-reviewer`, or warranted post-fix review roles. Use inline fallback only
when dispatch is unavailable, unsafe to isolate, or too small to benefit, and
record the fallback reason.

Respect the active platform runtime document for dispatch versus inline
execution. Do not collapse diagnostic or evidence roles inline when the host can
dispatch them with an isolated scope. When any listed role is dispatched, apply
the active platform's role prompt and dispatch requirements before the
task-specific failure, scope, expected output, and verification responsibility.

| Agent | Dispatch (when) |
|---|---|
| `debugger` | Dispatch `debugger` subagent to reproduce the failure, identify root cause, and recommend the minimal fix. By default, when the opposite host is available, run the investigation as cross-host analysis per `docs/shared/cross-host-review.md`: the current-host and opposite-host debuggers investigate in parallel and the main agent synthesizes one root-cause direction (competing hypotheses, deciding evidence, smallest next diagnostic). Otherwise use the Same-Host Parallel Fallback per the shared doc. |
| `explore` | Dispatch `explore` subagent to gather codebase facts, related call sites, working examples, and commands. |
| `executor` | Dispatch `executor` subagent to apply the minimal fix only after root cause and reproduction evidence exist. |
| `verifier` | Dispatch `verifier` subagent to confirm the fix and package evidence; its scenario lens covers post-fix validation when the failure affects user-facing flows, scenarios, or acceptance criteria. Cross-host merge: union/conservative. |
| `plan-reviewer` | Dispatch `plan-reviewer` subagent as a conditional escalation to reassess direction after three failed fix attempts, when architecture-level coupling is exposed, or before broad API/product/data/security/scope changes. Cross-host merge: one verdict. |
| `code-reviewer` | Dispatch `code-reviewer` post-fix when the changed code is nontrivial, shared, workflow-affecting, or maintainability-sensitive, or when its security lens is needed because auth, data, file system, network, secrets, sandbox, or policy-sensitive behavior is touched. Cross-host merge: merged findings. |

When the opposite host is available, run the `verifier`, `plan-reviewer`, and `code-reviewer` roles as cross-host review per `docs/shared/cross-host-review.md` using each role's `Cross-host merge` value above; otherwise use the Same-Host Parallel Fallback. The `debugger` investigation defaults to cross-host as stated in its row.

## Debugging Flow

1. Capture the exact failure command, input, environment, or user-visible symptom.
2. Reproduce the failure, or explain why it cannot be reproduced yet.
3. Read the relevant error output, logs, stack trace, and changed files.
4. Find the closest working example in the same codebase.
5. Build a hypothesis ledger before deep investigation:
   - For obvious, localized failures, record the single active hypothesis and
     why additional hypotheses would not change the next diagnostic step.
   - For unknown, nontrivial, flaky, repeated, or cross-boundary failures,
     record 2-3 plausible competing hypotheses before investigating any one
     deeply.
   - For each ledger entry, name the expected confirming evidence, expected
     refuting evidence, current confidence, and the smallest diagnostic step.
6. Select one active root-cause hypothesis from the ledger with evidence.
7. Test the active hypothesis with the smallest diagnostic step, update the
   ledger, and reject or replace the hypothesis when evidence contradicts it.
8. Trace the causal chain from the observed symptom back to the source that made
   the symptom possible. Do not accept a fix plan that only removes the visible
   trigger while leaving the failure mode latent. Before accepting a root cause,
   confirm it falsifiably with a causal toggle: toggling the suspected cause
   makes the failure appear and reverting it makes it disappear. When a clean
   toggle is not feasible (for example a race or environment-dependent failure),
   state why and name the next-strongest confirming evidence (such as a
   deterministic reproduction under the cause) instead of treating a plausible
   trace as proof.
9. For behavior fixes, read and follow `test-driven-development` to create a
   failing reproduction test before changing production code.
10. If reproduction and hypothesis evidence exist but the diagnosis remains
    contradictory, repeatedly inconclusive, or blocked after ordinary diagnostic
    passes, read and follow `fusion-rescue`. Return control to
    Systematic Debugging with the synthesis before applying a fix.
11. Apply the minimal fix with `executor` when the write scope is isolated; use
    inline work only with a recorded reason.
12. Dispatch warranted post-fix review roles when the changed scope or risk
    requires them.
13. Run the reproduction check, relevant regression checks, and
    `verification-before-completion` before claiming the failure is fixed. The
    verification evidence must show that the failure mode is gone, not only that
    the current trigger no longer appears in this environment.

Parallel hypothesis testing for steps 5-7: when reproduction is established and
two or more plausible root-cause hypotheses are independently testable, dispatch
one `debugger` subagent per hypothesis (cap 3) in a single batch. Step 6's
one-active-hypothesis rule applies per debugger agent: each parallel debugger
receives exactly one hypothesis, the confirming/refuting evidence it should look
for, and its read-only diagnostic scope. Each parallel debugger runs only
non-mutating diagnostics in disjoint scopes and returns evidence, confidence
movement, and rejected-hypothesis rationale; if diagnostics would mutate state
or scopes overlap, keep the sequential one-active-hypothesis flow above. The
main thread synthesizes the returned evidence, selects the confirmed root cause,
and a single `executor` applies the fix. Below two hypotheses, or when
hypotheses are not independently testable, the sequential flow above applies
unchanged.

## Stop Conditions

Stop and ask or escalate to `plan-reviewer` when:

- the failure cannot be reproduced and more data is needed from the user
- a `plan-reviewer` escalation trigger from `## Agent Roles` fires (repeated
  failed fix attempts; broad architecture or API scope; product behavior,
  data handling, security, or delivery-scope ambiguity)

## Anti-Patterns

- Changing code before reproducing or locating the failure.
- Fixing the stack-trace line when the bad value originated elsewhere.
- Bundling cleanup or refactors with a bug fix.
- Adding broad retries, catch-all handlers, or sleeps without evidence.
- Treating a later passing test as TDD evidence when no failing reproduction was
  observed first.
- Treating a passing trigger check as proof when the underlying failure mode or
  causal chain was not closed.
- Skipping competing hypotheses for an unknown or repeated failure because one
  log line looks familiar.

## Output

Return:

- Failure reproduced or reproduction blocker.
- Hypothesis ledger, including rejected hypotheses and evidence.
- Root cause and evidence.
- Causal chain and why the fix removes the failure mode.
- Causal toggle: the on/off observation, or "not feasible" with the reason and next-strongest confirming evidence.
- Reproduction test or documented exception.
- Fix summary.
- Verification commands and results.
- Residual risk.

## Next Skill Handoff

None — this is a failure-investigation mid-loop skill. It may use
`fusion-rescue` as a bounded internal escalation when ordinary diagnostics
stall, then return to this debugging flow. After verification, return the result
to the caller (`ralph`, `ultrawork`, or direct invocation). Do not chain to
another workflow skill.

## Source: docs/platforms/claude-code-runtime.md

# Claude Code Runtime Rules

This compact platform section is embedded in generated Claude Code-facing skill
documents.

## Skill Loading

Claude Code-facing public skills live under `skills-claude/`. Generated
`skills-claude/<skill>/SKILL.md` files compose the matching skill core, this
compact runtime section, and any Claude Code skill-specific overlay such as
`docs/platforms/claude-code-<skill>.md`. Slash commands must delegate to the
matching generated skill document.

## User Approval, Tasks, And Prompting

Use the host's structured question tool when available for approval,
preference, scope, or next-step selection; otherwise ask one focused plain-text
question and wait. Present options as actions the host agent will take.

When a core skill has a multi-phase approval handoff and the host exposes task
tracking, create one task per phase and complete them sequentially.

Keep Claude prompts explicit and sectioned: state scope, non-goals,
constraints, approval gates, expected evidence, and output format. Preserve
long-running context in artifacts before compaction, task handoff, or subagent
dispatch.

## Role Dispatch

Use the available Task, Agent, Workflow `agent()`, or subagent mechanism for
role dispatch. Prefer plugin-scoped agents named `oh-no-harness:<role>` when
the host lists them.

For independent read-only, review, verification, QA, security, or exploration
work, request background subagents and start the whole independent batch before
waiting for any one result. When a skill requires an atomic same-phase batch,
prefer Workflow `Promise.all` if available; otherwise do not inspect or
summarize early task results until the full intended batch has been requested.

After a Claude Code subagent reaches final status, capture the output and any
changed-file set before cleanup. When no further input is needed, close or
clean up the completed subagent with the mechanism exposed by the host; if none
is available, record that fallback.

For approved `ralplan` handoffs to ordinary `oh-no-harness:ralph`, treat
`Parallel trigger: approved-plan-handoff` as dispatch authorization for
eligible isolated roles. Do not require a separate `ralph with parallel
subagents` option when the plan already lists roles whose output can change the
implementation, review, verification, or ship/block decision.

If plugin-scoped agents are unavailable, keep the same role boundary by
embedding the matching `agents/<role>.md` prompt into the available subagent
mechanism. If no dispatch mechanism is available, keep the role inline and
record the fallback reason when the core skill requires it.

## Cross-Host Consult Channel

This is the shared cross-host consult mechanism used by Fusion Rescue and by
cross-host review (`docs/shared/cross-host-review.md`). On Claude Code the
opposite host is Codex. This section carries only the Claude-to-Codex
invocation; the activation, synthesis, and recursion-guard semantics live in the
calling skill core and the shared doc.

From Claude Code, consult Codex only through an available, explicitly loaded
`openai/codex-plugin-cc` capability, surfaced as `/codex:rescue` when that plugin
is installed. If the capability is unavailable, treat the opposite host as
unavailable; in default mode the calling skill applies the shared cross-host
contract's Same-Host Parallel Fallback (`docs/shared/cross-host-review.md`), and
require-cross-host mode blocks. Name the failure class and the current-host
fallback.

The consult must run synchronously and return Codex's actual assigned analysis.
Pass `--wait` to force foreground execution, for example `/codex:rescue --wait`,
and request read-only Codex behavior; do not let it run as a detached background
job and do not authorize write-capable edits for an analysis-only consult. A
response that only acknowledges a queued or background job — text that a task
started in the background with a status command for a job id — is not a valid
opposite-host response; treat it as no Codex response and degrade (default) or
block (require-cross-host). Do not poll status or fetch a deferred result to
compensate; the consult call itself must return the analysis.

The outbound prompt must request only the assigned analysis and must forbid the
opposite host from invoking further rescue, another workflow skill, or any
host-to-host call back to Claude Code or a third host (one cross-host hop).
Redact secrets before sending; on failure record only the failure class and
capability/path/auth status, never secret values.
