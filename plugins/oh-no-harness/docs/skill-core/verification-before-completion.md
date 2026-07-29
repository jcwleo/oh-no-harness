---
name: verification-before-completion
description: Use when an imminent complete, fixed, passing, ready, or safe claim—or final status after edits/tests—needs an evidence gate; not as an implementation substitute.
argument-hint: "<claim, task, plan, or changed-file scope>"
---

# Verification Before Completion

Do not claim success without fresh evidence. This skill is both a
standalone lightweight final gate and the final evidence gate inside
`ralph` and `ultrawork` — when those stronger workflows are active, verify
the final claim without weakening their PRD, review, cleanup, or QA
requirements. Do not use it as a substitute for `ralph` when the work needs
PRD tracking, cleanup, and review loops.

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
V4. An independent `verifier` audit is required only when a named trigger
    fires: an explicit user request; stale, missing, or conflicting evidence;
    a named security, data-loss, destructive, migration, recovery, or
    public-contract risk that actually needs independent evidence; or accepted
    blocking-review fix resolution. Mode, task non-triviality, the current
    agent having authored or accepted the proving tests or implementation,
    reviewer presence, and imminent completion are explicit NON-triggers. When a
    trigger fires, this self-gate never substitutes for that audit.
V9. Fresh revision-bound reviewer, verifier, and command evidence is reused as
    recorded. Completion imminence alone never justifies a rerun, an added
    test, or a fresh dispatch; only stale, missing, or conflicting evidence
    does.
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
4. Compare evidence to the canonical AC-ID ledger, mark changed or stale rows,
   and record the delta since the last independent audit [V6].
5. Complete the Risk Check Before Completion below.
6. Report skipped checks and residual risk.
7. Confirm whether any named V4 verifier trigger fired. If one did, confirm a separate-context independent `verifier` audit ran [V4]; if no separate context is available, record `dispatch-unavailable` as a blocker and return blocked/PAUSED to the caller, since inline command reruns cannot satisfy the audit. If none fired, record `Independent verifier: not-required (no trigger fired: <reason>)` and treat caller-owned fresh evidence as sufficient — do NOT dispatch a verifier merely because the claim is nontrivial, self-authored, or imminent [V9].
8. When a `code-reviewer` was dispatched, record `single-reviewer`, or
   `perspective-pair` plus its named firing trigger and the
   active platform's pair-mode value. One full-role reviewer is the default; a
   pair requires that named trigger, which also selects escalated
   platform diversity. An inline fallback requires a reason. Missing review
   topology is a named ledger gap, not a pass.
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

- For behavior-changing work, verify RED/GREEN/REFACTOR evidence or a
  documented TDD exception.
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

The completion claim classifies the result as: complete with direct evidence,
baseline guard satisfied or unavailable with reason, and no blocking review
findings; locally verified with explicit residual risk; or blocked / failed
verification because evidence or review blockers remain. Report every material
finding regardless of class: the blocking predicate determines the completion
result, not disclosure; non-blocking findings remain visible as residual risk.

## Validation Check

When measurable evidence influenced the work, record a validation check:
the evidence used, supported acceptance criterion or user outcome, proof
and gap, recurring risk addressed, similar-work expectation, excluded
case-specific details, added process cost, and completion claim. Treat
metric movement as a diagnostic signal, never the acceptance criteria:
reject completion claims whose only support is metric movement,
unseen-check guessing, fixture knowledge, task-name-specific guidance, or a
metric that does not match the real user, maintainer, operator, or public
contract. Also reject process inflation that would not help a skeptical
maintainer on similar work.

## Agent Roles

