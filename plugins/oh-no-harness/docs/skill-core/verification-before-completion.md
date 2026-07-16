---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, passing, implemented, verified, ready for review, safe to deliver, or when summarizing final status after edits or tests.
argument-hint: "<claim, task, plan, or changed-file scope>"
---

# Verification Before Completion

Do not claim success without fresh evidence. This skill is both a
standalone lightweight final gate and the final evidence gate inside
`ralph` and `ultrawork` — when those stronger workflows are active, verify
the final claim without weakening their PRD, review, cleanup, or QA
requirements. Do not use it as a substitute for `ralph` when the work needs
PRD tracking, cleanup, and review loops.

Interpret `MUST`, `MUST NOT`, `ONLY`, and `STOP` literally.

## Invariants

```text
V1. No completion claim without fresh, acceptance-mapped evidence verified
    in the current work pass; a previous run is not fresh evidence unless
    nothing it depends on changed.
V2. A success status is not acceptance: HTTP 2xx with an empty or error
    body, exit 0 with no state change, or a "done" log line without the
    observable effect is missing evidence, not a pass.
V3. A command list is not proof: every acceptance criterion maps to
    evidence with coverage strength, freshness, and audit status.
V4. For STANDARD/THOROUGH behavior-changing claims whose proving tests or
    implementation were authored or accepted by the current agent, an
    independent `verifier` audit is required — this self-gate never
    substitutes for it.
V5. A merge or integration step is evidence-changing unless the caller
    proves the final files and dependencies are identical to the
    verifier-audited state.
V6. Reuse the caller's canonical ledger in place, recording only the delta;
    never rewrite an unchanged parallel acceptance mapping.
V7. Secrets and PII are redacted to labeled placeholders before any
    real-surface artifact, command output, or log is recorded as evidence.
V8. Final evidence gate: return the result to the caller; never chain to
    another workflow skill.
```

## Required Gate

<HARD-GATE>
No completion claim may be made without fresh, acceptance-mapped evidence verified in the current work pass [V1].

Before making a completion claim, complete every step below; the claim is invalid if any step is skipped or rests on stale evidence:

1. State the exact claim to verify.
2. Identify the command, artifact, diff inspection, or checklist that can prove it.
3. Run or inspect the evidence fresh in the current work pass.
4. Read the output and exit status [V2].
5. Compare evidence to the canonical AC-ID ledger, mark changed or stale rows,
   and record the delta since the last independent audit [V6].
6. Complete the Risk Check Before Completion below.
7. Report skipped checks and residual risk.
8. For a STANDARD or THOROUGH behavior-changing claim whose proving tests or implementation were authored or accepted by the current agent, confirm an independent `verifier` audit ran per the carve-out [V4] (record the dispatch-unavailable fallback if the host cannot dispatch).
9. When a `code-reviewer` was dispatched, record `single-reviewer` for
   STANDARD, or the named THOROUGH pair trigger plus `cross-host` /
   `same-host-parallel-fallback`; an inline fallback requires a reason.
   Missing review topology is a named ledger gap, not a pass.
</HARD-GATE>

If no meaningful command exists, inspect the changed files and write a
manual verification checklist instead of implying automated confidence.

## Acceptance-To-Evidence Mapping

Reuse the caller's canonical ledger when present [V6]; a standalone
invocation creates this compact mapping once [V3]:

```text
Acceptance-to-evidence mapping:
- AC ID / criterion:
  - Evidence:
  - Coverage strength: direct | indirect | manual | missing
  - Freshness source:
  - Audit status: actual | audited | stale | blocked
  - Gap or residual risk:
```

Direct evidence is a focused test, scenario, or inspection that would fail
if the requested behavior were absent or wrong. Indirect evidence — broad
suites, lint, typecheck, formatting, compile — supports but never replaces
direct acceptance evidence for behavior-changing work. In STANDARD or
THOROUGH mode, for user-facing or behavior-changing work, direct evidence
must be an artifact observed from the real surface (actual command output,
terminal or UI capture, an HTTP response body); "should work", "looks
correct", and a printed or `--dry-run` command are indirect at best. This
bar does not apply to LIGHT or trivial work. New tests are supporting
evidence, not sufficient completion proof, when a viable nearby baseline or
smoke check could catch regressions.

## Evidence Rules

- A previous run is not fresh evidence unless no file or dependency changed
  since that run [V1].
- A passing lint check does not prove tests pass; a passing unit test does
  not prove a user-facing flow; a broad-suite pass does not prove a new
  semantic contract unless the new behavior is directly represented in it.
