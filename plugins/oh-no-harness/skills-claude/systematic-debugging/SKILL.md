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
- `../../docs/platforms/claude-code-systematic-debugging.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/systematic-debugging.md

# Systematic Debugging

Find the root cause before changing behavior. This is the direct debugging
entry point for failures that do not need the full `ralph` execution loop;
do not use it for greenfield feature work — use `ralplan` or `ralph` when
the task is broader than a bounded failure.

Interpret `MUST`, `MUST NOT`, `ONLY`, and `STOP` literally.

## Invariants

```text
D1. Reproduce (or explain why reproduction is blocked) before changing any
    code; never fix from a stack-trace line when the bad value originated
    elsewhere.
D2. A hypothesis ledger precedes deep investigation: one recorded
    hypothesis for an obvious localized failure; 2-3 competing hypotheses
    for unknown, nontrivial, flaky, repeated, or cross-boundary failures.
D3. A root cause is confirmed falsifiably by a causal toggle — toggling the
    suspected cause makes the failure appear and reverting makes it
    disappear; when a clean toggle is not feasible, state why and name the
    next-strongest confirming evidence.
D4. The minimal fix is applied only after root cause and reproduction
    evidence exist; behavior fixes create a failing reproduction test
    first (read and follow `test-driven-development`).
D5. Stop and route back to the user or `ralplan` after three failed fix
    attempts, on architecture-level coupling, or when the apparent fix
    would change broad APIs, product behavior, data handling, security, or
    delivery scope; do not directly dispatch
    `plan-reviewer` — planning review is Ralplan-owned.
D6. `fusion-rescue` is a bounded internal escalation when diagnostics
    stall; it returns control here before any fix is applied.
D7. The main agent orchestrates and owns `.oh-no` state. Diagnostic and
    evidence roles dispatch by default, and confirmed repository work-product
    fixes dispatch `executor`; inline mutation is only a recorded LIGHT-tiny
    or dispatch-unavailable fallback.
D8. The verification evidence must show the failure mode is gone, not only
    that the current trigger no longer appears in this environment.
D9. Mid-loop skill: after verification, return the result to the caller
    (`ralph`, `ultrawork`, or direct invocation); never chain to another
    workflow skill.
```

## Debugging Flow

1. Capture the exact failure command, input, environment, or user-visible
   symptom.
2. Reproduce the failure, or explain why it cannot be reproduced yet [D1].
3. Read the relevant error output, logs, stack trace, and changed files;
   find the closest working example in the same codebase.
4. Build the hypothesis ledger [D2]: for each entry name the expected
   confirming evidence, expected refuting evidence, current confidence, and
   the smallest diagnostic step.
5. Select one active hypothesis; test it with the smallest diagnostic
   step; update the ledger and reject or replace the hypothesis when
   evidence contradicts it.
6. Trace the causal chain from the observed symptom back to the source that
   made the symptom possible — do not accept a fix plan that only removes
   the visible trigger while leaving the failure mode latent. Confirm the
   root cause with a causal toggle [D3].
7. For behavior fixes, create the failing reproduction test before changing
   production code [D4].
8. If reproduction and hypothesis evidence exist but the diagnosis remains
   contradictory, repeatedly inconclusive, or blocked, read and follow
   `fusion-rescue`, then return here with the synthesis [D6].
9. Apply the minimal fix through `executor` by default once root cause and
   reproduction evidence exist. Keep the same executor identity across the
   reproduction RED, GREEN, and REFACTOR writes when TDD applies. Inline
   mutation is allowed only with `Mutation fallback: LIGHT-tiny` or after a
   failed dispatch attempt recorded as `Mutation fallback:
   dispatch-unavailable` [D4, D7].
10. Dispatch warranted post-fix review roles per `## Agent Roles`.
11. Run the reproduction check, relevant regression checks, and
    `verification-before-completion` before claiming the failure is fixed
    [D8].

Parallel hypothesis testing (steps 4-5): when reproduction is established
and two or more plausible hypotheses are independently testable, dispatch
one `debugger` per hypothesis in a single batch — at most 3 by default, extending toward 5 only when 3+ genuinely independent hypotheses are testable. Each parallel
debugger receives exactly one hypothesis, its confirming/refuting evidence
targets, and a read-only diagnostic scope; each runs only non-mutating
diagnostics in disjoint scopes and returns evidence, confidence movement,
and rejected-hypothesis rationale. If diagnostics would mutate state or
scopes overlap, keep the sequential flow. The main thread synthesizes the
evidence, selects the confirmed root cause, and a single `executor` applies
the fix.

## Stop Conditions

Stop and ask or route back to the user or `ralplan` when [D5]:

- the failure cannot be reproduced and more data is needed from the user
- repeated failed fixes, broad architecture or API scope, or product/data/
  security/delivery-scope ambiguity shows the approved plan or Direction
  Contract needs planning review
- the smallest confirmed fix would introduce a new architecture, scheduler,
  state machine, protocol, or public contract not present in the approved
  Direction Contract — return evidence instead of silently redesigning

