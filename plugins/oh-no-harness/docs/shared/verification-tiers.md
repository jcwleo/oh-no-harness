# Verification Tiers

Use the lightest tier that gives credible evidence for the change.

Verification tier is not the same as Ralph execution mode. Use
`docs/shared/execution-modes.md` to decide artifacts, dispatch, review, cleanup,
and persistence; use this file to decide evidence strength.

If risk is unclear, choose the higher tier. If a check cannot be run, say why and record the residual risk.

When verification is informed by measurable evidence, also apply
`docs/shared/validation-check.md`. Measurable evidence is diagnostic evidence,
not the acceptance criteria.

Every tier uses the caller's canonical AC-ID acceptance-to-evidence ledger when
one exists. A command list is not enough: state which requested behavior each
command, inspection, or manual scenario proves, whether that evidence is direct,
indirect, manual, or missing, and whether it is fresh, audited, stale, or
blocked. Do not create a second unchanged mapping in review or VBC.

Every behavior-changing tier also uses a risk check before completion. Identify
the actual contract surface, likely semantic model, and baseline or smoke check
a skeptical maintainer or user would expect, then add direct semantic evidence
when practical. This is category-level risk modeling, not case-specific
optimization.

## Evidence Redaction

Before writing command output, logs, or real-surface artifacts into `.oh-no`
state, a PR, handoff, or final report, redact secrets and PII to a labeled
placeholder. Retain only the non-sensitive evidence shape needed for the claim,
such as status, lengths, hashes, or short non-secret prefixes. Credential
values, auth headers, cookies, tokens, and raw user data are never evidence.

Verification budget policy:

- Prefer focused semantic evidence before broad suites.
- Prefer nearby baseline or smoke evidence before relying on newly added tests
  alone when existing behavior could regress.
- Run broad suites when shared behavior, public APIs, generated artifacts,
  concurrency, persistence, or cross-package contracts could be affected.
- Avoid repeated broad-suite reruns that do not follow a meaningful patch change
  or a patch-related failure.
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
- Record the risk check before completion and any contract-surface,
  baseline-guard, or direct semantic test added because of it.
- For behavior-changing work, validate RED/GREEN/REFACTOR evidence or a documented TDD exception.
- When the change is behavior-changing AND the proving tests or implementation
  were authored or accepted by the same agent, an independent `verifier` pass is
  required on subagent-capable hosts per the carve-out in
  `docs/shared/ralph-subagent-policy.md`; command success or an inline re-run by
  the implementing or accepting agent is not sufficient. Record the fallback
  reason if the host cannot dispatch.
- Record the exact commands, outputs, and skipped checks in the final report.

Recommended agents:

- `verifier` for acceptance and command evidence; required as an independent
  pass under the carve-out in Required evidence above.
- `code-reviewer` for behavior-affecting code or workflow changes, when the
  caller's review gate selects review; the STANDARD small-task carve-out in
  `docs/shared/execution-modes.md` may record a compliant not-required review
  instead.

## THOROUGH

Use for security-sensitive changes, data migrations, persistence changes, authorization or permission changes, public contracts, concurrency, externally visible workflows, broad architecture changes, release-critical work, or changes spanning multiple subsystems.

Required evidence:

- Run all STANDARD checks.
- Add targeted integration, smoke, migration, or end-to-end checks appropriate to the risk.
- Include diff-budget scope review when the patch is broad, generated,
  multi-package, or public-API heavy.
- Use independent review for design, security, QA, or regression concerns.
- The independent `verifier` audit required at STANDARD also applies here under
  the same carve-out; do not waive it for orchestration convenience.
- Include residual risk and skipped checks in the final report.

Recommended agents:

- Route design, sequencing, or migration-plan defects back through `ralplan`;
  its planning phase owns any `plan-reviewer` dispatch.
- `code-reviewer` for broad regression review, with its security lens when auth, data, network, file system, policy, or secret handling can be affected.
- `verifier` with its scenario lens for user-facing workflows; required as an
  independent pass under the carve-out in Required evidence above.
