# Claude Code Auto Routing Rules

This platform overlay is source content for the generated Claude Code-facing
`auto-routing` runtime document, after the shared core and
`docs/platforms/claude-code-runtime.md`.

Preferred config location:

```text
${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/data/<oh-no-harness-*>/config.json
```

When `CLAUDE_PLUGIN_ROOT` is set, use:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" status
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" on
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" off
```

If the plugin root is not exposed, resolve the installed script first:

```bash
tab="$(printf '\t')"
plugins="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins"
reg="$plugins/installed_plugins.json"
# 1) Host-exposed plugin root wins (stays first-preferred).
script="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/scripts/oh-no-config}"
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
  script="${root:+$root/scripts/oh-no-config}"
fi
# 3) Else the newest INSTALLED semver in the cache — never the marketplace checkout.
#    Sort on the VERSION path component (full path only as tie-break) so a second
#    marketplace identity cannot let an older version win.
if [ ! -x "$script" ]; then
  script="$(find "$plugins/cache" -path '*/oh-no-harness/*/scripts/oh-no-config' 2>/dev/null \
    | awk -F/ '{for(i=NF;i>0;i--) if($i=="scripts"){print $(i-1)"\t"$0; break}}' \
    | LC_ALL=C sort -t"$tab" -k1,1V -k2,2 | tail -n1 | cut -f2-)"
fi
"$script" status
```

On Claude Code, native skill descriptions select the destination. When the
stored preference is enabled, Claude-only action ordering and essential
precedence guidance applies from the next `SessionStart`; the clear/reset
command is `/clear`.
