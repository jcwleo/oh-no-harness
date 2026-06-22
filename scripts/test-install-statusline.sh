#!/usr/bin/env bash
# Behavior + contract tests for the install-statusline skill and installer.
#
# Runs entirely against temp directories (OH_NO_CLAUDE_DIR); it NEVER reads or
# writes the developer's real ~/.claude. Run from anywhere:
#   bash scripts/test-install-statusline.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$ROOT/plugins/oh-no-harness"
INSTALLER="$PLUGIN/scripts/install-statusline"
PAYLOAD="$PLUGIN/scripts/statusline-command"
SKILL_WRAPPER="$PLUGIN/skills-claude/install-statusline/SKILL.md"
COMMAND_WRAPPER="$PLUGIN/commands/install-statusline.md"
CODEX_WRAPPER="$PLUGIN/skills/install-statusline/SKILL.md"
CODEX_OVERLAY="$PLUGIN/docs/platforms/codex-install-statusline.md"
SESSION_START="$PLUGIN/hooks/session-start"
TARGET_CMD="bash ~/.claude/statusline-command.sh"

pass=0
fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; }

# Run the installer with a private OH_NO_CLAUDE_DIR; echoes the exit code.
run() { OH_NO_CLAUDE_DIR="$CLAUDE" "$INSTALLER" "$@"; }

setup_home() {
  WORK="$(mktemp -d)"
  CLAUDE="$WORK/.claude"
}
teardown_home() { rm -rf "$WORK"; }

sha() { shasum "$1" | awk '{print $1}'; }

# ---------------------------------------------------------------------------
echo "== fresh install =="
setup_home
out="$(run apply)"; rc=$?
[ "$rc" -eq 0 ] && ok "fresh apply exits 0" || bad "fresh apply exits 0 (got $rc)"
if [ -f "$CLAUDE/settings.json" ]; then
  cmd="$(jq -r '.statusLine.command' "$CLAUDE/settings.json")"
  ri="$(jq -r '.statusLine.refreshInterval' "$CLAUDE/settings.json")"
  typ="$(jq -r '.statusLine.type' "$CLAUDE/settings.json")"
  [ "$cmd" = "$TARGET_CMD" ] && ok "statusLine.command set to target" || bad "statusLine.command ($cmd)"
  [ "$ri" = "3" ] && ok "refreshInterval is 3" || bad "refreshInterval ($ri)"
  [ "$typ" = "command" ] && ok "statusLine.type is command" || bad "statusLine.type ($typ)"
else
  bad "settings.json created"
fi
if cmp -s "$PAYLOAD" "$CLAUDE/statusline-command.sh"; then ok "payload copied byte-identical"; else bad "payload copied byte-identical"; fi
teardown_home

# ---------------------------------------------------------------------------
echo "== preserves other settings keys (no clobber) =="
setup_home
mkdir -p "$CLAUDE"
printf '%s' '{"theme":"dark","env":{"A":"1"},"language":"한국어"}' > "$CLAUDE/settings.json"
run apply >/dev/null; rc=$?
[ "$rc" -eq 0 ] && ok "apply over existing keys exits 0" || bad "apply exits 0 (got $rc)"
[ "$(jq -r '.theme' "$CLAUDE/settings.json")" = "dark" ] && ok "theme preserved" || bad "theme preserved"
[ "$(jq -r '.env.A' "$CLAUDE/settings.json")" = "1" ] && ok "env.A preserved" || bad "env.A preserved"
[ "$(jq -r '.language' "$CLAUDE/settings.json")" = "한국어" ] && ok "language preserved" || bad "language preserved"
[ "$(jq -r '.statusLine.refreshInterval' "$CLAUDE/settings.json")" = "3" ] && ok "statusLine added" || bad "statusLine added"
teardown_home

