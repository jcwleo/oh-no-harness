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

## Required Reading

Read a triggered owner immediately before the dependent gate. A path reference
here is a pointer, not a substitute for reading. If a listed file cannot be
read, record the blocker instead of proceeding past the gate that depends on it.

| Contract | Class | Trigger / timing |
|---|---|---|
| `docs/shared/ralph-subagent-policy.md` | triggered | before dispatching a diagnostic, executor, reviewer, or verifier role |
| `docs/shared/cross-host-review.md` | triggered | before paired debugger or post-fix review when a named THOROUGH risk selects it |

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
for role isolation, fallback reasons, and eligible batch dispatch.

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
| `debugger` | Dispatch one `debugger` to reproduce the failure, identify root cause, and recommend the minimal fix. Use a paired cross-host/Same-Host investigation only for a named THOROUGH uncertainty or repeated-failure trigger. |
| `explore` | Dispatch `explore` subagent to gather codebase facts, related call sites, working examples, and commands. |
| `executor` | Dispatch `executor` subagent to apply the minimal fix only after root cause and reproduction evidence exist. |
| `verifier` | Dispatch `verifier` subagent to confirm the fix and package evidence; its scenario lens covers post-fix validation when the failure affects user-facing flows, scenarios, or acceptance criteria. An unconditionally single self-host independent pass, never a cross-host or same-host pair. |
| `plan-reviewer` | Dispatch `plan-reviewer` subagent as a conditional escalation to reassess direction after three failed fix attempts, when architecture-level coupling is exposed, or before broad API/product/data/security/scope changes. Cross-host merge: one verdict. |
| `code-reviewer` | Dispatch `code-reviewer` post-fix when the changed code is nontrivial, shared, workflow-affecting, or maintainability-sensitive, or when its security lens is needed because auth, data, file system, network, secrets, sandbox, or policy-sensitive behavior is touched. Cross-host merge: merged findings. |

STANDARD uses one dispatched reviewer or debugger instance. Apply
`docs/shared/cross-host-review.md` only when a named THOROUGH trigger selects a
pair. The post-fix `verifier` remains one independent self-host pass governed by
the maker-verifier carve-out.

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
- the smallest confirmed fix would introduce a new architecture, scheduler,
  state machine, protocol, or public contract not present in the approved
  Direction Contract; return evidence instead of silently redesigning

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

## Output Gate

<HARD-GATE>
Do not emit the Output below until every dispatched review records topology:
`single-reviewer` for STANDARD, or a named THOROUGH pair with `cross-host` /
`same-host-parallel-fallback`; an inline fallback requires a reason.
Missing review topology is a named ledger gap, not a pass. On the direct-invocation path
this gate owns the completion chokepoint; when invoked mid-loop from
`ralph`/`ultrawork`, the caller's completion gate is the backstop.
</HARD-GATE>

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

Dispatch only after the active skill's trigger fires, then read
`docs/platforms/claude-code.md` `## Role Dispatch` for the full host contract.
Prefer `oh-no-harness:<role>`, request the whole independent batch before
waiting, capture every final result, and clean up only after integration. An
approved-plan handoff is dispatch authorization for eligible isolated roles;
plugin-agent unavailability uses the documented embedded-role fallback.

## Cross-Host Consult Channel

This channel is trigger-loaded, not embedded in every workflow decision. When a
named THOROUGH paired-review or Fusion Rescue trigger fires, read and apply
`docs/platforms/claude-code.md` `## Cross-Host Consult Channel` before dispatch.
Until then, do not preload opposite-host invocation details.
