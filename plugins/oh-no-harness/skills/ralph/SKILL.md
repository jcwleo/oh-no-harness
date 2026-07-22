---
name: ralph
description: Use when implementing or executing an approved plan, PRD, spec, story list, ticket, or concrete task with acceptance criteria, required verification, or multiple implementation steps.
argument-hint: "<approved plan, PRD path, spec path, or concrete task>"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Ralph for Codex

This generated file is the Codex-facing runtime skill document. Codex should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/ralph.md`
- `../../docs/platforms/codex-ralph.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/ralph.md

# Ralph

Ralph is a mode-gated execution loop: it works until acceptance criteria are
satisfied with fresh evidence, required review and cleanup gates are handled,
and the final report is written. Ralph's main agent is the orchestrator: it
owns `.oh-no` state, gate decisions, result intake, and FSM transitions while
executor roles own default repository work-product mutation in
STANDARD/THOROUGH. Ralph owns execution mode selection or enforcement for
ordinary implementation. Do not route concrete add/fix/refactor/implement
requests directly to `test-driven-development`; Ralph invokes TDD internally
when behavior-changing edits require it.

Do not use when requirements are still vague — use `interview` or `ralplan`
first. Entering directly from `interview`, accept the path only if the spec's
provisional Ralph mode is `LIGHT`; a non-LIGHT spec without a `ralplan` plan
needs user re-confirmation before editing.

Interpret `MUST`, `MUST NOT`, `ONLY`, and `STOP` literally.

## Invariants

```text
E1. Copy the approved Direction Contract without reinterpretation before
    editing. If execution would change it, stop for explicit approval instead
    of silently rescoping. If the approved plan or an AC is itself wrong or
    infeasible as written, stop and route back to the user or `ralplan`
    (present options; never auto-invoke).
E2. An execution mode is recorded before any file change. Source priority:
    approved ralplan profile > explicit user instruction > interview LIGHT
    hint > Ralph-derived. Never de-escalate below an approved plan's mode
    without user approval.
E3. No source edit until a `Worktree decision` is recorded from the allowed
    table. A registered Git worktree is the direct-Ralph default; substitutes
    (`git clone`, `cp -R`, plain directories) are forbidden.
E4. Behavior-changing work requires RED evidence (fails against old behavior)
    before implementation and GREEN evidence before story completion; bug
    fixes need a reproduction; refactors need characterization; exceptions
    are recorded compactly.
E5. Every changed file and meaningful changed line traces to approved work;
    out-of-scope findings become residual risk or follow-ups, not diff growth.
E6. Parallel dispatch only for disjoint write scopes with no inter-dependency
    and clear ownership; create the whole eligible batch before waiting; a
    timeout or empty wait is never a final result.
E7. Review-then-verify: the selected code-review stage completes before the
    single independent self-host verifier starts; on blocking findings, the
    verifier starts only after the single fix manifest is recorded. The
    verifier is never the maker and never a pair.
E8. Review topology is mode-gated with a one-round budget: exactly one review
    round. Accepted blocking findings get one executor-owned focused fix; the
    independent verifier then audits the fixed revision as the safety net. A
    blocker unresolved after that goes to rescope or user direction.
E9. Mutation invalidates intersecting evidence except that the review verdict
    remains bound to its reviewed revision after the single post-review fix;
    the verifier owns freshness by binding to the mutated revision. A success
    status without the observable effect is missing evidence. Redact
    secrets/PII before writing evidence.
E10. Budget gates stop for rescope; a budget breach never authorizes
     automatic expansion.
E11. The run is invalid until every completion criterion is individually
     recorded in the session ledger; a silently omitted step is a named
     ledger gap, not a pass.
E12. Cleanup is trigger-gated after the behavior lock and BEFORE the single
     review round; rerun relevant verification whenever cleanup changes files;
     post-review cleanup is read-only (findings become residual risk or
     follow-ups).
E13. A direct-Ralph automatic worktree is not complete while work sits in the
     worktree: merge back with post-merge verification, or report the
     branch/PR handoff; on failure leave the worktree intact.
E14. Resume reconstructs state from artifacts, never working memory.
E15. Ralph is terminal: after the final report, no workflow skill is
     auto-invoked. Mid-loop skills (`test-driven-development`, `simplify`,
     `verification-before-completion`, `systematic-debugging`,
     `fusion-rescue`) are documented loop internals, not chaining events.
E17. The main agent is the orchestrator and sole owner of `.oh-no` state and
     FSM transitions. STANDARD/THOROUGH repository work-product mutation,
     including REVIEW-to-EXECUTE focused fixes, dispatches `executor`; inline
     mutation is only a recorded LIGHT-tiny or dispatch-unavailable fallback.
     Role result enums are caller gate inputs, never autonomous transitions.
```

`STOP` / `blocked` means: persist the snapshot with the blocked transition,
evidence, and unblock condition, then report — never a silent exit.

## Execution Run Snapshot

Maintain one snapshot in the session note or PRD; persist it at every phase
change, story completion, verdict, mutation, dispatch lifecycle change, and
before any pause [E14].
It is a resume index into the artifacts below, not a second evidence ledger.

```text
Execution run:
- Run: <id>; Phase: PREPARE | EXECUTE | REVIEW | FINALIZE
- Checkpoint: none | CLEANUP | RECHECK | INTEGRATE | COMPLETION_AUDIT
- Outcome: none | COMPLETE | PAUSED | RETURN_TO_PLAN
- Plan/approval: <path>; <status/source>
- Mode: <LIGHT|STANDARD|THOROUGH>; <source>; <tier>; <policies>; <Parallel trigger>
- Worktree decision and location: <decision>; <location>
- Stories: <id: status/passes — detail stays in prd.json>
- Review: <topology>; <verdict>; verifier-after-reviewer <yes|no|not-required>
- Budgets: <process-budget status>; diff-budget <pending | passed@<fingerprint> | stale>
- Freshness: <evidence invalidated by the last mutation>
- Active dispatches: <Packet ID; host handle; role; scope; pending|final|abandoned>
```

Keep an entry `pending` until its final output is captured, identity/revision is
validated, and the result is integrated or recorded with the host cleanup
decision. Mark it `final` only after those caller-owned intake steps complete;
the Packet ID remains the compact reference to the full issued packet.

## State Machine

