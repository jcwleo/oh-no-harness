---
name: ralplan-v2
description: Use when clear requirements need a risk-proportional, reviewed implementation plan before execution.
argument-hint: "<task, approved spec path, PRD, issue, or plan request>"
disable-model-invocation: true
---

# Ralplan v2 Core

## 0. NORMATIVE EXECUTION CONTRACT

Interpret `MUST`, `MUST NOT`, `REQUIRED`, `ONLY`, and `STOP` literally.

Ralplan converts approved requirements plus repository evidence into one
reviewed plan and Ralph execution profile. It never implements production code.

Global invariants:

```text
I1. Requirements direction is user-owned.
I2. The plan body is Planner-owned.
I3. Plan-Reviewer owns exact-draft review/verdict; it never replaces the plan.
I4. APPROVE freezes that draft; non-blocking findings cause no mutation/re-review.
I5. Roles are sequential; only paired Plan-Reviewer instances may overlap.
I6. Active semantic risk selects cost; category words and host capability do not.
I7. Omit inactive fields and unfired gates.
I8. Direct execution needs explicit approve-and-run; Ultrawork uses section 16 only.
I9. Host invocation syntax belongs to the wrapper adapter.
```

Conflict priority, highest first:

```text
user decision > requirements/Direction Contract > Active Plan Contract >
fired core gate > exact draft > role findings
```

Record conflict between higher-priority items and STOP; never infer direction.

## 1. SCOPE AND ROUTING

Use Ralplan for clear requirements needing cross-file/contract sequencing,
AC-to-evidence mapping, risk/rollout decisions, or a reviewed execution plan.

```text
IF user intent, scope, non-goals, constraints, or acceptance criteria are materially unclear
THEN recommend interview and STOP before CONTRACT_COMPILE.

IF the request is a single obvious edit with clear acceptance criteria and no planning decision
THEN recommend direct Ralph and STOP before CONTRACT_COMPILE.

IF a failing command, regression, flaky result, or unknown root cause is the primary problem
THEN recommend systematic-debugging and STOP.
```

Inside Ultrawork, return routing to Ultrawork; invoke no workflow independently.

## 2. SELF-SUFFICIENT CORE

This file contains all platform-neutral rules required to run Ralplan. External
documents may add compatible examples or rationale, but their absence is not a
blocker and they cannot override this core. Requirements sources and repository
evidence remain normal inputs.

The wrapper supplies host primitives for dispatch, waiting, user choice,
cross-host transport, and skill invocation. If a required primitive has no
core-allowed fallback, record it and STOP.

## 3. PLANNING RUN RECORD

Maintain one record; persist it before compaction or handoff.

```text
Planning run:
- Identity/type: <run id>; <direct-ralplan | ultrawork>
- State: ROUTE | REQUIREMENTS_GATE | CONTRACT_COMPILE | PLANNER_DRAFT | PLAN_REVIEW | REVISION_OR_FREEZE | PLAN_PERSIST | APPROVAL_HANDOFF | PAUSED | COMPLETE
- Source/Analyst: <path/summary>; <satisfied-by-spec|completed|gap-check|blocked>
- Contract/mode: <id>; <LIGHT|STANDARD|THOROUGH>
- Draft/review: <id>; <topology>; loop <0|1|2>; <verdict>
- Blockers/direction change: <state>; <yes|no>
- Artifact/approval/next: <path>; <status>; <skill|none>
```

Unrecorded in-memory state cannot authorize a transition.

## 4. STATE MACHINE

### S0 — ROUTE

Apply section 1. Inspect a supplied/discovered spec or plan. Reuse a plan only
when scope matches and approval is explicit-direct or recorded-Ultrawork.
Clear planning requests enter `REQUIREMENTS_GATE`; other routes enter `PAUSED`.

### S1 — REQUIREMENTS_GATE

Source priority: approved interview spec; approved PRD/issue/ticket; otherwise
the current request plus repository evidence.

The source establishes or explicitly leaves open: goal; stable AC IDs; scope
and non-goals; constraints/protected assumptions; visible success/failure;
material risks; unresolved decisions.

```text
Need repository facts -> read-only explore before Planner; batch independent
subsystems by isolated scope. Explore replaces no owned role.

Approved interview spec covers goal/scope/non-goals/constraints/risks/ACs ->
record `Analyst: satisfied-by-approved-spec`; otherwise run Analyst/gap check.

Gap changes product intent, architecture, data, security, or delivery scope ->
surface user decision and STOP before Planner.
```

Transition only after recording the requirements source and Analyst status.

