# Claude Code Auto Routing Rules

This platform overlay is source content for the generated Claude Code-facing
`auto-routing` runtime document, after the shared core and
`docs/platforms/claude-code-runtime.md`.

Preferred config location:

```text
$HOME/.claude/plugins/data/<oh-no-harness-*>/config.json
```

When `CLAUDE_PLUGIN_ROOT` is set, use:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" status
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" on
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" off
```

The `codexExecutor` toggle uses the same script with the `codex-executor`
subcommand:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" codex-executor status
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" codex-executor on
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" codex-executor off
```

The `sameHostReview` toggle uses the same script with the `same-host-review`
subcommand:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" same-host-review status
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" same-host-review on
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" same-host-review off
```

On Claude Code, the shared core's bootstrap/session-start timing applies as the
`SessionStart` event, and the clear/reset command is `/clear`.

When the `codexExecutor` toggle is ON, the codex-executor delegation block is
injected via `SessionStart` on Claude Code only. That injected block re-binds the
executor role and dispatches `oh-no-harness:executor-codex` in place of
`oh-no-harness:executor`. Turning the toggle on or off takes effect only after
the `SessionStart` event re-fires (a new session or `/clear`).

When the `sameHostReview` toggle is ON, the `<OH_NO_SAME_HOST_REVIEW>` block is
injected via `SessionStart` on Claude Code. Turning the toggle on or off takes
effect only after the `SessionStart` event re-fires (a new session or `/clear`).
