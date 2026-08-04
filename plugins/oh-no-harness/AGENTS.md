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

The first 10 names are workflow skills on Claude Code, Codex, and OpenCode.
Claude Code additionally exposes `install-statusline` and its Claude
`configure-subagents`, for 12 skills. OpenCode exposes its own standalone,
explicit-user-only `configure-subagents`, for 11 skills. Codex exposes only the
10 workflow skills.

The Claude Code `install-statusline` and `configure-subagents` sources are
human-invoke-only setup skills: their frontmatter sets
`disable-model-invocation: true` (so the model never auto-invokes them), and they
ship no Codex wrapper. Both are tracked by `MODEL_UNINVOCABLE_SKILLS`
(invocation), while exact platform availability is tracked by
`SKILL_AVAILABILITY` in the generator and validator. OpenCode's separate
`docs/platforms/opencode-configure-subagents.md` source has an explicit current-
user-request hard gate and is generated without Claude-only invocation metadata.

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

OpenCode model setup is separate from the Claude mechanism. Its explicit-user-
only skill calls the `oh_no_configure_subagents` plugin tool exactly once after
final confirmation. The tool uses `opencode/preference-writer.js` to write exact
provider/model and variant assignments for all nine roles to
`opencode-subagent-models.conf`. Its read-only catalog tool loads configured
models and model-specific variants through OpenCode's client; the write tool
revalidates all nine exact model/variant assignments before publication. The npm
setup completion output hands users off to `/configure-subagents`. A successful
change requires quitting and restarting OpenCode. If preferences are
unconfigured, the nine subagents inherit the `oh-no` primary model; same-role or
inherited-model calls must not be claimed as model diversity.

The unconditional bootstrap owns compact global no-route, direct-edit,
object-of-analysis, and caller-owned child-packet boundaries. Claude auto-on
adds action ordering and essential precedence; Codex gains no forced-routing
semantics.

Treat `docs/agent-core/*.md`, `agents/*.md`,
`docs/platforms/codex-agents/*.toml`, and the role entries in
`opencode/generated/agents.json` as internal role prompts, not additional
public skills. The nine `docs/agent-core/<role>.md` files contain only their
platform-neutral role behavior and are the source of truth for agent prompts;
common child-packet construction belongs to the main caller through the
SessionStart bootstrap or OpenCode static primary contract, not to a fragment
copied into every role. Do not
hand-edit `agents/*.md`, `docs/platforms/codex-agents/*.toml`, or
`opencode/generated/*.json`; regenerate them
with `python3 scripts/generate-agent-wrappers.py --write` from the repository
root after changing a role core, `docs/platforms/opencode-main-agent.md`, or
wrapper metadata. `agents/*.md` is
the Claude Code-facing subagent wrapper with YAML frontmatter, and
`docs/platforms/codex-agents/*.toml` is the Codex custom-agent wrapper.
`opencode/generated/agents.json` contains one `oh-no` primary generated from
`docs/platforms/opencode-main-agent.md` plus nine `oh-no-<role>` subagents;
`opencode/generated/commands.json` contains the exact 11-command OpenCode
inventory. Public
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
comes from `docs/platforms/codex-runtime.md`,
`docs/platforms/claude-code-runtime.md`, and
`docs/platforms/opencode-runtime.md` where the composition requires it.
Longer platform maintenance references
live in `docs/platforms/codex.md`, `docs/platforms/claude-code.md`, and
`docs/platforms/opencode.md`.
Skill-specific platform overlays live in `docs/platforms/codex-<name>.md` or
`docs/platforms/claude-code-<name>.md`, or
`docs/platforms/opencode-<name>.md` only when needed. Codex-facing runtime
skill documents are generated into
`skills/<name>/SKILL.md`; Claude Code-facing runtime skill documents are
generated into `skills-claude/<name>/SKILL.md`; OpenCode-facing runtime skill
documents are generated into `skills-opencode/<name>/SKILL.md`. Do not hand-edit
those generated runtime skill documents. Regenerate them with
`python3 scripts/generate-skill-wrappers.py --write` from the repository root
after changing skill core, platform guidance, or generator metadata.

The self-contained skills (`interview`, `ralplan`, `ralph`,
`systematic-debugging`, `ultrawork`, `verification-before-completion`)
compose each self-sufficient core directly with its required platform adapter,
without the common runtime document. Codex wrappers additionally compose the
dedicated child-packet floor, which contains no other host binding. OpenCode's
`configure-subagents` wrapper is standalone and generated only from
`docs/platforms/opencode-configure-subagents.md`. The 2026-07 FSM rewrites changed
structure, not routing.
The `ralplan-v2` preview was retired on 2026-07-17 after its structural
ideas were absorbed into `ralplan`.

For ongoing skill maintenance, fixes, and improvements, edit the source
documents, not the generated runtime documents. Put shared skill behavior,
workflow rules, approval gates, artifacts, and verification requirements in
`docs/skill-core/<name>.md`; this is the default and primary edit surface for
skill content changes. Touch compact `docs/platforms/*-runtime.md` files only
for host-specific rules that every generated skill document must actually carry.
Use the longer `docs/platforms/codex.md`, `docs/platforms/claude-code.md`, and
`docs/platforms/opencode.md`
for maintenance detail that should not be repeated in every generated skill
document. After any source-doc change, regenerate the runtime skill documents
and keep the generated `skills/`, `skills-claude/`, and `skills-opencode/` files
as outputs only.

The handwritten OpenCode source adapter is `opencode/index.js`, with preference
parsing in `opencode/preferences.js`, secure publication in
`opencode/preference-writer.js`, and read-only status checks in
`opencode/configure-opencode-subagents`. The explicit one-time npm installer is
`opencode/setup.js`; it preserves JSON/JSONC, backs up existing global config,
and idempotently registers the npm package without pre-populating OpenCode's
cache. Its config hook registers
`skills-opencode/` plus `opencode/generated/{agents,commands}.json`, disables
built-in `build` and `plan`, selects `oh-no` only when the default is absent or
one of those built-ins, preserves unrelated custom defaults, and raises
`subagent_depth` to at least 2 without lowering a higher custom value. Source
loading and deterministic tests are implemented. Global permission remains
native host inheritance; restrictive primary and same-role policies ceiling
finite package rules, while role hard denies and exact task topology remain
package-owned. The plugin root `package.json` publishes the public
`oh-no-harness` npm package with `opencode/index.js` as its only module export;
the package exposes `opencode/setup.js` only as its setup binary and contains
the OpenCode adapter, `skills-opencode/`, and package documentation/license
files. Release versions stay in lockstep across both
marketplace manifests and npm metadata.

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
