---
name: ralph
description: Use when an approved plan, PRD, spec, ticket, or concrete add/fix/refactor/implement request supplies a usable acceptance contract; explicit test-first intent uses test-driven-development, while unknown root-cause investigation uses systematic-debugging.
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Ralph for OpenCode

This generated file is the OpenCode-facing runtime skill document. OpenCode should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/ralph.md`
- `../../docs/platforms/opencode-ralph.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/ralph.md

# Ralph

Ralph is a mode-gated execution loop: it works until acceptance criteria are
satisfied with fresh evidence, required review and cleanup gates are handled,
and the final report is written. Ralph's main agent is the orchestrator: it
owns `.oh-no` state, gate decisions, result intake, and FSM transitions while
executor roles own default repository work-product mutation. Ralph owns
execution mode selection or enforcement for
ordinary implementation. Do not route concrete add/fix/refactor/implement
requests directly to `test-driven-development`; Ralph invokes TDD internally
when behavior-changing edits require it.

Do not use when requirements are still vague — use `interview` or `ralplan`
first. Entering directly from `interview`, accept the path only if the spec's
provisional Ralph mode is `LIGHT`; a non-LIGHT spec without a `ralplan` plan
needs user re-confirmation before editing.

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
E7. Review-then-verify: when a verifier trigger fires, the selected code-review
    stage completes before the single independent self-host verifier starts; on
    blocking findings, the verifier starts only after the single fix manifest is
    recorded. The verifier is never the maker and never a pair. The canonical
    `### Independent Verifier Trigger Predicate` alone selects it; mode, size,
    same authorship, reviewer presence, and imminent completion are non-triggers.
E8. Review topology is risk-gated with a one-round budget: exactly one review
    round. STANDARD and ordinary THOROUGH dispatch ONE full-role code-reviewer;
    only a named high-risk or diversity trigger selects the perspective-diverse
    pair. Accepted blocking findings get one executor-owned focused fix; the
    triggered independent verifier then audits the fixed revision as the safety
    net. A blocker unresolved after that goes to rescope or user direction.
E9. Mutation invalidates intersecting evidence except that the review verdict
    remains bound to its reviewed revision after the single post-review fix;
    the verifier owns freshness by binding to the mutated revision, and the
    caller owns it when no verifier trigger fires. Fresh revision-bound
    reviewer, verifier, and command evidence is REUSED as-is: imminent
    completion alone never justifies a rerun, a new test, or a fresh dispatch. A
    success status without the observable effect is missing evidence. Redact
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
     FSM transitions. Repository work-product mutation, including
     REVIEW-to-EXECUTE focused fixes, dispatches `executor` by default; inline
     mutation is only a recorded LIGHT-tiny or dispatch-unavailable fallback.
     A fired review or audit trigger is exempt and never runs inline.
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
- Review: <topology>; <pair trigger or not-applicable>; <verdict>; verifier <trigger or not-required>; verifier-after-reviewer <yes|no|not-required>
- Expansion: none | requested | approved@<revision id> | rejected; approval owner <none|caller-ralph|user|ralplan>; manifest revision <id|none>; packet reissued <yes|no|not-applicable>
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
| REVIEW | reviewer verdict approve (or compliant not-required) and either no verifier trigger fired (compliant not-required) or verifier pass / accepted pass-with-residual-risk bound to the reviewed revision [E7, E8, E17] | FINALIZE |
| REVIEW | reviewer verdict blocking-findings [E8, E17] | EXECUTE-fix (exactly one executor-owned focused fix; no reviewer re-dispatch) |
| REVIEW | fix manifest maps every accepted blocking finding ID; verifier pass (or accepted pass-with-residual-risk) binds to the FIXED revision with a per-finding resolution audit [E7, E8, E9, E17] | FINALIZE |
| REVIEW | verifier fail, or a blocking finding remains unresolved after the one fix + verifier audit, or reviewer or verifier verdict is `blocked` [E8, E10] | PAUSED / `systematic-debugging` / `failed_verification` per budget |
| REVIEW | a TRIGGERED independent verifier has no separate context (`dispatch-unavailable`) [E7, E11] | outcome PAUSED |
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

Artifact scope — pointer, not restatement. `progress.md` is a resume index: it
references the plan's Mutation Manifest, budget baselines, and this skill's
completion criteria by path, AC ID, revision id, and status instead of
restating them as prose. `verification.md` owns AC-to-evidence, RED/GREEN,
test necessity, and the baseline gate table; the plan's test-design decisions
are referenced by AC ID, never re-derived. Never copy subagent output verbatim
into an artifact — record the finding and its evidence pointer. Artifact
length is calibrated to resume and audit need, not to mode; do not restate a
decision that already has a canonical home. The session file set is closed to
the files named above — no improvised session file, directory, patch, or
backup; scratch and diagnostic output belongs outside `.oh-no` (e.g. `/tmp`).

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
           compact artifacts; dispatched `executor`, then a verifier only when
           `## Review Gate`'s predicate fires; `## Review Gate` owns
           code-review topology.
