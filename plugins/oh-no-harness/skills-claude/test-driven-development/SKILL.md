---
name: test-driven-development
description: Use when the user explicitly requests TDD, test-first, or RED-GREEN-REFACTOR, or an already-selected workflow enters its internal TDD gate; ordinary implementation remains Ralph.
argument-hint: "<explicit TDD/test-first change>"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Test Driven Development for Claude Code

This generated file is the Claude Code-facing runtime skill document. Claude Code slash commands should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/test-driven-development.md`
- `../../docs/platforms/claude-code-runtime.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/test-driven-development.md

# Test Driven Development

Write the test first. Watch it fail. Write the smallest production change that makes it pass. Refactor only after green.

## Software Development Stage

Test Driven Development is the internal mid-loop discipline for behavior-change work inside implementation and bug-fix execution.

Use it inside `ralph`, `systematic-debugging`, or `ultrawork` before changing production behavior. It is not a requirements, planning, cleanup, or final-verification substitute.

## Top-Level Routing Boundary

Do not use this skill as the top-level route for ordinary implementation
requests such as "add this feature", "fix this bug", "refactor this module",
or "implement this behavior". This is not a top-level implementation skill.
Use `ralph` for those concrete implementation requests so execution mode,
worktree isolation, review, cleanup, verification, and final reporting stay
attached to the work.

Use this skill as a top-level entry only when:

- the user explicitly asked for TDD, test-first, RED/GREEN/REFACTOR, or
  "write the failing test first"
- an already-selected workflow (`ralph`, `systematic-debugging`, or
  `ultrawork`) reaches its internal TDD gate

Direct-edit-eligible mutations are inert and never reach this skill;
other small concrete edits route through `ralph`, which may apply its STANDARD
small-task carve-out; there is no
separate direct edit path that reaches this skill outside a workflow or an
explicit user TDD request.

After the cycle completes, return control to `ralph`, `systematic-debugging`,
or `ultrawork`. Do not continue as a substitute for `ralph`.

## When To Use

Use before editing production code for:

- new features
- bug fixes
- behavior changes
- refactors that should preserve behavior

Exceptions require explicit user approval or a documented reason:

- docs-only changes
- config-only changes
- generated code
- throwaway prototypes
- no practical test harness exists yet

If a test harness is missing, write a verification plan before changing behavior.
A missing practical harness permits a documented TDD exception plus existing
real-surface, bounded manual, or residual-risk evidence; it does not authorize
new durable test infrastructure or production seams unless the user separately
approves that scope.

## Iron Law

No behavior-changing production code without a failing test first.

If production behavior was changed before a failing test existed, do not treat later tests as TDD evidence. Either restart the behavior change from a failing test or document explicit user approval to continue without TDD.

## Execution Ownership

Inside a dispatch-capable caller, assign one stable `Executor assignment ID`
to each observable behavior and keep its repository work-product writes across
RED, GREEN, and REFACTOR. Continue the same executor session when the host
supports it; a transport rebind may use one call per assigned mutation step
but must preserve and echo that assignment ID while each Packet ID remains
unique. Do not split one behavior's RED and GREEN writes across assignments.

The caller remains the orchestrator: it observes and records RED/GREEN results,
updates `.oh-no` evidence, validates the executor envelope, and decides every
gate. `Mutation status: complete` is not TDD or AC acceptance. Inline writes
are only a recorded LIGHT-tiny or dispatch-unavailable fallback inherited from
the caller's execution policy, and they owe the unchanged executor contract per
Ralph's `## Mode-Gated Agent Dispatch`.

## Required Cycle

For each behavior-changing task, use the cycle below; step 5 is its in-cycle
REFACTOR step and follows `## Refactor Rule`. A standalone behavior-preserving
refactor uses `## Refactor Integration` instead, and its characterization tests
are required evidence, not optional extra cases.

For this cycle, one behavior means one observable contract change from the
approved Direction Contract, not each internal branch, helper, or condition.
Coupled internal conditions that serve one observable outcome may share one
minimal RED; independent user-visible outcomes remain separate cycles.

1. RED: the assigned executor writes one minimal test that states the desired
   behavior.
2. Verify RED: the caller runs the test and confirms it fails for the expected
   reason.
3. GREEN: the same executor writes the smallest production change that can
   pass that test.
4. Verify GREEN: the caller runs the test and confirms it passes.
5. REFACTOR: the same executor cleans names, duplication, and structure only
   after green.
6. Verify GREEN again: the caller reruns the relevant check after refactor.
7. Repeat for the next behavior.

Do not batch independent observable behaviors into one RED step. If the test
name joins independent user-visible outcomes with "and", split the test; do not
split solely because one outcome depends on coupled internal conditions.

