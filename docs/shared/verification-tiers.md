# Verification Tiers

Use the lightest tier that gives credible evidence for the change.

If risk is unclear, choose the higher tier. If a check cannot be run, say why and record the residual risk.

## LIGHT

Use for non-runtime documentation, comments, formatting, or small isolated edits that cannot affect user-visible behavior, persisted data, permissions, or external systems.

Required evidence:

- Inspect changed files.
- Run the smallest relevant syntax or formatting check when one exists.
- Confirm the change matches the requested scope.
- Record command output, or explain why no command applies.

Recommended agents:

- `verifier` for independent evidence checks.

## STANDARD

Use for localized behavior changes, bug fixes, refactors with expected behavior preservation, configuration changes with limited blast radius, or instruction changes that alter agent behavior.

Required evidence:

- Inspect changed files.
- Run relevant lint, typecheck, unit, script, or scenario checks.
- Validate acceptance criteria.
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
- Use independent review for design, security, QA, or regression concerns.
- Include residual risk and skipped checks in the final report.

Recommended agents:

- `architect` for design, sequencing, and migration risk.
- `security-reviewer` when auth, data, network, file system, policy, or secret handling can be affected.
- `code-reviewer` for broad regression review.
- `qa-tester` for user-facing workflows.
