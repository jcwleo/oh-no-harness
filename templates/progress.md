# Progress: <title>

- Date: YYYY-MM-DD
- Slug: <slug>
- Spec: docs/oh-no/specs/YYYY-MM-DD-<slug>-spec.md | none
- Plan: docs/oh-no/plans/YYYY-MM-DD-<slug>-plan.md | inline
- Status: active | blocked | ready-for-verify | complete
- Worktree: <path and branch | not used>

## Resume checkpoint

Read in this order before continuing:

1. Spec
2. Plan
3. This progress file
4. Latest verification report, if any

## Current state

- Current task: T-001 | none
- Completed tasks: <T-xxx list>
- Remaining tasks: <T-xxx list>
- Blockers: <none or details>
- Last known verification: <command -> result | not yet run>
- Branch: <branch | not applicable>
- Worktree: <path | not used>
- Worktree baseline: <command/result | not used>
- Dirty-change handling: unrelated left in main | carried by <method> | none | not used

## Changed files

- <path>: <summary>

## Evidence log

| Time | Command/check | Result | Linked IDs |
| --- | --- | --- | --- |
| <time> | <command> | <pass/fail/notes> | AC-001 |

## Review status

- Spec compliance review: pending | passed | failed | not needed
- Code quality review: pending | passed | failed | not needed
- Review findings needing another loop: <none or details>

## Root-cause evidence, if applicable

- Cause identified: <yes/no>
- Evidence connecting cause to fix: <files/logs/tests>
- Diagnostic instrumentation: <removed/gated/not used>

## Spec or plan discrepancies

- <none or discrepancy and resolution>

## Next action

- <first incomplete task or verification step>

## Finalization handoff

Ralph does not finalize. When the completion gate passes, the
finalization options live in `verify`.

- Ready for finalization: yes | no | partial
- Verification report: docs/oh-no/reports/YYYY-MM-DD-<slug>-verify.md | not yet created
- Latest verification: see `Last known verification` in Resume checkpoint above
- Blockers preventing finalization: <none or details>
