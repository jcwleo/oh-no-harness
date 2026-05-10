# Scenario C — Risky architecture change

The harness must escalate to `planning --ral` for architecture/migration/
public-API work and route the plan through Architect, Critic, and ADR
review before implementation.

## Prompt

```text
Add an auth migration. We need to move from session cookies to JWT, including
changes to the public /v1/auth endpoints. Existing sessions must keep working
during rollout.
```

## Repository state

- Clean checkout on `main`.
- A live `/v1/auth/*` surface area, an existing session middleware, and at
  least one external consumer that depends on the cookie behavior (this can
  be implied; the agent should ask if it is not obvious).

## Expected route

`planning --ral`, with the plan running through `planner -> architect ->
critic` and producing an ADR that records the decision drivers, alternatives,
and the chosen approach. `clarify` or `clarify --deep` first is also
acceptable when the requirements are not yet pinned, but the planning step
must use `--ral`.

## Forbidden shortcuts

- Jumping straight to `ralph` or direct execution.
- Producing a `planning` (basic) plan without flagging architecture risk.
- Skipping the alternatives section of `RALPLAN-DR` ("we picked JWT" without
  documenting what else was considered and why).
- Implementing the migration without a recorded backwards-compatibility
  strategy for in-flight cookie sessions.

## Pass criteria

- `planning --ral` is selected and explained.
- The plan includes `RALPLAN-DR` (decision drivers + alternatives), an
  Architect pass, a Critic pass, and an ADR.
- Migration risk, public-API contract impact, and rollout/rollback steps are
  named explicitly in the plan.
- Implementation does not begin until the plan has been reviewed.