| Phase | Exit guard | Next |
|---|---|---|
| PREPARE | Direction Contract copied; mode, profile, active gates, budgets recorded; Worktree decision recorded; artifacts scaffolded per policy [E1, E2, E3] | EXECUTE |
| PREPARE | input too vague, or non-LIGHT spec without plan unconfirmed [E1] | outcome RETURN_TO_PLAN |
| PREPARE | worktree or environment blocked [E3] | outcome PAUSED |
| EXECUTE | a ready story remains | EXECUTE (orchestrated story loop below [E4, E5, E10, E17]) |
| EXECUTE | all stories pass with fresh evidence; CLEANUP and RECHECK are recorded; Diff-Budget Gate is `passed@<current stabilized fingerprint>` for the post-cleanup stabilized revision [E9, E10, E12] | REVIEW |
| EXECUTE | plan or AC infeasible as written [E1] | outcome RETURN_TO_PLAN |
| EXECUTE | debugging ladder exhausted [E15] | outcome PAUSED |
| REVIEW | reviewer verdict approve (or compliant not-required) and verifier pass / accepted pass-with-residual-risk bound to the reviewed revision; compliant verifier not-required follows the same reviewed-revision path [E7, E8, E17] | FINALIZE |
| REVIEW | reviewer verdict blocking-findings [E8, E17] | EXECUTE-fix (exactly one executor-owned focused fix; no reviewer re-dispatch) |
| REVIEW | fix manifest maps every accepted blocking finding ID; verifier pass (or accepted pass-with-residual-risk) binds to the FIXED revision with a per-finding resolution audit [E7, E8, E9, E17] | FINALIZE |
| REVIEW | verifier fail, or a blocking finding remains unresolved after the one fix + verifier audit, or reviewer or verifier verdict is `blocked` [E8, E10] | PAUSED / `systematic-debugging` / `failed_verification` per budget |
| REVIEW | a required independent verifier has no separate context (`dispatch-unavailable`) [E7, E11] | outcome PAUSED |
| FINALIZE | checkpoints INTEGRATE -> COMPLETION_AUDIT are satisfied and Diff-Budget is `passed@<current stabilized fingerprint>` [E9, E11, E13] | outcome COMPLETE |
| FINALIZE | merge or post-merge verification fails [E13] | outcome PAUSED |
| any | user stop, or a Direction Contract change is required [E1] | outcome PAUSED |

## Artifacts

Phase: PREPARE — scaffold per the artifact policy before editing.

```text
.oh-no/sessions/{sessionId}/prd.json          (full-prd-session)
.oh-no/sessions/{sessionId}/progress.md
.oh-no/sessions/{sessionId}/verification.md   (canonical AC-to-evidence ledger)
```

Reuse the chain session directory established earlier in this run; otherwise
create a timestamped one. On resume, the directory recorded in the run's
artifacts wins. LIGHT may use a compact session note unless the input
requires stories. `verification.md` is the canonical acceptance-to-evidence
ledger; PRD, progress, review, and report sections point to its AC IDs
instead of recreating mappings:

```text
Acceptance-to-evidence ledger row:
- AC ID; planned evidence; actual evidence;
- Coverage strength: direct | indirect | manual | missing
- Status: planned | actual | audited | stale | blocked
- Freshness source; reviewer findings by AC ID; verifier audit; residual risk
```

PRD stories (when the artifact policy requires a PRD, scaffold one from the
approved input before editing):

```json
{
  "title": "...",
  "directionContract": { "requirementsSource": "...", "primaryGoal": "...",
    "requiredOutcomeIds": ["AC-1"], "nonGoals": [], "constraints": [],
    "protectedAssumptions": [], "directionChangeApprovalRule": "explicit user approval",
    "confirmationStatus": "confirmed | inferred | open" },
  "executionMode": { "overallRalphMode": "...", "modeSource": "...",
    "verificationTier": "...", "artifactPolicy": "...", "agentPolicy": "...",
    "parallelTrigger": "...", "worktreeDecision": "...",
    "worktreeLocation": "...", "cleanupPolicy": "..." },
  "stories": [ { "id": "story-1", "description": "outcome", "executionMode": "...",
    "acceptanceCriteria": ["..."], "status": "pending", "passes": false } ]
}
```

Product or maintainer outcomes are stories; tests, review, cleanup, and
evidence stay activities under the AC-bearing story unless the user asked for
that infrastructure as a deliverable.

## Required Execution Mode

Phase: PREPARE. Ralph must set an execution mode before changing files and
must follow the selected mode during implementation, review, cleanup, and
reporting [E2]. Source priority per E2; with no approved profile, answer the
Execution Mode Decision Prompt and record `Mode source: derived by Ralph`.

Execution Mode Decision Prompt — answer from the request, repository facts,
and known verification commands, then choose the lightest credible loop:

```text
1. Expected size (files/lines) and existing test or verification coverage?
2. What observable behavior changes, and what real surface validates it?
3. Isolated, or crossing modules/generated artifacts/routing/public surface?
4. Could it affect runtime behavior, persisted data, permissions, secrets,
   network/filesystem, external services, concurrency, migrations, or
   destructive operations?
5. Are ACs and direct evidence already clear enough for a lighter loop?
6. What would force escalation mid-run?
7. Can a lighter mode produce credible evidence without skipping a stated
   requirement?
```

Mode definitions — `LIGHT | STANDARD | THOROUGH` (semantic risk selects;
category words alone never escalate):

```text
LIGHT    = risk-gated localized work (behavior or non-behavior) that clears
           the exclusion UNION and all six inclusion conditions; size is a
           soft screen that can only route OUT of LIGHT, never grant it;
           compact artifacts; dispatched `executor` -> dispatched independent
           `verifier`, with the code-reviewer pair waived.
STANDARD = localized behavior/config/prompt work with bounded blast radius
           and known ownership; session + verification artifacts; a
           perspective-diverse code-reviewer pair reviews behavior-affecting
           changes.
THOROUGH = active security/data/auth, destructive, public/release-critical,
           migration, changed concurrency/lifecycle, multi-system, or
           unknown-root-cause risk; full PRD session; risk-warranted roles.
```

### LIGHT Eligibility — Risk Gate, Soft Size Screen

LIGHT is the low-risk localized behavior change tier, and may also carry
non-behavioral work. All six bounded-judgment inclusion conditions MUST hold:

1. The intent is concrete.
2. The owner is known.
3. The root cause is known.
4. The change is localized: a bounded, cohesive edit set in one file or several
   tightly coupled files, with no cross-component contract. Multi-file
   COHESIVE changes are explicitly ALLOWED.
5. The change is trivially revertible.
6. A real-surface RED/GREEN check is feasible and named before editing, without
   a new harness and without manual-only or marker-only proof.

The hard exclusion UNION mirrors the surfaces protected by THOROUGH. LIGHT is
excluded when any of these is present or unknown: security/secrets/auth;
permission/tenancy; persisted data, storage, serialization, or retention;
public or external contracts, including CLI surfaces and documented config
keys or formats; release, build, CI, deploy, rollout, kill-switch, or other
operational surfaces; migration or backfill; a new dependency, dependency pin,
or lockfile; shared schema or central routing; generated files or generation
inputs; concurrency, scheduling, lifecycle, timeout, retry, or worker-count
semantics; destructive, filesystem, network, or external I/O; multi-system
scope; unknown root cause, owner, consumer, AC, or proof; difficult recovery;
or business-rule, financial, pricing, eligibility, compliance, moderation, or
safety-threshold materiality of the controlled VALUE, independent of technical
type or range-validity. Config is judged by what the VALUE CONTROLS, not the
file type. There is NO size-bound entry in this hard exclusion UNION. Loss of
cohesive localization fails the `localized` inclusion condition; large or
sprawling breadth is handled SOLELY by the soft screen below. No hard numeric
file-count or line-count bound exists anywhere in this eligibility gate.

