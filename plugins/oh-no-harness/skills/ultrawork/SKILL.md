---
name: ultrawork
description: Use when the user explicitly delegates autonomous end-to-end delivery across discovery, planning, implementation, and verification; not for a small execution-ready task.
argument-hint: "<goal, spec path, plan path, or broad delivery request>"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Ultrawork for Codex

This generated file is the Codex-facing runtime skill document. Codex should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/ultrawork.md`
- `../../docs/platforms/codex-child-packet-floor.md`
- `../../docs/platforms/codex-ultrawork.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/ultrawork.md

# Ultrawork

Ultrawork is a Markdown-first orchestration loop for moving from idea to
verified result with the retained skill chain. Each phase is chosen
explicitly from this Markdown workflow — there is no hidden next-step
selector. Do not use it for a small concrete fix whose contract surface,
baseline evidence, and verification command are already clear; use direct
implementation or `ralph`.


## Invariants

```text
U1. Ultrawork orchestrates the retained chain and never replaces it: the
    planning gate uses `ralplan`, the execution handoff uses `ralph`.
    When Ralph is unavailable, Ultrawork may inline the phase procedure but
    remains an orchestrator: repository mutation still dispatches `executor` by
    default under Ralph's need test; inline writes require a recorded LIGHT-tiny
    or dispatch-unavailable fallback and carry the unchanged executor contract
    per Ralph's `## Mode-Gated Agent Dispatch`, and a fired review or audit
    trigger is exempt from the need test and never runs inline.
U2. Approved existing specs or plans may skip earlier phases only when the
    skip reason and source artifact are recorded; a merely relevant plan
    without approval evidence or with mismatched scope goes through the
    planning gate.
U3. requirements_gate: planning must not start until the requirements
    source is recorded. Interview is the only user-facing content approval
    gate for new work; ultrawork never auto-approves the interview spec.
U4. Once ralplan's gates pass, record the plan approval source and
    continue into ralph without a separate Plan Approval Brief prompt;
    pause only on ralplan's named pause conditions (canonical list:
    ralplan `### Ultrawork exception`).
U5. worktree_gate: no source file edit until a `Worktree decision` is
    recorded. Ultrawork's worktree duties are the numbered list in
    `### WORKTREE` below.
U6. The Direction Contract and AC IDs carry unchanged through plan,
    session, packets, and report; each phase records only its delta; a
    phase needing a direction change pauses for explicit user approval.
U7. Markdown at .oh-no/sessions/{sessionId}/ultrawork.md is authoritative.
    No JSON state artifact in v1; any future JSON must be derived and
    non-authoritative. No timer, daemon, or background heartbeat.
U8. Doctor/status runs at entry, resume, pre-execution, pre-merge, and
    pre-final; BLOCKED stops before edits, merge, or final claim.
U9. Escalation routes are fixed: ambiguous requirements -> user or
    `interview`; direction/scope conflict -> user or `ralplan`; failing
    checks or unknown root cause -> `systematic-debugging` (which owns
    `debugger` dispatch); public-contract/security/packaging risk ->
    `code-reviewer` or `verifier`; missing worktree or verification
    evidence -> blocked.
U10. Any scope change, missing authority artifact, failed worktree gate,
     or failed verification transitions to a named non-success outcome,
     never silent continuation.
U11. Final Validation does not repeat Ralph's completed internal gates;
     review-then-verify order holds and an early verifier is stale,
     discarded, and rerun.
U12. The run is invalid unless the ledger shows each named phase gate
     satisfied or a recorded not-required reason; a silently omitted step
     is a named ledger gap, not a pass.
U13. Ultrawork is the only context that may invoke interview/ralplan/ralph
     without their per-step transition question. It skips the between-phase
     "which next skill?" question and the separate plan-approval prompt —
     and skips nothing else: spec approval when requirements are unclear,
     planning gates, scope-change pauses, verification, and final evidence
     all still run.
U14. Maker roles do not self-approve; inline checker fallback is still
     checker output. When a named verifier trigger fires on a
     subagent-capable host, an
     inline check by the maker or accepting agent never satisfies the
     independent verifier audit. Same authorship alone is not that trigger.
U16. Phase-agent authorization, eligibility, and fallback follow
     `## Agent Roles`.
