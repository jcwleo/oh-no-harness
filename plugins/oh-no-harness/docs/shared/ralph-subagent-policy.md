# Ralph Subagent Policy

This policy is shared by Claude Code and Codex. It began as Ralph's dispatch
policy and now defines when Ralph, Ultrawork, Simplify, Systematic Debugging,
Interview brownfield exploration, and Verification Before Completion may split
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

Oh No Harness should use subagents when they provide decision-changing benefit:
independent evidence, context-window relief, latency reduction, or safer
separation of review from implementation. Treat a standing user or plan
preference to use subagents proactively as explicit authorization for eligible
isolated roles, not as a command to spawn every possible role. On
subagent-capable hosts, prefer dispatch for read-heavy exploration, triage,
test/log analysis, summarization, verification (scenario QA lens included),
code review (security lens included), and other independent review roles when
the result can change the next decision. Inline execution is
appropriate when work is too small to benefit, cannot be isolated, requires
tight TDD sequencing, lacks host support, has been explicitly made inline-only,
or can be checked with an equally credible final narrow checklist.
Requests to maximize subagents mean maximize useful, decision-changing
delegation within those eligibility limits; they do not mean unconditional
dispatch.

Explicit user requests, standing preferences, approved plan triggers, or active
skill dispatch policies are sufficient when the host platform permits dispatch.
Natural dispatch is allowed only when the host tool definition permits
proactive dispatch and the selected mode, task risk, scope isolation, and
context-window benefit justify it.

On Codex, a SessionStart block named
`CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION` is the Oh No Harness standing
preference for sub-agents, delegation, and parallel agent work. Treat it as the
explicit session-level authorization for eligible isolated roles inside active
Oh No Harness workflows; do not ask for per-run subagent approval only to satisfy
that authorization.

A separate Codex SessionStart block named
`CODEX_ONLY_OH_NO_READONLY_EXPLORATION_DELEGATION` may authorize one no-skill
exploration subagent for simple read-only repository fact lookup. That lane is
limited to locating, tracing, or summarizing existing code/config/tests/docs; it
does not authorize planning, debugging, implementation, review (security lens
included), scenario QA, completion verification, ambiguous requirements, or
edits. It must not
read or reproduce secrets unless the user explicitly asks for that sensitive
lookup, and credential values must be redacted in subagent output. Without an
active workflow, dispatch only the registered read-only `oh-no-explore` custom
agent when the host recognizes it. If custom-agent dispatch is rejected as
unknown or unavailable, or only generic/default agents are available, keep the
lookup inline. If `oh-no-explore` is spawned, the next lifecycle tool for that
receiver must be the active wait mechanism, repeated until it returns that
receiver with final status `completed`; only then close or clean it up.
Close/cleanup output is not a substitute for the required wait result.

When the host is subagent-capable and the work has concrete isolated roles,
prefer dispatch over silently compressing every role that would provide
decision-changing evidence into the main context. The goal is independent
evidence and context separation, not merely parallelism.

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
- the role output would not change the implementation, review, verification, or
  ship/block decision
- remaining work is a final narrow re-check that an inline checklist can cover
  with equal evidence
- lifecycle, waiting, or integration cost is higher than the risk reduction for
  the selected execution mode

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

A wait timeout, empty wait result, or "no agents completed" response is not a
final status. Hard rule: MUST NOT close a running or pending subagent merely
because it is slow. Wait longer when the result is still needed, continue
non-overlapping local work, or record the role as pending or blocked. Close
without a captured final result only when the user explicitly cancels or stops
that subagent, the task scope invalidates the work, the spawn was duplicate or
mis-scoped, or continuing creates a safety, security, or filesystem risk. Record
that close as cancelled or abandoned and never use missing output as completion
evidence.

Do not leave completed subagents open after their outputs have been integrated,
rejected, or recorded as blocked. If the active platform does not expose an
explicit close or cleanup mechanism, record that no close mechanism was
available.

## Role Prompt And Task Packet Split

Registered custom agents and plugin-scoped agents provide the stable role
contract: role purpose, boundaries, operating rules, and output shape. They do
not carry the current story's acceptance criteria, file ownership, baseline
guard, contract surface, or lifecycle decision.

The active skill supplies those task-specific details in the dispatch packet at
spawn time. This packet is the only place to put per-task scope, `Do not touch`
paths, verification responsibility, dependencies, integration owner, and
wait/close expectations. Do not move platform invocation syntax or generated
wrapper metadata into `docs/agent-core`; do not move task-specific scope into
generated agent files.

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
- code review (security lens included) and verification (scenario QA lens
  included) run after implementation is stable

Do not parallelize when:

- two agents would edit the same file, directory, schema, migration, generated
  artifact, lockfile, or shared config
- one task depends on another task's output
- one behavior's TDD RED/GREEN order would be split across agents
- file ownership is unclear
- an implementer is still fixing unresolved reviewer findings

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