Size — files touched, lines changed, and blast radius — is a SOFT candidate
screen applied AFTER the exclusion gate and inclusion conditions. A large or
sprawling change with many files, a broad or diffuse blast radius, or more than
a cohesive localized edit set routes OUT of LIGHT to STANDARD. Size alone
NEVER grants LIGHT and NEVER fails a task by itself; only the exclusion gate
and inclusion conditions decide eligibility, and size only vetoes LIGHT.
There is NO hard file-count or line-count cap.
`unknown = excluded (fail closed)` and escalation to STANDARD on any surprise
mid-run are the PRIMARY
safety mechanism now that there is no hard size backstop. Ordered selection is
`D ? direct-edit : T ? THOROUGH : L ? LIGHT : STANDARD`;
the exclusion gate runs regardless of size. An exclusion hit does not automatically select
THOROUGH; existing rules then select STANDARD or THOROUGH.

For behavior-changing LIGHT work, condition 6 MUST override and limit E4's
general compact-exception allowance:
behavior-LIGHT gets NO TDD-exception escape. If RED is infeasible, reclassify
to STANDARD or THOROUGH; E4's
invariant-block text remains byte-identical.

This mechanism is a deterministic exclusion gate plus bounded-judgment
inclusion conditions, not a fully mechanical predicate.

Escalate on new semantic risk (an exclusion becoming present-or-unknown,
the edit set growing past a cohesive localized scope, security/data/public
surface, unexpected verification results); de-escalate
only when evidence removes the risk and no approved plan pins the mode.

### STANDARD Small-Task Carve-Out

All conditions must hold — size alone is never sufficient:

- at most two tightly coupled handwritten implementation files, roughly 50
  or fewer handwritten changed lines (mechanical regeneration excluded)
- an existing test, focused command, or direct observable check already
  distinguishes the new behavior from the old
- no security, data, permission, public-contract, release-critical,
  migration, new-dependency, shared-schema, generated-surface, or
  concurrency-semantics surface; root cause is not unknown
- direct `ralph` execution (`ultrawork` keeps the ordinary reviewer)

Record the eligibility block before editing with
`Review topology: not-required (STANDARD small carve-out: <reason>)` and
`Status: provisional`. This waives only reviewer dispatch; STANDARD executor
ownership is unchanged. TDD, worktree isolation, session evidence, the
independent verifier, and verification-before-completion are unchanged. The
step-recheck reclassifies it against the actual diff: any unexpected file or
surface, bound breach, proof-path failure, test-infrastructure addition, or
new semantic uncertainty invalidates it — record
`Review topology: perspective-pair` and run the ordinary STANDARD
perspective-diverse pair before the verifier. A record still `provisional` at
completion-claim time is a named ledger gap.

## Worktree Isolation Gate

<HARD-GATE>
For write-capable execution, do not edit source files until a `Worktree
decision` is recorded [E3].
</HARD-GATE>

Phase: PREPARE. Record exactly one decision from this table; `Worktree
decision and location` (the PRD `worktreeLocation` field) appear in the
snapshot and final report:

| Decision (recorded verbatim) | When | Mutation allowed |
|---|---|---|
| `Worktree decision: direct automatic worktree` | direct Ralph default: create or select a registered worktree before editing, no approval question asked | in the worktree |
| `Worktree decision: light direct checkout` | LIGHT carve-out below fully holds | current checkout |
| `Worktree decision: user declined/current checkout` | the user explicitly declined worktree use | current checkout |
| `Worktree decision: approved worktree` / `already in approved worktree` | the user named a worktree, or the checkout already is the approved task worktree | in that worktree |
| `Worktree decision: ultrawork automatic worktree` | invoked from `ultrawork`; execute there, then return control to Ultrawork for merge and post-merge verification | in the worktree |
| `Worktree decision: read-only/not applicable` | the task edits no files | none |
| `Worktree decision: blocked` | the repository cannot support the worktree and no fallback is approved | none — stop |

Default creation:

```sh
git worktree add .oh-no/worktrees/<task-slug> -b <branch-name>
```

Keep automatic task worktrees project-local under `.oh-no/worktrees/` — not
the parent workspace directory — and never substitute `git clone`, `cp -R`, a
plain directory, or a manual checkout. Do not nest a worktree inside an
existing `.oh-no/worktrees/` checkout. Inspect task changes from inside the
worktree (`git -C .oh-no/worktrees/<task-slug> status`); the integration
checkout's status does not show them.

LIGHT direct-checkout carve-out — ALL must hold: (1) LIGHT mode, (2) one
obvious file or tightly bounded edit set, (3) direct Ralph, never Ultrawork,
(4) no pre-existing uncommitted changes overlap the edit set or any files the
planned commands may mutate, (5) no broad-mutating command such as generation,
dependency installation, lockfile or snapshot update, autofix, or format-all,
(6) pre-edit status and a non-scope fingerprint are recorded so final status
can prove the non-scope set unchanged, and (7) no approved-plan worktree policy
applies — Ralph derives and owns the decision. These safeguards matter more
because LIGHT permits cohesive multi-file behavior changes and the eligibility
gate has no hard size backstop. Record `Worktree decision: light direct
checkout` plus a one-line reason. A compliant LIGHT run is ALWAYS in-place
light-direct-checkout; LIGHT NEVER pairs with an automatic worktree. Failure or
uncertainty in any safeguard — including uncommitted overlap, a broad-mutating
command, an unprovable non-scope set, or any residual doubt — reclassifies the
run OUT of LIGHT to STANDARD BEFORE any further edit. Only after that
reclassification may Ralph re-record
`Worktree decision: direct automatic worktree` and create or select
`.oh-no/worktrees/<task-slug>` for further edits, with already-landed edits
listed in the final report.

Artifact handoff: a new worktree does not see the integration checkout's
untracked `.oh-no` plan/spec. Before editing, copy the artifact into the
worktree, record an absolute path, or quote the approved task definition.

Completion responsibility [E13]: after verification, review, and cleanup
pass, carry out the merge back into the
integration checkout and post-merge verification — or, when the user
requested a branch/PR handoff, report the branch name and path. On merge
failure report the blocker and leave the worktree intact. Remove the
worktree only after integration and post-merge verification complete.

## Execution Loop

Phase: EXECUTE. Per story:

1. Select the next incomplete story; apply its task-level mode.
2. Dispatch `explore` when files, tests, or integration surfaces are not
   obvious — independent targets as one parallel batch (up to 5). Apply the
   `## Scope Trace Gate` and record why the intended edits are in scope.
