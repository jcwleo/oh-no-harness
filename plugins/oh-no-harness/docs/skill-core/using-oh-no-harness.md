---
name: using-oh-no-harness
description: Use when starting a session with Oh No Harness, deciding whether a local skill applies, selecting between interview, planning, Ralph execution, debugging, cleanup, or verification, and recognizing TDD as an internal guardrail.
argument-hint: "[task, question, or routing need]"
---

# Using Oh No Harness

Oh No Harness is a lightweight skill harness. Platform-specific public skill
wrappers load this shared core and then apply the active platform rules from
`docs/platforms/`.

## Software Development Stage

Using Oh No Harness is the workflow-entry and routing stage.

Use it before software work starts to decide whether the request needs `interview`, `ralplan`, `ralph`, debugging, cleanup, verification, or a direct small edit. Treat TDD as an internal guardrail discipline unless the user explicitly asks for TDD or test-first work.

## Core Rule

Before any response or action, including clarification questions, check whether a local Oh No Harness skill could apply.

If there is even a small chance that a local skill applies, read that skill before responding and follow it directly. If the selected skill turns out not to apply, say so briefly and continue with the next best path.

Needing more context is not a reason to skip skill selection. It is often the signal that `interview`, `ralplan`, `systematic-debugging`, or another local skill should be read first.

The available public skills are:

- `interview`: clarify vague product, design, or engineering requests into an approved spec.
- `ralplan`: create a consensus implementation plan before execution.
- `ralph`: execute a concrete PRD or approved plan until acceptance criteria and verification are satisfied.
- `autopilot`: orchestrate interview, planning, execution, QA, and final validation for larger end-to-end work.
- `auto-routing`: toggle stronger SessionStart skill-selection guidance for users who want it.
- `test-driven-development`: internal guardrail discipline for RED/GREEN/REFACTOR before behavior-changing production edits; not a generic implementation entrypoint.
- `simplify`: review changed code for reuse, simplification, efficiency, and altitude cleanup while preserving behavior.
- `verification-before-completion`: verify evidence before claiming work is complete, fixed, passing, or ready.
- `systematic-debugging`: investigate bugs, failing commands, regressions, and unexpected behavior before fixing.

## Recommended Development Flow

For LLM software development, prefer this order when the request is not already a small, concrete edit:

1. `using-oh-no-harness`: route the request and choose the right workflow surface.
2. `interview`: discover requirements, constraints, users, acceptance criteria, and brownfield facts for vague or requirement-light work.
3. `ralplan`: turn the approved spec or clear task into an implementation plan, sequencing, TDD expectations, required Ralph execution mode, risk handling, and verification strategy.
4. `ralph`: set or read the required execution mode, then execute the approved plan or concrete PRD according to that mode.
5. `test-driven-development`: run inside `ralph`, `systematic-debugging`, `autopilot`, or an explicitly chosen tiny direct edit path before behavior-changing production edits and bug fixes.
6. `systematic-debugging`: enter whenever a failing command, regression, flaky result, or unknown root cause blocks progress.
7. `simplify`: clean reuse, simplification, efficiency, and altitude issues only after behavior is locked and functional review has passed.
8. `verification-before-completion`: check fresh evidence before any final "done", "fixed", "passing", or "ready" claim.

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

The host agent, not the user, operates the workflow. The active platform wrapper
reads the selected skill core, invokes any allowed role agents, writes
artifacts, and runs verification. The user should only need to approve stage
outputs, choose a clearly named next workflow step, or correct direction when
the agent asks.

When describing the staged workflow, call the requirements-discovery stage `interview`, not a generic clarify phase.

## Worktree Isolation Default

For write-capable coding work, apply `docs/shared/worktree-isolation.md` before
editing source files.

`interview` and `ralplan` do not need to run inside a worktree by default because
they produce pre-execution artifacts. The worktree gate starts at execution:
direct `ralph` creates or selects a task worktree by default, records
`Worktree decision: direct automatic worktree`, and does not edit files until
that decision is visible.

`autopilot` is the orchestration exception because it also owns integration back
into the original checkout. When it reaches write-capable execution, it records
`Worktree decision: autopilot automatic worktree`, creates or selects a task
worktree, executes there, merges into the integration checkout, and runs
post-merge verification.

## Interview Gate

Before asking the user a clarification, scope, preference, or approval question:

1. Check whether the question exists because the request is broad, vague, ambiguous, or missing requirements, constraints, acceptance criteria, or user intent. If yes, read and follow `interview` first.
2. Check whether the question exists because the implementation strategy, sequencing, architecture, risk, or tradeoff is unclear. If yes, read and follow `ralplan` first.
3. Check whether the question exists because a failing command, regression, flaky behavior, or unknown root cause is blocking progress. If yes, read and follow `systematic-debugging` first.
4. Check whether the question is part of an already-selected workflow skill. If yes, ask it through that skill's rules.

Do not ask raw clarification questions for vague work before reading `interview`, unless the user explicitly tells you not to use the skill.

## Skill Chaining

Skill chaining is explicit Markdown guidance, not hidden automation.

When a skill defines a `Next Skill Handoff`, you MUST present the handoff to the user and wait for an explicit choice before invoking the next workflow skill. Present the options as actions the host agent will take, not commands the user must run manually. Do not auto-invoke the next workflow skill, even when a single recommended choice is named. The user's answer is the trigger.

Workflow skills (`interview`, `ralplan`, `ralph`) currently define this handoff. The recommended path is `interview → ralplan → ralph`, but each transition is a distinct user-confirmed step.

Internal mid-loop skills used inside an already-invoked workflow skill - for example `test-driven-development`, `simplify`, `verification-before-completion`, and `systematic-debugging` invoked from inside `ralph`'s execution loop - are part of that skill's documented procedure and do not require a separate per-step transition question.

The single exception is `autopilot`. When the user invokes `autopilot`, autopilot may move between `interview`, `ralplan`, and `ralph` without the per-step transition question. Content-approval gates inside the sub-skills (spec review, plan approval, final-completion verification) still run.

If the user overrides any recommendation, follow the user's instruction unless it would violate safety or repository constraints.

## Platform Notes

This core file does not define platform invocation syntax. Apply the active
public skill wrapper and the matching platform file named by that wrapper.

When a skill names an agent role, adapt the role through the active platform
file. Agents remain role prompts inside a selected skill; they do not own
artifact gates, approval gates, or next-skill handoffs.

Agents are role prompts inside a selected skill, not workflow entrypoints. An agent can recommend another role or workflow skill to the caller, but it does not own artifact gates, approval gates, or next-skill handoffs.

## Artifact Paths

Use `.oh-no/specs/` for generated specs.

Use `.oh-no/plans/` for generated plans.

Use `.oh-no/sessions/` for transient session artifacts.

Do not use legacy harness artifact paths.

## No Hidden Orchestration

Oh No Harness does not include an automatic mode controller or external state ledger.

If a workflow requires persistence, the persistence requirement lives in the skill text and in written artifacts.
