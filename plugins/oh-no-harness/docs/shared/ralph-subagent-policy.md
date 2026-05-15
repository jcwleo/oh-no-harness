# Ralph Subagent Policy

This policy is shared by Claude Code and Codex. It defines when Ralph may split
work into subagents, how to partition the work, and how to integrate results.
It does not define platform-specific invocation syntax.

## Dispatch Decision

Ralph may dispatch subagents only when all of these are true:

- the selected execution mode and agent policy allow delegation
- the active platform supports subagents
- the current request or approved plan allows the platform-specific dispatch
- the work can be isolated by file ownership, read-only scope, or review role
- the main agent can integrate the results deliberately

`LIGHT` work stays inline unless the user requested delegation or a specific
check cannot be credibly completed inline.

`STANDARD` work may use targeted subagents for isolated exploration,
implementation, review, verification, QA, or security checks.

`THOROUGH` work should use the role set warranted by the risk whenever the
active platform and approved plan allow it.

## Batch Rule

When two or more independent subagents are allowed, Ralph must create the full
eligible batch first and then wait for results. Do not start one independent
subagent, wait for it, and only then decide whether to start the rest.

While a batch is running, Ralph may continue only on local work that does not
overlap with the delegated scopes.

## Isolation Contract

Before dispatching, write down:

- story or task id
- role
- owned files, directories, or read-only scope
- files and directories the subagent must not touch
- expected output
- verification responsibility
- dependencies on other subagents
- integration owner
- start timing: background, foreground, or sequential

Implementation subagents must be told that they are not alone in the codebase.
They must not revert, overwrite, reformat, or broaden work outside their
assigned scope.

## Safe Parallel Work

Parallelize when:

- read-only agents inspect different subsystems
- executor write scopes are disjoint
- reviewers inspect the same final diff without editing
- QA, security review, code review, and verification run after implementation
  is stable

Do not parallelize when:

- two agents would edit the same file, directory, schema, migration, generated
  artifact, lockfile, or shared config
- one task depends on another task's output
- one behavior's TDD RED/GREEN order would be split across agents
- file ownership is unclear
- an implementer is still fixing unresolved reviewer findings
- `architect` and `critic` would review the same plan or completion evidence;
  run `architect` first and `critic` second

## Integration

After subagents finish:

1. Inspect each result and changed-file set.
2. Resolve conflicts deliberately.
3. Reconcile docs, tests, generated artifacts, and assumptions.
4. Run story-specific verification.
5. Run cross-story verification when shared behavior could be affected.
6. Mark work complete only after acceptance criteria and verification evidence
   pass.
