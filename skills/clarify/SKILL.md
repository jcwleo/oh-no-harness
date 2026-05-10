---
name: clarify
description: "Clarify a feature, refactor, bugfix, or product idea into an SDD-ready spec before planning or implementation. Uses a default clarification mode plus --deep for high-risk or high-ambiguity requirement pressure."
when_to_use: "Use before implementation when a request is ambiguous, design-shaped, risky, or likely to benefit from a written spec; use --deep for high-risk or high-ambiguity work."
argument-hint: "[--deep]"
---

# clarify

Clarify converts ambiguous, creative, risky, or underspecified work into a written spec before planning or implementation. It combines:

- a default clarification path for ordinary feature/refactor work and creative product/UX/behavior design, including alternatives, trade-offs, recommendation, and user approval when design choices matter;
- rigorous requirement narrowing for ambiguous or high-risk work (`--deep`), including Socratic pressure, weakest-dimension targeting, non-goal and decision-boundary gates, and explicit residual-risk capture.

## Use when

- The request involves a new feature, UX/product-shape decision, behavior change, creative direction, or "make this better/natural" improvement and the user has not already supplied a concrete implementation target.
- The request has unclear intent, scope, constraints, non-goals, success criteria, or ownership boundaries.
- The user asks for brainstorming, design exploration, an interview-style clarification, or says not to assume.
- The task may outgrow the current context window and needs a durable spec first.
- Jumping to code would risk building the wrong thing, hiding unresolved requirements, or losing context.

## Do not use when

- The task is already concrete, bounded, and testable enough to execute directly.
- The user explicitly asks to skip clarification and the risk is low; record any remaining uncertainty in the downstream plan instead.
- The user asks for investigation/debugging only; use `debug` unless a fix/spec boundary must be clarified first.

## Hard gate

`clarify` does not mutate product source code, scaffold implementation, push, open PRs, or invoke execution work. It may only inspect evidence and write/update the spec artifact. If the host workflow explicitly requires committing planning artifacts, commit only the approved spec artifact and follow the repo commit protocol; otherwise leave the spec uncommitted. The terminal state is a handoff to `planning` or `planning --ral`, not direct implementation.

Do not bypass this gate because the change looks simple. For small work, the spec can be short, but goals, boundaries, acceptance criteria, and verification must still be explicit enough for safe planning.

## Mode selection

There are exactly two clarify modes:

- `clarify`: the default mode for ordinary feature/refactor clarification and lightweight design exploration. Use it for new features, UX/product-shape changes, behavior design, creative direction, naturalness improvements, and normal scope/acceptance-criteria cleanup.
- `clarify --deep`: the high-rigor mode for high-risk, high-ambiguity, security-sensitive, migration, public API, broad architecture, data-safety, or explicit "do not assume" work.

`clarify --ral` is not a valid mode. `--ral` belongs to `planning --ral`, after the desired outcome is clear enough to plan. If a user appears to want both deeper clarification and stronger plan review, use `clarify --deep` first, then hand off to `planning --ral`.

If no mode is provided, use default `clarify` unless hidden assumptions, decision authority, safety, data loss, compatibility, rollback risk, or external contracts would materially change execution. Escalate to `clarify --deep` when those risks are present.

Keep the mode choice simple to avoid both failure modes: under-clarifying work that needs risk pressure, and over-interviewing small changes that only need the default path.

## Pre-work routing prompt

When a request looks like implementation is about to begin but the right route is not obvious, recommend one path before writing code. Keep it short:

1. Name the recommended path, such as `clarify`, `clarify --deep`, `planning`, `planning --ral`, or direct execution.
2. Give one concrete reason.
3. Offer only realistic alternatives.
4. Ask the user which route to take.

Do not show this prompt for tiny concrete edits, explicit skill invocations, or cases where the user already chose the route.

## Common workflow

1. Restate the target outcome in one or two sentences.
2. Inspect repository facts before asking about facts the code can answer; start from explicit paths, symbols, logs, tests, docs, or recent changes supplied by the user.
3. If the initial request or pasted context is too large to preserve safely, first create a concise prompt-safe summary that keeps goals, constraints, success criteria, non-goals, decision boundaries, and cited evidence. Use the summary for the rest of clarification and record the summarization in the spec.
4. Classify remaining unknowns as:
   - **facts to inspect**: discoverable from repository, logs, tests, or docs;
   - **facts to confirm**: code evidence exists but requires user intent confirmation;
   - **human decisions**: goals, trade-offs, non-goals, decision boundaries, success criteria.
