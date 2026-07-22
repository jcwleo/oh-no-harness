---
name: using-oh-no-harness
description: Use when starting a session with Oh No Harness, deciding whether a local skill applies, selecting between interview, planning, Ralph execution, fusion rescue, debugging, cleanup, or verification, and recognizing TDD as an internal guardrail.
argument-hint: "[task, question, or routing need]"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Using Oh No Harness for Codex

This generated file is the Codex-facing runtime skill document. Codex should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/using-oh-no-harness.md`
- `../../docs/platforms/codex-runtime.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/using-oh-no-harness.md

# Using Oh No Harness

Oh No Harness is a lightweight skill harness. Generated platform-specific public
skill documents compose this shared core with the active platform rules from
`docs/platforms/`.

## Software Development Stage

Using Oh No Harness is the workflow-entry and routing stage.

Use it before software work starts to decide whether the request needs `interview`, `ralplan`, `ralph`, `fusion-rescue`, debugging, cleanup, or verification. A strictly trivial inert edit may qualify for the router-owned direct-edit lane defined below; every other concrete edit routes to `ralph`, where Ralph's canonical LIGHT Eligibility defines the risk-gated middle tier before STANDARD or THOROUGH. Treat TDD as an internal guardrail discipline unless the user explicitly asks for TDD or test-first work.

## Core Rule

Before any response or action, route from the requested deliverable and read an
applicable local skill. Supporting process must not become the goal.
A workflow name used only as the subject of analysis, explanation, comparison,
or critique is not an invocation trigger. Route from the requested deliverable:
an analysis report versus a plan or execution artifact. Explicit requests to
create a plan, implement, execute, or invoke a workflow still route normally.

Routing may resolve to no workflow skill at all. When the requested deliverable
does not create or change repository work products (code, tests, docs, configs)
and does not claim their completion, answer directly without invoking a
workflow skill. This no-route lane covers research and information gathering,
conceptual or codebase questions, status or progress reports, and
version-control or environment housekeeping over already-written changes
(commit, push, branch, tag, stash, conflict-free rebase or merge, dependency
install, tool or editor config). Committing or pushing existing work is
housekeeping, not implementation, and does not route to `ralph`. If
housekeeping unexpectedly turns into content changes — for example a conflicted
rebase that needs code edits — re-route from the new deliverable at that point.

Direct-edit lane eligibility requires ALL of these conditions: one obvious file;
an inert edit — prose, comments, or formatting whose file is not consumed by
runtime, build, test, CI, dependency resolution, or an operational procedure;
the file is not generated and, when it is a generation source, regeneration and
validation run in the same action; and no security, permission, or public-contract
surface.
The lane never covers executable source, tests, build, CI, or hook definitions,
dependency or lockfile metadata, repository ignore or attribute files, schema or
migration content, or documents whose text drives destructive or operational
commands, regardless of size. Renames and behavior-preserving refactors of
executable source are not inert; they are `ralph` work, and refactors carry TDD
characterization. Positive examples are a README wording or typo fix and
non-consumed documentation prose; a one-line `.gitignore` addition, a variable
rename, or a runbook command tweak routes to `ralph`. The minimum procedure is
the direct edit plus a diff check, with regeneration and validation in that same
action when the file is a generation source. This lane is a router outcome, not
a public skill. It bypasses `ralph` mode, small-task carve-out, and worktree
machinery precisely because its eligibility excludes the behavior and contract
surfaces those gates protect. Any standing platform mutation-dispatch policy
still governs WHO applies the edit. If any condition fails, including a condition
discovered mid-edit, re-route to `ralph` from that point.

## Orchestration Ownership Boundary

Workflow main agents own `.oh-no` artifacts, packet/result gates, and workflow
transitions. STANDARD/THOROUGH repository work-product mutation is
executor-owned; writing workflow-owned `.oh-no` specs, plans, sessions, and
ledgers is orchestration state, not inline implementation. Inline work-product
mutation is only a recorded LIGHT-tiny or dispatch-unavailable fallback.

The available public skills are:

- `interview`: clarify vague product, design, or engineering requests into an approved spec.
- `ralplan`: create a consensus implementation plan before execution.
- `ralph`: execute a concrete PRD or approved plan until acceptance criteria and verification are satisfied.
- `ultrawork`: orchestrate interview, planning, execution, QA, and final validation for larger end-to-end work.
- `auto-routing`: manage session toggles — stronger SessionStart skill-selection guidance and Codex executor delegation.
- `test-driven-development`: internal guardrail discipline for RED/GREEN/REFACTOR before behavior-changing production edits; not a generic implementation entrypoint.
- `simplify`: review changed code for reuse, simplification, efficiency, and altitude cleanup while preserving behavior.
- `verification-before-completion`: verify evidence before claiming work is complete, fixed, passing, or ready.
- `systematic-debugging`: investigate bugs, failing commands, regressions, and unexpected behavior before fixing.
- `fusion-rescue`: run bounded three-panel rescue analysis with mandatory adversarial critique and fallback-aware synthesis when a hard problem stalls.

This router decides WHERE a request goes; the destination skill owns and
executes its own rules, while the direct-edit lane is this router's own
outcome. The worktree gate, execution modes, and the small-task carve-out are
`ralph`-owned (its generated document carries the decision table and mode
definitions); this skill only needs to know those routes exist.

## Recommended Development Flow

For LLM software development, prefer this order when the request is not already a direct-edit-eligible mutation or another small, concrete edit:

1. `using-oh-no-harness`: route the request and choose the right workflow surface.
2. `interview`: for vague or requirement-light work.
3. `ralplan`: turn the approved spec or clear task into the implementation plan and required Ralph execution mode.
4. `ralph`: set or read the required execution mode, then execute the approved plan or concrete PRD according to that mode.
5. `test-driven-development`: run inside `ralph`, `systematic-debugging`, or `ultrawork` before behavior-changing production edits and bug fixes.
6. `systematic-debugging`: enter whenever a failing command, regression, flaky result, or unknown root cause blocks progress.
7. `fusion-rescue`: escalate only when the selected workflow's ordinary analysis or debugging path stalls and independent panel synthesis could change the next action.
8. `simplify`: invoke only when the caller's quick diff scan finds reuse, simplification, efficiency, or altitude candidates (or candidate uncertainty) after behavior is locked and required review is satisfied or recorded as not needed.
9. `verification-before-completion`: check fresh evidence before any final "done", "fixed", "passing", or "ready" claim.

`ultrawork` is the opt-in end-to-end orchestration lane over the same
`interview` -> `ralplan` -> `ralph` stages. Use it when the user delegates the
loop to the agent; Ultrawork records its internal approvals and only pauses for
the user when a documented pause condition or unclear requirements require it.

Except for direct-edit-eligible mutations, small concrete tasks may skip
`interview` and `ralplan`, but still enter `ralph`; `ralph` must set a `LIGHT`,
`STANDARD`, or `THOROUGH` execution mode before editing and follow the relevant
TDD, debugging, cleanup, and verification gates for that mode.

