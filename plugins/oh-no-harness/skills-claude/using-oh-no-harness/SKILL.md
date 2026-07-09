---
name: using-oh-no-harness
description: Use when starting a session with Oh No Harness, deciding whether a local skill applies, selecting between interview, planning, Ralph execution, fusion rescue, debugging, cleanup, or verification, and recognizing TDD as an internal guardrail.
argument-hint: "[task, question, or routing need]"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Using Oh No Harness for Claude Code

This generated file is the Claude Code-facing runtime skill document. Claude Code slash commands should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/using-oh-no-harness.md`
- `../../docs/platforms/claude-code-runtime.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/using-oh-no-harness.md

# Using Oh No Harness

Oh No Harness is a lightweight skill harness. Generated platform-specific public
skill documents compose this shared core with the active platform rules from
`docs/platforms/`.

## Software Development Stage

Using Oh No Harness is the workflow-entry and routing stage.

Use it before software work starts to decide whether the request needs `interview`, `ralplan`, `ralph`, `fusion-rescue`, debugging, cleanup, verification, or a direct small edit. Treat TDD as an internal guardrail discipline unless the user explicitly asks for TDD or test-first work.

## Core Rule

Before any response or action, including clarification questions, check whether a local Oh No Harness skill could apply.

If there is even a small chance that a local skill applies, read that skill before responding and follow it directly. If the selected skill turns out not to apply, say so briefly and continue with the next best path.

Needing more context is not a reason to skip skill selection. It is often the signal that `interview`, `ralplan`, `systematic-debugging`, or another local skill should be read first.

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

## Required Reading

Before acting on any gate below that routes a decision through a shared
contract, read that contract. A path reference here is a pointer, not a
substitute for reading: do not apply one of these rules from memory when this
skill hands a decision to it. If a listed file cannot be read, record the
blocker instead of proceeding past the gate that depends on it.

- `docs/shared/worktree-isolation.md` — the write-capable worktree default the recommended flow relies on.

## Recommended Development Flow

For LLM software development, prefer this order when the request is not already a small, concrete edit:

1. `using-oh-no-harness`: route the request and choose the right workflow surface.
2. `interview`: for vague or requirement-light work.
3. `ralplan`: turn the approved spec or clear task into the implementation plan and required Ralph execution mode.
4. `ralph`: set or read the required execution mode, then execute the approved plan or concrete PRD according to that mode.
5. `test-driven-development`: run inside `ralph`, `systematic-debugging`, `ultrawork`, or an explicitly chosen tiny direct edit path before behavior-changing production edits and bug fixes.
6. `systematic-debugging`: enter whenever a failing command, regression, flaky result, or unknown root cause blocks progress.
7. `fusion-rescue`: escalate only when the selected workflow's ordinary analysis or debugging path stalls and independent panel synthesis could change the next action.
8. `simplify`: clean reuse, simplification, efficiency, and altitude issues only after behavior is locked and required review is satisfied or recorded as not needed.
9. `verification-before-completion`: check fresh evidence before any final "done", "fixed", "passing", or "ready" claim.

`ultrawork` is the opt-in end-to-end orchestration lane over the same
`interview` -> `ralplan` -> `ralph` stages. Use it when the user delegates the
loop to the agent; Ultrawork records its internal approvals and only pauses for
the user when a documented pause condition or unclear requirements require it.

Small concrete tasks may skip `interview` and `ralplan`, but `ralph` still
must set a `LIGHT`, `STANDARD`, or `THOROUGH` execution mode before editing and
must follow the relevant TDD, debugging, cleanup, and verification gates for
that mode.

Default ordinary implementation requests to `ralph`, not
`test-driven-development`. If a request says add, fix, refactor, or implement
and does not explicitly ask for TDD, test-first, RED/GREEN/REFACTOR, or a
failing test first, select `ralph` for concrete implementation (or
`systematic-debugging` when failure/root-cause investigation is still needed)
and let that workflow invoke TDD internally when behavior changes.

The host agent, not the user, operates the workflow. The active generated
runtime skill document composes the selected skill core, invokes any allowed
role agents, writes artifacts, and runs verification. The user should only need
to approve stage outputs, choose a clearly named next workflow step, or correct
direction when the agent asks.

When describing the staged workflow, call the requirements-discovery stage `interview`, not a generic clarify phase.

## Worktree Isolation Default