U17. A discovered plan admitted through U2 but lacking an execution
     profile gets the profile set before execution (schema is
     ralplan-owned); execution never starts profile-less.
```

`STOP`/blocked means: persist the heartbeat with the blocked gate,
evidence, and unblock condition, then report — never a silent exit.

## Heartbeat

Ultrawork establishes the chain session directory at
START_OR_RESUME; downstream skills in the same run reuse it. Write a
heartbeat at phase boundaries, long waits, compaction/handoff, scope
changes, and before the final report.

Heartbeat contents:

```text
Ultrawork run:
- Phase: START_OR_RESUME | REQUIREMENTS | PLANNING | WORKTREE | EXECUTION |
  QA | FINAL_VALIDATION | REPORT
- Outcome: none | succeeded_merged_verified_reported |
  succeeded_left_worktree_for_inspection | paused_for_user | blocked |
  cancelled | failed_verification | scope_change_pending_approval
- Goal/story; authoritative state path; last checkpoint; next action
- Blocker/status; worktree; verification; checker; stop condition
```

Resume precedence: newest user instructions outrank saved state; then the
authoritative Markdown, its referenced specs/plans and Ralph artifacts,
then Git worktree/merge evidence. Logs, apps, metrics, and connector data
are evidence only. On conflict, doctor/status records the mismatch and
pauses before editing or merging.

Doctor/status gate semantics [U8]: run at entry, resume, pre-execution,
pre-merge, and pre-final; output `PASS`, `WARN`, or `BLOCKED` after
checking artifact freshness, worktree/merge state, verification, stale
docs, custom-agent readiness, and validator drift. `BLOCKED` stops before
edits, merge, or final claim; `WARN` may continue only when acceptance
evidence is unaffected.

Checker outputs [U14]: record role, reviewed artifact or diff, findings,
evidence status, follow-up, verdict when applicable, dispatch/fallback
mode, and lifecycle status.

## State Machine

The lowercase gate tokens are each phase's guard label; the phases keep
their historical order: start_or_resume -> requirements_gate ->
planning_gate -> worktree_gate -> execution_handoff -> qa_loop ->
final_validation -> report.

| Phase | Exit guard | Next |
|---|---|---|
| START_OR_RESUME | heartbeat established; artifact discovery done; doctor PASS/WARN [U7, U8] | REQUIREMENTS |
| REQUIREMENTS | requirements_gate: planning must not start until the requirements source is recorded — approved interview spec, found approved artifact [U2], or already-concrete request [U3] | PLANNING |
| REQUIREMENTS | request is vague (missing target files/subsystem, acceptance criteria, user/caller impact, verification command, constraints, or concrete examples) [U3] | REQUIREMENTS (read and follow `interview`, then resume from the spec) |
| PLANNING | planning_gate: approved plan exists [U2] or ralplan gates passed with the approval source recorded; execution profile present [U4, U17] | WORKTREE |
| PLANNING | a ralplan pause condition fires [U4] | outcome paused_for_user |
| WORKTREE | worktree_gate: `Worktree decision: ultrawork automatic worktree` recorded; artifact access preserved [U5] | EXECUTION |
| WORKTREE | worktree creation fails and no fallback approved [U5] | outcome blocked |
| EXECUTION | execution_handoff: `ralph` completed its loop with the Ultrawork-approved plan or spec [U1] | QA |
| EXECUTION | ralph reports RETURN_TO_PLAN (plan defect, no direction change) [U9] | PLANNING |
| EXECUTION | ralph pauses for a direction change [U6] | outcome scope_change_pending_approval |
| QA | qa_loop: orchestration-level checks pass [U9] | FINAL_VALIDATION |
| QA | a fix from the debugging route changed files | QA (re-run the affected checks) |
| QA | root cause unknown after the debugging route, or a blocking reason is documented [U9] | outcome blocked or failed_verification |
| FINAL_VALIDATION | dependency graph satisfied; blocking findings resolved or recorded [U11] | REPORT |
| FINAL_VALIDATION | a reviewer blocker requires a code fix [U9, U11] | QA (fix via the debugging route; the verifier then confirms the fixed revision — no reviewer re-dispatch) |
| REPORT | ledger HARD-GATE satisfied; report written [U12] | outcome succeeded_merged_verified_reported or succeeded_left_worktree_for_inspection |
| any | user stop, scope change, or missing authority artifact [U6, U10] | outcome paused_for_user / scope_change_pending_approval / cancelled |

## Artifact Discovery

Phase: START_OR_RESUME. Before asking new questions, check `.oh-no/specs/`
and `.oh-no/plans/`.

- A relevant approved interview spec is the approved requirements source —
  move to planning. Carry its Direction Contract and AC IDs unchanged [U6].
- A relevant consensus plan may skip interview and planning only when it is
  approved (explicit user approval of its Plan Approval Brief, or a
  recorded ultrawork automatic-approval source from a prior run — a passing
  Findings Ledger Gate alone is quality evidence, not approval) and matches
  the current request's scope; record the skip reason and source artifact
  path [U2].
- If the admitted plan lacks an execution profile, set the missing profile
  before execution (the profile schema is ralplan-owned) and record the
  completed profile and its source in the ledger [U17].

## Phase Procedures

### START_OR_RESUME

Establish or reuse the chain session directory; write the first heartbeat;
run doctor/status [U8]; perform Artifact Discovery.

### REQUIREMENTS

If the request is vague, read and follow `interview` as the next skill,
then resume from the resulting spec. Interview's spec review still
surfaces to the user [U3, U13]. If the request already has a clear spec or
is concrete enough to plan without inventing product intent, record the
requirements source and move on.

### PLANNING

Read and follow `ralplan` unless an approved plan already exists per
Artifact Discovery. Inside Ultrawork the ralplan plan is automatically
approved for execution once it satisfies Ralplan's consensus,
direction-preservation, execution profile, and test-quality gates: record
`Plan approval source: ultrawork automatic approval after interview/spec`
and do not pause for a separate Plan Approval Brief [U4]. Ralplan's
`### Ultrawork exception` owns the canonical pause-condition list; when
one fires, pause for the user instead.

