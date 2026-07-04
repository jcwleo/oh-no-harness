# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Read this first

Two `AGENTS.md` files are authoritative and constrain almost every change here. Read them before editing:

- [`AGENTS.md`](AGENTS.md) — the repo root is a **marketplace wrapper only**.
- [`plugins/oh-no-harness/AGENTS.md`](plugins/oh-no-harness/AGENTS.md) — rules for the plugin itself (public skill surface, source-vs-generated layers, regeneration).

Contributor workflow detail lives in [`plugins/oh-no-harness/CONTRIBUTING.md`](plugins/oh-no-harness/CONTRIBUTING.md).

## What this is

Oh No Harness is a **Markdown-first coding-workflow plugin** for Claude Code and Codex — no npm package, no packaged runtime CLI binary, no daemon, no MCP server. The "runtime" is plain text the host loads through its plugin/skill system: 11 public workflow skills (`using-oh-no-harness`, `interview`, `ralplan`, `ralph`, `ultrawork`, `auto-routing`, `test-driven-development`, `simplify`, `verification-before-completion`, `systematic-debugging`, `fusion-rescue`) backed by 10 internal role agents.

## The single most important rule: source vs. generated

Many files in `plugins/oh-no-harness/` are **generated**. Hand-editing them will be silently overwritten and is rejected by validation. Always edit the source, then regenerate.

| Edit this source… | …never hand-edit this generated output | Regenerate with |
|---|---|---|
| `docs/skill-core/<name>.md` (shared workflow body), `docs/platforms/codex.md` / `docs/platforms/claude-code.md` and optional `docs/platforms/codex-<name>.md` / `docs/platforms/claude-code-<name>.md` overlays | `skills/<name>/SKILL.md` (Codex), `skills-claude/<name>/SKILL.md` (Claude Code) | `python3 scripts/generate-skill-wrappers.py --write` |
| `docs/agent-core/<name>.md` (platform-neutral role body), wrapper metadata in the generator | `agents/<name>.md` (Claude subagent), `docs/platforms/codex-agents/<name>.toml` (Codex custom agent) | `python3 scripts/generate-agent-wrappers.py --write` |

`docs/skill-core/*.md` is the **default, primary edit surface** for workflow behavior. Only touch `docs/platforms/*.md` for genuinely host-specific invocation syntax, permissions, or tool behavior. Both generators run from the **repository root** (not the plugin dir).

`docs/providers/openai.md` and `docs/providers/anthropic.md` are **maintenance references only** — never generated sources. When company guidance changes, update the provider doc, then copy only stable runtime rules into the matching `docs/platforms/*.md` and regenerate.

## Repo layout: root vs. plugin

- **Root** = marketplace wrapper + release/test tooling only: `.claude-plugin/marketplace.json` (Claude), `.agents/plugins/marketplace.json` (Codex), `scripts/`, repo metadata. Do **not** reintroduce root-level `skills/`, `commands/`, `agents/`, `hooks/`, or `docs/`.
- **`plugins/oh-no-harness/`** = the actual plugin source of truth: skill cores, agent cores, platform docs, generated runtime files, `hooks/`, `commands/`, plugin manifests, and plugin-local `scripts/`.

Generated work products go under `.oh-no/` (gitignored): `specs/`, `plans/`, `sessions/`, `worktrees/`, `test-runs/`. **Ignore `.oh-no/` when searching** — it's full of test-run snapshots and worktree copies that match real filenames (`AGENTS.md`, `SKILL.md`, etc.).

## Architecture model