### S2 — CONTRACT_COMPILE

Copy or derive the Direction Contract without changing its meaning:

```text
Direction Contract:
- Requirements source:
- User-confirmed primary goal:
- Required outcomes / AC IDs:
- Non-goals:
- Constraints:
- Do-not-silently-change assumptions:
- Direction-change approval rule:
- Confirmation status: confirmed | inferred | open
```

Select the lightest credible mode. Mode controls planning/review; verification,
agent, and worktree policies remain separate.

```text
LIGHT = small, isolated, low-ambiguity, non-behavioral work without public,
security/data, migration, concurrency/lifecycle, destructive, or release risk.

STANDARD = bounded behavior/configuration/prompt work with localized blast
radius, known ownership, and no THOROUGH trigger.

THOROUGH = active security/data/auth/permission, destructive,
public/release-critical, migration, changed concurrency/lifecycle, multi-system,
high-uncertainty, or difficult-recovery risk.
```

LIGHT requires every exclusion; any THOROUGH trigger wins; otherwise STANDARD.
Escalate on new semantic risk; de-escalate only when evidence removes it.

Compile exactly one Active Plan Contract and send the identical block to
Planner and every Plan-Reviewer instance:

```text
Active Plan Contract:
- Contract id:
- Mode: LIGHT | STANDARD | THOROUGH
- Always-required rows:
- Mode-required rows:
- Trigger-required rows:
- Explicitly-not-applicable high-risk ambiguity:
- Reviewer entitlement: only active rows may create missing-field blockers
```

```text
ALWAYS for plans -> direction_acceptance; minimal_scope_trace; core_evidence;
                    execution_handoff.
STANDARD|THOROUGH -> simplicity_justification; process_and_diff_budget.
behavior or named regression/safety risk -> detailed_test_design.
planning roles/review -> planning_role_evidence.
LIGHT without review -> compact no-review reason.
THOROUGH or operational/migration/public risk -> rollout_recovery.
open greenfield stack plus recommendation -> stack_options.
measurable evidence affects a decision -> validation_check.
non-inline agent policy -> parallel_dispatch.
every named risk that changes mode, review topology, rollout/recovery, or
verification -> risk_semantics for that fired risk.
named THOROUGH paired risk -> cross_host_review.
```

Inactive rows MUST be omitted. Do not emit exhaustive `not applicable` fields.
Use `Explicitly not applicable` only to resolve an ambiguous high-risk trigger.

`process_and_diff_budget` bounds expected file/surface groups, handwritten
change size, focused verification, broad-suite cap, and qualitative
rescope/escalation conditions. A wrong estimate does not override evidence.

### S3 — PLANNER_DRAFT

Planner is required. It receives the exact requirements source, Analyst result,
repository evidence, Direction Contract, Active Plan Contract, and active gate
inputs.

Output: plan path, draft v1, complete active body, approval status, and open
decisions/blockers.

Planner keeps one canonical body, smallest AC-sufficient approach, ordered
AC-mapped tasks, real contract surfaces, visible uncertainty, requirement-backed
complexity, one execution profile, and unchanged Direction Contract/AC IDs.

Planner MUST NOT implement production changes or write outside `.oh-no/plans/`.

No Plan-Reviewer may start before the complete `Planner draft v1` exists.

### S4 — PLAN_REVIEW

```text
LIGHT -> review may be omitted with one concrete risk-based reason.
STANDARD -> exactly one Plan-Reviewer.
THOROUGH -> one Plan-Reviewer unless a named paired risk fires.
Named paired risk -> section 8. Host availability alone creates no pair.
Omitted LIGHT review -> record reason; freeze Planner v1; go to PLAN_PERSIST.
```

Each Reviewer receives the exact contract, draft id, and full draft/durable
path, then performs two ordered passes in one role context:

```text
PASS 1 — ARCHITECTURE
- feasibility/ownership/sequence/coupling/failure; real contract surface;
  smallest sufficient approach; active risk/recovery/profile consistency.

PASS 2 — QUALITY_GATE
- challenge pass-1 severity; AC/scope/proof/direction; shallow or wrong-surface
  tests; inactive ceremony, optional-proof inflation, speculative process.
```

Material-blocker predicate:

```text
A finding is BLOCKING only when its smallest sufficient correction prevents
material failure of an active AC, approved constraint, safety invariant,
Direction Contract field, public contract, or fired mandatory gate.

Preference, future-proofing, generic best practice, and optional stronger proof
are NON-BLOCKING.
```

