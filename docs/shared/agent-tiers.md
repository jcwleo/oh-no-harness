# Agent Selection Tiers

Use base agent names and choose the amount of scrutiny the task needs. This is not a model routing table. Follow the active platform's model policy unless the current workflow explicitly allows a model choice.

## Selection Matrix

| Work type | Base agent | Light involvement | Standard involvement | High-scrutiny involvement |
|---|---|---|---|---|
| Exploration | `explore` | locate known files or facts | map code paths and tests | discover unfamiliar or cross-system behavior |
| Analysis | `analyst` | check a narrow requirement | compare product, risk, and constraints | resolve ambiguous goals or conflicting requirements |
| Planning | `planner` | outline a small change | produce an implementation plan | sequence broad, risky, or multi-team work |
| Architecture | `architect` | check local design fit | evaluate feasibility and tradeoffs | decide architecture, migration, or boundary changes |
| Critique | `critic` | challenge a focused decision | gate a plan before execution | adversarially review high-risk assumptions |
| Execution | `executor` | apply scoped mechanical edits | implement normal stories | implement risky, coupled, or migration-heavy changes |
| Debugging | `debugger` | inspect a known failing command | trace multi-file failures | investigate unknown root causes or nondeterminism |
| Verification | `verifier` | check commands and outputs | validate acceptance criteria | build release-level confidence from multiple signals |
| Code review | `code-reviewer` | review a focused diff | review behavior-affecting changes | review regression-prone or broad changes |
| Security review | `security-reviewer` | check a narrow sensitive path | review data, auth, and policy risk | assess security-critical or externally exposed behavior |
| QA testing | `qa-tester` | run smoke scenarios | validate user-facing workflows | design scenario coverage for complex flows |

## Escalation Rules

- Start with the lightest involvement that can produce credible evidence.
- Escalate when the work affects security, data integrity, irreversible operations, concurrency, public contracts, or multiple subsystems.
- Escalate when requirements are ambiguous, the failure mode is unknown, or the first verification result is inconclusive.
- Do not invent tier-specific agent names. Use the base agent and state the desired scope, risk level, and evidence in the delegation prompt.
