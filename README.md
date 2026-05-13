# Oh No Harness

[![GitHub release](https://img.shields.io/github/v/release/jcwleo/oh-no-harness?include_prereleases&color=blue)](https://github.com/jcwleo/oh-no-harness/releases)
[![Status: Beta](https://img.shields.io/badge/status-beta-orange.svg)](https://github.com/jcwleo/oh-no-harness/releases)
[![GitHub stars](https://img.shields.io/github/stars/jcwleo/oh-no-harness?style=flat&color=yellow)](https://github.com/jcwleo/oh-no-harness/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

**English** | [한국어](README.ko.md)

A lightweight Markdown-first skill harness for **Claude Code** and **Codex**. Ten focused workflows for clarifying vague work, planning, executing with verification, debugging, and cleanup — no daemon, no hidden state.

> ⚠️ **Beta** — Skill behavior, command shapes, and config layout may change between `0.x` releases. Pin a tag (`--ref v0.2.x`) if you need stability.

## Highlights

**🛠 Architecture**
- **Minimal deps.** No tmux, no daemon — just one `SessionStart` hook (Claude Code) or the standard skill cache (Codex).
- **Skills + agents.** 10 workflow skills backed by 11 role agents (`explore`, `analyst`, `planner`, `architect`, `critic`, `executor`, `debugger`, `verifier`, `code-reviewer`, `security-reviewer`, `qa-tester`).
- **Slash ↔ skill parity.** `commands/*.md` mirrors all 10 skill names with argument hints, then delegates to `skills/<name>/SKILL.md`.

**🔁 Workflow**
- **Socratic interview.** `/oh-no-harness:interview` routes code facts, research facts, and judgment calls separately — capturing decisions, constraints, and non-goals before any spec.
- **Mode-gated execution.** Specs and plans size work as `LIGHT` / `STANDARD` / `THOROUGH`; Ralph follows the recorded mode instead of always running the heaviest loop.
- **Auto-routing.** `/oh-no-harness:auto-routing on` nudges Claude to consult the right skill before clarifying or editing — no hidden state, no skipped approval gates.

**✨ Experience**
- **Plain-language input.** Just describe the task; the harness keeps handoffs explicit.
- **`/oh-no-harness:autopilot` for end-to-end.** Opt-in single command spanning interview → plan → execute → validate.

## Install

The repository root is the marketplace. The plugin source lives under
`plugins/oh-no-harness/`.

### Claude Code

```sh
claude plugin marketplace add jcwleo/oh-no-harness
claude plugin install oh-no-harness@oh-no-harness
```

After install, run `/oh-no-harness:auto-routing on` once. Then just describe the work — Claude Code is reminded to pick the right skill before clarifying, planning, editing, or claiming completion.

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

```sh
codex plugin marketplace add jcwleo/oh-no-harness
```

Then open `/plugins`, select **Oh No Harness**, and install it. The plugin
appears as `oh-no-harness@oh-no-harness`.

Pin to a tag or refresh:

```sh
codex plugin marketplace add jcwleo/oh-no-harness --ref v0.2.0
codex plugin marketplace upgrade oh-no-harness
```

## Usage

Each workflow is a plugin-namespaced slash command. In Claude Code, `commands/*.md` wrappers add autocomplete hints, then load the matching skill. Pick by what you have in hand:

| Skill | Use when |
|---|---|
| `/oh-no-harness:interview <vague task>` | Vague or requirement-light request — produces a spec with a provisional Ralph mode in `.oh-no/specs/`. |
| `/oh-no-harness:ralplan <task or spec>` | Broad, risky, or cross-file work needing a plan + approval — saved to `.oh-no/plans/`. |
| `/oh-no-harness:ralph <plan or ticket>` | Concrete task with acceptance criteria — reads the mode and executes to verification. |
| `/oh-no-harness:autopilot <request>` | End-to-end: interview → ralplan → ralph → verification in one flow. |
| `/oh-no-harness:test-driven-development <change>` | Any behavior-changing edit — enforces RED / GREEN / REFACTOR. |
| `/oh-no-harness:systematic-debugging <failure>` | Failing test, crash, or unknown root cause. |
| `/oh-no-harness:verification-before-completion` | Before claiming done / fixed / ready — demands fresh evidence. |
| `/oh-no-harness:ai-slop-cleaner` | Post-implementation cleanup — removes throwaway artifacts. |
| `/oh-no-harness:auto-routing on\|off\|status` | Toggle stronger skill-selection guidance (Claude Code only). |
| `/oh-no-harness:using-oh-no-harness` | Top-level index — start here if you forget the others. |

Not sure which to pick? Just describe the task — the harness routes by request shape. Use `/oh-no-harness:autopilot` when you want one request to span the full flow.

## Auto Routing (Claude Code)

Off by default. Turn it on once and the `SessionStart` hook tells Claude to always consult these skills before responding, asking clarifications, or editing files:

```text
/oh-no-harness:auto-routing on
```

Restart Claude Code or `/clear` after toggling. Setting persists across plugin updates.

## Privacy

- Single `SessionStart` hook that injects skill text — no `UserPromptSubmit`/`PreToolUse`/`PostToolUse`.
- **No** network calls, **no** telemetry.
- Reads/writes only inside the plugin dir and `~/.claude/plugins/data/<oh-no-harness-*>/` (or `~/.config/oh-no-harness/` on hosts without that layout) for the auto-routing flag.
- All commands, skills, and agents are plain Markdown. No daemon, no background process.

## Artifacts

Work products go under `.oh-no/`:

- `.oh-no/specs/` — interview output
- `.oh-no/plans/` — ralplan output
- `.oh-no/sessions/` — transient workflow state
- `.oh-no/test-runs/` — harness test logs

## Development

Maintainers and contributors: see [CONTRIBUTING.md](CONTRIBUTING.md) for the install-from-local-checkout flow, validation steps, live smoke tests, and the release workflow.