- A local test that would pass against the wrong public, caller, or
  verifier-facing surface does not prove the real contract.
- A tautological test is not valid evidence: a test that only asserts a
  mock was called, pins a constant, or cannot fail under any plausible
  regression confirms itself, not the behavior.
- For behavior-changing work, verify RED/GREEN/REFACTOR evidence or a
  documented TDD exception.
- When an agent reports success, inspect the changed files or artifacts
  before repeating the claim [V2].
- Redact secrets and PII before recording any evidence, keeping only the
  non-sensitive shape (status line, lengths, hashes, short non-secret
  prefixes) [V7].

## Risk Check Before Completion

Before the final claim, actively look for the most likely way local green
evidence could still miss the real user, maintainer, or uncovered behavior.
Keep the questions category-level and requirements-driven, not
case-specific.

```text
Risk check before completion:
- Acceptance criteria covered by direct evidence:
- Acceptance criteria only covered indirectly:
- Contract surface and semantic model checked:
- Baseline guard: existing test, smoke, inspection, or no viable baseline reason:
- Likely category risk a skeptical maintainer would test (for example
  contract-surface mismatch, semantic-lifecycle/state miss, hidden regression):
- One more useful failing test I would write if time allowed:
- Completion claim:
```

The "one more useful failing test" field is non-blocking residual-risk
documentation. Do not implement it or use it to block completion unless it maps
to an unmet AC ID or an approved named risk; otherwise record it as `not
relevant` with the reason.

The completion claim distinguishes: complete with direct evidence, baseline
guard satisfied or unavailable with reason, and no blocking review
findings; locally verified with explicit residual risk; or blocked / failed
verification because evidence or review blockers remain.

## Validation Check

When measurable evidence influenced the work, record a validation check:
the evidence used, supported acceptance criterion or user outcome, proof
and gap, recurring risk addressed, similar-work expectation, excluded
case-specific details, added process cost, and completion claim. Treat
metric movement as a diagnostic signal, never the acceptance criteria:
reject completion claims whose only support is metric movement,
unseen-check guessing, task-name-specific guidance, or a metric that does
not match the real user, maintainer, operator, or public contract.

## Agent Roles

Dispatch `verifier` by default for nontrivial completion claims on
subagent-capable hosts — independent evidence mapping can change the
ship/block decision or expose residual risk, and independence requires a
separate context [V4]. Add a `code-reviewer` (security lens included) when
the changed scope, verification tier, or user-facing risk warrants it.
Apply the active platform's dispatch authorization; do not ask for per-run
subagent approval when standing authorization covers these roles. Inline
verification is appropriate only for tiny direct checks with no
context-separation benefit or when dispatch is unavailable — record that
fallback or no-benefit reason before making the claim.

| Agent | Use |
|---|---|
| `verifier` | map the claim to evidence and run or inspect the required checks; scenario lens for user-facing flows; an unconditionally single self-host independent pass, never a cross-host or same-host pair |
| `code-reviewer` | review behavior-affecting code or workflow prompt changes when risk warrants it; security lens for auth, data, file system, network, secrets, or policy-sensitive changes; one instance for STANDARD, a pair only for a named THOROUGH trigger (cross-host merge: merged findings) |

Confirming-verifier reuse: when this skill runs as the final gate inside
`ralph` or `ultrawork` and the caller already completed the required
independent confirming `verifier` pass for the same final claim — a
compliant pass ran as an independent dispatch (never the maker) after the
selected code-review stage — and no file, dependency, or evidence changed
after that pass [V1, V5], do not dispatch a second `verifier` for that
claim. Record the reused pass as a reference to the caller's ledger entry
and that it ran after reviewer completion under the carve-out. This reuse
satisfies only the verifier-dispatch expectation: every Required Gate step
still executes in full, and this clause never licenses skipping this skill
itself. Dispatch a fresh `verifier` when evidence changed after the
caller's pass or when no compliant pass exists.

## Output

Return: claim verified; evidence used; commands or inspections performed;
acceptance criteria status; acceptance-to-evidence mapping; contract
surface and baseline guard status; risk check and completion claim;
validation check when applicable; skipped checks and reason; residual risk.

## Next Skill Handoff

None — this is the final evidence gate [V8]. Return the result to the
caller (`ralph`, `ultrawork`, or direct invocation). Do not chain to
another workflow skill.

Maintenance references (rationale only, never a runtime prerequisite):
`docs/shared/verification-tiers.md`, `docs/shared/validation-check.md`,
`docs/shared/ralph-subagent-policy.md`, `docs/shared/cross-host-review.md`,
`docs/shared/failure-taxonomy.md`.