```text
Blocker = basis <AC|constraint|safety|Direction|public contract|fired gate>;
exact draft pointer; material consequence; smallest sufficient correction;
and for gates: owner, trigger, failed obligation.
```

```text
Reviewed draft: vN; Verdict: APPROVE | ITERATE | REJECT
Architecture findings: <list|none>; Quality-gate findings: <list|none>
Direction preservation: preserved | requested-direction-change: yes
Required changes for Planner: <list|none>
```

Review v1 returns one consolidated set of currently known blockers. It MUST NOT
knowingly reserve blockers for v2.

### S5 — REVISION_OR_FREEZE

Verdict transition table:

| Verdict | Required transition |
|---|---|
| `APPROVE` | Freeze the exact reviewed draft. Non-blocking findings become optional follow-ups. Go to `PLAN_PERSIST`. |
| `ITERATE` | Planner performs disposition before any mutation. Follow `## 10. REVISION PROTOCOL`. |
| `REJECT` | Escalate immediately for user direction. Do not consume a review loop. STOP. |

```text
Any required body change invalidates APPROVE. A post-APPROVE user change starts
a new run; reuse the source only if direction, ACs, and scope are unchanged.
```

### S6 — PLAN_PERSIST

Write the final plan to `.oh-no/plans/{slug}.md`; transient notes use the
existing `.oh-no/sessions/{sessionId}/planning.md` when available. Every
placeholder is one sanitized path segment; resolve beneath its designated
`.oh-no` subtree and refuse traversal, outside paths, or unsafe overwrite.

The final plan MUST contain:

```text
Header:
- Next skill; approval; requirements source; Planner draft id;
  reviewed draft id or LIGHT no-review reason.

Body, in order:
1. Direction Contract
2. Goal/scope/non-goals/constraints; ACs and success signals
3. Smallest approach and affected contract surfaces
4. Ordered AC-mapped tasks and key files/modules
5. Active test/evidence design
6. Execution profile
7. Active risk/rollout/recovery
8. Open decisions/blockers/waivers; compact role/findings evidence
```

The plan body is canonical. Findings Ledger and Plan Approval Brief reference or
summarize it; they MUST NOT create a second plan schema.

### S7 — APPROVAL_HANDOFF

Apply either direct Ralplan or Ultrawork behavior. Never blend them.

Direct behavior is defined in `## 15. DIRECT APPROVAL HANDOFF`.
Ultrawork behavior is defined in `## 16. ULTRAWORK INTERNAL APPROVAL`.

## 5. EXECUTION PROFILE CONTRACT

Ralplan owns the authoritative Ralph execution profile. Include exactly one:

```text
Execution profile:
- Overall Ralph mode: LIGHT | STANDARD | THOROUGH
- Mode source: ralplan
- Verification tier: LIGHT | STANDARD | THOROUGH
- Artifact policy: compact | session-verification | full-prd-session
- Agent policy: inline-only | targeted-subagents | full-review-set
- Parallel trigger: approved-plan-handoff | explicit-user-request | natural-dispatch | none
- Worktree policy: direct-automatic-worktree | automatic-worktree-merge | not-applicable
- Worktree location: .oh-no/worktrees/<task-slug> | not-applicable
- Cleanup policy: not-needed | conditional | required
- Task sizing: T1 <mode> - <reason>; ...
- Escalation triggers:
```

Selection rules:

```text
Verification tier -> lightest tier proving all ACs and named risks.
Artifact policy -> compact for bounded LIGHT; session-verification when durable
  evidence/resume is useful; full-prd-session for multi-story THOROUGH work.
Agent policy -> inline-only without an isolable decision-changing role;
  targeted-subagents when such roles exist; full-review-set only for named risk.
Parallel trigger -> actual authorization source; none when inline-only.
Worktree policy -> direct Ralph write: direct-automatic-worktree;
  Ultrawork write: automatic-worktree-merge; read-only/planning: not-applicable.
Cleanup -> not-needed without production cleanup; conditional when candidates
  may exist; required only for named safety/broad-change risk.
Task sizing -> local semantic risk; overall mode equals the highest task mode.
```

`approved-plan-handoff` requires at least one role with safe isolation,
decision-changing value, and reasonable coordination cost. Any non-inline plan
names scopes, dependencies, expected output, and integration owner. Ralplan
records policy, not execution mechanics;
Ralph/Ultrawork owns the actual decision and must receive the exact approved
plan with provenance.

## 6. PLAN CONTENT QUALITY

Every task MUST map work and evidence to an active AC. Tests, review, metrics,
and commands are evidence, not replacement outcomes.

