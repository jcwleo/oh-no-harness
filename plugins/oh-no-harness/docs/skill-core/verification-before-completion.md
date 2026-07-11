---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, passing, implemented, verified, ready for review, safe to deliver, or when summarizing final status after edits or tests.
argument-hint: "<claim, task, plan, or changed-file scope>"
---

# Verification Before Completion

Do not claim success without fresh evidence.

This skill is both a standalone lightweight final gate and the final evidence gate inside `ralph` and `ultrawork`. When those stronger workflows are active, use this skill to verify the final claim without weakening their PRD, review, cleanup, or QA requirements.

## Software Development Stage

Verification Before Completion is the final evidence stage.

Use it after implementation, debugging, cleanup, and relevant review are done, immediately before claiming the work is complete, fixed, passing, ready, or safe to deliver.

## When To Use

Use before saying that:

- a task is complete
- a bug is fixed
- tests, lint, build, install, or smoke checks pass
- a plugin, skill, hook, or agent is ready
- a branch or artifact is ready for user review

Do not use as a substitute for `ralph` when the work needs PRD tracking, cleanup, and review loops.

## Required Reading

Read a triggered owner immediately before the gate that needs it. A path
reference here is a pointer, not a substitute for reading. If a listed file
cannot be read, record the blocker instead of proceeding past the gate that
depends on it.

| Contract | Class | Trigger / timing |
|---|---|---|
| `docs/shared/verification-tiers.md` | triggered | before selecting the evidence tier or recording evidence/redaction |
| `docs/shared/validation-check.md` | triggered | before validation when measurable evidence influenced the claim |
| `docs/shared/ralph-subagent-policy.md` | triggered | before maker-verifier independence or role dispatch is applied |
| `docs/shared/cross-host-review.md` | triggered | before paired code review when a named THOROUGH risk selected it |
| `docs/shared/failure-taxonomy.md` | triggered | before classification when the likely risk is non-obvious |

## Agent Roles

| Agent | Use |
|---|---|
| `verifier` | Map the claim to evidence and run or inspect the required checks; apply the scenario lens to validate user-facing flows or scenario coverage. An unconditionally single self-host independent pass, never a cross-host or same-host pair. |
| `code-reviewer` | Review behavior-affecting code or workflow prompt changes when risk warrants it; apply the security lens to auth, data, file system, network, secrets, or policy-sensitive changes. Cross-host merge: merged findings. |

Use one dispatched `code-reviewer` for STANDARD when review is warranted. Apply
cross-host review or the Same-Host Parallel Fallback only after a named THOROUGH
paired-review trigger, per `docs/shared/cross-host-review.md`. The dispatched
`verifier` is out of cross-host scope — an unconditionally single self-host
independent pass (never a cross-host or same-host pair) — governed by the
maker-verifier carve-out.

On subagent-capable hosts, dispatch `verifier` for nontrivial completion claims
when independent evidence mapping can change the ship/block decision or expose
residual risk. Add a `code-reviewer` subagent (security lens included) when the
changed scope, selected verification tier, or user-facing risk warrants it;
`verifier` applies its scenario lens when user-facing behavior changed.
Inline verification is appropriate only for tiny direct checks with no
context-separation benefit or when dispatch is unavailable; record that fallback
or no-benefit reason before making the claim.

