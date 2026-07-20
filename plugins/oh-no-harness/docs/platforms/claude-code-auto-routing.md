# Claude Code Auto Routing Rules

This platform overlay is source content for the generated Claude Code-facing
`auto-routing` runtime document, after the shared core and
`docs/platforms/claude-code-runtime.md`.

Preferred config location:

```text
${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/data/<oh-no-harness-*>/config.json
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

On Claude Code, the shared core's bootstrap/session-start timing applies as the
`SessionStart` event, and the clear/reset command is `/clear`.

When the `codexExecutor` toggle is ON, the codex-executor delegation block is
injected via `SessionStart` on Claude Code only. That injected block re-binds the
executor role and dispatches `oh-no-harness:executor-codex` in place of
`oh-no-harness:executor`. Turning the toggle on or off takes effect only after
the `SessionStart` event re-fires (a new session or `/clear`).
