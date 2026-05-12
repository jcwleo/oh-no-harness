# Oh No Harness

[![GitHub release](https://img.shields.io/github/v/release/jcwleo/oh-no-harness?include_prereleases&color=blue)](https://github.com/jcwleo/oh-no-harness/releases)
[![Status: Beta](https://img.shields.io/badge/status-beta-orange.svg)](https://github.com/jcwleo/oh-no-harness/releases)
[![GitHub stars](https://img.shields.io/github/stars/jcwleo/oh-no-harness?style=flat&color=yellow)](https://github.com/jcwleo/oh-no-harness/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

**English** | [한국어](README.ko.md)

A lightweight Markdown-first skill harness for **Claude Code** and **Codex**. Ten focused workflows for clarifying vague work, planning, executing with verification, debugging, and cleanup — no daemon, no hidden state.

> ⚠️ **Beta** — Skill behavior, command shapes, and config layout may change between `0.x` releases. Pin a tag (`--ref v0.2.x`) if you need stability.

## Highlights

- **Minimal external dependencies.** No tmux, no daemon, no extra CLIs. Claude Code uses a single `SessionStart` hook; Codex uses the standard skill cache. That's it.
- **Skills _plus_ specialized agents.** Ten public workflow skills own the software-development stages; 11 role agents (`explore`, `analyst`, `planner`, `architect`, `critic`, `executor`, `debugger`, `verifier`, `code-reviewer`, `security-reviewer`, `qa-tester`) supply focused analysis, execution, and review inside those skills.
- **Auto-routing adds skill-first guidance.** Flip `/auto-routing on` once and Claude Code is reminded to check the right skill before raw clarification questions or edits. It does not add hidden mode state or skip approval gates.
- **Just describe the task.** Plain natural-language input is enough to start. The harness keeps skill handoffs explicit, and `/autopilot` is the opt-in end-to-end path when you want one request to span interview, planning, execution, and validation.

## Install

The repo doubles as the plugin and the marketplace.

### Claude Code

```sh
claude plugin marketplace add jcwleo/oh-no-harness
claude plugin install oh-no-harness@oh-no-harness
```

Or interactively:

```text
/plugin marketplace add jcwleo/oh-no-harness
/plugin install oh-no-harness@oh-no-harness
```

Update later:

```sh
claude plugin marketplace update oh-no-harness
claude plugin update oh-no-harness@oh-no-harness
```

### Codex

```sh
codex plugin marketplace add jcwleo/oh-no-harness
```

Then enable it in `~/.codex/config.toml`:

```toml
[plugins."oh-no-harness@oh-no-harness"]
enabled = true
```

Pin to a tag or refresh:

```sh
codex plugin marketplace add jcwleo/oh-no-harness --ref v0.2.0
codex plugin marketplace upgrade oh-no-harness
```

## Usage

After install, invoke a skill as a slash command. Pick by what you have in hand:

| Skill | Use when |
|---|---|
| `/deep-interview <vague task>` | Request is vague or requirement-light. Produces a spec under `.oh-no/specs/`. |
| `/ralplan <task or spec>` | Broad, risky, or cross-file work that needs a plan + approval before coding. Saves to `.oh-no/plans/`. |
| `/ralph <plan or ticket>` | Concrete task with clear acceptance criteria. Executes to verification. |
| `/autopilot <request>` | End-to-end delivery: deep-interview → ralplan → ralph → verification in one flow. |
| `/test-driven-development <change>` | Any behavior-changing edit. Enforces RED/GREEN/REFACTOR. |
| `/systematic-debugging <failure>` | Failing test, crash, or unknown root cause. |
| `/verification-before-completion` | Before claiming "done"/"fixed"/"ready". Demands fresh evidence. |
| `/ai-slop-cleaner` | After implementation, before delivery. Removes throwaway artifacts. |
| `/auto-routing on\|off\|status` | Toggle stronger skill-selection guidance (Claude Code only). |
| `/using-oh-no-harness` | Top-level index — start here if you forget the others. |

Not sure which to pick? Just describe the task; the harness will guide skill selection based on the request shape while keeping workflow handoffs explicit unless you chose `/autopilot`.

## Auto Routing (Claude Code)

Off by default. Turn it on once and the `SessionStart` hook tells Claude to always consult these skills before responding, asking clarifications, or editing files:

```text
/auto-routing on
```

Restart Claude Code or `/clear` after toggling. Setting persists across plugin updates.

## Privacy

- Single `SessionStart` hook that injects skill text — no `UserPromptSubmit`/`PreToolUse`/`PostToolUse`.
- **No** network calls, **no** telemetry.
- Reads/writes only inside the plugin dir and `~/.claude/plugins/data/<oh-no-harness-*>/` (or `~/.config/oh-no-harness/` on hosts without that layout) for the auto-routing flag.
- All skills and agents are plain Markdown. No daemon, no background process.

## Artifacts

Work products go under `.oh-no/`:

- `.oh-no/specs/` — deep-interview output
- `.oh-no/plans/` — ralplan output
- `.oh-no/sessions/` — transient workflow state
- `.oh-no/test-runs/` — harness test logs

## Development

Maintainers and contributors: see [CONTRIBUTING.md](CONTRIBUTING.md) for the install-from-local-checkout flow, validation steps, live smoke tests, and the release workflow.
