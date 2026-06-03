# Ralph Subagent Policy

This policy is shared by Claude Code and Codex. It defines when Ralph may split
work into subagents, how to partition the work, and how to integrate results.
It does not define platform-specific invocation syntax.

## Dispatch Decision

Ralph may dispatch subagents only when all of these are true:

- the selected execution mode and agent policy allow delegation
- the active platform supports subagents
- the active skill, current request, or approved plan allows the
  platform-specific dispatch
- the work can be isolated by file ownership, read-only scope, or review role
- the main agent can integrate the results deliberately

## Subagent Bias

OpenAI Codex subagent guidance emphasizes that subagents keep noisy
intermediate work out of the main thread, preserve focus on requirements and
decisions, run independent exploration, tests, and log analysis in parallel, and
return distilled summaries instead of raw context-heavy output.

Oh No Harness should use subagents as much as possible when those benefits
apply. Treat a standing user or plan preference to use subagents aggressively as
explicit authorization for eligible isolated roles. On subagent-capable hosts,
dispatch by default for read-heavy exploration, triage, test/log analysis,
summarization, verification, QA, security review, code review, and other
independent review roles. Inline execution is the exception for work that is too
small to benefit, cannot be isolated, requires tight TDD sequencing, lacks host
support, or has been explicitly made inline-only.

Explicit user or plan requests are sufficient when the host platform permits
dispatch. Natural dispatch is allowed only when the host tool definition permits
it and the selected mode, task risk, scope isolation, and context-window benefit
justify it.

When the host is subagent-capable and the work has concrete isolated roles,
prefer dispatch over silently compressing every role into the main context. The
goal is independent evidence and context separation, not merely parallelism.

`LIGHT` work may stay inline only when it is a tiny, direct edit or inspection
with no meaningful context-separation benefit. Dispatch isolated read-heavy,
review, or verification checks when they would keep the main thread cleaner.

`STANDARD` work should use targeted subagents for isolated exploration,
implementation, review, verification, QA, or security checks whenever the active
platform supports them and coordination cost is reasonable.

`THOROUGH` work must use the role set warranted by the risk whenever the active
platform supports dispatch and the roles can be isolated.

## Subagent-Unavailable Environments

Perform roles inline and record the fallback reason when any of these apply:

- the current host tool definition does not expose the platform's subagent,
  background task, spawn, or wait mechanism
- the plugin or host environment does not expose the required role agents or
  prompt files
- host policy, approval mode, organization policy, or sandbox settings block
  subagent creation
- the subagent tool exists but spawning fails, the agent/thread limit is reached,
  or the host reports that background tasks are unavailable
- the active skill, selected execution mode, or approved plan requires inline-only
  execution
- the work cannot be isolated by file ownership, read-only scope, review role, or
  expected output
- the main agent cannot inspect and integrate the subagent result deliberately

These are fallback conditions, not permission to collapse role boundaries. When
subagents are unavailable, keep the same role blocks inline and state why
dispatch was unavailable.

## Batch Rule

When two or more independent subagents are allowed, Ralph must create the full
eligible batch first and then wait for results. Do not start one independent
subagent, wait for it, and only then decide whether to start the rest.

While a batch is running, Ralph may continue only on local work that does not
overlap with the delegated scopes.

## Subagent Lifecycle

The caller owns subagent lifecycle. After each dispatched subagent reaches a
final status, capture its result, changed-file set, and any follow-up evidence
needed for integration. Once that output has been inspected and no further
input is needed, close or clean up the completed subagent using the active
platform's mechanism.

Do not leave completed subagents open after their outputs have been integrated,
rejected, or recorded as blocked. If the active platform does not expose an
explicit close or cleanup mechanism, record that no close mechanism was
available.

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
4. Close or clean up every completed subagent after its output has been captured
   and integrated, rejected, or recorded.
5. Run story-specific verification.
6. Run cross-story verification when shared behavior could be affected.
7. Mark work complete only after acceptance criteria and verification evidence
   pass.
