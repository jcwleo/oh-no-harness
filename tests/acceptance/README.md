# Acceptance checks

Run these from the repository root after changing harness files:

```sh
scripts/validate-skills
python3 -m json.tool .codex-plugin/plugin.json >/dev/null
python3 -m json.tool .claude-plugin/plugin.json >/dev/null
python3 -m json.tool hooks/hooks.json >/dev/null
bash -n scripts/validate-skills
bash -n scripts/sync-adapters
bash -n hooks/session-start
bash -n hooks/run-hook.cmd
hooks/session-start | python3 -m json.tool >/dev/null
git diff --check
```

Expected result: every command exits 0.

`validate-skills` also checks canonical skill names, required role prompts, root-cause and completion-integrity rules, retrieval/sizing/resume rules, generated bundle shape, Codex custom-agent TOML templates, and the four artifact templates.

Codex first-turn bootstrap injection is not assumed by this MVP. Codex validation checks skill registration, native custom-agent templates, and documentation fallback. Claude validation checks the SessionStart hook shape, root `agents/*.md` subagent metadata, and safe bootstrap lookup.