### WORKTREE

For write-capable execution [U5]:

1. Create or select a registered Git worktree under
   `.oh-no/worktrees/<task-slug>` using `git worktree add` — `git clone`,
   `cp -R`, and plain directories are not valid substitutes.
2. Record `Worktree decision: ultrawork automatic worktree`.
3. Preserve access to the approved `.oh-no` spec, plan, or PRD in the task
   worktree: copy the artifact, record an absolute path, or quote the
   approved task definition.

After execution passes verification, merge the completed work back into
the integration checkout, run post-merge verification, and record
cleanup-or-left-for-inspection. If worktree creation, merge, or post-merge
verification fails, report the blocker instead of silently editing the
original checkout.

### EXECUTION

Read and follow `ralph` with the Ultrawork-approved plan or spec; treat
the ordinary `ralph` handoff as approved — no second implementation
approval unless a planning pause condition fired [U13]. Execution
preserves Ralph's selected execution mode, artifact policy, verification,
review, cleanup, and final report requirements. If the approved plan
selects `Parallel trigger: approved-plan-handoff`, preserve that trigger
in the handoff.

Ralph-unavailable fallback applies only when the host cannot load the `ralph`
skill (an explicit user instruction overrides); record the reason [U1]. Under
that fallback, Ultrawork still owns `.oh-no` state and gate decisions, sets the
required execution mode first, and applies Ralph's mode-gated loop. Dispatch
`executor` for repository work-product mutation under Ralph's need test and keep
one executor identity across the TDD cycle; inline mutation is only a recorded
LIGHT-tiny or dispatch-unavailable fallback and owes the unchanged executor
contract per Ralph's `## Mode-Gated Agent Dispatch`. Read and follow
`test-driven-development` before behavior-changing production edits and record
RED/GREEN/REFACTOR evidence or the approved exception.

### QA

Ralph owns story-level verification, mode-gated review, cleanup, and
verification-before-completion. The QA loop is the orchestration layer
around that result: investigate failed commands, integration problems,
merge problems, or scenario gaps that remain after Ralph's task-worktree
evidence — especially after worktree integration or when Ralph reports a
blocker. Dispatch [U9]:

- `systematic-debugging` (skill, not agent) for root-cause investigation
  before fixes; it owns `debugger` dispatch per its own contract
- `verifier` for evidence packaging and, via its scenario lens,
  user-facing flows

Repeat until checks pass or a blocking reason is documented.

### FINAL_VALIDATION

