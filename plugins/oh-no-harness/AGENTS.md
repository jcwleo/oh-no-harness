# Agent Instructions

This repository is a Markdown-first skill harness.

Keep the external skill surface limited to:

- `using-oh-no-harness`
- `interview`
- `ralplan`
- `ralph`
- `autopilot`
- `auto-routing`
- `test-driven-development`
- `ai-slop-cleaner`
- `verification-before-completion`
- `systematic-debugging`

Treat `agents/*.md` as internal role prompts, not additional public skills.
Skills own workflow stage selection, artifact creation, approval gates, and
next-skill handoffs. Agents may return findings and recommended next roles or
skills to the calling skill, but they must not bypass skill-chaining gates or
act as hidden workflow automation.

`commands/*.md` may exist only as thin Claude Code slash-command wrappers for
the same public skill names above. Each command must delegate to its matching
`skills-claude/<name>/SKILL.md`, preserve the user's raw arguments, and must not
add a new workflow, hidden automation, or separate source of truth.

Shared workflow behavior lives in `docs/skill-core/<name>.md`. Codex-facing
public skill wrappers live in `skills/<name>/SKILL.md`; Claude Code-facing
public skill wrappers live in `skills-claude/<name>/SKILL.md`. Keep wrappers
thin and platform-specific. Do not duplicate the full workflow body in both
platform skill directories.

Company-specific prompt guidance lives in `docs/providers/openai.md` and
`docs/providers/anthropic.md` as maintenance reference only. Do not add provider
docs to the runtime wrapper chain. Summarize stable OpenAI guidance in
`docs/platforms/codex.md` and stable Anthropic guidance in
`docs/platforms/claude-code.md`.

When adapting OMC content:

- Keep only dependencies required by the retained skills.
- Use `.oh-no/specs/` for generated specs.
- Use `.oh-no/plans/` for generated plans.
- Use `.oh-no/sessions/` for transient workflow state.
- Do not add OMC keyword detection, persistent mode hooks, bridge hooks, or state ledger behavior.
- Do not reintroduce `team`, `ultrawork`, `ultraqa`, `cancel`, `ask`, or `autoresearch`.

When editing skills, make skill chaining explicit in Markdown. Do not rely on hidden automation.
