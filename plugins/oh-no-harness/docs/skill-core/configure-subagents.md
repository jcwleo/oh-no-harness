---
name: configure-subagents
description: User-invoked setup action that configures the model and reasoning effort of the installed Oh No Harness Claude Code subagents. Run it explicitly with the slash command; it is never auto-invoked by the model.
argument-hint: "[check]"
disable-model-invocation: true
---

# Configure Subagents

Configure Subagents is a user-invoked setup action. It walks you through choosing
a `model` and reasoning `effort` for each of the 9 Oh No Harness Claude Code
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
after a plugin update restores the canonical runtime agents. The same preferences
store `top_tier_models`, the machine's top-tier model set, and the optional
native-only `secondary_top_model` used as the diversity leg for paired reviews
and fusion. **No proxy URL or token value is ever stored or printed.**

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
   root and locate the 9 installed agent files.
2. Ask first whether the user has **CLIProxyAPI** installed, as an explicit
   yes/no question. Do not let any auto-detection stand in for the user's answer.
3. When the answer is `yes`, diagnose only the *presence* of the
   `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` environment variables (never
   print their values); warn if the proxy wiring looks incomplete.
4. Configure these 9 agents one at a time, in this exact order:
   `explore`, `analyst`, `planner`, `plan-reviewer`, `executor`, `debugger`,
   `verifier`, `code-reviewer`, `fusion-rescue-analyst`.
5. For each agent, decide both a model and an effort before moving to the next
   agent.
   - Model choices when proxy is `no`: `fable`, `opus`, `sonnet`.
   - Model choices when proxy is `yes`: the three native models plus
     `GPT via CLIProxyAPI`; if the user picks GPT, ask a follow-up to choose an
     available GPT model alias. Splitting the GPT choice into a follow-up keeps
     every question within the host's 4-option limit.
   - Effort choices: `max`, `xhigh`, `high`, `medium`.
6. Ask for `top_tier_models`, the space-separated models that count as top tier
   on this machine. Propose the native default `fable opus`; when proxy is `yes`,
   the user may also include GPT aliases offered by the per-role primary-model
   flow.
7. Ask whether to set `secondary_top_model`, the diversity model for paired
   reviews and fusion. If yes, offer only the native aliases `fable`, `opus`,
   `sonnet`, and `haiku` — never GPT — and require the selection to be present in
   `top_tier_models`.
8. Summarize all 9 model+effort selections and both diversity settings, then ask
   for a single final apply or cancel confirmation. No file is written before
   that confirmation.
9. On apply, invoke the configurator exactly once so all 9 agents and the
   diversity settings change in one all-or-nothing transaction.

## Apply And Activation

- The configurator applies all 9 agents as one transaction: it stages and
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
- GPT primary models are offered only after an explicit CLIProxyAPI `yes`; when
  the answer is `no`, only native primary models are valid and a GPT choice is
  rejected before any write. `secondary_top_model` is always native-only,
  regardless of the proxy answer.
- Never print or store the proxy base URL or auth token.
- Do not invoke workflow skills from this setup skill.
