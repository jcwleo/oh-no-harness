---
name: systematic-debugging
description: Use when an observed failure, regression, flake, unexpected output, or unknown root cause needs investigation; a known-cause execution-ready fix remains Ralph.
argument-hint: "<failure, command, bug report, or unexpected behavior>"
---

# Systematic Debugging

Find the root cause before changing behavior. This is the direct debugging
entry point for failures that do not need the full `ralph` execution loop;
do not use it for greenfield feature work — use `ralplan` or `ralph` when
the task is broader than a bounded failure.

## Invariants

```text
D1. Reproduce (or explain why reproduction is blocked) before changing any
    code; never fix from a stack-trace line when the bad value originated
    elsewhere.
D2. A hypothesis ledger precedes diagnostic dispatch and deep investigation:
    one recorded hypothesis for an obvious localized failure; 2-3 competing
    hypotheses for unknown, nontrivial, flaky, repeated, or cross-boundary
    failures.
D3. A root cause is confirmed falsifiably by a causal toggle — toggling the
    suspected cause makes the failure appear and reverting makes it
    disappear; when a clean toggle is not feasible, state why and name the
    next-strongest confirming evidence.
D4. The minimal fix is applied only after root cause and reproduction
    evidence exist; behavior fixes create a failing reproduction test
    first (read and follow `test-driven-development`).
D5. Respect the active caller's stricter failed-fix budget and escalation
    route; without one, stop and route back to the user or `ralplan` after
    three failed fix attempts. Also route back on architecture-level coupling
    or a fix that would change broad APIs, product behavior, data handling,
    security, or delivery scope; do not directly dispatch
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
5. After building the ledger, when two or more active hypotheses are
   independently testable, dispatch exactly one `debugger` per hypothesis
   under `Parallel hypothesis testing`. Otherwise select one active hypothesis
   and test it sequentially with the smallest diagnostic step. Update the
   ledger and reject or replace hypotheses when evidence contradicts them.
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
10. Dispatch warranted post-fix review roles per `## Agent Roles` only when
    permitted by any caller-owned review budget.
11. Run the reproduction check, relevant regression checks, and
    `verification-before-completion` before claiming the failure is fixed
    [D8].

Parallel hypothesis testing (steps 4-5):
After building the ledger, when two or more active hypotheses are independently testable,
dispatch exactly one `debugger` per hypothesis in one batch — at most 3 by
default, extending toward 5 only when 3+ genuinely independent hypotheses are
testable. Dispatch the complete eligible batch before waiting for any result.
Each initial fan-out packet names exactly one assigned hypothesis and its confirming/refuting evidence targets.
Every other hypothesis and the rest of the hypothesis ledger are withheld.
Each debugger's initial packet is symptom-first with the raw reproduction,
expected and actual behavior, environment, and a read-only diagnostic scope,
without a preferred cause or fix, expected verdict, confidence ranking, or
sibling conclusions. A debugger must not receive multiple eligible hypotheses
or investigate the full ledger. A later clarification may disclose prior
actions only as neutral exact action, state, and raw outcome. Each debugger
runs only non-mutating diagnostics in a disjoint scope and returns evidence,
confidence movement, and rejected-hypothesis rationale. Keep investigation sequential for
one hypothesis, dependent hypotheses, overlapping scopes, or state-mutating
diagnostics. The main thread synthesizes the evidence, selects the confirmed
root cause, and a single `executor` applies the fix.

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

- Bundling cleanup or refactors with a bug fix.
- Adding broad retries, catch-all handlers, or sleeps without evidence.
- Treating a later passing test as TDD evidence when no failing
  reproduction was observed first.

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
required identity/result envelope and adds only the debugging workflow delta.
An initial debugger packet contains the raw reproduction, expected behavior,
actual behavior, environment, and diagnostic scope. In eligible fan-out it also
names exactly one assigned hypothesis and its confirming/refuting evidence
targets. Every other hypothesis and the rest of the hypothesis ledger are
withheld. The packet withholds the caller's
preferred cause or fix and all sibling conclusions, plus the expected verdict
and confidence ranking. Later disclosures of prior actions use only neutral
exact action, state, and raw outcome. Executor fix packets may include the
independently confirmed root cause. Debugger output itself is not redesigned
here.

| Agent | Dispatch (when) |
|---|---|
| `debugger` | exactly one instance per independently testable active hypothesis in one complete batch; one sequential instance when fan-out is ineligible; a paired investigation only for one named THOROUGH uncertainty when fan-out is not active |
| `explore` | gather codebase facts, related call sites, working examples, and commands |
| `executor` | default owner of the minimal fix after root cause and reproduction evidence exist; preserve its TDD identity across RED/GREEN/REFACTOR [D4, D7] |
| `verifier` | confirm the fix and package evidence; scenario lens for user-facing flows; an unconditionally single self-host independent pass, never part of a reviewer or debugger pair — required when the proving tests or fix were authored or accepted by the same agent |
| `code-reviewer` | post-fix when the changed code is nontrivial, shared, workflow-affecting, or maintainability-sensitive, or its security lens is needed because auth, data, file system, network, secrets, sandbox, or policy-sensitive behavior is touched; when dispatched, runs as the perspective-diverse pair with merged-finding synthesis |

STANDARD uses one dispatched `debugger` per eligible hypothesis in the complete
fan-out batch, or one sequential instance when fan-out is ineligible. Only when
hypothesis fan-out is not active may a named THOROUGH trigger use two same-role
instances with identical packets for one named uncertainty, dispatched in
parallel and synthesized into one result; never multiply that pair across
hypotheses. A post-fix `code-reviewer`, when dispatched, always runs as the
perspective-diverse pair: two same-role instances, each running the full role,
with Lens A = adversarial correctness + security skeptic and Lens B =
maintainability + coverage completeness. Their packets are
identical except the single `Assigned perspective:` line; the instances are
dispatched in parallel and synthesized into one verdict. A named THOROUGH
code-review trigger selects only escalated platform diversity. The active
platform supplies the diversity leg. If that leg is unavailable, default mode
uses two independent same-model instances and records the reason; an explicit
caller demand for diversity is strict mode and transitions to PAUSED instead of
falling back.

## Output Gate

<HARD-GATE>
Report every result, but do not classify it as passing until every dispatched review records topology:
an eligible debugger batch records `hypothesis-fanout:<count>`, a sequential
STANDARD debugger records `single-reviewer`, and a named THOROUGH debugger pair
records the active platform's pair-mode value. A dispatched post-fix
code-reviewer records `perspective-pair` with the active platform's pair-mode
value. An inline fallback requires a reason. Missing review topology is a named
ledger gap, not a pass. On the direct-invocation path this gate owns
the completion chokepoint; when invoked mid-loop from `ralph`/`ultrawork`, the
caller's completion gate is the backstop.
</HARD-GATE>

## Output

Return: failure reproduced or reproduction blocker; hypothesis ledger with
rejected hypotheses and evidence; root cause and evidence; causal chain and
why the fix removes the failure mode; causal toggle (the on/off
observation, or "not feasible" with the reason and next-strongest
confirming evidence); reproduction test or documented exception; fix
summary; verification commands and results; residual risk.

## Next Skill Handoff

None — after any bounded `fusion-rescue` escalation, return the result to the
caller; do not chain to another workflow skill [D9].
