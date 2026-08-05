# OpenCode Platform Rules

This is the longer OpenCode maintenance reference. Generated workflow documents
use the compact runtime, the static main-agent source, and any skill-specific
adapter instead.

## Native Surfaces

The public npm package is `oh-no-harness`; its default export is
`opencode/index.js`. Users run `npx --yes oh-no-harness@latest setup`, whose explicit
one-time binary validates and backs up the effective global JSON/JSONC config
before idempotently adding `"oh-no-harness"` to its `plugin` array. OpenCode
installs the registered package with Bun at startup. There is no persistent
global process, install lifecycle script, daemon, or MCP server.
The setup completion output directs users to `/configure-subagents` inside
OpenCode, where the plugin can use the native configured-provider catalog rather
than duplicating model discovery in the setup process.

OpenCode discovers `SKILL.md` definitions and loads them on demand with the
native `skill` tool. Use `question` for approval, preference, scope, and
next-step gates. A handoff is complete only after approval and a native `skill`
call by the current agent; do not tell the user to invoke the next workflow.

Oh No Harness subagents are OpenCode agent definitions named `oh-no-<role>`.
Programmatic dispatch uses `task` with exact
`subagent_type: oh-no-<role>`. Users may invoke a role directly with
`@oh-no-<role>`. The nine roles are `explore`, `analyst`, `planner`,
`plan-reviewer`, `executor`, `debugger`, `verifier`, `code-reviewer`, and
`fusion-rescue-analyst`.

## Task Lifecycle

Each task receives a self-contained packet because child sessions do not imply
the caller's full working context. Include purpose, exact target/revision,
scope, ownership and permissions, non-goals, acceptance contract, evidence,
output envelope, return owner, and stop/escalation conditions.

Foreground `task` is synchronous and is the default wait: use its completed
return as the role result. Independent task calls may be issued together in one
assistant turn, up to the main-agent concurrency limit. Background mode is
optional and availability-dependent; when used, OpenCode sends a completion
notification. Do not poll, sleep, duplicate a slow task, or redo its scope
inline. Capture every final output and changed-file set and use it before the
dependent transition.

If a named role is unavailable, follow the active skill's fallback. Never
silently relabel a built-in or generic subagent as an Oh No Harness role.
Required independent Plan-Reviewer, reviewer, verifier, and Fusion Rescue panel
contexts remain blockers when no separate task context exists.

## Models

An agent definition may set an exact `provider/model-id` and a model-specific
`variant`. A role without a model setting inherits the invoking primary agent's
model. A stored `default` variant omits the explicit agent variant override. The
`task` call has no model field, so callers must not add per-call overrides or
infer a model from a role label.

Configuration states are explicit:

- `configured`: the role has a stored exact provider/model ID and variant.
- `unconfigured`: the role inherits the current primary model.

Multiple calls to one role provide context and perspective independence, not
model diversity. Pair and Fusion Rescue adapters must report same-model behavior
unless distinct runtime identities are genuinely proven; OpenCode's same-role
binding alone never proves that. Strict diversity requests pause rather than
degrade silently or make a false claim.

## Configuration And Restart

Agent, skill, command, and config files are loaded at process startup and are
not hot-reloaded. Configuration workflows collect all values, obtain final
confirmation, and apply one transaction through their installed mechanism.
After a successful change, tell the user to quit and restart OpenCode. A new
conversation inside the same process is not a reliable activation boundary.

The standalone OpenCode Configure Subagents source reads the configured provider
catalog through `oh_no_get_model_catalog`, then records one exact available
model and model-specific variant for each of the nine roles. It has no profile
or preset modes. It is explicit-user-only and must not ask questions or call
either custom tool without current-request authorization. After final
question-based confirmation, it calls `oh_no_configure_subagents` exactly once
with all nine assignments; the tool reloads the catalog before writing.

Configuration writes are supported only on POSIX hosts, including macOS and
Linux. Windows (`win32`) returns `STATUS: unsupported-platform` without writing.
The writer validates the exact role set, rejects symlink or insecure final
directories, uses no-follow handles, publishes by same-directory atomic rename,
and fsyncs both content and directory. A post-rename directory-fsync failure is
reported as `STATUS: indeterminate-durability`: publication already occurred,
so it must never be described as "preferences were not changed."

## Permission Inheritance

The config hook leaves global `permission` unchanged so OpenCode inherits and
flattens it natively. A user-defined `agent.oh-no.permission` is a ceiling for
the primary and every package child; a same-name child policy can narrow only
that child. Replacement agents retain arbitrary `ask` and `deny` tool/target
patterns from those two agent scopes and discard their `allow` entries.

Package policy adds only the primary question requirement, exact finite task
edges with deny outside the topology, the configurator ask/deny boundary, edit
denies for non-planner/executor roles, and Bash denies for roles that must never
shell. Planner/executor edit and primary/executor/explore/debugger/verifier Bash
otherwise inherit host policy. Finite package exceptions are checked against
the concrete global, primary, and same-role result before emission. Symbolic
patterns are retained as restrictions, never evaluated as concrete tool names
or expanded through glob algebra; ambiguous combinations fail restrictive.

## Static Main Agent

`opencode-main-agent.md` owns the global no-route, direct-edit,
object-of-analysis, `.oh-no` state/gate, child-packet, need-test, review
independence, workflow-internal role boundaries and unmatched defaults, planning-boundary, model-fidelity, explicit-chaining,
and concurrency rules. Keep host detection, installation, dynamic model
selection, and config mutation outside that static source.
