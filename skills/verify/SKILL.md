---
name: verify
description: "Check completion claims against fresh evidence, tests, builds, lint, static checks, and spec acceptance IDs before final reporting."
---

# verify

Verify compares claims with evidence. It is the final gate before saying work is complete.

## Role passes

- `verifier`: default owner for claim-to-evidence mapping and `VERIFIED` / `PARTIAL` / `MISSING` status.
- `test-engineer`: use when test coverage, regression proof, or alternate verification is uncertain.
- `code-reviewer`: use when changed code needs quality, security, maintainability, or regression-risk review.
- `architect`: use when the completion claim depends on architecture, boundaries, public API, migrations, or broad refactors.

If native subagents are unavailable, perform these as current-session read-only role passes.

## Process

1. List the claims being made.
2. Map each claim to `AC-*`, `INV-*`, task IDs, or explicit user requirements.
3. Choose the smallest fresh command or inspection that can prove each claim.
4. Run the checks and read the output.
5. Check that fixes address the root cause rather than only masking symptoms.
6. Check that temporary diagnostic logs, tracing, assertions, or mitigations were removed or intentionally gated and documented.
7. Record `VERIFIED`, `PARTIAL`, or `MISSING` for each required claim.
8. If any required claim is `PARTIAL` or `MISSING`, do not report completion; return to `ralph` or `debug`.

## Verify report

For context-window-sized work, write:

```text
docs/oh-no/reports/YYYY-MM-DD-<slug>-verify.md
```

Use `templates/verify.md` as the preferred structure. Each entry should use a stable ID:

- `VR-001`: claim, linked `AC-*` or `INV-*`, evidence command/file, status, notes.

## Resume and context-window protocol

Before final verification on long work, read the spec, plan, and latest progress artifact. Rebuild the claim list from artifacts rather than memory. If artifacts disagree, mark the claim `PARTIAL` until the discrepancy is resolved.

## Evidence hierarchy

Prefer, in order:

1. Targeted tests for changed behavior.
2. Typecheck, lint, build, or static analysis.
3. Reproduction or smoke checks.
4. File inspection when no executable check exists.
5. Explicitly documented verification gap.

## Final response shape

Report:

- Changed files or inspected files
- Verification commands and pass/fail outcome
- Remaining risks or gaps
- Whether completion is safe to claim

## Completion integrity

Do not cut corners. Inspect required evidence directly, do not use placeholders or cherry-picked results, and report blockers or verification gaps instead of pretending completion. Follow the bootstrap completion-integrity rule.