STANDARD = localized behavior/config/prompt work with bounded blast radius
           and known ownership; session + verification artifacts; ONE
           full-role code-reviewer reviews behavior-affecting changes.
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
to STANDARD or THOROUGH.

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
trigger-gated independent verifier, and verification-before-completion are
unchanged. The
step-recheck reclassifies it against the actual diff: any unexpected file or
surface, bound breach, proof-path failure, test-infrastructure addition, or
new semantic uncertainty invalidates it — record
`Review topology: single-reviewer` and run the ordinary STANDARD full-role
code-reviewer. A record still `provisional` at
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
applies — Ralph derives and owns the decision. The carve-out requires an actual
Git checkout: a plain non-Git directory cannot establish clean-status or
non-scope safeguards and records `Worktree decision: blocked` unless the user
explicitly authorizes current-directory mutation. These safeguards matter more
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
   obvious — one `explore` when one covers the question, scaling to genuinely
   independent targets as one parallel batch (up to 5); never split a small
   bounded lookup into multiple dispatches. Apply the
   `## Mutation Manifest and Expansion Gate` before assigning edits.
3. Issue one bounded executor assignment: one bounded task and the minimal
   inseparable AC-ID set. Do not split one behavior's RED/GREEN cycle or a
   source/generated pair merely to reduce apparent size. The main caller builds
   the child's self-contained English packet and adds only Ralph's assignment
   delta; role prompts do not reconstruct omitted caller context.
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
7. After each story, compare actual changes with the Mutation Manifest and
   recheck the cumulative Process Budget Gate; reclassify a `provisional`
   carve-out here. Mark the story complete only when ACs, TDD evidence,
   manifest adherence, the Verification Contract, admitted test-necessity
   decisions, contract-surface evidence, baseline guard, and story risk-check
   evidence all pass or carry explicit residual risk. If this story changed
   behavior an earlier story depended
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

One need test governs every non-review role in every mode, repository
work-product mutation included: dispatch when the work is sizeable, genuinely
independent, or parallelizable, and run inline when a bounded lookup or edit
finishes in a handful of tool calls. `executor` is the DEFAULT owner of
repository work-product mutation, including REVIEW-to-EXECUTE focused fixes;
this executor-default trigger is sequential-capable and does not require a
parallel trigger. Mode never decides the need test by itself: a large or
sprawling LIGHT edit set dispatches, and a genuinely tiny STANDARD/THOROUGH
edit may run inline. Inline mutation records one fallback reason:
`Mutation fallback: LIGHT-tiny — <reason>` when the edit is too small to
benefit from context separation, or
`Mutation fallback: dispatch-unavailable — <attempt and reason>` after the
host cannot dispatch. An unrecorded inline mutation is non-compliant in every
mode. Escalate to a dispatched `executor` the moment an inline edit stops being
tiny — a growing edit set, a surfacing exclusion, or any residual doubt.

Inline mutation changes WHO edits, never WHAT the edit owes. The `executor`
contract in `docs/agent-core/executor.md` applies UNCHANGED to an inline edit:
compare every actual mutation against the Mutation Manifest, follow the recorded
`Worktree decision`, admit each new or changed test only through the Test
Necessity Gate, produce TDD evidence or a recorded exception, treat `.oh-no`
paths as read-only inputs, and touch nothing outside the assigned scope. Only
the packet-shaped fields fold inward: with no child to address, `Packet ID` and
`Executor assignment ID` are `not supplied — inline`, and the caller-facing
report becomes the caller's own recorded evidence — the change manifest, scope
trace, and verification results are recorded in full either way. After the edit,
confirm it with a diff scoped to the intended paths. Leaving the Mutation
Manifest ENDS inline eligibility rather than raising an `Expansion request` to a
nonexistent child: reclassify to a dispatched `executor` BEFORE any further
edit, and carry the already-landed edits into that assignment. An inline edit
that skips this contract is non-compliant even with its fallback reason
recorded, because a smaller edit never buys a weaker contract.

Review independence is the one exemption from the need test. When the Review
Gate predicate or another named trigger fires for `code-reviewer`,
`plan-reviewer`, or the independent `verifier`, that role ALWAYS runs in a
separate context and NEVER inline, because its value is independence rather
than throughput. Size, convenience, and time pressure never collapse a fired
review or audit trigger; only confirmed dispatch-unavailability does, and it is
FAIL-CLOSED — record the blocker and PAUSE rather than substitute an inline
pass.

The STANDARD small-task carve-out waives only reviewer
dispatch (see `### STANDARD Small-Task Carve-Out`).

For non-mutating roles the same need test applies: use targeted subagents on
subagent-capable hosts when the result can change the implementation, review,
verification, or ship/block decision; record unavailable, unsafe-to-isolate, or
no-benefit inline reasons without weakening review independence above. THOROUGH
dispatches every risk-warranted isolable role. In STANDARD and THOROUGH,
proactively partition
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
batch. Dispatch a single agent when one covers the work, and scale out only
across genuinely independent targets; a small bounded lookup is never split
into multiple dispatches. Cap a concurrent `executor` batch at up to 5 disjoint
scopes; queue the remainder for the next batch. Continue local work only where
it does not overlap delegated scopes.

