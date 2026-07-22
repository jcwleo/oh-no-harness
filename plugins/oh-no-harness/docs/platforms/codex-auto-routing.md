# Codex Auto Routing Rules

This platform overlay is source content for the generated Codex-facing
`auto-routing` runtime document, after the shared core and
`docs/platforms/codex-runtime.md`.

Codex native skill loading remains the primary routing surface. The
`auto-routing` skill can preserve the config file shape and explain the
preference, but it does not add forced routing to Codex SessionStart.

If a Codex-facing SessionStart hook runs, it must stay compact and must not
embed full skill core bodies.

Resolve the installed config script before running `status`, `on`, or `off`:

```bash
tab="$(printf '\t')"
cache="${CODEX_HOME:-$HOME/.codex}/plugins/cache"
# Codex exposes no skill-visible plugin root, so cache-newest is the only reachable
# path. Sort on the VERSION path component (full path only as tie-break) so a second
# marketplace identity cannot let an older version win.
script="$(find "$cache" -path '*/oh-no-harness/*/scripts/oh-no-config' 2>/dev/null \
  | awk -F/ '{for(i=NF;i>0;i--) if($i=="scripts"){print $(i-1)"\t"$0; break}}' \
  | LC_ALL=C sort -t"$tab" -k1,1V -k2,2 | tail -n1 | cut -f2-)"
"$script" status
```
