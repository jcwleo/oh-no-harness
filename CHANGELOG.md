# Changelog

All notable changes to this project are documented in this file. The format is
loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

`scripts/release` syncs the version in `.claude-plugin/plugin.json`,
`.codex-plugin/plugin.json`, the `ref` in `.claude-plugin/marketplace.json`, and
the install pin shown in `README.md`. Each release tag is created on `main`
after the source bump and the materialized Codex agent bundle.

> Note: entries for v0.0.1–v0.1.4 below are reconstructed from git
> history (commit titles, tag messages, and diff inspection) rather than
> written at release time, so wording may not exactly match each
> release's intent. From v0.1.5 onward, entries are added to the
> `## [Unreleased]` block at change time and renamed at tag time.

## [Unreleased]

### Added

- Root MIT `LICENSE` file matching the manifest license declaration.
- This `CHANGELOG.md` with a Keep-a-Changelog format and a
  reconstruction disclaimer for the v0.0.1..v0.1.4 backfilled entries.
- Eight fresh-session acceptance scenarios under
  `tests/acceptance/scenarios/`: five exercising routing and evidence
  discipline (feature request, failing-test debug, risky architecture,
  completion claim, dirty checkout) and three exercising the
  `code-reviewer` severity sweep (planted SQL injection, secret
  logging, swallowed exception on a money path), plus
  `transcripts/TEMPLATE.md` for recording fresh-session runs.
- `docs/oh-no/skill-authoring.md` and `docs/oh-no/evals.md` documenting
  the trigger-only `description` rule, the structural-vs-behavior
  validation split, and the FAIL transcript triage protocol.
- Seven technique reference docs under `docs/oh-no/techniques/`:
  test-first, regression-proof, testing-anti-patterns,
  root-cause-tracing, condition-based-waiting, diagnostic-logging,
  defense-in-depth.
- `docs/oh-no/host-mapping.md` and `docs/oh-no/platform-matrix.md`
  describing how to map the harness to a new host and a three-tier
  status matrix (`planned` / `documented` / `supported`).
- Optional `docs/oh-no/visual-clarification.md` for UI / UX / diagram
  clarification with a no-runtime / no-server / no-asset rule.
- `verify` finalization protocol with four next-step options
  (Merge locally / Push and PR / Keep as-is / Discard with typed
  confirmation) and rules for harness-owned vs externally managed
  worktrees.
- `agents/code-reviewer.md` severity taxonomy
  (BLOCKER / IMPORTANT / WATCH / NIT) and final status
  (CLEAR / ATTENTION / BLOCK / INSUFFICIENT_EVIDENCE) plus a
  security / data-loss / auth / secrets sweep.
- Template enrichment: `templates/plan.md` File/module map and
  per-task First failing check / Expected pass signal / Rollback note;
  `templates/verify.md` Evidence gaps table and Finalization block;
  `templates/progress.md` Resume checkpoint extended with
  Last known verification and Branch fields.
- `scripts/sync-adapters` now copies `docs/oh-no/` and
  `tests/acceptance/` reference materials into both Codex and Claude
  bundles so SKILL cross-references resolve at the consumer's
  checkout.
- `scripts/validate-skills` release-metadata sync gate: the manifest
  versions, the marketplace `ref`, the `README.md` install pin, and
  the `CHANGELOG.md` section heading must all agree on the current
  version.
- `scripts/validate-skills` supported-host gate: rows marked
  `supported` in the platform matrix must have a committed
  acceptance transcript whose `- Host:` metadata exactly matches
  one of the row's host aliases and whose `- Result:` is `PASS`.

### Changed

- `description` field of `clarify`, `planning`, and `debug` SKILL.md
  trimmed to trigger-only sentences (process narration moved to the
  body or `when_to_use`). `scripts/validate-skills` rejects
  process-summary fragments in `description`.