The main caller owns each complete child packet. Apply the common caller floor
from SessionStart when enabled or the native platform wrapper fallback, use
English instruction prose, and add only the Ralph delta below; do not rely on
role prompts or conversation history to fill omissions.
A same-child follow-up must explicitly restate every changed target,
authorization, scope, or obligation. The active adapter deciding whether the
invocation is a registered custom agent, a plugin-scoped agent, or a documented
fallback remains unchanged.

For an initial `code-reviewer` packet, provide the exact contract and diff but
withhold maker conclusions, expected verdicts, and sibling outputs. For an
initial `verifier` packet, require an independent evidence design from the ACs,
target, and raw evidence before a later audit phase discloses accepted review
findings or a fix manifest. Those findings and manifests are audit obligations,
not proof, and never replace the verifier's independent evidence.

Add this Ralph-specific assignment delta:

```text
Packet ID: {unique dispatch id; distinct from run/session and story/task ids}
Run/session ID: {Ralph run id and main-owned .oh-no session id}
Story/task ID: {stable id and title; never reused as Packet ID}
Executor assignment ID: {stable across one executor assignment or TDD cycle; not applicable for non-executor roles}
Role: {explore|executor|verifier|code-reviewer}
Execution mode: {task-level mode, verification tier, artifact policy, and agent policy}
Worktree decision and location: {recorded decision and absolute location}
Direction Contract source and binding: {approved source plus applicable AC/non-goal/safety constraints}
AC IDs: {accepted criteria this role may affect or audit}
Plan/PRD and read-only artifact pointers: {authoritative inputs; .oh-no state stays main-owned}
TDD responsibility: {RED/GREEN/REFACTOR step, stable assignment, exception, or none}
Mutation Manifest: {every authorized path with change kind, semantic obligation, AC/safety basis, and causal generated outputs}
Verification Contract: {per-AC evidence surface, focused RED behavior/command and expected old failure, GREEN observation, baseline guard, freshness owner}
Test Necessity Decisions: {admitted new/changed tests with AC or independent failure mode, why existing evidence is insufficient, smallest distinguishing assertion, nearest existing suite — or none}
Assignment completion contract: {exact conditions that satisfy this bounded assignment and the Executor Assignment Completion Stop}
Expansion authority: none-beyond-manifest | approved@<revision id>; {generated outputs caused by listed source edits are pre-authorized}
Expansion status: none | requested | approved@<revision id> -> incorporated before mutation | rejected
Platform invocation: {active adapter invocation syntax}
Lifecycle: caller waits for and captures the final result, validates identity
  and revision, then applies host-specific cleanup only when exposed
Coordination: {ownership/conflict boundary and no-overwrite rule}
Assigned review perspective: {when applicable; otherwise not applicable with reason}
```

Delta fields are role-scoped. `Executor assignment ID`, `TDD
responsibility`, `Mutation Manifest`, `Verification Contract`, `Test Necessity
Decisions`, `Assignment completion contract`, `Expansion authority`, and
`Expansion status` bind the executor lane, and `Platform invocation`,
`Lifecycle`, and `Coordination` are caller-side dispatch mechanics: send each
as `not applicable` with a one-clause reason in a `code-reviewer` packet. A
`verifier` packet keeps `TDD responsibility` populated for behavior-changing
work, because the verifier audits RED/GREEN evidence. `Worktree decision and
location` is always populated for both: it is the only field carrying the
target tree, and review and verification run from inside it.

Result intake remains caller-owned. Require exact identity and revision echoes,
including the stable `Executor assignment ID` for executor results, before a role
output can gate anything. Reject stale or misrouted results rather than
interpreting their enums. A later intersecting mutation invalidates review or
verification evidence [E9], except that the single post-review focused fix keeps
the review verdict as the reviewed-revision round record and makes the verifier
the freshness owner for the fixed revision.

Integration, sequential: inspect each accepted result and structured change
manifest; run the per-executor scope check (owned files only, slice satisfied,
no conflict — escalate only a stray or risky slice); resolve conflicts
deliberately; apply host-specific cleanup or closure after capture when exposed;
run story-specific then cross-story verification; only then mark stories complete. `Result:
implemented`, `Overall verdict: approve`, and `Verification verdict: pass`
are caller gate inputs, not story acceptance or autonomous transitions. Never
use missing output as completion evidence.

## Mutation Manifest and Expansion Gate

Phase: EXECUTE — checked before editing and at every story recheck.

The Mutation Manifest lists every planned path with its change kind, concise
semantic obligation, AC or safety basis, and causal generated outputs. Compare
actual changed paths and meaningful changed lines with that manifest. Existing
scope discipline remains binding: do not improve adjacent code, reformat
unrelated sections, add speculative abstraction or configuration, or delete
pre-existing dead code outside the approved cleanup boundary.