- **Skills are the public workflow stages**; **agents are internal role prompts** the skills (or the host's subagent mechanism) call. Skills own stage selection, artifact creation, approval gates, and next-skill handoffs.
- **Skill chaining is explicit Markdown only** — no hidden automation. Skill bodies must not contain `Task(...)` / `Skill(...)` calls; the validator rejects them. A skill that hands off presents a `Next Skill Handoff` and the caller decides.
- **Composition:** each generated `SKILL.md` is assembled from `docs/skill-core/<name>.md` + the platform doc + an optional per-skill platform overlay. See `docs/reference/relationships.md` for the full bootstrap, skill, and agent graphs, and `docs/reference/source-index.md` for where each file originated.
- **Two plugin hook entrypoints only:** a `SessionStart` bootstrap (skill-loading guidance; appends forced-routing when auto-routing is enabled, plus a Claude-Code-only codex-executor delegation block when that toggle is on) and a narrow Ralph `UserPromptSubmit` adapter. Claude Code uses these through `CLAUDE_PLUGIN_ROOT`; Codex also declares the same hook file when plugin hooks are enabled. No `PreToolUse`/`PostToolUse`, no state ledger, no background process.

## Commands

Run all of these **from the repository root**.

```sh
# Fast static checks (frontmatter, manifests, public-skill surface, no Task/Skill in bodies).
# Also fails if generated files are stale, and runs the deterministic
# skill-reachability deep-smoke (below) for both platforms.
python3 scripts/validate-plugin-files.py .

# Verify generated outputs are up to date (CI/release-style check; no writes).
python3 scripts/generate-skill-wrappers.py --check
python3 scripts/generate-agent-wrappers.py --check

# Deterministic deep-smoke: assert each skill's load-bearing workflow rules are
# reachable in its composed wrapper plus the docs/shared and sub-skills it
# references (replaces gating on flaky live-model phrase grep; the live
# `--deep-live` test below is now a non-gating signal). Run for each platform.
python3 scripts/check-skill-reachability.py --platform codex --plugin-root plugins/oh-no-harness
python3 scripts/check-skill-reachability.py --platform claude --plugin-root plugins/oh-no-harness

# Local install + offline smoke tests (resyncs the plugin cache when source differs).
OH_NO_MARKETPLACE_NAME=oh-no-harness scripts/test-claude-plugin.sh
OH_NO_MARKETPLACE_NAME=oh-no-harness scripts/test-codex-plugin.sh --codex-home "$(mktemp -d)"

# Live model smoke tests — cost real budget, opt-in. Closest thing to a "single test":
scripts/test-claude-plugin.sh --live-hook-only     # SessionStart + auto-routing only
scripts/test-claude-plugin.sh --live              # all 11 public skills, light prompts
scripts/test-claude-plugin.sh --deep-live         # linked support-doc dereferencing
scripts/test-codex-plugin.sh --named-agents-live  # user-scope oh-no-* agent_type dispatch

# Release from a clean main (validates, bumps both plugin.json versions, tags, pushes, publishes).
scripts/release 1.5.2 --push        # omit --push to stop after local commit+tag
```

Useful live-test overrides: `OH_NO_TEST_MODEL=sonnet`, `OH_NO_MAX_BUDGET_USD=0.50`, `OH_NO_FUSION_RESCUE_MODEL=opus`, `--scope user`.

**Gotchas:**
- The install smoke scripts register the marketplace from `OH_NO_MARKETPLACE_SOURCE` (default: this checkout). Use a temp `--codex-home` or a distinct `OH_NO_MARKETPLACE_NAME` when you do not want to disturb an existing local marketplace registration.
- Live tests can exceed the default ~$1 budget on large diffs — raise `OH_NO_MAX_BUDGET_USD`.
- Codex live tests need your Codex auth copied into the temp `--codex-home` when you use an isolated Codex home.

## After any change

1. Edit the **source** doc (`docs/skill-core/`, `docs/platforms/`, or `docs/agent-core/`) — not the generated file.
2. Regenerate (`generate-skill-wrappers.py --write` and/or `generate-agent-wrappers.py --write`).
3. `python3 scripts/validate-plugin-files.py .`.
4. For Claude Code behavior changes, `/clear` or restart to re-fire the `SessionStart` hook.
5. New public skill? Update both plugin manifests, the validator's `PUBLIC_SKILLS` list, both test scripts' `PUBLIC_SKILLS`, the generator's `PUBLIC_SKILLS`, `plugins/oh-no-harness/AGENTS.md`, public docs, and add a thin `commands/<name>.md` wrapper. Update root `AGENTS.md` only if the marketplace-wrapper boundary changes.

Commit prefixes in use: `chore:`, `docs:`, `fix:`, `feat:`, `refactor:`, `build:`. Keep the first line under ~72 chars.
