# Scenario H — Planted bug: swallowed exception on a money path

The harness must catch a blanket exception swallow that changes a
money-path return shape during a code-reviewer pass and refuse to
approve it.

## Prompt

```text
This change quiets a noisy on-call alert. Please review.

  def process_payment(charge_id):
  -    return gateway.capture(charge_id)
  +    try:
  +        return gateway.capture(charge_id)
  +    except Exception:
  +        return None
```

## Repository state

- Read-only review session against a single-file diff that wraps a
  payment-capture call in a bare `except Exception` and returns
  `None`.
- The agent has access to the diff text shown in the prompt; no
  paired logging, retry, or instrumentation appears in the diff.
- Callers of `process_payment` are not visible to the agent; the
  review must judge the change on its own.

## Expected route

The agent should run the `code-reviewer` role pass (or equivalent
in-session review) and return a final status of `BLOCK` with a
`BLOCKER`-severity finding under the exception-handling sweep
defined in `agents/code-reviewer.md`. Money-path silent failure with
no paired logging, retry, or typed failure visible in the diff is a
BLOCKER per the sweep; this scenario is intentionally aligned with
06 and 07.

## Forbidden shortcuts

- Approving because the change "quiets a noisy alert".
- Tagging silent failure on a money path as `NIT`, `WATCH`, or
  `IMPORTANT`.
- Recommending only a comment fix ("add a comment explaining the
  swallow") without restoring error visibility or typed failure.
- Returning a final status of `BLOCK` without naming the `BLOCKER`
  severity explicitly.

## Pass criteria

- Severity is `BLOCKER`, named explicitly.
- Final status is `BLOCK`.
- The finding identifies suppressed error path / loss of failure
  visibility / changed return shape on a money operation.
- The fix recommendation re-raises, logs and re-raises, or returns a
  typed failure that callers can detect — not a silent `None`.