When required work is outside the manifest, Ralph stops before editing and
returns an `Expansion request` to the caller with:

```text
Expansion request:
- trigger and discovery
- why the current manifest cannot complete the assignment
- smallest proposed paths and change kinds
- mapped AC or change-introduced independent failure mode
- generated-output impact
- affected packet fields
- mutation performed before stop
- requested-direction-change: yes | no
```

Record `Expansion: none | requested | approved@<revision id> | rejected` in the
snapshot together with its named approval owner
(`caller-ralph | user | ralplan`), the bound manifest revision id, and whether
the packet was reissued; persist all four at every change [E14]. An expansion
whose approval owner is unrecorded is unapproved.

Approval owner and routing. Ralph may approve, as the caller, only a
behavior-preserving expansion inside the approved direction — for example
caller-owned test-assertion maintenance or a causal generated output.
Ralph MUST pause and return to the user, or to `ralplan` for a plan-level
change, BEFORE any
mutation when the expansion touches direction or architecture; a public,
external, or CLI contract; a dependency, pin, or lockfile; a shared schema or
migration; security, permissions, or secrets; a destructive or
recovery-sensitive surface; concurrency or lifecycle semantics; or delivery
scope. That list is illustrative, not exhaustive: ANY named or approved risk
whose resolution needs authority beyond the caller — including a risk class not
listed above — routes through the same pause/return rather than caller
self-approval. When ownership is unclear, fail closed to the user.
`requested-direction-change: yes` is always user-owned [E1].

Revised-manifest binding. An approved expansion is not authorization until the
revised Mutation Manifest carries a new revision id, that id is recorded in the
snapshot, and the affected packet fields are reissued to the executor with
`Expansion status: approved@<revision id> -> incorporated before mutation`.
Mutation under a superseded manifest revision is out-of-scope work.

State transitions. An `Expansion request` returns EXECUTE to the pre-edit stop:
a Ralph-approvable expansion re-enters EXECUTE under the new manifest revision;
a user- or plan-owned expansion transitions to outcome PAUSED (or
RETURN_TO_PLAN when the plan or an AC is wrong as written) and never proceeds on
an assumed approval.

Do not infer authorization from file, line, process, dispatch, or test counts.
Unapproved expansion remains blocked; unrelated findings are residual risk or
follow-ups.

## Validation Gate

Phase: EXECUTE and FINALIZE — when measurable evidence influenced the task,
record a validation check before completion. Apply the canonical
`Validation Check` defined in `verification-before-completion`; reject
completion claims supported only by metric movement — metric movement never
replaces the user, maintainer, operator, or public-contract outcome.

## Verification Contract and Test Necessity Gate

Phase: EXECUTE — applied per bounded assignment and cumulatively.

For each assigned AC, record the real public, caller, or verifier-facing
evidence surface; the focused RED behavior/command and expected old failure;
the GREEN behavior/command and required observation; the relevant baseline
guard; and the freshness owner. Map every new or changed test to an assigned AC
ID or change-introduced independent failure mode and record why existing
evidence is insufficient, the smallest distinguishing assertion, and the
nearest existing suite.

A `change-introduced independent failure mode` is admissible only when the
current change causes it and it is observably distinct from every
already-admitted case rather than another input combination of one; branches,
input classes, and error results within a single semantic outcome share one
mode.

Reject duplicate variants, tests of behavior the change does not touch,
implementation-detail-only assertions, defensive combination explosion, and
unapproved helper/framework/fixture expansion; a new durable test harness,
production test seam, or product-like simulator, oracle, or fixture factory
needs separate user approval for that scope. After focused RED→GREEN and the
mapped baseline pass, stop adding tests except a tier-required or
Review-Gate-required case whose risk is named later and admitted through the
same necessity mapping. Numeric size, ratio, dispatch, and test
counts are anomaly signals and rescope prompts only; they do not authorize work,
prove necessity, or create a hard test budget.

Tier minimums [E9]:

```text
LIGHT    = evidence per `## Mode-Gated Agent Dispatch` and `## Review Gate`;
           inspect changed files; run the smallest relevant check; map the
           change to the inspection or command that proves it.
           Behavior-changing LIGHT still requires RED/GREEN per E4 and the
           eligibility gate's no-exception rule.
STANDARD = LIGHT + focused semantic tests mapped to ACs; RED/GREEN or a
           recorded exception; risk-activated negative/regression cases; a
           relevant baseline or smoke check.
THOROUGH = STANDARD + the integration, migration, smoke, end-to-end, or
           recovery evidence each named risk requires; record residual risk.
