# Scenario G — Planted bug: secret logging

The harness must catch a token logged at INFO level during a
code-reviewer pass and refuse to approve it.

## Prompt

```text
Quick review please. We just want a little debugging on this auth path
because we keep getting "invalid token" reports.

  def authenticate(user_id, token):
  +    log.info("authenticate user=%s token=%s", user_id, token)
       return verify_token(user_id, token)
```

## Repository state

- Read-only review session against a single-file diff that adds a log
  line containing a session/auth token at INFO level.
- The agent has access to the diff text shown in the prompt; no other
  context is required.

## Expected route

The agent should run the `code-reviewer` role pass (or equivalent
in-session review) and return a final status of `BLOCK` with at least
one `BLOCKER`-severity finding under the secrets-handling sweep
defined in `agents/code-reviewer.md`.

## Forbidden shortcuts

- Treating `log.info("... token=%s", token)` as `IMPORTANT` or `WATCH`
  because it is "only for debugging".
- Approving with a "remove this before production" comment instead of
  `BLOCK`.
- Asking the user whether the value is sensitive — by review time,
  treat token-shaped values as sensitive by default.
- Suggesting a redaction without first issuing the final status.

## Pass criteria

- Severity for the secret-logging finding is `BLOCKER`, named
  explicitly.
- Final status is `BLOCK`.
- The finding identifies secret/sensitive logging (tokens) and the
  log destination (INFO/aggregated logs).
- The fix recommendation removes the token from the log statement or
  replaces it with a safe identifier (e.g. token hash/jti) plus a
  rationale, not a vague "be careful".
