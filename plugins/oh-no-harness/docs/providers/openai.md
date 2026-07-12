# OpenAI Provider Prompt Guidance

This is a maintenance reference for Codex-facing platform guidance. Generated
Codex runtime skill documents compose `docs/skill-core/<skill>.md` and
`docs/platforms/codex-runtime.md`; they should not include this provider
document as an extra runtime source.

Keep this file company-scoped, not model-scoped. When OpenAI publishes a newer
coding or prompting guide, update this file and then copy only the stable,
runtime-critical rules into `docs/platforms/codex-runtime.md`. Keep longer
maintenance notes in `docs/platforms/codex.md`.

## Source Snapshot

Reviewed on 2026-07-12:

- OpenAI latest model guide:
  `https://developers.openai.com/api/docs/guides/latest-model`
- Codex runtime custom-agent selector observed in the current host: the 5.6
  family exposes Sol, Terra, and Luna variants with per-agent reasoning effort.
- OpenAI Codex prompting guide:
  `https://developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide`
- Codex subagent concepts:
  `https://developers.openai.com/codex/concepts/subagents`
- Codex subagent setup and custom agents:
  `https://developers.openai.com/codex/subagents`

## Stable Runtime Rules

- Put the outcome, acceptance criteria, non-goals or allowed side effects, and
  expected evidence before detailed steps.
- Keep tool instructions next to the tool-use decision. State when a tool should
  be used, when it should be avoided, and what output must be returned.
- For multi-step coding work, preserve plan state, assumptions, changed files,
  and verification evidence in artifacts before handoff or compaction.
- For subagents, include role, scope, files or directories, expected output,
  evidence requirement, and integration owner. Role names alone are not enough.
- Treat approved workflow policy or a user standing preference as the
  authorization boundary for repeated eligible Codex subagent dispatch; do not
  require per-step literal `subagent` wording after that boundary is recorded.
- Codex custom agents are TOML configuration files installed under
  `$CODEX_HOME/agents` or `~/.codex/agents` for personal agents, or under
  project `.codex/agents/` for project-scoped agents. They are not defined
  inside `config.toml`; Codex `[agents]` settings are global subagent settings.
  Oh No Harness uses a quiet user-scope SessionStart ensure by default for
  named `agent_type` dispatch readiness, and Ralph repeats that ensure only as
  fallback. Generated files record the plugin version so updates can refresh
  stale agent definitions. The generated templates pin role-specific models
  from the current 5.6 family and explicit reasoning effort to avoid relying on
  user-specific model inheritance: explore uses Terra at `medium`, analyst and
  executor use Sol at `high`, and the remaining Codex custom agents use Sol at
  `xhigh`. The generated `oh-no-explore` template also sets
  `sandbox_mode = "read-only"`. Claude Code YAML frontmatter is not Codex prompt
  content.
- Prefer compact final responses. Use longer output only for plan approval,
  review findings, verification evidence, or user-requested detail.

## Effort And Verbosity

When the host exposes reasoning or verbosity controls:

- use lower effort for small, already-isolated edits and simple explanations
- use medium effort for ordinary Ralph execution, focused review, and normal
  verification
- use higher effort for architecture-sensitive planning, hard debugging,
  adversarial critique, broad code review, or multi-agent integration
- keep final-answer verbosity low unless an active skill requires a structured
  artifact or evidence report

## Update Checklist

When refreshing OpenAI guidance:

1. Confirm the current official guide URLs.
2. Update this provider reference first.
3. Copy only short, stable runtime rules into `docs/platforms/codex-runtime.md`.
4. Do not create model-named provider files such as `gpt-*.md`.
5. Run plugin validation after changing platform guidance.