# ---------------------------------------------------------------------------
echo "== idempotency (already installed-matching) =="
setup_home
run apply >/dev/null
status="$(run check | grep '^STATUS:')"
[ "$status" = "STATUS: installed-matching" ] && ok "second check is installed-matching" || bad "check ($status)"
run apply | grep -q 'no changes made' && ok "re-apply makes no changes" || bad "re-apply makes no changes"
if ls "$CLAUDE"/*.bak.* >/dev/null 2>&1; then bad "no backup on idempotent re-apply"; else ok "no backup on idempotent re-apply"; fi
teardown_home

# ---------------------------------------------------------------------------
echo "== conflict: existing different statusLine =="
setup_home
mkdir -p "$CLAUDE"
printf '%s' '{"statusLine":{"type":"command","command":"echo MINE"},"theme":"x"}' > "$CLAUDE/settings.json"
status="$(run check | grep '^STATUS:')"
[ "$status" = "STATUS: conflict" ] && ok "check reports conflict" || bad "check ($status)"
before="$(sha "$CLAUDE/settings.json")"
run apply >/dev/null 2>&1; rc=$?
[ "$rc" -eq 3 ] && ok "apply without --replace refuses (exit 3)" || bad "apply refuses exit 3 (got $rc)"
[ "$(sha "$CLAUDE/settings.json")" = "$before" ] && ok "settings unchanged on refused apply" || bad "settings unchanged on refused apply"
run apply --replace >/dev/null; rc=$?
[ "$rc" -eq 0 ] && ok "apply --replace exits 0" || bad "apply --replace exits 0 (got $rc)"
ls "$CLAUDE"/settings.json.bak.* >/dev/null 2>&1 && ok "settings.json backed up on replace" || bad "settings.json backed up on replace"
[ "$(jq -r '.statusLine.command' "$CLAUDE/settings.json")" = "$TARGET_CMD" ] && ok "statusLine replaced with target" || bad "statusLine replaced"
[ "$(jq -r '.theme' "$CLAUDE/settings.json")" = "x" ] && ok "other key preserved through replace" || bad "other key preserved through replace"
teardown_home

# ---------------------------------------------------------------------------
echo "== invalid JSON settings.json =="
setup_home
mkdir -p "$CLAUDE"
printf '%s' 'not json {{{' > "$CLAUDE/settings.json"
before="$(sha "$CLAUDE/settings.json")"
run apply >/dev/null 2>&1; rc=$?
[ "$rc" -eq 6 ] && ok "apply refuses on invalid JSON (exit 6)" || bad "apply refuses on invalid JSON (got $rc)"
[ "$(sha "$CLAUDE/settings.json")" = "$before" ] && ok "invalid settings.json byte-unchanged" || bad "invalid settings.json byte-unchanged"
teardown_home

# ---------------------------------------------------------------------------
echo "== jq absent (single pinned behavior: refuse, exit 4, unchanged) =="
setup_home
mkdir -p "$CLAUDE"
printf '%s' '{"theme":"x"}' > "$CLAUDE/settings.json"
before="$(sha "$CLAUDE/settings.json")"
# Build a minimal PATH containing required tools EXCEPT jq.
NOBIN="$WORK/bin"; mkdir -p "$NOBIN"
for t in bash sh dirname cp chmod mktemp mv rm cmp date mkdir awk grep; do
  p="$(command -v "$t" 2>/dev/null)" && ln -s "$p" "$NOBIN/$t"
done
PATH="$NOBIN" OH_NO_CLAUDE_DIR="$CLAUDE" "$INSTALLER" apply >/dev/null 2>&1; rc=$?
[ "$rc" -eq 4 ] && ok "apply refuses without jq (exit 4)" || bad "apply refuses without jq (got $rc)"
[ "$(sha "$CLAUDE/settings.json")" = "$before" ] && ok "settings byte-unchanged without jq" || bad "settings byte-unchanged without jq"
[ ! -e "$CLAUDE/statusline-command.sh" ] && ok "no script written without jq" || bad "no script written without jq"
teardown_home

# ---------------------------------------------------------------------------
echo "== hard guarantee: model can never auto-invoke (static contract) =="
grep -q '^disable-model-invocation: true$' "$SKILL_WRAPPER" && ok "SKILL.md sets disable-model-invocation: true" || bad "SKILL.md flag"
grep -q '^disable-model-invocation: true$' "$COMMAND_WRAPPER" && ok "command wrapper sets disable-model-invocation: true" || bad "command wrapper flag"

forced_block="$(awk '/<OH_NO_FORCED_ROUTING>/{f=1} f{print} /<\/OH_NO_FORCED_ROUTING>/{f=0}' "$SESSION_START")"
bootstrap_block="$(awk '/<OH_NO_BOOTSTRAP>/{f=1} f{print} /<\/OH_NO_BOOTSTRAP>/{f=0}' "$SESSION_START")"
printf '%s' "$forced_block" | grep -q 'install-statusline' && bad "absent from FORCED_ROUTING block" || ok "absent from FORCED_ROUTING block"
printf '%s' "$bootstrap_block" | grep -q 'install-statusline' && bad "absent from BOOTSTRAP block" || ok "absent from BOOTSTRAP block"

# ---------------------------------------------------------------------------
echo "== Claude-Code-only: no Codex artifacts =="
[ ! -e "$CODEX_WRAPPER" ] && ok "no Codex skill wrapper" || bad "no Codex skill wrapper"
[ ! -e "$CODEX_OVERLAY" ] && ok "no Codex overlay" || bad "no Codex overlay"

# ---------------------------------------------------------------------------
echo
printf 'install-statusline tests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
