---
name: ralplan
description: Use when requirements are sufficiently known but implementation is broad, risky, architecture-sensitive, cross-file, multi-step, or strategy-unclear and needs a plan; not for still-vague discovery or an execution-ready task.
argument-hint: "<task, spec path, or plan request>"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Ralplan for Claude Code

This generated file is the Claude Code-facing runtime skill document. Claude Code slash commands should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/ralplan.md`
- `../../docs/platforms/claude-code-ralplan.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/ralplan.md

# Ralplan

Ralplan converts approved requirements plus repository evidence into one
reviewed plan and Ralph execution profile. It never implements production
code and writes only under `.oh-no/`. Plan-Reviewer depth and instance count
are selected by the execution risk, not applied as an unconditional tax.

Interpret `MUST`, `MUST NOT`, `ONLY`, and `STOP` literally.

## Invariants

```text
R1. Requirements direction is user-owned. A role proposal that changes the
    Direction Contract is `requested-direction-change: yes` and needs explicit
    user approval; do not incorporate a requested direction change without
    explicit approval. An approved change starts a new planning run.
R2. The plan body is Planner-owned. Plan-Reviewer reviews and blocks; it MUST
    NOT produce a replacement plan.
R3. Plan-Reviewer reviews the exact Planner draft (id + body), not a recap:
    architecture pass, then quality-gate pass, in one dispatch.
R4. APPROVE freezes the exact reviewed Planner draft. Non-blocking findings
    are optional follow-ups and cause no mutation or dispatch; a body change
    required before approval is blocking and yields ITERATE.
R5. On ITERATE, Planner classifies every blocker before mutating the draft or
    assigning a new draft id (disposition-before-mutation).
R6. Review runs exactly once (Review v1) per planning run. REJECT escalates
    immediately. An all-accepted ITERATE yields exactly one final Planner
    revision v2 with no further review.
R8. Every blocker names a basis, exact draft pointer, material consequence,
    and smallest sufficient correction. Preference, future-proofing, and
    optional stronger proof are non-blocking.
R9. Roles are sequential — Analyst -> Planner -> Plan-Reviewer.
    Every dispatched Plan-Reviewer review runs as one perspective-diverse pair;
    the named THOROUGH trigger selects only the
    platform's escalated diversity (cross-host on Codex).
R10. Active semantic risk selects mode and cost; category words and host
     capability alone never escalate.
R15. The Active plan contract is compiled once before Planner draft v1, and
     the identical block goes to Planner and every reviewer instance.
     Reviewer missing-field blocking is limited to its active rows.
R16. Recorded snapshot state authorizes transitions; unrecorded in-memory
     conclusions do not.
```

Conflict priority, highest first: user decision > requirements/Direction
Contract > Active Plan Contract > fired gate > exact draft > role findings.
Record the conflict and STOP; never infer direction.

`STOP` means: set outcome `PAUSED`, persist the snapshot with the blocked
transition and unblock condition, and report — never a silent exit.

## Planning Run Snapshot

Maintain one snapshot at `.oh-no/sessions/{sessionId}/planning.md` (reuse the
chain session directory when one exists; otherwise create a timestamped one).
Persist it at every phase change, verdict, disposition, approval change, and
before any pause or handoff [R16].

```text
Planning run:
- Run/type: <id>; <direct-ralplan | ultrawork>
- Phase: ROUTE | REQUIREMENTS | DRAFT | REVIEW | APPROVAL
- Outcome: none | ROUTED_INTERVIEW | ROUTED_RALPH | HANDOFF_RALPH |
  HANDOFF_ULTRAWORK | RETURN_ULTRAWORK | PAUSED
- Mode: LIGHT | STANDARD | THOROUGH
- Source/Analyst: <path or summary>; <satisfied-by-spec | completed | gap-check | blocked>
- Draft/plan: v<N>; .oh-no/plans/<slug>.md
- Review: not-run | done; <topology>; <verdict>; <blockers + dispositions>
- Approval: pending approval | approved-direct | approved-ultrawork
```

