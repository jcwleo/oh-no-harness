---
name: auto-routing
description: Use when the user wants to turn Oh No Harness automatic skill-selection guidance on or off, check routing status, or make the bootstrap prompt more or less assertive across sessions.
argument-hint: "[on|off|status]"
---

# Auto Routing

Auto Routing controls whether the Claude Code bootstrap hook adds stronger skill-selection guidance to `using-oh-no-harness`.

It does not add hidden runtime routing. It only changes persistent user preference for the SessionStart prompt.

## Software Development Stage

Auto Routing is a workflow-entry configuration stage, not a software development stage.

Use it to make future sessions more likely to choose the right skill before work starts. It should not gather requirements, plan, edit code, debug failures, clean code, or verify completion.

## When To Use

Use when the user asks to:

- enable, turn on, activate, or make skill routing more automatic
- disable, turn off, deactivate, or make skill routing quieter
- check current auto-routing status
- preserve stronger or weaker routing behavior across plugin updates

## Platform Behavior

Claude Code reads this setting from plugin data during `SessionStart`.

Changes take effect on the next Claude Code `SessionStart`, such as a new session, app restart, `/clear`, or compaction. Existing session context is not rewritten.

Codex does not run the Claude Code hook. In Codex, this skill can explain the setting and keep the file format consistent, but it does not change Codex bootstrap behavior.

## Configuration

The setting is stored outside the plugin cache so updates do not overwrite it.

Preferred location (Claude Code):

```text
$HOME/.claude/plugins/data/<oh-no-harness-*>/config.json
```

The `<oh-no-harness-*>` directory is the plugin data dir Claude Code creates for oh-no-harness (for example `oh-no-harness-oh-no-harness`). The script writes there directly so the SessionStart hook reads the same file regardless of which plugin's `CLAUDE_PLUGIN_DATA` happened to be set when the toggle ran.

Fallback location when that directory is unavailable (Cursor, Copilot, etc.):

```text
${XDG_CONFIG_HOME:-$HOME/.config}/oh-no-harness/config.json
```

Stored shape:

```json
{
  "autoRouting": {
    "enabled": true
  }
}
```

## Commands

When Bash is available, use the bundled script instead of editing config by hand.

If `CLAUDE_PLUGIN_ROOT` is set:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" status
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" on
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" off
```

If `CLAUDE_PLUGIN_ROOT` is not set, locate the installed script first:

```bash
script="$(find "$HOME/.claude/plugins/cache" -path '*/oh-no-harness/*/scripts/oh-no-config' -print -quit)"
"$script" status
```

## Response Rules

- For `on`, enable the setting, report the config path, and tell the user to restart Claude Code or run `/clear` before expecting the new behavior.
- For `off`, disable the setting, report the config path, and tell the user to restart Claude Code or run `/clear` before expecting the new behavior.
- For `status`, report whether auto-routing is on or off and where the setting is stored.
- If Bash is unavailable, explain the config file shape without claiming the setting changed.
- Do not invoke workflow skills from this configuration skill.
