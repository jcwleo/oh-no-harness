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
the result can change the next decision. On the same hosts, also prefer
dispatch for disjoint implementation (executor) work: when two or more pending
stories or tasks have verifiably non-overlapping write scopes and no
inter-dependency, run them as a concurrent executor batch for latency and
context-window relief. This makes independent implementation a first-class
dispatch reason, not only review or exploration — but it is justified
delegation, not parallelism for its own sake, and it stays bound by the
`## Safe Parallel Work` conditions and the Subagent-Unavailable fallbacks below.
Inline execution is appropriate when work is too small to benefit, cannot be
isolated, requires tight TDD sequencing, lacks host support, has been
explicitly made inline-only,
or can be checked with an equally credible final narrow checklist.
Requests to maximize subagents mean maximize useful, decision-changing
delegation within those eligibility limits; they do not mean unconditional
dispatch.

The equal-evidence / final-narrow-checklist inline exception covers re-running
or re-inspecting verification commands only, and that legitimate inline command
re-run remains valid. It does not cover the independent verifier audit — the
acceptance-to-evidence mapping plus the adversarial test-genuineness audit —
when the proving tests or implementation were authored or accepted by the same
agent (the executor/maker, or the orchestrator that accepted the executor's
output). That audit has no equal inline evidence because it is a self-review of
maker artifacts; at STANDARD and THOROUGH on subagent-capable hosts it must be
dispatched to an independent `verifier`. "Equal evidence" means identical
command output, not a self-assessment of one's own tests. LIGHT work is
unaffected, and on a genuinely subagent-unavailable host run the audit inline
and record the fallback reason.

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
`CODEX_ONLY_OH_NO_READONLY_EXPLORATION_DELEGATION` governs simple no-skill
repository fact lookup when no active Oh No Harness workflow or explicit
user-requested subagent task exists. That lane is limited to locating,
tracing, or summarizing existing code/config/tests/docs; it does not authorize
planning, debugging, implementation, review (security lens included), scenario
QA, completion verification, ambiguous requirements, or edits. It must not read
or reproduce secrets unless the user explicitly asks for that sensitive lookup,
and credential values must be redacted in any output. The lane may dispatch the
registered read-only `oh-no-explore` custom agent, as many as the lookup needs
and not capped at one; if `oh-no-explore` is unavailable, answer inline rather
than falling back to a generic or prompt-embedded subagent. When the lane
dispatches, each dispatched result is a dependency: wait for the receiver to
reach a final status, capture it, and use it before the next action, per the `## Subagent Lifecycle` hard rule below. If role work beyond read-only
exploration would be useful, select the relevant Oh No Harness skill or get
explicit subagent authorization first.

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

The independent verifier audit named in "Subagent Bias" is never one of these
fallback cases on a subagent-capable host: when the proving tests or
implementation were authored or accepted by the same agent, "the output would
not change the decision" and "equal evidence" do not apply, because the audit's
value is its independence. Inline it only on a genuinely subagent-unavailable
host, and record the fallback reason.

These are fallback conditions, not permission to collapse role boundaries. When
subagents are unavailable, keep the same role blocks inline and state why
dispatch was unavailable.

## Batch Rule

When two or more independent subagents are allowed, Ralph must create the full
eligible batch first and then wait for results. Do not start one independent
subagent, wait for it, and only then decide whether to start the rest.

The batch rule applies only to independent work at the same dependency depth. It
must not merge dependent review stages. In `ralph`'s Review Gate and
`ultrawork`'s Final Validation, when `code-reviewer` and a confirming
independent `verifier` are both required, the `verifier` is not eligible for the
first batch: run the `code-reviewer` pair first, capture and synthesize reviewer
outputs, resolve findings or record a blocker, and only then dispatch the
confirming verifier pass per `docs/shared/cross-host-review.md`.

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

## Delegated Codex Executor Boundary

When a Claude Code session policy rebinds an executor slice to
`executor-codex`, the transport returns raw Codex stdout and owns no repository
evidence. The caller must capture protected-target state immediately before and
after the sequential delegated call, including integration-checkout git status
and a filesystem sentinel for the ignored `.oh-no/` subtree and sibling
worktrees, EXCLUDING the delegated task worktree from protected-target traversal.
The caller runs the caller-owned escape guard, halts before merge on an unexpected
protected-target change, and records the result.

That filesystem sentinel is a `path + mtime + size` manifest, not a content
hash, and prunes the active delegated task-worktree path before comparison. It
cannot detect a content rewrite with the same path, mtime, and size.
The git-status arm also cannot attribute a tracked file whose status
was already dirty and remains unchanged, while arbitrary temp paths and
non-`.oh-no/` ignored paths remain outside the guard.

After the guard is clean, the caller derives the changed-file set from the task
worktree and applies the normal per-executor scope check, RED preservation,
verification, and review. A worktree diff alone does not prove confinement. On
transport failure, inspect partial worktree changes before choosing the
caller-mediated native fallback.

## Safe Parallel Work

Parallelize when:

- read-only agents inspect different subsystems
- executor write scopes are disjoint
- reviewers inspect the same final diff without editing
- same-role review instances inspect the same stable artifact under the
  cross-host or Same-Host Parallel Fallback contract (the verifier is never
  such a pair — it stays a single self-host pass)

Do not parallelize when:

- two agents would edit the same file, directory, schema, migration, generated
  artifact, lockfile, or shared config
- one task depends on another task's output
- a verifier's evidence depends on code-reviewer findings being completed,
  synthesized, and resolved or recorded as blocking
- one behavior's TDD RED/GREEN order would be split across agents
- file ownership is unclear
- an implementer is still fixing unresolved reviewer findings

## Integration

After subagents finish:

1. Inspect each result and changed-file set. For executor results from a
   parallel batch, run a per-executor scope check before integrating: a
   lightweight scope/correctness check that each executor touched only its owned
   files, satisfied its assigned slice, and left no conflict. Escalate only a
   stray or risky slice — one that wrote outside its scope, missed its slice, or
   carries real risk — to `code-reviewer` or `verifier`; a clean slice needs no
   escalation. This per-executor check is distinct from, and does not replace,
   the end-of-run review gate.
2. Resolve conflicts deliberately.
3. Reconcile docs, tests, generated artifacts, and assumptions.
4. Close or clean up every completed subagent after its output has been captured
   and integrated, rejected, or recorded.
5. Run story-specific verification.
6. Run cross-story verification when shared behavior could be affected.
7. Mark work complete only after acceptance criteria and verification evidence
   pass.