## State Machine

| Phase | Exit guard | Next |
|---|---|---|
| ROUTE | intent, scope, or acceptance criteria materially unclear | outcome ROUTED_INTERVIEW |
| ROUTE | single obvious edit with clear acceptance criteria and no planning decision | outcome ROUTED_RALPH |
| ROUTE | plannable request | REQUIREMENTS |
| REQUIREMENTS | source, Analyst status, Direction Contract, mode, and Active plan contract recorded [R10, R15] | DRAFT |
| REQUIREMENTS | gap changes product intent, architecture, data, security, or delivery scope [R1] | PAUSED for user decision |
| DRAFT | Planner draft v1 complete against the Active Plan Contract [R2] | REVIEW |
| DRAFT | Planner revision v2 complete with finding→fix mapping recorded [R2, R5, R6] | APPROVAL (no further review) |
| REVIEW | LIGHT no-review reason recorded, or verdict APPROVE [R4] | APPROVAL |
| REVIEW | a required Plan-Reviewer has no separate context after allowed fallback (`dispatch-unavailable`) | PAUSED |
| REVIEW | ITERATE with all blockers accepted [R5, R6] | DRAFT (final revision v2) |
| REVIEW | ITERATE with rejected/deferred/direction-change disposition [R5] | PAUSED for user decision |
| REVIEW | user resolved every non-accepted disposition as a permitted waiver with no body change: reviewed draft stays frozen [R4, R5] | APPROVAL |
| REVIEW | REJECT [R6] | PAUSED |
| APPROVAL | per `## Next Skill Handoff` (direct) or `### Ultrawork exception` | outcome per that section |

On resume after a disposition PAUSED, apply the `## Planner Revision
Contract` branch matrix: accepted corrections re-enter DRAFT; waiver-only
resolution enters APPROVAL with the waivers visible.

Routing outcomes recommend the named skill and stop; they never auto-invoke
it. A direction change in any phase follows R1.

## Requirements Source And Analyst Gate

Source priority: approved `interview` spec > approved PRD/issue/ticket >
current user request plus repository evidence.

Dispatch `explore` first when repository facts are needed — one subagent per
independent subsystem (up to 5), batched. Exploration replaces no role.

If an approved spec covers goal, scope, non-goals, constraints, risks, and
acceptance criteria, record `Analyst: satisfied by approved interview spec`
with `Gap check: none blocking`; otherwise run `analyst` (or a limited gap
check) before Planner — one `analyst` per independent requirement or risk area (up to 5), batched, when gaps span independent areas. Analyst output feeds the Planner draft; it never
replaces it.

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

Preserve the user's actual success criteria: a test, suite, metric, or local
command is supporting evidence, not a replacement outcome. If criteria
conflict or direction-changing facts remain inferred, mark the plan pending
instead of hiding the gap.

## Mode Selection

Phase: REQUIREMENTS — record the mode before leaving the phase.

Select the lightest credible mode [R10]:

```text
LIGHT    = work that qualifies under Ralph's canonical `LIGHT Eligibility —
           Risk Gate, Soft Size Screen`: risk-gated localized behavior or
           non-behavior work clearing its complete exclusion UNION and bounded-
           judgment inclusion conditions; size may veto, never grant, LIGHT.
STANDARD = bounded behavior/config/prompt work with localized blast radius,
           known ownership, and no THOROUGH trigger.
THOROUGH = active security/data/auth/permission, destructive,
           public/release-critical, migration, changed concurrency/lifecycle,
           multi-system, high-uncertainty, or difficult-recovery risk.
```

Any THOROUGH trigger wins; otherwise apply Ralph's complete canonical LIGHT
predicate before defaulting to STANDARD. A localized low-risk behavior change,
including cohesive multi-file work, may qualify, while a large or sprawling
change routes out to STANDARD under Ralph's canonical soft screen.
Escalate on new semantic risk; de-escalate only when evidence removes it.
Reusing a verified concurrency owner, or mechanical regeneration of validated
generated wrappers, is not a THOROUGH signal by itself. Note when the task may
fit Ralph's STANDARD small-task carve-out so Ralph can evaluate it.

