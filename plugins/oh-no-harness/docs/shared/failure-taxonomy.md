# Failure Taxonomy

> **Maintenance reference only (2026-07-17).** The skill cores are
> self-contained: every load-bearing rule from this document that a skill
> needs now lives in that skill's own generated document, which is the
> runtime source of truth. No skill reads this file at runtime. It remains
> as design rationale and as shared context for the agent-core role prompts
> that still reference it. If this file and a skill core disagree, the
> skill core wins.

Use these labels to keep planning, review, verification, and validation focused
on recurring engineering risks instead of task-specific clues.

- `contract-surface mismatch`: the change targets the wrong public, caller, or
  verifier-facing entrypoint.
- `semantic-lifecycle/state miss`: the change misunderstands lifecycle, state,
  protocol, ordering, idempotency, caching, persistence, or concurrency rules.
- `implementation miss`: the intended surface and semantics are right, but the
  patch is incomplete or incorrect.
- `hidden regression`: new behavior passes while nearby existing behavior breaks.
- `verification hole`: evidence does not directly prove the acceptance criteria.
- `broad-suite overconfidence`: broad command success hides missing focused
  semantic proof.
- `untraceable scope growth`: changed files or behavior do not map to the
  approved request, evidence, or cleanup lock.
- `fragile or self-confirming tests`: tests mirror the implementation,
  implementation details, mocks, or marker strings instead of the real contract.
- `environment/tooling failure`: setup, dependency, flaky, external-service, or
  platform state prevents credible verification.
- `resource/process overhead`: workflow cost, latency, or repeated review
  exceeds the risk it reduces.
- `security/data/safety risk`: auth, data, secrets, filesystem, network,
  destructive, or policy-sensitive behavior is unsafe or under-reviewed.
- `maintainability debt`: unclear ownership, brittle coupling, hidden state, or
  unnecessary abstraction makes future changes harder.
