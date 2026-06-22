# Claude Code Install Statusline Rules

This platform overlay is source content for the generated Claude Code-facing
`install-statusline` runtime document, after the shared core and
`docs/platforms/claude-code-runtime.md`.

The statusline installs into Claude Code's user settings at `~/.claude`.

When `CLAUDE_PLUGIN_ROOT` is set, run the bundled installer directly:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/install-statusline" check
"${CLAUDE_PLUGIN_ROOT}/scripts/install-statusline" apply
"${CLAUDE_PLUGIN_ROOT}/scripts/install-statusline" apply --replace
```

If the plugin root is not exposed, locate the installed script first:

```bash
script="$(find ~/.claude/plugins -path '*/oh-no-harness/*/scripts/install-statusline' -print -quit)"
"$script" check
```

For the `conflict` case, ask the user with the host's structured question tool
(`AskUserQuestion`) before replacing: show the existing
`statusLine.command`, and offer "back up and replace" versus "keep existing". Only
run `apply --replace` after an explicit choice to replace.

The statusline reads Claude Code's statusLine JSON input, including `.effort.level`
for the model reasoning effort. The change takes effect on the next
`refreshInterval` tick; `/clear` or a new session guarantees it.