- `verify` finalization protocol made conditional: it fires only when
  the verification target explicitly includes branch / worktree
  finalization. Ordinary "is this complete?" verifications end with
  the standard final response shape, and `templates/verify.md` adds
  `not requested` to the Selected option list.
- `scripts/release` now fails fast if `CHANGELOG.md` lacks a
  `## [<version>]` section for the new tag, and escapes version dots
  in the pattern so `## [1x2x3]` no longer satisfies the `1.2.3`
  pre-tag check.

### Fixed

- `scripts/validate-skills` transcript Result line check no longer
  treats `Result: PASS | FAIL | PARTIAL` as ERE alternation; literal
  pipes are required so single-branch transcripts no longer pass.
- `scripts/validate-skills` README install-pin check now anchors to
  the two canonical pin formats (`` currently `vX.Y.Z` `` and
  `--ref vX.Y.Z`) instead of substring-anywhere, so a stale pin
  cannot hide behind an unrelated version mention.
- `scripts/validate-skills` read-only sandbox check loop now covers
  `debugger` and `test-engineer` (previously only the six other
  read-only roles). The body regex switched to `[Rr]ead-only` to
  match sentence-initial capitalization.
- `scripts/validate-skills` supported-host gate now requires exact
  alias match (set intersection) instead of substring membership;
  `noncodex` no longer satisfies the `codex` alias. Filename stems
  are no longer treated as host evidence; transcripts must declare
  `- Host:` and `- Result:` metadata, and only `Result: PASS`
  contributes to the gate.

## [0.1.4] - 2026-05-10

### Added

- Documented how each canonical skill ingests `$ARGUMENTS` so positional and
  flag inputs do not mis-map when the user invokes a skill from Claude Code.

## [0.1.3] - 2026-05-10

### Added

- Argument mappings for every canonical skill (`clarify`, `planning`, `ralph`,
  `debug`, `verify`) to drive Claude Code's `argument-hint` autocomplete.

## [0.1.2] - 2026-05-10

### Changed

- Sharpened `description` and `when_to_use` metadata across the canonical
  skills so automatic routing fires on the right requests.

## [0.1.1] - 2026-05-10

### Added

- `scripts/release` automation that bumps the version in both plugin
  manifests, updates the marketplace ref and `README.md` install pin, runs
  validation, creates the source release commit, and tags a separate bundle
  commit with generated Codex agent TOML templates.
- Worktree-aware execution wired through `clarify`, `planning`, `ralph`,
  `debug`, and `verify` so isolated implementation lanes have a single
  contract.
- `.gitignore` for local harness state, generated bundles, and worktree
  directories.

### Changed

- Unified the harness workflows around verifiable isolated execution and
  documented `scripts/worktree-start` as the helper of record.

## [0.1.0] - 2026-05-10

### Added

- First public marketplace release. `.claude-plugin/marketplace.json`
  declares a single `oh-no-harness` plugin pinned to a release ref so
  `claude plugin marketplace update` picks up new releases.
- Install instructions for Claude Code and Codex in `README.md`.
- Adopted GitHub Flow as the contribution workflow for the repository.

## [0.0.1] - 2026-05-10

### Added

- Initial root-installable oh-no-harness release for Claude Code and Codex,
  with the canonical five skills (`clarify`, `planning`, `ralph`, `debug`,
  `verify`), required role prompts under `agents/`, the four artifact
  templates under `templates/`, the Claude `SessionStart` bootstrap hook, and
  the Codex skill registration via `.codex-plugin/plugin.json`.

[Unreleased]: https://github.com/jcwleo/oh-no-harness/compare/v0.1.4...HEAD
[0.1.4]: https://github.com/jcwleo/oh-no-harness/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/jcwleo/oh-no-harness/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/jcwleo/oh-no-harness/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/jcwleo/oh-no-harness/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/jcwleo/oh-no-harness/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/jcwleo/oh-no-harness/releases/tag/v0.0.1
