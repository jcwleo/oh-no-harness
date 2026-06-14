# Development Requirements Coverage

Use this shared taxonomy when `interview` or `ralplan` needs to surface
implementation-sensitive requirements without turning requirements discovery
into implementation planning.

## Purpose

Development requirements coverage keeps downstream planning and execution from
missing constraints that often change implementation shape, verification proof,
or release risk. It records what must be preserved, proven, or escalated; it
does not choose the implementation.

Use repository evidence for inspectable facts. Ask the user only when an
inferred answer changes behavior, architecture, data handling, security
posture, delivery scope, public support claims, or the smallest credible proof.

## Coverage Taxonomy

For Standard and Deep interviews, and for ralplan gap checks when the source
lacks coverage, classify each category as `required`, `not applicable`, or
`accepted assumption` with a source and downstream implication:

- Behavior, API, UI, or workflow contract
- Data model, persistence, migration, and backward compatibility
- Security, privacy, auth, permissions, and secrets
- Runtime, deployment, configuration, rollback, and release
- Observability, logging, monitoring, and operator feedback
- Performance, scale, latency, reliability, and concurrency
- Compatibility, accessibility, localization, and platform support
- External services, network boundaries, rate limits, and third-party contracts
- Verification commands, fixtures, manual checks, and smallest credible proof

If a required category is unresolved and would change the plan or execution
profile, keep the work pending approval instead of hiding the gap in assumptions.

## Interview Record

Standard and Deep interview specs record the full coverage block:

```text
Development requirements coverage:
- Source/evidence:
- Coverage status: complete | pending approval
- Required items by taxonomy category:
- Not applicable items:
- Accepted assumptions to escalate if wrong:
- Pending approval gaps:
```

Quick mode is exempt and no coverage block is required.

## Ralplan Carryover Record

Ralplan carries approved interview coverage forward instead of repeating the
full interview. When coverage is absent or stale, run Analyst or a limited
Analyst gap check and record only planning implications:

```text
Development requirements carryover:
- Source: approved interview spec | analyst gap check | PRD/ticket | user request
- Coverage status: carried forward | gap check completed | pending approval
- Required planning inputs:
- Not applicable decisions carried forward:
- Accepted assumptions to preserve or escalate:
- Pending approval gaps:
```

Use `approved interview coverage` when a current approved spec already contains
the taxonomy classifications. Use `limited Analyst gap check` when the source is
a PRD, ticket, user request, or older spec without adequate coverage.
