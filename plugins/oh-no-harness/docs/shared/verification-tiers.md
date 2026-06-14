# Verification Tiers

Use the lightest tier that gives credible evidence for the change.

Verification tier is not the same as Ralph execution mode. Use
`docs/shared/execution-modes.md` to decide artifacts, dispatch, review, cleanup,
and persistence; use this file to decide evidence strength.

If risk is unclear, choose the higher tier. If a check cannot be run, say why and record the residual risk.

When verification is informed by measurable evidence, also apply
`docs/shared/validation-check.md`. Measurable evidence is diagnostic evidence,
not the acceptance criteria.

Every tier uses acceptance-to-evidence mapping. A command list is not enough:
state which requested behavior each command, inspection, or manual scenario
proves, and whether that evidence is direct, indirect, manual, or missing.

Every behavior-changing tier also uses a risk check before completion. Ask what a
skeptical maintainer or user would test next, then add direct semantic evidence
when practical. This is category-level risk modeling, not case-specific
optimization.

Every write-capable tier also applies the baseline guard from
`docs/shared/finite-delivery-contract.md`: classify existing public-contract
evidence as required or not applicable, then run or inspect that evidence before
the final claim.

When the baseline guard is required, verification must include the baseline
evidence record from `docs/shared/finite-delivery-contract.md`. Missing command
status, missing adjacency explanation, or missing inspection result is a failed
verification state, not a passing result with lower confidence.

Verification budget policy:

- Prefer focused semantic evidence before broad suites.
- Run broad suites when shared behavior, public APIs, generated artifacts,
  concurrency, persistence, or cross-package contracts could be affected.
- Apply the contract-risk rules from `docs/shared/finite-delivery-contract.md`:
  stale state does not leak, change streams include a negative/noise check,
  parser and protocol work includes a compatibility baseline check with
  existing fixtures or docs examples when runnable, named risks become an
  executable contract probe, and crash-prone checks use the Runtime Stability
  Baseline before substituting narrower evidence.
- Treat baseline evidence as a guardrail, not as optional confidence padding:
  if the nearby existing contract fails, use `systematic-debugging` before
  claiming completion.
- Avoid repeated broad-suite reruns that do not follow a meaningful patch change
  or a patch-related failure.
- Reuse expensive broad evidence when the patch was integrated byte-for-byte and
  a smaller final-checkout smoke proves the same patch is active; record the
  patch identity check and residual risk instead of rerunning for confidence.
- If a broad suite is noisy, slow, flaky, or external-service-dependent, record
  the limitation and spend the next check on a smaller direct semantic test.

## LIGHT

Use for non-runtime documentation, comments, formatting, or small isolated edits that cannot affect user-visible behavior, persisted data, permissions, or external systems.

Required evidence:

- Inspect changed files.
- Run the smallest relevant syntax or formatting check when one exists.
- Confirm the change matches the requested scope.
- Map the requested change to the inspection or command that proves it.
- Record command output, or explain why no command applies.

Recommended agents:

- `verifier` for independent evidence checks.

## STANDARD

Use for localized behavior changes, bug fixes, refactors with expected behavior preservation, configuration changes with limited blast radius, or instruction changes that alter agent behavior.

Required evidence:

- Inspect changed files.
- Run relevant lint, typecheck, unit, script, or scenario checks.
- Validate acceptance criteria.
- Map every acceptance criterion to direct, indirect, manual, or missing
  evidence.
- Record the risk check before completion and any direct semantic test added because of it.
- Record baseline guard status from `docs/shared/finite-delivery-contract.md`.
- Record the baseline evidence record when the baseline guard is required.
- Record compatibility baseline status and runtime stability classification
  when either applies.
- Record executable contract probe status for each named compatibility,
  lifecycle, runtime, or public-contract risk.
- Record deliverable diff hygiene from `docs/shared/finite-delivery-contract.md`.
- For behavior-changing work, validate RED/GREEN/REFACTOR evidence or a documented TDD exception.
- Record the exact commands, outputs, and skipped checks in the final report.

Recommended agents:

- `verifier` for acceptance and command evidence.
- `code-reviewer` for behavior-affecting code or workflow changes.

## THOROUGH

Use for security-sensitive changes, data migrations, persistence changes, authorization or permission changes, public contracts, concurrency, externally visible workflows, broad architecture changes, release-critical work, or changes spanning multiple subsystems.

Required evidence:

- Run all STANDARD checks.
- Add targeted integration, smoke, migration, or end-to-end checks appropriate to the risk.
- Include diff-budget scope review when the patch is broad, generated,
  multi-package, or public-API heavy.
- Include baseline guard evidence for existing public contracts near every
  externally visible or shared changed surface.
- Include compatibility baseline evidence for standards, parsers,
  interpreters, protocols, serializers, generated code, and public
  configuration surfaces.
- Include executable contract probe evidence for every named compatibility,
  lifecycle, runtime, generated-artifact, or public-contract risk that could
  invalidate the completion claim.
- Include deliverable diff hygiene and ensure transient workflow artifacts are
  not part of the deliverable patch unless explicitly requested.
- Use independent review for design, security, QA, or regression concerns.
- Include residual risk and skipped checks in the final report.

Recommended agents:

- `plan-reviewer` for design, sequencing, and migration risk.
- `code-reviewer` for broad regression review, with its security lens when auth, data, network, file system, policy, or secret handling can be affected.
- `verifier` with its scenario lens for user-facing workflows.