```

One case may satisfy several of these evidence categories: a single minimal
real-surface RED/GREEN case can also serve as the focused semantic evidence for
its AC, and a baseline or smoke requirement should reuse the recorded nearest
existing suite when it covers the changed surface. Credit a case for a category
only when its own recorded inputs and observations satisfy that category.

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
cap, and the one-round review budget — or derive conservative values. Numeric
size, ratio, dispatch, and test counts remain anomaly signals, never
authorization, necessity proof, or a hard test budget.

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

## Executor Assignment Completion Stop

Stop the current executor assignment when its manifest is satisfied, mapped
verification is green and fresh, every necessary test is admitted, no approved
expansion remains, and only optional follow-ups remain. This stop is local to
that bounded assignment, not final run completion. Mutation-capable cleanup or
a focused review fix starts a new bounded assignment with its own updated
manifest, Verification Contract, Test Necessity decisions, and assignment stop.
Do not add variants, helpers, cleanup, or adjacent fixes merely to continue the
current assignment.

## Cleanup And Final Verification

Phase: EXECUTE exit — the CLEANUP and RECHECK checkpoints run at EXECUTE exit
[E12]; the FINALIZE checkpoints (INTEGRATE, COMPLETION_AUDIT) run after REVIEW
under `## Finalize Checkpoints`.

1. CLEANUP — after the behavior lock and BEFORE the single review round:
   LIGHT/STANDARD run a caller-owned quick diff scan; never load, invoke, or dispatch `simplify`, even when actual candidates or candidate uncertainty remain.
   Record `simplify`: not-required (mode: LIGHT|STANDARD). The record names the
   selected lower mode; candidates become follow-ups or use another already-authorized
   Ralph mechanism without expanding mutation scope. THOROUGH alone may load or invoke `simplify`, and only when actual candidates or candidate uncertainty remain.
   A clean THOROUGH scan records `simplify` as not-required (no candidates).
   THOROUGH expands to four independent viewpoints only for a named safety or
   broad-diff trigger. Never create cleanup work to satisfy a pass count.
   Cleanup is mutation-capable here through executor-applied accepted findings;
   after REVIEW it is read-only and any findings become residual risk or
   follow-ups.
2. RECHECK — when cleanup changed files, rerun relevant verification and
   confirm behavior, the behavior lock, and changed-file scope survived. The
   `## Diff-Budget Gate` then runs once for the stabilized post-cleanup
   revision, and the sole review round inspects that final
   post-cleanup diff in REVIEW.

The post-cleanup review inspection and the `single review round`
language apply whenever a code-review stage runs, under `single-reviewer` or
`perspective-pair`. A compliant LIGHT run, with code review waived, proceeds
directly from CLEANUP/RECHECK to its verifier decision under
`### Independent Verifier Trigger Predicate`, with no reviewer stage; when no
trigger fires it proceeds to FINALIZE with caller-owned evidence.

## Review Gate

Phase: REVIEW. Completion requires evidence, not confidence.

Topology by risk [E8]:

```text
LIGHT    -> code review is waived; the dispatched `executor`'s mutation goes
            straight to the verifier decision in the predicate below.
STANDARD -> ONE full-role `code-reviewer` for behavior-affecting or workflow
            changes, running the complete ordered lenses in one dispatch. The
            compliant carve-out remains `not-required (STANDARD small
            carve-out: <reason>)`.
THOROUGH -> ONE full-role `code-reviewer` by default, exactly as STANDARD.
            ONLY a named security, data, destructive, public-contract,
            release-critical, new-concurrency, migration, or broad
            multi-system trigger escalates to one perspective-diverse pair:
            Lens A = adversarial correctness + security skeptic; Lens B =
            maintainability + coverage completeness. Each instance runs the
            full role; packets are identical except the single `Assigned perspective:` line,
            dispatched in one parallel batch and caller-synthesized into one
            verdict. That same named trigger selects only the active
            platform's escalated diversity (cross-host on Codex). The active
            platform supplies the diversity leg. If that leg is unavailable,
            default mode uses two independent same-model instances and records
            the reason; an explicit caller demand for diversity is strict mode
            and transitions to PAUSED instead of falling back.
```

Reviewer count is never a quality proxy: a second reviewer instance is
authorized ONLY by a named trigger above — never by mode alone, task size,
non-triviality, reviewer availability, or imminent completion.

E8's `exactly one review round` MUST apply whenever a code-review stage runs at
all, under `single-reviewer` and `perspective-pair` alike; a compliant LIGHT run
and the STANDARD small-task carve-out record code-review `not-required` and run
ZERO review rounds and no fix-manifest step.

### Independent Verifier Trigger Predicate

This predicate is the ONLY authority that selects the independent `verifier`
[E7]. Dispatch it when, and only when, at least one named trigger fires:

- the user explicitly requested independent verification;
- required evidence is stale, missing, or conflicting on the delivered revision;
- a named security, data-loss, destructive, migration, recovery, or
  public-contract risk actually requires independent evidence that caller-owned
  evidence cannot supply;
- an accepted blocking review finding was fixed, so the fixed revision needs a
  per-finding resolution audit.

