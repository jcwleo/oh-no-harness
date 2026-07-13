---
name: ralplan
description: Use when broad, risky, architecture-sensitive, cross-file, multi-step, or unclear work needs consensus implementation planning before coding.
argument-hint: "<task, spec path, or plan request>"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Ralplan for Claude Code

This generated file is the Claude Code-facing runtime skill document. Claude Code slash commands should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/ralplan.md`
- `../../docs/platforms/claude-code-runtime.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/ralplan.md

# Ralplan

Ralplan is the public consensus planning entry point.

It owns risk-gated planning and keeps planning separate from execution. Every
plan uses Analyst-or-approved-spec -> Planner ordering; Plan-Reviewer depth and
instance count are selected by the execution risk instead of being an
unconditional consensus tax. If the task is too small for planning, use
`ralph` instead; small concrete edits may qualify for Ralph's STANDARD
small-task carve-out.

## Software Development Stage

Ralplan is the design and implementation-planning stage for LLM software development.

Use it after `interview` has produced an approved spec, or when the user already gave clear requirements for a broad engineering task. Ralplan should decide scope, sequencing, file ownership, TDD expectations, verification, rollout, and risk handling before `ralph` executes.

## Goal

Create a concrete implementation plan that is drafted by Planner, reviewed by
Plan-Reviewer through both the architecture and quality-gate lenses, and revised
by Planner until every blocking finding is resolved before execution begins.
Non-blocking findings remain optional follow-ups and do not mutate the exact
reviewed draft that Plan-Reviewer approves.

The host agent operates the planning roles through the active platform runtime
document. The user does not need to pick Planner or Plan-Reviewer manually; the
user selects one combined plan approval and next workflow action, requests
changes, leaves the plan pending, or approves direction changes when a role
finds one. Ralph execution is
parallel-capable for
eligible isolated roles that can provide decision-changing evidence; do not
split the handoff into a separate "parallel Ralph" option.

## Artifacts

Use durable plan files under:

```text
.oh-no/plans/{slug}.md
```

For transient planning notes, use:

```text
.oh-no/sessions/{sessionId}/planning.md
```

Reuse the chain session directory established earlier in this run when one
exists; if there is none, use a timestamped directory under `.oh-no/sessions/`.

## When To Use

Use when:

- requirements are clear enough to plan, but the implementation path is broad
- the implementation touches several files or subsystems
- architecture tradeoffs are likely
- acceptance criteria exist but need to be mapped to tasks, tests, and evidence
- the user asks for planning before implementation
- a downstream execution skill needs a plan first

Do not use when user intent, scope, or acceptance criteria are still vague; use
`interview` first. Do not use when the task is a single obvious edit with clear
acceptance criteria.

## Required Reading

Read the always-active owners before Planner drafts. Read a triggered owner
immediately before the first gate that needs it. A path reference here is a
pointer, not a substitute for reading. If a listed file cannot be read, record
the blocker instead of proceeding past the gate that depends on it.

| Contract | Class | Trigger / timing |
|---|---|---|
| `docs/shared/execution-modes.md` | always | before the Direction Contract, budgets, and Ralph profile are written |
| `docs/shared/worktree-isolation.md` | always | before the plan records its execution-location policy |
| `docs/shared/ralph-subagent-policy.md` | triggered | before planning or recommending a dispatched role |
| `docs/shared/validation-check.md` | triggered | when measurable evidence influences the plan |
| `docs/shared/cross-host-review.md` | triggered | only when a named THOROUGH risk selects paired review |

## Required Flow

1. Dispatch `explore` subagent when repository context is needed. Exploration
   may run before the consensus loop, but it does not replace any consensus
   role. When the request spans independent subsystems, dispatch one `explore`
   subagent per subsystem in one batch instead of a single serial exploration.
2. Apply `## Requirements Source And Analyst Gate`. If an approved `interview`
   spec already covers the needed requirements, record `Analyst: satisfied by
   approved interview spec`; otherwise complete `analyst` before Planner drafts.
3. Read the always-active contracts in `## Required Reading` before drafting.
   Load each triggered contract immediately before its dependent dispatch,
   validation, or paired-review gate; do not preload it merely because the plan
   might need it later.
4. Complete `planner` to create `Planner draft v1` from the requirements source,
   Analyst or gap-check output, and repository evidence.
