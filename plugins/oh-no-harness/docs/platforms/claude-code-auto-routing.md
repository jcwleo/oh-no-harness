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

Changes take effect on the next Claude Code `SessionStart`, such as a new
session, app restart, `/clear`, or compaction.