3. Record the story fields: expected outcome and ACs; owned files; contract
   surface (the actual public, caller, or verifier-facing entrypoint and any
   compatibility uncertainty that blocks editing); baseline guard (nearby
   existing checks that must still pass, or why none exists); TDD
   requirement or exception; verification command and acceptance-to-evidence
   mapping; the most likely story risk (for example contract-surface
   mismatch, semantic-lifecycle miss, hidden regression); diff-budget
   expectation; carve-out eligibility when claimed.
4. Classify the story's TDD requirement (behavior change, bug-fix
   reproduction, refactor characterization, or documented exception). If TDD
   applies, read and follow `test-driven-development` before editing
   production code; assign one stable `Executor assignment ID` across its
   RED/GREEN/REFACTOR writes on the dispatch path, while the main agent records
   the evidence [E4, E17].
5. Dispatch `executor` for repository work-product mutation per
   `## Mode-Gated Agent Dispatch`; the main agent mutates only its `.oh-no`
   state unless a permitted fallback is recorded. Honor any frozen `Parallel
   trigger`: `none` keeps execution sequential. When direct Ralph has no frozen
   trigger, scan remaining STANDARD/THOROUGH work for disjoint scopes and record
   `natural-dispatch` only when the isolation gates authorize one concurrent
   `executor` batch; apply the per-executor scope check before integrating.
6. Run the story-specific verification required by the mode and tier.
7. After each story, recheck the `Scope Trace Gate` and the cumulative
   Process Budget Gate against all work so far; reclassify a `provisional`
   carve-out here. Mark the story complete only when ACs, TDD evidence,
   scope trace, acceptance-to-evidence mapping, contract-surface evidence,
   baseline guard, and story risk-check evidence all pass or carry explicit
   residual risk. If this story changed behavior an earlier story depended
   on, re-verify that story — never leave a stale `passes: true` [E9].
8. On a failing check or unexpected behavior, read and follow
   `systematic-debugging` before attempting fixes. Ladder per root cause:
   one systematic-debugging pass plus one further fix, then `fusion-rescue`
   or record `blocked`/`failed_verification` with the evidence [E15].
9. After all stories, complete the CLEANUP and RECHECK checkpoints under
   `## Cleanup And Final Verification`, then run the `## Diff-Budget Gate`
   once for the current stabilized revision, before `## Review Gate`.

## Mode-Gated Agent Dispatch

Phase: EXECUTE and REVIEW. This section governs agent-role dispatch only;
workflow-skill chaining follows `## Final Handoff`.

Ralph's main agent is the orchestrator, not the default maker. It owns
`.oh-no` artifacts, packet issuance, result validation, gate interpretation,
and transitions. A role's `Result`, `Overall verdict`, or `Verification
verdict` is caller input; no enum advances the state machine by itself.

On subagent-capable hosts, STANDARD/THOROUGH repository work-product mutation
MUST dispatch `executor`, including REVIEW-to-EXECUTE focused fixes. This
executor-default trigger is sequential-capable and does not require a
parallel trigger. Inline mutation is permitted only with one recorded fallback:
`Mutation fallback: LIGHT-tiny — <reason>` for a tiny LIGHT edit, or
`Mutation fallback: dispatch-unavailable — <attempt and reason>` after the
host cannot dispatch. For every compliant revised-LIGHT run, dispatched
`executor` ownership is MANDATORY: the mutation goes to a dispatched `executor`
and the audit to a dispatched independent `verifier`; executor dispatch-
unavailability is FAIL-CLOSED and MUST PAUSE the run or reclassify it OUT of
LIGHT to STANDARD, never authorize inline completion; the unchanged
`LIGHT-tiny` inline path does NOT satisfy the revised-LIGHT path and remains a
narrow, separate escape valve for a trivial edit.

A run RECORDED in LIGHT mode under the widened
`### LIGHT Eligibility — Risk Gate, Soft Size Screen` tier MUST show
dispatched-`executor` evidence to reach completion. The `LIGHT-tiny` inline
fallback is a SEPARATE, narrower path for a tiny edit smaller than LIGHT
eligibility and is NOT a completion path for a widened-LIGHT-mode run. Executor
dispatch-unavailability in a LIGHT run PAUSES or reclassifies to STANDARD and
never authorizes inline completion WITHIN LIGHT.

The STANDARD small-task carve-out waives only reviewer
dispatch (see `### STANDARD Small-Task Carve-Out`).

For non-mutating roles, use targeted subagents on subagent-capable hosts when
the result can change the implementation, review, verification, or ship/block
decision; record unavailable, unsafe-to-isolate, or no-benefit inline reasons
without weakening the executor rule above. THOROUGH dispatches every
risk-warranted isolable role. In STANDARD and THOROUGH, proactively partition
disjoint implementation into parallel `executor` batches only when the recorded
trigger authorizes concurrency and ownership, dependency, TDD, and benefit gates
hold.

An approved plan authorizes its eligible isolated roles, not every role.
Record `Parallel trigger: approved-plan-handoff | explicit-user-request |
natural-dispatch | none` from the actual source. A frozen `none` remains `none`:
it means no concurrent batch and does not disable sequential executor ownership.
Keep every fallback role boundary visible and recorded.

## Parallel Subagent Policy

Dispatch conditions [E6]:

- allowed: disjoint executor write scopes; read-only agents on different
  subsystems; reviewers inspecting the same final diff without editing
- forbidden: overlapping writes to any file, schema, migration, generated
  artifact, lockfile, or shared config; dependent tasks; one behavior's TDD
  RED/GREEN order split across agents; unclear ownership; a verifier whose
  evidence depends on unresolved reviewer findings

Batch rule: create the whole eligible batch of independent same-depth work
before waiting on any result; never merge dependent review stages into one
batch. Cap a concurrent `executor` batch at up to 5 disjoint scopes; queue the remainder for the next batch. Continue local work only where it does not overlap delegated scopes.

Dispatch packet (the active adapter deciding whether the invocation is a
registered custom agent, a plugin-scoped agent, or a documented fallback):

```text
Packet ID: {unique dispatch id; mechanically distinct from run/session and story/task ids}
Run/session ID: {Ralph run id and main-owned .oh-no session id}
Story/task ID: {stable id and title; never reused as Packet ID}
Executor assignment ID: {stable across one executor assignment or TDD cycle; not applicable for non-executor roles}
Role: {explore|executor|verifier|code-reviewer}
Execution mode: {task-level mode and applicable policy}
Worktree decision and location: {recorded decision and absolute location}
Direction Contract source: {approved artifact path/section or direct request}
Direction Contract binding: {primary goal; applicable non-goals, constraints/protected assumptions, and direction-change approval rule}
AC IDs: {accepted criteria this role may affect or audit}
Plan/PRD path: {authoritative path or direct-task record}
Artifacts: {verification ledger and read-only inputs; .oh-no state stays main-owned}
Target revision/diff fingerprint: {revision plus stable fingerprint of the assigned target}
Scope: {owned files/directories, or read-only areas}
Do not touch: {other ownership, generated boundaries, and excluded paths}
Expected structured output: {exact role envelope, identity echo, and required evidence}
TDD responsibility: {RED/GREEN/REFACTOR step, persistent executor assignment, exception, or none}
Verification responsibility: {caller-owned, role-owned command/evidence, or none}
Platform invocation: {active adapter invocation syntax}
Lifecycle: caller waits for and captures the final result, validates its
identity/revision, integrates or records it, then applies host-specific cleanup
or closure only when the host exposes it; timeout or no-completion wait results
are not final results and never justify abandoning a running or pending subagent
merely because it is slow
Coordination: you are not alone in the codebase — do not revert, overwrite,
or reformat work outside your scope; report conflicts instead of resolving
them silently
```