Confirming-verifier reuse: when this skill runs as the final gate inside
`ralph` or `ultrawork` and the caller already completed the required
independent confirming `verifier` pass for the same final claim, and no file,
dependency, or evidence changed after that pass (the Evidence Rules'
unchanged-evidence bar: a previous run is not fresh evidence unless nothing it
depends on changed), do not dispatch a second `verifier` for that claim. A
compliant pass ran as an independent dispatch (never the maker) after the
selected code-review stage completed, per the maker-verifier carve-out in
`docs/shared/ralph-subagent-policy.md`. Record the reused pass (as a reference to
the caller's ledger entry for it) and that it ran after reviewer completion under
the carve-out. This reuse satisfies only the verifier-dispatch expectation above: every
Required Gate step still executes in full (currently steps 1–9), and this
clause never licenses skipping this skill itself. Dispatch a fresh `verifier`
when evidence changed after the caller's pass or when no compliant pass
exists.

Ledger reuse: when `ralph` or `ultrawork` provides a canonical
`verification.md` acceptance-to-evidence ledger, audit that ledger in place.
Record only the delta since the last reviewer/verifier audit: changed files,
commands, dependencies, evidence rows, stale rows, and the final claim. Do not
rewrite an unchanged parallel acceptance mapping. A standalone invocation with
no caller ledger creates the compact mapping below.

Apply the active platform's dispatch authorization for the eligible `verifier`
and risk-gated `code-reviewer` roles in this skill. Do not ask for per-run
subagent approval when the active platform already supplies standing
authorization for those evidence or review roles, the claim is nontrivial, risk
warrants them, and the role output can change the completion decision.

When any verification role is dispatched, apply the active platform's role
prompt and dispatch requirements before the claim, evidence scope, expected
output, and no-edit instruction for read-only review roles.

## Required Gate

<HARD-GATE>
No completion claim may be made without fresh, acceptance-mapped evidence verified in the current work pass.

Before making a completion claim, complete every step below; the claim is invalid if any step is skipped or rests on stale evidence:

1. State the exact claim to verify.
2. Identify the command, artifact, diff inspection, or checklist that can prove it.
3. Run or inspect the evidence fresh in the current work pass.
4. Read the output and exit status.
5. Compare evidence to the canonical AC-ID ledger, mark changed or stale rows,
   and record the delta since the last independent audit.
6. Complete the Risk Check Before Completion below.
7. Report skipped checks and residual risk.
8. For a STANDARD or THOROUGH behavior-changing claim whose proving tests or implementation were authored or accepted by the current agent, confirm an independent `verifier` audit ran per the carve-out in `docs/shared/ralph-subagent-policy.md` — this self-gate does not substitute for it (record the dispatch-unavailable fallback if the host cannot dispatch).
9. When a `code-reviewer` was dispatched, record `single-reviewer` for
   STANDARD, or the named THOROUGH pair trigger plus `cross-host` /
   `same-host-parallel-fallback`; an inline fallback requires a reason.
   Missing review topology is a named ledger gap, not a pass.
</HARD-GATE>

If no meaningful command exists, inspect the changed files and write a manual verification checklist instead of implying automated confidence.

When measurable evidence influenced the work, also apply
`docs/shared/validation-check.md`. Treat that evidence as a diagnostic
signal, not as the acceptance criteria.

## Acceptance-To-Evidence Mapping

Do not treat a command list as proof by itself. Reuse the caller's canonical
ledger when present; otherwise map each acceptance criterion or requested
behavior once:

```text
Acceptance-to-evidence mapping:
- AC ID / criterion:
  - Evidence:
  - Coverage strength: direct | indirect | manual | missing
  - Freshness source:
  - Audit status: actual | audited | stale | blocked
  - Gap or residual risk:
```

Direct evidence is a focused test, scenario, or inspection that would fail if
the requested behavior were absent or wrong. Indirect evidence, broad suites,
lint, typecheck, formatting, and compile checks are useful support, but they do
not replace direct acceptance evidence for behavior-changing work.
In STANDARD or THOROUGH mode, for user-facing or behavior-changing work, direct
evidence must be an artifact observed from the real surface — actual command
output, terminal or UI capture, an HTTP response body, or an equivalent observed
result. "Should work", "looks correct", and a printed or `--dry-run` command are
indirect evidence at best. This bar does not apply to LIGHT or trivial work such
as a pure-logic helper edit, which needs no captured real-surface artifact.
New tests are supporting evidence, not sufficient completion proof, when nearby
existing tests, smoke checks, or behavior-preserving inspections are available
and could catch regressions.

## Risk Check Before Completion

Before final completion, actively look for the most likely way local green
evidence could still miss the real user, maintainer, or uncovered behavior.
Keep the questions category-level and requirements-driven instead of
case-specific.

Record:

```text
Risk check before completion:
- Acceptance criteria covered by direct evidence:
- Acceptance criteria only covered indirectly:
- Contract surface and semantic model checked:
- Baseline guard: existing test, smoke, inspection, or no viable baseline reason:
- Likely `docs/shared/failure-taxonomy.md` risk a skeptical maintainer would test:
- One more useful failing test I would write if time allowed:
- Completion claim:
```

The completion claim should distinguish:

- complete with direct evidence, baseline guard satisfied or unavailable with reason, and no blocking review findings
- locally verified with explicit residual risk
- blocked or failed verification because evidence or review blockers remain

## Validation Check

For evidence-informed work, record a `Validation check` using the canonical
template in `docs/shared/validation-check.md`. Include the evidence used, the
supported acceptance criterion or user outcome, proof and gap, recurring risk
addressed, similar-work expectation, excluded case-specific details, added
process cost, and completion claim.

Reject completion claims whose only support is metric movement, unseen-check
guessing, task-name-specific guidance, or a measurable metric that does not match the
real user, maintainer, operator, or public contract.

## Evidence Rules

- A previous run is not fresh evidence unless no file or dependency changed since that run.
- A passing lint check does not prove tests pass.
- A passing unit test does not prove a user-facing flow works when the acceptance criteria require the flow.
- A broad suite pass does not prove a new semantic contract unless the new
  behavior is directly represented in that suite.
- A local test that would pass against the wrong public, caller, or
  verifier-facing surface does not prove the real contract.
- A tautological test is not valid evidence: a test that only asserts a mock was
  called, pins a constant, or cannot fail under any plausible regression confirms
  itself, not the behavior.
- A new test does not replace a viable nearby baseline or smoke check for
  regression-sensitive work.
- For behavior-changing work, verify RED/GREEN/REFACTOR evidence or a documented TDD exception.
- When an agent reports success, inspect the changed files or artifacts before repeating the claim.
- A success status is not acceptance: an HTTP 2xx with an empty or error body,
  exit 0 with no state change, or a "done" log line without the observable
  effect is missing evidence, not a pass.
- Before recording a real-surface artifact, command output, or log as evidence —
  here or in any `.oh-no` file, PR body, or handoff — redact secrets and PII to a
  labeled placeholder, keeping only the non-sensitive shape needed (status line,
  lengths, hashes, short non-secret prefixes), per the evidence-redaction rule
  in `docs/shared/verification-tiers.md`.

## Output

Return:

- Claim verified.
- Evidence used.
- Commands or inspections performed.
- Acceptance criteria status.
- Acceptance-to-evidence mapping.
- Contract surface and baseline guard status.
- Risk check before completion and completion claim.
- Validation check and risk from metric-only evidence when applicable.
- Skipped checks and reason.
- Residual risk.

## Next Skill Handoff

None — this is the final evidence gate. Return the result to the caller (`ralph`, `ultrawork`, or direct invocation). Do not chain to another workflow skill.