Behavior-changing task shape:

```text
1. RED: one case that fails against old or wrong-surface behavior.
2. GREEN: the smallest implementation expected to satisfy the AC.
3. REFACTOR: allowed only after GREEN.
4. VERIFY: focused evidence mapped to the AC.
```

Add negative/edge/regression cases only for an AC or named risk. Reject tests
that pass old behavior, miss the real contract surface, assert only status/
markers/mocks, use non-semantic broad snapshots, or build product-like proof
machinery.

When no meaningful old-behavior RED can exist, record one compact TDD exception
and the direct semantic evidence replacing it.

Verification tier minimums:

```text
LIGHT: inspect the changed surface; run syntax/format/scope checks and the
smallest direct proof of each AC.

STANDARD: LIGHT plus focused semantic tests mapped to ACs, RED/GREEN or a
recorded exception, risk-activated negative/regression cases, and a relevant
baseline check.

THOROUGH: STANDARD plus the integration, migration, smoke, end-to-end,
recovery, or adversarial evidence required by each named risk; record residual
risk and any proof that cannot be run locally.
```

When measurable evidence changes mode/scope/risk/verification, record source,
outcome, proof, gap, recurring risk, similar-work relevance, and collection
cost. Metrics never replace an AC or semantic proof.

For an open greenfield stack recommendation, include enough viable options to
expose the decision, relevant tradeoffs, one default, and the assumption that
would change it.

## 7. ROLE DISPATCH CONTRACT

Roles: `explore` gathers facts; `analyst` finds requirement gaps; `planner` owns
body/dispositions; `plan-reviewer` owns exact-draft review/verdict.

Ordering:

```text
explore may precede requirements analysis
analyst or approved-spec satisfaction
  -> planner v1
  -> plan-reviewer v1
  -> planner v2 only after accepted blocker dispositions
  -> plan-reviewer v2 delta closure, or full only under section 10
```

- Analyst, Planner, and Reviewer are sequential. Only a named THOROUGH Reviewer
  pair may overlap, after the exact draft exists.
- Use real role contexts when permitted and the role has a concrete artifact,
  isolated responsibility, and decision-changing output; otherwise preserve a
  separate inline role block and its fallback reason.
- Dispatch results are dependencies: wait, capture, use. Timeout/empty is not
  completion; do not redo pending scope. Invocation syntax stays in the adapter.

Ownership boundary:

```text
Ralplan owns plan-reviewer.
Ralph execution owns code-reviewer and verifier.
Plan-reviewer MUST NOT be reused for implementation completion, post-fix review,
debugging review, or final acceptance verification.
```

## 8. PAIRED REVIEW CONTRACT

Paired review requires a named THOROUGH risk whose independent second review can
materially change the verdict. Default mode permits fallback; only an explicit
user or approved requirement selects `require-cross-host`.

```text
- same role, exact draft, complete two-pass review per instance
- caller deduplicates into one APPROVE/ITERATE/REJECT verdict
- default: same-host parallel fallback if opposite host is unavailable
- require-cross-host: unavailable opposite host blocks
- reviewer instances make no additional cross-host hop
- record topology and fallback reason
```

Paired review does not change the Analyst -> Planner -> Plan-Reviewer sequence.

## 9. FINDINGS LEDGER

Record one compact ledger:

```text
Findings Ledger:
- Context: <source>; <contract id>; <dispatch trigger>; <ordered roles/ids>;
  <review topology/trigger>; <reviewed draft>
- Findings:
  - <id>; <owner>; <blocking|non-blocking>; <basis if blocking>;
    <draft pointer>; <consequence>; <smallest correction>;
    <accepted|rejected|deferred|direction-change|waived>; <plan pointer>
- Re-review/freeze: <not-required|delta|full>; <status>
```

Do not advance with a user-pending disposition, pending non-waivable gate,
unreflected accepted blocker, draft-id mismatch, or invalid review topology.

## 10. REVISION PROTOCOL

On `ITERATE`, Planner MUST classify every blocker before changing the draft.

```text
IF all blockers are accepted:
  create one v2 containing every accepted correction;
  run one delta closure review.

IF any blocker is rejected, deferred, direction-changing, or mixed:
  emit a disposition-only user-decision packet; keep pending;
  no partial v2/review v2 until every non-accepted disposition resolves.

IF valid waivers require no body change:
  only the user may approve a blocking waiver;
  freeze the unchanged reviewed draft with waivers visible;
  go to PLAN_PERSIST without v2/review v2.

IF a non-waivable gate failed:
  prohibit execution until its obligation passes or direction changes.

IF direction changes:
  update the requirements source;
  start a new planning run;
  do not consume the old run's closure review.
```

