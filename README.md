# Oh No Harness

`oh-no-harness` is a lightweight skill harness for Claude Code and Codex.

It combines Superpowers' simple bootstrap/plugin shape with a focused subset of OMC-derived workflows:

- `using-oh-no-harness`
- `deep-interview`
- `ralplan`
- `ralph`
- `autopilot`
- `auto-routing`
- `test-driven-development`
- `ai-slop-cleaner`
- `verification-before-completion`
- `systematic-debugging`

The harness intentionally does not port OMC's keyword detector, persistent-mode Stop hook, PreToolUse/PostToolUse bridge, mode state ledger, or unsupported workflow skills.

## Runtime Model

Claude Code receives one `SessionStart` bootstrap injection from `hooks/session-start`.
Public skills are also listed explicitly in `.claude-plugin/plugin.json` so Claude Code can index skill frontmatter such as `argument-hint` for slash-menu autocomplete.

The default bootstrap tells the agent to check relevant Oh No Harness skills before clarification questions. Vague or requirement-light work should route through `deep-interview` before the agent asks raw follow-up questions.

Claude Code users can enable stronger Superpowers-style skill-selection guidance with `auto-routing`. The setting is stored outside the plugin cache, so it persists across plugin updates.

Codex discovers skills through `.codex-plugin/plugin.json` and uses native skill loading.

All workflow routing is written inside Markdown skill files. There is no hidden skill orchestration runtime.

## Auto Routing

Auto-routing is off by default. Users who want stronger skill-selection guidance can toggle it:

```text
/auto-routing on
/auto-routing off
/auto-routing status
```

When enabled, the Claude Code `SessionStart` hook appends an `OH_NO_AUTO_ROUTING` policy that tells the agent to check local skills before responding, asking clarification questions, inspecting files, editing files, or claiming completion. The setting is stored in Claude Code plugin data or the user config fallback, not in the plugin cache.

After changing the setting, restart Claude Code or run `/clear`; existing session context is not rewritten.

## Claude Code Test

Run the local plugin install/update and structural test suite:

```bash
scripts/test-claude-plugin.sh
```

The script adds the local marketplace when needed, installs `oh-no-harness@oh-no-harness-dev` when missing, or updates the installed plugin when present. By default it uses the existing installed scope if found; otherwise it installs in `local` scope.

Live Claude Code skill smoke tests spend model budget, so they are explicit:

```bash
scripts/test-claude-plugin.sh --live
```

To check only that Claude Code actually runs the `SessionStart` hook, receives the Claude-only question policy, and changes behavior between auto-routing off/on:

```bash
scripts/test-claude-plugin.sh --live-hook-only --live-load installed
```

To verify that linked internal skill docs are actually read during execution:

```bash
scripts/test-claude-plugin.sh --deep-live
```

Useful overrides:

```bash
scripts/test-claude-plugin.sh --scope user --live-load installed --live
OH_NO_TEST_MODEL=sonnet OH_NO_MAX_BUDGET_USD=0.50 scripts/test-claude-plugin.sh --live
```

## Codex Test

Run the local Codex plugin install/update and prompt exposure test:

```bash
scripts/test-codex-plugin.sh
```

The script syncs the plugin into Codex's enabled plugin cache, enables `oh-no-harness@oh-no-harness-dev` in `$CODEX_HOME/config.toml`, and verifies that `codex debug prompt-input` exposes all public Oh No Harness skills. It also checks that Claude-only hook instructions do not leak into Codex.

Live Codex skill smoke tests spend model budget, so they are explicit:

```bash
scripts/test-codex-plugin.sh --live
```

To verify that linked internal skill docs are actually read during execution:

```bash
scripts/test-codex-plugin.sh --deep-live
```

Useful overrides:

```bash
scripts/test-codex-plugin.sh --codex-home /tmp/oh-no-codex-home
OH_NO_CODEX_TEST_MODEL=gpt-5.4-mini scripts/test-codex-plugin.sh --live
```

## Runtime Behavior and Privacy

Oh No Harness is a Markdown-only skill harness. At runtime it:

- Registers a single `SessionStart` hook (`hooks/session-start`) that emits an `additionalContext` JSON blob containing the `using-oh-no-harness` skill text and, if the user has run `/auto-routing on`, an additional routing policy. The hook does nothing else.
- Does **not** register `UserPromptSubmit`, `PreToolUse`, or `PostToolUse` hooks.
- Makes **no** network calls. The hook only reads bundled skill files and the per-user config file written by `/auto-routing`.
- Collects **no** telemetry. No usage data leaves the user's machine.
- Reads and writes only inside the plugin directory and `${CLAUDE_PLUGIN_DATA}` / `${HOME}/.config/oh-no-harness/` for the auto-routing setting.

All skills and agents are plain Markdown with frontmatter; there is no daemon, background process, or hidden orchestrator.

## Artifacts

Specs and plans produced by Oh No Harness should go under `.oh-no/`:

- `.oh-no/specs/` for deep-interview specs.
- `.oh-no/plans/` for ralplan implementation plans.
- `.oh-no/sessions/` for transient workflow state.
- `.oh-no/test-runs/` for harness test outputs.

Do not write `.omc/` paths from this harness.