Dispatch `verifier` only when a named V4 trigger fires; nontriviality alone is
not one. Independent evidence mapping can change the ship/block decision or
expose residual risk, and when triggered its independence requires a
separate context [V4]. With no trigger, record the compliant not-required reason
and reuse the fresh caller-owned evidence [V9]. Add a `code-reviewer` (security
lens included) when the changed scope, verification tier, or user-facing risk
warrants it; one full-role instance is the default.
Apply the active platform's dispatch authorization; do not ask for per-run
subagent approval when standing authorization covers these roles. Every direct
role dispatch reuses the target role's required identity/result envelope and
adds only this workflow's claim and evidence delta. A standalone invocation
creates compact Packet, run/session, and task IDs plus the target revision/diff
fingerprint from its current claim and scope; adapters pass that packet
unchanged. Inline verification is appropriate only for tiny direct checks where
V4 does not require an independent audit. When V4 requires one and dispatch is
unavailable, record the blocker and return blocked/PAUSED; inline evidence may
supplement the record but cannot satisfy the audit.

| Agent | Use |
|---|---|
| `verifier` | map the claim to evidence and run or inspect the required checks; scenario lens for user-facing flows; dispatched only on a named V4 trigger, and then a single self-host independent pass, never part of a reviewer pair |
| `code-reviewer` | review behavior-affecting code or workflow prompt changes when risk warrants it; security lens for auth, data, file system, network, secrets, or policy-sensitive changes; ONE full-role instance by default, escalating to a perspective-diverse pair only on the named high-risk trigger that also selects escalated platform diversity (pair synthesis: merged findings) |

A dispatched `code-reviewer` is ONE instance running the complete role with both
ordered lenses. Only a named security, data, destructive, public-contract,
release-critical, new-concurrency, migration, or broad multi-system trigger
escalates to two same-role instances, each running the
full role: Lens A = adversarial correctness + security skeptic; Lens B =
maintainability + coverage completeness. Their packets are
identical except the single `Assigned perspective:` line; the instances are
dispatched in parallel and synthesized into one verdict. That same fired trigger
selects escalated platform diversity. The active platform supplies
the diversity
leg. If that leg is unavailable, default mode uses two independent same-model
instances and records the reason; an explicit caller demand for diversity is
strict mode and transitions to PAUSED instead of falling back. The `verifier`
remains outside this pair contract.

Confirming-verifier reuse: when this skill runs as the final gate inside
`ralph` or `ultrawork` and the caller already completed a triggered
independent confirming `verifier` pass for the same final claim, do not
dispatch a second `verifier` when the pass ran as an independent dispatch
(never the maker) after the selected code-review stage and no file,
dependency, or evidence changed after that pass [V1, V5]. On the no-fix
path, the review and verifier evidence bind to the reviewed revision. On the
fix path, reuse requires review evidence bound to the reviewed revision plus
verifier evidence bound to the fixed revision, with the verifier dispatched
after the fix manifest was recorded. Record the reused pass as a reference
to the caller's ledger entry and its revision binding under the carve-out.
This reuse satisfies only the verifier-dispatch expectation: every Required
Gate step still executes in full, and this clause never licenses skipping
this skill itself. Dispatch a fresh `verifier` only when evidence changed after
the caller's pass, or when a named V4 trigger fires and no compliant pass
exists; a compliant `not-required (no trigger fired)` record needs no dispatch.

Confirming code-reviewer reuse: when this skill runs as the final gate inside
`ralph` or `ultrawork` and the caller already completed the single required
`code-reviewer` round for the same final claim — `single-reviewer` or a
triggered perspective-diverse pair — do not
dispatch a second `code-reviewer`. On the no-fix path, reuse requires review
evidence bound to the reviewed revision with no file, dependency, or evidence
change since that review. On the fix path, reuse requires that review binding
plus verifier evidence bound to the fixed revision, with no file, dependency,
or evidence change after the verifier pass. Record the reused review as a
reference to the caller's ledger entry and its revision binding. Dispatch a
fresh `code-reviewer` only when this skill runs standalone (not nested) or no
compliant code-review exists for the claim.

## Output

Return: claim verified; evidence used; commands or inspections performed;
acceptance criteria status; acceptance-to-evidence mapping; contract
surface and baseline guard status; risk check and completion claim;
validation check when applicable; skipped checks and reason; residual risk.

## Next Skill Handoff

None — this is the final evidence gate [V8]. Return the result to the
caller (`ralph`, `ultrawork`, or direct invocation). Do not chain to
another workflow skill.