5. Ask one focused question at a time when user input is required. Prefer multiple-choice options when the valid choices are known; use open-ended questions when the answer space is genuinely unknown.
6. Separate goals, non-goals, constraints, assumptions, open questions, and residual risks as the clarification proceeds.
7. Stop clarifying only when the mode-specific gates below are satisfied or the user chooses early exit with risk recorded.
8. Write or update the spec artifact.

## Default workflow

Use default `clarify` to turn ordinary feature/refactor requirements or creative product/UX/behavior ideas into an approved spec.

Required sequence:

1. **Explore context**: inspect relevant files, docs, examples, current patterns, and recent changes before proposing a design.
2. **Scope check**: if the idea contains multiple independent subsystems, identify them and recommend splitting into separate specs before drilling into details.
3. **Clarify intent**: ask one question at a time about purpose, users, constraints, success criteria, and what should not change.
4. **Clarify requirements**: make the goal, in-scope and out-of-scope boundaries, constraints, assumptions, acceptance criteria, and regression guards explicit.
5. **Propose approaches when choices matter**: for creative or behavior-shaping work, present 2-3 viable approaches with trade-offs. Lead with the recommended option and explain why.
6. **Present the direction**: summarize architecture, components, data flow, user-visible behavior, error handling, and testing/verification when relevant. Scale detail to complexity.
7. **Approval gate**: get user approval of the direction before writing the final spec when the direction changes user-visible behavior, architecture, data shape, or scope. If approval is partial, revise the disputed section and ask again.
8. **Spec self-review**: after writing the spec, scan for placeholders, contradictions, vague requirements, missing non-goals, scope creep, and untestable acceptance criteria. Fix issues inline.
9. **Written-spec review gate**: ask the user to review the written spec before planning. If changes are requested, update the spec and repeat the self-review.
10. **Commit gate**: if the repo/user workflow expects committed spec artifacts, commit only the spec artifact after written-spec approval and follow the repo commit protocol. Otherwise keep it as a working-tree artifact.
11. **Handoff**: hand off to `planning` only after the spec is reviewable and approved or after explicit early exit with risk recorded.

Design principles:

- Keep designs small and well-bounded. Prefer existing utilities and patterns over new abstractions.
- Include targeted cleanup only when it directly serves the current goal; do not add unrelated refactors.
- Treat visual work specially: when layouts, mockups, diagrams, or visual comparisons would materially clarify decisions, offer to create or inspect visual references before finalizing the design. Do not block non-visual conceptual questions on visual tooling.

Default readiness gates:

- Goal is stated in one sentence without ambiguous nouns.
- In-scope and out-of-scope boundaries are explicit.
- Constraints and assumptions are listed separately.
- Acceptance criteria are testable enough to become `AC-*` entries.
- Invariants/regression guards are explicit enough to become `INV-*` entries.
- Remaining open questions are recorded as `OQ-*` and do not block safe planning.

If an unknown would change architecture, data shape, external contracts, migration safety, or user-visible behavior in a high-risk way, escalate to `--deep`.

## `--deep` workflow

Use `--deep` to apply deep-interview-style pressure before planning.

### Clarity dimensions

Track clarity across these dimensions throughout the interview:

- **Intent**: why the user wants this and what problem it solves.
- **Outcome**: what end state should be true.
- **Scope**: how far the change should go and where it stops.
- **Constraints**: technical, product, safety, compatibility, migration, timing, and operational limits.
- **Success criteria**: what evidence proves the work is done.
- **Context**: how the request fits the current codebase or system, for brownfield work.
- **Non-goals**: what must explicitly stay out of scope.
- **Decision boundaries**: what the agent may decide without confirmation and what requires user approval.

### Interview loop

Repeat until the readiness gates are satisfied, the user exits early with risk recorded, or further questions would not materially change planning:

1. If the request has multiple top-level components, enumerate them first and ask one topology-confirmation question before depth-first clarification. Record active, deferred, merged, or split components.
2. Target the weakest clarity dimension, not a random new topic.
3. Ask exactly one focused question.
4. Treat each answer as a claim to pressure-test before moving on.
5. Use at least one pressure pass before crystallizing the spec:
   - ask for a concrete example, counterexample, or evidence signal;
   - expose a hidden assumption or dependency;
   - force a boundary or trade-off;
   - reframe symptoms toward the underlying cause or desired outcome.
6. For multi-component requests, keep a lightweight topology ledger: list each top-level component, whether it is active or deferred, and whether goal/constraint/success clarity is sufficient for that component. Do not let a well-described component hide ambiguity in sibling components.
7. For conceptually unstable requests, keep an ontology note: identify the core entities/nouns and stabilize their meanings before asking feature-detail questions.
8. When stuck or after several rounds without convergence, switch the next question into one challenge mode:
   - **Contrarian**: ask what would make the current direction wrong.
   - **Simplifier**: ask what can be removed while preserving value.
   - **Ontologist**: ask what the core entity or problem really is.
