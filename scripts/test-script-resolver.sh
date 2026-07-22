#!/usr/bin/env bash
# Behavioral and content contracts for bundled-script resolution.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$ROOT/plugins/oh-no-harness"
PYTHON="$(command -v python3)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; }

extract_block() {
  "$PYTHON" - "$1" "$2" <<'PY'
import sys
path, sentinel = sys.argv[1:]
lines = open(path, encoding="utf-8").read().splitlines()
blocks = []
in_bash = False
current = []
for line in lines:
    if not in_bash and line == "```bash":
        in_bash = True
        current = []
    elif in_bash and line == "```":
        blocks.append("\n".join(current))
        in_bash = False
    elif in_bash:
        current.append(line)
for block in blocks:
    if sentinel in block:
        print(block)
        raise SystemExit(0)
raise SystemExit(1)
PY
}

make_marker() {
  local path="$1" marker="$2"
  mkdir -p "$(dirname "$path")"
  printf '#!/usr/bin/env bash\nprintf '\''%%s\\n'\'' '\''%s'\''\n' "$marker" >"$path"
  chmod +x "$path"
}

run_claude_resolver() {
  local file="$1" name="$2" label="$3"
  local base="$WORK/claude-$name"
  local plugins="$base/plugins"
  local stale="$plugins/cache/oh-no-harness/oh-no-harness/1.6.2"
  local latest="$plugins/cache/oh-no-harness/oh-no-harness/1.7.2"
  local other="$plugins/cache/zzz-market/oh-no-harness/1.0.0"
  local checkout="$plugins/marketplaces/oh-no-harness/plugins/oh-no-harness"
  local block output rc

  make_marker "$stale/scripts/$name" STALE
  make_marker "$latest/scripts/$name" LATEST
  make_marker "$other/scripts/$name" OTHER-MP
  make_marker "$checkout/scripts/$name" CHECKOUT
  cat >"$plugins/installed_plugins.json" <<JSON
{
  "plugins": {
    "decoy@other": [
      { "installPath": "$other" }
    ],
    "oh-no-harness@oh-no-harness": [
      { "scope": "project", "installPath": "$stale" },
      { "scope": "user", "installPath": "$latest" }
    ]
  }
}
JSON

  if ! block="$(extract_block "$file" '"oh-no-harness@oh-no-harness"')"; then
    bad "$label exposes the shipping Claude resolver block"
    return
  fi
  output="$(CLAUDE_CONFIG_DIR="$base" HOME="$base/home" bash -euo pipefail -c 'unset CLAUDE_PLUGIN_ROOT; eval "$1"' _ "$block" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && [ "$output" = LATEST ] \
    && ok "$label exact-key registry selects newest scope entry" \
    || bad "$label registry resolver (rc=$rc output=$output)"

  cat >"$plugins/installed_plugins.json" <<JSON
{
  "plugins": {
    "oh-no-harness@oh-no-harness": [
      { "scope": "project", "installPath": "$stale" }
JSON
  output="$(CLAUDE_CONFIG_DIR="$base" HOME="$base/home" bash -euo pipefail -c 'unset CLAUDE_PLUGIN_ROOT; eval "$1"' _ "$block" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && [ "$output" = LATEST ] \
    && ok "$label truncated registry fails closed to latest cache" \
    || bad "$label truncated registry selected stale/aborted (rc=$rc output=$output)"

  printf '{"plugins":{"oh-no-harness@oh-no-harness":[{"scope":"project","installPath":"%s"}]}}\n' \
    "$stale" >"$plugins/installed_plugins.json"
  output="$(CLAUDE_CONFIG_DIR="$base" HOME="$base/home" bash -euo pipefail -c 'unset CLAUDE_PLUGIN_ROOT; eval "$1"' _ "$block" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && [ "$output" = LATEST ] \
    && ok "$label compact registry never selects stale path" \
    || bad "$label compact registry selected stale/aborted (rc=$rc output=$output)"

  rm -f "$plugins/installed_plugins.json"
  output="$(CLAUDE_CONFIG_DIR="$base" HOME="$base/home" bash -euo pipefail -c 'unset CLAUDE_PLUGIN_ROOT; eval "$1"' _ "$block" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && [ "$output" = LATEST ] \
    && ok "$label missing registry reaches version-field cache fallback" \
    || bad "$label missing-registry fallback (rc=$rc output=$output)"
}

run_codex_resolver() {
  local file="$1" name="$2" label="$3"
  local base="$WORK/codex-$name-$label"
  local cache="$base/plugins/cache"
  local latest="$cache/aaa-market/oh-no-harness/9.9.9"
  local older="$cache/zzz-market/oh-no-harness/1.0.0"
  local block output rc

  make_marker "$latest/scripts/$name" LATEST
  make_marker "$older/scripts/$name" OTHER-MP
  if ! block="$(extract_block "$file" 'cache-newest is the only reachable')"; then
    bad "$label exposes the shipping Codex resolver block"
    return
  fi
  output="$(CODEX_HOME="$base" HOME="$base/home" bash -euo pipefail -c 'eval "$1"' _ "$block" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && [ "$output" = LATEST ] \
    && ok "$label selects newest version across marketplaces" \
    || bad "$label Codex resolver (rc=$rc output=$output)"
}

printf '== shipping Claude resolver behavior ==\n'
run_claude_resolver "$PLUGIN/docs/platforms/claude-code-auto-routing.md" oh-no-config "Claude auto-routing"
run_claude_resolver "$PLUGIN/docs/platforms/claude-code-configure-subagents.md" configure-subagents "Claude configure-subagents"
run_claude_resolver "$PLUGIN/docs/platforms/claude-code-install-statusline.md" install-statusline "Claude install-statusline"

printf '== shipping Codex resolver behavior ==\n'
run_codex_resolver "$PLUGIN/docs/platforms/codex-auto-routing.md" oh-no-config "Codex auto-routing"
run_codex_resolver "$PLUGIN/docs/platforms/codex-ralph.md" install-codex-agents "Codex Ralph"
run_codex_resolver "$PLUGIN/docs/platforms/codex.md" install-codex-agents "Codex platform reference"

printf '== oh-no-config active install identity ==\n'
config_home="$WORK/config-home"
data="$config_home/plugins/data"
mkdir -p "$data/oh-no-harness-inline" "$data/oh-no-harness-oh-no-harness" "$data/oh-no-harness-zzz"
cache_script="$config_home/plugins/cache/oh-no-harness/oh-no-harness/9.9.9/scripts/oh-no-config"
named_script="$config_home/plugins/cache/zzz/oh-no-harness/9.9.9/scripts/oh-no-config"
inline_script="$WORK/checkout/scripts/oh-no-config"
for dest in "$cache_script" "$named_script" "$inline_script"; do
  mkdir -p "$(dirname "$dest")"
  cp "$PLUGIN/scripts/oh-no-config" "$dest"
  chmod +x "$dest"
done
path="$(CLAUDE_CONFIG_DIR="$config_home" HOME="$WORK/home" "$cache_script" path)"
[ "$path" = "$data/oh-no-harness-oh-no-harness/config.json" ] \
  && ok "cache install selects its active marketplace data identity" \
  || bad "cache install selected $path"
path="$(CLAUDE_CONFIG_DIR="$config_home" HOME="$WORK/home" "$named_script" path)"
[ "$path" = "$data/oh-no-harness-zzz/config.json" ] \
  && ok "named cache install selects its active marketplace data identity" \
  || bad "named cache install selected $path"
path="$(CLAUDE_CONFIG_DIR="$config_home" HOME="$WORK/home" "$inline_script" path)"
[ "$path" = "$data/oh-no-harness-inline/config.json" ] \
  && ok "inline install keeps deterministic lexically-first fallback" \
  || bad "inline install selected $path"

printf '== resolver content contracts ==\n'
claude_files=(
  "$PLUGIN/docs/platforms/claude-code-auto-routing.md"
  "$PLUGIN/docs/platforms/claude-code-configure-subagents.md"
  "$PLUGIN/docs/platforms/claude-code-install-statusline.md"
)
claude_names=(oh-no-config configure-subagents install-statusline)
for i in 0 1 2; do
  file="${claude_files[$i]}"; name="${claude_names[$i]}"
  grep -q -- '-print -quit' "$file" && bad "$name removed -print -quit" || ok "$name removed -print -quit"
  grep -Fq 'find "$plugins/cache"' "$file" && ok "$name fallback scans plugins/cache" || bad "$name fallback is not cache-scoped"
  grep -Fq 'sort -t"$tab" -k1,1V -k2,2' "$file" && ok "$name uses version-field sort -V" || bad "$name version-field sort missing"
  grep -Fq '"oh-no-harness@oh-no-harness"' "$file" && ok "$name scopes installPath to exact registry key" || bad "$name exact registry key missing"
  direct_line="$(grep -nF '"${CLAUDE_PLUGIN_ROOT}/scripts/'"$name"'"' "$file" | head -n1 | cut -d: -f1)"
  resolver_line="$(grep -nF 'plugins="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins"' "$file" | head -n1 | cut -d: -f1)"
  [ -n "$direct_line" ] && [ -n "$resolver_line" ] && [ "$direct_line" -lt "$resolver_line" ] \
    && ok "$name keeps CLAUDE_PLUGIN_ROOT invocation first" \
    || bad "$name CLAUDE_PLUGIN_ROOT-first ordering"
done
core="$PLUGIN/docs/skill-core/auto-routing.md"
grep -q -- '-print -quit' "$core" && bad "shared auto-routing core removed concrete first-match selector" || ok "shared auto-routing core removed concrete first-match selector"
grep -Fq "active platform runtime document's script-locator" "$core" && ok "shared auto-routing core points to platform locator" || bad "shared auto-routing locator pointer missing"
for file in "$PLUGIN/docs/platforms/codex-auto-routing.md" "$PLUGIN/docs/platforms/codex-ralph.md" "$PLUGIN/docs/platforms/codex.md"; do
  grep -Fq 'sort -t"$tab" -k1,1V -k2,2' "$file" && ok "$(basename "$file") uses version-field sort -V" || bad "$(basename "$file") version-field sort missing"
  grep -Fq 'prefer the Codex-exposed plugin root' "$file" && bad "$(basename "$file") claims a nonexistent Codex root tier" || ok "$(basename "$file") makes no nonexistent Codex root claim"
done
quiet='scripts/install-codex-agents --scope user --ensure --quiet'
for file in "$PLUGIN/docs/platforms/codex.md" "$PLUGIN/docs/platforms/codex-ralph.md" "$PLUGIN/docs/reference/relationships.md"; do
  grep -Fq "$quiet" "$file" && ok "$(basename "$file") preserves quiet ensure form" || bad "$(basename "$file") lost quiet ensure form"
done
grep -Fq 'Never apply against a Git source checkout; the configurator refuses that' "$PLUGIN/docs/platforms/claude-code-configure-subagents.md" \
  && ok "configure-subagents source-checkout refusal remains" \
  || bad "configure-subagents source-checkout refusal changed"
grep -Fq 'CLAUDE_PLUGIN_ROOT only launches the hook' "$PLUGIN/hooks/session-start" \
  && ok "SessionStart documents the dual-variable boundary" \
  || bad "SessionStart dual-variable boundary comment missing"
grep -Fq "printf ' Run %s --scope user --ensure for details.' \"\$installer_path\"" "$PLUGIN/hooks/session-start" \
  && ok "SessionStart uses the resolved installer path in its warning" \
  || bad "SessionStart warning still uses a bare installer path"

printf '\nscript resolver tests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
