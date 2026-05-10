# Repository Guidelines

## Project Structure & Module Organization

This repository is a lightweight, Markdown-first coding harness. The repo root is the plugin root for both Claude Code and Codex. Core workflow contracts live in `skills/*/SKILL.md`; keep only the canonical skills: `clarify`, `planning`, `ralph`, `debug`, and `verify`. Shared session guidance is in `bootstrap/oh-no.md`. Claude-ready role prompts live in `agents/*.md`; Codex custom-agent templates live in `.codex/agents/*.toml`. Plugin metadata is in `.codex-plugin/` and `.claude-plugin/`, and Claude startup hooks are in `hooks/`.

## Build, Test, and Development Commands

- `scripts/validate-skills` — validates skills, agents, templates, manifests, hooks, and bundle shape.
- `git diff --check` — catches trailing whitespace and patch formatting errors.
- `scripts/sync-adapters --dry-run` — previews separated Codex/Claude bundle outputs.
- `scripts/sync-adapters --write --out <dir>` — materializes installable bundles for inspection.
- `python3 -m json.tool <file>` — validates JSON manifests such as `.codex-plugin/plugin.json`.

There is no app build step or package install requirement for normal development.

## Coding Style & Naming Conventions

Prefer small, readable Markdown and shell changes. Use lowercase hyphenated names for skills, agents, files, and generated agent identifiers, for example `code-reviewer` and `test-engineer`. Shell scripts should be Bash, start with `#!/usr/bin/env bash`, and use `set -euo pipefail`. Keep policy in `skills/`, `agents/`, or `bootstrap/`, not hidden inside packaging scripts.

## Testing Guidelines

Run `scripts/validate-skills` after changing skills, agents, templates, manifests, hooks, or sync logic. For sync changes, also run `scripts/sync-adapters --write --out $(mktemp -d)` and inspect representative Claude and Codex files. Update `tests/acceptance/` when behavior expectations change.

## Commit & Pull Request Guidelines

The current Git history is minimal (`first commit`), so no detailed convention is established. Use a concise intent-focused commit title and include validation evidence in the body when useful. PRs should describe workflow impact, list changed areas, include validation commands/results, and call out any known Codex or Claude Code limitation.

## Agent-Specific Instructions

Do not add runtime daemons, hidden state machines, or new top-level skills without updating `docs/oh-no-harness-design.md` and `scripts/validate-skills`. Preserve the root-installable shared-core pattern: common source in `skills/`, `agents/`, `.codex/agents/`, and `bootstrap/`; packaging scripts only copy or separate that shape.
