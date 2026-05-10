# Plan: <title>

- Date: YYYY-MM-DD
- Slug: <slug>
- Source spec: docs/oh-no/specs/YYYY-MM-DD-<slug>-spec.md | inline
- Mode: basic | ral
- Size: inline-checklist | artifact-plan | milestone
- Worktree isolation: required | optional | not needed
- Status: draft | approved | superseded

## Retrieval basis

- Explicit inputs checked: <paths, symbols, logs, tests, commands>
- Searches run: <rg/search commands or none>
- Evidence gaps: <unknowns that remain>

## Requirements summary

<Brief summary tied to AC/INV IDs.>

## Sizing decision

- Why this is not overplanned: <reason>
- Why this is not underplanned: <reason>
- If more than 7 tasks, milestone split: <yes/no and rationale>

## Worktree isolation

- Decision: required | optional | not needed
- Dirty changes: none | unrelated | relevant-to-task
- Carry-forward step for relevant dirty changes: <commit, patch, stash/apply, or not applicable>
- Reason: <dirty checkout, parallel agents, overlapping files, long-lived branch, or not needed>
- Suggested branch: <feature/slug>
- Helper resolution: project-local `scripts/worktree-start` | installed oh-no helper | manual fallback
- Suggested setup command: `scripts/worktree-start <branch> --baseline '<command>'` | `git worktree add ...`
- Baseline command: <command or none>

## Task list

### T-001: <task title>

- Linked IDs: AC-001, INV-001
- Owned files/modules: <paths>
- Objective: <what changes>
- Implementation notes: <smallest coherent change>
- TDD or verification-first step: <RED/GREEN/REFACTOR or alternate evidence>
- Commands/checks: <commands>
- Dependencies: <none or T-xxx>

## Risks and mitigations

- <risk>: <mitigation>

## Root-cause plan, if applicable

- Symptom/evidence: <logs/tests/runtime behavior>
- Hypothesis to test: <hypothesis>
- Diagnostic logging/tracing/assertions needed: <yes/no; remove or gate plan>

## RALPLAN-DR, if `--ral`

- Principles:
- Decision drivers:
- Viable options:
- Architect review:
- Critic review:
- Re-review loop status:
- ADR:

## Plan self-review

- Placeholder scan passed: yes | no
- File/symbol/test names consistent: yes | no
- Every AC/INV linked to task or verification: yes | no
- Commands/checks concrete: yes | no
- Remaining planning risks: <none or details>