Do not repeat Ralph's completed internal gates [U11]. Dispatch
`code-reviewer` only for additional orchestration risk not already covered
by Ralph (integration, merge, public-contract, security, or cross-phase),
with its security lens when security-sensitive behavior was touched. When
dispatched, it runs as ONE full-role `code-reviewer` by default and records
`single-reviewer`. ONLY a named security, data, destructive, public-contract,
release-critical, new-concurrency, migration, or broad multi-system trigger
escalates it to the perspective-diverse pair, recorded as `perspective-pair`
with the active platform's pair-mode value; that same fired trigger selects
escalated platform diversity. Reviewer count is never a quality proxy: mode
alone, orchestration breadth, and imminent completion never authorize a second
instance. The STANDARD
small-task carve-out is a direct-Ralph path and never applies here. A triggered
pair
uses two same-role instances, each running the full role, with Lens A =
adversarial correctness + security skeptic and Lens B = maintainability +
coverage completeness. The two instances receive packets
identical except the single `Assigned perspective:` line, are dispatched in
parallel, and are synthesized into one verdict. The active platform supplies
the diversity leg. If that leg is unavailable, default mode uses two
independent same-model instances and records the reason; an explicit caller
demand for diversity is strict mode and transitions to PAUSED instead of
falling back.

An independent `verifier` audit is required exactly when a named trigger in
`verification-before-completion`'s V4 trigger predicate fires — explicit user
request; stale, missing, or conflicting evidence; a named security, data-loss,
destructive, migration, recovery, or public-contract risk actually needing
independent evidence; or accepted blocking-review fix resolution. Execution
having produced or changed the proving tests, and the implementation or tests
having been authored or accepted by the same agent, are explicit NON-triggers,
as are mode, orchestration breadth, and imminent completion [U11, U14]. When no
trigger fires, record
`Independent verifier: not-required (no trigger fired: <reason>)` and reuse the
fresh revision-bound evidence instead of re-proving it.
A fired trigger is satisfied through exactly one of two
mutually exclusive paths. Reuse Ralph's independent `verifier` pass only when
all hold: it covers the same final claim and revision, it was an independent
dispatch, it ran after the selected Final Validation code-review stage completed
or that review is compliantly not-required, and no file, dependency, or evidence
changed since that pass; otherwise dispatch one fresh self-host `verifier` pass.
If Ultrawork dispatches its own `code-reviewer`, Ralph's prior verifier is
early/stale by construction, so reuse is unavailable and the fresh self-host
`verifier` pass runs after reviewer synthesis and any fix manifest, bound to the
reviewed/fixed revision. When that audit is required but no separate context
exists, record the `dispatch-unavailable` blocker and pause; inline evidence
cannot satisfy it.

Review-then-verify order: run the selected code-review stage first, then
the confirming independent `verifier` pass (never the maker). Before
dispatching, write the dependency graph into the session ledger:

```text
Final Validation dependency graph:
- code-reviewer topology: not-required | single-reviewer | perspective-pair
- pair trigger: not-applicable | <named high-risk/diversity trigger>
- code-reviewer pair mode: not-required | <active platform pair-mode value>
- code-reviewer pass: pending | complete | blocked | not-required
- code-reviewer synthesis captured: yes | no | not-required
- blocking reviewer findings: none | fix-applied (manifest mapped) | blocking
- verifier trigger: none | <named V4 trigger>
- verifier source: fresh | reused@<ralph ledger entry + revision binding>
- verifier bound revision: reviewed | fixed | not-required
- verifier eligible to start: yes | no | not-required
- verifier started after reviewer completion: yes | no | not-required
- early verifier discarded and rerun: yes | no | not-applicable
```

`verifier eligible to start` is `yes` only after the selected code-review
stage completed (or a compliant not-required reason is recorded), its output
or synthesis is captured, and either findings are absent or the single fix
manifest maps every accepted blocking finding. A verifier spawned before that point is stale evidence, must be
recorded as discarded, and must be rerun after the dependency is
satisfied. When both roles are required, the ledger must show
`verifier started after reviewer completion: yes` or the verifier pass
does not count. On the fix path, the review remains bound to the reviewed
revision and the verifier must bind to the fixed revision; no reviewer
re-dispatch occurs.

If execution ran inline instead of through `ralph`, apply Ralph's
mode-gated review, cleanup, baseline guard, one-round review budget, and final
evidence requirements here before reporting success.

