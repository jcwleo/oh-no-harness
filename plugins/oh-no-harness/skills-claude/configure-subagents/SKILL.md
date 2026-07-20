---
name: configure-subagents
description: User-invoked setup action that configures the model and reasoning effort of the installed Oh No Harness Claude Code subagents. Run it explicitly with the slash command; it is never auto-invoked by the model.
argument-hint: "[check]"
disable-model-invocation: true
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Configure Subagents for Claude Code

This generated file is the Claude Code-facing runtime skill document. Claude Code slash commands should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/configure-subagents.md`
- `../../docs/platforms/claude-code-runtime.md`
- `../../docs/platforms/claude-code-configure-subagents.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/configure-subagents.md

# Configure Subagents

Configure Subagents is a user-invoked setup action. It walks you through choosing
a `model` and reasoning `effort` for each of the 14 Oh No Harness Claude Code
subagents, then applies those choices to the **installed runtime** agent Markdown
so the next Claude Code session dispatches each role with your chosen model and
effort.

This skill is **human-invoke-only**. It is never auto-invoked by the model: its
frontmatter sets `disable-model-invocation: true`, and it is intentionally left
out of the SessionStart routing map. Only an explicit
`/oh-no-harness:configure-subagents` from the user runs it.

It is **Claude Code-only**: it configures Claude Code subagent frontmatter and
ships no Codex wrapper. It does not change the generator-owned canonical
`agents/*.md` in the source checkout and never touches Codex custom-agent TOMLs.

## Software Development Stage

Configure Subagents is a one-time environment-setup action, not a software
development stage. It should not gather requirements, plan, edit project code,
debug failures, clean code, or verify completion. It does not invoke workflow
skills.

## When To Use

Use only when the user explicitly asks to configure, set, or change which model
or reasoning effort the Oh No Harness subagents run with. There is no
model-driven trigger for this skill; do not use it as part of any automated
workflow.

## What Gets Configured

The bundled configurator edits the installed runtime agents under the active
plugin root's `agents/` directory (the platform runtime overlay names the
concrete `${CLAUDE_PLUGIN_ROOT}` path). For each agent it replaces the `model:`
value and inserts or replaces a single `effort:` line immediately after `model:`,
preserving every other frontmatter and body byte.

Your choices are also saved as durable, schema-versioned preferences outside the
plugin cache (in the Oh No Harness data directory), so they can be reapplied
after a plugin update restores the canonical runtime agents. **No proxy URL or
token value is ever stored or printed.**

## Status-Only Check

When the user invokes the command with the `check` argument (the `[check]`
argument-hint), run only the configurator's read-only `check`, report the
resulting `STATUS:` line, and stop — do not begin the interview and write
nothing. A `recovery-required` status means a prior apply was interrupted and is
recovered on the next `apply` or SessionStart `reapply`. Run the full interview
below only when the command is invoked with no argument.

## Interview Flow

Follow this order to the end and write no files before the final confirmation.

1. Run the bundled configurator's read-only `check` to confirm the active plugin
   root and locate the 14 installed agent files.
2. Ask first whether the user has **CLIProxyAPI** installed, as an explicit
   yes/no question. Do not let any auto-detection stand in for the user's answer.
3. When the answer is `yes`, diagnose only the *presence* of the
   `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` environment variables (never
   print their values); warn if the proxy wiring looks incomplete.
4. Configure these 14 agents one at a time, in this exact order:
   `explore`, `analyst`, `planner`, `plan-reviewer`, `executor`,
   `executor-codex`, `debugger`, `verifier`, `code-reviewer`,
   `fusion-rescue-analyst`, `plan-reviewer-codex`, `code-reviewer-codex`,
   `debugger-codex`, `fusion-codex`.
5. For each agent, decide both a model and an effort before moving to the next
   agent.
   - Model choices when proxy is `no`: `fable`, `opus`, `sonnet`.
   - Model choices when proxy is `yes`: the three native models plus
     `GPT via CLIProxyAPI`; if the user picks GPT, ask a follow-up to choose
     `gpt-5.6-sol` or `gpt-5.6-terra`. Splitting the GPT choice into a follow-up
     keeps every question within the host's 4-option limit.
   - Effort choices: `max`, `xhigh`, `high`, `medium`.
6. Summarize all 14 selections in a table and ask for a single final apply or
   cancel confirmation. No file is written before that confirmation.
7. On apply, invoke the configurator exactly once so all 14 agents change in one
   all-or-nothing transaction.

## Apply And Activation

- The configurator applies all 14 agents as one transaction: it stages and
  re-validates every result, backs up the originals, writes a recovery journal,
  and swaps each file in with an atomic rename. Any mid-transaction failure rolls
  every file back, and a stale journal from an interrupted run is recovered on
  the next invocation. Each individual rename is atomic and the whole operation
  is recoverable through the backup and journal.
- After a manual apply, a new Claude Code session (or `/clear`) is the supported
  activation boundary; report that to the user.
- After a plugin update, the SessionStart hook reapplies stored preferences
  best-effort. Because agent metadata may already be snapshotted for the current
  session, a `/clear` or one more new session may still be needed for a
  SessionStart repair to take effect.

## Safety Rules

- Collect every choice first; write nothing until the user confirms the final
  summary.
- The configurator refuses to apply inside a Git source checkout, so the
  generator-owned canonical `agents/*.md` are never changed with user
  preferences.
- GPT models are offered only after an explicit CLIProxyAPI `yes`; when the
  answer is `no`, only the native models are valid and a GPT choice is rejected
  before any write.
- Never print or store the proxy base URL or auth token.
- Do not invoke workflow skills from this setup skill.

## Source: docs/platforms/claude-code-runtime.md

# Claude Code Runtime Rules

This compact platform section is embedded in generated Claude Code-facing skill
documents.

## Skill Loading

Claude Code-facing public skills live under `skills-claude/`. Generated
`skills-claude/<skill>/SKILL.md` files compose the matching skill core, this
compact runtime section, and any Claude Code skill-specific overlay such as
`docs/platforms/claude-code-<skill>.md`. Slash commands must delegate to the
matching generated skill document.

## User Approval, Tasks, And Prompting

Use the host's structured question tool when available for approval,
preference, scope, or next-step selection; otherwise ask one focused plain-text
question and wait. Present options as actions the host agent will take.

When a core skill has a multi-phase approval handoff and the host exposes task
tracking, create one task per phase and complete them sequentially.

Keep Claude prompts explicit and sectioned: state scope, non-goals,
constraints, approval gates, expected evidence, and output format. Preserve
long-running context in artifacts before compaction, task handoff, or subagent
dispatch.

## Role Dispatch

Dispatch only after the active skill's trigger fires, then read
`docs/platforms/claude-code.md` `## Role Dispatch` for the full host contract.
Prefer `oh-no-harness:<role>`, request the whole independent batch before
waiting, capture every final result, and clean up only after integration. An
approved-plan handoff is dispatch authorization for eligible isolated roles;
plugin-agent unavailability uses the documented embedded-role fallback.

## Cross-Host Consult Channel

This channel is trigger-loaded, not embedded in every workflow decision. When a
named THOROUGH paired-review or Fusion Rescue trigger fires, read and apply
`docs/platforms/claude-code.md` `## Cross-Host Consult Channel` before dispatch.
Until then, do not preload opposite-host invocation details.

## Source: docs/platforms/claude-code-configure-subagents.md

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
script="$(find "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins" -path '*/oh-no-harness/*/scripts/configure-subagents' -print -quit)"
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
