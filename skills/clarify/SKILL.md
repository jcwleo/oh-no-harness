---
name: clarify
description: "Clarify a feature, refactor, bugfix, or product idea into an SDD-ready spec before planning or implementation. Supports --design, --standard, and --deep profiles."
---

# clarify

Clarify converts ambiguous or creative work into a written spec. It combines lightweight design exploration with rigorous requirement narrowing while staying file/artifact based.

## Use when

- The request has unclear intent, scope, constraints, non-goals, or success criteria.
- The user asks for brainstorming, an interview-style clarification, or says not to assume.
- The task may outgrow the current context window and needs a durable spec first.

## Profiles

- `clarify --design`: creative feature, UX, behavior, or product-shape exploration.
- `clarify --standard`: normal feature/refactor clarification.
- `clarify --deep`: high-risk, high-ambiguity, security-sensitive, migration, public API, or explicit "do not assume" work.

If no profile is provided, choose the lightest profile that can remove the ambiguity.

## Process

1. Restate the target outcome in one or two sentences.
2. Inspect repository facts before asking about facts the code can answer; start from explicit paths, symbols, logs, or tests supplied by the user.
3. Ask one focused question at a time when user input is required.
4. Separate goals, non-goals, constraints, assumptions, and open questions.
5. Stop clarifying when the remaining ambiguity is low enough to plan safely.
6. Write or update a spec artifact.

## Spec artifact

Write the spec to:

```text
docs/oh-no/specs/YYYY-MM-DD-<slug>-spec.md
```

Use `templates/spec.md` as the preferred structure. The spec must include:

- Goal
- Non-goals
- User-visible behavior
- Scope boundaries
- Constraints and assumptions
- Acceptance criteria with stable IDs: `AC-001`, `AC-002`, ...
- Invariants and regression guards: `INV-001`, `INV-002`, ...
- Decisions: `DEC-001`, `DEC-002`, ...
- Open questions: `OQ-001`, `OQ-002`, ...
- Affected files or modules when known
- Verification matrix
- Decision log

## Role passes

Use role passes only when they reduce ambiguity:

- `explore`: inspect named files, symbols, logs, tests, or nearby repo patterns before asking about facts the repository can answer.
- `analyst`: use for `--deep`, high ambiguity, hidden requirements, acceptance criteria, non-goals, and edge-case discovery.

If native subagents are unavailable, perform these as current-session read-only passes and state that fallback when relevant.

## Root-cause clarification

For bugs, regressions, flaky behavior, and unexplained failures, clarify the evidence needed to find the root cause. Do not frame the desired outcome as a temporary workaround unless the user explicitly asks for mitigation first. If existing evidence is insufficient, capture what targeted diagnostic logging, tracing, assertions, or reproduction steps would make the cause observable.

## Completion integrity

Do not cut corners. Inspect required evidence directly, do not use placeholders or cherry-picked results, and report blockers or verification gaps instead of pretending completion. Follow the bootstrap completion-integrity rule.

## Guardrails

- Do not implement source changes in `clarify`.
- Do not hide unresolved requirements; record them as `OQ-*`.
- Do not ask batches of unrelated questions.
- If the user asks to proceed with remaining uncertainty, record the risk and hand off to `planning`.

## Handoff

- Use `planning` for ordinary executable plans.
- Use `planning --ral` when the spec has architectural risk, broad scope, or disputed tradeoffs.
