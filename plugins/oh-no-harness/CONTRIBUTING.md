# Contributing to Oh No Harness

This guide is for maintainers and contributors who want to develop the harness itself. End users should follow the [Install](README.md#install) section of the README instead.

## Prerequisites

The following CLIs must be on `PATH`:

- `claude` (Claude Code CLI)
- `codex` (Codex CLI)
- `opencode` 1.18.11 (for the pinned deterministic OpenCode source-loading lane)
- `node`
- `python3`

## Install your local checkout as a plugin

Register the working tree directly with the released Claude Code and Codex runtimes — but keep it out of the
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

# OpenCode: load opencode/index.js from source in fully disposable XDG/config
# homes and verify the real host inventory without provider credentials.
scripts/test-opencode-plugin.sh

# OpenCode npm: pack the public artifact, install it without lifecycle scripts,
# and run the same isolated host checks against the installed package.
scripts/test-opencode-package.sh
```

Install locations (relative to the config home the script uses):

- Claude Code → `$CLAUDE_CONFIG_DIR/plugins/cache/oh-no-harness/oh-no-harness/<version>/`
- Codex → `$CODEX_HOME/plugins/cache/oh-no-harness/oh-no-harness/<version>/`

OpenCode installs `oh-no-harness` with Bun at startup and caches npm plugins in
`~/.cache/opencode/node_modules/`. The package has no dependencies, lifecycle
scripts, global binary, daemon, or MCP server. Maintainer package tests use only
disposable install and config roots.

For a persistent daily-use install, follow the root `CLAUDE.md`: install from the
GitHub marketplace (`jcwleo/oh-no-harness`) so the runtime loads from the plugin
cache, and use these smoke scripts to verify local changes in isolation.

## Development cycle

1. Edit files under `plugins/oh-no-harness/`: shared skill bodies in `docs/skill-core/*.md`, platform guidance in `docs/platforms/*.md`, shared role bodies in `docs/agent-core/*.md`, hooks, handwritten OpenCode sources in `opencode/index.js`, `opencode/preferences.js`, `opencode/preference-writer.js`, and `opencode/configure-opencode-subagents`, plugin-local helpers, or docs. Do not hand-edit generated skill runtime documents in `skills/*/SKILL.md`, `skills-claude/*/SKILL.md`, or `skills-opencode/*/SKILL.md`; change the applicable source doc or `scripts/generate-skill-wrappers.py` metadata, then regenerate. Do not hand-edit generated role wrappers in `agents/*.md`, `docs/platforms/codex-agents/*.toml`, or `opencode/generated/*.json`; change `docs/agent-core/*.md`, `docs/platforms/opencode-main-agent.md`, or `scripts/generate-agent-wrappers.py` metadata, then regenerate.
2. Re-run the test script for the runtime you changed. Claude/Codex caches resync when source differs; the OpenCode source lane loads the entrypoint in a disposable config and the package lane verifies the packed artifact.
3. For Claude Code, `/clear` or restart the session to re-fire the `SessionStart` hook.
4. Codex picks up skill changes on the next session. Codex plugin hooks are opt-in; when enabled, `SessionStart` is the only hook entrypoint and adds no forced-routing semantics.
5. OpenCode snapshots config, agents, commands, and skills at process startup; quit and restart it after source or model-configuration changes. A new conversation is not a reliable reload boundary.

## Maintainer validation policy

This policy governs repository maintainers, contributors, coding agents, and CI
when developing, changing, or maintaining Oh No Harness itself. It does not
govern downstream plugin users or their projects, and it does not change runtime
skill behavior, workflow semantics, user-facing skill guidance, or requirements
injected into host sessions. Do not copy it into runtime prompt sources or user
workflow documentation.

After repository changes, use proportionate, outcome-focused validation. Gate
externally observable workflow outcomes, explicit machine protocols, and safety
boundaries—not
incidental narration, headings, synonymous IDs or wording, summaries, or trace
order. Classify requirements as MUST (blocking contract/safety), SHOULD
(non-blocking quality/topology/performance expectation unless promoted), or
DIAGNOSTIC (never independently blocking), separately from run outcomes: PASS,
HARD FAIL, WARNING, or INCONCLUSIVE (including `provider-limited`). Stochastic
presentation variance is a warning, not a release blocker.

Keep deterministic gates strict for static/generation freshness,
installation/identity, safety/permissions, lifecycle, containment, secret
scanning, and material correlation. Model-bearing maintainer smoke is
 direct-invocation-only: deterministically prove the active installed skill
 identity and one exact core invariant for each in-scope changed skill without
 running the workflow or natural routing.
 Reserve full direct `--live` for release or broad shared-contract validation.
 Fusion Rescue remains deferred while Claude-host credits are unavailable.
 Cross-host coverage is limited to the separate Codex-owned direct transport
 smoke; it is not workflow or fallback coverage. Preserve all isolation
 requirements. See the canonical
[test harness lane policy](docs/reference/test-harness-lanes.md).

## Validate maintainer changes before pushing

Fast static checks for repository changes (no installs):

```sh
# Run from the repository root.
python3 scripts/validate-plugin-files.py .
```

Full maintainer validation (static + Claude/Codex local install/update + OpenCode source loading):

```sh
scripts/test-claude-plugin.sh --isolated-config
OH_NO_MARKETPLACE_NAME=oh-no-harness scripts/test-codex-plugin.sh --codex-home "$(mktemp -d)"
scripts/test-opencode-plugin.sh
scripts/test-opencode-package.sh
```

Maintainer live model smoke tests after applicable repository changes (cost real
budget — opt-in). `--no-install` skips only
the driver's explicit marketplace/install/update commands; ordinary Claude Code
startup can still sync registry metadata in the effective `CLAUDE_CONFIG_DIR`.
With claudex/gateway auth, isolate that config while loading this checkout via
`--plugin-dir`:

```sh
# Deterministic installed-skill identity preflight plus one native invocation
# and exact invariant per non-Fusion public skill; no model Read event required.
scripts/test-claude-plugin.sh --isolated-config --no-install --live
# Separate bounded Claude role-dispatch mechanics using Sonnet; does not enlarge --live.
scripts/test-claude-plugin.sh --isolated-config --no-install --dispatch-live
scripts/test-codex-plugin.sh --no-install --live --codex-home /path/to/disposable-cloned-home
# Separate bounded Codex role-dispatch mechanics; does not enlarge --live.
scripts/test-codex-plugin.sh --no-install --dispatch-live --codex-home /path/to/disposable-cloned-home
# One Codex parent invokes one harness-owned Claude Code launcher; no workflow/fallback.
scripts/test-codex-plugin.sh --no-install --cross-host-live --codex-home /path/to/disposable-cloned-home
OH_NO_LIVE_PLUGIN_ROOT=/absolute/path/to/disposable-gpt-plugin scripts/test-claude-plugin.sh --isolated-config --no-install --live --model 'gpt-5.6-sol'
```

Natural SessionStart routing, deep-summary, exhaustive named-agent, topology,
worktree, and specialized Ralplan/Simplify/model-diversity model suites are
retired. Each host's `--dispatch-live` is only the bounded seven-parent, nominal
fourteen-call mechanics matrix documented in the lane policy. Fusion Rescue has
no maintainer CLI lane. Codex `--cross-host-live` is only one direct parent-to-
Claude transport proof and must not be counted as workflow or fallback coverage.

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

The release helper keeps the Claude Code, Codex, and npm package versions in
lockstep. It validates and tests a packed OpenCode artifact on every release;
with `--push`, it also requires npm authentication and publishes
`oh-no-harness@<version>` before creating the release tag.

Cut a release from a clean `main`:

```sh
scripts/release 0.2.2 --push
```

What `--push` does end-to-end:

1. Validates the version arg (semver: `0.2.2` or `v0.2.2`)
2. Refuses if tree is dirty, you're not on `main`, or the tag exists locally/remote
3. Rewrites `version` in both plugin manifests and `plugins/oh-no-harness/package.json`
4. Runs the agent-wrapper `--check`, npm package validation, and `validate-plugin-files.py`
5. Creates a `chore: release v0.2.2` commit if version files changed
6. With `--push`: pushes `main` to origin **before** the install tests — the Claude marketplace syncs from GitHub, so the tests can only verify content already on `origin/main`
7. Tests the packed OpenCode npm artifact, then runs the Codex and eligible Claude install tests
8. With `--push`, publishes `oh-no-harness@<version>` to npm; an existing version is accepted only when its registry integrity matches the local tarball exactly
9. Creates annotated tag `v0.2.2`
10. Builds release notes and, with `--push`, pushes the tag and publishes the GitHub Release

Skip flags:

- `--skip-tests` — skip install tests (validator still runs)
- `--skip-npm-publish` — publish main, tag, and the GitHub Release without npm; the packed npm artifact is still tested unless `--skip-tests` is also set
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
plugins/oh-no-harness/skills/<name>/SKILL.md       # Generated Codex-facing runtime skill document (10 total; no Codex setup wrappers)
plugins/oh-no-harness/skills-claude/<name>/SKILL.md # Generated Claude Code-facing runtime skill document (12 total: 10 workflows + 2 Claude setup skills)
plugins/oh-no-harness/skills-opencode/<name>/SKILL.md # Generated OpenCode-facing runtime skill document (11 total: 10 workflows + OpenCode configure-subagents)
plugins/oh-no-harness/docs/skill-core/<name>.md    # Shared workflow source of truth
plugins/oh-no-harness/docs/platforms/<platform>.md # Platform-wide runtime guidance and skill overlays
plugins/oh-no-harness/docs/agent-core/<name>.md    # Platform-neutral role prompt body
plugins/oh-no-harness/agents/<name>.md             # Generated Claude Code subagent wrapper
plugins/oh-no-harness/docs/platforms/codex-agents/<name>.toml # Generated optional Codex custom-agent template
plugins/oh-no-harness/docs/platforms/opencode-main-agent.md # Static orchestration contract source for the OpenCode oh-no primary
plugins/oh-no-harness/opencode/index.js            # OpenCode config hook and source entrypoint
plugins/oh-no-harness/opencode/preferences.js      # OpenCode model-preference parsing and loading
plugins/oh-no-harness/opencode/preference-writer.js          # Secure OpenCode-only preference publisher
plugins/oh-no-harness/opencode/configure-opencode-subagents # Read-only model preference status command
plugins/oh-no-harness/opencode/generated/agents.json # Generated oh-no primary + 9 oh-no-<role> subagents
plugins/oh-no-harness/opencode/generated/commands.json # Generated 11-command OpenCode inventory
scripts/release                   # Release helper
scripts/test-claude-plugin.sh     # Claude Code install + smoke tests
scripts/test-codex-plugin.sh      # Codex install + prompt-exposure + smoke tests
scripts/test-opencode-plugin.sh   # Isolated deterministic OpenCode source-loading test
scripts/test-opencode-static-contract.py # Deterministic OpenCode validator mutation tests
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

- Public workflow surface is the 10 workflow skills listed in `AGENTS.md` on Claude Code, Codex, and OpenCode. Claude Code additionally has 2 human-invoke-only setup skills (`install-statusline`, `configure-subagents`) for 12 total; OpenCode has its separate explicit-user-only `configure-subagents` for 11 total; Codex remains at 10. Keep `SKILL_AVAILABILITY`, exact generated inventories, applicable manifests, and host tests synchronized.
- Claude Code command wrappers must mirror those same 12 names only. Keep them thin: argument-hint metadata, `$ARGUMENTS`, and a direct read of the matching `skills-claude/<name>/SKILL.md` file. The `install-statusline` and `configure-subagents` wrappers are the two exceptions that set `disable-model-invocation: true` (they must never be model-invoked); all others set `false`.
- Platform availability and model invocation are separate dimensions in both `scripts/generate-skill-wrappers.py` and `scripts/validate-plugin-files.py`: `SKILL_AVAILABILITY` controls the 10/12/11 wrapper inventories, while `MODEL_UNINVOCABLE_SKILLS` controls Claude's `disable-model-invocation: true` setup wrappers. Keep both definitions synchronized across generator and validator; OpenCode `configure-subagents` uses its standalone current-user-request hard gate rather than Claude frontmatter.
- Keep generated runtime skill documents out of hand edits. Shared workflow rules belong in `docs/skill-core/`; platform invocation syntax and host-specific behavior belong in `docs/platforms/`; after changing either source, run `python3 scripts/generate-skill-wrappers.py --write` to refresh Codex, Claude Code, and OpenCode outputs.
- Keep role behavior in `docs/agent-core/` and the OpenCode primary contract in `docs/platforms/opencode-main-agent.md`. Do not hand-edit generated Claude Code wrappers in `agents/`, generated Codex custom-agent templates in `docs/platforms/codex-agents/`, or `opencode/generated/*.json`; after changing a source or wrapper metadata in `scripts/generate-agent-wrappers.py`, run `python3 scripts/generate-agent-wrappers.py --write`.
- Keep the handwritten OpenCode config hook in `opencode/index.js`. It registers `skills-opencode/` and both generated JSON inventories, disables built-in `build`/`plan`, substitutes `oh-no` only for absent or built-in defaults, preserves unrelated custom defaults, and raises subagent depth to at least 2. Model preferences remain separate in `opencode-subagent-models.conf` and require restart.
- Use `python3 scripts/generate-skill-wrappers.py --check` and `python3 scripts/generate-agent-wrappers.py --check` before release-facing changes. The validator and release script also run these checks and fail when generated files are stale.
- Do not add a public skill for optional Codex custom-agent installation. Use `plugins/oh-no-harness/scripts/install-codex-agents` and templates under `docs/platforms/codex-agents/`.
- Keep provider docs out of generated runtime sources. Use `docs/providers/openai.md` and `docs/providers/anthropic.md` as company-scoped maintenance references, then summarize only stable runtime rules in the matching platform doc.
- Positive workflow selection comes from each public skill description. Skills route to each other via Markdown links, not via runtime orchestration. No `Task(...)` / `Skill(...)` calls in skill bodies — the validator rejects them.
- Generated artifacts live under `.oh-no/` and are gitignored.
- Commit messages follow the existing prefixes: `chore:`, `docs:`, `fix:`, `feat:`, `refactor:`, `build:`. Keep first line under ~72 chars.
