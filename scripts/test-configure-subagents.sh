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

# Canonical role order (must mirror the AGENTS inventory in the validator and
# the configurator). Includes the five Claude-only Codex transport roles.
ROLES=(
  explore analyst planner plan-reviewer executor executor-codex debugger
  verifier code-reviewer fusion-rescue-analyst plan-reviewer-codex
  code-reviewer-codex debugger-codex fusion-codex
)

pass=0
fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; }

# Native (proxy=no) 14-assignment vector, one token per role in canonical order.
native_assignments() {
  printf '%s' \
    'explore=sonnet,high analyst=opus,xhigh planner=opus,max plan-reviewer=opus,xhigh executor=opus,high executor-codex=sonnet,medium debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh plan-reviewer-codex=sonnet,medium code-reviewer-codex=sonnet,medium debugger-codex=sonnet,medium fusion-codex=sonnet,medium'
}

# Alternate native vector (different efforts) for prefs-restore checks.
alt_assignments() {
  printf '%s' \
    'explore=opus,max analyst=sonnet,high planner=sonnet,high plan-reviewer=sonnet,high executor=sonnet,high executor-codex=opus,max debugger=sonnet,high verifier=opus,max code-reviewer=sonnet,high fusion-rescue-analyst=sonnet,high plan-reviewer-codex=opus,max code-reviewer-codex=opus,max debugger-codex=opus,max fusion-codex=opus,max'
}

# GPT variant: explore + analyst use CLIProxyAPI GPT aliases, rest native.
gpt_assignments() {
  printf '%s' \
    'explore=gpt-5.6-terra,medium analyst=gpt-5.6-sol,high planner=opus,max plan-reviewer=opus,xhigh executor=opus,high executor-codex=sonnet,medium debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh plan-reviewer-codex=sonnet,medium code-reviewer-codex=sonnet,medium debugger-codex=sonnet,medium fusion-codex=sonnet,medium'
}

model_for() { case "$1" in explore|verifier|executor-codex|plan-reviewer-codex|code-reviewer-codex|debugger-codex|fusion-codex) printf 'sonnet' ;; *) printf 'opus' ;; esac; }
effort_for() { case "$1" in planner) printf 'max' ;; explore|executor|verifier) printf 'high' ;; executor-codex|plan-reviewer-codex|code-reviewer-codex|debugger-codex|fusion-codex) printf 'medium' ;; *) printf 'xhigh' ;; esac; }

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

setup_fixture() {
  WORK="$(cd "$(mktemp -d)" && pwd -P)"   # physical path (logical==physical)
  TARGET="$WORK/plugin-root"
  CFG="$WORK/config"
  EXP="$WORK/expected"
  mkdir -p "$TARGET/agents" "$TARGET/scripts" "$TARGET/hooks" "$CFG" "$EXP"
  cp "$CONFIGURATOR" "$TARGET/scripts/configure-subagents"
  cp "$OH_NO_CONFIG_SRC" "$TARGET/scripts/oh-no-config"
  cp "$SESSION_START" "$TARGET/hooks/session-start"
  chmod +x "$TARGET/scripts/configure-subagents" "$TARGET/scripts/oh-no-config" "$TARGET/hooks/session-start"
  local role
  for role in "${ROLES[@]}"; do
    cp "$CANONICAL_AGENTS/$role.md" "$TARGET/agents/$role.md"
  done
}
teardown_fixture() { chmod -R u+rwx "$WORK" 2>/dev/null; rm -rf "$WORK"; }

hash_agents() { find "$TARGET/agents" -type f -exec shasum {} \; | sort | shasum; }
journal_files() { find "$CFG" -name 'subagent-journal*' 2>/dev/null; }

# Run the COPIED configurator (root derives from its physical location).
run() { OH_NO_CONFIG_DIR="$CFG" "$TARGET/scripts/configure-subagents" "$@"; }

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
echo "== apply: native-only 14 agents, byte-exact vs independent oracle (cmp) =="
setup_fixture
out="$(run apply --proxy no $(native_assignments))"; rc=$?
[ "$rc" -eq 0 ] && ok "native apply exits 0" || bad "native apply exits 0 (got $rc)"
printf '%s\n' "$out" | grep -q '^STATUS: applied' && ok "apply reports STATUS: applied" || bad "apply STATUS"
all_bytes_ok=1
for role in "${ROLES[@]}"; do
  oracle "$CANONICAL_AGENTS/$role.md" "$(model_for "$role")" "$(effort_for "$role")" "$EXP/$role.md"
  cmp -s "$TARGET/agents/$role.md" "$EXP/$role.md" || { all_bytes_ok=0; printf '        byte mismatch: %s\n' "$role"; }
