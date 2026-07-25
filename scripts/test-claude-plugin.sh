#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
PLUGIN_NAME="${OH_NO_PLUGIN_NAME:-oh-no-harness}"
MARKETPLACE_NAME="${OH_NO_MARKETPLACE_NAME:-oh-no-harness}"
MARKETPLACE_ROOT="${OH_NO_MARKETPLACE_ROOT:-$REPO_ROOT}"
PLUGIN_ROOT="${OH_NO_PLUGIN_ROOT:-$MARKETPLACE_ROOT/plugins/$PLUGIN_NAME}"
LIVE_PLUGIN_ROOT="${OH_NO_LIVE_PLUGIN_ROOT:-$PLUGIN_ROOT}"
LIVE_PLUGIN_ROOT_OVERRIDDEN=0; [[ -n "${OH_NO_LIVE_PLUGIN_ROOT:-}" ]] && LIVE_PLUGIN_ROOT_OVERRIDDEN=1
PLUGIN_ID="${PLUGIN_NAME}@${MARKETPLACE_NAME}"
MARKETPLACE_SOURCE="${OH_NO_MARKETPLACE_SOURCE:-$MARKETPLACE_ROOT}"
REQUESTED_SCOPE="${OH_NO_PLUGIN_SCOPE:-}"
INSTALL_MODE="${OH_NO_INSTALL:-1}"
ISOLATED_CONFIG="${OH_NO_ISOLATED_CONFIG:-0}"
ISOLATED_CONFIG_HOME=""
RUN_LIVE="${OH_NO_LIVE:-0}"
RUN_DEEP_LIVE="${OH_NO_DEEP_LIVE:-0}"
RUN_PARALLEL_LIVE="${OH_NO_PARALLEL_LIVE:-0}"
RUN_RALPLAN_LIVE="${OH_NO_RALPLAN_LIVE:-0}"
RUN_FUSION_RESCUE_LIVE="${OH_NO_FUSION_RESCUE_LIVE:-0}"
RUN_CROSS_HOST_FALLBACK_LIVE="${OH_NO_CROSS_HOST_FALLBACK_LIVE:-0}"
# Flag-only gate: this paid lane stays inert in release/default runs.
RUN_MODEL_DIVERSITY_LIVE=0
RUN_PARALLEL_EXECUTOR_LIVE="${OH_NO_PARALLEL_EXECUTOR_LIVE:-0}"
RUN_SIMPLIFY_LIVE="${OH_NO_SIMPLIFY_LIVE:-0}"
RUN_NATURAL_SESSION_START_LIVE="${OH_NO_NATURAL_SESSION_START_LIVE:-0}"
LIVE_HOOK_ONLY="${OH_NO_LIVE_HOOK_ONLY:-0}"
LIVE_LOAD_MODE="${OH_NO_LIVE_LOAD_MODE:-plugin-dir}"
LIVE_MODEL="${OH_NO_TEST_MODEL:-sonnet}"
LIVE_MAX_BUDGET_USD="${OH_NO_MAX_BUDGET_USD:-3.00}"
LIVE_TIMEOUT_SECONDS="${OH_NO_LIVE_TIMEOUT_SECONDS:-900}"
LIVE_TIMEOUT_GRACE_SECONDS="${OH_NO_LIVE_TIMEOUT_GRACE_SECONDS:-5}"
FUSION_RESCUE_LIVE_MODEL="${OH_NO_FUSION_RESCUE_MODEL:-${OH_NO_TEST_MODEL:-opus}}"
FUSION_RESCUE_MAX_BUDGET_USD="${OH_NO_FUSION_RESCUE_MAX_BUDGET_USD:-10.00}"
LIVE_SYSTEM_PROMPT="${OH_NO_SYSTEM_PROMPT:-You are a concise smoke test runner. You may read plugin skill-core and platform docs needed by the invoked skill. Do not edit files.}"
RUN_DIR="${OH_NO_TEST_RUN_DIR:-${MARKETPLACE_ROOT}/.oh-no/test-runs/$(date +%Y%m%d-%H%M%S)}"

PUBLIC_SKILLS=(
  interview
  ralplan
  ralph
  ultrawork
  auto-routing
  test-driven-development
  simplify
  verification-before-completion
  systematic-debugging
  fusion-rescue
  install-statusline
  configure-subagents
)
ALL_SKILLS=("${PUBLIC_SKILLS[@]}")
AGENTS=(
  explore
  analyst
  planner
  plan-reviewer
  executor
  debugger
  verifier
  code-reviewer
  fusion-rescue-analyst
)

usage() {
  cat <<USAGE
Usage: scripts/test-claude-plugin.sh [options]

Installs or updates the local Claude Code plugin, then runs structural checks.
Live Claude Code skill smoke tests are opt-in because they spend model budget.

Options:
  --live                 Run live /skill smoke tests after static checks.
  --deep-live            Run live deep smoke tests that require linked support docs.
  --parallel-live        Run live Ralph parallel-subagent smoke test.
  --ralplan-live         Run live Ralplan planner-to-reviewer-pair smoke test.
  --fusion-rescue-live   Run live Fusion Rescue three-panel model-diversity smoke test.
  --cross-host-fallback-live
                         Run live Claude same-model fallback proof: no secondary
                         configured yields exactly two code-reviewer instances and
                         require-model-diversity transitions to PAUSED.
  --model-diversity-live
                         Run live Ralph THOROUGH Review Gate model-diversity pair proof
                         with an isolated schema-v2 preference fixture.
  --parallel-executor-live
                         Run live Ralph proactive disjoint-executor parallel-batch
                         smoke test: an ordinary STANDARD/THOROUGH run over two
                         disjoint stories must proactively dispatch a concurrent
                         executor batch plus a post-batch per-executor scope check.
  --simplify-live        Run live simplify cleanup-subagent smoke test.
  --natural-session-start-live
                         Run live natural role-worker smoke tests for Interview, Ultrawork,
                         Systematic Debugging, and Verification Before Completion.
  --live-hook-only       Run only live Claude SessionStart hook policy and auto-routing tests.
  --skip-live            Skip live /skill smoke tests. Default.
  --no-install           Do not add marketplace, install, or update plugin.
  --isolated-config      Create and clean up a throwaway CLAUDE_CONFIG_DIR. This
                         protects install and model-bearing plugin-dir live runs;
                         gateway auth can remain available outside that directory.
  --scope <scope>        Install/update scope: local, project, user, managed.
                         Default: update existing scope if installed, otherwise user.
  --live-load <mode>     plugin-dir or installed. Default: plugin-dir.
  --marketplace-source <source>
                         Marketplace source passed to Claude Code marketplace add.
                         Default: this checkout. Use jcwleo/oh-no-harness to test GitHub.
  --model <model>        Claude model alias for live tests. Default: sonnet.
                         Fusion Rescue live defaults to opus unless overridden.
  --max-budget-usd <n>   Per-command max budget for live tests. Default: 3.00.
  -h, --help             Show this help.

Safety:
  The install step refuses to register a LOCAL (or unrecognized) marketplace
  source into your real Claude config, because that can overwrite the daily-use
  'oh-no-harness' GitHub registration with this checkout. A different
  OH_NO_MARKETPLACE_NAME is NOT a safe path (it still writes a local registration
  into the real config). Make it safe with --isolated-config (a throwaway config
  home) or a validated GitHub source (--marketplace-source jcwleo/oh-no-harness).
  For plugin-dir live
  runs, --no-install skips driver registration but ordinary Claude startup may
  still sync registry metadata: use --isolated-config with gateway auth, or a
  disposable non-default CLAUDE_CONFIG_DIR clone for native auth/settings.
  OH_NO_LIVE_PLUGIN_ROOT selects an absolute disposable plugin copy for model runs
  while canonical source validation stays on OH_NO_PLUGIN_ROOT; it requires --no-install.
  Real-config overrides are OH_NO_ALLOW_CANONICAL_LOCAL_MARKETPLACE=1 (install)
  and OH_NO_ALLOW_REAL_CLAUDE_CONFIG_LIVE=1 (model-bearing live), used knowingly.

Environment overrides:
  CLAUDE_BIN, PYTHON_BIN, OH_NO_PLUGIN_SCOPE, OH_NO_LIVE, OH_NO_DEEP_LIVE,
  OH_NO_PARALLEL_LIVE, OH_NO_RALPLAN_LIVE, OH_NO_TEST_MODEL,
  OH_NO_FUSION_RESCUE_LIVE, OH_NO_FUSION_RESCUE_MODEL,
  OH_NO_FUSION_RESCUE_MAX_BUDGET_USD, OH_NO_CROSS_HOST_FALLBACK_LIVE,
  OH_NO_PARALLEL_EXECUTOR_LIVE,
  OH_NO_SIMPLIFY_LIVE,
  OH_NO_NATURAL_SESSION_START_LIVE,
  OH_NO_MAX_BUDGET_USD, OH_NO_LIVE_TIMEOUT_SECONDS, OH_NO_LIVE_TIMEOUT_GRACE_SECONDS,
  OH_NO_LIVE_LOAD_MODE, OH_NO_LIVE_PLUGIN_ROOT, OH_NO_MARKETPLACE_SOURCE, OH_NO_ISOLATED_CONFIG,
  OH_NO_ALLOW_CANONICAL_LOCAL_MARKETPLACE, OH_NO_ALLOW_REAL_CLAUDE_CONFIG_LIVE
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --live) RUN_LIVE=1; shift ;;
    --deep-live) RUN_DEEP_LIVE=1; shift ;;
    --parallel-live) RUN_PARALLEL_LIVE=1; shift ;;
    --ralplan-live) RUN_RALPLAN_LIVE=1; shift ;;
    --fusion-rescue-live) RUN_FUSION_RESCUE_LIVE=1; shift ;;
    --cross-host-fallback-live) RUN_CROSS_HOST_FALLBACK_LIVE=1; shift ;;
    --model-diversity-live) RUN_MODEL_DIVERSITY_LIVE=1; shift ;;
    --parallel-executor-live) RUN_PARALLEL_EXECUTOR_LIVE=1; shift ;;
    --simplify-live) RUN_SIMPLIFY_LIVE=1; shift ;;
    --natural-session-start-live) RUN_NATURAL_SESSION_START_LIVE=1; shift ;;
    --live-hook-only) RUN_LIVE=1; LIVE_HOOK_ONLY=1; shift ;;
    --skip-live) RUN_LIVE=0; shift ;;
    --no-install) INSTALL_MODE=0; shift ;;
    --isolated-config) ISOLATED_CONFIG=1; shift ;;
    --scope) REQUESTED_SCOPE="${2:-}"; [[ -n "$REQUESTED_SCOPE" ]] || { echo "Missing value for --scope" >&2; exit 2; }; shift 2 ;;
    --live-load) LIVE_LOAD_MODE="${2:-}"; [[ -n "$LIVE_LOAD_MODE" ]] || { echo "Missing value for --live-load" >&2; exit 2; }; shift 2 ;;
    --marketplace-source) MARKETPLACE_SOURCE="${2:-}"; [[ -n "$MARKETPLACE_SOURCE" ]] || { echo "Missing value for --marketplace-source" >&2; exit 2; }; shift 2 ;;
    --model) LIVE_MODEL="${2:-}"; [[ -n "$LIVE_MODEL" ]] || { echo "Missing value for --model" >&2; exit 2; }; FUSION_RESCUE_LIVE_MODEL="$LIVE_MODEL"; shift 2 ;;
    --max-budget-usd) LIVE_MAX_BUDGET_USD="${2:-}"; [[ -n "$LIVE_MAX_BUDGET_USD" ]] || { echo "Missing value for --max-budget-usd" >&2; exit 2; }; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$LIVE_LOAD_MODE" in
  plugin-dir|installed) ;; *) echo "--live-load must be plugin-dir or installed" >&2; exit 2 ;;
esac
case "$REQUESTED_SCOPE" in
  ""|local|project|user|managed) ;; *) echo "--scope must be local, project, user, or managed" >&2; exit 2 ;;
esac

log() { printf '\n==> %s\n' "$*" >&2; }
ok() { printf 'ok - %s\n' "$*" >&2; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

cleanup_isolated_config() {
  [[ -n "${ISOLATED_CONFIG_HOME:-}" ]] && rm -rf "$ISOLATED_CONFIG_HOME"
  ISOLATED_CONFIG_HOME=""
}

# Own a throwaway config home for this run and guarantee its removal on normal
# exit, failure, and interrupt. Exporting CLAUDE_CONFIG_DIR redirects every
# `claude` call (and cached_plugin_root) into the temp home.
setup_isolated_config() {
  ISOLATED_CONFIG_HOME="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-claude-config.XXXXXX")"
  export CLAUDE_CONFIG_DIR="$ISOLATED_CONFIG_HOME"
  trap cleanup_isolated_config EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  log "Using isolated Claude config home: $ISOLATED_CONFIG_HOME"
}

snapshot_file_manifest() {
  local root="$1"
  "$PYTHON_BIN" - "$root" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
if root.is_dir():
    for path in sorted((item for item in root.rglob("*") if item.is_file()), key=lambda item: item.as_posix()):
        stat = path.stat()
        print(json.dumps([path.relative_to(root).as_posix(), stat.st_mtime_ns, stat.st_size], separators=(",", ":")))
PY
}

