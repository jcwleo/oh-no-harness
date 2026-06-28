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
- `auto-routing`: toggle stronger SessionStart skill-selection guidance for users who want it.
- `test-driven-development`: internal guardrail discipline for RED/GREEN/REFACTOR before behavior-changing production edits; not a generic implementation entrypoint.
- `simplify`: review changed code for reuse, simplification, efficiency, and altitude cleanup while preserving behavior.
- `verification-before-completion`: verify evidence before claiming work is complete, fixed, passing, or ready.
- `systematic-debugging`: investigate bugs, failing commands, regressions, and unexpected behavior before fixing.
- `fusion-rescue`: run bounded three-panel rescue analysis with mandatory adversarial critique and fallback-aware synthesis when a hard problem stalls.

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

`interview` and `ralplan` do not need to run inside a worktree by default because
they produce pre-execution artifacts. The worktree gate starts at execution:
direct `ralph` creates or selects a registered Git worktree under
`.oh-no/worktrees/<task-slug>` by default, records
`Worktree decision: direct automatic worktree`, and does not edit files until
that decision is visible.
Automatic task worktrees should stay inside the project rather than appearing as
parent-directory siblings unless an explicit fallback is recorded. Do not treat
`git clone`, `cp -R`, or a plain directory as a valid Ralph task worktree.

`ultrawork` is the orchestration exception because it also owns integration back
into the original checkout. When it reaches write-capable execution, it records
`Worktree decision: ultrawork automatic worktree`, creates or selects a task
registered Git worktree under `.oh-no/worktrees/<task-slug>`, executes there,
merges into the integration checkout, and runs post-merge verification.

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

## Cross-Host Consult Channel

This is the shared cross-host consult mechanism used by Fusion Rescue and by
cross-host review (`docs/shared/cross-host-review.md`). On Codex the opposite
host is Claude Code. This section carries only the Codex-to-Claude invocation;
the activation, synthesis, and recursion-guard semantics live in the calling
skill core and the shared doc.

From Codex, consult Claude Code through `${CLAUDE_BIN:-claude}` only when the
active Codex permission state is exactly `danger-full-access`. If the state is
missing, unknown, `read-only`, `workspace-write`, or anything else, do not call
Claude: treat the opposite host as unavailable; in default mode the calling skill
applies the shared cross-host contract's Same-Host Parallel Fallback
(`docs/shared/cross-host-review.md`), and require-cross-host mode blocks while
naming the failure class and the current-host fallback.

When the `danger-full-access` preflight confirms, build the Claude command as an
argument vector, not shell string interpolation: `${CLAUDE_BIN:-claude}`,
`--print`, `--model`, `opus`, `--permission-mode`, `dontAsk`,
`--no-session-persistence`, then the redacted prompt packet, unless the user
supplied a different Claude model. Do not strip Claude's tools by default; Claude
may need its own read-only tools to produce the assigned analysis. The read-only
boundary is enforced by the redacted packet and host permissions, not by
removing tools.

The consult must return Claude's actual assigned analysis synchronously. A launch
notice, queued-job message, background acknowledgement, or status pointer is not
a valid opposite-host response; treat it as unavailable. The Claude prompt must
request only the assigned analysis and must forbid file edits, writes, installs,
mutating commands, nested rescue, and any host-to-host ping-pong back to Codex or
a third host (one cross-host hop). Redact secrets before sending; on failure
record only the failure class and command/path/auth status, never secret values.
