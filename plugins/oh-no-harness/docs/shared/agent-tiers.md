# Agent Selection Tiers

Use base agent names and choose the amount of scrutiny the task needs. This is not a model routing table. Follow the active platform's model policy unless the current workflow explicitly allows a model choice.

## Selection Matrix

| Work type | Base agent | Light involvement | Standard involvement | High-scrutiny involvement |
|---|---|---|---|---|
| Exploration | `explore` | locate known files or facts | map code paths and tests | discover unfamiliar or cross-system behavior |
| Analysis | `analyst` | check a narrow requirement | compare product, risk, and constraints | resolve ambiguous goals or conflicting requirements |
| Planning | `planner` | outline a small change | produce an implementation plan | sequence broad, risky, or multi-team work |
| Plan review | `plan-reviewer` | check local design fit or challenge a focused decision | gate a plan before execution with feasibility and tradeoff review | adversarially review architecture, migration, boundary changes, and high-risk assumptions |
| Execution | `executor` | apply scoped mechanical edits | implement normal stories | implement risky, coupled, or migration-heavy changes |
| Debugging | `debugger` | inspect a known failing command | trace multi-file failures | investigate unknown root causes or nondeterminism |
| Verification | `verifier` | check commands and outputs | validate acceptance criteria | build release-level confidence from multiple signals |
| Code review | `code-reviewer` | review a focused diff | review behavior-affecting changes | review regression-prone or broad changes |
| Security review | `security-reviewer` | check a narrow sensitive path | review data, auth, and policy risk | assess security-critical or externally exposed behavior |
| QA testing | `qa-tester` | run smoke scenarios | validate user-facing workflows | design scenario coverage for complex flows |

## Invocation Policy

The active skill decides whether a role should be handled inline or dispatched.
For Ralph-driven work, follow the selected execution mode and agent policy from
`docs/shared/execution-modes.md`.

This file is not a dispatch contract. Ralph dispatch uses
`docs/shared/ralph-subagent-policy.md` plus the active platform adapter:
`docs/platforms/claude-code-ralph.md` for Claude Code or
`docs/platforms/codex-ralph.md` for Codex. Use this file only to choose the
lightest credible level of scrutiny for a role after the active skill has
decided that the role is needed.

Inline execution is appropriate only for tiny LIGHT work, platforms without
subagents, missing dispatch-worthy scope, tight sequencing, or checks that have
no meaningful context-separation benefit. Prefer dispatch for read-heavy,
review, verification, QA, security, and exploration roles whenever the active
skill and host policy allow it. The Escalation Rules below still govern when to
climb tiers.

## Skill Boundary

Agent tier selection does not select or invoke a workflow skill. The active skill decides the software-development stage, owns approvals, and controls any next-skill handoff. Agents return facts, edits, reviews, or recommendations to the caller; recommended next roles or skills are proposals for the caller to route.

## Escalation Rules

- Start with the lightest involvement that can produce credible evidence.
- Escalate when the work affects security, data integrity, irreversible operations, concurrency, public contracts, or multiple subsystems.
- Escalate when requirements are ambiguous, the failure mode is unknown, or the first verification result is inconclusive.
- Do not invent tier-specific agent names. Use the base agent and state the desired scope, risk level, and evidence in the delegation prompt.
