# Agent Instructions

This repository is a Markdown-first skill harness.

Keep the external skill surface limited to:

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
- `install-statusline`
- `configure-subagents`

`install-statusline` and `configure-subagents` are Claude-Code-only,
human-invoke-only setup skills: their frontmatter sets
`disable-model-invocation: true` (so the model never auto-invokes them), and they
ship no Codex wrapper. Both are tracked by `CLAUDE_ONLY_SKILLS` (platform) and
`MODEL_UNINVOCABLE_SKILLS` (invocation) in the generator and validator.

`configure-subagents` collects a model and reasoning effort for each of the 9
subagents (`explore`, `analyst`, `planner`, `plan-reviewer`, `executor`,
`debugger`, `verifier`, `code-reviewer`, `fusion-rescue-analyst`) and rewrites
the installed runtime `agents/*.md` in one recoverable transaction via
`scripts/configure-subagents`. It also stores the optional secondary top-tier
model used for config-driven Claude-host review-pair and Fusion Rescue model
diversity. It never edits the generator-owned canonical `agents/*.md` in a
source checkout, never mutates Codex custom-agent TOMLs, and never stores or
prints proxy credentials. The SessionStart hook reapplies stored preferences
best-effort after a plugin-cache update.

The unconditional bootstrap owns compact global no-route, direct-edit,
object-of-analysis, and caller-owned child-packet boundaries. Claude auto-on
adds action ordering and essential precedence; Codex gains no forced-routing
semantics.

Treat `docs/agent-core/*.md`, `agents/*.md`, and
`docs/platforms/codex-agents/*.toml` as internal role prompts, not additional
public skills. The nine `docs/agent-core/<role>.md` files contain only their
platform-neutral role behavior and are the source of truth for agent prompts;
common child-packet construction belongs to the main caller through the
SessionStart bootstrap, not to a fragment copied into every role. Do not
hand-edit `agents/*.md` or `docs/platforms/codex-agents/*.toml`; regenerate them
with `python3 scripts/generate-agent-wrappers.py --write` from the repository
root after changing a role core or wrapper metadata. `agents/*.md` is
the Claude Code-facing subagent wrapper with YAML frontmatter, and
`docs/platforms/codex-agents/*.toml` is the Codex custom-agent wrapper. Public
workflow descriptions own positive selection. Skills own workflow stage
selection, artifact creation, approval gates, and next-skill handoffs. Agents
may return findings and recommended next roles or skills to
the calling skill, but they must not bypass skill-chaining gates or act as
hidden workflow automation.

`commands/*.md` may exist only as thin Claude Code slash-command wrappers for
the same public skill names above. Each command must delegate to its matching
`skills-claude/<name>/SKILL.md`, preserve the user's raw arguments, and must not
add a new workflow, hidden automation, or separate source of truth.

Shared workflow behavior lives in `docs/skill-core/<name>.md`. Every generated
Codex workflow document also embeds the compact main-caller floor from
`docs/platforms/codex-child-packet-floor.md`; other compact platform guidance
comes from `docs/platforms/codex-runtime.md` and
`docs/platforms/claude-code-runtime.md` where the composition requires it.
Longer platform maintenance references
live in `docs/platforms/codex.md` and `docs/platforms/claude-code.md`.
Skill-specific platform overlays live in `docs/platforms/codex-<name>.md` or
`docs/platforms/claude-code-<name>.md` only when needed. Codex-facing runtime
skill documents are generated into
`skills/<name>/SKILL.md`; Claude Code-facing runtime skill documents are
generated into `skills-claude/<name>/SKILL.md`. Do not hand-edit those generated
runtime skill documents. Regenerate them with
`python3 scripts/generate-skill-wrappers.py --write` from the repository root
after changing skill core, platform guidance, or generator metadata.

The self-contained skills (`interview`, `ralplan`, `ralph`,
`systematic-debugging`, `ultrawork`, `verification-before-completion`)
compose each self-sufficient core directly with its required
`codex-<name>.md` or `claude-code-<name>.md` adapter, without either common
runtime document. Codex wrappers additionally compose the dedicated child-packet
floor, which contains no other host binding. The 2026-07 FSM rewrites changed
structure, not routing.
The `ralplan-v2` preview was retired on 2026-07-17 after its structural
ideas were absorbed into `ralplan`.

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
