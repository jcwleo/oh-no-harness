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

Worktree isolation starts before `ralph`, `ultrawork`, or an inline execution
path changes source files, tests, scripts, manifests, generated artifacts, or
other task-owned files.

## HARD-GATE

For write-capable execution, no source file edits may happen until a
`Worktree decision` is recorded.

Allowed decisions:

- `approved worktree`: the user approved creating or using a task worktree.
- `already in approved worktree`: the current checkout is already the approved
  task worktree.
- `direct automatic worktree`: direct `ralph` created or selected a task
  worktree by default without asking a worktree approval question. The task
  worktree and branch are the direct-Ralph deliverable unless the user or a
  caller explicitly approves integration.
- `user declined/current checkout`: the user explicitly declined worktree use
  for this task, so execution continues in the current checkout.
- `ultrawork automatic worktree`: `ultrawork` created or selected a task
  worktree without asking because the user delegated end-to-end execution.
- `read-only/not applicable`: the task will not edit files.
- `blocked`: the repository cannot support the requested worktree and no allowed
  fallback has been recorded.

If the decision is missing, ambiguous, or not one of the allowed decisions, stop
before editing and resolve the gate.

### Source Edit Location Guard

After the worktree decision is recorded, every source-editing command must run
against the recorded execution checkout. Before the first edit, record:

- execution checkout path
- integration checkout path, when different
- expected deliverable files or file classes

Before each manual patch, generated rewrite, or tool-driven source edit, confirm
the command's working directory or explicit path target is inside the execution
checkout. If a patch tool cannot set a working directory reliably, use explicit
paths relative to the execution checkout or stop and correct the command shape
before editing.

If an edit accidentally lands in the integration checkout or another location,
do not continue on top of it. Record the mistake, inspect the unintended diff,
move only task-owned edits into the execution checkout, restore the unintended
location without touching unrelated user changes, and rerun the local status
checks before proceeding.

Profile policy values:

- `direct-automatic-worktree`: direct `ralph` creates or selects a task worktree
  by default before write-capable execution and leaves the completed task branch
  or worktree for review unless an explicit integration step is approved.
- `automatic-worktree-merge`: `ultrawork` creates or selects a task worktree by
  default, then merges completed work back into the integration checkout.
- `not-applicable`: read-only work or pre-execution artifacts that do not edit
  task-owned files.

## Default Location

Automatic task worktrees must be registered Git worktrees created with
`git worktree add`. Do not substitute `git clone`, `cp -R`, a plain directory,
or a manual checkout; those are not task worktrees for this contract.

Automatic task worktrees are project-local by default. Create registered Git
worktrees under:

```text
.oh-no/worktrees/<task-slug>
```

from the integration checkout, using a task-specific branch. This keeps task
directories managed inside the project instead of scattering sibling worktrees
through the parent workspace directory.

Do not create automatic Ralph or Ultrawork task worktrees as
parent-directory siblings unless the project-local path is impossible or the
user explicitly requests another location. If project-local worktree creation
fails, record the blocker or explicit fallback decision before editing.

Because `.oh-no/` is normally ignored by the repository, project-local worktree
directories should not pollute the integration checkout's status. Still inspect
`git worktree list` before reusing a task slug, and inspect task changes from
inside the task worktree with `git -C .oh-no/worktrees/<task-slug> status` or an
equivalent command. The integration checkout's `git status` may not show edits
inside the ignored task worktree directory.

Before writing transient Oh No Harness artifacts in a target repository, confirm
that `.oh-no/` is ignored by the repository or by the local Git exclude file. If
it is not already ignored and the user did not ask to version harness artifacts,
append `.oh-no/` to `.git/info/exclude` rather than editing project
`.gitignore`. This is local workspace hygiene, not a source change. Recheck the
deliverable diff before completion and remove any unintended `.oh-no` artifacts
from the patch.

Remove completed task worktrees with
`git worktree remove .oh-no/worktrees/<task-slug>` only after the work was
integrated or deliberately abandoned and any required post-integration
verification is complete. Direct `ralph` normally leaves its completed worktree
or branch in place for external review. Do not clean up active task worktrees
with manual deletion or broad cleanup commands that remove `.oh-no/`.

If Ralph or Ultrawork is invoked from inside an existing
`.oh-no/worktrees/<task-slug>` checkout, do not create a
recursive nested worktree under that task checkout. Treat the current checkout as
`already in approved worktree` when it matches the task, or resolve worktree
creation from the integration checkout and record the explicit path.

## Direct Ralph

For direct `ralph` execution, create or select a registered Git worktree under
`.oh-no/worktrees/<task-slug>` by default before editing. Do not ask a worktree
approval question. Skip automatic worktree creation only when the user
explicitly asks to decide the execution location, the current checkout is
already an approved task worktree, the task is read-only, or the repository
cannot support `git worktree add`.

Record `Worktree decision: direct automatic worktree` in the session note or PRD
before editing. If the current checkout is already the approved task worktree,
record `already in approved worktree`. If the user explicitly declines worktree
use, record `user declined/current checkout` and continue only after that
decision is visible in the execution artifact.
If the repository cannot support a worktree and no explicit current-checkout
fallback is approved, record `blocked` and stop before editing.

Once a direct-Ralph worktree decision is recorded, do not ask again for the same
task/session unless the user changes the scope or the recorded decision becomes
invalid.

Direct `ralph` does not merge the task worktree back into the integration
checkout by default. Its final report must name the task branch, worktree path,
integration checkout, and integration status (`not merged by direct Ralph` unless
the user explicitly approved integration). If the user asks direct `ralph` to
integrate, treat that as an explicit integration step: inspect the task diff,
merge or apply only task-owned changes, run the selected mode's post-integration
verification, and report any blocker instead of silently editing the original
checkout.

## Ultrawork Automatic Worktree

`ultrawork` also uses automatic worktree execution. Its distinct responsibility
is post-execution integration: for write-capable execution, it must create or
select a registered Git worktree under `.oh-no/worktrees/<task-slug>`
automatically, record `Worktree decision: ultrawork automatic worktree`, and run
implementation inside that worktree.

After execution passes verification in the task worktree, `ultrawork` must merge
the completed work back into the integration checkout, run post-merge
verification, and record whether the worktree was cleaned up or deliberately
left for inspection.

If worktree creation, merge, or post-merge verification fails, report the blocker
instead of silently editing the original checkout.

## Artifact Handoff

When execution moves from the planning checkout into a worktree, preserve access
to the approved `.oh-no` spec, plan, or PRD before editing. A project-local
worktree under `.oh-no/worktrees/<task-slug>` does not automatically make the
integration checkout's untracked `.oh-no/specs/`, `.oh-no/plans/`, or
`.oh-no/sessions/` content available inside the task worktree. Use one of:

- copy the relevant artifact into the worktree's `.oh-no` path
- record an explicit absolute artifact path in the execution artifact
- quote the approved task definition in the execution artifact when the source
  artifact is intentionally not copied

Do not rely on untracked `.oh-no` files automatically appearing in a new git
worktree.

## Command Shape

Prefer ordinary git worktrees and task-specific branches. The exact names may
follow the host project's conventions, but automatic task worktrees should stay
under `.oh-no/worktrees/` unless an explicit fallback is recorded.

```sh
mkdir -p .oh-no/worktrees
git worktree add .oh-no/worktrees/<task-slug> -b <branch-name>
```

Before any approved integration, inspect the worktree diff. After integrating,
run the verification required by the selected Ralph mode. Clean up only when the
integration and post-integration verification are complete or when the user asks
to cancel the work.
