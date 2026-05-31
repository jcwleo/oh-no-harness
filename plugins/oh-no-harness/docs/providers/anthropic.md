# Anthropic Provider Prompt Guidance

This is a maintenance reference for Claude Code-facing platform guidance.
Runtime skill wrappers should read `docs/skill-core/<skill>.md` and
`docs/platforms/claude-code.md`; they should not load this provider document as
an extra runtime layer.

Keep this file company-scoped, not model-scoped. When Anthropic publishes a
newer Claude, Claude Code, or prompting guide, update this file and then copy
only the stable, runtime-critical rules into `docs/platforms/claude-code.md`.

## Source Snapshot

Reviewed on 2026-05-31:

- Claude Opus 4.8 update:
  `https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-8`
- Claude model migration guide:
  `https://platform.claude.com/docs/en/about-claude/models/migration-guide`
- Claude prompting best practices:
  `https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices`
- Claude Code subagents:
  `https://code.claude.com/docs/en/subagents`
- Claude Code common workflows:
  `https://code.claude.com/docs/en/common-workflows`

## Stable Runtime Rules

- Use clear sections or tagged blocks for goal, scope, non-goals, constraints,
  approval gates, expected evidence, and output format.
- Be explicit about what the agent may do, must not do, and must ask before
  changing. Do not rely on implied constraints.
- For user approval, ask one focused question at a time and keep choices
  mutually exclusive when the host supports structured questions.
- For Claude Code role dispatch, prefer plugin-scoped agents when available.
  If they are unavailable, embed the matching `agents/<role>.md` prompt in the
  host's Task, Agent, Workflow `agent()`, or subagent mechanism.
- Preserve long-running state in artifacts before compaction, task handoff, or
  subagent dispatch.

## Effort And Thinking

When the host exposes thinking or effort controls:

- use lower effort for small, already-bounded edits and simple explanations
- use higher effort for agentic coding, architecture review, critique,
  ambiguous debugging, or multi-step plan revision
- keep final answers concise unless an active skill requires a plan approval
  brief, findings list, or verification report

## Update Checklist

When refreshing Anthropic guidance:

1. Confirm the current official Claude and Claude Code guide URLs.
2. Update this provider reference first.
3. Copy only short, stable runtime rules into
   `docs/platforms/claude-code.md`.
4. Do not create model-named provider files such as `opus-*.md`.
5. Run plugin validation after changing platform guidance.