### REPORT

<HARD-GATE>
The run is invalid if the session ledger does not show each required phase gate satisfied, named individually: requirements_gate, planning_gate (Plan approval source recorded), worktree_gate, execution mode, verification, reviewer pass, independent verifier pass, simplify/cleanup, and VBC (or a recorded not-required reason for each) [U12]. A silently omitted step is a named ledger gap, not a pass. Each dispatched reviewer pass records `single-reviewer`, or `perspective-pair` plus its named pair trigger and the active platform's pair-mode value; an inline fallback requires a reason. A `perspective-pair` recorded without its named trigger is also a gap. Missing review topology is a named ledger gap, not a pass. Any verifier pass is governed by the named V4 trigger predicate and the sequencing field, and records either its firing trigger or the compliant `not-required (no trigger fired: <reason>)`. When both code-reviewer and verifier are required, the ledger must show `verifier started after reviewer completion: yes` or the verifier pass is stale and does not count. On the fix path, review evidence remains bound to the reviewed revision and the verifier pass must be bound to the fixed revision.
Run `verification-before-completion` before any completion claim or final report.
</HARD-GATE>

Skip re-running verification-before-completion only when Ralph already ran
it for the same final claim and no integration, merge, or
orchestration-level evidence changed after that point; otherwise run it
against the final orchestrated result.

The final report contains: active artifact paths (spec or plan and session
directory); phase status and skills used in order; execution mode and mode
source; Worktree decision, integration checkout, post-merge verification, and
cleanup status; files changed; commands run; review status; verification
evidence; residual risk; final result or blocker.

## Agent Roles

Ultrawork normally reaches most roles by reading and following
`interview`, `ralplan`, and `ralph` [U1]; inline phase handling is the
fallback, not the default. Dispatch each phase's agents as separate
subagents on subagent-capable hosts — dispatch keeps phase noise out of
the orchestration context, and checker independence requires a separate
context [U14]. Apply the active platform's dispatch authorization for
eligible phase agents without per-run subagent approval; do not pause
Ultrawork only to ask whether subagents may be used [U16]. Eligibility
still requires decision-changing value; content gates, role isolation,
fallback reasons, and lifecycle cleanup are never skipped. Every direct phase
role dispatch reuses the target role's required identity/result envelope and
adds only Ultrawork's workflow delta: phase, source plan/spec, and phase-owned
scope.

| Phase | Agents |
|---|---|
| REQUIREMENTS | follow `interview`; it dispatches `explore` for brownfield facts; no planning or review agents here |
| PLANNING | follow `ralplan`; sequential `analyst` -> `planner` -> risk-gated Plan-Reviewer; the Plan-Reviewer follows ralplan's risk-selected topology, defaulting to one full-role reviewer, while a named paired-review trigger selects whether the pair exists and then the platform's diversity mechanics |
| EXECUTION | follow `ralph`; isolated `explore`, executor-default repository mutation, `verifier`, and review agents per the approved mode and plan; Ralph-unavailable phase fallback preserves executor ownership, with inline mutation only for recorded LIGHT-tiny or dispatch-unavailable cases |
| QA | `systematic-debugging` owns `debugger`; `verifier` with the scenario lens |
| FINAL_VALIDATION | `code-reviewer` dispatched only for additional orchestration risk (ONE full-role instance by default; perspective-diverse pair only on a named trigger); independent `verifier` only on a named V4 trigger |

If the user invoked ultrawork with `parallel`, `subagents`, `spawn`,
`delegate`, or `one agent per` language outside an approved plan profile,
preserve that phrase as an explicit dispatch signal. Preserve
`Parallel trigger: natural-dispatch` only for direct Ralph execution when
the host permits proactive dispatch and the active skill policy itself
authorizes eligible isolated roles.

## Ultrawork Exception

Apply U13 verbatim: the user opted into orchestration, so each phase
boundary moves automatically once the prior phase's content gate is
satisfied (PLANNING's automatic approval per U4 — ralplan's
`### Ultrawork exception` owns the pause conditions).

If the user invokes `interview`, `ralplan`, or `ralph` directly without
going through ultrawork, the per-step Next Skill Handoff in those skills
is required.

## Source: docs/platforms/codex-child-packet-floor.md

# Codex Child Packet Floor

