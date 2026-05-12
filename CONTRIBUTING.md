# Contributing to Oh No Harness

This guide is for maintainers and contributors who want to develop the harness itself. End users should follow the [Install](README.md#install) section of the README instead.

## Prerequisites

The following CLIs must be on `PATH`:

- `claude` (Claude Code CLI)
- `codex` (Codex CLI)
- `python3`
- `rsync`

## Install your local checkout as a plugin

Maintainers do **not** install from GitHub. Instead, register the working tree directly with both runtimes:

```sh
# Claude Code: declare local marketplace + install in `local` scope.
# Refreshes the plugin cache whenever the working tree differs from cache.
OH_NO_MARKETPLACE_NAME=oh-no-harness scripts/test-claude-plugin.sh

# Codex: rsync the working tree into $CODEX_HOME/plugins/cache and enable it.
OH_NO_MARKETPLACE_NAME=oh-no-harness scripts/test-codex-plugin.sh
```

Install locations:

- Claude Code → `~/.claude/plugins/cache/oh-no-harness/oh-no-harness/<version>/`
- Codex → `~/.codex/plugins/cache/oh-no-harness/oh-no-harness/<version>/`

After this, both runtimes load skills, agents, and hooks straight from your checkout on every session start.

## Development cycle

1. Edit `skills/*/SKILL.md`, `agents/*.md`, `hooks/session-start`, `scripts/*`, or docs.
2. Re-run the test script for the runtime you changed — the cache resyncs when source differs.
3. For Claude Code, `/clear` or restart the session to re-fire the `SessionStart` hook.
4. Codex picks up changes on the next session.

## Validate before pushing

Fast static checks only (no installs):

```sh
python3 scripts/validate-plugin-files.py .
```

Full validation (static + local install/update for both runtimes):

```sh
OH_NO_MARKETPLACE_NAME=oh-no-harness scripts/test-claude-plugin.sh
OH_NO_MARKETPLACE_NAME=oh-no-harness scripts/test-codex-plugin.sh
```

Live model smoke tests (cost real budget — opt-in):

```sh
scripts/test-claude-plugin.sh --live              # all 10 public skills, light prompts
scripts/test-claude-plugin.sh --live-hook-only    # SessionStart + auto-routing only
scripts/test-claude-plugin.sh --deep-live         # linked internal docs dereferencing
scripts/test-codex-plugin.sh --live
scripts/test-codex-plugin.sh --deep-live
```

Useful overrides:

- `--scope user` — install into user scope instead of `local`
- `OH_NO_TEST_MODEL=sonnet` / `OH_NO_MAX_BUDGET_USD=0.50` — tune live model + budget
- `--codex-home /tmp/codex-test` — isolate Codex test installs to a throwaway home

## Release

Cut a release from a clean `main`:

```sh
scripts/release 0.2.2 --push
```

What `--push` does end-to-end:

1. Validates the version arg (semver: `0.2.2` or `v0.2.2`)
2. Refuses if tree is dirty, you're not on `main`, or the tag exists locally/remote
3. Rewrites `version` in `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json`
4. Runs `validate-plugin-files.py` + Claude/Codex install tests
5. Creates `chore: release v0.2.2` commit if version files changed
6. Creates annotated tag `v0.2.2`
7. Pushes `main` and the tag
8. Publishes a GitHub Release via `gh release create --latest --generate-notes`

Skip flags:

- `--skip-tests` — skip install tests (validator still runs)
- (omit `--push`) — stop after local commit + tag for review before publishing

## Repository layout

```text
.claude-plugin/plugin.json        # Claude Code manifest (lists public skills)
.claude-plugin/marketplace.json   # Self-hosted marketplace (source: "./")
.codex-plugin/plugin.json         # Codex manifest (skills: "./skills/")
hooks/session-start               # SessionStart bootstrap (Claude Code only)
hooks/run-hook.cmd                # Cross-platform polyglot wrapper
skills/<name>/SKILL.md            # Public skill (10 total)
skills/internal/plan/SKILL.md     # Internal-only skill (user-invocable: false)
agents/<name>.md                  # Subagent prompts (Claude-native, Codex-routable)
scripts/release                   # Release helper
scripts/test-claude-plugin.sh     # Claude Code install + smoke tests
scripts/test-codex-plugin.sh      # Codex install + prompt-exposure + smoke tests
scripts/validate-plugin-files.py  # Frontmatter and manifest static checks
scripts/oh-no-config              # Auto-routing on/off persistence
docs/reference/                   # Stable cross-skill references
docs/shared/                      # Shared docs (agent tiers, parallel coordination, etc.)
docs/specs/                       # Design specs
```

## Conventions

- Public skill surface is the 10 skills listed in `AGENTS.md`. Do not add user-invocable skills without updating the manifest's `skills` array and the validator's `PUBLIC_SKILLS` list.
- Skills route to each other via Markdown links, not via runtime orchestration. No `Task(...)` / `Skill(...)` calls in skill bodies — the validator rejects them.
- Generated artifacts live under `.oh-no/` and are gitignored.
- Commit messages follow the existing prefixes: `chore:`, `docs:`, `fix:`, `feat:`, `refactor:`, `build:`. Keep first line under ~72 chars.
