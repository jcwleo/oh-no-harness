# Verify Report: <title>

- Date: YYYY-MM-DD
- Slug: <slug>
- Spec: docs/oh-no/specs/YYYY-MM-DD-<slug>-spec.md | none
- Plan: docs/oh-no/plans/YYYY-MM-DD-<slug>-plan.md | inline
- Progress: docs/oh-no/runs/YYYY-MM-DD-<slug>-progress.md | none
- Verification checkout/worktree: <path and branch | current checkout>
- Final status: VERIFIED | PARTIAL | MISSING

## Claims checked

| VR ID | Linked ID | Claim | Evidence | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| VR-001 | AC-001 | <claim> | <command/file:line> | VERIFIED/PARTIAL/MISSING | <notes> |

## Evidence-before-claims gate

- Fresh command/inspection run for each claim: yes | no
- Output read directly: yes | no
- Verification checkout/worktree confirmed: yes | no
- Diff or changed-file scope reviewed: yes | no | not applicable
- RED/GREEN regression proof checked: yes | no | not applicable

## Commands run

```text
<command> -> <result>
```

## Root-cause and instrumentation check

- Root cause fixed rather than symptom masked: yes | no | not applicable
- Temporary workaround present: no | yes, documented below
- Diagnostic logging/tracing/assertions: removed | gated | intentionally retained | not used

## Retrieval and evidence gaps

- Searched/checked: <files, commands, searches>
- Could not verify: <none or gaps>

## Completion decision

- Safe to claim complete: yes | no
- Remaining risks: <none or details>
