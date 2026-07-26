#!/usr/bin/env bash
# Behavior + contract tests for the configure-subagents skill and its runtime
# configurator.
#
# Runs entirely against temp plugin/config roots. Every run copies the
# configurator + oh-no-config (and, for hook tests, session-start) into a temp
# plugin root and executes THAT copy, so the production root is always derived
# from the executing script's physical location — never a caller-provided path.
# It NEVER reads or writes the developer's real ~/.claude, the checked-in
# canonical agents/*.md, or any Codex custom-agent TOML. Run from anywhere:
#   bash scripts/test-configure-subagents.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$ROOT/plugins/oh-no-harness"
CONFIGURATOR="$PLUGIN/scripts/configure-subagents"
OH_NO_CONFIG_SRC="$PLUGIN/scripts/oh-no-config"
CANONICAL_AGENTS="$PLUGIN/agents"
SKILL_CORE="$PLUGIN/docs/skill-core/configure-subagents.md"
SKILL_OVERLAY="$PLUGIN/docs/platforms/claude-code-configure-subagents.md"
SKILL_WRAPPER="$PLUGIN/skills-claude/configure-subagents/SKILL.md"
COMMAND_WRAPPER="$PLUGIN/commands/configure-subagents.md"
CODEX_WRAPPER="$PLUGIN/skills/configure-subagents/SKILL.md"
CODEX_OVERLAY="$PLUGIN/docs/platforms/codex-configure-subagents.md"
SESSION_START="$PLUGIN/hooks/session-start"
PYTHON="$(command -v python3)"

# Opt in to the destructive fault-injection seams for this deterministic suite.
# Production ignores these seams unless this exact guard is set (asserted below).
export OH_NO_CONFIGURE_TEST_SEAMS=1

# Canonical 9-role order (must mirror the validator and configurator).
ROLES=(
  explore analyst planner plan-reviewer executor debugger verifier
  code-reviewer fusion-rescue-analyst
)

pass=0
fail=0
WORK=""
FIXTURE_STAGE_SURVIVED=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; }

# Native (proxy=no) 9-assignment vector, one token per role in canonical order.
native_assignments() {
  printf '%s' \
    'explore=sonnet,high analyst=opus,xhigh planner=opus,max plan-reviewer=opus,xhigh executor=opus,high debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh'
}

# Alternate native vector (different efforts) for prefs-restore checks.
alt_assignments() {
  printf '%s' \
    'explore=opus,max analyst=sonnet,high planner=sonnet,high plan-reviewer=sonnet,high executor=sonnet,high debugger=sonnet,high verifier=opus,max code-reviewer=sonnet,high fusion-rescue-analyst=sonnet,high'
}

# GPT variant: explore + analyst use CLIProxyAPI GPT aliases, rest native.
gpt_assignments() {
  printf '%s' \
    'explore=gpt-5.6-terra,medium analyst=gpt-5.6-sol,high planner=opus,max plan-reviewer=opus,xhigh executor=opus,high debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh'
}

model_for() { case "$1" in explore|verifier) printf 'sonnet' ;; *) printf 'opus' ;; esac; }
effort_for() { case "$1" in planner) printf 'max' ;; explore|executor|verifier) printf 'high' ;; *) printf 'xhigh' ;; esac; }

