---
name: auto-routing
description: Use when the user asks to enable, disable, or inspect future-session routing guidance; configuration only, not current-turn workflow selection.
argument-hint: "[on|off|status]"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Auto Routing for Claude Code

This generated file is the Claude Code-facing runtime skill document. Claude Code slash commands should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/auto-routing.md`
- `../../docs/platforms/claude-code-runtime.md`
- `../../docs/platforms/claude-code-auto-routing.md`

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

## Source: docs/platforms/claude-code-runtime.md

# Claude Code Runtime Rules

This compact platform section is embedded in generated Claude Code-facing skill
documents.

## Skill Loading

Claude Code-facing public skills live under `skills-claude/`. Generated
`skills-claude/<skill>/SKILL.md` files compose the matching skill core, this
compact runtime section, and any Claude Code skill-specific overlay such as
`docs/platforms/claude-code-<skill>.md`. Slash commands must delegate to the
matching generated skill document.

## User Approval, Tasks, And Prompting

Use the host's structured question tool when available for approval,
preference, scope, or next-step selection; otherwise ask one focused plain-text
question and wait. Present options as actions the host agent will take.

When a core skill has a multi-phase approval handoff and the host exposes task
tracking, create one task per phase and complete them sequentially.

Keep Claude prompts explicit and sectioned: state scope, non-goals,
constraints, approval gates, expected evidence, and output format. Preserve
long-running context in artifacts before compaction, task handoff, or subagent
dispatch.

## Role Dispatch

Dispatch only after the active skill's trigger fires, then read
`docs/platforms/claude-code.md` `## Role Dispatch` for the full host contract.
Prefer `oh-no-harness:<role>`, request the whole independent batch before
waiting, capture every final result, and clean up only after integration. An
approved-plan handoff is dispatch authorization for eligible isolated roles;
plugin-agent unavailability uses the documented embedded-role fallback.

## Model Diversity Pair

This mechanism is trigger-loaded, not embedded in every workflow decision. It
governs only how an ALREADY-SELECTED pair is dispatched; it never selects review
topology itself. The active core or skill owns that selection, and a
`code-reviewer` pair applies only where that core already selected
`perspective-pair` after a named trigger, or the caller explicitly demanded
strict diversity — never to every dispatched review. For
a dispatched THOROUGH `plan-reviewer` pair, such a selected `code-reviewer` pair,
or a named THOROUGH `debugger` pair, both legs MUST be requested in a single
batch: issue both subagent tool calls in the same assistant turn (or with
`Background: yes` for both) BEFORE waiting on either result; a serial
dispatch-wait-dispatch sequence is not a valid pair. The two legs' packet bodies
MUST be identical except the single `Assigned perspective:` line (Lens A on the
primary leg, Lens B on the diversity leg); leg identity (`primary` vs
`diversity`) is carried ONLY by the host dispatch metadata (the description field
and the model override), never inside the packet text. Read the role's concrete
stored primary and validated secondary top-tier model from the session
`<OH_NO_MODEL_DIVERSITY>` block. The primary leg is
unoverridden and uses the declared-frontmatter primary; the
secondary leg carries an explicit NATIVE model override. Claim
`model-diversity-pair` only when the primary is not `host-default` and the
secondary differs from it. Otherwise default to two independent same-model
instances as `same-model-parallel-fallback` with the reason recorded; an
explicit `require-model-diversity` demand transitions to PAUSED when the
diversity leg is unavailable. Fusion Rescue uses its Claude Code overlay's
three-panel assignment instead of this two-leg shape.

## Source: docs/platforms/claude-code-auto-routing.md

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

If the plugin root is not exposed, resolve the installed script first:

```bash
tab="$(printf '\t')"
plugins="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins"
reg="$plugins/installed_plugins.json"
# 1) Host-exposed plugin root wins (stays first-preferred).
script="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/scripts/oh-no-config}"
# 2) Else the authoritative installPath for the EXACT oh-no-harness@oh-no-harness
#    registry key (no jq; block-scoped so a config-home path or another plugin that
#    merely contains the substring never matches; newest version among that key's
#    scope entries). Trust only one validly closed array; truncated, compact, or
#    ambiguous input yields no candidate. installPath is a hint only, and a missing
#    or unreadable registry must not abort under strict mode: the [ -r ] guard +
#    `|| true` keep tier 3 reachable, and the [ -x ] guard lets a Windows drive-letter
#    path fall through.
if [ ! -x "$script" ] && [ -r "$reg" ]; then
  root="$(awk '
    /"oh-no-harness@oh-no-harness":[[:space:]]*\[/ {
      keys++
      if (keys != 1 || inblk || closed) { bad=1; next }
      inblk=1; next
    }
    inblk && /^[[:space:]]*\]/ { inblk=0; closed=1; next }
    inblk && /"installPath":/ {
      p=$0
      if (p !~ /"installPath":[[:space:]]*"[^"]+"/) { bad=1; next }
      sub(/.*"installPath":[[:space:]]*"/,"",p); sub(/".*/,"",p)
      v=p; sub(/.*\//,"",v); paths[++n]=p; versions[n]=v
    }
    END {
      if (keys == 1 && closed && !inblk && !bad)
        for (i=1; i<=n; i++) print versions[i] "\t" paths[i]
    }' "$reg" 2>/dev/null | LC_ALL=C sort -t"$tab" -k1,1V -k2,2 | tail -n1 | cut -f2- || true)"
  script="${root:+$root/scripts/oh-no-config}"
fi
# 3) Else the newest INSTALLED semver in the cache — never the marketplace checkout.
#    Sort on the VERSION path component (full path only as tie-break) so a second
#    marketplace identity cannot let an older version win.
if [ ! -x "$script" ]; then
  script="$(find "$plugins/cache" -path '*/oh-no-harness/*/scripts/oh-no-config' 2>/dev/null \
    | awk -F/ '{for(i=NF;i>0;i--) if($i=="scripts"){print $(i-1)"\t"$0; break}}' \
    | LC_ALL=C sort -t"$tab" -k1,1V -k2,2 | tail -n1 | cut -f2-)"
fi
"$script" status
```

On Claude Code, native skill descriptions select the destination. When the
stored preference is enabled, Claude-only action ordering and essential
precedence guidance applies from the next `SessionStart`; the clear/reset
command is `/clear`.
