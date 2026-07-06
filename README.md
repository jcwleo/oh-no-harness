# Oh No Harness

[![GitHub release](https://img.shields.io/github/v/release/jcwleo/oh-no-harness?include_prereleases&color=blue)](https://github.com/jcwleo/oh-no-harness/releases)
[![Status: Stable](https://img.shields.io/badge/status-stable-green.svg)](https://github.com/jcwleo/oh-no-harness/releases)
[![GitHub stars](https://img.shields.io/github/stars/jcwleo/oh-no-harness?style=flat&color=yellow)](https://github.com/jcwleo/oh-no-harness/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

**English** | [한국어](README.ko.md)

Your coding agent does not need another runtime. It needs a workflow it can actually read and follow.

**Oh No Harness** is that workflow for **Claude Code** and **Codex**: **11 stage skills** plus **9 role agents** that move vague work from `interview` to `ralplan` to verified `ralph` execution, with `fusion-rescue` for hard stalled problems, without npm, tmux, MCP, or a terminal-only control plane.

It sits between two extremes:

- Not an `oh-my-*` runtime asking for a corner of your terminal.
- Not a bare skill drawer where every phase feels like one more thing to pick.

It is a text-native workflow harness: stage skills coordinate the handoffs; role agents handle focused passes for exploration, planning, execution, review, security, QA, and verification.

- No `npm install -g`
- No `npx` dance
- No tmux window to keep alive
- No custom CLI muscle memory
- No MCP server to wire up before the work can start
- No terminal-only workflow that falls apart in app or plugin UIs

The runtime is deliberately boring: **text files your agent can read** —
platform skill wrappers in `skills/` and `skills-claude/`, shared workflow core
in `docs/skill-core/`, maintenance-only company prompt references in
`docs/providers/`, `agents/`, thin `commands/`, plugin manifests, and one
optional Claude Code `SessionStart` hook.

> [!NOTE]
> If you can read Markdown, you can audit the harness. If you can follow a handoff, you can understand the workflow.

Eleven focused workflows help clarify vague work, plan, execute with verification, rescue hard stalled problems, debug, and clean up — without a daemon, background service, or hidden state.

Oh No Harness follows semantic versioning from `1.0.0`.

## Highlights

**🛠 Architecture**
- **Plain text, not a sidecar.** No npm package, no project CLI, no tmux session manager, no MCP server. The behavior is Markdown you can read, diff, fork, and edit.
- **Native host install.** Claude Code and Codex load the plugin through their own plugin/skill systems; Oh No Harness does not add another thing to supervise.
- **Terminal optional.** Shell users can install from the terminal, but the daily workflow is not terminal-bound. The same Markdown skills fit Claude Code sessions and Codex App-style plugin UIs.
- **Workflow spine.** Public skills own the software-development stages; internal agents supply the specialist judgment without becoming extra commands to memorize.
- **Skills + agents.** 11 workflow skills backed by 9 role agents (`explore`, `analyst`, `planner`, `plan-reviewer`, `executor`, `debugger`, `verifier`, `code-reviewer`, `fusion-rescue-analyst`).
- **Slash ↔ skill parity.** `commands/*.md` mirrors all 11 skill names with argument hints, then delegates to the Claude Code wrapper in `skills-claude/<name>/SKILL.md`; Codex reads the matching wrapper in `skills/<name>/SKILL.md`.

| Too much | Too little | Oh No Harness |
|---|---|---|
| Start a sidecar runtime | Keep picking from a loose skill shelf | Install a native Claude Code / Codex plugin |
| Learn a project CLI | Remember every phase by hand | Use a small stage surface: `interview`, `ralplan`, `ralph` |
| Debug hooks, HUDs, MCP, tmux | Hope one skill has enough context | Let skills hand off to role agents with explicit evidence gates |
| Stay in terminal-land | Lose structure in GUI hosts | Use the same text skills through native plugin discovery |
| Operate a platform | Collect prompts | Review the Markdown that drives the workflow |

**🔁 Workflow**
- **Socratic interview.** `/oh-no-harness:interview` routes code facts, research facts, and judgment calls separately — capturing decisions, constraints, and non-goals before any spec.
- **Mode-gated execution.** Specs and plans size work as `LIGHT` / `STANDARD` / `THOROUGH`; Ralph follows the recorded mode instead of always running the heaviest loop.
- **Fusion rescue.** `/oh-no-harness:fusion-rescue` runs exactly three panel lenses, including a Codex-preferred adversarial lens when available, then lets the current host synthesize the next action.
- **Auto-routing.** `/oh-no-harness:auto-routing on` nudges Claude to consult the right skill before clarifying or editing — no hidden state, no skipped approval gates.

**✨ Experience**
- **Plain-language input.** Just describe the task; the harness keeps handoffs explicit.
- **`/oh-no-harness:ultrawork` for end-to-end.** Opt-in single command spanning interview → plan → execute → validate.

## Install

The repository root is the marketplace. The plugin source lives under
`plugins/oh-no-harness/`.

There is no `npm install`, `npx`, tmux bootstrap, standalone `oh-no` binary, MCP server, setup daemon, or runtime doctor to run. The terminal commands below are just install paths; the workflow itself lives inside the host, including GUI/plugin surfaces such as Codex App.

> [!TIP]
> Install the plugin where your agent already looks, turn on auto-routing in Claude Code if you want stronger guidance, then work inside the host.

### Claude Code

```sh
claude plugin marketplace add jcwleo/oh-no-harness
claude plugin install oh-no-harness@oh-no-harness
```

After install, run `/oh-no-harness:auto-routing on` once. Then just describe the work — Claude Code is reminded to pick the right skill before clarifying, planning, editing, or claiming completion.

**Optional — cross-host consult.** On Claude Code, cross-host review pairs and Fusion Rescue's Codex panel lens reach Codex through the companion script shipped with the Codex plugin for Claude Code. To enable them, also install that plugin and sign in to the Codex CLI:

```sh
claude plugin marketplace add openai/codex-plugin-cc
claude plugin install codex@openai-codex
```

Without it nothing blocks: those workflows automatically degrade to the Same-Host Parallel Fallback (two same-host agents, synthesized).

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

## Usage

Each workflow is a plugin-namespaced slash command. In Claude Code, `commands/*.md` wrappers add autocomplete hints, then load the matching skill. Pick by what you have in hand:

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
| `/oh-no-harness:auto-routing on\|off\|status` | Toggle stronger skill-selection guidance (Claude Code only). |
| `/oh-no-harness:using-oh-no-harness` | Top-level index — start here if you forget the others. |

Not sure which to pick? Just describe the task — the harness routes by request shape. Use `/oh-no-harness:ultrawork` when you want one request to span the full flow.

Typical staged flow:

1. You describe the work; Claude Code or Codex chooses `interview` when the goal is still fuzzy.
2. You approve the spec; the host agent invokes `ralplan` if implementation planning is needed.
3. You approve the plan; the host agent asks whether it should run ordinary `ralph` or end-to-end `ultrawork`. Approved Ralph handoffs are parallel-capable by default when the plan lists isolated roles.
4. `ralph` executes, verifies, reviews, and reports back. You do not need to choose internal role agents such as Planner, Plan-Reviewer, Executor, or Verifier; the host agent uses them when the selected workflow allows it.

## Auto Routing (Claude Code)

Off by default. Turn it on once and the `SessionStart` hook tells Claude to always consult these skills before responding, asking clarifications, or editing files:

```text
/oh-no-harness:auto-routing on
```

Restart Claude Code or `/clear` after toggling. Setting persists across plugin updates.

## Privacy

- Compact `SessionStart` guidance plus a narrow `UserPromptSubmit` Ralph adapter hook — no `PreToolUse`/`PostToolUse`.
- No npm runtime, no custom CLI process, no tmux process, no MCP server.
- **No** network calls, **no** telemetry.
- Reads/writes only inside the plugin dir and `~/.claude/plugins/data/<oh-no-harness-*>/` (or `~/.config/oh-no-harness/` on hosts without that layout) for the auto-routing flag.
- All commands, skills, and agents are plain Markdown. No daemon, no background process.

## Artifacts

Work products go under `.oh-no/`:

- `.oh-no/specs/` — interview output
- `.oh-no/plans/` — ralplan output
- `.oh-no/sessions/` — transient workflow state
- `.oh-no/worktrees/` — project-local Ralph/Ultrawork task worktrees
- `.oh-no/test-runs/` — harness test logs

## Development

Maintainers and contributors: see [CONTRIBUTING.md](CONTRIBUTING.md) for the install-from-local-checkout flow, validation steps, live smoke tests, and the release workflow.
