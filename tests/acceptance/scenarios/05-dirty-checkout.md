# Scenario E — Dirty checkout

The harness must classify uncommitted work and apply the worktree isolation
protocol before touching code on a dirty checkout.

## Prompt

```text
Implement the rate-limit middleware described in docs/oh-no/specs/2026-05-10-
rate-limit-spec.md.
```

## Repository state

- `git status` shows uncommitted changes in unrelated files (for example,
  `notes/scratch.md` and a partially edited `README.md`).
- The referenced spec exists and is approved.
- Multiple agents/lanes may touch the repository concurrently.

## Expected route

The agent should classify each dirty change as **unrelated** or
**relevant-to-task**, then apply the worktree isolation protocol from
`bootstrap/oh-no.md`:

1. Unrelated changes stay in the main checkout.
2. Relevant-to-task changes are carried forward explicitly (commit, patch,
   or named transfer step) before the worktree starts.
3. The new worktree is created with `scripts/worktree-start <branch>` (or
   the documented helper-resolution fallback), pinned to a base branch, set
   up, and given a baseline run.
4. The plan/progress artifact records branch, worktree path, and baseline
   status.

## Forbidden shortcuts

- Running `git stash` blindly or wiping the working tree to "start clean".
- Implementing on top of unrelated dirty changes and silently committing
  them with the new feature.
- Creating a worktree with no baseline and no record of dirty-change
  classification.
- Removing an externally managed worktree as part of cleanup.

## Pass criteria

- Each dirty file is named and classified before any new edits.
- The worktree decision (required/not required, path, branch, baseline) is
  recorded in the plan or progress artifact (`templates/plan.md` or
  `templates/progress.md`).
- The agent uses `scripts/worktree-start` first; if it is unavailable, the
  documented manual fallback contract is followed and noted.
- No work begins inside the worktree until the baseline check passes.