For `executor`, `code-reviewer`, and `verifier`, a source pointer alone is an
incomplete Direction Contract packet: copy every applicable goal, non-goal,
constraint/protected assumption, and approval rule into the binding field so the
role can mechanically reject scope drift.

Result intake is caller-owned. Before a role output can gate anything, require
exact Packet ID, Run/session ID, Story/task ID, role, and target
revision/diff-fingerprint echoes; executor results also echo the stable
`Executor assignment ID`. Require the executor's result fingerprint or the
reviewer's/verifier's reviewed/verified revision to bind to the current target.
Reject stale or misrouted results, record the mismatch, and redispatch or
rebase the packet instead of interpreting the enum. A later mutation
invalidates intersecting reviewer/verifier results [E9], except that the
single post-review focused fix does not invalidate-and-redispatch review. The
review verdict remains bound to the reviewed revision as the round record,
and the verifier is the mandatory freshness owner for the fixed revision. All
other intersecting-evidence invalidation is unchanged.

Integration, sequential: inspect each accepted result and structured change
manifest; run the per-executor scope check (owned files only, slice satisfied,
no conflict — escalate only a stray or risky slice); resolve conflicts
deliberately; apply host-specific cleanup or closure after capture when exposed;
run story-specific then cross-story verification; only then mark stories complete. `Result:
implemented`, `Overall verdict: approve`, and `Verification verdict: pass`
are caller gate inputs, not story acceptance or autonomous transitions. Never
use missing output as completion evidence.

## Scope Trace Gate

Phase: EXECUTE — checked before editing and at every story recheck.

Every changed file and every meaningful changed line maps to at least one of:
the user's concrete request; an approved spec, plan, PRD story, or ticket; a
test, AC, or verification requirement; removal of code made unused by the
current change; behavior-preserving cleanup under the current behavior lock
[E5]. Do not improve adjacent code, reformat unrelated sections, add
speculative abstraction or configuration, or delete pre-existing dead code
out of scope — report such findings as residual risk or follow-ups.

## Validation Gate

Phase: EXECUTE and FINALIZE — when measurable evidence influenced the task,
record a validation check before completion. Apply the canonical
`Validation Check` defined in `verification-before-completion`; reject
completion claims supported only by metric movement — metric movement never
replaces the user, maintainer, operator, or public-contract outcome.

## Verification Budget Policy

Phase: EXECUTE — applied per story and cumulatively.

Tier minimums [E9]:

```text
LIGHT    = follow the dispatched `executor` -> dispatched independent
           `verifier` path in Mode-Gated Agent Dispatch and Review Gate, with
           the code-reviewer pair waived; inspect changed files; run the
           smallest relevant check; map the change to the inspection or
           command that proves it. Behavior-changing LIGHT still requires
           RED/GREEN per E4 and the eligibility gate's no-exception rule.
STANDARD = LIGHT + focused semantic tests mapped to ACs; RED/GREEN or a
           recorded exception; risk-activated negative/regression cases; a
           relevant baseline or smoke check.
THOROUGH = STANDARD + the integration, migration, smoke, end-to-end, or
           recovery evidence each named risk requires; record residual risk.
```

Budget rules:

- Prove each AC with focused evidence before broad suites; run a broad suite
  once after behavior stabilizes and rerun only for a patch-related reason;
  on a slow or flaky suite record the limitation and use a smaller semantic
  check.
- Lint, typecheck, compile, and formatting are support evidence, not
  behavior evidence.
- In STANDARD/THOROUGH, behavior-changing stories need a real-surface
  artifact (actual command output, terminal/UI capture, or response body);
  a printed or `--dry-run` command is indirect. Inspect every artifact for
  silent failure: a success status (exit 0, HTTP 2xx, a "done" log) without
  the observable effect is missing evidence, not a pass.
- Redact secrets and PII to labeled placeholders before writing any output
  into `.oh-no` files or the report, keeping only the non-sensitive evidence
  shape (status, lengths, hashes, short non-secret prefixes).
- Record skipped checks and residual risk honestly; never claim stronger
  coverage than the evidence supports. Map every acceptance criterion to
  direct, indirect, manual, or missing evidence (acceptance-to-evidence
  mapping) before the final claim.

## Process Budget Gate

Phase: EXECUTE (budget baselines are copied at PREPARE) — this is the
cumulative per-story mid-run early-stop check (the Diff-Budget Gate owns the
final pre-review evaluation). At PREPARE, copy the plan's expected
changed-file groups, diff size, review topology, cleanup depth, broad-suite
cap, and the one-round review budget — or derive conservative values.

Stop for rescope, simplify, or user approval when [E10]: the handwritten
diff exceeds twice the estimate; generated output hides unexpectedly broad
source changes; supporting test/validation lines grow to roughly three times
the product change (measure via `git diff --stat` at each story recheck); a
blocking review finding remains unresolved after the single post-review
executor fix and verifier audit; or the same invariant is being implemented a
third time. The ratio is a stop signal, not a license to delete required
negative, regression, or safety cases.

## Diff-Budget Gate

Phase: EXECUTE exit — after CLEANUP and RECHECK. Snapshot status is `pending |
passed@<fingerprint> | stale`. Run this final gate once for the current
stabilized revision, after all stories and cleanup, before `## Review Gate`,
then record `passed@<fingerprint>` [E10].
Any later material mutation marks the result `stale` and returns the gate to
`pending`; run it once for the newly stabilized revision before entering REVIEW
or, after REVIEW/FINALIZE mutation, before INTEGRATE and COMPLETION_AUDIT.
Thresholds decide whether that revision-bound evaluation expands into the
detailed scope review — not whether the gate runs:

- more than twice the expected handwritten file or diff estimate
- more than 20 changed files, or more than 500 insertions
- generated files mixed with handwritten logic
- public API changes across more than three subsystems
- multiple packages changed without explicit acceptance-to-evidence mapping

The expanded scope review answers: why this breadth is necessary for the
current ACs; which changed files are essential versus collateral; whether a
narrower patch would satisfy the request; and the maintainer's rollback
boundary. Unjustified breadth narrows the patch or records a blocker.

