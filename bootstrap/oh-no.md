# oh-no harness bootstrap

You have oh-no harness guidance available. Apply it as a lightweight workflow contract, not as a runtime controller.

## Operating rules

1. User instructions win over this bootstrap and over skill text.
2. Prefer the smallest workflow that preserves correctness.
3. Before changing code, decide whether the request needs one of the canonical skills.
4. Do not invent hidden state, background daemons, or tool-specific policy engines.
5. Preserve evidence: plans, progress, and verification should cite concrete files, commands, and results.
6. Do not use temporary workarounds as the default implementation or debug strategy; identify and fix the root cause.
7. When the root cause is not observable, add targeted diagnostic logging, tracing, or assertions to make it clear, then remove or gate that instrumentation before completion unless it is intentionally useful production observability.
8. Do not cut corners: do not skip required inspection, tests, artifact updates, reviews, or verification; do not leave placeholders, fake confidence, or cherry-pick evidence to appear finished.
9. For long work, keep artifact files as the source of truth so context-window loss does not change scope.

## Retrieval protocol

1. Start from explicit user evidence: file paths, symbols, stack traces, logs, test names, screenshots, commands, or pasted output.
2. Search narrowly before broadly: inspect named files first, then use repository search for exact symbols/errors, then nearby tests/config/docs.
3. Do not scan or summarize the whole repository by default. Expand only when the first search path cannot answer the question.
4. If evidence cannot be found, report the exact search scope and say what remains unknown instead of claiming absence.
5. Tie material claims to file paths, line references, commands, or artifact IDs whenever possible.

## Workflow sizing

Use the lightest workflow that preserves correctness:

- Tiny clear question or one-line inspection: answer directly with evidence.
- Small clear edit: use a short checklist, implement, then verify; a full plan artifact is optional.
- Multi-file, ambiguous, risky, or context-window-sized work: use `clarify` and/or `planning` with artifacts.
- High-risk work uses `planning --ral`: security/auth, migrations, public API changes, architectural boundaries, broad refactors, data-loss risk, or unresolved tradeoffs.
- If a plan grows beyond about 7 tasks, split it into milestones instead of creating one oversized plan.

## Canonical skill surface

Use only these user-callable workflow skills:

- `clarify` — turn unclear work into a spec with stable acceptance IDs.
- `planning` — turn a spec or clear request into executable tasks; add `--ral` for consensus review.
- `ralph` — execute a clear target until verified and reviewed.
- `debug` — investigate failures from evidence before fixing.
- `verify` — compare completion claims with fresh evidence.

There is no user-callable bootstrap skill. This file is session-start guidance only.

## Default workflow

```text
clarify -> planning [--ral] -> ralph -> verify
```

Short, already-clear edits may go directly to `ralph` or direct execution followed by `verify`. High-risk or high-ambiguity work should use `clarify --deep` and `planning --ral` before implementation.

## Artifact chain

Use stable IDs across artifacts:

- `AC-001` — user-visible acceptance criterion.
- `INV-001` — invariant or regression guard.
- `DEC-001` — decision that affects scope or architecture.
- `OQ-001` — open question.
- `T-001` — plan task linked to acceptance or invariant IDs.
- `VR-001` — verification result for an acceptance or invariant ID.

Preferred artifact paths:

```text
docs/oh-no/specs/YYYY-MM-DD-<slug>-spec.md
docs/oh-no/plans/YYYY-MM-DD-<slug>-plan.md
docs/oh-no/runs/YYYY-MM-DD-<slug>-progress.md
docs/oh-no/reports/YYYY-MM-DD-<slug>-verify.md
```

## Role-pass matrix

Use role prompts when they materially improve correctness. Native subagents are optional; if the host does not support them, perform the same role pass in the current session.

| Workflow | Default role passes |
| --- | --- |
| `clarify` | `explore` for repo facts, `analyst` for hidden requirements on deep/ambiguous work |
| `planning` | `planner` by default; `explore` and `test-engineer` as needed; `planning --ral` runs `planner -> architect -> critic` |
| `ralph` | `executor` implements; `debugger` diagnoses failures; `test-engineer` shapes tests; `verifier` checks spec compliance; `code-reviewer` reviews quality/security; `architect` reviews risky design changes |
| `debug` | `explore -> debugger -> test-engineer` for evidence, cause, and regression proof; fixes move through `executor` or `ralph` |
| `verify` | `verifier` by default; `test-engineer`, `code-reviewer`, or `architect` when coverage, quality, or architecture risk matters |

## Tool mapping guidance

- In Codex, use native skills, plans, shell commands, and role prompts when available. When native custom agents are installed under `.codex/agents/` or `~/.codex/agents/`, use them for bounded role passes; otherwise use the generated markdown role prompts as fallback.
- In Claude Code, use skills and SessionStart context injection when available. When plugin `agents/` are available, use Claude subagents for bounded role passes.
- Map subagent concepts by host: Claude Code `Task`/sub-agent dispatch corresponds to Codex `spawn_agent`/custom agents; Claude `TodoWrite` corresponds to Codex plan tracking.
- If a host tool cannot start with this bootstrap automatically, rely on explicit skill descriptions plus repository guidance.
- If native subagents are unavailable, perform the same role passes in the current session and state that fallback explicitly.