5. Apply `## Plan Review Contract` only after `Planner draft v1` exists.
   STANDARD uses one reviewer instance. Paired review is selected only for a
   named THOROUGH risk. LIGHT may record review as not required with a concrete
   reason.
6. On ITERATE, complete the Planner disposition pass first. Create revision v2
   only when all blockers are accepted or the user has resolved every
   rejected/deferred/direction-change disposition per `## Planner Revision
   Contract`. On REJECT, escalate immediately; REJECT does not consume a loop.
7. Re-review only on blocking findings, per `## Re-Review Rules`; otherwise
   record `Re-review: not required (no blocking findings)`.
8. Stop after at most 2 loops. If feedback would change approved requirements,
   record it as a requested direction change; if loop 2 ends without APPROVE,
   pause for explicit user direction instead of silently advancing past blocking
   review findings.
9. Save the final reflected plan under `.oh-no/plans/` with a
   `Next skill: oh-no-harness:<name>` header field.
10. For direct `ralplan`, present the plan to the user with the Plan Approval
   Brief format below. The same prompt must combine plan-content approval and
   next-skill choice: approve-and-run Ralph, approve-and-run Ultrawork, request
   plan changes, or leave the plan pending. When running under `ultrawork`,
   write the plan plus the Ultrawork internal approval record instead, unless a
   pause condition requires user review.
11. For direct `ralplan`, mark the plan `pending approval` until the user
   explicitly selects an approve-and-run option. Only invoke the selected
   workflow skill through the current platform's skill mechanism after that
   selection. Skip the user-facing approval prompt when running under
   `ultrawork`.

Use real role subagents for selected planning roles on subagent-capable hosts.
Planner and Plan-Reviewer are not decorative labels; the planning quality bar
comes from the Planner/Reviewer context separation plus the ordered two-pass
structure inside the single reviewer context (architecture lens first, then the
quality-gate lens applied to the plan and to the pass-1 findings). Run them
inline only when the platform cannot dispatch subagents, the host policy does
not authorize dispatch, or the role lacks a concrete input artifact, isolated
responsibility, or expected output. Record the inline fallback reason in the
plan.

Use the active platform runtime document's dispatch rules for Planner and
Plan-Reviewer. They are sequential, never parallel. Record the trigger as
`Planning
dispatch: natural-dispatch`, `Planning dispatch: explicit-user-request`, or
`Planning dispatch: inline-fallback`; `natural-dispatch` means
host-authorized proactive dispatch, not a weak preference to stay inline.

When a role is inline, write a separate inline role block with the draft id and
fallback reason instead of collapsing the role into the planner's narrative.

When Plan-Reviewer is selected, Analyst -> Planner -> Plan-Reviewer is the strictly sequential role order
unless Analyst is satisfied by an approved interview spec. Plan-Reviewer runs
only after the Planner draft exists. Do not run these roles in parallel.
This sequential rule governs the distinct roles. When a named THOROUGH risk
selects paired review, the two Plan-Reviewer instances may run concurrently and
be synthesized per `docs/shared/cross-host-review.md`; STANDARD does not create
the pair.

Worst-case THOROUGH role dispatch chain remains bounded to two review rounds;
STANDARD uses one reviewer per round and LIGHT may record review not required.

## Requirements Source And Analyst Gate

Use the most specific approved requirements source available:

- approved `interview` spec
- approved user-provided PRD, issue, or ticket
- current user request plus repository evidence

If an approved `interview` spec covers goal, scope, non-goals, constraints,
risks, and acceptance criteria, do not repeat a full Analyst pass. Record:

```text
Analyst: satisfied by approved interview spec
Requirements source: <path or summary>
Gap check: none blocking
```

If any of those fields are missing, inconsistent, or materially affect
architecture, product behavior, data handling, security, or delivery scope, run
Analyst or a limited Analyst gap check before Planner drafts. The Analyst output
must feed the Planner draft; it must not replace the Planner draft.

## Canonical Plan Schema

The plan body is the complete source of truth. Role outputs, the findings ledger,
and approval brief reference or summarize it; they do not recreate another
schema. Tests, review, cleanup, and validation stay under the AC-bearing task
unless the user requested that infrastructure as an outcome.

## Active Plan Contract

