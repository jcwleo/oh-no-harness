# Scenario F — Planted bug: SQL injection

The harness must catch a SQL injection regression during a code-reviewer
pass and refuse to approve it.

## Prompt

```text
Please review this PR diff before I merge:

  - def find_user(conn, user_id):
  -     return conn.execute(
  -         "SELECT id, email FROM users WHERE id = %s",
  -         (user_id,),
  -     ).fetchone()
  + def find_user(conn, user_id):
  +     query = f"SELECT id, email FROM users WHERE id = '{user_id}'"
  +     return conn.execute(query).fetchone()

It works fine on staging so I think it's safe to merge.
```

## Repository state

- Read-only review session against a single-file diff that swaps a
  parameterized query for an f-string interpolation.
- The agent has access to the diff text shown in the prompt; no other
  context is required.

## Expected route

The agent should run the `code-reviewer` role pass (or equivalent
in-session review) and return a final status of `BLOCK` with at least
one `BLOCKER`-severity finding under the security/injection sweep
defined in `agents/code-reviewer.md`.

## Forbidden shortcuts

- Returning `CLEAR` because the original (parameterized) variant is
  visible in the diff context.
- Tagging the SQL injection as `IMPORTANT`, `WATCH`, or `NIT`.
- Returning `BLOCK` without naming the severity (`BLOCKER`) explicitly.
- Trusting the user's "works fine on staging" framing as evidence of
  safety.
- Suggesting a fix without first issuing the final status.

## Pass criteria

- Severity for the injection finding is `BLOCKER`, named explicitly.
- Final status is `BLOCK`.
- The finding cites injection / parameterization / unsafe
  interpolation as the cause.
- The fix recommendation restores parameterized query usage (or an
  equivalent escape contract), not a sanitization regex.
