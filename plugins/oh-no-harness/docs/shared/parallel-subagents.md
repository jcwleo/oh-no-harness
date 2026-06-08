# Parallel Subagent Pointer

This file is a short pointer, not a second policy. The source of truth for
parallel eligibility, isolation, fallback conditions, batch dispatch, subagent
bias, and integration is `docs/shared/ralph-subagent-policy.md`.

Use this file only when a skill wants a quick reminder that parallel work still
uses Ralph's shared subagent policy plus the active platform adapter.

## Platform Invocation

This file is platform-neutral. Platform-specific invocation lives in the active
adapter:

- Claude Code: `docs/platforms/claude-code-ralph.md`
- Codex: `docs/platforms/codex-ralph.md`

Keep the role plan the same, but use only the active platform's adapter when
actually dispatching subagents. If the active platform cannot dispatch, preserve
the same role boundary inline and record the fallback reason required by
`docs/shared/ralph-subagent-policy.md`.

When a parallel batch is useful and allowed, spawn the whole eligible batch
first. Do not spawn one subagent, wait for it, and only then decide whether to
spawn the rest.

After each subagent reaches a final status and its result has been captured,
integrated, rejected, or recorded as blocked, close or clean up the completed
subagent with the active platform's mechanism. A timeout, empty wait result, or
"no agents completed" response is not a final status. Hard rule: MUST NOT close
or clean up a running or pending subagent merely because it is slow. Close
without a captured final result only when the user explicitly cancels or stops
that subagent, the task scope invalidates the work, the spawn was duplicate or
mis-scoped, or continuing creates a safety, security, or filesystem risk. Record
that close as cancelled or abandoned and never use missing output as completion
evidence. If the platform has no explicit close operation, record that fallback.

## Quick Checklist

Before dispatching parallel work, confirm that
`docs/shared/ralph-subagent-policy.md` has been applied and write down:

- story or task id
- owned files, directories, or read-only scope
- files and directories that must not be touched
- expected output: patch, findings, evidence, or test result
- verification responsibility
- dependencies on other agents
- integration owner
- lifecycle owner: who captures output and closes or cleans up the completed
  subagent
- platform invocation: Claude Code agent name or Codex agent type
- start timing: foreground, background, or sequential after another role

Implementation subagents must be told that they are not alone in the codebase and must not revert, overwrite, or reformat work outside their assigned scope.