done
[ "$all_bytes_ok" -eq 1 ] && ok "all 14 files byte-exact vs oracle (model replaced, effort after model, rest preserved)" || bad "byte-for-byte preservation"
adjacency_ok=1
for role in "${ROLES[@]}"; do
  LC_ALL=C awk '/^model:/{m=NR} /^effort:/{e=NR} END{ if (e!=m+1) exit 1 }' "$TARGET/agents/$role.md" || { adjacency_ok=0; printf '        effort not adjacent: %s\n' "$role"; }
done
[ "$adjacency_ok" -eq 1 ] && ok "effort line immediately follows model line" || bad "effort adjacency"
[ -f "$CFG/subagent-models.conf" ] && ok "durable preferences file written" || bad "preferences file"
grep -q '^schema_version=' "$CFG/subagent-models.conf" && ok "preferences are schema-versioned" || bad "schema_version"
grep -q 'AUTH_TOKEN\|BASE_URL\|Bearer\|password\|secret' "$CFG/subagent-models.conf" && bad "preferences leaked credentials" || ok "preferences store no proxy credentials"
status="$(run check | grep '^STATUS:')"
[ "$status" = "STATUS: matching" ] && ok "check reports matching after apply" || bad "check after apply ($status)"
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
run apply --proxy no explore=sonnet,xhigh analyst=opus,xhigh planner=opus,max plan-reviewer=opus,xhigh executor=opus,high executor-codex=sonnet,medium debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh plan-reviewer-codex=sonnet,medium code-reviewer-codex=sonnet,medium debugger-codex=sonnet,medium fusion-codex=sonnet,medium >/dev/null
lines_second="$(wc -l < "$TARGET/agents/explore.md")"
[ "$lines_first" = "$lines_second" ] && ok "re-apply replaces effort without adding a line" || bad "effort replacement line count ($lines_first -> $lines_second)"
oracle "$CANONICAL_AGENTS/explore.md" sonnet xhigh "$EXP/explore-xhigh.md"
cmp -s "$TARGET/agents/explore.md" "$EXP/explore-xhigh.md" && ok "re-apply is byte-exact vs oracle" || bad "effort replacement byte-exact"
teardown_fixture

