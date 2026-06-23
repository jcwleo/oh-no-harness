---
name: simplify
description: Review changed code for reuse, simplification, efficiency, and altitude cleanups, then apply behavior-preserving fixes after implementation approval.
argument-hint: "[<target>]"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Simplify for Claude Code

This generated file is the Claude Code-facing runtime skill document. Claude Code slash commands should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/simplify.md`
- `../../docs/platforms/claude-code-runtime.md`
- `../../docs/platforms/claude-code-simplify.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/simplify.md

# Simplify

Simplify reviews changed code for reuse, simplification, efficiency, and
altitude issues, then applies behavior-preserving fixes.

It is a skill, not an agent. In Oh No Harness, `ralph` uses it after the
selected mode's required review is satisfied and before final verification;
the active platform runtime document supplies the matching simplify skill.

This is quality cleanup, not bug hunting. Use `code-reviewer` or the host's
code-review workflow for correctness bugs.

## Software Development Stage

Simplify is the post-implementation cleanup stage.

Use it after behavior is locked and the review required by the caller has passed
or has been recorded as not needed. It should improve reuse, clarity,
maintainability, and efficiency without changing behavior, adding scope, or
replacing implementation review.

## Cleanup Role Passes

These are skill-local cleanup role passes, not public workflow skills and not
`docs/agent-core` agents. Use the active platform's subagent mechanism only to
isolate the pass work when it is available and useful.

Cleanup review always runs all four labeled viewpoints — Reuse, Simplification,
Efficiency, and Altitude — as four separate role passes. There is no
single-combined-pass shortcut and no diff-size gate: every cleanup review keeps
the four viewpoints distinct so none is silently dropped.
Run the four passes in parallel using the active platform's subagent mechanism.
Apply the active platform's Simplify dispatch authorization and lifecycle rules
before launching cleanup subagents. Do not ask another approval question merely
to launch cleanup subagents when the active platform already supplies standing
authorization for eligible skill-local delegation.
If the active host cannot dispatch subagents, run the four passes inline as four
separate labeled blocks with the same role boundaries, and record the
dispatch-unavailable reason. If a cleanup change needs additional independent
evidence after the fixes, return that need to the caller so `verifier` or
`code-reviewer` can review the result after the cleanup pass.

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
- Reviewer needed: none | code-reviewer | plan-reviewer | verifier
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

Launch four independent cleanup subagents in parallel — the review always runs
all four cleanup role passes regardless of diff size. Start them in one batch
before waiting for any result. Pass each subagent the review diff and assign
exactly one angle: Reuse, Simplification, Efficiency, or Altitude. Use the active
platform's approved mechanism and Simplify platform overlay when available. The
caller owns lifecycle: after each cleanup subagent result is captured, close or
clean up the completed subagent using the active platform mechanism.

If subagent dispatch is unavailable, run the same four passes inline as four
separate labeled blocks — Reuse, Simplification, Efficiency, and Altitude — each
with its assigned scope and expected output, and record the dispatch-unavailable
fallback reason. Do not drop or merge any of the four viewpoints.

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

Capture all four cleanup pass results — the four parallel subagents, or the four
inline blocks when dispatch was unavailable — and close or clean up each
completed cleanup subagent. Then deduplicate findings that point at the same line
or mechanism and fix each remaining behavior-preserving cleanup directly.

Skip any finding whose fix would change intended behavior, require changes well
outside the reviewed diff, or that is a false positive. Note the skip rather
than debating it.

Run the behavior lock again after cleanup. If cleanup changed structure, tests,
or control flow, return that need to the caller so `code-reviewer` or
`verifier` can inspect the result.

## Output

Return:

- Behavior lock used.
- Files changed.
- Review angles run.
- Cleanup findings fixed.
- Reviewer follow-up findings and owner.
- Findings skipped and why.
- Verification commands and results.
- Residual risk.

## Next Skill Handoff

None - this is a post-implementation mid-loop skill. Return control to the caller (`ralph` or direct invocation). If the cleanup pass changed structure, tests, or control flow, recommend `code-reviewer` or `verifier` to the caller; do not invoke them yourself.

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

Use the available Task, Agent, Workflow `agent()`, or subagent mechanism for
role dispatch. Prefer plugin-scoped agents named `oh-no-harness:<role>` when
the host lists them.

For independent read-only, review, verification, QA, security, or exploration
work, request background subagents and start the whole independent batch before
waiting for any one result. When a skill requires an atomic same-phase batch,
prefer Workflow `Promise.all` if available; otherwise do not inspect or
summarize early task results until the full intended batch has been requested.

After a Claude Code subagent reaches final status, capture the output and any
changed-file set before cleanup. When no further input is needed, close or
clean up the completed subagent with the mechanism exposed by the host; if none
is available, record that fallback.

For approved `ralplan` handoffs to ordinary `oh-no-harness:ralph`, treat
`Parallel trigger: approved-plan-handoff` as dispatch authorization for
eligible isolated roles. Do not require a separate `ralph with parallel
subagents` option when the plan already lists roles whose output can change the
implementation, review, verification, or ship/block decision.

If plugin-scoped agents are unavailable, keep the same role boundary by
embedding the matching `agents/<role>.md` prompt into the available subagent
mechanism. If no dispatch mechanism is available, keep the role inline and
record the fallback reason when the core skill requires it.

## Cross-Host Consult Channel

This is the shared cross-host consult mechanism used by Fusion Rescue and by
cross-host review (`docs/shared/cross-host-review.md`). On Claude Code the
opposite host is Codex. This section carries only the Claude-to-Codex
invocation; the activation, synthesis, and recursion-guard semantics live in the
calling skill core and the shared doc.

From Claude Code, consult Codex only through an available, explicitly loaded
`openai/codex-plugin-cc` capability, surfaced as `/codex:rescue` when that plugin
is installed. If the capability is unavailable, treat the opposite host as
unavailable; in default mode the calling skill applies the shared cross-host
contract's Same-Host Parallel Fallback (`docs/shared/cross-host-review.md`), and
require-cross-host mode blocks. Name the failure class and the current-host
fallback.

The consult must run synchronously and return Codex's actual assigned analysis.
Pass `--wait` to force foreground execution, for example `/codex:rescue --wait`,
and request read-only Codex behavior; do not let it run as a detached background
job and do not authorize write-capable edits for an analysis-only consult. A
response that only acknowledges a queued or background job — text that a task
started in the background with a status command for a job id — is not a valid
opposite-host response; treat it as no Codex response and degrade (default) or
block (require-cross-host). Do not poll status or fetch a deferred result to
compensate; the consult call itself must return the analysis.

The outbound prompt must request only the assigned analysis and must forbid the
opposite host from invoking further rescue, another workflow skill, or any
host-to-host call back to Claude Code or a third host (one cross-host hop).
Redact secrets before sending; on failure record only the failure class and
capability/path/auth status, never secret values.

## Source: docs/platforms/claude-code-simplify.md

# Claude Code Simplify Rules

This platform overlay is source content for the generated Claude Code-facing
`simplify` runtime document, after the shared core and
`docs/platforms/claude-code-runtime.md`.

## Cleanup Dispatch

Cleanup always runs the four cleanup role passes in parallel. Prefer Workflow
`Promise.all` for the four-pass cleanup path when available; otherwise issue all
four background Task or Agent requests before inspecting or summarizing task
results. Each request gets exactly one angle: Reuse, Simplification, Efficiency,
or Altitude.

If Claude Code subagent dispatch is unavailable, preserve the same four cleanup
role passes inline as four labeled blocks and record the fallback reason required
by the shared core.
