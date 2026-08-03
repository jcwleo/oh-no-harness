---
name: configure-subagents
description: Use only for a current explicit user request or direct command to configure exact OpenCode provider/model IDs for Oh No Harness subagents; never auto-run.
---

# Configure OpenCode Subagents

<HARD-GATE>
First operational rule: continue only when the current user request explicitly
asks to configure Oh No Harness OpenCode subagents or directly invokes this
command. Otherwise STOP before calling `question`, calling
`oh_no_configure_subagents`, or writing anything. Prior conversation, inferred
preference, workflow entry, and another agent's recommendation are not
authorization.
</HARD-GATE>

This standalone setup source does not require the common runtime. It configures
these roles in order: `explore`, `analyst`, `planner`, `plan-reviewer`,
`executor`, `debugger`, `verifier`, `code-reviewer`, and
`fusion-rescue-analyst`.

## Collection

Use `question` for every choice and write nothing before final confirmation.
Model values must be exact OpenCode `provider/model-id` strings, not aliases,
display labels, provider names alone, or guessed IDs. Ask the user to provide
the exact value shown by `opencode models` when uncertain; do not run a model
discovery subprocess or Bash command as part of this workflow.

Ask for one mode:

- `single`: collect one exact provider/model ID and assign it to all nine roles.
- `preset`: collect exact `fast`, `capable`, and `deep` provider/model IDs. Map
  `explore` to fast; `analyst` and `executor` to capable; and `planner`,
  `plan-reviewer`, `debugger`, `verifier`, `code-reviewer`, and
  `fusion-rescue-analyst` to deep.
- `custom`: collect one exact provider/model ID for each role in canonical order.

Reject empty values, whitespace, commas, equals signs, or values without a
nonempty provider followed by `/` and a nonempty model ID. The model ID may
itself contain `/`. Preserve each accepted string exactly; do not normalize or
translate it.

## Confirmation And Apply

Show a final table with mode, all nine role-to-model assignments, target scope,
and the warning that activation requires a restart. Then use `question` once for
`Apply` or `Cancel`. Cancel stops with no tool call and no write.

After explicit `Apply`, call `oh_no_configure_subagents` exactly once with all
nine required properties in this canonical role order:

```json
{
  "explore": "<provider/model-id>",
  "analyst": "<provider/model-id>",
  "planner": "<provider/model-id>",
  "plan-reviewer": "<provider/model-id>",
  "executor": "<provider/model-id>",
  "debugger": "<provider/model-id>",
  "verifier": "<provider/model-id>",
  "code-reviewer": "<provider/model-id>",
  "fusion-rescue-analyst": "<provider/model-id>"
}
```

The tool must issue OpenCode's host permission request before publishing. If the
user denies that request, stop and report cancellation; no preference file is
written.

Do not invoke Bash, a subprocess, or any helper path. Do not preflight the tool,
invoke it once per role, retry it, or edit agent/config files directly. Treat
`STATUS: configured` as success. Treat any other status as no confirmed durable
change and report it without a second invocation. In particular,
`STATUS: indeterminate-durability` means preferences were published but durable
directory synchronization could not be confirmed; never report that status as
"preferences were not changed."

On success, report the configured roles and exact provider/model IDs without
claiming model diversity. Tell the user to quit and restart OpenCode; the
running process retains its startup agent definitions.
