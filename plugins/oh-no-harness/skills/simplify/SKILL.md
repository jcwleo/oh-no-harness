---
name: simplify
description: Use when a behavior-locked changed diff needs post-implementation, pre-review cleanup for reuse, simplicity, efficiency, and appropriate abstraction; not for initial implementation or correctness/root-cause work.
argument-hint: "[<target>]"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Simplify for Codex

This generated file is the Codex-facing runtime skill document. Codex should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/simplify.md`
- `../../docs/platforms/codex-child-packet-floor.md`
- `../../docs/platforms/codex-runtime.md`
- `../../docs/platforms/codex-simplify.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/simplify.md

# Simplify

Simplify reviews changed code for reuse, simplification, efficiency, and
altitude issues, then applies behavior-preserving fixes. Its main skill pass
is read-only discovery; accepted repository work-product cleanup is applied
through `executor`, with inline mutation only as a recorded LIGHT-tiny or
dispatch-unavailable fallback.

It is a skill, not an agent. In Oh No Harness, `ralph` uses it after the
behavior lock and BEFORE the single review round, so the sole review sees the
cleaned diff; the active platform runtime document supplies the matching
simplify skill. `ralph` owns a preflight quick diff scan and invokes this skill
only when that scan finds actual candidates or candidate uncertainty remains;
a clean quick scan records cleanup as not needed without invoking Simplify.

This is quality cleanup, not bug hunting. Use `code-reviewer` or the host's
code-review workflow for correctness bugs.

## Software Development Stage

Simplify is the post-implementation, pre-review cleanup stage.

Use it after behavior is locked and before the caller's single review round, so
that review sees the cleaned diff. It should improve reuse, clarity,
maintainability, and efficiency without changing behavior, adding scope, or
replacing implementation review.

## Cleanup Depth Decision

Reuse, Simplification, Efficiency, and Altitude are review viewpoints, not four
mandatory jobs.

- LIGHT and STANDARD: run one quick or combined scan over all four viewpoints.
  Record `no candidates` when the scan finds nothing; do not create cleanup work
  to satisfy a pass count.
- THOROUGH without a named expansion trigger: use the same combined scan.
- THOROUGH with a named safety, broad-diff, multi-system, or high-maintainability
  risk: run four independent viewpoint passes. They may run in one parallel
  batch when isolation and platform policy permit it, otherwise run four labeled
  inline blocks and record the fallback.

Record `Cleanup depth: combined | four-viewpoint`, its trigger, and the changed
files inspected. Viewpoint work is read-only discovery. Use discovery
subagents only when separate contexts can change the cleanup decision enough
to justify lifecycle cost. Every direct role dispatch reuses the target role's
required identity/result envelope and adds only Simplify's workflow delta: the
behavior lock and, for apply assignments, accepted cleanup finding IDs. If
cleanup creates a need for additional review or evidence, return it to the
caller; Simplify does not expand its own mandate.

## When To Use

Use for changed code that works but needs a quality pass before delivery:

- new code re-implements helpers the codebase already has
- logic can be simplified without changing behavior
- independent work is run sequentially or redundant work is repeated
- startup, hot paths, or tests do unnecessary I/O or computation
- fixes sit at the wrong altitude, such as fragile special cases on top of
  shared infrastructure
- Speculative abstraction, configuration, or generalization is not required by
  the current behavior
- comments, wrappers, or test details obscure the intended behavior

Do not use when the requested change is functional behavior, a broad refactor, or a rewrite without a behavior lock.

## Required Behavior Lock

Before editing, establish one of:

- passing tests that cover the changed surface
- a focused verification command
- a manual acceptance checklist
- a clear before/after behavior description when no command exists

For a cleanup that alters control flow, structure, or shared/altitude mechanisms,
an executable lock — passing tests or a focused verification command — is
required; a prose lock (checklist or before/after description) suffices only for
purely local edits. If only a prose lock exists for such a change, record it as
`reviewer follow-up` under the `Maintainability Debt Boundary` instead of
applying it.

If no behavior lock exists, create a verification plan first and state the risk.

## Maintainability Debt Boundary

Simplify may fix behavior-preserving cleanup inside the reviewed diff, but it
must not hide correctness, scope, security, or architecture concerns inside a
cleanup pass. When a finding points to maintainability debt that cannot be fixed
without changing behavior, widening scope, changing public contracts, or
touching sensitive behavior, record it as deferred reviewer work instead of
patching around it.

Classify every nontrivial finding as:

```text
Maintainability finding:
- Type: behavior-preserving cleanup | reviewer follow-up | out-of-scope
- Evidence:
- Cost if ignored:
- Safe cleanup action:
- Reviewer needed: none | code-reviewer | verifier
```

Use `reviewer follow-up` for brittle coupling, unclear ownership, hidden state,
cross-boundary special cases, fragile tests, risky generated changes, or cleanup
that would require a behavior decision.

## Scope

When called by `ralph`, limit cleanup to files changed in the current Ralph session.

When called directly, limit cleanup to the target files or paths named by the user.

Do not expand scope because nearby code looks messy.

If a PR number, branch name, or file path was passed as an argument, review that
target instead of the default diff.

## Phase 0 - Gather The Diff

Run `git diff @{upstream}...HEAD` to get the unified diff under review. If
there is no upstream, use the smallest credible fallback such as
`git diff main...HEAD`, `git diff master...HEAD`, or `git diff HEAD~1`.

If there are uncommitted changes, or the range diff is empty, also run
`git diff HEAD` and include working-tree changes in scope. Treat this diff as
the review scope.

## Phase 1 - Review

This phase is read-only discovery: do not edit repository work product or
`.oh-no` state while finding and classifying candidates.

