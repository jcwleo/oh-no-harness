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
