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
SUB_PAYLOAD="$PLUGIN/scripts/subagent-statusline-command"
SKILL_WRAPPER="$PLUGIN/skills-claude/install-statusline/SKILL.md"
COMMAND_WRAPPER="$PLUGIN/commands/install-statusline.md"
CODEX_WRAPPER="$PLUGIN/skills/install-statusline/SKILL.md"
CODEX_OVERLAY="$PLUGIN/docs/platforms/codex-install-statusline.md"
SESSION_START="$PLUGIN/hooks/session-start"

# Expected settings.json command values, mirroring the installer's $HOME->~
# collapse. The install dir is $CLAUDE (a temp dir via OH_NO_CLAUDE_DIR), so
# these resolve to an absolute path unless the temp dir happens to sit in $HOME.
cmd_dir_for() { case "$CLAUDE" in "$HOME"/*) printf '~%s' "${CLAUDE#"$HOME"}" ;; "$HOME") printf '~' ;; *) printf '%s' "$CLAUDE" ;; esac; }
expected_cmd()     { printf 'bash %s/statusline-command.sh' "$(cmd_dir_for)"; }
expected_sub_cmd() { printf 'bash %s/subagent-statusline-command.sh' "$(cmd_dir_for)"; }

pass=0
fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; }

# Run the installer with a private OH_NO_CLAUDE_DIR; echoes the exit code.
run() { OH_NO_CLAUDE_DIR="$CLAUDE" "$INSTALLER" "$@"; }

setup_home() {
  WORK="$(mktemp -d)"
  CLAUDE="$WORK/.claude"
  TARGET_CMD="$(expected_cmd)"
  TARGET_SUB_CMD="$(expected_sub_cmd)"
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
  subcmd="$(jq -r '.subagentStatusLine.command' "$CLAUDE/settings.json")"
  subtyp="$(jq -r '.subagentStatusLine.type' "$CLAUDE/settings.json")"
  [ "$subcmd" = "$TARGET_SUB_CMD" ] && ok "subagentStatusLine.command set to target" || bad "subagentStatusLine.command ($subcmd)"
  [ "$subtyp" = "command" ] && ok "subagentStatusLine.type is command" || bad "subagentStatusLine.type ($subtyp)"
else
  bad "settings.json created"
fi
if cmp -s "$PAYLOAD" "$CLAUDE/statusline-command.sh"; then ok "payload copied byte-identical"; else bad "payload copied byte-identical"; fi
if cmp -s "$SUB_PAYLOAD" "$CLAUDE/subagent-statusline-command.sh"; then ok "subagent payload copied byte-identical"; else bad "subagent payload copied byte-identical"; fi
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
echo "== honors CLAUDE_CONFIG_DIR when OH_NO_CLAUDE_DIR is unset =="
WORK="$(mktemp -d)"; CFG="$WORK/custom-config"
CLAUDE_CONFIG_DIR="$CFG" "$INSTALLER" apply >/dev/null; rc=$?
[ "$rc" -eq 0 ] && ok "apply into CLAUDE_CONFIG_DIR exits 0" || bad "apply into CLAUDE_CONFIG_DIR (got $rc)"
[ -f "$CFG/settings.json" ] && ok "settings.json created in CLAUDE_CONFIG_DIR" || bad "settings.json in CLAUDE_CONFIG_DIR"
[ -f "$CFG/statusline-command.sh" ] && ok "statusline script in CLAUDE_CONFIG_DIR" || bad "statusline script in CLAUDE_CONFIG_DIR"
[ -f "$CFG/subagent-statusline-command.sh" ] && ok "subagent script in CLAUDE_CONFIG_DIR" || bad "subagent script in CLAUDE_CONFIG_DIR"
case "$CFG" in "$HOME"/*) cd_="~${CFG#"$HOME"}" ;; *) cd_="$CFG" ;; esac
exp="bash $cd_/statusline-command.sh"
[ "$(jq -r '.statusLine.command' "$CFG/settings.json")" = "$exp" ] && ok "command points at CLAUDE_CONFIG_DIR (not ~/.claude)" || bad "command points at CLAUDE_CONFIG_DIR ($(jq -r '.statusLine.command' "$CFG/settings.json"))"
rm -rf "$WORK"

# ---------------------------------------------------------------------------
echo "== upgrade: our statusLine present but subagentStatusLine missing =="
setup_home
run apply >/dev/null                                    # full install (both slots)
# simulate a pre-subagent install: drop subagentStatusLine, keep our statusLine
tmp="$(mktemp)"; jq 'del(.subagentStatusLine)' "$CLAUDE/settings.json" > "$tmp" && mv "$tmp" "$CLAUDE/settings.json"
status="$(run check | grep '^STATUS:')"
[ "$status" = "STATUS: installed-outdated" ] && ok "missing subagent slot reads outdated" || bad "check ($status)"
run apply >/dev/null; rc=$?                              # no --replace needed: our own line
[ "$rc" -eq 0 ] && ok "upgrade apply exits 0 (no --replace)" || bad "upgrade apply exits 0 (got $rc)"
[ "$(jq -r '.subagentStatusLine.command' "$CLAUDE/settings.json")" = "$TARGET_SUB_CMD" ] && ok "subagent slot added on upgrade" || bad "subagent slot added on upgrade"
if ls "$CLAUDE"/*.bak.* >/dev/null 2>&1; then bad "no backup on own-line upgrade"; else ok "no backup on own-line upgrade"; fi
teardown_home

# ---------------------------------------------------------------------------
echo "== conflict: existing different subagentStatusLine =="
setup_home
mkdir -p "$CLAUDE"
printf '%s' '{"subagentStatusLine":{"type":"command","command":"echo SUBMINE"}}' > "$CLAUDE/settings.json"
status="$(run check | grep '^STATUS:')"
[ "$status" = "STATUS: conflict" ] && ok "different subagentStatusLine reports conflict" || bad "check ($status)"
before="$(sha "$CLAUDE/settings.json")"
run apply >/dev/null 2>&1; rc=$?
[ "$rc" -eq 3 ] && ok "apply refuses subagent conflict (exit 3)" || bad "apply refuses (got $rc)"
[ "$(sha "$CLAUDE/settings.json")" = "$before" ] && ok "settings unchanged on subagent conflict" || bad "settings unchanged on subagent conflict"
teardown_home

# ---------------------------------------------------------------------------
echo "== subagent renderer: emits one JSON row per task =="
now="$(date +%s)"
render_in='{"columns":100,"tasks":[
  {"id":"t1","name":"Explore","status":"running","model":"claude-sonnet-5","tokenCount":36000,"contextWindowSize":200000,"startTime":'"$(( (now-90) * 1000 ))"',"description":"searching"},
  {"id":"t2","name":"gen","status":"completed","tokenCount":3100,"startTime":'"$(( (now-5) * 1000 ))"',"description":"no model resolved"}
]}'
out="$(printf '%s' "$render_in" | bash "$SUB_PAYLOAD")"
[ "$(printf '%s\n' "$out" | grep -c '"id"')" -eq 2 ] && ok "one JSON row per task" || bad "row count ($(printf '%s' "$out" | grep -c '"id"'))"
if printf '%s\n' "$out" | jq -e '.id and .content' >/dev/null 2>&1; then ok "each row is valid JSON with id+content"; else bad "each row is valid JSON with id+content"; fi
printf '%s\n' "$out" | grep -q 'Sonnet5' && ok "resolved model shown (Sonnet5)" || bad "resolved model shown"
printf '%s\n' "$out" | grep -q 'inherit' && ok "unresolved model falls back to inherit" || bad "unresolved model fallback"
# empty / no-task inputs must produce no output and succeed
[ -z "$(printf '' | bash "$SUB_PAYLOAD")" ] && ok "empty input yields no rows" || bad "empty input yields no rows"
[ -z "$(printf '%s' '{"columns":80,"tasks":[]}' | bash "$SUB_PAYLOAD")" ] && ok "no tasks yields no rows" || bad "no tasks yields no rows"

# ---------------------------------------------------------------------------
echo "== subagent renderer: canonical Oh No Harness role marker =="
now="$(date +%s)"
marker_in='{"columns":120,"tasks":[
  {"id":"m1","type":"local_agent","status":"running","startTime":'"$(( (now-30) * 1000 ))"',"description":"[oh-no-harness:explore] searching repo"},
  {"id":"m2","type":"local_agent","status":"running","startTime":'"$(( (now-30) * 1000 ))"',"description":"plain unmarked work"}
]}'
mout="$(printf '%s' "$marker_in" | bash "$SUB_PAYLOAD")"
# marked row (m1): canonical role in the leading slot; generic type dropped; only
# the post-marker text kept as the trailing description; raw marker stripped.
row1="$(printf '%s\n' "$mout" | jq -r 'select(.id=="m1") | .content')"
printf '%s' "$row1" | grep -q 'oh-no-harness:explore' && ok "marked row shows canonical role" || bad "marked row shows canonical role"
printf '%s' "$row1" | grep -q 'local_agent' && bad "marked row still shows local_agent" || ok "marked row drops local_agent"
printf '%s' "$row1" | grep -q '"searching repo"' && ok "marked row keeps post-marker description" || bad "marked row keeps post-marker description"
printf '%s' "$row1" | grep -Fq 'oh-no-harness:explore]' && bad "marked row leaves raw marker in description" || ok "marked row strips raw marker from description"
# unmarked row (m2): existing name/type fallback + description unchanged.
row2="$(printf '%s\n' "$mout" | jq -r 'select(.id=="m2") | .content')"
printf '%s' "$row2" | grep -q 'local_agent' && ok "unmarked row keeps type fallback" || bad "unmarked row keeps type fallback"
printf '%s' "$row2" | grep -q '"plain unmarked work"' && ok "unmarked row keeps description" || bad "unmarked row keeps description"
printf '%s' "$row2" | grep -q 'oh-no-harness:' && bad "unmarked row invents a role label" || ok "unmarked row shows no role label"

# ---------------------------------------------------------------------------
echo "== SessionStart context carries the canonical role-marker instruction =="
# Execute the Claude Code branch of the hook and assert on the instruction that
# actually reaches the model (the emitted additionalContext), not just the hook
# source. OH_NO_CONFIG_DIR points at an empty temp dir so the reapply and
# auto-routing lookups are silent no-ops that never read or mutate the real
# ~/.claude or plugin data; env -u strips any inherited host markers.
HOOK_WORK="$(mktemp -d)"
label_ctx="$(env -u CURSOR_PLUGIN_ROOT -u PLUGIN_ROOT -u COPILOT_CLI \
  CLAUDE_PLUGIN_ROOT="$HOOK_WORK/plugin" OH_NO_CONFIG_DIR="$HOOK_WORK/config" \
  bash "$SESSION_START" | jq -r '.hookSpecificOutput.additionalContext')"
label_block="$(printf '%s\n' "$label_ctx" | awk '/<OH_NO_SUBAGENT_ROLE_LABEL>/{f=1} f{print} /<\/OH_NO_SUBAGENT_ROLE_LABEL>/{f=0}')"
rm -rf "$HOOK_WORK"
printf '%s' "$label_block" | grep -Fq '[oh-no-harness:<role>]' && ok "role-marker convention documented in SessionStart" || bad "role-marker convention documented in SessionStart"
printf '%s' "$label_block" | grep -q 'description' && ok "instruction ties marker to task description" || bad "instruction ties marker to task description"
# CR-1: the instruction must be dispatch-mechanism-complete, not limited to
# Task/Agent. It must also name the Workflow agent() call and generalize to any
# equivalent Claude subagent mechanism that carries a task description.
printf '%s' "$label_block" | grep -q 'Task' && ok "instruction names the Task tool" || bad "instruction names the Task tool"
printf '%s' "$label_block" | grep -q 'Agent' && ok "instruction names the Agent tool" || bad "instruction names the Agent tool"
printf '%s' "$label_block" | grep -Fq 'agent()' && ok "instruction names the Workflow agent() call" || bad "instruction names the Workflow agent() call"
printf '%s' "$label_block" | grep -Eqi 'subagent mechanism|equivalent' && ok "instruction generalizes to equivalent subagent mechanisms" || bad "instruction generalizes to equivalent subagent mechanisms"

# ---------------------------------------------------------------------------
echo "== Claude-Code-only: no Codex artifacts =="
[ ! -e "$CODEX_WRAPPER" ] && ok "no Codex skill wrapper" || bad "no Codex skill wrapper"
[ ! -e "$CODEX_OVERLAY" ] && ok "no Codex overlay" || bad "no Codex overlay"

# ---------------------------------------------------------------------------
echo
printf 'install-statusline tests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
