# Diagnostic logging

When evidence is insufficient, add targeted logging, tracing, or
assertions to expose the missing fact. Treat the instrumentation as a
debugging tool, not a feature.

## Rules

- **Bounded scope.** Instrument the smallest call path that can reveal
  the missing fact.
- **Bounded retention.** Remove the instrumentation before completion
  or gate it behind an intentional debug/observability switch.
- **No secrets.** Never log credentials, tokens, PII, or anything
  covered by the secrets sweep in `agents/code-reviewer.md`. Logging
  a token is a BLOCKER, even temporarily.
- **No hot-path spam.** Instrument at a level (DEBUG/TRACE) that does
  not drown production logs.
- **Correlatable.** Emit an ID or marker so logs can be correlated
  across hops (request-id, trace-id, batch-id).

## What to capture

- Inputs to the suspect function, redacted to non-sensitive fields.
- The branch taken (which `if`, which match arm, which retry).
- The state at the failure boundary (variable values, return shape,
  size of a collection).
- Time/duration when timing is plausibly the cause.

## When the instrumentation should stay

It can stay if it is useful production observability and was reviewed
under the same severity rules as a feature change. Otherwise it must
be removed before the verify report is filed.

The verify report records which logs were removed and which were
intentionally retained, so a reviewer can audit the decision.

## Cross-references

- `skills/debug/SKILL.md` — the diagnostic-logging step in the
  four-phase debug process.
- `skills/ralph/SKILL.md` — the root-cause discipline rule that
  forces removal/gating before completion.
- `agents/code-reviewer.md` — the severity for retained debug logs.
- `tests/acceptance/scenarios/02-failing-test-debug.md` — the
  evidence-first path that justifies adding instrumentation in the
  first place.
- `tests/acceptance/scenarios/07-planted-bug-secret-logging.md` —
  the BLOCKER case for logging a token.
