# Contributing to Oh No Harness

This guide is for maintainers and contributors who want to develop the harness itself. End users should follow the [Install](README.md#install) section of the README instead.

## Prerequisites

The following CLIs must be on `PATH`:

- `claude` (Claude Code CLI)
- `codex` (Codex CLI)
- `python3`

## Install your local checkout as a plugin

Register the working tree directly with both runtimes — but keep it out of the
daily-use `oh-no-harness` registration (see the root `CLAUDE.md` warning). The
Claude script **fails closed** if a local source would be registered into your
real `~/.claude` config, so isolate the config home with `--isolated-config`:

```sh
# Run from the repository root.

# Claude Code: --isolated-config installs into a throwaway config home (created
# and cleaned up by the script) so the local checkout never overwrites your
# daily-use GitHub registration. Refreshes the plugin cache whenever the working
# tree differs from cache.
scripts/test-claude-plugin.sh --isolated-config

# Codex: exercise the /plugins install path from the root marketplace wrapper.
OH_NO_MARKETPLACE_NAME=oh-no-harness scripts/test-codex-plugin.sh --codex-home "$(mktemp -d)"
```

Install locations (relative to the config home the script uses):

- Claude Code → `$CLAUDE_CONFIG_DIR/plugins/cache/oh-no-harness/oh-no-harness/<version>/`
- Codex → `$CODEX_HOME/plugins/cache/oh-no-harness/oh-no-harness/<version>/`

For a persistent daily-use install, follow the root `CLAUDE.md`: install from the
GitHub marketplace (`jcwleo/oh-no-harness`) so the runtime loads from the plugin
cache, and use these smoke scripts to verify local changes in isolation.

## Development cycle

1. Edit files under `plugins/oh-no-harness/`: shared skill bodies in `docs/skill-core/*.md`, platform guidance in `docs/platforms/*.md`, shared role bodies in `docs/agent-core/*.md`, hooks, `scripts/oh-no-config`, `scripts/install-codex-agents`, or docs. Do not hand-edit generated skill runtime documents in `skills/*/SKILL.md` or `skills-claude/*/SKILL.md`; change `docs/skill-core/*.md`, `docs/platforms/*.md`, or `scripts/generate-skill-wrappers.py` metadata, then regenerate. Do not hand-edit generated role wrappers in `agents/*.md` or `docs/platforms/codex-agents/*.toml`; change `docs/agent-core/*.md` or `scripts/generate-agent-wrappers.py` metadata, then regenerate.
2. Re-run the test script for the runtime you changed — the cache resyncs when source differs.
3. For Claude Code, `/clear` or restart the session to re-fire the `SessionStart` hook.
4. Codex picks up skill changes on the next session. Codex plugin hooks are opt-in; when enabled, `SessionStart` is the only hook entrypoint and adds no forced-routing semantics.

## Validate before pushing

Fast static checks only (no installs):

```sh
# Run from the repository root.
python3 scripts/validate-plugin-files.py .
```

Full validation (static + local install/update for both runtimes):

```sh
scripts/test-claude-plugin.sh --isolated-config
OH_NO_MARKETPLACE_NAME=oh-no-harness scripts/test-codex-plugin.sh --codex-home "$(mktemp -d)"
```

Live model smoke tests (cost real budget — opt-in). `--no-install` skips only
the driver's explicit marketplace/install/update commands; ordinary Claude Code
startup can still sync registry metadata in the effective `CLAUDE_CONFIG_DIR`.
With claudex/gateway auth, isolate that config while loading this checkout via
`--plugin-dir`:

```sh
scripts/test-claude-plugin.sh --isolated-config --no-install --live           # all 10 workflow skills
scripts/test-claude-plugin.sh --isolated-config --no-install --live-hook-only # SessionStart + routing
scripts/test-claude-plugin.sh --isolated-config --no-install --deep-live      # linked support docs
OH_NO_LIVE_PLUGIN_ROOT=/absolute/path/to/disposable-gpt-plugin scripts/test-claude-plugin.sh --isolated-config --no-install --live --model 'gpt-5.6-sol'
scripts/test-codex-plugin.sh --live
scripts/test-codex-plugin.sh --deep-live
scripts/test-codex-plugin.sh --named-agents-live # user-scope oh-no-* agent_type dispatch
```

`OH_NO_LIVE_PLUGIN_ROOT` is a test-only selector for an absolute disposable
plugin copy. Source validation, manifests, inventories, and generator checks
remain bound to the canonical worktree plugin root. The copy may contain
GPT-only agent frontmatter or model-diversity edits for live testing, but must
never be installed, committed, or treated as source/generated truth.

Useful overrides:

- `--scope user` — install into user scope instead of `local`
- `OH_NO_TEST_MODEL=sonnet` / `OH_NO_MAX_BUDGET_USD=0.50` — tune general live model + budget
- `OH_NO_FUSION_RESCUE_MODEL=opus` / `OH_NO_FUSION_RESCUE_MAX_BUDGET_USD=10.00` — tune Fusion Rescue model-diversity panel live validation
- `--codex-home /tmp/codex-test` — isolate Codex test installs to a throwaway home
- `--isolated-config` — use a throwaway Claude config the script creates and cleans up; with claudex/gateway auth, pair it with `--no-install --live` so startup sync cannot touch the real registry
- `CLAUDE_CONFIG_DIR=/path/to/disposable-clone` — for native auth/settings stored in the Claude config, point live tests at a physical throwaway clone of the needed config, never the real default
- `--no-install` — load this checkout or `OH_NO_LIVE_PLUGIN_ROOT` via `--plugin-dir` without explicit driver marketplace/install/update commands; it does not disable ordinary Claude startup plugin sync
- `OH_NO_LIVE_PLUGIN_ROOT=/absolute/path/to/disposable-plugin-copy` — route only model-bearing live plugin-dir/add-dir reads through a validated disposable copy; requires `--no-install` and should be paired with `--isolated-config`, never the real-config escape hatch
- `--marketplace-source jcwleo/oh-no-harness` — test the public GitHub marketplace source instead of the local checkout
- `OH_NO_CONFIG_DIR` — isolates Oh No Harness data only; it is not Claude registry isolation
- `OH_NO_ALLOW_REAL_CLAUDE_CONFIG_LIVE=1` — acknowledged last resort that permits model-bearing plugin-dir lanes to use the real config and accept startup-sync metadata writes
- `OH_NO_ALLOW_CANONICAL_LOCAL_MARKETPLACE=1` — deliberately register a local-source marketplace into the real `~/.claude` config (bypasses the install gate; rarely wanted)
- `plugins/oh-no-harness/scripts/install-codex-agents` — install optional Codex custom agents into user scope by default (`$CODEX_HOME/agents` or `~/.codex/agents`); Codex SessionStart is the sole automatic ensure path

## Release

Cut a release from a clean `main`:

```sh
scripts/release 0.2.2 --push
```

What `--push` does end-to-end:

1. Validates the version arg (semver: `0.2.2` or `v0.2.2`)
2. Refuses if tree is dirty, you're not on `main`, or the tag exists locally/remote
3. Rewrites `version` in `plugins/oh-no-harness/.claude-plugin/plugin.json` and `plugins/oh-no-harness/.codex-plugin/plugin.json`
4. Runs the agent-wrapper `--check` and `validate-plugin-files.py`
5. Creates a `chore: release v0.2.2` commit if version files changed
6. With `--push`: pushes `main` to origin **before** the install tests — the Claude marketplace syncs from GitHub, so the tests can only verify content already on `origin/main`
7. Runs the Codex install test, then the Claude install test when local `HEAD` matches `origin/main`. The Claude test derives a credential-free `owner/repo` slug from `origin` and runs with `--isolated-config` + `OH_NO_INSTALL=1`, so it installs the GitHub-synced marketplace into a throwaway config home and verifies the pushed revision without touching your real `~/.claude`
8. Creates annotated tag `v0.2.2`
9. Builds release notes from `git log <prev-tag>..<tag>`, grouped by conventional-commit prefix
10. With `--push`: pushes the tag, then publishes a GitHub Release via `gh release create` with the generated `--notes-file` (`--prerelease` for `0.x`, `--latest` for `1.x` and later)

Skip flags:

- `--skip-tests` — skip install tests (validator still runs)
- (omit `--push`) — stop after local commit + tag for review before publishing

## Repository layout

```text
README.md                         # Marketplace wrapper README
.claude-plugin/marketplace.json   # Claude marketplace manifest (source: "./plugins/oh-no-harness")
.agents/plugins/marketplace.json  # Codex marketplace manifest (source: "./plugins/oh-no-harness")
plugins/oh-no-harness/.claude-plugin/plugin.json  # Claude Code plugin manifest
plugins/oh-no-harness/.codex-plugin/plugin.json   # Codex plugin manifest
plugins/oh-no-harness/hooks/session-start          # SessionStart bootstrap
plugins/oh-no-harness/hooks/run-hook.cmd           # Cross-platform polyglot wrapper
plugins/oh-no-harness/commands/<name>.md           # Claude slash-command wrapper
plugins/oh-no-harness/skills/<name>/SKILL.md       # Generated Codex-facing runtime skill document (10 total; no Codex wrapper for the two Claude-only setup skills install-statusline and configure-subagents)
plugins/oh-no-harness/skills-claude/<name>/SKILL.md # Generated Claude Code-facing runtime skill document (12 total: 10 cross-platform + 2 Claude-only setup skills)
plugins/oh-no-harness/docs/skill-core/<name>.md    # Shared workflow source of truth
plugins/oh-no-harness/docs/platforms/<platform>.md # Platform-wide runtime guidance and skill overlays
plugins/oh-no-harness/docs/agent-core/<name>.md    # Platform-neutral role prompt body
plugins/oh-no-harness/agents/<name>.md             # Generated Claude Code subagent wrapper
plugins/oh-no-harness/docs/platforms/codex-agents/<name>.toml # Generated optional Codex custom-agent template
scripts/release                   # Release helper
scripts/test-claude-plugin.sh     # Claude Code install + smoke tests
scripts/test-codex-plugin.sh      # Codex install + prompt-exposure + smoke tests
scripts/generate-skill-wrappers.py # Regenerates generated runtime skill documents
scripts/generate-agent-wrappers.py # Regenerates generated agent wrappers
scripts/validate-plugin-files.py  # Frontmatter and manifest static checks
plugins/oh-no-harness/scripts/oh-no-config         # Auto-routing on/off persistence
plugins/oh-no-harness/scripts/install-codex-agents # Optional Codex custom-agent installer
plugins/oh-no-harness/docs/reference/              # Stable cross-skill references
plugins/oh-no-harness/docs/shared/                 # Shared docs
plugins/oh-no-harness/docs/providers/              # Company prompt guide maintenance references
plugins/oh-no-harness/docs/specs/                  # Design specs
```

## Conventions

- Public skill surface is the 12 skills listed in `AGENTS.md` — 10 cross-platform workflow skills plus 2 Claude-Code-only, human-invoke-only setup skills (`install-statusline`, `configure-subagents`) — for 12 Claude-visible total; the Codex surface is the 10 workflow skills only. Do not add user-invocable skills without updating the manifest's `skills` array and the validator's `PUBLIC_SKILLS` list.
- Claude Code command wrappers must mirror those same 12 names only. Keep them thin: argument-hint metadata, `$ARGUMENTS`, and a direct read of the matching `skills-claude/<name>/SKILL.md` file. The `install-statusline` and `configure-subagents` wrappers are the two exceptions that set `disable-model-invocation: true` (they must never be model-invoked); all others set `false`.
- Claude-Code-only or human-invoke-only skills use two carve-outs, kept conceptually distinct, in both `scripts/generate-skill-wrappers.py` and `scripts/validate-plugin-files.py`: `CLAUDE_ONLY_SKILLS` (ships only the Claude wrapper; the Codex wrapper is asserted absent and `test-codex-plugin.sh` must NOT list the skill) and `MODEL_UNINVOCABLE_SKILLS` (its command wrapper sets `disable-model-invocation: true`). Keep the two sets identical across the generator and validator — the validator runs the generator's `--check` as a subprocess.
- Keep generated runtime skill documents out of hand edits. Shared workflow rules belong in `docs/skill-core/`; platform invocation syntax and host-specific behavior belong in `docs/platforms/`; after changing either source, run `python3 scripts/generate-skill-wrappers.py --write`.
- Keep role behavior in `docs/agent-core/`. Do not hand-edit generated Claude Code wrappers in `agents/` or generated Codex custom-agent templates in `docs/platforms/codex-agents/`; after changing agent-core content or wrapper metadata in `scripts/generate-agent-wrappers.py`, run `python3 scripts/generate-agent-wrappers.py --write`.
- Use `python3 scripts/generate-skill-wrappers.py --check` and `python3 scripts/generate-agent-wrappers.py --check` before release-facing changes. The validator and release script also run these checks and fail when generated files are stale.
- Do not add a public skill for optional Codex custom-agent installation. Use `plugins/oh-no-harness/scripts/install-codex-agents` and templates under `docs/platforms/codex-agents/`.
- Keep provider docs out of generated runtime sources. Use `docs/providers/openai.md` and `docs/providers/anthropic.md` as company-scoped maintenance references, then summarize only stable runtime rules in the matching platform doc.
- Positive workflow selection comes from each public skill description. Skills route to each other via Markdown links, not via runtime orchestration. No `Task(...)` / `Skill(...)` calls in skill bodies — the validator rejects them.
- Generated artifacts live under `.oh-no/` and are gitignored.
- Commit messages follow the existing prefixes: `chore:`, `docs:`, `fix:`, `feat:`, `refactor:`, `build:`. Keep first line under ~72 chars.