## Cleanup And Final Verification

Phase: EXECUTE exit — the CLEANUP and RECHECK checkpoints run at EXECUTE exit
[E12]; the FINALIZE checkpoints (INTEGRATE, COMPLETION_AUDIT) run after REVIEW
under `## Finalize Checkpoints`.

1. CLEANUP — after the behavior lock and BEFORE the single review round:
   LIGHT/STANDARD run a caller-owned quick diff scan and
   invoke `simplify` (one combined scan) only when actual candidates or
   candidate uncertainty remain; a clean scan records cleanup as not needed.
   THOROUGH expands to four independent viewpoints only for a named safety or
   broad-diff trigger. Never create cleanup work to satisfy a pass count.
   Cleanup is mutation-capable here through executor-applied accepted findings;
   after REVIEW it is read-only and any findings become residual risk or
   follow-ups.
2. RECHECK — when cleanup changed files, rerun relevant verification and
   confirm behavior, the behavior lock, and changed-file scope survived. The
   `## Diff-Budget Gate` then runs once for the stabilized post-cleanup
   revision, and the sole perspective-diverse pair inspects that final
   post-cleanup diff in REVIEW.

The post-cleanup perspective-pair inspection and the `single review round`
language apply ONLY when the selected review topology is `perspective-pair`.
A compliant LIGHT run, with the reviewer pair waived, proceeds directly from
CLEANUP/RECHECK to its REQUIRED independent verifier, with no reviewer stage.

## Review Gate

Phase: REVIEW. Completion requires evidence, not confidence.

Topology by mode [E8]:

```text
LIGHT    -> the code-reviewer pair is waived; the dispatched `executor`'s
            mutation goes straight to the required independent `verifier`.
STANDARD -> one perspective-diverse code-reviewer pair for behavior-affecting
            or workflow changes: Lens A = adversarial correctness + security
            skeptic; Lens B = maintainability + coverage completeness. Each
            instance runs the full role; packets are identical except the single `Assigned perspective:` line,
            dispatched in one parallel batch and caller-synthesized into one
            verdict. The compliant
            carve-out remains `not-required (STANDARD small carve-out:
            <reason>)`.
THOROUGH -> the same perspective-diverse pair; a named security, data,
            destructive, public-contract, release-critical, new-concurrency,
            migration, or broad multi-system trigger selects only the active
            platform's escalated diversity (cross-host on Codex). The active
            platform supplies the diversity leg. If that leg is unavailable,
            default mode uses two independent same-model instances and records
            the reason; an explicit caller demand for diversity is strict mode
            and transitions to PAUSED instead of falling back.
```

E8's `exactly one review round` MUST apply when the selected code-review
topology is `perspective-pair`; a compliant LIGHT run and the STANDARD
small-task carve-out record code-review `not-required` and run ZERO review
rounds, while their independent verifier remains REQUIRED.

For LIGHT, the code-review stage is waived, so proceed directly from the
dispatched executor's revision to the required independent verifier, with no
reviewer stage to complete first and no fix-manifest step.

Review-then-verify [E7]: run exactly one selected code-review stage first and
validate its caller-synthesized `Overall verdict`, blocking finding IDs, and
reviewed revision binding. With no blocking findings, start the required
independent self-host `verifier` pass (independence per E7) against
the reviewed revision. On `blocking-findings`, issue exactly one
executor-owned focused fix and record its manifest before the verifier starts;
the verifier packet includes the reviewer findings, fix manifest, and the
obligation to audit every blocking finding ID against the fixed revision.
Reviewer approval of the fixed revision is NOT required and MUST NOT be requested.
Validate the verifier's `Verification verdict`, verified revision binding, and
per-finding audit before using it.

Completion requires either reviewer verdict `approve` (or compliant
`not-required`) and verifier `pass` / accepted `pass-with-residual-risk` bound
to the reviewed revision, or reviewer verdict `blocking-findings` with a fix
manifest mapping every accepted blocking finding ID, and the verifier pass (or accepted pass-with-residual-risk) binds to the FIXED revision with a per-finding resolution audit.
`pass-with-residual-risk` also requires the caller to record why the named risk
is non-blocking and every AC remains satisfied. A compliant LIGHT path records
code-reviewer topology `not-required (LIGHT: reviewer pair waived)`; the
dispatched verifier's `pass` (or accepted
`pass-with-residual-risk`) binds to the `reviewed` revision and follows the same
reviewed-revision completion path as a compliant STANDARD small-task carve-out;
the verifier is NEVER waived in LIGHT. Verifier `fail`, an
unresolved blocking finding after the one fix and audit returns to the
budgeted `systematic-debugging` or `failed_verification` path; either role's
`blocked` verdict pauses. These enums are caller
inputs under E17, never autonomous transitions.

The verifier audit is required at STANDARD/THOROUGH when the proving tests or
implementation were authored or accepted by the same agent. A compliant LIGHT
run also requires that independent verifier audit; `dispatch-unavailable` for
it is a LIGHT blocker (transition to PAUSED) exactly as for STANDARD/THOROUGH.
It MUST run in a separate context. If no separate context is available, record `Independent
verifier: dispatch-unavailable` as a blocker and transition to PAUSED. Inline
command reruns may still strengthen caller-owned evidence, but they cannot
count as the required independent audit. When the audit is optional or not
required, record that reason without turning dispatch unavailability into a
pass.

Record the Review Gate dependency graph in the ledger:

```text
Review Gate dependency graph:
- code-reviewer topology: not-required | perspective-pair
- code-reviewer pass: pending | complete | blocked | not-required
- blocking reviewer findings: none | fix-applied (manifest mapped) | blocking
- verifier bound revision: reviewed | fixed | not-required
- verifier eligible to start: yes | no
- verifier started after reviewer completion: yes | no | not-required
- early verifier discarded and rerun: yes | no | not-applicable
```

`verifier eligible to start` is `yes` only after the selected code-review
output and pair synthesis are captured and either findings are none / review is
compliantly not-required, or the single fix manifest is recorded. A verifier
spawned before that point is stale evidence: record it as discarded and rerun
it after the dependency is satisfied. When both roles are required, the ledger
must show `verifier started after reviewer completion: yes` or the verifier
pass does not count.

Review focus — the reviewer pass must check:

- every story satisfies its ACs with mapped (not merely listed) evidence
- the contract surface, semantic model, and baseline guard were identified
  before accepting local green results
- a simpler or safer approach; scope trace and speculative-complexity
  rejection
- RED/GREEN or documented exceptions for behavior changes
- the security lens when auth, data, secrets, filesystem, network, config,
  or destructive operations were touched
- the applicable negative-path scenarios — malformed or boundary input,
  stale state, cancel/resume or concurrency — probed when their triggers
  hold, or each ruled out with a one-line reason that names why no approved
  AC ID, named risk, adjacent regression surface, safety invariant, or
  directly changed semantic model triggers it

