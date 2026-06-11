# Parallel Subagent Pointer

This file is a short pointer, not a second policy. The source of truth for
parallel eligibility, isolation, fallback conditions, batch dispatch, subagent
bias, and integration is `docs/shared/ralph-subagent-policy.md`.

Use this file only when a skill wants a quick reminder that parallel work still
uses Ralph's shared subagent policy plus the active platform adapter.

Batch dispatch and subagent lifecycle rules, including close/cleanup of completed subagents and the prohibition on closing running subagents, live in `docs/shared/ralph-subagent-policy.md`.

## Platform Invocation

This file is platform-neutral. Platform-specific invocation lives in the active
adapter:

- Claude Code: `docs/platforms/claude-code-ralph.md`
- Codex: `docs/platforms/codex-ralph.md`

Keep the role plan the same, but use only the active platform's adapter when
actually dispatching subagents. If the active platform cannot dispatch, preserve
the same role boundary inline and record the fallback reason required by
`docs/shared/ralph-subagent-policy.md`.