## Active Plan Contract

Phase: REQUIREMENTS — compile before leaving the phase; consumed in DRAFT
and REVIEW.

Compile one mode- and trigger-aware block and send the identical block to
Planner and every Plan-Reviewer instance [R15]:

```text
Active plan contract:
- Mode: LIGHT | STANDARD | THOROUGH
- Always required: <active rows below>
- Mode-required: <only rows active for this mode>
- Trigger-required: <only rows whose named trigger fired>
- Explicitly not applicable: <only an ambiguous high-risk trigger worth disambiguating>
- Reviewer entitlement: missing-field blocking is limited to the active fields above
```

Canonical activation table:

| Row | Activation | Plan projection | Reviewer entitlement |
|---|---|---|---|
| Direction and acceptance core | always | Direction Contract; success ownership/signals; confidence | contradiction, missing observable success, or unresolved direction-changing inference |
| Minimal scope trace | always | smallest approach; affected files and contract-surface uncertainty; ordered AC-mapped tasks | infeasible order, wrong surface, unmapped work, or scope beyond the smallest AC-sufficient change |
| Core evidence | always | smallest verification and TDD applicability; AC-to-evidence mapping | material proof hole only; stronger optional proof is non-blocking |
| Execution handoff | implementation plan | next skill with compact profile and worktree policy; risks/open decisions | unsafe or inconsistent handoff; LIGHT stays compact |
| Simplicity justification | STANDARD or THOROUGH | rejected speculative complexity; justification for new abstraction or dependency | current-scope speculative complexity only |
| Detailed test design | behavior change or named regression/safety risk | must-fail/must-pass; relevant negative or adversarial cases only | missing relevant case; inactive categories omitted |
| Process and diff budget | STANDARD or THOROUGH | expected handwritten scope; broad-suite cap and rescope threshold | concrete budget violation, not an unfired larger process |
| Planning-role evidence | selected roles/review, or LIGHT no-review | role/review order, ids, topology, dispositions, or one compact LIGHT no-review reason | evidence for roles that ran only |
| Rollout/recovery | THOROUGH or operational/migration/public-contract risk | smallest safe rollout; rollback boundary | only when named risk makes recovery material |
| Stack options | greenfield + open stack + recommendation requested | 2-3 options, tradeoffs, default, decision-changing assumption | never required without the trigger |
| Validation check | measurable evidence influenced request | evidence source, supported AC, proof and gap | never required without the trigger |
| Parallel dispatch | agent policy not `inline-only` | eligible roles/scopes and dependencies; integration owner | inline-only needs only its profile value |
| Risk semantics | migration, data/security/destructive, concurrency/lifecycle, or public/release trigger | semantics/evidence for the fired trigger | depth/gates limited to named trigger and owner |
| Paired review | named THOROUGH paired-review trigger | trigger, platform-defined diversity mode, and synthesis evidence | never required in STANDARD or without trigger |

Audited deduplicated baseline caps: LIGHT=11; STANDARD=24; THOROUGH=26.
Inactive rows are omitted — do not emit `not applicable` ceremony. The
validator derives fixture counts from active projections and rejects growth.

When `Recommendation requested` is `yes`, present 2-3 viable technology
stacks, their tradeoffs and one recommended default; the recommendation
requires approval through the existing Plan Approval Brief before Ralph.

## Planner Draft Contract

Planner owns `Planner draft v1` and the plan body. Send it the requirements
source, Analyst status, repository evidence, and the exact Active plan
contract. Planner returns role metadata plus the plan body with active fields
only. The plan body is the single canonical schema; ledger and brief
reference it. Plan-Reviewer reviews that exact draft, not a recap [R3]. No
reviewer starts before the complete draft exists.

