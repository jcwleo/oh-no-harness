# Claude Code Configure Subagents Rules

This platform overlay is source content for the generated Claude Code-facing
`configure-subagents` runtime document, after the shared core and
`docs/platforms/claude-code-runtime.md`.

The configurator edits the installed runtime agents under the active plugin
root's `agents/` directory. When `CLAUDE_PLUGIN_ROOT` is set, run the bundled
configurator directly:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/configure-subagents" check
```

If the plugin root is not exposed, locate the installed script first; the script
derives its own physical plugin root from that location, so no root path is
passed to it:

```bash
script="$(find ~/.claude/plugins -path '*/oh-no-harness/*/scripts/configure-subagents' -print -quit)"
"$script" check
```

Never apply against a Git source checkout; the configurator refuses that so the
generator-owned canonical `agents/*.md` are never rewritten with preferences.

## The `check` (status-only) branch

When the command is invoked as `/oh-no-harness:configure-subagents check` (the
`[check]` argument-hint), run **only** the read-only status check and report its
`STATUS:` line to the user, then stop. Do not start the interview and write
nothing. Its statuses are: `unconfigured`, `matching`, `drifted`,
`invalid-preferences`, `invalid-agents`, `source-checkout`, and
`recovery-required`. A `recovery-required` status means a prior run was
interrupted; re-running an `apply` (or the SessionStart `reapply`) recovers it.

Only when the command is invoked with no argument do you run the full interview
below. Every run — including the interview's first step — begins with this same
read-only `check` to confirm the plugin root and the 14 installed agent files.

## Asking The Questions

Use the host's structured question tool (`AskUserQuestion`) for every choice, one
focused question at a time.

1. First ask whether the user has **CLIProxyAPI** installed as a yes/no question.
   This answer alone decides whether GPT model aliases are offered; do not
   substitute environment auto-detection for the user's answer.
2. When the answer is `yes`, check only whether `ANTHROPIC_BASE_URL` and
   `ANTHROPIC_AUTH_TOKEN` are set (presence only, never echo their values) and
   warn if either is missing. Use a presence-only test that never prints a value:

   ```bash
   # Reports only set/missing; never expands the variable into output.
   [ -n "${ANTHROPIC_BASE_URL:-}" ] && printf 'ANTHROPIC_BASE_URL: set\n' || printf 'ANTHROPIC_BASE_URL: missing\n'
   [ -n "${ANTHROPIC_AUTH_TOKEN:-}" ] && printf 'ANTHROPIC_AUTH_TOKEN: set\n' || printf 'ANTHROPIC_AUTH_TOKEN: missing\n'
   ```
3. For each of the 14 agents in order, ask the model question:
   - Proxy `no`: offer exactly `fable`, `opus`, `sonnet`.
   - Proxy `yes`: offer `fable`, `opus`, `sonnet`, and `GPT via CLIProxyAPI`.
     When the user picks the GPT option, ask a second question offering
     `gpt-5.6-sol` and `gpt-5.6-terra`. Keeping GPT behind a follow-up keeps each
     `AskUserQuestion` within its four-option limit.
4. Then ask the effort question offering `max`, `xhigh`, `high`, `medium`.

## Applying

Collect all 14 model+effort selections, show a final summary table, and ask a
single apply-or-cancel confirmation with `AskUserQuestion`. Only after an explicit
apply, run the configurator once with the collected assignments so all 14 agents
change in one transaction. Write nothing before that confirmation.

Build the apply invocation as a Bash argument array so each `role=model,effort`
token is passed as one literal argument (never interpolated into a single string
and never through `eval`). The 14 tokens must be in the canonical role order:

```bash
args=(apply --proxy no
  explore=sonnet,high
  analyst=opus,xhigh
  planner=opus,max
  plan-reviewer=opus,xhigh
  executor=opus,high
  executor-codex=sonnet,medium
  debugger=opus,xhigh
  verifier=sonnet,high
  code-reviewer=opus,xhigh
  fusion-rescue-analyst=opus,xhigh
  plan-reviewer-codex=sonnet,medium
  code-reviewer-codex=sonnet,medium
  debugger-codex=sonnet,medium
  fusion-codex=sonnet,medium)
"$script" "${args[@]}"    # or "${CLAUDE_PLUGIN_ROOT}/scripts/configure-subagents" "${args[@]}"
```

Use `--proxy yes` instead when CLIProxyAPI was confirmed; only then may a token's
model be `gpt-5.6-sol` or `gpt-5.6-terra`. The configurator exits non-zero and
writes nothing if the tokens are incomplete, reordered, or use a model the proxy
answer does not allow.

After a successful apply, tell the user the change takes effect in the next Claude
Code session; `/clear` or a new session guarantees it. Stored preferences are
reapplied best-effort by the SessionStart hook after a plugin update, and a
`/clear` may still be needed for that repair to take effect in the current
session.