## Anti-Patterns

- Changing code before reproducing or locating the failure.
- Fixing the stack-trace line when the bad value originated elsewhere.
- Bundling cleanup or refactors with a bug fix.
- Adding broad retries, catch-all handlers, or sleeps without evidence.
- Treating a later passing test as TDD evidence when no failing
  reproduction was observed first.
- Treating a passing trigger check as proof when the causal chain was not
  closed.
- Skipping competing hypotheses for an unknown or repeated failure because
  one log line looks familiar.

## Agent Roles

Dispatch diagnostic and evidence roles by default on subagent-capable hosts
[D7] — context separation keeps logs, traces, and exploratory output out of
the main thread. Dispatch is trigger-loaded and governed by the active
platform adapter; when this debugging pass runs inside Ralph, Ralph's
`## Mode-Gated Agent Dispatch` governs. Apply the active platform's
dispatch authorization; do not ask for per-run subagent approval when
standing authorization covers these roles. For diagnostic or evidence roles,
inline fallback may be unavailable, unsafe-to-isolate, or too-small-to-benefit
when recorded. Repository mutation follows the stricter executor-default rule
in D7: only LIGHT-tiny or dispatch-unavailable permits inline writes. Do not
collapse diagnostic or evidence roles inline when the host can dispatch them
with an isolated scope.

The normal flow is diagnostic first (`debugger`, plus `explore` when
context is missing), then the executor-default minimal fix (`executor`), then
evidence (`verifier`). Every direct role dispatch reuses the target role's
required identity/result envelope and adds only the debugging workflow delta:
the failure/reproduction command, confirmed root cause or active hypothesis,
and diagnostic or fix scope. Debugger output itself is not redesigned here.

| Agent | Dispatch (when) |
|---|---|
| `debugger` | one instance to reproduce, identify root cause, and recommend the minimal fix; a paired cross-host or same-host investigation ONLY for a named THOROUGH uncertainty or repeated-failure trigger |
| `explore` | gather codebase facts, related call sites, working examples, and commands |
| `executor` | default owner of the minimal fix after root cause and reproduction evidence exist; preserve its TDD identity across RED/GREEN/REFACTOR [D4, D7] |
| `verifier` | confirm the fix and package evidence; scenario lens for user-facing flows; an unconditionally single self-host independent pass, never a cross-host or same-host pair — required when the proving tests or fix were authored or accepted by the same agent |
| `code-reviewer` | post-fix when the changed code is nontrivial, shared, workflow-affecting, or maintainability-sensitive, or its security lens is needed because auth, data, file system, network, secrets, sandbox, or policy-sensitive behavior is touched; cross-host merge: merged findings |

STANDARD uses one dispatched reviewer or debugger instance; a pair requires
a named THOROUGH trigger, with same-host parallel fallback recorded when the
opposite host is unavailable.

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

Return: failure reproduced or reproduction blocker; hypothesis ledger with
rejected hypotheses and evidence; root cause and evidence; causal chain and
why the fix removes the failure mode; causal toggle (the on/off
observation, or "not feasible" with the reason and next-strongest
confirming evidence); reproduction test or documented exception; fix
summary; verification commands and results; residual risk.

## Next Skill Handoff

None — this is a failure-investigation mid-loop skill [D9]. It may use
`fusion-rescue` as a bounded internal escalation, then return to this flow.
After verification, return the result to the caller. Do not chain to
another workflow skill.

## Source: docs/platforms/claude-code-systematic-debugging.md

# Systematic Debugging Claude Code Adapter

<ADAPTER_CONTRACT>
This adapter binds the Systematic Debugging core to Claude Code. The core
owns every semantic decision; this file owns only host invocation and
lifecycle mechanics. If they conflict, the core wins. The generated core
plus this adapter is sufficient: longer platform, shared, and agent
documents are optional maintenance context, never a runtime prerequisite.
</ADAPTER_CONTRACT>

## Role Dispatch

Dispatch roles through the exposed Task, Agent, Workflow `agent()`, or
subagent primitive with the plugin agents from `agents/`
(`oh-no-harness:<agent>`; manual mention `@agent-oh-no-harness:<agent>`).
Dispatch is trigger-loaded — dispatch only after the core's trigger fires.
Pass the core-defined role envelope and debugging delta unchanged. Parallel
hypothesis debuggers are one batch — request all before waiting. A notification,
timeout, or empty wait result is not a final status; capture each result,
then close or clean up the completed subagent when the host exposes that
mechanism. If a plugin-scoped agent is unavailable, embed the matching
`agents/<agent>.md` prompt into the available subagent mechanism; with no
subagent primitive, keep the role boundary inline and record the fallback.

## Cross-Host Consult Channel

A named-THOROUGH paired `debugger` or post-fix `code-reviewer` dispatches
the current-host role and its `-codex` transport with identical packets;
the consult is read-only, foreground, one hop, returning the actual
opposite-host result. On opposite-host unavailability run the same-host
parallel fallback and record it.