## Plan Review Contract

Plan-Reviewer receives the exact Active plan contract, draft id, and full
draft or path, then runs the architecture pass and the quality-gate pass in
one dispatch [R3]. Every required Plan-Reviewer pass runs in a separate
context. If the named role is unavailable, use a generic separate subagent or
the active platform's default pair fallback. If no separate context exists,
record `Plan-Reviewer: dispatch-unavailable` as a blocker and transition to
PAUSED; an inline review cannot satisfy the required pass. The compliant LIGHT
no-review carve-out remains unchanged.

Topology by mode:

```text
LIGHT    -> review may be omitted with one concrete risk-based reason.
STANDARD -> one perspective-diverse Plan-Reviewer pair: two instances of the
            same role, each running the full two-pass review with one distinct
            assigned perspective (Lens A strongest-antithesis/feasibility-risk;
            Lens B acceptance-coverage/quality-gate completeness), packets
            identical except the single `Assigned perspective:` line,
            dispatched in one parallel batch and synthesized into one verdict
            by the caller. The active platform supplies the diversity leg;
            unavailable diversity in default mode falls back to two independent
            same-model instances with the reason recorded; explicit diversity
            demand is strict mode and transitions to PAUSED.
THOROUGH -> the same perspective-diverse pair; a named security/data/
            destructive, public/release-contract, concurrency, migration, or
            comparable multi-system trigger additionally selects the platform's
            escalated diversity (cross-host pair on Codex).
```

Worst-case THOROUGH role dispatch chain remains bounded to one review round.

Blocker predicate [R8]:

- A finding is BLOCKING only when its smallest sufficient correction
  prevents material failure of an active AC, approved constraint, safety
  invariant, Direction Contract field, public contract, or fired mandatory
  gate. Unsupported false rejection is a contract failure.
- Every blocker names one
  `Blocking basis: <AC ID | safety invariant | Direction Contract field | applicable mandatory gate>`,
  the exact draft pointer, material consequence, and smallest sufficient
  correction; a gate blocker also names its owner, trigger, and failed
  obligation.
- Review v1 returns one consolidated blocker set and MUST NOT knowingly
  reserve any blocker; there is no second review round.

Return shape:

```text
Reviewed draft: v<N>
Verdict: APPROVE | ITERATE | REJECT
Architecture findings: <list | none>; Quality-gate findings: <list | none>
Direction preservation: preserved | requested-direction-change: yes
Required changes for Planner: <list | none>
```

Verdict consequences are R4 verbatim: APPROVE freezes the exact reviewed
Planner draft; Non-blocking findings are optional follow-ups; Any plan-body
change that must be incorporated before approval is blocking and yields
ITERATE.

## Planner Revision Contract

On ITERATE, Planner first classifies every blocker as `accepted`,
`rejected`, `deferred`, or `direction-change` [R5]. A disposition-only
user-decision packet carries the original finding, basis, pointer,
consequence, smallest correction, and Planner reason. Branch matrix:

- All accepted: create exactly one final Planner revision v2; run no further review — the Plan Approval Brief surfaces each accepted finding→fix mapping for the user.
- Any rejected: return the disposition-only user-decision packet; create no v2 until the user resolves it.
- Any deferred: leave the plan pending in the disposition-only user-decision packet; create no v2.
- Mixed: resolve every non-accepted blocker before exactly one v2.
- Permitted waivers with no body change: keep the waivers visible; create no v2.
- Non-waivable gate: keep the plan pending and prohibit execution until its owner-defined obligation passes or direction changes.
- Direction change: update the requirements source, start a new planning run.

For each accepted blocker, the final v2 plan body records the finding id,
basis, applied change, and body section pointer. Accepted changes must appear
in the plan body; ledger-only comments are not a valid revision. After v2-final,
proceed directly to APPROVAL; the Plan Approval Brief carries the per-blocker
finding→fix mapping and the user judges.

## Findings Ledger Gate