## Proportional Test Boundary

One minimal RED/GREEN case per changed behavior is the default. Add negative,
boundary, semantic-model, concurrency, resume, adversarial, or baseline cases
only when an AC ID, named safety/risk trigger, adjacent regression surface, or
safety invariant requires them. A reviewer may identify a verification hole; it
may not demand an exhaustive matrix merely because stronger proof is imaginable.

If no approved admission source exists, record the proposed extra case as `not
relevant` with the reason and do not implement it.

Tests stay evidence under the AC-bearing product story; do not turn test
infrastructure into a separate product story unless the user requested it as an
outcome. Do not build a product-like state machine, scheduler, protocol
simulator, Git oracle, duplicate parser, fixture factory, or full runtime model
solely to verify the implementation; apply the approval and fallback rule in
`## When To Use`.

## RED Requirements

A valid RED test:

- tests real behavior, not implementation details
- has a clear behavior-focused name
- fails because the behavior is missing or wrong
- does not fail because of typos, broken imports, invalid setup, or missing fixtures
- uses mocks only when real dependencies are impractical
- is not tautological: a test that only asserts a mock was called, pins a
  constant, or cannot fail under any plausible regression is self-confirming, not
  RED evidence

If the test passes immediately, it is not RED. Change the test or choose a behavior that is not already covered.

If the test errors before reaching the behavior, fix the test setup and rerun until it fails for the expected reason.

## GREEN Requirements

GREEN means:

- the new test passes
- the relevant existing checks still pass
- the implementation is the smallest reasonable change
- no unrelated refactor or extra feature was added

If another check fails, fix it before moving on.

## Refactor Rule

After GREEN, limit refactoring to the existing behavior and scope: remove
duplication, improve names, extract helpers, and align with nearby patterns.
Do not add behavior, scope, unrelated cleanup, or speculative abstraction.
Then rerun the relevant GREEN check.

## Bug Fix Integration

For a bug fix, first write a test that reproduces the bug.

The RED evidence must show the original symptom or a minimal equivalent. A fix without a reproduction test is not TDD unless the user explicitly approves the exception.

## Refactor Integration

For behavior-preserving refactors, first add or identify characterization tests that lock the existing behavior.

Run those tests before refactoring, then rerun them after each meaningful refactor step.

## Evidence To Record

When this skill is used from a session-scoped workflow (`ralph`, `ultrawork`, or
`systematic-debugging` operating in a session), record TDD evidence in:

```text
.oh-no/sessions/{sessionId}/verification.md
```

When invoked top-level with no session (an explicit user TDD request), record
the same RED/GREEN/REFACTOR evidence inline in the final report or completion
claim instead.

Record:

- story id
- test file and test name
- RED command and expected failure summary
- GREEN command and pass summary
- post-refactor command and pass summary
- any approved exception and reason

## Next Skill Handoff

None — this is an internal mid-loop discipline. Return control to the caller skill (`ralph`, `systematic-debugging`, or `ultrawork`) once the cycle is complete or an exception is recorded. Do not continue as a substitute for `ralph`.

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

## Model Diversity Pair

This mechanism is trigger-loaded, not embedded in every workflow decision. It
governs only how an ALREADY-SELECTED pair is dispatched; it never selects review
topology itself. The active core or skill owns that selection, and a
`code-reviewer` pair applies only where that core already selected
`perspective-pair` after a named trigger, or the caller explicitly demanded
strict diversity — never to every dispatched review. For
a dispatched THOROUGH `plan-reviewer` pair, such a selected `code-reviewer` pair,
or a named THOROUGH `debugger` pair, both legs MUST be requested in a single
batch: issue both subagent tool calls in the same assistant turn (or with
`Background: yes` for both) BEFORE waiting on either result; a serial
dispatch-wait-dispatch sequence is not a valid pair. The two legs' packet bodies
MUST be identical except the single `Assigned perspective:` line (Lens A on the
primary leg, Lens B on the diversity leg); leg identity (`primary` vs
`diversity`) is carried ONLY by the host dispatch metadata (the description field
and the model override), never inside the packet text. Read the role's concrete
stored primary and validated secondary top-tier model from the session
`<OH_NO_MODEL_DIVERSITY>` block. The primary leg is
unoverridden and uses the declared-frontmatter primary; the
secondary leg carries an explicit NATIVE model override. Claim
`model-diversity-pair` only when the primary is not `host-default` and the
secondary differs from it. Otherwise default to two independent same-model
instances as `same-model-parallel-fallback` with the reason recorded; an
explicit `require-model-diversity` demand transitions to PAUSED when the
diversity leg is unavailable. Fusion Rescue uses its Claude Code overlay's
three-panel assignment instead of this two-leg shape.
