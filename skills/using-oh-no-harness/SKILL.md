---
name: using-oh-no-harness
description: Use when starting a session with Oh No Harness, deciding whether a local skill applies, selecting between interview, planning, execution, debugging, TDD, cleanup, or verification skills, handling a request that may need one, or asking a clarification question.
---

# Using Oh No Harness

Oh No Harness is a lightweight skill harness. Claude Code may receive this skill as session-start bootstrap context; Codex discovers it through native skill loading.

## Core Rule

Before any response or action, including clarification questions, check whether a local Oh No Harness skill could apply.

If there is even a small chance that a local skill applies, read that skill before responding and follow it directly. If the selected skill turns out not to apply, say so briefly and continue with the next best path.

Needing more context is not a reason to skip skill selection. It is often the signal that `deep-interview`, `ralplan`, `systematic-debugging`, or another local skill should be read first.

The available public skills are:

- `deep-interview`: clarify vague product, design, or engineering requests into an approved spec.
- `ralplan`: create a consensus implementation plan before execution.
- `ralph`: execute a concrete PRD or approved plan until acceptance criteria and verification are satisfied.
- `autopilot`: orchestrate interview, planning, execution, QA, and final validation for larger end-to-end work.
- `auto-routing`: toggle stronger SessionStart skill-selection guidance for users who want it.
- `test-driven-development`: enforce RED/GREEN/REFACTOR before behavior-changing production edits.
- `ai-slop-cleaner`: remove AI-generated code slop while preserving behavior.
- `verification-before-completion`: verify evidence before claiming work is complete, fixed, passing, or ready.
- `systematic-debugging`: investigate bugs, failing commands, regressions, and unexpected behavior before fixing.

## Clarification Gate

Before asking the user a clarification, scope, preference, or approval question:

1. Check whether the question exists because the request is broad, vague, ambiguous, or missing requirements, constraints, acceptance criteria, or user intent. If yes, read and follow `deep-interview` first.
2. Check whether the question exists because the implementation strategy, sequencing, architecture, risk, or tradeoff is unclear. If yes, read and follow `ralplan` first.
3. Check whether the question is part of an already-selected workflow skill. If yes, ask it through that skill's rules.

Do not ask raw clarification questions for vague work before reading `deep-interview`, unless the user explicitly tells you not to use the skill.

## Skill Chaining

Skill chaining is explicit Markdown guidance, not hidden automation.

When a skill defines a `Next Skill Handoff`, you MUST present the handoff to the user and wait for an explicit choice before invoking the next workflow skill. Do not auto-invoke the next workflow skill, even when a single recommended choice is named. The user's answer is the trigger.

Workflow skills (`deep-interview`, `ralplan`, `ralph`) currently define this handoff. The recommended path is `deep-interview → ralplan → ralph`, but each transition is a distinct user-confirmed step.

Internal mid-loop skills used inside an already-invoked workflow skill — for example `test-driven-development`, `ai-slop-cleaner`, `verification-before-completion`, and `systematic-debugging` invoked from inside `ralph`'s execution loop — are part of that skill's documented procedure and do not require a separate per-step transition question.

The single exception is `autopilot`. When the user invokes `autopilot`, autopilot may move between `deep-interview`, `ralplan`, and `ralph` without the per-step transition question. Content-approval gates inside the sub-skills (spec review, plan approval, final-completion verification) still run.

If the user overrides any recommendation, follow the user's instruction unless it would violate safety or repository constraints.

## Platform Notes

Claude Code may expose skills through its own skill mechanism.

Codex exposes skills through native skill loading and may use subagents only when the user explicitly authorizes delegation.

When a skill names an agent role, adapt it to the current harness:

- Claude Code: use the available Task/subagent mechanism.
- Codex: use `spawn_agent` only when the user explicitly requested subagents or parallel delegation; otherwise perform the work inline and preserve the same role boundaries.

## Artifact Paths

Use `.oh-no/specs/` for generated specs.

Use `.oh-no/plans/` for generated plans.

Use `.oh-no/sessions/` for transient session artifacts.

Do not use legacy harness artifact paths.

## No Hidden Orchestration

Oh No Harness does not include an automatic mode controller or external state ledger.

If a workflow requires persistence, the persistence requirement lives in the skill text and in written artifacts.