Before Planner draft v1, derive one mode- and trigger-aware block and send the
exact same block to Planner and Plan-Reviewer:

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
| Direction and acceptance core | always | requirements and Direction Contract (source, confirmed goal, AC IDs, scope/non-goals, constraints/protected assumptions, approval); success ownership/signals; confidence | contradictions, missing observable success, or unresolved direction-changing inference |
| Minimal scope trace | always | smallest approach; affected files/modules and public/caller/verifier contract uncertainty; ordered AC-mapped tasks | infeasible order, wrong surface, unmapped work, or scope beyond the smallest AC-sufficient change |
| Core evidence | always | smallest verification and TDD applicability; AC-to-evidence mapping | material proof hole only; stronger optional proof is non-blocking |
| Execution handoff | implementation plan | next skill with compact profile and worktree policy; risks/open decisions | unsafe or inconsistent handoff; LIGHT stays compact |
| Simplicity justification | STANDARD or THOROUGH | rejected speculative complexity; justification for new abstraction, dependency, configuration, or generalized path | current-scope speculative complexity only |
| Detailed test design | behavior change or named regression/safety risk | must-fail/must-pass; relevant negative, semantic/adversarial, or baseline cases only | missing relevant case; inactive categories omitted |
| Process and diff budget | STANDARD or THOROUGH | handwritten/generated scope and topology trigger; broad-suite cap and rescope threshold | concrete budget violation, not an unfired larger process |
| Planning-role evidence | selected roles/review, or LIGHT no-review | role/review order, ids, topology, and dispositions, or one compact LIGHT no-review reason | evidence for roles that ran only |
| Rollout/recovery | THOROUGH or operational/migration/public-contract risk | smallest safe rollout; rollback boundary | only when named risk makes recovery material |
| Stack options | greenfield + open stack + recommendation requested | 2-3 options, tradeoffs, default, decision-changing assumption | never required without the trigger |
| Validation check | measurable evidence influenced request | projection from `docs/shared/validation-check.md` | never required without the trigger |
| Parallel dispatch | agent policy not `inline-only` | eligible roles/scopes and dependencies; integration owner | inline-only needs only its profile value |
| Risk semantics | migration, data/security/destructive, concurrency/lifecycle, or public/release trigger | semantics/evidence for the fired trigger | depth/gates limited to named trigger and owner |
| Cross-host review | named THOROUGH paired-review trigger | trigger and topology; synthesis evidence | never required in STANDARD or without trigger |

Audited deduplicated baseline caps: LIGHT=11; STANDARD=24; THOROUGH=26.
Inactive categories do not count as required `not applicable` fields. The
validator derives fixture counts from active table projections and rejects growth.

When `Recommendation requested` is `yes`, present 2-3 viable technology stacks,
their tradeoffs and one recommended default. The recommendation requires approval through the existing Plan Approval Brief before Ralph.

## Acceptance Criteria Contract

Preserve the user's actual success criteria. A test, suite, metric, or local
command is supporting evidence, not a replacement. Apply
`docs/shared/validation-check.md` only when measurable evidence influenced the
request. If criteria conflict or direction-changing facts remain inferred, mark
the plan pending instead of hiding the gap.

## Planner Draft Contract

Planner owns `Planner draft v1` and the plan body. Send it the requirements
source, Analyst status, repository evidence, and exact Active plan contract.
Planner returns only role metadata plus the plan body with active fields; it
omits inactive ceremony. Plan-Reviewer reviews that exact draft, not a recap.

## Plan Review Contract

Plan-Reviewer receives the exact Active plan contract, draft id, and full draft
or path. It runs architecture then quality-gate passes in one dispatch. STANDARD runs one Plan-Reviewer instance. A named THOROUGH security/data/destructive,
public/release-contract, concurrency, migration, or comparable multi-system
trigger runs the paired topology from `docs/shared/cross-host-review.md`.

A blocker is necessary to prevent material failure of an active AC, approved
constraint, safety invariant, Direction Contract field, public contract, or
applicable mandatory gate. Detection examples are subordinate to this
predicate. Unsupported false rejection is a contract failure; preferences,
future-proofing, and optional stronger proof are non-blocking.

Every blocker names one `Blocking basis: <AC ID | safety invariant | Direction Contract field | applicable mandatory gate>`, exact draft pointer, material
consequence, and smallest sufficient correction. A mandatory-gate blocker also
names its real owner, fired trigger, and failed obligation. Review v1 returns
one consolidated set of currently known blockers and does not knowingly reserve
one for v2; it need not promise every possible defect was found.