Reviewer findings outside the Scope Trace Gate are residual risk or
follow-ups, not fixes in this run; a regression caused by the current change
always maps to approved scope and may block. For accepted blocking finding
IDs, the main agent issues exactly one focused `executor` assignment and
records a manifest mapped to every accepted finding ID; the reviewer never
applies the fix or advances the FSM, and is never re-dispatched. Budget
[E8]: exactly one review round; after the executor-owned fix the verifier audit
of the fixed revision is the recheck. A blocker remaining after that budget
goes to `systematic-debugging`, `blocked`, or `failed_verification`.

## Finalize Checkpoints

Phase: FINALIZE — the remaining checkpoints run in order, after REVIEW:

3. INTEGRATE — carry out the worktree completion responsibility [E13]: merge
   back into the integration checkout and run post-merge verification, or
   report the branch/PR handoff.
4. COMPLETION_AUDIT — read and follow `verification-before-completion` before
   any completion claim, then write the final report.

## Resume Protocol

Phase: any, on re-entry.

On re-entry after interruption or compaction, reconstruct from artifacts
[E14]: re-read the input artifact, snapshot, and session files; recompute
incomplete stories from recorded `status`/`passes`; re-confirm the mode and
`Worktree decision` before further edits. Reconcile every `pending` Active
dispatch entry through its recorded host handle before redispatching overlapping
scope: capture a final result, keep it pending, or mark it `abandoned` only for
an explicit cancel, invalidation, duplicate, or safety reason. Never redispatch
overlapping work while the prior entry remains pending. Treat the story in
flight as unverified and re-run its verification; if the worktree diverged from
recorded work, re-verify completed stories whose acceptance depended on the
changed files; resume the loop at the first incomplete story.

## Persistence Rule

Phase: FINALIZE — COMPLETION_AUDIT checkpoint.

<HARD-GATE>
The run is invalid if the session does not show each required completion criterion below satisfied [E11] — including, named individually,
the required reviewer pass, the independent verifier pass, simplify, and verification-before-completion
(or an explicit missing-evidence blocker / not-required reason recorded for
each). A silently omitted step is a named ledger gap, not a pass.

