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

Implementation and debugging must favor root-cause fixes over temporary workarounds. If the cause is not visible from current evidence, add targeted diagnostic logging or tracing to expose it, then remove or gate that instrumentation before claiming completion unless it is intentional observability.

The harness also treats completion integrity as a hard rule: do not cut corners, skip checks, fake confidence, leave placeholders, or cherry-pick evidence to appear done. Either complete the requested work thoroughly with evidence or report the precise blocker/gap.

Retrieval and planning should stay right-sized: inspect explicit user evidence first, expand search only as needed, and use `planning --ral` only for high-risk or high-tradeoff work. For long tasks, use the artifact templates in `templates/` so context-window loss does not change scope.

`bootstrap/oh-no.md` is session-start guidance only, not a user-callable skill.

## Structure

The repository uses a root-level plugin layout: the repository root is the plugin root for both Claude Code and Codex.

```text
.codex-plugin/plugin.json           # Codex plugin metadata; registers ./skills/
.claude-plugin/plugin.json          # Claude Code plugin metadata
.codex/agents/*.toml                # Codex native custom-agent templates
hooks/                              # Claude SessionStart bootstrap hook
bootstrap/oh-no.md                  # shared session guidance
skills/*/SKILL.md                   # workflow contracts
agents/*.md                         # Claude-ready role/subagent prompts
scripts/validate-skills             # local consistency checks
scripts/sync-adapters               # optional platform-specific bundle materializer
templates/*.md                      # spec/plan/progress/verify artifact templates
docs/oh-no-harness-design.md        # design notes
```

## Development flow

This repository uses GitHub Flow. Keep `main` releasable. For every change, create a short-lived branch, commit the smallest coherent update, run `scripts/validate-skills` and `git diff --check`, then open a pull request. Merge to `main` only after review/validation. Tag releases from `main` after merge, for example `v0.0.1`.

## Validate

```sh
scripts/validate-skills
git diff --check
```

Optional static checks:

```sh
python3 -m json.tool .codex-plugin/plugin.json >/dev/null
python3 -m json.tool .claude-plugin/plugin.json >/dev/null
python3 -m json.tool hooks/hooks.json >/dev/null
bash -n scripts/validate-skills
bash -n scripts/sync-adapters
bash -n hooks/session-start
bash -n hooks/run-hook.cmd
```

## Plugin notes

- Superpowers pattern: keep the workflow core shared, and make the repo root installable for each host.
- Claude Code: root `.claude-plugin/`, `skills/`, `agents/`, and `hooks/` make the checkout a Claude plugin candidate; `hooks/session-start` injects `bootstrap/oh-no.md` on `SessionStart`.
- Claude native subagents: root `agents/*.md` include YAML frontmatter (`name`, `description`, `tools`) and can be used as Claude subagents.
- Codex: root `.codex-plugin/plugin.json` registers the canonical skills through `"skills": "./skills/"`.
- Codex native custom agents: root `.codex/agents/*.toml` provides custom-agent templates. If the host does not auto-install plugin custom agents, copy them into the project `.codex/agents/` or user `~/.codex/agents/`.
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
