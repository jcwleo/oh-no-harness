---
name: test-driven-development
description: Use inside ralph-owned execution to enforce RED/GREEN/REFACTOR before behavior-changing production edits, or when explicitly asked for TDD/test-first work; not a top-level implementation route.
argument-hint: "<explicit TDD/test-first change>"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Test Driven Development for Claude Code

This generated file is the Claude Code-facing runtime skill document. Claude Code slash commands should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/test-driven-development.md`
- `../../docs/platforms/claude-code.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/test-driven-development.md

# Test Driven Development

Write the test first. Watch it fail. Write the smallest production change that makes it pass. Refactor only after green.

## Software Development Stage

Test Driven Development is the internal mid-loop discipline for behavior-change work inside implementation and bug-fix execution.

Use it inside `ralph`, `systematic-debugging`, or an explicitly chosen tiny direct edit path before changing production behavior. It is not a requirements, planning, cleanup, or final-verification substitute.

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
- the active host is intentionally taking a tiny direct edit path and only
  needs the TDD discipline before a behavior-changing edit

After the cycle completes, return control to `ralph`, `systematic-debugging`,
`ultrawork`, or the explicitly chosen tiny direct edit path. Do not continue as
a substitute for `ralph`.

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

## Iron Law

No behavior-changing production code without a failing test first.

If production behavior was changed before a failing test existed, do not treat later tests as TDD evidence. Either restart the behavior change from a failing test or document explicit user approval to continue without TDD.

## Required Cycle

For each behavior:

1. RED: write one minimal test that states the desired behavior.
2. Verify RED: run the test and confirm it fails for the expected reason.
3. GREEN: write the smallest production change that can pass that test.
4. Verify GREEN: run the test and confirm it passes.
5. REFACTOR: clean names, duplication, and structure only after green.
6. Verify GREEN again: rerun the relevant check after refactor.
7. Repeat for the next behavior.

Do not batch several behaviors into one RED step. If the test name needs "and", split the test.

## RED Requirements

A valid RED test:

- tests real behavior, not implementation details
- has a clear behavior-focused name
- fails because the behavior is missing or wrong
- does not fail because of typos, broken imports, invalid setup, or missing fixtures
- uses mocks only when real dependencies are impractical

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

Refactor only after GREEN.

Allowed refactors:

- remove duplication
- improve names
- extract helpers
- align with nearby patterns

Not allowed during refactor:

- new behavior
- new scope
- unrelated cleanup
- speculative abstraction

After refactoring, rerun the relevant GREEN check.

## Bug Fix Integration

For a bug fix, first write a test that reproduces the bug.

The RED evidence must show the original symptom or a minimal equivalent. A fix without a reproduction test is not TDD unless the user explicitly approves the exception.

## Refactor Integration

For behavior-preserving refactors, first add or identify characterization tests that lock the existing behavior.

Run those tests before refactoring, then rerun them after each meaningful refactor step.

## Evidence To Record

When this skill is used from `ralph`, record TDD evidence in:

```text
.oh-no/sessions/{sessionId}/verification.md
```

Record:

- story id
- test file and test name
- RED command and expected failure summary
- GREEN command and pass summary
- post-refactor command and pass summary
- any approved exception and reason

## Common Rationalizations

| Rationalization | Response |
|---|---|
| "I will test after." | Tests after code do not prove the test would have caught the missing behavior. |
| "This is too small." | Small behavior still needs a guard if it can regress. |
| "Manual testing is faster." | Manual checks are not repeatable evidence. |
| "The existing code has no tests." | Add the smallest useful test around the changed surface. |
| "The test is hard to write." | Hard to test often means unclear interface or excess coupling. Simplify the design or ask for help. |
| "I already wrote the code." | Later tests are not RED evidence. Restart or document explicit user approval. |

## Completion Checklist

Before claiming the behavior is complete:

- RED was observed for each new or changed behavior.
- Each RED failure matched the expected missing behavior.
- GREEN was observed after the minimal implementation.
- Refactor happened only after GREEN.
- Relevant checks were rerun after refactor.
- Exceptions were explicitly approved or documented.

## Next Skill Handoff

None — this is an internal mid-loop discipline. Return control to the caller skill (`ralph`, `systematic-debugging`, or the tiny direct edit path) once the cycle is complete or an exception is recorded. Do not continue as a substitute for `ralph`.

## Source: docs/platforms/claude-code.md