shared_stage_manifest() {
  local root="${TMPDIR:-/tmp}" d role complete
  for d in "$root"/*; do
    [ -d "$d" ] || continue; complete=1
    for role in "${ROLES[@]}"; do [ -f "$d/$role.md" ] || { complete=0; break; }; done
    [ "$complete" = 1 ] && printf '%s\n' "$d"
  done | LC_ALL=C sort
}
SHARED_STAGE_BASELINE="$(shared_stage_manifest)"

# Independent byte-exact oracle (Python, NOT the production awk/head/tail). Reads
# raw bytes, transforms only the frontmatter model/effort lines, and copies the
# body verbatim (preserving final-newline state and trailing bytes). Writes the
# expected file so callers compare with cmp, not command substitution.
oracle() {
  # oracle <src> <model> <effort> <dest>
  "$PYTHON" - "$1" "$2" "$3" "$4" <<'PY'
import sys
src, model, effort, dest = sys.argv[1:5]
data = open(src, "rb").read()
assert data[:4] == b"---\n", "fixture missing opening frontmatter delimiter"
close = data.find(b"\n---\n", 3)
assert close != -1, "fixture missing closing frontmatter delimiter"
fm_end = close + len(b"\n---\n")
region = data[:fm_end].decode("utf-8")
body = data[fm_end:]  # raw bytes, preserved verbatim
out = []
for i, ln in enumerate(region.split("\n")):
    if i == 0:
        out.append(ln)            # opening ---
    elif ln.startswith("model:"):
        out.append("model: " + model)
        out.append("effort: " + effort)
    elif ln.startswith("effort:"):
        continue
    else:
        out.append(ln)
open(dest, "wb").write("\n".join(out).encode("utf-8") + body)
PY
}

cleanup_fixture() {
  [ -n "${WORK:-}" ] || return 0
  local owned_work="$WORK" owned_stage="$STAGE_PARENT"
  chmod -R u+rwx "$owned_work" 2>/dev/null; rm -rf "$owned_work"
  [ ! -e "$owned_stage" ] || FIXTURE_STAGE_SURVIVED=1
  WORK=""
}
trap cleanup_fixture EXIT

setup_fixture() {
  WORK="$(cd "$(mktemp -d)" && pwd -P)"   # physical path (logical==physical)
  TARGET="$WORK/plugin-root"
  CFG="$WORK/config"
  EXP="$WORK/expected"
  STAGE_PARENT="$WORK/configure-stage"
  mkdir -p "$TARGET/agents" "$TARGET/scripts" "$TARGET/hooks" "$CFG" "$EXP" "$STAGE_PARENT"
  cp "$CONFIGURATOR" "$TARGET/scripts/configure-subagents"
  cp "$OH_NO_CONFIG_SRC" "$TARGET/scripts/oh-no-config"
  cp "$SESSION_START" "$TARGET/hooks/session-start"
  chmod +x "$TARGET/scripts/configure-subagents" "$TARGET/scripts/oh-no-config" "$TARGET/hooks/session-start"
  local role
  for role in "${ROLES[@]}"; do
    cp "$CANONICAL_AGENTS/$role.md" "$TARGET/agents/$role.md"
  done
}

setup_cache_identity_fixture() {
  setup_fixture
  CACHE_HOME="$WORK/claude-home"
  CANONICAL_DATA_ROOT="$CACHE_HOME/plugins/data/oh-no-harness-oh-no-harness"
  LEGACY_DATA_ROOT="$CACHE_HOME/plugins/data/oh-no-harness-inline"
  CACHE_TARGET="$CACHE_HOME/plugins/cache/oh-no-harness/oh-no-harness/9.9.9"
  mkdir -p "$CANONICAL_DATA_ROOT" "$LEGACY_DATA_ROOT" "$(dirname "$CACHE_TARGET")"
  mv "$TARGET" "$CACHE_TARGET"
  TARGET="$CACHE_TARGET"
}
teardown_fixture() { cleanup_fixture; }

hash_agents() { find "$TARGET/agents" -type f -exec shasum {} \; | sort | shasum; }
journal_files() { find "$CFG" -name 'subagent-journal*' 2>/dev/null; }

# Run the COPIED configurator (root derives from its physical location).
run() { TMPDIR="$STAGE_PARENT" OH_NO_CONFIG_DIR="$CFG" "$TARGET/scripts/configure-subagents" "$@"; }

# ---------------------------------------------------------------------------
echo "== check: read-only + unconfigured =="
setup_fixture
before_hash="$(hash_agents)"
status="$(run check | grep '^STATUS:')"
[ "$status" = "STATUS: unconfigured" ] && ok "check reports unconfigured before any apply" || bad "check status ($status)"
[ "$before_hash" = "$(hash_agents)" ] && ok "check writes nothing" || bad "check must not write"
[ ! -e "$CFG/subagent-models.conf" ] && ok "check creates no preferences file" || bad "check created preferences file"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== apply: native-only 9 agents, byte-exact vs independent oracle (cmp) =="
setup_fixture
out="$(run apply --proxy no $(native_assignments))"; rc=$?
[ "$rc" -eq 0 ] && ok "native apply exits 0" || bad "native apply exits 0 (got $rc)"
printf '%s\n' "$out" | grep -q '^STATUS: applied' && ok "apply reports STATUS: applied" || bad "apply STATUS"
all_bytes_ok=1
for role in "${ROLES[@]}"; do
  oracle "$CANONICAL_AGENTS/$role.md" "$(model_for "$role")" "$(effort_for "$role")" "$EXP/$role.md"
  cmp -s "$TARGET/agents/$role.md" "$EXP/$role.md" || { all_bytes_ok=0; printf '        byte mismatch: %s\n' "$role"; }
done
[ "$all_bytes_ok" -eq 1 ] && ok "all 9 files byte-exact vs oracle (model replaced, effort after model, rest preserved)" || bad "byte-for-byte preservation"
adjacency_ok=1
for role in "${ROLES[@]}"; do
  LC_ALL=C awk '/^model:/{m=NR} /^effort:/{e=NR} END{ if (e!=m+1) exit 1 }' "$TARGET/agents/$role.md" || { adjacency_ok=0; printf '        effort not adjacent: %s\n' "$role"; }
done
[ "$adjacency_ok" -eq 1 ] && ok "effort line immediately follows model line" || bad "effort adjacency"
[ -f "$CFG/subagent-models.conf" ] && ok "durable preferences file written" || bad "preferences file"
grep -q '^schema_version=2$' "$CFG/subagent-models.conf" && ok "preferences use schema v2" || bad "schema_version=2"
grep -q 'AUTH_TOKEN\|BASE_URL\|Bearer\|password\|secret' "$CFG/subagent-models.conf" && bad "preferences leaked credentials" || ok "preferences store no proxy credentials"
status="$(run check | grep '^STATUS:')"
[ "$status" = "STATUS: matching" ] && ok "check reports matching after apply" || bad "check after apply ($status)"
[ -z "$(find "$STAGE_PARENT" -mindepth 1 -maxdepth 1 -type d -print -quit)" ] && ok "successful apply removes its private staging directory" || bad "successful apply left a private staging directory"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== schema-v2 diversity preferences: accept native, reject invalid secondary =="
setup_fixture
run apply --proxy no --secondary-top-model fable --top-tier-models "fable opus" $(native_assignments) >/dev/null; rc=$?
[ "$rc" -eq 0 ] && ok "native secondary accepted" || bad "native secondary rejected (rc=$rc)"
grep -q '^schema_version=2$' "$CFG/subagent-models.conf" && ok "schema-v2 preferences persisted" || bad "schema-v2 preferences missing"
grep -q '^secondary_top_model=fable$' "$CFG/subagent-models.conf" && ok "secondary persisted" || bad "secondary not persisted"
grep -q '^top_tier_models=fable opus$' "$CFG/subagent-models.conf" && ok "top-tier list persisted" || bad "top-tier list not persisted"
teardown_fixture
setup_fixture
before_hash="$(hash_agents)"
run apply --proxy yes --secondary-top-model gpt-5.6-sol --top-tier-models "fable opus gpt-5.6-sol" $(gpt_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "GPT secondary always rejected even with proxy=yes" || bad "GPT secondary must be native-only"
[ "$before_hash" = "$(hash_agents)" ] && ok "GPT secondary rejection is pre-write" || bad "GPT secondary rejection wrote agents"
teardown_fixture
setup_fixture
before_hash="$(hash_agents)"
run apply --proxy no --secondary-top-model sonnet --top-tier-models "fable opus" $(native_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "secondary outside top-tier models rejected" || bad "secondary outside top-tier models accepted"
[ "$before_hash" = "$(hash_agents)" ] && ok "non-member secondary rejection is pre-write" || bad "non-member secondary rejection wrote agents"
teardown_fixture
setup_fixture
out="$(run apply --proxy yes --top-tier-models "gpt-5.6-sol opus" $(gpt_assignments) 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "mixed GPT/native top-tier list accepted" || bad "mixed GPT/native top-tier list rejected (rc=$rc output=$out)"
grep -q '^top_tier_models=gpt-5.6-sol opus$' "$CFG/subagent-models.conf" && ok "mixed GPT/native top-tier list persisted" || bad "mixed GPT/native top-tier list missing"
teardown_fixture
setup_fixture
before_hash="$(hash_agents)"
out="$(run apply --proxy yes --top-tier-models "gpt-5.6-sol gpt-5.6-terra" $(gpt_assignments) 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ok "all-GPT top-tier list rejected by configurator" || bad "all-GPT top-tier list accepted"
printf '%s' "$out" | grep -q 'at least one of fable/opus/sonnet/haiku required' && ok "all-GPT rejection names native-entry rule" || bad "all-GPT rejection omitted native-entry rule"
[ "$before_hash" = "$(hash_agents)" ] && ok "all-GPT top-tier rejection is pre-write" || bad "all-GPT top-tier rejection wrote agents"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== byte preservation: no-final-newline, trailing sentinel, unterminated fm =="
# no final newline in body
setup_fixture
printf -- '---\nname: explore\nmodel: opus\ncolor: blue\n---\nbody line without a trailing newline' > "$EXP/src-nonl.md"
cp "$EXP/src-nonl.md" "$TARGET/agents/explore.md"
run apply --proxy no $(native_assignments) >/dev/null; rc=$?
oracle "$EXP/src-nonl.md" sonnet high "$EXP/exp-nonl.md"
{ [ "$rc" -eq 0 ] && cmp -s "$TARGET/agents/explore.md" "$EXP/exp-nonl.md"; } && ok "no-final-newline body preserved byte-exact" || bad "no-final-newline not preserved"
teardown_fixture
# trailing sentinel bytes after a blank line, no final newline
setup_fixture
printf -- '---\nname: analyst\nmodel: opus\ncolor: blue\n---\nreal body\n\nSENTINEL-TRAILER-NO-NL' > "$EXP/src-sentinel.md"
cp "$EXP/src-sentinel.md" "$TARGET/agents/analyst.md"
run apply --proxy no $(native_assignments) >/dev/null; rc=$?
oracle "$EXP/src-sentinel.md" opus xhigh "$EXP/exp-sentinel.md"
{ [ "$rc" -eq 0 ] && cmp -s "$TARGET/agents/analyst.md" "$EXP/exp-sentinel.md"; } && ok "trailing sentinel bytes preserved byte-exact" || bad "trailing sentinel bytes not preserved"
teardown_fixture
# unterminated frontmatter (no closing delimiter) must be rejected pre-write
setup_fixture
printf -- '---\nname: verifier\nmodel: opus\ncolor: blue\n' > "$TARGET/agents/verifier.md"
before_hash="$(hash_agents)"
run apply --proxy no $(native_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "unterminated frontmatter rejected" || bad "unterminated frontmatter not rejected (rc=$rc)"
[ "$before_hash" = "$(hash_agents)" ] && ok "no writes on unterminated frontmatter" || bad "partial write on unterminated frontmatter"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== apply: effort replacement in place on re-apply (cmp) =="
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
lines_first="$(wc -l < "$TARGET/agents/explore.md")"
run apply --proxy no explore=sonnet,xhigh analyst=opus,xhigh planner=opus,max plan-reviewer=opus,xhigh executor=opus,high debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh >/dev/null
lines_second="$(wc -l < "$TARGET/agents/explore.md")"
[ "$lines_first" = "$lines_second" ] && ok "re-apply replaces effort without adding a line" || bad "effort replacement line count ($lines_first -> $lines_second)"
oracle "$CANONICAL_AGENTS/explore.md" sonnet xhigh "$EXP/explore-xhigh.md"
cmp -s "$TARGET/agents/explore.md" "$EXP/explore-xhigh.md" && ok "re-apply is byte-exact vs oracle" || bad "effort replacement byte-exact"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== proxy gate: GPT rejected pre-write when proxy=no, accepted when proxy=yes =="
setup_fixture
before_hash="$(hash_agents)"
run apply --proxy no explore=gpt-5.6-terra,medium analyst=opus,xhigh planner=opus,max plan-reviewer=opus,xhigh executor=opus,high debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "gpt-5.6-terra rejected when proxy=no" || bad "gpt-5.6-terra should be rejected when proxy=no"
run apply --proxy no explore=gpt-5.6-sol,high analyst=opus,xhigh planner=opus,max plan-reviewer=opus,xhigh executor=opus,high debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "gpt-5.6-sol rejected when proxy=no" || bad "gpt-5.6-sol should be rejected when proxy=no"
[ "$before_hash" = "$(hash_agents)" ] && ok "no files written on proxy-gate rejection" || bad "proxy-gate rejection wrote files"
run apply --proxy yes $(gpt_assignments) >/dev/null; rc=$?
[ "$rc" -eq 0 ] && ok "both GPT aliases accepted when proxy=yes" || bad "GPT aliases rejected when proxy=yes (got $rc)"
grep -q '^model: gpt-5.6-terra$' "$TARGET/agents/explore.md" && ok "explore set to gpt-5.6-terra" || bad "explore model"
grep -q '^model: gpt-5.6-sol$' "$TARGET/agents/analyst.md" && ok "analyst set to gpt-5.6-sol" || bad "analyst model"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== inventory/vocabulary rejection (pre-write) =="
setup_fixture
before_hash="$(hash_agents)"
reject() {
  local label="$1"; shift
  run apply "$@" >/dev/null 2>&1; local rc=$?
  local now; now="$(hash_agents)"
  if [ "$rc" -ne 0 ] && [ "$now" = "$before_hash" ]; then ok "$label"; else bad "$label (rc=$rc)"; fi
}
reject "14-role apply rejected by exact-count contract" --proxy no $(native_assignments) extra-a=sonnet,high extra-b=sonnet,high extra-c=sonnet,high extra-d=sonnet,high extra-e=sonnet,high
reject "invalid model rejected" --proxy no explore=turbo,high analyst=opus,xhigh planner=opus,max plan-reviewer=opus,xhigh executor=opus,high debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh
reject "invalid effort rejected" --proxy no explore=sonnet,turbo analyst=opus,xhigh planner=opus,max plan-reviewer=opus,xhigh executor=opus,high debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh
reject "missing role (8) rejected" --proxy no explore=sonnet,high analyst=opus,xhigh planner=opus,max plan-reviewer=opus,xhigh executor=opus,high debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh
reject "duplicate role rejected" --proxy no explore=sonnet,high explore=sonnet,high planner=opus,max plan-reviewer=opus,xhigh executor=opus,high debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh
reject "unknown role rejected" --proxy no explore=sonnet,high mystery=opus,xhigh planner=opus,max plan-reviewer=opus,xhigh executor=opus,high debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh
reject "reordered roles rejected" --proxy no analyst=opus,xhigh explore=sonnet,high planner=opus,max plan-reviewer=opus,xhigh executor=opus,high debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh
reject "missing proxy answer rejected" $(native_assignments)
teardown_fixture

# ---------------------------------------------------------------------------
echo "== invalid target files produce no partial writes =="
setup_fixture
ln -sf "/etc/hosts" "$TARGET/agents/executor.md"
before_hash="$(hash_agents)"
run apply --proxy no $(native_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "apply refuses a symlinked target agent" || bad "symlink target not refused (rc=$rc)"
[ "$before_hash" = "$(hash_agents)" ] && ok "no partial write on symlink target" || bad "partial write on symlink target"
teardown_fixture
setup_fixture
rm -f "$TARGET/agents/debugger.md"
run apply --proxy no $(native_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "apply refuses a missing target agent" || bad "missing target not refused (rc=$rc)"
[ ! -e "$TARGET/agents/debugger.md" ] && ok "missing target stays missing" || bad "missing target written"
grep -q '^effort: ' "$TARGET/agents/explore.md" && bad "partial write on missing target" || ok "no partial write to other agents on missing target"
teardown_fixture
setup_fixture
printf 'no frontmatter here\n' > "$TARGET/agents/verifier.md"
before_hash="$(hash_agents)"
run apply --proxy no $(native_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "apply refuses malformed frontmatter" || bad "malformed frontmatter not refused (rc=$rc)"
[ "$before_hash" = "$(hash_agents)" ] && ok "no partial write on malformed frontmatter" || bad "partial write on malformed frontmatter"
teardown_fixture
setup_fixture
{ printf -- '---\nname: code-reviewer\nmodel: sonnet\nmodel: opus\ncolor: blue\n---\nbody\n'; } > "$TARGET/agents/code-reviewer.md"
run apply --proxy no $(native_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "apply refuses duplicate frontmatter model key" || bad "duplicate frontmatter not refused (rc=$rc)"
teardown_fixture
setup_fixture
chmod 500 "$TARGET/agents"
before_hash="$(hash_agents)"
run apply --proxy no $(native_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "apply refuses unwritable target dir" || bad "unwritable target not refused (rc=$rc)"
[ "$before_hash" = "$(hash_agents)" ] && ok "no partial write to unwritable target" || bad "partial write to unwritable target"
chmod 700 "$TARGET/agents"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== CR-4 physical confinement: symlinked root / symlinked agents refused =="
# symlinked plugin root
setup_fixture
mv "$TARGET" "$WORK/real-root"
ln -s "$WORK/real-root" "$TARGET"
before_hash="$(find "$WORK/real-root/agents" -type f -exec shasum {} \; | sort | shasum)"
TMPDIR="$STAGE_PARENT" OH_NO_CONFIG_DIR="$CFG" "$TARGET/scripts/configure-subagents" apply --proxy no $(native_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "apply refuses a symlinked plugin root" || bad "symlinked root not refused (rc=$rc)"
[ "$before_hash" = "$(find "$WORK/real-root/agents" -type f -exec shasum {} \; | sort | shasum)" ] && ok "symlinked-root agents byte-unchanged" || bad "symlinked-root agents mutated"
teardown_fixture
# symlinked agents directory
setup_fixture
rm -rf "$TARGET/agents"
mkdir -p "$WORK/elsewhere"
cp "$CANONICAL_AGENTS"/*.md "$WORK/elsewhere/"
ln -s "$WORK/elsewhere" "$TARGET/agents"
before_hash="$(find -L "$WORK/elsewhere" -type f -exec shasum {} \; | sort | shasum)"
run apply --proxy no $(native_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "apply refuses a symlinked agents directory" || bad "symlinked agents not refused (rc=$rc)"
[ "$before_hash" = "$(find -L "$WORK/elsewhere" -type f -exec shasum {} \; | sort | shasum)" ] && ok "symlinked-agents target byte-unchanged" || bad "symlinked-agents target mutated"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== CR-1 fault injection: journal, prefs publication, restore =="
# journal creation failure -> abort before any commit
setup_fixture
before_hash="$(hash_agents)"
OH_NO_CONFIGURE_FAIL_JOURNAL=1 run apply --proxy no $(native_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "journal-creation failure aborts nonzero" || bad "journal failure exit (got $rc)"
[ "$before_hash" = "$(hash_agents)" ] && ok "journal-creation failure writes no agent files" || bad "journal failure wrote agents"
[ ! -e "$CFG/subagent-models.conf" ] && ok "journal-creation failure publishes no preferences" || bad "journal failure wrote prefs"
[ -z "$(journal_files)" ] && ok "journal-creation failure leaves no journal" || bad "journal failure left a journal"
teardown_fixture
# prefs publication failure -> restore runtime + prior prefs, clear journal
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null                 # first good config -> prior prefs
for role in "${ROLES[@]}"; do cp "$CANONICAL_AGENTS/$role.md" "$TARGET/agents/$role.md"; done  # drift
baseline_hash="$(hash_agents)"
OH_NO_CONFIGURE_FAIL_PREFS=1 run apply --proxy no $(alt_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "prefs-publication failure exits nonzero" || bad "prefs failure exit (got $rc)"
[ "$baseline_hash" = "$(hash_agents)" ] && ok "prefs-publication failure restores every runtime file" || bad "prefs failure left runtime changed"
grep -q '^assignment=explore,sonnet,high$' "$CFG/subagent-models.conf" && ok "prefs-publication failure restores prior preferences" || bad "prior prefs not restored"
grep -q '^assignment=explore,opus,max$' "$CFG/subagent-models.conf" && bad "failed new prefs leaked into stored preferences" || ok "failed new preferences not published"
[ -z "$(journal_files)" ] && ok "prefs-publication failure clears the journal (rollback complete)" || bad "journal left after prefs-failure rollback"
teardown_fixture
# restore failure -> journal retained, recovery-required, never silently cleared
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
for role in "${ROLES[@]}"; do cp "$CANONICAL_AGENTS/$role.md" "$TARGET/agents/$role.md"; done
OH_NO_CONFIGURE_FAIL_AFTER=3 OH_NO_CONFIGURE_FAIL_RESTORE=1 run apply --proxy no $(alt_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "restore failure exits nonzero" || bad "restore failure exit (got $rc)"
[ -n "$(journal_files)" ] && ok "restore failure retains the journal (recovery required)" || bad "journal silently cleared on restore failure"
status="$(run check | grep '^STATUS:')"
[ "$status" = "STATUS: recovery-required" ] && ok "check reports recovery-required after retained journal" || bad "retained-journal status ($status)"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== CR-2 serialization: held lock blocks writers; stale dead owner reclaimed =="
setup_fixture
mkdir -p "$CFG/subagent-lock.d"
printf 'pid=%s\nhost=%s\ntxn=test\n' "$$" "$(hostname 2>/dev/null || uname -n)" > "$CFG/subagent-lock.d/owner"
before_hash="$(hash_agents)"
OH_NO_CONFIGURE_LOCK_ATTEMPTS=2 run apply --proxy no $(native_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "apply blocked while a live owner holds the lock" || bad "apply not blocked by held lock (rc=$rc)"
[ "$before_hash" = "$(hash_agents)" ] && ok "blocked apply makes no partial runtime writes" || bad "blocked apply wrote agents"
[ ! -e "$CFG/subagent-models.conf" ] && ok "blocked apply publishes no preferences (no mixed state)" || bad "blocked apply wrote prefs"
out="$(run reapply --quiet)"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "reapply --quiet skips safely while lock is held" || bad "reapply did not skip under held lock (rc=$rc out=$out)"
[ "$before_hash" = "$(hash_agents)" ] && ok "skipped reapply makes no writes" || bad "skipped reapply wrote agents"
rm -rf "$CFG/subagent-lock.d"
run apply --proxy no $(native_assignments) >/dev/null; rc=$?
[ "$rc" -eq 0 ] && ok "apply succeeds once the lock is released" || bad "apply after release (got $rc)"
teardown_fixture
# stale (dead-owner) lock is reclaimed
setup_fixture
( exit 0 ) & deadpid=$!; wait "$deadpid" 2>/dev/null
mkdir -p "$CFG/subagent-lock.d"
printf 'pid=%s\nhost=%s\ntxn=dead\n' "$deadpid" "$(hostname 2>/dev/null || uname -n)" > "$CFG/subagent-lock.d/owner"
run apply --proxy no $(native_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "apply reclaims a stale (dead-owner) lock" || bad "stale lock not reclaimed (rc=$rc)"
[ ! -e "$CFG/subagent-lock.d" ] && ok "lock released after reclaim + apply" || bad "lock left after reclaim"
teardown_fixture
# owner-marker publication is mandatory: on failure, fail before writes and leave
# no half-owned lock behind (otherwise other processes read it as stale).
setup_fixture
before_hash="$(hash_agents)"
OH_NO_CONFIGURE_FAIL_OWNER=1 run apply --proxy no $(native_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "owner-write failure fails before any write" || bad "owner-write failure not fatal (rc=$rc)"
[ "$before_hash" = "$(hash_agents)" ] && ok "owner-write failure writes no agent files" || bad "owner-write failure wrote agents"
[ ! -e "$CFG/subagent-models.conf" ] && ok "owner-write failure publishes no preferences" || bad "owner-write failure wrote prefs"
[ ! -e "$CFG/subagent-lock.d" ] && ok "owner-write failure leaves no half-owned lock" || bad "owner-write failure left a lock dir"
teardown_fixture
# concurrent writers serialize to a consistent end state (no mixed runtime/prefs)
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
run apply --proxy no $(native_assignments) >/dev/null 2>&1 & p1=$!
run apply --proxy no $(alt_assignments) >/dev/null 2>&1 & p2=$!
wait "$p1"; r1=$?; wait "$p2"; r2=$?
{ [ "$r1" -eq 0 ] && [ "$r2" -eq 0 ]; } && ok "concurrent applies both complete under the lock" || bad "concurrent applies rc ($r1,$r2)"
status="$(run check | grep '^STATUS:')"
[ "$status" = "STATUS: matching" ] && ok "concurrent applies leave consistent matching state" || bad "concurrent end state ($status)"
[ ! -e "$CFG/subagent-lock.d" ] && ok "concurrent applies leave no lock" || bad "lock left after concurrent applies"
[ -z "$(journal_files)" ] && ok "concurrent applies leave no journal" || bad "journal left after concurrent applies"
teardown_fixture
# two reclaimers of a single stale lock both complete without corrupting state
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
( exit 0 ) & deadpid=$!; wait "$deadpid" 2>/dev/null
mkdir -p "$CFG/subagent-lock.d"
printf 'pid=%s\nhost=%s\ntxn=dead\n' "$deadpid" "$(hostname 2>/dev/null || uname -n)" > "$CFG/subagent-lock.d/owner"
run apply --proxy no $(alt_assignments) >/dev/null 2>&1 & q1=$!
run apply --proxy no $(native_assignments) >/dev/null 2>&1 & q2=$!
wait "$q1"; s1=$?; wait "$q2"; s2=$?
{ [ "$s1" -eq 0 ] && [ "$s2" -eq 0 ]; } && ok "two reclaimers of one stale lock both complete" || bad "dual reclaimer rc ($s1,$s2)"
status="$(run check | grep '^STATUS:')"
[ "$status" = "STATUS: matching" ] && ok "dual reclaim leaves consistent matching state" || bad "dual reclaim end state ($status)"
[ ! -e "$CFG/subagent-lock.d" ] && ok "dual reclaim leaves no lock" || bad "lock left after dual reclaim"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== CR-5 journal trust: invalid journals retained, never followed =="
plant_and_check() {
  local label="$1" journal="$2"
  setup_fixture
  run apply --proxy no $(native_assignments) >/dev/null
  local applied_hash; applied_hash="$(hash_agents)"
  printf '%s' "$journal" > "$CFG/subagent-journal.conf"
  run reapply --quiet >/dev/null 2>&1; local rc=$?
  local retained=no; [ -n "$(journal_files)" ] && retained=yes
  if [ "$rc" -ne 0 ] && [ "$retained" = yes ] && [ "$applied_hash" = "$(hash_agents)" ]; then
    ok "$label"
  else
    bad "$label (rc=$rc retained=$retained)"
  fi
  teardown_fixture
}
plant_and_check "wrong-schema (bad sv value) journal retained + refused" "$(printf 'schema_version=999\nroot=PLACEHOLDER\ntxn=abc\nprior_prefs=absent\n')"
# CR-9: a structurally valid journal whose root is not the current physical root
# is moot/superseded -> discard OUR fixed journal, never follow the foreign path.
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
applied_hash="$(hash_agents)"
foreign="$WORK/foreign-root"; mkdir -p "$foreign"; printf 'sentinel\n' > "$foreign/keep"
printf 'schema_version=1\nroot=%s\ntxn=abc\nprior_prefs=present\n' "$foreign" > "$CFG/subagent-journal.conf"
run reapply --quiet >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "superseded (foreign-root) journal is cleared, not wedged" || bad "superseded-root rc=$rc"
[ -z "$(journal_files)" ] && ok "superseded-root journal is discarded" || bad "superseded-root journal retained"
[ "$applied_hash" = "$(hash_agents)" ] && ok "superseded-root recovery makes no runtime writes (already matching)" || bad "superseded-root wrote agents"
{ [ -f "$foreign/keep" ] && [ "$(find "$foreign" -mindepth 1 | wc -l | tr -d ' ')" = 1 ]; } && ok "superseded-root: foreign path never followed or written" || bad "superseded-root touched foreign path"
teardown_fixture
# CR-9: superseded-root short-circuits BEFORE any txn/backup parsing (unsafe txn
# in a foreign-root journal is irrelevant and never dereferenced).
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
applied_hash="$(hash_agents)"
printf 'schema_version=1\nroot=%s\ntxn=../../escape\nprior_prefs=absent\n' "$WORK/other-root" > "$CFG/subagent-journal.conf"
run reapply --quiet >/dev/null 2>&1; rc=$?
{ [ "$rc" -eq 0 ] && [ -z "$(journal_files)" ] && [ "$applied_hash" = "$(hash_agents)" ]; } && ok "superseded-root with unsafe txn is safely discarded" || bad "superseded-root unsafe-txn handling (rc=$rc)"
teardown_fixture
# traversal txn / legacy destination-path journal not followed
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
applied_hash="$(hash_agents)"
printf 'schema_version=1\nroot=%s\ntxn=../escape\nprior_prefs=absent\n' "$TARGET" > "$CFG/subagent-journal.conf"
run reapply --quiet >/dev/null 2>&1; rc=$?
{ [ "$rc" -ne 0 ] && [ -n "$(journal_files)" ] && [ "$applied_hash" = "$(hash_agents)" ]; } && ok "traversal-txn journal retained + refused" || bad "traversal-txn journal handling (rc=$rc)"
teardown_fixture
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
applied_hash="$(hash_agents)"
printf 'schema_version=1\nagents_dir=/etc\nbackup_dir=/tmp/evil\nfile=../../etc/passwd\n' > "$CFG/subagent-journal.conf"
run reapply --quiet >/dev/null 2>&1; rc=$?
{ [ "$rc" -ne 0 ] && [ -n "$(journal_files)" ] && [ "$applied_hash" = "$(hash_agents)" ]; } && ok "legacy destination-path journal not followed" || bad "legacy destination-path journal handling (rc=$rc)"
teardown_fixture
# symlinked backup dir
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
applied_hash="$(hash_agents)"
mkdir -p "$WORK/evil-backup"
ln -s "$WORK/evil-backup" "$CFG/subagent-backups/badbk"
printf 'schema_version=1\nroot=%s\ntxn=badbk\nprior_prefs=absent\n' "$TARGET" > "$CFG/subagent-journal.conf"
run reapply --quiet >/dev/null 2>&1; rc=$?
{ [ "$rc" -ne 0 ] && [ -n "$(journal_files)" ] && [ "$applied_hash" = "$(hash_agents)" ]; } && ok "symlinked backup-dir journal refused" || bad "symlinked backup-dir journal handling (rc=$rc)"
teardown_fixture

assert_journal_refused() {
  run reapply --quiet >/dev/null 2>&1; local rc=$?
  local retained=no; [ -n "$(journal_files)" ] && retained=yes
  { [ "$rc" -ne 0 ] && [ "$retained" = yes ] && [ "$applied_hash" = "$(hash_agents)" ]; } && ok "$1" || bad "$1 (rc=$rc retained=$retained)"
}
# prior_prefs value outside present|absent
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
applied_hash="$(hash_agents)"
printf 'schema_version=1\nroot=%s\ntxn=abc\nprior_prefs=maybe\n' "$TARGET" > "$CFG/subagent-journal.conf"
assert_journal_refused "invalid prior_prefs value retained + refused (no partial restore)"
teardown_fixture
# duplicate key
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
applied_hash="$(hash_agents)"
printf 'schema_version=1\nroot=%s\nroot=%s\ntxn=abc\nprior_prefs=absent\n' "$TARGET" "$TARGET" > "$CFG/subagent-journal.conf"
assert_journal_refused "duplicate-key journal retained + refused"
teardown_fixture
# unknown extra key
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
applied_hash="$(hash_agents)"
printf 'schema_version=1\nroot=%s\ntxn=abc\nprior_prefs=absent\nunknown=foo\n' "$TARGET" > "$CFG/subagent-journal.conf"
assert_journal_refused "extra-key journal retained + refused"
teardown_fixture
# malformed backup agent frontmatter (schema/root valid, backup body corrupt)
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
applied_hash="$(hash_agents)"
realtxn="$(basename "$(find "$CFG/subagent-backups" -mindepth 1 -maxdepth 1 -type d | head -1)")"
printf 'no frontmatter here\n' > "$CFG/subagent-backups/$realtxn/verifier.md"
printf 'schema_version=1\nroot=%s\ntxn=%s\nprior_prefs=absent\n' "$TARGET" "$realtxn" > "$CFG/subagent-journal.conf"
assert_journal_refused "malformed backup agent journal retained + refused (validated before restore)"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== CR-9 version transition: crash under root A, recover under distinct root B =="
setup_fixture                                   # $TARGET = physical root A, shared $CFG
run apply --proxy no $(native_assignments) >/dev/null    # configure A + durable prefs
for role in "${ROLES[@]}"; do cp "$CANONICAL_AGENTS/$role.md" "$TARGET/agents/$role.md"; done  # drift A
OH_NO_CONFIGURE_CRASH_AFTER=3 run reapply --quiet >/dev/null 2>&1   # hard crash -> journal(root=A) remains
[ -n "$(journal_files)" ] && ok "crash under root A leaves a journal recording root A" || bad "no journal after crash under A"
a_hash_before="$(find "$TARGET/agents" -type f -exec shasum {} \; | sort | shasum)"
# Build a physically distinct, valid, unconfigured root B sharing the same $CFG.
ROOTB="$WORK/plugin-root-b"
mkdir -p "$ROOTB/agents" "$ROOTB/scripts"
cp "$CONFIGURATOR" "$ROOTB/scripts/configure-subagents"
cp "$OH_NO_CONFIG_SRC" "$ROOTB/scripts/oh-no-config"
chmod +x "$ROOTB/scripts/configure-subagents" "$ROOTB/scripts/oh-no-config"
for role in "${ROLES[@]}"; do cp "$CANONICAL_AGENTS/$role.md" "$ROOTB/agents/$role.md"; done
run_b() { TMPDIR="$STAGE_PARENT" OH_NO_CONFIG_DIR="$CFG" "$ROOTB/scripts/configure-subagents" "$@"; }
# Before mutation, B still sees the recovery-required journal.
statusb="$(run_b check | grep '^STATUS:')"
[ "$statusb" = "STATUS: recovery-required" ] && ok "root B check reports recovery-required before mutation" || bad "root B pre-mutation status ($statusb)"
out="$(run_b reapply --quiet)"; rc=$?
[ "$rc" -eq 0 ] && ok "reapply under root B is not wedged by the root-A journal" || bad "root B reapply wedged (rc=$rc)"
[ -z "$(journal_files)" ] && ok "root B recovery discards the superseded root-A journal" || bad "superseded journal not cleared under B"
convb_ok=1
for role in "${ROLES[@]}"; do
  oracle "$CANONICAL_AGENTS/$role.md" "$(model_for "$role")" "$(effort_for "$role")" "$EXP/$role.md"
  cmp -s "$ROOTB/agents/$role.md" "$EXP/$role.md" || convb_ok=0
done
[ "$convb_ok" -eq 1 ] && ok "root B converges byte-exactly to the intact durable preferences (cmp)" || bad "root B did not converge to prefs"
[ "$a_hash_before" = "$(find "$TARGET/agents" -type f -exec shasum {} \; | sort | shasum)" ] && ok "no writes into root A during root B recovery" || bad "root B recovery wrote into root A"
statusb="$(run_b check | grep '^STATUS:')"
[ "$statusb" = "STATUS: matching" ] && ok "root B check reports matching after recovery+converge" || bad "root B post status ($statusb)"
teardown_fixture
# Manual apply under a distinct root B (with a superseded root-A journal) proceeds.
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
printf 'schema_version=1\nroot=%s\ntxn=abc\nprior_prefs=present\n' "$TARGET" > "$CFG/subagent-journal.conf"  # journal for root A
ROOTB="$WORK/plugin-root-b"
mkdir -p "$ROOTB/agents" "$ROOTB/scripts"
cp "$CONFIGURATOR" "$ROOTB/scripts/configure-subagents"; cp "$OH_NO_CONFIG_SRC" "$ROOTB/scripts/oh-no-config"
chmod +x "$ROOTB/scripts/configure-subagents" "$ROOTB/scripts/oh-no-config"
for role in "${ROLES[@]}"; do cp "$CANONICAL_AGENTS/$role.md" "$ROOTB/agents/$role.md"; done
TMPDIR="$STAGE_PARENT" OH_NO_CONFIG_DIR="$CFG" "$ROOTB/scripts/configure-subagents" apply --proxy no $(alt_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "manual apply under distinct root B proceeds past the superseded journal" || bad "manual apply under B blocked (rc=$rc)"
[ -z "$(journal_files)" ] && ok "manual apply under B leaves no journal" || bad "journal left after apply under B"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== CR-10 seam gating: destructive seams ignored without the test guard =="
setup_fixture
before_hash="$(hash_agents)"
OH_NO_CONFIGURE_TEST_SEAMS=0 OH_NO_CONFIGURE_FAIL_JOURNAL=1 run apply --proxy no $(native_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "FAIL_JOURNAL seam ignored when OH_NO_CONFIGURE_TEST_SEAMS!=1" || bad "seam honoured without guard (rc=$rc)"
grep -q '^effort: ' "$TARGET/agents/explore.md" && ok "apply completes normally with the seam guard off" || bad "apply blocked with seam guard off"
teardown_fixture
# A second seam, also ignored without the guard.
setup_fixture
OH_NO_CONFIGURE_TEST_SEAMS=0 OH_NO_CONFIGURE_FAIL_OWNER=1 run apply --proxy no $(native_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "FAIL_OWNER seam ignored when OH_NO_CONFIGURE_TEST_SEAMS!=1" || bad "owner seam honoured without guard (rc=$rc)"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== CR-6 preflight: malformed/missing unconfigured target -> invalid-agents =="
setup_fixture
rm -rf "$TARGET/agents"
status="$(run check | grep '^STATUS:')"
[ "$status" = "STATUS: invalid-agents" ] && ok "missing agents dir (unconfigured) reports invalid-agents" || bad "missing-agents check status ($status)"
teardown_fixture
setup_fixture
printf 'no frontmatter here\n' > "$TARGET/agents/verifier.md"
status="$(run check | grep '^STATUS:')"
[ "$status" = "STATUS: invalid-agents" ] && ok "malformed agent (unconfigured) reports invalid-agents" || bad "malformed-agent check status ($status)"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== schema migration: v1 prefs stale; v1 interrupted journal recovers cleanly =="
setup_fixture
cat >"$CFG/subagent-models.conf" <<'PREFS'
schema_version=1
proxy=no
assignment=explore,sonnet,high
PREFS
before_hash="$(hash_agents)"
status="$(run check | grep '^STATUS:')"
[ "$status" = "STATUS: invalid-preferences" ] && ok "v1 preferences enter reconfigure path" || bad "v1 preferences status ($status)"
run reapply --quiet >/dev/null 2>&1; rc=$?
[ "$rc" -eq 4 ] && ok "v1 preferences are rejected as stale without partial apply" || bad "v1 prefs reapply rc=$rc"
[ "$before_hash" = "$(hash_agents)" ] && ok "v1 preferences recovery path writes no agents" || bad "v1 preferences path partially wrote agents"
teardown_fixture
setup_fixture
txn="preupgrade-v1"
mkdir -p "$CFG/subagent-backups/$txn"
for role in "${ROLES[@]}"; do cp "$TARGET/agents/$role.md" "$CFG/subagent-backups/$txn/$role.md"; done
baseline_hash="$(hash_agents)"
printf '
# interrupted mutation
' >> "$TARGET/agents/explore.md"
printf 'schema_version=1
root=%s
txn=%s
prior_prefs=absent
' "$TARGET" "$txn" > "$CFG/subagent-journal.conf"
run reapply --quiet >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "pre-upgrade v1 interrupted journal recovers with exit 0 (no exit-7)" || bad "v1 journal recovery rc=$rc"
[ "$baseline_hash" = "$(hash_agents)" ] && ok "v1 journal recovery rolls runtime back" || bad "v1 journal recovery did not roll back"
[ ! -e "$CFG/subagent-models.conf" ] && ok "v1 journal recovery restores absent prior prefs" || bad "v1 journal recovery left prefs"
[ -z "$(journal_files)" ] && ok "v1 journal recovery clears journal" || bad "v1 journal recovery retained journal"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== reapply: idempotent no-op when matching; repairs simulated drift (cmp) =="
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
backups_before="$(find "$CFG/subagent-backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
out="$(run reapply --quiet)"; rc=$?
[ "$rc" -eq 0 ] && ok "matching reapply exits 0" || bad "matching reapply exits 0 (got $rc)"
[ -z "$out" ] && ok "matching reapply is a silent no-op" || bad "matching reapply produced output ($out)"
backups_after="$(find "$CFG/subagent-backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
[ "$backups_before" = "$backups_after" ] && ok "matching reapply creates no new backup" || bad "matching reapply created a backup"
cp "$CANONICAL_AGENTS/explore.md" "$TARGET/agents/explore.md"
status="$(run check | grep '^STATUS:')"
[ "$status" = "STATUS: drifted" ] && ok "check detects drift after simulated plugin update" || bad "drift not detected ($status)"
out="$(run reapply --quiet)"; rc=$?
[ "$rc" -eq 0 ] && ok "drift reapply exits 0" || bad "drift reapply exits 0 (got $rc)"
[ -n "$out" ] && ok "drift reapply emits a restart notice" || bad "drift reapply produced no notice"
printf '%s' "$out" | grep -qi 'session\|/clear' && ok "restart notice mentions a new session or /clear" || bad "restart notice wording"
oracle "$CANONICAL_AGENTS/explore.md" sonnet high "$EXP/explore-high.md"
cmp -s "$TARGET/agents/explore.md" "$EXP/explore-high.md" && ok "drift reapply restored the configured value (cmp)" || bad "drift not repaired"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== reapply: no-op with no stored preferences =="
setup_fixture
before_hash="$(hash_agents)"
out="$(run reapply --quiet)"; rc=$?
[ "$rc" -eq 0 ] && ok "reapply with no preferences exits 0" || bad "reapply no-prefs exit (got $rc)"
[ -z "$out" ] && ok "reapply with no preferences is silent" || bad "reapply no-prefs produced output ($out)"
[ "$before_hash" = "$(hash_agents)" ] && ok "reapply with no preferences writes nothing" || bad "reapply no-prefs wrote files"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== mid-commit failure rolls back; hard crash recovers on next run =="
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
for role in "${ROLES[@]}"; do cp "$CANONICAL_AGENTS/$role.md" "$TARGET/agents/$role.md"; done
baseline_hash="$(hash_agents)"
OH_NO_CONFIGURE_FAIL_AFTER=3 run reapply --quiet >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "injected mid-commit failure exits non-zero" || bad "injected failure exit (got $rc)"
[ "$baseline_hash" = "$(hash_agents)" ] && ok "rollback restored every file to pre-commit state" || bad "rollback incomplete"
[ -z "$(journal_files)" ] && ok "rollback clears the transaction journal" || bad "journal left after rollback"
OH_NO_CONFIGURE_CRASH_AFTER=3 run reapply --quiet >/dev/null 2>&1
[ -n "$(journal_files)" ] && ok "hard crash leaves a stale journal" || bad "no stale journal after crash"
status="$(run check | grep '^STATUS:')"
[ "$status" = "STATUS: recovery-required" ] && ok "check reports recovery-required on stale journal" || bad "stale journal status ($status)"
run reapply --quiet >/dev/null; rc=$?
[ "$rc" -eq 0 ] && ok "next run recovers and completes" || bad "recovery run exit (got $rc)"
[ -z "$(journal_files)" ] && ok "recovery clears the stale journal" || bad "stale journal persists after recovery"
recovered_ok=1
for role in "${ROLES[@]}"; do
  oracle "$CANONICAL_AGENTS/$role.md" "$(model_for "$role")" "$(effort_for "$role")" "$EXP/$role.md"
  cmp -s "$TARGET/agents/$role.md" "$EXP/$role.md" || recovered_ok=0
done
[ "$recovered_ok" -eq 1 ] && ok "post-recovery state is fully configured (cmp)" || bad "post-recovery state incomplete"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== backup retention pruning keeps only the newest N =="
setup_fixture
OH_NO_CONFIGURE_BACKUP_KEEP=2 run apply --proxy no $(native_assignments) >/dev/null
OH_NO_CONFIGURE_BACKUP_KEEP=2 run apply --proxy no $(alt_assignments) >/dev/null
OH_NO_CONFIGURE_BACKUP_KEEP=2 run apply --proxy no $(native_assignments) >/dev/null
count="$(find "$CFG/subagent-backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
[ "$count" -le 2 ] && ok "backup pruning keeps at most the configured retention ($count<=2)" || bad "backup pruning kept $count > 2"
teardown_fixture
# malformed retention env falls back safely (no arithmetic diagnostics)
setup_fixture
out="$(OH_NO_CONFIGURE_BACKUP_KEEP=abc run apply --proxy no $(native_assignments) 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "malformed OH_NO_CONFIGURE_BACKUP_KEEP still applies successfully" || bad "malformed retention broke apply (rc=$rc)"
printf '%s' "$out" | grep -qi 'integer expression\|syntax error\|not found' && bad "malformed retention produced arithmetic diagnostics" || ok "malformed retention produces no arithmetic diagnostics"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== apply refuses a Git source checkout (protects canonical agents) =="
setup_fixture
mkdir -p "$TARGET/.git"
before_hash="$(hash_agents)"
run apply --proxy no $(native_assignments) >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "apply refuses a Git checkout target" || bad "apply into Git checkout not refused (rc=$rc)"
[ "$before_hash" = "$(hash_agents)" ] && ok "Git checkout agents byte-unchanged" || bad "Git checkout agents mutated"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== SessionStart: no-op / drift-repair / failure path all emit valid JSON =="
run_hook() { env TMPDIR="$STAGE_PARENT" CLAUDE_PLUGIN_ROOT="$TARGET" OH_NO_CONFIG_DIR="$CFG" "$@" "$TARGET/hooks/session-start"; }
valid_json() { printf '%s' "$1" | "$PYTHON" -c 'import json,sys; json.loads(sys.stdin.read())' >/dev/null 2>&1; }

# Canonical resolver order, exercised by both the writer and SessionStart reader.
echo "== resolver: writer and hook reader share deterministic priority =="
without_ambient_oh_no_config() { env -u OH_NO_CONFIG_DIR "$@"; }
resolver_case() {
  local label="$1" mode="$2"
  setup_fixture
  local explicit="$WORK/explicit" claude_home="$WORK/claude-home" plugin_data="$WORK/wrong-plugin-data" xdg="$WORK/xdg" home="$WORK/home"
  mkdir -p "$explicit" "$claude_home/plugins/data/oh-no-harness-resolver-fixture" "$plugin_data" "$xdg" "$home"
  local expected env_args=()
  case "$mode" in
    explicit)
      expected="$explicit"; env_args=(OH_NO_CONFIG_DIR="$explicit" CLAUDE_PLUGIN_DATA="$plugin_data" CLAUDE_CONFIG_DIR="$claude_home" XDG_CONFIG_HOME="$xdg" HOME="$home") ;;
    plugin-data-ignored)
      expected="$claude_home/plugins/data/oh-no-harness-resolver-fixture"; env_args=(CLAUDE_PLUGIN_DATA="$plugin_data" CLAUDE_CONFIG_DIR="$claude_home" XDG_CONFIG_HOME="$xdg" HOME="$home") ;;
    claude-glob)
      expected="$claude_home/plugins/data/oh-no-harness-resolver-fixture"; env_args=(CLAUDE_CONFIG_DIR="$claude_home" XDG_CONFIG_HOME="$xdg" HOME="$home") ;;
    xdg)
      rm -rf "$claude_home/plugins/data"; expected="$xdg/oh-no-harness"; env_args=(CLAUDE_PLUGIN_DATA="$plugin_data" CLAUDE_CONFIG_DIR="$claude_home" XDG_CONFIG_HOME="$xdg" HOME="$home") ;;
  esac
  without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" "${env_args[@]}" "$TARGET/scripts/configure-subagents" apply --proxy no $(native_assignments) >/dev/null 2>&1; local rc=$?
  [ "$rc" -eq 0 ] && [ -f "$expected/subagent-models.conf" ] && ok "$label writer resolved expected directory" || bad "$label writer resolver (rc=$rc expected=$expected)"
  local out
  out="$(without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" "${env_args[@]}" CLAUDE_PLUGIN_ROOT="$TARGET" "$TARGET/hooks/session-start")"
  printf '%s' "$out" | grep -q 'effective_primaries=.*code-reviewer:opus' && ok "$label hook reader found writer preferences" || bad "$label hook reader resolver drifted"
  teardown_fixture
}
resolver_case "OH_NO_CONFIG_DIR wins" explicit
resolver_case "CLAUDE_PLUGIN_DATA ignored" plugin-data-ignored
resolver_case "CLAUDE_CONFIG_DIR plugins-data glob" claude-glob
resolver_case "XDG fallback" xdg

# A cache install must select its active marketplace data identity even when a
# lexically-earlier empty inline sibling coexists. The explicit override remains
# a separate writer/reader symmetry guard.
echo "== resolver: cache identity beats lexically-earlier empty plugin-data sibling =="
setup_cache_identity_fixture
collision_home="$CACHE_HOME"
collision_fixture="$CANONICAL_DATA_ROOT"
env TMPDIR="$STAGE_PARENT" OH_NO_CONFIG_DIR="$collision_fixture" "$TARGET/scripts/configure-subagents" apply \
  --proxy no --secondary-top-model fable --top-tier-models "fable opus" $(native_assignments) >/dev/null
hook_out="$(without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$collision_home" CLAUDE_PLUGIN_ROOT="$TARGET" "$TARGET/hooks/session-start")"
printf '%s' "$hook_out" | grep -q 'secondary_top_model=fable' && ok "cache identity resolves populated canonical fixture despite earlier sibling" || bad "cache identity did not resolve populated canonical fixture"
hook_out="$(env TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$collision_home" OH_NO_CONFIG_DIR="$collision_fixture" CLAUDE_PLUGIN_ROOT="$TARGET" "$TARGET/hooks/session-start")"
printf '%s' "$hook_out" | grep -q 'secondary_top_model=fable' && ok "explicit override resolves populated fixture despite earlier sibling" || bad "explicit override did not resolve populated fixture"
teardown_fixture

# Read-only config state may fall back to the legacy inline identity, but the
# canonical path remains the storage locator and always wins when populated.
echo "== oh-no-config: legacy read continuity with canonical path and precedence =="
setup_cache_identity_fixture
config_home="$CACHE_HOME"
canonical_config_root="$CANONICAL_DATA_ROOT"
legacy_config_root="$LEGACY_DATA_ROOT"
cat >"$legacy_config_root/config.json" <<'JSON'
{
  "autoRouting": {
    "enabled": true
  }
}
JSON
canonical_before="$(find "$canonical_config_root" -mindepth 1 -print | LC_ALL=C sort | shasum)"
legacy_before="$(shasum "$legacy_config_root/config.json")"
status_out="$(without_ambient_oh_no_config CLAUDE_CONFIG_DIR="$config_home" "$TARGET/scripts/oh-no-config" status)"; status_rc=$?
enabled_out="$(without_ambient_oh_no_config CLAUDE_CONFIG_DIR="$config_home" "$TARGET/scripts/oh-no-config" is-enabled)"; enabled_rc=$?
path_out="$(without_ambient_oh_no_config CLAUDE_CONFIG_DIR="$config_home" "$TARGET/scripts/oh-no-config" path)"; path_rc=$?
{ [ "$status_rc" -eq 0 ] && printf '%s\n' "$status_out" | grep -q '^auto-routing: on$' && printf '%s\n' "$status_out" | grep -Fq "config: $legacy_config_root/config.json"; } && ok "legacy-only status reads enabled state and reports effective legacy path" || bad "legacy-only status missed legacy config ($status_out)"
[ "$enabled_rc" -eq 0 ] && [ -z "$enabled_out" ] && ok "legacy-only is-enabled reads enabled state silently" || bad "legacy-only is-enabled missed legacy config (rc=$enabled_rc)"
[ "$path_rc" -eq 0 ] && [ "$path_out" = "$canonical_config_root/config.json" ] && ok "path remains the canonical storage locator during legacy read-through" || bad "path did not remain canonical ($path_out)"
[ "$canonical_before" = "$(find "$canonical_config_root" -mindepth 1 -print | LC_ALL=C sort | shasum)" ] && [ ! -e "$canonical_config_root/config.json" ] && [ "$legacy_before" = "$(shasum "$legacy_config_root/config.json")" ] && ok "legacy read-through mutates neither canonical nor legacy config state" || bad "legacy read-through mutated config state"

cat >"$canonical_config_root/config.json" <<'JSON'
{
  "autoRouting": {
    "enabled": false
  }
}
JSON
canonical_before="$(shasum "$canonical_config_root/config.json")"
legacy_before="$(shasum "$legacy_config_root/config.json")"
status_out="$(without_ambient_oh_no_config CLAUDE_CONFIG_DIR="$config_home" "$TARGET/scripts/oh-no-config" status)"; status_rc=$?
enabled_out="$(without_ambient_oh_no_config CLAUDE_CONFIG_DIR="$config_home" "$TARGET/scripts/oh-no-config" is-enabled)"; enabled_rc=$?
path_out="$(without_ambient_oh_no_config CLAUDE_CONFIG_DIR="$config_home" "$TARGET/scripts/oh-no-config" path)"; path_rc=$?
{ [ "$status_rc" -eq 0 ] && printf '%s\n' "$status_out" | grep -q '^auto-routing: off$' && printf '%s\n' "$status_out" | grep -Fq "config: $canonical_config_root/config.json"; } && ok "canonical disabled config wins over enabled legacy config" || bad "canonical precedence status changed ($status_out)"
[ "$enabled_rc" -eq 1 ] && [ -z "$enabled_out" ] && ok "canonical disabled config makes is-enabled exit 1 silently" || bad "canonical precedence is-enabled changed (rc=$enabled_rc)"
[ "$path_rc" -eq 0 ] && [ "$path_out" = "$canonical_config_root/config.json" ] && ok "path remains canonical when both config identities exist" || bad "coexisting config path changed ($path_out)"
[ "$canonical_before" = "$(shasum "$canonical_config_root/config.json")" ] && [ "$legacy_before" = "$(shasum "$legacy_config_root/config.json")" ] && ok "canonical precedence reads mutate neither config file" || bad "canonical precedence read mutated config state"
teardown_fixture

# Only the supported canonical cache-data identity may read through to the
# inline sibling. Unrelated identities and arbitrary override/XDG roots must not.
echo "== CR-2 oh-no-config: legacy read-through is exact-identity only =="
setup_fixture
identity_data="$WORK/plugins/data"
unrelated_root="$identity_data/oh-no-harness-unrelated"
inline_root="$identity_data/oh-no-harness-inline"
mkdir -p "$unrelated_root" "$inline_root"
cat >"$inline_root/config.json" <<'JSON'
{
  "autoRouting": {
    "enabled": true
  }
}
JSON
status_out="$(OH_NO_CONFIG_DIR="$unrelated_root" "$TARGET/scripts/oh-no-config" status)"; status_rc=$?
enabled_out="$(OH_NO_CONFIG_DIR="$unrelated_root" "$TARGET/scripts/oh-no-config" is-enabled)"; enabled_rc=$?
{ [ "$status_rc" -eq 0 ] && printf '%s\n' "$status_out" | grep -q '^auto-routing: off$' && printf '%s\n' "$status_out" | grep -Fq "config: $unrelated_root/config.json"; } && ok "unrelated marketplace-like identity does not read inline config" || bad "unrelated identity read inline config ($status_out)"
[ "$enabled_rc" -eq 1 ] && [ -z "$enabled_out" ] && ok "unrelated identity is-enabled stays safely off" || bad "unrelated identity is-enabled read inline state (rc=$enabled_rc)"

arbitrary_root="$WORK/arbitrary/oh-no-harness-oh-no-harness"
arbitrary_inline="$WORK/arbitrary/oh-no-harness-inline"
mkdir -p "$arbitrary_root" "$arbitrary_inline"
cp "$inline_root/config.json" "$arbitrary_inline/config.json"
status_out="$(OH_NO_CONFIG_DIR="$arbitrary_root" "$TARGET/scripts/oh-no-config" status)"
printf '%s\n' "$status_out" | grep -q '^auto-routing: off$' && printf '%s\n' "$status_out" | grep -Fq "config: $arbitrary_root/config.json" && ok "arbitrary OH_NO_CONFIG_DIR does not gain inline sibling read-through" || bad "arbitrary OH_NO_CONFIG_DIR read inline sibling ($status_out)"

xdg_root="$WORK/xdg"
mkdir -p "$xdg_root/oh-no-harness-inline"
cp "$inline_root/config.json" "$xdg_root/oh-no-harness-inline/config.json"
status_out="$(without_ambient_oh_no_config HOME="$WORK/no-claude-home" XDG_CONFIG_HOME="$xdg_root" "$TARGET/scripts/oh-no-config" status)"
printf '%s\n' "$status_out" | grep -q '^auto-routing: off$' && printf '%s\n' "$status_out" | grep -Fq "config: $xdg_root/oh-no-harness/config.json" && ok "XDG fallback root does not read an inline-named sibling" || bad "XDG root read inline sibling ($status_out)"
teardown_fixture

# A present canonical pathname is authoritative even when it is not a regular
# file. Status/is-enabled stay safely off instead of consulting stale legacy data.
echo "== CR-3 oh-no-config: non-regular canonical path blocks legacy fallback =="
setup_cache_identity_fixture
config_home="$CACHE_HOME"
canonical_config="$CANONICAL_DATA_ROOT/config.json"
legacy_config="$LEGACY_DATA_ROOT/config.json"
cat >"$legacy_config" <<'JSON'
{
  "autoRouting": {
    "enabled": true
  }
}
JSON
mkdir "$canonical_config"
status_out="$(without_ambient_oh_no_config CLAUDE_CONFIG_DIR="$config_home" "$TARGET/scripts/oh-no-config" status)"; status_rc=$?
enabled_out="$(without_ambient_oh_no_config CLAUDE_CONFIG_DIR="$config_home" "$TARGET/scripts/oh-no-config" is-enabled)"; enabled_rc=$?
{ [ "$status_rc" -eq 0 ] && printf '%s\n' "$status_out" | grep -q '^auto-routing: off$' && printf '%s\n' "$status_out" | grep -Fq "config: $canonical_config"; } && ok "canonical config directory is authoritative and safely off" || bad "canonical directory fell through to legacy ($status_out)"
[ "$enabled_rc" -eq 1 ] && [ -z "$enabled_out" ] && ok "canonical config directory makes is-enabled fail safely" || bad "canonical directory is-enabled read legacy (rc=$enabled_rc)"
rmdir "$canonical_config"
ln -s "$WORK/missing-config-target" "$canonical_config"
status_out="$(without_ambient_oh_no_config CLAUDE_CONFIG_DIR="$config_home" "$TARGET/scripts/oh-no-config" status)"; status_rc=$?
enabled_out="$(without_ambient_oh_no_config CLAUDE_CONFIG_DIR="$config_home" "$TARGET/scripts/oh-no-config" is-enabled)"; enabled_rc=$?
{ [ "$status_rc" -eq 0 ] && printf '%s\n' "$status_out" | grep -q '^auto-routing: off$' && printf '%s\n' "$status_out" | grep -Fq "config: $canonical_config"; } && ok "dangling canonical config symlink is authoritative and safely off" || bad "dangling canonical symlink fell through to legacy ($status_out)"
[ "$enabled_rc" -eq 1 ] && [ -z "$enabled_out" ] && ok "dangling canonical symlink makes is-enabled fail safely" || bad "dangling canonical symlink is-enabled read legacy (rc=$enabled_rc)"
[ -L "$canonical_config" ] && [ "$(readlink "$canonical_config")" = "$WORK/missing-config-target" ] && ok "non-regular precedence checks do not mutate canonical path" || bad "non-regular precedence mutated canonical path"
teardown_fixture

# A valid legacy schema-2 preference must be visible to read-only check when the
# canonical cache identity has no preferences. Check must not populate canonical state.
echo "== check: valid legacy preferences report legacy-unmigrated without canonical writes =="
setup_cache_identity_fixture
migration_home="$CACHE_HOME"
canonical_fixture="$CANONICAL_DATA_ROOT"
legacy_fixture="$LEGACY_DATA_ROOT"
cat >"$legacy_fixture/subagent-models.conf" <<'PREFS'
schema_version=2
proxy=yes
secondary_top_model=fable
top_tier_models=fable opus gpt-5.6-sol
assignment=explore,gpt-5.6-sol,high
assignment=analyst,opus,xhigh
assignment=planner,opus,max
assignment=plan-reviewer,opus,xhigh
assignment=executor,opus,high
assignment=debugger,opus,xhigh
assignment=verifier,sonnet,high
assignment=code-reviewer,opus,xhigh
assignment=fusion-rescue-analyst,opus,xhigh
PREFS
canonical_before="$(find "$canonical_fixture" -mindepth 1 -print | LC_ALL=C sort | shasum)"
legacy_before="$(shasum "$legacy_fixture/subagent-models.conf")"
status="$(without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" "$TARGET/scripts/configure-subagents" check | grep '^STATUS:')"
[ "$status" = "STATUS: legacy-unmigrated" ] && ok "check reports legacy-unmigrated when only valid legacy preferences exist" || bad "legacy-only check status ($status)"
[ "$canonical_before" = "$(find "$canonical_fixture" -mindepth 1 -print | LC_ALL=C sort | shasum)" ] && [ ! -e "$canonical_fixture/subagent-models.conf" ] && ok "legacy-only check leaves canonical state absent and unchanged" || bad "legacy-only check mutated canonical state"
[ "$legacy_before" = "$(shasum "$legacy_fixture/subagent-models.conf")" ] && ok "legacy-only check leaves legacy preferences unchanged" || bad "legacy-only check mutated legacy preferences"
teardown_fixture

# Legacy preference discovery is limited to the one supported canonical cache
# identity. Marketplace-like siblings and arbitrary override roots stay isolated.
echo "== CR-2 configure-subagents: legacy import is exact-identity only =="
setup_fixture
identity_data="$WORK/plugins/data"
unrelated_fixture="$identity_data/oh-no-harness-unrelated"
legacy_fixture="$identity_data/oh-no-harness-inline"
mkdir -p "$unrelated_fixture" "$legacy_fixture"
cat >"$legacy_fixture/subagent-models.conf" <<'PREFS'
schema_version=2
proxy=no
secondary_top_model=
top_tier_models=fable opus
assignment=explore,sonnet,high
assignment=analyst,opus,xhigh
assignment=planner,opus,max
assignment=plan-reviewer,opus,xhigh
assignment=executor,opus,high
assignment=debugger,opus,xhigh
assignment=verifier,sonnet,high
assignment=code-reviewer,opus,xhigh
assignment=fusion-rescue-analyst,opus,xhigh
PREFS
legacy_before="$(shasum "$legacy_fixture/subagent-models.conf")"
agents_before="$(hash_agents)"
status="$(TMPDIR="$STAGE_PARENT" OH_NO_CONFIG_DIR="$unrelated_fixture" "$TARGET/scripts/configure-subagents" check | grep '^STATUS:')"
[ "$status" = "STATUS: unconfigured" ] && ok "unrelated marketplace-like identity does not discover inline preferences" || bad "unrelated identity discovered inline preferences ($status)"
out="$(TMPDIR="$STAGE_PARENT" OH_NO_CONFIG_DIR="$unrelated_fixture" "$TARGET/scripts/configure-subagents" reapply --quiet 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "unrelated identity reapply remains a silent no-op" || bad "unrelated identity imported inline preferences (rc=$rc out=$out)"
[ ! -e "$unrelated_fixture/subagent-models.conf" ] && [ "$agents_before" = "$(hash_agents)" ] && [ "$legacy_before" = "$(shasum "$legacy_fixture/subagent-models.conf")" ] && ok "unrelated identity leaves canonical, runtime, and inline source unchanged" || bad "unrelated identity mutated preference state"

arbitrary_fixture="$WORK/arbitrary/oh-no-harness-oh-no-harness"
arbitrary_legacy="$WORK/arbitrary/oh-no-harness-inline"
mkdir -p "$arbitrary_fixture" "$arbitrary_legacy"
cp "$legacy_fixture/subagent-models.conf" "$arbitrary_legacy/subagent-models.conf"
status="$(TMPDIR="$STAGE_PARENT" OH_NO_CONFIG_DIR="$arbitrary_fixture" "$TARGET/scripts/configure-subagents" check | grep '^STATUS:')"
[ "$status" = "STATUS: unconfigured" ] && ok "arbitrary OH_NO_CONFIG_DIR does not gain inline preference discovery" || bad "arbitrary OH_NO_CONFIG_DIR discovered inline preferences ($status)"
teardown_fixture

# A supported reapply imports valid legacy preferences once, applies them, and
# preserves the legacy source. A second reapply must be a matching no-op.
echo "== reapply: imports valid legacy preferences once and preserves source =="
setup_cache_identity_fixture
migration_home="$CACHE_HOME"
canonical_fixture="$CANONICAL_DATA_ROOT"
legacy_fixture="$LEGACY_DATA_ROOT"
cat >"$legacy_fixture/subagent-models.conf" <<'PREFS'
schema_version=2
proxy=yes
secondary_top_model=fable
top_tier_models=fable opus gpt-5.6-sol
assignment=explore,gpt-5.6-sol,high
assignment=analyst,opus,xhigh
assignment=planner,opus,max
assignment=plan-reviewer,opus,xhigh
assignment=executor,opus,high
assignment=debugger,opus,xhigh
assignment=verifier,sonnet,high
assignment=code-reviewer,opus,xhigh
assignment=fusion-rescue-analyst,opus,xhigh
PREFS
legacy_before="$(shasum "$legacy_fixture/subagent-models.conf")"
[ ! -e "$canonical_fixture/subagent-models.conf" ] && ok "legacy import starts without canonical preferences" || bad "legacy import fixture unexpectedly has canonical preferences"
out="$(without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" "$TARGET/scripts/configure-subagents" reapply --quiet)"; rc=$?
[ "$rc" -eq 0 ] && ok "legacy import reapply exits 0" || bad "legacy import reapply exit (rc=$rc)"
{ [ -f "$canonical_fixture/subagent-models.conf" ] && grep -q '^schema_version=2$' "$canonical_fixture/subagent-models.conf" && grep -q '^assignment=explore,gpt-5.6-sol,high$' "$canonical_fixture/subagent-models.conf"; } && ok "reapply imports valid legacy preferences into canonical storage" || bad "reapply did not import valid legacy preferences"
{ grep -q '^model: gpt-5.6-sol$' "$TARGET/agents/explore.md" && grep -q '^effort: high$' "$TARGET/agents/explore.md"; } && ok "legacy import applies explore=gpt-5.6-sol,high to runtime" || bad "legacy import did not apply explore model and effort"
[ "$legacy_before" = "$(shasum "$legacy_fixture/subagent-models.conf")" ] && ok "legacy import leaves source preferences present and byte-identical" || bad "legacy import changed legacy source preferences"
[ ! -e "$canonical_fixture/subagent-journal.conf" ] && [ ! -e "$canonical_fixture/subagent-lock.d" ] && ok "legacy import leaves no journal or lock" || bad "legacy import left partial transaction state"
status="$(without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" "$TARGET/scripts/configure-subagents" check | grep '^STATUS:')"
[ "$status" = "STATUS: matching" ] && ok "legacy import converges to matching canonical state" || bad "legacy import post-check status ($status)"
agents_after_first="$(hash_agents)"
if [ -f "$canonical_fixture/subagent-models.conf" ]; then canonical_after_first="$(shasum "$canonical_fixture/subagent-models.conf")"; else canonical_after_first=absent; fi
backups_after_first="$(find "$canonical_fixture/subagent-backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
out="$(without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" "$TARGET/scripts/configure-subagents" reapply --quiet)"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "repeated legacy import reapply is a silent matching no-op" || bad "repeated legacy import reapply was not a silent no-op (rc=$rc)"
if [ -f "$canonical_fixture/subagent-models.conf" ]; then canonical_after_second="$(shasum "$canonical_fixture/subagent-models.conf")"; else canonical_after_second=absent; fi
backups_after_second="$(find "$canonical_fixture/subagent-backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
status="$(without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" "$TARGET/scripts/configure-subagents" check | grep '^STATUS:')"
[ "$status" = "STATUS: matching" ] && ok "repeated legacy import remains matching" || bad "repeated legacy import status ($status)"
[ "$agents_after_first" = "$(hash_agents)" ] && [ "$canonical_after_first" = "$canonical_after_second" ] && ok "repeated legacy import changes neither runtime nor canonical preferences" || bad "repeated legacy import mutated matching state"
[ "$backups_after_first" = "$backups_after_second" ] && ok "repeated legacy import creates no unnecessary backup" || bad "repeated legacy import created another backup"
[ "$legacy_before" = "$(shasum "$legacy_fixture/subagent-models.conf")" ] && ok "repeated legacy import still preserves legacy source" || bad "repeated legacy import changed legacy source"
teardown_fixture

# Once import has captured legacy A under the canonical lock, an atomic pathname
# replacement with valid B during the runtime transaction must not split runtime
# and canonical publication. The replacement remains untouched and is reported
# through the existing coexistence-conflict status.
echo "== CR-1 legacy import: runtime and canonical publish one locked snapshot =="
setup_cache_identity_fixture
migration_home="$CACHE_HOME"
canonical_fixture="$CANONICAL_DATA_ROOT"
legacy_fixture="$LEGACY_DATA_ROOT"
legacy_path="$legacy_fixture/subagent-models.conf"
cat >"$legacy_path" <<'PREFS_A'
schema_version=2
proxy=yes
secondary_top_model=fable
top_tier_models=fable opus gpt-5.6-sol
assignment=explore,gpt-5.6-sol,high
assignment=analyst,opus,xhigh
assignment=planner,opus,max
assignment=plan-reviewer,opus,xhigh
assignment=executor,opus,high
assignment=debugger,opus,xhigh
assignment=verifier,sonnet,high
assignment=code-reviewer,opus,xhigh
assignment=fusion-rescue-analyst,opus,xhigh
PREFS_A
cp "$legacy_path" "$WORK/legacy-a.conf"
cat >"$WORK/legacy-b.conf" <<'PREFS_B'
schema_version=2
proxy=no
secondary_top_model=
top_tier_models=fable opus
assignment=explore,opus,max
assignment=analyst,sonnet,high
assignment=planner,sonnet,high
assignment=plan-reviewer,sonnet,high
assignment=executor,sonnet,high
assignment=debugger,sonnet,high
assignment=verifier,opus,max
assignment=code-reviewer,sonnet,high
assignment=fusion-rescue-analyst,sonnet,high
PREFS_B
cp "$WORK/legacy-b.conf" "$WORK/legacy-b.expected"
# Keep the process inside the journaled transaction long enough for the test to
# observe that boundary without a production timing hook.
"$PYTHON" - "$TARGET/agents/analyst.md" <<'PY'
import sys
with open(sys.argv[1], "ab") as f:
    chunk = (b"snapshot-race-padding-" * 128) + b"\n"
    for _ in range(32768):
        f.write(chunk)
PY
reapply_out="$WORK/reapply.out"
reapply_err="$WORK/reapply.err"
without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" "$TARGET/scripts/configure-subagents" reapply --quiet >"$reapply_out" 2>"$reapply_err" & import_pid=$!
swapped=0
while kill -0 "$import_pid" 2>/dev/null; do
  if [ -f "$canonical_fixture/subagent-journal.conf" ]; then
    mv "$WORK/legacy-b.conf" "$legacy_path"
    swapped=1
    break
  fi
done
wait "$import_pid"; import_rc=$?
[ "$swapped" -eq 1 ] && ok "legacy pathname replaced after the journaled transaction began" || bad "did not observe the transaction boundary before import completed"
[ "$import_rc" -eq 0 ] && ok "snapshot import completes after concurrent legacy replacement" || bad "snapshot import failed (rc=$import_rc err=$(cat "$reapply_err"))"
{ [ -f "$canonical_fixture/subagent-models.conf" ] && cmp -s "$canonical_fixture/subagent-models.conf" "$WORK/legacy-a.conf"; } && ok "canonical publication preserves exact snapshot-A bytes" || bad "canonical preferences did not publish snapshot A"
cmp -s "$legacy_path" "$WORK/legacy-b.expected" && ok "legacy replacement B remains byte-identical at the live source pathname" || bad "legacy replacement B was changed or removed"
{ grep -q '^model: gpt-5.6-sol$' "$TARGET/agents/explore.md" && grep -q '^effort: high$' "$TARGET/agents/explore.md"; } && ok "runtime converges from snapshot A" || bad "runtime did not converge from snapshot A"
status="$(without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" "$TARGET/scripts/configure-subagents" check | grep '^STATUS:')"
[ "$status" = "STATUS: preference-conflict" ] && ok "post-import status coherently reports untouched replacement B conflict" || bad "post-import status is inconsistent ($status)"
[ ! -e "$canonical_fixture/subagent-journal.conf" ] && [ ! -e "$canonical_fixture/subagent-lock.d" ] && [ -z "$(find "$canonical_fixture" -maxdepth 1 -name '.subagent-legacy-snapshot.*' -print -quit)" ] && ok "snapshot import leaves no journal, lock, or private snapshot residue" || bad "snapshot import left transaction residue"
teardown_fixture

# A hard crash after journal publication must keep the immutable import snapshot
# inside the owned lock lifecycle. Supported recovery reclaims that exact stale
# lock, converges from the still-live legacy source, and leaves no import residue.
echo "== V-1 legacy import: hard-crash recovery reclaims lock-owned snapshot =="
setup_cache_identity_fixture
migration_home="$CACHE_HOME"
canonical_fixture="$CANONICAL_DATA_ROOT"
legacy_fixture="$LEGACY_DATA_ROOT"
legacy_path="$legacy_fixture/subagent-models.conf"
cat >"$legacy_path" <<'PREFS'
schema_version=2
proxy=yes
secondary_top_model=fable
top_tier_models=fable opus gpt-5.6-sol
assignment=explore,gpt-5.6-sol,high
assignment=analyst,opus,xhigh
assignment=planner,opus,max
assignment=plan-reviewer,opus,xhigh
assignment=executor,opus,high
assignment=debugger,opus,xhigh
assignment=verifier,sonnet,high
assignment=code-reviewer,opus,xhigh
assignment=fusion-rescue-analyst,opus,xhigh
PREFS
legacy_before="$(shasum "$legacy_path")"
without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" OH_NO_CONFIGURE_CRASH_AFTER=3 "$TARGET/scripts/configure-subagents" reapply --quiet >/dev/null 2>&1
crash_rc=$?
[ "$crash_rc" -ne 0 ] && ok "legacy import hard crash exits nonzero" || bad "legacy import hard crash unexpectedly completed"
lock_snapshot="$canonical_fixture/subagent-lock.d/legacy-prefs.snapshot"
lock_hold="$canonical_fixture/subagent-lock.d/legacy-prefs.hold"
{ [ -f "$canonical_fixture/subagent-lock.d/owner" ] && [ -f "$lock_snapshot" ] && [ ! -e "$lock_hold" ]; } && ok "post-journal crash retains only the exact lock-owned snapshot beside owner metadata" || bad "post-journal crash did not retain the exact lock-owned snapshot lifecycle"
[ -f "$canonical_fixture/subagent-journal.conf" ] && ok "legacy import hard crash retains its recovery journal" || bad "legacy import hard crash lost its recovery journal"
without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" "$TARGET/scripts/configure-subagents" reapply --quiet >/dev/null; recovery_rc=$?
[ "$recovery_rc" -eq 0 ] && ok "supported reapply recovers and completes legacy import" || bad "supported legacy-import recovery failed (rc=$recovery_rc)"
{ [ -f "$canonical_fixture/subagent-models.conf" ] && cmp -s "$canonical_fixture/subagent-models.conf" "$legacy_path"; } && ok "hard-crash recovery publishes exact live legacy bytes canonically" || bad "hard-crash recovery did not publish exact legacy bytes"
{ grep -q '^model: gpt-5.6-sol$' "$TARGET/agents/explore.md" && grep -q '^effort: high$' "$TARGET/agents/explore.md"; } && ok "hard-crash recovery converges runtime from legacy preferences" || bad "hard-crash recovery did not converge runtime"
[ "$legacy_before" = "$(shasum "$legacy_path")" ] && [ -f "$legacy_path" ] && [ ! -L "$legacy_path" ] && ok "hard-crash recovery preserves the live legacy source path and bytes" || bad "hard-crash recovery changed the live legacy source"
status="$(without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" "$TARGET/scripts/configure-subagents" check | grep '^STATUS:')"
[ "$status" = "STATUS: matching" ] && ok "hard-crash recovery reaches matching state" || bad "hard-crash recovery status ($status)"
import_residue="$(find "$canonical_fixture" -maxdepth 2 \( -name '.subagent-legacy-hold.*' -o -name '.subagent-legacy-snapshot.*' -o -name 'legacy-prefs.hold' -o -name 'legacy-prefs.snapshot' \) -print -quit)"
[ ! -e "$canonical_fixture/subagent-journal.conf" ] && [ ! -e "$canonical_fixture/subagent-lock.d" ] && [ -z "$import_residue" ] && ok "supported recovery leaves no journal, lock, or legacy-import transient residue" || bad "supported recovery left legacy-import transaction residue"
teardown_fixture

# Canonical preferences retain precedence when a valid legacy source coexists:
# identical bytes are benign, while different valid preferences fail closed.
echo "== coexistence: identical legacy is benign; different valid legacy conflicts =="
setup_cache_identity_fixture
migration_home="$CACHE_HOME"
canonical_fixture="$CANONICAL_DATA_ROOT"
legacy_fixture="$LEGACY_DATA_ROOT"
without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" "$TARGET/scripts/configure-subagents" apply --proxy no $(native_assignments) >/dev/null
cp "$canonical_fixture/subagent-models.conf" "$legacy_fixture/subagent-models.conf"
canonical_before="$(shasum "$canonical_fixture/subagent-models.conf")"
legacy_before="$(shasum "$legacy_fixture/subagent-models.conf")"
agents_before="$(hash_agents)"
backups_before="$(find "$canonical_fixture/subagent-backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
status="$(without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" "$TARGET/scripts/configure-subagents" check | grep '^STATUS:')"
[ "$status" = "STATUS: matching" ] && ok "byte-identical canonical and legacy preferences remain matching" || bad "identical coexistence check status ($status)"
out="$(without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" "$TARGET/scripts/configure-subagents" reapply --quiet)"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "identical coexistence reapply is a silent canonical no-op" || bad "identical coexistence reapply changed behavior (rc=$rc)"
backups_after="$(find "$canonical_fixture/subagent-backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
[ "$canonical_before" = "$(shasum "$canonical_fixture/subagent-models.conf")" ] && [ "$legacy_before" = "$(shasum "$legacy_fixture/subagent-models.conf")" ] && [ "$agents_before" = "$(hash_agents)" ] && [ "$backups_before" = "$backups_after" ] && ok "identical coexistence mutates no canonical, legacy, runtime, or backup state" || bad "identical coexistence mutated state"
[ ! -e "$canonical_fixture/subagent-journal.conf" ] && [ ! -e "$canonical_fixture/subagent-lock.d" ] && ok "identical coexistence leaves no journal or lock" || bad "identical coexistence left transaction state"
teardown_fixture

setup_cache_identity_fixture
migration_home="$CACHE_HOME"
canonical_fixture="$CANONICAL_DATA_ROOT"
legacy_fixture="$LEGACY_DATA_ROOT"
without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" "$TARGET/scripts/configure-subagents" apply --proxy no $(native_assignments) >/dev/null
cat >"$legacy_fixture/subagent-models.conf" <<'PREFS'
schema_version=2
proxy=no
secondary_top_model=
top_tier_models=fable opus
assignment=explore,opus,max
assignment=analyst,sonnet,high
assignment=planner,sonnet,high
assignment=plan-reviewer,sonnet,high
assignment=executor,sonnet,high
assignment=debugger,sonnet,high
assignment=verifier,opus,max
assignment=code-reviewer,sonnet,high
assignment=fusion-rescue-analyst,sonnet,high
PREFS
canonical_before="$(shasum "$canonical_fixture/subagent-models.conf")"
legacy_before="$(shasum "$legacy_fixture/subagent-models.conf")"
agents_before="$(hash_agents)"
backups_before="$(find "$canonical_fixture/subagent-backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
status="$(without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" "$TARGET/scripts/configure-subagents" check | grep '^STATUS:')"
[ "$status" = "STATUS: preference-conflict" ] && ok "different valid canonical and legacy preferences report conflict" || bad "different-valid coexistence check status ($status)"
[ "$canonical_before" = "$(shasum "$canonical_fixture/subagent-models.conf")" ] && [ "$legacy_before" = "$(shasum "$legacy_fixture/subagent-models.conf")" ] && [ "$agents_before" = "$(hash_agents)" ] && ok "conflict check is read-only for canonical, legacy, and runtime state" || bad "conflict check mutated state"
conflict_out="$(without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" "$TARGET/scripts/configure-subagents" reapply --quiet 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && [ "$conflict_out" = "configure-subagents: canonical and legacy subagent preferences conflict; reapply skipped." ] && ok "conflicting reapply fails with a fixed value-free diagnostic" || bad "conflicting reapply did not fail closed (rc=$rc)"
backups_after="$(find "$canonical_fixture/subagent-backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
[ "$canonical_before" = "$(shasum "$canonical_fixture/subagent-models.conf")" ] && [ "$legacy_before" = "$(shasum "$legacy_fixture/subagent-models.conf")" ] && [ "$agents_before" = "$(hash_agents)" ] && [ "$backups_before" = "$backups_after" ] && ok "conflicting reapply preserves canonical, legacy, runtime, and backup state" || bad "conflicting reapply mutated state"
[ ! -e "$canonical_fixture/subagent-journal.conf" ] && [ ! -e "$canonical_fixture/subagent-lock.d" ] && ok "conflicting reapply leaves no journal or lock" || bad "conflicting reapply left transaction state"
teardown_fixture

# Present invalid or unsafe legacy sources are distinct from true absence. Keep
# the five required classes compact while checking the same public behavior.
echo "== legacy validation: invalid and unsafe sources fail closed; absence stays unconfigured =="
write_complete_legacy_prefs() {
  local path="$1" schema="$2" proxy="$3" explore_assignment="${4:-explore,sonnet,high}"
  cat >"$path" <<PREFS
schema_version=$schema
proxy=$proxy
secondary_top_model=
top_tier_models=fable opus
assignment=$explore_assignment
assignment=analyst,opus,xhigh
assignment=planner,opus,max
assignment=plan-reviewer,opus,xhigh
assignment=executor,opus,high
assignment=debugger,opus,xhigh
assignment=verifier,sonnet,high
assignment=code-reviewer,opus,xhigh
assignment=fusion-rescue-analyst,opus,xhigh
PREFS
}

# Complete records may be separated by blank lines and comments whose first
# non-whitespace character is '#'; valid import preserves every source byte.
echo "== V-2 legacy grammar: comments and blank lines remain byte-exact =="
setup_cache_identity_fixture
migration_home="$CACHE_HOME"
canonical_fixture="$CANONICAL_DATA_ROOT"
legacy_fixture="$LEGACY_DATA_ROOT"
legacy_path="$legacy_fixture/subagent-models.conf"
cat >"$legacy_path" <<'PREFS'
# supported leading comment

schema_version=2
  # supported indented comment
proxy=no
secondary_top_model=
top_tier_models=fable opus

assignment=explore,sonnet,high
assignment=analyst,opus,xhigh
assignment=planner,opus,max
assignment=plan-reviewer,opus,xhigh
assignment=executor,opus,high
assignment=debugger,opus,xhigh
assignment=verifier,sonnet,high
assignment=code-reviewer,opus,xhigh
assignment=fusion-rescue-analyst,opus,xhigh

PREFS
cp "$legacy_path" "$WORK/comments-blanks.expected"
status="$(without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" "$TARGET/scripts/configure-subagents" check | grep '^STATUS:')"
[ "$status" = "STATUS: legacy-unmigrated" ] && ok "comments/blanks legacy fixture is recognized as valid" || bad "comments/blanks legacy status ($status)"
without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" "$TARGET/scripts/configure-subagents" reapply --quiet >/dev/null; rc=$?
[ "$rc" -eq 0 ] && [ -f "$canonical_fixture/subagent-models.conf" ] && cmp -s "$canonical_fixture/subagent-models.conf" "$WORK/comments-blanks.expected" && ok "comments/blanks import remains byte-identical canonically" || bad "comments/blanks import changed source bytes"
teardown_fixture

invalid_legacy_case() {
  local label="$1" mode="$2"
  setup_cache_identity_fixture
  local migration_home="$CACHE_HOME"
  local canonical_fixture="$CANONICAL_DATA_ROOT"
  local legacy_fixture="$LEGACY_DATA_ROOT"
  local legacy_path="$legacy_fixture/subagent-models.conf"
  local target_path="$WORK/symlink-target.conf"
  local synthetic_value="synthetic-credential-value-v2"
  case "$mode" in
    invalid) write_complete_legacy_prefs "$legacy_path" 2 maybe ;;
    incomplete) printf 'schema_version=2\nproxy=no\n' >"$legacy_path" ;;
    unsupported) write_complete_legacy_prefs "$legacy_path" 1 no ;;
    unknown-record) write_complete_legacy_prefs "$legacy_path" 2 no; printf 'SYNTHETIC_AUTH_TOKEN=%s\n' "$synthetic_value" >>"$legacy_path" ;;
    extra-equals) write_complete_legacy_prefs "$legacy_path" "2=$synthetic_value" no ;;
    assignment-two) write_complete_legacy_prefs "$legacy_path" 2 no 'explore,high' ;;
    assignment-four) write_complete_legacy_prefs "$legacy_path" 2 no "explore,sonnet,$synthetic_value,high" ;;
    symlink) write_complete_legacy_prefs "$target_path" 2 no; ln -s "$target_path" "$legacy_path" ;;
    non-regular) mkdir "$legacy_path" ;;
    absent) ;;
  esac

  local canonical_before agents_before legacy_before="" target_before=""
  canonical_before="$(find "$canonical_fixture" -mindepth 1 -print | LC_ALL=C sort | shasum)"
  agents_before="$(hash_agents)"
  case "$mode" in
    invalid|incomplete|unsupported|unknown-record|extra-equals|assignment-two|assignment-four) legacy_before="$(shasum "$legacy_path")" ;;
    symlink) legacy_before="$(readlink "$legacy_path")"; target_before="$(shasum "$target_path")" ;;
  esac

  local status out rc
  status="$(without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" "$TARGET/scripts/configure-subagents" check | grep '^STATUS:')"
  if [ "$mode" = absent ]; then
    [ "$status" = "STATUS: unconfigured" ] && ok "$label: absent legacy remains unconfigured" || bad "$label: absent legacy check status ($status)"
  else
    [ "$status" = "STATUS: invalid-legacy-preferences" ] && ok "$label: check reports invalid-legacy-preferences" || bad "$label: check status ($status)"
  fi
  out="$(without_ambient_oh_no_config TMPDIR="$STAGE_PARENT" CLAUDE_CONFIG_DIR="$migration_home" "$TARGET/scripts/configure-subagents" reapply --quiet 2>&1)"; rc=$?
  if [ "$mode" = absent ]; then
    [ "$rc" -eq 0 ] && [ -z "$out" ] && ok "$label: absent legacy reapply stays silent" || bad "$label: absent legacy reapply changed (rc=$rc)"
  else
    [ "$rc" -ne 0 ] && [ "$out" = "configure-subagents: legacy subagent preferences are invalid or unsafe; reapply skipped." ] && ok "$label: reapply fails with fixed invalid-legacy diagnostic" || bad "$label: reapply did not fail closed (rc=$rc)"
    { ! printf '%s' "$out" | grep -Fq "$legacy_path" && ! printf '%s' "$out" | grep -Fq "$synthetic_value"; } && ok "$label: diagnostic is path-free and synthetic-value-free" || bad "$label: diagnostic leaked a path or synthetic value"
  fi

  local legacy_unchanged=0
  case "$mode" in
    invalid|incomplete|unsupported|unknown-record|extra-equals|assignment-two|assignment-four) [ -f "$legacy_path" ] && [ ! -L "$legacy_path" ] && [ "$legacy_before" = "$(shasum "$legacy_path")" ] && legacy_unchanged=1 ;;
    symlink) [ -L "$legacy_path" ] && [ "$legacy_before" = "$(readlink "$legacy_path")" ] && [ "$target_before" = "$(shasum "$target_path")" ] && legacy_unchanged=1 ;;
    non-regular) [ -d "$legacy_path" ] && [ -z "$(find "$legacy_path" -mindepth 1 -print -quit)" ] && legacy_unchanged=1 ;;
    absent) [ ! -e "$legacy_path" ] && [ ! -L "$legacy_path" ] && legacy_unchanged=1 ;;
  esac
  [ "$canonical_before" = "$(find "$canonical_fixture" -mindepth 1 -print | LC_ALL=C sort | shasum)" ] && [ "$agents_before" = "$(hash_agents)" ] && [ "$legacy_unchanged" = 1 ] && ok "$label: canonical, runtime, backup, transaction, and legacy state unchanged" || bad "$label: invalid legacy handling mutated state"
  teardown_fixture
}
invalid_legacy_case "invalid current schema" invalid
invalid_legacy_case "incomplete current schema" incomplete
invalid_legacy_case "unsupported schema" unsupported
invalid_legacy_case "unknown credential-shaped record" unknown-record
invalid_legacy_case "known record with extra equals suffix" extra-equals
invalid_legacy_case "assignment with two fields" assignment-two
invalid_legacy_case "assignment with four fields" assignment-four
invalid_legacy_case "symlinked preference path" symlink
invalid_legacy_case "non-regular preference path" non-regular
invalid_legacy_case "absent preference path guard" absent

# Always-injected model-diversity block branches.
echo "== SessionStart model-diversity injection branches (no secondary, no preferences, degenerate) =="
setup_fixture
run apply --proxy no --top-tier-models "fable opus" $(native_assignments) >/dev/null
hook_out="$(run_hook)"
printf '%s' "$hook_out" | grep -q '<OH_NO_MODEL_DIVERSITY>' && ok "no-secondary prefs inject diversity block" || bad "no-secondary block missing"
printf '%s' "$hook_out" | grep -q 'top_tier_models=fable opus' && ok "no-secondary block uses prefs top-tier list" || bad "no-secondary top-tier missing"
printf '%s' "$hook_out" | grep -q 'effective_primaries=.*code-reviewer:opus' && ok "no-secondary block includes primaries" || bad "no-secondary primaries missing"
printf '%s' "$hook_out" | grep -q 'secondary_top_model=' && bad "no-secondary block emitted secondary line" || ok "no-secondary block omits secondary line"
teardown_fixture
setup_fixture
run apply --proxy yes --top-tier-models "gpt-5.6-sol opus" $(gpt_assignments) >/dev/null
hook_out="$(run_hook)"
printf '%s' "$hook_out" | grep -q 'top_tier_models=gpt-5.6-sol opus' && ok "mixed GPT/native list retained for adapter first-native fallback" || bad "mixed GPT/native injected list changed"
printf '%s' "$hook_out" | grep -q 'effective_primaries=.*code-reviewer:opus' && ok "mixed GPT/native block retains concrete primaries" || bad "mixed GPT/native primaries missing"
teardown_fixture
setup_fixture
cat >"$CFG/subagent-models.conf" <<'PREFS'
schema_version=2
proxy=yes
secondary_top_model=
top_tier_models=gpt-5.6-sol gpt-5.6-terra
assignment=explore,gpt-5.6-terra,medium
assignment=analyst,gpt-5.6-sol,high
assignment=planner,opus,max
assignment=plan-reviewer,opus,xhigh
assignment=executor,opus,high
assignment=debugger,opus,xhigh
assignment=verifier,sonnet,high
assignment=code-reviewer,opus,xhigh
assignment=fusion-rescue-analyst,opus,xhigh
PREFS
hook_out="$(run_hook)"
printf '%s' "$hook_out" | grep -q 'top_tier_models=fable opus' && ok "hand-written all-GPT prefs degrade to DEFAULT_TOP_TIER_MODELS" || bad "all-GPT prefs did not degrade to default top-tier list"
printf '%s' "$hook_out" | grep -q 'gpt-5.6-' && bad "all-GPT prefs leaked into injected diversity block" || ok "all-GPT prefs omitted from injected diversity block"
printf '%s' "$hook_out" | grep -q 'effective_primaries=plan-reviewer:host-default code-reviewer:host-default' && ok "all-GPT prefs degrade all primaries with malformed-prefs path" || bad "all-GPT prefs did not use malformed-prefs fallback"
teardown_fixture
setup_fixture
hook_out="$(run_hook)"
printf '%s' "$hook_out" | grep -q '<OH_NO_MODEL_DIVERSITY>' && ok "no-prefs injects diversity block" || bad "no-prefs block missing"
printf '%s' "$hook_out" | grep -q 'top_tier_models=fable opus' && ok "no-prefs block uses DEFAULT_TOP_TIER_MODELS" || bad "no-prefs default top-tier missing"
printf '%s' "$hook_out" | grep -q 'effective_primaries=plan-reviewer:host-default code-reviewer:host-default' && ok "no-prefs block uses host-default primaries" || bad "no-prefs primaries missing"
teardown_fixture
setup_fixture
run apply --proxy no --secondary-top-model fable --top-tier-models "fable" $(native_assignments) >/dev/null
hook_out="$(run_hook)"
printf '%s' "$hook_out" | grep -q 'top_tier_models=fable' && ok "degenerate prefs inject singleton top-tier list" || bad "degenerate top-tier missing"
printf '%s' "$hook_out" | grep -q 'secondary_top_model=fable' && ok "degenerate prefs inject validated secondary" || bad "degenerate secondary missing"
teardown_fixture
# no stored preferences
setup_fixture
hook_out="$(run_hook)"
valid_json "$hook_out" && ok "SessionStart emits valid JSON with no config" || bad "SessionStart JSON invalid with no config"
printf '%s' "$hook_out" | grep -qi 'subagent model configuration' && bad "no-config SessionStart added a spurious notice" || ok "no-config SessionStart adds no reapply notice"
teardown_fixture
# configured + drifted -> repair + fixed success notice
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
cp "$CANONICAL_AGENTS/planner.md" "$TARGET/agents/planner.md"
hook_out="$(run_hook)"
valid_json "$hook_out" && ok "SessionStart emits valid JSON on repair" || bad "SessionStart JSON invalid on repair"
oracle "$CANONICAL_AGENTS/planner.md" opus max "$EXP/planner.md"
cmp -s "$TARGET/agents/planner.md" "$EXP/planner.md" && ok "SessionStart reapply repaired drifted agent (cmp)" || bad "SessionStart reapply did not repair"
printf '%s' "$hook_out" | grep -qi 'session\|/clear' && ok "SessionStart repair notice mentions session/clear" || bad "SessionStart repair notice missing"
teardown_fixture
# reapply failure during the hook -> valid JSON + fixed credential/path-free notice
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
for role in "${ROLES[@]}"; do cp "$CANONICAL_AGENTS/$role.md" "$TARGET/agents/$role.md"; done
hook_out="$(run_hook OH_NO_CONFIGURE_FAIL_AFTER=3)"
valid_json "$hook_out" && ok "SessionStart emits valid JSON on reapply failure" || bad "SessionStart JSON invalid on failure"
printf '%s' "$hook_out" | grep -q 'could not reapply your saved subagent model configuration' && ok "failure path emits fixed credential-free warning" || bad "failure warning missing"
printf '%s' "$hook_out" | grep -qF "$TARGET" && bad "failure notice leaked a filesystem path" || ok "failure notice leaks no filesystem path"
printf '%s' "$hook_out" | grep -q 'AUTH_TOKEN\|BASE_URL\|Bearer' && bad "failure notice leaked credentials" || ok "failure notice leaks no credentials"
teardown_fixture
# invalid stored preferences during the hook -> fixed failure branch, no success
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
printf 'schema_version=999\nproxy=no\n' > "$CFG/subagent-models.conf"
hook_out="$(run_hook)"
valid_json "$hook_out" && ok "SessionStart emits valid JSON on invalid stored preferences" || bad "SessionStart JSON invalid on invalid prefs"
printf '%s' "$hook_out" | grep -q 'could not reapply your saved subagent model configuration' && ok "invalid-prefs hook takes the fixed failure branch" || bad "invalid-prefs failure notice missing"
printf '%s' "$hook_out" | grep -q 'reapplied your saved subagent model configuration' && bad "invalid-prefs hook emitted a false success notice" || ok "invalid-prefs hook emits no success notice"
teardown_fixture
# invalid runtime agent file during the hook -> fixed failure branch, no success
setup_fixture
run apply --proxy no $(native_assignments) >/dev/null
printf 'no frontmatter here\n' > "$TARGET/agents/verifier.md"
hook_out="$(run_hook)"
valid_json "$hook_out" && ok "SessionStart emits valid JSON on invalid runtime agents" || bad "SessionStart JSON invalid on invalid agents"
printf '%s' "$hook_out" | grep -q 'could not reapply your saved subagent model configuration' && ok "invalid-agents hook takes the fixed failure branch" || bad "invalid-agents failure notice missing"
printf '%s' "$hook_out" | grep -q 'reapplied your saved subagent model configuration' && bad "invalid-agents hook emitted a false success notice" || ok "invalid-agents hook emits no success notice"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== static contracts: human-only, no auto-routing, no Codex wrapper =="
grep -q '^disable-model-invocation: true$' "$SKILL_CORE" && ok "skill core sets disable-model-invocation: true" || bad "skill core flag"
grep -q '^disable-model-invocation: true$' "$SKILL_WRAPPER" && ok "generated SKILL.md sets disable-model-invocation: true" || bad "SKILL.md flag"
grep -q '^disable-model-invocation: true$' "$COMMAND_WRAPPER" && ok "command wrapper sets disable-model-invocation: true" || bad "command wrapper flag"
[ ! -e "$CODEX_WRAPPER" ] && ok "no Codex skill wrapper" || bad "Codex skill wrapper exists"
[ ! -e "$CODEX_OVERLAY" ] && ok "no Codex overlay" || bad "Codex overlay exists"
forced_block="$(LC_ALL=C awk '/<OH_NO_FORCED_ROUTING>/{f=1} f{print} /<\/OH_NO_FORCED_ROUTING>/{f=0}' "$SESSION_START")"
bootstrap_block="$(LC_ALL=C awk '/<OH_NO_BOOTSTRAP>/{f=1} f{print} /<\/OH_NO_BOOTSTRAP>/{f=0}' "$SESSION_START")"
printf '%s' "$forced_block" | grep -q 'configure-subagents' && bad "absent from FORCED_ROUTING block" || ok "absent from FORCED_ROUTING block"
printf '%s' "$bootstrap_block" | grep -q 'configure-subagents' && bad "absent from BOOTSTRAP block" || ok "absent from BOOTSTRAP block"
# overlay/core define the [check] status-only branch and safe argument-array shape
grep -q 'check' "$SKILL_CORE" && ok "skill core documents the check branch" || bad "skill core check branch"
grep -Fq '"${CLAUDE_PLUGIN_ROOT}/scripts/configure-subagents" check' "$SKILL_OVERLAY" && ok "overlay shows check invocation" || bad "overlay check invocation"
grep -Fq 'find "$plugins/cache"' "$SKILL_OVERLAY" && ok "overlay fallback scans plugins/cache" || bad "overlay cache-scoped fallback"
grep -Fq 'sort -t"$tab" -k1,1V -k2,2' "$SKILL_OVERLAY" && ok "overlay fallback sorts by version field" || bad "overlay version-field sort"
grep -Fq '"oh-no-harness@oh-no-harness"' "$SKILL_OVERLAY" && ok "overlay scopes installPath to exact registry key" || bad "overlay exact registry key"
direct_line="$(grep -nF '"${CLAUDE_PLUGIN_ROOT}/scripts/configure-subagents" check' "$SKILL_OVERLAY" | head -n1 | cut -d: -f1)"
resolver_line="$(grep -nF 'plugins="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins"' "$SKILL_OVERLAY" | head -n1 | cut -d: -f1)"
[ -n "$direct_line" ] && [ -n "$resolver_line" ] && [ "$direct_line" -lt "$resolver_line" ] && ok "overlay keeps CLAUDE_PLUGIN_ROOT first" || bad "overlay CLAUDE_PLUGIN_ROOT ordering"

# ---------------------------------------------------------------------------
[ "$(shared_stage_manifest)" = "$SHARED_STAGE_BASELINE" ] && [ "$FIXTURE_STAGE_SURVIVED" = 0 ] && [ -z "$WORK" ] \
  && ok "success and both SIGKILL seams leave no shared-temp or post-teardown fixture stage" \
  || bad "success or SIGKILL staging escaped shared-temp/fixture teardown containment"
echo
printf 'configure-subagents tests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