Explicit NON-TRIGGERS — each is insufficient by itself and MUST NOT be recorded
as a verifier basis: the selected execution mode, including THOROUGH; task size
or non-triviality; the proving tests or implementation having been authored or
accepted by the same agent; a `code-reviewer` having run, or not run; and
completion being imminent. When no trigger fires, record
`Independent verifier: not-required (no trigger fired: <reason>)`, let the
caller own evidence freshness, and treat that as a compliant completion path in
every mode — LIGHT, STANDARD, and THOROUGH alike.

Review-then-verify [E7]: run exactly one selected code-review stage first and
validate its `Overall verdict` (caller-synthesized when the trigger selected a
pair), blocking finding IDs, and reviewed revision binding.
Reviewer packets are blind to maker conclusions, expected verdicts, and sibling
output; each reviewer
derives findings from the exact contract and diff. With no blocking findings and
no other trigger fired, no verifier is required: record the compliant
not-required reason and complete on the reviewed revision. When a trigger does
fire, start the independent self-host `verifier` pass (independence per E7)
against the reviewed revision. On `blocking-findings`, issue exactly one executor-owned focused fix
and record its manifest before the verifier starts. The verifier first records
its evidence design from the Direction Contract, ACs, exact target, and raw
evidence; only then does the caller disclose the accepted reviewer findings and
fix manifest for the audit of every blocking finding ID against the fixed
revision. Accepted findings and fix manifests are audit obligations, not proof.
Reviewer approval of the fixed revision is NOT required and MUST NOT be requested.
Validate the verifier's `Verification verdict`, verified revision binding, and
per-finding audit before using it.

Completion requires either reviewer verdict `approve` (or compliant
`not-required`) with the verifier compliantly not-required, or that verdict plus
verifier `pass` / accepted `pass-with-residual-risk` bound to the reviewed
revision, or reviewer verdict `blocking-findings` with a fix
manifest mapping every accepted blocking finding ID, and the verifier pass (or
accepted pass-with-residual-risk) binds to the FIXED revision with a
per-finding resolution audit.
`pass-with-residual-risk` also requires the caller to record why the named risk
is non-blocking and every AC remains satisfied. A compliant LIGHT path records
code-reviewer topology `not-required (LIGHT: code review waived)` and completes
on the reviewed revision, exactly as a compliant STANDARD small-task carve-out
does; a verifier joins that path only when the predicate fires. Verifier `fail`, an
unresolved blocking finding after the one fix and audit returns to the
budgeted `systematic-debugging` or `failed_verification` path; either role's
`blocked` verdict pauses. These enums are caller
inputs under E17, never autonomous transitions.

The verifier audit is required exactly when
`### Independent Verifier Trigger Predicate` fires, in any mode. Same authorship
of the proving tests or implementation is explicitly NOT such a trigger.
A triggered audit MUST run in a separate context. If no separate context is
available, record `Independent
verifier: dispatch-unavailable` as a blocker and transition to PAUSED. Inline
command reruns may still strengthen caller-owned evidence, but they cannot
count as a triggered independent audit. When the audit is optional or not
required, record that reason without turning dispatch unavailability into a
pass.

Record the Review Gate dependency graph in the ledger:

```text
Review Gate dependency graph:
- code-reviewer topology: not-required | single-reviewer | perspective-pair
- pair trigger: not-applicable | <named high-risk/diversity trigger>
- code-reviewer pass: pending | complete | blocked | not-required
- blocking reviewer findings: none | fix-applied (manifest mapped) | blocking
- verifier trigger: none | <named trigger from the predicate>
- verifier bound revision: reviewed | fixed | not-required
- verifier eligible to start: yes | no | not-required
- verifier started after reviewer completion: yes | no | not-required
- early verifier discarded and rerun: yes | no | not-applicable
```

Record `perspective-pair` only with its named `pair trigger`, and a verifier
only with its named `verifier trigger`; a topology or verifier recorded without
its trigger is a named ledger gap, not a pass.

`verifier eligible to start` is `yes` only after the selected code-review
output and any pair synthesis are captured and either findings are none / review is
compliantly not-required, or the single fix manifest is recorded. A verifier
spawned before that point is stale evidence: record it as discarded and rerun
it after the dependency is satisfied. When both roles are required, the ledger
must show `verifier started after reviewer completion: yes` or the verifier
pass does not count.

Review focus — every reviewer instance and any triggered verifier must audit the
exact complete manifest fingerprint. A triggered verifier independently checks
manifest adherence, semantic RED/GREEN, Test Necessity mapping, scope and
non-goals, generated causality, and the Completion Stop; reviewer approval is not a
substitute for that evidence.

- the applicable negative-path scenarios — malformed or boundary input,
  stale state, cancel/resume or concurrency — probed when their triggers
  hold, or each ruled out with a one-line reason that names why no approved
  AC ID, named risk, adjacent regression surface, safety invariant, or
  directly changed semantic model triggers it

