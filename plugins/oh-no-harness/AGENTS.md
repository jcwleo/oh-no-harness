# Agent Instructions

This repository is a Markdown-first skill harness.

Keep the external skill surface limited to:

- `using-oh-no-harness`
- `interview`
- `ralplan`
- `ralph`
- `ultrawork`
- `auto-routing`
- `test-driven-development`
- `simplify`
- `verification-before-completion`
- `systematic-debugging`
- `fusion-rescue`

Treat `docs/agent-core/*.md`, `agents/*.md`, and
`docs/platforms/codex-agents/*.toml` as internal role prompts, not additional
public skills. `docs/agent-core/*.md` contains the platform-neutral role bodies
and is the source of truth for agent behavior. Do not hand-edit
`agents/*.md` or `docs/platforms/codex-agents/*.toml`; regenerate them with
`python3 scripts/generate-agent-wrappers.py --write` from the repository root
after changing
`docs/agent-core/*.md` or wrapper metadata in the generator. `agents/*.md` is
the Claude Code-facing subagent wrapper with YAML frontmatter, and
`docs/platforms/codex-agents/*.toml` is the Codex custom-agent wrapper. Skills
own workflow stage selection, artifact creation, approval gates, and next-skill
handoffs. Agents may return findings and recommended next roles or skills to
the calling skill, but they must not bypass skill-chaining gates or act as
hidden workflow automation.

`commands/*.md` may exist only as thin Claude Code slash-command wrappers for
the same public skill names above. Each command must delegate to its matching
`skills-claude/<name>/SKILL.md`, preserve the user's raw arguments, and must not
add a new workflow, hidden automation, or separate source of truth.

Shared workflow behavior lives in `docs/skill-core/<name>.md`. Generated
skill documents embed compact platform runtime guidance from
`docs/platforms/codex-runtime.md` and
`docs/platforms/claude-code-runtime.md`. Longer platform maintenance references
live in `docs/platforms/codex.md` and `docs/platforms/claude-code.md`.
Skill-specific platform overlays live in `docs/platforms/codex-<name>.md` or
`docs/platforms/claude-code-<name>.md` only when needed. Codex-facing runtime
skill documents are generated into
`skills/<name>/SKILL.md`; Claude Code-facing runtime skill documents are
generated into `skills-claude/<name>/SKILL.md`. Do not hand-edit those generated
runtime skill documents. Regenerate them with
`python3 scripts/generate-skill-wrappers.py --write` from the repository root
after changing skill core, platform guidance, or generator metadata.

For ongoing skill maintenance, fixes, and improvements, edit the source
documents, not the generated runtime documents. Put shared skill behavior,
workflow rules, approval gates, artifacts, and verification requirements in
`docs/skill-core/<name>.md`; this is the default and primary edit surface for
skill content changes. Touch compact `docs/platforms/*-runtime.md` files only
for host-specific rules that every generated skill document must actually carry.
Use the longer `docs/platforms/codex.md` and `docs/platforms/claude-code.md`
for maintenance detail that should not be repeated in every generated skill
document. After any source-doc change, regenerate the runtime skill documents
and keep the generated `skills/` and `skills-claude/` files as outputs only.

Company-specific prompt guidance lives in `docs/providers/openai.md` and
`docs/providers/anthropic.md` as maintenance reference only. Do not add provider
docs as generated runtime sources. Summarize stable OpenAI guidance in
`docs/platforms/codex-runtime.md` and stable Anthropic guidance in
`docs/platforms/claude-code-runtime.md`; keep longer platform notes in
`docs/platforms/codex.md` and `docs/platforms/claude-code.md`.

When adapting OMC content:

- Keep only dependencies required by the retained skills.
- Use `.oh-no/specs/` for generated specs.
- Use `.oh-no/plans/` for generated plans.
- Use `.oh-no/sessions/` for transient workflow state.
- Use `.oh-no/worktrees/` for project-local task worktrees.
- Do not add OMC keyword detection, persistent mode hooks, bridge hooks, or state ledger behavior.
- `ultrawork` is the renamed former `autopilot` end-to-end workflow. Keep that
  scope: it orchestrates `interview` -> `ralplan` -> `ralph` with visible
  Markdown state and verification gates.
- Do not reintroduce OMC-era `team`, `ultraqa`, `cancel`, `ask`,
  `autoresearch`, or legacy `ultrawork` behavior such as hidden state ledgers,
  bridge hooks, keyword mode controllers, or runtime daemons.

When editing skills, make skill chaining explicit in Markdown. Do not rely on hidden automation.