# Claude Code Platform Rules

This platform section is source content for generated Claude Code-facing
runtime skill documents.

## Skill Loading

Claude Code-facing public skills live under `skills-claude/`. Files in
`skills-claude/<skill>/SKILL.md` are generated runtime documents composed from
the matching `docs/skill-core/<skill>.md` file, this Claude Code platform file,
and any Claude Code skill-specific overlay such as
`docs/platforms/claude-code-<skill>.md`.

Claude slash commands must delegate to `skills-claude/<skill>/SKILL.md` so the
model sees the generated Claude Code runtime document for that skill.

## User Approval

When asking the user for approval, preference, scope, or next-step selection,
use the available structured question tool when the host exposes one. Prefer one
focused question at a time. For option questions, provide a small set of
mutually exclusive choices and put the recommended option first when there is a
clear recommendation.

If a structured question tool is unavailable, ask in plain text and wait for the
user's answer. Present options as actions the host agent will take. Do not tell
the user to run a command manually when the skill handoff expects the host agent
to invoke the next skill.

## Task Tracking

When a core skill has a multi-phase approval handoff and the host exposes task
tracking, create one task per phase and complete them sequentially. Do not
collapse content approval and next-step selection into one hidden step.

## Auto Routing

The `auto-routing` skill controls whether the Claude Code SessionStart hook adds
stronger skill-selection guidance to `using-oh-no-harness`.

Preferred config location:

```text
$HOME/.claude/plugins/data/<oh-no-harness-*>/config.json
```

When `CLAUDE_PLUGIN_ROOT` is set, use:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" status
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" on
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" off
```

Changes take effect on the next Claude Code `SessionStart`, such as a new
session, app restart, `/clear`, or compaction.

## Anthropic-Aligned Prompting

This file carries the runtime-sized Anthropic guidance for Claude Code. The
longer maintenance reference lives in `docs/providers/anthropic.md`, but
generated Claude Code-facing runtime skill documents do not include provider
docs as an extra runtime source.

For Anthropic/Claude models, keep instructions explicit and sectioned:

- state scope, non-goals, constraints, approval gates, and expected evidence in
  stable headings or tagged sections
- avoid relying on implication; say what the agent may do, must not do, and must
  ask before changing
- give one focused user question at a time when approval or direction is needed
- preserve long-running context in artifacts before compaction, task handoff, or
  subagent dispatch
- keep final answers concise unless the active skill requires a structured plan,
  review, or verification report

When the host exposes extended thinking or effort controls, use higher effort
for agentic coding, architecture review, plan critique, and ambiguous debugging.
Use lower effort for small, already-bounded edits.

## Role Dispatch

Claude Code subagent descriptions are delegation metadata. Generated
`agents/*.md` descriptions may keep the `Use proactively` trigger so Claude can
select useful role agents, but they must bind that proactivity to active Oh No
Harness workflows and caller-owned approval and handoff gates. The agent body
contains the stable role contract; the Task, Agent, or Workflow prompt supplies
the current story scope, acceptance criteria, contract surface, baseline guard,
expected output, and lifecycle.

Use the available Task, Agent, Workflow `agent()`, or subagent mechanism for
role dispatch. Prefer plugin-scoped agents named `oh-no-harness:<role>` when
the host lists them.

For independent read-only, review, verification, QA, security, or exploration
work, request background subagents and start the whole independent batch before
waiting for any one result.
When a skill requires an atomic same-phase batch, prefer Workflow `Promise.all`
if available; direct Task or Agent background notifications may arrive before
the model has emitted later task requests, so do not inspect or summarize those
results until the full intended batch has been requested.

After a Claude Code subagent reaches a final status, capture the output and any
changed-file set before cleanup. When no further input is needed, close or clean
up the completed subagent with the mechanism exposed by the host; if none is
available, record that fallback.

For approved `ralplan` handoffs to ordinary `oh-no-harness:ralph`, treat
`Parallel trigger: approved-plan-handoff` as dispatch authorization for
eligible isolated roles. Do not require a separate `ralph with parallel
subagents` option when the plan already lists roles whose output can change the
implementation, review, verification, or ship/block decision.

If plugin-scoped agents are unavailable, keep the same role boundary by
embedding the matching `agents/<role>.md` prompt into the available subagent
mechanism. If no dispatch mechanism is available, keep the role inline and
record the fallback reason when the core skill requires it.
