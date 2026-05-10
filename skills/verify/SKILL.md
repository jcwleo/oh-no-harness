---
name: verify
description: "Check completion claims against fresh evidence, tests, builds, lint, static checks, diffs, and spec acceptance IDs before final reporting."
---

# verify

Verify compares claims with evidence. It is the final gate before saying work is complete.

## Evidence-before-claims gate

Before any completion, success, fixed, passing, or ready claim:

1. Identify the exact claim.
2. Identify the fresh command, inspection, diff, or artifact that can prove it.
3. Run the full command or perform the inspection now; do not rely on stale output or another agent's summary.
4. Read the output or inspected evidence.
5. State the claim only with the evidence, or mark it `PARTIAL` / `MISSING`.

If you have not run or inspected the evidence in this verification pass, do not claim it passes.

## Worktree-aware verification

Before running checks, identify the verification checkout:

- If the plan or progress artifact records a worktree path/branch, verify the diff, commands, and artifacts from that worktree.
- If `Worktree isolation: required` is recorded but no worktree path is available, mark affected claims `PARTIAL` until the execution checkout is identified.
- If no worktree was used, explicitly verify against the current checkout and changed-file scope.
- Do not combine evidence from the main checkout with a worktree implementation unless the relationship is explicit and checked.

## Role passes

- `verifier`: default owner for claim-to-evidence mapping and `VERIFIED` / `PARTIAL` / `MISSING` status.
- `test-engineer`: use when test coverage, regression proof, RED/GREEN evidence, or alternate verification is uncertain.
- `code-reviewer`: use when changed code needs quality, security, maintainability, or regression-risk review.
- `architect`: use when the completion claim depends on architecture, boundaries, public API, migrations, or broad refactors.

If native subagents are unavailable, perform these as current-session read-only role passes.

## Process

1. List the claims being made.
2. Map each claim to `AC-*`, `INV-*`, task IDs, changed files, or explicit user requirements.
3. Identify the checkout/worktree where implementation happened and run all diff/command checks there unless explicitly justified.
4. Inspect the diff or changed-file list when work involved edits; verify the files changed match the claimed scope.
5. Choose the smallest fresh command or inspection that can prove each claim.
6. Run the checks and read the output.
7. Check that fixes address the root cause rather than only masking symptoms.
8. Check that temporary diagnostic logs, tracing, assertions, or mitigations were removed or intentionally gated and documented.
9. For regression tests, verify RED/GREEN evidence when practical: the check failed for the original bug or missing behavior and passes after the fix. If safe revert/disable proof is impractical, record the alternate evidence.
10. Record `VERIFIED`, `PARTIAL`, or `MISSING` for each required claim.
11. If any required claim is `PARTIAL` or `MISSING`, do not report completion; return to `ralph` or `debug`.

## Verify report

For context-window-sized work, write:

```text
docs/oh-no/reports/YYYY-MM-DD-<slug>-verify.md
```

Use `templates/verify.md` as the preferred structure. Each entry should use a stable ID:

- `VR-001`: claim, linked `AC-*` or `INV-*`, evidence command/file/diff, status, notes.

## Resume and context-window protocol

Before final verification on long work, read the spec, plan, and latest progress artifact. Rebuild the claim list from artifacts rather than memory. If artifacts disagree, mark the claim `PARTIAL` until the discrepancy is resolved.

If progress records a worktree, read that path and branch before verifying. If the worktree no longer exists, mark execution-dependent claims `PARTIAL` and report the missing checkout.

## Evidence hierarchy

Prefer, in order:

1. Targeted tests for changed behavior.
2. RED/GREEN regression proof for bug fixes when practical.
3. Typecheck, lint, build, or static analysis.
4. Reproduction or smoke checks.
5. Diff and file inspection against `AC-*`, `INV-*`, and scope.
6. Explicitly documented verification gap.

## Red flags

Stop and gather evidence instead of claiming completion when:

- The output was not read.
- Only a partial command ran but the claim is broad.
- A test was added but never observed failing for the original behavior.
- The implementation changed files outside the claimed scope and the diff was not reviewed.
- Another role reported success but no command, diff, or artifact evidence is available.
- A workaround, diagnostic log, disabled check, retry, or fallback remains unexplained.

## Final response shape

Report:

- Changed files or inspected files.
- Verification checkout/worktree.
- Verification commands and pass/fail outcome.
- `VERIFIED` / `PARTIAL` / `MISSING` status for required claims.
- Remaining risks or gaps.
- Whether completion is safe to claim.

## Completion integrity

Do not cut corners. Inspect required evidence directly, do not use placeholders or cherry-picked results, and report blockers or verification gaps instead of pretending completion. Follow the bootstrap completion-integrity rule.
