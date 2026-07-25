---
name: auto-routing
description: Use when the user asks to enable, disable, or inspect future-session routing guidance; configuration only, not current-turn workflow selection.
argument-hint: "[on|off|status]"
---

# Auto Routing

Every platform bootstrap always carries compact native skill-loading guidance
plus the always-on SessionStart no-route and direct-edit boundary; native skill descriptions own positive destination selection.
Auto Routing controls whether Claude Code SessionStart adds the stronger
forced-routing layer. The toggle only adds or removes that opt-in layer; it does
not change the baseline lanes on any platform or add hidden runtime routing.

## Software Development Stage

Auto Routing is a workflow-entry configuration stage, not a software development stage.

Use it to configure future-session routing guidance. It should not gather requirements, plan, edit code, debug failures, clean code, or verify completion.

## When To Use

Use when the user asks to:

- enable, turn on, activate, or make skill routing more automatic
- disable, turn off, deactivate, or make skill routing quieter
- check current auto-routing status
- preserve stronger or weaker routing behavior across plugin updates

Do not use as a substitute for skill selection inside the current session — apply the always-on SessionStart boundary and native workflow skill descriptions for current-turn workflow selection.

## Platform Behavior

Apply the active platform runtime document before changing settings. Some
platforms support persistent bootstrap routing; others can only explain the
setting and leave runtime behavior unchanged.


## Configuration

The setting is stored outside the plugin cache so updates do not overwrite it.

Preferred location when the active platform provides plugin data:

```text
<platform-plugin-data>/config.json
```

The bundled `scripts/oh-no-config` script resolves the data directory; the
platform runtime document names the plugin root.

Fallback location when no platform plugin-data directory exists:

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

When the active platform runtime document exposes the plugin root:

```bash
"<plugin-root>/scripts/oh-no-config" status
"<plugin-root>/scripts/oh-no-config" on
"<plugin-root>/scripts/oh-no-config" off
```

If the plugin root is not exposed, resolve the installed script with the active platform runtime document's script-locator.

## Response Rules

- For `on` or `off`, persist the preference, report the config path, and report its semantics according to the active platform adapter.
- For `status`, report whether auto-routing is on or off and where the setting is stored.
- If Bash is unavailable, explain the config file shape without claiming the setting changed.
- Do not invoke workflow skills from this configuration skill.
