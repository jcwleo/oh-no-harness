# Changelog

All notable changes to this project are documented in this file. The format is
loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

`scripts/release` syncs the version in `.claude-plugin/plugin.json`,
`.codex-plugin/plugin.json`, the `ref` in `.claude-plugin/marketplace.json`, and
the install pin shown in `README.md`. Each release tag is created on `main`
after the source bump and the materialized Codex agent bundle.

## [Unreleased]

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
