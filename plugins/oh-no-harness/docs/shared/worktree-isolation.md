# Worktree Isolation

Use this contract for write-capable coding tasks. It protects the user's current
checkout when the same repository may be open in multiple Codex App, Claude
Code, terminal, or GUI sessions.

This policy is separate from parallel subagent dispatch. A single agent working
alone still applies the worktree gate before editing source files.

## Non-Execution Phases

`interview` and `ralplan` do not need to run inside a worktree by default. They
may create `.oh-no` specs, plans, or session notes in the current checkout
because they are pre-execution artifacts.

Worktree isolation starts before `ralph`, `autopilot`, or an inline execution
path changes source files, tests, scripts, manifests, generated artifacts, or
other task-owned files.

## HARD-GATE

For write-capable execution, no source file edits may happen until a
`Worktree decision` is recorded.

Allowed decisions:

- `approved worktree`: the user approved creating or using a task worktree.
- `already in approved worktree`: the current checkout is already the approved
  task worktree.
- `user declined/current checkout`: the user explicitly declined worktree use
  for this task, so execution continues in the current checkout.
- `autopilot automatic worktree`: `autopilot` created or selected a task
  worktree without asking because the user delegated end-to-end execution.
- `read-only/not applicable`: the task will not edit files.
- `blocked`: the repository cannot support the requested worktree and no allowed
  fallback has been recorded.

If the decision is missing, ambiguous, or not one of the allowed decisions, stop
before editing and resolve the gate.

## Direct Ralph

For direct `ralph` execution, ask the user once before creating or switching to a
task worktree. Recommend worktree use as the default.

After the user answers, record the `Worktree decision` in the session note or
PRD and do not ask again for the same task/session unless the user changes the
scope or the recorded decision becomes invalid.

If the user approves, create or select a task worktree before editing. If the
user declines, record `user declined/current checkout` and continue only after
that decision is visible in the execution artifact.

## Autopilot Automatic Worktree

`autopilot` does not ask the one-time direct-Ralph worktree question. For
write-capable execution, it must create or select a task worktree automatically,
record `Worktree decision: autopilot automatic worktree`, and run implementation
inside that worktree.

After execution passes verification in the task worktree, `autopilot` must merge
the completed work back into the integration checkout, run post-merge
verification, and record whether the worktree was cleaned up or deliberately
left for inspection.

If worktree creation, merge, or post-merge verification fails, report the blocker
instead of silently editing the original checkout.

## Artifact Handoff

When execution moves from the planning checkout into a worktree, preserve access
to the approved `.oh-no` spec, plan, or PRD before editing. Use one of:

- copy the relevant artifact into the worktree's `.oh-no` path
- record an explicit absolute artifact path in the execution artifact
- quote the approved task definition in the execution artifact when the source
  artifact is intentionally not copied

Do not rely on untracked `.oh-no` files automatically appearing in a new git
worktree.

## Command Shape

Prefer ordinary git worktrees and task-specific branches. The exact names may
follow the host project's conventions.

```sh
git worktree add ../<repo>-<task-slug> -b <branch-name>
```

Before integrating, inspect the worktree diff. After integrating, run the
verification required by the selected Ralph mode. Clean up only when the merge
and post-merge verification are complete or when the user asks to cancel the
work.