Record in the snapshot: selected roles and ids in order, topology and named
trigger, each finding with reviewer-owned `blocking | non-blocking` severity
and its blocking basis, disposition, accepted section pointer, permitted
waiver, and `Revision: none | v2-final (finding→fix mapping in brief)`.
A required Plan-Reviewer cannot be skipped or satisfied inline; missing review
topology or `Plan-Reviewer: dispatch-unavailable` is a blocker, not a pass. Do
not advance while a user-pending disposition or non-waivable gate is open, or
accepted blocking feedback is not in the body.

## Test Case Design Quality

For a behavior change, start with one must-fail-before-implementation case
and one must-pass-after-implementation case; the RED case must fail against
the old broken behavior. Add a negative or forbidden-behavior case,
semantic/adversarial case, or edge, boundary, or regression case only when an
AC or named risk activates it. Reject tests that would pass old or
wrong-surface behavior, only check marker strings, snapshot broad output, or
mock away the contract; do not build a product-like state machine or fixture
system solely for proof. A TDD exception explains why RED/GREEN is not
practical.

## Execution Profile

Ralplan owns the authoritative Ralph execution profile.
It owns verification tier. Keep exactly one complete profile in the plan:

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

For repository work-product mutation, `Agent policy: inline-only` is valid
only for a recorded LIGHT-tiny execution or when the execution host cannot
dispatch and Ralph must record that fallback. STANDARD/THOROUGH repository
work-product mutation plans select
`targeted-subagents` or `full-review-set` so executor ownership survives even
when `Parallel trigger: none`; `none` means no concurrent batch, not inline
mutation. Ralplan plans this ownership while Ralph remains the execution
orchestrator and `.oh-no` state owner.

Dispatch-eligibility test (canonical; other sections reference it): a role
qualifies for parallel dispatch only with safe isolation, decision-changing
value, and reasonable coordination cost. Record `Parallel trigger:
approved-plan-handoff` only when at least one isolated role passes it;
otherwise record `none` while preserving the mode-required sequential executor
policy above. Ralplan records worktree policy; Ralph owns the actual worktree
decision.

## Plan File Requirements

Save the final plan to `.oh-no/plans/{slug}.md` with a
`Next skill: oh-no-harness:<name>` header field, this plan identity block,
approval status, the Direction Contract as its first section, and the
complete active plan body:

```text
Plan identity:
- Planner draft id: v<N>
- Reviewed draft id: v<N> | not-reviewed (LIGHT: <reason>)
- Approval status: pending approval | approved-direct | approved-ultrawork
- Approval source: user approve-and-run | ultrawork automatic approval | none
```

Compact LIGHT plans must still preserve goal, scope, non-goals, acceptance criteria, tasks, key files, verification, compact execution profile, and approval status; they may omit inactive review, process, dispatch, risk, and rollout ceremony. Dispatch detail appears only for roles passing the dispatch-eligibility test in `## Execution Profile`.

## Plan Approval Brief

After consensus, show a decision-critical projection: path/status;
goal/scope; tasks/key files; AC alignment; smallest approach and rejected
complexity; active stack/validation/test/rollout decisions; review summary
with unresolved blockers/waivers; when a v2 exists, per-blocker finding→fix
mapping with body pointers and any permitted waivers; worktree/dispatch
handoff; verification; risks/open decisions; one compact execution-profile
recap. Omit inactive sections. Compact LIGHT preserves the same items `## Plan File Requirements`
lists for compact LIGHT plans. When dispatch is active, recap only
roles/scopes passing the dispatch-eligibility test in
`## Execution Profile`.

## Next Skill Handoff

<HARD-GATE>
Do NOT invoke `ralph`, `ultrawork`, or any other workflow skill after
presenting the plan until the user has explicitly approved the plan AND
chosen the next step. Skill chaining is approval-gated, not automatic.
</HARD-GATE>

The Plan Approval Brief ends with exactly one combined choice:

- approve-and-run Ralph (recommended) — approve the plan and execute it
  task-by-task with Ralph as orchestrator, mode-required executor ownership for
  repository work-product mutation, and eligible isolated subagents when they
  add decision-changing evidence, plus verification, review, cleanup, and final
  report. The ordinary `oh-no-harness:ralph` choice preserves the plan path and
  the exact frozen `Parallel trigger` value. When that value is
  `approved-plan-handoff`, Ralph treats the approved dispatch plan as
  authorization for every eligible isolated role; `none` preserves sequential
  executor ownership without authorizing a concurrent batch.
- approve-and-run Ultrawork — approve the plan and orchestrate execution,
  QA, and final validation end-to-end
- request plan changes — after a v2-final, start a NEW one-round planning run
  with a fresh run id and fresh Review v1; never create an unreviewed v3 inside
  the current run. Otherwise revise the plan, invalidate the approval freeze,
  and re-present the brief
- leave the plan pending — keep the plan unapproved and invoke no workflow

End the question with `Which approach?`. The plan stays `pending approval`
until an approve-and-run choice is explicit; the user is approving the host
agent's next action, not being asked to run a command. On approve-and-run,
set `approved-direct`, hand off the exact frozen plan and profile, and set
outcome HANDOFF_RALPH or HANDOFF_ULTRAWORK. On leave pending, set outcome
PAUSED with no workflow invoked.

### Ultrawork exception

If invoked from `ultrawork`, skip the user-facing brief. Complete the same
planning gates, write the plan plus
`Plan approval source: ultrawork automatic approval after interview/spec`,
set `approved-ultrawork`, and return control (outcome RETURN_ULTRAWORK).
Pause for the user only on: changed approved scope, a blocking product
decision or ambiguity, conflict with the approved requirements source,
missing execution profile, any unresolved rejected/deferred/direction-change
blocker, a pending non-waivable gate, an explicit manual-review request, or a
review verdict of ITERATE: a v2-final revision requires explicit user approval
of its finding→fix mapping; automatic approval covers only a zero-blocker
APPROVE path. Automatic approval never accepts a v2-final on the user's behalf,
because the mapping replaces the deleted closure review. Automatic approval
replaces only the prompt; it skips no gate.

## Agent Roles

Dispatch planning roles as real subagents by default on subagent-capable
hosts, per the active platform adapter. Dispatch is the quality mechanism,
not an optimization: it keeps exploration noise and draft production out of
the main context, and Plan-Reviewer independence requires a separate context
— a same-context review self-confirms its own plan. Keep sequential role
boundaries [R9].

Optional roles retain recorded inline fallback when the host cannot dispatch
subagents, host policy does not authorize dispatch, or the role lacks a concrete
input artifact, isolated responsibility, or expected output — keep a visibly
separate inline role block and record the reason. A required Plan-Reviewer is
the exception: it must use a separate context, with a generic separate subagent
or the active platform's default pair fallback when the named role is
unavailable; if none exists, record the blocker and transition PAUSED instead
of reviewing inline. Record the trigger as `Planning dispatch:
natural-dispatch`, `explicit-user-request`, or `inline-fallback`.

| Agent | Dispatch (when) |
|---|---|
| `explore` | repository facts needed; one per independent subsystem (up to 5), batched |
| `analyst` | requirements gaps, unless satisfied by an approved interview spec; one per independent requirement or risk area (up to 5), batched |
| `planner` | creates `Planner draft v1` and the single final `Planner revision v2`; owns body and dispositions |
| `plan-reviewer` | reviews the exact draft once per `## Plan Review Contract` as a perspective-diverse pair |

Only Ralplan dispatches `plan-reviewer`; execution skills own their own
review roles.

## Output

Return: plan path; role and review-topology summary; findings ledger;
execution profile; plan approval brief; approval status; recommended next
skill or pause reason.

## Source: docs/platforms/claude-code-ralplan.md

# Ralplan Claude Code Adapter

