# OpenAI Provider Prompt Guidance

This is a maintenance reference for Codex-facing platform guidance. Runtime
skill wrappers should read `docs/skill-core/<skill>.md` and
`docs/platforms/codex.md`; they should not load this provider document as an
extra runtime layer.

Keep this file company-scoped, not model-scoped. When OpenAI publishes a newer
coding or prompting guide, update this file and then copy only the stable,
runtime-critical rules into `docs/platforms/codex.md`.

## Source Snapshot

Reviewed on 2026-06-03:

- OpenAI latest model guide:
  `https://developers.openai.com/api/docs/guides/latest-model`
- GPT-5.5 model page:
  `https://developers.openai.com/api/docs/models/gpt-5.5/`
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
- Codex custom agents are TOML configuration files under `.codex/agents/` or
  `~/.codex/agents/`; Claude Code YAML frontmatter is not Codex prompt content.
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
3. Copy only short, stable runtime rules into `docs/platforms/codex.md`.
4. Do not create model-named provider files such as `gpt-*.md`.
5. Run plugin validation after changing platform guidance.