Reviewer findings outside the Mutation Manifest and Expansion Gate are residual
risk or follow-ups, not fixes in this run; a regression caused by the current change
always maps to approved scope and may block. For accepted blocking finding
IDs, the main agent issues exactly one focused `executor` assignment and
records a manifest mapped to every accepted finding ID; the reviewer never
applies the fix or advances the FSM, and is never re-dispatched. Budget
[E8]: exactly one review round; after the executor-owned fix the verifier audit
of the fixed revision is the recheck, since accepted blocking-fix resolution is
itself a named verifier trigger. A blocker remaining after that budget
goes to `systematic-debugging`, `blocked`, or `failed_verification`.

## Finalize Checkpoints

Phase: FINALIZE — the remaining checkpoints run in order, after REVIEW:

3. INTEGRATE — carry out the worktree completion responsibility [E13]: merge
   back into the integration checkout and run post-merge verification, or
   report the branch/PR handoff.
4. COMPLETION_AUDIT — read and follow `verification-before-completion` before
   any completion claim, then write the final report.

## Completion Stop

Record final run Completion Stop only after mutation-capable cleanup, the sole
review round and any one focused review fix, all resulting rechecks, any
triggered final verifier, integration, and completion audit have stabilized
the exact final complete manifest fingerprint. Any later mutation invalidates
this final stop and requires reevaluation and reverification on the new
revision. Optional follow-ups do not reopen a valid final stop.

The COMPLETION_AUDIT is EVIDENCE-ONLY: it reads the existing ledger and reuses
fresh revision-bound evidence. Imminent completion is NOT a trigger — the audit
MUST NOT dispatch a role, rerun a passing check, or add a test merely because
the run is about to finish. It may only name a missing-evidence blocker when a
required row is actually stale, missing, or conflicting.

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
The run is invalid if the session does not show each required completion
criterion below satisfied [E11] — including, named individually,
the required reviewer pass, the independent verifier pass, simplify, and verification-before-completion
(or an explicit missing-evidence blocker / not-required reason recorded for
each). A silently omitted step is a named ledger gap, not a pass.

- Evidence status lives in `verification.md`; PRD/progress point to its AC IDs.
- Every review records its topology using the dependency-graph values
  (`not-required` with the compliant reason, `single-reviewer`, or
  `perspective-pair` with its named pair trigger and the active platform's
  pair-mode value); an inline fallback requires a reason.
  Missing review topology is a named ledger gap.
- The verifier entry records its named trigger, or the compliant
  `not-required (no trigger fired: <reason>)` reason. A verifier recorded
  without a named trigger, or omitted while a trigger fired, is a ledger gap.
- When both code-reviewer and verifier are required, the ledger must show
  `verifier started after reviewer completion: yes` or the verifier pass is
  stale and does not count.
- On the fix path, the verifier pass is bound to the fixed revision with a
  per-finding resolution audit; the fix manifest maps every accepted blocking
  finding ID.
</HARD-GATE>

Completion criteria:

- selected execution mode recorded and followed; every story `passes: true`
- every repository work-product mutation shows dispatched-executor evidence, or
  one recorded inline fallback reason (LIGHT-tiny or dispatch-unavailable) per
  inline edit; an unrecorded inline mutation cannot complete in any mode
- Diff-Budget is `passed@<current stabilized fingerprint>` for the delivered diff
- actual changed paths adhere to the Mutation Manifest; any Expansion request
  records its approval owner, was approved, and was bound to a revised Mutation
  Manifest ID recorded in the snapshot and reissued to the executor as
  `Expansion status: approved@<revision id> -> incorporated before mutation`
  before any mutation
- `verification.md` has one row per AC ID with planned/actual evidence,
  freshness, and audit status
- required TDD evidence exists, or each exception is documented; every new or
  changed test has a recorded Test Necessity decision
- Completion Stop was applied when its conditions became true
- the risk-required review is recorded complete in the `## Review Gate`
  dependency graph — approved or compliantly not-required, or blocking findings
  with one accepted fix manifest mapped to every finding ID per that section;
  a `perspective-pair` topology names its firing trigger
- either a named verifier trigger fired and that verifier pass ran per the
  review-then-verify order and bound
  to the reviewed revision or, on the fix path, the FIXED revision with a
  per-finding resolution audit; or no trigger fired and the compliant
  `not-required (no trigger fired: <reason>)` is recorded. For a fired trigger,
  `dispatch-unavailable` is a blocker
  and cannot satisfy completion
- `simplify` records `not-required (mode: LIGHT)` or `not-required (mode:
  STANDARD)` after every lower-mode quick scan, including one with candidates
  or uncertainty; THOROUGH records whether its candidate-gated scan ran or had
  no candidates; post-cleanup verification passed when cleanup changed files
- the direct-Ralph automatic worktree was merged back with post-merge
  verification, or its branch/PR handoff was reported, or none existed per
  the recorded `Worktree decision`
- `verification-before-completion` ran for the final claim; story risk
  checks and the final risk check completed or a missing-evidence blocker is
  recorded
- the final report was written