file_identity() { "$PYTHON_BIN" -c 'import hashlib,os,sys; p=sys.argv[1]; print("absent" if not os.path.exists(p) else "present:%s:%s" % (hashlib.sha256(open(p,"rb").read()).hexdigest(), os.stat(p).st_mtime_ns))' "$1"; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

run_live_process_with_timeout() {
  local rc=0
  "$PYTHON_BIN" - "$LIVE_TIMEOUT_SECONDS" "$LIVE_TIMEOUT_GRACE_SECONDS" "$@" <<'PY' || rc=$?
import os
import signal
import subprocess
import sys
import time

timeout_seconds = float(sys.argv[1])
grace_seconds = float(sys.argv[2])
command = sys.argv[3:]
if not command:
    raise SystemExit("live command runner received no command")
if timeout_seconds <= 0 or grace_seconds < 0:
    raise SystemExit("live command timeout must be positive and grace must be non-negative")

process = subprocess.Popen(
    command,
    env=os.environ.copy(),
    start_new_session=True,
)

def group_exists():
    try:
        os.killpg(process.pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True

def signal_group(signum):
    try:
        os.killpg(process.pid, signum)
    except ProcessLookupError:
        pass

def stop_group():
    signal_group(signal.SIGTERM)
    deadline = time.monotonic() + grace_seconds
    while group_exists() and time.monotonic() < deadline:
        if process.poll() is None:
            try:
                process.wait(timeout=min(0.1, max(0.0, deadline - time.monotonic())))
            except subprocess.TimeoutExpired:
                pass
        else:
            time.sleep(0.05)
    if group_exists():
        signal_group(signal.SIGKILL)
    if process.poll() is None:
        process.wait()

def forward_signal(signum, _frame):
    stop_group()
    raise SystemExit(128 + signum)

for forwarded_signal in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
    signal.signal(forwarded_signal, forward_signal)

try:
    return_code = process.wait(timeout=timeout_seconds)
except subprocess.TimeoutExpired:
    print(
        f"ERROR: live command exceeded {timeout_seconds:g}s: {command[0]}",
        file=sys.stderr,
    )
    stop_group()
    raise SystemExit(124)
except BaseException:
    if group_exists():
        stop_group()
    raise

if group_exists():
    stop_group()
raise SystemExit(return_code)
PY
  return "$rc"
}

run_plugin_dir_live_process_with_timeout() {
  local disposable_config="" rc=0
  if [[ "$INSTALL_MODE" == 0 && "$LIVE_LOAD_MODE" == plugin-dir && -z "${OH_NO_CONFIG_DIR+x}" ]]; then
    disposable_config="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-live-config.XXXXXX")"
    OH_NO_CONFIG_DIR="$disposable_config" run_live_process_with_timeout "$@" || rc=$?
    rm -rf "$disposable_config"
    return "$rc"
  fi
  run_live_process_with_timeout "$@"
}

run_live_timeout_offline_test() {
  log "Running offline Claude live-timeout process-group regression"
  local temp_root fixture pid_file err_file child_pid rc
  local saved_timeout="$LIVE_TIMEOUT_SECONDS"
  local saved_grace="$LIVE_TIMEOUT_GRACE_SECONDS"
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-claude-timeout-self-test.XXXXXX")"
  fixture="$temp_root/spawn-descendant.py"
  pid_file="$temp_root/descendant.pid"
  err_file="$temp_root/timeout.err"
  cat >"$fixture" <<'PY'
import signal
import subprocess
import sys
import time
from pathlib import Path

child = subprocess.Popen(
    [
        sys.executable,
        "-c",
        "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(60)",
    ]
)
Path(sys.argv[1]).write_text(str(child.pid), encoding="utf-8")
while True:
    time.sleep(1)
PY

  LIVE_TIMEOUT_SECONDS="0.3"
  LIVE_TIMEOUT_GRACE_SECONDS="0.1"
  rc=0
  run_live_process_with_timeout "$PYTHON_BIN" "$fixture" "$pid_file" \
    >/dev/null 2>"$err_file" || rc=$?
  LIVE_TIMEOUT_SECONDS="$saved_timeout"
  LIVE_TIMEOUT_GRACE_SECONDS="$saved_grace"

  [[ "$rc" == "124" ]] \
    || { rm -rf "$temp_root"; fail "Claude timeout fixture returned $rc instead of 124"; }
  grep -Fq "live command exceeded 0.3s" "$err_file" \
    || { rm -rf "$temp_root"; fail "Claude timeout fixture omitted the timeout diagnostic"; }
  [[ -s "$pid_file" ]] \
    || { rm -rf "$temp_root"; fail "Claude timeout fixture did not record its descendant pid"; }
  child_pid="$(<"$pid_file")"
  "$PYTHON_BIN" - "$child_pid" <<'PY' \
    || { rm -rf "$temp_root"; fail "Claude timeout runner left its descendant process alive"; }
import os
import sys
import time

pid = int(sys.argv[1])
deadline = time.monotonic() + 2
while time.monotonic() < deadline:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        raise SystemExit(0)
    time.sleep(0.05)
raise SystemExit(f"descendant process still exists after process-group cleanup: {pid}")
PY

  rc=0
  run_live_process_with_timeout "$PYTHON_BIN" -c 'raise SystemExit(7)' \
    >/dev/null 2>&1 || rc=$?
  [[ "$rc" == "7" ]] || { rm -rf "$temp_root"; fail "Claude timeout runner changed child exit 7 to $rc"; }

  local fake_home="$temp_root/fake-home" real_data config_record real_before isolated_path explicit="$temp_root/explicit"
  real_data="$fake_home/.claude/plugins/data/oh-no-harness-inline"; config_record="$temp_root/live-config-path"
  mkdir -p "$real_data"; printf 'sentinel\n' >"$real_data/sentinel"
  real_before="$(snapshot_file_manifest "$real_data")"
  cat >"$temp_root/fake-live" <<'SH'
#!/usr/bin/env bash
config_dir="${OH_NO_CONFIG_DIR:-$HOME/.claude/plugins/data/oh-no-harness-inline}"
printf '%s\n' "$config_dir" >"$1"; mkdir -p "$config_dir"; printf 'touched\n' >"$config_dir/live-child-touch"
exit "$2"
SH
  chmod +x "$temp_root/fake-live"; rc=0
  (unset OH_NO_CONFIG_DIR; HOME="$fake_home"; INSTALL_MODE=0; LIVE_LOAD_MODE=plugin-dir; run_plugin_dir_live_process_with_timeout "$temp_root/fake-live" "$config_record" 7) >/dev/null 2>&1 || rc=$?
  isolated_path="$(<"$config_record")"
  [[ "$rc" == 7 && ! -e "$isolated_path" && "$real_before" == "$(snapshot_file_manifest "$real_data")" ]] \
    || { rm -rf "$temp_root"; fail "plugin-dir live child escaped disposable OH_NO_CONFIG_DIR or cleanup/status preservation failed"; }
  OH_NO_CONFIG_DIR="$explicit" run_plugin_dir_live_process_with_timeout "$temp_root/fake-live" "$config_record" 0 >/dev/null 2>&1
  [[ "$(<"$config_record")" == "$explicit" && -f "$explicit/live-child-touch" ]] \
    || { rm -rf "$temp_root"; fail "live isolation overrode an explicit OH_NO_CONFIG_DIR"; }
  local hook_files_before hook_hash_before hook_root_before
  hook_files_before="$(snapshot_file_manifest "$real_data")"; hook_hash_before="$(shasum -a 256 "$real_data/sentinel")"; hook_root_before="$("$PYTHON_BIN" -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$real_data")"
  (unset OH_NO_CONFIG_DIR CLAUDE_CONFIG_DIR XDG_CONFIG_HOME; HOME="$fake_home"; validate_hooks) >/dev/null 2>&1
  [[ "$hook_files_before" == "$(snapshot_file_manifest "$real_data")" && "$hook_hash_before" == "$(shasum -a 256 "$real_data/sentinel")" && "$hook_root_before" == "$("$PYTHON_BIN" -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$real_data")" ]] \
    || { rm -rf "$temp_root"; fail "validate_hooks changed real-like plugin-data content, file mtimes, or root directory mtime"; }
  rm -rf "$temp_root"
  ok "Claude timeout/live and validate_hooks isolation preserve status, cleanup, explicit overrides, and plugin-data metadata"
}

marketplace_exists() {
  "$CLAUDE_BIN" plugin marketplace list --json \
    | "$PYTHON_BIN" -c 'import json, sys
name = sys.argv[1]
data = json.load(sys.stdin)
for item in data:
    if item.get("name") == name:
        sys.exit(0)
sys.exit(1)
' "$MARKETPLACE_NAME"
}

# Shared source classification / config-identity primitive (also used by
# scripts/release), so the two tools cannot drift on what counts as a local vs.
# remote source or as the real config home.
marketplace_source_tool() {
  "$PYTHON_BIN" "$MARKETPLACE_ROOT/scripts/marketplace_source.py" "$@"
}

append_live_plugin_dir_arg() {
  [[ "$LIVE_LOAD_MODE" == plugin-dir ]] && cmd+=(--plugin-dir "$LIVE_PLUGIN_ROOT")
  return 0
}

validate_live_plugin_root() {
  [[ "$LIVE_PLUGIN_ROOT_OVERRIDDEN" == 1 ]] || return 0
  [[ "$INSTALL_MODE" == 0 ]] || fail "OH_NO_LIVE_PLUGIN_ROOT is a live-only disposable plugin copy and requires --no-install"
  [[ "$LIVE_PLUGIN_ROOT" == /* && -d "$LIVE_PLUGIN_ROOT" && -r "$LIVE_PLUGIN_ROOT" ]] || fail "OH_NO_LIVE_PLUGIN_ROOT must be an absolute, readable plugin directory"
  local path role skill
  for path in .claude-plugin/plugin.json hooks/hooks.json hooks/session-start hooks/run-hook.cmd scripts/oh-no-config scripts/configure-subagents; do [[ -r "$LIVE_PLUGIN_ROOT/$path" ]] || fail "OH_NO_LIVE_PLUGIN_ROOT is missing readable $path"; done
  for role in "${AGENTS[@]}"; do [[ -r "$LIVE_PLUGIN_ROOT/agents/$role.md" ]] || fail "OH_NO_LIVE_PLUGIN_ROOT is missing readable agent $role"; done
  for skill in "${PUBLIC_SKILLS[@]}"; do [[ -r "$LIVE_PLUGIN_ROOT/skills-claude/$skill/SKILL.md" ]] || fail "OH_NO_LIVE_PLUGIN_ROOT is missing readable Claude skill $skill"; done
  "$PYTHON_BIN" -c 'import json,sys; m=json.load(open(sys.argv[1], encoding="utf-8")); h=json.load(open(sys.argv[2], encoding="utf-8")); assert m.get("name")==sys.argv[3] and isinstance(m.get("skills"),list) and h.get("hooks",{}).get("SessionStart")' "$LIVE_PLUGIN_ROOT/.claude-plugin/plugin.json" "$LIVE_PLUGIN_ROOT/hooks/hooks.json" "$PLUGIN_NAME" || fail "OH_NO_LIVE_PLUGIN_ROOT has invalid manifest or SessionStart hook shape"
}

model_bearing_plugin_dir_live_requested() {
  [[ "$LIVE_LOAD_MODE" == plugin-dir && "${RUN_LIVE}${RUN_DEEP_LIVE}${RUN_PARALLEL_LIVE}${RUN_RALPLAN_LIVE}${RUN_FUSION_RESCUE_LIVE}${RUN_CROSS_HOST_FALLBACK_LIVE}${RUN_MODEL_DIVERSITY_LIVE}${RUN_PARALLEL_EXECUTOR_LIVE}${RUN_SIMPLIFY_LIVE}${RUN_NATURAL_SESSION_START_LIVE}" == *1* ]]
}

guard_real_claude_config_live() {
  model_bearing_plugin_dir_live_requested || return 0
  [[ "$(marketplace_source_tool config-identity "${CLAUDE_CONFIG_DIR:-}" "$HOME")" == default ]] || return 0
  if [[ "${OH_NO_ALLOW_REAL_CLAUDE_CONFIG_LIVE:-0}" == 1 ]]; then
    log "OH_NO_ALLOW_REAL_CLAUDE_CONFIG_LIVE=1: allowing model-bearing plugin-dir live commands to use the real Claude config; ordinary startup plugin sync may update registry metadata"
    return 0
  fi
  fail "refusing model-bearing plugin-dir live commands with the real default Claude config: ordinary Claude startup plugin sync may update registry metadata even under --no-install. Use --isolated-config with gateway auth, or set CLAUDE_CONFIG_DIR to a disposable physical clone containing required native auth/settings. To knowingly accept real-config metadata writes, set OH_NO_ALLOW_REAL_CLAUDE_CONFIG_LIVE=1. OH_NO_CONFIG_DIR does not isolate the Claude registry."
}

# Install gate: refuse local/invalid marketplace sources in the real config
# regardless of name; isolation or a validated GitHub source is safe.
guard_canonical_local_marketplace() {
  # Symlink/`.`/`..`/trailing-slash aware; unset/empty => $HOME/.claude.
  local identity
  identity="$(marketplace_source_tool config-identity "${CLAUDE_CONFIG_DIR:-}" "$HOME")"
  [[ "$identity" == "default" ]] || return 0   # isolated config cannot disturb the real one

  local klass redacted
  klass="$(marketplace_source_tool classify-source "$MARKETPLACE_SOURCE")"
  redacted="$(marketplace_source_tool redact "$MARKETPLACE_SOURCE")"
  case "$klass" in
    remote)
      return 0   # a validated GitHub source only re-syncs from the remote
      ;;
    local)
      if [[ "${OH_NO_ALLOW_CANONICAL_LOCAL_MARKETPLACE:-0}" == "1" ]]; then
        log "OH_NO_ALLOW_CANONICAL_LOCAL_MARKETPLACE=1: registering '${MARKETPLACE_NAME}' from a local source into your real Claude config on purpose (${redacted})"
        return 0
      fi
      fail "refusing to register the '${MARKETPLACE_NAME}' marketplace from a LOCAL source (${redacted}) into your real Claude config: this can overwrite the daily-use GitHub registration with a working-tree checkout. Re-run with an isolated config (--isolated-config) or a validated GitHub --marketplace-source (e.g. jcwleo/oh-no-harness). To do it on purpose, set OH_NO_ALLOW_CANONICAL_LOCAL_MARKETPLACE=1."
      ;;
    *)
      fail "refusing to register the '${MARKETPLACE_NAME}' marketplace from an unrecognized/invalid source (${redacted}) into your real Claude config. Use a validated GitHub --marketplace-source (e.g. jcwleo/oh-no-harness) or an isolated config (--isolated-config)."
      ;;
  esac
}

installed_scope_for_plugin() {
  "$CLAUDE_BIN" plugin list --json \
    | "$PYTHON_BIN" -c 'import json, sys
plugin_id = sys.argv[1]
requested = sys.argv[2]
data = json.load(sys.stdin)

matches = [item for item in data if item.get("id") == plugin_id]
if not matches:
    sys.exit(1)

if requested:
    for item in matches:
        if item.get("scope") == requested:
            print(requested)
            sys.exit(0)
    sys.exit(1)

for preferred in ("local", "project", "user", "managed"):
    for item in matches:
        if item.get("scope") == preferred:
            print(preferred)
            sys.exit(0)

print(matches[0].get("scope", "user"))
' "$PLUGIN_ID" "${REQUESTED_SCOPE:-}"
}

assert_json_valid() {
  local path="$1"
  "$PYTHON_BIN" -m json.tool "$path" >/dev/null
  ok "valid JSON: ${path#$PLUGIN_ROOT/}"
}

validate_frontmatter() {
  # validate-plugin-files.py also runs the deterministic skill-reachability
  # deep-smoke (both platforms); no separate invocation needed here.
  "$PYTHON_BIN" "$MARKETPLACE_ROOT/scripts/validate-plugin-files.py" "$MARKETPLACE_ROOT" "$PLUGIN_ROOT"
}

plugin_version() {
  "$PYTHON_BIN" - "$PLUGIN_ROOT/.claude-plugin/plugin.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    print(json.load(fh)["version"])
PY
}

cached_plugin_root() {
  local claude_home="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
  printf '%s/plugins/cache/%s/%s/%s\n' "$claude_home" "$MARKETPLACE_NAME" "$PLUGIN_NAME" "$(plugin_version)"
}

cache_manifest_matches_source() {
  local cached_manifest
  cached_manifest="$(cached_plugin_root)/.claude-plugin/plugin.json"
  [[ -f "$cached_manifest" ]] || return 1
  cmp -s "$PLUGIN_ROOT/.claude-plugin/plugin.json" "$cached_manifest"
}

cache_content_matches_source() {
  local cached_root
  cached_root="$(cached_plugin_root)"
  [[ -d "$cached_root" ]] || return 1

  "$PYTHON_BIN" - "$PLUGIN_ROOT" "$cached_root" <<'PY'
from __future__ import annotations

import filecmp
import sys
from pathlib import Path

source = Path(sys.argv[1])
cached = Path(sys.argv[2])

include_files = [
    "README.md",
    "AGENTS.md",
    ".claude-plugin/plugin.json",
    ".codex-plugin/plugin.json",
]
include_dirs = ["skills", "skills-claude", "commands", "agents", "hooks", "scripts", "docs"]

paths: list[Path] = [Path(item) for item in include_files]
for dirname in include_dirs:
    root = source / dirname
    if not root.exists():
        continue
    for path in sorted(root.rglob("*")):
        if path.is_file():
            paths.append(path.relative_to(source))

for rel in paths:
    left = source / rel
    right = cached / rel
    if not right.exists():
        raise SystemExit(1)
    if not filecmp.cmp(left, right, shallow=False):
        raise SystemExit(1)
PY
}

refresh_installed_plugin_cache() {
  local target_scope="$1"

  if cache_content_matches_source; then
    ok "cached Claude plugin content matches source"
    return
  fi

  log "Refreshing installed plugin cache because cached content differs from source"
  "$CLAUDE_BIN" plugin uninstall --scope "$target_scope" --keep-data --yes "$PLUGIN_ID"
  rm -rf "$(cached_plugin_root)"
  "$CLAUDE_BIN" plugin install --scope "$target_scope" "$PLUGIN_ID"

  if ! cache_content_matches_source; then
    fail "cached Claude plugin content still differs from source after reinstall"
  fi
  ok "cached Claude plugin content refreshed"
}

# snapshot <integration-checkout> <owned-slug>
#
# Emits a JSON manifest for the caller-owned escape guard around a delegated
# executor slice. The caller's protected target set is
# everything EXCEPT the delegated slice's own worktree:
#   1. the integration checkout's tracked + untracked-NON-ignored state via
#      `git -C <integration> status --porcelain`; PLUS
#   2. a FILESYSTEM SENTINEL (path + mtime_ns + size, modeled on _pexec_sentinel)
#      over the ENTIRE gitignored `.oh-no/` subtree (plans/sessions/specs/test-runs/
#      worktrees AND any other top-level `.oh-no/` dir) AND each sibling
#      `.oh-no/worktrees/*`, EXCLUDING `.oh-no/worktrees/<owned-slug>`. Walking the
#      whole subtree instead of a fixed dir allowlist means a new gitignored dir such
#      as `specs/` is covered automatically.
# `git status --porcelain` is BLIND to the gitignored `.oh-no/` subtree
# (worktree-isolation.md:85-89), which is the exact class the demonstrated escape
# hit, so the sentinel is mandatory. The sentinel is path+mtime+size, NOT a content
# hash (a same-path/same-mtime/same-size content edit is invisible — accepted
# residual). No jq/node; Python only, like the rest of the harness.
snapshot() {
  local integration="$1" owned_slug="$2" git_status=""
  git_status="$(git -C "$integration" status --porcelain 2>/dev/null || true)"
  OH_NO_ESCAPE_GIT_STATUS="$git_status" "$PYTHON_BIN" - "$integration" "$owned_slug" <<'SENTINEL'
import json, os, sys
integration, owned_slug = sys.argv[1], sys.argv[2]
git_status = sorted(
    line for line in os.environ.get("OH_NO_ESCAPE_GIT_STATUS", "").splitlines()
    if line.strip()
)
manifest = {"__git_status__": git_status}
oh_no = os.path.join(integration, ".oh-no")
owned_real = os.path.realpath(os.path.join(oh_no, "worktrees", owned_slug))
# Walk the WHOLE .oh-no/ subtree (plans, sessions, specs, test-runs, worktrees, and
# any future top-level dir), NOT a fixed allowlist, so a new gitignored subtree such
# as specs/ is covered automatically. `git status --porcelain` is blind to all of
# .oh-no/, so this sentinel is the only arm covering it.
if os.path.isdir(oh_no):
    for dirpath, dirnames, filenames in os.walk(oh_no):
        # EXCLUDE the delegated slice's own worktree: prune it before descending so
        # legitimate in-worktree writes never register as a protected-set breach.
        dirnames[:] = [
            d for d in dirnames
            if os.path.realpath(os.path.join(dirpath, d)) != owned_real
        ]
        for name in filenames:
            path = os.path.join(dirpath, name)
            try:
                st = os.stat(path)
            except OSError:
                continue
            manifest[os.path.relpath(path, integration)] = [st.st_mtime_ns, st.st_size]
print(json.dumps(manifest, sort_keys=True))
SENTINEL
}

# escape_net_verdict <pre-manifest> <post-manifest> <owned-slug>
#
# PURE comparator over two `snapshot` manifests. Prints `clean` (exit 0) when the
# protected target set is unchanged, or `HALT <offending paths>` (exit 1) when an
# unexpected out-of-scope write appears. The guard's firing is gated
# deterministically offline, not merely implied by a clean live run. No jq/node;
# Python only.
escape_net_verdict() {
  local pre="$1" post="$2" owned_slug="$3"
  OH_NO_ESCAPE_PRE="$pre" OH_NO_ESCAPE_POST="$post" "$PYTHON_BIN" - "$owned_slug" <<'VERDICT'
import json, os, sys
owned_slug = sys.argv[1]
pre = json.loads(os.environ.get("OH_NO_ESCAPE_PRE") or "{}")
post = json.loads(os.environ.get("OH_NO_ESCAPE_POST") or "{}")
owned_prefix = "/".join((".oh-no", "worktrees", owned_slug))
offending = []
# (1) integration-checkout tracked/untracked-non-ignored delta. SYMMETRIC diff so a
# REMOVED status line (a deleted/restored tracked file, or a further edit that changes
# an existing line) is a breach too, not only additions. Lines that appear in exactly
# one of pre/post — added AND removed — both count.
for line in sorted(set(post.get("__git_status__", [])) ^ set(pre.get("__git_status__", []))):
    offending.append("git-status:" + line)
# (2) filesystem-sentinel delta over the ignored .oh-no/ subtree + sibling worktrees.
pre_fs = {k: v for k, v in pre.items() if k != "__git_status__"}
post_fs = {k: v for k, v in post.items() if k != "__git_status__"}
for path in sorted(set(pre_fs) | set(post_fs)):
    norm = path.replace(os.sep, "/")
    # Defensive: the owned slice's own worktree is never protected (snapshot already
    # prunes it; this second guard makes the comparator self-contained).
    if norm == owned_prefix or norm.startswith(owned_prefix + "/"):
        continue
    if pre_fs.get(path) != post_fs.get(path):
        offending.append("sentinel:" + path)
if offending:
    print("HALT " + " ".join(offending))
    sys.exit(1)
print("clean")
VERDICT
}

# Test 0 (offline gating floor) — the escape-net pure function's positive/clean/
# exclusion firing test. Builds a REAL synthetic .oh-no/ tree under a temp dir,
# runs the REAL sentinel probe over REAL files (not only a hand-built dict fed to
# the comparator, so a probe bug such as failing to recurse .oh-no/plans/ subdirs
# is caught), and feeds the resulting real snapshots to escape_net_verdict.
run_escape_net_offline_test() {
  log "Running offline escape-net pure-function firing test (test 0)"
  local tmp
  tmp="$(mktemp -d)"
  local owned="delegated-executor-runtime"
  local other="some-other-task"
  # A REAL git repo with `.oh-no/` gitignored, mirroring production: `git status`
  # is BLIND to the .oh-no/ subtree (so the sentinel arm is the only coverage there)
  # while the git-status arm covers tracked/untracked-NON-ignored integration files.
  # This lets the git-status symmetric-diff case (d) run over a REAL probe, not a
  # hand-built dict.
  (
    cd "$tmp"
    git init -q
    git config user.email escape-net@example.com
    git config user.name "escape-net test"
    printf '.oh-no/\n' >.gitignore
    git add .gitignore
    git commit -qm "seed: gitignore .oh-no/"
  )
  mkdir -p \
    "$tmp/.oh-no/plans/sub" \
    "$tmp/.oh-no/sessions" \
    "$tmp/.oh-no/specs" \
    "$tmp/.oh-no/test-runs" \
    "$tmp/.oh-no/worktrees/$owned" \
    "$tmp/.oh-no/worktrees/$other"
  printf 'plan\n' >"$tmp/.oh-no/plans/sub/plan.md"
  printf 'session\n' >"$tmp/.oh-no/sessions/s.md"
  printf 'spec\n' >"$tmp/.oh-no/specs/spec.md"
  printf 'owned work\n' >"$tmp/.oh-no/worktrees/$owned/owned.txt"
  printf 'other work\n' >"$tmp/.oh-no/worktrees/$other/other.txt"

  local pre post verdict rc
  pre="$(snapshot "$tmp" "$owned")"

  # (a) clean case: pre == post => clean.
  verdict="$(escape_net_verdict "$pre" "$(snapshot "$tmp" "$owned")" "$owned")" \
    || { rm -rf "$tmp"; fail "escape-net clean case exited non-zero: $verdict"; }
  [[ "$verdict" == "clean" ]] \
    || { rm -rf "$tmp"; fail "escape-net expected clean on identical snapshots, got: $verdict"; }

  # (b) owned-worktree-only delta => clean (exclusion works, proven at the probe level).
  printf 'more owned work\n' >>"$tmp/.oh-no/worktrees/$owned/owned.txt"
  printf 'new owned file\n' >"$tmp/.oh-no/worktrees/$owned/owned2.txt"
  verdict="$(escape_net_verdict "$pre" "$(snapshot "$tmp" "$owned")" "$owned")" \
    || { rm -rf "$tmp"; fail "escape-net owned-only delta case exited non-zero: $verdict"; }
  [[ "$verdict" == "clean" ]] \
    || { rm -rf "$tmp"; fail "escape-net expected clean on owned-worktree-only delta (exclusion), got: $verdict"; }

  # (c) INDUCED out-of-scope write: a NEW file under a sibling .oh-no/worktrees/<other>,
  # a size change under .oh-no/plans/, AND a NEW file under .oh-no/specs/ (C1: the
  # WHOLE .oh-no/ subtree is covered, including specs/, not a fixed dir allowlist)
  # => HALT listing ALL THREE offending paths.
  printf 'ESCAPE\n' >"$tmp/.oh-no/worktrees/$other/leak.txt"
  printf 'dirtied plan with many more bytes than before\n' >"$tmp/.oh-no/plans/sub/plan.md"
  printf 'ESCAPE spec\n' >"$tmp/.oh-no/specs/leak-spec.md"
  post="$(snapshot "$tmp" "$owned")"
  rc=0
  verdict="$(escape_net_verdict "$pre" "$post" "$owned")" || rc=$?
  [[ "$rc" != "0" ]] || { rm -rf "$tmp"; fail "escape-net FAILED to HALT on the induced out-of-scope write; verdict: $verdict"; }
  [[ "$verdict" == HALT* ]] || { rm -rf "$tmp"; fail "escape-net expected a HALT verdict, got: $verdict"; }
  case "$verdict" in
    *".oh-no/worktrees/$other/leak.txt"*) ;;
    *) rm -rf "$tmp"; fail "escape-net HALT did not list the sibling-worktree leak: $verdict" ;;
  esac
  case "$verdict" in
    *".oh-no/plans/sub/plan.md"*) ;;
    *) rm -rf "$tmp"; fail "escape-net HALT did not list the dirtied integration plan: $verdict" ;;
  esac
  # C1 RED case: before the whole-.oh-no/ sentinel walk, specs/ is uncovered, so this
  # induced .oh-no/specs/ write is invisible and this assertion fails.
  case "$verdict" in
    *".oh-no/specs/leak-spec.md"*) ;;
    *) rm -rf "$tmp"; fail "escape-net HALT did not list the .oh-no/specs/ escape (C1 whole-subtree coverage): $verdict" ;;
  esac

  # (d) git-status SYMMETRIC-diff (F3): a REMOVED status line between pre and post is a
  # breach too, not only additions. Create an untracked NON-ignored file at the
  # integration root (git status shows `?? stray.txt`), snapshot, remove it, snapshot;
  # the removed status line must HALT. Before the symmetric-diff fix (additions-only)
  # this is invisible (a removal is neither an addition nor a .oh-no/ sentinel delta).
  printf 'stray\n' >"$tmp/stray.txt"
  local pre_git post_git
  pre_git="$(snapshot "$tmp" "$owned")"      # git-status arm: `?? stray.txt` present
  rm -f "$tmp/stray.txt"
  post_git="$(snapshot "$tmp" "$owned")"     # `?? stray.txt` REMOVED between pre/post
  rc=0
  verdict="$(escape_net_verdict "$pre_git" "$post_git" "$owned")" || rc=$?
  rm -rf "$tmp"
  [[ "$rc" != "0" ]] || fail "escape-net FAILED to HALT on a REMOVED git-status line (F3 symmetric diff); verdict: $verdict"
  [[ "$verdict" == HALT* ]] || fail "escape-net expected a HALT verdict on a removed git-status line, got: $verdict"
  case "$verdict" in
    *"git-status:"*"stray.txt"*) ;;
    *) fail "escape-net HALT did not list the removed git-status line (F3): $verdict" ;;
  esac
  ok "escape-net pure function HALTs on induced out-of-scope writes (incl. .oh-no/specs/ and removed git-status lines) and stays clean otherwise (test 0)"
}

run_active_stale_scan_reader_offline_test() {
  log "Running offline active stale-scan reader regression"
  "$PYTHON_BIN" - "$MARKETPLACE_ROOT/scripts/validate-plugin-files.py" <<'PY' \
    || fail "offline active stale-scan reader regression failed"
import importlib.util
import pathlib
import sys
import tempfile

validator_path = pathlib.Path(sys.argv[1])
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("oh_no_validate_plugin_files", validator_path)
if spec is None or spec.loader is None:
    raise SystemExit(f"could not import validator: {validator_path}")
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)

with tempfile.TemporaryDirectory() as raw_tmp:
    tmp = pathlib.Path(raw_tmp)
    binary = tmp / "binary-fixture"
    extensionless = tmp / "run-hook"
    command_wrapper = tmp / "run-hook.cmd"
    invalid_utf8 = tmp / "invalid-utf8.txt"

    binary.write_bytes(b"compiled\x00payload\xff")
    extensionless.write_text("extensionless UTF-8: \uc548\uc804\n", encoding="utf-8")
    command_wrapper.write_text("@echo UTF-8: \uc548\uc804\r\n", encoding="utf-8")
    invalid_utf8.write_bytes(b"text candidate without NUL: \xff\xfe")

    if validator.read_active_stale_scan_text(binary) is not None:
        raise SystemExit("NUL-containing binary fixture was not skipped")
    if validator.read_active_stale_scan_text(extensionless) != "extensionless UTF-8: \uc548\uc804\n":
        raise SystemExit("extensionless UTF-8 text was not scanned")
    if validator.read_active_stale_scan_text(command_wrapper) != "@echo UTF-8: \uc548\uc804\r\n":
        raise SystemExit(".cmd UTF-8 text was not scanned")

    try:
        validator.read_active_stale_scan_text(invalid_utf8)
    except SystemExit as exc:
        message = str(exc)
        if str(invalid_utf8) not in message:
            raise SystemExit(f"controlled invalid-UTF8 error omitted path: {message}")
        if "Traceback" in message:
            raise SystemExit(f"invalid-UTF8 error leaked a traceback: {message}")
    else:
        raise SystemExit("non-NUL invalid-UTF8 text candidate did not fail")

print("ok - active stale-scan reader skips NUL binary and scans extensionless/.cmd UTF-8 text")
PY
  ok "active stale-scan reader handles binary, extensionless, .cmd, and invalid-UTF8 candidates"
}

validate_routing_hook_source_contract() {
  "$PYTHON_BIN" - "$PLUGIN_ROOT/hooks/session-start" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
problems = []
bootstrap_start = source.find("bootstrap_policy='")
bootstrap_end = source.find('\n\nauto_routing_policy=""', bootstrap_start)
bootstrap = ""
if bootstrap_start < 0 or bootstrap_end < 0:
    problems.append("cannot locate unconditional OH_NO_BOOTSTRAP source")
else:
    bootstrap = source[bootstrap_start + len("bootstrap_policy='") : bootstrap_end]
forced_match = re.search(
    r"auto_routing_policy='\s*(<OH_NO_FORCED_ROUTING>.*?</OH_NO_FORCED_ROUTING>)'",
    source,
    flags=re.DOTALL,
)
forced = forced_match.group(1) if forced_match else ""
if not forced:
    problems.append("cannot locate Claude OH_NO_FORCED_ROUTING source")

for marker in (
    "A workflow name used only as the subject of analysis, explanation, comparison, or critique is not an invocation trigger.",
    "Route from the requested deliverable: an analysis report versus a plan or execution artifact.",
):
    if marker not in bootstrap:
        problems.append(f"unconditional bootstrap missing object-of-analysis owner: {marker}")
    if marker in forced:
        problems.append(f"forced block duplicates object-of-analysis owner: {marker}")
for marker in (
    "Routing reminder:",
    "using-oh-no-harness",
    "Use oh-no-harness:test-driven-development only as an explicit TDD/test-first route",
):
    if marker in bootstrap:
        problems.append(f"unconditional bootstrap retains retired routing text: {marker}")

forced_lower = forced.lower()
if "routing map" in forced_lower or forced_lower.count("oh-no-harness:") > 1:
    problems.append("Claude forced block retains an exhaustive positive catalog")
if (
    'if [ "$is_claude_code" = true ] && "${OH_NO_PLUGIN_ROOT}/scripts/oh-no-config" is-enabled' not in source
    or source.count("<OH_NO_FORCED_ROUTING>") != 1
):
    problems.append("forced routing is not singular and Claude-only")

if problems:
    raise SystemExit(
        "Claude routing hook source contract failed:\n  - " + "\n  - ".join(problems)
    )
print("ok - Claude routing hook source matches description-owned target shape")
PY
}

validate_hooks() {
  log "Validating hook wiring"
  validate_routing_hook_source_contract
  assert_json_valid "$PLUGIN_ROOT/hooks/hooks.json"
  bash -n "$PLUGIN_ROOT/hooks/session-start"
  bash -n "$PLUGIN_ROOT/scripts/oh-no-config"
  ok "shell syntax: hooks/session-start"
  ok "shell syntax: scripts/oh-no-config"
  local hook_config hook_rc=0
  hook_config="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-hook-config.XXXXXX")"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" OH_NO_CONFIG_DIR="$hook_config" "$PLUGIN_ROOT/hooks/run-hook.cmd" session-start \
    | "$PYTHON_BIN" -m json.tool >/dev/null || hook_rc=$?
  rm -rf "$hook_config"
  [[ "$hook_rc" == 0 ]] || return "$hook_rc"
  ok "session-start emits valid JSON"

  local temp_data
  temp_data="$(mktemp -d)"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/hooks/run-hook.cmd" session-start >"$temp_data/hook-off.json"
  "$PYTHON_BIN" - "$temp_data/hook-off.json" "$PLUGIN_ROOT" <<'PY'
import json, sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
text = json.dumps(data)
if "OH_NO_FORCED_ROUTING" in text:
    raise SystemExit("forced-routing policy was present while config is unset")
if "OH_NO_AUTO_ROUTING" in text:
    raise SystemExit("legacy auto-routing tag was present while config is unset")
if "Use native skill loading to read the relevant Oh No Harness skill when it applies." not in text:
    raise SystemExit("base bootstrap is missing compact native skill-loading guidance")
required = ["No-route lane", "Direct-edit lane",
    "A workflow name used only as the subject of analysis, explanation, comparison, or critique is not an invocation trigger.",
    "Route from the requested deliverable: an analysis report versus a plan or execution artifact.",
    "Child packet floor", "caller sends a proportional self-contained English packet", "purpose/outcome", "target role", "repo mutation/review/verify", "exact target/revision + result/revision binding", "scope/permissions/non-goals", "contract/acceptance", "evidence/output", "stop/escalation", "Initial independent review/verify/debug", "withholds maker conclusions", "expected verdicts", "sibling output", "preferred causes", "disclose only later for audit/clarification",
]
missing = [needle for needle in required if needle not in text]
if missing:
    raise SystemExit(f"Claude SessionStart missing unconditional routing/child-packet boundaries: {missing}")
if text.count("Child packet floor:") != 1: raise SystemExit("Claude SessionStart child-packet floor is not singular")
for forbidden in ("Global Context Capsule", "Capsule delta", "_global-context-capsule.md", "Purpose\\nAssigned outcome / acceptance criteria"):
    if forbidden in text: raise SystemExit(f"Claude SessionStart retains former receiver schema: {forbidden}")
for forbidden in (
    "OH_NO_SKILL_CORE",
    "Below is the full content",
    "docs/skill-core/using-oh-no-harness.md",
    "Routing reminder:",
    "using-oh-no-harness",
    "Use oh-no-harness:test-driven-development only as an explicit TDD/test-first route",
):
    if forbidden in text:
        raise SystemExit(f"base bootstrap retains retired routing content: {forbidden}")
for forbidden in (
    "CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION",
    "explicit user request for eligible Oh No Harness workflow",
    "Custom-Agent Spawn Troubleshooting",
    "before fallback",
):
    if forbidden in text:
        raise SystemExit(f"Claude SessionStart leaked Codex subagent policy: {forbidden}")
for forbidden in (
    "About to make a behavior-changing production edit: oh-no-harness:test-driven-development",
    "behavior-changing edits go through test-driven-development",
):
    if forbidden in text:
        raise SystemExit(f"Claude SessionStart still routes ordinary implementation to TDD: {forbidden}")
# Baseline includes the always-on OH_NO_MAIN_AGENT_ORCHESTRATION block; keep
# headroom modest so unintended bloat still trips this guard.
if len(text) > 6600:
    raise SystemExit(f"Claude SessionStart default context is too large: {len(text)} chars")
PY
  OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/scripts/oh-no-config" on >"$temp_data/helper-on.txt"
  OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/scripts/oh-no-config" off >"$temp_data/helper-off.txt"
  OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/scripts/oh-no-config" on >/dev/null
  OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/scripts/oh-no-config" path >"$temp_data/helper-path.txt"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/hooks/run-hook.cmd" session-start >"$temp_data/hook-on.json"
  "$PYTHON_BIN" - "$temp_data/hook-on.json" "$PLUGIN_ROOT/skills-claude/auto-routing/SKILL.md" "$temp_data" <<'PY'
import json, re, sys
from pathlib import Path

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = json.dumps(data)
root = Path(sys.argv[3])
expected_config = root / "config.json"
if (root / "helper-path.txt").read_text(encoding="utf-8").strip() != str(expected_config):
    raise SystemExit("auto-routing helper path escaped the disposable config directory")
helper_outputs = {state: (root / f"helper-{state}.txt").read_text(encoding="utf-8") for state in ("on", "off")}
for state, output in helper_outputs.items():
    if f"auto-routing: {state}" not in output or f"config: {expected_config}" not in output:
        raise SystemExit(f"auto-routing helper did not report persisted {state} state in the disposable directory")
    for forbidden in ("restart", "immediate", "current turn", "current-turn", "stronger", "exhaustive", "routing semantics changed", "changes routing semantics"):
        if forbidden in output.lower():
            raise SystemExit(f"auto-routing helper overclaims platform routing semantics: {forbidden}")
wrapper = Path(sys.argv[2]).read_text(encoding="utf-8")
wrapper_normal = re.sub(r"[^a-z0-9/]+", " ", wrapper.lower())
missing_wrapper = [value for value in ("native skill descriptions", "select the destination", "on claude code", "next sessionstart") if value not in wrapper_normal]
if missing_wrapper or "/clear" not in wrapper.lower():
    raise SystemExit(f"generated Claude auto-routing wrapper misses ownership/effect-boundary semantics: {missing_wrapper}")
if not (forced_match := re.search(r"<OH_NO_FORCED_ROUTING>.*?</OH_NO_FORCED_ROUTING>", text)):
    raise SystemExit("forced-routing policy missing while config is enabled")
forced_text = forced_match.group(0)
for forbidden in (
    "Routing map",
    "Red flags",
    "A workflow name used only as the subject of analysis",
    "Route from the requested deliverable: an analysis report versus a plan or execution artifact.",
):
    if forbidden in forced_text:
        raise SystemExit(f"forced-routing policy retains duplicated routing content: {forbidden}")
required = [
    "installed skill descriptions",
    "explicit end-to-end",
    "active failure",
    "explicit test-first",
    "most upstream incomplete prerequisite",
    "The always-injected OH_NO_BOOTSTRAP no-route, direct-edit, and object",
]
missing = [needle for needle in required if needle.lower() not in forced_text.lower()]
if missing:
    raise SystemExit(f"forced-routing policy missing target ordering/precedence markers: {missing}")
for forbidden in (
    "About to make a behavior-changing production edit: oh-no-harness:test-driven-development",
    "behavior-changing edits go through test-driven-development",
):
    if forbidden in forced_text:
        raise SystemExit(f"forced-routing policy still routes ordinary implementation to TDD: {forbidden}")
PY
  rm -rf "$temp_data"
  ok "session-start respects auto-routing config"

  temp_data="$(mktemp -d)"
  local temp_path
  temp_path="$temp_data/bin"
  mkdir -p "$temp_path"
  ln -s "$(command -v bash)" "$temp_path/bash"
  ln -s "$(command -v cat)" "$temp_path/cat"
  ln -s "$(command -v dirname)" "$temp_path/dirname"

  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" OH_NO_CONFIG_DIR="$temp_data" PATH="$temp_path" "$PLUGIN_ROOT/hooks/run-hook.cmd" session-start >"$temp_data/hook-no-rg.json"
  "$PYTHON_BIN" - "$temp_data/hook-no-rg.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = json.dumps(data)
if "OH_NO_RG_SEARCH_TOOLING" in text:
    raise SystemExit("rg search tooling policy was present while rg is unavailable")
PY

  cat >"$temp_path/rg" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$temp_path/rg"

  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" OH_NO_CONFIG_DIR="$temp_data" PATH="$temp_path" "$PLUGIN_ROOT/hooks/run-hook.cmd" session-start >"$temp_data/hook-with-rg.json"
  "$PYTHON_BIN" - "$temp_data/hook-with-rg.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = json.dumps(data)
if "OH_NO_RG_SEARCH_TOOLING" not in text:
    raise SystemExit("rg search tooling policy missing while rg is available")
if "rg --files" not in text:
    raise SystemExit("rg search tooling policy is missing rg --files guidance")
PY
  rm -rf "$temp_data"
  ok "session-start adds rg search guidance only when rg is available"

  "$PYTHON_BIN" - "$PLUGIN_ROOT/hooks/hooks.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    hooks = json.load(fh)

required = {"SessionStart"}
actual = set(hooks.get("hooks", {}).keys())
extra = actual - required
missing = required - actual
if extra or missing:
    raise SystemExit(f"Unexpected hook events. missing={sorted(missing)} extra={sorted(extra)}")
PY
  ok "SessionStart is the only configured plugin hook"
}

validate_manifests() {
  log "Validating plugin manifests"
  assert_json_valid "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  assert_json_valid "$MARKETPLACE_ROOT/.claude-plugin/marketplace.json"
  assert_json_valid "$PLUGIN_ROOT/.codex-plugin/plugin.json"
  "$CLAUDE_BIN" plugin validate "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  "$CLAUDE_BIN" plugin validate "$MARKETPLACE_ROOT/.claude-plugin/marketplace.json"
}

install_or_update_plugin() {
  [[ "$INSTALL_MODE" == "1" ]] || { log "Skipping install/update (--no-install)"; return; }

  guard_canonical_local_marketplace

  log "Ensuring Claude Code marketplace is registered"
  local target_scope
  local installed_scope=""

  if installed_scope="$(installed_scope_for_plugin 2>/dev/null)"; then
    target_scope="$installed_scope"
    ok "plugin already installed in ${target_scope} scope"
  else
    target_scope="${REQUESTED_SCOPE:-user}"
    ok "plugin not installed; target scope is ${target_scope}"
  fi

  if [[ -n "$REQUESTED_SCOPE" ]]; then
    target_scope="$REQUESTED_SCOPE"
  fi

  if [[ "$target_scope" == "managed" && -z "$installed_scope" ]]; then
    fail "managed scope can only update an existing managed install; choose local, project, or user for a new install"
  fi

  local source_for_log
  source_for_log="$(marketplace_source_tool redact "$MARKETPLACE_SOURCE")"
  if marketplace_exists; then
    log "Refreshing marketplace registration from ${source_for_log}"
    "$CLAUDE_BIN" plugin marketplace remove "$MARKETPLACE_NAME"
  else
    log "Adding marketplace from ${source_for_log}"
  fi
  "$CLAUDE_BIN" plugin marketplace add --scope "$target_scope" "$MARKETPLACE_SOURCE"
  ok "marketplace registered: ${MARKETPLACE_NAME} -> ${source_for_log} (${target_scope})"

  if "$CLAUDE_BIN" plugin list --json \
      | "$PYTHON_BIN" -c 'import json, sys
plugin_id, scope = sys.argv[1], sys.argv[2]
data = json.load(sys.stdin)
for item in data:
    if item.get("id") == plugin_id and item.get("scope") == scope:
        sys.exit(0)
sys.exit(1)
' "$PLUGIN_ID" "$target_scope"
  then
    log "Updating installed plugin"
    "$CLAUDE_BIN" plugin update --scope "$target_scope" "$PLUGIN_ID"
    ok "plugin updated: ${PLUGIN_ID} (${target_scope})"
  else
    log "Installing plugin"
    "$CLAUDE_BIN" plugin install --scope "$target_scope" "$PLUGIN_ID"
    ok "plugin installed: ${PLUGIN_ID} (${target_scope})"
  fi

  refresh_installed_plugin_cache "$target_scope"

  "$CLAUDE_BIN" plugin list --json \
    | "$PYTHON_BIN" -c 'import json, sys
plugin_id, scope = sys.argv[1], sys.argv[2]
data = json.load(sys.stdin)
for item in data:
    if item.get("id") == plugin_id and item.get("scope") == scope:
        print("{} {} enabled={} scope={}".format(item["id"], item.get("version", "?"), item.get("enabled"), item.get("scope")))
        sys.exit(0)
raise SystemExit(f"{plugin_id} not installed in {scope} scope after install/update")
' "$PLUGIN_ID" "$target_scope"
}

live_prompt_for_skill() {
  case "$1" in
    interview)
      printf '/%s:interview --quick Build a tiny note-taking feature. Smoke test only; you may read plugin skill-core and platform docs if needed; do not edit files. Reply with the first clarification question you would ask.' "$PLUGIN_NAME"
      ;;
    ralplan)
      printf '/%s:ralplan Add a small smoke-test feature to an existing app. Smoke test only; you may read plugin skill-core and platform docs if needed; do not edit files. Reply with the planning artifact you would create and the approval gate.' "$PLUGIN_NAME"
      ;;
    ralph)
      printf '/%s:ralph Approved no-op smoke-test plan: inspect scope, make no file changes, and report verification approach. Smoke test only; you may read plugin skill-core and platform docs if needed; do not edit files. Reply with how execution would proceed.' "$PLUGIN_NAME"
      ;;
    ultrawork)
      printf '/%s:ultrawork Deliver a small smoke-test workflow from vague request to verification. Smoke test only; you may read plugin skill-core and platform docs if needed; do not edit files. Reply with the workflow stages you would orchestrate.' "$PLUGIN_NAME"
      ;;
    auto-routing)
      printf '/%s:auto-routing status Smoke test only. Read the generated skill document and answer this read-only platform-semantics question; do not change any setting, config, or file. Explain how native destination descriptions own positive selection, what Claude auto-routing adds, why its effect boundary is the next Claude SessionStart with /clear, and why current-turn activation, a generic restart alone, or a stronger/exhaustive destination router are not effects.' "$PLUGIN_NAME"
      ;;
    test-driven-development)
      printf '/%s:test-driven-development Explicit TDD/test-first smoke request. Smoke test only; you may read plugin skill-core and platform docs if needed; do not edit files. Reply with the TDD cycle steps you would follow.' "$PLUGIN_NAME"
      ;;
    simplify)
      printf '/%s:simplify --review Review a small diff for reuse, simplification, efficiency, and altitude cleanup. Smoke test only; you may read plugin skill-core and platform docs if needed; do not edit files. Reply with the cleanup categories you would check.' "$PLUGIN_NAME"
      ;;
    verification-before-completion)
      printf '/%s:verification-before-completion Smoke test only; you may read plugin skill-core and platform docs if needed; do not edit files. Reply with the evidence gate you would apply before claiming completion.' "$PLUGIN_NAME"
      ;;
    systematic-debugging)
      printf '/%s:systematic-debugging A smoke test command is failing. Smoke test only; you may read plugin skill-core and platform docs if needed; do not edit files. Reply with the debugging phases you would follow before fixing.' "$PLUGIN_NAME"
      ;;
    fusion-rescue)
      printf '/%s:fusion-rescue Approved no-op smoke-test problem: compare three panel views, make no file changes, and report synthesis fields. Smoke test only; you may read plugin skill-core and platform docs if needed; do not edit files. Reply with the panel slots and judge/synthesis fields you would use.' "$PLUGIN_NAME"
      ;;
    install-statusline)
      printf '/%s:install-statusline check Smoke test only. You may read plugin skill-core and platform docs needed by the invoked skill. Do not edit files or run the installer. Reply with what this setup skill installs and that it is user-invoked only.' "$PLUGIN_NAME"
      ;;
    configure-subagents)
      printf '/%s:configure-subagents check Smoke test only. You may read plugin skill-core and platform docs needed by the invoked skill. Do not edit files or run the configurator. Reply with what this setup skill configures, that it asks about CLIProxyAPI first, and that it is user-invoked only.' "$PLUGIN_NAME"
      ;;
    *)
      fail "No live prompt for skill: $1"
      ;;
  esac
}

run_live_skill_test() {
  local skill="$1"
  local out_file="$RUN_DIR/${skill}.json"
  local prompt
  prompt="$(live_prompt_for_skill "$skill")"
  prompt="$prompt Ground your reply in the skill document the command tells you to read; if you cannot read it, say so instead of answering from memory."

  local cmd=(
    "$CLAUDE_BIN"
    --print
    --verbose
    --output-format stream-json
    --model "$LIVE_MODEL"
    --max-budget-usd "$LIVE_MAX_BUDGET_USD"
    --permission-mode dontAsk
    # Read is required: the plugin command wrapper instructs the model to Read
    # the generated SKILL.md, so with --tools "" the skill body never reaches
    # context and the smoke result is a prior-knowledge guess or a refusal.
    --tools "Read"
    --no-session-persistence
    --system-prompt "$LIVE_SYSTEM_PROMPT"
  )

  append_live_plugin_dir_arg

  cmd+=("$prompt")

  run_plugin_dir_live_process_with_timeout "${cmd[@]}" >"$out_file"

  "$PYTHON_BIN" - "$out_file" "$skill" <<'PY'
import json, re, sys

path, skill = sys.argv[1], sys.argv[2]
result = ""
cost = None
read_paths = []

with open(path, "r", encoding="utf-8") as fh:
    for line_number, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        if data.get("type") == "assistant":
            for part in data.get("message", {}).get("content", []):
                if part.get("type") != "tool_use" or part.get("name") != "Read":
                    continue
                payload = part.get("input", {})
                read_path = payload.get("file_path") or payload.get("path")
                if isinstance(read_path, str):
                    read_paths.append(read_path.replace("\\", "/"))
        if data.get("type") == "result":
            if data.get("is_error"):
                raise SystemExit(f"{skill} live smoke failed: {data.get('result')}")
            result = str(data.get("result", "")).strip()
            cost = data.get("total_cost_usd")

if not result:
    raise SystemExit(f"{skill} live smoke returned an empty result")
if result.startswith("Unknown command:"):
    raise SystemExit(f"{skill} live smoke did not resolve the Claude slash command: {result}")
expected_suffix = f"/skills-claude/{skill}/SKILL.md"
if not any(f"/{value.lstrip('/')}".endswith(expected_suffix) for value in read_paths):
    raise SystemExit(
        f"{skill} live smoke answered without a Read of its generated SKILL.md; "
        f"read_paths={read_paths!r}"
    )
if skill == "auto-routing":
    lower = result.lower()
    normalized = re.sub(r"[^a-z0-9/]+", " ", lower)
    if not re.search(r"\bnext (?:claude(?: code)? )?sessionstart\b", normalized) or "/clear" not in lower:
        raise SystemExit("auto-routing response misses next Claude SessionStart effect boundary or /clear guidance")

print(f"ok - live skill smoke: {skill} cost={cost}")
PY
}

run_live_hook_test() {
  local out_file="$RUN_DIR/hook-policy-${LIVE_LOAD_MODE}.jsonl"
  local prompt="Smoke test only. Inspect your session-start instructions, not this user message. If they include both a Claude Code-only policy telling you to use AskUserQuestion for clarification, preference, scope, or approval questions when available, and compact Oh No Harness guidance telling you to use native skill loading for relevant Oh No Harness skills, reply exactly OH_NO_HOOK_POLICY_PRESENT. Otherwise reply exactly OH_NO_HOOK_POLICY_MISSING."

  local cmd=(
    "$CLAUDE_BIN"
    --print
    --verbose
    --output-format stream-json
    --include-hook-events
    --model "$LIVE_MODEL"
    --max-budget-usd "$LIVE_MAX_BUDGET_USD"
    --permission-mode dontAsk
    --tools default
    --no-session-persistence
    --system-prompt "$LIVE_SYSTEM_PROMPT"
  )

  append_live_plugin_dir_arg

  cmd+=("$prompt")
  run_plugin_dir_live_process_with_timeout "${cmd[@]}" >"$out_file"

  "$PYTHON_BIN" - "$out_file" "$LIVE_LOAD_MODE" <<'PY'
import json
import sys

path, load_mode = sys.argv[1], sys.argv[2]
session_start_hooks = 0
successful_policy_hook_responses = 0
assistant_policy_present = False
loaded_oh_no_plugin = load_mode == "plugin-dir"
ask_user_question_available = False
result = None
cost = None

with open(path, "r", encoding="utf-8") as fh:
    for line in fh:
        if not line.strip():
            continue
        data = json.loads(line)
        if data.get("type") == "system" and data.get("subtype") == "hook_started" and data.get("hook_event") == "SessionStart":
            session_start_hooks += 1
        if data.get("type") == "system" and data.get("subtype") == "hook_response" and data.get("hook_event") == "SessionStart":
            output = data.get("output", "")
            has_question_policy = "CLAUDE_CODE_ONLY" in output and "AskUserQuestion" in output
            has_compact_bootstrap = (
                "OH_NO_BOOTSTRAP" in output
                and "Use native skill loading to read the relevant Oh No Harness skill when it applies." in output
                and "OH_NO_SKILL_CORE" not in output
            )
            if data.get("outcome") == "success" and has_question_policy and has_compact_bootstrap:
                successful_policy_hook_responses += 1
        if data.get("type") == "system" and data.get("subtype") == "init":
            for plugin in data.get("plugins", []):
                source = plugin.get("source", "")
                name = plugin.get("name", "")
                if name == "oh-no-harness" or "oh-no-harness" in source:
                    loaded_oh_no_plugin = True
            ask_user_question_available = "AskUserQuestion" in data.get("tools", [])
        if data.get("type") == "assistant":
            text = "".join(
                part.get("text", "")
                for part in data.get("message", {}).get("content", [])
                if part.get("type") == "text"
            )
            if "OH_NO_HOOK_POLICY_PRESENT" in text:
                assistant_policy_present = True
        if data.get("type") == "result":
            result = data.get("result")
            cost = data.get("total_cost_usd")

if session_start_hooks < 1:
    raise SystemExit("no SessionStart hook was observed")
if successful_policy_hook_responses < 1:
    raise SystemExit("SessionStart hook did not emit both the AskUserQuestion policy and compact native skill-loading bootstrap")
if not loaded_oh_no_plugin:
    raise SystemExit("oh-no-harness plugin was not reported as loaded")
if not ask_user_question_available:
    # Non-gating: AskUserQuestion is an interactive-only tool that the host CLI
    # does not expose in non-interactive --print mode (confirmed across all
    # permission modes). The plugin's actual responsibility — injecting the
    # AskUserQuestion policy into the SessionStart hook output — is hard-gated by
    # the successful_policy_hook_responses check above. Tool presence in the
    # runtime is a host/CLI property the plugin cannot control, so a print-mode
    # absence is environment variance, not a plugin defect.
    print(
        "WARN: AskUserQuestion not exposed in --print tool list "
        "(host/CLI interactive-only; SessionStart policy injection still gated above)",
        file=sys.stderr,
    )
if not assistant_policy_present:
    print(
        "WARN: model did not echo OH_NO_HOOK_POLICY_PRESENT (model variance); "
        f"deterministic SessionStart policy injection still gated above; result={result!r}",
        file=sys.stderr,
    )

print(f"ok - live Claude hook policy smoke: load_mode={load_mode} cost={cost}")
PY
}

run_live_auto_routing_case() {
  local state="$1"
  local config_dir="$2"
  local expected="$3"
  local out_file="$RUN_DIR/auto-routing-${state}-${LIVE_LOAD_MODE}.jsonl"
  local prompt="Smoke test only. Inspect the literal session-start hook instructions, not this user message. Look for the forced-routing marker tag whose name is formed by joining OH, NO, FORCED, and ROUTING with underscores. If that marker appears in the session-start hook instructions, reply exactly AUTO_ROUTING_MARKER_PRESENT. If that marker is absent, reply exactly AUTO_ROUTING_MARKER_MISSING. Do not infer from the default Oh No Harness core rule."

  local cmd=(
    "$CLAUDE_BIN"
    --print
    --verbose
    --output-format stream-json
    --include-hook-events
    --model "$LIVE_MODEL"
    --max-budget-usd "$LIVE_MAX_BUDGET_USD"
    --permission-mode dontAsk
    --tools default
    --no-session-persistence
    --system-prompt "$LIVE_SYSTEM_PROMPT"
  )

  append_live_plugin_dir_arg

  cmd+=("$prompt")
  OH_NO_CONFIG_DIR="$config_dir" run_live_process_with_timeout "${cmd[@]}" >"$out_file"

  "$PYTHON_BIN" - "$out_file" "$expected" "$state" <<'PY'
import json
import sys

path, expected, state = sys.argv[1], sys.argv[2], sys.argv[3]
session_start_hooks = 0
hook_policy_present = False
assistant_present = False
assistant_missing = False
result = None
cost = None

with open(path, "r", encoding="utf-8") as fh:
    for line in fh:
        if not line.strip():
            continue
        data = json.loads(line)
        if data.get("type") == "system" and data.get("subtype") == "hook_started" and data.get("hook_event") == "SessionStart":
            session_start_hooks += 1
        if data.get("type") == "system" and data.get("subtype") == "hook_response" and data.get("hook_event") == "SessionStart":
            if "OH_NO_FORCED_ROUTING" in data.get("output", ""):
                hook_policy_present = True
        if data.get("type") == "assistant":
            text = "".join(
                part.get("text", "")
                for part in data.get("message", {}).get("content", [])
                if part.get("type") == "text"
            )
            if "AUTO_ROUTING_MARKER_PRESENT" in text:
                assistant_present = True
            if "AUTO_ROUTING_MARKER_MISSING" in text:
                assistant_missing = True
        if data.get("type") == "result":
            result = data.get("result")
            cost = data.get("total_cost_usd")

if session_start_hooks < 1:
    raise SystemExit(f"auto-routing {state}: no SessionStart hook was observed")

# The deterministic gate is whether the SessionStart hook OUTPUT carries
# OH_NO_FORCED_ROUTING per the auto-routing config — that is the plugin's
# responsibility and stays a hard failure. Whether a single stochastic --print
# model answer echoes PRESENT/MISSING is model-interpretation variance (the
# model may read the always-present default routing reminder despite the "do not
# infer from the default core rule" instruction), so it is demoted to a WARN,
# consistent with the non-gating live deep-smoke direction.
if expected == "present":
    if not hook_policy_present:
        raise SystemExit("auto-routing enabled but hook output did not contain OH_NO_FORCED_ROUTING")
    if not assistant_present or assistant_missing:
        print(f"WARN: auto-routing enabled but model did not report PRESENT (model variance); result={result!r}", file=sys.stderr)
else:
    if hook_policy_present:
        raise SystemExit("auto-routing disabled but hook output contained OH_NO_FORCED_ROUTING")
    if not assistant_missing or assistant_present:
        print(f"WARN: auto-routing disabled but model did not report MISSING (model variance); result={result!r}", file=sys.stderr)

print(f"ok - live Claude auto-routing {state}: cost={cost}")
PY
}

run_live_auto_routing_test() {
  local temp_root off_dir on_dir
  temp_root="$(mktemp -d)"
  off_dir="$temp_root/off"
  on_dir="$temp_root/on"
  mkdir -p "$off_dir" "$on_dir"

  OH_NO_CONFIG_DIR="$on_dir" "$PLUGIN_ROOT/scripts/oh-no-config" on >/dev/null
  run_live_auto_routing_case off "$off_dir" missing
  run_live_auto_routing_case on "$on_dir" present
  rm -rf "$temp_root"
}

run_live_tests() {
  if [[ "$RUN_LIVE" != "1" ]]; then
    log "Skipping live Claude skill smoke tests"
    printf 'Run with --live or OH_NO_LIVE=1 to invoke the public /skill commands and live hook policy test.\n' >&2
    return
  fi

  log "Running live Claude hook policy test (${LIVE_LOAD_MODE})"
  mkdir -p "$RUN_DIR"
  run_live_hook_test
  run_live_auto_routing_test

  if [[ "$LIVE_HOOK_ONLY" == "1" ]]; then
    ok "live hook output saved under ${RUN_DIR#$MARKETPLACE_ROOT/}"
    return
  fi

  log "Running live Claude skill smoke tests (${LIVE_LOAD_MODE})"
  for skill in "${PUBLIC_SKILLS[@]}"; do
    run_live_skill_test "$skill"
  done
  ok "live outputs saved under ${RUN_DIR#$MARKETPLACE_ROOT/}"
}

deep_prompt_for_skill() {
  case "$1" in
    interview)
      printf '/%s:interview --quick Deep smoke test only. Read the invariants, state machine, snapshot, company-context rules, and Socratic guidance in the wrapper. Do not create artifacts or edit files. Return when company context should be considered, whether it is advisory or executable, whether remote/global systems should be searched for it, and the names of the Socratic guidance sections for question routing, answer capture, and the Spec Closure Gate including acceptance criteria, goal restatement, and machine-consumable requirements. End with OH_NO_CLAUDE_DEEP_OK interview.' "$PLUGIN_NAME"
      ;;
    ralplan)
      printf '/%s:ralplan Deep smoke test only. Read the invariants, Direction Contract, planning-run snapshot, state machine, proportional test design, mode selection, and execution profile. Do not create artifacts or edit files. Return the Direction Contract fields and single canonical schema owner, single-review-round rule, approval status term, conditional Analyst -> Planner -> Plan-Reviewer ordering rule, STANDARD perspective-diverse Plan-Reviewer pair rule, named THOROUGH escalated-diversity trigger, final-revision-v2 / no-re-review rule, required Blocking basis field, APPROVE exact-draft freeze and non-blocking optional-follow-up rule, process budget, Ralph execution profile, and project-local worktree path. End with OH_NO_CLAUDE_DEEP_OK ralplan.' "$PLUGIN_NAME"
      ;;
    ralph)
      printf '/%s:ralph Deep smoke test only. Read the wrapper invariants, state machine, snapshot, and gates. Do not create artifacts or edit files. Return the Direction Contract, the four phases and three outcomes, execution mode decision heading, mode-gated dispatch heading, parallel trigger, canonical verification ledger, STANDARD perspective-diverse code-reviewer pair rule, named THOROUGH escalated-diversity trigger, cumulative per-story Process Budget timing, final Diff-Budget exactly-once-before-Review timing, proportional cleanup rule, default worktree path, and TDD internal mid-loop discipline boundary including that TDD is not a top-level implementation route. End with OH_NO_CLAUDE_DEEP_OK ralph.' "$PLUGIN_NAME"
      ;;
    ultrawork)
      printf '/%s:ultrawork Deep smoke test only. Read the wrapper invariants, heartbeat, state machine, and phase procedures, following the linked phase skills where needed. Do not create artifacts or edit files. Return the spec artifact path from clarification, the single-review-round planning rule, the project-local automatic worktree path, the Ultrawork auto-approval rule after interview/spec approval, how ralplan approval becomes a recorded internal execution approval, how ralph is invoked with the Ultrawork-approved plan, the required execution mode source in the final report, and the cleanup/final-verification heading reached through execution. End with OH_NO_CLAUDE_DEEP_OK ultrawork.' "$PLUGIN_NAME"
      ;;
    simplify)
      printf '/%s:simplify --review Deep smoke test only. Read the shared simplify core and Claude Code platform docs. Do not create artifacts or edit files. Return the Required Behavior Lock and Phase headings; the LIGHT/STANDARD combined-scan default; the named THOROUGH trigger for four independent Reuse, Simplification, Efficiency, and Altitude passes; batch/fallback behavior only after that trigger; and the false-positive or behavior-changing skip rule. End with OH_NO_CLAUDE_DEEP_OK simplify.' "$PLUGIN_NAME"
      ;;
    auto-routing)
      printf '/%s:auto-routing Deep smoke test only. Do NOT change any settings and do NOT run oh-no-config; read the skill body and Claude Code platform notes, then answer read-only. Return the oh-no-config on/off/status commands, the default OFF state, the external config location, and the restart or /clear requirement. End with OH_NO_CLAUDE_DEEP_OK auto-routing.' "$PLUGIN_NAME"
      ;;
    *)
      fail "No deep live prompt for skill: $1"
      ;;
  esac
}

assert_deep_json_output() {
  "$PYTHON_BIN" - "$1" "$2" <<'PY'
import json
import sys

SEMANTIC_VARIANCE_EXIT = 88

path, skill = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

if data.get("is_error"):
    raise SystemExit(f"{skill} deep smoke failed: {data.get('result')}")
if data.get("permission_denials"):
    raise SystemExit(f"{skill} deep smoke had permission denials: {data.get('permission_denials')!r}")

text = str(data.get("result", ""))
if text.strip().startswith("Unknown command:"):
    raise SystemExit(f"{skill} deep smoke did not resolve the Claude slash command: {text!r}")
text_lower = text.lower()
expected = {
    "interview": [
        "advisory",
        "Question Routing",
        "Answer Capture",
        "Spec Closure Gate",
        "Acceptance criteria",
        "Goal restatement",
        "Machine-consumable",
    ],
    "ralplan": [
        "pending approval",
        "Direction Contract",
        "Overall Ralph mode",
        "Task sizing",
        "Execution profile",
        "Analyst",
        "Planner",
        "STANDARD",
        "perspective",
        "pair",
        "named THOROUGH",
        "diversity",
        "process budget",
        ".oh-no/worktrees/<task-slug>",
    ],
    "ralph": [
        "Direction Contract",
        "PREPARE",
        "FINALIZE",
        "Required Execution Mode",
        "Mode-Gated Agent Dispatch",
        "STANDARD",
        "THOROUGH",
        "Parallel trigger",
        "Acceptance-to-evidence ledger",
        "perspective",
        "pair",
        "diversity",
        "combined scan",
        ".oh-no/worktrees/<task-slug>",
        "test-driven-development",
        "internal mid-loop",
    ],
    "ultrawork": [
        ".oh-no/specs/interview-{slug}.md",
        ".oh-no/worktrees/<task-slug>",
        "auto",
        "approval",
        "ralplan",
        "ralph",
        "Ultrawork-approved",
        "Mode source",
        "Cleanup And Final Verification",
    ],
    "simplify": [
        "Required Behavior Lock",
        "Phase 0 - Gather The Diff",
        "Phase 1 - Review",
        "Phase 2 - Apply The Fixes",
        "Reuse",
        "Simplification",
        "Efficiency",
        "Altitude",
        "subagent",
        "batch",
        "before waiting",
        "inline",
        "dispatch-unavailable reason",
        "false positive",
        "intended behavior",
    ],
    "auto-routing": [
        "oh-no-config",
        "on",
        "off",
        "status",
        "config",
        "restart",
    ],
}

missing = [needle for needle in expected[skill] if needle.lower() not in text_lower]
if missing:
    print(f"{skill} deep smoke missing markers: {missing}; got {text!r}", file=sys.stderr)
    raise SystemExit(SEMANTIC_VARIANCE_EXIT)

if skill in {"ralplan", "ultrawork"} and not any(
    marker in text_lower
    for marker in ("one round", "one review round", "single round", "single review round", "exactly once")
):
    print(f"{skill} deep smoke missing single-review-round marker; got {text!r}", file=sys.stderr)
    raise SystemExit(SEMANTIC_VARIANCE_EXIT)

if skill == "ralph" and not (
    "not a top-level implementation" in text_lower
    or "not the top-level route" in text_lower
    or "not a top-level route" in text_lower
    or ("not" in text_lower and "top-level" in text_lower and "implementation" in text_lower)
):
    print(f"{skill} deep smoke missing TDD top-level route boundary; got {text!r}", file=sys.stderr)
    raise SystemExit(SEMANTIC_VARIANCE_EXIT)

if (
    "oh_no_claude_deep_ok" not in text_lower
    and f"oh_no_claude_deep_ok {skill}".lower() not in text_lower
):
    print(f"{skill} deep smoke missing success marker; got {text!r}", file=sys.stderr)
    raise SystemExit(SEMANTIC_VARIANCE_EXIT)

def terms_appear_in_order(*terms: str) -> bool:
    cursor = -1
    for term in terms:
        cursor = text_lower.find(term, cursor + 1)
        if cursor == -1:
            return False
    return True

if skill == "interview" and not (
    "already available" in text_lower or "already in session" in text_lower
    or "already in the session" in text_lower
    or "already present" in text_lower
):
    print(f"{skill} deep smoke missing company-context availability marker; got {text!r}", file=sys.stderr)
    raise SystemExit(SEMANTIC_VARIANCE_EXIT)

if skill == "interview" and not (
    "do not search remote" in text_lower
    or "should not be searched" in text_lower
    or ("remote" in text_lower and "not" in text_lower and "search" in text_lower)
):
    print(f"{skill} deep smoke missing remote-search policy marker; got {text!r}", file=sys.stderr)
    raise SystemExit(SEMANTIC_VARIANCE_EXIT)

if skill == "ralplan" and not (
    "analyst" in text_lower
    and "planner" in text_lower
    and "plan-reviewer" in text_lower
    and (
        "analyst -> planner -> plan-reviewer" in text_lower
        or "analyst, planner, plan-reviewer" in text_lower
        or "analyst, planner, and plan-reviewer" in text_lower
        or (
            terms_appear_in_order("analyst", "planner", "plan-reviewer")
            and ("first" in text_lower or "then" in text_lower or "sequential" in text_lower)
        )
        or (
            "analyst first" in text_lower
            and "planner second" in text_lower
            and "plan-reviewer third" in text_lower
        )
    )
):
    print(f"{skill} deep smoke missing full consensus ordering marker; got {text!r}", file=sys.stderr)
    raise SystemExit(SEMANTIC_VARIANCE_EXIT)

if skill == "ralplan" and not (
    "process budget" in text_lower and "named thorough" in text_lower
):
    print(f"{skill} deep smoke missing proportional process-budget marker; got {text!r}", file=sys.stderr)
    raise SystemExit(SEMANTIC_VARIANCE_EXIT)

if skill == "ralplan" and not (
    "blocking basis" in text_lower
    and "non-blocking" in text_lower
    and "optional" in text_lower
    and "approve" in text_lower
    and ("exact reviewed" in text_lower or "exact draft" in text_lower)
):
    print(f"{skill} deep smoke missing exact-draft freeze/blocking-basis marker; got {text!r}", file=sys.stderr)
    raise SystemExit(SEMANTIC_VARIANCE_EXIT)

if skill == "ralph" and not (
    "process budget" in text_lower
    and "cumulative" in text_lower
    and ("per-story" in text_lower or "per story" in text_lower)
    and "diff-budget" in text_lower
    and ("exactly once" in text_lower or "one time" in text_lower)
    and "before" in text_lower
    and "review" in text_lower
):
    print(f"{skill} deep smoke missing process/diff budget timing marker; got {text!r}", file=sys.stderr)
    raise SystemExit(SEMANTIC_VARIANCE_EXIT)

if skill == "ralplan" and not (
    ("planner" in text_lower and "plan-reviewer" in text_lower)
    and (
        "sequential" in text_lower
        or "only after planner" in text_lower
        or "only after the planner draft" in text_lower
        or "planner before plan-reviewer" in text_lower
        or "never run them in parallel" in text_lower
    )
):
    print(f"{skill} deep smoke missing Planner/Plan-Reviewer single-dispatch ordering marker; got {text!r}", file=sys.stderr)
    raise SystemExit(SEMANTIC_VARIANCE_EXIT)

if skill == "ralplan" and not (
    "blocking" in text_lower
    and ("v2" in text_lower or "final revision" in text_lower)
    and (
        "no re-review" in text_lower
        or "no further review" in text_lower
        or "without re-review" in text_lower
        or "never re-review" in text_lower
    )
):
    print(f"{skill} deep smoke missing blocking-findings v2-final/no-re-review marker; got {text!r}", file=sys.stderr)
    raise SystemExit(SEMANTIC_VARIANCE_EXIT)

linked_doc_markers = {
    "ralph": [
        "Direction Contract",
        "Mode-Gated Agent Dispatch",
        "Parallel trigger",
        "Acceptance-to-evidence ledger",
    ],
    "ultrawork": [
        "Mode source",
        "Cleanup And Final Verification",
    ],
    "auto-routing": [
        "persistent user preference",
        "Model Diversity Pair",
        "clear/reset command is `/clear`",
    ],
}

if skill in linked_doc_markers and not all(marker.lower() in text_lower for marker in linked_doc_markers[skill]):
    print(f"{skill} deep smoke missing linked-doc marker; got {text!r}", file=sys.stderr)
    raise SystemExit(SEMANTIC_VARIANCE_EXIT)

if skill == "simplify" and not (
    ("host" in text_lower and "policy" in text_lower)
    or "subagent dispatch is unavailable" in text_lower
    or ("dispatch" in text_lower and "unavailable" in text_lower)
):
    print(f"{skill} deep smoke missing host dispatch/fallback policy marker; got {text!r}", file=sys.stderr)
    raise SystemExit(SEMANTIC_VARIANCE_EXIT)

print(f"ok - deep Claude linked-doc smoke: {skill} cost={data.get('total_cost_usd')}")
PY
}

run_deep_live_skill_test() {
  local skill="$1"
  local out_file="$RUN_DIR/deep-${skill}.json"
  local prompt
  local read_root="$LIVE_PLUGIN_ROOT"
  prompt="$(deep_prompt_for_skill "$skill")"

  if [[ "$LIVE_LOAD_MODE" == "installed" ]]; then
    read_root="$(cached_plugin_root)"
  fi

  local cmd=(
    "$CLAUDE_BIN"
    --print
    --output-format json
    --model "$LIVE_MODEL"
    --max-budget-usd "$LIVE_MAX_BUDGET_USD"
    --permission-mode bypassPermissions
    --tools default
    --add-dir "$read_root"
    --no-session-persistence
    --system-prompt "You are a read-only deep smoke test runner. You may read local files needed by the invoked skill. Do not edit files or create artifacts."
  )

  append_live_plugin_dir_arg

  cmd+=("$prompt")
  run_plugin_dir_live_process_with_timeout "${cmd[@]}" >"$out_file"
  # Live deep-smoke demotes only semantic marker/paraphrase variance. Tool,
  # permission, malformed-output, and command failures remain hard failures per
  # the lane contract.
  local deep_rc=0
  assert_deep_json_output "$out_file" "$skill" || deep_rc=$?
  if [[ "$deep_rc" == "88" ]]; then
    log "WARN: live deep-smoke for $skill flagged paraphrase/dereference variance (non-gating)"
  elif [[ "$deep_rc" != "0" ]]; then
    return "$deep_rc"
  fi
}

run_deep_live_tests() {
  if [[ "$RUN_DEEP_LIVE" != "1" ]]; then
    log "Skipping deep Claude linked-doc smoke tests"
    printf 'Run with --deep-live or OH_NO_DEEP_LIVE=1 to verify linked support docs are read.\n' >&2
    return
  fi

  log "Running deep Claude linked-doc smoke tests (${LIVE_LOAD_MODE})"
  mkdir -p "$RUN_DIR"
  for skill in interview ralplan ralph ultrawork simplify auto-routing; do
    run_deep_live_skill_test "$skill"
  done
  ok "deep live outputs saved under ${RUN_DIR#$MARKETPLACE_ROOT/}"
}

assert_natural_prompt_has_no_explicit_subagent_terms() {
  local label="$1"
  local prompt="$2"
  local prompt_lower
  prompt_lower="$(printf '%s' "$prompt" | LC_ALL=C tr '[:upper:]' '[:lower:]')"
  for forbidden in \
    "subagent" "sub-agent" "spawn" "delegate" "delegation" "parallel agent" \
    "worker" "agent_type" "role:" "wave" "wait results" "wait_agent" \
    "close_agent" "clean up" "cleanup" "lifecycle"; do
    if [[ "$prompt_lower" == *"$forbidden"* ]]; then
      fail "${label} natural prompt contains explicit subagent authorization term: ${forbidden}"
    fi
  done
}

assert_natural_routing_prompt_shape() {
  local label="$1"
  local prompt="$2"
  local prompt_lower
  prompt_lower="$(printf '%s' "$prompt" | LC_ALL=C tr '[:upper:]' '[:lower:]')"
  for forbidden in \
    "oh-no-harness" "using-oh-no-harness" "interview" "ralplan" "ralph" \
    "ultrawork" "auto-routing" "test-driven-development" "simplify" \
    "verification-before-completion" "systematic-debugging" "fusion-rescue" \
    "skills/" "skills-claude/" "commands/" "skill.md"; do
    if [[ "$prompt_lower" == *"$forbidden"* ]]; then
      fail "${label} natural routing prompt names an expected skill/plugin/command path: ${forbidden}"
    fi
  done
}

natural_session_start_prompt_for_skill() {
  case "$1" in
    "vague requirements") cat <<'PROMPT'
I have an idea for improving the small tool described in README.md, but I have not decided its users, constraints, or acceptance criteria. Inspect the repository facts, then help me work out the requirements without changing files.
PROMPT
      ;;
    "autonomous end-to-end") printf '%s\n' 'Take the broad improvement goal in README.md from unclear requirements through implementation and final evidence autonomously. Manage the whole end-to-end delivery without asking me to choose each stage.' ;;
    "ordinary implementation") printf '%s\n' 'Update the runtime-consumed executable src/timeout.sh so TIMEOUT is 10 instead of 5. Acceptance criteria: run.sh prints TIMEOUT=10, existing behavior stays scoped to that value, and focused checks pass.' ;;
    "explicit test-first") printf '%s\n' 'Change the runtime-consumed executable src/timeout.sh so TIMEOUT is 10. Use RED/GREEN/REFACTOR: add or update the focused failing test first, show its failure, make the smallest production change, and rerun it.' ;;
    "unknown-cause failure") printf '%s\n' 'Running tests/startup_test.sh currently fails and the root cause is unknown. Reproduce the failure, determine the cause from evidence, apply the smallest justified fix, and rerun the focused check.' ;;
    "known-cause fix") printf '%s\n' 'The confirmed cause is the misspelled MODE value in runtime-consumed executable src/parser.sh; the exact fix is MODE=fast. Apply that localized change and verify tests/parser_test.sh without reopening root-cause investigation.' ;;
    "plan-only/pending approval") printf '%s\n' 'Prepare an approval-ready cross-file implementation plan for the concrete two-shell-file contract in README.md covering src/alpha.sh and src/beta.sh. Do not edit source or execute changes. Leave execution pending and present the next approval actions after the plan.' ;;
    "no-route research") printf '%s\n' 'Read README.md and explain how this disposable example is structured. Return the answer only; do not create files or change the project.' ;;
    "direct-edit eligible") printf '%s\n' 'Fix the one obvious "teh" typo in notes/private-notes.md and show the diff. This private prose file is inert, non-generated, non-operational, not consumed by build/test/CI, and has no security, permission, migration, or public-contract effect.' ;;
    "direct-edit ineligible") printf '%s\n' 'Fix the one "teh" typo printed by executable src/status.sh and verify tests/status_test.sh. This file is runtime-consumed source, so do not take a prose-only shortcut.' ;;
    *) fail "No natural Claude prompt for case: $1" ;;
  esac
}

run_natural_prompt_guard_offline_test() {
  log "Running offline Claude natural-prompt causality guard fixtures"
  local allowed_prompt case_id forbidden object_prompt prompt
  allowed_prompt="Read the repository facts, assess the requested outcome, and summarize the evidence without editing files."
  assert_natural_prompt_has_no_explicit_subagent_terms "allowed-fixture" "$allowed_prompt"
  assert_natural_routing_prompt_shape "allowed-fixture" "$allowed_prompt"
  for forbidden in \
    "subagent" "sub-agent" "spawn" "delegate" "delegation" "parallel agent" \
    "worker" "agent_type" "role:" "wave" "wait results" "wait_agent" \
    "close_agent" "clean up" "cleanup" "lifecycle"; do
    if (assert_natural_prompt_has_no_explicit_subagent_terms \
      "forbidden-fixture" "Read facts, then ${forbidden}, then summarize.") >/dev/null 2>&1; then
      fail "Claude natural-prompt guard missed forbidden fixture: ${forbidden}"
    fi
  done

  for case_id in "vague requirements" "autonomous end-to-end" "ordinary implementation" \
    "explicit test-first" "unknown-cause failure" "known-cause fix" "plan-only/pending approval" \
    "no-route research" "direct-edit eligible" "direct-edit ineligible"; do
    prompt="$(natural_session_start_prompt_for_skill "$case_id")"
    assert_natural_prompt_has_no_explicit_subagent_terms "$case_id" "$prompt"
    assert_natural_routing_prompt_shape "$case_id" "$prompt"
  done
  object_prompt='Analyze the Ralplan review loop for unnecessary steps. Return an analysis report only; do not create a plan or execute changes.'
  assert_natural_prompt_has_no_explicit_subagent_terms "object analysis" "$object_prompt"
  [[ "$object_prompt" == *"Ralplan"* && "$object_prompt" != *"/"* && "$object_prompt" != *"SKILL.md"* ]] \
    || fail "object-analysis prompt escaped its bounded workflow-subject exception"
  ok "Claude natural-prompt guard accepts real outcome-only prompts and rejects dispatch mechanics"
}

assert_ralplan_object_analysis_stayed_analysis_only() {
  local out_file="$1"
  "$PYTHON_BIN" - "$out_file" <<'PY'
import json, re, sys

workflows = {"interview", "ralplan", "ralph", "ultrawork", "auto-routing", "test-driven-development",
             "simplify", "verification-before-completion", "systematic-debugging", "fusion-rescue"}
result = ""
for line in open(sys.argv[1], encoding="utf-8"):
    if not line.strip():
        continue
    data = json.loads(line)
    if data.get("parent_tool_use_id") is not None: continue
    if data.get("type") == "result":
        if data.get("is_error") is True:
            raise SystemExit("Ralplan object-analysis smoke returned an error result")
        result = str(data.get("result", "")).strip()
    if data.get("type") != "assistant":
        continue
    for part in data.get("message", {}).get("content", []):
        if part.get("type") != "tool_use":
            continue
        name, payload = part.get("name", ""), part.get("input", {})
        if name in {"Agent", "Task"} and str(payload.get("subagent_type", "")).lower() in {
            "oh-no-harness:planner", "oh-no-harness:plan-reviewer",
        }:
            raise SystemExit("Ralplan object-analysis smoke dispatched a planning role")
        if name == "Workflow":
            wf_name = str(payload.get("name", "")).lower()
            script = (str(payload.get("script", "")) + " " + str(payload.get("scriptPath", ""))).lower()
            if "ralplan" in wf_name or ("ralplan" in script and "workflow(" in script):
                raise SystemExit("Ralplan object-analysis smoke invoked the Ralplan workflow")
        selected = " ".join(str(value) for value in payload.values()).lower()
        if name == "Skill":
            for workflow in workflows:
                if re.search(rf"(^|[^a-z0-9-]){re.escape(workflow)}($|[^a-z0-9-])", selected):
                    raise SystemExit(f"Ralplan object-analysis smoke activated workflow {workflow}")
        if name == "Read":
            path = str(payload.get("file_path", payload.get("path", ""))).replace("\\", "/")
            match = re.search(r"/skills-claude/([^/]+)/SKILL[.]md$", path)
            if match and match.group(1) in workflows:
                raise SystemExit(f"Ralplan object-analysis smoke activated workflow {match.group(1)}")
if not result:
    raise SystemExit("Ralplan object-analysis smoke returned no final analysis")
print("ok - Ralplan object-analysis request stayed analysis-only")
PY
}

run_ralplan_object_analysis_dispatch_guard_offline_test() {
  log "Running offline Ralplan object-analysis dispatch-guard fixtures"
  local temp_root fixture output rc selector
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-ralplan-dispatch-guard.XXXXXX")"
  fixture="$temp_root/transcript.jsonl"
  cat >"$fixture" <<'JSONL'
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Agent","input":{"subagent_type":"oh-no-harness:explore","prompt":"Compare oh-no-harness:planner with oh-no-harness:plan-reviewer without dispatching either."}}]}}
{"type":"result","is_error":false,"result":"Bounded comparison."}
JSONL
  output="$(assert_ralplan_object_analysis_stayed_analysis_only "$fixture" 2>&1)" \
    || { rm -rf "$temp_root"; fail "dispatch guard rejected an explore selector with prompt-only planning-role mentions: $output"; }
  printf '%s\n' '{"type":"assistant","parent_tool_use_id":"parent","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/plugin/skills-claude/ralplan/SKILL.md"}}]}}' '{"type":"result","is_error":false,"result":"Analysis."}' >"$fixture"
  assert_ralplan_object_analysis_stayed_analysis_only "$fixture" >/dev/null \
    || { rm -rf "$temp_root"; fail "dispatch guard treated a child Ralplan wrapper Read as parent activation"; }
  for selector in oh-no-harness:planner oh-no-harness:plan-reviewer; do
    cat >"$fixture" <<JSONL
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Task","input":{"subagent_type":"$selector","prompt":"Analyze only."}}]}}
{"type":"result","is_error":false,"result":"Analysis."}
JSONL
    rc=0; output="$(assert_ralplan_object_analysis_stayed_analysis_only "$fixture" 2>&1)" || rc=$?
    [[ "$rc" != "0" && "$output" == *"dispatched a planning role"* ]] \
      || { rm -rf "$temp_root"; fail "dispatch guard accepted planning selector $selector (rc=$rc output=$output)"; }
  done

  cat >"$fixture" <<'JSONL'
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Workflow","input":{"name":"ralplan","script":"return analysisOnly();"}}]}}
{"type":"result","is_error":false,"result":"Analysis."}
JSONL
  rc=0; output="$(assert_ralplan_object_analysis_stayed_analysis_only "$fixture" 2>&1)" || rc=$?
  [[ "$rc" != "0" && "$output" == *"invoked the Ralplan workflow"* ]] \
    || { rm -rf "$temp_root"; fail "dispatch guard accepted a structured ralplan Workflow invocation (rc=$rc output=$output)"; }

  for selector in Skill Read; do
    if [[ "$selector" == "Skill" ]]; then
      printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"oh-no-harness:ralplan"}}]}}' >"$fixture"
    else
      printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/plugin/skills-claude/ralplan/SKILL.md"}}]}}' >"$fixture"
    fi
    printf '%s\n' '{"type":"result","is_error":false,"result":"Analysis."}' >>"$fixture"
    rc=0; output="$(assert_ralplan_object_analysis_stayed_analysis_only "$fixture" 2>&1)" || rc=$?
    [[ "$rc" != "0" && "$output" == *"activated workflow ralplan"* ]] \
      || { rm -rf "$temp_root"; fail "dispatch guard accepted a structured ralplan $selector activation (rc=$rc output=$output)"; }
  done

  cat >"$fixture" <<'JSONL'
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Workflow","input":{"name":"analysis-only","script":"const note = 'ralplan is out of scope'; return note;"}}]}}
{"type":"result","is_error":false,"result":"Bounded analysis."}
JSONL
  output="$(assert_ralplan_object_analysis_stayed_analysis_only "$fixture" 2>&1)" \
    || { rm -rf "$temp_root"; fail "dispatch guard rejected a Workflow script that only mentioned ralplan: $output"; }
  rm -rf "$temp_root"
  ok "Ralplan object-analysis dispatch guard uses structured selectors and ignores prompt-only role/workflow mentions"
}

natural_source_checkout_fingerprint() {
  local root="$1"
  {
    printf 'UNSTAGED\0'; git -C "$root" diff --binary
    printf '\0STAGED\0'; git -C "$root" diff --cached --binary
    printf '\0UNTRACKED\0'
    git -C "$root" ls-files --others --exclude-standard -z | "$PYTHON_BIN" -c 'import os,sys
root=os.fsencode(sys.argv[1]); paths=sorted(filter(None,sys.stdin.buffer.read().split(b"\0")))
for rel in paths:
 p=os.path.join(root,rel); link=os.path.islink(p); data=os.readlink(p) if link else open(p,"rb").read()
 sys.stdout.buffer.write(len(rel).to_bytes(8,"big")+rel+(b"L" if link else b"F")+len(data).to_bytes(8,"big")+data)' "$root"
  } | shasum -a 256
}

natural_git_fixture() {
  local root="$1" label="$2" mode="${3:-initialize}" status
  case "$label" in "autonomous end-to-end"|"ordinary implementation"|"explicit test-first"|"unknown-cause failure"|"known-cause fix"|"direct-edit eligible"|"direct-edit ineligible") ;; *) return 0 ;; esac
  if [[ "$mode" == initialize ]]; then
    git -C "$root" init -q; git -C "$root" config user.name oh-no-fixture; git -C "$root" config user.email fixture@example.invalid
    git -C "$root" add .; git -C "$root" commit -qm baseline
  fi
  git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "$label fixture is not an actual Git checkout"
  status="$(git -C "$root" status --porcelain)"; [[ -z "$status" ]] || fail "$label fixture is dirty before launch: $status"
}
natural_payload_changes() { diff -qr -x .git "$1" "$2" || true; }
run_natural_git_fixture_offline_test() {
  log "Running offline Claude natural Git-fixture guards"
  local root label dir status direct before changes; root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-claude-git-fixtures.XXXXXX")"; trap 'rm -rf "$root"' RETURN
  for label in "autonomous end-to-end" "ordinary implementation" "explicit test-first" "unknown-cause failure" "known-cause fix" "direct-edit eligible" "direct-edit ineligible" "vague requirements" "plan-only/pending approval" "no-route research" "object analysis"; do
    dir="$root/${label//[ \/]/-}"; mkdir -p "$dir"; printf 'fixture\n' >"$dir/fixture.txt"; natural_git_fixture "$dir" "$label"
    case "$label" in "autonomous end-to-end"|"ordinary implementation"|"explicit test-first"|"unknown-cause failure"|"known-cause fix"|"direct-edit eligible"|"direct-edit ineligible") [[ -z "$(git -C "$dir" status --porcelain)" ]] || fail "$label fixture was not clean" ;; *) ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "$label unexpectedly became a Git fixture" ;; esac
  done
  dir="$root/ordinary-implementation"; printf 'dirty\n' >>"$dir/fixture.txt"; if (natural_git_fixture "$dir" "ordinary implementation" verify) >/dev/null 2>&1; then fail "dirty selected Claude fixture passed its pre-launch guard"; fi
  direct="$root/direct-containment"; before="$root/direct-before"; mkdir -p "$direct/notes" "$before"; printf 'Keep teh private note concise.\n' >"$direct/notes/private-notes.md"; natural_git_fixture "$direct" "direct-edit eligible"; cp -R "$direct/." "$before/"
  git -C "$direct" config fixture.metadata changed; [[ -z "$(natural_payload_changes "$before" "$direct")" ]] || fail ".git-only Claude metadata counted as payload mutation"
  printf 'Keep the private note concise.\n' >"$direct/notes/private-notes.md"; changes="$(natural_payload_changes "$before" "$direct")"
  [[ "$(printf '%s\n' "$changes" | grep -c .)" == 1 && "$changes" == *"notes/private-notes.md"* ]] || fail "Claude direct-edit containment lost its exact one-file payload boundary: $changes"
  rm -rf "$root"; trap - RETURN; ok "Claude selected natural fixtures are clean Git checkouts and payload diffs exclude .git"
}

assert_claude_natural_activation_smoke() {
  local out_file="$1" err_file="$2" label="$3" expected_route="$4" routing_state="$5"
  "$PYTHON_BIN" - "$out_file" "$err_file" "$label" "$expected_route" "$routing_state" <<'PY'
import json, re, sys

out_path, err_path, label, expected, routing_state = sys.argv[1:6]
workflows = {"interview", "ralplan", "ralph", "ultrawork", "auto-routing", "test-driven-development",
             "simplify", "verification-before-completion", "systematic-debugging", "fusion-rescue"}

def text(value):
    if isinstance(value, str): return value
    if isinstance(value, dict): return " ".join(text(item) for item in value.values())
    if isinstance(value, list): return " ".join(text(item) for item in value)
    return ""

def selected_route(payload):
    selector = str(payload.get("skill", "")).lower()
    namespace = "oh-no-harness:"
    if selector.startswith(namespace):
        selector = selector[len(namespace):]
    return selector if selector in workflows else ""

err_text = open(err_path, encoding="utf-8").read()
if "agent thread limit reached" in err_text.lower():
    raise SystemExit(f"{label} natural activation smoke hit the agent thread limit")

activations, actions, tool_results, test_bashes, wrapper_reads, plan_writes = [], [], {}, [], [], []
sequence = 0
final_result = ""
final_sequence = None
if routing_state not in {"off", "on"}:
    raise SystemExit(f"{label} natural activation smoke received invalid routing state: {routing_state}")
for line in open(out_path, encoding="utf-8"):
    if not line.strip(): continue
    data = json.loads(line)
    if data.get("parent_tool_use_id") is not None: continue
    if data.get("type") == "assistant":
        for part in data.get("message", {}).get("content", []):
            if part.get("type") != "tool_use": continue
            sequence += 1
            name, payload = part.get("name", ""), part.get("input", {})
            route = selected_route(payload) if name == "Skill" else ""
            if name == "Read":
                path = str(payload.get("file_path", payload.get("path", ""))).replace("\\", "/")
                match = re.search(r"/skills-claude/([^/]+)/SKILL[.]md$", path)
                if match and match.group(1) in workflows:
                    route = match.group(1)
            if route:
                activations.append((sequence, route, name))
                if name == "Read": wrapper_reads.append((sequence, route, part.get("id", "")))
            else:
                actions.append((sequence, name, text(payload), part.get("id", "")))
            if name in {"Write", "Edit", "NotebookEdit"}:
                plan_writes.append((sequence, part.get("id", ""), str(payload.get("file_path", payload.get("path", ""))).replace("\\", "/"), str(payload.get("content", payload.get("new_string", "")))))
            if name == "Bash" and "tests/timeout_test.sh" in text(payload):
                test_bashes.append((sequence, part.get("id", "")))
    if data.get("type") == "user":
        for part in data.get("message", {}).get("content", []):
            if part.get("type") == "tool_result":
                tool_results[part.get("tool_use_id", "")] = (part.get("is_error") is True, text(part))
    if data.get("type") == "result":
        sequence += 1
        final_sequence = sequence
        actions.append((sequence, "final result", "", ""))
        if data.get("is_error") is True:
            raise SystemExit(f"{label} natural activation smoke returned an error result")
        final_result = str(data.get("result", "")).strip()

if not final_result or final_sequence is None:
    raise SystemExit(f"{label} natural activation smoke returned no non-empty final result")
mutations = [item for item in actions if item[1] in {"Edit", "Write", "NotebookEdit"}]
if expected == "none":
    if activations:
        raise SystemExit(f"{label} activated workflow wrappers: {activations!r}")
    if label == "direct-edit eligible":
        target = "notes/private-notes.md"
        if len(mutations) != 1 or target not in mutations[0][2].replace("\\", "/"):
            raise SystemExit(f"{label} lacked exactly one intended notes mutation: {mutations!r}")
        mutation_sequence = mutations[0][0]
        proofs = []
        for action_sequence, name, command, tool_id in actions:
            if name != "Bash" or not mutation_sequence < action_sequence < final_sequence: continue
            git_scoped = re.search(r"\bgit\s+diff\b[^\n;&|]*--\s+['\"]?(?:[.]/)?notes/private-notes[.]md(?:['\"]|\s|$)", command)
            plain_scoped = not re.search(r"\bgit\s+diff\b", command) and re.search(r"(?:^|[;&|]\s*)diff\b[^\n;&|]*notes/private-notes[.]md", command)
            failed, output = tool_results.get(tool_id, (True, "")); lines = output.splitlines()
            evidence = target in output.replace("\\", "/") and ((any(line.startswith("--- ") for line in lines) and any(line.startswith("+++ ") for line in lines) and any(line.startswith("-") and not line.startswith("---") for line in lines) and any(line.startswith("+") and not line.startswith("+++") for line in lines)) or (any(line.startswith("< ") for line in lines) and any(line.startswith("> ") for line in lines)))
            if (git_scoped or plain_scoped) and not failed and evidence: proofs.append((action_sequence, command))
        if not proofs:
            raise SystemExit(f"{label} lacked a successful scoped runtime diff after mutation and before final")
    print(f"ok - {label} natural Claude smoke stayed outside workflow activation")
    raise SystemExit(0)

if not activations or activations[0][1] != expected:
    raise SystemExit(f"{label} first host-visible workflow activation was not {expected}: {activations!r}")
first_expected = activations[0][0]
expected_reads = [item for item in wrapper_reads if item[1] == expected]
if not expected_reads:
    raise SystemExit(f"{label} did not attempt the generated {expected} wrapper Read")
for _, _, tool_id in expected_reads:
    if tool_id not in tool_results:
        raise SystemExit(f"{label} generated {expected} wrapper Read returned no tool result")
    if tool_results[tool_id][0]:
        raise SystemExit(f"{label} generated {expected} wrapper Read failed: {tool_results[tool_id][1]}")
if routing_state == "on":
    first_action = min(item[0] for item in actions)
    if first_expected >= first_action:
        raise SystemExit(f"{label} performed actionable work before {expected} activation: {actions!r}")

def activated_before(route):
    return any(index <= first_expected and value == route for index, value, _ in activations)

def forbid(routes, anywhere=False):
    found = [item for item in activations if item[1] in routes and (anywhere or item[0] <= first_expected)]
    if found: raise SystemExit(f"{label} activated forbidden adjacent workflow: {found!r}")

if label == "ordinary implementation": forbid({"test-driven-development", "systematic-debugging"})
elif label == "explicit test-first": forbid({"ralph"})
elif label == "unknown-cause failure" and activated_before("ralph"):
    raise SystemExit(f"{label} activated ralph before debugging")
elif label == "known-cause fix": forbid({"systematic-debugging"}, anywhere=True)
elif label == "plan-only/pending approval": forbid({"ralph", "ultrawork"}, anywhere=True)
elif label == "direct-edit ineligible":
    forbid(workflows - {"ralph"}, anywhere=True)

if label == "vague requirements":
    reads = [item for item in actions if item[1] in {"Read", "Glob", "Grep"} and first_expected < item[0] < final_sequence]
    if not reads or mutations: raise SystemExit(f"{label} missed post-activation repository read or mutated files")
elif label == "explicit test-first":
    production = [item for item in mutations if "src/timeout.sh" in item[2]]
    if not test_bashes or not production or min(x[0] for x in test_bashes) >= min(x[0] for x in production):
        raise SystemExit(f"{label} did not run the focused test Bash before production mutation")
    failed = any(tool_results.get(tool_id, (False, ""))[0] or re.search(
        r"(?:exit(?:ed)?(?:[ _-]+with)?(?:[ _-]+code)?|status)\s*[:=]?\s*[1-9]", tool_results.get(tool_id, (False, ""))[1], re.I
    ) for _, tool_id in test_bashes)
    if not failed: raise SystemExit(f"{label} focused pre-production test did not visibly fail")
elif label == "unknown-cause failure":
    fixes = [item for item in mutations if "src/startup.sh" in item[2]]
    evidence = [item for item in actions if item[1] in {"Read", "Bash"} and item[0] > first_expected]
    if not fixes or not evidence or min(x[0] for x in evidence) >= min(x[0] for x in fixes):
        raise SystemExit(f"{label} missed reproduction/read evidence before fix mutation")
elif label == "plan-only/pending approval":
    plans = [item for item in plan_writes if re.search(r"(?:^|/)[.]oh-no/plans/[^/]+$", item[2]) and item[3].strip() and item[1] in tool_results and not tool_results[item[1]][0]]
    plan_sequence = min((item[0] for item in plans), default=None)
    approval_pattern = re.compile(r"\b(?:approv|proceed|execut|review|revis|continu|next (?:action|step))", re.I)
    approval = [item for item in actions if item[1] == "AskUserQuestion" and plan_sequence is not None and item[0] > plan_sequence and approval_pattern.search(item[2])]
    final_approval = plan_sequence is not None and final_sequence > plan_sequence and approval_pattern.search(final_result)
    production = [item for item in mutations if re.search(r"(?:^|/)src/", item[2].replace("\\", "/"))]
    if not plans or not (approval or final_approval) or production: raise SystemExit(f"{label} lacked a successful nonempty plan followed by approval interaction or mutated production")

print(f"ok - {label} natural Claude smoke observed {expected} as the first workflow activation")
PY
}

run_natural_activation_assertion_offline_test() {
  log "Running offline Claude natural-activation assertion fixtures"
  local temp_root fixture err_file output rc
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-natural-activation.XXXXXX")"
  fixture="$temp_root/transcript.jsonl"; err_file="$temp_root/stderr"; : >"$err_file"
  cat >"$fixture" <<'JSONL'
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"pre","name":"Read","input":{"file_path":"README.md"}}]}}
{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"pre","content":"README"}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill","name":"Skill","input":{"skill":"oh-no-harness:ultrawork"}}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"wrapper","name":"Read","input":{"file_path":"/tmp/plugin/skills-claude/ultrawork/SKILL.md"}}]}}
{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"wrapper","content":"skill body"}]}}
{"type":"result","is_error":false,"result":"done"}
JSONL
  assert_claude_natural_activation_smoke "$fixture" "$err_file" fixture ultrawork off >/dev/null \
    || { rm -rf "$temp_root"; fail "natural assertion rejected an off-state preliminary repository Read"; }
  rc=0; output="$(assert_claude_natural_activation_smoke "$fixture" "$err_file" fixture ultrawork on 2>&1)" || rc=$?
  [[ "$rc" != "0" && "$output" == *"actionable work before ultrawork activation"* ]] \
    || { rm -rf "$temp_root"; fail "natural assertion accepted pre-activation work with routing on: $output"; }
  cat >"$fixture" <<'JSONL'
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill","name":"Skill","input":{"skill":"oh-no-harness:ultrawork"}}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"wrapper","name":"Read","input":{"file_path":"/tmp/plugin/skills-claude/ultrawork/SKILL.md"}}]}}
{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"wrapper","content":"permission denied","is_error":true}]}}
{"type":"result","is_error":false,"result":"done"}
JSONL
  rc=0; output="$(assert_claude_natural_activation_smoke "$fixture" "$err_file" fixture ultrawork off 2>&1)" || rc=$?
  [[ "$rc" != "0" && "$output" == *"generated ultrawork wrapper Read failed"* ]] \
    || { rm -rf "$temp_root"; fail "natural assertion accepted a failed generated-wrapper Read: $output"; }
  cat >"$fixture" <<'JSONL'
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill","name":"Skill","input":{"skill":"oh-no-harness:ultrawork","args":"Start with Interview."}}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"wrapper","name":"Read","input":{"file_path":"/tmp/plugin/skills-claude/ultrawork/SKILL.md"}}]}}
{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"wrapper","content":"skill body"}]}}
{"type":"result","is_error":false,"result":"done"}
JSONL
  assert_claude_natural_activation_smoke "$fixture" "$err_file" fixture ultrawork off >/dev/null \
    || { rm -rf "$temp_root"; fail "natural assertion let Skill args override the Ultrawork selector"; }
  cat >"$fixture" <<'JSONL'
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill","name":"Skill","input":{"skill":"oh-no-harness:interview","args":"Continue through Ultrawork."}}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"wrapper","name":"Read","input":{"file_path":"/tmp/plugin/skills-claude/interview/SKILL.md"}}]}}
{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"wrapper","content":"skill body"}]}}
{"type":"result","is_error":false,"result":"done"}
JSONL
  rc=0; output="$(assert_claude_natural_activation_smoke "$fixture" "$err_file" fixture ultrawork off 2>&1)" || rc=$?
  [[ "$rc" != "0" && "$output" == *"first host-visible workflow activation was not ultrawork"* ]] \
    || { rm -rf "$temp_root"; fail "natural assertion let Skill args override the Interview selector: $output"; }
  printf '%s\n' '{"type":"assistant","parent_tool_use_id":"parent","message":{"content":[{"type":"tool_use","id":"child","name":"Bash","input":{"command":"pwd"}}]}}' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill","name":"Skill","input":{"skill":"oh-no-harness:ultrawork"}}]}}' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"wrapper","name":"Read","input":{"file_path":"/tmp/plugin/skills-claude/ultrawork/SKILL.md"}}]}}' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"wrapper","content":"skill body"}]}}' '{"type":"result","is_error":false,"result":"done"}' >"$fixture"
  assert_claude_natural_activation_smoke "$fixture" "$err_file" fixture ultrawork on >/dev/null || { rm -rf "$temp_root"; fail "natural assertion treated child Bash as parent pre-route work"; }
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill","name":"Skill","input":{"skill":"oh-no-harness:test-driven-development"}}]}}' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"wrapper","name":"Read","input":{"file_path":"/tmp/plugin/skills-claude/test-driven-development/SKILL.md"}}]}}' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"wrapper","content":"skill body"}]}}' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"red","name":"Bash","input":{"command":"tests/timeout_test.sh"}}]}}' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"red","is_error":false,"content":"EXIT_CODE=1"}]}}' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"edit","name":"Edit","input":{"file_path":"src/timeout.sh","old_string":"5","new_string":"10"}}]}}' '{"type":"result","is_error":false,"result":"done"}' >"$fixture"
  assert_claude_natural_activation_smoke "$fixture" "$err_file" "explicit test-first" test-driven-development off >/dev/null || { rm -rf "$temp_root"; fail "natural assertion missed parent-visible EXIT_CODE=1 RED evidence"; }
  local route_prefix plan_write
  route_prefix='{"type":"assistant","message":{"content":[{"type":"tool_use","id":"skill","name":"Skill","input":{"skill":"oh-no-harness:ralplan"}}]}}'
  plan_write='{"type":"assistant","message":{"content":[{"type":"tool_use","id":"plan","name":"Write","input":{"file_path":".oh-no/plans/approved.md","content":"Approval-ready plan"}}]}}'
  printf '%s\n' "$route_prefix" '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"wrapper","name":"Read","input":{"file_path":"/tmp/plugin/skills-claude/ralplan/SKILL.md"}}]}}' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"wrapper","content":"skill body"}]}}' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"ask","name":"AskUserQuestion","input":{"question":"What requirements are missing?"}}]}}' '{"type":"result","is_error":false,"result":"Please clarify the requirements."}' >"$fixture"
  rc=0; output="$(assert_claude_natural_activation_smoke "$fixture" "$err_file" "plan-only/pending approval" ralplan off 2>&1)" || rc=$?; [[ "$rc" != 0 && "$output" == *"lacked a successful nonempty plan"* ]] || { rm -rf "$temp_root"; fail "plan-only oracle accepted a requirements pause: $output"; }
  printf '%s\n' "$route_prefix" '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"wrapper","name":"Read","input":{"file_path":"/tmp/plugin/skills-claude/ralplan/SKILL.md"}}]}}' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"wrapper","content":"skill body"}]}}' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"ask","name":"AskUserQuestion","input":{"question":"Proceed to execution?"}}]}}' '{"type":"result","is_error":false,"result":"Proceed to execution?"}' >"$fixture"
  rc=0; output="$(assert_claude_natural_activation_smoke "$fixture" "$err_file" "plan-only/pending approval" ralplan off 2>&1)" || rc=$?; [[ "$rc" != 0 ]] || { rm -rf "$temp_root"; fail "plan-only oracle accepted a bare approval question without a plan"; }
  printf '%s\n' "$route_prefix" '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"wrapper","name":"Read","input":{"file_path":"/tmp/plugin/skills-claude/ralplan/SKILL.md"}}]}}' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"wrapper","content":"skill body"}]}}' "$plan_write" '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"plan","content":"created"}]}}' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"ask","name":"AskUserQuestion","input":{"question":"Would you like to review, revise, or continue?"}}]}}' '{"type":"result","is_error":false,"result":"Awaiting your choice."}' >"$fixture"
  assert_claude_natural_activation_smoke "$fixture" "$err_file" "plan-only/pending approval" ralplan off >/dev/null || { rm -rf "$temp_root"; fail "plan-only oracle rejected a plan plus broad next-action question"; }
  printf '%s\n' "$route_prefix" '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"wrapper","name":"Read","input":{"file_path":"/tmp/plugin/skills-claude/ralplan/SKILL.md"}}]}}' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"wrapper","content":"skill body"}]}}' "$plan_write" '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"plan","content":"created"}]}}' '{"type":"result","is_error":false,"result":"Plan ready for review and approval."}' >"$fixture"
  assert_claude_natural_activation_smoke "$fixture" "$err_file" "plan-only/pending approval" ralplan off >/dev/null || { rm -rf "$temp_root"; fail "plan-only oracle rejected an approval-oriented final after the plan"; }
  printf '%s\n' "$route_prefix" '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"wrapper","name":"Read","input":{"file_path":"/tmp/plugin/skills-claude/ralplan/SKILL.md"}}]}}' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"wrapper","content":"skill body"}]}}' "$plan_write" '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"plan","content":"created"}]}}' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"edit","name":"Edit","input":{"file_path":"src/alpha.sh","old_string":"alpha","new_string":"changed"}}]}}' '{"type":"result","is_error":false,"result":"Plan ready for approval."}' >"$fixture"
  rc=0; assert_claude_natural_activation_smoke "$fixture" "$err_file" "plan-only/pending approval" ralplan off >/dev/null 2>&1 || rc=$?; [[ "$rc" != 0 ]] || { rm -rf "$temp_root"; fail "plan-only oracle accepted production mutation after a plan"; }
  local direct_edit diff_output; direct_edit='{"type":"assistant","message":{"content":[{"type":"tool_use","id":"edit","name":"Edit","input":{"file_path":"notes/private-notes.md","old_string":"teh","new_string":"the"}}]}}'; diff_output=$'diff --git a/notes/private-notes.md b/notes/private-notes.md\n--- a/notes/private-notes.md\n+++ b/notes/private-notes.md\n-Keep teh private note concise.\n+Keep the private note concise.'
  printf '%s\n' "$direct_edit" '{"type":"result","is_error":false,"result":"done"}' >"$fixture"; rc=0; assert_claude_natural_activation_smoke "$fixture" "$err_file" "direct-edit eligible" none off >/dev/null 2>&1 || rc=$?; [[ "$rc" != 0 ]] || fail "direct-edit oracle accepted no runtime diff"
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"diff","name":"Bash","input":{"command":"git diff -- notes/private-notes.md"}}]}}' "{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"diff\",\"content\":$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$diff_output")} ]}}" "$direct_edit" '{"type":"result","is_error":false,"result":"done"}' >"$fixture"; rc=0; assert_claude_natural_activation_smoke "$fixture" "$err_file" "direct-edit eligible" none off >/dev/null 2>&1 || rc=$?; [[ "$rc" != 0 ]] || fail "direct-edit oracle accepted a diff before mutation"
  printf '%s\n' "$direct_edit" '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"diff","name":"Bash","input":{"command":"git diff -- notes/private-notes.md"}}]}}' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"diff","is_error":true,"content":"diff failed"}]}}' '{"type":"result","is_error":false,"result":"done"}' >"$fixture"; rc=0; assert_claude_natural_activation_smoke "$fixture" "$err_file" "direct-edit eligible" none off >/dev/null 2>&1 || rc=$?; [[ "$rc" != 0 ]] || fail "direct-edit oracle accepted a failed diff"
  printf '%s\n' "$direct_edit" '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"diff","name":"Bash","input":{"command":"git diff"}}]}}' "{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"diff\",\"content\":$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$diff_output")} ]}}" '{"type":"result","is_error":false,"result":"done"}' >"$fixture"; rc=0; assert_claude_natural_activation_smoke "$fixture" "$err_file" "direct-edit eligible" none off >/dev/null 2>&1 || rc=$?; [[ "$rc" != 0 ]] || fail "direct-edit oracle accepted an unscoped diff"
  printf '%s\n' "$direct_edit" '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"diff","name":"Bash","input":{"command":"git diff -- notes/private-notes.md"}}]}}' "{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"diff\",\"content\":$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$diff_output")} ]}}" '{"type":"result","is_error":false,"result":"done"}' >"$fixture"; assert_claude_natural_activation_smoke "$fixture" "$err_file" "direct-edit eligible" none off >/dev/null || fail "direct-edit oracle rejected mutation then successful scoped diff then final"
  local cleanup_a cleanup_b cleanup_c cleanup_err
  cleanup_a="$(mktemp -d)"; cleanup_b="$(mktemp -d)"; cleanup_c="$(mktemp -d)"; cleanup_err="$temp_root/cleanup.err"
  bash -u -c 'printf -v cleanup_cmd '\''rm -rf -- %q %q %q'\'' "$1" "$2" "$3"; trap "$cleanup_cmd" EXIT' _ "$cleanup_a" "$cleanup_b" "$cleanup_c" 2>"$cleanup_err"
  [[ ! -e "$cleanup_a" && ! -e "$cleanup_b" && ! -e "$cleanup_c" ]] && ! grep -q 'unbound variable' "$cleanup_err" || { rm -rf "$temp_root" "$cleanup_a" "$cleanup_b" "$cleanup_c"; fail "literal cleanup trap failed under bash -u"; }
  rm -rf "$temp_root"
  ok "natural activation assertion scopes parent events, RED evidence, approval-ready plans, and cleanup"
}

run_natural_session_start_live_skill_test() {
  local label="$1" expected_route="$2" routing_state="$3" prompt="${4:-}"
  local safe_label="${label//\//-}" temp_project config_dir before_dir config_path cleanup_cmd
  local out_file="$RUN_DIR/natural-${routing_state}-${safe_label// /-}.jsonl"
  local err_file="$RUN_DIR/natural-${routing_state}-${safe_label// /-}.err"
  [[ -n "$prompt" ]] || prompt="$(natural_session_start_prompt_for_skill "$label")"
  assert_natural_prompt_has_no_explicit_subagent_terms "$label" "$prompt"
  [[ "$label" == "object analysis" ]] || assert_natural_routing_prompt_shape "$label" "$prompt"

  temp_project="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-claude-natural-project.XXXXXX")"; config_dir="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-claude-natural-config.XXXXXX")"
  before_dir="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-claude-natural-before.XXXXXX")"
  (
    printf -v cleanup_cmd 'rm -rf -- %q %q %q' "$temp_project" "$config_dir" "$before_dir"; trap "$cleanup_cmd" EXIT
    case "$label" in
      "vague requirements"|"autonomous end-to-end"|"no-route research"|"object analysis") printf 'Disposable example with an intentionally broad improvement goal.\n' >"$temp_project/README.md" ;;
      "ordinary implementation"|"explicit test-first") mkdir -p "$temp_project/src" "$temp_project/tests"; printf 'TIMEOUT=5\n' >"$temp_project/src/timeout.sh"; printf '#!/bin/sh\n. ./src/timeout.sh\nprintf "TIMEOUT=%%s\\n" "$TIMEOUT"\n' >"$temp_project/run.sh"; printf '#!/bin/sh\n[ "$(./run.sh)" = "TIMEOUT=10" ]\n' >"$temp_project/tests/timeout_test.sh"; chmod +x "$temp_project/run.sh" "$temp_project/tests/timeout_test.sh" ;;
      "unknown-cause failure") mkdir -p "$temp_project/src" "$temp_project/tests"; printf '#!/bin/sh\nprintf "ready\\n"\n' >"$temp_project/src/startup.sh"; printf '#!/bin/sh\n[ "$(./src/startup.sh)" = "started" ]\n' >"$temp_project/tests/startup_test.sh"; chmod +x "$temp_project/src/startup.sh" "$temp_project/tests/startup_test.sh" ;;
      "known-cause fix") mkdir -p "$temp_project/src" "$temp_project/tests"; printf '#!/bin/sh\nMODE=sloww\nprintf "%%s\\n" "$MODE"\n' >"$temp_project/src/parser.sh"; printf '#!/bin/sh\n[ "$(./src/parser.sh)" = "fast" ]\n' >"$temp_project/tests/parser_test.sh"; chmod +x "$temp_project/src/parser.sh" "$temp_project/tests/parser_test.sh" ;;
      "plan-only/pending approval") mkdir -p "$temp_project/src"; printf 'Plan two POSIX sh scripts with no external dependency. Both accept exactly one LABEL; alpha.sh prints newline-terminated alpha:<LABEL> and beta.sh prints newline-terminated beta:<LABEL>. Invalid arity prints usage to stderr and exits 2. Include focused valid-argument and invalid-arity tests.\n' >"$temp_project/README.md"; printf '#!/bin/sh\nprintf "alpha\\n"\n' >"$temp_project/src/alpha.sh"; printf '#!/bin/sh\nprintf "beta\\n"\n' >"$temp_project/src/beta.sh" ;;
      "direct-edit eligible") mkdir -p "$temp_project/notes"; printf 'Keep teh private note concise.\n' >"$temp_project/notes/private-notes.md" ;;
      "direct-edit ineligible") mkdir -p "$temp_project/src" "$temp_project/tests"; printf '#!/bin/sh\nprintf "teh status\\n"\n' >"$temp_project/src/status.sh"; printf '#!/bin/sh\n[ "$(./src/status.sh)" = "the status" ]\n' >"$temp_project/tests/status_test.sh"; chmod +x "$temp_project/src/status.sh" "$temp_project/tests/status_test.sh" ;;
    esac
    natural_git_fixture "$temp_project" "$label" initialize
    cp -R "$temp_project/." "$before_dir/"

    config_path="$(OH_NO_CONFIG_DIR="$config_dir" "$PLUGIN_ROOT/scripts/oh-no-config" path)"
    case "$config_path" in "$config_dir"/*) ;; *) fail "$label helper config path escaped disposable directory: $config_path" ;; esac
    [[ "$routing_state" == "off" ]] || OH_NO_CONFIG_DIR="$config_dir" "$PLUGIN_ROOT/scripts/oh-no-config" on >/dev/null
    local checkout_before checkout_after
    checkout_before="$(natural_source_checkout_fingerprint "$MARKETPLACE_ROOT")"

    natural_git_fixture "$temp_project" "$label" verify
    local cmd=("$CLAUDE_BIN" --print --verbose --output-format stream-json --include-hook-events
      --model "$LIVE_MODEL" --max-budget-usd "$LIVE_MAX_BUDGET_USD" --permission-mode acceptEdits
      --tools default --allowedTools "Bash" --no-session-persistence --system-prompt "Work only inside the current disposable test project. Follow the user request and installed instructions.")
    [[ "$expected_route" == "none" ]] || cmd+=(--add-dir "$LIVE_PLUGIN_ROOT/skills-claude/$expected_route")
    append_live_plugin_dir_arg
    (cd "$temp_project" && OH_NO_CONFIG_DIR="$config_dir" run_live_process_with_timeout "${cmd[@]}" "$prompt") >"$out_file" 2>"$err_file"

    checkout_after="$(natural_source_checkout_fingerprint "$MARKETPLACE_ROOT")"
    [[ "$checkout_before" == "$checkout_after" ]] || fail "$label live child mutated the source checkout"
    assert_claude_natural_activation_smoke "$out_file" "$err_file" "$label" "$expected_route" "$routing_state"
    [[ "$label" == "object analysis" ]] && assert_ralplan_object_analysis_stayed_analysis_only "$out_file"

    local changes
    changes="$(natural_payload_changes "$before_dir" "$temp_project")"
    case "$label" in
      "vague requirements"|"no-route research"|"object analysis")
        [[ -z "$changes" && ! -e "$temp_project/.oh-no" ]] || fail "$label changed its disposable project or created workflow artifacts"
        ;;
      "direct-edit eligible")
        [[ "$(printf '%s\n' "$changes" | grep -c .)" == "1" && "$changes" == *"notes/private-notes.md"* ]] \
          || fail "$label did not change exactly its one inert notes file: $changes"
        [[ ! -e "$temp_project/.oh-no" ]] || fail "$label created a workflow artifact"
        ;;
      "plan-only/pending approval")
        cmp -s "$before_dir/README.md" "$temp_project/README.md" \
          && cmp -s "$before_dir/src/alpha.sh" "$temp_project/src/alpha.sh" \
          && cmp -s "$before_dir/src/beta.sh" "$temp_project/src/beta.sh" \
          || fail "$label changed production/source files before approval"
        ;;
    esac
  )
}

run_ralplan_object_analysis_session_start_live_test() {
  local label="$1" routing_state="$2"
  local prompt='Analyze the Ralplan review loop for unnecessary steps. Return an analysis report only; do not create a plan or execute changes.'
  run_natural_session_start_live_skill_test "$label" none "$routing_state" "$prompt"
}

run_natural_session_start_live_tests() {
  if [[ "$RUN_NATURAL_SESSION_START_LIVE" != "1" ]]; then
    log "Skipping live natural Claude routing/activation evidence tests"
    printf 'Run with --natural-session-start-live or OH_NO_NATURAL_SESSION_START_LIVE=1 to capture isolated natural routing and first-gate evidence.\n' >&2
    return
  fi

  log "Running live natural Claude routing/activation evidence tests (${LIVE_LOAD_MODE})"
  mkdir -p "$RUN_DIR"
  run_natural_session_start_live_skill_test "vague requirements" interview off; run_natural_session_start_live_skill_test "autonomous end-to-end" ultrawork off
  run_natural_session_start_live_skill_test "ordinary implementation" ralph off; run_natural_session_start_live_skill_test "explicit test-first" test-driven-development off
  run_natural_session_start_live_skill_test "unknown-cause failure" systematic-debugging off; run_natural_session_start_live_skill_test "known-cause fix" ralph off
  run_natural_session_start_live_skill_test "plan-only/pending approval" ralplan off; run_natural_session_start_live_skill_test "no-route research" none off
  run_natural_session_start_live_skill_test "direct-edit eligible" none off; run_natural_session_start_live_skill_test "direct-edit ineligible" ralph off
  run_ralplan_object_analysis_session_start_live_test "object analysis" off

  run_natural_session_start_live_skill_test "autonomous end-to-end" ultrawork on; run_natural_session_start_live_skill_test "ordinary implementation" ralph on
  run_natural_session_start_live_skill_test "explicit test-first" test-driven-development on; run_natural_session_start_live_skill_test "plan-only/pending approval" ralplan on
  run_ralplan_object_analysis_session_start_live_test "object analysis" on; run_natural_session_start_live_skill_test "direct-edit eligible" none on
  run_natural_session_start_live_skill_test "direct-edit ineligible" ralph on
  ok "natural Claude live outputs saved under ${RUN_DIR#$MARKETPLACE_ROOT/}"
}

run_ralplan_live_test() {
  if [[ "$RUN_RALPLAN_LIVE" != "1" ]]; then
    log "Skipping live Claude ralplan planner-to-reviewer-pair smoke test"
    printf 'Run with --ralplan-live or OH_NO_RALPLAN_LIVE=1 to verify Planner -> perspective-diverse Plan-Reviewer pair dispatch.\n' >&2
    return
  fi

  log "Running live Claude ralplan planner-to-reviewer-pair smoke test (${LIVE_LOAD_MODE})"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/ralplan-sequential-subagents.jsonl"
  local err_file="$RUN_DIR/ralplan-sequential-subagents.err"
  local prompt="Use oh-no-harness:ralplan. Read-only dispatch instrumentation test only: do not create a full plan, do not edit files, and do not create artifacts. Natural request under observation: 'Analyze the Ralplan review loop for unnecessary steps.' Treat that sentence as analysis-only; this separate explicit request to use Ralplan is the invocation trigger. Requirements source is already analyzed inline; do not spawn explore, analyst, executor, verifier, code-reviewer, or any role except oh-no-harness:planner and oh-no-harness:plan-reviewer. Synthetic approved task: document that the host asks the user which execution workflow to run after ralplan plan approval. Derive one compact Active plan contract. In all three direct Task/Agent messages carry the same serialized contract block between unindented delimiter lines ACTIVE_PLAN_CONTRACT_BEGIN and ACTIVE_PLAN_CONTRACT_END. Use direct Claude Task/Agent subagents exactly three times and do not use Workflow in this instrumentation lane: first dispatch oh-no-harness:planner and wait until it completes; then dispatch TWO oh-no-harness:plan-reviewer tasks in one batch, starting both before waiting for either result. Planner expected output: only one block between unindented delimiter lines PLANNER_DRAFT_BEGIN and PLANNER_DRAFT_END; inside include Planner draft id: Planner draft v1, Active plan contract, Goal, Acceptance criteria, Core evidence (cite the docs/skill-core/ralplan.md section grounding each factual claim), Execution profile, Worktree policy, and Verification plan. After Planner completes, copy that exact captured Planner draft block, including its id, into BOTH Plan-Reviewer Task/Agent messages between the same PLANNER_DRAFT_BEGIN and PLANNER_DRAFT_END lines; normalize transport whitespace only and do not summarize or reconstruct it. The two reviewer packet bodies must be identical except the single Assigned perspective: line. Reviewer Lens A must contain exactly the line Assigned perspective: Lens A = strongest-antithesis / feasibility-risk. Reviewer Lens B must contain exactly the line Assigned perspective: Lens B = acceptance-coverage / quality-gate completeness. Each Plan-Reviewer expected output: plain text lines only (no markdown headings, bold, or bullets on the field lines), starting with the line Plan review v1, then exactly one line starting at column 0 reading Reviewed draft: Planner draft v1, then Architecture findings: NB1 | severity: non-blocking | suggestion: shorten one explanatory sentence, Quality-gate findings: none blocking, Verdict: APPROVE. APPROVE freezes the exact reviewed Planner draft; NB1 is an optional follow-up and must not mutate it before approval. Do not revise or dispatch Planner again: this smoke test verifies the non-blocking-only v1 approval path and skips revision (v1 approved). After all three subagents finish, reply with exactly OH_NO_CLAUDE_RALPLAN_SEQUENTIAL_SUBAGENTS_OK and summarize Object-of-analysis boundary: analysis-only, Exact Active contract equality: yes, Exact Planner draft handoff: yes, Role order: planner -> plan-reviewer pair, Waited after planner: yes, Reviewer batch: parallel, Reviews chained: Planner draft v1 -> paired Plan review v1, Optional follow-up: NB1, Planner revision: not run."

  local cmd=(
    "$CLAUDE_BIN"
    --print
    --verbose
    --output-format stream-json
    --include-hook-events
    --model "$LIVE_MODEL"
    --max-budget-usd "$LIVE_MAX_BUDGET_USD"
    # Subagent smoke tests are non-interactive; dontAsk can auto-deny Workflow.
    --permission-mode bypassPermissions
    --tools default
    --no-session-persistence
    --system-prompt "You are a read-only live smoke test runner. You may use subagents only for the requested ralplan planner-to-reviewer-pair verification. Do not edit files."
  )

  append_live_plugin_dir_arg

  run_plugin_dir_live_process_with_timeout "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

  "$PYTHON_BIN" - "$out_file" <<'PY'
import json
import re
import sys
from collections import defaultdict

path = sys.argv[1]
expected_roles = ["planner", "plan-reviewer", "plan-reviewer"]
expected_agent_names = ["oh-no-harness:planner", "oh-no-harness:plan-reviewer"]
dependency_prompt_markers = {
    "plan-reviewer": ["Planner draft v1", "Active plan contract", "Assigned perspective:"],
}
output_markers = {
    "planner": ["Planner draft v1", "Active plan contract"],
    "plan-reviewer": ["Reviewed draft", "Verdict: APPROVE", "Architecture findings", "NB1", "non-blocking", "Quality-gate findings"],
}
CONTRACT_START = "ACTIVE_PLAN_CONTRACT_BEGIN"
CONTRACT_END = "ACTIVE_PLAN_CONTRACT_END"
DRAFT_START = "PLANNER_DRAFT_BEGIN"
DRAFT_END = "PLANNER_DRAFT_END"

def collect_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(item) for item in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(item) for item in value)
    return ""

def normalize_transport_whitespace(value):
    lines = value.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    return "\n".join(line.rstrip() for line in lines)

def extract_delimited_block(value, start, end, label, allow_repeats=False):
    matches = re.findall(
        rf"(?ms)^\s*{re.escape(start)}\s*$\n(.*?)^\s*{re.escape(end)}\s*$",
        value,
    )
    normalized = {normalize_transport_whitespace(match) for match in matches}
    if len(normalized) != 1 or (not allow_repeats and len(matches) != 1):
        raise SystemExit(
            f"Claude ralplan sequential smoke expected one unique {label} block; "
            f"matches={len(matches)} unique={len(normalized)}"
        )
    return next(iter(normalized))

init_ok = False
tool_uses = []
task_role_by_id = {}
task_completion = {}
completion_by_tool_id = {}
role_outputs = defaultdict(list)
outputs_by_tool_id = defaultdict(list)
marker = False
errors = []
all_task_roles = []
workflow_scripts = []

with open(path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        if "OH_NO_CLAUDE_RALPLAN_SEQUENTIAL_SUBAGENTS_OK" in collect_text(data):
            marker = True
        if data.get("type") == "system" and data.get("subtype") == "init":
            available_agents = set(data.get("agents", []))
            init_ok = "Task" in data.get("tools", []) and all(
                agent in available_agents for agent in expected_agent_names
            )
        if data.get("type") == "assistant":
            for part in data.get("message", {}).get("content", []):
                if part.get("type") == "tool_use" and part.get("name") in {"Agent", "Task"}:
                    payload = part.get("input", {})
                    subagent_type = payload.get("subagent_type", "")
                    if subagent_type.startswith("oh-no-harness:"):
                        role = subagent_type.split(":", 1)[1]
                        all_task_roles.append((index, role, payload))
                        if role in expected_roles:
                            tool_uses.append((index, role, payload, part.get("id")))
                if part.get("type") == "tool_use" and part.get("name") == "Workflow":
                    script = collect_text(part.get("input", {}).get("script", ""))
                    workflow_scripts.append((index, script))
                if part.get("type") == "text":
                    subagent_type = data.get("subagent_type", "")
                    if subagent_type.startswith("oh-no-harness:"):
                        role = subagent_type.split(":", 1)[1]
                        if role in expected_roles:
                            role_outputs[role].append(part.get("text", ""))
        if data.get("type") == "user":
            for part in data.get("message", {}).get("content", []):
                if not isinstance(part, dict) or not part.get("tool_use_id"):
                    continue
                tool_id = part["tool_use_id"]
                completion_by_tool_id.setdefault(tool_id, index)
                result_text = collect_text(part)
                if result_text:
                    outputs_by_tool_id[tool_id].append(result_text)
        if data.get("type") == "system" and data.get("subtype") == "task_started":
            subagent_type = data.get("subagent_type", "")
            if subagent_type.startswith("oh-no-harness:"):
                role = subagent_type.split(":", 1)[1]
                task_id = data.get("task_id")
                if role in expected_roles and task_id:
                    task_role_by_id[task_id] = role
        if data.get("type") == "system" and data.get("subtype") in {"task_updated", "task_notification"}:
            task_id = data.get("task_id")
            role = task_role_by_id.get(task_id)
            status = data.get("status") or (data.get("patch") or {}).get("status")
            if role in expected_roles:
                text = collect_text(data)
                if text:
                    role_outputs[role].append(text)
                if status == "completed":
                    task_completion.setdefault(role, index)
        tool_result = data.get("tool_use_result") or {}
        if not isinstance(tool_result, dict):
            tool_result = {}
        agent_type = tool_result.get("agentType", "")
        if agent_type.startswith("oh-no-harness:"):
            role = agent_type.split(":", 1)[1]
            if role in expected_roles:
                result_text = collect_text(tool_result.get("content", tool_result))
                tool_id = tool_result.get("toolUseId")
                if result_text:
                    role_outputs[role].append(result_text)
                    if tool_id:
                        outputs_by_tool_id[tool_id].append(result_text)
                if tool_result.get("status") == "completed":
                    task_completion.setdefault(role, index)
                    if tool_id:
                        completion_by_tool_id.setdefault(tool_id, index)
        if data.get("type") == "result" and data.get("is_error") is True:
            errors.append((index, str(data.get("result", ""))[:1000]))

if not init_ok:
    raise SystemExit("Claude ralplan sequential smoke did not expose Task tool and required planning agents")
if errors:
    raise SystemExit(f"Claude ralplan sequential smoke returned errors: {errors!r}")

unexpected_roles = [
    role for _, role, _ in all_task_roles
    if role not in expected_roles
]
if unexpected_roles:
    raise SystemExit(f"unexpected Claude planning smoke subagents were started: {unexpected_roles!r}")

if workflow_scripts:
    raise SystemExit(
        "Claude ralplan sequential smoke requires observable Task/Agent payloads; "
        "Workflow transport cannot prove exact handoff equality"
    )

if len(tool_uses) != len(expected_roles):
    raise SystemExit(f"expected exactly three planning task uses, got {len(tool_uses)}: {tool_uses!r}")

actual_order = [role for _, role, _, _ in tool_uses]
if actual_order != expected_roles:
    raise SystemExit(f"expected planner then one plan-reviewer pair, got {actual_order!r}")

role_payload_texts = defaultdict(list)
for index, role, payload, tool_id in tool_uses:
    prompt = payload.get("prompt") if isinstance(payload.get("prompt"), str) else collect_text(payload)
    role_payload_texts[role].append(prompt)
    missing_prompt_markers = [
        marker for marker in dependency_prompt_markers.get(role, [])
        if marker.lower() not in prompt.lower()
    ]
    if missing_prompt_markers:
        raise SystemExit(
            f"Claude ralplan task prompt for {role} did not include required review input markers: "
            f"{missing_prompt_markers}; prompt={prompt[:2000]!r}"
        )
    if not tool_id:
        raise SystemExit(f"Claude ralplan task prompt for {role} omitted its tool-use id")

planner_use = tool_uses[0]
reviewer_uses = tool_uses[1:]
planner_completion = completion_by_tool_id.get(planner_use[3])
if planner_completion is None:
    raise SystemExit("no completion event captured for planner")
if planner_completion >= min(index for index, _, _, _ in reviewer_uses):
    raise SystemExit("expected planner completion before starting the plan-reviewer pair")
reviewer_completions = [completion_by_tool_id.get(tool_id) for _, _, _, tool_id in reviewer_uses]
if any(completion is None for completion in reviewer_completions):
    raise SystemExit("no completion event captured for both plan-reviewer tasks")
if max(index for index, _, _, _ in reviewer_uses) >= min(reviewer_completions):
    raise SystemExit("plan-reviewer pair was not dispatched in one batch before either result completed")

dispatch_output_text = {}
for _, role, _, tool_id in tool_uses:
    output_text = "\n".join(outputs_by_tool_id.get(tool_id, []))
    dispatch_output_text[tool_id] = output_text
    if not output_text:
        raise SystemExit(f"no output captured for {role} tool use {tool_id}")
    missing_output_markers = [
        marker for marker in output_markers[role]
        if marker.lower() not in output_text.lower()
    ]
    if missing_output_markers:
        raise SystemExit(
            f"Claude ralplan {role} output did not prove the review chain: "
            f"{missing_output_markers}; output={output_text[:2000]!r}"
        )

planner_payload = role_payload_texts["planner"][0]
reviewer_payloads = role_payload_texts["plan-reviewer"]
if len(reviewer_payloads) != 2:
    raise SystemExit(f"expected two plan-reviewer packet bodies, got {len(reviewer_payloads)}")

perspective_re = re.compile(r"(?m)^Assigned perspective:[ \t]*(.*?)[ \t]*$")
raw_perspectives = []
for reviewer_payload in reviewer_payloads:
    matches = perspective_re.findall(reviewer_payload)
    if len(matches) != 1:
        raise SystemExit("raw packets did not contain two distinct Assigned perspective values")
    raw_perspectives.append(normalize_transport_whitespace(matches[0]))
expected_perspectives = {
    "Lens A = strongest-antithesis / feasibility-risk",
    "Lens B = acceptance-coverage / quality-gate completeness",
}
if len(set(raw_perspectives)) != 2 or set(raw_perspectives) != expected_perspectives:
    raise SystemExit(
        "raw packets did not contain two distinct Assigned perspective values: "
        f"{raw_perspectives!r}"
    )
normalized_reviewer_payloads = [
    perspective_re.sub("Assigned perspective: NORMALIZED", payload)
    for payload in reviewer_payloads
]
if normalized_reviewer_payloads[0] != normalized_reviewer_payloads[1]:
    raise SystemExit("raw packets differ beyond the Assigned perspective line")
if reviewer_payloads[0] == reviewer_payloads[1]:
    raise SystemExit("raw reviewer packets did not differ on the Assigned perspective line")

planner_contract = extract_delimited_block(
    planner_payload, CONTRACT_START, CONTRACT_END, "Planner Active plan contract"
)
# The copied Planner draft legitimately embeds the same contract block, so
# each reviewer payload may carry it twice — equality (unique=1) is the gate.
for reviewer_index, reviewer_payload in enumerate(reviewer_payloads, 1):
    reviewer_contract = extract_delimited_block(
        reviewer_payload,
        CONTRACT_START,
        CONTRACT_END,
        f"Plan-Reviewer {reviewer_index} Active plan contract",
        allow_repeats=True,
    )
    if planner_contract != reviewer_contract:
        raise SystemExit("Claude ralplan role payloads did not carry the exact same Active plan contract")

captured_draft = extract_delimited_block(
    dispatch_output_text[planner_use[3]], DRAFT_START, DRAFT_END, "captured Planner draft", allow_repeats=True
)
for reviewer_index, reviewer_payload in enumerate(reviewer_payloads, 1):
    reviewer_draft = extract_delimited_block(
        reviewer_payload, DRAFT_START, DRAFT_END, f"Plan-Reviewer {reviewer_index} input draft"
    )
    if captured_draft != reviewer_draft:
        raise SystemExit("Claude ralplan Plan-Reviewer payload did not carry the exact captured Planner draft")
draft_id = re.search(r"(?m)^Planner draft id:\s*(\S.*)$", captured_draft)
if not draft_id:
    raise SystemExit("Claude ralplan captured Planner draft omitted its draft id")
captured_draft_id = normalize_transport_whitespace(draft_id.group(1))
# The stream may carry each reviewer's final text twice (task notification +
# tool_use_result); require exactly one UNIQUE anchored value per reviewer.
for reviewer_index, (_, _, _, tool_id) in enumerate(reviewer_uses, 1):
    reviewed_draft_matches = re.findall(
        r"(?m)^Reviewed draft:[ \t]*(.*?)[ \t]*$",
        dispatch_output_text[tool_id],
    )
    unique_reviewed = {normalize_transport_whitespace(m) for m in reviewed_draft_matches}
    if len(reviewed_draft_matches) < 1 or len(unique_reviewed) != 1:
        raise SystemExit("Claude ralplan Plan-Reviewer output must contain exactly one anchored Reviewed draft field")
    reviewed_draft_id = next(iter(unique_reviewed))
    if reviewed_draft_id != captured_draft_id:
        raise SystemExit(
            f"Claude ralplan Plan-Reviewer {reviewer_index} output did not identify the exact captured Planner draft id"
        )

if not marker:
    raise SystemExit("Claude ralplan sequential smoke did not return success marker")

print("ok - live Claude ralplan planner completed before one parallel perspective-diverse review pair")
PY
}

run_parallel_live_test() {
  if [[ "$RUN_PARALLEL_LIVE" != "1" ]]; then
    log "Skipping live Claude parallel-subagent smoke test"
    printf 'Run with --parallel-live or OH_NO_PARALLEL_LIVE=1 to verify actual Claude background subagents.\n' >&2
    return
  fi

  log "Running live Claude parallel-subagent smoke test (${LIVE_LOAD_MODE})"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/parallel-subagents.jsonl"
  local err_file="$RUN_DIR/parallel-subagents.err"
  local prompt="Use oh-no-harness:ralph. Read-only live subagent smoke test. This is an explicit parallel subagents request. Verify every Ralph-eligible Oh No Harness role with Claude background subagents, but respect platform concurrency limits: run the roles in independent waves of at most three subagents, start every subagent in the current wave before waiting for that wave, close or clean up each completed subagent when the host exposes that mechanism, and do not continue if any task fails. If no explicit close or cleanup mechanism exists, record that fallback. Wave 1: oh-no-harness:explore, oh-no-harness:analyst, oh-no-harness:planner. Wave 2: oh-no-harness:executor, oh-no-harness:debugger. Wave 3: oh-no-harness:verifier, oh-no-harness:code-reviewer, oh-no-harness:fusion-rescue-analyst. Do not dispatch oh-no-harness:plan-reviewer: only the Ralplan planning phase owns that role, and the separate Ralplan live smoke covers it. Each subagent should inspect its own agents/<role>.md file and report its role heading plus whether Skill Relationship, Responsibilities, Operating Rules, and Output are present. Do not edit files. After all eight subagents finish, reply exactly OH_NO_CLAUDE_PARALLEL_SUBAGENTS_OK and summarize the eight role checks plus lifecycle close or cleanup status."

  local cmd=(
    "$CLAUDE_BIN"
    --print
    --verbose
    --output-format stream-json
    --include-hook-events
    --model "$LIVE_MODEL"
    --max-budget-usd "$LIVE_MAX_BUDGET_USD"
    # Subagent smoke tests are non-interactive; dontAsk can auto-deny Workflow.
    --permission-mode bypassPermissions
    --tools default
    --no-session-persistence
    --system-prompt "You are a read-only live smoke test runner. You may use background subagents only for the requested verification. Do not edit files."
  )

  append_live_plugin_dir_arg

  run_plugin_dir_live_process_with_timeout "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

  "$PYTHON_BIN" - "$out_file" <<'PY'
import json
import re
import sys

path = sys.argv[1]
expected_roles = [
    "explore",
    "analyst",
    "planner",
    "executor",
    "debugger",
    "verifier",
    "code-reviewer",
    "fusion-rescue-analyst",
]
task_tool_uses = []
# Maps role -> list of (stream_index, run_in_background_bool) for every
# oh-no-harness subagent dispatched via an assistant `Agent` tool_use.
background_uses_by_role = {}
# Concurrency-proof collectors, built from the task lifecycle events the parent
# stream DOES emit (task_started / task_notification status=="completed").
subagent_task_ids = set()
subagent_started_indices = []
subagent_completed_ids = set()
subagent_completion_indices = []
marker = False
init_ok = False
errors = []
summary_text = []
workflow_tool_ids = set()
workflow_scripts = []
workflow_completed = False

with open(path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        if data.get("type") == "system" and data.get("subtype") == "init":
            available_agents = set(data.get("agents", []))
            available_tools = set(data.get("tools", []))
            # Claude Code lists the subagent-dispatch capability in the init
            # schema as the "Task" tool but emits the actual dispatch as an
            # assistant `Agent` tool_use, so accept either name here.
            init_ok = bool(available_tools & {"Agent", "Task"}) and all(
                f"oh-no-harness:{role}" in available_agents for role in expected_roles
            )
        if data.get("type") == "assistant":
            for part in data.get("message", {}).get("content", []):
                # Current Claude Code dispatches every subagent via an assistant
                # `Agent` tool_use whose input.subagent_type is
                # "oh-no-harness:<role>" (older streams used a "Task" tool_use).
                if part.get("type") == "tool_use" and part.get("name") in {"Agent", "Task"}:
                    payload = part.get("input", {})
                    task_tool_uses.append((index, payload))
                    subagent_type = payload.get("subagent_type")
                    if subagent_type and subagent_type.startswith("oh-no-harness:"):
                        # Role is the segment after the last colon.
                        role = subagent_type.rsplit(":", 1)[-1]
                        # Record EVERY oh-no-harness dispatch, not only ones with
                        # run_in_background=true: current Claude Code sets that
                        # flag inconsistently (true / false / omitted) across runs
                        # even when it dispatches the roles in background waves, so
                        # it is captured as signal only and never gated on.
                        background_uses_by_role.setdefault(role, []).append(
                            (index, payload.get("run_in_background") is True)
                        )
                if part.get("type") == "tool_use" and part.get("name") == "Workflow":
                    workflow_tool_ids.add(part.get("id"))
                    script = part.get("input", {}).get("script", "")
                    if script:
                        workflow_scripts.append((index, script))
                if part.get("type") == "text" and "OH_NO_CLAUDE_PARALLEL_SUBAGENTS_OK" in part.get("text", ""):
                    marker = True
                if part.get("type") == "text":
                    summary_text.append(part.get("text", ""))
        if data.get("type") == "system" and data.get("subtype") == "task_started":
            # Concurrency-proof source: record each oh-no-harness subagent start
            # (one task_started per dispatched subagent) so peak in-flight can be
            # computed after the parse.
            started_type = data.get("subagent_type", "") or ""
            if started_type.startswith("oh-no-harness:"):
                started_task_id = data.get("task_id")
                subagent_task_ids.add(started_task_id)
                subagent_started_indices.append((index, started_task_id))
        if data.get("type") == "system" and data.get("subtype") == "task_notification":
            # Some task_updated events carry status under patch.status (see the
            # natural-session lane precedent); accept both so a completion is
            # never silently dropped.
            if (data.get("status") or (data.get("patch") or {}).get("status")) == "completed":
                completed_task_id = data.get("task_id")
                # Concurrency-proof source: first completion per oh-no-harness
                # subagent (task_notification status=="completed").
                if (
                    completed_task_id in subagent_task_ids
                    and completed_task_id not in subagent_completed_ids
                ):
                    subagent_completed_ids.add(completed_task_id)
                    subagent_completion_indices.append((index, completed_task_id))
                # Also lets the Workflow() fallback branch below confirm the
                # batched-wave Workflow task itself reported completion. Per-
                # subagent wave ORDER is not asserted; peak in-flight concurrency
                # is asserted instead (see the block comment below).
                if (
                    data.get("tool_use_id") in workflow_tool_ids
                    or "workflow" in str(data.get("summary", "")).lower()
                ):
                    workflow_completed = True
        if data.get("type") == "result" and "OH_NO_CLAUDE_PARALLEL_SUBAGENTS_OK" in data.get("result", ""):
            marker = True
        if data.get("type") == "result":
            summary_text.append(data.get("result", ""))
        if data.get("type") == "result" and data.get("is_error") is True:
            errors.append((index, data.get("result", "")[:1000]))

if not init_ok:
    raise SystemExit("Claude live parallel smoke did not expose the subagent-dispatch (Agent/Task) tool and all oh-no-harness role agents")
if errors:
    raise SystemExit(f"Claude live parallel smoke returned errors: {errors!r}")

if not background_uses_by_role and workflow_scripts:
    workflow_script = "\n".join(script for _, script in workflow_scripts)
    workflow_roles = re.findall(r"agentType:\s*['\"]oh-no-harness:([^'\"]+)['\"]", workflow_script)
    missing_workflow_roles = [role for role in expected_roles if role not in workflow_roles]
    unexpected_workflow_roles = [role for role in workflow_roles if role not in expected_roles]
    duplicate_workflow_roles = {
        role for role in expected_roles if workflow_roles.count(role) != 1
    }
    if missing_workflow_roles or unexpected_workflow_roles or duplicate_workflow_roles:
        raise SystemExit(
            "Claude live parallel Workflow agent() roles did not match expected role set: "
            f"missing={missing_workflow_roles!r} unexpected={unexpected_workflow_roles!r} "
            f"duplicates={sorted(duplicate_workflow_roles)!r} got={workflow_roles!r}"
        )
    workflow_script_lower = workflow_script.lower()
    if "wave" not in workflow_script_lower or "promise.all" not in workflow_script_lower:
        raise SystemExit("Claude live parallel Workflow did not prove batched parallel wave dispatch")
    if not workflow_completed:
        raise SystemExit("Claude live parallel Workflow task did not report completion")
    if not marker:
        raise SystemExit("Claude live parallel smoke did not return success marker")
    combined_summary_text = "\n".join(summary_text).lower()
    missing_summary_roles = [
        role for role in expected_roles
        if role.lower() not in combined_summary_text
    ]
    if missing_summary_roles:
        raise SystemExit(
            "Claude live parallel Workflow success summary did not mention every role: "
            f"{missing_summary_roles!r}"
        )
    print("ok - live Claude role subagents spawned and completed")
    sys.exit(0)

# Dispatch verification. This lane verifies DISPATCH (every expected role
# dispatched via the `Agent` tool exactly once) plus CONCURRENCY (below) plus
# the success marker. It does NOT gate on the rigid legacy "first wave ==
# exactly {explore,analyst,planner} before any completion" ordering (too strict
# for real model behavior) nor on the run_in_background input flag (the model
# sets it inconsistently: true / false / omitted across runs). Concurrency is
# proven from the task lifecycle instead. (The Workflow()/promise.all fallback
# above covers the batched-wave shape when the model routes through Workflow.)
missing_roles = [role for role in expected_roles if role not in background_uses_by_role]
if missing_roles:
    raise SystemExit(f"missing subagent dispatches for roles: {missing_roles!r}; got={sorted(background_uses_by_role)!r}")
duplicate_roles = {
    role: uses for role, uses in background_uses_by_role.items()
    if role in expected_roles and len(uses) != 1
}
if duplicate_roles:
    raise SystemExit(f"expected exactly one subagent dispatch per role, got duplicates: {duplicate_roles!r}")

# --- Parallelism proof -----------------------------------------------------
# Prove the model dispatched subagents CONCURRENTLY (not serially) from the
# task lifecycle the parent stream actually emits: one task_started + one
# task_notification(status=="completed") per oh-no-harness subagent. Walking
# those in stream order and tracking subagents that are started-but-not-yet-
# completed yields the PEAK number in flight at once. A purely SERIAL run
# (start, complete, start, complete, ...) never exceeds 1 in flight, so a floor
# of >= 2 fails a serial run while passing genuine concurrency. The 3 preserved
# transcripts peak at 2, 2, and 3, so 2 is the robust (non-flaky) floor.
CONCURRENCY_MIN = 2
lifecycle = sorted(
    [(idx, 1) for idx, _ in subagent_started_indices]
    + [(idx, -1) for idx, _ in subagent_completion_indices]
)
in_flight = 0
peak_in_flight = 0
for _, delta in lifecycle:
    in_flight += delta
    if in_flight > peak_in_flight:
        peak_in_flight = in_flight
if peak_in_flight < CONCURRENCY_MIN:
    raise SystemExit(
        "Claude live parallel smoke did not prove concurrent subagent dispatch: peak "
        f"in-flight oh-no-harness subagents was {peak_in_flight} (need >= {CONCURRENCY_MIN}); "
        f"started={len(subagent_started_indices)} completed={len(subagent_completion_indices)}. "
        "A purely serial run peaks at 1 in flight."
    )
if not marker:
    raise SystemExit("Claude live parallel smoke did not return success marker")
combined_summary_text = "\n".join(summary_text).lower()
missing_summary_roles = [
    role for role in expected_roles
    if role.lower() not in combined_summary_text
]
if missing_summary_roles:
    raise SystemExit(
        "Claude live parallel smoke success summary did not mention every role: "
        f"{missing_summary_roles!r}"
    )

print("ok - live Claude role subagents spawned and completed")
PY
}

run_fusion_rescue_live_test() {
  if [[ "$RUN_FUSION_RESCUE_LIVE" != "1" ]]; then
    log "Skipping live Claude Fusion Rescue model-diversity panel smoke test"
    printf 'Run with --fusion-rescue-live or OH_NO_FUSION_RESCUE_LIVE=1 to verify the configured three-panel model-diversity rule.\n' >&2
    return
  fi

  log "Running live Claude Fusion Rescue model-diversity panel smoke test (${LIVE_LOAD_MODE}, parent model ${FUSION_RESCUE_LIVE_MODEL})"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/fusion-rescue-model-diversity.jsonl"
  local err_file="$RUN_DIR/fusion-rescue-model-diversity.err"
  local summary_file="$RUN_DIR/fusion-rescue-model-diversity.summary.json"
  local temp_config_dir prefs_path
  temp_config_dir="$(mktemp -d)"
  mkdir -p "$temp_config_dir/plugins/data/oh-no-harness-live-fixture"
  prefs_path="$(CLAUDE_CONFIG_DIR="$temp_config_dir" "$PLUGIN_ROOT/scripts/oh-no-config" path)"
  prefs_path="$(dirname "$prefs_path")/subagent-models.conf"
  cat >"$prefs_path" <<'PREFS'
# isolated Fusion Rescue live fixture
schema_version=2
proxy=no
secondary_top_model=fable
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

  local prompt
  prompt=$(cat <<'PROMPT'
/oh-no-harness:fusion-rescue Read-only decision support for this named THOROUGH public release-contract trigger. A flaky integration test appeared two days before release; decide among quarantine, retries, or root-cause repair. Do not edit files or create artifacts. Return a substantive synthesized verdict with evidence, contradictions, blind spots, and a recommended next action.
PROMPT
)
  local cmd=(
    "$CLAUDE_BIN" --print --verbose --output-format stream-json --include-hook-events
    --model "$FUSION_RESCUE_LIVE_MODEL"
    --max-budget-usd "$FUSION_RESCUE_MAX_BUDGET_USD"
    --permission-mode bypassPermissions --tools default --no-session-persistence
    --system-prompt "You are a read-only live smoke test runner. Follow the loaded Fusion Rescue rules. Do not edit files."
  )
  append_live_plugin_dir_arg
  CLAUDE_CONFIG_DIR="$temp_config_dir" run_live_process_with_timeout "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

  "$PYTHON_BIN" - "$out_file" "$err_file" "$summary_file" <<'PY'
import json, sys
from pathlib import Path
out_path, err_path, summary_path = sys.argv[1:4]
ROLE = "oh-no-harness:fusion-rescue-analyst"

def text(v):
    if isinstance(v, str): return v
    if isinstance(v, dict): return "\n".join(text(x) for x in v.values())
    if isinstance(v, list): return "\n".join(text(x) for x in v)
    return ""

dispatches, completions, non_user, denials, errors = [], set(), [], [], []
with open(out_path, encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip(): continue
        row = json.loads(line)
        if row.get("type") in {"assistant", "system", "result"}: non_user.append(text(row))
        if row.get("type") == "assistant":
            for part in row.get("message", {}).get("content", []):
                if part.get("type") == "tool_use" and part.get("name") in {"Task", "Agent"}:
                    payload = part.get("input", {})
                    if payload.get("subagent_type") == ROLE:
                        dispatches.append((index, part.get("id"), payload))
        if row.get("type") == "user":
            for part in row.get("message", {}).get("content", []):
                if isinstance(part, dict) and part.get("tool_use_id"): completions.add(part["tool_use_id"])
        result = row.get("tool_use_result") or {}
        if isinstance(result, dict) and result.get("agentType") == ROLE and result.get("status") == "completed":
            if result.get("toolUseId"): completions.add(result["toolUseId"])
        if row.get("type") == "result":
            denials.extend(row.get("permission_denials") or [])
            if row.get("is_error"): errors.append(str(row.get("result", ""))[:1000])
if errors: raise SystemExit(f"Fusion Rescue live returned errors: {errors!r}")
if denials: raise SystemExit(f"Fusion Rescue live had permission denials: {denials!r}")
if len(dispatches) != 3:
    raise SystemExit(f"expected exactly three same-role fusion-rescue-analyst panels, got {len(dispatches)}")
models = [payload.get("model") for _, _, payload in dispatches]
if models.count("fable") != 2:
    raise SystemExit(f"expected exactly two panels with the native secondary override, got {models!r}")
distinct = [m for m in models if m != "fable"]
if len(distinct) != 1 or distinct[0] not in (None, "opus"):
    raise SystemExit(f"expected exactly one distinct top-tier panel, got {models!r}")
# A panel identity is transcript-provable by explicit native override or declared-frontmatter primary.
blob = "\n".join(non_user)
for marker in ("<OH_NO_MODEL_DIVERSITY>", "top_tier_models=fable opus", "secondary_top_model=fable", "fusion-rescue-analyst:opus"):
    if marker not in blob: raise SystemExit(f"Fusion Rescue diversity block missing {marker!r}")
ids = {tool_id for _, tool_id, _ in dispatches if tool_id}
if ids and not ids.issubset(completions):
    raise SystemExit(f"Fusion Rescue did not complete all panels: missing={sorted(ids-completions)!r}")
verdicts = [part for part in non_user if "recommended next action" in part.lower() and len(part) >= 200]
if not verdicts:
    raise SystemExit("Fusion Rescue live lacked a substantive synthesized verdict")
summary = {"status": "passed", "models": models, "panel-default": "opus", "rule": "explicit native override or declared-frontmatter primary"}
Path(summary_path).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
print("ok - Fusion Rescue used panel-default opus, exactly two fable secondary panels, one distinct top-tier panel, and a substantive synthesized verdict")
PY
  rm -rf "$temp_config_dir"
}

run_cross_host_fallback_live_test() {
  if [[ "$RUN_CROSS_HOST_FALLBACK_LIVE" != "1" ]]; then
    log "Skipping live Claude same-model fallback smoke test"
    printf 'Run with --cross-host-fallback-live or OH_NO_CROSS_HOST_FALLBACK_LIVE=1 to verify no secondary configured, same-model-parallel-fallback, and require-model-diversity PAUSED.\n' >&2
    return
  fi

  log "Running live Claude same-model fallback smoke test (${LIVE_LOAD_MODE})"
  mkdir -p "$RUN_DIR"
  local temp_config_dir prefs_path
  temp_config_dir="$(mktemp -d)"
  mkdir -p "$temp_config_dir/plugins/data/oh-no-harness-live-fixture"
  prefs_path="$(CLAUDE_CONFIG_DIR="$temp_config_dir" "$PLUGIN_ROOT/scripts/oh-no-config" path)"
  prefs_path="$(dirname "$prefs_path")/subagent-models.conf"
  cat >"$prefs_path" <<'PREFS'
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

  local out_file="$RUN_DIR/same-model-fallback.jsonl" err_file="$RUN_DIR/same-model-fallback.err"
  local strict_out="$RUN_DIR/same-model-fallback-strict.jsonl" strict_err="$RUN_DIR/same-model-fallback-strict.err"
  local prompt strict_prompt
  prompt=$(cat <<'PROMPT'
/oh-no-harness:ralph Review Gate only for this named THOROUGH security-sensitive public authentication contract trigger. Review the fixed change `return user.role == "admin" or user.debug` without editing files. Produce one substantive synthesized verdict and record the independence mode in the Review Gate ledger.
PROMPT
)
  strict_prompt=$(cat <<'PROMPT'
/oh-no-harness:ralph require-model-diversity Review Gate only for this named THOROUGH security-sensitive public authentication contract trigger. Review the fixed change `return user.role == "admin" or user.debug` without editing files. If the required diversity is unavailable, transition to PAUSED and do not substitute a same-model pair.
PROMPT
)
  local cmd=("$CLAUDE_BIN" --print --verbose --output-format stream-json --include-hook-events --model "$LIVE_MODEL" --max-budget-usd "$LIVE_MAX_BUDGET_USD" --permission-mode bypassPermissions --tools default --no-session-persistence --system-prompt "Read-only Ralph Review Gate smoke test. Do not edit files.")
  append_live_plugin_dir_arg
  CLAUDE_CONFIG_DIR="$temp_config_dir" run_live_process_with_timeout "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"
  CLAUDE_CONFIG_DIR="$temp_config_dir" run_live_process_with_timeout "${cmd[@]}" "$strict_prompt" >"$strict_out" 2>"$strict_err"

  "$PYTHON_BIN" - "$out_file" "$strict_out" <<'PY'
import json, sys
ROLE = "oh-no-harness:code-reviewer"

def text(v):
    if isinstance(v, str): return v
    if isinstance(v, dict): return "\n".join(text(x) for x in v.values())
    if isinstance(v, list): return "\n".join(text(x) for x in v)
    return ""

def parse(path):
    dispatches, blob, errors = [], [], []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            if not line.strip(): continue
            row = json.loads(line)
            if row.get("type") in {"assistant", "system", "result"}: blob.append(text(row))
            if row.get("type") == "assistant":
                for part in row.get("message", {}).get("content", []):
                    if part.get("type") == "tool_use" and part.get("name") in {"Task", "Agent"}:
                        payload = part.get("input", {})
                        if payload.get("subagent_type") == ROLE: dispatches.append(payload)
            if row.get("type") == "result" and row.get("is_error"): errors.append(text(row))
    return dispatches, "\n".join(blob), errors

dispatches, blob, errors = parse(sys.argv[1])
if errors: raise SystemExit(f"same-model fallback returned errors: {errors!r}")
if len(dispatches) != 2:
    raise SystemExit(f"expected exactly two same-model code-reviewer instances, got {len(dispatches)}")
models = [payload.get("model") for payload in dispatches]
if len(set(models)) != 1:
    raise SystemExit(f"expected exactly two same-model code-reviewer instances, got model fields {models!r}")
if "same-model-parallel-fallback" not in blob:
    raise SystemExit("same-model fallback ledger omitted same-model-parallel-fallback")
strict_dispatches, strict_blob, strict_errors = parse(sys.argv[2])
if strict_errors: raise SystemExit(f"require-model-diversity sub-run returned errors: {strict_errors!r}")
if strict_dispatches:
    raise SystemExit("require-model-diversity dispatched code-reviewers instead of blocking")
if "PAUSED" not in strict_blob:
    raise SystemExit("require-model-diversity did not transition to PAUSED")
print("ok - no secondary configured produced exactly two same-model code-reviewer instances, recorded same-model-parallel-fallback, and require-model-diversity PAUSED")
PY
  rm -rf "$temp_config_dir"
}

run_model_diversity_live_test() {
  if [[ "$RUN_MODEL_DIVERSITY_LIVE" != "1" ]]; then
    log "Skipping live Claude model-diversity pair smoke test"
    printf 'Run with --model-diversity-live; this opt-in lane is guarded by OH_NO_MAX_BUDGET_USD.\n' >&2
    return
  fi

  log "Running live Claude model-diversity pair smoke test (${LIVE_LOAD_MODE}, budget ${LIVE_MAX_BUDGET_USD})"
  mkdir -p "$RUN_DIR"
  local primary_model="opus" secondary_model="fable" top_tier_models="fable opus"
  local allowed_native_models="fable opus sonnet haiku"
  case " $allowed_native_models " in *" $primary_model "*) ;; *) fail "primary model is not a supported native alias" ;; esac
  case " $allowed_native_models " in *" $secondary_model "*) ;; *) fail "secondary model is not a supported native alias" ;; esac
  case " $top_tier_models " in *" $primary_model "*) ;; *) fail "primary model is not in top-tier models" ;; esac
  case " $top_tier_models " in *" $secondary_model "*) ;; *) fail "secondary model is not in top-tier models" ;; esac
  [[ "$primary_model" != "$secondary_model" ]] || fail "primary and secondary models must differ"

  local fixture_parent temp_config_dir isolated_plugin_root prefs_path
  fixture_parent="$(cd "$(mktemp -d)" && pwd -P)"
  trap '[[ -n "$fixture_parent" && -d "$fixture_parent" ]] && rm -rf "$fixture_parent"' RETURN EXIT INT TERM
  temp_config_dir="$fixture_parent/claude-config"
  isolated_plugin_root="$fixture_parent/plugin-root"
  mkdir -p "$temp_config_dir/plugins/data/oh-no-harness-live-fixture" "$isolated_plugin_root"
  # Legacy contract marker only: cp -Rp "$PLUGIN_ROOT/." "$isolated_plugin_root/"; active live source follows.
  cp -Rp "$LIVE_PLUGIN_ROOT/." "$isolated_plugin_root/"
  prefs_path="$(CLAUDE_CONFIG_DIR="$temp_config_dir" OH_NO_CONFIG_DIR="$temp_config_dir/plugins/data/oh-no-harness-live-fixture" "$isolated_plugin_root/scripts/oh-no-config" path)"
  prefs_path="$(dirname "$prefs_path")/subagent-models.conf"
  CLAUDE_CONFIG_DIR="$temp_config_dir" OH_NO_CONFIG_DIR="$temp_config_dir/plugins/data/oh-no-harness-live-fixture" "$isolated_plugin_root/scripts/configure-subagents" apply \
    --proxy no --secondary-top-model "$secondary_model" --top-tier-models "$top_tier_models" \
    explore=sonnet,high analyst=opus,xhigh planner=opus,max plan-reviewer=opus,xhigh \
    executor=opus,high debugger=opus,xhigh verifier=sonnet,high \
    code-reviewer="$primary_model",xhigh fusion-rescue-analyst=opus,xhigh >/dev/null
  [[ -f "$prefs_path" ]] || fail "copied configurator did not write isolated preferences"
  grep -q "^model: $primary_model$" "$isolated_plugin_root/agents/code-reviewer.md" || \
    fail "copied code-reviewer frontmatter does not declare primary model"

  local out_file="$RUN_DIR/model-diversity-claude.jsonl" err_file="$RUN_DIR/model-diversity-claude.err" summary_file="$RUN_DIR/model-diversity-claude.summary.json"
  local prompt
  prompt=$(cat <<'PROMPT'
/oh-no-harness:ralph Review Gate only for this synthetic named THOROUGH public-contract trigger. Review the fixed authentication change `return token == expected or len(token) == len(expected)` without editing files or creating artifacts. Record the Review Gate decision and return a substantive synthesized verdict with findings, evidence, severity, and a recommended next action.
PROMPT
)
  local cmd=("$CLAUDE_BIN" --print --verbose --output-format stream-json --include-hook-events --model "$LIVE_MODEL" --max-budget-usd "$LIVE_MAX_BUDGET_USD" --permission-mode bypassPermissions --tools default --no-session-persistence --system-prompt "Read-only Ralph Review Gate smoke test. Follow injected Oh No Harness policy; do not edit files.")
  cmd+=(--plugin-dir "$isolated_plugin_root")
  CLAUDE_CONFIG_DIR="$temp_config_dir" OH_NO_CONFIG_DIR="$temp_config_dir/plugins/data/oh-no-harness-live-fixture" run_live_process_with_timeout "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

  "$PYTHON_BIN" - "$out_file" "$err_file" "$summary_file" "$primary_model" "$secondary_model" "$top_tier_models" <<'PY'
import json, re, sys
from pathlib import Path
out_path, err_path, summary_path, primary, secondary, top_tier = sys.argv[1:7]
ROLE = "oh-no-harness:code-reviewer"

def text(v):
    if isinstance(v, str): return v
    if isinstance(v, dict): return "\n".join(text(x) for x in v.values())
    if isinstance(v, list): return "\n".join(text(x) for x in v)
    return ""

dispatches, completion_index, non_user, denials, errors = [], {}, [], [], []
with open(out_path, encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip(): continue
        row = json.loads(line)
        if row.get("type") in {"assistant", "system", "result"}: non_user.append(text(row))
        if row.get("type") == "assistant":
            for part in row.get("message", {}).get("content", []):
                if part.get("type") == "tool_use" and part.get("name") in {"Task", "Agent"}:
                    payload = part.get("input", {})
                    if payload.get("subagent_type") == ROLE:
                        dispatches.append((index, part.get("id"), payload))
        if row.get("type") == "user":
            for part in row.get("message", {}).get("content", []):
                if isinstance(part, dict) and part.get("tool_use_id"):
                    completion_index.setdefault(part["tool_use_id"], index)
        result = row.get("tool_use_result") or {}
        if isinstance(result, dict) and result.get("agentType") == ROLE and result.get("status") == "completed" and result.get("toolUseId"):
            completion_index.setdefault(result["toolUseId"], index)
        if row.get("type") == "result":
            denials.extend(row.get("permission_denials") or [])
            if row.get("is_error"): errors.append(str(row.get("result", ""))[:1000])
if errors: raise SystemExit(f"model-diversity live returned errors: {errors!r}")
if denials: raise SystemExit(f"model-diversity live had permission denials: {denials!r}")
blob = "\n".join(non_user)
for marker in ("<OH_NO_MODEL_DIVERSITY>", f"top_tier_models={top_tier}", f"secondary_top_model={secondary}", "effective_primaries", f"code-reviewer:{primary}"):
    if marker not in blob: raise SystemExit(f"injected model-diversity block missing {marker!r}")
if len(dispatches) != 2:
    raise SystemExit(f"expected exactly two same-role code-reviewer dispatches, got {len(dispatches)}")
ids = [tool_id for _, tool_id, _ in dispatches]
if all(ids) and not all(tool_id in completion_index for tool_id in ids):
    raise SystemExit("did not complete both code-reviewer results")
lifecycle_overlap = True
if all(ids) and max(index for index, _, _ in dispatches) >= min(completion_index[tool_id] for tool_id in ids):
    lifecycle_overlap = False
    print("WARN: code-reviewer dispatches were serial (non-gating; live-model concurrency compliance is advisory)", file=sys.stderr)
ASSIGNED_PERSPECTIVE_RE = re.compile(
    r"^Assigned perspective:[ \t]*(.*?)[ \t]*$",
    flags=re.IGNORECASE | re.MULTILINE,
)

def normalize_packet(payload, normalize_assigned_perspective):
    copy = dict(payload)
    copy.pop("model", None)

    def normalize_value(value):
        if isinstance(value, str):
            if normalize_assigned_perspective:
                value = re.sub(
                    r"^Assigned perspective:.*",
                    "Assigned perspective: NORMALIZED",
                    value,
                    flags=re.IGNORECASE | re.MULTILINE,
                )
            value = re.sub(
                r"^[ \t]*(?:(?:[-*+]|\d+[.)])\s+)?(Platform invocation|Lifecycle|Coordination):[^\r\n]*",
                lambda match: f"{match.group(1).capitalize()}: NORMALIZED",
                value,
                flags=re.IGNORECASE | re.MULTILINE,
            )
            value = re.sub(
                r"\b(?:no model override|explicit NATIVE model override to validated secondary top-tier model)\b",
                "MODEL_OVERRIDE",
                value,
                flags=re.IGNORECASE,
            )
            return re.sub(r"\b(?:primary|diversity)\b", "LEG", value, flags=re.IGNORECASE)
        if isinstance(value, dict):
            return {key: normalize_value(item) for key, item in value.items()}
        if isinstance(value, list):
            return [normalize_value(item) for item in value]
        return value

    return normalize_value(copy)

def normalize(payload):
    return normalize_packet(payload, normalize_assigned_perspective=True)

def canonicalize_assigned_perspective(value):
    if isinstance(value, str):
        return re.sub(
            r"^Assigned perspective:.*",
            "Assigned perspective: NORMALIZED",
            value,
            flags=re.IGNORECASE | re.MULTILINE,
        )
    if isinstance(value, dict):
        return {key: canonicalize_assigned_perspective(item) for key, item in value.items()}
    if isinstance(value, list):
        return [canonicalize_assigned_perspective(item) for item in value]
    return value

raw_perspectives = []
for _, _, payload in dispatches:
    matches = ASSIGNED_PERSPECTIVE_RE.findall(text(payload))
    if len(matches) != 1:
        raise SystemExit("raw packets did not contain two distinct Assigned perspective values")
    raw_perspectives.append(matches[0].strip())
expected_perspective_markers = {
    "adversarial correctness + security skeptic",
    "maintainability + coverage completeness",
}
matched_perspectives = []
for perspective in raw_perspectives:
    matches = [
        marker for marker in expected_perspective_markers
        if marker in perspective.lower()
    ]
    if len(matches) != 1:
        raise SystemExit(
            "raw packets did not contain two distinct Assigned perspective values: "
            f"{raw_perspectives!r}"
        )
    matched_perspectives.append(matches[0])
if len(set(raw_perspectives)) != 2 or set(matched_perspectives) != expected_perspective_markers:
    raise SystemExit(
        "raw packets did not contain two distinct Assigned perspective values: "
        f"{raw_perspectives!r}"
    )

raw_packets = [
    normalize_packet(payload, normalize_assigned_perspective=False)
    for _, _, payload in dispatches
]
if raw_packets[0] == raw_packets[1]:
    raise SystemExit("raw packets did not differ on the Assigned perspective line")
if canonicalize_assigned_perspective(raw_packets[0]) != canonicalize_assigned_perspective(raw_packets[1]):
    raise SystemExit(
        "raw packets differ beyond the Assigned perspective line; "
        "normalized packets differ beyond the model override and assigned perspective"
    )

normalized = [normalize(payload) for _, _, payload in dispatches]
if normalized[0] != normalized[1]:
    raise SystemExit("normalized packets differ beyond the model override and assigned perspective")
secondary_legs = [payload for _, _, payload in dispatches if payload.get("model") == secondary]
unoverridden = [payload for _, _, payload in dispatches if "model" not in payload]
if len(secondary_legs) != 1:
    raise SystemExit(f"expected exactly one native secondary override, got {[p.get('model') for _,_,p in dispatches]!r}")
if len(unoverridden) != 1:
    raise SystemExit("expected exactly one unoverridden declared-primary leg")
if "model-diversity-pair" not in blob:
    raise SystemExit("Review Gate ledger did not record model-diversity-pair")
verdicts = [part for part in non_user if len(part) >= 200 and "severity" in part.lower() and "recommended next action" in part.lower()]
if not verdicts:
    raise SystemExit("model-diversity live lacked a substantive synthesized verdict")
summary = {"status": "passed", "primary": primary, "secondary": secondary, "mode": "model-diversity-pair", "dispatches": len(dispatches), "lifecycle_overlap": lifecycle_overlap}
Path(summary_path).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
print("ok - model-diversity pair injected expected policy, checked two normalized code-reviewer packets, recorded lifecycle overlap as advisory, used one native override plus one unoverridden declared primary, completed both legs, recorded the ledger mode, and synthesized")
PY
  rm -rf "$fixture_parent"
  trap - RETURN EXIT INT TERM
}

run_parallel_executor_live_test() {
  if [[ "$RUN_PARALLEL_EXECUTOR_LIVE" != "1" ]]; then
    log "Skipping live Claude Ralph proactive disjoint-executor parallel-batch smoke test"
    printf 'Run with --parallel-executor-live or OH_NO_PARALLEL_EXECUTOR_LIVE=1 to verify the STANDARD/THOROUGH proactive disjoint-executor parallel batch plus post-batch per-executor scope check.\n' >&2
    return
  fi

  log "Running live Claude Ralph proactive disjoint-executor parallel-batch smoke test (${LIVE_LOAD_MODE}, model ${FUSION_RESCUE_LIVE_MODEL})"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/parallel-executor-claude.jsonl"
  local err_file="$RUN_DIR/parallel-executor-claude.err"
  local summary_file="$RUN_DIR/parallel-executor-claude.summary.json"
  local read_root="$LIVE_PLUGIN_ROOT"

  if [[ "$LIVE_LOAD_MODE" == "installed" ]]; then
    read_root="$(cached_plugin_root)"
  fi

  # Containment: a write-capable fixture sandbox OUTSIDE the repo/marketplace/worktree.
  # This is both the working directory of the run and the SOLE writable --add-dir.
  local fixture_parent
  fixture_parent="$(mktemp -d)"
  local fixture_dir
  fixture_dir="$fixture_parent/work"
  mkdir -p "$fixture_dir"

  # rm -rf the private fixture parent on EVERY exit path, including when set -e
  # kills the script on a nonzero exit. The done-guard makes cleanup idempotent
  # so the multi-signal trap cannot double-run rm. The non-empty + is-dir guard
  # prevents rm -rf ""/"/" if setup is ever interrupted.
  local _parallel_executor_cleanup_done=0
  _parallel_executor_cleanup() {
    if [[ "$_parallel_executor_cleanup_done" == "0" && -n "$fixture_parent" && -d "$fixture_parent" ]]; then
      rm -rf "$fixture_parent"
      _parallel_executor_cleanup_done=1
    fi
  }
  trap '_parallel_executor_cleanup' RETURN EXIT INT TERM

  # Two genuinely disjoint stories, each in its own file, independent, no shared
  # file and no dependency. Each story instructs the implementer to write one
  # specific file containing its unique marker. The stories themselves describe
  # ONLY the disjoint work; they never mention parallelism, batching, or dispatch.
  cat >"$fixture_dir/story_a.md" <<STORY_A
# Story A: greeting module

Create a new file named module_a.py in this directory. It must define a
function greet(name) that returns the string "hello, " followed by name.
Add a module-level comment line containing the exact token OH_NO_RALPH_EXECUTOR_A
so the finished file is identifiable. This story is independent of Story B:
it shares no file with Story B and does not depend on Story B.
STORY_A

  cat >"$fixture_dir/story_b.md" <<STORY_B
# Story B: arithmetic module

Create a new file named module_b.py in this directory. It must define a
function add(x, y) that returns x plus y. Add a module-level comment line
containing the exact token OH_NO_RALPH_EXECUTOR_B so the finished file is
identifiable. This story is independent of Story A: it shares no file with
Story A and does not depend on Story A.
STORY_B

  # CONTRACT-NOT-PROMPT-COMPLIANCE: an ORDINARY direct STANDARD Ralph run
  # over two disjoint stories. The prompt describes the two stories and asks Ralph
  # to run them and report. It does NOT instruct parallelism, batching, "dispatch
  # two executors", or background dispatch — the EDITED ralph contract loaded via
  # the plugin is what must drive proactive concurrent executor dispatch.
  local prompt
  prompt=$(cat <<PROMPT
Use ${PLUGIN_NAME}:ralph in STANDARD mode. Work entirely inside the current working directory; do not read, write, or touch anything outside it. Do not create helper files in /tmp, /var/tmp, your home directory, the plugin directory, or any absolute path outside the current working directory; if a helper file is needed, put it under .oh-no/ inside the current working directory. There are two stories to implement, described in story_a.md and story_b.md in this directory. Read both story files. This is a throwaway smoke-test fixture, so keep verification focused on the two story files and the files they require.

Direction Contract: requirements source is this approved smoke packet; primary goal is AC-OVERLAP-1, reuse Ralph existing verified disjoint eligibility decision to allow eligible executor overlap; non-goals are no new scheduler, state machine, protocol, Git oracle, duplicate fixture system, or concurrent fallback/commit/integration; constraints are one owner per file and serial integration; direction changes require explicit caller approval. Carry AC-OVERLAP-1 and these non-goals into the Ralph session, every executor/reviewer/verifier packet, and the final summary.
Direction Contract: each dispatched packet must preserve that same goal, non-goals, constraints, and approval boundary without reinterpretation.

Story A and Story B are independent of each other: they touch different files and neither depends on the other. Implement both stories so each described file is created exactly as its story specifies, then run them and report the result.

When you are completely finished and both files exist, emit a final summary that restates AC-OVERLAP-1 and the non-goals unchanged, then contains the exact token OH_NO_RALPH_POST_BATCH_CHECK followed by, for each implemented unit, the file it owns and the marker contained in that file, confirming each unit stayed within its own file. Then emit the exact final marker OH_NO_RALPH_PARALLEL_EXECUTOR_OK on its own line.
PROMPT
)

  # Containment snapshot BEFORE: any new/modified marketplace entry attributable
  # to the run is a hard failure (defense-in-depth, see below).
  local repo_status_before
  repo_status_before="$(git -C "$MARKETPLACE_ROOT" status --porcelain 2>/dev/null || true)"

  # Out-of-fixture sentinel snapshot (defense-in-depth): one probe captures
  # path+mtime+size of a few sensitive targets plus the fixture's parent dir
  # listing. The SAME probe is used for the BEFORE and AFTER captures so they can
  # never drift apart; any change after the run is a containment breach.
  _pexec_sentinel() {
    "$PYTHON_BIN" - "$1" <<'SENTINEL'
import json, os, sys
fixture_dir = sys.argv[1]
parent = os.path.dirname(os.path.realpath(fixture_dir))
home = os.path.expanduser("~")
targets = [
    os.path.join(home, ".ssh"),
    os.path.join(home, ".bashrc"),
    os.path.join(home, ".zshrc"),
]
manifest = {}
for t in targets:
    try:
        st = os.stat(t)
        manifest[t] = [st.st_mtime_ns, st.st_size]
    except OSError:
        manifest[t] = None
try:
    siblings = sorted(os.listdir(parent))
except OSError:
    siblings = []
manifest["__parent__"] = parent
manifest["__siblings__"] = siblings
print(json.dumps(manifest, sort_keys=True))
SENTINEL
  }
  local sentinel_before
  sentinel_before="$(_pexec_sentinel "$fixture_dir")"

  # Live-fidelity execution: use bypassPermissions so the scripted run can read
  # the installed/plugin-dir skill docs and run ordinary verification commands
  # the way a real live Ralph invocation would. Permission denials are hard
  # failures in the parser below; containment is enforced by the temp cwd plus
  # transcript path scans, marketplace git-status, and out-of-fixture sentinels.
  local cmd=(
    "$CLAUDE_BIN"
    --print
    --verbose
    --output-format stream-json
    --include-hook-events
    --model "$FUSION_RESCUE_LIVE_MODEL"
    --max-budget-usd "$FUSION_RESCUE_MAX_BUDGET_USD"
    --permission-mode bypassPermissions
    --tools default
    --no-session-persistence
    --system-prompt "You are a live smoke test runner for an Oh No Harness Ralph run. Implement only the two disjoint stories in the current working directory. Write only inside the current working directory. Do not edit, create, or delete any file outside it, including /tmp, /var/tmp, home directories, plugin directories, or absolute helper-file paths. Do not install plugins."
  )

  append_live_plugin_dir_arg

  # Run with fixture_dir as the WORKING DIRECTORY (do NOT inherit cwd=repo).
  # Capture the run exit code without tripping set -e so cleanup always runs.
  local run_rc=0
  if (
    cd "$fixture_dir"
    run_plugin_dir_live_process_with_timeout "${cmd[@]}" "$prompt"
  ) >"$out_file" 2>"$err_file"; then
    run_rc=0
  else
    run_rc=$?
    log "Claude parallel-executor live invocation exited non-zero (rc=$run_rc); proceeding to parser for diagnosis"
  fi

  # Containment snapshot AFTER.
  local repo_status_after
  repo_status_after="$(git -C "$MARKETPLACE_ROOT" status --porcelain 2>/dev/null || true)"

  local sentinel_after
  sentinel_after="$(_pexec_sentinel "$fixture_dir")"

  local parser_rc=0
  if OH_NO_PEXEC_STATUS_BEFORE="$repo_status_before" \
    OH_NO_PEXEC_STATUS_AFTER="$repo_status_after" \
    OH_NO_PEXEC_SENTINEL_BEFORE="$sentinel_before" \
    OH_NO_PEXEC_SENTINEL_AFTER="$sentinel_after" \
    "$PYTHON_BIN" - "$out_file" "$err_file" "$summary_file" "$FUSION_RESCUE_LIVE_MODEL" "$fixture_dir" "$MARKETPLACE_ROOT" <<'PY'
import json
import os
import re
import shlex
import sys
from collections import defaultdict
from pathlib import Path

out_path, err_path, summary_path, model, fixture_dir, marketplace_root = sys.argv[1:7]

# Containment baseline: any new/modified marketplace entry attributable to the
# run is a hard failure. The before/after porcelain snapshots are passed via env.
status_before = os.environ.get("OH_NO_PEXEC_STATUS_BEFORE", "")
status_after = os.environ.get("OH_NO_PEXEC_STATUS_AFTER", "")
# Out-of-fixture sentinel snapshots (defense-in-depth): sensitive targets plus
# the fixture parent dir listing, captured before/after the run.
sentinel_before = os.environ.get("OH_NO_PEXEC_SENTINEL_BEFORE", "")
sentinel_after = os.environ.get("OH_NO_PEXEC_SENTINEL_AFTER", "")

EXECUTOR_MARKERS = {
    "A": "OH_NO_RALPH_EXECUTOR_A",
    "B": "OH_NO_RALPH_EXECUTOR_B",
}
POST_BATCH_MARKER = "OH_NO_RALPH_POST_BATCH_CHECK"
FINAL_MARKER = "OH_NO_RALPH_PARALLEL_EXECUTOR_OK"
DIRECTION_MARKERS = (
    "AC-OVERLAP-1",
    "no new scheduler",
    "state machine",
    "protocol",
    "Git oracle",
    "serial integration",
)

secret_patterns = [
    re.compile(r"(?<![A-Za-z0-9])sk-[A-Za-z0-9_-]{20,512}(?![A-Za-z0-9_-])"),
    re.compile(r"(?i)(api[_-]?key|access[_-]?token|refresh[_-]?token|private[_-]?key|cookie)[ \t]*[:=][ \t]*['\"]?[A-Za-z0-9_./+=-]{12,}"),
]
write_tool_names = {"Edit", "Write", "NotebookEdit"}
fixture_real = os.path.realpath(fixture_dir)

def collect_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(item) for item in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(item) for item in value)
    return ""

def under_fixture(path):
    """Positive path-containment guard: True iff path resolves under fixture_dir."""
    if not path:
        return False
    candidate = str(path).strip().strip("\"'")
    candidate = os.path.expanduser(os.path.expandvars(candidate))
    if "$" in candidate:
        return False
    if not os.path.isabs(candidate):
        candidate = os.path.join(fixture_real, candidate)
    real = os.path.realpath(candidate)
    return real == fixture_real or real.startswith(fixture_real + os.sep)

# Bash commands that write somewhere. We only need to catch escapes OUTSIDE
# fixture_dir; a redirection/move/copy/remove target that does not resolve under
# the sandbox is treated as an escape.
WRITE_BASH_TOKENS = (">", ">>", "tee", "cp", "mv", "rm", "mkdir", "touch", "dd", "install", "sed -i", "ln")

# Standard non-persistent device targets are not containment escapes: writing to
# them discards output (or is a tty/fd), so a benign command like
# `command -v python 2>/dev/null` must not be flagged. This Bash scan is a
# defense-in-depth containment guard and must not false-positive on these.
DISCARD_WRITE_TARGETS = {"/dev/null", "/dev/stdout", "/dev/stderr", "/dev/tty", "/dev/zero"}

def clean_write_target(target):
    """Strip surrounding quotes and trailing shell metacharacters (e.g. the `;`
    fused onto `2>/dev/null;`) so containment matching sees the real path."""
    t = target.strip().strip("\"'")
    return t.rstrip(";|&)" + " \t")

def is_benign_write_target(target):
    t = clean_write_target(target)
    if not t or t in (">", ">>", "&>", "|"):
        return True
    return t in DISCARD_WRITE_TARGETS or t.startswith("/dev/fd/")

def bash_write_targets(command):
    """Best-effort extraction of write targets from a bash command string."""
    targets = []
    try:
        tokens = shlex.split(command, posix=True)
    except ValueError:
        tokens = command.split()
    # Redirection targets: token immediately following > or >> (or fused like >file).
    for i, tok in enumerate(tokens):
        if tok in (">", ">>", "1>", "2>", "&>", ">|") and i + 1 < len(tokens):
            targets.append(tokens[i + 1])
        else:
            m = re.match(r"^(?:[12]?>>?|&>)([^>].*)$", tok)
            if m and m.group(1):
                targets.append(m.group(1))
    # File-mutating commands: treat their non-flag path arguments as write targets.
    mutating = {"tee", "cp", "mv", "rm", "mkdir", "touch", "dd", "install", "ln"}
    if tokens:
        head = os.path.basename(tokens[0])
        if head in mutating:
            for tok in tokens[1:]:
                if tok.startswith("-"):
                    continue
                if "=" in tok and tok.split("=", 1)[0].isalpha():
                    continue
                targets.append(tok)
        if head == "sed" and "-i" in tokens:
            for tok in tokens[1:]:
                if tok.startswith("-"):
                    continue
                targets.append(tok)
    return targets

def command_writes(command):
    lowered = command.lower()
    return any(tok in lowered or tok in command for tok in WRITE_BASH_TOKENS)

INTERPRETER_WRITE_PATTERNS = (
    re.compile(r"\bopen\(\s*['\"][^'\"]+['\"]\s*,\s*['\"][^'\"]*[wax+][^'\"]*['\"]"),
    re.compile(r"\bopen\(\s*(?:os\.environ\[[^\]]+\]|[^,]+)\s*,\s*['\"][^'\"]*[wax+][^'\"]*['\"]"),
    re.compile(r"\bopen\(.*?\bmode\s*=\s*['\"][^'\"]*[wax+][^'\"]*['\"]", re.S),
    re.compile(r"(?:\b[A-Za-z_]\w*\(|\bpathlib\.Path\(|\.joinpath\().{0,300}\.(?:write_text|write_bytes|touch|mkdir|open)\s*\("),
    re.compile(r"\btempfile\."),
)
FORBIDDEN_ENV_OR_HOME_REF = re.compile(
    r"(?:\$HOME|\$\{HOME\}|\$TMPDIR|\$\{TMPDIR\}|~(?:/|$)|"
    r"os\.environ\s*\[\s*['\"](?:HOME|TMPDIR)['\"]\s*\]|"
    r"os\.environ\.get\(\s*['\"](?:HOME|TMPDIR)['\"]\s*\)|Path\.home\(\)|tempfile\.)"
)
RISKY_ABSOLUTE_PATH_RE = re.compile(
    r"(?<![\w@%+=:.-])/(?:tmp|var/tmp|var/folders|private/tmp|private/var/tmp|private/var/folders|Users|home|root|etc)(?:[^\s'\"`;<>()|&]*)"
)
EXECUTABLE_PATH_PREFIXES = (
    "/bin/",
    "/sbin/",
    "/usr/bin/",
    "/usr/sbin/",
    "/usr/local/bin/",
    "/opt/homebrew/bin/",
    "/System/",
    "/Library/",
)

def command_may_write(command):
    return command_writes(command) or any(pattern.search(command) for pattern in INTERPRETER_WRITE_PATTERNS)

def interpreter_write_targets(command):
    targets = []
    # open("path", "w") or open(os.environ["HOME"] + "/x", "w").
    for match in re.finditer(r"\bopen\(\s*(?P<expr>.+?)\s*,\s*['\"][^'\"]*[wax+][^'\"]*['\"]", command, flags=re.S):
        expr = match.group("expr").strip()
        literal = re.match(r"^['\"]([^'\"]+)['\"]$", expr)
        if literal:
            targets.append(literal.group(1))
        elif re.search(r"os\.environ\s*\[\s*['\"](?:HOME|TMPDIR)['\"]\s*\]|Path\.home\(\)|tempfile\.", expr):
            targets.append("__DYNAMIC_OUT_OF_FIXTURE__")
        else:
            targets.append("__AMBIGUOUS_INTERPRETER_WRITE_TARGET__")
    # open("path", mode="w"), open(file="path", mode="w"), and dynamic keyword forms.
    for match in re.finditer(r"\bopen\((?P<args>.*?\bmode\s*=\s*['\"][^'\"]*[wax+][^'\"]*['\"][^)]*)\)", command, flags=re.S):
        args = match.group("args")
        file_expr = None
        file_match = re.search(r"\bfile\s*=\s*(?P<expr>[^,]+)", args)
        if file_match:
            file_expr = file_match.group("expr").strip()
        else:
            first_arg = args.split(",", 1)[0].strip()
            if first_arg and not first_arg.startswith("mode"):
                file_expr = first_arg
        if not file_expr:
            targets.append("__AMBIGUOUS_INTERPRETER_WRITE_TARGET__")
            continue
        literal = re.match(r"^['\"]([^'\"]+)['\"]$", file_expr)
        if literal:
            targets.append(literal.group(1))
        elif re.search(
            r"os\.environ\s*\[\s*['\"](?:HOME|TMPDIR)['\"]\s*\]|"
            r"os\.environ\.get\(\s*['\"](?:HOME|TMPDIR)['\"]\s*\)|Path\.home\(\)|tempfile\.",
            file_expr,
        ):
            targets.append("__DYNAMIC_OUT_OF_FIXTURE__")
        else:
            targets.append("__AMBIGUOUS_INTERPRETER_WRITE_TARGET__")
    # Path("path").write_text(...), pathlib.Path("path").touch(), or aliased
    # Path constructors such as `from pathlib import Path as P; P("/tmp/x").write_text(...)`.
    for match in re.finditer(
        r"(?:\b[A-Za-z_]\w*|\bpathlib\.Path)\(\s*['\"](?P<path>[^'\"]+)['\"]\s*\)"
        r"(?:\.[A-Za-z_]\w*\([^)]*\))*\.(?:write_text|write_bytes|touch|mkdir|open)\s*\(",
        command,
        flags=re.S,
    ):
        targets.append(match.group("path"))
    return targets

def command_write_escape_reasons(command):
    if not command_may_write(command):
        return []

    reasons = []
    if FORBIDDEN_ENV_OR_HOME_REF.search(command):
        reasons.append("forbidden env/home path reference in write-capable command")

    explicit_targets = []

    for target in bash_write_targets(command):
        explicit_targets.append(target)
        if is_benign_write_target(target):
            continue
        cleaned = clean_write_target(target)
        if not under_fixture(cleaned):
            reasons.append(f"write target outside fixture: {cleaned!r}")

    for target in interpreter_write_targets(command):
        explicit_targets.append(target)
        if target == "__DYNAMIC_OUT_OF_FIXTURE__":
            reasons.append("dynamic interpreter write target resolves outside fixture")
            continue
        if target == "__AMBIGUOUS_INTERPRETER_WRITE_TARGET__":
            reasons.append("ambiguous interpreter write target cannot be proven under fixture")
            continue
        cleaned = clean_write_target(target)
        if not under_fixture(cleaned):
            reasons.append(f"interpreter write target outside fixture: {cleaned!r}")

    # Last-resort fallback for nested shell/interpreter commands where the write
    # intent is visible but no concrete target was extracted (for example
    # `bash -lc 'touch /tmp/x'`). Avoid using this when explicit write targets
    # were found, because absolute paths may be harmless string content written
    # into a fixture-local file.
    if explicit_targets:
        return reasons

    for raw_path in RISKY_ABSOLUTE_PATH_RE.findall(command):
        cleaned = clean_write_target(raw_path)
        if is_benign_write_target(cleaned):
            continue
        if cleaned.startswith(EXECUTABLE_PATH_PREFIXES):
            continue
        if not under_fixture(cleaned):
            reasons.append(f"absolute path in write-capable command outside fixture: {cleaned!r}")

    return reasons

errors = []
permission_denials = []
# (tool_use_index, marker_letter) for each distinct executor dispatch.
executor_dispatch_uses = defaultdict(list)
direction_packet_gaps = []
task_starts = []
task_notifications = []          # (index, status, summary)
first_task_notification_index = None
executor_completion_indexes = {}  # marker_letter -> completion index (best effort)
post_batch_indexes = []          # indexes of non-user text containing POST_BATCH_MARKER
final_marker_seen = False
final_marker_text = []
init_ok = False
saw_any_task_event = False
# Same-assistant-turn co-occurrence (CORROBORATION ONLY).
same_turn_cooccurrence = False

with open(err_path, "r", encoding="utf-8") as fh:
    err_text = fh.read()
if "unknown command" in err_text.lower() or "unknown agent" in err_text.lower():
    raise SystemExit(f"Claude parallel-executor live saw unavailable command/agent in stderr: {err_text[:2000]!r}")
# F4: the secret scan also covers stderr, not just the JSONL transcript.
if any(pattern.search(err_text) for pattern in secret_patterns):
    raise SystemExit("Claude parallel-executor live stderr exposed a secret-like value")

with open(out_path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        text = collect_text(data)
        if any(pattern.search(text) for pattern in secret_patterns):
            raise SystemExit(f"Claude parallel-executor live transcript exposed a secret-like value near line {index}")

        if data.get("type") == "system" and data.get("subtype") == "init":
            available_agents = set(data.get("agents", []))
            init_ok = "Task" in data.get("tools", []) and (
                "oh-no-harness:executor" in available_agents
            )

        if data.get("type") == "assistant":
            turn_markers = set()
            for part in data.get("message", {}).get("content", []):
                ptype = part.get("type")
                if ptype == "tool_use" and part.get("name") in write_tool_names:
                    payload = part.get("input", {})
                    target = payload.get("file_path") or payload.get("path") or payload.get("notebook_path") or ""
                    if not under_fixture(target):
                        raise SystemExit(
                            "Claude parallel-executor live wrote OUTSIDE the fixture sandbox via "
                            f"{part.get('name')!r}: target={target!r} fixture={fixture_real!r}"
                        )
                if ptype == "tool_use" and part.get("name") == "Bash":
                    command = str(part.get("input", {}).get("command", ""))
                    escape_reasons = command_write_escape_reasons(command)
                    if escape_reasons:
                        raise SystemExit(
                            "Claude parallel-executor live ran a write-capable Bash command with "
                            "out-of-fixture containment escapes: "
                            f"reasons={escape_reasons!r} command={command[:500]!r} fixture={fixture_real!r}"
                        )
                if ptype == "tool_use" and part.get("name") in {"Agent", "Task"}:
                    payload = part.get("input", {})
                    payload_text = collect_text(payload)
                    subagent_type = str(payload.get("subagent_type", ""))
                    # F5: only count dispatches whose subagent_type is the executor
                    # role. Two concurrent NON-executor subagents (e.g. explore) that
                    # merely quote a marker must not false-pass the disjoint-executor
                    # batch proof.
                    is_executor = "executor" in subagent_type.lower()
                    matched = [
                        letter for letter, marker in EXECUTOR_MARKERS.items()
                        if marker in payload_text
                    ]
                    if is_executor and len(matched) == 1:
                        executor_dispatch_uses[matched[0]].append(index)
                        turn_markers.add(matched[0])
                        missing_direction = [m for m in DIRECTION_MARKERS if m.lower() not in payload_text.lower()]
                        if missing_direction:
                            direction_packet_gaps.append((index, matched[0], missing_direction))
                if ptype == "text":
                    if FINAL_MARKER in part.get("text", ""):
                        final_marker_seen = True
                        final_marker_text.append(part.get("text", ""))
                    if POST_BATCH_MARKER in part.get("text", ""):
                        post_batch_indexes.append(index)
            # CORROBORATION ONLY: both executors dispatched in one assistant turn.
            if {"A", "B"}.issubset(turn_markers):
                same_turn_cooccurrence = True

        if data.get("type") == "system" and data.get("subtype") == "task_started":
            saw_any_task_event = True
            task_starts.append((index, data.get("task_id")))

        if data.get("type") == "system" and data.get("subtype") == "task_notification":
            saw_any_task_event = True
            if first_task_notification_index is None:
                first_task_notification_index = index
            status = data.get("status")
            summary = str(data.get("summary", ""))
            task_notifications.append((index, status, summary))
            if status == "completed":
                for letter, marker in EXECUTOR_MARKERS.items():
                    if marker in summary and letter not in executor_completion_indexes:
                        executor_completion_indexes[letter] = index

        if data.get("type") == "result":
            permission_denials.extend(data.get("permission_denials") or [])
            result_text = str(data.get("result", ""))
            if FINAL_MARKER in result_text:
                final_marker_seen = True
            if POST_BATCH_MARKER in result_text:
                post_batch_indexes.append(index)
            if data.get("is_error") is True:
                errors.append((index, result_text[:1000]))

if not init_ok:
    raise SystemExit("Claude parallel-executor live did not expose Task tool and the oh-no-harness:executor role")
if errors:
    raise SystemExit(f"Claude parallel-executor live returned errors: {errors!r}")
if permission_denials:
    raise SystemExit(f"Claude parallel-executor live had permission denials: {permission_denials!r}")

# CONTAINMENT: no new/modified marketplace entry attributable to the run.
def porcelain_set(text):
    return {line for line in text.splitlines() if line.strip()}

new_entries = sorted(porcelain_set(status_after) - porcelain_set(status_before))
if new_entries:
    raise SystemExit(
        "Claude parallel-executor live mutated the marketplace working tree (containment breach): "
        f"{new_entries!r}"
    )

# CONTAINMENT (defense-in-depth): out-of-fixture sentinel must be unchanged and
# no new file may appear next to the fixture sandbox.
if sentinel_before or sentinel_after:
    try:
        before_manifest = json.loads(sentinel_before) if sentinel_before else {}
        after_manifest = json.loads(sentinel_after) if sentinel_after else {}
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Claude parallel-executor live could not parse the containment sentinel: {exc}")
    changed = sorted(
        key for key in set(before_manifest) | set(after_manifest)
        if key not in ("__parent__", "__siblings__")
        and before_manifest.get(key) != after_manifest.get(key)
    )
    if changed:
        raise SystemExit(
            "Claude parallel-executor live changed a sensitive out-of-fixture target "
            f"(containment breach): {changed!r}"
        )
    before_siblings = set(before_manifest.get("__siblings__", []))
    after_siblings = set(after_manifest.get("__siblings__", []))
    new_siblings = sorted(after_siblings - before_siblings)
    if new_siblings:
        raise SystemExit(
            "Claude parallel-executor live created a new file next to the fixture sandbox "
            f"(containment breach): {new_siblings!r} parent={after_manifest.get('__parent__')!r}"
        )

# CONCURRENCY PROOF (mirror run_parallel_live_test; NOT the foreground lane).
# Both executors must be dispatched exactly once, identified by unique markers.
missing_executors = sorted(set(EXECUTOR_MARKERS) - set(executor_dispatch_uses))
if missing_executors:
    raise SystemExit(
        "INCONCLUSIVE: Ralph did not dispatch both disjoint executors (single-executor or inline run is a FAIL); "
        f"missing={missing_executors!r} got={ {k: len(v) for k, v in executor_dispatch_uses.items()} !r}"
    )
duplicate_executors = {
    letter: idxs for letter, idxs in executor_dispatch_uses.items() if len(idxs) != 1
}
if duplicate_executors:
    raise SystemExit(
        "Claude parallel-executor live expected exactly one dispatch per disjoint executor; "
        f"duplicates={duplicate_executors!r}"
    )

dispatch_index_a = executor_dispatch_uses["A"][0]
dispatch_index_b = executor_dispatch_uses["B"][0]

# PRIMARY proof: both executor dispatch tool_use indices occur BEFORE the first
# task completion notification. No task_notification to order against => the run
# never produced an observable concurrent batch => INCONCLUSIVE (FAIL).
if not saw_any_task_event:
    raise SystemExit(
        "INCONCLUSIVE: no task_started/task_notification events in the stream, so a concurrent "
        "executor batch was not observable (an inline/sequential run is a FAIL, never a soft pass)"
    )
if first_task_notification_index is None:
    raise SystemExit(
        "INCONCLUSIVE: no task_notification event to order executor dispatches against; cannot prove a "
        "concurrent batch (sequential/inline run is a FAIL)"
    )

both_before_first_notification = (
    dispatch_index_a < first_task_notification_index
    and dispatch_index_b < first_task_notification_index
)
if not both_before_first_notification:
    # Sequential dispatch: the second executor was dispatched only after the first
    # completed. That is the explicit FAIL case, not a soft pass.
    raise SystemExit(
        "INCONCLUSIVE: disjoint-executor dispatches were not both started before the first task completion "
        "notification (sequential dispatch is a FAIL, never a concurrent batch); "
        f"dispatch_a={dispatch_index_a} dispatch_b={dispatch_index_b} "
        f"first_task_notification_index={first_task_notification_index}"
    )

# F6: corroborator - at least two background tasks must have actually started, so
# the two executor dispatches map to two real concurrent task lifecycles.
if len(task_starts) < 2:
    raise SystemExit(
        "INCONCLUSIVE: fewer than two task_started events for a two-executor batch "
        f"(no observable concurrent lifecycle); task_starts={task_starts!r}"
    )

# Post-batch per-executor scope check must appear AFTER both executor completions.
# Prefer completion notifications; if the host did not tag summaries with the
# markers, fall back to the last task completion notification index.
completed_notification_indexes = [idx for idx, status, _ in task_notifications if status == "completed"]
if len(completed_notification_indexes) >= 2:
    both_completions_index = sorted(completed_notification_indexes)[1]
elif executor_completion_indexes and len(executor_completion_indexes) == 2:
    both_completions_index = max(executor_completion_indexes.values())
else:
    both_completions_index = None

if direction_packet_gaps:
    raise SystemExit(
        "Claude parallel-executor live failed Direction Contract carry-forward "
        f"into executor packets: {direction_packet_gaps!r}"
    )

if both_completions_index is None:
    raise SystemExit(
        "INCONCLUSIVE: could not observe both disjoint-executor completions to anchor "
        "the post-batch scope check (completion-observation gaps are hard failures for "
        "this lane); "
        f"completed_notifications={completed_notification_indexes!r} "
        f"executor_completion_indexes={executor_completion_indexes!r}"
    )

post_batch_after_completions = [idx for idx in post_batch_indexes if idx > both_completions_index]
if len(post_batch_after_completions) < 1:
    raise SystemExit(
        "Claude parallel-executor live did not emit the post-batch per-executor scope-check marker "
        f"OH_NO_RALPH_POST_BATCH_CHECK after both executor completions; post_batch_indexes={post_batch_indexes!r} "
        f"both_completions_index={both_completions_index}"
    )

if not final_marker_seen:
    raise SystemExit(
        "Claude parallel-executor live did not return the final marker OH_NO_RALPH_PARALLEL_EXECUTOR_OK"
    )

final_evidence = "\n".join(final_marker_text)
missing_final_direction = [m for m in DIRECTION_MARKERS if m.lower() not in final_evidence.lower()]
if missing_final_direction:
    raise SystemExit(
        "Claude parallel-executor live final evidence dropped Direction Contract markers: "
        f"{missing_final_direction!r}"
    )

summary = {
    "status": "passed",
    "model": model,
    "fixture_dir": fixture_real,
    "executors": {
        "A": {"marker": EXECUTOR_MARKERS["A"], "dispatch_index": dispatch_index_a},
        "B": {"marker": EXECUTOR_MARKERS["B"], "dispatch_index": dispatch_index_b},
    },
    "first_task_notification_index": first_task_notification_index,
    "both_dispatched_before_first_notification": both_before_first_notification,
    "same_turn_cooccurrence_corroboration": same_turn_cooccurrence,
    "task_started_count": len(task_starts),
    "both_completions_index": both_completions_index,
    "post_batch_check_after_completions": len(post_batch_after_completions),
    "post_batch_marker": POST_BATCH_MARKER,
    "final_marker": FINAL_MARKER,
    "permission_mode": "bypassPermissions",
    "marketplace_containment": "clean",
    "out_of_fixture_sentinel": "clean",
}
Path(summary_path).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print("ok - live Claude Ralph proactively dispatched a concurrent disjoint-executor batch with a post-batch per-executor scope check")
PY
  then
    parser_rc=0
  else
    parser_rc=$?
  fi

  # Always clean up the fixture sandbox, then surface the parser verdict. The
  # RETURN/EXIT/INT/TERM trap is the backstop; this explicit call clears it on the
  # normal path so a later EXIT does not double-run.
  _parallel_executor_cleanup
  trap - RETURN EXIT INT TERM

	  if [[ "$parser_rc" != "0" ]]; then
	    return "$parser_rc"
	  fi
	  if [[ "$run_rc" != "0" ]]; then
	    log "Claude parallel-executor live command invocation failed despite parser-accepted transcript (rc=$run_rc)"
	    return "$run_rc"
	  fi
	}

run_simplify_live_test() {
  if [[ "$RUN_SIMPLIFY_LIVE" != "1" ]]; then
    log "Skipping live Claude simplify cleanup-subagent smoke test"
    printf 'Run with --simplify-live or OH_NO_SIMPLIFY_LIVE=1 to verify actual Claude simplify cleanup subagents.\n' >&2
    return
  fi

  log "Running live Claude simplify cleanup-subagent smoke test (${LIVE_LOAD_MODE})"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/simplify-cleanup-subagents.jsonl"
  local err_file="$RUN_DIR/simplify-cleanup-subagents.err"
  local prompt
  prompt="Use /${PLUGIN_NAME}:simplify --review. Read-only dispatch instrumentation test only: do not edit files, do not create artifacts, do not apply cleanup fixes, and do not run Phase 2. Verify Phase 1 dispatch only. Do not inspect repository files, do not run Bash or Read, and do not start helper workers beyond the four cleanup angle workers. Use this synthetic one-line diff for every worker: plugins/oh-no-harness/docs/skill-core/simplify.md: Phase 1 dispatch contract changed for smoke verification. Use Claude Workflow with Promise.all and exactly four agent() calls when Workflow is available; otherwise use Claude background Task or Agent workers exactly four times, but request all four before inspecting or summarizing any task result. The four cleanup subagent angles must be exactly Reuse, Simplification, Efficiency, and Altitude. Each task or agent prompt MUST include exactly one line of the form Angle: <angle>, one matching marker line, plus these literal lines: Scope: synthetic dispatch diff; Do not edit files; Do not create artifacts; Do not apply cleanup fixes; Do not run Phase 2; Expected output: matching marker plus Angle, File, Line, Summary, Concrete cost fields. Marker lines by angle: Reuse uses Marker: OH_NO_SIMPLIFY_REUSE_READONLY; Simplification uses Marker: OH_NO_SIMPLIFY_SIMPLIFICATION_READONLY; Efficiency uses Marker: OH_NO_SIMPLIFY_EFFICIENCY_READONLY; Altitude uses Marker: OH_NO_SIMPLIFY_ALTITUDE_READONLY. Each cleanup subagent must return its matching OH_NO_SIMPLIFY_* marker and labeled Angle, File, Line, Summary, and Concrete cost fields. A Workflow must return all four raw child results so the event stream carries per-angle completion evidence. After each cleanup subagent result is captured, close or clean up that completed subagent when the host exposes that mechanism; if no explicit close or cleanup mechanism exists, record that fallback. Preserve every matching angle marker in the parent response. After all four cleanup subagents finish, reply exactly OH_NO_CLAUDE_SIMPLIFY_SUBAGENTS_OK and summarize Review angles: Reuse, Simplification, Efficiency, Altitude; Launched before waiting: yes; lifecycle close or cleanup status."
  prompt="Named THOROUGH broad-diff cleanup trigger. ${prompt}"

  local cmd=(
    "$CLAUDE_BIN"
    --print
    --verbose
    --output-format stream-json
    --include-hook-events
    --model "$LIVE_MODEL"
    --max-budget-usd "$LIVE_MAX_BUDGET_USD"
    # Subagent smoke tests are non-interactive; dontAsk can auto-deny Workflow.
    --permission-mode bypassPermissions
    --tools default
    --no-session-persistence
    --system-prompt "You are a read-only live smoke test runner. You may use background subagents only for the requested simplify verification. Do not edit files."
  )

  append_live_plugin_dir_arg

  run_plugin_dir_live_process_with_timeout "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

  "$PYTHON_BIN" - "$out_file" <<'PY'
import json
import re
import sys
from collections import defaultdict

path = sys.argv[1]
expected_angles = ["Reuse", "Simplification", "Efficiency", "Altitude"]
required_payload_markers = [
    "Scope: synthetic dispatch diff",
    "Do not edit files",
    "Do not create artifacts",
    "Do not apply cleanup fixes",
    "Do not run Phase 2",
    "Expected output: matching marker plus Angle, File, Line, Summary, Concrete cost fields",
]
angle_markers = {
    "Reuse": "OH_NO_SIMPLIFY_REUSE_READONLY",
    "Simplification": "OH_NO_SIMPLIFY_SIMPLIFICATION_READONLY",
    "Efficiency": "OH_NO_SIMPLIFY_EFFICIENCY_READONLY",
    "Altitude": "OH_NO_SIMPLIFY_ALTITUDE_READONLY",
}

def collect_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(item) for item in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(item) for item in value)
    return ""

def angles_in_payload(text):
    matches = []
    for angle in expected_angles:
        if re.search(rf"(?im)^\s*Angle:\s*{re.escape(angle)}\s*$", text):
            matches.append(angle)
    return matches

init_ok = False
task_tool_uses = []
tasks_by_angle = defaultdict(list)
task_angle_by_tool_use_id = {}
task_angle_by_id = {}
completed_angles = set()
result_texts_by_angle = defaultdict(list)
bad_background_payloads = []
unexpected_task_uses = []
task_starts = []
first_task_notification_index = None
workflow_tool_ids = set()
workflow_scripts = []
workflow_completed = False
workflow_result_texts = []
summary_text = []
result_aware_text_indexes = []
marker = False
errors = []

with open(path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        if "OH_NO_CLAUDE_SIMPLIFY_SUBAGENTS_OK" in collect_text(data):
            marker = True
        if data.get("type") == "system" and data.get("subtype") == "init":
            tools = set(data.get("tools", []))
            init_ok = bool({"Task", "Agent", "Workflow"} & tools)
        if data.get("type") == "assistant":
            for part in data.get("message", {}).get("content", []):
                if part.get("type") == "tool_use" and part.get("name") in {"Agent", "Task"}:
                    payload = part.get("input", {})
                    payload_text = collect_text(payload)
                    matched_angles = angles_in_payload(payload_text)
                    if len(matched_angles) == 1:
                        if payload.get("run_in_background") is not True:
                            bad_background_payloads.append((index, payload_text[:1000]))
                        angle = matched_angles[0]
                        task_tool_uses.append((index, angle, payload))
                        tasks_by_angle[angle].append((index, payload_text))
                        tool_use_id = part.get("id")
                        if tool_use_id:
                            task_angle_by_tool_use_id[tool_use_id] = angle
                    elif "Angle:" in payload_text:
                        raise SystemExit(
                            "expected each Claude simplify task prompt to contain exactly one Angle line; "
                            f"line={index} angles={matched_angles!r} payload={payload_text[:2000]!r}"
                        )
                    else:
                        unexpected_task_uses.append((index, part.get("name"), payload_text[:1000]))
                if part.get("type") == "tool_use" and part.get("name") == "Workflow":
                    workflow_tool_ids.add(part.get("id"))
                    script = collect_text(part.get("input", {}).get("script", ""))
                    if script:
                        workflow_scripts.append((index, script))
                if part.get("type") == "text":
                    text = part.get("text", "")
                    summary_text.append(text)
                    if any(token in text.lower() for token in ("reported", "waiting", "results captured")):
                        result_aware_text_indexes.append(index)
        if data.get("type") == "user":
            for part in data.get("message", {}).get("content", []):
                if not isinstance(part, dict) or part.get("type") != "tool_result":
                    continue
                tool_use_id = part.get("tool_use_id")
                result_text = collect_text(part.get("content", ""))
                if tool_use_id in workflow_tool_ids and result_text:
                    workflow_result_texts.append(result_text)
                angle = task_angle_by_tool_use_id.get(tool_use_id)
                if angle and result_text:
                    completed_angles.add(angle)
                    result_texts_by_angle[angle].append(result_text)
        if data.get("type") == "system" and data.get("subtype") == "task_started":
            task_id = data.get("task_id")
            tool_use_id = data.get("tool_use_id")
            task_starts.append((index, task_id))
            angle = task_angle_by_tool_use_id.get(tool_use_id)
            if task_id and angle:
                task_angle_by_id[task_id] = angle
        if data.get("type") == "system" and data.get("subtype") in {"task_notification", "task_updated"}:
            if first_task_notification_index is None:
                first_task_notification_index = index
            result_text = collect_text(
                data.get("summary") or data.get("result") or data.get("output") or ""
            )
            if data.get("status") == "completed":
                tool_use_id = data.get("tool_use_id")
                if (
                    tool_use_id in workflow_tool_ids
                    or "workflow" in str(data.get("summary", "")).lower()
                ):
                    workflow_completed = True
                    if result_text:
                        workflow_result_texts.append(result_text)
                angle = (
                    task_angle_by_tool_use_id.get(tool_use_id)
                    or task_angle_by_id.get(data.get("task_id"))
                )
                if not angle and result_text:
                    result_angles = [
                        name for name, marker_value in angle_markers.items()
                        if marker_value in result_text
                    ]
                    if len(result_angles) == 1:
                        angle = result_angles[0]
                if angle:
                    completed_angles.add(angle)
                    if result_text:
                        result_texts_by_angle[angle].append(result_text)
        if data.get("type") == "result" and data.get("is_error") is True:
            errors.append((index, str(data.get("result", ""))[:1000]))
        if data.get("type") == "result":
            text = str(data.get("result", ""))
            summary_text.append(text)
            if any(token in text.lower() for token in ("reported", "waiting", "results captured")):
                result_aware_text_indexes.append(index)

if not init_ok:
    raise SystemExit("Claude simplify cleanup smoke did not expose Task, Agent, or Workflow tooling")
if errors:
    raise SystemExit(f"Claude simplify cleanup smoke returned errors: {errors!r}")
if bad_background_payloads:
    raise SystemExit(
        "Claude simplify cleanup task prompts were not marked as background tasks: "
        f"{bad_background_payloads!r}"
    )
if unexpected_task_uses:
    raise SystemExit(
        "Claude simplify cleanup smoke started unexpected helper Task/Agent workers: "
        f"{unexpected_task_uses!r}"
    )

if not task_tool_uses and workflow_scripts:
    workflow_script = "\n".join(script for _, script in workflow_scripts)
    workflow_script_lower = workflow_script.lower()
    missing_angles = [
        angle for angle in expected_angles
        if angle.lower() not in workflow_script_lower
    ]
    missing_markers = [
        marker for marker in ["Angle:", *angle_markers.values(), *required_payload_markers]
        if marker.lower() not in workflow_script_lower
    ]
    agent_calls = re.findall(r"\bagent\s*\(", workflow_script)
    has_static_agent_batch = len(agent_calls) >= len(expected_angles)
    has_dynamic_angle_batch = (
        re.search(r"\bparallel\s*\(\s*\w+\.map\s*\(", workflow_script) is not None
        and len(agent_calls) >= 1
    )
    has_parallel_batch = (
        "promise.all" in workflow_script_lower
        or re.search(r"\bparallel\s*\(", workflow_script) is not None
    )
    if missing_angles or missing_markers:
        raise SystemExit(
            "Claude simplify Workflow script did not include required cleanup angle prompt markers: "
            f"missing_angles={missing_angles!r} missing_markers={missing_markers!r}"
        )
    if not has_parallel_batch or not (has_static_agent_batch or has_dynamic_angle_batch):
        raise SystemExit("Claude simplify Workflow did not prove four batched parallel agent() calls")
    if re.search(r"\bawait\s+agent\s*\(", workflow_script):
        raise SystemExit("Claude simplify Workflow used serial await agent() instead of a Promise.all batch")
    if not workflow_completed:
        raise SystemExit("Claude simplify Workflow task did not report completion")
    workflow_result_text = "\n".join(workflow_result_texts)
    if not workflow_result_text.strip():
        raise SystemExit("Claude simplify Workflow completed without exposing its child-result payload")
    missing_result_markers = [
        marker_value for marker_value in angle_markers.values()
        if marker_value not in workflow_result_text
    ]
    if missing_result_markers:
        raise SystemExit(
            "Claude simplify Workflow result omitted per-angle child markers: "
            f"{missing_result_markers!r}"
        )
    missing_result_fields = [
        field for field in ("Angle", "File", "Line", "Summary", "Concrete cost")
        if len(re.findall(rf"(?im)^\s*{re.escape(field)}\s*:", workflow_result_text)) < len(expected_angles)
    ]
    if missing_result_fields:
        raise SystemExit(
            "Claude simplify Workflow result omitted labeled fields from one or more child results: "
            f"{missing_result_fields!r}"
        )
    if not marker:
        raise SystemExit("Claude simplify cleanup smoke did not return success marker")
    combined_summary_text = "\n".join(summary_text)
    missing_summary_markers = [
        marker_value for marker_value in angle_markers.values()
        if marker_value not in combined_summary_text
    ]
    if missing_summary_markers:
        raise SystemExit(
            "Claude simplify Workflow parent response did not preserve every child marker: "
            f"{missing_summary_markers!r}"
        )
    print("ok - live Claude simplify cleanup subagents spawned in one Workflow batch")
    sys.exit(0)

if len(task_tool_uses) != len(expected_angles):
    raise SystemExit(
        f"expected exactly {len(expected_angles)} Claude simplify task uses, "
        f"got {len(task_tool_uses)}: {task_tool_uses!r}"
    )
missing_angles = [angle for angle in expected_angles if angle not in tasks_by_angle]
duplicate_angles = {
    angle: payloads for angle, payloads in tasks_by_angle.items()
    if len(payloads) != 1
}
if missing_angles or duplicate_angles:
    raise SystemExit(
        "Claude simplify cleanup angles did not match the required set: "
        f"missing={missing_angles!r} duplicates={duplicate_angles!r}"
    )
if len(task_starts) < len(expected_angles):
    raise SystemExit(f"expected at least {len(expected_angles)} task_started events, got {task_starts!r}")
missing_completed_angles = [angle for angle in expected_angles if angle not in completed_angles]
if missing_completed_angles:
    raise SystemExit(
        "Claude simplify cleanup smoke lacked completed result evidence for angles: "
        f"{missing_completed_angles!r}"
    )
for angle in expected_angles:
    result_text = "\n".join(result_texts_by_angle[angle])
    if angle_markers[angle] not in result_text:
        raise SystemExit(
            f"Claude simplify cleanup result for {angle} omitted marker {angle_markers[angle]!r}"
        )
    missing_fields = [
        field for field in ("Angle", "File", "Line", "Summary", "Concrete cost")
        if not re.search(rf"(?im)^\s*{re.escape(field)}\s*:", result_text)
    ]
    if missing_fields:
        raise SystemExit(
            f"Claude simplify cleanup result for {angle} omitted labeled fields: {missing_fields!r}"
        )
if first_task_notification_index is not None:
    angles_before_first_result_text = {
        angle for index, angle, _ in task_tool_uses
        if not any(first_task_notification_index < text_index < index for text_index in result_aware_text_indexes)
    }
    if set(expected_angles) != angles_before_first_result_text:
        raise SystemExit(
            "Claude simplify cleanup tasks were not fully requested before result-aware summary text; "
            f"expected={expected_angles!r} got={sorted(angles_before_first_result_text)!r}"
        )
for angle, payloads in tasks_by_angle.items():
    _, payload = payloads[0]
    missing_payload_markers = [
        marker for marker in [f"Angle: {angle}", f"Marker: {angle_markers[angle]}", *required_payload_markers]
        if marker.lower() not in payload.lower()
    ]
    if missing_payload_markers:
        raise SystemExit(
            f"Claude simplify task prompt for {angle} missed required markers: "
            f"{missing_payload_markers}; payload={payload[:2000]!r}"
        )
if not marker:
    raise SystemExit("Claude simplify cleanup smoke did not return success marker")
combined_summary_text = "\n".join(summary_text)
missing_summary_markers = [
    marker_value for marker_value in angle_markers.values()
    if marker_value not in combined_summary_text
]
if missing_summary_markers:
    raise SystemExit(
        "Claude simplify cleanup parent response did not preserve every child marker: "
        f"{missing_summary_markers!r}"
    )

print("ok - live Claude simplify cleanup subagents spawned in one batch")
PY
}
run_configure_subagents_offline_test() {
  log "Running offline configure-subagents behavior + contract test suite"
  bash "$MARKETPLACE_ROOT/scripts/test-configure-subagents.sh" || fail "configure-subagents offline test suite failed"
  local fixture config prefs role
  fixture="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-claude-hook-cap.XXXXXX")"; fixture="$(cd "$fixture" && pwd -P)"
  cp -R "$PLUGIN_ROOT" "$fixture/plugin"; config="$fixture/config"; prefs="$config/subagent-models.conf"; mkdir -p "$config"
  {
    printf '%s\n' 'schema_version=2' 'proxy=yes' 'secondary_top_model=haiku' 'top_tier_models=fable opus sonnet haiku gpt-5.6-sol gpt-5.6-terra'
    for role in explore analyst planner plan-reviewer executor debugger verifier code-reviewer fusion-rescue-analyst; do printf 'assignment=%s,gpt-5.6-terra,max\n' "$role"; done
  } >"$prefs"
  CLAUDE_PLUGIN_ROOT="$fixture/plugin" OH_NO_CONFIG_DIR="$config" "$fixture/plugin/hooks/run-hook.cmd" session-start >"$fixture/reapply.json"
  CLAUDE_PLUGIN_ROOT="$fixture/plugin" OH_NO_CONFIG_DIR="$config" "$fixture/plugin/hooks/run-hook.cmd" session-start >"$fixture/matching.json"
  rm "$fixture/plugin/agents/explore.md"; CLAUDE_PLUGIN_ROOT="$fixture/plugin" OH_NO_CONFIG_DIR="$config" "$fixture/plugin/hooks/run-hook.cmd" session-start >"$fixture/failure.json"
  "$PYTHON_BIN" - "$fixture/matching.json" "$fixture/reapply.json" "$fixture/failure.json" <<'PY'
import json, sys
from pathlib import Path
for label, path, notice in zip(("matching-max", "reapply-max", "failure-max"), sys.argv[1:], (None, "reapplied your saved", "could not reapply")):
    text = json.dumps(json.loads(Path(path).read_text(encoding="utf-8")))
    if len(text) > 6600 or (notice and notice not in text): raise SystemExit(f"Claude SessionStart {label} cap/notice failure: {len(text)}, {notice}")
    missing = [m for m in ("No-route lane", "Direct-edit lane", "Child packet floor", "target role", "withholds maker conclusions", "secondary_top_model=haiku") if m not in text]; forbidden = [m for m in ("Global Context Capsule", "Capsule delta", "_global-context-capsule.md", "Purpose\\nAssigned outcome / acceptance criteria") if m in text]
    if missing or forbidden or text.count("Child packet floor:") != 1: raise SystemExit(f"Claude SessionStart {label} child-packet/routing drift: missing={missing}, forbidden={forbidden}")
print("ok - maximum configured matching, reapply, and failure SessionStart branches stay within 6600")
PY
  rm -rf "$fixture"
}
run_script_resolver_offline_test() {
  log "Running offline bundled-script resolver behavior + contract test suite"
  bash "$MARKETPLACE_ROOT/scripts/test-script-resolver.sh" \
    || fail "bundled-script resolver offline test suite failed"
}
# Deterministic safety regressions use fake CLIs/configs only: no real Claude,
# user config, marketplace registration, or live model is touched.
run_live_plugin_root_offline_test() {
  log "Running offline live-only plugin-root regression"
  local temp_root canonical live malformed missing fake launch rc role skill source driver main_source canonical_arg live_read live_add live_copy case_spec root args
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-live-root-test.XXXXXX")"; canonical="$temp_root/canonical"; live="$temp_root/live"; malformed="$temp_root/malformed"; missing="$temp_root/missing"; fake="$temp_root/fake-claude"; launch="$temp_root/launched"
  mkdir -p "$canonical" "$live/.claude-plugin" "$live/agents" "$live/skills-claude" "$live/hooks" "$live/scripts" "$malformed"; printf 'canonical\n' >"$canonical/marker"; printf 'live\n' >"$live/marker"; printf '{"name":"%s","skills":[]}\n' "$PLUGIN_NAME" >"$live/.claude-plugin/plugin.json"; printf '{"hooks":{"SessionStart":[{}]}}\n' >"$live/hooks/hooks.json"
  for role in "${AGENTS[@]}"; do printf '%s\n' "$role" >"$live/agents/$role.md"; done
  for skill in "${PUBLIC_SKILLS[@]}"; do mkdir -p "$live/skills-claude/$skill"; printf '%s\n' "$skill" >"$live/skills-claude/$skill/SKILL.md"; done
  for source in hooks/session-start hooks/run-hook.cmd scripts/oh-no-config scripts/configure-subagents; do printf '#!/bin/sh\n' >"$live/$source"; chmod +x "$live/$source"; done
  cat >"$fake" <<'SH'
#!/bin/sh
printf 'launched\n' >"$FAKE_LAUNCH_LOG"
SH
  chmod +x "$fake"
  [[ -n "${LIVE_PLUGIN_ROOT:-}" ]] || { rm -rf "$temp_root"; fail "driver has no independent live plugin root"; }
  ( PLUGIN_ROOT="$canonical"; LIVE_PLUGIN_ROOT="$live"; LIVE_PLUGIN_ROOT_OVERRIDDEN=1; INSTALL_MODE=0; validate_live_plugin_root; cmd=(); LIVE_LOAD_MODE=plugin-dir; append_live_plugin_dir_arg; [[ "${cmd[*]}" == "--plugin-dir $live" && "$(<"${cmd[1]}/marker")" == live ]] ) || { rm -rf "$temp_root"; fail "live argv did not select the disposable plugin root"; }
  ( PLUGIN_ROOT="$canonical"; LIVE_PLUGIN_ROOT="$canonical"; LIVE_PLUGIN_ROOT_OVERRIDDEN=0; INSTALL_MODE=1; validate_live_plugin_root; cmd=(); LIVE_LOAD_MODE=plugin-dir; append_live_plugin_dir_arg; [[ "${cmd[*]}" == "--plugin-dir $canonical" ]] ) || { rm -rf "$temp_root"; fail "unset live-root override changed default plugin-dir behavior"; }
  driver="$REPO_ROOT/scripts/test-claude-plugin.sh"; source="$driver"; main_source="$(declare -f main)"
  [[ "$(grep -Ec '^[[:space:]]*append_live_plugin_dir_arg$' "$source")" == 11 && "$main_source" == *"validate_live_plugin_root"* ]] || { rm -rf "$temp_root"; fail "one or more model-bearing live call sites bypass the live-root selector"; }
  canonical_arg='--plugin-dir "$PLUGIN''_ROOT"'; live_read='local read_root="$LIVE''_PLUGIN_ROOT"'; live_add='--add-dir "$LIVE''_PLUGIN_ROOT/skills-claude/$expected_route"'; live_copy='cp -Rp "$LIVE''_PLUGIN_ROOT/." "$isolated_plugin_root/"'
  ! grep -Fq -- "$canonical_arg" "$source" && grep -Fq "$live_read" "$source" && grep -Fq -- "$live_add" "$source" && grep -Fq "$live_copy" "$source" || { rm -rf "$temp_root"; fail "canonical plugin root leaked into live plugin-dir/add-dir/model-diversity routing"; }
  declare -f validate_manifests | grep -Fq 'PLUGIN_ROOT' && ! declare -f validate_manifests | grep -Fq 'LIVE_PLUGIN_ROOT' || { rm -rf "$temp_root"; fail "source validation was rebound from the canonical plugin root"; }
  for case_spec in relative "$missing" "$malformed" "$live:install"; do
    rm -f "$launch"; rc=0; root="${case_spec%:install}"; args=(--isolated-config --no-install --live-hook-only); [[ "$case_spec" == *:install ]] && args=(--isolated-config --live-hook-only)
    ( OH_NO_LIVE_PLUGIN_ROOT="$root" CLAUDE_BIN="$fake" FAKE_LAUNCH_LOG="$launch" "$driver" "${args[@]}" ) >/dev/null 2>&1 || rc=$?
    [[ "$rc" == 1 && ! -e "$launch" ]] || { rm -rf "$temp_root"; fail "invalid/install-mode live-root case launched an executable: $case_spec"; }
  done
  rm -rf "$temp_root"
  ok "live-only plugin root: canonical validation, all live argv, defaults, shape, and install guard verified"
}

run_claude_state_isolation_offline_test() (
  log "Running offline Claude process state-isolation canary"
  local temp_root synthetic_home home_state fake records rejected_records rejected_config driver canonical_plugin canonical_marketplace live_plugin interview_prompt prompt actual_before home_before success_config failure_config cleanup_cmd rc
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-claude-state-canary.XXXXXX")"; printf -v cleanup_cmd 'rm -rf -- %q' "$temp_root"; trap "$cleanup_cmd" EXIT
  synthetic_home="$temp_root/home"; home_state="$synthetic_home/.claude.json"; mkdir -p "$synthetic_home"; printf 'synthetic home sentinel\n' >"$home_state"
  actual_before="$(file_identity "$HOME/.claude.json")"; home_before="$(file_identity "$home_state")"
  fake="$temp_root/fake-claude.py"; records="$temp_root/records.jsonl"; rejected_records="$temp_root/rejected.jsonl"; rejected_config="$temp_root/rejected-config"; driver="$REPO_ROOT/scripts/test-claude-plugin.sh"
  canonical_plugin="$PLUGIN_ROOT"; canonical_marketplace="$MARKETPLACE_ROOT"; live_plugin="$LIVE_PLUGIN_ROOT"; interview_prompt="$(live_prompt_for_skill interview)"; interview_prompt="$interview_prompt Ground your reply in the skill document the command tells you to read; if you cannot read it, say so instead of answering from memory."
  cat >"$fake" <<'PY'
#!/usr/bin/env python3
import json, os, sys; from pathlib import Path
argv = sys.argv[1:]; home, config = os.environ.get("HOME", ""), os.environ.get("CLAUDE_CONFIG_DIR", "")
selected = (config or home).rstrip("/") + "/.claude.json"
with open(os.environ["FAKE_CLAUDE_LOG"], "a", encoding="utf-8") as fh:
    fh.write(json.dumps({"argv": argv, "HOME": home, "CLAUDE_CONFIG_DIR": config, "selected_state": selected}, separators=(",", ":")) + "\n")
Path(selected).parent.mkdir(parents=True, exist_ok=True); Path(selected).write_text("oh-no fake claude state marker\n", encoding="utf-8")
validates = {os.environ["FAKE_VALIDATE_PLUGIN"], os.environ["FAKE_VALIDATE_MARKETPLACE"]}
if len(argv) == 3 and argv[:2] == ["plugin", "validate"] and argv[2] in validates: raise SystemExit(0)
expected = ["--print", "--verbose", "--output-format", "stream-json", "--model", "fake-model", "--max-budget-usd", "0", "--permission-mode", "dontAsk", "--tools", "Read", "--no-session-persistence", "--system-prompt", "fake-system", "--plugin-dir", os.environ["FAKE_LIVE_PLUGIN_ROOT"]]
if len(argv) == len(expected) + 1 and argv[:-1] == expected and argv[-1] == os.environ["FAKE_INTERVIEW_PROMPT"]:
    read_path = str(Path(os.environ["FAKE_LIVE_PLUGIN_ROOT"]) / "skills-claude/interview/SKILL.md")
    print(json.dumps({"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":read_path}}]}}))
    print(json.dumps({"type":"result","is_error":False,"result":"fake interview result","total_cost_usd":0}))
    raise SystemExit(0)
raise SystemExit(97)
PY
  chmod +x "$fake"
  export FAKE_CLAUDE_LOG="$records" FAKE_VALIDATE_PLUGIN="$canonical_plugin/.claude-plugin/plugin.json" FAKE_VALIDATE_MARKETPLACE="$canonical_marketplace/.claude-plugin/marketplace.json" FAKE_LIVE_PLUGIN_ROOT="$live_plugin" FAKE_INTERVIEW_PROMPT="$interview_prompt"
  rc=0
  ( export HOME="$synthetic_home" CLAUDE_BIN="$fake"; source "$driver"; PLUGIN_ROOT="$canonical_plugin"; MARKETPLACE_ROOT="$canonical_marketplace"; LIVE_PLUGIN_ROOT="$live_plugin"; INSTALL_MODE=0; LIVE_LOAD_MODE=plugin-dir; LIVE_MODEL=fake-model; LIVE_MAX_BUDGET_USD=0; LIVE_SYSTEM_PROMPT=fake-system; RUN_DIR="$temp_root/run"; mkdir -p "$RUN_DIR"; setup_isolated_config; printf '%s\n' "$CLAUDE_CONFIG_DIR" >"$temp_root/success-config"; validate_manifests >/dev/null; run_live_skill_test interview >/dev/null; grep -Fxq 'oh-no fake claude state marker' "$CLAUDE_CONFIG_DIR/.claude.json"; printf 'observed\n' >"$temp_root/marker-observed" ) >/dev/null 2>"$temp_root/success.err" || rc=$?
  [[ "$rc" == 0 && -s "$temp_root/marker-observed" && -s "$temp_root/success-config" ]] || fail "Claude state-isolation success child failed (rc=$rc)"
  success_config="$(<"$temp_root/success-config")"; [[ "$success_config" == /* && ! -d "$success_config" ]] || fail "Claude state-isolation success config was not cleaned"
  for prompt in "/$PLUGIN_NAME:interview" "$interview_prompt UNPLANNED-SUFFIX"; do
    rc=0; HOME="$synthetic_home" CLAUDE_CONFIG_DIR="$rejected_config" FAKE_CLAUDE_LOG="$rejected_records" "$fake" --print --verbose --output-format stream-json --model fake-model --max-budget-usd 0 --permission-mode dontAsk --tools Read --no-session-persistence --system-prompt fake-system --plugin-dir "$live_plugin" "$prompt" >/dev/null 2>&1 || rc=$?; [[ "$rc" == 97 ]] || fail "Claude state-isolation fake accepted malformed Interview prompt (rc=$rc)"
  done
  [[ "$(grep -c . "$rejected_records")" == 2 ]] || fail "Claude state-isolation malformed prompt evidence was not isolated"
  rc=0
  ( export HOME="$synthetic_home" CLAUDE_BIN="$fake"; source "$driver"; setup_isolated_config; printf '%s\n' "$CLAUDE_CONFIG_DIR" >"$temp_root/failure-config"; exit 23 ) >/dev/null 2>&1 || rc=$?
  [[ "$rc" == 23 && -s "$temp_root/failure-config" ]] || fail "Claude state-isolation failure child did not return 23"
  failure_config="$(<"$temp_root/failure-config")"; [[ "$failure_config" == /* && ! -d "$failure_config" ]] || fail "Claude state-isolation failure config was not cleaned"
  "$PYTHON_BIN" - "$records" "$synthetic_home" "$success_config" "$canonical_plugin" "$canonical_marketplace" "$live_plugin" "$interview_prompt" <<'PY'
import json, os, sys
records = [json.loads(line) for line in open(sys.argv[1], encoding="utf-8") if line.strip()]
home, config, plugin, marketplace, live, prompt = sys.argv[2:]
if len(records) != 3:
    raise SystemExit(f"expected exactly 3 fake Claude calls, got {len(records)}")
if [r["argv"] for r in records[:2]] != [["plugin", "validate", plugin + "/.claude-plugin/plugin.json"], ["plugin", "validate", marketplace + "/.claude-plugin/marketplace.json"]]:
    raise SystemExit("fake Claude manifest calls did not match canonical paths")
expected = ["--print", "--verbose", "--output-format", "stream-json", "--model", "fake-model", "--max-budget-usd", "0", "--permission-mode", "dontAsk", "--tools", "Read", "--no-session-persistence", "--system-prompt", "fake-system", "--plugin-dir", live, prompt]
if records[2]["argv"] != expected:
    raise SystemExit("fake Claude live call did not match the exact planned Interview invocation")
for record in records:
    selected = record["selected_state"]
    if record["HOME"] != home or record["CLAUDE_CONFIG_DIR"] != config or not os.path.isabs(config) or selected != config + "/.claude.json" or selected == home + "/.claude.json":
        raise SystemExit("fake Claude process did not inherit disposable state isolation")
PY
  [[ "$(file_identity "$home_state")" == "$home_before" ]] || fail "Claude state-isolation canary changed synthetic HOME state"
  [[ "$(file_identity "$HOME/.claude.json")" == "$actual_before" ]] || fail "Claude state-isolation canary changed actual HOME state"
  ok "Claude process state isolation: planned prompt=0, malformed prompts=97/97, 3 success records, identities, and cleanup verified"
)

run_marketplace_isolation_offline_test() {
  log "Running offline marketplace-isolation fail-closed regression"
  local temp_root fake_home fixture helper before after rc out err
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-claude-marketplace-guard.XXXXXX")"
  fake_home="$temp_root/home"
  helper="$REPO_ROOT/scripts/marketplace_source.py"
  fixture="$fake_home/.claude/plugins/marketplaces/oh-no-harness/.git/config"
  mkdir -p "$(dirname "$fixture")"
  printf '[remote "origin"]\n\turl = https://github.com/jcwleo/oh-no-harness.git\n' >"$fixture"

  before="$temp_root/before.manifest"
  after="$temp_root/after.manifest"
  snapshot_file_manifest "$fake_home" >"$before"

  # ---- shared primitive: source-classification matrix ---------------------
  local s src expect actual cfg
  for s in "$REPO_ROOT=local" "file:///tmp/x=local" "/abs/path=local" "./rel=local" "../rel=local" "~/x=local" "jcwleo/oh-no-harness=remote" "https://github.com/jcwleo/oh-no-harness.git=remote" "https://github.com/jcwleo/oh-no-harness=remote" "git@github.com:jcwleo/oh-no-harness.git=remote" "ssh://git@github.com/jcwleo/oh-no-harness.git=remote" "ssh://git@github.com:jcwleo/oh-no-harness.git=invalid" "http://github.com/a/b=invalid" "https://gitlab.com/a/b=invalid" "https://user:tok@github.com/a/b=invalid" "https://github.com/a/b?x=1=invalid" "singleword=invalid"; do
    expect="${s##*=}"; src="${s%=*}"
    actual="$("$PYTHON_BIN" "$helper" classify-source "$src")"
    [[ "$actual" == "$expect" ]] || { rm -rf "$temp_root"; fail "classify-source('$src')='$actual' expected '$expect'"; }
  done

  # ---- shared primitive: github-slug parse + credential rejection ---------
  for s in "https://github.com/jcwleo/oh-no-harness.git" "https://github.com/jcwleo/oh-no-harness" "git@github.com:jcwleo/oh-no-harness.git" "ssh://git@github.com/jcwleo/oh-no-harness.git"; do
    actual="$("$PYTHON_BIN" "$helper" github-slug "$s")"
    [[ "$actual" == "jcwleo/oh-no-harness" ]] || { rm -rf "$temp_root"; fail "github-slug('$s')='$actual' expected jcwleo/oh-no-harness"; }
  done
  out="$temp_root/slug.out"; err="$temp_root/slug.err"
  for s in "http://github.com/a/b" "https://x:s3cr3t@github.com/jcwleo/oh-no-harness.git" "https://gitlab.com/a/b" "https://github.com:443/a/b" "ssh://user@github.com/a/b" "ssh://git@github.com:jcwleo/oh-no-harness.git"; do
    rc=0
    "$PYTHON_BIN" "$helper" github-slug "$s" >"$out" 2>"$err" || rc=$?
    [[ "$rc" != "0" ]] || { rm -rf "$temp_root"; fail "github-slug accepted an unsupported origin: $s"; }
    grep -Fq "s3cr3t" "$out" "$err" && { rm -rf "$temp_root"; fail "github-slug leaked a credential from '$s'"; } || true
  done

  # ---- shared primitive: redaction ----------------------------------------
  [[ "$("$PYTHON_BIN" "$helper" redact "https://x:s3cr3t@github.com/a/b")" == "https://***@github.com/a/b" ]] || { rm -rf "$temp_root"; fail "redact did not mask URL userinfo"; }
  [[ "$("$PYTHON_BIN" "$helper" redact "/local/path")" == "/local/path" ]] || { rm -rf "$temp_root"; fail "redact altered a local path"; }

  # ---- shared primitive: config-home identity (exact/trailing/dot/symlink) -
  mkdir -p "$fake_home/.claude"
  ln -s "$fake_home/.claude" "$temp_root/cfglink"
  for s in "=default" "$fake_home/.claude=default" "$fake_home/.claude/=default" "$fake_home/.claude/.=default" "$fake_home/x/../.claude=default" "$temp_root/cfglink=default" "$temp_root/other-config=isolated"; do
    expect="${s##*=}"; cfg="${s%=*}"
    actual="$("$PYTHON_BIN" "$helper" config-identity "$cfg" "$fake_home")"
    [[ "$actual" == "$expect" ]] || { rm -rf "$temp_root"; fail "config-identity('$cfg')='$actual' expected '$expect'"; }
  done

  # ---- model-bearing plugin-dir live guard --------------------------------
  local live_home="$temp_root/live-home" live_registry fake_live="$temp_root/fake-live" launch_log="$temp_root/live-launch.log" live_before live_mtime
  live_registry="$live_home/.claude/plugins/known_marketplaces.json"; mkdir -p "$(dirname "$live_registry")"; printf 'sentinel\n' >"$live_registry"
  live_before="$(shasum -a 256 "$live_registry")"; live_mtime="$("$PYTHON_BIN" -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$live_registry")"
  cat >"$fake_live" <<'FAKE_LIVE'
#!/usr/bin/env bash
printf 'launched\n' >>"$FAKE_LIVE_LOG"
registry="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/known_marketplaces.json"
mkdir -p "$(dirname "$registry")"; printf 'mutated\n' >"$registry"
FAKE_LIVE
  chmod +x "$fake_live"
  run_guarded_fake_live() { declare -F guard_real_claude_config_live >/dev/null && guard_real_claude_config_live; "$fake_live"; }
  rc=0; ( unset CLAUDE_CONFIG_DIR OH_NO_CONFIG_DIR OH_NO_ALLOW_REAL_CLAUDE_CONFIG_LIVE; HOME="$live_home" CLAUDE_BIN="$fake_live" FAKE_LIVE_LOG="$launch_log" "$REPO_ROOT/scripts/test-claude-plugin.sh" --no-install --live-hook-only ) >/dev/null 2>"$temp_root/live.err" || rc=$?
  [[ "$rc" == 1 && ! -e "$launch_log" && "$live_before" == "$(shasum -a 256 "$live_registry")" && "$live_mtime" == "$("$PYTHON_BIN" -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$live_registry")" ]] || { rm -rf "$temp_root"; fail "real-default-config plugin-dir live path launched before the fail-closed guard"; }
  grep -Fq "ordinary Claude startup plugin sync" "$temp_root/live.err" || { rm -rf "$temp_root"; fail "real-config live guard omitted the startup-sync risk"; }
  for s in RUN_LIVE RUN_DEEP_LIVE RUN_PARALLEL_LIVE RUN_RALPLAN_LIVE RUN_FUSION_RESCUE_LIVE RUN_CROSS_HOST_FALLBACK_LIVE RUN_MODEL_DIVERSITY_LIVE RUN_PARALLEL_EXECUTOR_LIVE RUN_SIMPLIFY_LIVE RUN_NATURAL_SESSION_START_LIVE; do
    rc=0; ( unset CLAUDE_CONFIG_DIR OH_NO_ALLOW_REAL_CLAUDE_CONFIG_LIVE; HOME="$live_home"; RUN_LIVE=0 RUN_DEEP_LIVE=0 RUN_PARALLEL_LIVE=0 RUN_RALPLAN_LIVE=0 RUN_FUSION_RESCUE_LIVE=0 RUN_CROSS_HOST_FALLBACK_LIVE=0 RUN_MODEL_DIVERSITY_LIVE=0 RUN_PARALLEL_EXECUTOR_LIVE=0 RUN_SIMPLIFY_LIVE=0 RUN_NATURAL_SESSION_START_LIVE=0; printf -v "$s" 1; LIVE_LOAD_MODE=plugin-dir; guard_real_claude_config_live ) 2>/dev/null || rc=$?
    [[ "$rc" == 1 ]] || { rm -rf "$temp_root"; fail "real-config live guard missed $s"; }
  done
  : >"$launch_log"; ( HOME="$live_home"; RUN_LIVE=1; LIVE_LOAD_MODE=plugin-dir; ISOLATED_CONFIG_HOME=""; export FAKE_LIVE_LOG="$launch_log"; setup_isolated_config; run_guarded_fake_live ) >/dev/null 2>&1
  [[ -s "$launch_log" && "$live_before" == "$(shasum -a 256 "$live_registry")" && "$live_mtime" == "$("$PYTHON_BIN" -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$live_registry")" ]] || { rm -rf "$temp_root"; fail "--isolated-config live path changed the fake real registry or did not launch"; }
  : >"$launch_log"; ( HOME="$live_home"; CLAUDE_CONFIG_DIR="$temp_root/explicit-live-config"; RUN_LIVE=1; LIVE_LOAD_MODE=plugin-dir; export CLAUDE_CONFIG_DIR FAKE_LIVE_LOG="$launch_log"; run_guarded_fake_live ) >/dev/null 2>&1
  [[ -s "$launch_log" && "$live_before" == "$(shasum -a 256 "$live_registry")" && "$live_mtime" == "$("$PYTHON_BIN" -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$live_registry")" ]] || { rm -rf "$temp_root"; fail "explicit non-default CLAUDE_CONFIG_DIR live path changed the fake real registry or did not launch"; }
  rc=0; ( unset CLAUDE_CONFIG_DIR OH_NO_ALLOW_REAL_CLAUDE_CONFIG_LIVE; HOME="$live_home"; OH_NO_CONFIG_DIR="$temp_root/oh-no-only"; RUN_LIVE=1; LIVE_LOAD_MODE=plugin-dir; guard_real_claude_config_live ) 2>/dev/null || rc=$?
  [[ "$rc" == 1 ]] || { rm -rf "$temp_root"; fail "OH_NO_CONFIG_DIR was mistaken for Claude registry isolation"; }
  local escape_home="$temp_root/escape-home" escape_registry="$temp_root/escape-home/.claude/plugins/known_marketplaces.json"
  mkdir -p "$(dirname "$escape_registry")"; printf 'sentinel\n' >"$escape_registry"; : >"$launch_log"
  ( unset CLAUDE_CONFIG_DIR; HOME="$escape_home"; OH_NO_ALLOW_REAL_CLAUDE_CONFIG_LIVE=1; RUN_LIVE=1; LIVE_LOAD_MODE=plugin-dir; export FAKE_LIVE_LOG="$launch_log"; run_guarded_fake_live ) >/dev/null 2>&1
  [[ -s "$launch_log" && "$(<"$escape_registry")" == mutated ]] || { rm -rf "$temp_root"; fail "explicit real-config live escape hatch did not permit the mutation-capable fixture"; }

  # ---- guard control flow (name-agnostic; blocker 1a) ----------------------
  err="$temp_root/danger.err"
  rc=0
  (
    unset CLAUDE_CONFIG_DIR OH_NO_ALLOW_CANONICAL_LOCAL_MARKETPLACE
    HOME="$fake_home"; MARKETPLACE_NAME="oh-no-harness"; MARKETPLACE_SOURCE="$REPO_ROOT"
    guard_canonical_local_marketplace
  ) 2>"$err" || rc=$?
  [[ "$rc" == "1" ]] || { rm -rf "$temp_root"; fail "guard did not block local source + default config (rc=$rc)"; }
  grep -Fq "from a LOCAL source" "$err" || { rm -rf "$temp_root"; fail "guard block message missing the expected diagnostic"; }

  # A non-canonical name is NOT a safe path.
  rc=0
  (
    unset CLAUDE_CONFIG_DIR OH_NO_ALLOW_CANONICAL_LOCAL_MARKETPLACE
    HOME="$fake_home"; MARKETPLACE_NAME="some-other-marketplace"; MARKETPLACE_SOURCE="$REPO_ROOT"
    guard_canonical_local_marketplace
  ) 2>/dev/null || rc=$?
  [[ "$rc" == "1" ]] || { rm -rf "$temp_root"; fail "guard treated a non-canonical name + local + default as safe (rc=$rc)"; }

  # An invalid source is always refused.
  rc=0
  (
    unset CLAUDE_CONFIG_DIR OH_NO_ALLOW_CANONICAL_LOCAL_MARKETPLACE
    HOME="$fake_home"; MARKETPLACE_NAME="oh-no-harness"; MARKETPLACE_SOURCE="http://github.com/a/b"
    guard_canonical_local_marketplace
  ) 2>/dev/null || rc=$?
  [[ "$rc" == "1" ]] || { rm -rf "$temp_root"; fail "guard allowed an invalid source into the real config (rc=$rc)"; }

  # Safe variants: isolated config, validated GitHub source, explicit opt-in.
  rc=0
  ( HOME="$fake_home"; CLAUDE_CONFIG_DIR="$temp_root/iso"; MARKETPLACE_NAME="oh-no-harness"; MARKETPLACE_SOURCE="$REPO_ROOT"; guard_canonical_local_marketplace ) 2>/dev/null || rc=$?
  [[ "$rc" == "0" ]] || { rm -rf "$temp_root"; fail "guard blocked an isolated config (rc=$rc)"; }
  rc=0
  ( unset CLAUDE_CONFIG_DIR; HOME="$fake_home"; MARKETPLACE_NAME="oh-no-harness"; MARKETPLACE_SOURCE="jcwleo/oh-no-harness"; guard_canonical_local_marketplace ) 2>/dev/null || rc=$?
  [[ "$rc" == "0" ]] || { rm -rf "$temp_root"; fail "guard blocked a validated GitHub source (rc=$rc)"; }
  rc=0
  ( unset CLAUDE_CONFIG_DIR; HOME="$fake_home"; OH_NO_ALLOW_CANONICAL_LOCAL_MARKETPLACE=1; MARKETPLACE_NAME="oh-no-harness"; MARKETPLACE_SOURCE="$REPO_ROOT"; guard_canonical_local_marketplace ) 2>/dev/null || rc=$?
  [[ "$rc" == "0" ]] || { rm -rf "$temp_root"; fail "explicit opt-in did not override the guard (rc=$rc)"; }

  # ---- production install call-site with a logging fake CLAUDE_BIN ---------
  local fake_claude wire_log
  fake_claude="$temp_root/fake-claude"
  wire_log="$temp_root/wire.log"
  cat >"$fake_claude" <<'FAKE'
#!/usr/bin/env bash
printf '%s\tCLAUDE_CONFIG_DIR=%s\n' "$*" "${CLAUDE_CONFIG_DIR:-}" >>"$FAKE_CLAUDE_LOG"
case "$*" in
  *"marketplace list"*) printf '[]\n' ;;
  *"plugin list"*) printf '[]\n' ;;
  *) : ;;
esac
exit 0
FAKE
  chmod +x "$fake_claude"

  # Blocked case: the guard must fire before ANY CLI command runs.
  : >"$wire_log"
  rc=0
  (
    unset CLAUDE_CONFIG_DIR OH_NO_ALLOW_CANONICAL_LOCAL_MARKETPLACE
    HOME="$fake_home"
    export FAKE_CLAUDE_LOG="$wire_log"
    CLAUDE_BIN="$fake_claude"; MARKETPLACE_NAME="oh-no-harness"; MARKETPLACE_SOURCE="$REPO_ROOT"
    INSTALL_MODE=1; PLUGIN_ID="oh-no-harness@oh-no-harness"
    install_or_update_plugin
  ) >/dev/null 2>&1 || rc=$?
  [[ "$rc" == "1" ]] || { rm -rf "$temp_root"; fail "blocked install_or_update_plugin did not fail closed (rc=$rc)"; }
  [[ ! -s "$wire_log" ]] || { local leaked; leaked="$(cat "$wire_log")"; rm -rf "$temp_root"; fail "blocked install path executed CLI commands: $leaked"; }

  # Safe synthetic case: expected marketplace command + isolated env recorded.
  : >"$wire_log"
  rc=0
  (
    unset OH_NO_ALLOW_CANONICAL_LOCAL_MARKETPLACE
    export FAKE_CLAUDE_LOG="$wire_log"
    export CLAUDE_CONFIG_DIR="$temp_root/iso-wire"
    CLAUDE_BIN="$fake_claude"; MARKETPLACE_NAME="oh-no-harness"; MARKETPLACE_SOURCE="jcwleo/oh-no-harness"
    INSTALL_MODE=1; REQUESTED_SCOPE=""; PLUGIN_ID="oh-no-harness@oh-no-harness"
    install_or_update_plugin
  ) >/dev/null 2>&1 || true
  grep -q "plugin marketplace add" "$wire_log" || { rm -rf "$temp_root"; fail "safe install path did not run marketplace add"; }
  grep "plugin marketplace add" "$wire_log" | grep -Fq "CLAUDE_CONFIG_DIR=$temp_root/iso-wire" || { rm -rf "$temp_root"; fail "marketplace add did not carry the isolated config env"; }
  grep -q "plugin install" "$wire_log" || { rm -rf "$temp_root"; fail "safe install path did not run plugin install"; }

  # --no-install / OH_NO_INSTALL=0 must skip install (and the guard) entirely.
  rc=0
  (
    unset CLAUDE_CONFIG_DIR; HOME="$fake_home"
    CLAUDE_BIN="/bin/false"; MARKETPLACE_NAME="oh-no-harness"; MARKETPLACE_SOURCE="$REPO_ROOT"
    INSTALL_MODE=0
    install_or_update_plugin
  ) >/dev/null 2>&1 || rc=$?
  [[ "$rc" == "0" ]] || { rm -rf "$temp_root"; fail "--no-install did not skip the install/guard path (rc=$rc)"; }

  # ---- release invocation contract (guard/call-site removal must fail) -----
  local rel_log="$temp_root/release-invoke.log"
  : >"$rel_log"
  (
    source "$REPO_ROOT/scripts/release"
    run() { printf 'ARGV=%s\nSRC=%s\nINSTALL=%s\n' "$*" "${OH_NO_MARKETPLACE_SOURCE:-}" "${OH_NO_INSTALL:-}"; }
    MARKETPLACE_NAME="oh-no-harness"
    run_claude_install_test "jcwleo/oh-no-harness"
  ) >"$rel_log" 2>/dev/null || true
  grep -q 'ARGV=.*scripts/test-claude-plugin.sh.*--isolated-config' "$rel_log" || { rm -rf "$temp_root"; fail "release Claude invocation missing --isolated-config"; }
  grep -q '^SRC=jcwleo/oh-no-harness$' "$rel_log" || { rm -rf "$temp_root"; fail "release Claude invocation did not pass the credential-free slug"; }
  grep -q '^INSTALL=1$' "$rel_log" || { rm -rf "$temp_root"; fail "release Claude invocation did not force OH_NO_INSTALL=1"; }

  # A hostile inherited OH_NO_INSTALL=0 must be overridden to 1.
  : >"$rel_log"
  (
    source "$REPO_ROOT/scripts/release"
    run() { printf 'INSTALL=%s\n' "${OH_NO_INSTALL:-}"; }
    export OH_NO_INSTALL=0
    MARKETPLACE_NAME="oh-no-harness"
    run_claude_install_test "jcwleo/oh-no-harness"
  ) >"$rel_log" 2>/dev/null || true
  grep -q '^INSTALL=1$' "$rel_log" \
    || { rm -rf "$temp_root"; fail "release did not override an inherited OH_NO_INSTALL=0"; }

  # Release derives a credential-free slug and rejects unsupported origins.
  local slug
  slug="$( ( source "$REPO_ROOT/scripts/release"; github_slug_from_origin "git@github.com:jcwleo/oh-no-harness.git" ) 2>/dev/null )"
  [[ "$slug" == "jcwleo/oh-no-harness" ]] \
    || { rm -rf "$temp_root"; fail "release did not parse a valid origin to a slug (got '$slug')"; }
  out="$temp_root/rel-slug.out"; err="$temp_root/rel-slug.err"
  rc=0
  ( source "$REPO_ROOT/scripts/release"; github_slug_from_origin "https://x:s3cr3t@github.com/jcwleo/oh-no-harness.git" ) >"$out" 2>"$err" || rc=$?
  [[ "$rc" != "0" ]] \
    || { rm -rf "$temp_root"; fail "release accepted a credentialed origin URL"; }
  grep -Fq "s3cr3t" "$out" "$err" \
    && { rm -rf "$temp_root"; fail "release leaked a credential from the origin URL"; } || true

  # Success/fixed-failure cleanup is covered by run_claude_state_isolation_offline_test; retain interrupt coverage here.
  local iso_home
  iso_home="$(bash -c 'set -uo pipefail; source "'"$REPO_ROOT"'/scripts/test-claude-plugin.sh"; setup_isolated_config; printf "%s\n" "$CLAUDE_CONFIG_DIR"; kill -INT $$; sleep 5' 2>/dev/null || true)"
  { [[ -n "$iso_home" && ! -d "$iso_home" ]]; } \
    || { rm -rf "$temp_root"; fail "isolated config not cleaned on INT (home=$iso_home)"; }
  iso_home="$(bash -c 'set -uo pipefail; source "'"$REPO_ROOT"'/scripts/test-claude-plugin.sh"; setup_isolated_config; printf "%s\n" "$CLAUDE_CONFIG_DIR"; kill -TERM $$; sleep 5' 2>/dev/null || true)"
  { [[ -n "$iso_home" && ! -d "$iso_home" ]]; } \
    || { rm -rf "$temp_root"; fail "isolated config not cleaned on TERM (home=$iso_home)"; }

  # The simulated user marketplace fixture is byte-for-byte unchanged.
  snapshot_file_manifest "$fake_home" >"$after"
  cmp -s "$before" "$after" \
    || { rm -rf "$temp_root"; fail "regression mutated the simulated user marketplace fixture"; }

  rm -rf "$temp_root"
  ok "marketplace/live-config isolation: guarded install/live call-sites, safe-path matrix, release contract, and cleanup verified"
}
main() {
  cd "$PLUGIN_ROOT"
  require_command "$CLAUDE_BIN"
  require_command "$PYTHON_BIN"

  [[ "$ISOLATED_CONFIG" == "1" ]] && setup_isolated_config
  guard_real_claude_config_live
  validate_live_plugin_root

  log "Testing ${PLUGIN_ID} from ${PLUGIN_ROOT}"
  validate_manifests; validate_hooks
  run_live_timeout_offline_test; run_natural_prompt_guard_offline_test; run_natural_git_fixture_offline_test
  run_natural_activation_assertion_offline_test; run_ralplan_object_analysis_dispatch_guard_offline_test
  run_escape_net_offline_test; run_active_stale_scan_reader_offline_test
  run_configure_subagents_offline_test; run_script_resolver_offline_test
  run_live_plugin_root_offline_test; run_marketplace_isolation_offline_test; run_claude_state_isolation_offline_test
  validate_frontmatter; install_or_update_plugin
  run_live_tests; run_deep_live_tests; run_ralplan_live_test; run_parallel_live_test
  run_fusion_rescue_live_test; run_cross_host_fallback_live_test; run_model_diversity_live_test
  run_parallel_executor_live_test; run_simplify_live_test; run_natural_session_start_live_tests
  log "All requested checks passed"
}

# Run main only when executed directly. When sourced (e.g. to exercise a single
# offline function such as run_escape_net_offline_test or validate_hooks without
# spending the full install/live suite), main is skipped.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
