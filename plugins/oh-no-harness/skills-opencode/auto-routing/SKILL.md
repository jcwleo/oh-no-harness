---
name: auto-routing
description: Use when the user asks to enable, disable, or inspect future-session routing guidance; configuration only, not current-turn workflow selection.
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Auto Routing for OpenCode

This generated file is the OpenCode-facing runtime skill document. OpenCode should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/auto-routing.md`
- `../../docs/platforms/opencode-runtime.md`
- `../../docs/platforms/opencode-auto-routing.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/auto-routing.md

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

## Source: docs/platforms/opencode-runtime.md

# OpenCode Runtime Rules

This compact section is embedded in generated OpenCode-facing skill documents.

## Native Skills And Questions

Load an applicable Oh No Harness workflow with OpenCode's native `skill` tool.
The loaded skill is the source of truth. When it names a next-skill handoff,
obtain the required approval with `question`, then load the selected skill
yourself and pass the artifact path and approved profile. Do not ask the user to
invoke it manually.

Use `question` for approval, preference, scope, and next-step choices. Ask one
focused question at a time unless the active skill explicitly combines
questions. Present a small set of mutually exclusive actions and wait for the
answer before crossing the gate.

## Role Dispatch

Dispatch an Oh No Harness role with OpenCode's `task` tool and exact
`subagent_type: oh-no-<role>`. The direct user form is `@oh-no-<role>`.
Do not substitute a built-in or generic subagent while the matching role is
available.

Use a self-contained packet with purpose, role, exact target and revision,
scope and permissions, non-goals, acceptance contract, required evidence and
output, and stop/escalation conditions. Foreground `task` is the default: its
completed return is the wait and result. For independent work, issue the whole
eligible batch in one assistant turn. If background tasks are exposed, wait for
their automatic completion notifications; do not poll, duplicate, or redo their
scope inline. Capture and use every final result before advancing.

The role's configured model is selected by its agent definition; never pass or
claim a per-call model override. An unconfigured role inherits the invoking
primary agent's model. Two calls to one role therefore prove independent
contexts, not model diversity.

## Configuration Activation

OpenCode loads skills, agents, and configuration at startup. After any Oh No
Harness configuration change, tell the user to quit and restart OpenCode; the
current process keeps its startup snapshot.

## Source: docs/platforms/opencode-auto-routing.md

# OpenCode Auto Routing Rules

This overlay follows the shared Auto Routing core and the OpenCode runtime.

OpenCode native skill descriptions and the `skill` tool remain the positive
routing surface. Whenever the selected primary is `oh-no`, its static main-agent
rules always provide the standing no-route, direct-edit, object-of-analysis, and
orchestration contract. Auto Routing must not add keyword routing, hidden
workflow chaining, or a second destination selector.

OpenCode has no persistent Auto Routing toggle in this implementation. The
shared configuration and persistence instructions do not apply on this
platform: do not run the configuration script, write a preference, or edit any
configuration, skill, or agent file for `status`, `on`, or `off`.

- For `status`, report that there is no stored on/off state and that the
  selected `oh-no` primary always carries its standing routing and orchestration
  contract. Explain that native skill descriptions remain the positive
  selection mechanism and no hidden routing is active.
- For `on`, explain that it is a no-op because no stronger persistent routing
  layer is available on OpenCode. Perform no write and do not claim changed
  state or require a restart.
- For `off`, explain that it is a no-op because the selected `oh-no` primary's
  standing contract is not toggleable. Perform no write and do not claim changed
  state or require a restart.
