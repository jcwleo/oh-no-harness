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

## Model Diversity Pair

This mechanism is trigger-loaded, not embedded in every workflow decision. For
a dispatched THOROUGH `plan-reviewer` pair, any dispatched `code-reviewer` pair
(every dispatched review),
or a named THOROUGH `debugger` pair, both legs MUST be requested in a single
batch: issue both subagent tool calls in the same assistant turn (or with
`Background: yes` for both) BEFORE waiting on either result; a serial
dispatch-wait-dispatch sequence is not a valid pair. The two legs' packet bodies
MUST be identical except the single `Assigned perspective:` line (Lens A on the
primary leg, Lens B on the diversity leg); leg identity (`primary` vs
`diversity`) is carried ONLY by the host dispatch metadata (the description field
and the model override), never inside the packet text. Read the role's concrete
stored primary and validated secondary top-tier model from the session
`<OH_NO_MODEL_DIVERSITY>` block. The primary leg is
unoverridden and uses the declared-frontmatter primary; the
secondary leg carries an explicit NATIVE model override. Claim
`model-diversity-pair` only when the primary is not `host-default` and the
secondary differs from it. Otherwise default to two independent same-model
instances as `same-model-parallel-fallback` with the reason recorded; an
explicit `require-model-diversity` demand transitions to PAUSED when the
diversity leg is unavailable. Fusion Rescue uses its Claude Code overlay's
three-panel assignment instead of this two-leg shape.

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
tab="$(printf '\t')"
plugins="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins"
reg="$plugins/installed_plugins.json"
# 1) Host-exposed plugin root wins (stays first-preferred).
script="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/scripts/configure-subagents}"
# 2) Else the authoritative installPath for the EXACT oh-no-harness@oh-no-harness
#    registry key (no jq; block-scoped so a config-home path or another plugin that
#    merely contains the substring never matches; newest version among that key's
#    scope entries). Trust only one validly closed array; truncated, compact, or
#    ambiguous input yields no candidate. installPath is a hint only, and a missing
#    or unreadable registry must not abort under strict mode: the [ -r ] guard +
#    `|| true` keep tier 3 reachable, and the [ -x ] guard lets a Windows drive-letter
#    path fall through.
if [ ! -x "$script" ] && [ -r "$reg" ]; then
  root="$(awk '
    /"oh-no-harness@oh-no-harness":[[:space:]]*\[/ {
      keys++
      if (keys != 1 || inblk || closed) { bad=1; next }
      inblk=1; next
    }
    inblk && /^[[:space:]]*\]/ { inblk=0; closed=1; next }
    inblk && /"installPath":/ {
      p=$0
      if (p !~ /"installPath":[[:space:]]*"[^"]+"/) { bad=1; next }
      sub(/.*"installPath":[[:space:]]*"/,"",p); sub(/".*/,"",p)
      v=p; sub(/.*\//,"",v); paths[++n]=p; versions[n]=v
    }
    END {
      if (keys == 1 && closed && !inblk && !bad)
        for (i=1; i<=n; i++) print versions[i] "\t" paths[i]
    }' "$reg" 2>/dev/null | LC_ALL=C sort -t"$tab" -k1,1V -k2,2 | tail -n1 | cut -f2- || true)"
  script="${root:+$root/scripts/configure-subagents}"
fi
# 3) Else the newest INSTALLED semver in the cache — never the marketplace checkout.
#    Sort on the VERSION path component (full path only as tie-break) so a second
#    marketplace identity cannot let an older version win.
if [ ! -x "$script" ]; then
  script="$(find "$plugins/cache" -path '*/oh-no-harness/*/scripts/configure-subagents' 2>/dev/null \
    | awk -F/ '{for(i=NF;i>0;i--) if($i=="scripts"){print $(i-1)"\t"$0; break}}' \
    | LC_ALL=C sort -t"$tab" -k1,1V -k2,2 | tail -n1 | cut -f2-)"
fi
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
read-only `check` to confirm the plugin root and the 9 installed agent files.

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
3. For each of the 9 agents in order, ask the model question:
   - Proxy `no`: offer exactly `fable`, `opus`, `sonnet`.
   - Proxy `yes`: offer `fable`, `opus`, `sonnet`, and `GPT via CLIProxyAPI`.
     When the user picks the GPT option, ask a second question offering the
     available GPT aliases. Keeping GPT behind a follow-up keeps each
     `AskUserQuestion` within its four-option limit.
4. Then ask the effort question offering `max`, `xhigh`, `high`, `medium`.
5. Ask for the space-separated `top_tier_models` value, proposing the native
   default `fable opus`. GPT aliases may be included only when the proxy answer
   was `yes`.
6. Ask whether to configure `secondary_top_model`. If yes, offer exactly
   `fable`, `opus`, `sonnet`, and `haiku`; do not offer GPT for this key, and
   require the selection to be present in `top_tier_models`.

## Applying

Collect all 9 model+effort selections plus the diversity settings, show a final
summary table, and ask a single apply-or-cancel confirmation with
`AskUserQuestion`. Only after an explicit apply, run the configurator once with
the collected settings so all 9 agents change in one transaction. Write nothing
before that confirmation.

Build the apply invocation as a Bash argument array so each option and
`role=model,effort` token is passed as one literal argument (never interpolated
into a single string and never through `eval`). The 9 role tokens must be in the
canonical role order:

```bash
args=(apply --proxy no
  --secondary-top-model fable
  --top-tier-models "fable opus"
  explore=sonnet,high
  analyst=opus,xhigh
  planner=opus,max
  plan-reviewer=opus,xhigh
  executor=opus,high
  debugger=opus,xhigh
  verifier=sonnet,high
  code-reviewer=opus,xhigh
  fusion-rescue-analyst=opus,xhigh)
"$script" "${args[@]}"    # or "${CLAUDE_PLUGIN_ROOT}/scripts/configure-subagents" "${args[@]}"
```

Omit `--secondary-top-model` when the user chooses no secondary. Use
`--proxy yes` when CLIProxyAPI was confirmed; only then may a per-role primary or
a `top_tier_models` entry use one of the GPT aliases offered by the wizard. The
configurator exits non-zero and writes nothing if the role tokens are incomplete
or reordered, if a model is not allowed by the proxy answer, or if the secondary
is not native and present in the top-tier list.

After a successful apply, tell the user the change takes effect in the next Claude
Code session; `/clear` or a new session guarantees it. Stored preferences are
reapplied best-effort by the SessionStart hook after a plugin update, and a
`/clear` may still be needed for that repair to take effect in the current
session.
