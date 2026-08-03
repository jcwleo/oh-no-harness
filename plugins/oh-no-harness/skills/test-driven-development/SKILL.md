---
name: test-driven-development
description: Use when the user explicitly requests TDD, test-first, or RED-GREEN-REFACTOR, or an already-selected workflow enters its internal TDD gate; ordinary implementation remains Ralph.
argument-hint: "<explicit TDD/test-first change>"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Test Driven Development for Codex

This generated file is the Codex-facing runtime skill document. Codex should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/test-driven-development.md`
- `../../docs/platforms/codex-child-packet-floor.md`
- `../../docs/platforms/codex-runtime.md`

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
