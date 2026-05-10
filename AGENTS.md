# Repository Guidelines

## Project Structure & Module Organization

This repository is a lightweight, Markdown-first coding harness. The repo root is the plugin root for both Claude Code and Codex. Core workflow contracts live in `skills/*/SKILL.md`; keep only the canonical skills: `clarify`, `planning`, `ralph`, `debug`, and `verify`. Shared session guidance is in `bootstrap/oh-no.md`. Role prompts live in `agents/*.md`; Codex custom-agent templates are generated into bundle `.codex/agents/*.toml` at adapter-sync time. Plugin metadata is in `.codex-plugin/` and `.claude-plugin/`, and Claude startup hooks are in `hooks/`.

## Build, Test, and Development Commands

- `scripts/validate-skills` — validates skills, agents, templates, manifests, hooks, and bundle shape.
- `git diff --check` — catches trailing whitespace and patch formatting errors.
- `scripts/sync-codex-agents --check` — verifies Codex TOML can be rendered from `agents/*.md`.
- `scripts/sync-codex-agents --write --out <dir>` — generates Codex custom-agent TOML from `agents/*.md`.
- `scripts/sync-adapters --dry-run` — previews separated Codex/Claude bundle outputs.
- `scripts/sync-adapters --write --out <dir>` — materializes installable bundles for inspection.
- `scripts/release <version> [--push]` — updates release refs, creates the generated bundle tag commit, and optionally pushes.
- `python3 -m json.tool <file>` — validates JSON manifests such as `.codex-plugin/plugin.json`.

There is no app build step or package install requirement for normal development.

## Coding Style & Naming Conventions

Prefer small, readable Markdown and shell changes. Use lowercase hyphenated names for skills, agents, files, and generated agent identifiers, for example `code-reviewer` and `test-engineer`. Shell scripts should be Bash, start with `#!/usr/bin/env bash`, and use `set -euo pipefail`. Keep policy in `skills/`, `agents/`, or `bootstrap/`, not hidden inside packaging scripts.

## Testing Guidelines

Run `scripts/validate-skills` after changing skills, agents, templates, manifests, hooks, or sync logic. After changing `agents/*.md`, rely on validation to render-check Codex TOML; do not commit generated `.codex/agents/*.toml` in the source checkout. For sync changes, also run `scripts/sync-adapters --write --out $(mktemp -d)` and inspect representative Claude and Codex files. For release-flow changes, run `bash -n scripts/release`. Update `tests/acceptance/` when behavior expectations change.

## Commit & Pull Request Guidelines

This repository uses GitHub Flow. Keep `main` releasable; do not commit feature work directly to `main`. Create a short-lived branch such as `docs/github-flow-guidelines`, make the smallest coherent change, run validation, push the branch, and open a PR. PRs should describe workflow impact, list changed areas, include validation commands/results, and call out known Codex or Claude Code limitations. Releases are tagged from `main` after merge.

## Agent-Specific Instructions

Do not add runtime daemons, hidden state machines, or new top-level skills without updating `docs/oh-no-harness-design.md` and `scripts/validate-skills`. Preserve the root-installable shared-core pattern: common source in `skills/`, `agents/`, and `bootstrap/`; generated Codex templates are materialized only in adapter bundles; packaging scripts only copy, generate, or separate that shape.