The proportionality ladder is direct-edit (strictly inert, no `ralph`) < LIGHT <
STANDARD/THOROUGH. Reference Ralph's canonical `LIGHT Eligibility — Risk Gate,
Soft Size Screen` for the complete LIGHT predicate: qualifying localized
behavior or non-behavior work runs through dispatched `executor` -> dispatched
independent `verifier`, waives the code-reviewer pair, and uses the in-place
`light direct checkout`. Ralph work outside LIGHT keeps the STANDARD/THOROUGH
automatic-worktree and independent-verifier envelope, including the reviewer
pair except for the existing STANDARD carve-out below.

LIGHT and Ralph's STANDARD small-task carve-out share the waive-reviewer-keep-
verifier pattern. LIGHT additionally uses the in-place direct checkout rather
than an automatic worktree. Within STANDARD, a small behavior-changing task
that meets the carve-out is a secondary lightweight path: it waives only
reviewer dispatch, not executor ownership, with conditional cleanup, TDD, the
independent `verifier` pass, and worktree isolation unchanged.

A concrete change that reuses an existing scheduler, eligibility decision,
lifecycle owner, or contract surface normally routes to Ralph STANDARD when its
scope is localized and acceptance criteria are clear. Do not route to
Ralplan/THOROUGH merely because the request mentions concurrency; escalate only
when concurrency semantics, ordering, ownership, safety, or lifecycle actually
change.

For a migration that changes Oh No Harness policy itself, an approved plan may
define a temporary bootstrap execution budget. That budget governs the current
run, but edited skill text is not assumed active mid-session; target-policy
claims require a fresh session or equivalent clean load.

Default ordinary implementation requests to `ralph`, not
`test-driven-development`. If a request says add, fix, refactor, or implement
and does not explicitly ask for TDD, test-first, RED/GREEN/REFACTOR, or a
failing test first, select `ralph` for concrete implementation (or
`systematic-debugging` when failure/root-cause investigation is still needed)
and let that workflow invoke TDD internally when behavior changes. The
router-owned direct-edit lane is the exception only for eligible non-behavioral
mutations.

The host agent, not the user, operates the workflow. The active generated
runtime skill document composes the selected skill core, invokes any allowed
role agents, writes artifacts, and runs verification. The user should only need
to approve stage outputs, choose a clearly named next workflow step, or correct
direction when the agent asks.

When describing the staged workflow, call the requirements-discovery stage `interview`, not a generic clarify phase.

## Worktree Isolation Default

For write-capable coding work, the worktree gate applies before source files
are edited; `ralph` owns the decision table and `ultrawork` owns merge-back.
The direct-edit lane edits the current checkout directly; its strict eligibility
conditions are what make bypassing that machinery safe.

`interview` and `ralplan` do not need a worktree by default because they produce
pre-execution artifacts; the worktree gate starts at execution. Direct `ralph`
creates a registered Git worktree under `.oh-no/worktrees/<task-slug>` and records
`Worktree decision: direct automatic worktree` before editing; keep automatic
worktrees project-local rather than parent-directory siblings, and never
`git clone`, `cp -R`, or a plain directory. `ultrawork` also creates an
automatic worktree and additionally owns merge-back into the integration
checkout (`Worktree decision: ultrawork automatic worktree`). A narrow LIGHT
carve-out (`light direct checkout`) exists for direct `ralph` only — never for
`ultrawork` or non-LIGHT work. The carve-out conditions, allowed decisions, and
merge responsibilities live in `ralph`'s generated document.

## Interview Gate

Before asking the user a clarification, scope, preference, or approval question:

1. Check whether the question exists because the request is broad, vague, ambiguous, or missing requirements, constraints, acceptance criteria, or user intent. If yes, read and follow `interview` first.
2. Check whether the question exists because the implementation strategy, sequencing, architecture, risk, or tradeoff is unclear. If yes, read and follow `ralplan` first.
3. Check whether the question exists because a failing command, regression, flaky behavior, or unknown root cause is blocking progress. If yes, read and follow `systematic-debugging` first.
4. Check whether the question exists because ordinary `ralph` or `systematic-debugging` analysis has stalled and a bounded adversarial panel could change the next action. If yes, read and follow `fusion-rescue` first.
5. Check whether the question is part of an already-selected workflow skill. If yes, ask it through that skill's rules.

Do not ask raw clarification questions for vague work before reading `interview`, unless the user explicitly tells you not to use the skill.

## Skill Chaining

Skill chaining is explicit Markdown guidance, not hidden automation.

When a skill defines a `Next Skill Handoff`, you MUST present the handoff to the user and wait for an explicit choice before invoking the next workflow skill. Present the options as actions the host agent will take, not commands the user must run manually. Do not auto-invoke the next workflow skill, even when a single recommended choice is named. The user's answer is the trigger.

Workflow skills (`interview`, `ralplan`) currently define this handoff; `ralph` is terminal and defines only a `Final Handoff` with no next-skill question. The recommended path is `interview → ralplan → ralph`, but each transition is a distinct user-confirmed step.

`ralplan` combines plan-content approval and next-skill choice into one combined
explicit transition: the user must choose approve-and-run Ralph, approve-and-run
Ultrawork, request plan changes, or leave the plan pending. Do not auto-invoke
`ralph`, `ultrawork`, or another workflow after `ralplan` unless the user
selects an approve-and-run option. `interview` remains unchanged and follows its
own handoff rules.

Internal mid-loop skills used inside an already-invoked workflow skill - for example `test-driven-development`, `fusion-rescue`, `simplify`, `verification-before-completion`, and `systematic-debugging` invoked from inside `ralph`'s execution loop - are part of that skill's documented procedure and do not require a separate per-step transition question.

The single exception is `ultrawork`. When the user invokes `ultrawork`,
ultrawork may move between `interview`, `ralplan`, and `ralph` without the
per-step transition question. If requirements are unclear, `interview` spec
review still surfaces to the user. Once the requirements source is approved or
already concrete, `ralplan` plan approval is handled as an Ultrawork internal
approval record unless a documented pause condition appears. Final-completion
verification still runs before any completion claim.

If the user overrides any recommendation, follow the user's instruction unless it would violate safety or repository constraints.

## Platform Notes

This core file does not define platform invocation syntax. Use the active
generated public skill document, which already composes this core with the
matching platform source files named in its runtime composition metadata.

When a skill names an agent role, adapt the role through the active platform
file. Agents remain role prompts inside a selected skill, not workflow
entrypoints: an agent can recommend another role or workflow skill to the
caller, but it does not own artifact gates, approval gates, or next-skill
handoffs.

## Artifact Paths

Use `.oh-no/specs/` for generated specs.

Use `.oh-no/plans/` for generated plans.

Use `.oh-no/sessions/` for transient session artifacts.

Session continuity is scoped to one continuous workflow run. The first skill in
a run that needs a session establishes `.oh-no/sessions/<id>/` (Ultrawork
establishes it at `start_or_resume`); downstream skills in the same run reuse
that directory. Skills in a chain share the session directory; each artifact
file has one owning workflow stage, and internal mid-loop skills (for example,
`test-driven-development` recording RED/GREEN evidence into `verification.md`)
write into their caller's session files by design. Create a new timestamped
directory only when no chain session exists in the current run. On resume or
re-entry, the session directory recorded in the run's artifacts wins; never
mint a new directory when artifacts name one. Across host sessions, durable
specs and plans (their `Next skill` headers) are the continuity bridge, not
session directories. The chain session directory lives in the integration
checkout, not in task worktrees; `ralph` owns the artifact-handoff rule for
making `.oh-no` artifacts visible inside a worktree.

Use `.oh-no/worktrees/` for project-local Ralph and Ultrawork task worktrees.

Do not use legacy harness artifact paths.

## No Hidden Orchestration

Oh No Harness does not include an automatic mode controller or external state ledger.

If a workflow requires persistence, the persistence requirement lives in the skill text and in written artifacts.

## Source: docs/platforms/codex-runtime.md

# Codex Runtime Rules

This compact platform section is embedded in generated Codex-facing skill
documents.

## Skill Loading

Codex-facing public skills live under `skills/`. Generated
`skills/<skill>/SKILL.md` files compose the matching skill core, this compact
runtime section, and any Codex skill-specific overlay such as
`docs/platforms/codex-<skill>.md`.

## User Approval And Prompting

Ask approval, preference, scope, or next-step questions directly in the Codex
conversation. Keep prompts outcome-first: state the desired outcome,
acceptance criteria, non-goals or side effects, expected evidence, and output
shape before detailed steps.

Use compact final answers unless the active skill requires a plan, review, or
verification report. Preserve durable state in written artifacts before long
work, compaction, or handoff.

## Role Dispatch

Dispatch only after the active skill's trigger fires, then read
`docs/platforms/codex.md` `## Role Dispatch` for the full host contract. Use
`spawn_agent(agent_type="oh-no-<role>", ...)` first with `fork_turns="none"`
(omitting it defaults to a full-history fork, which rejects a custom
`agent_type`), do not combine it with `fork_context=true`, and use generic
prompt embedding only after the custom agent is actually rejected. The task packet carries scope, ownership, expected
output, and lifecycle.

Every dispatched result is a dependency: `wait_agent` must reach final status,
the caller captures and uses the output, and only then performs lifecycle
cleanup. Timeout, empty output, or "No agents completed yet" is not final; do
not close, redo inline, or use missing output as evidence.

## Generic Role Prompt Fallback

After confirmed custom-agent unavailability, embed
`docs/agent-core/<role>.md`; see the full platform doc for the fallback shape.

## Cross-Host Consult Channel

This channel is trigger-loaded, not embedded in every workflow decision. When a
named THOROUGH paired-review or Fusion Rescue trigger fires, read and apply
`docs/platforms/codex.md` `## Cross-Host Consult Channel` before dispatch. Until
then, do not preload opposite-host invocation details.
