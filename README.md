# Oh No Harness

[![GitHub release](https://img.shields.io/github/v/release/jcwleo/oh-no-harness?include_prereleases&color=blue)](https://github.com/jcwleo/oh-no-harness/releases)
[![Status: Stable](https://img.shields.io/badge/status-stable-green.svg)](https://github.com/jcwleo/oh-no-harness/releases)
[![GitHub stars](https://img.shields.io/github/stars/jcwleo/oh-no-harness?style=flat&color=yellow)](https://github.com/jcwleo/oh-no-harness/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

**English** | [한국어](README.ko.md)

Your coding agent does not need another runtime. It needs a workflow it can actually read and follow.

**Oh No Harness** is that workflow for **Claude Code**, **Codex**, and **OpenCode**: **10 workflow skills** plus **9 role agents** that move vague work from `interview` to `ralplan` to verified `ralph` execution, with `fusion-rescue` for hard stalled problems, without a daemon, global CLI, MCP, or a terminal-only control plane.

It sits between two extremes:

- Not an `oh-my-*` runtime asking for a corner of your terminal.
- Not a bare skill drawer where every phase feels like one more thing to pick.

It is a text-native workflow harness: stage skills coordinate the handoffs; role agents handle focused passes for exploration, planning, execution, review, security, QA, and verification.

- No `npm install -g` runtime
- One `npx` setup command; no runtime CLI
- No tmux window to keep alive
- No custom CLI muscle memory
- No MCP server to wire up before the work can start
- No terminal-only workflow that falls apart in app or plugin UIs

The runtime is deliberately boring: **text files your agent can read** —
platform skill wrappers in `skills/`, `skills-claude/`, and `skills-opencode/`, shared workflow core
in `docs/skill-core/`, maintenance-only company prompt references in
`docs/providers/`, generated agent/command definitions, thin host adapters, and
compact native hook entrypoints.

> [!NOTE]
> If you can read Markdown, you can audit the harness. If you can follow a handoff, you can understand the workflow.

Ten focused workflows help clarify vague work, plan, execute with verification, rescue hard stalled problems, debug, and clean up — without a daemon, background service, or hidden state.

Oh No Harness follows semantic versioning from `1.0.0`.

## Highlights

**🛠 Architecture**
- **Plain text, not a sidecar.** No global runtime, project CLI, tmux session manager, daemon, or MCP server. The behavior is Markdown plus thin host-native configuration you can read, diff, fork, and edit.
- **Native host loading.** Claude Code and Codex install through their own plugin/skill systems. OpenCode installs the public `oh-no-harness` npm plugin through its native startup package loader.
- **Terminal optional.** Shell users can install from the terminal, but the daily workflow is not terminal-bound. The same Markdown skills fit Claude Code sessions and Codex App-style plugin UIs.
- **Workflow spine.** Public skills own the software-development stages; internal agents supply the specialist judgment without becoming extra commands to memorize.
- **Skills + agents.** All three runtime sources expose the same 10 workflow skills backed by 9 role agents (`explore`, `analyst`, `planner`, `plan-reviewer`, `executor`, `debugger`, `verifier`, `code-reviewer`, `fusion-rescue-analyst`). Claude Code adds 2 human-invoked setup skills (`install-statusline`, `configure-subagents`) for 12 total; OpenCode adds its own explicit-user-only `configure-subagents` for 11; Codex remains at 10.
- **Host-native command parity.** Claude Code's `commands/*.md` mirrors its 12 skills, Codex reads the 10 wrappers in `skills/`, and OpenCode's generated 11 commands route through the `oh-no` primary to `skills-opencode/`.
- **OpenCode orchestration.** The config hook registers one `oh-no` primary carrying the static orchestration contract and nine `oh-no-<role>` subagents, disables built-in `build`/`plan`, sets the required subagent depth to 2, and preserves an unrelated custom default agent.

| Too much | Too little | Oh No Harness |
|---|---|---|
| Start a sidecar runtime | Keep picking from a loose skill shelf | Install through the native Claude Code, Codex, or OpenCode plugin surface |
| Learn a project CLI | Remember every phase by hand | Use a small stage surface: `interview`, `ralplan`, `ralph` |
| Debug hooks, HUDs, MCP, tmux | Hope one skill has enough context | Let skills hand off to role agents with explicit evidence gates |
| Stay in terminal-land | Lose structure in GUI hosts | Use the same text skills through native plugin discovery |
| Operate a platform | Collect prompts | Review the Markdown that drives the workflow |

**🔁 Workflow**
- **Socratic interview.** `/oh-no-harness:interview` routes code facts, research facts, and judgment calls separately — capturing decisions, constraints, and non-goals before any spec.
- **Mode-gated execution.** Specs and plans size work as `LIGHT` / `STANDARD` / `THOROUGH`; Ralph follows the recorded mode instead of always running the heaviest loop.
- **Fusion rescue.** `/oh-no-harness:fusion-rescue` runs exactly three panel lenses, applies configured model diversity on Claude Code, preserves the bounded Claude consult from the Codex host when available, then lets the current host synthesize the next action.
- **Auto-routing.** Destination skill descriptions own positive selection. On Claude Code, `/oh-no-harness:auto-routing on` adds before-action ordering and essential precedence rather than a central selector — no hidden state, no skipped approval gates.

**✨ Experience**
- **Plain-language input.** Just describe the task; the harness keeps handoffs explicit.
- **`/oh-no-harness:ultrawork` for end-to-end.** Opt-in single command spanning interview → plan → execute → validate.

## Install

The repository root is the Claude Code/Codex marketplace. The plugin source lives under
`plugins/oh-no-harness/`.

The npm package is an OpenCode plugin with one explicit setup command, not a global runtime CLI: there is no standalone global `oh-no` process, MCP server, setup daemon, or runtime doctor. The workflow lives inside the host, including GUI/plugin surfaces such as Codex App.

> [!TIP]
> Install the plugin where your agent already looks, describe the task so native discovery can use the skill descriptions, and turn on auto-routing in Claude Code only if you want stronger action-ordering guidance.

### Claude Code

```sh
claude plugin marketplace add jcwleo/oh-no-harness
claude plugin install oh-no-harness@oh-no-harness
```

After install, just describe the work — native discovery uses the destination skill descriptions. Optionally run `/oh-no-harness:auto-routing on` to add before-action ordering and essential precedence on the next Claude Code `SessionStart`.

**Optional — model diversity.** On Claude Code, THOROUGH review pairs and Fusion Rescue panels gain model diversity when you configure a secondary top-tier model with `/oh-no-harness:configure-subagents`. Without a valid secondary, workflows use the `same-model-parallel-fallback`; an explicit `require-model-diversity` request blocks instead of falling back.

<details>
<summary>Interactive install (inside Claude Code)</summary>

```text
/plugin marketplace add jcwleo/oh-no-harness
/plugin install oh-no-harness@oh-no-harness
```

</details>

<details>
<summary>Update later</summary>

```sh
claude plugin marketplace update oh-no-harness
claude plugin update oh-no-harness@oh-no-harness
```

</details>

### Codex

Add the marketplace:

```sh
codex plugin marketplace add jcwleo/oh-no-harness
```

Then open `/plugins` in Codex, or the Codex App plugin sidebar, select
**Oh No Harness** from the `oh-no-harness` marketplace, and install it. The
plugin appears as `oh-no-harness@oh-no-harness`.

<details>
<summary>Update later</summary>

```sh
codex plugin marketplace upgrade oh-no-harness
```

</details>

### OpenCode

Run the one-time setup command:

```sh
npx --yes oh-no-harness@latest setup
```

The installer locates the effective OpenCode global config, validates JSON or
JSONC, preserves existing settings and comments, creates a credential-safe
backup when changing an existing file, and adds `"oh-no-harness"` to the
`plugin` array exactly once. Quit any running OpenCode, start it again, then run
`/configure-subagents` to select each role's exact available model and
model-specific variant. Check registration without writing with:

```sh
npx --yes oh-no-harness@latest setup --check
```

Manual fallback:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["oh-no-harness"]
}
```

OpenCode installs npm plugins with Bun at startup and caches them under
`~/.cache/opencode/node_modules/`. Quit and restart OpenCode after installation
or an Oh No Harness version/configuration change; a new conversation does not
reload agents, commands, skills, or plugin configuration.

## Usage

Each workflow has a host-native command/skill entrypoint. In Claude Code, `commands/*.md` wrappers add autocomplete hints and load the matching namespaced skill; OpenCode's generated commands use the same bare skill names through the `oh-no` primary. Pick by what you have in hand:

| Skill | Use when |
|---|---|
| `/oh-no-harness:interview <vague task>` | Vague or requirement-light request — produces a spec with a provisional Ralph mode in `.oh-no/specs/`. |
| `/oh-no-harness:ralplan <task or spec>` | Broad, risky, or cross-file work needing a plan + approval — saved to `.oh-no/plans/`. |
| `/oh-no-harness:ralph <plan or ticket>` | Concrete task with acceptance criteria — reads the mode and executes to verification. |
| `/oh-no-harness:ultrawork <request>` | End-to-end: interview → ralplan → ralph → verification in one flow. |
| `/oh-no-harness:fusion-rescue <hard problem>` | Bounded three-panel rescue analysis for stalled problems; standalone returns recommendations, Ralph/debugging callers resume after synthesis. |
| `/oh-no-harness:test-driven-development <change>` | Explicit TDD/test-first request, or an internal gate inside Ralph/debugging execution — ordinary implementation routes through Ralph. |
| `/oh-no-harness:systematic-debugging <failure>` | Failing test, crash, or unknown root cause. |
| `/oh-no-harness:verification-before-completion` | Before claiming done / fixed / ready — demands fresh evidence. |
| `/oh-no-harness:simplify` | Post-implementation quality cleanup for reuse, simplification, efficiency, and altitude. |
| `/oh-no-harness:auto-routing on\|off\|status` | Inspect or configure host routing guidance; positive selection remains description-owned, Codex gains no forced routing, and OpenCode keeps its static primary contract. |

Not sure which to pick? Just describe the task — native host discovery selects from the destination skill descriptions. On installed Claude Code/Codex surfaces, use `/oh-no-harness:ultrawork` when you want one request to span the full flow.

### Setup commands (Claude Code only)

These two are one-time environment-setup actions, not workflow stages. They are human-invoked only (never auto-selected by the model) and ship no Codex wrapper:

| Command | Use when |
|---|---|
| `/oh-no-harness:install-statusline [check]` | Install the bundled developer statusline into `~/.claude` (`check` reports status only). |
| `/oh-no-harness:configure-subagents [check]` | Choose each installed subagent's model and reasoning effort plus the optional secondary top-tier model used for Claude-host model diversity (`check` reports status only). |

### OpenCode setup source

The OpenCode source runtime has a separate explicit-user-only
`configure-subagents` skill. After confirmation, the skill calls the
`oh_no_configure_subagents` custom tool to write exact `provider/model-id`
assignments for all nine roles to `opencode-subagent-models.conf`. The
`configure-opencode-subagents` executable is read-only and supports status
`check` only; it never writes preferences. Activation requires quitting and
restarting OpenCode. Without configured assignments, roles inherit the `oh-no`
primary model. Multiple inherited or same-role calls provide independent
contexts, not proven model diversity.

### Typical staged flow

1. You describe the work; the active host chooses `interview` when the goal is still fuzzy.
2. You approve the spec; the host agent invokes `ralplan` if implementation planning is needed.
3. You approve the plan; the host agent asks whether it should run ordinary `ralph` or end-to-end `ultrawork`. Approved Ralph handoffs are parallel-capable by default when the plan lists isolated roles.
4. `ralph` executes, verifies, reviews, and reports back. You do not need to choose internal role agents such as Planner, Plan-Reviewer, Executor, or Verifier; the host agent uses them when the selected workflow allows it.

## Auto Routing

Positive workflow selection comes from skill descriptions on every host. On Claude Code, the compact `SessionStart` bootstrap always carries global no-route, direct-edit, and object-of-analysis boundaries; auto-routing is off by default, and enabling it adds action ordering and essential precedence. Codex receives no forced-routing semantics. OpenCode's `oh-no` primary always carries its static orchestration contract; any available OpenCode preference change takes effect only after quitting and restarting the process.

```text
/oh-no-harness:auto-routing on
```

For the Claude Code command above, restart Claude Code or `/clear` after toggling. Setting persists across plugin updates.

## Privacy

- On Claude Code/Codex, the compact `SessionStart` bootstrap is the only plugin hook; there is no `UserPromptSubmit`, `PreToolUse`, or `PostToolUse` hook.
- OpenCode uses a startup config hook, not the Claude/Codex `SessionStart` hook; it registers static local source and starts no background process.
- The npm package provides a one-time setup command and a startup-loaded OpenCode plugin, not a persistent global CLI process; there is no tmux process, daemon, or MCP server.
- The runtime plugin makes **no** network calls and sends **no** telemetry; installation uses the host's normal GitHub/npm package transport.
- Reads/writes only inside the plugin dir and `~/.claude/plugins/data/<oh-no-harness-*>/` (or `~/.config/oh-no-harness/` on hosts without that layout) for persistent harness settings.
- Claude Code's `configure-subagents` (when you run it) rewrites the **installed** runtime agent Markdown under the active plugin root's `agents/` directory, and stores your durable model/effort choices, top-tier/secondary diversity settings, plus a bounded set of timestamped agent backups in the Oh No Harness data directory. Those backups retain agent bodies; **no proxy base URL or auth-token value is ever stored or printed** — CLIProxyAPI wiring is only checked for presence.
- Commands, skills, and agents are auditable Markdown or generated JSON loaded by thin host-native adapters. No daemon, no background process.

## Artifacts

Work products go under `.oh-no/`:

- `.oh-no/specs/` — interview output
- `.oh-no/plans/` — ralplan output
- `.oh-no/sessions/` — transient workflow state
- `.oh-no/worktrees/` — project-local Ralph/Ultrawork task worktrees
- `.oh-no/test-runs/` — harness test logs

## Development

Maintainers and contributors: see [CONTRIBUTING.md](CONTRIBUTING.md) for the install-from-local-checkout flow, validation steps, live smoke tests, and the release workflow.