For write-capable coding work, apply `docs/shared/worktree-isolation.md` before
editing source files.

`interview` and `ralplan` do not need a worktree by default because they produce
pre-execution artifacts; the worktree gate starts at execution. Direct `ralph`
creates a registered Git worktree under `.oh-no/worktrees/<task-slug>` and records
`Worktree decision: direct automatic worktree` before editing; keep automatic
worktrees project-local rather than parent-directory siblings, and never
`git clone`, `cp -R`, or a plain directory. `ultrawork` also creates an
automatic worktree and additionally owns merge-back into the integration
checkout (`Worktree decision: ultrawork automatic worktree`). A narrow LIGHT
carve-out (`light direct checkout`) exists for direct `ralph` only — never for
`ultrawork` or non-LIGHT work. See `docs/shared/worktree-isolation.md` for the
carve-out conditions, the allowed decisions, and merge responsibilities.

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
checkout, not in task worktrees (worktree access follows
`docs/shared/worktree-isolation.md` `## Artifact Handoff`).

Use `.oh-no/worktrees/` for project-local Ralph and Ultrawork task worktrees.

Do not use legacy harness artifact paths.

## No Hidden Orchestration

Oh No Harness does not include an automatic mode controller or external state ledger.

If a workflow requires persistence, the persistence requirement lives in the skill text and in written artifacts.

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

When the session context carries the same-host review toggle block, skip the
opposite-host preflight and consult entirely; do not probe availability. The
calling skill then runs its own same-host path — the Same-Host Parallel pair for
the review roles (`plan-reviewer`, `code-reviewer`, `debugger`), or the normal
local panels for Fusion Rescue — and records `same-host-parallel-selected`.

From Claude Code, the current-host main agent consults Codex only by dispatching
the dedicated read-only consult agent `oh-no-harness:<role>-codex` for the
assigned opposite-host leg, where `<role>` is `plan-reviewer`, `code-reviewer`,
or `debugger` for shared cross-host review, or `fusion` for a Fusion Rescue panel
slot. That consult agent resolves the Codex companion path and runs one
synchronous, read-only `codex-companion.mjs task` call: it omits the write flag
so the companion sandbox is read-only (best-effort, not a guarantee — see the
consult agent cores), and it never runs the call as a detached background job. If the companion is unavailable or unresolvable, treat the
opposite host as unavailable; in default mode the calling skill applies the
shared cross-host contract's Same-Host Parallel Fallback
(`docs/shared/cross-host-review.md`), and require-cross-host mode blocks. Name the
failure class and the current-host fallback.

The consult must return Codex's actual assigned analysis synchronously. The
`codex-companion.mjs` call passes the scoped, redacted packet with `--prompt-file`
and must not run in the background. A response that only acknowledges a queued or
background job — text that a task started in the background with a status command
for a job id — is not a valid opposite-host response; treat it as no Codex
response and degrade (default) or block (require-cross-host). Do not poll status
or fetch a deferred result to compensate; the consult call itself must return the
analysis.

For shared cross-host review, the packet the `oh-no-harness:<role>-codex` agent
sends must instruct Codex to dispatch the matching `oh-no-<role>` role agent for
the assigned opposite-host pass, where `<role>` is `plan-reviewer`,
`code-reviewer`, or `debugger`. Codex must wait for that dispatched role agent and
return its assigned role result, and the consult agent must require role-ownership
proof that the dispatched role agent — not a parent inline Codex answer — produced
it. A direct Codex parent answer is not a
valid opposite-host shared review response. If Codex cannot dispatch the matching
role agent, or the role-ownership proof is missing, treat the opposite host as
unavailable in default mode or block in require-cross-host mode; do not accept
inline Codex parent analysis as the cross-host pass. Role ownership is best-effort
— there is no host selector that forces it — so it is required and proven, not
assumed.

Fusion Rescue panel slots remain governed by the Fusion Rescue panel contract;
the role-agent requirement above applies only to shared cross-host review. The
`oh-no-harness:fusion-codex` panel slot dispatches `oh-no-fusion-rescue-analyst`
for one assigned lens (see `docs/platforms/claude-code-fusion-rescue.md`).

The outbound packet must request only the assigned analysis and must forbid the
opposite host from invoking further rescue, another workflow skill, or any
host-to-host call back to Claude Code or a third host (one cross-host hop).
Redact secrets before sending; on failure record only the failure class and
companion/path/auth status, never secret values.