This compact main-session source is the hook-disabled native-skill fallback for
caller-owned child packets. When SessionStart is enabled, its compatible global
floor remains the normal direct-dispatch owner.

The main caller sends each child a proportional self-contained English packet
with purpose/outcome; target role; exact target/revision and result/revision
binding for repository mutation, review, or verification;
scope/permissions/non-goals; contract/acceptance; expected evidence/output; and
stop/escalation. Keep simple read-only packets proportional. Workflow-specific
IDs and deltas come from the selected skill; role prompts do not reconstruct
omitted caller context.

For initial independent review, verification, or debugging, withhold maker
conclusions, expected verdicts, sibling outputs, and preferred root-cause
hypotheses. Disclose them only later when needed for audit or clarification.

## Source: docs/platforms/codex-ultrawork.md

# Ultrawork Codex Adapter

<ADAPTER_CONTRACT>
This adapter binds the Ultrawork core to Codex. The core owns every
semantic decision; this file owns only host invocation and lifecycle
mechanics. If they conflict, the core wins. The generated core plus this
adapter is sufficient: longer platform, shared, and agent documents are
optional maintenance context, never a runtime prerequisite.
</ADAPTER_CONTRACT>

## Sub-Skill Invocation

Invoke `interview`, `ralplan`, and `ralph` through the installed Codex
skill mechanism with the artifact path as context; never ask the user to
type a command. The sub-skill's own generated wrapper is its source of
truth — do not restate its rules in the handoff prompt.

## Phase-Agent Dispatch

Dispatch is trigger-loaded — dispatch only after the active phase's trigger
fires. The Codex SessionStart block
`CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION` is the standing
session-level authorization for eligible phase-owned roles; do not ask for
per-run subagent approval to satisfy it. If `spawn_agent` is exposed, make
the actual registered-agent call first:

Derive every name from the actual Ultrawork role and phase; for example:

```text
spawn_agent(task_name="ultrawork_planner_planning_1", agent_type="oh-no-planner", message=<self-contained packet>, fork_turns="none")
```

Use role-correct unique equivalents for other or sibling phase dispatches. Only
an actual unknown/unavailable `agent_type` rejection confirms the
custom role cannot be used; then use a generic agent with the matching
`docs/agent-core/<role>.md` prompt embedded and record the fallback. One
payload shape per spawn; no `fork_context`. Pass the core-defined role envelope
and phase delta unchanged. Spawn the whole independent batch before
`wait_agent`. A timeout, empty
wait, or "No agents completed
yet" is not final — never close a running or pending subagent merely
because it is slow, and never use missing output as completion evidence.
Call `close_agent` only after capturing a final result, and only when the
host exposes it; if no close primitive exists, closure is host-managed —
record that and continue.

## Review Pair Modes

This section implements only the topology the core already selected; it never
selects topology itself. An ordinary `single-reviewer` Final Validation review —
the default in STANDARD and THOROUGH alike — dispatches exactly ONE full-role
Codex `code-reviewer` and records `single-reviewer`; this is intentional single
review, so no fallback reason is required.

ONLY after the core's named paired-review trigger fired, or the caller
explicitly demanded a strict pair, does the review run as one
perspective-diverse pair recorded as
`same-host-perspective-pair`; that same fired trigger selects cross-host
review when available, or `same-host-parallel-fallback` when the opposite host
is unavailable; record the required fallback reason. `require-cross-host` pauses
instead of degrading.

Once a pair is actually selected, spawn both legs before waiting.
The two review legs receive redacted packets identical except the single `Assigned perspective:` line.

## Cross-Host Consult Channel

This channel opens ONLY after a named THOROUGH Final Validation trigger actually
fires; absent that trigger there is no second leg to consult. A fired trigger
starts one Codex
`code-reviewer` and one transport-owner reviewer making exactly one foreground
Claude call (`claude --print --model opus --permission-mode dontAsk
--no-session-persistence`). A launch notice, background acknowledgement, or
empty output is unavailable evidence; on opposite-host unavailability run
`same-host-parallel-fallback` and record the required fallback reason.

## Worktree Commands

Use ordinary `git worktree add .oh-no/worktrees/<task-slug> -b <branch>`
from the integration checkout; inspect task changes with
`git -C .oh-no/worktrees/<task-slug> status`. Remove the worktree only
after integration and post-merge verification complete.
