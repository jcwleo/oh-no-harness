# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Markdown-first coding-workflow plugin that doubles as both the plugin and the marketplace for Claude Code and Codex. There is no runtime, no daemon, no hidden state — the repo's "behavior" is the text inside `skills/`, `agents/`, `bootstrap/`, `templates/`, and the thin host metadata in `hooks/`, `.claude-plugin/`, and `.codex-plugin/`. Treat changes here as documentation contracts that downstream agent runtimes consume verbatim.

The repo root **is** the plugin root for both hosts simultaneously. There is no separate `adapters/` source — `scripts/sync-adapters` only copies the same source into per-host bundles when explicitly requested.

## Common commands

```sh
scripts/validate-skills          # full lint of skills, agents, templates, manifests, hooks, bundle shape
git diff --check                 # whitespace / patch sanity
scripts/sync-adapters --dry-run  # preview which files would land in per-host bundles
scripts/sync-adapters --write --out "$(mktemp -d)"   # materialize bundles for inspection
scripts/worktree-start <branch>  # create isolated worktree under .worktrees/ (or worktrees/) with baseline run

python3 -m json.tool .codex-plugin/plugin.json >/dev/null
python3 -m json.tool .claude-plugin/plugin.json >/dev/null
python3 -m json.tool hooks/hooks.json >/dev/null
bash -n scripts/validate-skills scripts/worktree-start scripts/sync-adapters hooks/session-start hooks/run-hook.cmd
hooks/session-start | python3 -m json.tool >/dev/null   # the hook must emit valid JSON
```

There is no app build step, no package install, no test runner beyond `scripts/validate-skills`. After any change to `skills/`, `agents/`, `templates/`, `hooks/`, manifests, or `scripts/sync-adapters`, run `scripts/validate-skills` — it is the source of truth for what this repo guarantees.

## Architecture: how the pieces fit together

```
bootstrap/oh-no.md      ── session-start guidance (NOT a callable skill); injected by Claude SessionStart hook
skills/<name>/SKILL.md  ── user-callable workflow contracts: clarify, planning, ralph, debug, verify (exactly these five)
agents/<role>.md        ── Claude-ready role prompts with YAML frontmatter (name/description/tools)
.codex/agents/<role>.toml ── Codex custom-agent templates with name/description/developer_instructions
templates/*.md          ── spec.md, plan.md, progress.md, verify.md — required artifact skeletons
hooks/                  ── Claude SessionStart bootstrap: hooks.json -> run-hook.cmd -> session-start (emits additionalContext JSON)
.claude-plugin/         ── Claude Code plugin metadata + marketplace.json
.codex-plugin/          ── Codex plugin metadata; registers `"skills": "./skills/"`
scripts/validate-skills ── exhaustive lint that every other script and Markdown file must satisfy
scripts/sync-adapters   ── optional: copies the shared core into dist/codex/ and dist/claude/ bundles
scripts/worktree-start  ── isolated-worktree helper used by ralph/debug for mutation-heavy work
docs/oh-no-harness-design.md ── the design rationale; cite this when changing invariants
```

The five canonical skills form a fixed pipeline: `clarify -> planning [--ral] -> ralph -> verify` with `debug` as a side-branch. Skill names, agent names, and template names are **closed sets** — `scripts/validate-skills` enforces both presence and exact membership, and rejects legacy names like `brainstorming`, `deep-interview`, `writing-plans`, `ralplan`, `using-oh-no`.

The artifact chain uses stable IDs across files: `AC-*` (acceptance), `INV-*` (invariants), `DEC-*` (decisions), `OQ-*` (open questions), `T-*` (plan tasks), `VR-*` (verify results). Any new template or skill that ships acceptance/verification language must thread these IDs.

Read-only roles (`architect`, `critic`, `code-reviewer`, `verifier`, `explore`, `analyst`) must say so in both `agents/<role>.md` body and `.codex/agents/<role>.toml` (`sandbox_mode = "read-only"`). Only `executor` is a write role, and `agents/executor.md` must contain the literal string `write role`.

## When editing this repo, things `validate-skills` will catch

- Frontmatter drift: every `skills/<name>/SKILL.md` needs `name: <name>` and `description:`; every `agents/<role>.md` needs `name`, `description`, `tools`, and the body must include `Authority:`, `Purpose:`, `Checklist:`.
- Required phrases: many SKILL.md files must contain specific tokens (e.g. `RALPLAN-DR`, `Architect`, `Critic`, `ADR`, `Worktree isolation: required`, `Plan self-review`, `Re-review loop`, `Mode: basic`, `RED -> GREEN -> REFACTOR`, `Resume and context-window protocol`, `Fresh-lane rules`, `Host mapping`, `spawn_agent`, etc.). When editing, grep `scripts/validate-skills` for the file you touched before assuming a rename is safe.
- Every SKILL.md and agent prompt must mention root-cause / workaround discipline AND completion-integrity discipline (`Do not cut corners` / `Completion integrity` / `Integrity rule`). This is enforced by a loop at the bottom of validate-skills.
- Worktree-aware roles (`executor`, `debugger`, `test-engineer`, `verifier`, `code-reviewer`) must reference worktrees in both their `.md` and `.toml` forms.
- Templates must include traceability tokens (`AC-001` / `T-001` / `VR-001`) and resume/sizing markers (`Retrieval basis|Retrieval and evidence gaps|Resume checkpoint|Sizing decision`).
- The `hooks/session-start` script must emit valid JSON (it's piped through `python3 -m json.tool`). It reads `bootstrap/oh-no.md` and wraps it as `additionalContext`. If you add multi-line content to the bootstrap, verify the shell-side JSON escaping (`escape_for_json`) still produces parseable output.
- `scripts/sync-adapters --write` must produce a tree that itself passes a subset of validate-skills' checks (frontmatter on copied agents, `"skills": "./skills/"` in the codex bundle, etc.). The validator runs sync-adapters into a tempdir as part of its check.

## Hard invariants (from `docs/oh-no-harness-design.md` §11)

- **Zero runtime by default**: no daemons, no tmux, no persistent state, no `.oh-no/state` DB.
- **Skills are behavior contracts**: policy lives in `skills/`, `agents/`, `bootstrap/` — never in scripts or hook code.
- **Host metadata is packaging only**: `.claude-plugin/`, `.codex-plugin/`, `hooks/` describe how to install, not what to do.
- **Reviewers do not implement**: only `executor` has write authority.
- **Planning does not mutate product code**: `clarify` and `planning` produce artifacts; only `ralph`/`debug`+executor mutate code.
- **Ralph requires a target**: `ralph` refuses to start without a plan/spec/checklist.

Do not add a top-level skill, hidden state mechanism, or runtime daemon without first updating `docs/oh-no-harness-design.md` AND the matching assertions in `scripts/validate-skills`.

## Repo workflow

GitHub Flow. Keep `main` releasable; branch per change; run `scripts/validate-skills` and `git diff --check` before pushing; open a PR. Releases are tagged from `main` (current pin: `v0.1.0` in `.claude-plugin/marketplace.json`). When changing the pinned ref, update both `.claude-plugin/marketplace.json` and the install instructions in `README.md`.