Review v2 receives the full plan but closes prior dispositions, changed sections,
and affected dependencies. Full review requires named material change to
direction/scope, architecture/ownership, public contract, safety/data, or proof.

A new v2 blocker requires `Why first raised now`; revision defects/material v1
misses may still block.

```text
Loop 1 = Planner v1 + Review v1
Loop 2 = Planner v2 + Review v2
```

REJECT consumes no loop. After loop 2 without APPROVE, STOP for explicit user
direction.

## 11. DIRECTION PRESERVATION

The smallest correction required by an AC, constraint, safety invariant, public
contract, or fired gate stays inside direction. New product scope; changed goal,
non-goal, AC, constraint, assumption, public behavior, or delivery outcome;
unrequired process machinery; and preference-driven stack/architecture
replacement require `requested-direction-change: yes` and explicit approval.

Do not incorporate a requested direction change into the current draft before
approval. Start a new planning run after approval.

## 12. PLAN APPROVAL BRIEF

```text
Approval brief = path/status; goal/scope/non-goals; AC-mapped tasks/key files;
smallest approach; active test/stack/evidence/risk decisions; topology/verdict/
blockers/waivers/follow-ups; execution profile; open decisions/risks.
```

LIGHT still preserves goal, scope/non-goals, ACs, tasks/key files, verification,
compact profile, review-omission reason, and approval status.

## 13. PAUSE AND STOP CONDITIONS

`STOP` means set `PAUSED`, report the blocked transition/evidence/unblock
condition, and await user or dependency resolution; it is not silent exit.

Set `PAUSED` for: invalid/contradictory requirements; unresolved direction;
missing required host primitive with no fallback; missing Planner draft or
required Reviewer; user-pending disposition; pending non-waivable gate; two
loops without APPROVE; missing/inconsistent profile; explicit stop/manual
review; or an Ultrawork pause condition.

## 14. ARTIFACT AND DATA SAFETY

Redact secrets/PII/raw data; never inspect credentials for examples. Ralplan
edits no production files and creates no hidden state, daemons, keyword modes,
or background automation. Durable state is visible Markdown under `.oh-no/`.

## 15. DIRECT APPROVAL HANDOFF

<HARD-GATE>
For direct Ralplan, do NOT invoke Ralph, Ultrawork, or any other workflow after
presenting the plan until the user explicitly approves the plan and selects an
approve-and-run action.
</HARD-GATE>

Set `pending-approval`. End with exactly one combined choice:

```text
1. approve-and-run Ralph — approve this plan and execute it with the recorded profile
2. approve-and-run Ultrawork — approve this plan and continue end-to-end orchestration
3. request plan changes — invalidate the current approval freeze and revise/review again
4. leave the plan pending — invoke no workflow
```

End the question with `Which approach?`.

Approve-and-run sets `approved-direct`, hands off the exact plan/profile, and
sets Ralplan `COMPLETE`; Ralph preserves `approved-plan-handoff`.

On request plan changes, return to Planner under the APPROVE invalidation rule.
On leave pending, set `PAUSED` with no workflow invocation.

## 16. ULTRAWORK INTERNAL APPROVAL

For `ultrawork`, omit direct approval only when the source is approved/concrete,
direction is preserved, Planner/review passed, the exact draft is frozen, the
profile is complete, and no unresolved disposition/non-waivable gate remains.

Record:

```text
Plan approval source: ultrawork automatic approval after interview/spec
Approval status: approved-ultrawork
```

Set Ralplan `COMPLETE` and return control to Ultrawork. Changed scope/direction,
product ambiguity, requirements conflict, missing profile, unresolved
blocker/gate, or manual review pauses. Automatic approval replaces only the
direct prompt; it skips no requirements, role, review, direction, or profile
gate.

## 17. OUTPUT CONTRACT

Return run/source/Analyst; plan/contract/mode/draft; topology/verdict/ledger;
execution profile/approval brief; approval and next-skill or pause reason.

Final compliance check:

```text
[ ] Source/direction/identical Active Plan Contract are explicit.
[ ] Planner owns mutation; Reviewer used exact draft/topology/blocker predicate.
[ ] Corrections are reflected; APPROVE freeze/non-blocking rules held.
[ ] At most two loops; reachable plan and complete profile exist.
[ ] Direct approval is pending/explicit or Ultrawork approval is valid.
```