9. After each answer, update a qualitative clarity status: `blocked`, `partial`, or `ready` for each dimension. For extra-rigorous runs, optionally convert these to an ambiguity rubric (`blocked=0`, `partial=0.5`, `ready=1`) and continue until all mandatory gates are `ready` and residual ambiguity is low. Use this as an in-session rubric, not hidden persistent state.

Mandatory readiness gates for `--deep`:

- Non-goals are explicit.
- Decision boundaries are explicit.
- Acceptance criteria are testable.
- Residual risks and unresolved assumptions are recorded.
- Brownfield codebase facts that can be inspected have been inspected or are listed as retrieval gaps.
- At least one pressure pass has challenged a prior answer.

Early exit is allowed only if the user explicitly chooses it. Record the warning in the spec decision log and hand off to `planning --ral` when risk remains material. Do not bridge from `clarify --deep` to implementation directly; planning remains a separate approval boundary.

## Spec artifact

Write the spec to:

```text
docs/oh-no/specs/YYYY-MM-DD-<slug>-spec.md
```

Use `templates/spec.md` as the preferred base structure. Extend it with mode-specific sections when needed. The spec must include:

- Date, slug, mode, and status.
- Retrieval basis: user evidence, repository evidence checked, and unknowns after retrieval.
- Prompt-safe summary note when oversized initial context was summarized.
- Goal.
- Non-goals.
- User-visible behavior.
- Scope boundaries.
- Constraints and assumptions.
- Acceptance criteria with stable IDs: `AC-001`, `AC-002`, ...
- Invariants and regression guards: `INV-001`, `INV-002`, ...
- Decisions: `DEC-001`, `DEC-002`, ...
- Open questions: `OQ-001`, `OQ-002`, ...
- Affected files or modules when known.
- Verification matrix.
- Decision log.

For default mode when design choices matter, also include:

- Considered approaches and trade-offs.
- Recommended design and rationale.
- Design approval status or explicit early-exit note.

For `--deep`, also include:

- Clarity breakdown by dimension.
- Non-goal and decision-boundary gates.
- Topology ledger for multi-component work, when applicable.
- Core entity/ontology notes for conceptually unstable work, when applicable.
- Pressure-pass notes: assumption challenged, trade-off forced, or example/counterexample captured.
- Residual risks and planning warnings.

## Role passes

Use role passes only when they reduce ambiguity:

- `explore`: inspect named files, symbols, logs, tests, docs, or nearby repo patterns before asking about facts the repository can answer.
- `analyst`: use for `--deep`, high ambiguity, hidden requirements, acceptance criteria, non-goals, decision boundaries, and edge-case discovery.

If native subagents are unavailable, perform these as current-session read-only passes and state that fallback when relevant.

## Root-cause clarification

For bugs, regressions, flaky behavior, and unexplained failures, clarify the evidence needed to find the root cause. Do not frame the desired outcome as a temporary workaround unless the user explicitly asks for mitigation first. If existing evidence is insufficient, capture what targeted diagnostic logging, tracing, assertions, or reproduction steps would make the cause observable.

## Completion integrity

Do not cut corners. Inspect required evidence directly, do not use placeholders or cherry-picked results, and report blockers or verification gaps instead of pretending completion. Follow the bootstrap completion-integrity rule.

Before completing `clarify`, verify:

- The selected mode is recorded.
- Required mode gates are satisfied or an early-exit risk is recorded.
- The spec has no placeholders, unresolved contradictions, or fake certainty.
- `AC-*`, `INV-*`, `DEC-*`, and `OQ-*` IDs are stable and meaningful.
- Retrieval gaps are explicit rather than hidden.
- Handoff target is correct.

## Guardrails

- Do not implement source changes in `clarify`.
- Do not hide unresolved requirements; record them as `OQ-*` or residual risks.
- Do not ask batches of unrelated questions.
- Do not ask the user for codebase facts that can be inspected directly.
- Do not over-interview once remaining ambiguity would not change planning.
- Do not preserve heavyweight upstream runtime requirements such as hidden state machines, HUDs, stop hooks, or mandatory numeric scoring; this harness is artifact-first.

## Handoff

- Use `planning` for ordinary executable plans from approved or sufficiently clear specs.
- Use `planning --ral` when the spec has architectural risk, broad scope, disputed trade-offs, unresolved residual risk, or any `--deep` early-exit warning.
- If the user asks to proceed with remaining uncertainty, record the risk and hand off to `planning --ral` unless the uncertainty is clearly low-impact.