# ---------------------------------------------------------------------------
echo "== proxy gate: GPT rejected pre-write when proxy=no, accepted when proxy=yes =="
setup_fixture
before_hash="$(hash_agents)"
run apply --proxy no explore=gpt-5.6-terra,medium analyst=opus,xhigh planner=opus,max plan-reviewer=opus,xhigh executor=opus,high executor-codex=sonnet,medium debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh plan-reviewer-codex=sonnet,medium code-reviewer-codex=sonnet,medium debugger-codex=sonnet,medium fusion-codex=sonnet,medium >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "gpt-5.6-terra rejected when proxy=no" || bad "gpt-5.6-terra should be rejected when proxy=no"
run apply --proxy no explore=gpt-5.6-sol,high analyst=opus,xhigh planner=opus,max plan-reviewer=opus,xhigh executor=opus,high executor-codex=sonnet,medium debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh plan-reviewer-codex=sonnet,medium code-reviewer-codex=sonnet,medium debugger-codex=sonnet,medium fusion-codex=sonnet,medium >/dev/null 2>&1; rc=$?
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
reject "invalid model rejected"   --proxy no explore=turbo,high analyst=opus,xhigh planner=opus,max plan-reviewer=opus,xhigh executor=opus,high executor-codex=sonnet,medium debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh plan-reviewer-codex=sonnet,medium code-reviewer-codex=sonnet,medium debugger-codex=sonnet,medium fusion-codex=sonnet,medium
reject "invalid effort rejected"  --proxy no explore=sonnet,turbo analyst=opus,xhigh planner=opus,max plan-reviewer=opus,xhigh executor=opus,high executor-codex=sonnet,medium debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh plan-reviewer-codex=sonnet,medium code-reviewer-codex=sonnet,medium debugger-codex=sonnet,medium fusion-codex=sonnet,medium
reject "missing role (13) rejected" --proxy no explore=sonnet,high analyst=opus,xhigh planner=opus,max plan-reviewer=opus,xhigh executor=opus,high executor-codex=sonnet,medium debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh plan-reviewer-codex=sonnet,medium code-reviewer-codex=sonnet,medium debugger-codex=sonnet,medium
reject "duplicate role rejected"  --proxy no explore=sonnet,high explore=sonnet,high planner=opus,max plan-reviewer=opus,xhigh executor=opus,high executor-codex=sonnet,medium debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh plan-reviewer-codex=sonnet,medium code-reviewer-codex=sonnet,medium debugger-codex=sonnet,medium fusion-codex=sonnet,medium
reject "unknown role rejected"    --proxy no explore=sonnet,high mystery=opus,xhigh planner=opus,max plan-reviewer=opus,xhigh executor=opus,high executor-codex=sonnet,medium debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh plan-reviewer-codex=sonnet,medium code-reviewer-codex=sonnet,medium debugger-codex=sonnet,medium fusion-codex=sonnet,medium
reject "reordered roles rejected" --proxy no analyst=opus,xhigh explore=sonnet,high planner=opus,max plan-reviewer=opus,xhigh executor=opus,high executor-codex=sonnet,medium debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh plan-reviewer-codex=sonnet,medium code-reviewer-codex=sonnet,medium debugger-codex=sonnet,medium fusion-codex=sonnet,medium
reject "missing proxy answer rejected" explore=sonnet,high analyst=opus,xhigh planner=opus,max plan-reviewer=opus,xhigh executor=opus,high executor-codex=sonnet,medium debugger=opus,xhigh verifier=sonnet,high code-reviewer=opus,xhigh fusion-rescue-analyst=opus,xhigh plan-reviewer-codex=sonnet,medium code-reviewer-codex=sonnet,medium debugger-codex=sonnet,medium fusion-codex=sonnet,medium
teardown_fixture

# ---------------------------------------------------------------------------
echo "== includes 5 Codex transport roles; leaves Codex TOML untouched =="
setup_fixture
mkdir -p "$TARGET/docs/platforms/codex-agents"
printf 'name = "oh-no-executor"\n' > "$TARGET/docs/platforms/codex-agents/oh-no-executor.toml"
toml_before="$(shasum "$TARGET/docs/platforms/codex-agents/oh-no-executor.toml")"
run apply --proxy no $(native_assignments) >/dev/null; rc=$?
[ "$rc" -eq 0 ] && ok "apply including 5 transport roles succeeds" || bad "apply with transports (got $rc)"
for t in executor-codex plan-reviewer-codex code-reviewer-codex debugger-codex fusion-codex; do
  grep -q '^effort: ' "$TARGET/agents/$t.md" && ok "transport role configured: $t" || bad "transport role not configured: $t"
done
[ "$toml_before" = "$(shasum "$TARGET/docs/platforms/codex-agents/oh-no-executor.toml")" ] && ok "Codex custom-agent TOML byte-unchanged" || bad "Codex TOML mutated"
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
OH_NO_CONFIG_DIR="$CFG" "$TARGET/scripts/configure-subagents" apply --proxy no $(native_assignments) >/dev/null 2>&1; rc=$?
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
run_b() { OH_NO_CONFIG_DIR="$CFG" "$ROOTB/scripts/configure-subagents" "$@"; }
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
OH_NO_CONFIG_DIR="$CFG" "$ROOTB/scripts/configure-subagents" apply --proxy no $(alt_assignments) >/dev/null 2>&1; rc=$?
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
run_hook() { env CLAUDE_PLUGIN_ROOT="$TARGET" OH_NO_CONFIG_DIR="$CFG" "$@" "$TARGET/hooks/session-start"; }
valid_json() { printf '%s' "$1" | "$PYTHON" -c 'import json,sys; json.loads(sys.stdin.read())' >/dev/null 2>&1; }
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
grep -Fq 'find ~/.claude/plugins' "$SKILL_OVERLAY" && ok "overlay shows located-script fallback" || bad "overlay fallback"

# ---------------------------------------------------------------------------
echo
printf 'configure-subagents tests: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
