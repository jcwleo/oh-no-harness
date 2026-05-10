# oh-no-harness

Lightweight coding-tool harness inspired by Superpowers, with selected planning and execution discipline from OMC/OMX but without a default runtime, daemon, tmux team layer, HUD, or hidden state database.

## Canonical workflow

```text
clarify -> planning [--ral] -> ralph -> verify
```

Canonical user-callable skills:

- `clarify` — produce an SDD-ready spec from unclear work.
- `planning` — produce executable tasks; add `--ral` for RALPLAN-DR, Architect, Critic, and ADR review.
- `ralph` — execute a clear target until verified and reviewed.
- `debug` — investigate from logs, tests, and live code paths before fixing.
- `verify` — prove completion claims with fresh evidence.

When a request looks ready to become work but the right path is ambiguous, the harness should recommend a route before editing: direct execution, `clarify`, `clarify --deep`, `planning`, or `planning --ral`. The `clarify` skill has only two modes; `--ral` belongs to planning.

Claude Code autocomplete shows each skill's expected arguments through `argument-hint`, for example `clarify [--deep]` and `planning [--ral] [spec-or-request]`. Each skill also declares matching positional `arguments` for Claude Code substitution and uses `when_to_use` to sharpen automatic routing without adding hidden runtime logic.

Implementation and debugging must favor root-cause fixes over temporary workarounds. If the cause is not visible from current evidence, add targeted diagnostic logging or tracing to expose it, then remove or gate that instrumentation before claiming completion unless it is intentional observability.

The harness also treats completion integrity as a hard rule: do not cut corners, skip checks, fake confidence, leave placeholders, or cherry-pick evidence to appear done. Either complete the requested work thoroughly with evidence or report the precise blocker/gap.

Retrieval and planning should stay right-sized: inspect explicit user evidence first, expand search only as needed, and use `planning --ral` only for high-risk or high-tradeoff work. For long tasks, use the artifact templates in `templates/` so context-window loss does not change scope.

`bootstrap/oh-no.md` is session-start guidance only, not a user-callable skill.

## Install

The repository doubles as the plugin and as the marketplace that publishes it.

### Claude Code

```sh
claude plugin marketplace add jcwleo/oh-no-harness
claude plugin install oh-no-harness@oh-no-harness
```

In an interactive session the slash-command equivalents are:

```text
/plugin marketplace add jcwleo/oh-no-harness
/plugin install oh-no-harness@oh-no-harness
```

The plugin installs at user scope. The plugin is pinned to a specific release ref (currently `v0.1.2`) via `.claude-plugin/marketplace.json`, so re-running `claude plugin marketplace update oh-no-harness` is what picks up new releases.

### Codex

```sh
codex plugin marketplace add jcwleo/oh-no-harness
```

This registers the marketplace in `~/.codex/config.toml` and clones the repo into `~/.codex/.tmp/marketplaces/oh-no-harness`. Codex CLI does not currently expose a non-interactive `plugin install` / `enable` subcommand — enable the plugin from your interactive Codex session, or add the following block to `~/.codex/config.toml` manually:

```toml
[plugins."oh-no-harness@oh-no-harness"]
enabled = true
```

To pin the marketplace itself to a specific tag instead of the default branch:

```sh
codex plugin marketplace add jcwleo/oh-no-harness --ref v0.1.2
```

## Structure

The repository uses a root-level plugin layout: the repository root is the plugin root for both Claude Code and Codex.

```text
.codex-plugin/plugin.json           # Codex plugin metadata; registers ./skills/
.claude-plugin/plugin.json          # Claude Code plugin metadata
hooks/                              # Claude SessionStart bootstrap hook
bootstrap/oh-no.md                  # shared session guidance
skills/*/SKILL.md                   # workflow contracts
agents/*.md                         # Claude-ready role/subagent prompts
scripts/worktree-start              # isolated git worktree helper for conflict-safe execution
scripts/sync-codex-agents           # renders Codex custom-agent TOML from agents/*.md
scripts/validate-skills             # local consistency checks
scripts/sync-adapters               # optional platform-specific bundle materializer
scripts/release                     # version, bundle-tag, and optional push helper
templates/*.md                      # spec/plan/progress/verify artifact templates
docs/oh-no-harness-design.md        # design notes
```

## Development flow

This repository uses GitHub Flow. Keep `main` releasable. For every change, create a short-lived branch, commit the smallest coherent update, run `scripts/validate-skills` and `git diff --check`, then open a pull request. Merge to `main` only after review/validation. Tag releases from `main` after merge, for example `v0.1.0`.

## Validate

```sh
scripts/sync-codex-agents --check
scripts/validate-skills
git diff --check
```

## Isolated worktrees

Use isolated worktrees for implementation when multiple tasks, agents, or humans may work concurrently, or when the current checkout has unrelated changes:

```sh
scripts/worktree-start feature/<slug>
```

The helper prefers project-local `.worktrees/`, verifies the worktree directory is gitignored, creates a dedicated branch, runs detected setup, and runs a baseline check when one is available. Plans should record whether worktree isolation is required and Ralph should execute mutation-heavy work there when required.

When oh-no harness is used as an installed plugin in another repository, use project-local `scripts/worktree-start` if that repository provides it; otherwise use the installed harness helper when its path is available, or follow the same `git worktree add` contract manually. Before creating the worktree, classify dirty changes as unrelated or relevant-to-task so required uncommitted work is not silently left behind.

Optional static checks:

```sh
python3 -m json.tool .codex-plugin/plugin.json >/dev/null
python3 -m json.tool .claude-plugin/plugin.json >/dev/null
python3 -m json.tool hooks/hooks.json >/dev/null
bash -n scripts/validate-skills
bash -n scripts/sync-codex-agents
bash -n scripts/worktree-start
bash -n scripts/sync-adapters
bash -n scripts/release
bash -n hooks/session-start
bash -n hooks/run-hook.cmd
```

## Release

Run releases from `main` with no tracked working tree changes:

```sh
scripts/release v0.1.1
```

The release helper updates plugin versions, updates the marketplace ref and README pin, validates the source checkout, creates a source release commit on `main`, then creates a tag-only bundle commit with generated `.codex/agents/*.toml`. By default it does not push. To publish:

```sh
scripts/release v0.1.1 --push
```

## Plugin notes

- Superpowers pattern: keep the workflow core shared, and make the repo root installable for each host.
- Claude Code: root `.claude-plugin/`, `skills/`, `agents/`, and `hooks/` make the checkout a Claude plugin candidate; `hooks/session-start` injects `bootstrap/oh-no.md` on `SessionStart`.
- Claude native subagents: root `agents/*.md` include YAML frontmatter (`name`, `description`, `tools`) and can be used as Claude subagents.
- Codex: root `.codex-plugin/plugin.json` registers the canonical skills through `"skills": "./skills/"`.
- Codex native custom agents: `scripts/sync-adapters --write` materializes generated templates under the Codex bundle's `.codex/agents/*.toml`. Edit `agents/*.md`; do not commit generated TOML from the source checkout. If the host does not auto-install plugin custom agents, copy the generated bundle templates into the project `.codex/agents/` or user `~/.codex/agents/`.
- Codex fallback: skills still describe role-pass usage, so the harness remains usable without native custom agents.

To preview separated installable bundles without writing files:

```sh
scripts/sync-adapters --dry-run
```

To materialize local bundles under `dist/`:

```sh
scripts/sync-adapters --write
```

## Design

- Design notes: [`docs/oh-no-harness-design.md`](docs/oh-no-harness-design.md)
