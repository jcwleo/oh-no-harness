# Parallel Subagent Coordination

Use parallel subagents only when the work can be isolated and integrated deliberately.

If user instructions or the current platform restrict delegation, follow those restrictions first.

## Dispatch Requirements

Before dispatching parallel work, write down:

- story or task id
- owned files, directories, or read-only scope
- files and directories that must not be touched
- expected output: patch, findings, evidence, or test result
- verification responsibility
- dependencies on other agents
- integration owner

Implementation subagents must be told that they are not alone in the codebase and must not revert, overwrite, or reformat work outside their assigned scope.

## Safe Parallel Work

Parallelize when:

- agents are read-only and inspect different subsystems
- executor write scopes are disjoint
- reviewers inspect the same final diff without editing
- QA, security review, and code review run after implementation is stable

Do not parallelize when:

- two agents would edit the same file, directory, schema, migration, generated artifact, lockfile, or shared config
- one task depends on another task's output
- TDD RED/GREEN order for one behavior would be split across agents
- file ownership is unclear
- a reviewer has found unresolved issues that an implementer is still fixing

## Integration

After parallel work completes:

1. Inspect each result and changed-file set.
2. Resolve conflicts deliberately.
3. Run story-specific verification.
4. Run cross-story verification when shared behavior could be affected.
5. Reconcile documentation, tests, generated artifacts, and final assumptions.
6. Only then mark stories or tasks complete.