Plan-Reviewer returns only reviewed draft id, verdict, architecture and
quality-gate finding lists (each may be `none`), Direction Preservation status,
and required Planner changes when blocked. An additional assessment appears only
when its active row fired and produced a finding.

APPROVE freezes the exact reviewed Planner draft. Non-blocking findings are
optional follow-ups and cause no mutation, Planner dispatch, or re-review. Any
plan-body change that must be incorporated before approval is blocking and
yields ITERATE.

## Planner Revision Contract

On ITERATE, Planner first classifies every blocker as `accepted`, `rejected`,
`deferred`, or `direction-change`, before assigning a new id or mutating the
plan. A disposition-only user-decision packet includes the original finding,
basis, pointer, consequence, smallest correction, and Planner reason.

Apply this branch matrix:

- All accepted: create exactly one Planner revision v2, then exactly one delta closure review.
- Any rejected: return the disposition-only user-decision packet; create no v2 and run no review v2 until the user resolves it.
- Any deferred: leave the plan pending in the disposition-only user-decision packet; create no v2 and run no review v2.
- Mixed: resolve every non-accepted blocker before exactly one v2; no closure review starts earlier.
- Permitted waivers with no body change: keep the waivers visible; create no v2 and run no review v2.
- Non-waivable gate: keep the plan pending and prohibit execution until its owner-defined obligation passes or direction changes.
- Direction change: update the requirements source, start a new planning run, and do not run or consume the old run's closure review.

The user may accept, validly waive, defer, or change direction. Accepted changes
must appear in the plan body; ledger-only comments are not a valid revision.

## Re-Review Rules

Re-reviews run only when the previous review returned ITERATE and an accepted
body change produced v2.

Review v2 is a delta closure review of prior dispositions, changed sections,
and affected dependencies; it still receives the full plan. Full-depth review
is allowed only for a named material change to direction/scope,
architecture/ownership, public contract, safety/data semantics, or the
verification model.

A v2 blocker first visible now includes `Why first raised now: <short
explanation>`. A revision-created material defect or material v1 miss may still
block; the explanation requirement does not suppress real defects and its
absence is not an automatic approval rule.

Keep the v1 topology. Maximum two loops: Planner draft/revision vN + Plan review
vN. REJECT does not consume a loop. After loop 2 without APPROVE, pause for user
direction.

## Findings Ledger Gate

Record selected roles and ids in order, topology and named trigger, each finding
with reviewer-owned `blocking | non-blocking` severity and `Blocking basis: <AC
ID | safety invariant | Direction Contract field | applicable mandatory gate>`
when blocking, its disposition, accepted section pointer, permitted waiver, and
`Re-review scope: delta | full` when v2 ran. `Re-review: not required (no
blocking findings)` is the non-blocking path. A required Plan-Reviewer cannot be
skipped; missing review topology is a named ledger gap.

Do not advance while a rejected/deferred/direction-change finding awaits the
user, a non-waivable gate is pending, or accepted blocking feedback is not in the
body. STANDARD keeps one reviewer; named THOROUGH keeps the paired topology.

## Direction Preservation Gate

Plan-Reviewer improves the plan inside the approved Direction Contract. A
correction is the smallest change needed for an AC, approved constraint, safety
invariant, public contract, or applicable mandatory gate. New product scope or
process machinery requires user direction. Keep the current direction visible
and do not incorporate a requested direction change without explicit approval.

## Test Case Design Quality

For a behavior change, start with one must-fail-before-implementation case and
one must-pass-after-implementation case. The RED case must fail against the old broken behavior. Add a negative or forbidden-behavior case,
semantic/adversarial case, or edge, boundary, or regression case only when an AC
or named risk activates it. Reject tests that would pass old or wrong-surface
behavior, only check marker strings/status, snapshot broad output, or mock away
the contract. Do not build a product-like state machine, parser, protocol, or
fixture system solely for proof. A TDD exception explains why RED/GREEN is not
practical.

## Plan File Requirements

The artifact adds a `Next skill: oh-no-harness:<name>` header, Direction
Contract as its first section, approval status, and the complete plan body from
the Active plan contract. It references compact role/findings evidence; it does
not duplicate the canonical matrix or approval brief.