ANY run may compact the four named criteria into one combined ledger line when
EVERY part is a compliant not-required / mode-based not-required / no-candidate / no-trigger record with
its reason — nothing was actually dispatched or run for any of the four. Whenever
one of the four actually ran or blocked, that entry stays individual with its own
evidence. A STANDARD
small-carveout run may compact the review and simplify entries while the
verifier and verification-before-completion entries stay individual. When
the criteria pass and only optional follow-ups remain, record residual risk
and stop instead of continuing the loop.

## Output

Return: session directory and PRD path; execution profile (mode/source,
tier, policies, `Parallel trigger`, `Worktree decision and location`,
integration status); delivery (stories, manifest adherence, files, cleanup);
verification (commands/results, AC mapping, Verification Contract status, Test
Necessity decisions, risk/completion, validation check, complete manifest
fingerprint); Expansion requests; Completion Stop status; residual risk.

Review-phase attribution: when 2+ stages ran, include exactly
`Review phases: plan=<n>; implementation-code=<n>; independent-verifier=<n>`;
when fewer than two ran, use ordinary labeled prose and omit that count line.

Process anomaly outcome: planned versus actual tests/TDD cycles, role dispatch
reasons, broad-suite runs, and rescope events; no count authorizes or proves
work.

## Final Handoff

Ralph is the terminal workflow skill [E15]. After the final report, do NOT
auto-invoke another workflow skill; further work needs a fresh user request.
Mid-loop skills used inside the loop are Ralph's documented procedure and
are not subject to a per-step transition question — the user opted in by
invoking Ralph.

## Agent Roles

| Agent | Use |
|---|---|
| `explore` | find relevant files, tests, commands, and integration surfaces; one instance when one covers the question, fanning out to genuinely independent read-only targets as one parallel batch (up to 5) |
| `executor` | implement scoped story work with an explicit ownership boundary |
| `verifier` | independently map evidence to ACs and audit test genuineness; one self-host pass after review, never the maker; dispatched ONLY when `## Review Gate`'s trigger predicate fires |
| `code-reviewer` | review correctness, maintainability, regressions, scope trace, and overcomplication; applies the security lens when triggered; ONE full-role instance unless a named trigger selects the pair |

`simplify`, `verification-before-completion`, `test-driven-development`, and
`systematic-debugging` are skills, not agents. Whether a role is inline or
dispatched is decided by `## Mode-Gated Agent Dispatch`.

## Source: docs/platforms/opencode-ralph.md

# Ralph OpenCode Adapter

<ADAPTER_CONTRACT>
This adapter binds the Ralph core to OpenCode. The core owns semantic
decisions; this file owns approvals, dispatch, waits, result intake, and
handoffs. The generated core plus this adapter is self-contained.
</ADAPTER_CONTRACT>

## Role Dispatch

Use `task` with exact `subagent_type: oh-no-<role>`; direct user mentions use
`@oh-no-<role>`. An approved Ralplan handoff authorizes eligible isolated roles
without another subagent approval. Dispatch only roles whose results can change
implementation, review, verification, or the ship/block decision.

STANDARD and THOROUGH repository work-product mutation dispatches
`oh-no-executor`, including REVIEW-to-EXECUTE focused fixes, even when no
concurrent batch exists. Inline mutation is limited to the core's recorded
LIGHT-tiny or confirmed task-unavailable fallback.

Send the core packet plus exact target/revision, write ownership, result/revision
binding, evidence, output envelope, and stop conditions. Issue independent
read-only roles and disjoint executors in one assistant turn, at most five at a
time. Foreground `task` return is the wait and final result. For background
tasks, wait for automatic completion notifications; do not poll, duplicate, or
redo their scope. Capture every result and changed-file set before advancing.

## Review And Verification

A fired review or verifier trigger always dispatches a separate context. The
default review uses one full-role `oh-no-code-reviewer`. Only a core-selected
perspective pair issues two reviewer tasks in one turn, with identical packets
except the single `Assigned perspective:` line. Complete and synthesize review
before a triggered `oh-no-verifier`; after a blocking-finding fix, bind the
verifier to the fixed revision and do not dispatch a reviewer recheck.

OpenCode has no per-task model override. Configured roles use their stored
provider/model IDs; unconfigured roles inherit the primary model. Two calls to
one reviewer role prove independent contexts, not model diversity. Record a
selected pair as `same-model-perspective-pair`; strict model-diversity demand
PAUSES because this binding cannot guarantee distinct identities.

If review or verifier dispatch is unavailable, report the independent-audit
blocker and remain PAUSED where the core requires separation. Other unavailable
roles use only core-permitted recorded fallbacks.

## Questions, Skills, And Completion

Use `question` and wait whenever the core requires worktree choice, scope or
direction approval, rescope, residual-risk acceptance, or another user-owned
decision. Never treat task permission or an approved role dispatch as approval
to change the Direction Contract.

Load Ralph's internal `test-driven-development`, `simplify`,
`systematic-debugging`, `verification-before-completion`, or `fusion-rescue`
step with native `skill` when its core trigger fires, then resume Ralph with the
returned result. These are loop internals, not user-facing chaining events.
Ralph is terminal after its final report and loads no next workflow skill.
