---
name: simplify
description: Review changed code for reuse, simplification, efficiency, and altitude cleanups, then apply behavior-preserving fixes after implementation approval.
argument-hint: "[<target>]"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Simplify for Codex

This generated file is the Codex-facing runtime skill document. Codex should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/simplify.md`
- `../../docs/platforms/codex-runtime.md`
- `../../docs/platforms/codex-simplify.md`

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

Phase 1 owns the small-diff gate and decides whether cleanup review uses one
combined pass or four separate role passes. On either path the report must keep
the four labeled viewpoints: Reuse, Simplification, Efficiency, and Altitude.
Apply the active platform's Simplify dispatch authorization and lifecycle rules
before launching cleanup subagents. Do not ask another approval question merely
to launch cleanup subagents when the active platform already supplies standing
authorization for eligible skill-local delegation.
If the active host cannot dispatch subagents, record the dispatch-unavailable
reason before continuing inline: above the gate, preserve the same four role
boundaries as separate inline fallback blocks; for a small diff, run the
single pass inline with the same four labeled sections. If a cleanup change
needs additional independent evidence after the fixes, return that need to
the caller so `verifier` or `code-reviewer` can review the result after the
cleanup pass.

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

Apply the small-diff gate to the review diff first: a diff is small when it
touches at most 3 changed files AND at most 100 changed lines AND no
generated files. When any bound is exceeded, unknown, or uncertain, default
to the four parallel cleanup subagents.

For diffs above the small-diff gate, launch four independent cleanup subagents
in parallel because the review requires four cleanup role passes. Start them in
one batch before waiting for any result. Pass each subagent the review diff and
assign exactly one angle: Reuse, Simplification, Efficiency, or Altitude. For a
small diff, launch one cleanup subagent with the review diff and all four
angles; this is the single pass that still reports all four labeled sections:
Reuse, Simplification, Efficiency, and Altitude, and it must not drop or merge
them. Use the active platform's approved mechanism and Simplify platform overlay
when available. The caller owns lifecycle: after each cleanup subagent result is
captured, close or clean up the completed subagent using the active platform
mechanism.

If subagent dispatch is unavailable, run the selected path inline: above the
gate, run Reuse, Simplification, Efficiency, and Altitude as
four separate inline fallback blocks with the same assigned scope, expected
output, and fallback reason; for a small diff, run the single pass inline
with the same four labeled sections and record the fallback reason.

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

On the parallel path, wait for all four cleanup subagent results, capture
every result, and close or clean up each completed cleanup subagent.
On the small-diff path, capture the single cleanup subagent's result and
close or clean up that completed subagent. Then deduplicate findings that
point at the same line or mechanism and fix each remaining
behavior-preserving cleanup directly.

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

Codex role dispatch is host-policy controlled. Use `spawn_agent` only when the
host exposes it, the active skill permits dispatch, and the role has isolated
read-only scope, disjoint write ownership, or an independent review or
verification responsibility.

For Oh No Harness roles, use the registered custom agent first:
`spawn_agent(agent_type="oh-no-<role>", ...)`. Generic fallback is allowed only
inside an active Oh No Harness workflow or explicit user-requested subagent
task after an actual `agent_type="oh-no-<role>"` attempt is rejected as unknown
or unavailable, and the fallback reason is recorded. Do not infer custom-agent
unavailability from rendered schema text, display comments, or uncertainty.

Do not combine `agent_type="oh-no-<role>"` with `fork_context=true` or any
full-history fork request. Pass the current scope, constraints, expected output,
and lifecycle in the spawned-agent message, using one payload shape only.

The Codex SessionStart standing authorization, a user standing preference, an
approved plan profile, or an active Oh No Harness skill policy is workflow-level
authorization for eligible isolated subagents. Do not ask another per-run
approval question only to dispatch those roles. Dispatch only when the result
can change implementation, review, verification, latency, context management,
or the ship/block decision.

After `wait_agent` returns a final status, capture the output and any
changed-file set before cleanup. A timeout, empty wait, or "No agents completed
yet" result is not final and is not permission to close the subagent. Once a
role is dispatched, its assigned scope, role, and expected output become a
workflow dependency. Wait until every in-scope dispatched subagent reaches final
status, capture its result, and use that result in synthesis, implementation,
review, verification, or an explicit blocked/abandoned record before advancing
past the dependent step or claiming completion. While waiting, continue only
genuinely non-overlapping local work. Do not redo delegated work inline, spawn
a duplicate replacement, or let parent inline analysis substitute for the
subagent result merely because the subagent is slow. Never use missing output
as completion evidence.

Close or clean up a subagent without a captured final result only when the user
explicitly cancels or stops that subagent, the task scope invalidates the work,
the spawn was duplicate or mis-scoped, or continuing creates a safety, security,
or filesystem risk. Record that close as cancelled or abandoned.

## Generic Role Prompt Fallback

When generic Codex agent types are used after confirmed custom-agent
unavailability, embed the matching `docs/agent-core/<role>.md` prompt body in
the spawned-agent message. If only `agents/<role>.md` exists, strip Claude Code
YAML frontmatter before embedding.

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

Use Codex subagent dispatch when the active Codex host exposes it and the
cleanup pass is worth isolating. For diffs above the small-diff gate, launch the
Reuse, Simplification, Efficiency, and Altitude cleanup subagents as one
eligible batch before waiting for any result. For a small diff, launch one
cleanup subagent only when it provides useful context separation; otherwise keep
the single cleanup pass inline with all four labeled sections.

If Codex subagent dispatch is unavailable, unsafe, or not useful, preserve the
same cleanup role boundary inline and record the fallback reason required by the
shared core.