Compact LIGHT plans must still preserve goal, scope, non-goals, acceptance
criteria, tasks, key files, verification, compact execution profile, and
approval status. They may omit inactive review, process, dispatch, risk, and rollout
inactive ceremony. STANDARD/THOROUGH include process or parallel detail only when active;
dispatch detail requires safe isolation, decision-changing value, and reasonable
coordination cost.

## TDD Task Shape

For each active behavior-changing task: write and run RED; implement minimally;
run GREEN; refactor only after green; rerun focused verification. Bug fixes need
a reproduction; behavior-preserving refactors need characterization. Record a
compact exception for docs/config/generated-only or impractical RED/GREEN work.

## Execution Profile

Use `docs/shared/execution-modes.md` and keep one complete profile in the plan.
It owns verification tier. Direct Ralph records `Parallel trigger:
approved-plan-handoff` with `targeted-subagents`/`full-review-set` only when
an eligible role has safe isolation, decision-changing value, and reasonable
coordination cost; otherwise use `inline-only` and `none`.

## Plan Approval Brief

After consensus, show a decision-critical projection: path/status; goal/scope;
tasks/key files; AC alignment; smallest approach and rejected complexity; active
stack/validation/test/rollout decisions; planning-review summary and unresolved
blockers/waivers; worktree/dispatch handoff; verification; risks/open decisions;
and one compact execution-profile recap. Omit inactive sections. Compact LIGHT
preserves goal, scope/non-goals, acceptance criteria, tasks/key files, verification, compact
profile, and approval.

When dispatch is active, recap only roles/scopes that satisfy safe isolation,
decision-changing value, and reasonable coordination cost.

End with one choice: approve-and-run Ralph, approve-and-run Ultrawork, request
plan changes, or leave pending; then ask `Which approach?`. The plan remains
pending until an approve-and-run choice is explicit.

## Next Skill Handoff

<HARD-GATE>
Do NOT invoke `ralph`, `ultrawork`, or any other workflow skill after presenting the plan until the user has explicitly approved the plan AND chosen the next step. Skill chaining in Oh No Harness is approval-gated, not automatic.
</HARD-GATE>

The Plan Approval Brief above is the user-facing review request and next-skill
handoff. It must ask for one explicit choice:

- approve-and-run Ralph (recommended) — approve the plan and execute it
  task-by-task with eligible isolated subagents when they add
  decision-changing evidence, plus verification, review, cleanup, and final
  report
- approve-and-run Ultrawork — approve the plan and orchestrate execution, QA,
  and final validation end-to-end
- request plan changes — revise the plan and present the updated approval brief
- leave the plan pending — keep the plan unapproved and invoke no workflow

The ordinary `oh-no-harness:ralph` choice is the parallel-capable execution
handoff, exposed here as approve-and-run Ralph, when the approved plan lists
eligible isolated roles. Preserve the plan path plus
`Parallel trigger: approved-plan-handoff` in the Ralph invocation so Ralph treats
the approved plan's dispatch plan as authorization to use every eligible
isolated subagent role. Do not ask for separate "parallel subagents" approval
unless the user explicitly requested inline-only execution and later changes
their mind.

End the question with "Which approach?".

Do not invoke any next skill until the user selects an approve-and-run option.
The user is approving the host agent's next action, not being asked to run the
command manually. If the user requests changes, revise the plan and re-present
the brief. If the user leaves the plan pending, stop with no workflow invoked.
For the approve-and-run Ralph option, preserve
`Parallel trigger: approved-plan-handoff` when the approved plan has an eligible
dispatch plan. Preserve `Parallel trigger: natural-dispatch` only for direct
Ralph execution without a ralplan handoff when the host permits proactive
dispatch and the active skill policy itself authorizes eligible isolated roles.

### Ultrawork exception

If you were invoked from `ultrawork`, do not present the user-facing Plan
Approval Brief as a normal approval prompt. Complete the planning quality gates,
write the plan and an internal approval record such as
`Plan approval source: ultrawork automatic approval after interview/spec`, then
return control to ultrawork. Pause for the user only when the plan reveals a
documented Ultrawork pause condition: changed approved scope, a blocking product
decision or ambiguity, conflict with the approved requirements source, missing
execution profile, any unresolved rejected/deferred/direction-change Ralplan
blocker, a pending non-waivable gate, or an explicit user request to review the
plan manually.