<ADAPTER_CONTRACT>
This adapter binds the Ralplan core to Claude Code. The core owns every
semantic decision; this file owns only host invocation and lifecycle
mechanics. If they conflict, the core wins. The generated core plus this
adapter is sufficient: longer platform, shared, and agent documents are
optional maintenance context, never a runtime prerequisite.
</ADAPTER_CONTRACT>

## Host Bindings

```text
user_choice      = structured question tool when exposed; otherwise one direct
                   plain-text question and wait
native_role(r)   = plugin agent `oh-no-harness:<r>` through the exposed Task,
                   Agent, Workflow agent(), or equivalent subagent primitive;
                   manual mention form is `@agent-oh-no-harness:<r>`
roles            = explore | analyst | planner | plan-reviewer
next_skill       = invoke the installed Ralph or Ultrawork skill through the
                   host skill mechanism; never ask the user to type a command
```

Follow the active platform runtime document's dispatch policy for role
dispatch: dispatch is trigger-loaded — dispatch only after the active skill's
trigger fires. For each dispatch, send one self-contained packet containing:
run/phase; role; exact bounded task; requirements source; Direction Contract;
Active plan contract; draft id and full draft/path when applicable;
scope/non-goals; required output; and dependency/return owner. Do not assume
inherited conversation.

If the plugin agent is unavailable, use a generic subagent with the matching
`agents/<role>.md` prompt embedded. If no subagent primitive exists, optional
roles may use the core's visibly separate inline fallback. A required
Plan-Reviewer instead reports `dispatch-unavailable` to the core so the skill
records the blocker and transitions PAUSED; the adapter must not substitute an
inline pass.

## Lifecycle

Dispatch Analyst, Planner, and Plan-Reviewer only at their core phase and in
strict sequence. For a fired paired-review gate only, request both reviewer
legs before waiting. A dispatched result is a dependency: wait for final
status, capture and use the result, then clean up when the host exposes
cleanup. A notification, timeout, empty result, or queued/background
acknowledgement is not completion. Do not duplicate pending work inline.

## Model Diversity Pair

For any dispatched `plan-reviewer` pair (every dispatched review), dispatch two
same-role instances in parallel and synthesize one verdict. Both legs MUST be
requested in a single batch: issue both subagent tool calls in the same
assistant turn (or with `Background: yes` for both) BEFORE waiting on either
result; a serial dispatch-wait-dispatch sequence is not a valid pair. The two legs'
packet bodies MUST be identical except the single `Assigned perspective:` line
(Lens A on the primary leg, Lens B on the diversity leg); leg identity (`primary`
vs `diversity`) is carried ONLY by the host dispatch metadata (the description
field and the model override), never inside the packet text. Read the role's declared stored primary
and the validated secondary top-tier model from the session
`<OH_NO_MODEL_DIVERSITY>` block.

- `model-diversity-pair`: the primary leg is dispatched without a model
  override and therefore uses the concrete declared-frontmatter primary; the
  diversity leg uses an explicit NATIVE model override for the validated
  secondary. The primary must not be `host-default`, and the secondary must
  differ from the declared stored primary.
- `same-model-parallel-fallback`: when no valid diversity configuration exists,
  the declared primary cannot be applied, or the secondary override fails in
  default mode, dispatch two independent same-model `plan-reviewer` instances
  and record the reason.
- `require-model-diversity`: an explicit caller demand for diversity is strict;
  if the diversity leg is unavailable or fails, transition to PAUSED. Do not
  substitute the same-model fallback.

## Approval Handoff

Use one user interaction for the four combined choices in the core's
`## Next Skill Handoff`. After explicit approve-and-run, invoke the selected
skill yourself with the exact frozen plan and execution profile. Under
Ultrawork, return the approved artifact and control to the caller instead of
opening a second prompt.

Before every phase transition, verify: correct role identity; exact contract
and draft; final dependency result captured; paired topology valid; no
premature next-skill invocation.
