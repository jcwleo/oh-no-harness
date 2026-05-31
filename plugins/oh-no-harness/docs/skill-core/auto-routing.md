---
name: auto-routing
description: Use when the user wants to turn Oh No Harness automatic skill-selection guidance on or off, check routing status, or make the bootstrap prompt more or less assertive across sessions.
argument-hint: "[on|off|status]"
---

# Auto Routing

Auto Routing controls whether a supported platform bootstrap hook adds stronger
skill-selection guidance to `using-oh-no-harness`.

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

Do not use as a substitute for skill selection inside the current session. This skill only changes persistent bootstrap behavior — for choosing a workflow skill in the current turn, read and follow `using-oh-no-harness`.

## Platform Behavior

Apply the active platform wrapper before changing settings. Some platforms
support persistent bootstrap routing; others can only explain the setting and
leave runtime behavior unchanged.

When the active platform supports persistent bootstrap routing, changes take
effect on the next bootstrap or session-start event, such as a new session, app
restart, clear/reset command, or compaction. Existing session context is not
rewritten.

## Configuration

The setting is stored outside the plugin cache so updates do not overwrite it.

Preferred location when the active platform provides plugin data:

```text
<platform-plugin-data>/config.json
```

The platform wrapper defines how to resolve the plugin data directory.

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

When the active platform wrapper exposes the plugin root:

```bash
"<plugin-root>/scripts/oh-no-config" status
"<plugin-root>/scripts/oh-no-config" on
"<plugin-root>/scripts/oh-no-config" off
```

If the plugin root is not exposed, locate the installed script first according
to the active platform wrapper.

```bash
script="$(find <platform-plugin-cache> -path '*/oh-no-harness/*/scripts/oh-no-config' -print -quit)"
"$script" status
```

## Response Rules

- For `on`, enable the setting, report the config path, and tell the user to
  restart or clear the active platform session before expecting the new behavior.
- For `off`, disable the setting, report the config path, and tell the user to
  restart or clear the active platform session before expecting the new behavior.
- For `status`, report whether auto-routing is on or off and where the setting is stored.
- If Bash is unavailable, explain the config file shape without claiming the setting changed.
- Do not invoke workflow skills from this configuration skill.