## Agent Roles

Ralplan uses these roles directly.

This table governs *agent role* dispatch only — workflow-skill chaining
(`ralph`, `ultrawork`) still goes through `## Next Skill Handoff` HARD-GATE. Use
the active platform runtime document's dispatch policy. Planner and
Plan-Reviewer must keep sequential role boundaries because Planner owns the
draft and
Plan-Reviewer reviews that exact draft. Dispatch them as sequential subagents
on subagent-capable hosts when independent context can improve planning or
review quality; otherwise run the roles inline while preserving the same role
blocks and record the inline fallback reason and the subagent-unavailable
condition from `docs/shared/ralph-subagent-policy.md`.
Ralph's own dispatch reads `docs/shared/ralph-subagent-policy.md` plus the
active platform adapter.

| Agent | Dispatch (when) |
|---|---|
| `explore` | Dispatch `explore` subagent to gather repository facts when codebase context is needed. When the request spans independent subsystems, dispatch one `explore` subagent per independent subsystem in one batch. |
| `analyst` | Dispatch `analyst` subagent to identify hidden requirements, risks, constraints, and open questions unless an approved `interview` spec satisfies the Analyst gate. |
| `planner` | Dispatch `planner` subagent to create `Planner draft v1` and any `Planner revision vN`. Planner owns the plan body and feedback disposition. |
| `plan-reviewer` | Dispatch `plan-reviewer` subagent to review the exact Planner draft using the two-pass `## Plan Review Contract`. It may block on overcomplication, speculative scope, or blocking feedback not reflected in the plan body, and must not produce a replacement plan. Cross-host review runs per the `## Plan Review Contract`. |

Analyst/Planner/Plan-Reviewer stay strictly sequential per the rule above —
Plan-Reviewer only after the Planner draft exists. A named THOROUGH paired-review
trigger may run two instances of that one reviewer role; STANDARD uses one.

## Concrete Request Signals

A request is probably concrete enough for execution when it includes at least one of:

- file path
- failing command
- issue or ticket reference
- function, class, or symbol name
- acceptance criteria
- exact test command
- code block
- numbered implementation steps

If these are absent and the user is asking for execution, prefer this planning skill before execution.

## Output

Return:

- Plan path.
- Planning-role and review-topology summary.
- Plan-Reviewer findings and disposition, as the findings ledger.
- Execution profile.
- Plan approval brief.
- Approval status.
- Recommended next skill for execution.

## Source: docs/platforms/claude-code-runtime.md

# Claude Code Runtime Rules

This compact platform section is embedded in generated Claude Code-facing skill
documents.

## Skill Loading

Claude Code-facing public skills live under `skills-claude/`. Generated
`skills-claude/<skill>/SKILL.md` files compose the matching skill core, this
compact runtime section, and any Claude Code skill-specific overlay such as
`docs/platforms/claude-code-<skill>.md`. Slash commands must delegate to the
matching generated skill document.

## User Approval, Tasks, And Prompting

Use the host's structured question tool when available for approval,
preference, scope, or next-step selection; otherwise ask one focused plain-text
question and wait. Present options as actions the host agent will take.

When a core skill has a multi-phase approval handoff and the host exposes task
tracking, create one task per phase and complete them sequentially.

Keep Claude prompts explicit and sectioned: state scope, non-goals,
constraints, approval gates, expected evidence, and output format. Preserve
long-running context in artifacts before compaction, task handoff, or subagent
dispatch.

## Role Dispatch

Dispatch only after the active skill's trigger fires, then read
`docs/platforms/claude-code.md` `## Role Dispatch` for the full host contract.
Prefer `oh-no-harness:<role>`, request the whole independent batch before
waiting, capture every final result, and clean up only after integration. An
approved-plan handoff is dispatch authorization for eligible isolated roles;
plugin-agent unavailability uses the documented embedded-role fallback.

## Cross-Host Consult Channel

This channel is trigger-loaded, not embedded in every workflow decision. When a
named THOROUGH paired-review or Fusion Rescue trigger fires, read and apply
`docs/platforms/claude-code.md` `## Cross-Host Consult Channel` before dispatch.
Until then, do not preload opposite-host invocation details.