- Evidence status lives in `verification.md`; PRD/progress point to its AC IDs.
- Every review records its topology using the dependency-graph values
  (`not-required` with the compliant reason, or `perspective-pair` with the
  active platform's pair-mode value); an inline fallback requires a reason.
  Missing review topology is a named ledger gap.
- When both code-reviewer and verifier are required, the ledger must show
  `verifier started after reviewer completion: yes` or the verifier pass is
  stale and does not count.
- On the fix path, the verifier pass is bound to the fixed revision with a
  per-finding resolution audit; the fix manifest maps every accepted blocking
  finding ID.
</HARD-GATE>

Completion criteria:

- selected execution mode recorded and followed; every story `passes: true`
- a run recorded in LIGHT mode shows dispatched-executor evidence (the
  LIGHT-tiny inline fallback does not satisfy widened-LIGHT completion)
- Diff-Budget is `passed@<current stabilized fingerprint>` for the delivered diff
- `verification.md` has one row per AC ID with planned/actual evidence,
  freshness, and audit status
- required TDD evidence exists, or each exception is documented
- the mode-required review is recorded complete in the `## Review Gate`
  dependency graph — approved or compliantly not-required, or blocking findings
  with one accepted fix manifest mapped to every finding ID per that section
- the independent verifier pass ran per the review-then-verify order and bound
  to the reviewed revision or, on the fix path, the FIXED revision with a
  per-finding resolution audit; otherwise a compliant not-required reason is
  recorded; `dispatch-unavailable` is a blocker
  and cannot satisfy completion
- the proportional `simplify` scan ran, was disabled, or recorded no
  candidates; post-cleanup verification passed when cleanup changed files
- the direct-Ralph automatic worktree was merged back with post-merge
  verification, or its branch/PR handoff was reported, or none existed per
  the recorded `Worktree decision`
- `verification-before-completion` ran for the final claim; story risk
  checks and the final risk check completed or a missing-evidence blocker is
  recorded
- the final report was written

A LIGHT run with no behavior change may compact the four named criteria into
one combined ledger line when each part is actually true; a STANDARD
small-carveout run may compact the review and simplify entries while the
verifier and verification-before-completion entries stay individual. When
the criteria pass and only optional follow-ups remain, record residual risk
and stop instead of continuing the loop.

## Output

Return: session directory and PRD path; execution profile (mode/source,
tier, policies, `Parallel trigger`, `Worktree decision and location`,
integration status); delivery (stories, files, cleanup); verification
(commands/results, AC mapping, contract/baseline, risk/completion,
validation check, diff budget); residual risk.

Review-phase attribution: when 2+ stages ran, include exactly
`Review phases: plan=<n>; implementation-code=<n>; independent-verifier=<n>`;
when fewer than two ran, use ordinary labeled prose and omit that count line.

Process budget outcome: planned versus actual tests/TDD cycles, role
dispatch count and reasons, broad-suite count, and rescope events.

## Final Handoff

Ralph is the terminal workflow skill [E15]. After the final report, do NOT
auto-invoke another workflow skill; further work needs a fresh user request.
Mid-loop skills used inside the loop are Ralph's documented procedure and
are not subject to a per-step transition question — the user opted in by
invoking Ralph.

## Agent Roles

| Agent | Use |
|---|---|
| `explore` | find relevant files, tests, commands, and integration surfaces; independent read-only targets as one parallel batch (up to 5) |
| `executor` | implement scoped story work with an explicit ownership boundary |
| `verifier` | independently map evidence to ACs and audit test genuineness; one self-host pass after review, never the maker |
| `code-reviewer` | review correctness, maintainability, regressions, scope trace, and overcomplication; applies the security lens when triggered |

`simplify`, `verification-before-completion`, `test-driven-development`, and
`systematic-debugging` are skills, not agents. Whether a role is inline or
dispatched is decided by `## Mode-Gated Agent Dispatch`.

## Source: docs/platforms/codex-ralph.md

# Codex Ralph Adapter

CODEX_ONLY_RALPH_ADAPTER

<ADAPTER_CONTRACT>
This adapter binds the Ralph core to Codex. The core owns every semantic
decision; this file owns only host invocation and lifecycle mechanics. If
they conflict, the core wins. The generated core plus this adapter is
sufficient: longer platform, shared, and agent documents are optional
maintenance context, never a runtime prerequisite. Do not apply it on Claude
Code or other platforms.
</ADAPTER_CONTRACT>

## Dispatch Decision

Ralph is parallel-capable on Codex when the host exposes `spawn_agent`.
Dispatch is trigger-loaded — dispatch only after the active skill's trigger
fires, within host policy and the core's isolation rules.

Sufficient dispatch signals: an approved `ralplan` handoff preserving
`Parallel trigger: approved-plan-handoff` (no separate subagent wording
needed); an explicit user phrase (`subagent`, `spawn`, `delegate`,
`parallel agents`, `one agent per`); or a standing user/plan preference to
maximize subagents — which authorizes eligible isolated roles for the whole
run, including read-heavy exploration, test/log analysis, verification,
review, and disjoint implementation (executor) work in STANDARD/THOROUGH
when write scopes are non-overlapping, but never roles whose output would
not change a decision. When no non-mutating dispatch-worthy role exists, it
may run inline under the core's role fallback rules; host denial must be
recorded. Record `Parallel trigger: none` when no concurrent batch is
admitted. Record `Parallel trigger: natural-dispatch` only when the host
permits proactive dispatch and the active skill policy authorizes it.

## Executor-Default Trigger

When the core records STANDARD/THOROUGH repository work-product mutation,
call `spawn_agent` for `oh-no-executor` even when `Parallel trigger: none`;
that trigger controls concurrency, not sequential executor ownership. The
same rule applies to REVIEW-to-EXECUTE focused fixes. Inline mutation is valid
only for the core's recorded LIGHT-tiny or dispatch-unavailable fallback, and
unavailability requires the failed named-agent attempt or equivalent current
host rejection described below.

## Invocation

Codex SessionStart is the sole automatic custom-agent preparation path: it
runs `scripts/install-codex-agents --scope user --ensure --quiet`. Installed
files carry the plugin version marker and pin role models. When a named
`oh-no-*` agent type is not recognized, resolve and run the installed installer,
then retry:

```bash
tab="$(printf '\t')"
cache="${CODEX_HOME:-$HOME/.codex}/plugins/cache"
# Codex exposes no skill-visible plugin root, so cache-newest is the only reachable
# path. Sort on the VERSION path component (full path only as tie-break) so a second
# marketplace identity cannot let an older version win.
script="$(find "$cache" -path '*/oh-no-harness/*/scripts/install-codex-agents' 2>/dev/null \
  | awk -F/ '{for(i=NF;i>0;i--) if($i=="scripts"){print $(i-1)"\t"$0; break}}' \
  | LC_ALL=C sort -t"$tab" -k1,1V -k2,2 | tail -n1 | cut -f2-)"
"$script" --scope user --ensure
```

Use generic prompt-embedded dispatch only after confirmed custom-agent
unavailability, and record the fallback reason.

Dispatch order:

- `oh-no-<role>` when the host recognizes that `agent_type`. This is
  required for Oh No Harness role dispatch, not just preferred.
- `explorer` for read-heavy exploration, `worker` for scoped implementation
  with a disjoint write set, `default` for specialized review/QA/security —
  ONLY when the host rejects `oh-no-<role>` as unknown or unavailable, or
  the work is not an Oh No Harness role. Record the fallback reason.

Do not claim custom agents are unavailable without a failed
`spawn_agent(agent_type="oh-no-<role>", ...)` attempt or an equivalent
current host rejection; do not infer unavailability from rendered schema
text, display comments, or missing shown parameters.

Spawn with `fork_turns="none"` — omitting `fork_turns` defaults to a
full-history fork, and forked agents inherit the parent agent type, so the
custom `agent_type` is rejected. Do not use `fork_context` (unsupported) or
any full-history fork with `agent_type = "oh-no-<role>"`. Send the relevant
plan, scope, ownership, and evidence context in the spawn message, one
payload shape only (prompt/message or items, never both). The generated
`oh-no-explore`, `oh-no-verifier`, and `oh-no-code-reviewer` templates set
`sandbox_mode = "read-only"`; other Ralph role templates inherit the host
sandbox and stay scoped by the core dispatch packet.

Spawn every independent agent in the eligible batch before calling
`wait_agent`.

## Lifecycle

After `wait_agent` returns a final status, capture the result and inspect
any changed-file set. A timeout, empty wait result, or "No agents completed
yet" is not a final status. Hard rule: MUST NOT call `close_agent` for a
running or pending Ralph subagent after timeout, no-completion, or empty
wait output — leave it running, wait longer when its result is needed,
continue non-overlapping work, or record the role as pending or blocked.
Close without a captured final result only on explicit user cancel, scope
invalidation, duplicate/mis-scoped spawn, or a safety/security/filesystem
risk; record that close as cancelled or abandoned and never use missing
output as completion evidence. When no more input is needed for a completed
subagent and the host exposes `close_agent`, call it; if it reports already
closed or unavailable, record that instead of retrying. If the host exposes
no explicit close, record that closure is host-managed or unavailable.

## Role Prompt Embedding

Codex display names are not stable role identifiers; registered custom-agent
names and the dispatch message are the source of truth. For a registered
`oh-no-<role>` agent, the TOML `developer_instructions` already supplies the
role prompt — keep the task prompt focused on the core dispatch packet plus:

```text
Codex agent type: oh-no-<role>   # or <explorer|worker|default> fallback
```

For a generic fallback, add the embedded role prompt:

```text
Agent prompt source: docs/agent-core/<role>.md
Agent prompt content:
<matching docs/agent-core/<role>.md prompt content>
```

The embedded or registered prompt must preserve the role's Skill
Relationship, Responsibilities, Operating Rules, and Output sections. If
`docs/agent-core/<role>.md` is unavailable but `agents/<role>.md` exists,
strip the Claude Code YAML frontmatter before embedding — Claude-only
frontmatter (`tools`, `model`, `background`, `isolation`, `color`) must not
enter Codex prompt content. For `worker` tasks give each agent an explicit
ownership boundary; read-only reviewers must not edit files.

## Cross-Host Consult Channel

A fired named THOROUGH review trigger on Codex starts one Codex `code-reviewer`
and one transport-owner reviewer making exactly one foreground Claude call.
The two review legs receive redacted packets identical except the single `Assigned perspective:` line.
A launch notice, background acknowledgement, or empty output is unavailable
evidence; on opposite-host unavailability run `same-host-parallel-fallback` and
record the required fallback reason.

## Re-Homed Core Pair Rules

```text
STANDARD -> one perspective-diverse code-reviewer pair when review is required,
            recorded as same-host-perspective-pair; this is intentional
            same-host review, so no fallback reason is required.
THOROUGH -> the same perspective-diverse pair. A named security, data,
            destructive, public-contract, release-critical, new-concurrency,
            migration, or broad multi-system risk selects cross-host review when
            available, or same-host-parallel-fallback when the opposite host is
            unavailable; record the fallback reason.
```

Both the STANDARD and THOROUGH pairs follow the same packet rule stated in the
Cross-Host Consult Channel: the two legs differ only by their `Assigned
perspective:` line.

- Every review records its topology using the dependency-graph values
  (`not-required` with the compliant reason, or `perspective-pair` with its
  independence mode); an inline fallback requires a reason. Missing review
  topology is a named ledger gap.

## Cleanup

When Ralph reaches the CLEANUP checkpoint on Codex, use the Oh No Harness
`simplify` skill through the generated Codex Simplify runtime document.
