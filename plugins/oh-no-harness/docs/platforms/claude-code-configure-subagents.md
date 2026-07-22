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
