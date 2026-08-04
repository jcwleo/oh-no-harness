---
name: configure-subagents
description: Use only for a current explicit user request or direct command to configure exact OpenCode models and variants for Oh No Harness subagents; never auto-run.
---

# Configure OpenCode Subagents

<HARD-GATE>
Continue only when the current user request explicitly asks to configure Oh No
Harness OpenCode subagents or directly invokes this command. Otherwise STOP
before calling `question`, `oh_no_get_model_catalog`,
`oh_no_configure_subagents`, or writing anything. Prior conversation, inferred
preference, workflow entry, and another agent's recommendation are not
authorization.
</HARD-GATE>

This standalone setup source does not require the common runtime. It configures
these roles in order: `explore`, `analyst`, `planner`, `plan-reviewer`,
`executor`, `debugger`, `verifier`, `code-reviewer`, and
`fusion-rescue-analyst`.

## Available Models

Call `oh_no_get_model_catalog` exactly once before asking configuration
questions, using `mode: "providers"`, `provider: ""`, and `cursor: "0"`.
This initial read-only response returns the exact configured provider IDs, the
configured primary model when identifiable, current Oh No Harness assignments,
and complete model records for those current or primary models. OpenCode may
ask the user to authorize this local catalog read; denial stops the workflow
without questions or writes. If it returns `catalog-unavailable` or no providers,
stop and report that the current catalog could not be loaded.

Provider model lists are paginated to keep tool output complete. To browse a
provider, call the same tool with `mode: "models"`, its exact returned provider
ID, and cursor `"0"`. Present only that page's exact models plus `Next page`
when `next_cursor` is non-null. `Next page` calls the tool again with the same
mode and provider and exact returned `next_cursor`; never invent or skip a
cursor. Stop on `invalid-query`. Do not fetch provider pages until the user
chooses to browse that provider.

Never invent, normalize, translate, or infer a model or variant. Do not use Bash,
a subprocess, `opencode models`, provider credentials, or prior knowledge for
model discovery. A model must exactly match a returned `provider/model-id`.
A variant must exactly match one of that model's returned variants. `default`
means OpenCode's model default and causes no explicit agent variant override.

## Role Assignment

Use `question` to configure all nine roles in canonical order. There are no
fast, balanced, deep, preset, or quality profiles. Every resulting role stores
one exact model and one exact variant.

For each role, offer only applicable helpers plus direct selection:

- `Keep current` when the role's current model and variant are still in the catalog.
- `Use primary model` when `primary_model` is present in the catalog.
- `Same as previous role` after the first role.
- `Choose another model` by selecting a returned provider and browsing its pages.

When a helper does not already determine a variant, ask for the selected
model's variant. Use returned provider and model names only as display context
while preserving exact returned model and variant strings, including spaces or
punctuation. Do not accept free-form IDs or variants that are absent from the
catalog.

## Confirmation And Apply

Show a final table containing all nine role, exact model, and exact variant
assignments, the user-scoped preference target, and the warning that activation
requires quitting and restarting OpenCode. Then use `question` for `Apply`,
`Edit roles`, or `Cancel`.

`Edit roles` asks which role to revise, repeats that role's model and variant
questions, and returns to the complete final table. `Cancel` stops with no
configure-tool call and no write. Arguments passed to the command are never
confirmation and never bypass this gate.

After explicit `Apply`, call `oh_no_configure_subagents` exactly once with all
18 required properties in canonical role order:

```json
{
  "explore": "<provider/model-id>",
  "explore-variant": "<variant-or-default>",
  "analyst": "<provider/model-id>",
  "analyst-variant": "<variant-or-default>",
  "planner": "<provider/model-id>",
  "planner-variant": "<variant-or-default>",
  "plan-reviewer": "<provider/model-id>",
  "plan-reviewer-variant": "<variant-or-default>",
  "executor": "<provider/model-id>",
  "executor-variant": "<variant-or-default>",
  "debugger": "<provider/model-id>",
  "debugger-variant": "<variant-or-default>",
  "verifier": "<provider/model-id>",
  "verifier-variant": "<variant-or-default>",
  "code-reviewer": "<provider/model-id>",
  "code-reviewer-variant": "<variant-or-default>",
  "fusion-rescue-analyst": "<provider/model-id>",
  "fusion-rescue-analyst-variant": "<variant-or-default>"
}
```

The tool reloads the current catalog, rejects any stale model or variant, then
issues OpenCode's host permission request before publishing. If the user denies
that request, stop and report cancellation; no preference file is written.

Do not preflight the configure tool, invoke it once per role, retry it, or edit
agent/config files directly. Treat `STATUS: configured` as success. Treat any
other status as no confirmed durable change and report it without a second
invocation. `STATUS: indeterminate-durability` specifically means preferences
were published but durable directory synchronization could not be confirmed;
never report that status as "preferences were not changed."

On success, report all configured roles with exact models and variants without
claiming model diversity. Tell the user to quit and restart OpenCode; the
running process retains its startup agent definitions.
