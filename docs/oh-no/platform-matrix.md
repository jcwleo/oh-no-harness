# Platform matrix

Coverage status per host. Update this matrix whenever a host gains or
loses any of the five integration surfaces.

| Host | Status | Skills | Agents | Hooks | Bootstrap injection | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Claude Code | supported | yes (`/<skill>`) | yes (Claude `Task` / native subagents from `agents/*.md`) | yes (`hooks/session-start` on `SessionStart`) | yes — additionalContext from `bootstrap/oh-no.md` | Reference host. Plugin metadata in `.claude-plugin/`. |
| Codex CLI / App | supported | yes (registered via `.codex-plugin/plugin.json` `"skills": "./skills/"`) | generated TOML at bundle time (`scripts/sync-codex-agents`) | limited (no SessionStart equivalent) | not assumed — fallback to repository guidance (`AGENTS.md`) | `scripts/sync-adapters --write` materializes the Codex bundle. |
| Cursor | planned | TBD — needs slash-command surface mapping | TBD — likely as markdown role prompts only | TBD — no native equivalent of SessionStart known at writing time | not assumed | No work has begun. |
| OpenCode | planned | TBD | TBD | TBD | TBD | No work has begun. |
| Gemini CLI | planned | TBD | TBD | TBD | TBD | No work has begun. |
| GitHub Copilot CLI | planned | TBD | TBD | TBD | TBD | No work has begun. |

Status legend:

- **supported** — the host can run the canonical workflow end-to-end
  through native primitives or a documented current-session
  fallback. Behavior validated by at least one transcript under
  `tests/acceptance/transcripts/`.
- **planned** — the host is on the roadmap; some surfaces may already
  work but the contract has not been verified.

Hosts not listed above are not supported. Do not add a "host" row
without at least a working SKILL.md discovery path; otherwise the
matrix overstates coverage.

## How to update

When you change a row:

1. Run the scenario set in `tests/acceptance/scenarios/` against the
   host in a fresh session.
2. File the resulting transcripts under
   `tests/acceptance/transcripts/`.
3. Move the host's status from `planned` to `supported` only after
   at least one transcript is committed.

## Cross-references

- `docs/oh-no/host-mapping.md` — the design principles each cell in
  this matrix expresses.
- `tests/acceptance/scenarios/` — the canonical scenarios used to
  validate any "supported" claim.
- `tests/acceptance/transcripts/TEMPLATE.md` — the transcript shape
  required to upgrade a row to `supported`.
