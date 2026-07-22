# Claude Code Install Statusline Rules

This platform overlay is source content for the generated Claude Code-facing
`install-statusline` runtime document, after the shared core and
`docs/platforms/claude-code-runtime.md`.

The statusline installs into the config directory this Claude Code binary reads:
`CLAUDE_CONFIG_DIR` when set, otherwise `~/.claude`. The bundled installer
resolves this itself; do not hardcode `~/.claude`.

When `CLAUDE_PLUGIN_ROOT` is set, run the bundled installer directly:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/install-statusline" check
"${CLAUDE_PLUGIN_ROOT}/scripts/install-statusline" apply
"${CLAUDE_PLUGIN_ROOT}/scripts/install-statusline" apply --replace
```

If the plugin root is not exposed, locate the installed script first:

```bash
tab="$(printf '\t')"
plugins="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins"
reg="$plugins/installed_plugins.json"
# 1) Host-exposed plugin root wins (stays first-preferred).
script="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/scripts/install-statusline}"
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
  script="${root:+$root/scripts/install-statusline}"
fi
# 3) Else the newest INSTALLED semver in the cache — never the marketplace checkout.
#    Sort on the VERSION path component (full path only as tie-break) so a second
#    marketplace identity cannot let an older version win.
if [ ! -x "$script" ]; then
  script="$(find "$plugins/cache" -path '*/oh-no-harness/*/scripts/install-statusline' 2>/dev/null \
    | awk -F/ '{for(i=NF;i>0;i--) if($i=="scripts"){print $(i-1)"\t"$0; break}}' \
    | LC_ALL=C sort -t"$tab" -k1,1V -k2,2 | tail -n1 | cut -f2-)"
fi
"$script" check
```

For the `conflict` case, ask the user with the host's structured question tool
(`AskUserQuestion`) before replacing: show the existing
`statusLine.command`, and offer "back up and replace" versus "keep existing". Only
run `apply --replace` after an explicit choice to replace.

The statusline reads Claude Code's statusLine JSON input, including `.effort.level`
for the model reasoning effort. The change takes effect on the next
`refreshInterval` tick; `/clear` or a new session guarantees it.