Apply the Cleanup Depth Decision. A combined scan checks Reuse, Simplification,
Efficiency, and Altitude in one bounded pass. When a named THOROUGH trigger
selects four-viewpoint depth, launch the four independent cleanup subagents in
one batch before waiting when the host concurrency limit permits it. Otherwise
use the smallest bounded waves that preserve four independent contexts; use four
labeled inline blocks only with a recorded dispatch-unavailable reason. The
caller captures and cleans up every dispatched result.

Each pass returns findings with `file`, `line`, a one-line `summary`, and the
concrete cost: what is duplicated, wasted, fragile, or harder to maintain.
Each pass must also classify whether the finding is behavior-preserving cleanup,
reviewer follow-up, or out-of-scope under the `Maintainability Debt Boundary`.

### Reuse

Flag new code that re-implements something the codebase already has. Search
shared utilities and files adjacent to the change, and name the existing helper
or local pattern to use instead.

### Simplification

Flag unnecessary complexity the diff adds: redundant or derivable state,
copy-paste with slight variation, deep nesting, dead code left behind, or
Speculative abstraction. Name the simpler behavior-preserving form.

### Efficiency

Flag wasted work the diff introduces: redundant computation or repeated I/O,
independent operations run sequentially, or blocking work added to startup,
tests, or hot paths. Name the cheaper behavior-preserving alternative.

### Altitude

Check that each change is implemented at the right depth, not as a fragile
bandaid. Special cases layered on shared infrastructure are a sign the fix is
not deep enough. Prefer generalizing the underlying mechanism over adding
special cases, but skip anything that would change intended behavior or exceed
the reviewed scope.

## Phase 2 - Apply The Fixes

Capture the combined result or all four expanded results, then deduplicate
findings that point at the same line or mechanism. Select only accepted
behavior-preserving cleanup and dispatch one scoped `executor` assignment (or
up to 5 disjoint assignments when the caller's isolation policy permits). Reuse the
executor's required envelope and add only the behavior lock plus accepted
cleanup finding IDs. Simplify interprets the executor envelope; `Mutation
status: complete` is not cleanup acceptance.

Inline application is allowed with `Mutation fallback: LIGHT-tiny` when the
cleanup is too small to benefit from context separation, or
`Mutation fallback: dispatch-unavailable` after a failed dispatch attempt.
Record the reason; an unrecorded inline application is non-compliant. Inline
application owes the unchanged executor contract per Ralph's
`## Mode-Gated Agent Dispatch`. `.oh-no` state and finding dispositions
remain caller-owned.

Skip any finding whose fix would change intended behavior, require changes well
outside the reviewed diff, or that is a false positive. Note the skip rather
than debating it.

Run the behavior lock again after cleanup. If the post-cleanup behavior lock
regresses from the pre-cleanup result, assign a focused executor revert/fix or
report the blocker; do not let a discovery role mutate the work product. If
cleanup changed structure, tests, or control flow, return that evidence need
to the caller. When the caller is `ralph`, its upcoming sole review inspects
the cleaned result; cleanup does not add a later review round.

## Output

Return:

- Behavior lock used.
- Files changed.
- Cleanup depth, trigger, and review viewpoints covered.
- Cleanup findings fixed.
- Reviewer follow-up findings and owner.
- Findings skipped and why.
- Verification commands and results.
- Residual risk.

## Next Skill Handoff

None - this is a post-implementation mid-loop skill. Return control to the caller (`ralph` or direct invocation). If the cleanup pass changed structure, tests, or control flow, identify the evidence need for the caller; under `ralph`, the upcoming sole review covers the cleaned diff. Do not invoke another role or skill yourself.

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
`docs/platforms/codex.md` `## Role Dispatch` for the full host contract. For typed
Oh No role dispatch, use
`spawn_agent(task_name="ralplan_planner_draft_01", agent_type="oh-no-planner", message=<self-contained packet>, fork_turns="none")` first unless the selected active skill's platform adapter gives an exact spawn form, which takes precedence. The legacy `spawn_agent(agent_type="oh-no-planner", ...)` shorthand is incomplete
(omitting `fork_turns="none"` defaults to a full-history fork, which rejects a custom
`agent_type`), do not combine it with `fork_context=true`, and use generic
prompt embedding only after the custom agent is actually rejected. The example encodes the Ralplan workflow, Planner role, draft phase, and stable ordinal; derive each caller's concrete identity the same way and keep sibling names unique. The task packet carries scope, ownership, expected
output, and lifecycle; task names match `^[a-z0-9_]+$`, use deterministic workflow/role/phase-or-lens/stable-ordinal sibling uniqueness, and never replace requested `agent_type` plus child `agent_role` and matching developer instructions as role proof.

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

## Source: docs/platforms/codex-simplify.md

# Codex Simplify Rules

This platform overlay is source content for the generated Codex-facing
`simplify` runtime document, after the shared core and
`docs/platforms/codex-runtime.md`.

## Cleanup Dispatch

On Codex, the `CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION` SessionStart
context is the standing explicit user request for Simplify cleanup delegation.
Do not ask another approval question merely to launch eligible cleanup
subagents.

When the core selects combined depth, run one combined pass. When it selects
four-viewpoint depth, use intentionally untyped `spawn_agent(task_name="simplify_reuse", message=<self-contained Reuse packet>, fork_turns="none")`; use that same three-field form with self-contained viewpoint messages and task names `simplify_simplification`, `simplify_efficiency`, and `simplify_altitude`, never passing `agent_type`, then launch
all four before waiting only when the host limit permits four; otherwise launch
three, wait and capture them, then launch the remaining viewpoint. If Codex
subagent dispatch is unavailable, use the core's inline labeled-block fallback.
The core owns selection, inline-fallback, and fallback-reason semantics.
