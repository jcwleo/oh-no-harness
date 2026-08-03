#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
# The self-inspecting offline guards (shared-helper injection, parser inventory,
# safety extraction) must read the RUNNING script, not a fixed CWD-relative path.
# A hardcoded "scripts/test-codex-plugin.sh" let a mutated variant read canonical
# source and certify itself, which silently neutralised those guards under mutation.
SELF_PATH="${BASH_SOURCE[0]}"
[[ "$SELF_PATH" == /* ]] || SELF_PATH="$SCRIPT_DIR/$(basename -- "$SELF_PATH")"

CODEX_BIN="${CODEX_BIN:-codex}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
CODEX_HOME_DIR="${CODEX_HOME:-${HOME}/.codex}"
PLUGIN_NAME="${OH_NO_PLUGIN_NAME:-oh-no-harness}"
MARKETPLACE_NAME="${OH_NO_MARKETPLACE_NAME:-oh-no-harness}"
MARKETPLACE_ROOT="${OH_NO_MARKETPLACE_ROOT:-$REPO_ROOT}"
PLUGIN_ROOT="${OH_NO_PLUGIN_ROOT:-$MARKETPLACE_ROOT/plugins/$PLUGIN_NAME}"
PLUGIN_ID="${PLUGIN_NAME}@${MARKETPLACE_NAME}"
MARKETPLACE_SOURCE="${OH_NO_MARKETPLACE_SOURCE:-$MARKETPLACE_ROOT}"
INSTALL_MODE="${OH_NO_INSTALL:-1}"
RUN_LIVE="${OH_NO_LIVE:-0}"
RUN_DISPATCH_LIVE="${OH_NO_DISPATCH_LIVE:-0}"
RUN_CROSS_HOST_LIVE="${OH_NO_CROSS_HOST_LIVE:-0}"
LIVE_MODEL="${OH_NO_CODEX_TEST_MODEL:-}"
CROSS_HOST_MAX_BUDGET_USD="${OH_NO_MAX_BUDGET_USD:-3.00}"
FORCE_ISOLATED_CODEX_HOME="${OH_NO_ISOLATE_CODEX_HOME:-0}"
LIVE_TIMEOUT_SECONDS="${OH_NO_LIVE_TIMEOUT_SECONDS:-900}"
LIVE_TIMEOUT_GRACE_SECONDS="${OH_NO_LIVE_TIMEOUT_GRACE_SECONDS:-5}"
FUSION_RESCUE_MAX_BUDGET_USD="${OH_NO_FUSION_RESCUE_MAX_BUDGET_USD:-10.00}"
RUN_DIR="${OH_NO_TEST_RUN_DIR:-${MARKETPLACE_ROOT}/.oh-no/test-runs/$(date +%Y%m%d-%H%M%S)-codex}"
CODEX_HOME_SOURCE_DIR=""
CODEX_ACTIVE_HOME_DIR=""
CODEX_LIVE_TEMP_ROOTS=()
CODEX_LIVE_CLONE_MARKER=".oh-no-live-clone-provenance.json"
ISOLATED_CODEX_LIVE_FUNCTIONS=(
  run_live_skill_test
  run_dispatch_live_scenario
  run_cross_host_live_test
)

cleanup_codex_live_temp_roots() {
  local dir
  for dir in "${CODEX_LIVE_TEMP_ROOTS[@]:-}"; do
    [[ -n "$dir" ]] && rm -rf "$dir"
  done
  return 0
}

trap cleanup_codex_live_temp_roots EXIT

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
)

usage() {
  cat <<USAGE
Usage: scripts/test-codex-plugin.sh [options]

Adds the marketplace, verifies deterministic install/identity gates, and exposes
public skills. Ordinary --live directly invokes each public non-Fusion skill and
checks one explicit read-only invariant. Separate --dispatch-live probes bounded
internal role dispatch mechanics without enlarging --live. Separate
--cross-host-live proves one direct Codex parent -> Claude Code transport.

Options:
  --live              Run direct public-skill invariant smokes.
  --dispatch-live     Run the minimal internal role-dispatch matrix.
  --cross-host-live   Run one direct Codex parent -> Claude Code transport smoke.
  --skip-live         Skip all live smokes. Default.
  --no-install       Skip marketplace/app-server install.
  --codex-home <dir> Use this Codex home instead of \$CODEX_HOME or ~/.codex.
  --model <model>    Model for direct smokes. Default: Codex config default.
  --marketplace-source <source>
  -h, --help         Show this help.

Natural-routing, deep-summary, topology, worktree, and exhaustive-agent model
suites have been retired. Fusion Rescue remains deferred. Cross-host is limited
to the separate direct transport smoke; no workflow, fallback, panel, or subagent.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --live) RUN_LIVE=1; shift ;;
    --dispatch-live) RUN_DISPATCH_LIVE=1; shift ;;
    --cross-host-live) RUN_CROSS_HOST_LIVE=1; shift ;;
    --skip-live) RUN_LIVE=0; RUN_DISPATCH_LIVE=0; RUN_CROSS_HOST_LIVE=0; shift ;;
    --no-install) INSTALL_MODE=0; shift ;;
    --codex-home) CODEX_HOME_DIR="${2:-}"; [[ -n "$CODEX_HOME_DIR" ]] || { echo "Missing value for --codex-home" >&2; exit 2; }; shift 2 ;;
    --model) LIVE_MODEL="${2:-}"; [[ -n "$LIVE_MODEL" ]] || { echo "Missing value for --model" >&2; exit 2; }; shift 2 ;;
    --marketplace-source) MARKETPLACE_SOURCE="${2:-}"; [[ -n "$MARKETPLACE_SOURCE" ]] || { echo "Missing value for --marketplace-source" >&2; exit 2; }; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done
CODEX_ACTIVE_HOME_DIR="$CODEX_HOME_DIR"

isolated_codex_live_home_requested() {
  [[ "$RUN_LIVE" == "1" || "$RUN_DISPATCH_LIVE" == "1" || "$RUN_CROSS_HOST_LIVE" == "1" || "$FORCE_ISOLATED_CODEX_HOME" == "1" ]]
}

clone_codex_live_home() {
  local source_home="$1"
  local target_home="$2"

  [[ -f "$source_home/config.toml" ]] \
    || fail "Codex live isolation requires the active config at $source_home/config.toml"

  "$PYTHON_BIN" - "$source_home" "$target_home" <<'PY' || return $?
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])

if source.resolve() == target.resolve():
    raise SystemExit("isolated Codex live clone target must differ from the active home")

for name in ("config.toml", "auth.json", "config.json"):
    path = source / name
    if path.is_symlink():
        raise SystemExit(f"active Codex {name} must not be a symlink for live isolation")
    if path.exists() and not path.is_file():
        raise SystemExit(f"active Codex {name} is not a regular file")

agents = source / "agents"
if agents.is_symlink():
    raise SystemExit("active Codex agents root must not be a symlink for live isolation")
if agents.exists() and not agents.is_dir():
    raise SystemExit("active Codex agents path is not a directory")
if agents.exists():
    for path in agents.rglob("*"):
        if path.is_symlink():
            relative = path.relative_to(agents).as_posix()
            raise SystemExit(
                f"active Codex agents tree contains a symlink: {relative}"
            )
        if not path.is_file() and not path.is_dir():
            relative = path.relative_to(agents).as_posix()
            raise SystemExit(
                f"active Codex agents tree contains an unsupported entry: {relative}"
            )
PY

  rm -rf "$target_home" || return $?
  mkdir -p "$target_home" || return $?

  local config_file
  for config_file in auth.json config.json config.toml; do
    if [[ -f "$source_home/$config_file" ]]; then
      cp -p "$source_home/$config_file" "$target_home/$config_file" || return $?
    fi
  done
  chmod 600 "$target_home/config.toml" || return $?
  [[ ! -f "$target_home/auth.json" ]] || chmod 600 "$target_home/auth.json" || return $?

  if [[ -d "$source_home/agents" ]]; then
    cp -Rp "$source_home/agents" "$target_home/agents" || return $?
  fi

  "$PYTHON_BIN" - "$source_home" "$target_home" "$CODEX_LIVE_CLONE_MARKER" <<'PY' || return $?
import hashlib
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
marker_name = sys.argv[3]


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def entry_map(root: Path) -> dict[str, list[str]]:
    if not root.exists():
        return {}
    if root.is_symlink():
        raise SystemExit(f"Codex live agents root must be independent: {root}")
    entries: dict[str, list[str]] = {}
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            raise SystemExit(f"Codex live agents tree must be symlink-free: {relative}")
        elif path.is_file():
            entries[relative] = ["file", digest(path)]
        elif path.is_dir():
            entries[relative] = ["dir", ""]
        else:
            raise SystemExit(f"unsupported active-agent entry type: {relative}")
    return entries


for name in ("config.toml", "auth.json", "config.json"):
    source_path = source / name
    target_path = target / name
    if source_path.exists() != target_path.exists():
        raise SystemExit(f"isolated Codex live clone presence mismatch: {name}")
    if source_path.exists() and digest(source_path) != digest(target_path):
        raise SystemExit(f"isolated Codex live clone content mismatch: {name}")

source_agents = entry_map(source / "agents")
target_agents = entry_map(target / "agents")
if source_agents != target_agents:
    raise SystemExit("isolated Codex live clone does not match the active agents tree")

source_manifest = {
    "config": {
        name: digest(source / name)
        for name in ("config.toml", "auth.json", "config.json")
        if (source / name).exists()
    },
    "agents": source_agents,
}
marker = target / marker_name
marker.write_text(
    json.dumps(
        {
            "schema_version": 1,
            "source_home": str(source.resolve()),
            "source_manifest": source_manifest,
        },
        sort_keys=True,
    ) + "\n",
    encoding="utf-8",
)
marker.chmod(0o600)
PY
}

assert_codex_live_home_provenance() {
  local live_home="$1"

  "$PYTHON_BIN" - "$live_home" "$CODEX_LIVE_CLONE_MARKER" <<'PY' || return $?
import hashlib
import json
import sys
from pathlib import Path

target = Path(sys.argv[1])
marker = target / sys.argv[2]

if marker.is_symlink() or not marker.is_file():
    raise SystemExit(f"isolated Codex live home lacks verified provenance: {target}")

payload = json.loads(marker.read_text(encoding="utf-8"))
if payload.get("schema_version") != 1:
    raise SystemExit("isolated Codex live provenance has an unsupported schema")
source = Path(str(payload.get("source_home") or ""))
if not source.is_absolute() or source.resolve() == target.resolve():
    raise SystemExit("isolated Codex live provenance does not name an independent source")


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def entry_map(root: Path) -> dict[str, list[str]]:
    if not root.exists():
        return {}
    if root.is_symlink():
        raise SystemExit("active Codex agents root became a symlink during live test")
    entries: dict[str, list[str]] = {}
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            raise SystemExit(
                f"active Codex agents tree gained a symlink during live test: {relative}"
            )
        if path.is_file():
            entries[relative] = ["file", digest(path)]
        elif path.is_dir():
            entries[relative] = ["dir", ""]
        else:
            raise SystemExit(
                f"active Codex agents tree gained an unsupported entry: {relative}"
            )
    return entries


for name in ("config.toml", "auth.json", "config.json"):
    path = source / name
    if path.is_symlink():
        raise SystemExit(f"active Codex {name} became a symlink during live test")

current_manifest = {
    "config": {
        name: digest(source / name)
        for name in ("config.toml", "auth.json", "config.json")
        if (source / name).exists()
    },
    "agents": entry_map(source / "agents"),
}
if current_manifest != payload.get("source_manifest"):
    raise SystemExit("active Codex config or agents changed during isolated live test")
PY
}

run_live_process_with_timeout_seconds() {
  local live_home="$1"
  local timeout_seconds="$2"
  shift 2

  "$PYTHON_BIN" - "$live_home" "$timeout_seconds" "$LIVE_TIMEOUT_GRACE_SECONDS" "$@" <<'PY'
import os
import signal
import subprocess
import sys
import time

live_home = sys.argv[1]
timeout_seconds = float(sys.argv[2])
grace_seconds = float(sys.argv[3])
command = sys.argv[4:]
if not command:
    raise SystemExit("live command runner received no command")
if timeout_seconds <= 0 or grace_seconds < 0:
    raise SystemExit("live command timeout must be positive and grace must be non-negative")

environment = os.environ.copy()
environment["CODEX_HOME"] = live_home
process = subprocess.Popen(command, env=environment, start_new_session=True)


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
}

live_timeout_seconds_for_policy() {
  case "$1" in
    ordinary) printf '%s\n' "$LIVE_TIMEOUT_SECONDS" ;;
    ralplan-natural) printf '%s\n' "$RALPLAN_NATURAL_LIVE_TIMEOUT_SECONDS" ;;
    *) fail "unknown Codex live-timeout policy: $1" ;;
  esac
}

run_live_process_with_timeout_for_policy() {
  local live_home="$1"
  local policy="$2"
  local timeout_seconds
  shift 2
  timeout_seconds="$(live_timeout_seconds_for_policy "$policy")"
  run_live_process_with_timeout_seconds "$live_home" "$timeout_seconds" "$@"
}

run_live_process_with_timeout() {
  local live_home="$1"
  shift
  run_live_process_with_timeout_for_policy "$live_home" ordinary "$@"
}

run_live_timeout_offline_test() {
  log "Running offline Codex live-timeout process-group regression"
  local temp_root fixture pid_file err_file child_pid rc
  local saved_timeout="$LIVE_TIMEOUT_SECONDS"
  local saved_grace="$LIVE_TIMEOUT_GRACE_SECONDS"
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-codex-timeout-self-test.XXXXXX")"
  fixture="$temp_root/spawn-descendant.py"
  pid_file="$temp_root/descendant.pid"
  err_file="$temp_root/timeout.err"
  mkdir -p "$temp_root/live-home"
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
  run_live_process_with_timeout \
    "$temp_root/live-home" "$PYTHON_BIN" "$fixture" "$pid_file" \
    >/dev/null 2>"$err_file" || rc=$?
  LIVE_TIMEOUT_SECONDS="$saved_timeout"
  LIVE_TIMEOUT_GRACE_SECONDS="$saved_grace"

  [[ "$rc" == "124" ]] \
    || { rm -rf "$temp_root"; fail "Codex timeout fixture returned $rc instead of 124"; }
  grep -Fq "live command exceeded 0.3s" "$err_file" \
    || { rm -rf "$temp_root"; fail "Codex timeout fixture omitted the timeout diagnostic"; }
  [[ -s "$pid_file" ]] \
    || { rm -rf "$temp_root"; fail "Codex timeout fixture did not record its descendant pid"; }
  child_pid="$(<"$pid_file")"
  "$PYTHON_BIN" - "$child_pid" <<'PY' \
    || { rm -rf "$temp_root"; fail "Codex timeout runner left its descendant process alive"; }
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
  run_live_process_with_timeout \
    "$temp_root/live-home" "$PYTHON_BIN" -c 'raise SystemExit(7)' \
    >/dev/null 2>&1 || rc=$?
  rm -rf "$temp_root"
  [[ "$rc" == "7" ]] || fail "Codex timeout runner changed child exit 7 to $rc"
  ok "Codex live-timeout runner returns 124, kills descendants, and preserves child status"
}

run_live_timeout_policy_offline_test() {
  log "Running offline Codex live-timeout policy regression"
  local saved_timeout="$LIVE_TIMEOUT_SECONDS"
  local saved_ralplan_timeout="$RALPLAN_NATURAL_LIVE_TIMEOUT_SECONDS"
  local temp_root rc=0 default_values override_values
  default_values="$(
    env -u OH_NO_LIVE_TIMEOUT_SECONDS bash -c \
      'script=$1; set --; source "$script"; printf "%s %s\n" "$LIVE_TIMEOUT_SECONDS" "$RALPLAN_NATURAL_LIVE_TIMEOUT_SECONDS"' \
      timeout-policy-default "$SELF_PATH"
  )"
  [[ "$default_values" == "900 1500" ]] \
    || fail "Codex live-timeout defaults changed: $default_values"
  LIVE_TIMEOUT_SECONDS=900
  RALPLAN_NATURAL_LIVE_TIMEOUT_SECONDS=1500
  [[ "$(live_timeout_seconds_for_policy ordinary)" == "900" ]] \
    || fail "ordinary Codex live commands no longer resolve the 900-second default"
  [[ "$(live_timeout_seconds_for_policy ralplan-natural)" == "1500" ]] \
    || fail "natural Ralplan live command does not resolve the fixed 1500-second default ceiling"
  override_values="$(
    OH_NO_LIVE_TIMEOUT_SECONDS=37 bash -c \
      'script=$1; set --; source "$script"; printf "%s %s\n" "$LIVE_TIMEOUT_SECONDS" "$RALPLAN_NATURAL_LIVE_TIMEOUT_SECONDS"' \
      timeout-policy-override "$SELF_PATH"
  )"
  [[ "$override_values" == "37 37" ]] \
    || fail "explicit OH_NO_LIVE_TIMEOUT_SECONDS no longer overrides both supported live-timeout policies: $override_values"

  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-codex-timeout-policy.XXXXXX")"
  mkdir -p "$temp_root/live-home"
  LIVE_TIMEOUT_SECONDS="0.45"
  RALPLAN_NATURAL_LIVE_TIMEOUT_SECONDS="0.8"
  run_live_process_with_timeout_for_policy \
    "$temp_root/live-home" ordinary "$PYTHON_BIN" -u -c \
    'import time; time.sleep(0.15); print("progress", flush=True); time.sleep(0.15); print("receipt", flush=True); time.sleep(0.4)' \
    >/dev/null 2>&1 || rc=$?
  [[ "$rc" == "124" ]] \
    || { rm -rf "$temp_root"; fail "ordinary timeout deadline was reset by progress/receipt or returned $rc instead of 124"; }
  rc=0
  run_live_process_with_timeout_for_policy \
    "$temp_root/live-home" ralplan-natural "$PYTHON_BIN" -c 'import time; time.sleep(0.7)' \
    >/dev/null 2>&1 || rc=$?
  LIVE_TIMEOUT_SECONDS="$saved_timeout"
  RALPLAN_NATURAL_LIVE_TIMEOUT_SECONDS="$saved_ralplan_timeout"
  rm -rf "$temp_root"
  [[ "$rc" == "0" ]] \
    || fail "scaled natural Ralplan timeout policy returned $rc instead of 0"
  ok "ordinary live commands retain 900s, natural Ralplan defaults to 1500s, explicit override wins, and progress does not reset the deadline"
}

run_in_verified_codex_live_home() {
  local live_home="$1"
  shift

  assert_codex_live_home_provenance "$live_home" || return $?
  local status=0
  run_live_process_with_timeout "$live_home" "$@" || status=$?
  assert_codex_live_home_provenance "$live_home" || return $?
  return "$status"
}

run_in_verified_codex_live_home_for_policy() {
  local live_home="$1"
  local policy="$2"
  shift 2

  assert_codex_live_home_provenance "$live_home" || return $?
  local status=0
  run_live_process_with_timeout_for_policy "$live_home" "$policy" "$@" || status=$?
  assert_codex_live_home_provenance "$live_home" || return $?
  return "$status"
}

run_codex_live_command() {
  local live_home="$1"
  shift

  if [[ -f "$live_home/$CODEX_LIVE_CLONE_MARKER" && ! -L "$live_home/$CODEX_LIVE_CLONE_MARKER" ]]; then
    run_in_verified_codex_live_home "$live_home" "$@"
    return
  fi

  "$PYTHON_BIN" - "$CODEX_ACTIVE_HOME_DIR" "$live_home" <<'PY' || return $?
import sys
from pathlib import Path

active = Path(sys.argv[1]).resolve()
requested = Path(sys.argv[2]).resolve()
if requested != active:
    raise SystemExit(
        "live Codex commands may use only the active home or a verified active-home clone"
    )
PY
  run_live_process_with_timeout "$live_home" "$@"
}

validate_codex_live_clone_safety() {
  local temp_root
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-codex-clone-self-test.XXXXXX")"
  local source="$temp_root/source"
  local target="$temp_root/target"
  local external_agents="$temp_root/external-agents"
  mkdir -p "$source/agents" "$external_agents"
  printf 'model = "fixture"\n' >"$source/config.toml"
  printf '{"token":"fixture"}\n' >"$source/auth.json"
  printf '{"fixture":true}\n' >"$source/config.json"
  printf 'developer_instructions = "fixture"\n' >"$source/agents/oh-no-planner.toml"
  printf 'sentinel\n' >"$external_agents/sentinel"

  clone_codex_live_home "$source" "$target"
  assert_codex_live_home_provenance "$target"

  local dispatch_fingerprint
  dispatch_fingerprint="$(dispatch_home_fingerprint "$target")"
  printf 'model = "runtime-owned-rewrite"\n' >"$target/config.toml"
  [[ "$(dispatch_home_fingerprint "$target")" == "$dispatch_fingerprint" ]] \
    || { rm -rf "$temp_root"; fail "Codex dispatch fingerprint rejected a disposable config.toml rewrite"; }

  printf '{"token":"changed"}\n' >"$target/auth.json"
  [[ "$(dispatch_home_fingerprint "$target")" != "$dispatch_fingerprint" ]] \
    || { rm -rf "$temp_root"; fail "Codex dispatch fingerprint missed a disposable auth.json change"; }
  cp -p "$source/auth.json" "$target/auth.json"

  printf '{"fixture":false}\n' >"$target/config.json"
  [[ "$(dispatch_home_fingerprint "$target")" != "$dispatch_fingerprint" ]] \
    || { rm -rf "$temp_root"; fail "Codex dispatch fingerprint missed a disposable config.json change"; }
  cp -p "$source/config.json" "$target/config.json"

  printf 'developer_instructions = "changed"\n' >"$target/agents/oh-no-planner.toml"
  [[ "$(dispatch_home_fingerprint "$target")" != "$dispatch_fingerprint" ]] \
    || { rm -rf "$temp_root"; fail "Codex dispatch fingerprint missed a disposable agents-tree change"; }
  cp -p "$source/agents/oh-no-planner.toml" "$target/agents/oh-no-planner.toml"

  printf 'model = "active-source-change"\n' >"$source/config.toml"
  if assert_codex_live_home_provenance "$target" >/dev/null 2>&1; then
    rm -rf "$temp_root"
    fail "Codex live provenance accepted an active source config.toml change"
  fi
  printf 'model = "fixture"\n' >"$source/config.toml"
  assert_codex_live_home_provenance "$target"

  local unverified_home="$temp_root/unverified-home"
  mkdir -p "$unverified_home"
  printf 'model = "fixture"\n' >"$unverified_home/config.toml"
  if (run_codex_live_command "$unverified_home" true >/dev/null 2>&1); then
    rm -rf "$temp_root"
    fail "Codex live command runner accepted an unverified disposable home"
  fi

  local root_link_source="$temp_root/root-link-source"
  mkdir -p "$root_link_source"
  printf 'model = "fixture"\n' >"$root_link_source/config.toml"
  ln -s "$external_agents" "$root_link_source/agents"
  if (clone_codex_live_home "$root_link_source" "$target" >/dev/null 2>&1); then
    rm -rf "$temp_root"
    fail "Codex live clone accepted a symlinked active agents root"
  fi

  local nested_link_source="$temp_root/nested-link-source"
  mkdir -p "$nested_link_source/agents"
  printf 'model = "fixture"\n' >"$nested_link_source/config.toml"
  ln -s "$external_agents/sentinel" "$nested_link_source/agents/oh-no-planner.toml"
  if (clone_codex_live_home "$nested_link_source" "$target" >/dev/null 2>&1); then
    rm -rf "$temp_root"
    fail "Codex live clone accepted a symlink inside the active agents tree"
  fi

  [[ "$(cat "$external_agents/sentinel")" == "sentinel" ]] \
    || { rm -rf "$temp_root"; fail "Codex live clone safety test mutated the symlink target"; }
  rm -rf "$temp_root"
}

prepare_isolated_codex_live_home() {
  case "$FORCE_ISOLATED_CODEX_HOME" in
    0|1) ;;
    *) fail "OH_NO_ISOLATE_CODEX_HOME must be 0 or 1" ;;
  esac
  isolated_codex_live_home_requested || return 0

  CODEX_HOME_SOURCE_DIR="$CODEX_HOME_DIR"
  local temp_root
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-codex-live.XXXXXX")"
  CODEX_LIVE_TEMP_ROOTS+=("$temp_root")
  CODEX_HOME_DIR="$temp_root/codex-home"
  clone_codex_live_home "$CODEX_HOME_SOURCE_DIR" "$CODEX_HOME_DIR"

  log "Using isolated Codex live home cloned from the active runtime: $CODEX_HOME_SOURCE_DIR"
}

log() {
  printf '\n==> %s\n' "$*" >&2
}

ok() {
  printf 'ok - %s\n' "$*" >&2
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

assert_no_codex_live_secret_leak() {
  local auth_file="$1"
  shift
  "$PYTHON_BIN" - "$auth_file" "$@" <<'PY'
import hashlib
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlsplit

auth_path = Path(sys.argv[1])
roots = [Path(value) for value in sys.argv[2:]]
secret_key = re.compile(
    r"(?i)(?:^|[_-])(?:tokens?|keys?|secret|password|cookie|credential|bearer)(?:$|[_-])"
)
secret_patterns = (
    re.compile(r"(?<![A-Za-z0-9_-])sk-[A-Za-z0-9_-]{20,512}(?![A-Za-z0-9_-])"),
    re.compile(r"(?i)(api[_-]?key|access[_-]?token|refresh[_-]?token|id[_-]?token|session[_-]?token|private[_-]?key|secret|password|cookie|credential|bearer)\s*[:=]\s*['\"]?[A-Za-z0-9_./+=-]{12,}"),
)

secret_values = set()
if auth_path.is_file():
    try:
        auth = json.loads(auth_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SystemExit(f"unable to inspect isolated auth safely: {type(exc).__name__}")

    def collect(value, key=""):
        if isinstance(value, dict):
            for child_key, child in value.items():
                collect(child, str(child_key))
        elif isinstance(value, list):
            for child in value:
                collect(child, key)
        elif isinstance(value, str) and len(value) >= 12 and secret_key.search(key):
            secret_values.add(value)

    collect(auth)

targets = []
for root in roots:
    if root.is_file():
        targets.append(root)
    elif root.is_dir():
        targets.extend(path for path in root.rglob("*") if path.is_file())

diagnostic_labels = {
    "access_token", "session_token", "refresh_token", "id_token", "api_key",
    "password", "private_key", "authorization", "bearer", "token",
    "credential", "secret", "cookie",
}
json_path_labels = diagnostic_labels | {
    "type", "payload", "item", "content", "message", "text", "tool_output",
    "websiteUrl", "role", "name", "input", "output", "last_agent_message",
}
alphanumeric_run = re.compile(r"[A-Za-z0-9_]+")


def safe_structure(text):
    def replace(match):
        token = match.group(0)
        if token.lower() in diagnostic_labels:
            return token.lower()
        return f"<redacted:{len(token)}>"
    return alphanumeric_run.sub(replace, text)


def safe_json_key(key):
    return key if key in json_path_labels else f"<redacted:{len(key)}>"


def safe_metadata(value):
    if not isinstance(value, str):
        return None
    if (
        re.fullmatch(r"[A-Za-z][A-Za-z0-9_.-]{0,63}", value)
        and value not in secret_values
        and not any(pattern.search(value) for pattern in secret_patterns)
    ):
        return value
    return safe_structure(value)


def visible_line_parts(line):
    try:
        value = json.loads(line)
    except json.JSONDecodeError:
        return line, [("$", line)], None, None

    def redact_encrypted(item):
        if isinstance(item, dict):
            if item.get("type") == "encrypted_content":
                return {"type": "encrypted_content", "content": "<opaque>"}
            return {
                key: (
                    "<opaque>"
                    if key in {"ciphertext", "encrypted_content"}
                    else redact_encrypted(child)
                )
                for key, child in item.items()
            }
        if isinstance(item, list):
            return [redact_encrypted(child) for child in item]
        return item

    def collect_strings(item, path="$"):
        if isinstance(item, str):
            return [(path, item)]
        if isinstance(item, dict):
            result = []
            for key, child in item.items():
                child_path = f"{path}.{safe_json_key(str(key))}"
                result.extend(collect_strings(child, child_path))
            return result
        if isinstance(item, list):
            result = []
            for index, child in enumerate(item):
                result.extend(collect_strings(child, f"{path}[{index}]"))
            return result
        return []

    visible_value = redact_encrypted(value)
    payload = value.get("payload") if isinstance(value, dict) else None
    event_type = value.get("type") if isinstance(value, dict) else None
    payload_type = payload.get("type") if isinstance(payload, dict) else None
    return (
        json.dumps(visible_value, sort_keys=True),
        collect_strings(visible_value),
        safe_metadata(event_type),
        safe_metadata(payload_type),
    )


url_token_pattern = re.compile(r"(?i)(?<![A-Za-z0-9_])https?://[^\s<>\"'`]+")
def is_public_url_slug(text, match):
    if re.fullmatch(r"sk-(?:[a-z]+-){2,}[a-z]+", match.group(0)) is None:
        return False
    for url_match in url_token_pattern.finditer(text):
        token = url_match.group(0).rstrip(".,;:!?)]}")
        token_end = url_match.start() + len(token)
        if not (url_match.start() <= match.start() < match.end() <= token_end):
            continue
        parsed = urlsplit(token)
        if (
            parsed.scheme not in {"http", "https"}
            or not parsed.netloc
            or parsed.username is not None
            or parsed.password is not None
            or parsed.query
            or parsed.fragment
        ):
            return False
        path_start = token.find(parsed.path, len(parsed.scheme) + 3 + len(parsed.netloc))
        relative_start = match.start() - url_match.start()
        relative_end = match.end() - url_match.start()
        if path_start < 0 or not (
            path_start <= relative_start < relative_end <= path_start + len(parsed.path)
        ):
            return False
        left = token[relative_start - 1] if relative_start else ""
        right = token[relative_end] if relative_end < len(token) else ""
        return left == "/" and right in {"", "/"}
    return False


def emit_secret_diagnostic(
    path, line_number, event_type, payload_type, json_path, visible_text,
    detector_class, detector_index, match_start, match_length,
):
    urls = []
    for url_match in re.finditer(r"(?i)https?://[^\s<>\"'`]+", visible_text):
        token = url_match.group(0).rstrip(".,;:!?)]}")
        try:
            urls.append(urlsplit(token))
        except ValueError:
            pass
    context_start = max(0, match_start - 80)
    context_end = min(len(visible_text), match_start + match_length + 80)
    diagnostic = {
        "artifact": path.name,
        "line": line_number,
        "event_type": event_type,
        "payload_type": payload_type,
        "json_path": json_path,
        "detector_class": detector_class,
        "detector_index": detector_index,
        "match_start": match_start,
        "match_length": match_length,
        "string_length": len(visible_text),
        "sha256": hashlib.sha256(visible_text.encode("utf-8")).hexdigest(),
        "structural_context": safe_structure(visible_text[context_start:context_end]),
        "source_path_mention": bool(re.search(
            r"(?:^|[\s\"'])(?:/(?:Users|home|root|private|tmp|var)/|(?:scripts|plugins|backlog|docs|src|tests)/)",
            visible_text,
        )),
        "diff_marker": bool(re.search(r"(?m)^(?:diff --git |[+-]{3} |[+-](?![+-]))", visible_text)),
        "url_scheme": bool(re.search(r"(?i)https?://", visible_text)),
        "url_query": any(bool(parsed.query) for parsed in urls),
        "url_userinfo": any(parsed.username is not None or parsed.password is not None for parsed in urls),
    }
    print(
        "SAFE_SECRET_DIAGNOSTIC " + json.dumps(diagnostic, sort_keys=True, separators=(",", ":")),
        file=sys.stderr,
    )
    raise SystemExit(1)


for path in targets:
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError as exc:
        raise SystemExit(f"unable to inspect live artifact safely: {path.name}: {type(exc).__name__}")
    for line_number, line in enumerate(lines, 1):
        visible_line, visible_strings, event_type, payload_type = visible_line_parts(line)
        exact_candidates = []
        for traversal_index, (json_path, visible_text) in enumerate(visible_strings):
            for value in secret_values:
                start = visible_text.find(value)
                if start >= 0:
                    exact_candidates.append((traversal_index, start, value, json_path, visible_text))
        if exact_candidates:
            _, start, value, json_path, visible_text = min(
                exact_candidates, key=lambda item: (item[0], item[1], item[2])
            )
            emit_secret_diagnostic(
                path, line_number, event_type, payload_type, json_path,
                visible_text, "exact-auth", "exact-auth", start, len(value),
            )
        serialized_exact = []
        for value in secret_values:
            start = visible_line.find(value)
            if start >= 0:
                serialized_exact.append((start, value))
        if serialized_exact:
            start, value = min(serialized_exact, key=lambda item: (item[0], item[1]))
            emit_secret_diagnostic(
                path, line_number, event_type, payload_type, "$<serialized>",
                visible_line, "exact-auth", "exact-auth", start, len(value),
            )
        for json_path, visible_text in visible_strings:
            for pattern_index, pattern in enumerate(secret_patterns, 1):
                for match in pattern.finditer(visible_text):
                    if pattern_index == 1 and is_public_url_slug(visible_text, match):
                        continue
                    emit_secret_diagnostic(
                        path, line_number, event_type, payload_type, json_path,
                        visible_text, "generic-pattern", f"pattern-{pattern_index}",
                        match.start(), match.end() - match.start(),
                    )
PY
}

codex_malformed_url_secret_fixture() {
  printf '%s%s%s\n' 'prefixhttps://example.invalid/' 's' 'k-task-app-hub-content-chain/privacy'
}

validate_codex_live_secret_scanner() {
  local temp_root auth_file safe_file safe_spawn_file safe_url_file encrypted_file leak_file fixture_source_file
  local diagnostic_file diagnostic_err
  local access_token id_token session_token private_key credential long_nonsecret generic_secret safe_suffix
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-codex-secret-scan.XXXXXX")"
  CODEX_LIVE_TEMP_ROOTS+=("$temp_root")
  auth_file="$temp_root/auth.json"
  safe_file="$temp_root/safe.jsonl"
  safe_spawn_file="$temp_root/safe-spawn.jsonl"
  safe_url_file="$temp_root/safe-url.jsonl"
  encrypted_file="$temp_root/encrypted.jsonl"
  leak_file="$temp_root/leak.jsonl"
  fixture_source_file="$temp_root/malformed-url-fixture-source.txt"
  diagnostic_file="$temp_root/scanner-diagnostic.jsonl"
  diagnostic_err="$temp_root/scanner-diagnostic.err"
  access_token="$(printf '%s%s-%024d' 'fixture-ac' 'cess' 0)"
  id_token="$(printf '%s%s-%024d' 'fixture-i' 'd' 1)"
  session_token="$(printf '%s%s-%024d' 'fixture-ses' 'sion' 2)"
  private_key="$(printf '%s%s-%024d' 'fixture-pri' 'vate' 3)"
  long_nonsecret="$(printf '%s%s%0600d' 's' 'k-' 4)"
  generic_secret="$(printf '%s%s%024d' 's' 'k-' 5)"
  safe_suffix="$(printf '%0396d' 6)"

  printf '{"access_token":"%s","id_token":"%s","session_token":"%s","private_key":"%s"}\n' \
    "$access_token" "$id_token" "$session_token" "$private_key" >"$auth_file"

  scanner_reject_with_safe_diagnostic() {
    local expected_detector="$1"
    local forbidden_value="$2"
    local expected_event="${3:-null}"
    local expected_payload="${4:-null}"
    local expected_url_scheme="${5:-false}"
    local rc=0
    : >"$diagnostic_err"
    assert_no_codex_live_secret_leak "$auth_file" "$leak_file" \
      >/dev/null 2>"$diagnostic_err" || rc=$?
    [[ "$rc" != "0" ]] || fail "Codex live secret scanner missed its credential fixture ($expected_detector)"
    "$PYTHON_BIN" - "$diagnostic_err" "$expected_detector" "$forbidden_value" \
      "$expected_event" "$expected_payload" "$expected_url_scheme" <<'PY' \
      || fail "Codex live secret scanner emitted an unsafe or incomplete diagnostic for $expected_detector"
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
expected_detector = sys.argv[2]
forbidden_value = sys.argv[3]
expected_event = None if sys.argv[4] == "null" else sys.argv[4]
expected_payload = None if sys.argv[5] == "null" else sys.argv[5]
expected_url_scheme = sys.argv[6] == "true"
lines = [line for line in path.read_text(encoding="utf-8").splitlines() if line]
if len(lines) != 1 or not lines[0].startswith("SAFE_SECRET_DIAGNOSTIC "):
    raise SystemExit("diagnostic must be one structured SAFE_SECRET_DIAGNOSTIC line")
payload = json.loads(lines[0].removeprefix("SAFE_SECRET_DIAGNOSTIC "))
required = {
    "artifact", "line", "event_type", "payload_type", "json_path",
    "detector_class", "detector_index", "match_start", "match_length",
    "string_length", "sha256", "structural_context", "source_path_mention",
    "diff_marker", "url_scheme", "url_query", "url_userinfo",
}
missing = sorted(required - payload.keys())
if missing:
    raise SystemExit(f"missing diagnostic fields: {missing}")
if payload["artifact"] != "leak.jsonl" or payload["line"] != 1:
    raise SystemExit("diagnostic artifact location is not deterministic")
if payload["detector_index"] != expected_detector:
    raise SystemExit(f"wrong detector index: {payload['detector_index']!r}")
if payload["event_type"] != expected_event or payload["payload_type"] != expected_payload:
    raise SystemExit(
        f"wrong parsed JSON types: event={payload['event_type']!r} payload={payload['payload_type']!r}"
    )
if payload["url_scheme"] is not expected_url_scheme:
    raise SystemExit(f"wrong URL-scheme context: {payload['url_scheme']!r}")
if not isinstance(payload["json_path"], str) or not payload["json_path"].startswith("$"):
    raise SystemExit("diagnostic JSON path is missing")
if payload["match_start"] < 0 or payload["match_length"] <= 0:
    raise SystemExit("diagnostic match bounds are invalid")
if payload["match_start"] + payload["match_length"] > payload["string_length"]:
    raise SystemExit("diagnostic match bounds exceed the visible string")
if len(payload["sha256"]) != 64 or any(ch not in "0123456789abcdef" for ch in payload["sha256"]):
    raise SystemExit("diagnostic SHA-256 is invalid")
if forbidden_value and forbidden_value in lines[0]:
    raise SystemExit("diagnostic preserved a raw synthetic credential")
if "<redacted:" not in payload["structural_context"]:
    raise SystemExit("diagnostic structural context did not redact non-allowlisted text")
for name in ("source_path_mention", "diff_marker", "url_scheme", "url_query", "url_userinfo"):
    if not isinstance(payload[name], bool):
        raise SystemExit(f"diagnostic context flag {name} is not boolean")
PY
    cp "$diagnostic_err" "$diagnostic_file"
    assert_no_codex_live_secret_leak "$auth_file" "$diagnostic_file" \
      || fail "Codex live secret scanner diagnostic triggered the production scanner"
  }

  assert_no_codex_live_secret_leak "$auth_file" "$SELF_PATH" \
    || fail "Codex live secret scanner source self-observation rejected the complete harness script"
  printf 'safe live artifact\nopaque=%s\n' "$long_nonsecret" >"$safe_file"
  assert_no_codex_live_secret_leak "$auth_file" "$safe_file" \
    || fail "Codex live secret scanner rejected its safe fixture"

  printf '{"type":"item.started","item":{"type":"spawn_agent","message":"risk-%s. task-%024d risk_sk-%024d"}}\n' \
    "$safe_suffix" 7 8 >"$safe_spawn_file"
  assert_no_codex_live_secret_leak "$auth_file" "$safe_spawn_file" \
    || fail "Codex live secret scanner rejected benign embedded task/risk tokens"

  printf '{"websiteUrl":"https://example.invalid/sk-task-app-hub-content-chain/privacy"}\n' \
    >"$safe_url_file"
  assert_no_codex_live_secret_leak "$auth_file" "$safe_url_file" \
    || fail "Codex live secret scanner rejected a public URL slug"
  printf '{"tool_output":"diff --git a/file b/file\\n+ policy: https://example.invalid/sk-task-app-hub-content-chain/privacy ; retained"}\n' \
    >"$safe_url_file"
  assert_no_codex_live_secret_leak "$auth_file" "$safe_url_file" \
    || fail "Codex live secret scanner rejected an embedded public URL slug"

  printf '{"type":"response_item","payload":{"type":"agent_message","content":[{"type":"encrypted_content","ciphertext":"%s-%s"}]}}\n' \
    "$generic_secret" "$access_token" >"$encrypted_file"
  assert_no_codex_live_secret_leak "$auth_file" "$encrypted_file" \
    || fail "Codex live secret scanner rejected opaque encrypted transcript content"

  printf 'visible=%s\n' "$generic_secret" >"$leak_file"
  # The visible secret-like fixture must fail and produce scanner-safe structure only.
  scanner_reject_with_safe_diagnostic "pattern-1" "$generic_secret"

  printf 'visible=%s%s-%024d\n' 's' 'k-proj' 9 >"$leak_file"
  if assert_no_codex_live_secret_leak "$auth_file" "$leak_file" >/dev/null 2>&1; then
    fail "Codex live secret scanner missed its visible project secret fixture"
  fi

  printf '{"type":"response_item","payload":{"type":"agent_message","message":"%s%s=fixture-%s%s-%024d"}}\n' \
    'pass' 'word' 'pass' 'word' 10 >"$leak_file"
  scanner_reject_with_safe_diagnostic \
    "pattern-2" "$(printf 'fixture-%s%s-%024d' 'pass' 'word' 10)" \
    "response_item" "agent_message"

  printf '{"websiteUrl":"https://example.invalid/?api_key=%s"}\n' "$generic_secret" >"$leak_file"
  if assert_no_codex_live_secret_leak "$auth_file" "$leak_file" >/dev/null 2>&1; then
    fail "Codex live secret scanner ignored a secret-like URL query value"
  fi

  printf '{"websiteUrl":"https://%s@example.invalid/privacy"}\n' "$generic_secret" >"$leak_file"
  if assert_no_codex_live_secret_leak "$auth_file" "$leak_file" >/dev/null 2>&1; then
    fail "Codex live secret scanner ignored userinfo credentials"
  fi

  declare -f codex_malformed_url_secret_fixture >"$fixture_source_file"
  assert_no_codex_live_secret_leak "$auth_file" "$fixture_source_file" \
    || fail "Codex live secret scanner fixture source self-observed as a live credential"
  printf '{"tool_output":"%s"}\n' "$(codex_malformed_url_secret_fixture)" >"$leak_file"
  # The malformed concatenated URL token must still fail while reporting URL context safely.
  scanner_reject_with_safe_diagnostic \
    "pattern-1" "$(codex_malformed_url_secret_fixture)" null null true

  for credential in "$access_token" "$id_token" "$session_token" "$private_key"; do
    printf 'larger-token=prefix%suffix\n' "$credential" >"$leak_file"
    scanner_reject_with_safe_diagnostic "exact-auth" "$credential"
  done
  rm -rf "$temp_root"
  ok "Codex live secret scanner rejects credential-bearing artifacts"
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

tree_manifest_digest() {
  local root="$1"
  "$PYTHON_BIN" - "$root" <<'PY'
import hashlib
import json
import stat
import sys
from pathlib import Path

root = Path(sys.argv[1])
if not root.is_absolute() or root.is_symlink() or not root.is_dir():
    raise SystemExit(f"manifest root must be an absolute, non-symlink directory: {root}")
entries = []
for path in sorted(root.rglob("*"), key=lambda item: item.relative_to(root).as_posix()):
    relative = path.relative_to(root).as_posix()
    info = path.lstat()
    mode = stat.S_IMODE(info.st_mode)
    if stat.S_ISLNK(info.st_mode):
        raise SystemExit(f"manifest tree must be symlink-free: {relative}")
    if stat.S_ISDIR(info.st_mode):
        entries.append([relative, "dir", mode, ""])
    elif stat.S_ISREG(info.st_mode):
        entries.append([relative, "file", mode, hashlib.sha256(path.read_bytes()).hexdigest()])
    else:
        raise SystemExit(f"manifest tree has unsupported entry: {relative}")
payload = json.dumps(entries, separators=(",", ":"), ensure_ascii=True).encode()
print(hashlib.sha256(payload).hexdigest())
PY
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

json_value() {
  "$PYTHON_BIN" - "$PLUGIN_ROOT/.codex-plugin/plugin.json" "$1" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)

value = data
for part in sys.argv[2].split("."):
    value = value[part]
print(value)
PY
}

# The plugin root the live run actually loads. Wrapper-activation evidence is
# bound to this exact directory, so a decoy tree or a stale prior-version cache
# root cannot stand in for it.
#
# Resolution is decided by MODE, never by candidate count. Counting candidates was
# wrong twice: a SOLE stale cached version was accepted merely because it was
# unambiguous (singularity is not identity), and a no-install run bound to the
# cache whenever one existed, even though such a run loads from its explicit
# plugin root. Both errors silently validate evidence against the wrong tree.
CODEX_ACTIVE_PLUGIN_ROOT=""
# Identity recorded by the actual install operation. This is the authority for
# install mode; the local PLUGIN_ROOT manifest is NOT, because the source checkout
# can be a different version than the installed tree.
CODEX_INSTALLED_PLUGIN_VERSION=""
codex_installed_version_file() { printf '%s\n' "$RUN_DIR/installed-plugin-version.txt"; }
codex_safe_version_component() {
  local value="$1"
  [[ "$value" != "." && "$value" != ".." && "$value" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]]
}
codex_installed_plugin_version() {
  if [[ -n "$CODEX_INSTALLED_PLUGIN_VERSION" ]]; then
    codex_safe_version_component "$CODEX_INSTALLED_PLUGIN_VERSION" || return 1
    printf '%s\n' "$CODEX_INSTALLED_PLUGIN_VERSION"; return 0
  fi
  local recorded value
  recorded="$(codex_installed_version_file)"
  # A whitespace-only file is NOT identity: `-s` accepts it, but stripping leaves an
  # empty version that would then be concatenated into a cache path.
  if [[ -s "$recorded" ]]; then
    value="$(tr -d '[:space:]' <"$recorded")"
    if [[ -n "$value" ]] && codex_safe_version_component "$value"; then
      CODEX_INSTALLED_PLUGIN_VERSION="$value"
      printf '%s\n' "$CODEX_INSTALLED_PLUGIN_VERSION"; return 0
    fi
  fi
  return 1
}
codex_active_plugin_root() {
  [[ -z "$CODEX_ACTIVE_PLUGIN_ROOT" ]] || { printf '%s\n' "$CODEX_ACTIVE_PLUGIN_ROOT"; return 0; }
  local cache_parent version selected resolved
  if [[ "$INSTALL_MODE" == "1" ]]; then
    # Install mode binds to the version the INSTALL reported. Falling back to the
    # local manifest under source/installed skew names the wrong tree: it either
    # misses entirely (source 2.2.0 vs installed 2.1.0) or, if a stale directory
    # happens to match, validates evidence against a tree the run never loaded.
    cache_parent="$CODEX_HOME_DIR/plugins/cache/$MARKETPLACE_NAME/$PLUGIN_NAME"
    version="$(codex_installed_plugin_version || true)"
    [[ -n "$version" ]] \
      || fail "Codex active plugin root needs the installed plugin version; none was recorded by the install operation at $(codex_installed_version_file)"
    [[ -f "$cache_parent/$version/skills/ralph/SKILL.md" ]] \
      || fail "Codex active plugin root missing for INSTALLED version $version under $cache_parent"
    selected="$cache_parent/$version"
    resolved="$("$PYTHON_BIN" - "$cache_parent" "$selected" <<'PY'
from pathlib import Path
import sys

parent = Path(sys.argv[1]).resolve()
selected = Path(sys.argv[2]).resolve()
if selected.parent != parent:
    raise SystemExit("installed plugin root escaped its cache parent")
print(selected)
PY
)" || fail "Codex active plugin root escaped cache parent $cache_parent"
  else
    # A source/no-install run loads from its explicit plugin root. A cache may also
    # exist from earlier runs; it is not what this run loads.
    [[ -f "$PLUGIN_ROOT/skills/ralph/SKILL.md" ]] \
      || fail "Codex active plugin root has no generated wrapper under $PLUGIN_ROOT"
    selected="$PLUGIN_ROOT"
    resolved="$("$PYTHON_BIN" -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve())' "$selected")"
  fi
  CODEX_ACTIVE_PLUGIN_ROOT="$resolved"
  printf '%s\n' "$CODEX_ACTIVE_PLUGIN_ROOT"
}

codex_begin_install_attempt() {
  CODEX_INSTALLED_PLUGIN_VERSION=""
  CODEX_ACTIVE_PLUGIN_ROOT=""
  rm -f \
    "$RUN_DIR/installed-plugin-version.txt" \
    "$RUN_DIR/installed-plugin-version.tmp" \
    "$RUN_DIR/post-install-plugin-read.json" \
    "$RUN_DIR/post-install-plugin-read.tmp"
}

codex_record_installed_identity() {
  local response_path="$1" record_path="$2"
  "$PYTHON_BIN" - "$response_path" "$record_path" <<'PY'
import json
import re
import sys
from pathlib import Path

response_path = Path(sys.argv[1])
record_path = Path(sys.argv[2])
try:
    response = json.loads(response_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as error:
    raise SystemExit(f"post-install plugin/read response was unreadable: {error}")
plugin = response.get("plugin") or {}
summary = plugin.get("summary") or {}
if summary.get("installed") is not True:
    raise SystemExit("post-install plugin/read did not report summary.installed=true")
installed_version = summary.get("localVersion")
if not isinstance(installed_version, str) or not installed_version.strip():
    raise SystemExit("post-install plugin/read returned no summary.localVersion")
installed_version = installed_version.strip()
if installed_version in {".", ".."} or re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._+-]*", installed_version) is None:
    raise SystemExit(f"post-install plugin/read returned unsafe localVersion: {installed_version!r}")
record_path.parent.mkdir(parents=True, exist_ok=True)
temp_record = record_path.with_name("installed-plugin-version.tmp")
try:
    temp_record.write_text(installed_version + "\n", encoding="utf-8")
    temp_record.replace(record_path)
finally:
    temp_record.unlink(missing_ok=True)
PY
}

assert_json_valid() {
  local path="$1"
  "$PYTHON_BIN" -m json.tool "$path" >/dev/null
  ok "valid JSON: ${path#$PLUGIN_ROOT/}"
}

validate_codex_manifest() {
  log "Validating Codex plugin manifest"
  assert_json_valid "$PLUGIN_ROOT/.codex-plugin/plugin.json"
  "$PYTHON_BIN" "$MARKETPLACE_ROOT/scripts/validate-plugin-files.py" "$MARKETPLACE_ROOT" "$PLUGIN_ROOT"

  local manifest_name manifest_version
  manifest_name="$(json_value name)"
  manifest_version="$(json_value version)"
  [[ "$manifest_name" == "$PLUGIN_NAME" ]] || fail "manifest name is ${manifest_name}, expected ${PLUGIN_NAME}"
  [[ "$manifest_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "manifest version is not semver: ${manifest_version}"
  ok "Codex manifest identity: ${manifest_name} ${manifest_version}"
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
        "Codex routing hook source contract failed:\n  - " + "\n  - ".join(problems)
    )
print("ok - Codex routing hook source preserves native-description asymmetry")
PY
}

validate_codex_hooks() {
  log "Validating Codex hook separation"
  validate_routing_hook_source_contract
  assert_json_valid "$PLUGIN_ROOT/hooks/hooks.json"
  bash -n "$PLUGIN_ROOT/hooks/session-start"

  local temp_data
  temp_data="$(mktemp -d)"
  local had_codex_home previous_codex_home
  had_codex_home=0
  previous_codex_home=""
  if [[ -n "${CODEX_HOME+x}" ]]; then
    had_codex_home=1
    previous_codex_home="$CODEX_HOME"
  fi
  export CODEX_HOME="$temp_data/codex-home"

  PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" session-start \
    >"$temp_data/session-start.json"
  "$PYTHON_BIN" - "$temp_data/session-start.json" "$PLUGIN_ROOT" <<'PY'
import json, re, sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
output = data.get("hookSpecificOutput", {})
if output.get("hookEventName") != "SessionStart":
    raise SystemExit("Codex SessionStart emitted the wrong hook event")
text = output.get("additionalContext", "")
if "Use native skill loading to read the relevant Oh No Harness skill when it applies." not in text:
    raise SystemExit("Codex SessionStart is missing compact native skill-loading guidance")
required = ["No-route lane", "Direct-edit lane",
    "A workflow name used only as the subject of analysis, explanation, comparison, or critique is not an invocation trigger.",
    "Route from the requested deliverable: an analysis report versus a plan or execution artifact.",
    "Child packet floor", "caller sends a proportional self-contained English packet", "purpose/outcome", "target role", "repo mutation/review/verify", "exact target/revision + result/revision binding", "scope/permissions/non-goals", "contract/acceptance", "evidence/output", "stop/escalation", "Initial independent review/verify/debug", "withholds maker conclusions", "expected verdicts", "sibling output", "preferred causes", "disclose only later for audit/clarification",
    "CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION",
    "sub-agents, delegation, and parallel agent work proactively",
    "explicit user request for eligible Oh No Harness workflow",
    "every in-scope subagent result is a workflow dependency",
    "wait to final status, capture it, and use it",
    "MUST NOT redo delegated work inline",
    "CODEX_ONLY_OH_NO_READONLY_EXPLORATION_DELEGATION",
    "simple read-only repository fact lookup prompts",
    "as many as the lookup needs and not capped at one",
    "you may dispatch the registered read-only oh-no-explore custom agent",
    "This lane is not for planning, debugging",
    "redact credential values",
    "first select the relevant Oh No Harness skill",
    "Custom-Agent Spawn Troubleshooting",
    "before fallback",
]
missing = [needle for needle in required if needle not in text]
if missing or text.count("Child packet floor:") != 1:
    raise SystemExit(f"Codex SessionStart routing/child-packet drift: missing={missing}, count={text.count('Child packet floor:')}")
for forbidden in ("Global Context Capsule", "Capsule delta", "_global-context-capsule.md", "Purpose\nAssigned outcome / acceptance criteria"):
    if forbidden in text: raise SystemExit(f"Codex SessionStart retains former receiver schema: {forbidden}")
match = re.search(r"read `([^`]+/docs/platforms/codex[.]md)` section", text)
if match is None:
    raise SystemExit("Codex SessionStart is missing the absolute troubleshooting-doc pointer")
actual_doc = Path(match.group(1)).resolve()
expected_doc = (Path(sys.argv[2]) / "docs/platforms/codex.md").resolve()
if actual_doc != expected_doc or not actual_doc.is_file():
    raise SystemExit(
        f"Codex SessionStart troubleshooting pointer does not resolve to the installed doc: "
        f"actual={actual_doc}, expected={expected_doc}"
    )
for forbidden in (
    "OH_NO_SKILL_CORE",
    "Below is the full content",
    "docs/skill-core/using-oh-no-harness.md",
    "Routing reminder:",
    "using-oh-no-harness",
    "Use oh-no-harness:test-driven-development only as an explicit TDD/test-first route",
):
    if forbidden in text:
        raise SystemExit(f"Codex SessionStart retains retired routing content: {forbidden}")
for forbidden in (
    "About to make a behavior-changing production edit: oh-no-harness:test-driven-development",
    "behavior-changing edits go through test-driven-development",
):
    if forbidden in text:
        raise SystemExit(f"Codex SessionStart still routes ordinary implementation to TDD: {forbidden}")
if len(text) > 5200:
    raise SystemExit(f"Codex SessionStart default context is too large: {len(text)} chars")
for forbidden in ("CLAUDE_CODE_ONLY", "AskUserQuestion"):
    if forbidden in text:
        raise SystemExit(f"Codex SessionStart leaked Claude-only policy: {forbidden}")
for forbidden in ("installed:", "unchanged:", "would install:", "Preflight output:"):
    if forbidden in text:
        raise SystemExit(f"Codex SessionStart leaked custom-agent installer output: {forbidden}")
PY

  local session_start_agent_count
  session_start_agent_count="$(find "$CODEX_HOME/agents" -maxdepth 1 -type f -name 'oh-no-*.toml' | wc -l | tr -d ' ')"
  [[ "$session_start_agent_count" == "9" ]] || fail "Codex SessionStart ensured ${session_start_agent_count} user-scope agents, expected 9"
  grep -q 'oh-no-harness-installed-plugin-version:' "$CODEX_HOME/agents/oh-no-code-reviewer.toml" \
    || fail "Codex SessionStart did not write installed plugin version marker"

  local routing_config_dir="$temp_data/config"
  OH_NO_CONFIG_DIR="$routing_config_dir" "$PLUGIN_ROOT/scripts/oh-no-config" path >"$temp_data/config-path.out"
  OH_NO_CONFIG_DIR="$routing_config_dir" "$PLUGIN_ROOT/scripts/oh-no-config" on >"$temp_data/config-on.out"
  PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" OH_NO_CONFIG_DIR="$routing_config_dir" "$PLUGIN_ROOT/hooks/run-hook.cmd" session-start \
    >"$temp_data/session-start-codex-routing-on.json"
  OH_NO_CONFIG_DIR="$routing_config_dir" "$PLUGIN_ROOT/scripts/oh-no-config" off >"$temp_data/config-off.out"
  "$PYTHON_BIN" - "$temp_data/session-start-codex-routing-on.json" "$routing_config_dir" \
    "$temp_data/config-path.out" "$temp_data/config-on.out" "$temp_data/config-off.out" \
    "$PLUGIN_ROOT/skills/auto-routing/SKILL.md" <<'PY'
import json
import re
import sys
from pathlib import Path

hook_path, root_arg, path_out, on_out, off_out, wrapper_path = sys.argv[1:]
text = json.loads(Path(hook_path).read_text(encoding="utf-8")).get("hookSpecificOutput", {}).get("additionalContext", "")
if "OH_NO_FORCED_ROUTING" in text:
    raise SystemExit("Codex SessionStart should not add forced routing when auto-routing is enabled")
root = Path(root_arg).resolve()
outputs = [Path(path).read_text(encoding="utf-8") for path in (path_out, on_out, off_out)]
reported = [Path(outputs[0].strip()).resolve()]
reported += [Path(re.search(r"(?m)^config: (.+)$", output).group(1)).resolve() for output in outputs[1:]]
if any(path != root / "config.json" for path in reported):
    raise SystemExit(f"Codex helper config path escaped disposable directory: {reported}")
state = json.loads((root / "config.json").read_text(encoding="utf-8"))
if state.get("autoRouting", {}).get("enabled") is not False:
    raise SystemExit("Codex helper off output did not leave the disposable state disabled")
forbidden = (r"\brestart\w*\b", r"\b(?:immediate(?:ly)?|current[- ]turn|activat(?:e[sd]?|ion)|takes? effect)\b", r"\bforced[- ]routing\b", r"\b(?:stronger|exhaustive)[- ]routing\b", r"\b(?:change\w* .*routing semantics|routing semantics .*change\w*)\b")
if any(re.search(pattern, "\n".join(outputs), re.I) for pattern in forbidden):
    raise SystemExit("Codex helper output overclaims activation or changed routing semantics")
wrapper = " ".join(Path(wrapper_path).read_text(encoding="utf-8").lower().split())
required = ("codex native skill loading remains the primary routing surface", "enabling it does not add forced routing", "does not change current routing semantics")
missing = [phrase for phrase in required if phrase not in wrapper]
if missing:
    raise SystemExit(f"generated Codex auto-routing wrapper is missing platform semantics: {missing}")
PY

  local blocked_session_home
  blocked_session_home="$temp_data/codex-home-session-blocked"
  mkdir -p "$blocked_session_home/agents"
  printf 'user owned\n' >"$blocked_session_home/agents/oh-no-code-reviewer.toml"
  CODEX_HOME="$blocked_session_home" PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" session-start \
    >"$temp_data/session-start-blocked.json"
  "$PYTHON_BIN" - "$temp_data/session-start-blocked.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
output = data.get("hookSpecificOutput", {})
if output.get("hookEventName") != "SessionStart":
    raise SystemExit("blocked Codex SessionStart emitted the wrong hook event")
text = output.get("additionalContext", "")
required = [
    "CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION",
    "Codex custom-agent ensure warning",
    "oh-no-* custom-agent dispatch remains the default",
    "prompt-embedded fallback requires confirmed unavailability",
    "no-skill read-only exploration may dispatch oh-no-explore",
    "MUST NOT call close_agent for a running or pending subagent",
    "spawned in-scope subagent results are workflow dependencies",
    "never use missing output as completion evidence",
]
missing = [needle for needle in required if needle not in text]
if missing:
    raise SystemExit(f"blocked Codex SessionStart missing compact fallback warning: {missing}")
for forbidden in ("Preflight stdout:", "Preflight stderr:", "installed:"):
    if forbidden in text:
        raise SystemExit(f"blocked Codex SessionStart warning is too verbose: {forbidden}")
PY
  [[ "$(cat "$blocked_session_home/agents/oh-no-code-reviewer.toml")" == "user owned" ]] \
    || fail "Codex SessionStart overwrote an unmarked user-owned agent file"

  local blocked_symlink_home
  blocked_symlink_home="$temp_data/codex-home-session-symlink"
  mkdir -p "$blocked_symlink_home/agents"
  ln -s "$blocked_symlink_home/agents/missing-target.toml" "$blocked_symlink_home/agents/oh-no-code-reviewer.toml"
  CODEX_HOME="$blocked_symlink_home" PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" session-start \
    >"$temp_data/session-start-symlink-blocked.json"
  "$PYTHON_BIN" - "$temp_data/session-start-symlink-blocked.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = data.get("hookSpecificOutput", {}).get("additionalContext", "")
required = [
    "CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION",
    "Codex custom-agent ensure warning",
    "oh-no-* custom-agent dispatch remains the default",
    "prompt-embedded fallback requires confirmed unavailability",
    "no-skill read-only exploration may dispatch oh-no-explore",
    "MUST NOT call close_agent for a running or pending subagent",
    "spawned in-scope subagent results are workflow dependencies",
    "never use missing output as completion evidence",
]
missing = [needle for needle in required if needle not in text]
if missing:
    raise SystemExit(f"symlink-blocked Codex SessionStart missing compact fallback warning: {missing}")
PY
  [[ -L "$blocked_symlink_home/agents/oh-no-code-reviewer.toml" ]] \
    || fail "Codex SessionStart replaced a non-regular symlink agent path"

  local temp_path
  temp_path="$temp_data/bin"
  mkdir -p "$temp_path"
  ln -s "$(command -v bash)" "$temp_path/bash"
  ln -s "$(command -v cat)" "$temp_path/cat"
  ln -s "$(command -v dirname)" "$temp_path/dirname"

  PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" OH_NO_CONFIG_DIR="$temp_data" PATH="$temp_path" "$PLUGIN_ROOT/hooks/run-hook.cmd" session-start \
    >"$temp_data/session-start-no-rg.json"
  "$PYTHON_BIN" - "$temp_data/session-start-no-rg.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
output = data.get("hookSpecificOutput", {})
text = output.get("additionalContext", "")
if "OH_NO_RG_SEARCH_TOOLING" in text:
    raise SystemExit("Codex SessionStart included rg guidance while rg is unavailable")
PY

  cat >"$temp_path/rg" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$temp_path/rg"

  PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" OH_NO_CONFIG_DIR="$temp_data" PATH="$temp_path" "$PLUGIN_ROOT/hooks/run-hook.cmd" session-start \
    >"$temp_data/session-start-with-rg.json"
  "$PYTHON_BIN" - "$temp_data/session-start-with-rg.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
output = data.get("hookSpecificOutput", {})
text = output.get("additionalContext", "")
if "OH_NO_RG_SEARCH_TOOLING" not in text:
    raise SystemExit("Codex SessionStart missed rg guidance while rg is available")
if "rg --files" not in text:
    raise SystemExit("Codex SessionStart rg guidance is missing rg --files")
PY

  if [[ "$had_codex_home" == "1" ]]; then
    export CODEX_HOME="$previous_codex_home"
  else
    unset CODEX_HOME
  fi
  rm -rf "$temp_data"
  ok "Codex SessionStart is the only configured plugin hook"
}

validate_codex_agent_installer() {
  log "Validating optional Codex custom-agent installer"

  local installer="$PLUGIN_ROOT/scripts/install-codex-agents"
  sh -n "$installer"

  local temp_data dry_run_count installed_count project_dry_run_count remaining_count force_status manifest_version
  local ensure_count quiet_size conflict_status
  temp_data="$(mktemp -d)"
  manifest_version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN_ROOT/.codex-plugin/plugin.json" | head -n 1)"

  CODEX_HOME="$temp_data/codex-home" "$installer" --dry-run >"$temp_data/default-user-dry-run.out"
  dry_run_count="$(grep -c '^would install: ' "$temp_data/default-user-dry-run.out")"
  [[ "$dry_run_count" == "9" ]] || fail "Codex agent default user dry-run planned ${dry_run_count} installs, expected 9"
  grep -q "$temp_data/codex-home/agents/oh-no-code-reviewer.toml" "$temp_data/default-user-dry-run.out" \
    || fail "Codex agent default install did not target CODEX_HOME user scope"

  env -u CODEX_HOME HOME="$temp_data/home-default" "$installer" --dry-run >"$temp_data/home-default-dry-run.out"
  dry_run_count="$(grep -c '^would install: ' "$temp_data/home-default-dry-run.out")"
  [[ "$dry_run_count" == "9" ]] || fail "Codex agent HOME fallback dry-run planned ${dry_run_count} installs, expected 9"
  grep -q "$temp_data/home-default/.codex/agents/oh-no-code-reviewer.toml" "$temp_data/home-default-dry-run.out" \
    || fail "Codex agent default install did not target HOME fallback user scope"

  "$installer" --scope project --dry-run >"$temp_data/project-dry-run.out"
  project_dry_run_count="$(grep -c '^would install: ' "$temp_data/project-dry-run.out")"
  [[ "$project_dry_run_count" == "9" ]] || fail "Codex agent project dry-run planned ${project_dry_run_count} installs, expected 9"

  CODEX_HOME="$temp_data/ensure-home" "$installer" --scope user --ensure --quiet \
    >"$temp_data/ensure-install.out" 2>"$temp_data/ensure-install.err"
  quiet_size="$(wc -c <"$temp_data/ensure-install.out" | tr -d ' ')"
  [[ "$quiet_size" == "0" ]] || fail "Codex agent --ensure --quiet wrote success stdout"
  quiet_size="$(wc -c <"$temp_data/ensure-install.err" | tr -d ' ')"
  [[ "$quiet_size" == "0" ]] || fail "Codex agent --ensure --quiet wrote success stderr"
  ensure_count="$(find "$temp_data/ensure-home/agents" -type f -name 'oh-no-*.toml' | wc -l | tr -d ' ')"
  [[ "$ensure_count" == "9" ]] || fail "Codex agent --ensure wrote ${ensure_count} templates, expected 9"

  CODEX_HOME="$temp_data/ensure-home" "$installer" --scope user --ensure --quiet \
    >"$temp_data/ensure-current.out" 2>"$temp_data/ensure-current.err"
  quiet_size="$(wc -c <"$temp_data/ensure-current.out" | tr -d ' ')"
  [[ "$quiet_size" == "0" ]] || fail "Codex agent current --ensure --quiet wrote stdout"
  quiet_size="$(wc -c <"$temp_data/ensure-current.err" | tr -d ' ')"
  [[ "$quiet_size" == "0" ]] || fail "Codex agent current --ensure --quiet wrote stderr"

  {
    printf '# oh-no-harness-installed-plugin-version: 0.0.0\n'
    printf '# oh-no-harness-generated-codex-agent\n'
    printf 'name = "oh-no-code-reviewer"\n'
    printf 'description = "stale generated file"\n'
    printf 'developer_instructions = "stale"\n'
  } >"$temp_data/ensure-home/agents/oh-no-code-reviewer.toml"
  CODEX_HOME="$temp_data/ensure-home" "$installer" --scope user --ensure --quiet \
    >"$temp_data/ensure-stale.out" 2>"$temp_data/ensure-stale.err"
  grep -q "oh-no-harness-installed-plugin-version: ${manifest_version}" "$temp_data/ensure-home/agents/oh-no-code-reviewer.toml" \
    || fail "Codex agent --ensure did not refresh stale plugin version marker"
  grep -q '# Code Reviewer Agent' "$temp_data/ensure-home/agents/oh-no-code-reviewer.toml" \
    || fail "Codex agent --ensure did not refresh stale agent prompt content"
  quiet_size="$(wc -c <"$temp_data/ensure-stale.out" | tr -d ' ')"
  [[ "$quiet_size" == "0" ]] || fail "Codex agent stale --ensure --quiet wrote stdout"
  quiet_size="$(wc -c <"$temp_data/ensure-stale.err" | tr -d ' ')"
  [[ "$quiet_size" == "0" ]] || fail "Codex agent stale --ensure --quiet wrote stderr"

  {
    printf '# oh-no-harness-installed-plugin-version: 1.1.11\n'
    printf '# oh-no-harness-generated-codex-agent\n'
    printf 'name = "oh-no-cleanup-reuse"\n'
    printf 'description = "retired generated cleanup file"\n'
    printf 'developer_instructions = "retired"\n'
  } >"$temp_data/ensure-home/agents/oh-no-cleanup-reuse.toml"
  printf 'user owned\n' >"$temp_data/ensure-home/agents/oh-no-user-owned-extra.toml"
  CODEX_HOME="$temp_data/ensure-home" "$installer" --scope user --ensure --quiet \
    >"$temp_data/ensure-retired.out" 2>"$temp_data/ensure-retired.err"
  [[ ! -e "$temp_data/ensure-home/agents/oh-no-cleanup-reuse.toml" ]] \
    || fail "Codex agent --ensure left retired generated cleanup agent"
  [[ "$(cat "$temp_data/ensure-home/agents/oh-no-user-owned-extra.toml")" == "user owned" ]] \
    || fail "Codex agent --ensure removed or changed an unmarked extra user agent"
  quiet_size="$(wc -c <"$temp_data/ensure-retired.out" | tr -d ' ')"
  [[ "$quiet_size" == "0" ]] || fail "Codex agent retired --ensure --quiet wrote stdout"
  quiet_size="$(wc -c <"$temp_data/ensure-retired.err" | tr -d ' ')"
  [[ "$quiet_size" == "0" ]] || fail "Codex agent retired --ensure --quiet wrote stderr"

  mkdir -p "$temp_data/ensure-conflict/agents"
  printf 'user owned\n' >"$temp_data/ensure-conflict/agents/oh-no-code-reviewer.toml"
  set +e
  CODEX_HOME="$temp_data/ensure-conflict" "$installer" --scope user --ensure --quiet \
    >"$temp_data/ensure-conflict.out" 2>"$temp_data/ensure-conflict.err"
  conflict_status=$?
  set -e
  [[ "$conflict_status" != "0" ]] || fail "Codex agent --ensure succeeded despite unmarked conflict"
  grep -q 'skip unmarked existing:' "$temp_data/ensure-conflict.err" \
    || fail "Codex agent --ensure did not report unmarked conflict"
  [[ "$(cat "$temp_data/ensure-conflict/agents/oh-no-code-reviewer.toml")" == "user owned" ]] \
    || fail "Codex agent --ensure changed an unmarked user-owned file"

  mkdir -p "$temp_data/ensure-symlink/agents"
  ln -s "$temp_data/ensure-symlink/agents/missing-target.toml" "$temp_data/ensure-symlink/agents/oh-no-code-reviewer.toml"
  set +e
  CODEX_HOME="$temp_data/ensure-symlink" "$installer" --scope user --ensure --quiet \
    >"$temp_data/ensure-symlink.out" 2>"$temp_data/ensure-symlink.err"
  conflict_status=$?
  set -e
  [[ "$conflict_status" != "0" ]] || fail "Codex agent --ensure succeeded despite symlink conflict"
  grep -q 'skip non-regular existing:' "$temp_data/ensure-symlink.err" \
    || fail "Codex agent --ensure did not report symlink conflict"
  [[ -L "$temp_data/ensure-symlink/agents/oh-no-code-reviewer.toml" ]] \
    || fail "Codex agent --ensure replaced a symlink conflict"

  mkdir -p "$temp_data/ensure-directory/agents/oh-no-code-reviewer.toml"
  set +e
  CODEX_HOME="$temp_data/ensure-directory" "$installer" --scope user --ensure --quiet \
    >"$temp_data/ensure-directory.out" 2>"$temp_data/ensure-directory.err"
  conflict_status=$?
  set -e
  [[ "$conflict_status" != "0" ]] || fail "Codex agent --ensure succeeded despite directory conflict"
  grep -q 'skip non-regular existing:' "$temp_data/ensure-directory.err" \
    || fail "Codex agent --ensure did not report directory conflict"
  [[ -d "$temp_data/ensure-directory/agents/oh-no-code-reviewer.toml" ]] \
    || fail "Codex agent --ensure replaced a directory conflict"

  CODEX_HOME="$temp_data/codex-home" "$installer" >"$temp_data/user-install.out"
  installed_count="$(find "$temp_data/codex-home/agents" -type f -name 'oh-no-*.toml' | wc -l | tr -d ' ')"
  [[ "$installed_count" == "9" ]] || fail "Codex agent user install wrote ${installed_count} templates, expected 9"
  grep -q "oh-no-harness-installed-plugin-version: ${manifest_version}" "$temp_data/codex-home/agents/oh-no-code-reviewer.toml" \
    || fail "Codex agent user install did not write the current plugin version marker"
  grep -q 'model = "gpt-5.6-sol"' "$temp_data/codex-home/agents/oh-no-code-reviewer.toml" \
    || fail "Codex agent user install did not write the Sol reviewer model"
  grep -q 'model_reasoning_effort = "xhigh"' "$temp_data/codex-home/agents/oh-no-code-reviewer.toml" \
    || fail "Codex agent user install did not write the reviewer reasoning effort"
  grep -q 'sandbox_mode = "read-only"' "$temp_data/codex-home/agents/oh-no-code-reviewer.toml" \
    || fail "Codex agent user install did not write the read-only sandbox for code-reviewer"
  grep -q 'model = "gpt-5.6-terra"' "$temp_data/codex-home/agents/oh-no-explore.toml" \
    || fail "Codex agent user install did not write the Terra explore model"
  grep -q 'model_reasoning_effort = "medium"' "$temp_data/codex-home/agents/oh-no-explore.toml" \
    || fail "Codex agent user install did not write the explore reasoning effort"
  grep -q 'model_reasoning_effort = "high"' "$temp_data/codex-home/agents/oh-no-analyst.toml" \
    || fail "Codex agent user install did not write the analyst reasoning effort"
  grep -q 'model_reasoning_effort = "high"' "$temp_data/codex-home/agents/oh-no-executor.toml" \
    || fail "Codex agent user install did not write the executor reasoning effort"
  grep -q 'sandbox_mode = "read-only"' "$temp_data/codex-home/agents/oh-no-explore.toml" \
    || fail "Codex agent user install did not write the read-only sandbox for explore"
  {
    printf '# oh-no-harness-installed-plugin-version: 0.0.0\n'
    printf '# oh-no-harness-generated-codex-agent\n'
    printf 'name = "oh-no-code-reviewer"\n'
    printf 'description = "stale generated file"\n'
    printf 'developer_instructions = "stale"\n'
  } >"$temp_data/codex-home/agents/oh-no-code-reviewer.toml"
  CODEX_HOME="$temp_data/codex-home" "$installer" --force >"$temp_data/user-reinstall.out"
  grep -q "oh-no-harness-installed-plugin-version: ${manifest_version}" "$temp_data/codex-home/agents/oh-no-code-reviewer.toml" \
    || fail "Codex agent user reinstall did not refresh stale plugin version marker"
  grep -q '# Code Reviewer Agent' "$temp_data/codex-home/agents/oh-no-code-reviewer.toml" \
    || fail "Codex agent user reinstall did not refresh stale agent prompt content"
  {
    printf '# oh-no-harness-installed-plugin-version: 1.1.11\n'
    printf '# oh-no-harness-generated-codex-agent\n'
    printf 'name = "oh-no-cleanup-altitude"\n'
    printf 'description = "retired generated cleanup file"\n'
    printf 'developer_instructions = "retired"\n'
  } >"$temp_data/codex-home/agents/oh-no-cleanup-altitude.toml"
  CODEX_HOME="$temp_data/codex-home" "$installer" --remove >"$temp_data/user-remove.out"
  remaining_count="$(find "$temp_data/codex-home" -type f | wc -l | tr -d ' ')"
  [[ "$remaining_count" == "0" ]] || fail "Codex agent user remove left ${remaining_count} files"

  mkdir -p "$temp_data/home-unmarked/agents"
  printf 'user owned\n' >"$temp_data/home-unmarked/agents/oh-no-code-reviewer.toml"
  set +e
  CODEX_HOME="$temp_data/home-unmarked" "$installer" --scope user --force \
    >"$temp_data/unmarked-force.out" 2>"$temp_data/unmarked-force.err"
  force_status=$?
  set -e
  [[ "$force_status" != "0" ]] || fail "Codex agent installer overwrote an unmarked file with --force"
  grep -q 'skip unmarked existing:' "$temp_data/unmarked-force.err" \
    || fail "Codex agent installer did not report unmarked overwrite protection"
  [[ "$(cat "$temp_data/home-unmarked/agents/oh-no-code-reviewer.toml")" == "user owned" ]] \
    || fail "Codex agent installer changed an unmarked user-owned file"

  rm -rf "$temp_data"
  ok "Codex custom-agent installer installs, removes, and protects unmarked files"
}

codex_marketplace_exists() {
  CODEX_HOME="$CODEX_HOME_DIR" "$CODEX_BIN" plugin marketplace list --json \
    | "$PYTHON_BIN" -c 'import json, sys
name = sys.argv[1]
data = json.load(sys.stdin)
for item in data.get("marketplaces", []):
    if item.get("name") == name:
        sys.exit(0)
sys.exit(1)
' "$MARKETPLACE_NAME"
}

install_codex_agents_user_scope() {
  [[ "$INSTALL_MODE" == "1" ]] || { log "Skipping Codex custom-agent user-scope install (--no-install)"; return; }

  log "Installing optional Codex custom agents into user scope"
  mkdir -p "$RUN_DIR" "$CODEX_HOME_DIR"

  local out_file="$RUN_DIR/codex-agents-user-install.out"
  local err_file="$RUN_DIR/codex-agents-user-install.err"
  CODEX_HOME="$CODEX_HOME_DIR" "$PLUGIN_ROOT/scripts/install-codex-agents" --scope user --ensure --quiet \
    >"$out_file" 2>"$err_file" || {
      cat "$err_file" >&2
      fail "Codex custom-agent user-scope install failed"
    }

  local installed_count
  installed_count="$(find "$CODEX_HOME_DIR/agents" -maxdepth 1 -type f -name 'oh-no-*.toml' | wc -l | tr -d ' ')"
  [[ "$installed_count" == "9" ]] || fail "Codex custom-agent user-scope install wrote ${installed_count} templates, expected 9"
  ok "Codex custom agents installed into ${CODEX_HOME_DIR}/agents"
}

install_via_codex_plugins() {
  [[ "$INSTALL_MODE" == "1" ]] || { log "Skipping Codex marketplace install (--no-install)"; return; }

  mkdir -p "$RUN_DIR" "$CODEX_HOME_DIR"
  # LIFECYCLE: destroy prior on-disk and in-memory identity before the first
  # fallible install action. RUN_DIR can be reused, so a failed retry must never
  # expose identity from an earlier successful attempt.
  codex_begin_install_attempt

  log "Registering marketplace through Codex CLI"
  if codex_marketplace_exists; then
    CODEX_HOME="$CODEX_HOME_DIR" "$CODEX_BIN" plugin marketplace remove "$MARKETPLACE_NAME" >/dev/null
  fi
  CODEX_HOME="$CODEX_HOME_DIR" "$CODEX_BIN" plugin marketplace add "$MARKETPLACE_SOURCE"
  ok "Codex marketplace registered from ${MARKETPLACE_SOURCE}"

  log "Installing through Codex /plugins app-server path"
  local app_log="$RUN_DIR/app-server-plugin-install.jsonl"
  local app_err="$RUN_DIR/app-server-plugin-install.err"

  "$PYTHON_BIN" - \
    "$CODEX_BIN" \
    "$CODEX_HOME_DIR" \
    "$MARKETPLACE_SOURCE" \
    "$PLUGIN_NAME" \
    "$MARKETPLACE_NAME" \
    "$app_log" \
    "$app_err" \
    "${PUBLIC_SKILLS[@]}" <<'PY'
from __future__ import annotations

import json
import os
import queue
import subprocess
import sys
import threading
import time
from pathlib import Path

codex_bin, codex_home, marketplace_source, plugin_name, marketplace_name, app_log, app_err, *skills = sys.argv[1:]
plugin_id = f"{plugin_name}@{marketplace_name}"

env = os.environ.copy()
env["CODEX_HOME"] = codex_home

proc = subprocess.Popen(
    [codex_bin, "app-server", "--listen", "stdio://", "--enable", "remote_plugin"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    bufsize=1,
    env=env,
)

stdout_queue: queue.Queue[str | None] = queue.Queue()
stderr_lines: list[str] = []
log_path = Path(app_log)
err_path = Path(app_err)


def read_stdout() -> None:
    if proc.stdout is None: raise RuntimeError("Codex app-server stdout pipe was not created")
    with log_path.open("w", encoding="utf-8") as log:
        for line in proc.stdout:
            log.write(line)
            log.flush()
            stdout_queue.put(line)
    stdout_queue.put(None)


def read_stderr() -> None:
    if proc.stderr is None: raise RuntimeError("Codex app-server stderr pipe was not created")
    with err_path.open("w", encoding="utf-8") as err:
        for line in proc.stderr:
            stderr_lines.append(line)
            err.write(line)
            err.flush()


threading.Thread(target=read_stdout, daemon=True).start()
threading.Thread(target=read_stderr, daemon=True).start()


def fail(message: str) -> None:
    try:
        if proc.stdin:
            proc.stdin.close()
    finally:
        proc.terminate()
    raise SystemExit(message)


def send(message: dict) -> None:
    if proc.stdin is None:
        fail("app-server stdin is closed")
    proc.stdin.write(json.dumps(message, separators=(",", ":")) + "\n")
    proc.stdin.flush()


def wait_response(request_id: int, timeout: float = 60.0) -> dict:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        remaining = max(0.1, deadline - time.monotonic())
        try:
            line = stdout_queue.get(timeout=min(0.5, remaining))
        except queue.Empty:
            if proc.poll() is not None:
                fail(f"app-server exited before response id={request_id}; stderr={''.join(stderr_lines)!r}")
            continue
        if line is None:
            fail(f"app-server stdout closed before response id={request_id}; stderr={''.join(stderr_lines)!r}")
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        if payload.get("id") == request_id:
            if "error" in payload:
                fail(f"app-server request id={request_id} failed: {payload['error']}")
            return payload["result"]
    fail(f"timed out waiting for app-server response id={request_id}; stderr={''.join(stderr_lines)!r}")


send(
    {
        "id": 1,
        "method": "initialize",
        "params": {
            "clientInfo": {"name": "oh-no-harness-test", "title": None, "version": "0"},
            "capabilities": {"experimentalApi": True},
        },
    }
)
wait_response(1, timeout=30.0)
send({"method": "initialized"})

# Give the app-server time to load configured marketplaces. This mirrors the
# TUI startup path before the user opens /plugins.
time.sleep(4.0)

send({"id": 2, "method": "plugin/list", "params": {"cwds": None, "marketplaceKinds": None}})
plugin_list = wait_response(2, timeout=60.0)

marketplaces = plugin_list.get("marketplaces", [])
marketplace = next((item for item in marketplaces if item.get("name") == marketplace_name), None)
if marketplace is None:
    names = [item.get("name") for item in marketplaces]
    fail(f"{marketplace_name} marketplace was not listed by plugin/list; listed={names!r}")

summary = next((item for item in marketplace.get("plugins", []) if item.get("id") == plugin_id), None)
if summary is None:
    fail(f"{plugin_id} was not listed in marketplace {marketplace_name}")
if summary.get("installPolicy") != "AVAILABLE":
    fail(f"{plugin_id} installPolicy={summary.get('installPolicy')!r}, expected AVAILABLE")
if summary.get("availability") != "AVAILABLE":
    fail(f"{plugin_id} availability={summary.get('availability')!r}, expected AVAILABLE")
marketplace_path = marketplace.get("path")
if not marketplace_path:
    fail(f"{marketplace_name} marketplace did not include a marketplace path")

send(
    {
        "id": 3,
        "method": "plugin/read",
        "params": {"marketplacePath": marketplace_path, "remoteMarketplaceName": None, "pluginName": plugin_name},
    }
)
plugin_read = wait_response(3, timeout=60.0)
detail = plugin_read["plugin"]
# NOTE: this is a PRE-INSTALL read. Its version describes what the marketplace
# OFFERS, not what got installed, so it must never be recorded as installed
# identity. The authoritative record is written after plugin/install succeeds.
actual_skills = [skill["name"] for skill in detail.get("skills", [])]
expected_skills = [f"{plugin_name}:{skill}" for skill in skills]
missing_skills = [skill for skill in expected_skills if skill not in actual_skills]
if missing_skills:
    fail(f"plugin/read missing public skills: {missing_skills}; actual={actual_skills}")

send(
    {
        "id": 4,
        "method": "plugin/install",
        "params": {"marketplacePath": marketplace_path, "remoteMarketplaceName": None, "pluginName": plugin_name},
    }
)
install = wait_response(4, timeout=60.0)
if install.get("authPolicy") != "ON_INSTALL":
    fail(f"plugin/install authPolicy={install.get('authPolicy')!r}, expected ON_INSTALL")

# AUTHORITATIVE INSTALLED IDENTITY, obtained only AFTER the install succeeded.
# Order matters: a pre-install read describes the offer, not the installed tree.
# Only the forced-refresh post-install read is bound to this completed operation.
# Existing cache directories are never identity evidence, even when one looks valid.
send(
    {
        "id": 5,
        "method": "plugin/read",
        "params": {
            "marketplacePath": marketplace_path,
            "remoteMarketplaceName": None,
            "pluginName": plugin_name,
            "forceReload": True,
        },
    }
)
post_install = wait_response(5, timeout=60.0)
post_install_path = Path(app_log).with_name("post-install-plugin-read.json")
post_install_temp = post_install_path.with_name("post-install-plugin-read.tmp")
post_install_temp.write_text(json.dumps(post_install, separators=(",", ":")), encoding="utf-8")
post_install_temp.replace(post_install_path)

if proc.stdin:
    proc.stdin.close()
try:
    proc.wait(timeout=10)
except subprocess.TimeoutExpired:
    proc.terminate()
    proc.wait(timeout=5)

PY
  codex_record_installed_identity \
    "$RUN_DIR/post-install-plugin-read.json" \
    "$RUN_DIR/installed-plugin-version.txt" \
    || fail "Codex post-install identity response was invalid"
  ok "Codex CLI marketplace add plus /plugins lists and installs ${PLUGIN_ID} from ${MARKETPLACE_SOURCE}"
}

assert_codex_prompt_exposes_skills() {
  if [[ "$INSTALL_MODE" != "1" ]]; then
    log "Skipping Codex prompt exposure check (--no-install)"
    printf 'Run without --no-install to install this checkout and verify prompt exposure for all public skills.\n' >&2
    return
  fi

  log "Verifying Codex prompt exposes oh-no-harness skills"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/prompt-input.json"

  CODEX_HOME="$CODEX_HOME_DIR" "$CODEX_BIN" debug prompt-input "Oh No Harness smoke prompt." >"$out_file"

  "$PYTHON_BIN" - "$out_file" "$PLUGIN_NAME" "${PUBLIC_SKILLS[@]}" <<'PY'
import json
import sys

path = sys.argv[1]
plugin_name = sys.argv[2]
skills = sys.argv[3:]

with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

text = "\n".join(
    item.get("text", "")
    for message in data
    for item in message.get("content", [])
    if item.get("type") == "input_text"
)

missing = []
for skill in skills:
    needle = f"{plugin_name}:{skill}"
    if needle not in text:
        missing.append(needle)

if missing:
    raise SystemExit(f"missing Codex skill exposure: {', '.join(missing)}")

if "CLAUDE_CODE_ONLY" in text or "AskUserQuestion" in text:
    raise SystemExit("Claude-only hook policy leaked into Codex prompt")

print(f"ok - Codex prompt exposes {len(skills)} public oh-no-harness skills")
PY
}

direct_invariant_for_skill() {
  case "$1" in
    interview) printf 'clarify-before-planning' ;;
    ralplan) printf 'wait-for-user-approval' ;;
    ralph) printf 'require-acceptance-contract' ;;
    ultrawork) printf 'wait-for-spec-approval' ;;
    auto-routing) printf 'future-session-guidance-only' ;;
    test-driven-development) printf 'create-red-first' ;;
    simplify) printf 'lock-behavior-then-combined-scan' ;;
    verification-before-completion) printf 'withhold-completion' ;;
    systematic-debugging) printf 'reproduce-first' ;;
    *) fail "No direct invariant for skill: $1" ;;
  esac
}

direct_prompt_for_skill() {
  case "$1" in
    interview) printf '$%s:interview A request says only "improve this tool" and omits users and constraints. Apply the directly invoked installed skill. Choose exactly one: clarify-before-planning | plan-now.' "$PLUGIN_NAME" ;;
    ralplan) printf '$%s:ralplan A reviewed plan is ready but required user approval is pending. Apply the directly invoked installed skill. Choose exactly one: wait-for-user-approval | execute-now.' "$PLUGIN_NAME" ;;
    ralph) printf '$%s:ralph The task has no usable acceptance contract. Apply the directly invoked installed skill. Choose exactly one: require-acceptance-contract | execute-without-contract.' "$PLUGIN_NAME" ;;
    ultrawork) printf '$%s:ultrawork Requirements remain unclear and spec-content approval has not occurred. Apply the directly invoked installed skill. Choose exactly one: wait-for-spec-approval | begin-autonomous-execution.' "$PLUGIN_NAME" ;;
    auto-routing) printf '$%s:auto-routing The stored preference is changed during this turn. Apply the directly invoked installed skill. Choose exactly one: future-session-guidance-only | changes-current-turn.' "$PLUGIN_NAME" ;;
    test-driven-development) printf '$%s:test-driven-development A test-first change has no failing focused test yet. Apply the directly invoked installed skill. Choose exactly one: create-red-first | edit-production-first.' "$PLUGIN_NAME" ;;
    simplify) printf '$%s:simplify No behavior lock exists and no named THOROUGH expansion trigger is present. Apply the directly invoked installed skill. Choose exactly one: lock-behavior-then-combined-scan | run-four-way-cleanup-now.' "$PLUGIN_NAME" ;;
    verification-before-completion) printf '$%s:verification-before-completion One required acceptance criterion lacks direct evidence. Apply the directly invoked installed skill. Choose exactly one: withhold-completion | claim-complete.' "$PLUGIN_NAME" ;;
    systematic-debugging) printf '$%s:systematic-debugging A failing test has an unknown cause and has not been reproduced. Apply the directly invoked installed skill. Choose exactly one: reproduce-first | patch-first.' "$PLUGIN_NAME" ;;
    *) fail "No direct prompt for skill: $1" ;;
  esac
  printf ' Do not execute the workflow, dispatch, create artifacts, run commands, or change files. Reply with exactly two lines: `Skill: %s` and `Invariant: <one listed choice>`.' "$1"
}

direct_smoke_failure_class() {
  local rc="$1" evidence_file="$2"
  if grep -Eiq 'unknown[[:space:]:-]+(command|option|argument|skill|invocation)|unexpected[[:space:]]+argument|unrecognized[[:space:]]+(option|argument)|invalid[[:space:]]+(option|argument)|permission denied|command not found|not found:[[:space:]]*command|no such file or directory|failed to (start|launch)|could not (start|launch)|unsupported (host|platform)|incompatible (host|platform)|^usage:' "$evidence_file"; then
    printf 'hard-fail\n'; return 0
  fi
  if [[ "$rc" == 124 ]]; then printf 'provider-limited\n'; return 0; fi
  if grep -Eiq 'HTTP[[:space:]]*429|rate[ -]?limit|cooling down|credits?[[:space:]]+(unavailable|exhausted)|provider credits?[[:space:]]+exhausted|quota exceeded' "$evidence_file"; then
    printf 'provider-limited\n'; return 0
  fi
  printf 'hard-fail\n'
}

assert_direct_result_fields() {
  "$PYTHON_BIN" - "$1" "$2" "$3" <<'PY'
import sys
skill, expected, path = sys.argv[1:]
lines = [line.strip() for line in open(path, encoding="utf-8").read().strip().splitlines() if line.strip()]
wanted = [f"Skill: {skill}", f"Invariant: {expected}"]
if lines != wanted:
    raise SystemExit(f"HARD FAIL [{skill}] expected exactly {wanted!r}; got {lines!r}")
PY
}

assert_direct_installed_skill_identity() {
  "$PYTHON_BIN" - "$1" "$2" "$PLUGIN_NAME" <<'PY'
import json, re, sys
from pathlib import Path
root = Path(sys.argv[1]).resolve()
skill, plugin_name = sys.argv[2:]
manifest_path = root / ".codex-plugin" / "plugin.json"
try:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as exc:
    raise SystemExit(f"HARD FAIL [{skill}] unreadable active Codex plugin manifest: {exc}")
if manifest.get("name") != plugin_name or manifest.get("skills") != "./skills/":
    raise SystemExit(f"HARD FAIL [{skill}] active Codex plugin identity or skill path is wrong")
wrapper = root / "skills" / skill / "SKILL.md"
try:
    resolved = wrapper.resolve(strict=True)
    text = wrapper.read_text(encoding="utf-8")
except OSError as exc:
    raise SystemExit(f"HARD FAIL [{skill}] missing installed skill identity: {exc}")
if resolved.parent != wrapper.parent.resolve():
    raise SystemExit(f"HARD FAIL [{skill}] installed skill escaped its expected path: {resolved}")
if "oh-no-harness-generated-skill-wrapper" not in text:
    raise SystemExit(f"HARD FAIL [{skill}] installed skill lacks generated-wrapper identity")
match = re.search(r"(?m)^name:[ \t]*([^\n]+)[ \t]*$", text)
if match is None or match.group(1).strip() != skill:
    raise SystemExit(f"HARD FAIL [{skill}] installed skill frontmatter identity is wrong")
PY
}

validate_codex_direct_result() {
  "$PYTHON_BIN" - "$1" "$2" "$3" "$4" "$5" <<'PY'
import json, re, sys
from pathlib import Path
out, log, skill, root, result_path = sys.argv[1:]
try:
    text = Path(out).read_text(encoding="utf-8").strip()
except OSError as exc:
    raise SystemExit(f"HARD FAIL [{skill}] malformed command result: {exc}")
rows = []
diagnostics = []
try:
    for number, line in enumerate(Path(log).read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("{"):
            try:
                row = json.loads(stripped)
            except json.JSONDecodeError as exc:
                raise SystemExit(f"HARD FAIL [{skill}] malformed JSON event at line {number}: {exc}") from exc
            if not isinstance(row, dict):
                raise SystemExit(f"HARD FAIL [{skill}] non-object JSON event at line {number}")
            rows.append(row)
            continue
        try:
            non_object = json.loads(stripped)
        except json.JSONDecodeError:
            diagnostics.append((number, stripped))
            continue
        if not isinstance(non_object, dict):
            raise SystemExit(f"HARD FAIL [{skill}] non-object JSON event at line {number}")
        raise SystemExit(f"HARD FAIL [{skill}] JSON event must start with '{{' at line {number}")
except OSError as exc:
    raise SystemExit(f"HARD FAIL [{skill}] malformed JSON result: {exc}") from exc
if not text:
    raise SystemExit(f"HARD FAIL [{skill}] empty command result")
hard_diagnostic = re.compile(
    r"unknown[\s:-]+(command|option|argument|skill|invocation)|"
    r"unexpected\s+argument|unrecognized\s+(option|argument)|"
    r"invalid\s+(option|argument)|permission denied|command not found|"
    r"not found:\s*command|no such file or directory|failed to (start|launch)|"
    r"could not (start|launch)|unsupported (host|platform)|"
    r"incompatible (host|platform)|^usage:",
    re.IGNORECASE,
)
for number, diagnostic in diagnostics:
    if hard_diagnostic.search(diagnostic):
        raise SystemExit(f"HARD FAIL [{skill}] hard CLI diagnostic at line {number}: {diagnostic}")
if not rows or rows[-1].get("type") != "turn.completed":
    raise SystemExit(f"HARD FAIL [{skill}] missing successful terminal turn.completed event")
if diagnostics:
    print(f"WARNING [{skill}] ignored {len(diagnostics)} non-JSON Codex diagnostic line(s)", file=sys.stderr)
Path(result_path).write_text(text, encoding="utf-8")
PY
}

run_direct_smoke_classifier_offline_test() {
  local root file got
  root="$(mktemp -d)"; file="$root/evidence"
  for value in 'HTTP 429: credentials cooling down' 'quota exceeded' 'provider credits exhausted'; do
    printf '%s\n' "$value" >"$file"; got="$(direct_smoke_failure_class 1 "$file")"; [[ "$got" == provider-limited ]] || fail "provider exhaustion classifier fixture failed: $value"
  done
  : >"$file"; got="$(direct_smoke_failure_class 124 "$file")"; [[ "$got" == provider-limited ]] || fail "timeout classifier fixture failed"
  for value in 'Unknown skill invocation' 'permission denied' 'error: unexpected argument --bad' 'Unknown option: --rate-limit' 'unexpected argument --rate-limit'; do
    printf '%s\n' "$value" >"$file"; got="$(direct_smoke_failure_class 2 "$file")"; [[ "$got" == hard-fail ]] || fail "hard-failure classifier accepted: $value"
  done
  printf 'Skill: interview\nInvariant: plan-now\n' >"$file"
  if assert_direct_result_fields interview clarify-before-planning "$file" >/dev/null 2>&1; then fail "wrong finite invariant choice passed"; fi
  printf 'Skill: interview\nInvariant: clarify-before-planning\nNarration: extra\n' >"$file"
  if assert_direct_result_fields interview clarify-before-planning "$file" >/dev/null 2>&1; then fail "third direct-result line passed"; fi
  local plugin="$root/plugin" out="$root/out" log="$root/events.jsonl" parsed="$root/parsed" wrapper="$root/plugin/skills/interview/SKILL.md"
  mkdir -p "$plugin/.codex-plugin" "$plugin/skills/interview"
  printf '{"name":"%s","skills":"./skills/"}\n' "$PLUGIN_NAME" >"$plugin/.codex-plugin/plugin.json"
  printf '%s\n' '---' 'name: interview' '---' '<!-- oh-no-harness-generated-skill-wrapper -->' >"$wrapper"
  assert_direct_installed_skill_identity "$plugin" interview || fail "valid installed skill identity fixture failed"
  mv "$wrapper" "$wrapper.saved"
  if assert_direct_installed_skill_identity "$plugin" interview >/dev/null 2>&1; then fail "missing installed skill identity passed"; fi
  mv "$wrapper.saved" "$wrapper"
  printf '%s\n' '---' 'name: wrong-skill' '---' '<!-- oh-no-harness-generated-skill-wrapper -->' >"$wrapper"
  if assert_direct_installed_skill_identity "$plugin" interview >/dev/null 2>&1; then fail "wrong installed skill identity passed"; fi
  printf '%s\n' '---' 'name: interview' '---' '<!-- oh-no-harness-generated-skill-wrapper -->' >"$wrapper"
  printf 'Skill: interview\nInvariant: clarify-before-planning\n' >"$out"
  "$PYTHON_BIN" - "$log" "$plugin" <<'PY'
import json, sys
from pathlib import Path
path, _root = map(Path, sys.argv[1:])
rows = [
    {"type": "thread.started", "thread_id": "fixture-thread"},
    {"type": "turn.started"},
    {"type": "item.completed", "item": {"id": "message-1", "type": "agent_message", "text": "Skill: interview\\nInvariant: clarify-before-planning"}},
    {"type": "turn.completed", "usage": {"input_tokens": 1, "output_tokens": 1}},
]
diagnostic = "2026-08-02T17:02:37.105780Z ERROR codex_core::tools::router: error=exec_command failed: UnknownProcessId { process_id: 31416 }"
path.write_text("Reading additional input from stdin...\n\n" + "\n".join(json.dumps(row) for row in rows) + "\n" + diagnostic + "\n", encoding="utf-8")
PY
  validate_codex_direct_result "$out" "$log" interview "$plugin" "$parsed" || fail "plain Codex diagnostics around complete events fixture failed"
  { printf 'plain diagnostic before events\n'; command cat "$log"; } >"$root/diagnostics-around.jsonl"
  validate_codex_direct_result "$out" "$root/diagnostics-around.jsonl" interview "$plugin" "$parsed" || fail "plain diagnostic before events fixture failed"
  { command cat "$log"; printf '{malformed-json-event\n'; } >"$root/malformed-event.jsonl"
  if validate_codex_direct_result "$out" "$root/malformed-event.jsonl" interview "$plugin" "$parsed" >/dev/null 2>&1; then fail "malformed JSON event candidate passed"; fi
  { command cat "$log"; printf '[]\n'; } >"$root/non-object-event.jsonl"
  if validate_codex_direct_result "$out" "$root/non-object-event.jsonl" interview "$plugin" "$parsed" >/dev/null 2>&1; then fail "non-object JSON event passed"; fi
  { command cat "$log"; printf 'Unknown option: --rate-limit\n'; } >"$root/hard-diagnostic.jsonl"
  if validate_codex_direct_result "$out" "$root/hard-diagnostic.jsonl" interview "$plugin" "$parsed" >/dev/null 2>&1; then fail "hard CLI diagnostic passed with rc 0"; fi
  "$PYTHON_BIN" - "$log" "$root/incomplete.jsonl" <<'PY'
import json, sys
from pathlib import Path
source, target = map(Path, sys.argv[1:])
lines = [line for line in source.read_text(encoding="utf-8").splitlines() if '"type": "turn.completed"' not in line]
target.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
  if validate_codex_direct_result "$out" "$root/incomplete.jsonl" interview "$plugin" "$parsed" >/dev/null 2>&1; then fail "missing terminal event passed"; fi
  rm -rf "$root"; ok "direct smoke classifiers, exact output, and proportional Codex JSON diagnostics"
}

run_live_skill_test() {
  local skill="$1" expected out_file log_file result_file prompt before after rc active_root class
  expected="$(direct_invariant_for_skill "$skill")"; out_file="$RUN_DIR/${skill}.txt"; log_file="$RUN_DIR/${skill}.jsonl"; result_file="$RUN_DIR/${skill}.result"; prompt="$(direct_prompt_for_skill "$skill")"; active_root="$(codex_active_plugin_root)"
  assert_direct_installed_skill_identity "$active_root" "$skill"
  before="$(git -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=all; git -C "$REPO_ROOT" diff --binary HEAD | shasum -a 256)"
  local cmd=("$CODEX_BIN" --ask-for-approval never exec --json --cd "$PLUGIN_ROOT" --sandbox read-only --skip-git-repo-check --output-last-message "$out_file")
  [[ -z "$LIVE_MODEL" ]] || cmd+=(--model "$LIVE_MODEL")
  cmd+=("$prompt")
  rc=0; run_codex_live_command "$CODEX_HOME_DIR" "${cmd[@]}" </dev/null >"$log_file" 2>&1 || rc=$?
  after="$(git -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=all; git -C "$REPO_ROOT" diff --binary HEAD | shasum -a 256)"
  [[ "$before" == "$after" ]] || fail "HARD FAIL [$skill] forbidden project mutation"
  if [[ "$rc" != 0 ]]; then
    class="$(direct_smoke_failure_class "$rc" "$log_file")"
    if [[ "$class" == provider-limited ]]; then printf 'INCONCLUSIVE(provider-limited) - %s (command rc=%s)\n' "$skill" "$rc" >&2; return 0; fi
    fail "HARD FAIL [$skill] direct invocation failed (rc=$rc): $(tail -n 3 "$log_file" | tr '\n' ' ')"
  fi
  validate_codex_direct_result "$out_file" "$log_file" "$skill" "$active_root" "$result_file"
  assert_direct_result_fields "$skill" "$expected" "$result_file"
  printf 'PASS - %s: %s\n' "$skill" "$expected"
}

run_live_tests() {
  if [[ "$RUN_LIVE" != "1" ]]; then
    log "Skipping live Codex direct skill smokes"; printf 'Run with --live or OH_NO_LIVE=1 for one direct read-only invariant per public non-Fusion skill.\n' >&2; printf 'SKIPPED/DEFERRED - fusion-rescue: Claude-host provider credits exhausted\n' >&2; return
  fi
  mkdir -p "$RUN_DIR"; log "Running direct Codex skill smokes"
  local skill
  for skill in "${PUBLIC_SKILLS[@]}"; do
    if [[ "$skill" == "fusion-rescue" ]]; then printf 'SKIPPED/DEFERRED - fusion-rescue: Claude-host provider credits exhausted\n' >&2; continue; fi
    run_live_skill_test "$skill"
  done
  ok "direct live outputs saved under ${RUN_DIR#$MARKETPLACE_ROOT/}"
}

dispatch_scenario_contract() {
  case "$1" in
    interview) printf '%s|%s|%s|%s\n' 'oh-no-explore' read-only '' '' ;;
    ralplan) printf '%s|%s|%s|%s\n' 'oh-no-planner,oh-no-plan-reviewer' workspace-write '.oh-no/plans/task-53-ralplan-probe.md,.oh-no/sessions/task-53-dispatch-ralplan/planning.md' '.oh-no/plans/task-53-ralplan-probe.md' ;;
    ralph) printf '%s|%s|%s|%s\n' 'oh-no-executor,oh-no-code-reviewer' workspace-write 'dispatch-fixture/src/formatter.py,dispatch-fixture/tests/test_formatter.py,dispatch-fixture/.oh-no/sessions/task-53-dispatch-ralph/progress.md,dispatch-fixture/.oh-no/sessions/task-53-dispatch-ralph/verification.md' 'dispatch-fixture/src/formatter.py,dispatch-fixture/tests/test_formatter.py' ;;
    verification-before-completion) printf '%s|%s|%s|%s\n' 'oh-no-verifier' read-only '' '' ;;
    systematic-debugging) printf '%s|%s|%s|%s\n' 'oh-no-debugger' read-only '' '' ;;
    auto-routing|simplify) printf '%s|%s|%s|%s\n' '' read-only '' '' ;;
    *) fail "unknown dispatch-live scenario: $1" ;;
  esac
}

dispatch_home_fingerprint() {
  "$PYTHON_BIN" - "$1" <<'PY'
import hashlib, os, sys
from pathlib import Path
root = Path(sys.argv[1]); h = hashlib.sha256()
paths = [root / name for name in ("auth.json", "config.json")]
agents = root / "agents"
if agents.exists(): paths.extend(sorted(agents.rglob("*")))
for path in paths:
    if not path.exists() and not path.is_symlink(): continue
    relative = path.relative_to(root).as_posix().encode()
    h.update(relative + b"\0")
    if path.is_symlink(): h.update(b"L" + os.readlink(path).encode())
    elif path.is_file(): h.update(b"F" + path.read_bytes())
    elif path.is_dir(): h.update(b"D")
    h.update(b"\0")
print(h.hexdigest())
PY
}

run_sanitized_dispatch_command() (
  local launch_dir="$1"
  shift
  cd "$launch_dir"
  unset OLDPWD
  local name
  while IFS= read -r name; do
    [[ -n "$name" ]] && unset "$name"
  done < <("$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" environment-unsets --repo-root "$REPO_ROOT")
  "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" environment-check --repo-root "$REPO_ROOT" || return $?
  run_codex_live_command "$CODEX_HOME_DIR" "$@" </dev/null
)

prepare_dispatch_fixture() {
  local skill="$1" workspace="$2" nonce="$3"
  local fixture="$workspace/dispatch-fixture"
  mkdir -p "$fixture"
  case "$skill" in
    interview)
      printf 'Brownfield service fact: fixture protocol is kestrel-%s.\n' "$nonce" >"$fixture/FACTS.md"
      ;;
    ralplan)
      mkdir -p "$workspace/.oh-no/plans" "$workspace/.oh-no/sessions/task-53-dispatch-ralplan"
      printf 'Session ID: task-53-dispatch-ralplan\nMode: STANDARD\nApproval: planning scenario approved\n' >"$workspace/.oh-no/sessions/task-53-dispatch-ralplan/planning.md"
      printf 'Plan a read-only status command that prints the fixture nonce %s. No implementation.\n' "$nonce" >"$fixture/request.txt"
      ;;
    ralph)
      mkdir -p "$fixture/src" "$fixture/tests" "$fixture/.oh-no/sessions/task-53-dispatch-ralph"
      printf '%s\n' 'def normalize_label(value):' '    return value.strip()' >"$fixture/src/formatter.py"
      printf '%s\n' 'import unittest' 'from src.formatter import normalize_label' '' 'class NormalizeLabelTest(unittest.TestCase):' '    def test_trims_outer_whitespace(self):' '        self.assertEqual(normalize_label("  alpha  "), "alpha")' '' 'if __name__ == "__main__":' '    unittest.main()' >"$fixture/tests/test_formatter.py"
      git -C "$fixture" init -q
      git -C "$fixture" add src/formatter.py tests/test_formatter.py
      git -C "$fixture" -c user.name=fixture -c user.email=fixture.invalid commit -qm fixture-base
      ;;
    verification-before-completion)
      printf 'immutable-evidence nonce=%s status=verified\n' "$nonce" >"$fixture/evidence.txt"
      chmod 444 "$fixture/evidence.txt"
      ;;
    systematic-debugging)
      printf 'reproduction: exit 17\nhypothesis: parser rejects kestrel-%s before normalization\n' "$nonce" >"$fixture/failure.log"
      ;;
    auto-routing)
      printf 'nonce=%s\nauto-routing=off\nmeaning=future sessions only\n' "$nonce" >"$fixture/status.txt"
      ;;
    simplify)
      mkdir -p "$fixture/src" "$fixture/tests"
      printf 'def label():\n    value = "%s"\n    return value\n' "$nonce" >"$fixture/src/value.py"
      printf 'from src.value import label\n\ndef test_label():\n    assert label()\n' >"$fixture/tests/test_value.py"
      git -C "$fixture" init -q
      git -C "$fixture" add src/value.py tests/test_value.py
      git -C "$fixture" -c user.name=fixture -c user.email=fixture.invalid commit -qm fixture-base
      printf 'def label():\n    return "%s"\n' "$nonce" >"$fixture/src/value.py"
      ;;
  esac
}

dispatch_prompt() {
  local skill="$1" nonce="$2" child_json="$3"
  local common="Every expected child task must require its assigned nonce in its final result. Wait for each expected child to complete and preserve the nonce-bearing receipt. Include scenario nonce $nonce and every child nonce in your final answer. Do not use generic agents or optional agents."
  case "$skill" in
    interview)
      printf '$%s:interview Tiny brownfield fact lookup. Read dispatch-fixture/FACTS.md only by dispatching exactly one agent_type oh-no-explore. Child nonces: %s. %s Do not change files.\n' "$PLUGIN_NAME" "$child_json" "$common" ;;
    ralplan)
      printf '$%s:ralplan Use fixed Session ID task-53-dispatch-ralplan in STANDARD mode. The approved planning state is in .oh-no/sessions/task-53-dispatch-ralplan/planning.md and the request is dispatch-fixture/request.txt. Dispatch oh-no-planner to create .oh-no/plans/task-53-ralplan-probe.md, wait for Planner completion, then dispatch exactly one oh-no-plan-reviewer to review that plan and wait for reviewer completion. Child nonces: %s. %s Do not apply reviewer feedback or request a v2. Stop immediately after the review, before user approval or execution. Only the probe plan and this session planning.md may change.\n' "$PLUGIN_NAME" "$child_json" "$common" ;;
    ralph)
      printf '$%s:ralph Use STANDARD mode and fixed Session ID task-53-dispatch-ralph. Worktree decision: user declined/current disposable fixture checkout. Approved bounded change in dispatch-fixture: normalize_label must trim outer whitespace and collapse internal whitespace; update only src/formatter.py and tests/test_formatter.py, using python -B -m unittest discover -s tests. Dispatch oh-no-executor for this bounded two-file change and wait for Executor completion. Then dispatch exactly one oh-no-code-reviewer to review the resulting change, wait for Code Reviewer completion, and stop. Child nonces: %s. %s Stop before verifier or completion. No worktree, pair, additional executor, or commit. Only dispatch-fixture/src/formatter.py, dispatch-fixture/tests/test_formatter.py, dispatch-fixture/.oh-no/sessions/task-53-dispatch-ralph/progress.md, and dispatch-fixture/.oh-no/sessions/task-53-dispatch-ralph/verification.md may change.\n' "$PLUGIN_NAME" "$child_json" "$common" ;;
    verification-before-completion)
      printf '$%s:verification-before-completion Independently verify immutable dispatch-fixture/evidence.txt by dispatching exactly one oh-no-verifier. Child nonces: %s. %s Do not change files or claim broader completion.\n' "$PLUGIN_NAME" "$child_json" "$common" ;;
    systematic-debugging)
      printf '$%s:systematic-debugging The failure is reproduced and one active hypothesis is recorded in dispatch-fixture/failure.log. Diagnose only in a separate context by dispatching exactly one oh-no-debugger. Child nonces: %s. %s Do not patch or change files.\n' "$PLUGIN_NAME" "$child_json" "$common" ;;
    auto-routing)
      printf '$%s:auto-routing Report the read-only semantics/status from dispatch-fixture/status.txt. Dispatch zero children and change nothing. Include scenario nonce %s in the final answer.\n' "$PLUGIN_NAME" "$nonce" ;;
    simplify)
      printf '$%s:simplify Inspect the tiny behavior-locked clean diff under dispatch-fixture. Combined-depth expansion is not justified. Dispatch zero named children, do not edit, and include scenario nonce %s in the final answer.\n' "$PLUGIN_NAME" "$nonce" ;;
  esac
}

run_dispatch_live_scenario() {
  local skill="$1" active_root contract roles sandbox allow require attempt
  active_root="$(codex_active_plugin_root)"
  contract="$(dispatch_scenario_contract "$skill")"
  IFS='|' read -r roles sandbox allow require <<<"$contract"
  for attempt in 1 2; do
    local root workspace evidence prompt_file out_file log_file before_file after_file canonical_before canonical_after
    local session_before session_manifest export_dir session_file
    local nonce parent_nonce child_json role role_nonce home_before home_after rc class oracle_rc
    local baseline_head='' baseline_branch=''
    local canonical_paths=(
      '.oh-no/plans/task-53-ralplan-probe.md'
      '.oh-no/sessions/task-53-dispatch-ralplan/planning.md'
      '.oh-no/sessions/task-53-dispatch-ralph/progress.md'
      '.oh-no/sessions/task-53-dispatch-ralph/verification.md'
      'dispatch-fixture/.oh-no/sessions/task-53-dispatch-ralph/progress.md'
      'dispatch-fixture/.oh-no/sessions/task-53-dispatch-ralph/verification.md'
      '.oh-no/worktrees/task-53-dispatch-ralph'
    )
    root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-codex-dispatch-${skill}.XXXXXX")"
    CODEX_LIVE_TEMP_ROOTS+=("$root")
    workspace="$root/plugin"; evidence="$root/evidence"; mkdir -p "$workspace" "$evidence"
    cp -Rp "$active_root/." "$workspace/"
    nonce="$($PYTHON_BIN -c 'import secrets; print(secrets.token_hex(12))')"
    parent_nonce="PARENT-$nonce"; child_json='{'; local first=1
    IFS=',' read -ra expected_roles <<<"$roles"
    for role in "${expected_roles[@]:-}"; do
      [[ -n "$role" ]] || continue
      role_nonce="CHILD-${role#oh-no-}-$nonce"
      (( first == 1 )) || child_json+=','
      child_json+="\"$role\":\"$role_nonce\""; first=0
    done
    child_json+='}'
    prepare_dispatch_fixture "$skill" "$workspace" "$parent_nonce"
    if [[ "$skill" == ralph ]]; then
      baseline_head="$(git -C "$workspace/dispatch-fixture" rev-parse HEAD)"
      baseline_branch="$(git -C "$workspace/dispatch-fixture" symbolic-ref -q --short HEAD || printf 'DETACHED')"
    fi
    prompt_file="$evidence/prompt.txt"; dispatch_prompt "$skill" "$parent_nonce" "$child_json" >"$prompt_file"
    out_file="$evidence/result.txt"; log_file="$evidence/events.jsonl"
    before_file="$evidence/before.json"; after_file="$evidence/after.json"
    canonical_before="$evidence/canonical-before.json"; canonical_after="$evidence/canonical-after.json"
    session_before="$evidence/session-before.json"; session_manifest="$evidence/new-sessions.json"
    export_dir="$RUN_DIR/dispatch-live/$skill/attempt-$attempt"
    [[ ! -e "$export_dir" && ! -L "$export_dir" ]] || fail "HARD FAIL [$skill] dispatch evidence destination already exists"
    "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" session-inventory --sessions "$CODEX_HOME_DIR/sessions" --output "$session_before"
    "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" snapshot "$workspace" "$before_file"
    "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" selected-snapshot "$REPO_ROOT" "$canonical_before" "${canonical_paths[@]}"
    home_before="$(dispatch_home_fingerprint "$CODEX_HOME_DIR")"
    assert_direct_installed_skill_identity "$workspace" "$skill"
    local cmd=("$CODEX_BIN" --ask-for-approval never exec --json --cd "$workspace" --sandbox "$sandbox" --skip-git-repo-check --output-last-message "$out_file")
    [[ -z "$LIVE_MODEL" ]] || cmd+=(--model "$LIVE_MODEL")
    cmd+=("$(<"$prompt_file")")
    rc=0; run_sanitized_dispatch_command "$root" "${cmd[@]}" >"$log_file" 2>&1 || rc=$?
    "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" new-session-manifest --sessions "$CODEX_HOME_DIR/sessions" --before "$session_before" --output "$session_manifest"
    local -a new_session_files=()
    while IFS= read -r -d '' session_file; do new_session_files+=("$session_file"); done \
      < <("$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" session-paths --sessions "$CODEX_HOME_DIR/sessions" --manifest "$session_manifest")
    assert_no_codex_live_secret_leak "$CODEX_HOME_DIR/auth.json" "$evidence" "${new_session_files[@]}" \
      || fail "HARD FAIL [$skill] dispatch evidence secret scan failed"
    "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" export-evidence \
      --sessions "$CODEX_HOME_DIR/sessions" --manifest "$session_manifest" --destination "$export_dir" \
      --prompt "$prompt_file" --result "$out_file" --events "$log_file"
    home_after="$(dispatch_home_fingerprint "$CODEX_HOME_DIR")"
    [[ "$home_before" == "$home_after" ]] || fail "HARD FAIL [$skill] Codex auth.json, config.json, or agents tree changed"
    "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" selected-snapshot "$REPO_ROOT" "$canonical_after" "${canonical_paths[@]}"
    "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" compare-snapshots --skill "$skill" --before "$canonical_before" --after "$canonical_after"
    "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" snapshot "$workspace" "$after_file"
    "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" mutation --skill "$skill" --before "$before_file" --after "$after_file" --allow "$allow"
    if [[ "$skill" == ralph ]]; then
      "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" git-state --skill ralph --repo "$workspace/dispatch-fixture" --head "$baseline_head" --branch "$baseline_branch"
    fi
    if [[ "$rc" != 0 ]]; then
      class="$(direct_smoke_failure_class "$rc" "$log_file")"
      if [[ "$class" == provider-limited ]]; then printf 'INCONCLUSIVE(provider-limited) - dispatch %s (command rc=%s)\n' "$skill" "$rc" >&2; return 0; fi
      fail "HARD FAIL [$skill] dispatch invocation failed (rc=$rc)"
    fi
    "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" mutation --skill "$skill" --before "$before_file" --after "$after_file" --allow "$allow" --require "$require"
    oracle_rc=0
    "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" verify \
      --events "$log_file" --result "$out_file" --prompt "$prompt_file" --sessions "$CODEX_HOME_DIR/sessions" \
      --skill "$skill" --plugin "$PLUGIN_NAME" --roles "$roles" \
      --child-nonces "$child_json" --parent-nonce "$parent_nonce" || oracle_rc=$?
    if [[ "$oracle_rc" == 0 ]]; then return 0; fi
    if [[ "$oracle_rc" == 75 && "$attempt" == 1 ]]; then
      printf 'WARNING [%s] retrying once after dispatch variance\n' "$skill" >&2
      continue
    fi
    return "$oracle_rc"
  done
}

run_dispatch_live_tests() {
  if [[ "$RUN_DISPATCH_LIVE" != "1" ]]; then
    log "Skipping Codex internal role-dispatch live matrix"
    printf 'Run with --dispatch-live or OH_NO_DISPATCH_LIVE=1 for the bounded seven-scenario dispatch matrix.\n' >&2
    return
  fi
  mkdir -p "$RUN_DIR"
  log "Running minimal Codex internal role-dispatch matrix"
  local skill
  for skill in interview ralplan ralph verification-before-completion systematic-debugging auto-routing simplify; do
    run_dispatch_live_scenario "$skill"
  done
  ok "dispatch-live matrix completed (7 parents, nominal 14 total model calls)"
}

run_codex_dispatch_oracle_offline_test() {
  log "Running offline Codex dispatch-live oracle fixtures"
  "$PYTHON_BIN" "$SCRIPT_DIR/test-codex-dispatch-live-oracle.py" "$SCRIPT_DIR/codex-dispatch-live-oracle.py"
  ok "Codex dispatch oracle pins linkage, role, completion, nonce, unexpected-child, and mutation gates"
}

run_codex_dispatch_evidence_offline_test() {
  log "Running offline Codex dispatch evidence export fixtures"
  local root home evidence before manifest destination session_file secret
  local -a new_sessions=()
  root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-codex-dispatch-evidence.XXXXXX")"
  home="$root/home"; evidence="$root/evidence"; mkdir -p "$home/sessions/preexisting" "$evidence"
  secret="$(printf 'fixture-dispatch-%s-%012d' 'secret' 1)"
  printf '{"access_token":"%s"}\n' "$secret" >"$home/auth.json"
  printf 'model = "fixture"\n' >"$home/config.toml"
  printf '%s\n' '{"type":"session_meta","payload":{"id":"old"}}' >"$home/sessions/preexisting/old.jsonl"
  before="$root/before.json"; manifest="$root/new.json"
  "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" session-inventory --sessions "$home/sessions" --output "$before"
  mkdir -p "$home/sessions/new/parent" "$home/sessions/new/child"
  printf '%s\n' '{"type":"session_meta","payload":{"id":"parent"}}' >"$home/sessions/new/parent/rollout.jsonl"
  printf '%s\n' '{"type":"session_meta","payload":{"id":"child"}}' >"$home/sessions/new/child/rollout.jsonl"
  ln -s "$home/auth.json" "$home/sessions/new/credential.jsonl"
  printf 'prompt\n' >"$evidence/prompt.txt"; printf 'result\n' >"$evidence/result.txt"; printf '{}\n' >"$evidence/events.jsonl"
  "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" new-session-manifest --sessions "$home/sessions" --before "$before" --output "$manifest"
  while IFS= read -r -d '' session_file; do new_sessions+=("$session_file"); done \
    < <("$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" session-paths --sessions "$home/sessions" --manifest "$manifest")
  assert_no_codex_live_secret_leak "$home/auth.json" "$evidence" "${new_sessions[@]}" \
    || { rm -rf "$root"; fail "safe dispatch evidence fixture failed secret scan"; }
  destination="$root/export/attempt-1"
  "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" export-evidence \
    --sessions "$home/sessions" --manifest "$manifest" --destination "$destination" \
    --prompt "$evidence/prompt.txt" --result "$evidence/result.txt" --events "$evidence/events.jsonl"
  [[ -f "$destination/sessions/new/parent/rollout.jsonl" && -f "$destination/sessions/new/child/rollout.jsonl" \
      && ! -e "$destination/sessions/preexisting/old.jsonl" && ! -e "$destination/sessions/new/credential.jsonl" \
      && ! -e "$destination/auth.json" && ! -e "$destination/config.toml" ]] \
    || { rm -rf "$root"; fail "dispatch evidence export included the wrong files"; }

  "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" session-inventory --sessions "$home/sessions" --output "$before"
  mkdir -p "$home/sessions/retry"; printf '%s\n' '{"type":"session_meta","payload":{"id":"retry"}}' >"$home/sessions/retry/rollout.jsonl"
  "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" new-session-manifest --sessions "$home/sessions" --before "$before" --output "$manifest"
  new_sessions=()
  while IFS= read -r -d '' session_file; do new_sessions+=("$session_file"); done \
    < <("$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" session-paths --sessions "$home/sessions" --manifest "$manifest")
  assert_no_codex_live_secret_leak "$home/auth.json" "$evidence" "${new_sessions[@]}" \
    || { rm -rf "$root"; fail "retry dispatch evidence fixture failed secret scan"; }
  "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" export-evidence \
    --sessions "$home/sessions" --manifest "$manifest" --destination "$root/export/attempt-2" \
    --prompt "$evidence/prompt.txt" --result "$evidence/result.txt" --events "$evidence/events.jsonl"
  [[ -f "$root/export/attempt-1/sessions/new/parent/rollout.jsonl" && -f "$root/export/attempt-2/sessions/retry/rollout.jsonl" ]] \
    || { rm -rf "$root"; fail "dispatch evidence retry destinations were not separate"; }

  "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" session-inventory --sessions "$home/sessions" --output "$before"
  mkdir -p "$home/sessions/unsafe"; printf '{"message":"%s"}\n' "$secret" >"$home/sessions/unsafe/rollout.jsonl"
  "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" new-session-manifest --sessions "$home/sessions" --before "$before" --output "$manifest"
  new_sessions=()
  while IFS= read -r -d '' session_file; do new_sessions+=("$session_file"); done \
    < <("$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" session-paths --sessions "$home/sessions" --manifest "$manifest")
  if assert_no_codex_live_secret_leak "$home/auth.json" "$evidence" "${new_sessions[@]}" >/dev/null 2>&1; then
    rm -rf "$root"; fail "unsafe dispatch evidence passed the secret scanner"
  fi
  [[ ! -e "$root/export/attempt-3" ]] || { rm -rf "$root"; fail "unsafe dispatch evidence was exported"; }
  rm -rf "$root"
  ok "dispatch evidence exports only new safe session JSONL files into separate attempts"
}

run_cross_host_oracle_offline_test() {
  log "Running offline Codex -> Claude transport oracle fixtures"
  "$PYTHON_BIN" "$SCRIPT_DIR/test-cross-host-live-oracle.py" "$SCRIPT_DIR/cross-host-live-oracle.py"
  ok "cross-host oracle pins launcher, terminal, nested Read/result, semantic, mutation, and secret gates"
}

validate_cross_host_budget() {
  "$PYTHON_BIN" - "$CROSS_HOST_MAX_BUDGET_USD" <<'PY'
from decimal import Decimal, InvalidOperation
import sys

try:
    value = Decimal(sys.argv[1])
except InvalidOperation:
    raise SystemExit("cross-host Claude budget must be numeric")
if not value.is_finite() or value <= 0 or value > Decimal("3.00"):
    raise SystemExit("cross-host Claude budget must be greater than 0 and no more than 3.00")
PY
}

prepare_cross_host_fixture() {
  local workspace="$1" receiver_nonce="$2" launcher="$workspace/dispatch-fixture/invoke-claude.py"
  mkdir -p "$workspace/dispatch-fixture"
  cat >"$workspace/dispatch-fixture/receiver-input.txt" <<EOF
receiver_nonce=$receiver_nonce
acceptance=non-idempotent payment capture must never be automatically retried
retry_non_idempotent_payment_capture=true
EOF
  "$PYTHON_BIN" - "$launcher" "$CROSS_HOST_MAX_BUDGET_USD" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
budget = sys.argv[2]
source = f'''#!/usr/bin/env python3
import os
import subprocess
import sys

argv = [
    os.environ.get("CLAUDE_BIN", "claude"),
    "--print",
    "--verbose",
    "--output-format", "stream-json",
    "--model", "sonnet",
    "--max-budget-usd", {budget!r},
    "--permission-mode", "dontAsk",
    "--tools", "Read",
    "--no-session-persistence",
    (
        "Read only dispatch-fixture/receiver-input.txt. Return a concise receiver "
        "finding containing exactly the receiver identity 'Receiver: claude-code', "
        "the receiver nonce read from that file, the exact conflicting setting, and "
        "whether the setting violates the acceptance rule. Do not infer fixture values "
        "without the Read result."
    ),
]
result = subprocess.run(argv, capture_output=True, text=True, timeout=240)
print(result.stdout, end="")
if result.stderr:
    print(result.stderr, end="", file=sys.stderr)
raise SystemExit(result.returncode)
'''
path.write_text(source, encoding="utf-8")
path.chmod(0o700)
PY
}

cross_host_prompt() {
  local parent_nonce="$1"
  printf '%s\n' \
    "This is a direct transport smoke from one Codex parent to Claude Code. Do not invoke any skill, workflow, agent, subagent, collaboration tool, fallback, panel, or edit. Execute exactly this command once and no other command: python3 dispatch-fixture/invoke-claude.py. Wait for its terminal output. Then report parent nonce $parent_nonce plus the receiver result, and stop."
}

run_cross_host_live_test() {
  if [[ "$RUN_CROSS_HOST_LIVE" != "1" ]]; then
    log "Skipping Codex -> Claude direct transport live smoke"
    printf 'Run with --cross-host-live or OH_NO_CROSS_HOST_LIVE=1 for the bounded direct transport smoke.\n' >&2
    return
  fi
  validate_cross_host_budget || fail "invalid cross-host Claude budget: $CROSS_HOST_MAX_BUDGET_USD"
  mkdir -p "$RUN_DIR"
  local active_root attempt
  active_root="$(codex_active_plugin_root)"
  for attempt in 1 2; do
    local root workspace evidence claude_config prompt_file result_file events_file before after
    local session_before session_manifest export_dir session_file rc oracle_rc parent_nonce receiver_nonce
    local -a new_session_files=()
    root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-codex-cross-host.XXXXXX")"
    CODEX_LIVE_TEMP_ROOTS+=("$root")
    workspace="$root/workspace"; evidence="$root/evidence"; claude_config="$root/claude-config"
    mkdir -p "$workspace" "$evidence" "$claude_config"
    cp -Rp "$active_root/." "$workspace/"
    parent_nonce="PARENT-$($PYTHON_BIN -c 'import secrets; print(secrets.token_hex(12))')"
    receiver_nonce="RECEIVER-$($PYTHON_BIN -c 'import secrets; print(secrets.token_hex(12))')"
    prepare_cross_host_fixture "$workspace" "$receiver_nonce"
    prompt_file="$evidence/prompt.txt"; cross_host_prompt "$parent_nonce" >"$prompt_file"
    result_file="$evidence/result.txt"; events_file="$evidence/events.jsonl"
    before="$evidence/protected-before.json"; after="$evidence/protected-after.json"
    session_before="$evidence/session-before.json"; session_manifest="$evidence/new-sessions.json"
    export_dir="$RUN_DIR/cross-host-live/attempt-$attempt"
    [[ ! -e "$export_dir" && ! -L "$export_dir" ]] || fail "HARD FAIL [cross-host-live] evidence destination already exists"
    "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" session-inventory \
      --sessions "$CODEX_HOME_DIR/sessions" --output "$session_before"
    "$PYTHON_BIN" "$SCRIPT_DIR/cross-host-live-oracle.py" snapshot --output "$before" \
      --root "workspace=$workspace" \
      --root "canonical=$REPO_ROOT" --exclude .git --exclude .oh-no \
      --root "codex-auth=$CODEX_HOME_DIR/auth.json" \
      --root "codex-config-json=$CODEX_HOME_DIR/config.json" \
      --root "codex-agents=$CODEX_HOME_DIR/agents" \
      --root "real-claude-config=$HOME/.claude" \
      --root "real-claude-state=$HOME/.claude.json"
    local cmd=("$CODEX_BIN" --ask-for-approval never exec --json --cd "$workspace" \
      --sandbox danger-full-access --skip-git-repo-check --output-last-message "$result_file")
    [[ -z "$LIVE_MODEL" ]] || cmd+=(--model "$LIVE_MODEL")
    cmd+=("$(<"$prompt_file")")
    rc=0
    CLAUDE_CONFIG_DIR="$claude_config" run_sanitized_dispatch_command "$root" "${cmd[@]}" \
      >"$events_file" 2>&1 || rc=$?
    "$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" new-session-manifest \
      --sessions "$CODEX_HOME_DIR/sessions" --before "$session_before" --output "$session_manifest"
    while IFS= read -r -d '' session_file; do new_session_files+=("$session_file"); done \
      < <("$PYTHON_BIN" "$SCRIPT_DIR/codex-dispatch-live-oracle.py" session-paths \
        --sessions "$CODEX_HOME_DIR/sessions" --manifest "$session_manifest")
    "$PYTHON_BIN" "$SCRIPT_DIR/cross-host-live-oracle.py" snapshot --output "$after" \
      --root "workspace=$workspace" \
      --root "canonical=$REPO_ROOT" --exclude .git --exclude .oh-no \
      --root "codex-auth=$CODEX_HOME_DIR/auth.json" \
      --root "codex-config-json=$CODEX_HOME_DIR/config.json" \
      --root "codex-agents=$CODEX_HOME_DIR/agents" \
      --root "real-claude-config=$HOME/.claude" \
      --root "real-claude-state=$HOME/.claude.json"
    assert_codex_live_home_provenance "$CODEX_HOME_DIR" \
      || fail "HARD FAIL [cross-host-live] source Codex home provenance changed"
    assert_no_codex_live_secret_leak "$CODEX_HOME_DIR/auth.json" "$evidence" "${new_session_files[@]}" \
      || fail "HARD FAIL [cross-host-live] evidence secret scan failed"
    "$PYTHON_BIN" "$SCRIPT_DIR/cross-host-live-oracle.py" export-evidence \
      --events "$events_file" --result "$result_file" --prompt "$prompt_file" \
      --sessions "$CODEX_HOME_DIR/sessions" --session-manifest "$session_manifest" \
      --destination "$export_dir"
    [[ "$rc" == 0 ]] || fail "HARD FAIL [cross-host-live] outer Codex command failed (rc=$rc)"
    oracle_rc=0
    "$PYTHON_BIN" "$SCRIPT_DIR/cross-host-live-oracle.py" verify \
      --events "$events_file" --result "$result_file" \
      --sessions "$CODEX_HOME_DIR/sessions" --session-manifest "$session_manifest" \
      --parent-nonce "$parent_nonce" --receiver-nonce "$receiver_nonce" \
      --workspace "$workspace" --before "$before" --after "$after" || oracle_rc=$?
    if [[ "$oracle_rc" == 0 ]]; then
      ok "cross-host-live direct transport completed"
      return
    fi
    if [[ "$oracle_rc" == 75 && "$attempt" == 1 ]]; then
      printf 'WARNING [cross-host-live] retrying once after missing, wrong, or duplicate launcher dispatch\n' >&2
      continue
    fi
    return "$oracle_rc"
  done
}

run_codex_safety_extraction_offline_test() {
  log "Running offline Codex safety-extraction guards"
  # The live safety inspectors used to match only `function_call` /
  # `command_execution` and only ONE command per event. Today's shape is a
  # `custom_tool_call` named `exec` whose input batches several
  # tools.exec_command(...) calls, so a forbidden write in the second embedded
  # command -- or in any child custom_tool_call at all -- was never inspected.
  # These fixtures pin the canonical shared extractor's behaviour directly.
  "$PYTHON_BIN" - "$SELF_PATH" <<'PY'
import json, re, sys, subprocess, pathlib
source = pathlib.Path(sys.argv[1]).read_text()
start = source.index("codex_oracle_shared_helpers() {")
end = source.index("SHARED_HELPERS_PY\n}", start)
head = "  cat <<'SHARED_HELPERS_PY'\n"
block = source[start:end]
helpers = block[block.index(head) + len(head):]
ns = {}
exec("import json, re\n" + helpers, ns)
inspect = ns["safety_inspectable_commands"]
bearing = ns["event_is_command_bearing"]
reads_readme = ns["reads_readme_command"]
retained_result = ns["retained_output_result"]
assert reads_readme("nl -ba README.md")
assert not reads_readme("echo README.md")
assert retained_result("Process exited with code 0\nOutput:\ncontent\n") == (0, "content\n")
assert retained_result("Process exited with code 1\nOutput:\nmissing\n") == (1, "missing\n")

FORBIDDEN = [re.compile(p) for p in (
    r"\btouch\b", r"\brm\b", r"\bsed\s+-i\b", r"\bmv\b", r"\bcp\b",
    r"\bapply_patch\b", r">\s*\S", r"\bchmod\b",
)]
EGRESS = [re.compile(r"\bclaude\b"), re.compile(r"\bcodex\b")]

def child(inp, call_id="c1"):
    return {"payload": {"type": "custom_tool_call", "name": "exec",
                        "call_id": call_id, "input": inp}}
def parent(command):
    return {"item": {"type": "command_execution", "id": "p1", "command": command}}
def fcall(cmd):
    return {"payload": {"type": "function_call", "name": "exec_command",
                        "call_id": "f1", "arguments": json.dumps({"cmd": cmd})}}

def js(*commands, capture=None):
    lines = []
    for index, command in enumerate(commands, 1):
        lines.append('const r%d = await tools.exec_command({"cmd":"%s"});' % (index, command))
    lines.append("text(r%d.output);" % (capture or len(commands)))
    return "\n".join(lines) + "\n"

failures = []
def check(label, event, want_forbidden, want_egress, want_commands=None):
    commands = inspect(event)
    is_bearing = bearing(event)
    hit_f = is_bearing and any(p.search(c) for c in commands for p in FORBIDDEN)
    hit_e = is_bearing and any(p.search(c) for c in commands for p in EGRESS)
    problems = []
    if hit_f != want_forbidden:
        problems.append(f"forbidden={hit_f} want={want_forbidden}")
    if hit_e != want_egress:
        problems.append(f"egress={hit_e} want={want_egress}")
    if want_commands is not None and commands != want_commands:
        problems.append(f"commands={commands!r} want={want_commands!r}")
    if problems:
        failures.append(f"{label}: " + "; ".join(problems))

# --- child custom_tool_call shape: each forbidden write must be caught ---
check("child touch", child(js("touch src/status.sh")), True, False)
check("child rm", child(js("rm -rf src")), True, False)
check("child sed -i", child(js("sed -i s/a/b/ README.md")), True, False)
check("child redirect", child(js("printf x > src/status.sh")), True, False)
# --- host egress in the child shape ---
check("child claude egress", child(js("claude -p hello")), False, True)
check("child codex egress", child(js("codex exec hi")), False, True)
# --- safe reads must not trip either guard ---
check("child safe read", child(js("nl -ba README.md")), False, False)
check("child safe cat", child(js("cat src/status.sh")), False, False)
# --- BATCHED: violation in the SECOND embedded command ---
check("batched second violation",
      child(js("nl -ba README.md", "rm -rf src")), True, False,
      ["nl -ba README.md", "rm -rf src"])
check("batched egress second",
      child(js("nl -ba README.md", "claude -p x")), False, True,
      ["nl -ba README.md", "claude -p x"])
# --- missing output: safety must still inspect the ISSUED command ---
missing = {"payload": {"type": "custom_tool_call", "name": "exec",
                       "call_id": "no-output", "input": js("rm -rf src")}}
check("violation with no retained output", missing, True, False)
# --- a command whose read credit would fail closed is STILL inspected ---
unowned = child('const r = placeholder\nawait tools.exec_command({"cmd":"sed -i s/a/b/ README.md"});\ntext(r.output);\n')
check("unowned mutation still inspected", unowned, True, False,
      ["sed -i s/a/b/ README.md"])
branchy = child('let r;\nif (f) { r = await tools.exec_command({"cmd":"rm -rf src"}); }\ntext(r.output);\n')
check("branch-ambiguous mutation still inspected", branchy, True, False)
# --- parent and function_call shapes keep working ---
check("parent touch", parent("touch src/status.sh"), True, False)
check("parent safe read", parent("nl -ba README.md"), False, False)
check("function_call rm", fcall("rm -rf src"), True, False)
check("function_call safe", fcall("cat README.md"), False, False)
# --- prose that is not a call must not manufacture a violation ---
check("prose only", child('// rm -rf src\ntext("done");\n'), False, False, [])
check("regex literal only",
      child('const re = /await tools.exec_command({"cmd":"rm -rf src"})/;\n'), False, False, [])

if failures:
    raise SystemExit("safety-extraction fixtures failed:\n  " + "\n  ".join(failures))
print("ok - safety extraction inspects every issued command in every observed shape")
PY
  ok "Codex safety inspectors use canonical shared extraction for all shapes"
}
run_codex_install_identity_offline_test() (
  log "Running offline Codex installed-identity response and lifecycle guards"
  local root response record rc unsafe
  root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-codex-install-identity.XXXXXX")"
  trap 'rm -rf "$root"' EXIT
  response="$root/post-install-plugin-read.json"
  record="$root/installed-plugin-version.txt"

  printf '%s\n' '{"plugin":{"summary":{"installed":true,"localVersion":"2.1.0"}}}' >"$response"
  printf '%s\n' '9.9.9' >"$record"
  codex_record_installed_identity "$response" "$record" \
    || fail "Codex installed-identity validator rejected the current nested PluginReadResponse shape"
  [[ "$(<"$record")" == "2.1.0" && ! -e "$root/installed-plugin-version.tmp" ]] \
    || fail "Codex installed-identity validator did not atomically replace a stale record"

  printf '%s\n' '{"plugin":{"summary":{"installed":false,"localVersion":"2.1.0"}}}' >"$response"
  rm -f "$record"; rc=0
  codex_record_installed_identity "$response" "$record" >/dev/null 2>&1 || rc=$?
  [[ "$rc" != 0 && ! -e "$record" ]] \
    || fail "Codex installed-identity validator accepted summary.installed=false"

  printf '%s\n' '{"plugin":{"summary":{"installed":true}}}' >"$response"
  rc=0; codex_record_installed_identity "$response" "$record" >/dev/null 2>&1 || rc=$?
  [[ "$rc" != 0 && ! -e "$record" ]] \
    || fail "Codex installed-identity validator accepted a missing summary.localVersion"

  for unsafe in '..' '../outside' '/tmp/outside' '2.1.0/other' '2.1.0\\other'; do
    "$PYTHON_BIN" - "$response" "$unsafe" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
path.write_text(json.dumps({"plugin": {"summary": {"installed": True, "localVersion": sys.argv[2]}}}), encoding="utf-8")
PY
    rc=0; codex_record_installed_identity "$response" "$record" >/dev/null 2>&1 || rc=$?
    [[ "$rc" != 0 && ! -e "$record" ]] \
      || fail "Codex installed-identity validator accepted unsafe localVersion $unsafe"
  done

  # A reused process and RUN_DIR may carry both in-memory and on-disk identity. The
  # attempt boundary clears all of it BEFORE a simulated first install action fails.
  RUN_DIR="$root/reused-run"; mkdir -p "$RUN_DIR"
  printf '%s\n' '2.1.0' >"$RUN_DIR/installed-plugin-version.txt"
  printf '%s\n' 'partial' >"$RUN_DIR/installed-plugin-version.tmp"
  printf '%s\n' '{}' >"$RUN_DIR/post-install-plugin-read.json"
  printf '%s\n' 'partial' >"$RUN_DIR/post-install-plugin-read.tmp"
  CODEX_INSTALLED_PLUGIN_VERSION="2.1.0"
  CODEX_ACTIVE_PLUGIN_ROOT="$root/stale-root"
  codex_begin_install_attempt
  rc=0; false || rc=$?
  [[ "$rc" != 0 && -z "$CODEX_INSTALLED_PLUGIN_VERSION" && -z "$CODEX_ACTIVE_PLUGIN_ROOT" ]] \
    || fail "Codex install retry retained in-memory identity after a failed first action"
  [[ ! -e "$RUN_DIR/installed-plugin-version.txt" && ! -e "$RUN_DIR/installed-plugin-version.tmp" \
      && ! -e "$RUN_DIR/post-install-plugin-read.json" && ! -e "$RUN_DIR/post-install-plugin-read.tmp" ]] \
    || fail "Codex install retry retained stale identity files after a failed first action"
  ok "Codex installed identity follows plugin.summary installed/localVersion and clears stale retry state"
)
run_codex_install_integration_offline_test() (
  log "Running offline Codex install lifecycle and app-server boundary fixtures"
  local root fake_codex fake_app log capture rc
  root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-codex-install-integration.XXXXXX")"
  trap "rm -rf '$root'" EXIT
  fake_codex="$root/fake-codex"
  fake_app="$root/fake-app-server.py"
  log="$root/codex-actions.log"
  capture="$root/request-5.json"

  cat >"$fake_codex" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1 $2 $3" == "plugin marketplace list" ]]; then
  [[ -z "${CODEX_INSTALLED_PLUGIN_VERSION:-}" && -z "${CODEX_ACTIVE_PLUGIN_ROOT:-}" ]] || exit 91
  [[ ! -e "$RUN_DIR/installed-plugin-version.txt" && ! -e "$RUN_DIR/installed-plugin-version.tmp" \
      && ! -e "$RUN_DIR/post-install-plugin-read.json" && ! -e "$RUN_DIR/post-install-plugin-read.tmp" ]] || exit 92
  printf '%s\n' 'list-clean' >>"$FAKE_CODEX_LOG"
  printf '%s\n' '{"marketplaces":[]}'
  exit 0
fi
if [[ "$1 $2 $3" == "plugin marketplace add" ]]; then
  printf '%s\n' 'add' >>"$FAKE_CODEX_LOG"
  exit "${FAKE_MARKETPLACE_ADD_STATUS:-0}"
fi
if [[ "$1" == "app-server" ]]; then
  exec "$PYTHON_BIN" "$FAKE_APP_SERVER"
fi
exit 93
SH
  chmod +x "$fake_codex"
  cat >"$fake_app" <<'PY'
import json
import os
import sys
from pathlib import Path

skills = [
    "interview", "ralplan", "ralph", "ultrawork", "auto-routing",
    "test-driven-development", "simplify", "verification-before-completion",
    "systematic-debugging", "fusion-rescue",
]
for line in sys.stdin:
    message = json.loads(line)
    request_id = message.get("id")
    if request_id is None:
        continue
    if request_id == 1:
        result = {}
    elif request_id == 2:
        result = {"marketplaces": [{"name": "oh-no-harness", "path": "/offline/marketplace", "plugins": [{"id": "oh-no-harness@oh-no-harness", "installPolicy": "AVAILABLE", "availability": "AVAILABLE"}]}]}
    elif request_id == 3:
        result = {"plugin": {"skills": [{"name": f"oh-no-harness:{skill}"} for skill in skills]}}
    elif request_id == 4:
        result = {"authPolicy": "ON_INSTALL"}
    elif request_id == 5:
        Path(os.environ["FAKE_REQUEST_CAPTURE"]).write_text(json.dumps(message), encoding="utf-8")
        result = {"plugin": {"summary": {"installed": True, "localVersion": "2.1.0"}}}
    else:
        raise SystemExit(f"unexpected request id: {request_id}")
    print(json.dumps({"id": request_id, "result": result}), flush=True)
PY

  export CODEX_BIN="$fake_codex" PYTHON_BIN FAKE_APP_SERVER="$fake_app" FAKE_CODEX_LOG="$log" FAKE_REQUEST_CAPTURE="$capture"
  export INSTALL_MODE=1 MARKETPLACE_SOURCE="$root/marketplace" MARKETPLACE_NAME=oh-no-harness PLUGIN_NAME=oh-no-harness
  export CODEX_HOME_DIR="$root/codex-home" RUN_DIR="$root/reused-run"
  mkdir -p "$RUN_DIR" "$CODEX_HOME_DIR"
  printf '%s\n' '9.9.9' >"$RUN_DIR/installed-plugin-version.txt"
  printf '%s\n' 'partial' >"$RUN_DIR/installed-plugin-version.tmp"
  printf '%s\n' '{}' >"$RUN_DIR/post-install-plugin-read.json"
  printf '%s\n' 'partial' >"$RUN_DIR/post-install-plugin-read.tmp"
  export CODEX_INSTALLED_PLUGIN_VERSION=9.9.9 CODEX_ACTIVE_PLUGIN_ROOT="$root/stale-root"
  export FAKE_MARKETPLACE_ADD_STATUS=73
  export -f install_via_codex_plugins codex_marketplace_exists codex_begin_install_attempt log ok fail
  rc=0
  bash -e -c 'set --; install_via_codex_plugins >/dev/null 2>&1' install-lifecycle || rc=$?
  [[ "$rc" == "73" ]] || fail "Codex install lifecycle fixture did not reach the controlled first marketplace add failure (rc=$rc)"
  [[ "$(<"$log")" == $'list-clean\nadd' ]] \
    || fail "Codex install lifecycle fixture did not prove cleanup before the first external marketplace actions: $(<"$log")"

  : >"$log"; rm -rf "$RUN_DIR" "$CODEX_HOME_DIR"; mkdir -p "$RUN_DIR" "$CODEX_HOME_DIR"
  export CODEX_INSTALLED_PLUGIN_VERSION="" CODEX_ACTIVE_PLUGIN_ROOT="" FAKE_MARKETPLACE_ADD_STATUS=0
  install_via_codex_plugins >/dev/null
  "$PYTHON_BIN" - "$capture" <<'PY'
import json
import sys
from pathlib import Path
message = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if message.get("id") != 5 or message.get("method") != "plugin/read":
    raise SystemExit(f"captured the wrong app-server request: {message!r}")
if message.get("params", {}).get("forceReload") is not True:
    raise SystemExit(f"post-install plugin/read did not force reload: {message!r}")
PY
  [[ "$(<"$RUN_DIR/installed-plugin-version.txt")" == "2.1.0" ]] \
    || fail "Codex install integration fixture did not record the post-install nested summary"
  ok "Codex install clears stale identity before marketplace actions and force-reloads request 5"
)
run_codex_active_plugin_root_offline_test() {
  log "Running offline Codex active-plugin-root resolution guards"
  # Wrapper-activation evidence is bound to the root the run actually loads, so
  # resolution must be decided by MODE, not by how many cached versions happen to
  # exist. A single stale cached version is still stale; being the only candidate
  # does not make it this run's root. Conversely a no-install run loads from its
  # explicit PLUGIN_ROOT even when a cache is present, so a stale cache must never
  # win there. Each case runs in a subshell with its own disposable CODEX_HOME.
  local root manifest_version resolved rc expected
  root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-codex-active-root.XXXXXX")"
  trap 'rm -rf "$root"' RETURN
  manifest_version="$(json_value version)"
  [[ -n "$manifest_version" ]] || fail "Codex active-root test could not read the manifest version"
  # $1 = case label; $2 = install mode; $3 = space-separated cached versions to
  # create; $4 = expected resolved root ("FAIL" when resolution must fail closed);
  # $5 = version the install operation RECORDED ("" = nothing recorded);
  # $6 = version in the local source manifest (defaults to the real manifest).
  apr_case() {
    local label="$1" install_mode="$2" versions="$3" want="$4" recorded="${5:-}" source_version="${6:-$manifest_version}"
    local home cache version source_root run_dir
    home="$root/${label//[ \/]/-}"; cache="$home/plugins/cache/$MARKETPLACE_NAME/$PLUGIN_NAME"
    source_root="$home/source-plugin"; run_dir="$home/run"
    mkdir -p "$source_root/skills/ralph" "$source_root/.codex-plugin" "$run_dir"
    printf '%s\n' "wrapper" >"$source_root/skills/ralph/SKILL.md"
    # The LOCAL manifest may deliberately disagree with the installed version: that
    # skew is the whole point of these cases.
    printf '{"name":"%s","version":"%s"}\n' "$PLUGIN_NAME" "$source_version" \
      >"$source_root/.codex-plugin/plugin.json"
    for version in $versions; do
      mkdir -p "$cache/$version/skills/ralph"
      printf '%s\n' "wrapper" >"$cache/$version/skills/ralph/SKILL.md"
    done
    [[ -z "$recorded" ]] || printf '%s\n' "$recorded" >"$run_dir/installed-plugin-version.txt"
    rc=0
    resolved="$(
      CODEX_ACTIVE_PLUGIN_ROOT=""
      CODEX_INSTALLED_PLUGIN_VERSION=""
      CODEX_HOME_DIR="$home"
      INSTALL_MODE="$install_mode"
      PLUGIN_ROOT="$source_root"
      RUN_DIR="$run_dir"
      codex_active_plugin_root 2>/dev/null
    )" || rc=$?
    if [[ "$want" == "FAIL" ]]; then
      [[ "$rc" != 0 ]] || fail "Codex active-root resolution accepted $label instead of failing closed (got: $resolved)"
      return 0
    fi
    expected="$("$PYTHON_BIN" -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve())' "$want")"
    [[ "$rc" == 0 ]] || fail "Codex active-root resolution failed closed on $label, which is resolvable"
    [[ "$resolved" == "$expected" ]] || fail "Codex active-root resolution bound $label to $resolved instead of $expected"
  }
  apr_cache() { printf '%s/%s/plugins/cache/%s/%s/%s' "$root" "$1" "$MARKETPLACE_NAME" "$PLUGIN_NAME" "$2"; }
  # Install mode binds to the version the INSTALL recorded.
  apr_case "install current only" 1 "$manifest_version" "$(apr_cache install-current-only "$manifest_version")" "$manifest_version"
  apr_case "install multiple with recorded present" 1 "0.0.1 $manifest_version 99.0.0" "$(apr_cache install-multiple-with-recorded-present "$manifest_version")" "$manifest_version"
  # H) SOURCE/INSTALLED SKEW. The checkout is bumped to 2.2.0 while the installed
  #    tree is still 2.1.0. Binding to the local manifest names a nonexistent
  #    directory; binding to the recorded installed version is correct.
  apr_case "install source 2.2.0 with installed 2.1.0" 1 "2.1.0" "$(apr_cache install-source-2.2.0-with-installed-2.1.0 2.1.0)" "2.1.0" "2.2.0"
  # H) STALE MATCHING-LOCAL-CACHE DECOY. Under the same skew a stale 2.2.0 directory
  #    also exists, so a local-manifest resolver would happily bind to a tree the run
  #    never loaded. The recorded installed version must still win.
  apr_case "install stale local-matching cache decoy" 1 "2.1.0 2.2.0" "$(apr_cache install-stale-local-matching-cache-decoy 2.1.0)" "2.1.0" "2.2.0"
  # H) A remote marketplace-style source has no local manifest version to fall back
  #    on at all, so only the recorded identity can resolve it.
  apr_case "install from remote marketplace-style source" 1 "2.1.0" "$(apr_cache install-from-remote-marketplace-style-source 2.1.0)" "2.1.0" "0.0.0-unknown"
  # Fail-closed: nothing recorded, and a recorded version with no matching tree.
  apr_case "install with no recorded version" 1 "$manifest_version" FAIL ""
  apr_case "install recorded version absent from cache" 1 "0.0.1 0.0.2" FAIL "$manifest_version"
  apr_case "install empty cache" 1 "" FAIL "$manifest_version"
  # A SOLE stale cached version must fail closed: singularity is not identity.
  apr_case "install sole stale cache with mismatched record" 1 "0.0.1" FAIL "$manifest_version"
  # No-install mode binds to the explicit source root regardless of cache contents,
  # and regardless of any recorded installed version.
  apr_case "no-install with no cache" 0 "" "$root/no-install-with-no-cache/source-plugin" ""
  apr_case "no-install with stale cache" 0 "0.0.1" "$root/no-install-with-stale-cache/source-plugin" ""
  apr_case "no-install with current cache" 0 "$manifest_version" "$root/no-install-with-current-cache/source-plugin" ""
  apr_case "no-install ignores a recorded installed version" 0 "2.1.0" "$root/no-install-ignores-a-recorded-installed-version/source-plugin" "2.1.0" "2.2.0"
  # --- item 5 lifecycle: the record must be run-bound, post-install, and atomic ---
  # A REUSED RUN_DIR holding a stale record must not be trusted: install removes any
  # prior record first, so a stale record with no matching cache tree fails closed.
  apr_case "install reused RUN_DIR stale record" 1 "2.1.0" FAIL "9.9.9"
  # An abandoned atomic temp file is not a record.
  apr_lifecycle_case() {
    local label="$1" want="$2" home cache run_dir source_root
    home="$root/${label//[ \/]/-}"; cache="$home/plugins/cache/$MARKETPLACE_NAME/$PLUGIN_NAME"
    run_dir="$home/run"; source_root="$home/source-plugin"
    mkdir -p "$source_root/skills/ralph" "$source_root/.codex-plugin" "$run_dir" "$cache/2.1.0/skills/ralph"
    printf '%s\n' "wrapper" >"$source_root/skills/ralph/SKILL.md"
    printf '{"name":"%s","version":"2.2.0"}\n' "$PLUGIN_NAME" >"$source_root/.codex-plugin/plugin.json"
    printf '%s\n' "wrapper" >"$cache/2.1.0/skills/ralph/SKILL.md"
    shift 2
    "$@" "$run_dir" "$cache"
    rc=0
    resolved="$(
      CODEX_ACTIVE_PLUGIN_ROOT=""; CODEX_INSTALLED_PLUGIN_VERSION=""
      CODEX_HOME_DIR="$home"; INSTALL_MODE=1; PLUGIN_ROOT="$source_root"; RUN_DIR="$run_dir"
      codex_active_plugin_root 2>/dev/null
    )" || rc=$?
    if [[ "$want" == "FAIL" ]]; then
      [[ "$rc" != 0 ]] || fail "Codex active-root resolution accepted $label instead of failing closed (got: $resolved)"
    else
      local expected
      expected="$("$PYTHON_BIN" -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve())' "$cache/$want")"
      [[ "$rc" == 0 && "$resolved" == "$expected" ]] \
        || fail "Codex active-root resolution bound $label to '$resolved' (rc=$rc) instead of $expected"
    fi
  }
  apr_only_tempfile() { printf '2.1.0' >"$1/installed-plugin-version.tmp"; }
  apr_no_record()     { : ; }
  apr_empty_record()  { : >"$1/installed-plugin-version.txt"; }
  apr_good_record()   { printf '2.1.0\n' >"$1/installed-plugin-version.txt"; }
  apr_blank_record()  { printf '   \n' >"$1/installed-plugin-version.txt"; }
  # An interrupted atomic write leaves only the .tmp file, which is not identity.
  apr_lifecycle_case "install abandoned atomic temp only" FAIL apr_only_tempfile
  # A failed install writes nothing, so there is no record to read.
  apr_lifecycle_case "install failed leaves no record" FAIL apr_no_record
  # A truncated/empty or whitespace-only record is not identity. These two are
  # REGRESSION GUARDS, not discriminating fixtures: an empty version also fails the
  # subsequent cache-path check, so they hold even without the emptiness guard in
  # codex_installed_plugin_version. That guard is defense in depth.
  apr_lifecycle_case "install empty record" FAIL apr_empty_record
  apr_lifecycle_case "install blank record" FAIL apr_blank_record
  # A successful post-install record resolves, even though the LOCAL manifest says
  # 2.2.0 -- proving the local manifest is not consulted.
  apr_lifecycle_case "install successful post-install record" "2.1.0" apr_good_record
  # Retry semantics: a stale record replaced by the correct one resolves.
  apr_retry_record() { printf '9.9.9\n' >"$1/installed-plugin-version.txt"; printf '2.1.0\n' >"$1/installed-plugin-version.txt"; }
  apr_lifecycle_case "install retry overwrites stale record" "2.1.0" apr_retry_record
  rm -rf "$root"; trap - RETURN
  ok "Codex active plugin root resolves by mode and rejects stale cached versions"
}
codex_run_oracle_script() {
  local script marker_lines
  script="$(cat)"
  # Require EXACTLY ONE marker LINE. A substring test passed when the marker merely
  # appeared inside a string or comment (where no substitution happens), and it also
  # passed with duplicate markers, which would inject the helpers twice and let the
  # second copy silently redefine the first.
  marker_lines="$(printf '%s\n' "$script" | grep -c '^#@SHARED_HELPERS@$' || true)"
  [[ "$marker_lines" == "1" ]] \
    || fail "oracle script needs exactly one '#@SHARED_HELPERS@' marker line, found $marker_lines"
  # Compose through files. Bash-level assembly was far too slow on bash 3.2 (the
  # macOS default): both `${var//pat/rep}` and a per-line read loop over this
  # ~15KB oracle cost seconds per call, which multiplied across the fixture suite
  # into minutes. `awk` streams it in one pass instead.
  local dir composed helpers_file status=0
  dir="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-codex-oracle.XXXXXX")"
  composed="$dir/oracle.py"; helpers_file="$dir/helpers.py"
  codex_oracle_shared_helpers >"$helpers_file"
  # awk reports the substitution count so injection integrity is PROVEN, not assumed.
  local substitutions
  substitutions="$(awk -v helpers="$helpers_file" '
    $0 == "#@SHARED_HELPERS@" { n += 1; while ((getline line < helpers) > 0) print line > out; close(helpers); next }
    { print > out }
    END { print n + 0 }
  ' out="$composed" <<<"$script")"
  [[ "$substitutions" == "1" ]] \
    || fail "shared-helper injection substituted $substitutions times, expected exactly 1"
  # The composed oracle must retain no marker line.
  ! grep -q '^#@SHARED_HELPERS@$' "$composed" \
    || fail "composed oracle still contains a '#@SHARED_HELPERS@' marker line"
  "$PYTHON_BIN" "$composed" "$@" || status=$?
  rm -rf "$dir"
  return $status
}
# Shared Python helper source for the natural-activation and no-skill oracles.
# Both need the SAME bounded command extraction and completion-aware read
# semantics; a second hand-maintained copy in the no-skill lane diverged and
# silently kept the original free-regex false positives. This is emitted into
# each heredoc-generated oracle so there is exactly ONE implementation.
codex_oracle_shared_helpers() {
  cat <<'SHARED_HELPERS_PY'
read_tool_pattern = re.compile(r"(?:^|(?:-lc\s+)[\"']|(?:&&|[;|])\s*|\r?\n[ \t]*)(?:cat|sed|head|tail|more|less|nl)(?:\s|$)")
repo_path_pattern = re.compile(r"(?:^|[\s'\"/])(?:README[.]md|run[.]sh|src/|tests/|notes/)")
write_pattern = re.compile(r"\b(?:apply_patch|patch|touch|rm|mv|cp|chmod|install)\b|\b(?:sed|perl)\s+-i\b|" r"write_(?:text|bytes)|open\([^)]*,\s*['\"]?[wa]")
def collect_text(value): return value if isinstance(value, str) else "\n".join(collect_text(item) for item in value.values()) if isinstance(value, dict) else "\n".join(collect_text(item) for item in value) if isinstance(value, list) else ""
def reads_readme_command(command):
    """True only for a bounded read-tool command naming README.md as a path token."""
    return bool(read_tool_pattern.search(command)) and re.search(
        r"(?:^|[\s'\"/=])README[.]md(?=$|[\s'\";&|)])", command) is not None
def retained_output_result(output, call_status=None):
    """(exit status or None, retained body) for one matched child tool result."""
    structured = not isinstance(output, str)
    def structured_text(value):
        if isinstance(value, str):
            return value
        if isinstance(value, list):
            if not value:
                return None
            parts = [structured_text(item) for item in value]
            return None if any(part is None for part in parts) else "".join(parts)
        if isinstance(value, dict):
            if value.get("type") == "input_text" and isinstance(value.get("text"), str):
                return value["text"]
            present = [key for key in ("output", "content", "result", "text") if key in value]
            if len(present) == 1:
                return structured_text(value[present[0]])
        return None
    text = structured_text(output)
    if text is None:
        return None, ""
    observed_status = str(call_status or "").strip().lower()
    if observed_status and observed_status != "completed":
        return None, ""
    host_completed = re.findall(r"(?m)^\s*Script completed\s*$", text)
    host_failed = re.findall(r"(?m)^\s*Script failed\s*$", text)
    legacy = re.findall(r"(?m)^\s*Process exited with code\s+(\d+)\s*$", text)
    if (host_completed and host_failed) or len(host_completed) > 1 or len(host_failed) > 1 or len(legacy) > 1:
        return None, ""
    if structured and observed_status != "completed":
        return None, ""
    if host_completed or host_failed:
        if legacy:
            return None, ""
        status = 0 if host_completed else 1
    elif legacy:
        status = int(legacy[0])
    else:
        return None, ""
    body_match = re.search(r"(?ms)^Output:\s*\n(.*)\Z", text)
    return status, body_match.group(1) if body_match else ""
# One custom-tool input can batch SEVERAL tools.exec_command(...) calls, and the
# JS object key appears both quoted (`"cmd":`) and bare (`cmd:`). Recovering only
# the FIRST `"cmd"` hid every later command, so a child whose repository read was
# its second embedded call looked like it never read anything.
#
# A free `cmd:"…"` regex over the whole input was the opposite error: an unrelated
# object literal (`const metadata = {cmd:"nl -ba README.md"}`) or a `//` comment
# manufactured a repository read that never executed, and since the surrounding
# call's own output was successful and nonempty every completion-side guard passed.
# Only INVOCATION scoping can reject that, so a `cmd` value counts solely when it
# is a key of the object literal passed as an `exec_command(...)` argument.
#
# This is deliberately NOT a JavaScript parser. It is a bounded scanner over the
# captured shapes: quote/escape-aware strings, `//` and `/* */` comments, balanced
# parentheses/braces/brackets, and one flat argument object whose keys are bare or
# quoted identifiers. Anything outside that contract -- a non-object argument, an
# unterminated string or comment, a malformed key/value, a non-string or
# non-double-quoted `cmd` -- yields NO command for that call rather than a guess.
# Approved receivers, matched LEXICALLY rather than by a regex that may restart
# inside a longer token. `exec_command` is a call site only when the token
# immediately before it is nothing, `tools.`, or `functions.` (spaces around the
# dot allowed, as the host emits). `other . exec_command` and a bare word butted
# against the name (`narrative exec_command`) are different receivers, so a regex
# lookbehind alone -- which only inspects the single previous character -- cannot
# decide this. The scanner therefore anchors on the NAME and walks backwards.
exec_name_pattern = re.compile(r"exec_command\s*[(]")
js_identifier_pattern = re.compile(r"[A-Za-z_$][A-Za-z0-9_$]*")
js_identifier_tail = re.compile(r"[A-Za-z0-9_$]")
# Keywords that may legally sit immediately before a bare call expression. Any
# other bare word before `exec_command(` is prose, not an invocation.
js_expression_keywords = {"await", "return", "yield", "typeof", "void", "new"}
def js_prev_token(text, index):
    """The identifier/punctuation token ending at or before index.

    Returns (kind, value, start) where kind is "word", "dot", "other", or "bos".
    A LINE BREAK is reported as a statement boundary ("bos"), not skipped: JavaScript
    terminates statements at a newline, so `const r = placeholder\\nawait tools.…`
    starts a NEW statement. Treating the newline as insignificant whitespace made the
    token chain read `placeholder await tools .`, which rejected a perfectly valid
    call and silently dropped its command -- including real mutations -- from the
    safety records. Horizontal whitespace is still skipped.
    """
    cursor = index
    while cursor >= 0 and text[cursor] in " \t":
        cursor -= 1
    if cursor >= 0 and text[cursor] in "\r\n":
        return ("bos", "", cursor)
    if cursor < 0:
        return ("bos", "", 0)
    if text[cursor] == ".":
        return ("dot", ".", cursor)
    if js_identifier_tail.match(text[cursor]):
        end = cursor + 1
        while cursor >= 0 and js_identifier_tail.match(text[cursor]):
            cursor -= 1
        return ("word", text[cursor + 1:end], cursor + 1)
    return ("other", text[cursor], cursor)
def js_approved_receiver(text, name_start):
    """True when the exec_command token at name_start is a genuine invocation.

    The ENTIRE prefix chain is validated, not just one token. An earlier version
    inspected a single preceding token, so `narrative await exec_command(...)` and
    `narrative tools.exec_command(...)` passed: the `await`/`tools.` immediately
    before the name looked approved while the prose word in front of it was never
    examined. Accepted shapes are exactly:
        exec_command(                      -- bare, at a statement/expression start
        <kw> exec_command(                 -- kw in js_expression_keywords
        tools|functions . exec_command(    -- optionally preceded by one <kw>
    Anything else, including a bare identifier anywhere in the chain, is prose.
    """
    kind, value, start = js_prev_token(text, name_start - 1)
    if kind == "dot":
        # Dotted form: the receiver must be exactly `tools` or `functions`.
        kind, value, start = js_prev_token(text, start - 1)
        if kind != "word" or value not in {"tools", "functions"}:
            return False
        kind, value, start = js_prev_token(text, start - 1)
    if kind == "bos":
        return True
    if kind == "other":
        # Punctuation (`=`, `(`, `,`, `;`, an operator) is an expression boundary.
        return True
    if kind != "word" or value not in js_expression_keywords:
        return False
    # A keyword is allowed, but only when IT is itself expression-initial. This is
    # what rejects `narrative await exec_command(...)`.
    kind, value, start = js_prev_token(text, start - 1)
    return kind in {"bos", "other"}
def js_skip_gap(text, index):
    """Advance past whitespace and comments. -1 marks an unterminated comment."""
    limit = len(text)
    while index < limit:
        if text[index] in " \t\r\n":
            index += 1
        elif text.startswith("//", index):
            stop = text.find("\n", index)
            index = limit if stop < 0 else stop + 1
        elif text.startswith("/*", index):
            stop = text.find("*/", index)
            if stop < 0:
                return -1
            index = stop + 2
        else:
            break
    return index
def js_read_string(text, index):
    """Read the string literal opening at text[index]. -1 marks unterminated."""
    quote, limit, cursor = text[index], len(text), index + 1
    while cursor < limit:
        char = text[cursor]
        if char == "\\":
            cursor += 2
            continue
        if char == quote:
            return cursor + 1, text[index:cursor + 1]
        if char == "\n" and quote != "`":
            return -1, ""
        cursor += 1
    return -1, ""
js_closer_for = {"{": "}", "[": "]", "(": ")"}
def js_skip_value(text, index):
    """Consume a non-string value, stopping at its object's `,` or closer.

    Nesting is tracked with a TYPED stack, so a mismatched closer is malformed
    rather than merely decrementing a counter. An untyped depth counter accepted
    `(]` as balanced, which let a syntactically impossible argument object parse and
    still yield a credited command.
    """
    limit, stack, cursor = len(text), [], index
    while cursor < limit:
        char = text[cursor]
        if char in "\"'`":
            cursor, _ = js_read_string(text, cursor)
            if cursor < 0:
                return -1
            continue
        if text.startswith("//", cursor) or text.startswith("/*", cursor):
            cursor = js_skip_gap(text, cursor)
            if cursor < 0:
                return -1
            continue
        if char in js_closer_for:
            stack.append(js_closer_for[char])
        elif char in "}])":
            if not stack:
                return cursor
            if stack[-1] != char:
                return -1
            stack.pop()
        elif char == "," and not stack:
            return cursor
        cursor += 1
    return -1
def js_exec_argument_cmd(text, index):
    """Parse the argument object at text[index] == '{'.

    Returns (end_offset, cmd_or_None); (-1, None) when the shape is unsupported.
    Only a `cmd` key at this object's own top level is recognized, so a `cmd`
    nested inside another value stays invisible.
    """
    limit, command = len(text), None
    cursor = js_skip_gap(text, index + 1)
    if cursor < 0:
        return -1, None
    if cursor < limit and text[cursor] == "}":
        return cursor + 1, None
    while cursor < limit:
        if text[cursor] in "\"'":
            cursor, raw_key = js_read_string(text, cursor)
            if cursor < 0:
                return -1, None
            key = raw_key[1:-1]
        else:
            key_match = js_identifier_pattern.match(text, cursor)
            if not key_match:
                return -1, None
            key, cursor = key_match.group(0), key_match.end()
        cursor = js_skip_gap(text, cursor)
        if cursor < 0 or cursor >= limit or text[cursor] != ":":
            return -1, None
        cursor = js_skip_gap(text, cursor + 1)
        if cursor < 0 or cursor >= limit:
            return -1, None
        if text[cursor] in "\"'`":
            cursor, raw_value = js_read_string(text, cursor)
            if cursor < 0:
                return -1, None
            if key == "cmd":
                # The host always emits a double-quoted JSON-compatible command
                # string; anything else is not decodable here without guessing.
                if raw_value[0] != '"':
                    return -1, None
                try:
                    decoded = json.loads(raw_value)
                except json.JSONDecodeError:
                    return -1, None
                command = decoded
        else:
            cursor = js_skip_value(text, cursor)
            if cursor < 0:
                return -1, None
            if key == "cmd":
                return -1, None
        cursor = js_skip_gap(text, cursor)
        if cursor < 0 or cursor >= limit:
            return -1, None
        if text[cursor] == "}":
            return cursor + 1, command
        if text[cursor] != ",":
            return -1, None
        cursor = js_skip_gap(text, cursor + 1)
        if cursor < 0:
            return -1, None
        if cursor < limit and text[cursor] == "}":
            return cursor + 1, command
    return -1, None
# The result variable a call is assigned to (`const r2 = await tools.exec_command`),
# needed to decide WHICH batched command the single retained output describes.
#
# Assignment parsing must TERMINATE at the call expression. A pattern that bridged
# arbitrary identifier/dot/whitespace runs matched across a statement boundary, so
# `const r = placeholder\nawait tools.exec_command(...)` bound the call to `r`
# even though `r` actually holds `placeholder`. Only the supported optional `await`
# and the approved receiver syntax may sit between the `=` and the call name; the
# `=` itself must not be part of `==`/`!=`/`<=`/`>=`/`=>`.
js_assignment_pattern = re.compile(
    r"(?:(?:const|let|var)\s+)?(?P<name>[A-Za-z_$][A-Za-z0-9_$]*)\s*(?<![=!<>])=(?![=>])\s*"
    r"(?:await\s+)?(?:(?:tools|functions)\s*[.]\s*)?\Z")
# The result actually captured into the host-retained output. This must be an
# EXECUTABLE sink: a commented-out `text(r.output)` and the literal string
# "r.output" are data, and crediting them let a child narrate a capture it never
# performed. Candidate sinks are therefore discovered only in executable regions,
# which js_executable_spans computes with the same quote/comment awareness the rest
# of this scanner uses.
js_capture_pattern = re.compile(r"(?<![A-Za-z0-9_$.])text\s*[(]\s*(?P<name>[A-Za-z_$][A-Za-z0-9_$]*)\s*[.]\s*output\s*[)]")
# A `/` starts a REGEX LITERAL only where a value may begin. After an identifier,
# a number, or a closing `)`/`]`/`}` it is division instead. Getting this wrong in
# either direction is unsafe, so the decision uses the previous significant token.
js_regex_prefix_words = {"return", "typeof", "void", "case", "in", "of", "new",
                         "delete", "instanceof", "await", "yield", "do", "else"}
def js_regex_allowed_at(text, index):
    """True when text[index] == '/' begins a regex literal rather than division."""
    kind, value, _ = js_prev_token(text, index - 1)
    if kind == "bos":
        return True
    if kind == "word":
        return value in js_regex_prefix_words
    if kind == "dot":
        return False
    # Punctuation: a value may follow `=`, `(`, `,`, `:`, `[`, operators, etc., but
    # NOT a closing delimiter (that is division on the preceding expression).
    return value not in {")", "]", "}"}
def js_read_regex(text, index):
    """Index just past the regex literal opening at text[index]. -1 = unterminated.

    Escapes and character classes are honoured: inside `[...]` a `/` does not end the
    literal, and `\\/` never does.
    """
    limit, cursor, in_class = len(text), index + 1, False
    while cursor < limit:
        char = text[cursor]
        if char == "\\":
            cursor += 2
            continue
        if char == "\n":
            return -1
        if in_class:
            if char == "]":
                in_class = False
        elif char == "[":
            in_class = True
        elif char == "/":
            cursor += 1
            # Trailing flags belong to the token.
            while cursor < limit and js_identifier_tail.match(text[cursor]):
                cursor += 1
            return cursor
        cursor += 1
    return -1
def js_read_template(text, index):
    """(end_index, executable_spans) for the template literal at text[index].

    Raw template text is DATA. `${...}` substitutions are executable, so their
    interiors are returned as spans. -1 marks an unterminated template.
    """
    limit, cursor, spans = len(text), index + 1, []
    while cursor < limit:
        char = text[cursor]
        if char == "\\":
            cursor += 2
            continue
        if char == "`":
            return cursor + 1, spans
        if text.startswith("${", cursor):
            depth, start = 1, cursor + 2
            scan = start
            while scan < limit and depth:
                inner = text[scan]
                if inner in "\"'`":
                    if inner == "`":
                        scan, nested = js_read_template(text, scan)
                        if scan < 0:
                            return -1, spans
                        spans.extend(nested)
                    else:
                        scan, _ = js_read_string(text, scan)
                        if scan < 0:
                            return -1, spans
                    continue
                if inner == "{":
                    depth += 1
                elif inner == "}":
                    depth -= 1
                    if not depth:
                        break
                scan += 1
            if depth:
                return -1, spans
            spans.append((start, scan))
            cursor = scan + 1
            continue
        cursor += 1
    return -1, spans
def js_executable_spans(text):
    """(start, end) spans of `text` that are real code, not data.

    Data means strings, template RAW text, comments, AND regex literals. The regex
    case is the subtle one: `/const r = await tools.exec_command(...)/` is a single
    token whose body looks like ordinary code to a scanner that only skips quotes and
    comments, so it fabricated a complete credited read out of a pattern.

    Template `${...}` substitutions ARE executable and are emitted as spans; the raw
    text around them is not. An unterminated construct truncates the span list, which
    fails closed for positive evidence.
    """
    spans, limit, cursor, span_start = [], len(text), 0, 0
    while cursor < limit:
        char = text[cursor]
        if char == "`":
            spans.append((span_start, cursor))
            cursor, interpolations = js_read_template(text, cursor)
            if cursor < 0:
                return spans
            spans.extend(interpolations)
            span_start = cursor
            continue
        if char in "\"'":
            spans.append((span_start, cursor))
            cursor, _ = js_read_string(text, cursor)
            if cursor < 0:
                return spans
            span_start = cursor
            continue
        if text.startswith("//", cursor) or text.startswith("/*", cursor):
            spans.append((span_start, cursor))
            cursor = js_skip_gap(text, cursor)
            if cursor < 0:
                return spans
            span_start = cursor
            continue
        if char == "/" and js_regex_allowed_at(text, cursor):
            spans.append((span_start, cursor))
            cursor = js_read_regex(text, cursor)
            if cursor < 0:
                return spans
            span_start = cursor
            continue
        cursor += 1
    spans.append((span_start, limit))
    return spans
def js_capture_sites(raw_text):
    """(result_name, offset) for each executable output sink, in source order."""
    sites = []
    for start, end in js_executable_spans(raw_text):
        for match in js_capture_pattern.finditer(raw_text, start, end):
            sites.append((match.group("name"), match.start()))
    sites.sort(key=lambda site: site[1])
    return sites
def captured_result_name(raw_text):
    """The single result variable whose output was retained, else None.

    Zero captures and several DIFFERENT captured results both return None: the
    retained output cannot be attributed to one command, so no command may claim it.
    """
    names = {name for name, _ in js_capture_sites(raw_text)}
    return next(iter(names)) if len(names) == 1 else None
def embedded_commands(raw_text):
    """Every `cmd` actually passed to an exec_command(...) call, in source order."""
    return [command for command, _, _ in embedded_command_records(raw_text)]
# Control-flow keywords whose presence makes straight-line reachability undecidable
# for this bounded scanner. Conditional execution is exactly the case where an
# assignment may or may not reach the capture, so it must fail closed.
js_control_keywords = re.compile(r"(?<![A-Za-z0-9_$.])(?:if|else|for|while|do|switch|case|try|catch|finally)(?![A-Za-z0-9_$])")
def js_control_flow_between(text, start, end):
    """True when a control-flow construct appears in executable code in [start,end)."""
    lo, hi = min(start, end), max(start, end)
    for span_start, span_end in js_executable_spans(text):
        window_lo, window_hi = max(span_start, lo), min(span_end, hi)
        if window_lo >= window_hi:
            continue
        if js_control_keywords.search(text, window_lo, window_hi):
            return True
        # A ternary `?` between the assignment and the capture is also conditional.
        if "?" in text[window_lo:window_hi]:
            return True
    return False
def js_straight_line_between(text, owner_offset, site_offset):
    """True when the owning assignment plainly reaches the capture.

    Requirements, all bounded: no control-flow construct between them, and neither
    endpoint nested more deeply in braces than the other (which would mean the
    assignment lives inside a block the capture is outside of, or vice versa).
    """
    if js_control_flow_between(text, owner_offset, site_offset):
        return False
    # Brace depth is computed over executable spans only, so a `{` inside a string
    # or regex cannot change it.
    def depth_at(target):
        depth = 0
        for span_start, span_end in js_executable_spans(text):
            for index in range(span_start, min(span_end, target)):
                if text[index] == "{":
                    depth += 1
                elif text[index] == "}":
                    depth -= 1
        return depth
    if depth_at(owner_offset) != depth_at(site_offset):
        return False
    # A control-flow construct ANYWHERE before the assignment can still make the
    # assignment conditional (e.g. an `if` block that assigns and falls through), so
    # require the owning assignment itself not to sit inside a nested block.
    return depth_at(owner_offset) == 0
def embedded_command_ownership(raw_text):
    """(command, owns_retained_output) per real call, in source order.

    Ownership is TEMPORAL: the retained output belongs to the latest assignment of
    the captured variable that still REACHES the capture. Matching on variable name
    alone credited an earlier command whose result had already been overwritten and
    never retained -- and, with one variable assigned twice, credited BOTH.
    """
    records = embedded_command_records(raw_text)
    sites = js_capture_sites(raw_text)
    # EXACTLY ONE supported capture site. Several sites -- even naming the same
    # variable -- mean the retained output cannot be tied to one command.
    if len(sites) != 1:
        return [(command, False) for command, _, _ in records]
    captured, site_offset = sites[0]
    # Among calls bound to the captured variable, only the LATEST one before the
    # capture can have produced the retained output.
    candidates = [offset for _, name, offset in records
                  if name == captured and offset < site_offset]
    if not candidates:
        return [(command, False) for command, _, _ in records]
    owner_offset = max(candidates)
    # CONTROL FLOW. Straight-line reachability is required. If the owning assignment
    # or the capture sits inside a branch or loop, or the variable is assigned in
    # more than one branch, which assignment actually reaches the capture is not
    # decidable by this bounded scanner -- so read credit fails closed. Every real
    # exec call still remains a RECORD for mutation/safety detection.
    if not js_straight_line_between(raw_text, owner_offset, site_offset):
        return [(command, False) for command, _, _ in records]
    if len(candidates) > 1 and js_control_flow_between(raw_text, min(candidates), site_offset):
        return [(command, False) for command, _, _ in records]
    return [(command, offset == owner_offset) for command, _, offset in records]
def js_statement_start(text, offset):
    """Offset of the innermost enclosing statement/block boundary before `offset`.

    Bounded and quote/comment aware: the boundary is the latest `;`, LF, `{`, `}`,
    `(`, `,`, or `?`/`:` that lies in an EXECUTABLE span. Assignment ownership may
    only be sought within this window, which is what stops
    `const r = placeholder\\nawait tools.exec_command(...)` from binding the call to
    `r` -- the newline ends that statement.
    """
    boundary = 0
    for start, end in js_executable_spans(text):
        for index in range(start, min(end, offset)):
            if text[index] in ";\n{}(,?:":
                boundary = index + 1
    return boundary
def embedded_command_records(raw_text):
    """(command, result_variable_or_None, offset) per real exec_command call.

    CALL RECOGNITION IS SEPARATE FROM OWNERSHIP. A syntactically valid call in a new
    statement is always a record even when no variable owns it; previously a failed
    assignment match silently discarded the whole call, so a real
    `sed -i` mutation after a placeholder assignment VANISHED from the safety
    records. Only an invalid/prose prefix yields no record at all.
    """
    found = []
    for span_start, span_end in js_executable_spans(raw_text):
        cursor = span_start
        while cursor < span_end:
            call_match = exec_name_pattern.match(raw_text, cursor)
            if not call_match or call_match.end() > span_end or not js_approved_receiver(raw_text, cursor):
                cursor += 1
                continue
            argument_start = js_skip_gap(raw_text, call_match.end())
            if argument_start < 0:
                break
            cursor = call_match.end()
            if argument_start >= span_end or raw_text[argument_start] != "{":
                continue
            end_offset, command = js_exec_argument_cmd(raw_text, argument_start)
            if end_offset < 0:
                continue
            # INVOCATION CLOSURE: the call is only a call once its own `)` is present.
            # A truncated transcript can end mid-invocation with a well-formed
            # argument object, and crediting that would invent an unfinished read.
            closing = js_skip_gap(raw_text, end_offset)
            if closing < 0 or closing >= len(raw_text) or raw_text[closing] != ")":
                cursor = end_offset
                continue
            if isinstance(command, str) and command.strip():
                # Ownership is sought only inside the call's OWN statement, so an
                # assignment in a previous statement cannot claim it.
                window = js_statement_start(raw_text, call_match.start())
                assigned = js_assignment_pattern.search(raw_text, window, call_match.start())
                # The call's own offset travels with the record: result ownership is
                # TEMPORAL, so a later reassignment of the same variable supersedes.
                found.append((command, assigned.group("name") if assigned else None, call_match.start()))
            cursor = closing + 1
    found.sort(key=lambda record: record[2])
    return found
def command_records_from_event(data):
    """(command, output_is_this_command's) per shell command an event records.

    A parent `command_execution` stays exactly ONE evidence record (its whole
    command string, compound segments included) and owns its own completion. A
    child exec tool call yields one record per embedded command so read and
    mutation predicates apply to each independently -- but the call retains only
    ONE output, so at most one embedded command may claim it.
    """
    item = data.get("item") or {}
    payload = data.get("payload") or {}
    if item.get("type") == "command_execution":
        command = str(item.get("command") or "")
        return [(command, True)] if command else []
    # Child subagent transcripts (codex-cli >= 0.146) record shell work as a
    # custom_tool_call named "exec" whose input is a JS snippet wrapping
    # tools.exec_command({"cmd": ...}), not a function_call with JSON arguments.
    # Reading only the function_call shape found 0 of 2 real child commands.
    if (payload.get("type") == "function_call" and payload.get("name") in {"exec_command", "functions.exec_command"}) \
            or (payload.get("type") == "custom_tool_call" and payload.get("name") in {"exec", "functions.exec"}):
        raw = payload.get("arguments") or payload.get("input") or ""
        raw_text = raw if isinstance(raw, str) else json.dumps(raw)
        if not raw_text:
            return []
        try:
            arguments_data = json.loads(raw_text)
        except json.JSONDecodeError:
            # The JS wrapper is not JSON; recover every embedded cmd string so the
            # read/mutation patterns match the actual commands rather than the
            # surrounding JavaScript.
            # The retained output is whatever the script CAPTURED, so read evidence
            # follows the capture link uniformly -- no special case for a lone call.
            # No capture, an unsupported combination of several results, a call whose
            # result was never assigned, and a call whose result was overwritten
            # before the capture all leave the outcome unknown, which fails closed
            # rather than borrowing another command's success.
            return embedded_command_ownership(raw_text)
        if isinstance(arguments_data, dict):
            command = arguments_data.get("cmd")
            if isinstance(command, str) and command.strip():
                return [(command, True)]
        return []
    return []
def commands_from_event(data):
    return [command for command, _ in command_records_from_event(data)]
def safety_inspectable_commands(data):
    """Every command an event ISSUED, for forbidden-write / host-egress inspection.

    Safety inspection is deliberately independent of completion-sensitive positive
    evidence. A command counts here as soon as it was issued, even when its result
    was never retained and even when read-credit logic would fail closed -- an
    unobserved `rm -rf` is still a violation. Every embedded command of a batched
    `custom_tool_call` is inspected, not just the first: the old inspectors matched
    only `function_call`/`command_execution`, so today's `custom_tool_call` name
    `exec` shape (and every command after the first inside it) went unexamined.
    """
    commands = [command for command, _ in command_records_from_event(data)]
    if commands:
        return commands
    # A JS wrapper input that yielded NO call is prose, a comment, or a regex: it
    # must not be handed to the safety patterns as if it were a command, or
    # `// rm -rf src` would raise a violation for a line that never ran. Only a
    # plain non-JS command string (the parent `command_execution` shape, or a
    # function_call whose JSON arguments failed to parse) is worth falling back to.
    item = data.get("item") or {}
    payload = data.get("payload") or {}
    command = item.get("command")
    if isinstance(command, str) and command.strip():
        return [command]
    if payload.get("type") == "function_call":
        raw = payload.get("arguments")
        if isinstance(raw, str) and raw.strip() and "exec_command" not in raw:
            try:
                decoded = json.loads(raw)
            except json.JSONDecodeError:
                return [raw]
            if isinstance(decoded, dict):
                value = decoded.get("cmd") or decoded.get("command")
                if isinstance(value, str) and value.strip():
                    return [value]
    return []
FUSION_WRITE_STDIN_MAX_OUTPUT_TOKENS = 12000


def fusion_parent_observed_result_text(data):
    """Return parent-owned observed output, never prompts or tool-request instructions."""
    item = data.get("item") or {}
    if item.get("type") == "agent_message":
        return collect_text(item.get("text") or item.get("content") or "")
    payload = data.get("payload") or {}
    if data.get("type") == "event_msg" and payload.get("type") == "task_complete":
        return collect_text(payload.get("last_agent_message") or "")
    return ""


def fusion_provider_observed_success_markers(panel_results, parent_results):
    """Return exact success tokens found only on child/parent result surfaces."""
    text = "\n".join([
        *(str(value) for value in panel_results.values()),
        *(str(value) for value in parent_results),
    ])
    return [
        marker for marker in (
            "OH_NO_CODEX_FUSION_RESCUE_LIVE_OK",
            "OH_NO_CLAUDE_FUSION_PANEL_OK",
        )
        if marker in text
    ]


def fusion_launcher_proof(raw_text, budget):
    """Recognize one bounded Codex custom-exec Claude launcher, or fail closed."""
    def reject(reason):
        return {"ok": False, "reason": reason, "argv": [], "terminal_mode": None}

    if not isinstance(raw_text, str):
        return reject("custom exec input was not text")
    records = embedded_command_records(raw_text)
    if len(records) != 1:
        return reject("custom exec must contain exactly one exec_command operation")
    command, result_name, _ = records[0]
    if not result_name:
        return reject("custom exec result was not assigned")
    executable = "".join(raw_text[start:end] for start, end in js_executable_spans(raw_text))
    json_sinks = re.findall(
        r"(?<![A-Za-z0-9_$.])text\s*[(]\s*JSON[.]stringify\s*[(]\s*([A-Za-z_$][A-Za-z0-9_$]*)\s*[)]\s*[)]",
        executable,
    )
    output_sinks = re.findall(
        r"(?<![A-Za-z0-9_$.])text\s*[(]\s*([A-Za-z_$][A-Za-z0-9_$]*)\s*[.]\s*output\s*[)]",
        executable,
    )
    session_sinks = re.findall(
        r"if\s*[(]\s*([A-Za-z_$][A-Za-z0-9_$]*)[.]session_id\s*[)]\s*text\s*[(]\s*`SESSION_ID=[$][{]\1[.]session_id[}]`\s*[)]",
        raw_text,
    )
    all_text_calls = re.findall(r"(?<![A-Za-z0-9_$.])text\s*[(]", executable)
    if json_sinks == [result_name] and not output_sinks and not session_sinks and len(all_text_calls) == 1:
        pass
    elif output_sinks == [result_name] and len(session_sinks) <= 1 and all(name == result_name for name in session_sinks) and len(all_text_calls) == 1 + len(session_sinks):
        if session_sinks:
            expected = f"SESSION_ID=${{{result_name}.session_id}}"
            if expected not in raw_text:
                return reject("session sink was not derived from the retained result")
    else:
        return reject("custom exec lacked one retained sink for its assigned result")
    skeleton = [" "] * len(raw_text)
    for start, end in js_executable_spans(raw_text):
        skeleton[start:end] = raw_text[start:end]
    statements = [re.sub(r"\s+", " ", statement).strip() for statement in "".join(skeleton).split(";") if statement.strip()]
    first_statement = re.fullmatch(
        rf"const {re.escape(result_name)} = await (?:tools|functions)\s*[.]\s*exec_command\s*[(].*[)]",
        statements[0] if statements else "",
        re.S,
    )
    json_statement = re.fullmatch(rf"text\s*[(]\s*JSON[.]stringify\s*[(]\s*{re.escape(result_name)}\s*[)]\s*[)]", statements[1] if len(statements) > 1 else "")
    output_statement = re.fullmatch(rf"text\s*[(]\s*{re.escape(result_name)}[.]output\s*[)]", statements[1] if len(statements) > 1 else "")
    session_statement = re.fullmatch(rf"if\s*[(]\s*{re.escape(result_name)}[.]session_id\s*[)]\s*text\s*[(]\s*(?:{re.escape(result_name)}[.]session_id)?\s*[)]", statements[2] if len(statements) > 2 else "")
    if not first_statement or not (
        len(statements) == 2 and json_statement
        or len(statements) == 2 and output_statement and not session_sinks
        or len(statements) == 3 and output_statement and session_statement and session_sinks == [result_name]
    ):
        return reject("custom exec contained an unsupported JavaScript operation or statement")

    command_match = re.fullmatch(r"\s*(python|python3)\s+(-c|-)\s+(.*)\s*", command, re.S)
    if command_match is None:
        return reject("launcher was not bounded python -c or python - heredoc")
    mode, remainder = command_match.group(2), command_match.group(3)
    if mode == "-c":
        try:
            outer = shlex.split(command)
        except ValueError:
            return reject("python -c command was not shell-parseable")
        if len(outer) != 3 or Path(outer[0]).name not in {"python", "python3"} or outer[1] != "-c":
            return reject("python -c source was not one quoted literal argument")
        raw_argument = remainder.strip()
        if not raw_argument or raw_argument[0] not in {"'", '"'}:
            return reject("python -c source was not shell-quoted")
        python_source = outer[2]
    else:
        heredoc = re.fullmatch(r"<<(['\"])([A-Za-z_][A-Za-z0-9_]*)\1\r?\n(.*)\r?\n\2", remainder, re.S)
        if heredoc is None:
            return reject("python stdin source was not one exact quoted heredoc")
        python_source = heredoc.group(3)

    try:
        tree = ast.parse(python_source, mode="exec")
    except SyntaxError:
        return reject("Python launcher source was not parseable")
    if any(isinstance(node, (ast.Delete, ast.AugAssign, ast.AnnAssign, ast.NamedExpr, ast.Starred, ast.Lambda, ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)) for node in ast.walk(tree)):
        return reject("Python launcher used dynamic or mutable syntax")
    imports = []
    for statement in tree.body:
        if isinstance(statement, ast.Import):
            imports.extend((alias.name, alias.asname) for alias in statement.names)
        elif isinstance(statement, ast.ImportFrom):
            return reject("Python launcher used from-import")
    if len(imports) != len(set(imports)) or any(alias is not None for _, alias in imports) or set(name for name, _ in imports) != {"os", "subprocess"} | ({"sys"} if any(name == "sys" for name, _ in imports) else set()) or any(name not in {"os", "subprocess", "sys"} for name, _ in imports):
        return reject("Python launcher imports were not bounded")
    if not {"os", "subprocess"}.issubset({name for name, _ in imports}):
        return reject("Python launcher omitted required imports")

    assignments = {}
    store_counts = {}
    for node in ast.walk(tree):
        if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Store):
            store_counts[node.id] = store_counts.get(node.id, 0) + 1
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            assignments.setdefault(node.targets[0].id, []).append(node)
    run_calls = [
        node for node in ast.walk(tree)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
        and isinstance(node.func.value, ast.Name) and node.func.value.id == "subprocess" and node.func.attr == "run"
    ]
    subprocess_calls = [
        node for node in ast.walk(tree)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
        and isinstance(node.func.value, ast.Name) and node.func.value.id == "subprocess"
    ]
    if len(run_calls) != 1 or subprocess_calls != run_calls:
        return reject("Python launcher must call subprocess.run exactly once")
    run_call = run_calls[0]
    result_assignments = [
        node for nodes in assignments.values() for node in nodes if node.value is run_call
    ]
    if len(result_assignments) != 1:
        return reject("subprocess result lacked one immutable binding")
    result_stmt = result_assignments[0]
    result_name = result_stmt.targets[0].id
    if store_counts.get(result_name) != 1 or len(run_call.args) != 1 or not isinstance(run_call.args[0], ast.Name):
        return reject("subprocess result or argv binding was ambiguous")
    argv_name = run_call.args[0].id
    if len(assignments.get(argv_name, [])) != 1 or store_counts.get(argv_name) != 1:
        return reject("argv was reassigned or aliased")
    argv_stmt = assignments[argv_name][0]
    if argv_stmt.lineno >= result_stmt.lineno or not isinstance(argv_stmt.value, ast.List):
        return reject("argv did not dominate subprocess.run as a concrete list")
    argv_loads = [node for node in ast.walk(tree) if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Load) and node.id == argv_name]
    if argv_loads != [run_call.args[0]]:
        return reject("argv was aliased, mutated, or reused")

    string_assignments = [
        node for nodes in assignments.values() for node in nodes
        if isinstance(node.value, ast.Constant) and isinstance(node.value.value, str)
    ]
    if not argv_stmt.value.elts or not isinstance(argv_stmt.value.elts[-1], ast.Name):
        return reject("prompt was not the final argv element")
    prompt_name = argv_stmt.value.elts[-1].id
    if len(assignments.get(prompt_name, [])) != 1 or store_counts.get(prompt_name) != 1:
        return reject("prompt was dynamic or reassigned")
    prompt_stmt = assignments[prompt_name][0]
    if prompt_stmt not in string_assignments or prompt_stmt.lineno >= argv_stmt.lineno:
        return reject("prompt was not one dominating string constant")
    prompt_loads = [node for node in ast.walk(tree) if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Load) and node.id == prompt_name]
    if prompt_loads != [argv_stmt.value.elts[-1]]:
        return reject("prompt was used outside the final argv position")

    def resolver(node):
        direct = (
            isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "get"
            and isinstance(node.func.value, ast.Attribute) and node.func.value.attr == "environ"
            and isinstance(node.func.value.value, ast.Name) and node.func.value.value.id == "os"
            and not node.keywords
        )
        if direct and len(node.args) == 2 and all(isinstance(arg, ast.Constant) for arg in node.args):
            return [arg.value for arg in node.args] == ["CLAUDE_BIN", "claude"]
        return (
            isinstance(node, ast.BoolOp) and isinstance(node.op, ast.Or) and len(node.values) == 2
            and isinstance(node.values[1], ast.Constant) and node.values[1].value == "claude"
            and isinstance(node.values[0], ast.Call) and isinstance(node.values[0].func, ast.Attribute)
            and node.values[0].func.attr == "get" and isinstance(node.values[0].func.value, ast.Attribute)
            and node.values[0].func.value.attr == "environ" and isinstance(node.values[0].func.value.value, ast.Name)
            and node.values[0].func.value.value.id == "os" and len(node.values[0].args) == 1
            and isinstance(node.values[0].args[0], ast.Constant) and node.values[0].args[0].value == "CLAUDE_BIN"
            and not node.values[0].keywords
        )

    executable_node = argv_stmt.value.elts[0]
    exe_stmt = None
    if isinstance(executable_node, ast.Name):
        exe_name = executable_node.id
        if len(assignments.get(exe_name, [])) != 1 or store_counts.get(exe_name) != 1:
            return reject("executable binding was reassigned")
        exe_stmt = assignments[exe_name][0]
        if exe_stmt.lineno >= argv_stmt.lineno or not resolver(exe_stmt.value):
            return reject("executable binding was not CLAUDE_BIN/claude")
        exe_loads = [node for node in ast.walk(tree) if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Load) and node.id == exe_name]
        if exe_loads != [executable_node]:
            return reject("executable binding was aliased or reused")
    elif not resolver(executable_node):
        return reject("executable was not CLAUDE_BIN/claude")
    top_imports = {id(statement) for statement in tree.body if isinstance(statement, ast.Import)}
    if any(id(node) not in top_imports for node in ast.walk(tree) if isinstance(node, (ast.Import, ast.ImportFrom))):
        return reject("Python launcher contained a nested or unsupported import")
    recognized_assignments = {id(prompt_stmt), id(argv_stmt), id(result_stmt)}
    if exe_stmt is not None:
        recognized_assignments.add(id(exe_stmt))
    if any(id(node) not in recognized_assignments for node in ast.walk(tree) if isinstance(node, ast.Assign)):
        return reject("Python launcher contained an unrecognized assignment")
    if any(isinstance(node, (ast.Attribute, ast.Subscript)) and isinstance(node.ctx, ast.Store) for node in ast.walk(tree)):
        return reject("Python launcher assigned through an attribute or subscript")

    argv = ["claude"]
    for index, element in enumerate(argv_stmt.value.elts[1:], 1):
        if index == len(argv_stmt.value.elts) - 1 and isinstance(element, ast.Name) and element.id == prompt_name:
            argv.append(prompt_stmt.value.value)
        elif isinstance(element, ast.Constant) and isinstance(element.value, str):
            argv.append(element.value)
        else:
            return reject("argv contained dynamic, concatenated, or starred elements")
    if len(argv) != 10 or argv.count("--print") + argv.count("-p") != 1:
        return reject("argv had extras or an invalid print mode")
    def exact_pair(flag, expected):
        positions = [index for index, token in enumerate(argv) if token == flag]
        return len(positions) == 1 and positions[0] + 1 < len(argv) and argv[positions[0] + 1] == expected
    if not all((exact_pair("--model", "opus"), exact_pair("--max-budget-usd", budget), exact_pair("--permission-mode", "dontAsk"))):
        return reject("argv required flag/value pairs were not exact")
    if argv.count("--no-session-persistence") != 1 or "--tools" in argv:
        return reject("argv session/tools controls were invalid")
    consumed = {0, len(argv) - 1}
    for flag in ("--model", "--max-budget-usd", "--permission-mode"):
        position = argv.index(flag); consumed.update({position, position + 1})
    consumed.add(argv.index("--print") if "--print" in argv else argv.index("-p"))
    consumed.add(argv.index("--no-session-persistence"))
    if consumed != set(range(len(argv))):
        return reject("argv contained extra tokens")

    keywords = {keyword.arg: keyword.value for keyword in run_call.keywords if keyword.arg is not None}
    if len(keywords) != len(run_call.keywords):
        return reject("subprocess.run used expanded keywords")
    allowed = {"capture_output", "stdin", "stdout", "stderr", "text", "timeout", "shell", "check"}
    if not set(keywords) <= allowed:
        return reject("subprocess.run used unsafe keywords")
    literal_true = lambda node: isinstance(node, ast.Constant) and node.value is True
    literal_false = lambda node: isinstance(node, ast.Constant) and node.value is False
    capture = "capture_output" in keywords and literal_true(keywords["capture_output"])
    pipes = all(
        key in keywords and isinstance(keywords[key], ast.Attribute)
        and isinstance(keywords[key].value, ast.Name) and keywords[key].value.id == "subprocess"
        and keywords[key].attr == "PIPE"
        for key in ("stdout", "stderr")
    )
    if capture == pipes or (capture and ({"stdout", "stderr"} & set(keywords))):
        return reject("subprocess output capture was missing or mixed")
    if "stdin" in keywords and not (
        isinstance(keywords["stdin"], ast.Attribute) and isinstance(keywords["stdin"].value, ast.Name)
        and keywords["stdin"].value.id == "subprocess" and keywords["stdin"].attr == "DEVNULL"
    ):
        return reject("subprocess stdin was not DEVNULL")
    timeout = keywords.get("timeout")
    timeout_ok = timeout is None or (
        isinstance(timeout, ast.Constant)
        and isinstance(timeout.value, (int, float))
        and not isinstance(timeout.value, bool)
        and 0 < timeout.value <= 300
    )
    # run_codex_live_command already enforces the outer process-group deadline;
    # an inner timeout is optional evidence, not a provider-limit acceptance rule.
    if not literal_true(keywords.get("text")) or not timeout_ok:
        return reject("subprocess text/timeout controls were invalid")
    if "shell" in keywords and not literal_false(keywords["shell"]):
        return reject("subprocess shell was not false")
    if "check" in keywords and not literal_false(keywords["check"]):
        return reject("subprocess check was not false")

    def result_attr(node, attr):
        return isinstance(node, ast.Attribute) and node.attr == attr and isinstance(node.value, ast.Name) and node.value.id == result_name
    def exit_from_result(statement):
        call = statement.exc if isinstance(statement, ast.Raise) else statement.value if isinstance(statement, ast.Expr) else None
        return (
            isinstance(call, ast.Call) and len(call.args) == 1 and not call.keywords and result_attr(call.args[0], "returncode")
            and ((isinstance(call.func, ast.Name) and call.func.id == "SystemExit")
                 or (isinstance(call.func, ast.Attribute) and isinstance(call.func.value, ast.Name) and call.func.value.id == "sys" and call.func.attr == "exit"))
        )
    success_statements = tree.body
    try_nodes = [node for node in tree.body if isinstance(node, ast.Try)]
    handler_family = "none"
    if try_nodes:
        if len(try_nodes) != 1 or try_nodes[0].orelse or try_nodes[0].finalbody or try_nodes[0].body != [result_stmt]:
            return reject("subprocess try block was not bounded")
        handler_names = []
        for handler in try_nodes[0].handlers:
            target = handler.type
            if isinstance(target, ast.Name):
                handler_names.append(target.id)
            elif isinstance(target, ast.Attribute) and isinstance(target.value, ast.Name):
                handler_names.append(target.value.id + "." + target.attr)
            else:
                return reject("subprocess handler type was not bounded")
            handler_constants = [node.value for node in ast.walk(handler) if isinstance(node, ast.Constant) and isinstance(node.value, str)]
            if any(re.search(r"(?i)(?:CLAUDE_CALL_STATUS=completed|CLAUDE_EXIT_CODE=|CLAUDE_EXIT_STATUS=|429|cooling down|provider.failure|OH_NO_CLAUDE_FUSION_PANEL_OK)", value) for value in handler_constants):
                return reject("subprocess handler could fabricate provider terminal evidence")
        if set(handler_names) == {"FileNotFoundError", "subprocess.TimeoutExpired"} and len(handler_names) == 2:
            handler_family = "bounded-specific"
        elif handler_names == ["Exception"] and try_nodes[0].handlers[0].name:
            handler_family = "launch-failure"
        else:
            return reject("subprocess handlers were not a certified family")
        success_statements = [statement for statement in tree.body if getattr(statement, "lineno", 0) > result_stmt.lineno]
    else:
        success_statements = [statement for statement in tree.body if getattr(statement, "lineno", 0) > result_stmt.lineno]

    def exact_print(call, arguments):
        return (
            isinstance(call, ast.Call) and isinstance(call.func, ast.Name) and call.func.id == "print"
            and len(call.args) == len(arguments) and all(predicate(argument) for predicate, argument in zip(arguments, call.args))
            and len(call.keywords) == 1 and call.keywords[0].arg == "end"
            and isinstance(call.keywords[0].value, ast.Constant) and call.keywords[0].value.value == ""
        )
    direct_stdout = (
        len(success_statements) == 3 and isinstance(success_statements[0], ast.Expr)
        and exact_print(success_statements[0].value, (lambda node: result_attr(node, "stdout"),))
    )
    direct_stderr = (
        len(success_statements) == 3 and isinstance(success_statements[1], ast.If)
        and result_attr(success_statements[1].test, "stderr") and len(success_statements[1].body) == 1
        and isinstance(success_statements[1].body[0], ast.Expr)
        and exact_print(success_statements[1].body[0].value, (
            lambda node: isinstance(node, ast.Constant) and node.value == "\n[stderr]",
            lambda node: result_attr(node, "stderr"),
        ))
        and not success_statements[1].orelse
    )
    final_exits = [statement for statement in success_statements if exit_from_result(statement)]
    constants = [node.value for statement in success_statements for node in ast.walk(statement) if isinstance(node, ast.Constant) and isinstance(node.value, str)]
    forbidden_static = re.compile(r"(?i)(?:429|cooling down|provider.failure|OH_NO_CLAUDE_FUSION_PANEL_OK)")
    if any(forbidden_static.search(value) for value in constants):
        return reject("launcher emitted fabricated provider/success text")
    def plain_print(statement, predicate, keyword_predicate=None):
        if not (
            isinstance(statement, ast.Expr) and isinstance(statement.value, ast.Call)
            and isinstance(statement.value.func, ast.Name) and statement.value.func.id == "print"
            and len(statement.value.args) == 1 and predicate(statement.value.args[0])
        ):
            return False
        if keyword_predicate is None:
            return not statement.value.keywords
        return keyword_predicate(statement.value.keywords)
    def fixed_sys_exit(statement, status):
        return (
            isinstance(statement, ast.Expr) and isinstance(statement.value, ast.Call)
            and isinstance(statement.value.func, ast.Attribute) and isinstance(statement.value.func.value, ast.Name)
            and statement.value.func.value.id == "sys" and statement.value.func.attr == "exit"
            and len(statement.value.args) == 1 and not statement.value.keywords
            and isinstance(statement.value.args[0], ast.Constant) and statement.value.args[0].value == status
        )
    def label_plus_result_string(node, label, attr):
        return (
            isinstance(node, ast.BinOp) and isinstance(node.op, ast.Add)
            and isinstance(node.left, ast.Constant) and node.left.value == label
            and isinstance(node.right, ast.Call) and isinstance(node.right.func, ast.Name)
            and node.right.func.id == "str" and len(node.right.args) == 1 and not node.right.keywords
            and result_attr(node.right.args[0], attr)
        )
    def stderr_class_argument(node):
        return (
            isinstance(node, ast.BinOp) and isinstance(node.op, ast.Add)
            and isinstance(node.left, ast.Constant) and node.left.value == "CLAUDE_STDERR_CLASS="
            and isinstance(node.right, ast.IfExp)
            and isinstance(node.right.test, ast.UnaryOp) and isinstance(node.right.test.op, ast.Not)
            and result_attr(node.right.test.operand, "stderr")
            and isinstance(node.right.body, ast.Constant) and node.right.body.value == "empty"
            and isinstance(node.right.orelse, ast.Constant) and node.right.orelse.value == "nonempty"
        )
    def stdout_end_keywords(keywords):
        if len(keywords) != 1 or keywords[0].arg != "end" or not isinstance(keywords[0].value, ast.IfExp):
            return False
        choice = keywords[0].value
        if not (
            isinstance(choice.body, ast.Constant) and choice.body.value == ""
            and isinstance(choice.orelse, ast.Constant) and choice.orelse.value in {"\n", "\\n"}
            and isinstance(choice.test, ast.BoolOp) and isinstance(choice.test.op, ast.Or)
            and len(choice.test.values) == 2
        ):
            return False
        def endswith_newline(node):
            return (
                isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "endswith"
                and result_attr(node.func.value, "stdout") and len(node.args) == 1 and not node.keywords
                and isinstance(node.args[0], ast.Constant) and node.args[0].value in {"\n", "\\n"}
            )
        def empty_stdout(node):
            return isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Not) and result_attr(node.operand, "stdout")
        values = choice.test.values
        return (endswith_newline(values[0]) and empty_stdout(values[1])) or (empty_stdout(values[0]) and endswith_newline(values[1]))

    transport_structure = (
        len(success_statements) == 6
        and plain_print(success_statements[0], lambda node: label_plus_result_string(node, "CLAUDE_EXIT_STATUS=", "returncode"))
        and plain_print(success_statements[1], stderr_class_argument)
        and plain_print(success_statements[2], lambda node: isinstance(node, ast.Constant) and node.value == "CLAUDE_STDOUT_BEGIN")
        and plain_print(success_statements[3], lambda node: result_attr(node, "stdout"), stdout_end_keywords)
        and plain_print(success_statements[4], lambda node: isinstance(node, ast.Constant) and node.value == "CLAUDE_STDOUT_END")
        and fixed_sys_exit(success_statements[5], 0)
    )
    if direct_stdout and direct_stderr and len(final_exits) == 1:
        terminal_mode = "direct"
    elif transport_structure:
        allowed_transport_constants = {
            "CLAUDE_EXIT_STATUS=", "CLAUDE_STDERR_CLASS=", "empty", "nonempty",
            "CLAUDE_STDOUT_BEGIN", "CLAUDE_STDOUT_END", "", "\n", "\\n",
        }
        if any(value not in allowed_transport_constants for value in constants):
            return reject("result transport envelope emitted an unsupported static label")
        terminal_mode = "transport"
    else:
        completed = [value for value in constants if value == "CLAUDE_CALL_STATUS=completed"]
        stdout_begin = [value for value in constants if value == "CLAUDE_STDOUT_BEGIN"]
        stdout_end = [value for value in constants if value == "CLAUDE_STDOUT_END"]
        exit_prints = []
        stdout_relays = []
        for node in ast.walk(ast.Module(body=success_statements, type_ignores=[])):
            if not isinstance(node, ast.Call) or not isinstance(node.func, ast.Name) or node.func.id != "print" or not node.args:
                continue
            argument = node.args[0]
            if label_plus_result_string(argument, "CLAUDE_EXIT_CODE=", "returncode"):
                exit_prints.append(node)
            if result_attr(argument, "stdout"):
                stdout_relays.append(node)
        allowed_labels = {
            "CLAUDE_CALL_STATUS=completed", "CLAUDE_EXIT_CODE=", "CLAUDE_STDOUT_BEGIN",
            "CLAUDE_STDOUT_END", "CLAUDE_STDERR_BEGIN", "CLAUDE_STDERR_END",
        }
        if any(value not in allowed_labels for value in constants):
            return reject("textual completed envelope emitted an unsupported static label")
        stderr_blocks = [statement for statement in success_statements if isinstance(statement, ast.If)]
        stderr_ok = not stderr_blocks or (
            len(stderr_blocks) == 1 and result_attr(stderr_blocks[0].test, "stderr") and not stderr_blocks[0].orelse
            and len(stderr_blocks[0].body) == 3
            and plain_print(stderr_blocks[0].body[0], lambda node: isinstance(node, ast.Constant) and node.value == "CLAUDE_STDERR_BEGIN")
            and plain_print(stderr_blocks[0].body[1], lambda node: result_attr(node, "stderr"))
            and plain_print(stderr_blocks[0].body[2], lambda node: isinstance(node, ast.Constant) and node.value == "CLAUDE_STDERR_END")
        )
        core = success_statements[:-1]
        if stderr_blocks:
            core = [statement for statement in core if statement is not stderr_blocks[0]]
        structure_ok = (
            len(core) == 5
            and plain_print(core[0], lambda node: isinstance(node, ast.Constant) and node.value == "CLAUDE_CALL_STATUS=completed")
            and plain_print(core[1], lambda node: node in [item.args[0] for item in exit_prints])
            and plain_print(core[2], lambda node: isinstance(node, ast.Constant) and node.value == "CLAUDE_STDOUT_BEGIN")
            and plain_print(core[3], lambda node: result_attr(node, "stdout"))
            and plain_print(core[4], lambda node: isinstance(node, ast.Constant) and node.value == "CLAUDE_STDOUT_END")
            and success_statements and exit_from_result(success_statements[-1])
        )
        if len(completed) != 1 or len(stdout_begin) != 1 or len(stdout_end) != 1 or len(exit_prints) != 1 or len(stdout_relays) != 1 or len(final_exits) != 1 or not stderr_ok or not structure_ok:
            return reject("textual completed envelope was incomplete or not result-derived")
        terminal_mode = "envelope"

    def env_get_call(node, arity):
        return (
            isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "get"
            and isinstance(node.func.value, ast.Attribute) and node.func.value.attr == "environ"
            and isinstance(node.func.value.value, ast.Name) and node.func.value.value.id == "os"
            and len(node.args) == arity and not node.keywords
            and isinstance(node.args[0], ast.Constant) and node.args[0].value == "CLAUDE_BIN"
            and (arity == 1 or isinstance(node.args[1], ast.Constant) and node.args[1].value == "claude")
        )
    def plain_print_call(statement, predicate):
        return (
            isinstance(statement, ast.Expr) and isinstance(statement.value, ast.Call)
            and isinstance(statement.value.func, ast.Name) and statement.value.func.id == "print"
            and len(statement.value.args) == 1 and not statement.value.keywords
            and predicate(statement.value.args[0])
        )
    def fixed_handler_exit(statement, status):
        return (
            isinstance(statement, ast.Expr) and isinstance(statement.value, ast.Call)
            and isinstance(statement.value.func, ast.Attribute) and isinstance(statement.value.func.value, ast.Name)
            and statement.value.func.value.id == "sys" and statement.value.func.attr == "exit"
            and len(statement.value.args) == 1 and not statement.value.keywords
            and isinstance(statement.value.args[0], ast.Constant) and statement.value.args[0].value == status
        )
    def command_source_argument(node):
        return (
            isinstance(node, ast.BinOp) and isinstance(node.op, ast.Add)
            and isinstance(node.left, ast.Constant) and node.left.value == "CLAUDE_COMMAND_SOURCE="
            and isinstance(node.right, ast.IfExp) and env_get_call(node.right.test, 1)
            and isinstance(node.right.body, ast.Constant) and node.right.body.value == "CLAUDE_BIN"
            and isinstance(node.right.orelse, ast.Constant) and node.right.orelse.value == "literal_claude"
        )
    def exception_stdout(node, name):
        return isinstance(node, ast.Attribute) and node.attr == "stdout" and isinstance(node.value, ast.Name) and node.value.id == name
    def timeout_output_argument(node, name):
        return (
            isinstance(node, ast.IfExp)
            and isinstance(node.test, ast.Call) and isinstance(node.test.func, ast.Name) and node.test.func.id == "isinstance"
            and len(node.test.args) == 2 and not node.test.keywords and exception_stdout(node.test.args[0], name)
            and isinstance(node.test.args[1], ast.Name) and node.test.args[1].id == "str"
            and exception_stdout(node.body, name)
            and isinstance(node.orelse, ast.Call) and isinstance(node.orelse.func, ast.Attribute) and node.orelse.func.attr == "decode"
            and exception_stdout(node.orelse.func.value, name) and not node.orelse.args
            and len(node.orelse.keywords) == 1 and node.orelse.keywords[0].arg == "errors"
            and isinstance(node.orelse.keywords[0].value, ast.Constant) and node.orelse.keywords[0].value.value == "replace"
        )

    certified_handler_statements = []
    if try_nodes:
        for handler in try_nodes[0].handlers:
            target_name = handler.type.id if isinstance(handler.type, ast.Name) else handler.type.value.id + "." + handler.type.attr
            body = handler.body
            if handler_family == "launch-failure":
                exception_name = handler.name
                def failure_type_argument(node):
                    return (
                        isinstance(node, ast.BinOp) and isinstance(node.op, ast.Add)
                        and isinstance(node.left, ast.Constant) and node.left.value == "CLAUDE_LAUNCH_FAILURE_TYPE="
                        and isinstance(node.right, ast.Attribute) and node.right.attr == "__name__"
                        and isinstance(node.right.value, ast.Call) and isinstance(node.right.value.func, ast.Name)
                        and node.right.value.func.id == "type" and len(node.right.value.args) == 1
                        and not node.right.value.keywords and isinstance(node.right.value.args[0], ast.Name)
                        and node.right.value.args[0].id == exception_name
                    )
                valid = (
                    target_name == "Exception" and isinstance(exception_name, str)
                    and len(body) == 2 and plain_print_call(body[0], failure_type_argument)
                    and fixed_handler_exit(body[1], 125)
                )
            elif target_name == "FileNotFoundError":
                valid = (
                    len(body) in {2, 3}
                    and plain_print_call(body[0], lambda node: isinstance(node, ast.Constant) and node.value == "CLAUDE_CALL_STATUS=executable_not_found")
                    and fixed_handler_exit(body[-1], 127)
                    and (len(body) == 2 or plain_print_call(body[1], command_source_argument))
                )
            else:
                exception_name = handler.name
                timeout_if = body[1] if len(body) == 3 else None
                valid_timeout_if = timeout_if is None or (
                    isinstance(exception_name, str) and isinstance(timeout_if, ast.If)
                    and exception_stdout(timeout_if.test, exception_name) and not timeout_if.orelse
                    and len(timeout_if.body) == 3
                    and plain_print_call(timeout_if.body[0], lambda node: isinstance(node, ast.Constant) and node.value == "CLAUDE_STDOUT_BEGIN")
                    and plain_print_call(timeout_if.body[1], lambda node: timeout_output_argument(node, exception_name))
                    and plain_print_call(timeout_if.body[2], lambda node: isinstance(node, ast.Constant) and node.value == "CLAUDE_STDOUT_END")
                )
                valid = (
                    len(body) in {2, 3}
                    and plain_print_call(body[0], lambda node: isinstance(node, ast.Constant) and node.value == "CLAUDE_CALL_STATUS=timeout")
                    and fixed_handler_exit(body[-1], 124)
                    and valid_timeout_if
                )
            if not valid:
                return reject("subprocess handler contained an unsupported statement or call")
            certified_handler_statements.extend(body)

    run_container = try_nodes[0] if try_nodes else result_stmt
    certified_top = {
        *(id(statement) for statement in tree.body if isinstance(statement, ast.Import)),
        id(prompt_stmt), id(argv_stmt), id(run_container),
        *(id(statement) for statement in success_statements),
    }
    if exe_stmt is not None:
        certified_top.add(id(exe_stmt))
    if any(id(statement) not in certified_top for statement in tree.body):
        return reject("Python launcher contained an unsupported top-level statement")
    call_containers = [prompt_stmt, argv_stmt, run_container, *success_statements, *certified_handler_statements]
    if exe_stmt is not None:
        call_containers.append(exe_stmt)
    certified_calls = {id(node) for container in call_containers for node in ast.walk(container) if isinstance(node, ast.Call)}
    if any(id(node) not in certified_calls for node in ast.walk(tree) if isinstance(node, ast.Call)):
        return reject("Python launcher contained an unsupported global call")
    return {"ok": True, "reason": "ok", "argv": argv, "terminal_mode": terminal_mode}


def fusion_textual_terminal(value):
    """Normalize one strict launcher-certified textual terminal envelope."""
    text = collect_text(value)
    transport_exits = re.findall(r"(?m)^CLAUDE_EXIT_STATUS=(-?[0-9]+)$", text)
    stderr_classes = re.findall(r"(?m)^CLAUDE_STDERR_CLASS=(empty|nonempty)$", text)
    transport_begins = list(re.finditer(r"(?m)^CLAUDE_STDOUT_BEGIN\r?$", text))
    transport_end_offsets = [match.start() for match in re.finditer(r"CLAUDE_STDOUT_END\r?$", text, re.M)]
    if transport_exits or stderr_classes:
        if len(transport_exits) != 1 or len(stderr_classes) != 1 or len(transport_begins) != 1 or len(transport_end_offsets) != 1:
            return None
        begin = transport_begins[0].end()
        end = transport_end_offsets[0]
        if begin >= end:
            return None
        stdout = text[begin:end]
        if stdout.startswith("\r\n"):
            stdout = stdout[2:]
        elif stdout.startswith("\n"):
            stdout = stdout[1:]
        if stdout.endswith("\\n"):
            stdout = stdout[:-2]
        elif stdout.endswith("\r\n"):
            stdout = stdout[:-2]
        elif stdout.endswith("\n"):
            stdout = stdout[:-1]
        if "CLAUDE_" in stdout:
            return None
        exit_code = int(transport_exits[0])
        return {
            "exit_code": exit_code,
            "status": "failed" if exit_code else "completed",
            "output": stdout + "\n",
            "stderr_class": stderr_classes[0],
        }

    status = re.findall(r"(?m)^CLAUDE_CALL_STATUS=([^\r\n]+)$", text)
    exits = re.findall(r"(?m)^CLAUDE_EXIT_CODE=(-?[0-9]+)$", text)
    begins = list(re.finditer(r"(?m)^CLAUDE_STDOUT_BEGIN\r?$", text))
    ends = list(re.finditer(r"(?m)^CLAUDE_STDOUT_END\r?$", text))
    if status != ["completed"] or len(exits) != 1 or len(begins) != 1 or len(ends) != 1 or begins[0].end() >= ends[0].start():
        return None
    stdout = text[begins[0].end():ends[0].start()].lstrip("\r\n").rstrip("\r\n") + "\n"
    stderr_begins = list(re.finditer(r"(?m)^CLAUDE_STDERR_BEGIN\r?$", text))
    stderr_ends = list(re.finditer(r"(?m)^CLAUDE_STDERR_END\r?$", text))
    if len(stderr_begins) != len(stderr_ends) or len(stderr_begins) > 1:
        return None
    if stderr_begins:
        if stderr_begins[0].end() >= stderr_ends[0].start():
            return None
        stdout += text[stderr_begins[0].end():stderr_ends[0].start()].lstrip("\r\n").rstrip("\r\n") + "\n"
    return {"exit_code": int(exits[0]), "status": "failed" if int(exits[0]) else "completed", "output": stdout}


def event_is_command_bearing(data):
    """True when an event can carry shell commands, in any observed shape."""
    item = data.get("item") or {}
    payload = data.get("payload") or {}
    if str(item.get("type") or "").lower() == "command_execution":
        return True
    if payload.get("type") == "function_call" and payload.get("name") in {"exec_command", "functions.exec_command"}:
        return True
    if payload.get("type") == "custom_tool_call" and payload.get("name") in {"exec", "functions.exec"}:
        return True
    return False
SHARED_HELPERS_PY
}
write_fusion_rescue_safe_rejection_summary() {
  local out_file="$1" err_file="$2" sessions_dir="$3" summary_file="$4"
  local first_leg_rc="$5" scanner_result="$6" classifier_rc="$7"
  codex_run_oracle_script "$out_file" "$err_file" "$sessions_dir" "$summary_file" \
    "$first_leg_rc" "$scanner_result" "$classifier_rc" "$FUSION_RESCUE_MAX_BUDGET_USD" <<'PY'
import ast
import hashlib
import json
import re
import shlex
import sys
from pathlib import Path

#@SHARED_HELPERS@
out_path, err_path, sessions_path, summary_path = map(Path, sys.argv[1:5])
first_leg_rc, scanner_result, classifier_rc_text, budget = sys.argv[5:9]

def digest_blob(label, blob):
    return {
        "channel": label,
        "sha256": hashlib.sha256(blob).hexdigest(),
        "size_bytes": len(blob),
    }

def read_bytes(path):
    try:
        return path.read_bytes()
    except OSError:
        return b""

def collect_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(item) for item in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(item) for item in value)
    return ""

def decoded(value):
    if not isinstance(value, str):
        return value
    try:
        return json.loads(value)
    except json.JSONDecodeError:
        return value

def argv_for(value):
    value = decoded(value)
    if isinstance(value, dict):
        value = value.get("argv") or value.get("cmd") or value.get("command") or ""
    if isinstance(value, list):
        return [str(item) for item in value]
    try:
        return shlex.split(str(value or ""))
    except ValueError:
        return []

def bounded_wrapper_proof(raw):
    return fusion_launcher_proof(raw, budget)


def nested_terminal(value):
    candidates = []
    def visit(candidate):
        if isinstance(candidate, dict):
            if "exit_code" in candidate or "output" in candidate:
                if isinstance(candidate.get("exit_code"), int) and not isinstance(candidate.get("exit_code"), bool) and isinstance(candidate.get("output"), str):
                    candidates.append(candidate)
                return
            for nested in candidate.values():
                visit(nested)
        elif isinstance(candidate, list):
            for nested in candidate:
                visit(nested)
        elif isinstance(candidate, str):
            try:
                decoded_value = json.loads(candidate)
            except json.JSONDecodeError:
                return
            if decoded_value != candidate:
                visit(decoded_value)
    visit(value)
    if len(candidates) != 1:
        return None
    candidate = candidates[0]
    return candidate["exit_code"], str(candidate.get("status") or ""), candidate["output"]


def terminal(value, fallback_status=""):
    value = decoded(value)
    exit_code = None
    status = fallback_status
    if isinstance(value, dict):
        for key in ("exit_code", "return_code", "status_code"):
            candidate = value.get(key)
            if isinstance(candidate, int):
                exit_code = candidate
                break
            if isinstance(candidate, str) and re.fullmatch(r"-?[0-9]+", candidate.strip()):
                exit_code = int(candidate.strip())
                break
        status = str(value.get("status") or status)
        text = collect_text(value.get("aggregated_output") or value.get("output") or value.get("content") or value.get("result") or "")
    else:
        text = collect_text(value)
    return exit_code, status, text

out_blob = read_bytes(out_path)
err_blob = read_bytes(err_path)
session_blobs = []
if sessions_path.is_dir():
    for path in sorted(sessions_path.rglob("*.jsonl")):
        session_blobs.append(read_bytes(path))
sessions_blob = b"\0".join(session_blobs)
launches = []
outputs = {}
ordered_payloads = []
event_shapes = set()
row_number = 0
for blob in [out_blob, *session_blobs]:
    for line in blob.decode("utf-8", errors="replace").splitlines():
        row_number += 1
        try:
            data = json.loads(line)
        except json.JSONDecodeError:
            continue
        item = data.get("item") or {}
        payload = data.get("payload") or {}
        if payload:
            ordered_payloads.append((row_number, payload))
        if item.get("type") == "command_execution":
            command = item.get("command") or ""
            argv = argv_for(command)
            if argv and Path(argv[0]).name == "claude":
                identity = item.get("id") or item.get("call_id")
                launches.append((identity, "command_execution", argv, None))
                outputs[identity] = terminal({
                    "exit_code": item.get("exit_code", item.get("return_code")),
                    "status": item.get("status"),
                    "output": item.get("aggregated_output") or item.get("output") or "",
                })
                event_shapes.add("command_execution")
        payload_type = payload.get("type")
        if payload_type in {"function_call", "custom_tool_call"} and payload.get("name") in {"exec_command", "functions.exec_command", "exec"}:
            raw = payload.get("arguments") or payload.get("input") or payload.get("command") or ""
            terminal_mode = None
            if payload_type == "custom_tool_call":
                proof = bounded_wrapper_proof(raw)
                argv = proof["argv"] if proof["ok"] else []
                terminal_mode = proof["terminal_mode"] if proof["ok"] else None
            else:
                argv = argv_for(raw)
            if argv and Path(argv[0]).name == "claude":
                identity = payload.get("call_id") or payload.get("id")
                launches.append((identity, payload_type, argv, terminal_mode))
                event_shapes.add(payload_type)
        if payload_type in {"function_call_output", "custom_tool_call_output"}:
            identity = payload.get("call_id") or payload.get("id")
            outputs[identity] = terminal(payload.get("output") or payload.get("content") or payload.get("result") or payload, str(payload.get("status") or ""))

if len(launches) == 1 and launches[0][1] == "custom_tool_call":
    launch_identity = launches[0][0]
    launch_line = next((line for line, payload in ordered_payloads if (payload.get("call_id") or payload.get("id")) == launch_identity and payload.get("type") == "custom_tool_call"), None)
    launch_output = outputs.get(launch_identity, (None, "", ""))[2]
    cells = re.findall(r"(?i)Script running with cell ID\s+([A-Za-z0-9_-]+)", launch_output)
    if launch_line is not None and len(cells) == 1:
        cell = cells[0]
        session = None
        wait_requests = {}
        poll_requests = {}
        correlated = []
        for line, payload in ordered_payloads:
            if line <= launch_line:
                continue
            payload_type = payload.get("type")
            call_identity = payload.get("call_id") or payload.get("id")
            if payload_type == "function_call" and payload.get("name") == "wait":
                value = decoded(payload.get("arguments") or "")
                if isinstance(value, dict) and str(value.get("cell_id")) == cell:
                    wait_requests[call_identity] = line
                continue
            if payload_type == "custom_tool_call" and payload.get("name") == "exec":
                raw = payload.get("input") or ""
                match = re.fullmatch(
                    r'\s*const\s+r\s*=\s*await\s+tools[.]write_stdin\s*[(]\s*[{]\s*session_id\s*:\s*([1-9][0-9]*)\s*,\s*chars\s*:\s*["\']["\']\s*,\s*yield_time_ms\s*:\s*([1-9][0-9]*)\s*,\s*max_output_tokens\s*:\s*([1-9][0-9]*)\s*[}]\s*[)]\s*;\s*(?:text\s*[(]\s*JSON[.]stringify\s*[(]\s*r\s*[)]\s*[)]|text\s*[(]\s*r[.]output\s*[)]\s*;\s*if\s*[(]\s*r[.]session_id\s*[)]\s*text\s*[(]\s*`SESSION_ID=[$][{]r[.]session_id[}]`\s*[)])\s*;?\s*',
                    raw,
                    re.S,
                )
                if match and int(match.group(2)) <= 30000 and int(match.group(3)) <= FUSION_WRITE_STDIN_MAX_OUTPUT_TOKENS:
                    poll_requests[call_identity] = (line, int(match.group(1)))
                continue
            if payload_type not in {"function_call_output", "custom_tool_call_output"}:
                continue
            raw_output = payload.get("output") or payload.get("content") or payload.get("result") or ""
            if call_identity in wait_requests:
                output_text = collect_text(raw_output)
                structured_terminal = nested_terminal(raw_output)
                textual_terminal = fusion_textual_terminal(raw_output) if launches[0][3] in {"envelope", "transport"} else None
                if structured_terminal is not None and textual_terminal is not None:
                    correlated.append((None, "collision", ""))
                elif structured_terminal is not None:
                    correlated.append(structured_terminal)
                elif textual_terminal is not None:
                    correlated.append((textual_terminal["exit_code"], textual_terminal["status"], textual_terminal["output"]))
                structured_sessions = re.findall(r'["\']session_id["\']\s*:\s*["\']?([1-9][0-9]*)', output_text)
                textual_sessions = re.findall(r'(?m)^SESSION_ID=([1-9][0-9]*)$', output_text)
                observed_sessions = structured_sessions or textual_sessions if not (structured_sessions and textual_sessions) else []
                if len(observed_sessions) == 1:
                    observed_session = int(observed_sessions[0])
                    if session is None:
                        session = observed_session
                    elif session != observed_session:
                        correlated.append((None, "session-changed", ""))
                continue
            request = poll_requests.get(call_identity)
            if request is None or session is None or request[1] != session or line <= request[0]:
                continue
            structured = nested_terminal(raw_output)
            textual = fusion_textual_terminal(raw_output) if launches[0][3] in {"envelope", "transport"} else None
            if structured is not None and textual is not None:
                correlated.append((None, "collision", ""))
            elif structured is not None:
                correlated.append(structured)
            elif textual is not None:
                correlated.append((textual["exit_code"], textual["status"], textual["output"]))
            else:
                next_cells = re.findall(r"(?i)Script running with cell ID\s+([A-Za-z0-9_-]+)", collect_text(raw_output))
                if len(next_cells) == 1:
                    cell = next_cells[0]
        if len(correlated) == 1:
            outputs[launch_identity] = correlated[0]
            event_shapes.add("custom_tool_call+custom_write_stdin")

identity, shape, argv, terminal_mode = launches[0] if len(launches) == 1 else (None, None, [], None)
exit_code, terminal_status, output = outputs.get(identity, (None, "", ""))
required_pairs = (("--model", "opus"), ("--max-budget-usd", budget), ("--permission-mode", "dontAsk"))
def exact_pair(flag, value):
    positions = [index for index, token in enumerate(argv) if token == flag]
    return len(positions) == 1 and positions[0] + 1 < len(argv) and argv[positions[0] + 1] == value
competing_patterns = (
    r"(?i)command not found", r"(?i)permission denied",
    r"(?i)(?:invalid|unknown) (?:option|argument|model)",
    r"(?i)(?:config(?:uration)? (?:parse|syntax) error|failed to parse config|error parsing config)",
    r"(?i)\b(?:HTTP(?:/[0-9.]+)?\s*)?(?:401|403|5[0-9]{2})\b",
    r"(?i)timed? out|timeout", r"(?i)terminated by signal|signal [0-9]+",
    r"(?i)(?:budget|spend limit).*(?:exceeded|failure|failed|reached)",
)
summary = {
    "status": "rejected",
    "reason_code": "first-leg-classifier-rejected",
    "first_leg_rc": int(first_leg_rc),
    "scanner_result": scanner_result,
    "artifacts": [
        digest_blob("stdout", out_blob),
        digest_blob("stderr", err_blob),
        digest_blob("sessions", sessions_blob),
    ],
    "launch_count": len(launches),
    "event_shapes": sorted(event_shapes),
    "verified_argv": {
        "executable": bool(argv and Path(argv[0]).name == "claude"),
        "print_mode": argv.count("--print") + argv.count("-p") == 1,
        "model_opus": exact_pair("--model", "opus"),
        "budget": exact_pair("--max-budget-usd", budget),
        "permission_mode_dontAsk": exact_pair("--permission-mode", "dontAsk"),
        "session_persistence_disabled": argv.count("--no-session-persistence") == 1,
        "tools_override_absent": "--tools" not in argv,
    },
    "correlated_inner_exit_code": exit_code,
    "terminal_status_failed": exit_code not in (None, 0) or terminal_status.lower() in {"failed", "error", "cancelled"},
    "http429": re.search(r"(?i)(?:\bHTTP(?:/[0-9.]+)?\s*(?:status(?:\s+code)?\s*)?[:=]?\s*429\b|\bHTTP status(?: code)?\s*[:=]?\s*429\b|API Error:\s*Request rejected\s*\(429\))", output) is not None,
    "cooldown": re.search(r"(?i)\bcredentials(?:\s+for\s+model\s+\S+)?(?:\s+are)?\s+cooling down\b", output) is not None,
    "success_marker": "OH_NO_CLAUDE_FUSION_PANEL_OK" in output,
    "competing_error": any(re.search(pattern, output) for pattern in competing_patterns),
    "classifier_outcome": "rejected",
    "classifier_rc": int(classifier_rc_text),
    "fallback": {"status": "not-run"},
}
summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
}

run_fusion_rescue_live_test() {
  if [[ "$RUN_FUSION_RESCUE_LIVE" != "1" ]]; then
    log "Skipping live Codex Fusion Rescue cross-host smoke test"
    printf 'Run with --fusion-rescue-live or OH_NO_FUSION_RESCUE_LIVE=1 to verify Fusion Rescue panel subagents plus Claude Opus consult from a Codex subagent.\n' >&2
    return
  fi

  log "Running live Codex Fusion Rescue cross-host smoke test"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/fusion-rescue-codex-claude.jsonl"
  local err_file="$RUN_DIR/fusion-rescue-codex-claude.err"
  local summary_file="$RUN_DIR/fusion-rescue-codex-claude.summary.json"
  local live_workspace="$RUN_DIR/fusion-rescue-codex-workspace"
  local prompt
  mkdir -p "$live_workspace"
  prompt=$(cat <<PROMPT
Use the oh-no-harness:fusion-rescue skill. Read-only live integration smoke test only: do not edit files, do not create artifacts, do not install plugins, and do not run nested rescue. Use require-cross-host behavior, so a missing Claude consult is a test failure, not a default fallback.

Synthetic smoke-test problem all panels must analyze meaningfully: a CI pipeline has an intermittently failing integration test two days before release. The team must choose whether to quarantine the test, add automatic retries, or root-cause/fix the failure before release. Every panel result must discuss release risk, CI signal, quarantine, auto-retry, and root-cause evidence rather than only saying the smoke test is formatted correctly.

Before any Claude consult or cross-host panel assignment, inspect the current Codex permission/sandbox context. This test is launched with danger-full-access, so you must explicitly record: Codex permission preflight: danger-full-access confirmed. Only after that confirmation may Panel 1 invoke Claude. If the permission state is not danger-full-access, do not call Claude; because this prompt uses require-cross-host behavior, block with require-cross-host unavailable, state that Claude cannot be used because Codex permission is not danger-full-access, name the current-host three-panel fallback as the next local option, and do not return the success marker.

Build exactly three panel slots and then synthesize as the current Codex main judge.

Panel 1 primary must be a Codex current-host subagent using spawn_agent with task_name "fusion_primary_claude" and agent_type "oh-no-fusion-rescue-analyst". This is the cross-host consult panel, and it is allowed only because the Codex main agent has confirmed danger-full-access. Its message must include exactly these lines: Lens: primary; Marker: OH_NO_FUSION_PANEL_PRIMARY_CLAUDE; fusion depth: 1; Scope: this synthetic CI release-risk problem only; Do not edit files; Expected output: marker line plus assigned lens fields and the Claude response marker; Codex permission preflight: danger-full-access confirmed. This subagent must invoke \${CLAUDE_BIN:-claude} exactly once as an argument vector, not a shell-interpolated string, with these controls: --print, --model opus, --max-budget-usd ${FUSION_RESCUE_MAX_BUDGET_USD}, --permission-mode dontAsk, --no-session-persistence. Do not pass a --tools override: Claude Opus may use its own read-only tools to analyze, but the prompt and host permissions must forbid file edits, writes, installs, and mutating commands. Do not require Claude Task/Agent proof. Do not ask Claude Code to run a slash command, public workflow skill, Task, Agent, Workflow, subagent, /codex:rescue, codex:codex-rescue, or Claude-side fusion-rescue. The Claude prompt must be read-only and must state that Claude Opus must answer the assigned panel directly. It must return OH_NO_CLAUDE_FUSION_PANEL_OK plus lens name primary, strongest finding, evidence used, assumption under test, likely failure mode, recommended next action, confidence and why, what would change the conclusion, and fusion depth: 1. The Claude prompt must also state: this consult is read-only; do not edit files, write state, install plugins, run mutating commands, invoke rescue, fusion-rescue, cross-host consult, Codex, or another host from inside this panel. The primary Codex subagent must return OH_NO_FUSION_PANEL_PRIMARY_CLAUDE plus the Claude marker and a substantive summary of the Claude CI integration-test release analysis mentioning at least quarantine, auto-retry, root-cause, and release risk.

Panel 2 adversarial must be a Codex current-host subagent using spawn_agent with task_name "fusion_adversarial" and agent_type "oh-no-fusion-rescue-analyst". Its message must include exactly these lines: Lens: adversarial; Marker: OH_NO_FUSION_PANEL_ADVERSARIAL; fusion depth: 1; Do not invoke rescue, fusion-rescue, cross-host consult, or another host from inside this panel; Scope: this synthetic CI release-risk problem only; Do not edit files; Expected output: marker line plus assigned lens fields only. It must attack the assumptions behind quarantine, auto-retry, and shipping without root cause.

Panel 3 pragmatic must be a second Codex current-host subagent using spawn_agent with task_name "fusion_pragmatic" and agent_type "oh-no-fusion-rescue-analyst". Its message must include exactly these lines: Lens: pragmatic; Marker: OH_NO_FUSION_PANEL_PRAGMATIC; fusion depth: 1; Do not invoke rescue, fusion-rescue, cross-host consult, or another host from inside this panel; Scope: this synthetic CI release-risk problem only; Do not edit files; Expected output: marker line plus assigned lens fields only. It must recommend the simplest reversible next step and verification path for the CI release-risk decision.

Start all three Codex subagents before waiting when possible. Wait for each receiver until completed, capture all three results, then close all three completed receivers only when the host exposes close_agent; otherwise include exactly: Close/cleanup was not available. If wait_agent returns no agents completed yet, wait longer; MUST NOT close a running or pending receiver. After all three panel subagents finish, synthesize rather than concatenate. Final answer must contain exactly the marker OH_NO_CODEX_FUSION_RESCUE_LIVE_OK and must include: Codex permission preflight: danger-full-access confirmed; panels completed: primary, adversarial, pragmatic; Claude marker: OH_NO_CLAUDE_FUSION_PANEL_OK; Codex markers: OH_NO_FUSION_PANEL_PRIMARY_CLAUDE, OH_NO_FUSION_PANEL_ADVERSARIAL, OH_NO_FUSION_PANEL_PRAGMATIC; consensus; contradictions; unique insights; blind spots; recommended next action; confidence and why; panel availability/fallback notes: primary available via Codex cross-host subagent using claude -p --model opus with no Claude tools enabled after danger-full-access preflight, Codex adversarial available, Codex pragmatic available; opposite-host response path: Claude via Codex primary subagent; fusion depth: 1.
PROMPT
)

  local cmd=(
    "$CODEX_BIN"
    --enable plugin_hooks
    --ask-for-approval never
    exec
    --json
    --cd "$live_workspace"
    # Claude CLI auth/cache access fails under workspace-write in this lane.
    # Keep the task cwd disposable and let the parser reject writes/secrets.
    --sandbox danger-full-access
    --skip-git-repo-check
  )

  if [[ -n "$LIVE_MODEL" ]]; then
    cmd+=(--model "$LIVE_MODEL")
  fi

  local first_leg_rc=0
  run_codex_live_command "$CODEX_HOME_DIR" "${cmd[@]}" "$prompt" </dev/null >"$out_file" 2>"$err_file" \
    || first_leg_rc=$?
  if ! assert_no_codex_live_secret_leak \
    "$CODEX_HOME_DIR/auth.json" \
    "$out_file" \
    "$err_file" \
    "$CODEX_HOME_DIR/sessions"; then
    rm -f "$out_file" "$err_file" "$summary_file"
    fail "Codex Fusion Rescue live artifacts failed the credential-leak guard and were removed"
  fi

  local first_oracle_rc=0 first_oracle_err="$RUN_DIR/fusion-rescue-codex-claude.oracle.err"
  {
    codex_run_oracle_script "$out_file" "$err_file" "$CODEX_HOME_DIR" "$FUSION_RESCUE_MAX_BUDGET_USD" "$summary_file" "$first_leg_rc" 2>"$first_oracle_err" <<'PY'
import ast
import json
import re
import shlex
import sys
from pathlib import Path

#@SHARED_HELPERS@
out_path, err_path, live_home, budget, summary_path, first_leg_rc_text = sys.argv[1:7]
first_leg_rc = int(first_leg_rc_text)
expected_markers = {
    "primary": "OH_NO_FUSION_PANEL_PRIMARY_CLAUDE",
    "adversarial": "OH_NO_FUSION_PANEL_ADVERSARIAL",
    "pragmatic": "OH_NO_FUSION_PANEL_PRAGMATIC",
}
required_final_markers = [
    "OH_NO_CODEX_FUSION_RESCUE_LIVE_OK",
    "OH_NO_CLAUDE_FUSION_PANEL_OK",
    "OH_NO_FUSION_PANEL_PRIMARY_CLAUDE",
    "OH_NO_FUSION_PANEL_ADVERSARIAL",
    "OH_NO_FUSION_PANEL_PRAGMATIC",
    "Codex permission preflight",
    "danger-full-access confirmed",
    "panels completed: primary, adversarial, pragmatic",
    "panel availability/fallback notes",
    "opposite-host response path",
    "Codex cross-host subagent",
    "fusion depth: 1",
]
required_synthesis_fields = [
    "consensus",
    "contradictions",
    "unique insights",
    "blind spots",
    "recommended next action",
    "confidence and why",
]
required_panel_fields = [
    "lens name",
    "strongest finding",
    "evidence used",
    "assumption under test",
    "likely failure mode",
    "recommended next action",
    "confidence",
    "what would change",
]
domain_markers = [
    "ci",
    "integration",
    "quarantine",
    "retry",
    "root-cause",
    "release",
    "risk",
]
required_claude_argv = [
    "claude",
    "--model",
    "opus",
    "--max-budget-usd",
    budget,
    "--permission-mode",
    "dontAsk",
    "--no-session-persistence",
]
# opus model is verified authoritatively via required_claude_argv (--model opus,
# checked against tool_text above); do NOT also require the literal "claude opus"
# phrase in the model-generated prompt text — that bigram is a brittle phrase-grep
# the model can satisfy semantically (e.g. an `--model opus` invocation plus a
# panel prompt) without echoing those exact words. Keep only the direct-panel
# intent terms here.
required_claude_direct_prompt_terms = ("assigned", "panel", "direct")
forbidden_claude_prompt_patterns = [
    re.compile(r"(?i)(?<!do not )\b(?:ask\s+Claude\s+Code\s+to\s+)?(?:use|run|invoke|call|execute|delegate\s+to)\s+(?:the\s+)?(?:Claude\s+Code\s+)?/?(?:oh-no-harness:)?fusion-rescue\b"),
    re.compile(r"(?i)(?<!do not )\b(?:ask\s+Claude\s+Code\s+to\s+)?(?:use|run|invoke|call|execute|delegate\s+to)\s+(?:the\s+)?(?:/codex:rescue|codex:codex-rescue)\b"),
    re.compile(r"(?i)(?<!do not )\b(?:ask\s+Claude\s+Code\s+to\s+)?(?:use|run|invoke|call|execute|delegate\s+to)\s+(?:Claude\s+)?(?:Task|Agent|Workflow|subagents?)\b"),
]
allowed_claude_prompt_fixtures = [
    "Do not ask Claude Code to run a slash command, public workflow skill, Task, Agent, Workflow, subagent, /codex:rescue, codex:codex-rescue, or Claude-side fusion-rescue.",
    "Do not invoke rescue, fusion-rescue, cross-host consult, Codex, or another host from inside this panel.",
]
forbidden_claude_prompt_fixtures = [
    "Please run /oh-no-harness:fusion-rescue for this panel.",
    "Invoke oh-no-harness:fusion-rescue directly.",
    "Ask Claude Code to run /codex:rescue.",
    "Execute codex:codex-rescue.",
    "Delegate to Claude Workflow.",
    "Run subagent for this panel.",
    "Use subagents for this review.",
]
for fixture in allowed_claude_prompt_fixtures:
    hits = [pattern.pattern for pattern in forbidden_claude_prompt_patterns if pattern.search(fixture)]
    if hits:
        raise SystemExit(f"Fusion Rescue Codex live forbidden prompt guard rejects allowed fixture {fixture!r}: {hits!r}")
for fixture in forbidden_claude_prompt_fixtures:
    if not any(pattern.search(fixture) for pattern in forbidden_claude_prompt_patterns):
        raise SystemExit(f"Fusion Rescue Codex live forbidden prompt guard misses fixture {fixture!r}")
secret_patterns = [
    re.compile(r"(?<![A-Za-z0-9_-])sk-[A-Za-z0-9_-]{20,512}(?![A-Za-z0-9_-])"),
    re.compile(r"(?i)(api[_-]?key|access[_-]?token|refresh[_-]?token|private[_-]?key|cookie)\s*[:=]\s*['\"]?[A-Za-z0-9_./+=-]{12,}"),
]
forbidden_write_tools = {
    "apply_patch",
    "edit",
    "write",
    "write_file",
    "file_change",
    "patch",
}
forbidden_command_patterns = [
    re.compile(r"(^|[;&|'\"]\s*)(apply_patch|touch|mkdir|rm|cp|mv|tee)\b"),
    re.compile(r"(^|[;&|'\"]\s*)sed\s+-i\b"),
    re.compile(r"(^|[;&|'\"]\s*)cat\s+>"),
    re.compile(r"(^|[;&|'\"]\s*)printf\b[^|;&]*>"),
]
claude_command_patterns = [
    re.compile(r"(^|[;&|'\"]\s*)(\$\{CLAUDE_BIN:-claude\}|claude)\b"),
    re.compile(r"\bexecFile\([^)]*claude", re.IGNORECASE),
    re.compile(r"\bspawnSync\([^)]*claude", re.IGNORECASE),
    re.compile(r"\bsubprocess\.[A-Za-z_]+\([^)]*claude", re.IGNORECASE),
]
forbidden_fallbacks = [
    "Claude unavailable",
    "Claude primary unavailable",
    "Codex adversarial unavailable",
    "cross-host consult is unavailable",
    "require-cross-host unavailable",
]

def collect_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(item) for item in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(item) for item in value)
    return ""

def role_of_event(data):
    item = data.get("item") or {}
    message = data.get("message") or {}
    return item.get("role") or data.get("role") or message.get("role") or ""

def receiver_transcript_and_agent_role(receiver):
    sessions_root = Path(live_home) / "sessions"
    session_candidates = list(sessions_root.rglob(f"*{receiver}*.jsonl"))
    if not session_candidates:
        raise SystemExit(f"Fusion Rescue Codex live could not find session transcript for receiver: {receiver}")
    transcript_parts = []
    agent_role = None
    for path in session_candidates:
        text = path.read_text(encoding="utf-8", errors="replace")
        transcript_parts.append(text)
        for line in text.splitlines():
            if not line.strip():
                continue
            data = json.loads(line)
            if data.get("type") != "session_meta":
                continue
            payload = data.get("payload") or {}
            source = payload.get("source") if isinstance(payload.get("source"), dict) else {}
            subagent = source.get("subagent") if isinstance(source.get("subagent"), dict) else {}
            thread_spawn = (
                subagent.get("thread_spawn")
                if isinstance(subagent.get("thread_spawn"), dict)
                else {}
            )
            agent_role = payload.get("agent_role") or thread_spawn.get("agent_role")
            break
        if agent_role is not None:
            break
    if agent_role is not None:
        return "\n".join(transcript_parts), agent_role
    raise SystemExit(f"Fusion Rescue Codex live transcript lacked session_meta: {receiver}")


def parent_linked_panel_transcripts(parent_thread_id):
    children = {}
    linked_children = 0
    for path in (Path(live_home) / "sessions").rglob("*.jsonl"):
        text = path.read_text(encoding="utf-8", errors="replace")
        rows = [json.loads(line) for line in text.splitlines() if line.strip()]
        meta = next(
            (row.get("payload") or {} for row in rows if row.get("type") == "session_meta"),
            None,
        )
        if not isinstance(meta, dict):
            continue
        source = meta.get("source") if isinstance(meta.get("source"), dict) else {}
        subagent = source.get("subagent") if isinstance(source.get("subagent"), dict) else {}
        thread_spawn = (
            subagent.get("thread_spawn")
            if isinstance(subagent.get("thread_spawn"), dict)
            else {}
        )
        parent = meta.get("parent_thread_id") or thread_spawn.get("parent_thread_id")
        agent_role = meta.get("agent_role") or thread_spawn.get("agent_role")
        if parent != parent_thread_id or agent_role != "oh-no-fusion-rescue-analyst":
            continue
        linked_children += 1
        user_messages = []
        assistant_messages = []
        task_complete_messages = []
        encrypted_task_messages = 0
        completed = False
        for row in rows:
            payload = row.get("payload") or {}
            if row.get("type") == "event_msg" and payload.get("type") == "task_complete":
                completed = True
                final_message = collect_text(payload.get("last_agent_message"))
                if final_message:
                    task_complete_messages.append(final_message)
            if row.get("type") != "response_item":
                continue
            if payload.get("type") == "agent_message":
                content = payload.get("content") or []
                if any(
                    isinstance(item, dict) and item.get("type") == "encrypted_content"
                    for item in content
                ):
                    encrypted_task_messages += 1
                else:
                    user_messages.append(collect_text(content))
                continue
            if payload.get("type") != "message":
                continue
            if payload.get("role") == "user":
                user_messages.append(collect_text(payload.get("content")))
            elif payload.get("role") == "assistant":
                assistant_messages.append(collect_text(payload.get("content")))
        task_input = "\n".join(user_messages)
        task_output = (
            task_complete_messages[-1]
            if task_complete_messages
            else "\n".join(dict.fromkeys(assistant_messages))
        )
        matched_output = [
            lens for lens, marker in expected_markers.items()
            if marker in task_output
        ]
        if len(matched_output) != 1:
            raise SystemExit(
                "Fusion Rescue Codex live parent-linked child output did not identify "
                f"exactly one panel lens: {matched_output!r}"
            )
        lens = matched_output[0]
        matched_input = [
            candidate for candidate, marker in expected_markers.items()
            if marker in task_input
        ]
        if encrypted_task_messages < 1 and matched_input != [lens]:
            raise SystemExit(
                f"Fusion Rescue Codex live plaintext task did not match {lens} and "
                f"lacked encrypted task-channel evidence: {matched_input!r}"
            )
        if lens in children:
            raise SystemExit(f"Fusion Rescue Codex live found duplicate parent-linked transcripts for {lens}")
        if not completed:
            raise SystemExit(f"Fusion Rescue Codex live parent-linked {lens} child lacked task_complete")
        receiver = meta.get("id") or meta.get("session_id") or path.stem
        children[lens] = {
            "receiver": receiver,
            "text": text,
            "role": agent_role,
            "input": task_input if matched_input == [lens] else "",
            "encrypted_task_messages": encrypted_task_messages,
            "output": task_output,
        }
    if linked_children != len(expected_markers):
        raise SystemExit(
            "Fusion Rescue Codex live expected exactly three parent-linked panel "
            f"sessions, found {linked_children}"
        )
    return children


def assert_meaningful_domain_analysis(label, text):
    lower_text = text.lower()
    hits = [marker for marker in domain_markers if marker in lower_text]
    if len(hits) < 4:
        raise SystemExit(
            f"Fusion Rescue Codex live {label} did not include meaningful CI release-risk analysis; "
            f"domain_hits={hits!r} text={text[:2000]!r}"
        )
    weak_markers = (
        "no substantive problem packet",
        "only format",
        "format/scope smoke",
        "no actionable problem packet",
    )
    for marker in weak_markers:
        if marker in lower_text:
            raise SystemExit(
                f"Fusion Rescue Codex live {label} returned weak/non-substantive analysis marker "
                f"{marker!r}; text={text[:2000]!r}"
            )
    # "only smoke" flags a panel that treats the task as merely a smoke check.
    # Exclude legitimate analysis phrasing like "read-only smoke scope", where
    # the substring "only smoke" appears inside "read-only" without being weak.
    if re.search(r"(?<!read-)only smoke", lower_text):
        raise SystemExit(
            f"Fusion Rescue Codex live {label} returned weak/non-substantive analysis marker "
            f"'only smoke'; text={text[:2000]!r}"
        )

def inspect_primary_claude_call(transcript):
    launch_records = []
    custom_candidates = {}
    outputs_by_call = {}
    ordered_payloads = []
    event_shapes = []

    def decoded_payload_value(payload):
        raw = (
            payload.get("arguments")
            or payload.get("input")
            or payload.get("command")
            or payload.get("content")
            or ""
        )
        if isinstance(raw, str):
            try:
                return json.loads(raw) if raw else ""
            except json.JSONDecodeError:
                return raw
        return raw

    def command_from_payload(payload):
        decoded = decoded_payload_value(payload)
        if isinstance(decoded, dict):
            for key in ("argv", "cmd", "command"):
                value = decoded.get(key)
                if isinstance(value, list):
                    return [str(item) for item in value]
                if value:
                    return str(value)
        if isinstance(decoded, list):
            return [str(item) for item in decoded]
        return str(decoded or "")

    def terminal_result(value, fallback_status=""):
        decoded = value
        if isinstance(value, str):
            try:
                decoded = json.loads(value)
            except json.JSONDecodeError:
                decoded = value
        exit_code = None
        status = fallback_status
        if isinstance(decoded, dict):
            for key in ("exit_code", "return_code", "status_code"):
                candidate = decoded.get(key)
                if isinstance(candidate, int):
                    exit_code = candidate
                    break
                if isinstance(candidate, str) and re.fullmatch(r"-?[0-9]+", candidate.strip()):
                    exit_code = int(candidate.strip())
                    break
            status = str(decoded.get("status") or status)
            output = collect_text(
                decoded.get("aggregated_output")
                or decoded.get("output")
                or decoded.get("content")
                or decoded.get("result")
                or ""
            )
        else:
            output = collect_text(decoded)
        return {"exit_code": exit_code, "status": status, "output": output}

    def nested_terminal_result(value):
        candidates = []

        def visit(candidate):
            if isinstance(candidate, dict):
                if "exit_code" in candidate or "output" in candidate:
                    if isinstance(candidate.get("exit_code"), int) and not isinstance(candidate.get("exit_code"), bool) and isinstance(candidate.get("output"), str):
                        candidates.append(candidate)
                    return
                for nested in candidate.values():
                    visit(nested)
                return
            if isinstance(candidate, list):
                for nested in candidate:
                    visit(nested)
                return
            if not isinstance(candidate, str):
                return
            try:
                decoded = json.loads(candidate)
            except json.JSONDecodeError:
                return
            if decoded != candidate:
                visit(decoded)

        visit(value)
        if len(candidates) > 1:
            raise SystemExit("Fusion Rescue Codex live primary async output exposed multiple structured terminal objects")
        if not candidates:
            return None
        candidate = candidates[0]
        return {
            "exit_code": candidate["exit_code"],
            "status": str(candidate.get("status") or ""),
            "output": candidate["output"],
        }

    def argv_for(command):
        if isinstance(command, list):
            return command
        try:
            return shlex.split(command)
        except ValueError as exc:
            raise SystemExit(f"Fusion Rescue Codex live primary Claude command was not valid argv text: {exc}")

    def custom_exec_argv(data, raw_text):
        proof = fusion_launcher_proof(raw_text, budget)
        if not proof["ok"]:
            raise SystemExit(
                "Fusion Rescue Codex live primary Claude custom exec was not a bounded semantic launcher: "
                + proof["reason"]
            )
        return proof

    def async_cell(value):
        text = collect_text(value)
        matches = re.findall(r"(?i)Script running with cell ID\s+([A-Za-z0-9_-]+)", text)
        if len(matches) > 1:
            raise SystemExit("Fusion Rescue Codex live primary async output exposed multiple cell handles")
        return matches[0] if matches else None

    def async_write_stdin_request(raw):
        if not isinstance(raw, str) or "write_stdin" not in raw:
            return None
        operations = re.findall(r"tools[.]([A-Za-z_][A-Za-z0-9_]*)\s*[(]", raw)
        if operations != ["write_stdin"]:
            raise SystemExit("Fusion Rescue Codex live primary async poll mixed or duplicated execution primitives")
        calls = re.findall(r"(?:const\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*)?await\s+tools[.]write_stdin\s*[(]\s*[{]([^{}]*)[}]\s*[)]", raw, re.S)
        if len(calls) != 1 or not calls[0][0]:
            raise SystemExit("Fusion Rescue Codex live primary async poll lacked exactly one assigned write_stdin operation")
        result_name, call_fields = calls[0]
        executable = "".join(raw[start:end] for start, end in js_executable_spans(raw))
        json_sinks = re.findall(r"text\s*[(]\s*JSON[.]stringify\s*[(]\s*([A-Za-z_$][A-Za-z0-9_$]*)\s*[)]\s*[)]", executable)
        output_sinks = re.findall(r"text\s*[(]\s*([A-Za-z_$][A-Za-z0-9_$]*)[.]output\s*[)]", executable)
        session_sinks = re.findall(r"if\s*[(]\s*([A-Za-z_$][A-Za-z0-9_$]*)[.]session_id\s*[)]\s*text\s*[(]\s*`SESSION_ID=[$][{]([A-Za-z_$][A-Za-z0-9_$]*)[.]session_id[}]`\s*[)]", raw)
        text_calls = re.findall(r"(?<![A-Za-z0-9_$.])text\s*[(]", executable)
        json_sink_ok = json_sinks == [result_name] and not output_sinks and not session_sinks and len(text_calls) == 1
        output_sink_ok = output_sinks == [result_name] and session_sinks in ([], [(result_name, result_name)]) and len(text_calls) == 1 + len(session_sinks)
        if not (json_sink_ok or output_sink_ok):
            raise SystemExit("Fusion Rescue Codex live primary async poll sink did not retain its assigned result")
        fields = {}
        for token in call_fields.split(","):
            match = re.fullmatch(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*?)\s*", token, re.S)
            if match is None or match.group(1) in fields:
                raise SystemExit("Fusion Rescue Codex live primary async poll arguments were ambiguous")
            fields[match.group(1)] = match.group(2)
        field_names = set(fields)
        bounded = field_names == {"session_id", "chars", "yield_time_ms", "max_output_tokens"}
        if field_names not in ({"session_id", "chars"}, {"session_id", "chars", "yield_time_ms", "max_output_tokens"}):
            raise SystemExit("Fusion Rescue Codex live primary async poll arguments were incomplete or ambiguous")
        if re.fullmatch(r"[1-9][0-9]*", fields["session_id"]) is None:
            raise SystemExit("Fusion Rescue Codex live primary async poll lacked one concrete numeric session identity")
        if fields["chars"] not in {'""', "''"}:
            raise SystemExit("Fusion Rescue Codex live primary async poll attempted nonempty input")
        if bounded:
            if re.fullmatch(r"[1-9][0-9]*", fields["yield_time_ms"]) is None:
                raise SystemExit("Fusion Rescue Codex live primary async poll lacked a bounded yield")
            if re.fullmatch(r"[1-9][0-9]*", fields["max_output_tokens"]) is None:
                raise SystemExit("Fusion Rescue Codex live primary async poll lacked a bounded output limit")
            yield_time_ms = int(fields["yield_time_ms"])
            max_output_tokens = int(fields["max_output_tokens"])
            if yield_time_ms > 30000 or max_output_tokens > FUSION_WRITE_STDIN_MAX_OUTPUT_TOKENS:
                raise SystemExit("Fusion Rescue Codex live primary async poll exceeded its wait/output bounds")
        return int(fields["session_id"]), bounded

    def validate_argv(command):
        argv = argv_for(command)
        if not argv:
            raise SystemExit("Fusion Rescue Codex live primary Claude launch had empty argv")
        executable = argv[0]
        if executable != "${CLAUDE_BIN:-claude}" and Path(executable).name != "claude":
            raise SystemExit(
                f"Fusion Rescue Codex live primary launch used unexpected executable {executable!r}"
            )
        if any(token in {"|", "||", "&&", ";", ">", ">>", "<"} for token in argv):
            raise SystemExit("Fusion Rescue Codex live primary Claude launch used a shell pipeline or wrapper")
        if Path(executable).name in {"bash", "sh", "zsh", "env"}:
            raise SystemExit("Fusion Rescue Codex live primary Claude launch used an unrelated wrapper")
        if argv.count("--print") + argv.count("-p") != 1:
            raise SystemExit("Fusion Rescue Codex live primary Claude launch must use exactly one print-mode flag")
        required_pairs = (("--model", "opus"), ("--max-budget-usd", budget), ("--permission-mode", "dontAsk"))
        for flag, expected in required_pairs:
            positions = [index for index, token in enumerate(argv) if token == flag]
            if len(positions) != 1 or positions[0] + 1 >= len(argv) or argv[positions[0] + 1] != expected:
                raise SystemExit(
                    f"Fusion Rescue Codex live primary Claude argv must contain exactly {flag} {expected}"
                )
        if argv.count("--no-session-persistence") != 1:
            raise SystemExit("Fusion Rescue Codex live primary Claude argv must disable session persistence")
        forbidden_session_flags = {"--continue", "--resume", "--session-id", "--fork-session"}
        if forbidden_session_flags & set(argv):
            raise SystemExit("Fusion Rescue Codex live primary Claude argv enabled session persistence")
        if "--tools" in argv:
            raise SystemExit("Fusion Rescue Codex live primary Claude argv unexpectedly overrode tools")
        prompt_text = " ".join(argv[1:])
        missing_direct_terms = [
            term for term in required_claude_direct_prompt_terms
            if term not in prompt_text.lower()
        ]
        if missing_direct_terms:
            raise SystemExit(
                "Fusion Rescue Codex live primary Claude prompt missed a direct Opus panel-review instruction; "
                f"missing_terms={missing_direct_terms!r}"
            )
        forbidden_prompt_hits = [
            pattern.pattern for pattern in forbidden_claude_prompt_patterns
            if pattern.search(prompt_text)
        ]
        if forbidden_prompt_hits:
            raise SystemExit(
                "Fusion Rescue Codex live primary Claude prompt appears to delegate to Claude-side workflow tooling: "
                f"{forbidden_prompt_hits!r}"
            )
        return argv

    for line_number, line in enumerate(transcript.splitlines(), 1):
        if not line.strip():
            continue
        data = json.loads(line)
        event_text = collect_text(data)
        if any(pattern.search(event_text) for pattern in secret_patterns):
            raise SystemExit(
                f"Fusion Rescue Codex live primary transcript exposed a secret-like value near line {line_number}"
            )
        item = data.get("item") or {}
        payload = data.get("payload") or {}
        ordered_payloads.append((line_number, payload, data))
        event_shapes.append(
            {
                "line": line_number,
                "data_type": data.get("type"),
                "item_type": item.get("type"),
                "payload_type": payload.get("type"),
                "payload_name": payload.get("name"),
            }
        )
        item_type_lower = str(item.get("type") or data.get("type") or "").lower()
        tool_lower = str(item.get("tool") or item.get("name") or payload.get("name") or "").lower()
        if item_type_lower in forbidden_write_tools or tool_lower in forbidden_write_tools:
            raise SystemExit(
                f"Fusion Rescue Codex live primary subagent saw write-capable event at line {line_number}: "
                f"type={item_type_lower!r} tool={tool_lower!r}"
            )
        inspectable = safety_inspectable_commands(data)
        if event_is_command_bearing(data) and any(
            pattern.search(candidate)
            for candidate in inspectable
            for pattern in forbidden_command_patterns
        ):
            raise SystemExit(
                f"Fusion Rescue Codex live primary subagent saw write-like command at line {line_number}"
            )

        if item.get("type") == "command_execution":
            command = item.get("command") or ""
            if command and any(pattern.search(str(command)) for pattern in claude_command_patterns):
                identity = item.get("id") or item.get("call_id")
                if not identity:
                    raise SystemExit(
                        "Fusion Rescue Codex live primary command_execution lacked item identity"
                    )
                launch_records.append({
                    "identity": identity,
                    "line": line_number,
                    "command": command,
                    "shape": "command_execution",
                })
                outputs_by_call[identity] = terminal_result(
                    {
                        "exit_code": item.get("exit_code", item.get("return_code")),
                        "status": item.get("status"),
                        "aggregated_output": item.get("aggregated_output") or item.get("output") or "",
                    },
                    str(item.get("status") or ""),
                )
            continue

        payload_type = payload.get("type")
        is_function_exec = (
            payload_type == "function_call"
            and payload.get("name") in {"exec_command", "functions.exec_command"}
        )
        is_custom_exec = (
            payload.get("type") == "custom_tool_call"
            and payload.get("name") == "exec"
        )
        if is_function_exec or is_custom_exec:
            command = command_from_payload(payload)
            command_text = " ".join(command) if isinstance(command, list) else str(command)
            if command_text and any(pattern.search(command_text) for pattern in claude_command_patterns):
                identity = payload.get("call_id") or payload.get("id")
                if not identity:
                    raise SystemExit(
                        "Fusion Rescue Codex live primary Claude launch lacked call/item identity"
                    )
                record = {
                    "identity": identity,
                    "line": line_number,
                    "command": command,
                    "shape": payload_type,
                }
                if is_custom_exec:
                    if not isinstance(command, list):
                        raw = payload.get("input") or payload.get("arguments") or ""
                        raw_text = raw if isinstance(raw, str) else json.dumps(raw)
                        launcher = custom_exec_argv(data, raw_text)
                        record["command"] = launcher["argv"]
                        record["terminal_mode"] = launcher["terminal_mode"]
                    custom_candidates[identity] = record
                else:
                    launch_records.append(record)
            continue

        is_correlated_output = (
            payload_type == "function_call_output"
            or payload.get("type") == "custom_tool_call_output"
        )
        if is_correlated_output:
            identity = payload.get("call_id") or payload.get("id")
            if not identity:
                raise SystemExit(
                    "Fusion Rescue Codex live primary terminal output lacked call/item identity"
                )
            outputs_by_call[identity] = terminal_result(
                payload.get("output") or payload.get("content") or payload.get("result") or payload,
                str(payload.get("status") or ""),
            )

    async_launches = []
    for identity, record in sorted(custom_candidates.items(), key=lambda item: item[1]["line"]):
        observed = outputs_by_call.get(identity)
        if observed is None:
            launch_records.append(record)
            continue
        output = observed["output"]
        cell = async_cell(output)
        pre_execution_failure = (
            "Script failed" in output
            and "Script error:" in output
            and "ReferenceError:" in output
            and cell is None
            and nested_terminal_result(observed["output"]) is None
        )
        if pre_execution_failure:
            continue
        if cell is not None:
            record["shape"] = "custom_tool_call+function_wait"
            record["async_cell"] = cell
            async_launches.append(record)
            outputs_by_call.pop(identity, None)
        launch_records.append(record)

    if len(async_launches) == 1:
        async_launch = async_launches[0]
        state = {"cell": async_launch["async_cell"], "session": None, "terminal": None}
        wait_requests = {}
        poll_requests = {}
        for line_number, payload, _data in ordered_payloads:
            payload_type = payload.get("type")
            identity = payload.get("call_id") or payload.get("id")
            if payload_type == "function_call" and payload.get("name") == "wait":
                arguments = decoded_payload_value(payload)
                if not isinstance(arguments, dict) or not isinstance(arguments.get("cell_id"), (str, int)):
                    raise SystemExit("Fusion Rescue Codex live primary async wait lacked one concrete cell handle")
                wait_requests[identity] = (line_number, str(arguments["cell_id"]))
                continue
            if payload_type == "custom_tool_call" and payload.get("name") == "exec":
                poll_request = async_write_stdin_request(payload.get("input") or "")
                if poll_request is not None:
                    if not identity:
                        raise SystemExit("Fusion Rescue Codex live primary async poll lacked call identity")
                    if line_number < async_launch["line"]:
                        raise SystemExit("Fusion Rescue Codex live primary async poll preceded its launch")
                    if identity in poll_requests:
                        raise SystemExit("Fusion Rescue Codex live primary async poll reused call identity")
                    poll_session, poll_bounded = poll_request
                    poll_requests[identity] = (line_number, poll_session, poll_bounded)
                continue
            if payload_type not in {"function_call_output", "custom_tool_call_output"}:
                continue
            raw_output = payload.get("output") or payload.get("content") or payload.get("result") or ""
            terminal = terminal_result(raw_output, str(payload.get("status") or ""))
            structured_terminal = nested_terminal_result(raw_output)
            textual_terminal = fusion_textual_terminal(raw_output) if async_launch.get("terminal_mode") in {"envelope", "transport"} else None
            if structured_terminal is not None and textual_terminal is not None:
                raise SystemExit("Fusion Rescue Codex live primary async output mixed structured and textual terminal proofs")
            has_terminal_proof = structured_terminal is not None or textual_terminal is not None or "OH_NO_CLAUDE_FUSION_PANEL_OK" in terminal["output"]
            if line_number < async_launch["line"] and has_terminal_proof:
                raise SystemExit("Fusion Rescue Codex live primary async terminal output preceded its launch")
            if identity in poll_requests:
                poll_line, poll_session, poll_bounded = poll_requests.pop(identity)
                if line_number <= poll_line:
                    raise SystemExit("Fusion Rescue Codex live primary async poll output did not follow its call")
                if state["session"] is None or poll_session != state["session"]:
                    raise SystemExit("Fusion Rescue Codex live primary async poll session did not match its launch")
                if has_terminal_proof:
                    if not poll_bounded:
                        raise SystemExit("Fusion Rescue Codex live primary async terminal poll lacked bounded wait semantics")
                    if state["terminal"] is not None:
                        raise SystemExit("Fusion Rescue Codex live primary async launch had multiple terminal outputs")
                    if structured_terminal is not None:
                        terminal = structured_terminal
                    elif textual_terminal is not None:
                        terminal = textual_terminal
                    state["terminal"] = terminal
                    async_launch["shape"] = "custom_tool_call+custom_write_stdin"
                    continue
                next_cell = async_cell(terminal["output"])
                if next_cell is None:
                    raise SystemExit("Fusion Rescue Codex live primary async poll lacked its next cell handle")
                state["cell"] = next_cell
                continue
            if identity not in wait_requests:
                if has_terminal_proof:
                    raise SystemExit("Fusion Rescue Codex live primary terminal output came from an unrelated wait")
                continue
            wait_line, wait_cell = wait_requests.pop(identity)
            if wait_line < async_launch["line"]:
                if has_terminal_proof:
                    raise SystemExit("Fusion Rescue Codex live primary async wait preceded its launch")
                continue
            if wait_cell != state["cell"]:
                if has_terminal_proof:
                    raise SystemExit("Fusion Rescue Codex live primary async terminal wait used a mismatched cell handle")
                continue
            output_blob = collect_text(raw_output)
            structured_sessions = re.findall(r'["\']session_id["\']\s*:\s*["\']?([1-9][0-9]*)', output_blob)
            textual_sessions = re.findall(r'(?m)^SESSION_ID=([1-9][0-9]*)$', output_blob)
            if structured_sessions and textual_sessions:
                raise SystemExit("Fusion Rescue Codex live primary async wait mixed structured and textual session identities")
            observed_sessions = structured_sessions or textual_sessions
            session_ids = {int(value) for value in observed_sessions}
            if len(observed_sessions) > 1 or len(session_ids) > 1:
                raise SystemExit("Fusion Rescue Codex live primary async wait exposed multiple session identities")
            if session_ids:
                observed_session = next(iter(session_ids))
                if state["session"] is None:
                    state["session"] = observed_session
                elif state["session"] != observed_session:
                    raise SystemExit("Fusion Rescue Codex live primary async wait session changed")
            if has_terminal_proof:
                if state["session"] is None:
                    raise SystemExit("Fusion Rescue Codex live primary async terminal output lacked a correlated session")
                if state["terminal"] is not None:
                    raise SystemExit("Fusion Rescue Codex live primary async launch had multiple terminal outputs")
                if structured_terminal is not None:
                    terminal = structured_terminal
                elif textual_terminal is not None:
                    terminal = textual_terminal
                state["terminal"] = terminal
        if poll_requests:
            raise SystemExit("Fusion Rescue Codex live primary async poll lacked correlated output")
        if state["terminal"] is not None:
            outputs_by_call[async_launch["identity"]] = state["terminal"]

    if len(launch_records) != 1:
        raise SystemExit(
            "Fusion Rescue Codex live primary subagent must invoke Claude exactly once; "
            f"saw {len(launch_records)} candidate launch(es): {launch_records!r}"
        )
    launch = launch_records[0]
    argv = validate_argv(launch["command"])
    terminal = outputs_by_call.get(launch["identity"])
    if terminal is None:
        raise SystemExit(
            "Fusion Rescue Codex live primary Claude launch lacked correlated terminal output"
        )
    output = terminal["output"]
    exit_code = terminal["exit_code"]
    status_lower = terminal["status"].lower()
    nonzero = exit_code is not None and exit_code != 0
    terminal_failed = nonzero or status_lower in {"failed", "error", "cancelled"}
    success_marker = "OH_NO_CLAUDE_FUSION_PANEL_OK" in output
    http_429 = re.search(
        r"(?i)(?:\bHTTP(?:/[0-9.]+)?\s*(?:status(?:\s+code)?\s*)?[:=]?\s*429\b|\bHTTP status(?: code)?\s*[:=]?\s*429\b|API Error:\s*Request rejected\s*\(429\))",
        output,
    ) is not None
    cooldown = re.search(r"(?i)\bcredentials(?:\s+for\s+model\s+\S+)?(?:\s+are)?\s+cooling down\b", output) is not None
    competing_error_patterns = (
        r"(?i)command not found",
        r"(?i)permission denied",
        r"(?i)(?:invalid|unknown) (?:option|argument|model)",
        r"(?i)(?:config(?:uration)? (?:parse|syntax) error|failed to parse config|error parsing config)",
        r"(?i)\b(?:HTTP(?:/[0-9.]+)?\s*)?(?:401|403|5[0-9]{2})\b",
        r"(?i)timed? out|timeout",
        r"(?i)terminated by signal|signal [0-9]+",
        r"(?i)(?:budget|spend limit).*(?:exceeded|failure|failed|reached)",
    )
    competing = [pattern for pattern in competing_error_patterns if re.search(pattern, output)]
    if launch.get("terminal_mode") == "transport" and terminal.get("stderr_class") != "empty":
        raise SystemExit(
            "Fusion Rescue Codex live provider transport reported nonempty or uncertified stderr"
        )

    if exit_code == 1 and http_429 and cooldown:
        if success_marker:
            raise SystemExit(
                "Fusion Rescue Codex live provider-limited output coexisted with the Claude success marker"
            )
        if competing:
            raise SystemExit(
                "Fusion Rescue Codex live provider-limited output contained a competing terminal failure: "
                f"{competing!r}"
            )
        return {
            "outcome": "provider-limited",
            "argv": argv,
            "output": output,
            "identity": launch["identity"],
            "shape": launch["shape"],
            "exit_code": exit_code,
        }
    if http_429 or cooldown:
        raise SystemExit(
            "Fusion Rescue Codex live provider-limited classification requires inner exit_code=1 plus both HTTP 429 and credentials cooling down"
        )
    if terminal_failed:
        raise SystemExit(
            "Fusion Rescue Codex live primary Claude invocation failed outside the provider-limited class"
        )
    if not success_marker:
        raise SystemExit(
            "Fusion Rescue Codex live primary subagent did not capture Claude marker in correlated command output"
        )
    return {
        "outcome": "full",
        "argv": argv,
        "output": output,
        "identity": launch["identity"],
        "shape": launch["shape"],
        "exit_code": exit_code,
    }


def inspect_linked_primary_claude_call(receiver_to_lens, receiver_transcripts):
    primary_receivers = [
        receiver for receiver, lens in receiver_to_lens.items()
        if lens == "primary"
    ]
    if len(primary_receivers) != 1:
        raise SystemExit(
            "Fusion Rescue Codex live expected exactly one parent-linked primary receiver"
        )
    primary_receiver = primary_receivers[0]
    transcript = receiver_transcripts.get(primary_receiver)
    if transcript is None:
        raise SystemExit(
            "Fusion Rescue Codex live primary receiver lacked a loaded transcript"
        )
    return primary_receiver, inspect_primary_claude_call(transcript)


def run_primary_claude_classifier_fixtures():
    argv = [
        "claude",
        "--print",
        "--model",
        "opus",
        "--max-budget-usd",
        budget,
        "--permission-mode",
        "dontAsk",
        "--no-session-persistence",
        "Review the assigned primary panel directly.",
    ]

    def transcript(shape, output, exit_code=1, output_identity="call-1", extra_rows=()):
        if shape == "command_execution":
            rows = [{
                "item": {
                    "type": "command_execution",
                    "id": "call-1",
                    "status": "failed" if exit_code else "completed",
                    "exit_code": exit_code,
                    "command": argv,
                    "aggregated_output": output,
                }
            }]
        else:
            call_type = "function_call" if shape == "function_call" else "custom_tool_call"
            output_type = "function_call_output" if shape == "function_call" else "custom_tool_call_output"
            name = "exec_command" if shape == "function_call" else "exec"
            rows = [
                {
                    "payload": {
                        "type": call_type,
                        "name": name,
                        "call_id": "call-1",
                        "arguments": json.dumps({"argv": argv}),
                    }
                },
                {
                    "payload": {
                        "type": output_type,
                        "call_id": output_identity,
                        "output": json.dumps({"exit_code": exit_code, "output": output}),
                    }
                },
            ]
        rows.extend(extra_rows)
        return "\n".join(json.dumps(row) for row in rows)

    provider_text = "HTTP 429: credentials cooling down"
    for shape in ("command_execution", "function_call", "custom_tool_call"):
        result = inspect_primary_claude_call(transcript(shape, provider_text))
        if result["outcome"] != "provider-limited" or result["shape"] != shape:
            raise SystemExit(f"Fusion classifier positive fixture failed for {shape}: {result!r}")
    full = inspect_primary_claude_call(
        transcript("function_call", "OH_NO_CLAUDE_FUSION_PANEL_OK", exit_code=0)
    )
    if full["outcome"] != "full":
        raise SystemExit(f"Fusion classifier full-success control failed: {full!r}")

    def async_transcript(final_cell="8", final_session=None, second_launch=False, terminal_before_launch=False, duplicate_terminal=False):
        prompt = argv[-1]
        py_source = (
            'import os, subprocess\n'
            'prompt = ' + json.dumps(prompt) + '\n'
            'argv = [os.environ.get("CLAUDE_BIN", "claude"), '
            '"--print", "--model", "opus", "--max-budget-usd", ' + json.dumps(budget) + ', '
            '"--permission-mode", "dontAsk", "--no-session-persistence", prompt]\n'
            'result = subprocess.run(argv, capture_output=True, text=True, timeout=240)\n'
            'print(result.stdout, end="")\n'
            'if result.stderr: print("\\n[stderr]", result.stderr, end="")\n'
            'raise SystemExit(result.returncode)'
        )
        launch_input = (
            'const r = await tools.exec_command({cmd: ' + json.dumps("python3 -c " + shlex.quote(py_source)) + '});\n'
            'text(JSON.stringify(r));\n'
        )
        rows = []
        if terminal_before_launch:
            rows.extend((
                {"payload": {"type": "function_call", "name": "wait", "call_id": "wait-early", "arguments": json.dumps({"cell_id": "3"})}},
                {"payload": {"type": "function_call_output", "call_id": "wait-early", "output": json.dumps({"exit_code": 0, "output": "CLAUDE_EXIT_CODE=1\nHTTP 429: credentials cooling down"})}},
            ))
        for call_id, error in (
            ("pre-btoa", "ReferenceError: btoa is not defined"),
            ("pre-text-encoder", "ReferenceError: TextEncoder is not defined"),
        ):
            rows.extend((
                {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": call_id, "input": launch_input}},
                {"payload": {"type": "custom_tool_call_output", "call_id": call_id, "output": "Script failed\nWall time 0.0 seconds\nOutput:\nScript error:\n" + error}},
            ))
        rows.extend((
            {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": "launch-async", "input": launch_input}},
            {"payload": {"type": "custom_tool_call_output", "call_id": "launch-async", "output": "Script running with cell ID 3\nWall time 11.0 seconds\nOutput:\n"}},
        ))
        if second_launch:
            rows.extend((
                {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": "launch-second", "input": launch_input}},
                {"payload": {"type": "custom_tool_call_output", "call_id": "launch-second", "output": "Script running with cell ID 9\nWall time 11.0 seconds\nOutput:\n"}},
            ))
        rows.extend((
            {"payload": {"type": "function_call", "name": "wait", "call_id": "wait-3", "arguments": json.dumps({"cell_id": "3"})}},
            {"payload": {"type": "function_call_output", "call_id": "wait-3", "output": [
                {"type": "input_text", "text": "Script completed\nWall time 16.1 seconds\nOutput:\n"},
                {"type": "input_text", "text": json.dumps({"session_id": 27543, "output": ""})},
            ]}},
            {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": "poll-1", "input": "const r = await tools.write_stdin({session_id: 27543, chars: \"\"}); text(JSON.stringify(r));"}},
            {"payload": {"type": "custom_tool_call_output", "call_id": "poll-1", "output": "Script running with cell ID 4\nWall time 11.0 seconds\nOutput:\n"}},
            {"payload": {"type": "function_call", "name": "wait", "call_id": "wait-4", "arguments": json.dumps({"cell_id": "4"})}},
            {"payload": {"type": "function_call_output", "call_id": "wait-4", "output": [
                {"type": "input_text", "text": "Script completed\nWall time 14.2 seconds\nOutput:\n"},
                {"type": "input_text", "text": json.dumps({"session_id": 27543, "output": ""})},
            ]}},
            {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": "poll-2", "input": "const r = await tools.write_stdin({session_id: 27543, chars: \"\"}); text(JSON.stringify(r));"}},
            {"payload": {"type": "custom_tool_call_output", "call_id": "poll-2", "output": "Script running with cell ID 8\nWall time 11.0 seconds\nOutput:\n"}},
            {"payload": {"type": "function_call", "name": "wait", "call_id": "wait-final", "arguments": json.dumps({"cell_id": final_cell})}},
            {"payload": {"type": "function_call_output", "call_id": "wait-final", "output": [
                {"type": "input_text", "text": "Script completed\nWall time 7.4 seconds\nOutput:\n"},
                {"type": "input_text", "text": json.dumps({
                    **({"session_id": final_session} if final_session is not None else {}),
                    "exit_code": 1,
                    "output": "API Error: Request rejected (429) · All credentials for model claude-opus-5 are cooling down via provider claude\n",
                })},
            ]}},
        ))
        if duplicate_terminal:
            rows.extend((
                {"payload": {"type": "function_call", "name": "wait", "call_id": "wait-duplicate", "arguments": json.dumps({"cell_id": "8"})}},
                {"payload": {"type": "function_call_output", "call_id": "wait-duplicate", "output": json.dumps({
                    "exit_code": 0,
                    "output": "CLAUDE_EXIT_CODE=1\nHTTP 429: credentials cooling down",
                })}},
            ))
        return "\n".join(json.dumps(row) for row in rows)

    def async_write_stdin_transcript(final_input=None, output_identity="poll-final", prelaunch=False, duplicate_terminal=False):
        rows = [json.loads(row) for row in async_transcript().splitlines()]
        final_input = final_input or "const r = await tools.write_stdin({session_id: 27543, chars: \"\", yield_time_ms: 30000, max_output_tokens: 10000}); text(JSON.stringify(r));"
        terminal_rows = (
            {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": "poll-final", "input": final_input}},
            {"payload": {"type": "custom_tool_call_output", "call_id": output_identity, "output": [
                {"type": "input_text", "text": "Script completed\nWall time 9.5 seconds\nOutput:\n"},
                {"type": "input_text", "text": json.dumps({
                    "exit_code": 1,
                    "output": "API Error: Request rejected (429) · All credentials for model claude-opus-5 are cooling down via provider claude\n",
                })},
            ]}},
        )
        rows[-2:] = terminal_rows
        if prelaunch:
            rows[:0] = (
                {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": "poll-early", "input": final_input}},
                {"payload": {"type": "custom_tool_call_output", "call_id": "poll-early", "output": "Script running with cell ID 99\nWall time 11.0 seconds\nOutput:\n"}},
            )
        if duplicate_terminal:
            duplicate = json.loads(json.dumps(terminal_rows))
            duplicate[0]["payload"]["call_id"] = "poll-duplicate"
            duplicate[1]["payload"]["call_id"] = "poll-duplicate"
            rows.extend(duplicate)
        return "\n".join(json.dumps(row) for row in rows)

    def assigned_argv_wrapper_transcript(terminal_output=None, source_transform=None, output_identity="poll-assigned", poll_session=52069, duplicate_terminal=False, extra_rows=()):
        prompt = argv[-1]
        py_source = (
            'import os, subprocess\n'
            'prompt = """' + prompt + '"""\n'
            'argv = [os.environ.get("CLAUDE_BIN", "claude"), "--print", "--model", "opus", '
            '"--max-budget-usd", ' + json.dumps(budget) + ', "--permission-mode", "dontAsk", '
            '"--no-session-persistence", prompt]\n'
            'result = subprocess.run(argv, capture_output=True, text=True, timeout=240)\n'
            'print(result.stdout, end="")\n'
            'if result.stderr: print("\\n[stderr]", result.stderr, end="")\n'
            'raise SystemExit(result.returncode)'
        )
        if source_transform is not None:
            py_source = source_transform(py_source)
        launch_input = (
            'const r = await tools.exec_command({cmd: ' + json.dumps("python3 -c " + shlex.quote(py_source)) + ', '
            'workdir: "/tmp/fusion-fixture", yield_time_ms: 30000, max_output_tokens: 8000});\n'
            'text(JSON.stringify(r));'
        )
        terminal_output = terminal_output or {
            "exit_code": 1,
            "output": "API Error: Request rejected (429) · All credentials for model claude-opus-5 are cooling down via provider claude\n",
        }
        terminal_items = [
            {"type": "input_text", "text": "Script completed\nWall time 7.6 seconds\nOutput:\n"},
            {"type": "input_text", "text": json.dumps(terminal_output)},
        ]
        if duplicate_terminal:
            terminal_items.append({"type": "input_text", "text": json.dumps(terminal_output)})
        rows = [
            {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": "launch-assigned", "input": launch_input}},
            {"payload": {"type": "custom_tool_call_output", "call_id": "launch-assigned", "output": "Script running with cell ID 1\nWall time 11.0 seconds\nOutput:\n"}},
            {"payload": {"type": "function_call", "name": "wait", "call_id": "wait-assigned", "arguments": json.dumps({"cell_id": "1"})}},
            {"payload": {"type": "function_call_output", "call_id": "wait-assigned", "output": [
                {"type": "input_text", "text": "Script completed\nWall time 16.1 seconds\nOutput:\n"},
                {"type": "input_text", "text": json.dumps({"session_id": 52069, "output": ""})},
            ]}},
            {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": "poll-assigned", "input": f"const r = await tools.write_stdin({{session_id: {poll_session}, chars: \"\", yield_time_ms: 30000, max_output_tokens: 8000}}); text(JSON.stringify(r));"}},
            {"payload": {"type": "custom_tool_call_output", "call_id": output_identity, "output": terminal_items}},
        ]
        rows.extend(extra_rows)
        return "\n".join(json.dumps(row) for row in rows)

    def heredoc_wrapper_transcript(source_transform=None, command_transform=None, sink_transform=None, terminal_text=None, terminal_via_wait=False):
        prompt = argv[-1]
        py_source = (
            'import os\nimport subprocess\nimport sys\n\n'
            'prompt = ' + repr(prompt) + '\n'
            "exe = os.environ.get('CLAUDE_BIN') or 'claude'\n"
            "argv = [exe, '--print', '--model', 'opus', '--max-budget-usd', " + repr(budget) + ", '--permission-mode', 'dontAsk', '--no-session-persistence', prompt]\n"
            'try:\n'
            '    completed = subprocess.run(argv, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=300, check=False)\n'
            'except FileNotFoundError:\n'
            "    print('CLAUDE_CALL_STATUS=executable_not_found')\n"
            '    sys.exit(127)\n'
            'except subprocess.TimeoutExpired:\n'
            "    print('CLAUDE_CALL_STATUS=timeout')\n"
            '    sys.exit(124)\n'
            "print('CLAUDE_CALL_STATUS=completed')\n"
            "print('CLAUDE_EXIT_CODE=' + str(completed.returncode))\n"
            "print('CLAUDE_STDOUT_BEGIN')\n"
            'print(completed.stdout)\n'
            "print('CLAUDE_STDOUT_END')\n"
            'if completed.stderr:\n'
            "    print('CLAUDE_STDERR_BEGIN')\n"
            '    print(completed.stderr)\n'
            "    print('CLAUDE_STDERR_END')\n"
            'sys.exit(completed.returncode)\n'
        )
        if source_transform is not None:
            py_source = source_transform(py_source)
        command = "python3 - <<'PY'\n" + py_source + "PY"
        if command_transform is not None:
            command = command_transform(command)
        sink = 'text(r.output);\nif (r.session_id) text(`SESSION_ID=${r.session_id}`);'
        if sink_transform is not None:
            sink = sink_transform(sink)
        launch_input = (
            'const r = await tools.exec_command({cmd: ' + json.dumps(command) + ', '
            'workdir: "/tmp/fusion-fixture", yield_time_ms: 30000, max_output_tokens: 8000});\n'
            + sink
        )
        rows = [
            {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": "launch-heredoc", "input": launch_input}},
            {"payload": {"type": "custom_tool_call_output", "call_id": "launch-heredoc", "output": "Script running with cell ID 1\nWall time 11.0 seconds\nOutput:\n"}},
            {"payload": {"type": "function_call", "name": "wait", "call_id": "wait-heredoc", "arguments": json.dumps({"cell_id": "1"})}},
            {"payload": {"type": "function_call_output", "call_id": "wait-heredoc", "output": [{"type": "input_text", "text": json.dumps({"session_id": 32478, "output": ""})}]}},
        ]
        for index in range(1, 6):
            rows.extend((
                {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": f"poll-heredoc-{index}", "input": f"const r = await tools.write_stdin({{session_id: 32478, chars: \"\", yield_time_ms: 30000, max_output_tokens: 8000}}); text(r.output); if (r.session_id) text(`SESSION_ID=${{r.session_id}}`);"}},
                {"payload": {"type": "custom_tool_call_output", "call_id": f"poll-heredoc-{index}", "output": f"Script running with cell ID {index + 1}\nWall time 11.0 seconds\nOutput:\n"}},
            ))
        terminal_text = terminal_text or "CLAUDE_CALL_STATUS=completed\nCLAUDE_EXIT_CODE=1\nCLAUDE_STDOUT_BEGIN\nAPI Error: Request rejected (429) · All credentials for model claude-opus-5 are cooling down via provider claude\nCLAUDE_STDOUT_END\n"
        rows.append(
            {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": "poll-heredoc-final", "input": "const r = await tools.write_stdin({session_id: 32478, chars: \"\", yield_time_ms: 30000, max_output_tokens: 8000}); text(r.output); if (r.session_id) text(`SESSION_ID=${r.session_id}`);"}}
        )
        if terminal_via_wait:
            rows.extend((
                {"payload": {"type": "custom_tool_call_output", "call_id": "poll-heredoc-final", "output": "Script running with cell ID 7\nWall time 11.0 seconds\nOutput:\n"}},
                {"payload": {"type": "function_call", "name": "wait", "call_id": "wait-heredoc-final", "arguments": json.dumps({"cell_id": "7"})}},
                {"payload": {"type": "function_call_output", "call_id": "wait-heredoc-final", "output": [{"type": "input_text", "text": "Script completed\nWall time 5.0 seconds\nOutput:\n"}, {"type": "input_text", "text": terminal_text}]}},
            ))
        else:
            rows.append(
                {"payload": {"type": "custom_tool_call_output", "call_id": "poll-heredoc-final", "output": [{"type": "input_text", "text": "Script completed\nWall time 5.0 seconds\nOutput:\n"}, {"type": "input_text", "text": terminal_text}]}}
            )
        return "\n".join(json.dumps(row) for row in rows)

    def semantic_transport_wrapper_transcript(
        source_transform=None, terminal_text=None, poll_tokens=12000,
        poll_session=16195, poll_chars="", final_parent_text="Claude marker: absent.",
    ):
        prompt = argv[-1]
        py_source = (
            'import os, subprocess, sys\n'
            'prompt = ' + repr(prompt) + '\n'
            'binary = os.environ.get("CLAUDE_BIN") or "claude"\n'
            'args = [binary, "--print", "--model", "opus", "--max-budget-usd", ' + repr(budget) + ', "--permission-mode", "dontAsk", "--no-session-persistence", prompt]\n'
            'try:\n'
            '    cp = subprocess.run(args, shell=False, capture_output=True, text=True)\n'
            'except Exception as exc:\n'
            '    print("CLAUDE_LAUNCH_FAILURE_TYPE=" + type(exc).__name__)\n'
            '    sys.exit(125)\n'
            'print("CLAUDE_EXIT_STATUS=" + str(cp.returncode))\n'
            'print("CLAUDE_STDERR_CLASS=" + ("empty" if not cp.stderr else "nonempty"))\n'
            'print("CLAUDE_STDOUT_BEGIN")\n'
            'print(cp.stdout, end="" if cp.stdout.endswith("\\\\n") or not cp.stdout else "\\\\n")\n'
            'print("CLAUDE_STDOUT_END")\n'
            'sys.exit(0)\n'
        )
        if source_transform is not None:
            py_source = source_transform(py_source)
        launch_input = (
            'const r = await tools.exec_command({cmd: ' + json.dumps("python3 -c " + shlex.quote(py_source)) + ', '
            'workdir: "/tmp/fusion-fixture", yield_time_ms: 30000, max_output_tokens: 12000});\n'
            'text(r.output);\nif (r.session_id) text(`SESSION_ID=${r.session_id}`);'
        )
        terminal_text = terminal_text or (
            "CLAUDE_EXIT_STATUS=1\n"
            "CLAUDE_STDERR_CLASS=empty\n"
            "CLAUDE_STDOUT_BEGIN\n"
            "API Error: Request rejected (429) · All credentials for model claude-opus-5 are cooling down via provider claude\n"
            "\\nCLAUDE_STDOUT_END\n"
        )
        rows = [
            {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": "call_ksm2zVFgGGQBkjfq6HsAPYVm", "input": launch_input}},
            {"payload": {"type": "custom_tool_call_output", "call_id": "call_ksm2zVFgGGQBkjfq6HsAPYVm", "output": "Script running with cell ID 1\nWall time 11.0 seconds\nOutput:\n"}},
            {"payload": {"type": "function_call", "name": "wait", "call_id": "wait-semantic", "arguments": json.dumps({"cell_id": "1"})}},
            {"payload": {"type": "function_call_output", "call_id": "wait-semantic", "output": [{"type": "input_text", "text": json.dumps({"session_id": 16195, "output": ""})}]}},
        ]
        for index in range(1, 5):
            rows.extend((
                {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": f"poll-semantic-{index}", "input": f'const r = await tools.write_stdin({{session_id: {poll_session}, chars: {json.dumps(poll_chars)}, yield_time_ms: 30000, max_output_tokens: {poll_tokens}}});\ntext(r.output);\nif (r.session_id) text(`SESSION_ID=${{r.session_id}}`);'}},
                {"payload": {"type": "custom_tool_call_output", "call_id": f"poll-semantic-{index}", "output": f"Script running with cell ID {index + 1}\nWall time 11.0 seconds\nOutput:\n"}},
            ))
        rows.extend((
            {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": "call_eWhCQFTAiwnBHFcEbFPooZLM", "input": f'const r = await tools.write_stdin({{session_id: {poll_session}, chars: {json.dumps(poll_chars)}, yield_time_ms: 30000, max_output_tokens: {poll_tokens}}});\ntext(r.output);\nif (r.session_id) text(`SESSION_ID=${{r.session_id}}`);'}},
            {"payload": {"type": "custom_tool_call_output", "call_id": "call_eWhCQFTAiwnBHFcEbFPooZLM", "output": [{"type": "input_text", "text": "Script completed\nWall time 0.0 seconds\nOutput:\n"}, {"type": "input_text", "text": terminal_text}]}},
            {"type": "event_msg", "payload": {"type": "task_complete", "last_agent_message": final_parent_text}},
        ))
        return "\n".join(json.dumps(row) for row in rows)

    semantic_transport = inspect_primary_claude_call(semantic_transport_wrapper_transcript())
    if semantic_transport["outcome"] != "provider-limited" or semantic_transport["shape"] != "custom_tool_call+custom_write_stdin" or semantic_transport["exit_code"] != 1 or first_leg_rc != 0:
        raise SystemExit(f"Fusion classifier semantic transport fixture failed: {semantic_transport!r}")

    parent_stream = (
        {"item": {"type": "message", "role": "user", "text": "Require OH_NO_CLAUDE_FUSION_PANEL_OK and OH_NO_CODEX_FUSION_RESCUE_LIVE_OK."}},
        {"item": {"type": "collab_tool_call", "tool": "spawn_agent", "status": "completed", "message": "Primary instruction requires OH_NO_CLAUDE_FUSION_PANEL_OK."}},
        {"item": {"type": "agent_message", "text": "Provider-limited final. Claude marker: absent."}},
    )
    observed_parent_results = [
        text for row in parent_stream
        if (text := fusion_parent_observed_result_text(row))
    ]
    primary_results = {"receiver-primary": "Primary result. Claude marker: absent."}
    if fusion_provider_observed_success_markers(primary_results, observed_parent_results):
        raise SystemExit("Fusion provider result guard counted outbound prompt/spawn instruction tokens")
    claude_collision_parent = [fusion_parent_observed_result_text(
        {"item": {"type": "agent_message", "text": "OH_NO_CLAUDE_FUSION_PANEL_OK"}}
    )]
    codex_collision_parent = [fusion_parent_observed_result_text(
        {"item": {"type": "agent_message", "text": "OH_NO_CODEX_FUSION_RESCUE_LIVE_OK"}}
    )]
    for label, panel_results, parent_results, expected in (
        ("primary child Claude token", {"receiver-primary": "OH_NO_CLAUDE_FUSION_PANEL_OK"}, observed_parent_results, ["OH_NO_CLAUDE_FUSION_PANEL_OK"]),
        ("parent final Claude token", primary_results, claude_collision_parent, ["OH_NO_CLAUDE_FUSION_PANEL_OK"]),
        ("parent final Codex token", primary_results, codex_collision_parent, ["OH_NO_CODEX_FUSION_RESCUE_LIVE_OK"]),
    ):
        actual = fusion_provider_observed_success_markers(panel_results, parent_results)
        if actual != expected:
            raise SystemExit(f"Fusion provider result guard missed {label}: {actual!r}")

    assigned_wrapper = inspect_primary_claude_call(assigned_argv_wrapper_transcript())
    if assigned_wrapper["outcome"] != "provider-limited" or assigned_wrapper["shape"] != "custom_tool_call+custom_write_stdin":
        raise SystemExit(f"Fusion classifier assigned-argv wrapper fixture failed: {assigned_wrapper!r}")
    heredoc_wrapper = inspect_primary_claude_call(heredoc_wrapper_transcript())
    if heredoc_wrapper["outcome"] != "provider-limited" or heredoc_wrapper["shape"] != "custom_tool_call+custom_write_stdin" or heredoc_wrapper["exit_code"] != 1 or first_leg_rc != 0:
        raise SystemExit(f"Fusion classifier heredoc wrapper fixture failed: {heredoc_wrapper!r}")
    heredoc_final_wait = inspect_primary_claude_call(heredoc_wrapper_transcript(terminal_via_wait=True))
    if heredoc_final_wait["outcome"] != "provider-limited" or heredoc_final_wait["shape"] != "custom_tool_call+function_wait" or heredoc_final_wait["exit_code"] != 1:
        raise SystemExit(f"Fusion classifier heredoc final-wait fixture failed: {heredoc_final_wait!r}")
    heredoc_negatives = (
        ("unquoted heredoc", {"command_transform": lambda command: command.replace("<<'PY'", "<<PY", 1)}),
        ("extra shell command", {"command_transform": lambda command: command + "\nprintf fabricated"}),
        ("pipeline", {"command_transform": lambda command: command + " | cat"}),
        ("redirection", {"command_transform": lambda command: command + " > /tmp/output"}),
        ("wrong env key", {"source_transform": lambda source: source.replace("CLAUDE_BIN", "WRONG_BIN")}),
        ("executable reassignment", {"source_transform": lambda source: source.replace("argv = [exe", "exe = 'claude'\nargv = [exe")}),
        ("unbounded timeout", {"source_transform": lambda source: source.replace("timeout=300", "timeout=301")}),
        ("check true", {"source_transform": lambda source: source.replace("check=False", "check=True")}),
        ("second subprocess", {"source_transform": lambda source: source.replace("try:\n", "subprocess.run(argv, capture_output=True, text=True, timeout=1)\ntry:\n")}),
        ("os.system call", {"source_transform": lambda source: source.replace("try:\n", "os.system('true')\ntry:\n")}),
        ("open write call", {"source_transform": lambda source: source.replace("try:\n", "open('/tmp/fabricated', 'w')\ntry:\n")}),
        ("eval call", {"source_transform": lambda source: source.replace("try:\n", "eval('1 + 1')\ntry:\n")}),
        ("exec call", {"source_transform": lambda source: source.replace("try:\n", "exec('value = 1')\ntry:\n")}),
        ("dynamic import call", {"source_transform": lambda source: source.replace("try:\n", "__import__('pathlib')\ntry:\n")}),
        ("arbitrary method call", {"source_transform": lambda source: source.replace("try:\n", "prompt.upper()\ntry:\n")}),
        ("handler arbitrary call", {"source_transform": lambda source: source.replace("except FileNotFoundError:\n", "except FileNotFoundError:\n    os.system('true')\n")}),
        ("pre-run static provider print", {"source_transform": lambda source: source.replace("try:\n", "print('HTTP 429 credentials cooling down')\ntry:\n")}),
        ("environment subscript assignment", {"source_transform": lambda source: source.replace("try:\n", "os.environ['CLAUDE_BIN'] = 'other'\ntry:\n")}),
        ("nested import", {"source_transform": lambda source: source.replace("try:\n", "if True:\n    import socket\ntry:\n")}),
        ("extra JavaScript tool call", {"sink_transform": lambda sink: "await tools.write_file({path: '/tmp/fabricated', content: 'x'});\n" + sink}),
        ("static provider print", {"source_transform": lambda source: source.replace("print('CLAUDE_CALL_STATUS=completed')", "print('HTTP 429 credentials cooling down')\nprint('CLAUDE_CALL_STATUS=completed')")}),
        ("constant exit marker", {"source_transform": lambda source: source.replace("str(completed.returncode)", "'1'")}),
        ("constant final exit", {"source_transform": lambda source: source.replace("sys.exit(completed.returncode)", "sys.exit(1)")}),
        ("output not result-derived", {"source_transform": lambda source: source.replace("print(completed.stdout)", "print('fabricated output')")}),
        ("timeout branch provider proof", {"source_transform": lambda source: source.replace("print('CLAUDE_CALL_STATUS=timeout')", "print('CLAUDE_CALL_STATUS=completed')\n    print('CLAUDE_EXIT_CODE=1')")}),
        ("sink bound to another result", {"sink_transform": lambda sink: sink.replace("r.output", "other.output")}),
        ("multiple output owners", {"sink_transform": lambda sink: sink + "\ntext(JSON.stringify(r));"}),
        ("constant textual exit proof", {"terminal_text": "CLAUDE_CALL_STATUS=completed\nCLAUDE_EXIT_CODE=1\nCLAUDE_STDOUT_BEGIN\nHTTP 429 credentials cooling down\nCLAUDE_STDOUT_END\nCLAUDE_EXIT_CODE=1\n"}),
    )
    for label, kwargs in heredoc_negatives:
        try:
            inspect_primary_claude_call(heredoc_wrapper_transcript(**kwargs))
        except SystemExit:
            pass
        else:
            raise SystemExit(f"Fusion classifier heredoc negative fixture unexpectedly passed: {label}")
    semantic_transport_negatives = (
        ("dynamic timeout", {"source_transform": lambda source: source.replace("text=True)", "text=True, timeout=int('1'))")}),
        ("timeout None", {"source_transform": lambda source: source.replace("text=True)", "text=True, timeout=None)")}),
        ("timeout zero", {"source_transform": lambda source: source.replace("text=True)", "text=True, timeout=0)")}),
        ("timeout 301", {"source_transform": lambda source: source.replace("text=True)", "text=True, timeout=301)")}),
        ("handler arbitrary call", {"source_transform": lambda source: source.replace('    print("CLAUDE_LAUNCH_FAILURE_TYPE="', '    os.system("true")\n    print("CLAUDE_LAUNCH_FAILURE_TYPE="')}),
        ("handler provider text", {"source_transform": lambda source: source.replace('    print("CLAUDE_LAUNCH_FAILURE_TYPE="', '    print("HTTP 429 credentials cooling down")\n    print("CLAUDE_LAUNCH_FAILURE_TYPE="')}),
        ("handler wrong exit", {"source_transform": lambda source: source.replace("sys.exit(125)", "sys.exit(1)")}),
        ("handler no alias", {"source_transform": lambda source: source.replace("except Exception as exc:", "except Exception:")}),
        ("bare handler", {"source_transform": lambda source: source.replace("except Exception as exc:", "except:")}),
        ("multiple broad handlers", {"source_transform": lambda source: source.replace("except Exception as exc:", "except Exception as exc:\n    print(\"CLAUDE_LAUNCH_FAILURE_TYPE=\" + type(exc).__name__)\n    sys.exit(125)\nexcept Exception as other:")}),
        ("BaseException handler", {"source_transform": lambda source: source.replace("except Exception as exc:", "except BaseException as exc:")}),
        ("extra handler statement", {"source_transform": lambda source: source.replace("    sys.exit(125)", "    print(type(exc).__name__)\n    sys.exit(125)")}),
        ("constant exit status", {"source_transform": lambda source: source.replace("str(cp.returncode)", '"1"')}),
        ("status wrong result", {"source_transform": lambda source: source.replace("str(cp.returncode)", "str(other.returncode)")}),
        ("fabricated stderr class", {"source_transform": lambda source: source.replace('(\"empty\" if not cp.stderr else \"nonempty\")', '"empty"')}),
        ("nonempty stderr class", {"terminal_text": "CLAUDE_EXIT_STATUS=1\nCLAUDE_STDERR_CLASS=nonempty\nCLAUDE_STDOUT_BEGIN\nHTTP 429: credentials cooling down\n\\nCLAUDE_STDOUT_END\n"}),
        ("stdout constant", {"source_transform": lambda source: source.replace("print(cp.stdout, end=", 'print("HTTP 429 credentials cooling down", end=')}),
        ("stdout wrong result", {"source_transform": lambda source: source.replace("print(cp.stdout, end=", "print(other.stdout, end=")}),
        ("final nonzero wrapper exit", {"source_transform": lambda source: source.replace("sys.exit(0)", "sys.exit(1)")}),
        ("static provider text", {"source_transform": lambda source: source.replace('print("CLAUDE_STDOUT_BEGIN")', 'print("HTTP 429 credentials cooling down")\nprint("CLAUDE_STDOUT_BEGIN")')}),
        ("poll output cap 12001", {"poll_tokens": 12001}),
        ("poll nonempty chars", {"poll_chars": "x"}),
        ("poll mismatched session", {"poll_session": 99999}),
        ("success token collision", {"terminal_text": "CLAUDE_EXIT_STATUS=1\nCLAUDE_STDERR_CLASS=empty\nCLAUDE_STDOUT_BEGIN\nHTTP 429: credentials cooling down; OH_NO_CLAUDE_FUSION_PANEL_OK\n\\nCLAUDE_STDOUT_END\n"}),
    )
    for label, kwargs in semantic_transport_negatives:
        transcript_text = semantic_transport_wrapper_transcript(**kwargs)
        try:
            inspect_primary_claude_call(transcript_text)
        except SystemExit:
            pass
        else:
            raise SystemExit(f"Fusion classifier semantic transport negative fixture unexpectedly passed: {label}")
    assigned_wrapper_negatives = (
        ("shell=True", {"source_transform": lambda source: source.replace(
            'result = subprocess.run(argv, capture_output=True, text=True, timeout=240)',
            'result = subprocess.run(argv, capture_output=True, text=True, timeout=240, shell=True)',
        )}),
        ("string command", {"source_transform": lambda source: source.replace(
            'result = subprocess.run(argv, capture_output=True, text=True, timeout=240)',
            'result = subprocess.run("claude --print", capture_output=True, text=True, timeout=240, shell=False)',
        )}),
        ("argv reassignment", {"source_transform": lambda source: source.replace(
            'result = subprocess.run(argv,', 'argv = argv\nresult = subprocess.run(argv,',
        )}),
        ("prompt reassignment", {"source_transform": lambda source: source.replace(
            'argv = [', 'prompt = prompt\nargv = [',
        )}),
        ("argv mutation", {"source_transform": lambda source: source.replace(
            'result = subprocess.run(argv,', 'argv.append("--tools")\nresult = subprocess.run(argv,',
        )}),
        ("tools override", {"source_transform": lambda source: source.replace(
            '"--no-session-persistence", prompt]', '"--no-session-persistence", "--tools", "", prompt]',
        )}),
        ("two subprocess calls", {"source_transform": lambda source: source.replace(
            'result = subprocess.run(argv,', 'subprocess.run(argv, capture_output=True, text=True, timeout=240)\nresult = subprocess.run(argv,',
        )}),
        ("subprocess prose without AST call", {"source_transform": lambda source: source.replace(
            'result = subprocess.run(argv, capture_output=True, text=True, timeout=240)',
            '# subprocess.run(argv, capture_output=True, text=True, timeout=240)\nresult = None',
        )}),
        ("constant SystemExit", {"source_transform": lambda source: source.replace(
            'raise SystemExit(result.returncode)', 'raise SystemExit(1)',
        )}),
        ("stdout prose constant", {"source_transform": lambda source: source.replace(
            'print(result.stdout, end="")', 'print("unrelated stdout", end="")',
        )}),
        ("stderr prose constant", {"source_transform": lambda source: source.replace(
            'print("\\n[stderr]", result.stderr, end="")', 'print("unrelated stderr", end="")',
        )}),
        ("altered stderr condition", {"source_transform": lambda source: source.replace(
            'if result.stderr:', 'if True:',
        )}),
        ("stderr else branch", {"source_transform": lambda source: source.replace(
            'if result.stderr: print("\\n[stderr]", result.stderr, end="")',
            'if result.stderr:\n    print("\\n[stderr]", result.stderr, end="")\nelse:\n    print("unrelated")',
        )}),
        ("nested terminal missing exit_code", {"terminal_output": {"output": provider_text}}),
        ("nested terminal exit_code zero", {"terminal_output": {"exit_code": 0, "output": provider_text}}),
        ("nested terminal arbitrary nonzero exit_code", {"terminal_output": {"exit_code": 2, "output": provider_text}}),
        ("multiple nested terminal objects", {"duplicate_terminal": True}),
        ("mismatched terminal call identity", {"output_identity": "poll-other"}),
        ("mismatched terminal session", {"poll_session": 99999}),
        ("provider text only in task-complete prose", {
            "terminal_output": {"exit_code": 1, "output": "generic provider failure"},
            "extra_rows": ({"type": "event_msg", "payload": {"type": "task_complete", "last_agent_message": provider_text}},),
        }),
    )
    for label, kwargs in assigned_wrapper_negatives:
        try:
            inspect_primary_claude_call(assigned_argv_wrapper_transcript(**kwargs))
        except SystemExit:
            pass
        else:
            raise SystemExit(f"Fusion classifier assigned-argv negative fixture unexpectedly passed: {label}")

    async_result = inspect_primary_claude_call(async_transcript())
    if async_result["outcome"] != "provider-limited" or async_result["shape"] != "custom_tool_call+function_wait":
        raise SystemExit(f"Fusion classifier async wait fixture failed: {async_result!r}")
    async_write_result = inspect_primary_claude_call(async_write_stdin_transcript())
    if async_write_result["outcome"] != "provider-limited" or async_write_result["shape"] != "custom_tool_call+custom_write_stdin":
        raise SystemExit(f"Fusion classifier async write_stdin fixture failed: {async_write_result!r}")
    for label, kwargs in (
        ("second eligible async launch", {"second_launch": True}),
        ("terminal output before launch", {"terminal_before_launch": True}),
        ("mismatched wait handle", {"final_cell": "99"}),
        ("mismatched wait session", {"final_session": 99999}),
        ("multiple terminal wait outputs", {"duplicate_terminal": True}),
    ):
        try:
            inspect_primary_claude_call(async_transcript(**kwargs))
        except SystemExit:
            pass
        else:
            raise SystemExit(f"Fusion classifier async negative fixture unexpectedly passed: {label}")
    write_stdin_negatives = (
        ("pre-launch write_stdin", {"prelaunch": True}),
        ("changed write_stdin session", {"final_input": "const r = await tools.write_stdin({session_id: 99999, chars: \"\", yield_time_ms: 30000, max_output_tokens: 10000}); text(JSON.stringify(r));"}),
        ("missing write_stdin session", {"final_input": "const r = await tools.write_stdin({chars: \"\", yield_time_ms: 30000, max_output_tokens: 10000}); text(JSON.stringify(r));"}),
        ("nonempty write_stdin input", {"final_input": "const r = await tools.write_stdin({session_id: 27543, chars: \"x\", yield_time_ms: 30000, max_output_tokens: 10000}); text(JSON.stringify(r));"}),
        ("ambiguous write_stdin session", {"final_input": "const r = await tools.write_stdin({session_id: 27543, session_id: 27543, chars: \"\", yield_time_ms: 30000, max_output_tokens: 10000}); text(JSON.stringify(r));"}),
        ("multiple write_stdin operations", {"final_input": "const a = await tools.write_stdin({session_id: 27543, chars: \"\"}); const b = await tools.write_stdin({session_id: 27543, chars: \"\"}); text(JSON.stringify(b));"}),
        ("mixed exec_command and write_stdin", {"final_input": "const a = await tools.exec_command({cmd: \"true\"}); const b = await tools.write_stdin({session_id: 27543, chars: \"\", yield_time_ms: 30000, max_output_tokens: 10000}); text(JSON.stringify(b));"}),
        ("unbounded terminal write_stdin", {"final_input": "const r = await tools.write_stdin({session_id: 27543, chars: \"\"}); text(JSON.stringify(r));"}),
        ("mismatched write_stdin output identity", {"output_identity": "poll-other"}),
        ("multiple terminal write_stdin outputs", {"duplicate_terminal": True}),
    )
    for label, kwargs in write_stdin_negatives:
        try:
            inspect_primary_claude_call(async_write_stdin_transcript(**kwargs))
        except SystemExit:
            pass
        else:
            raise SystemExit(f"Fusion classifier async write_stdin negative fixture unexpectedly passed: {label}")

    negative_outputs = {
        "429 without cooldown": "HTTP 429",
        "cooldown without 429": "credentials cooling down",
        "401": "HTTP 401: credentials cooling down",
        "403": "HTTP 403: credentials cooling down",
        "5xx": "HTTP 503: credentials cooling down",
        "command not found": "HTTP 429: credentials cooling down; command not found",
        "permission denied": "HTTP 429: credentials cooling down; permission denied",
        "invalid option": "HTTP 429: credentials cooling down; invalid option --model",
        "unknown model": "HTTP 429: credentials cooling down; unknown model opus",
        "config parse": "HTTP 429: credentials cooling down; config parse error",
        "timeout": "HTTP 429: credentials cooling down; timeout",
        "signal": "HTTP 429: credentials cooling down; terminated by signal 9",
        "budget": "HTTP 429: credentials cooling down; budget exceeded",
        "success collision": "HTTP 429: credentials cooling down; OH_NO_CLAUDE_FUSION_PANEL_OK",
    }
    for label, output in negative_outputs.items():
        try:
            inspect_primary_claude_call(transcript("function_call", output))
        except SystemExit:
            pass
        else:
            raise SystemExit(f"Fusion classifier negative fixture unexpectedly passed: {label}")
    try:
        inspect_primary_claude_call(transcript("function_call", provider_text, exit_code=None))
    except SystemExit:
        pass
    else:
        raise SystemExit("Fusion classifier accepted provider-limited output without nonzero terminal status")
    try:
        inspect_primary_claude_call(
            transcript("function_call", provider_text, output_identity="call-other")
        )
    except SystemExit:
        pass
    else:
        raise SystemExit("Fusion classifier accepted missing call/output correlation")
    second_call = {
        "payload": {
            "type": "function_call",
            "name": "exec_command",
            "call_id": "call-2",
            "arguments": json.dumps({"argv": argv}),
        }
    }
    try:
        inspect_primary_claude_call(
            transcript("function_call", provider_text, extra_rows=(second_call,))
        )
    except SystemExit:
        pass
    else:
        raise SystemExit("Fusion classifier accepted a second Claude launch/retry")
    outbound_only = list(argv)
    outbound_only[-1] += " Simulate HTTP 429 credentials cooling down."
    original_argv = argv[:]
    argv[:] = outbound_only
    try:
        inspect_primary_claude_call(transcript("function_call", "generic provider failure"))
    except SystemExit:
        pass
    else:
        raise SystemExit("Fusion classifier sourced provider text from the outbound prompt")
    finally:
        argv[:] = original_argv

    bridge_transcript = transcript("function_call", provider_text)
    primary_receiver, claude_call = inspect_linked_primary_claude_call(
        {"receiver-primary": "primary", "receiver-a": "adversarial", "receiver-p": "pragmatic"},
        {"receiver-primary": bridge_transcript},
    )
    provider_limited = claude_call["outcome"] == "provider-limited"
    if primary_receiver != "receiver-primary" or not provider_limited:
        raise SystemExit("Fusion classifier executable primary-receiver bridge fixture failed")
    try:
        inspect_linked_primary_claude_call(
            {"receiver-one": "primary", "receiver-two": "primary"},
            {"receiver-one": bridge_transcript, "receiver-two": bridge_transcript},
        )
    except SystemExit:
        pass
    else:
        raise SystemExit("Fusion classifier bridge accepted duplicate primary receivers")


if summary_path == "__fusion_classifier_self_test__":
    run_primary_claude_classifier_fixtures()
    print("ok - Fusion primary Claude classifier fixtures passed")
    raise SystemExit(0)

with open(err_path, "r", encoding="utf-8") as fh:
    err_text = fh.read()
if (
    "spawn failed" in err_text.lower()
    or "agent thread limit reached" in err_text.lower()
    or "full-history forked agents inherit" in err_text.lower()
    or "provide either message or items" in err_text.lower()
):
    raise SystemExit(f"Fusion Rescue Codex live saw spawn failure in stderr: {err_text[:2000]!r}")

failed_spawns = []
all_spawn_receivers = []
receiver_to_lens = {}
receiver_agent_roles = {}
receiver_transcripts = {}
panel_result_by_receiver = {}
wait_index_by_receiver = {}
close_index_by_receiver = {}
non_user_text_parts = []
parent_result_text_parts = []
parent_thread_id = None
used_transcript_fallback = False

with open(out_path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        if data.get("type") == "thread.started":
            parent_thread_id = data.get("thread_id") or parent_thread_id
        item = data.get("item") or {}
        event_text = collect_text(data)
        if any(pattern.search(event_text) for pattern in secret_patterns):
            raise SystemExit(f"Fusion Rescue Codex live transcript exposed a secret-like value near line {index}")
        item_type_lower = str(item.get("type") or data.get("type") or "").lower()
        tool_lower = str(item.get("tool") or item.get("name") or data.get("tool") or data.get("name") or "").lower()
        command_text = str(item.get("command") or "")
        if item_type_lower in forbidden_write_tools or tool_lower in forbidden_write_tools:
            raise SystemExit(
                f"Fusion Rescue Codex live saw write-capable event at line {index}: "
                f"type={item_type_lower!r} tool={tool_lower!r}"
            )
        if item_type_lower == "command_execution" and any(
            pattern.search(command_text) for pattern in forbidden_command_patterns
        ):
            raise SystemExit(
                f"Fusion Rescue Codex live saw write-like command at line {index}: "
                f"{command_text[:1000]!r}"
            )
        if event_is_command_bearing(data) and any(
            pattern.search(command)
            for command in safety_inspectable_commands(data)
            for pattern in claude_command_patterns
        ):
            raise SystemExit(
                "Fusion Rescue Codex live Claude launch was not owned by the parent-linked primary child"
            )
        if role_of_event(data) != "user":
            non_user_text_parts.append(event_text)
        parent_result_text = fusion_parent_observed_result_text(data)
        if parent_result_text:
            parent_result_text_parts.append(parent_result_text)
        if item.get("type") != "collab_tool_call":
            continue
        tool = item.get("tool")
        status = item.get("status")
        if tool == "spawn_agent" and status == "failed":
            failed_spawns.append((index, collect_text(item)[:2000]))
        if tool == "spawn_agent" and status == "completed":
            all_spawn_receivers.extend(item.get("receiver_thread_ids") or [])
            spawn_text = collect_text(item)
            matched = [lens for lens, marker in expected_markers.items() if marker in spawn_text]
            if not matched:
                raise SystemExit(
                    "Fusion Rescue Codex live saw an unexpected spawn_agent call "
                    f"without a required panel marker at line {index}: {spawn_text[:2000]!r}"
                )
            if len(matched) != 1:
                raise SystemExit(
                    f"Fusion Rescue Codex live spawn payload matched multiple lenses {matched!r}; "
                    f"text={spawn_text[:2000]!r}"
                )
            receivers = item.get("receiver_thread_ids") or []
            if len(receivers) != 1:
                raise SystemExit(
                    f"Fusion Rescue Codex live expected one receiver for {matched[0]}, got {receivers!r}"
            )
            if matched[0] == "primary":
                for required in required_claude_argv + [
                    "OH_NO_CLAUDE_FUSION_PANEL_OK",
                    "Codex permission preflight",
                    "danger-full-access confirmed",
                ]:
                    if required.lower() not in spawn_text.lower():
                        raise SystemExit(
                            f"Fusion Rescue Codex live primary spawn prompt missed {required!r}; "
                            f"text={spawn_text[:2000]!r}"
                        )
            receiver_to_lens[receivers[0]] = matched[0]
        if status == "completed" and tool in {"wait", "wait_agent", "close_agent"}:
            text = collect_text(item)
            mentioned = set(item.get("receiver_thread_ids") or [])
            mentioned.update(receiver for receiver in receiver_to_lens if receiver in text)
            mentioned.update(
                receiver for receiver in (item.get("agents_states") or {})
                if receiver in receiver_to_lens
            )
            if tool in {"wait", "wait_agent"}:
                for receiver in mentioned:
                    state = (item.get("agents_states") or {}).get(receiver) or {}
                    if state.get("status") == "completed" and state.get("message"):
                        wait_index_by_receiver.setdefault(receiver, index)
                        panel_result_by_receiver.setdefault(receiver, str(state.get("message")))
            if tool == "close_agent":
                for receiver in mentioned:
                    close_index_by_receiver.setdefault(receiver, index)

if failed_spawns:
    raise SystemExit(f"Fusion Rescue Codex live saw failed spawn_agent calls: {failed_spawns!r}")

if not receiver_to_lens:
    used_transcript_fallback = True
    if not parent_thread_id:
        raise SystemExit("Fusion Rescue Codex live lacked both collab spawn events and a parent thread id")
    transcript_children = parent_linked_panel_transcripts(parent_thread_id)
    missing_transcript_lenses = sorted(set(expected_markers) - set(transcript_children))
    if missing_transcript_lenses:
        raise SystemExit(
            "Fusion Rescue Codex live parent-linked transcript fallback omitted panel lenses: "
            f"{missing_transcript_lenses!r}"
        )
    for lens, child in transcript_children.items():
        if lens == "primary" and child["input"]:
            for required in required_claude_argv + [
                "OH_NO_CLAUDE_FUSION_PANEL_OK",
                "Codex permission preflight",
                "danger-full-access confirmed",
            ]:
                if required.lower() not in child["input"].lower():
                    raise SystemExit(
                        f"Fusion Rescue Codex live primary transcript task missed {required!r}"
                    )
        elif lens == "primary" and child["encrypted_task_messages"] < 1:
            raise SystemExit(
                "Fusion Rescue Codex live primary transcript lacked encrypted task-channel evidence"
            )
        receiver = child["receiver"]
        receiver_to_lens[receiver] = lens
        receiver_transcripts[receiver] = child["text"]
        receiver_agent_roles[receiver] = child["role"]
        panel_result_by_receiver[receiver] = child["output"]
        wait_index_by_receiver[receiver] = 0
        all_spawn_receivers.append(receiver)

missing_lenses = sorted(set(expected_markers) - set(receiver_to_lens.values()))
if missing_lenses:
    raise SystemExit(
        f"Fusion Rescue Codex live did not spawn required panel lenses: {missing_lenses!r}; "
        f"got={receiver_to_lens!r}"
    )
if len(receiver_to_lens) != len(expected_markers):
    raise SystemExit(f"Fusion Rescue Codex live expected exactly three Codex panel receivers, got {receiver_to_lens!r}")
if sorted(all_spawn_receivers) != sorted(receiver_to_lens):
    raise SystemExit(
        "Fusion Rescue Codex live saw spawned receivers outside the three expected panels: "
        f"all={all_spawn_receivers!r} expected={sorted(receiver_to_lens)!r}"
    )

for receiver, lens in receiver_to_lens.items():
    if receiver in receiver_transcripts:
        transcript = receiver_transcripts[receiver]
        actual_agent_role = receiver_agent_roles[receiver]
    else:
        transcript, actual_agent_role = receiver_transcript_and_agent_role(receiver)
        receiver_transcripts[receiver] = transcript
        receiver_agent_roles[receiver] = actual_agent_role
    if actual_agent_role != "oh-no-fusion-rescue-analyst":
        raise SystemExit(
            f"Fusion Rescue Codex live spawned receiver {receiver} for {lens} with "
            f"agent_role={actual_agent_role!r}; expected oh-no-fusion-rescue-analyst"
        )
    if lens != "primary":
        for line_number, line in enumerate(transcript.splitlines(), 1):
            if not line.strip():
                continue
            row = json.loads(line)
            if not event_is_command_bearing(row):
                continue
            commands = safety_inspectable_commands(row)
            if any(
                pattern.search(command)
                for command in commands
                for pattern in claude_command_patterns
            ):
                raise SystemExit(
                    "Fusion Rescue Codex live Claude launch was owned by a non-primary panel "
                    f"{lens} near transcript line {line_number}"
                )

primary_receiver, claude_call = inspect_linked_primary_claude_call(
    receiver_to_lens, receiver_transcripts
)
provider_limited = claude_call["outcome"] == "provider-limited"
if first_leg_rc not in {0, 1}:
    raise SystemExit("Fusion Rescue Codex live outer command status was not 0 or 1")
if first_leg_rc == 1 and not provider_limited:
    raise SystemExit("Fusion Rescue Codex live outer RC1 lacked exact provider-limited inner proof")

missing_waits = sorted(set(receiver_to_lens) - set(wait_index_by_receiver))
missing_closes = sorted(set(receiver_to_lens) - set(close_index_by_receiver))
all_non_user_text = "\n".join(non_user_text_parts)
non_user_text = all_non_user_text
if missing_waits:
    raise SystemExit(f"Fusion Rescue Codex live did not capture wait_agent results: {missing_waits!r}")
if (
    missing_closes
    and not used_transcript_fallback
    and "close/cleanup was not available" not in all_non_user_text.lower()
):
    raise SystemExit(
        "Fusion Rescue Codex live left receivers without close evidence or an unavailable-cleanup record"
    )
for receiver in receiver_to_lens:
    if receiver in close_index_by_receiver and close_index_by_receiver[receiver] <= wait_index_by_receiver[receiver]:
        raise SystemExit(f"Fusion Rescue Codex live closed receiver before wait result: {receiver}")

if not provider_limited:
    for receiver, lens in receiver_to_lens.items():
        result_text = panel_result_by_receiver.get(receiver, "")
        lower_result_text = result_text.lower()
        marker = expected_markers[lens]
        if marker not in result_text:
            raise SystemExit(f"Fusion Rescue Codex live panel {lens} did not return its required marker")
        if lens not in lower_result_text:
            raise SystemExit(f"Fusion Rescue Codex live panel {lens} result did not name its lens")
        for field in required_panel_fields:
            if field not in lower_result_text:
                raise SystemExit(f"Fusion Rescue Codex live panel {lens} result missed required field {field!r}")
        assert_meaningful_domain_analysis(f"panel {lens}", result_text)

success_text = "\n".join(
    part for part in parent_result_text_parts
    if "OH_NO_CODEX_FUSION_RESCUE_LIVE_OK" in part
)
if provider_limited:
    primary_panel_results = {
        receiver: panel_result_by_receiver.get(receiver, "")
        for receiver, lens in receiver_to_lens.items()
        if lens == "primary"
    }
    leaked = fusion_provider_observed_success_markers(
        primary_panel_results, parent_result_text_parts
    )
    if leaked:
        raise SystemExit(
            "Fusion Rescue Codex live provider-limited path contained full-success evidence: "
            f"{leaked!r}"
        )
else:
    if not success_text:
        raise SystemExit("Fusion Rescue Codex live did not return success marker OH_NO_CODEX_FUSION_RESCUE_LIVE_OK")
    lower_success_text = success_text.lower()
    for marker in required_final_markers:
        if marker.lower() not in lower_success_text:
            raise SystemExit(f"Fusion Rescue Codex live missing final marker/text: {marker!r}")
    for field in required_synthesis_fields:
        if field.lower() not in lower_success_text:
            raise SystemExit(f"Fusion Rescue Codex live missing synthesis field: {field!r}")
    for marker in forbidden_fallbacks:
        if marker.lower() in lower_success_text:
            raise SystemExit(f"Fusion Rescue Codex live reported forbidden fallback marker: {marker!r}")

summary = {
    "status": "provider-limited" if provider_limited else "passed",
    "accepted_outcome": "PASS(provider-limited)" if provider_limited else "PASS",
    "message": (
        "invocation transport was proven but Claude panel inference/output was unavailable"
        if provider_limited
        else "full cross-host Claude panel output and synthesis were proven"
    ),
    "codex_panel_receivers": [
        {
            "receiver": receiver,
            "lens": receiver_to_lens[receiver],
            "agent_role": receiver_agent_roles[receiver],
            "wait_result_line": wait_index_by_receiver[receiver],
            "close_result_line": close_index_by_receiver.get(receiver, "host-managed/unavailable"),
            "returned_marker": expected_markers[receiver_to_lens[receiver]],
        }
        for receiver in sorted(receiver_to_lens, key=lambda item: receiver_to_lens[item])
    ],
    "claude_consult": {
        "codex_permission_preflight": "danger-full-access confirmed",
        "model": "opus",
        "budget": budget,
        "print_mode": True,
        "permission_mode": "dontAsk",
        "path": "Codex primary subagent -> Claude CLI",
        "primary_receiver": primary_receiver,
        "session_persistence": "disabled",
        "outcome": claude_call["outcome"],
        "call_identity": claude_call["identity"],
        "event_shape": claude_call["shape"],
        "terminal_exit_code": claude_call["exit_code"],
        "marker": None if provider_limited else "OH_NO_CLAUDE_FUSION_PANEL_OK",
        "verified_argv": {
            "executable": True,
            "print_mode": True,
            "model_opus": True,
            "budget": True,
            "permission_mode_dontAsk": True,
            "session_persistence_disabled": True,
            "tools_override_absent": True,
        },
    },
    "final_marker": None if provider_limited else "OH_NO_CODEX_FUSION_RESCUE_LIVE_OK",
}
Path(summary_path).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

if provider_limited:
    print("ok - provider-limited Claude transport classification accepted; continuing to permission fallback")
else:
    print("ok - full cross-host Fusion Rescue classification accepted; continuing to permission fallback")
PY
  } || first_oracle_rc=$?

  if (( first_oracle_rc != 0 )); then
    write_fusion_rescue_safe_rejection_summary \
      "$out_file" "$err_file" "$CODEX_HOME_DIR/sessions" "$summary_file" \
      "$first_leg_rc" passed "$first_oracle_rc" \
      || { rm -f "$out_file" "$err_file" "$first_oracle_err"; fail "Fusion Rescue safe rejection summary failed"; }
    rm -f "$out_file" "$err_file" "$first_oracle_err"
    if (( first_leg_rc != 0 )); then
      return "$first_leg_rc"
    fi
    return "$first_oracle_rc"
  fi
  rm -f "$first_oracle_err"

  log "Running live Codex Fusion Rescue permission fallback smoke test"
  local fallback_out_file="$RUN_DIR/fusion-rescue-codex-permission-fallback.jsonl"
  local fallback_err_file="$RUN_DIR/fusion-rescue-codex-permission-fallback.err"
  local fallback_summary_file="$RUN_DIR/fusion-rescue-codex-permission-fallback.summary.json"
  local fallback_workspace="$RUN_DIR/fusion-rescue-codex-permission-fallback-workspace"
  local fallback_prompt
  mkdir -p "$fallback_workspace"
  fallback_prompt=$(cat <<'PROMPT'
Use the oh-no-harness:fusion-rescue skill. Read-only live integration permission fallback smoke test only: do not edit files, do not create artifacts, do not install plugins, and do not run nested rescue. Use default Fusion Rescue behavior, not require-cross-host behavior.

This run is intentionally launched with Codex read-only sandbox permissions. Before any Claude consult or cross-host panel assignment, inspect the current Codex permission/sandbox context. Because the permission state is not danger-full-access, you must not invoke Claude, must state that Claude cannot be used because Codex permission is not danger-full-access, and must use three current-host Codex panel agents only.

Synthetic smoke-test problem all panels must analyze meaningfully: a CI pipeline has an intermittently failing integration test two days before release. The team must choose whether to quarantine the test, add automatic retries, or root-cause/fix the failure before release. Every panel result must discuss release risk, CI signal, quarantine, auto-retry, and root-cause evidence rather than only saying the smoke test is formatted correctly.

Build exactly three current-host Codex panel slots and then synthesize as the current Codex main judge.

Panel 1 primary must be a Codex current-host subagent using spawn_agent with task_name "fusion_primary_self" and agent_type "oh-no-fusion-rescue-analyst". Its message must include exactly these lines: Lens: primary; Marker: OH_NO_FUSION_PANEL_PRIMARY_SELF; fusion depth: 1; Do not invoke rescue, fusion-rescue, cross-host consult, Claude, or another host from inside this panel; Scope: this synthetic CI release-risk problem only; Do not edit files; Expected output: marker line plus assigned lens fields only. It must provide the strongest constructive diagnosis for quarantine, auto-retry, root-cause, CI signal, and release risk.

Panel 2 adversarial must be a Codex current-host subagent using spawn_agent with task_name "fusion_adversarial" and agent_type "oh-no-fusion-rescue-analyst". Its message must include exactly these lines: Lens: adversarial; Marker: OH_NO_FUSION_PANEL_ADVERSARIAL; fusion depth: 1; Do not invoke rescue, fusion-rescue, cross-host consult, Claude, or another host from inside this panel; Scope: this synthetic CI release-risk problem only; Do not edit files; Expected output: marker line plus assigned lens fields only. It must attack the assumptions behind quarantine, auto-retry, and shipping without root cause.

Panel 3 pragmatic must be a Codex current-host subagent using spawn_agent with task_name "fusion_pragmatic" and agent_type "oh-no-fusion-rescue-analyst". Its message must include exactly these lines: Lens: pragmatic; Marker: OH_NO_FUSION_PANEL_PRAGMATIC; fusion depth: 1; Do not invoke rescue, fusion-rescue, cross-host consult, Claude, or another host from inside this panel; Scope: this synthetic CI release-risk problem only; Do not edit files; Expected output: marker line plus assigned lens fields only. It must recommend the simplest reversible next step and verification path for the CI release-risk decision.

Start all three Codex subagents before waiting when possible. Wait for each receiver until completed, capture all three results, then close all three completed receivers only when the host exposes close_agent; otherwise include exactly: Close/cleanup was not available. If wait_agent returns no agents completed yet, wait longer; MUST NOT close a running or pending receiver. After all three panel subagents finish, synthesize rather than concatenate. Final answer must contain exactly the marker OH_NO_CODEX_FUSION_PERMISSION_FALLBACK_OK and must include: Codex permission preflight: not danger-full-access; Claude unavailable: Codex permission state is not danger-full-access; panels completed: primary, adversarial, pragmatic; Codex markers: OH_NO_FUSION_PANEL_PRIMARY_SELF, OH_NO_FUSION_PANEL_ADVERSARIAL, OH_NO_FUSION_PANEL_PRAGMATIC; consensus; contradictions; unique insights; blind spots; recommended next action; confidence and why; panel availability/fallback notes: Claude unavailable because Codex permission state is not danger-full-access, self-host fallback used with Codex primary, Codex adversarial, Codex pragmatic; opposite-host response path: unavailable due to Codex permission state; fusion depth: 1. Do not include OH_NO_CLAUDE_FUSION_PANEL_OK.
PROMPT
)

  local fallback_cmd=(
    "$CODEX_BIN"
    --enable plugin_hooks
    --ask-for-approval never
    exec
    --json
    --cd "$fallback_workspace"
    --sandbox read-only
    --skip-git-repo-check
  )

  if [[ -n "$LIVE_MODEL" ]]; then
    fallback_cmd+=(--model "$LIVE_MODEL")
  fi

  run_codex_live_command "$CODEX_HOME_DIR" "${fallback_cmd[@]}" "$fallback_prompt" </dev/null >"$fallback_out_file" 2>"$fallback_err_file"
  if ! assert_no_codex_live_secret_leak \
    "$CODEX_HOME_DIR/auth.json" \
    "$fallback_out_file" \
    "$fallback_err_file" \
    "$CODEX_HOME_DIR/sessions"; then
    rm -f "$fallback_out_file" "$fallback_err_file" "$fallback_summary_file"
    fail "Codex Fusion Rescue permission-fallback artifacts failed the credential-leak guard and were removed"
  fi

  codex_run_oracle_script "$fallback_out_file" "$fallback_err_file" "$CODEX_HOME_DIR" "$fallback_summary_file" <<'PY'
import json
import re
import sys
from pathlib import Path

#@SHARED_HELPERS@
out_path, err_path, live_home, summary_path = sys.argv[1:5]
expected_markers = {
    "primary": "OH_NO_FUSION_PANEL_PRIMARY_SELF",
    "adversarial": "OH_NO_FUSION_PANEL_ADVERSARIAL",
    "pragmatic": "OH_NO_FUSION_PANEL_PRAGMATIC",
}
required_final_markers = [
    "OH_NO_CODEX_FUSION_PERMISSION_FALLBACK_OK",
    "Codex permission preflight",
    "not danger-full-access",
    "Claude unavailable: Codex permission state is not danger-full-access",
    "panels completed: primary, adversarial, pragmatic",
    "panel availability/fallback notes",
    "self-host fallback",
    "opposite-host response path",
    "fusion depth: 1",
]
required_synthesis_fields = [
    "consensus",
    "contradictions",
    "unique insights",
    "blind spots",
    "recommended next action",
    "confidence and why",
]
required_panel_fields = [
    "lens name",
    "strongest finding",
    "evidence used",
    "assumption under test",
    "likely failure mode",
    "recommended next action",
    "confidence",
    "what would change",
]
domain_markers = ["ci", "integration", "quarantine", "retry", "root-cause", "release", "risk"]
secret_patterns = [
    re.compile(r"(?<![A-Za-z0-9_-])sk-[A-Za-z0-9_-]{20,512}(?![A-Za-z0-9_-])"),
    re.compile(r"(?i)(api[_-]?key|access[_-]?token|refresh[_-]?token|private[_-]?key|cookie)\s*[:=]\s*['\"]?[A-Za-z0-9_./+=-]{12,}"),
]
forbidden_write_tools = {"apply_patch", "edit", "write", "write_file", "file_change", "patch"}
forbidden_command_patterns = [
    re.compile(r"(^|[;&|'\"]\s*)(apply_patch|touch|mkdir|rm|cp|mv|tee)\b"),
    re.compile(r"(^|[;&|'\"]\s*)sed\s+-i\b"),
    re.compile(r"(^|[;&|'\"]\s*)cat\s+>"),
    re.compile(r"(^|[;&|'\"]\s*)printf\b[^|;&]*>"),
]
claude_command_patterns = [
    re.compile(r"(^|[;&|'\"]\s*)(\$\{CLAUDE_BIN:-claude\}|claude)\b"),
    re.compile(r"\bexecFile\([^)]*claude", re.IGNORECASE),
    re.compile(r"\bspawnSync\([^)]*claude", re.IGNORECASE),
    re.compile(r"\bsubprocess\.[A-Za-z_]+\([^)]*claude", re.IGNORECASE),
]
codex_command_patterns = [
    re.compile(r"(^|[;&|'\"]\s*)(codex)\b"),
    re.compile(r"\bexecFile\([^)]*codex", re.IGNORECASE),
    re.compile(r"\bspawnSync\([^)]*codex", re.IGNORECASE),
    re.compile(r"\bsubprocess\.[A-Za-z_]+\([^)]*codex", re.IGNORECASE),
]

def collect_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(item) for item in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(item) for item in value)
    return ""

def role_of_event(data):
    item = data.get("item") or {}
    message = data.get("message") or {}
    return item.get("role") or data.get("role") or message.get("role") or ""

def receiver_transcript_and_agent_role(receiver):
    sessions_root = Path(live_home) / "sessions"
    session_candidates = list(sessions_root.rglob(f"*{receiver}*.jsonl"))
    if not session_candidates:
        raise SystemExit(f"Fusion Rescue Codex permission fallback could not find session transcript for receiver: {receiver}")
    transcript_parts = []
    agent_role = None
    for path in session_candidates:
        text = path.read_text(encoding="utf-8", errors="replace")
        transcript_parts.append(text)
        for line in text.splitlines():
            if not line.strip():
                continue
            data = json.loads(line)
            if data.get("type") != "session_meta":
                continue
            payload = data.get("payload") or {}
            source = payload.get("source") if isinstance(payload.get("source"), dict) else {}
            subagent = source.get("subagent") if isinstance(source.get("subagent"), dict) else {}
            thread_spawn = (
                subagent.get("thread_spawn")
                if isinstance(subagent.get("thread_spawn"), dict)
                else {}
            )
            agent_role = payload.get("agent_role") or thread_spawn.get("agent_role")
            break
        if agent_role is not None:
            break
    if agent_role is not None:
        return "\n".join(transcript_parts), agent_role
    raise SystemExit(f"Fusion Rescue Codex permission fallback transcript lacked session_meta: {receiver}")


def parent_linked_panel_transcripts(parent_thread_id):
    children = {}
    linked_children = 0
    for path in (Path(live_home) / "sessions").rglob("*.jsonl"):
        text = path.read_text(encoding="utf-8", errors="replace")
        rows = [json.loads(line) for line in text.splitlines() if line.strip()]
        meta = next(
            (row.get("payload") or {} for row in rows if row.get("type") == "session_meta"),
            None,
        )
        if not isinstance(meta, dict):
            continue
        source = meta.get("source") if isinstance(meta.get("source"), dict) else {}
        subagent = source.get("subagent") if isinstance(source.get("subagent"), dict) else {}
        thread_spawn = (
            subagent.get("thread_spawn")
            if isinstance(subagent.get("thread_spawn"), dict)
            else {}
        )
        parent = meta.get("parent_thread_id") or thread_spawn.get("parent_thread_id")
        agent_role = meta.get("agent_role") or thread_spawn.get("agent_role")
        if parent != parent_thread_id or agent_role != "oh-no-fusion-rescue-analyst":
            continue
        linked_children += 1
        user_messages = []
        assistant_messages = []
        task_complete_messages = []
        encrypted_task_messages = 0
        completed = False
        for row in rows:
            payload = row.get("payload") or {}
            if row.get("type") == "event_msg" and payload.get("type") == "task_complete":
                completed = True
                final_message = collect_text(payload.get("last_agent_message"))
                if final_message:
                    task_complete_messages.append(final_message)
            if row.get("type") != "response_item":
                continue
            if payload.get("type") == "agent_message":
                content = payload.get("content") or []
                if any(
                    isinstance(item, dict) and item.get("type") == "encrypted_content"
                    for item in content
                ):
                    encrypted_task_messages += 1
                else:
                    user_messages.append(collect_text(content))
                continue
            if payload.get("type") != "message":
                continue
            if payload.get("role") == "user":
                user_messages.append(collect_text(payload.get("content")))
            elif payload.get("role") == "assistant":
                assistant_messages.append(collect_text(payload.get("content")))
        task_input = "\n".join(user_messages)
        task_output = (
            task_complete_messages[-1]
            if task_complete_messages
            else "\n".join(dict.fromkeys(assistant_messages))
        )
        matched_output = [
            lens for lens, marker in expected_markers.items()
            if marker in task_output
        ]
        if len(matched_output) != 1:
            raise SystemExit(
                "Fusion Rescue Codex permission fallback parent-linked child output "
                f"did not identify exactly one lens: {matched_output!r}"
            )
        lens = matched_output[0]
        matched_input = [
            candidate for candidate, marker in expected_markers.items()
            if marker in task_input
        ]
        if encrypted_task_messages < 1 and matched_input != [lens]:
            raise SystemExit(
                "Fusion Rescue Codex permission fallback plaintext task did not "
                f"match {lens} and lacked encrypted task-channel evidence: {matched_input!r}"
            )
        if lens in children:
            raise SystemExit(
                f"Fusion Rescue Codex permission fallback found duplicate parent-linked transcripts for {lens}"
            )
        if not completed:
            raise SystemExit(
                f"Fusion Rescue Codex permission fallback parent-linked {lens} child lacked task_complete"
            )
        receiver = meta.get("id") or meta.get("session_id") or path.stem
        children[lens] = {
            "receiver": receiver,
            "text": text,
            "role": agent_role,
            "input": task_input if matched_input == [lens] else "",
            "encrypted_task_messages": encrypted_task_messages,
            "output": task_output,
        }
    if linked_children != len(expected_markers):
        raise SystemExit(
            "Fusion Rescue Codex permission fallback expected exactly three parent-linked "
            f"panel sessions, found {linked_children}"
        )
    return children


def assert_meaningful_domain_analysis(label, text):
    lower_text = text.lower()
    hits = [marker for marker in domain_markers if marker in lower_text]
    if len(hits) < 4:
        raise SystemExit(
            f"Fusion Rescue Codex permission fallback {label} did not include meaningful CI release-risk analysis; "
            f"domain_hits={hits!r} text={text[:2000]!r}"
        )

def inspect_fallback_receiver_transcript(receiver, lens, transcript):
    host_command_hits = []
    for line_number, line in enumerate(transcript.splitlines(), 1):
        if not line.strip():
            continue
        data = json.loads(line)
        event_text = collect_text(data)
        if any(pattern.search(event_text) for pattern in secret_patterns):
            raise SystemExit(
                f"Fusion Rescue Codex permission fallback receiver {receiver} exposed a secret-like value near line {line_number}"
            )
        item = data.get("item") or {}
        payload = data.get("payload") or {}
        item_type_lower = str(item.get("type") or data.get("type") or "").lower()
        tool_lower = str(item.get("tool") or item.get("name") or data.get("tool") or data.get("name") or "").lower()
        command_text = str(item.get("command") or "")
        if payload.get("type") == "function_call":
            tool_lower = str(payload.get("name") or tool_lower).lower()
            arguments_text = str(payload.get("arguments") or "")
            try:
                arguments_data = json.loads(arguments_text) if arguments_text else {}
            except json.JSONDecodeError:
                arguments_data = {}
            if isinstance(arguments_data, dict) and arguments_data.get("cmd"):
                command_text = str(arguments_data.get("cmd"))
        if item_type_lower in forbidden_write_tools or tool_lower in forbidden_write_tools:
            raise SystemExit(
                f"Fusion Rescue Codex permission fallback receiver {receiver} ({lens}) saw write-capable event "
                f"at line {line_number}: type={item_type_lower!r} tool={tool_lower!r}"
            )
        # Canonical shared extraction: all observed shapes (including the current
        # custom_tool_call "exec") and every batched embedded command.
        if not event_is_command_bearing(data):
            continue
        inspectable = safety_inspectable_commands(data)
        if command_text and command_text not in inspectable:
            inspectable = inspectable + [command_text]
        if any(pattern.search(candidate) for candidate in inspectable
               for pattern in forbidden_command_patterns):
            raise SystemExit(
                f"Fusion Rescue Codex permission fallback receiver {receiver} ({lens}) saw write-like command "
                f"at line {line_number}: {command_text[:1000]!r}"
            )
        if any(pattern.search(command_text) for pattern in claude_command_patterns):
            host_command_hits.append((line_number, "claude", command_text[:1000]))
        if any(pattern.search(command_text) for pattern in codex_command_patterns):
            host_command_hits.append((line_number, "codex", command_text[:1000]))
    if host_command_hits:
        raise SystemExit(
            f"Fusion Rescue Codex permission fallback receiver {receiver} ({lens}) invoked a forbidden host command: "
            f"{host_command_hits!r}"
        )

with open(err_path, "r", encoding="utf-8") as fh:
    err_text = fh.read()
if "spawn failed" in err_text.lower() or "agent thread limit reached" in err_text.lower():
    raise SystemExit(f"Fusion Rescue Codex permission fallback saw spawn failure in stderr: {err_text[:2000]!r}")

failed_spawns = []
all_spawn_receivers = []
receiver_to_lens = {}
receiver_agent_roles = {}
receiver_transcripts = {}
panel_result_by_receiver = {}
wait_index_by_receiver = {}
close_index_by_receiver = {}
non_user_text_parts = []
claude_command_hits = []
parent_thread_id = None
used_transcript_fallback = False

with open(out_path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        if data.get("type") == "thread.started":
            parent_thread_id = data.get("thread_id") or parent_thread_id
        item = data.get("item") or {}
        payload = data.get("payload") or {}
        event_text = collect_text(data)
        if any(pattern.search(event_text) for pattern in secret_patterns):
            raise SystemExit(f"Fusion Rescue Codex permission fallback transcript exposed a secret-like value near line {index}")
        item_type_lower = str(item.get("type") or data.get("type") or "").lower()
        tool_lower = str(item.get("tool") or item.get("name") or data.get("tool") or data.get("name") or "").lower()
        command_text = str(item.get("command") or "")
        if payload.get("type") == "function_call":
            arguments_text = str(payload.get("arguments") or "")
            try:
                arguments_data = json.loads(arguments_text) if arguments_text else {}
            except json.JSONDecodeError:
                arguments_data = {}
            if isinstance(arguments_data, dict) and arguments_data.get("cmd"):
                command_text = str(arguments_data.get("cmd"))
        if item_type_lower in forbidden_write_tools or tool_lower in forbidden_write_tools:
            raise SystemExit(
                f"Fusion Rescue Codex permission fallback saw write-capable event at line {index}: "
                f"type={item_type_lower!r} tool={tool_lower!r}"
            )
        # Canonical shared extraction (see above): all shapes, all embedded commands.
        inspectable = safety_inspectable_commands(data)
        if command_text and command_text not in inspectable:
            inspectable = inspectable + [command_text]
        if event_is_command_bearing(data):
            if any(pattern.search(candidate) for candidate in inspectable
                   for pattern in forbidden_command_patterns):
                raise SystemExit(
                    f"Fusion Rescue Codex permission fallback saw write-like command at line {index}: "
                    f"{command_text[:1000]!r}"
                )
            if any(pattern.search(candidate) for candidate in inspectable
                   for pattern in claude_command_patterns):
                claude_command_hits.append((index, "; ".join(inspectable)[:1000]))
        if role_of_event(data) != "user":
            non_user_text_parts.append(event_text)
        if item.get("type") != "collab_tool_call":
            continue
        tool = item.get("tool")
        status = item.get("status")
        if tool == "spawn_agent" and status == "failed":
            failed_spawns.append((index, collect_text(item)[:2000]))
        if tool == "spawn_agent" and status == "completed":
            all_spawn_receivers.extend(item.get("receiver_thread_ids") or [])
            spawn_text = collect_text(item)
            matched = [lens for lens, marker in expected_markers.items() if marker in spawn_text]
            if len(matched) != 1:
                raise SystemExit(
                    f"Fusion Rescue Codex permission fallback spawn payload matched {matched!r}; "
                    f"text={spawn_text[:2000]!r}"
                )
            receivers = item.get("receiver_thread_ids") or []
            if len(receivers) != 1:
                raise SystemExit(
                    f"Fusion Rescue Codex permission fallback expected one receiver for {matched[0]}, got {receivers!r}"
                )
            if "OH_NO_CLAUDE_FUSION_PANEL_OK" in spawn_text:
                raise SystemExit("Fusion Rescue Codex permission fallback primary spawn prompt leaked Claude success marker")
            receiver_to_lens[receivers[0]] = matched[0]
        if status == "completed" and tool in {"wait", "wait_agent", "close_agent"}:
            text = collect_text(item)
            mentioned = set(item.get("receiver_thread_ids") or [])
            mentioned.update(receiver for receiver in receiver_to_lens if receiver in text)
            mentioned.update(
                receiver for receiver in (item.get("agents_states") or {})
                if receiver in receiver_to_lens
            )
            if tool in {"wait", "wait_agent"}:
                for receiver in mentioned:
                    state = (item.get("agents_states") or {}).get(receiver) or {}
                    if state.get("status") == "completed" and state.get("message"):
                        wait_index_by_receiver.setdefault(receiver, index)
                        panel_result_by_receiver.setdefault(receiver, str(state.get("message")))
            if tool == "close_agent":
                for receiver in mentioned:
                    close_index_by_receiver.setdefault(receiver, index)

if failed_spawns:
    raise SystemExit(f"Fusion Rescue Codex permission fallback saw failed spawn_agent calls: {failed_spawns!r}")
if claude_command_hits:
    raise SystemExit(f"Fusion Rescue Codex permission fallback invoked Claude despite read-only permission: {claude_command_hits!r}")
if not receiver_to_lens:
    used_transcript_fallback = True
    if not parent_thread_id:
        raise SystemExit(
            "Fusion Rescue Codex permission fallback lacked both collab spawn events and a parent thread id"
        )
    transcript_children = parent_linked_panel_transcripts(parent_thread_id)
    missing_transcript_lenses = sorted(set(expected_markers) - set(transcript_children))
    if missing_transcript_lenses:
        raise SystemExit(
            "Fusion Rescue Codex permission fallback parent-linked transcripts omitted panel lenses: "
            f"{missing_transcript_lenses!r}"
        )
    for lens, child in transcript_children.items():
        if "OH_NO_CLAUDE_FUSION_PANEL_OK" in child["input"] or "OH_NO_CLAUDE_FUSION_PANEL_OK" in child["output"]:
            raise SystemExit(
                "Fusion Rescue Codex permission fallback transcript leaked forbidden Claude success marker"
            )
        receiver = child["receiver"]
        receiver_to_lens[receiver] = lens
        receiver_agent_roles[receiver] = child["role"]
        receiver_transcripts[receiver] = child["text"]
        panel_result_by_receiver[receiver] = child["output"]
        wait_index_by_receiver[receiver] = 0
        all_spawn_receivers.append(receiver)
missing_lenses = sorted(set(expected_markers) - set(receiver_to_lens.values()))
if missing_lenses:
    raise SystemExit(
        f"Fusion Rescue Codex permission fallback did not spawn required panel lenses: {missing_lenses!r}; "
        f"got={receiver_to_lens!r}"
    )
if len(receiver_to_lens) != len(expected_markers):
    raise SystemExit(f"Fusion Rescue Codex permission fallback expected exactly three Codex panel receivers, got {receiver_to_lens!r}")
if sorted(all_spawn_receivers) != sorted(receiver_to_lens):
    raise SystemExit(
        "Fusion Rescue Codex permission fallback saw spawned receivers outside the three expected panels: "
        f"all={all_spawn_receivers!r} expected={sorted(receiver_to_lens)!r}"
    )

for receiver, lens in receiver_to_lens.items():
    if receiver in receiver_transcripts:
        transcript = receiver_transcripts[receiver]
        actual_agent_role = receiver_agent_roles[receiver]
    else:
        transcript, actual_agent_role = receiver_transcript_and_agent_role(receiver)
        receiver_agent_roles[receiver] = actual_agent_role
    if actual_agent_role != "oh-no-fusion-rescue-analyst":
        raise SystemExit(
            f"Fusion Rescue Codex permission fallback spawned receiver {receiver} for {lens} with "
            f"agent_role={actual_agent_role!r}; expected oh-no-fusion-rescue-analyst"
        )
    inspect_fallback_receiver_transcript(receiver, lens, transcript)

missing_waits = sorted(set(receiver_to_lens) - set(wait_index_by_receiver))
missing_closes = sorted(set(receiver_to_lens) - set(close_index_by_receiver))
all_non_user_text = "\n".join(non_user_text_parts)
if missing_waits:
    raise SystemExit(f"Fusion Rescue Codex permission fallback did not capture wait_agent results: {missing_waits!r}")
if (
    missing_closes
    and not used_transcript_fallback
    and "close/cleanup was not available" not in all_non_user_text.lower()
):
    raise SystemExit(
        "Fusion Rescue Codex permission fallback left receivers without close evidence or an unavailable-cleanup record: "
        f"{missing_closes!r}"
    )
for receiver in receiver_to_lens:
    if receiver in close_index_by_receiver and close_index_by_receiver[receiver] <= wait_index_by_receiver[receiver]:
        raise SystemExit(f"Fusion Rescue Codex permission fallback closed receiver before wait result: {receiver}")

for receiver, lens in receiver_to_lens.items():
    result_text = panel_result_by_receiver.get(receiver, "")
    lower_result_text = result_text.lower()
    marker = expected_markers[lens]
    if marker not in result_text:
        raise SystemExit(
            f"Fusion Rescue Codex permission fallback panel {lens} did not return marker {marker!r}; "
            f"result={result_text[:2000]!r}"
        )
    if "OH_NO_CLAUDE_FUSION_PANEL_OK" in result_text:
        raise SystemExit("Fusion Rescue Codex permission fallback panel returned forbidden Claude marker")
    if lens not in lower_result_text:
        raise SystemExit(
            f"Fusion Rescue Codex permission fallback panel {lens} wait result did not name its lens; "
            f"result={result_text[:2000]!r}"
        )
    for field in required_panel_fields:
        if field not in lower_result_text:
            raise SystemExit(
                f"Fusion Rescue Codex permission fallback panel {lens} wait result missed field {field!r}; "
                f"result={result_text[:2000]!r}"
            )
    assert_meaningful_domain_analysis(f"panel {lens}", result_text)

non_user_text = "\n".join(non_user_text_parts)
if "OH_NO_CLAUDE_FUSION_PANEL_OK" in non_user_text:
    raise SystemExit("Fusion Rescue Codex permission fallback included forbidden Claude success marker")
success_text = "\n".join(
    part for part in non_user_text_parts
    if "OH_NO_CODEX_FUSION_PERMISSION_FALLBACK_OK" in part
)
if not success_text:
    raise SystemExit("Fusion Rescue Codex permission fallback did not return success marker")
lower_success_text = success_text.lower()
for marker in required_final_markers:
    if marker.lower() not in lower_success_text:
        raise SystemExit(f"Fusion Rescue Codex permission fallback missing final marker/text: {marker!r}")
for field in required_synthesis_fields:
    if field.lower() not in lower_success_text:
        raise SystemExit(f"Fusion Rescue Codex permission fallback missing synthesis field: {field!r}")
for marker in expected_markers.values():
    if marker.lower() not in lower_success_text:
        raise SystemExit(f"Fusion Rescue Codex permission fallback missing final panel marker: {marker!r}")

summary = {
    "status": "passed",
    "codex_permission_preflight": "not danger-full-access",
    "claude_consult": {
        "status": "skipped",
        "reason": "Codex permission state is not danger-full-access",
    },
    "codex_panel_receivers": [
        {
            "receiver": receiver,
            "lens": receiver_to_lens[receiver],
            "agent_role": receiver_agent_roles[receiver],
            "wait_result_line": wait_index_by_receiver[receiver],
            "close_result_line": close_index_by_receiver.get(receiver, "host-managed/unavailable"),
            "returned_marker": expected_markers[receiver_to_lens[receiver]],
        }
        for receiver in sorted(receiver_to_lens, key=lambda item: receiver_to_lens[item])
    ],
    "final_marker": "OH_NO_CODEX_FUSION_PERMISSION_FALLBACK_OK",
}
Path(summary_path).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print("ok - live Codex Fusion Rescue skipped Claude without danger-full-access and used self-host panels")
PY

  "$PYTHON_BIN" - "$summary_file" "$fallback_summary_file" <<'PY'
import json
import sys
from pathlib import Path
primary = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
fallback = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
if fallback.get("status") != "passed":
    raise SystemExit("Fusion Rescue permission-fallback continuation did not pass")
outcome = primary.get("accepted_outcome")
if outcome == "PASS(provider-limited)":
    print("PASS(provider-limited) - invocation transport was proven but Claude panel inference/output was unavailable; permission fallback also passed")
elif outcome == "PASS":
    print("PASS - full cross-host Fusion Rescue and permission fallback both passed")
else:
    raise SystemExit(f"Fusion Rescue primary summary had unknown outcome: {outcome!r}")
PY
}

run_codex_cross_host_fallback_live_test() {
  if [[ "$RUN_CROSS_HOST_FALLBACK_LIVE" != "1" ]]; then
    log "Skipping live Codex cross-host Same-Host Parallel Fallback smoke test"
    printf 'Run with --cross-host-fallback-live or OH_NO_CODEX_CROSS_HOST_FALLBACK_LIVE=1 to verify the default-mode opposite-host-unavailable two-same-host-agent fallback on Codex.\n' >&2
    return
  fi

  log "Running live Codex cross-host Same-Host Parallel Fallback smoke test"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/cross-host-fallback-codex.jsonl"
  local err_file="$RUN_DIR/cross-host-fallback-codex.err"
  local summary_file="$RUN_DIR/cross-host-fallback-codex.summary.json"
  local live_workspace="$RUN_DIR/cross-host-fallback-codex-workspace"
  local prompt target_revision target_fingerprint
  rm -rf "$live_workspace"
  mkdir -p "$live_workspace"
  git -C "$live_workspace" init -q --object-format=sha1
  cat >"$live_workspace/auth.py" <<'AUTH_FIXTURE'
def is_admin(user):
    return bool(user.get("is_admin", False))
AUTH_FIXTURE
  git -C "$live_workspace" add auth.py
  GIT_AUTHOR_NAME='Oh No Fixture' GIT_AUTHOR_EMAIL='fixture@example.invalid' \
  GIT_COMMITTER_NAME='Oh No Fixture' GIT_COMMITTER_EMAIL='fixture@example.invalid' \
  GIT_AUTHOR_DATE='2000-01-01T00:00:00Z' GIT_COMMITTER_DATE='2000-01-01T00:00:00Z' \
    git -C "$live_workspace" -c commit.gpgsign=false commit -qm baseline
  target_revision="$(git -C "$live_workspace" rev-parse HEAD)"
  cat >"$live_workspace/auth.py" <<'AUTH_FIXTURE'
def is_admin(user):
    return bool(user.get("is_admin", False) or user.get("debug", False))
AUTH_FIXTURE
  target_fingerprint="$target_revision:$(git -C "$live_workspace" diff --binary HEAD -- auth.py | shasum -a 256 | awk '{print $1}')"
  prompt=$(cat <<PROMPT
Use the oh-no-harness:verification-before-completion skill for a synthetic final review. Read-only live cross-host fallback smoke test only: do not edit files, do not create artifacts, do not install plugins, and do not run nested rescue. This run is in DEFAULT mode (NOT require-cross-host).

Named THOROUGH trigger: security-sensitive public authentication contract review. Pairing is trigger-driven, not availability-driven.

This run is intentionally launched with Codex read-only sandbox permissions. Before any cross-host review or opposite-host consult, inspect the current Codex permission/sandbox context. Because the permission state is not danger-full-access, the Claude Code cross-host consult is UNAVAILABLE and UNAUTHORIZED: you must NOT invoke ${CLAUDE_BIN:-claude}, must NOT shell out to claude, must NOT make any cross-host or opposite-host hop, and must NOT invoke /codex:rescue, codex:codex-rescue, rescue, fusion-rescue, or another host. Treat the opposite host (Claude Code) as unavailable and take the default-mode Same-Host Parallel Fallback (two same-host Codex agents synthesized), NOT the cross-host path.

The disposable Git fixture at ${live_workspace} has baseline revision ${target_revision} and exact target fingerprint ${target_fingerprint}. Its working-tree diff adds or user.get("debug", False) to auth.py. Acceptance criterion AC-AUTH-1: only is_admin=true may grant admin; debug mode must never grant admin. Each reviewer must inspect that exact file and Git diff, bind its Reviewed revision/diff fingerprint to ${target_fingerprint}, and report the debug-admin bypass as a blocking finding; blocked due an absent target is not substantive review success. Dispatch EXACTLY TWO same-host Codex code-reviewer agents in parallel, each running the COMPLETE code-reviewer role. Use task_name "cross_host_lens_a" and agent_type "oh-no-code-reviewer" for Lens A; use task_name "cross_host_lens_b" and agent_type "oh-no-code-reviewer" for Lens B. The task names and receiver metadata are outside the child packet body. Send the following complete bodies exactly:

CHILD_PACKET_BEGIN
Assigned perspective: adversarial correctness + security skeptic
Common result marker: OH_NO_XHOST_FALLBACK_REVIEW_RESULT
Packet ID: xhost-fallback-review
Run/session ID: xhost-fallback-live
Story/task ID: synthetic-auth-review
Target role: code-reviewer
Target revision/diff fingerprint: ${target_fingerprint}
Scope: inspect ${live_workspace}/auth.py and the exact baseline-to-working-tree diff only
Observation command: issue a read-only command naming the exact absolute ${live_workspace}/auth.py path, or `git -C ${live_workspace} diff HEAD -- auth.py`, and retain its successful nonempty result
Permissions: read-only same-host review
Non-goals: edits, artifacts, opposite-host calls, nested rescue
Review basis: security-sensitive public authentication contract; debug bypass must not grant admin
Expected evidence/output: complete code-reviewer role output followed by the exact caller-owned annex
Stop/escalation boundary: return findings to the parent; do not mutate or dispatch another host
Do not edit files
Do not invoke rescue, fusion-rescue, cross-host consult, Claude, or another host from inside this agent
Run the complete code-reviewer role, then append a caller-owned annex with exactly one nonempty standalone line for each label below. Do not rename, merge, or omit any label.
Strongest finding:
Evidence used:
Likely failure mode:
Recommended next action:
CHILD_PACKET_END

CHILD_PACKET_BEGIN
Assigned perspective: maintainability + coverage completeness
Common result marker: OH_NO_XHOST_FALLBACK_REVIEW_RESULT
Packet ID: xhost-fallback-review
Run/session ID: xhost-fallback-live
Story/task ID: synthetic-auth-review
Target role: code-reviewer
Target revision/diff fingerprint: ${target_fingerprint}
Scope: inspect ${live_workspace}/auth.py and the exact baseline-to-working-tree diff only
Observation command: issue a read-only command naming the exact absolute ${live_workspace}/auth.py path, or `git -C ${live_workspace} diff HEAD -- auth.py`, and retain its successful nonempty result
Permissions: read-only same-host review
Non-goals: edits, artifacts, opposite-host calls, nested rescue
Review basis: security-sensitive public authentication contract; debug bypass must not grant admin
Expected evidence/output: complete code-reviewer role output followed by the exact caller-owned annex
Stop/escalation boundary: return findings to the parent; do not mutate or dispatch another host
Do not edit files
Do not invoke rescue, fusion-rescue, cross-host consult, Claude, or another host from inside this agent
Run the complete code-reviewer role, then append a caller-owned annex with exactly one nonempty standalone line for each label below. Do not rename, merge, or omit any label.
Strongest finding:
Evidence used:
Likely failure mode:
Recommended next action:
CHILD_PACKET_END

Start both Codex subagents before waiting. Wait for each receiver until completed, capture both results, then close both completed receivers only when the host exposes close_agent; otherwise include exactly: Close/cleanup was not available. If wait_agent returns no agents completed yet, wait longer; MUST NOT close a running or pending receiver. Map each result by its receiver and Assigned perspective metadata, not by different marker text. After both same-host agents finish, synthesize immediately as the current Codex main judge rather than concatenate. Final answer must contain exactly the marker OH_NO_XHOST_FALLBACK_OK and must include: Codex permission preflight: not danger-full-access; Claude unavailable: Codex permission state is not danger-full-access; same-host agents: 2; common child result marker: OH_NO_XHOST_FALLBACK_REVIEW_RESULT; a single synthesis block marked OH_NO_XHOST_FALLBACK_SYNTHESIS with consensus, contradictions, and recommended next action; and a fallback note stating the opposite host (Claude Code) was treated as unavailable and the review ran via the Same-Host Parallel Fallback of two same-host agents rather than as a single current-host pass or a cross-host consult. Do NOT emit OH_NO_CLAUDE_FUSION_PANEL_OK or any Claude/opposite-host success marker and do NOT claim a cross-host consult occurred.
PROMPT
)

  local cmd=(
    "$CODEX_BIN"
    --enable plugin_hooks
    --ask-for-approval never
    exec
    --json
    --cd "$live_workspace"
    --sandbox read-only
    --skip-git-repo-check
  )

  if [[ -n "$LIVE_MODEL" ]]; then
    cmd+=(--model "$LIVE_MODEL")
  fi

  run_codex_live_command "$CODEX_HOME_DIR" "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"
  if ! assert_no_codex_live_secret_leak \
    "$CODEX_HOME_DIR/auth.json" \
    "$out_file" \
    "$err_file" \
    "$CODEX_HOME_DIR/sessions"; then
    rm -f "$out_file" "$err_file" "$summary_file"
    fail "Codex cross-host fallback artifacts failed the credential-leak guard and were removed"
  fi

  codex_run_oracle_script "$out_file" "$err_file" "$CODEX_HOME_DIR" "$summary_file" "$live_workspace" "$target_fingerprint" <<'PY'
import json
import re
import sys
from pathlib import Path

#@SHARED_HELPERS@
out_path, err_path, live_home, summary_path, live_workspace, target_fingerprint = sys.argv[1:7]
expected_perspectives = {
    "A": "adversarial correctness + security skeptic",
    "B": "maintainability + coverage completeness",
}
common_result_marker = "OH_NO_XHOST_FALLBACK_REVIEW_RESULT"
required_final_markers = [
    "OH_NO_XHOST_FALLBACK_OK",
    "OH_NO_XHOST_FALLBACK_REVIEW_RESULT",
    "OH_NO_XHOST_FALLBACK_SYNTHESIS",
    "Codex permission preflight",
    "not danger-full-access",
    "same-host agents: 2",
]
required_synthesis_fields = [
    "consensus",
    "contradictions",
    "recommended next action",
]
# Markers that would prove the cross-host path (NOT the fallback) was taken.
# Their presence anywhere in non-user transcript text fails the lane: the whole
# point is that the default-mode fallback, not the opposite-host hop, ran.
forbidden_crosshost_markers = [
    "OH_NO_CLAUDE_FUSION_PANEL_OK",
    "OH_NO_CLAUDE_FUSION_RESCUE_CODEX_OK",
    "OH_NO_CODEX_RESCUE_RETURN_OK",
]
secret_patterns = [
    re.compile(r"(?<![A-Za-z0-9_-])sk-[A-Za-z0-9_-]{20,512}(?![A-Za-z0-9_-])"),
    re.compile(r"(?i)(api[_-]?key|access[_-]?token|refresh[_-]?token|private[_-]?key|cookie)\s*[:=]\s*['\"]?[A-Za-z0-9_./+=-]{12,}"),
]
forbidden_write_tools = {"apply_patch", "edit", "write", "write_file", "file_change", "patch"}
forbidden_command_patterns = [
    re.compile(r"(^|[;&|'\"]\s*)(apply_patch|touch|mkdir|rm|cp|mv|tee)\b"),
    re.compile(r"(^|[;&|'\"]\s*)sed\s+-i\b"),
    re.compile(r"(^|[;&|'\"]\s*)cat\s+>"),
    re.compile(r"(^|[;&|'\"]\s*)printf\b[^|;&]*>"),
]
# Any of these in an exec command proves a cross-host hop to Claude (the wrong
# surface): the fallback must stay same-host and never shell out to claude.
# The unexpanded `${CLAUDE_BIN:-claude}` token ends in `}` (a non-word char), so
# it must NOT carry a trailing \b; only the bare `claude` word form does.
claude_command_patterns = [
    re.compile(r"(^|[;&|'\"]\s*)\$\{CLAUDE_BIN:-claude\}"),
    re.compile(r"(^|[;&|'\"]\s*)claude\b"),
    re.compile(r"\bexecFile\([^)]*claude", re.IGNORECASE),
    re.compile(r"\bspawnSync\([^)]*claude", re.IGNORECASE),
    re.compile(r"\bsubprocess\.[A-Za-z_]+\([^)]*claude", re.IGNORECASE),
]

def collect_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(item) for item in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(item) for item in value)
    return ""


def physical_line_field_values(text, label):
    return re.findall(
        rf"(?m)^[ \t]*{re.escape(label)}:[ \t]*(.*)$",
        text,
    )


def missing_complete_code_reviewer_output(text):
    issues = []
    correctness_match = re.search(
        r"(?mi)^[ \t]*-?[ \t]*Correctness and maintainability findings:[ \t]*$",
        text,
    )
    security_match = re.search(
        r"(?mi)^[ \t]*-?[ \t]*Security findings:[ \t]*$",
        text,
    )
    if not correctness_match or not security_match or security_match.start() <= correctness_match.start():
        issues.append("ordered correctness and security lens sections")
        return issues
    envelope = text[:correctness_match.start()]
    required_envelope = (
        "Packet ID",
        "Run/session ID",
        "Story/task ID",
        "Role",
        "Reviewed revision/diff fingerprint",
        "Overall verdict",
        "Blocking finding IDs",
    )
    envelope_values = {}
    for field in required_envelope:
        values = physical_line_field_values(envelope, field)
        if len(values) != 1 or not values[0].strip():
            issues.append(field)
        else:
            envelope_values[field] = values[0].strip()
    if envelope_values.get("Role") != "code-reviewer":
        issues.append("Role: code-reviewer")
    verdict = envelope_values.get("Overall verdict")
    if verdict not in {"approve", "blocking-findings", "blocked"}:
        issues.append("Overall verdict enum")
    blocking_ids = envelope_values.get("Blocking finding IDs", "")
    if verdict == "blocking-findings" and blocking_ids.lower() == "none":
        issues.append("blocking verdict requires finding IDs")
    if verdict in {"approve", "blocked"} and blocking_ids.lower() != "none":
        issues.append("non-blocking verdict requires Blocking finding IDs: none")

    correctness = text[correctness_match.end():security_match.start()]
    security = text[security_match.end():]
    required_lens_fields = {
        "correctness": (
            "Practical maintainability gate result",
            "Contract and baseline regression check",
            "Direction Contract and AC-ID mapping",
        ),
        "security": (
            "Security verdict",
            "Safety trigger checklist result",
            "Residual risk",
        ),
    }
    for lens, section in (("correctness", correctness), ("security", security)):
        for field in required_lens_fields[lens]:
            values = physical_line_field_values(section, field)
            if len(values) != 1 or not values[0].strip():
                issues.append(field)
        substantive_lines = []
        for line in section.splitlines():
            stripped = line.strip().lstrip("-*+ ").strip()
            if not stripped or re.match(r"^[A-Za-z][A-Za-z /-]*:[ \t]*", stripped):
                continue
            if stripped.lower() in {"fixture", "placeholder", "present", "tbd", "todo"}:
                continue
            substantive_lines.append(stripped)
        explicit_none = bool(
            re.search(
                r"(?mi)^[ \t]*(?:[-*+]\s*)?(?:none|no (?:blocking )?(?:correctness |security )?findings(?: remain)?(?:\b.*)?)$",
                section,
            )
        )
        if not substantive_lines and not explicit_none:
            issues.append(f"substantive {lens} lens findings")
    return issues


def annex_presentation_outcome(text):
    fields = (
        "Strongest finding",
        "Evidence used",
        "Likely failure mode",
        "Recommended next action",
    )
    hard = []
    warnings = []
    for field in fields:
        values = physical_line_field_values(text, field)
        if not values:
            if field == "Likely failure mode":
                warnings.append("missing exact standalone Likely failure mode field")
            else:
                hard.append(field)
            continue
        if len(values) != 1 or not values[0].strip():
            hard.append(field)
    return hard, warnings


def perspectives_in_text(text):
    values = re.findall(r"(?m)^Assigned perspective:\s*(.*?)\s*$", text)
    return [
        lens for lens, perspective in expected_perspectives.items()
        if values.count(perspective) == 1
    ]


def role_of_event(data):
    item = data.get("item") or {}
    message = data.get("message") or {}
    return item.get("role") or data.get("role") or message.get("role") or ""


def metadata_layers(meta):
    source = meta.get("source") if isinstance(meta.get("source"), dict) else {}
    subagent = source.get("subagent") if isinstance(source.get("subagent"), dict) else {}
    thread_spawn = subagent.get("thread_spawn") if isinstance(subagent.get("thread_spawn"), dict) else {}
    return meta, thread_spawn


def resolved_metadata_value(meta, key, required=False):
    values = [layer.get(key) for layer in metadata_layers(meta) if key in layer]
    distinct = []
    for value in values:
        if value not in distinct:
            distinct.append(value)
    if len(distinct) > 1:
        raise SystemExit(f"Codex cross-host fallback found conflicting {key} metadata: {distinct!r}")
    if required and (not distinct or distinct[0] in (None, "")):
        raise SystemExit(f"Codex cross-host fallback lacked required {key} metadata")
    return distinct[0] if distinct else None


def resolved_session_metadata(path, rows):
    metas = [row.get("payload") or {} for row in rows if row.get("type") == "session_meta"]
    if len(metas) != 1 or not isinstance(metas[0], dict):
        raise SystemExit(f"Codex cross-host fallback expected exactly one session_meta in {path}")
    meta = metas[0]
    identities = []
    for key in ("id", "session_id"):
        value = meta.get(key) if key in meta else None
        if value not in (None, "") and value not in identities:
            identities.append(value)
    if len(identities) > 1:
        raise SystemExit(
            f"Codex cross-host fallback expected one consistent receiver identity in {path}: {identities!r}"
        )
    if not identities:
        raise SystemExit(f"Codex cross-host fallback lacked receiver identity in {path}")
    thread_spawn = metadata_layers(meta)[1]
    spawn_parent = thread_spawn.get("id")
    if spawn_parent not in (None, ""):
        parent = resolved_metadata_value(meta, "parent_thread_id", required=True)
        if spawn_parent != parent:
            raise SystemExit(
                f"Codex cross-host fallback found conflicting spawn-parent identity in {path}: "
                f"thread_spawn.id={spawn_parent!r}, parent_thread_id={parent!r}"
            )
    return meta, identities[0]


def resolve_receiver_session(receiver):
    matches = []
    for path in (Path(live_home) / "sessions").rglob("*.jsonl"):
        rows = [
            json.loads(line)
            for line in path.read_text(encoding="utf-8", errors="replace").splitlines()
            if line.strip()
        ]
        if not any(row.get("type") == "session_meta" for row in rows):
            continue
        meta, identity = resolved_session_metadata(path, rows)
        if identity == receiver:
            matches.append((path, rows, meta))
    if len(matches) != 1:
        raise SystemExit(
            f"Codex cross-host fallback expected exactly one session for receiver {receiver!r}, found {len(matches)}"
        )
    return matches[0]


def receiver_transcript_and_agent_role(receiver):
    path, rows, meta = resolve_receiver_session(receiver)
    parent = resolved_metadata_value(meta, "parent_thread_id", required=True)
    if parent != parent_thread_id:
        raise SystemExit(
            f"Codex cross-host fallback receiver {receiver} had foreign parent {parent!r}"
        )
    agent_role = resolved_metadata_value(meta, "agent_role", required=True)
    return path.read_text(encoding="utf-8", errors="replace"), agent_role


def parent_linked_lens_transcripts(parent_thread_id):
    children = {}
    linked_children = 0
    for path in (Path(live_home) / "sessions").rglob("*.jsonl"):
        text = path.read_text(encoding="utf-8", errors="replace")
        rows = [json.loads(line) for line in text.splitlines() if line.strip()]
        if not any(row.get("type") == "session_meta" for row in rows):
            continue
        meta, receiver = resolved_session_metadata(path, rows)
        parent = resolved_metadata_value(meta, "parent_thread_id")
        agent_role = resolved_metadata_value(meta, "agent_role")
        if parent != parent_thread_id:
            continue
        if agent_role != "oh-no-code-reviewer":
            raise SystemExit(
                f"Codex cross-host fallback parent-linked receiver {receiver} had role {agent_role!r}"
            )
        linked_children += 1
        user_messages = []
        assistant_messages = []
        task_complete_messages = []
        encrypted_task_messages = 0
        completed = False
        for row in rows:
            payload = row.get("payload") or {}
            if row.get("type") == "event_msg" and payload.get("type") == "task_complete":
                completed = True
                final_message = collect_text(payload.get("last_agent_message"))
                if final_message:
                    task_complete_messages.append(final_message)
            if row.get("type") != "response_item":
                continue
            if payload.get("type") == "agent_message":
                content = payload.get("content") or []
                if any(
                    isinstance(item, dict) and item.get("type") == "encrypted_content"
                    for item in content
                ):
                    encrypted_task_messages += 1
                else:
                    user_messages.append(collect_text(content))
                continue
            if payload.get("type") != "message":
                continue
            if payload.get("role") == "user":
                user_messages.append(collect_text(payload.get("content")))
            elif payload.get("role") == "assistant":
                assistant_messages.append(collect_text(payload.get("content")))
        task_input = "\n".join(user_messages)
        task_output = (
            task_complete_messages[-1]
            if task_complete_messages
            else "\n".join(dict.fromkeys(assistant_messages))
        )
        if len(re.findall(rf"(?m)^\s*{re.escape(common_result_marker)}\s*$", task_output)) != 1:
            raise SystemExit(
                "Codex cross-host fallback parent-linked child output lacked one common result marker"
            )
        matched_input = perspectives_in_text(task_input)
        lens = matched_input[0] if len(matched_input) == 1 else ""
        if len(matched_input) != 1:
            agent_path = str(resolved_metadata_value(meta, "agent_path", required=True) or "")
            node = agent_path.rstrip("/").rsplit("/", 1)[-1]
            metadata_matches = [
                candidate for candidate in expected_perspectives
                if node == f"cross_host_lens_{candidate.lower()}"
            ]
            if encrypted_task_messages < 1 or len(metadata_matches) != 1:
                raise SystemExit(
                    "Codex cross-host fallback child lacked one receiver-bound Assigned perspective"
                )
            lens = metadata_matches[0]
        if lens in children:
            raise SystemExit(f"Codex cross-host fallback found duplicate parent-linked transcripts for lens {lens}")
        if not completed:
            raise SystemExit(f"Codex cross-host fallback parent-linked lens {lens} child lacked task_complete")
        expected_node = f"cross_host_lens_{lens.lower()}"
        agent_path = str(resolved_metadata_value(meta, "agent_path", required=True) or "")
        if agent_path.rstrip("/").rsplit("/", 1)[-1] != expected_node:
            raise SystemExit(
                f"Codex cross-host fallback receiver {receiver} had wrong agent_path {agent_path!r}"
            )
        children[lens] = {
            "receiver": receiver,
            "text": text,
            "role": agent_role,
            "input": task_input if matched_input == [lens] else "",
            "encrypted_task_messages": encrypted_task_messages,
            "output": task_output,
        }
    if linked_children != len(expected_perspectives):
        raise SystemExit(
            "Codex cross-host fallback expected exactly two parent-linked lens sessions, "
            f"found {linked_children}"
        )
    return children


def persisted_parent_lifecycle(parent_id, receivers):
    _path, rows, _meta = resolve_receiver_session(parent_id)
    calls = {}
    receipt_indexes = {}
    close_indexes = {}
    cleanup_unavailable = False
    for index, row in enumerate(rows, 1):
        payload = row.get("payload") or {}
        payload_type = payload.get("type")
        if payload_type in {"custom_tool_call", "function_call"}:
            name = str(payload.get("name") or "")
            call_id = payload.get("call_id")
            raw_input = payload.get("input") if "input" in payload else payload.get("arguments")
            calls[call_id] = (index, name, collect_text(raw_input))
            continue
        if payload_type not in {"custom_tool_call_output", "function_call_output"}:
            continue
        call_id = payload.get("call_id")
        if call_id not in calls:
            continue
        call_index, name, call_input = calls[call_id]
        output = collect_text(payload.get("output"))
        mentioned = {receiver for receiver in receivers if receiver in call_input or receiver in output}
        if name in {"wait", "wait_agent"}:
            for receiver in mentioned:
                if re.search(rf"(?is){re.escape(receiver)}.*completed", output) and output.strip():
                    receipt_indexes.setdefault(receiver, index)
        elif name == "close_agent":
            if re.search(r"(?i)unavailable|unsupported|unknown tool|not exposed", output):
                cleanup_unavailable = True
            for receiver in mentioned:
                if receiver in receipt_indexes and call_index > receipt_indexes[receiver]:
                    close_indexes.setdefault(receiver, index)
    missing_receipts = sorted(set(receivers) - set(receipt_indexes))
    missing_closes = sorted(set(receivers) - set(close_indexes))
    if missing_receipts:
        raise SystemExit(
            f"Codex cross-host fallback transcript lacked correlated parent receipt evidence: {missing_receipts!r}"
        )
    if missing_closes and not cleanup_unavailable:
        raise SystemExit(
            "Codex cross-host fallback transcript lacked close-after-receipt evidence or authoritative "
            f"cleanup-unavailable output: {missing_closes!r}"
        )
    return receipt_indexes, close_indexes


def inspect_fallback_receiver_transcript(receiver, lens, transcript):
    host_command_hits = []
    target_read_result_evidence = []
    target_read_observations = []
    command_calls = []
    command_outputs = {}
    workspace_path = Path(live_workspace)
    exact_workspaces = {str(workspace_path), str(workspace_path.resolve())}
    exact_auth_paths = {str(workspace_path / "auth.py"), str(workspace_path.resolve() / "auth.py")}
    for line_number, line in enumerate(transcript.splitlines(), 1):
        if not line.strip():
            continue
        data = json.loads(line)
        event_text = collect_text(data)
        if any(pattern.search(event_text) for pattern in secret_patterns):
            raise SystemExit(
                f"Codex cross-host fallback live receiver {receiver} exposed a secret-like value near line {line_number}"
            )
        item = data.get("item") or {}
        payload = data.get("payload") or {}
        item_type_lower = str(item.get("type") or data.get("type") or "").lower()
        tool_lower = str(item.get("tool") or item.get("name") or data.get("tool") or data.get("name") or "").lower()
        command_text = str(item.get("command") or "")
        if payload.get("type") == "function_call":
            tool_lower = str(payload.get("name") or tool_lower).lower()
            arguments_text = str(payload.get("arguments") or "")
            try:
                arguments_data = json.loads(arguments_text) if arguments_text else {}
            except json.JSONDecodeError:
                arguments_data = {}
            if isinstance(arguments_data, dict) and arguments_data.get("cmd"):
                command_text = str(arguments_data.get("cmd"))
        if item_type_lower in forbidden_write_tools or tool_lower in forbidden_write_tools:
            raise SystemExit(
                f"Codex cross-host fallback live receiver {receiver} ({lens}) saw write-capable event "
                f"at line {line_number}: type={item_type_lower!r} tool={tool_lower!r}"
            )
        payload_type = payload.get("type")
        if payload_type in {"custom_tool_call_output", "function_call_output"} and payload.get("call_id"):
            command_outputs[str(payload.get("call_id"))] = (
                payload.get("output") or payload.get("content") or payload.get("result") or "",
                str(payload.get("status") or ""),
            )
        if item.get("type") == "command_execution" and (item.get("id") or item.get("call_id")):
            command_outputs[str(item.get("id") or item.get("call_id"))] = (
                {
                    "exit_code": item.get("exit_code", item.get("return_code")),
                    "status": item.get("status"),
                    "aggregated_output": item.get("aggregated_output") or item.get("output") or "",
                },
                str(item.get("status") or ""),
            )
        # Canonical shared extraction: all observed shapes (including the current
        # custom_tool_call "exec") and every batched embedded command.
        if not event_is_command_bearing(data):
            continue
        inspectable = safety_inspectable_commands(data)
        if command_text and command_text not in inspectable:
            inspectable = inspectable + [command_text]
        call_id = str(
            item.get("id") or item.get("call_id") or payload.get("call_id") or payload.get("id") or ""
        )
        for candidate, owns_output in command_records_from_event(data):
            command_calls.append((line_number, call_id, candidate, owns_output, str(payload.get("status") or item.get("status") or "")))
        if any(pattern.search(candidate) for candidate in inspectable
               for pattern in forbidden_command_patterns):
            raise SystemExit(
                f"Codex cross-host fallback live receiver {receiver} ({lens}) saw write-like command "
                f"at line {line_number}: {command_text[:1000]!r}"
            )
        if any(pattern.search(candidate) for candidate in inspectable
               for pattern in claude_command_patterns):
            host_command_hits.append((line_number, "claude", "; ".join(inspectable)[:1000]))
    if host_command_hits:
        raise SystemExit(
            f"Codex cross-host fallback live receiver {receiver} ({lens}) invoked a forbidden Claude/opposite-host command: "
            f"{host_command_hits!r}"
        )
    read_tool_pattern = re.compile(r"(?:^|[;&|]\s*|\s)(?:cat|sed|head|tail|nl|git(?:\s+-C\s+\S+)?\s+(?:diff|show))(?:\s|$)")
    for line_number, call_id, candidate, owns_output, call_status in command_calls:
        exact_target = any(path in candidate for path in exact_auth_paths)
        exact_git_diff = (
            any(path in candidate for path in exact_workspaces)
            and re.search(r"(?:^|\s)git\s+-C\s+[^;&|]+\s+(?:diff|show)\b[^;&|]*--\s+auth[.]py(?:\s|$)", candidate)
        )
        if not (read_tool_pattern.search(candidate) and (exact_target or exact_git_diff)):
            continue
        if not call_id or not owns_output or call_id not in command_outputs:
            continue
        raw_output, output_status = command_outputs[call_id]
        status, retained = retained_output_result(raw_output, output_status or call_status)
        target_read_observations.append((line_number, call_id, exact_target, bool(exact_git_diff), status, bool(retained.strip())))
        if status == 0 and retained.strip():
            target_read_result_evidence.append((line_number, call_id, candidate))
    if not target_read_result_evidence:
        raise SystemExit(
            f"Codex cross-host fallback live receiver {receiver} ({lens}) did not inspect the exact auth.py target through a successful correlated command result; calls={command_calls!r} outputs={sorted(command_outputs)!r} observations={target_read_observations!r}"
        )

with open(err_path, "r", encoding="utf-8") as fh:
    err_text = fh.read()
if "spawn failed" in err_text.lower() or "agent thread limit reached" in err_text.lower():
    raise SystemExit(f"Codex cross-host fallback live saw spawn failure in stderr: {err_text[:2000]!r}")

failed_spawns = []
all_spawn_receivers = []
receiver_to_lens = {}
packet_by_receiver = {}
receiver_agent_roles = {}
receiver_transcripts = {}
agent_result_by_receiver = {}
wait_index_by_receiver = {}
close_index_by_receiver = {}
non_user_text_parts = []
claude_command_hits = []
parent_thread_id = None
used_transcript_fallback = False
presentation_warnings = []

with open(out_path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        if data.get("type") == "thread.started":
            parent_thread_id = data.get("thread_id") or parent_thread_id
        item = data.get("item") or {}
        payload = data.get("payload") or {}
        event_text = collect_text(data)
        if any(pattern.search(event_text) for pattern in secret_patterns):
            raise SystemExit(f"Codex cross-host fallback live transcript exposed a secret-like value near line {index}")
        item_type_lower = str(item.get("type") or data.get("type") or "").lower()
        tool_lower = str(item.get("tool") or item.get("name") or data.get("tool") or data.get("name") or "").lower()
        command_text = str(item.get("command") or "")
        if payload.get("type") == "function_call":
            arguments_text = str(payload.get("arguments") or "")
            try:
                arguments_data = json.loads(arguments_text) if arguments_text else {}
            except json.JSONDecodeError:
                arguments_data = {}
            if isinstance(arguments_data, dict) and arguments_data.get("cmd"):
                command_text = str(arguments_data.get("cmd"))
        if item_type_lower in forbidden_write_tools or tool_lower in forbidden_write_tools:
            raise SystemExit(
                f"Codex cross-host fallback live saw write-capable event at line {index}: "
                f"type={item_type_lower!r} tool={tool_lower!r}"
            )
        # Canonical shared extraction (see above): all shapes, all embedded commands.
        inspectable = safety_inspectable_commands(data)
        if command_text and command_text not in inspectable:
            inspectable = inspectable + [command_text]
        if event_is_command_bearing(data):
            if any(pattern.search(candidate) for candidate in inspectable
                   for pattern in forbidden_command_patterns):
                raise SystemExit(
                    f"Codex cross-host fallback live saw write-like command at line {index}: "
                    f"{command_text[:1000]!r}"
                )
            if any(pattern.search(candidate) for candidate in inspectable
                   for pattern in claude_command_patterns):
                claude_command_hits.append((index, "; ".join(inspectable)[:1000]))
        if role_of_event(data) != "user":
            non_user_text_parts.append(event_text)
        if item.get("type") != "collab_tool_call":
            continue
        tool = item.get("tool")
        status = item.get("status")
        if tool == "spawn_agent" and status == "failed":
            failed_spawns.append((index, collect_text(item)[:2000]))
        if tool == "spawn_agent" and status == "completed":
            all_spawn_receivers.extend(item.get("receiver_thread_ids") or [])
            spawn_text = collect_text(item)
            matched = perspectives_in_text(spawn_text)
            if len(matched) != 1:
                raise SystemExit(
                    "Codex cross-host fallback live spawn payload lacked one Assigned perspective; "
                    f"line={index} matched={matched!r} text={spawn_text[:2000]!r}"
                )
            packet_matches = re.findall(
                r"(?ms)^\s*CHILD_PACKET_BEGIN\s*$\n(.*?)^\s*CHILD_PACKET_END\s*$",
                spawn_text,
            )
            if len(packet_matches) != 1 or common_result_marker not in packet_matches[0]:
                raise SystemExit(
                    "Codex cross-host fallback live spawn payload lacked one complete common-marker child packet"
                )
            receivers = item.get("receiver_thread_ids") or []
            if len(receivers) != 1:
                raise SystemExit(
                    f"Codex cross-host fallback live expected one receiver for lens {matched[0]}, got {receivers!r}"
                )
            for forbidden in forbidden_crosshost_markers:
                if forbidden in spawn_text:
                    raise SystemExit(
                        f"Codex cross-host fallback live spawn prompt leaked opposite-host success marker {forbidden!r}"
                    )
            receiver_to_lens[receivers[0]] = matched[0]
            packet_by_receiver[receivers[0]] = packet_matches[0].strip()
        if status == "completed" and tool in {"wait", "wait_agent", "close_agent"}:
            text = collect_text(item)
            mentioned = set(item.get("receiver_thread_ids") or [])
            mentioned.update(receiver for receiver in receiver_to_lens if receiver in text)
            mentioned.update(
                receiver for receiver in (item.get("agents_states") or {})
                if receiver in receiver_to_lens
            )
            if tool in {"wait", "wait_agent"}:
                for receiver in mentioned:
                    state = (item.get("agents_states") or {}).get(receiver) or {}
                    if state.get("status") == "completed" and state.get("message"):
                        wait_index_by_receiver.setdefault(receiver, index)
                        agent_result_by_receiver.setdefault(receiver, str(state.get("message")))
            if tool == "close_agent":
                for receiver in mentioned:
                    close_index_by_receiver.setdefault(receiver, index)

if failed_spawns:
    raise SystemExit(f"Codex cross-host fallback live saw failed spawn_agent calls: {failed_spawns!r}")

# Wrong-surface guard: the fallback path, not the cross-host hop, must have run.
if claude_command_hits:
    raise SystemExit(
        "Codex cross-host fallback live invoked a Claude/opposite-host command instead of staying "
        f"same-host (cross-host path taken, not the fallback): {claude_command_hits!r}"
    )

if not receiver_to_lens:
    used_transcript_fallback = True
    if not parent_thread_id:
        raise SystemExit(
            "Codex cross-host fallback live lacked both collab spawn events and a parent thread id"
        )
    transcript_children = parent_linked_lens_transcripts(parent_thread_id)
    missing_transcript_lenses = sorted(set(expected_perspectives) - set(transcript_children))
    if missing_transcript_lenses:
        raise SystemExit(
            "Codex cross-host fallback live parent-linked transcripts omitted lenses: "
            f"{missing_transcript_lenses!r}"
        )
    for lens, child in transcript_children.items():
        forbidden_hits = [
            marker for marker in forbidden_crosshost_markers
            if marker in child["input"] or marker in child["output"]
        ]
        if forbidden_hits:
            raise SystemExit(
                "Codex cross-host fallback transcript leaked opposite-host success markers: "
                f"{forbidden_hits!r}"
            )
        receiver = child["receiver"]
        receiver_to_lens[receiver] = lens
        receiver_agent_roles[receiver] = child["role"]
        receiver_transcripts[receiver] = child["text"]
        agent_result_by_receiver[receiver] = child["output"]
        all_spawn_receivers.append(receiver)
    persisted_waits, persisted_closes = persisted_parent_lifecycle(
        parent_thread_id,
        set(receiver_to_lens),
    )
    wait_index_by_receiver.update(persisted_waits)
    close_index_by_receiver.update(persisted_closes)

if len(packet_by_receiver) != len(expected_perspectives):
    captured_packets = []
    for transcript_path in (Path(live_home) / "sessions").rglob("*.jsonl"):
        rows = [
            json.loads(line)
            for line in transcript_path.read_text(encoding="utf-8", errors="replace").splitlines()
            if line.strip()
        ]
        if not any(row.get("type") == "session_meta" for row in rows):
            continue
        _meta, identity = resolved_session_metadata(transcript_path, rows)
        if identity != parent_thread_id:
            continue
        captured_packets.extend(
            packet.strip()
            for packet in re.findall(
                r"(?ms)^\s*CHILD_PACKET_BEGIN\s*$\n(.*?)^\s*CHILD_PACKET_END\s*$",
                collect_text(rows),
            )
        )
    for packet in captured_packets:
        matched = perspectives_in_text(packet)
        if len(matched) == 1:
            packet_by_receiver[f"parent-captured-{matched[0]}"] = packet
if len(packet_by_receiver) != len(expected_perspectives):
    raise SystemExit("Codex cross-host fallback could not capture both complete child packet bodies")
normalized_packets = {
    re.sub(r"(?m)^Assigned perspective:.*$", "Assigned perspective: NORMALIZED", packet)
    for packet in packet_by_receiver.values()
}
if len(normalized_packets) != 1:
    raise SystemExit("Codex cross-host fallback child packet bodies differed beyond Assigned perspective")

# Two distinct same-host lens agents (two agents, not one pass).
missing_lenses = sorted(set(expected_perspectives) - set(receiver_to_lens.values()))
if missing_lenses:
    raise SystemExit(
        f"Codex cross-host fallback live did not dispatch both same-host lens agents; "
        f"missing={missing_lenses!r} got={receiver_to_lens!r}"
    )
if len(receiver_to_lens) != len(expected_perspectives):
    raise SystemExit(
        f"Codex cross-host fallback live expected exactly two same-host lens receivers, got {receiver_to_lens!r}"
    )
if sorted(all_spawn_receivers) != sorted(receiver_to_lens):
    raise SystemExit(
        "Codex cross-host fallback live saw spawned receivers outside the two expected lenses: "
        f"all={all_spawn_receivers!r} expected={sorted(receiver_to_lens)!r}"
    )

for receiver, lens in receiver_to_lens.items():
    if receiver in receiver_transcripts:
        transcript = receiver_transcripts[receiver]
        actual_agent_role = receiver_agent_roles[receiver]
    else:
        transcript, actual_agent_role = receiver_transcript_and_agent_role(receiver)
        receiver_agent_roles[receiver] = actual_agent_role
    if actual_agent_role != "oh-no-code-reviewer":
        raise SystemExit(
            f"Codex cross-host fallback live spawned receiver {receiver} for lens {lens} with "
            f"agent_role={actual_agent_role!r}; expected oh-no-code-reviewer"
        )
    inspect_fallback_receiver_transcript(receiver, lens, transcript)

missing_waits = sorted(set(receiver_to_lens) - set(wait_index_by_receiver))
missing_closes = sorted(set(receiver_to_lens) - set(close_index_by_receiver))
all_non_user_text = "\n".join(non_user_text_parts)
if missing_waits:
    raise SystemExit(f"Codex cross-host fallback live did not capture wait_agent results: {missing_waits!r}")
if (
    missing_closes
    and not used_transcript_fallback
    and "close/cleanup was not available" not in all_non_user_text.lower()
):
    raise SystemExit(
        "Codex cross-host fallback live left receivers without close evidence or an unavailable-cleanup record: "
        f"{missing_closes!r}"
    )
for receiver in receiver_to_lens:
    if receiver in close_index_by_receiver and close_index_by_receiver[receiver] <= wait_index_by_receiver[receiver]:
        raise SystemExit(f"Codex cross-host fallback live closed receiver before wait result: {receiver}")

for receiver, lens in receiver_to_lens.items():
    result_text = agent_result_by_receiver.get(receiver, "")
    lower_result_text = result_text.lower()
    marker_count = len(re.findall(rf"(?m)^\s*{re.escape(common_result_marker)}\s*$", result_text))
    if marker_count != 1:
        raise SystemExit(
            f"Codex cross-host fallback live lens {lens} did not return exactly one common marker; "
            f"count={marker_count} result={result_text[:2000]!r}"
        )
    for forbidden in forbidden_crosshost_markers:
        if forbidden in result_text:
            raise SystemExit(
                f"Codex cross-host fallback live lens {lens} returned forbidden opposite-host marker {forbidden!r}"
            )
    missing_role_fields = missing_complete_code_reviewer_output(result_text)
    if missing_role_fields:
        raise SystemExit(
            f"Codex cross-host fallback live lens {lens} lacked complete code-reviewer role output: "
            f"{missing_role_fields!r}; result={result_text[:2000]!r}"
        )
    reviewed = physical_line_field_values(result_text, "Reviewed revision/diff fingerprint")
    verdicts = physical_line_field_values(result_text, "Overall verdict")
    if reviewed != [target_fingerprint]:
        raise SystemExit(
            f"Codex cross-host fallback live lens {lens} did not bind to the exact target fingerprint"
        )
    if verdicts != ["blocking-findings"]:
        raise SystemExit(
            f"Codex cross-host fallback live lens {lens} did not return a substantive blocking verdict: {verdicts!r}"
        )
    semantic_finding = (
        "debug" in lower_result_text
        and "admin" in lower_result_text
        and any(term in lower_result_text for term in ("bypass", "unauthorized", "escalation", "grants admin"))
    )
    if not semantic_finding:
        raise SystemExit(
            f"Codex cross-host fallback live lens {lens} missed the blocking debug-admin bypass finding"
        )
    hard_annex_issues, annex_warnings = annex_presentation_outcome(result_text)
    if hard_annex_issues:
        raise SystemExit(
            f"Codex cross-host fallback live lens {lens} wait result lacked a required substantive annex field or was ambiguous: "
            f"{hard_annex_issues!r}; result={result_text[:2000]!r}"
        )
    presentation_warnings.extend(f"lens {lens}: {warning}" for warning in annex_warnings)

non_user_text = "\n".join(non_user_text_parts)
lower_non_user_text = non_user_text.lower()
for forbidden in forbidden_crosshost_markers:
    if forbidden.lower() in lower_non_user_text:
        raise SystemExit(
            "Codex cross-host fallback live exposed an opposite-host success marker "
            f"(cross-host path taken, not the fallback): {forbidden!r}"
        )

success_text = "\n".join(
    part for part in non_user_text_parts
    if "OH_NO_XHOST_FALLBACK_OK" in part
)
if not success_text:
    raise SystemExit("Codex cross-host fallback live did not return success marker OH_NO_XHOST_FALLBACK_OK")
lower_success_text = success_text.lower()
for marker in required_final_markers:
    if marker.lower() not in lower_success_text:
        raise SystemExit(f"Codex cross-host fallback live missing final marker/text: {marker!r}")

# At least one synthesis marker across the transcript. The model may legitimately
# reference the marker more than once (e.g. a synthesis heading plus the final
# OH_NO_XHOST_FALLBACK_OK summary); a raw "exactly one" count is brittle. The
# required_synthesis_fields check below proves a real synthesis block exists, not
# just a marker echo, and the dispatch-based two-lens guard above stays strict.
synthesis_count = non_user_text.count("OH_NO_XHOST_FALLBACK_SYNTHESIS")
if synthesis_count < 1:
    raise SystemExit(
        f"Codex cross-host fallback live expected at least one synthesis marker, got {synthesis_count}"
    )
for field in required_synthesis_fields:
    if field.lower() not in lower_success_text:
        raise SystemExit(f"Codex cross-host fallback live missing synthesis field: {field!r}")
if not (
    "debug" in lower_success_text
    and "admin" in lower_success_text
    and any(term in lower_success_text for term in ("bypass", "unauthorized", "escalation", "grants admin"))
):
    raise SystemExit("Codex cross-host fallback synthesis omitted the blocking debug-admin bypass finding")

# Fallback note: the opposite host (Claude Code) was treated as unavailable and
# the review ran via the Same-Host Parallel Fallback.
if not (
    ("unavailable" in lower_success_text)
    and ("same-host" in lower_success_text or "same host" in lower_success_text)
    and ("opposite host" in lower_success_text or "claude" in lower_success_text)
):
    raise SystemExit(
        "Codex cross-host fallback live missing fallback note that the opposite host (Claude Code) was "
        f"unavailable and the review ran via the Same-Host Parallel Fallback; success_text={success_text[:2000]!r}"
    )

if presentation_warnings:
    print(
        "WARNING [codex/cross-host-fallback-live/annex-presentation]: "
        + "; ".join(sorted(presentation_warnings))
    )

summary = {
    "status": "passed",
    "codex_permission_preflight": "not danger-full-access",
    "opposite_host": "unavailable",
    "claude_consult": {
        "status": "skipped",
        "reason": "Codex permission state is not danger-full-access",
    },
    "same_host_lens_agents": [
        {
            "receiver": receiver,
            "lens": receiver_to_lens[receiver],
            "agent_role": receiver_agent_roles[receiver],
            "wait_result_line": wait_index_by_receiver[receiver],
            "close_result_line": close_index_by_receiver.get(receiver, "host-managed/unavailable"),
            "assigned_perspective": expected_perspectives[receiver_to_lens[receiver]],
            "returned_marker": common_result_marker,
        }
        for receiver in sorted(receiver_to_lens, key=lambda item: receiver_to_lens[item])
    ],
    "synthesis_marker": "OH_NO_XHOST_FALLBACK_SYNTHESIS",
    "final_marker": "OH_NO_XHOST_FALLBACK_OK",
}
Path(summary_path).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print("ok - live Codex cross-host Same-Host Parallel Fallback dispatched two same-host lens agents and synthesized")
PY
}

run_fusion_rescue_provider_classifier_offline_test() {
  log "Running offline Fusion Rescue provider classifier fixtures"
  local oracle_source
  oracle_source="$("$PYTHON_BIN" - "$SELF_PATH" <<'PY'
import re
import sys
from pathlib import Path
source = Path(sys.argv[1]).read_text(encoding="utf-8")
blocks = re.findall(r"<<'PY'\n(.*?)\nPY", source, re.S)
print(next(block for block in blocks if "def inspect_primary_claude_call" in block))
PY
)"
  printf '%s\n' "$oracle_source" \
    | codex_run_oracle_script /dev/null /dev/null /dev/null "$FUSION_RESCUE_MAX_BUDGET_USD" __fusion_classifier_self_test__ 0
  "$PYTHON_BIN" - "$SELF_PATH" <<'PY'
import sys
from pathlib import Path
source = Path(sys.argv[1]).read_text(encoding="utf-8")
start = source.index("run_fusion_rescue_live_test()")
end = source.index("run_codex_cross_host_fallback_live_test()", start)
body = source[start:end]
required = (
    '"accepted_outcome": "PASS(provider-limited)" if provider_limited else "PASS"',
    "invocation transport was proven but Claude panel inference/output was unavailable",
    'if fallback.get("status") != "passed":',
    "permission fallback also passed",
    "assert_no_codex_live_secret_leak",
    '|| first_leg_' + 'rc=$?',
    'primary_receiver, claude_call = inspect_linked_' + 'primary_claude_call(\n    receiver_to_lens, receiver_transcripts\n)',
    'provider_limited = claude_call["outcome"] == "provider-' + 'limited"\nif first_leg_rc not in {0, 1}:',
    'if first_leg_rc == 1 and not provider_' + 'limited:',
    'if (( first_oracle_rc != 0 )); ' + 'then',
    'return "$first_leg_' + 'rc"',
    'write_fusion_rescue_safe_' + 'rejection_summary',
)
missing = [fragment for fragment in required if fragment not in body]
if missing:
    raise SystemExit(f"Fusion provider-limited continuation contract missed fragments: {missing!r}")
provider_summary = body.index('"accepted_outcome": "PASS(provider-limited)"')
fallback_run = body.index('log "Running live Codex Fusion Rescue permission fallback smoke test"')
final_report = body.index('print("PASS(provider-limited) - invocation transport was proven')
if not provider_summary < fallback_run < final_report:
    raise SystemExit("Fusion provider-limited path could exit before permission-fallback continuation")
print("ok - Fusion provider-limited summary remains distinct and permission fallback continues")
PY
}

run_fusion_rescue_control_flow_offline_test() {
  log "Running offline production-linked Fusion Rescue control-flow fixtures"
  "$PYTHON_BIN" - "$SELF_PATH" <<'PY'
import json
import os
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path

source = Path(sys.argv[1]).resolve()
runner = r'''
set -euo pipefail
script="$1"
root="$2"
set --
source "$script"
mkdir -p "$root/run" "$root/home/sessions"
RUN_FUSION_RESCUE_LIVE=1
RUN_DIR="$root/run"
CODEX_HOME_DIR="$root/home"
CODEX_BIN=codex-fixture
LIVE_MODEL=""
FUSION_RESCUE_MAX_BUDGET_USD=0.50
trace="$root/trace"
: >"$trace"
run_codex_live_command() {
  local count
  count="$(grep -c '^command-' "$trace" || true)"
  count=$((count + 1))
  printf 'command-%s\n' "$count" >>"$trace"
  if [[ "$count" == 1 ]]; then
    printf '%s\n' "${FIRST_TRANSCRIPT:-fixture-first-leg}"
    printf '%s\n' "fixture-first-stderr" >&2
    return "${FIRST_RC:-0}"
  fi
  printf '%s\n' 'fixture-fallback-output'
  printf '%s\n' 'fixture-fallback-stderr' >&2
  return "${FALLBACK_COMMAND_RC:-0}"
}
assert_no_codex_live_secret_leak() {
  local count
  count="$(grep -c '^scan-' "$trace" || true)"
  count=$((count + 1))
  printf 'scan-%s\n' "$count" >>"$trace"
  if [[ "$count" == 1 ]]; then
    if [[ "${FIRST_SCAN:-pass}" != pass ]]; then
      printf '%s\n' 'SAFE_SECRET_DIAGNOSTIC {"status":"fixture-secret-scan-rejected"}' >&2
      return 1
    fi
  else
    [[ "${FALLBACK_SCAN:-pass}" == pass ]]
  fi
}
codex_run_oracle_script() {
  if [[ "$#" == 8 ]]; then
    local temp script_file helpers_file substitutions status=0
    temp="$(mktemp -d)"; script_file="$temp/oracle.py"; helpers_file="$temp/helpers.py"
    codex_oracle_shared_helpers >"$helpers_file"
    substitutions="$(awk -v helpers="$helpers_file" '$0 == "#@SHARED_HELPERS@" { n += 1; while ((getline line < helpers) > 0) print line > out; close(helpers); next } { print > out } END { print n + 0 }' out="$script_file")"
    [[ "$substitutions" == 1 ]] || return 98
    "$PYTHON_BIN" "$script_file" "$@" || status=$?
    rm -rf "$temp"
    return "$status"
  fi
  cat >/dev/null
  if [[ "$#" == 6 ]]; then
    printf 'classify\n' >>"$trace"
    local rc="$6" summary="$5" class="${FIRST_CLASS:-full}"
    if [[ "${FIRST_PARSER_RC:-0}" != 0 ]]; then return "$FIRST_PARSER_RC"; fi
    if [[ "$class" == provider && ( "$rc" == 0 || "$rc" == 1 ) ]]; then
      printf '%s\n' '{"status":"provider-limited","accepted_outcome":"PASS(provider-limited)"}' >"$summary"
      return 0
    fi
    if [[ "$class" == full && "$rc" == 0 ]]; then
      printf '%s\n' '{"status":"passed","accepted_outcome":"PASS"}' >"$summary"
      return 0
    fi
    return 65
  fi
  printf 'fallback-parser\n' >>"$trace"
  [[ "${FALLBACK_PARSER_RC:-0}" == 0 ]] || return "$FALLBACK_PARSER_RC"
  if [[ "${FALLBACK_SUMMARY:-passed}" == passed ]]; then
    printf '%s\n' '{"status":"passed"}' >"$4"
  else
    printf '%s\n' '{"status":"failed"}' >"$4"
  fi
}
run_fusion_rescue_live_test
'''

def case(label, env, expected_rc, expected_pass=None, expected_trace=(), absent_trace=(), safe_schema=False, safe_expect=None):
    with tempfile.TemporaryDirectory() as temp:
        case_env = os.environ.copy()
        case_env.update(env)
        result = subprocess.run(
            ["bash", "-c", runner, "fusion-control-fixture", str(source), temp],
            text=True,
            capture_output=True,
            env=case_env,
        )
        trace_path = Path(temp) / "trace"
        trace = trace_path.read_text(encoding="utf-8").splitlines() if trace_path.exists() else []
        if result.returncode != expected_rc:
            raise SystemExit(f"{label}: rc={result.returncode}, expected={expected_rc}, stderr={result.stderr!r}")
        combined = result.stdout + result.stderr
        if expected_pass is not None and expected_pass not in combined:
            raise SystemExit(f"{label}: missing final pass {expected_pass!r}: {combined!r}")
        if expected_pass is None and "PASS(provider-limited)" in combined:
            raise SystemExit(f"{label}: emitted provider-limited pass on rejected path")
        positions = []
        for marker in expected_trace:
            if marker not in trace:
                raise SystemExit(f"{label}: missing trace marker {marker!r}: {trace!r}")
            positions.append(trace.index(marker))
        if positions != sorted(positions):
            raise SystemExit(f"{label}: trace order was not preserved: {trace!r}")
        if any(marker in trace for marker in absent_trace):
            raise SystemExit(f"{label}: forbidden trace marker present: {trace!r}")
        if safe_schema:
            summary = json.loads((Path(temp) / "run" / "fusion-rescue-codex-claude.summary.json").read_text(encoding="utf-8"))
            required = {
                "status", "reason_code", "first_leg_rc", "scanner_result", "artifacts",
                "launch_count", "event_shapes", "verified_argv", "correlated_inner_exit_code",
                "terminal_status_failed", "http429", "cooldown", "success_marker",
                "competing_error", "classifier_outcome", "classifier_rc", "fallback",
            }
            if set(summary) != required or summary["fallback"] != {"status": "not-run"}:
                raise SystemExit(f"{label}: unsafe or incomplete rejection schema: {summary!r}")
            for key, expected in (safe_expect or {}).items():
                actual = summary
                for component in key.split("."):
                    actual = actual[component]
                if actual != expected:
                    raise SystemExit(f"{label}: safe summary {key}={actual!r}, expected {expected!r}: {summary!r}")
            if (Path(temp) / "run" / "fusion-rescue-codex-claude.jsonl").exists() or (Path(temp) / "run" / "fusion-rescue-codex-claude.err").exists():
                raise SystemExit(f"{label}: raw first-leg artifacts survived rejection")

def heredoc_wrapper_transcript():
    prompt = "Review the assigned primary panel directly."
    py_source = (
        'import os\nimport subprocess\nimport sys\n\n'
        'prompt = ' + repr(prompt) + '\n'
        "exe = os.environ.get('CLAUDE_BIN') or 'claude'\n"
        "argv = [exe, '--print', '--model', 'opus', '--max-budget-usd', '0.50', '--permission-mode', 'dontAsk', '--no-session-persistence', prompt]\n"
        'try:\n'
        '    completed = subprocess.run(argv, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=300, check=False)\n'
        'except FileNotFoundError:\n'
        "    print('CLAUDE_CALL_STATUS=executable_not_found')\n"
        '    sys.exit(127)\n'
        'except subprocess.TimeoutExpired:\n'
        "    print('CLAUDE_CALL_STATUS=timeout')\n"
        '    sys.exit(124)\n'
        "print('CLAUDE_CALL_STATUS=completed')\n"
        "print('CLAUDE_EXIT_CODE=' + str(completed.returncode))\n"
        "print('CLAUDE_STDOUT_BEGIN')\n"
        'print(completed.stdout)\n'
        "print('CLAUDE_STDOUT_END')\n"
        'if completed.stderr:\n'
        "    print('CLAUDE_STDERR_BEGIN')\n"
        '    print(completed.stderr)\n'
        "    print('CLAUDE_STDERR_END')\n"
        'sys.exit(completed.returncode)\n'
    )
    command = "python3 - <<'PY'\n" + py_source + "PY"
    launch_input = (
        'const r = await tools.exec_command({cmd: ' + json.dumps(command) + '});\n'
        'text(r.output); if (r.session_id) text(`SESSION_ID=${r.session_id}`);'
    )
    output = "CLAUDE_CALL_STATUS=completed\nCLAUDE_EXIT_CODE=1\nCLAUDE_STDOUT_BEGIN\nAPI Error: Request rejected (429) · All credentials for model claude-opus-5 are cooling down via provider claude\nCLAUDE_STDOUT_END\n"
    rows = (
        {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": "launch-heredoc", "input": launch_input}},
        {"payload": {"type": "custom_tool_call_output", "call_id": "launch-heredoc", "output": "Script running with cell ID 1\nOutput:\n"}},
        {"payload": {"type": "function_call", "name": "wait", "call_id": "wait-heredoc", "arguments": json.dumps({"cell_id": "1"})}},
        {"payload": {"type": "function_call_output", "call_id": "wait-heredoc", "output": [{"type": "input_text", "text": json.dumps({"session_id": 32478, "output": ""})}]}},
        {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": "poll-heredoc", "input": "const r = await tools.write_stdin({session_id: 32478, chars: \"\", yield_time_ms: 30000, max_output_tokens: 8000}); text(r.output); if (r.session_id) text(`SESSION_ID=${r.session_id}`);"}},
        {"payload": {"type": "custom_tool_call_output", "call_id": "poll-heredoc", "output": "Script running with cell ID 2\nOutput:\n"}},
        {"payload": {"type": "function_call", "name": "wait", "call_id": "wait-heredoc-final", "arguments": json.dumps({"cell_id": "2"})}},
        {"payload": {"type": "function_call_output", "call_id": "wait-heredoc-final", "output": output}},
    )
    return "\n".join(json.dumps(row) for row in rows)

def semantic_transport_wrapper_transcript():
    prompt = "Review the assigned primary panel directly."
    py_source = (
        'import os, subprocess, sys\n'
        'prompt = ' + repr(prompt) + '\n'
        'binary = os.environ.get("CLAUDE_BIN") or "claude"\n'
        'args = [binary, "--print", "--model", "opus", "--max-budget-usd", "0.50", "--permission-mode", "dontAsk", "--no-session-persistence", prompt]\n'
        'try:\n'
        '    cp = subprocess.run(args, shell=False, capture_output=True, text=True)\n'
        'except Exception as exc:\n'
        '    print("CLAUDE_LAUNCH_FAILURE_TYPE=" + type(exc).__name__)\n'
        '    sys.exit(125)\n'
        'print("CLAUDE_EXIT_STATUS=" + str(cp.returncode))\n'
        'print("CLAUDE_STDERR_CLASS=" + ("empty" if not cp.stderr else "nonempty"))\n'
        'print("CLAUDE_STDOUT_BEGIN")\n'
        'print(cp.stdout, end="" if cp.stdout.endswith("\\\\n") or not cp.stdout else "\\\\n")\n'
        'print("CLAUDE_STDOUT_END")\n'
        'sys.exit(0)\n'
    )
    launch_input = (
        'const r = await tools.exec_command({cmd: ' + json.dumps("python3 -c " + shlex.quote(py_source)) + ', '
        'workdir: "/tmp/fusion-fixture", yield_time_ms: 30000, max_output_tokens: 12000});\n'
        'text(r.output);\nif (r.session_id) text(`SESSION_ID=${r.session_id}`);'
    )
    terminal_text = (
        "CLAUDE_EXIT_STATUS=1\nCLAUDE_STDERR_CLASS=empty\nCLAUDE_STDOUT_BEGIN\n"
        "API Error: Request rejected (429) · All credentials for model claude-opus-5 are cooling down via provider claude\n"
        "\\nCLAUDE_STDOUT_END\n"
    )
    rows = [
        {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": "call_ksm2zVFgGGQBkjfq6HsAPYVm", "input": launch_input}},
        {"payload": {"type": "custom_tool_call_output", "call_id": "call_ksm2zVFgGGQBkjfq6HsAPYVm", "output": "Script running with cell ID 1\nOutput:\n"}},
        {"payload": {"type": "function_call", "name": "wait", "call_id": "wait-semantic", "arguments": json.dumps({"cell_id": "1"})}},
        {"payload": {"type": "function_call_output", "call_id": "wait-semantic", "output": [{"type": "input_text", "text": json.dumps({"session_id": 16195, "output": ""})}]}},
    ]
    for index in range(1, 5):
        rows.extend((
            {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": f"poll-semantic-{index}", "input": 'const r = await tools.write_stdin({session_id: 16195, chars: "", yield_time_ms: 30000, max_output_tokens: 12000}); text(r.output); if (r.session_id) text(`SESSION_ID=${r.session_id}`);'}},
            {"payload": {"type": "custom_tool_call_output", "call_id": f"poll-semantic-{index}", "output": f"Script running with cell ID {index + 1}\nOutput:\n"}},
        ))
    rows.extend((
        {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": "call_eWhCQFTAiwnBHFcEbFPooZLM", "input": 'const r = await tools.write_stdin({session_id: 16195, chars: "", yield_time_ms: 30000, max_output_tokens: 12000}); text(r.output); if (r.session_id) text(`SESSION_ID=${r.session_id}`);'}},
        {"payload": {"type": "custom_tool_call_output", "call_id": "call_eWhCQFTAiwnBHFcEbFPooZLM", "output": [{"type": "input_text", "text": terminal_text}]}},
        {"type": "event_msg", "payload": {"type": "task_complete", "last_agent_message": "Claude marker: absent."}},
    ))
    return "\n".join(json.dumps(row) for row in rows)


def assigned_wrapper_transcript(competing=False, source_transform=None):
    prompt = "Review the assigned primary panel directly."
    py_source = (
        'import os, subprocess\n'
        'prompt = """' + prompt + '"""\n'
        'argv = [os.environ.get("CLAUDE_BIN", "claude"), "--print", "--model", "opus", "--max-budget-usd", "0.50", "--permission-mode", "dontAsk", "--no-session-persistence", prompt]\n'
        'result = subprocess.run(argv, capture_output=True, text=True, timeout=240)\n'
        'print(result.stdout, end="")\n'
        'if result.stderr: print("\\n[stderr]", result.stderr, end="")\n'
        'raise SystemExit(result.returncode)'
    )
    if source_transform is not None:
        py_source = source_transform(py_source)
    launch_input = (
        'const r = await tools.exec_command({cmd: ' + json.dumps("python3 -c " + shlex.quote(py_source)) + ', '
        'workdir: "/tmp/fusion-fixture", yield_time_ms: 30000, max_output_tokens: 8000});\n'
        'text(JSON.stringify(r));'
    )
    output = "API Error: Request rejected (429) · All credentials for model claude-opus-5 are cooling down via provider claude"
    if competing:
        output += "; permission denied"
    rows = (
        {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": "launch-assigned", "input": launch_input}},
        {"payload": {"type": "custom_tool_call_output", "call_id": "launch-assigned", "output": "Script running with cell ID 1\nWall time 11.0 seconds\nOutput:\n"}},
        {"payload": {"type": "function_call", "name": "wait", "call_id": "wait-assigned", "arguments": json.dumps({"cell_id": "1"})}},
        {"payload": {"type": "function_call_output", "call_id": "wait-assigned", "output": [{"type": "input_text", "text": json.dumps({"session_id": 52069, "output": ""})}]}},
        {"payload": {"type": "custom_tool_call", "name": "exec", "call_id": "poll-assigned", "input": "const r = await tools.write_stdin({session_id: 52069, chars: \"\", yield_time_ms: 30000, max_output_tokens: 8000}); text(JSON.stringify(r));"}},
        {"payload": {"type": "custom_tool_call_output", "call_id": "poll-assigned", "output": [{"type": "input_text", "text": json.dumps({"exit_code": 1, "output": output})}]}},
    )
    return "\n".join(json.dumps(row) for row in rows)

ordered = ("command-1", "scan-1", "classify", "command-2", "scan-2", "fallback-parser")
case("provider RC1 continues", {"FIRST_RC":"1", "FIRST_CLASS":"provider", "FIRST_TRANSCRIPT":"HTTP 429: credentials cooling down"}, 0, "PASS(provider-limited) -", ordered)
case("provider RC0 continues", {"FIRST_RC":"0", "FIRST_CLASS":"provider", "FIRST_TRANSCRIPT":heredoc_wrapper_transcript()}, 0, "PASS(provider-limited) -", ordered)
case("full RC0 continues", {"FIRST_RC":"0", "FIRST_CLASS":"full", "FIRST_TRANSCRIPT":"OH_NO_CLAUDE_FUSION_PANEL_OK"}, 0, "PASS -", ordered)
case("arbitrary RC1 preserved", {"FIRST_RC":"1", "FIRST_CLASS":"reject", "FIRST_TRANSCRIPT":"generic failure"}, 1, None, ("command-1", "scan-1", "classify"), ("command-2", "fallback-parser"), safe_schema=True)
wrapper_summary = {
    "launch_count": 1,
    "verified_argv.executable": True,
    "verified_argv.print_mode": True,
    "verified_argv.model_opus": True,
    "verified_argv.budget": True,
    "verified_argv.permission_mode_dontAsk": True,
    "verified_argv.session_persistence_disabled": True,
    "verified_argv.tools_override_absent": True,
    "correlated_inner_exit_code": 1,
    "terminal_status_failed": True,
    "http429": True,
    "cooldown": True,
}
case("assigned wrapper safe summary", {"FIRST_RC":"1", "FIRST_CLASS":"reject", "FIRST_TRANSCRIPT":assigned_wrapper_transcript()}, 1, None, ("command-1", "scan-1", "classify"), ("command-2", "fallback-parser"), safe_schema=True, safe_expect={**wrapper_summary, "competing_error": False})
case("heredoc wrapper safe summary", {"FIRST_RC":"0", "FIRST_CLASS":"reject", "FIRST_TRANSCRIPT":heredoc_wrapper_transcript()}, 65, None, ("command-1", "scan-1", "classify"), ("command-2", "fallback-parser"), safe_schema=True, safe_expect={**wrapper_summary, "first_leg_rc": 0, "competing_error": False})
case("semantic transport wrapper safe summary", {"FIRST_RC":"0", "FIRST_CLASS":"reject", "FIRST_TRANSCRIPT":semantic_transport_wrapper_transcript()}, 65, None, ("command-1", "scan-1", "classify"), ("command-2", "fallback-parser"), safe_schema=True, safe_expect={**wrapper_summary, "first_leg_rc": 0, "competing_error": False})
case("assigned wrapper competing error safe summary", {"FIRST_RC":"1", "FIRST_CLASS":"reject", "FIRST_TRANSCRIPT":assigned_wrapper_transcript(competing=True)}, 1, None, ("command-1", "scan-1", "classify"), ("command-2", "fallback-parser"), safe_schema=True, safe_expect={**wrapper_summary, "competing_error": True})
for label, transform in (
    ("constant SystemExit", lambda source: source.replace('raise SystemExit(result.returncode)', 'raise SystemExit(1)')),
    ("stdout prose constant", lambda source: source.replace('print(result.stdout, end="")', 'print("unrelated stdout", end="")')),
    ("altered stderr condition", lambda source: source.replace('if result.stderr:', 'if True:')),
    ("stderr else branch", lambda source: source.replace(
        'if result.stderr: print("\\n[stderr]", result.stderr, end="")',
        'if result.stderr:\n    print("\\n[stderr]", result.stderr, end="")\nelse:\n    print("unrelated")',
    )),
):
    case(f"safe summary rejects {label}", {"FIRST_RC":"1", "FIRST_CLASS":"reject", "FIRST_TRANSCRIPT":assigned_wrapper_transcript(source_transform=transform)}, 1, None, ("command-1", "scan-1", "classify"), ("command-2", "fallback-parser"), safe_schema=True, safe_expect={"launch_count": 0})
case("timeout RC124 preserved", {"FIRST_RC":"124", "FIRST_CLASS":"provider", "FIRST_TRANSCRIPT":"HTTP 429: credentials cooling down"}, 124, None, ("command-1", "scan-1", "classify"), ("command-2", "fallback-parser"))
case("scanner blocks classifier", {"FIRST_RC":"1", "FIRST_CLASS":"provider", "FIRST_SCAN":"fail"}, 1, None, ("command-1", "scan-1"), ("classify", "command-2", "fallback-parser"))
case("fallback command failure blocks pass", {"FIRST_RC":"1", "FIRST_CLASS":"provider", "FALLBACK_COMMAND_RC":"71"}, 71, None, ordered[:4], ("fallback-parser",))
case("fallback scanner blocks parser", {"FIRST_RC":"1", "FIRST_CLASS":"provider", "FALLBACK_SCAN":"fail"}, 1, None, ordered[:5], ("fallback-parser",))
case("fallback parser blocks pass", {"FIRST_RC":"1", "FIRST_CLASS":"provider", "FALLBACK_PARSER_RC":"72"}, 72, None, ordered)
case("fallback failed summary blocks pass", {"FIRST_RC":"1", "FIRST_CLASS":"provider", "FALLBACK_SUMMARY":"failed"}, 1, None, ordered)
print("ok - production-linked Fusion Rescue captured-RC, scanner, classifier, fallback, and final-pass ordering fixtures passed")
PY
}

main() {
  cd "$PLUGIN_ROOT"
  require_command "$PYTHON_BIN"
  require_command "$CODEX_BIN"
  run_live_timeout_offline_test; run_direct_smoke_classifier_offline_test
  run_codex_dispatch_oracle_offline_test; run_cross_host_oracle_offline_test
  run_codex_install_identity_offline_test; run_codex_install_integration_offline_test
  run_codex_active_plugin_root_offline_test; run_codex_safety_extraction_offline_test
  run_fusion_rescue_provider_classifier_offline_test; run_fusion_rescue_control_flow_offline_test
  validate_codex_live_secret_scanner; run_codex_dispatch_evidence_offline_test
  validate_codex_live_clone_safety
  prepare_isolated_codex_live_home
  log "Testing ${PLUGIN_ID} for Codex from ${PLUGIN_ROOT}"
  validate_codex_manifest; validate_codex_hooks; validate_codex_agent_installer
  install_via_codex_plugins; install_codex_agents_user_scope; assert_codex_prompt_exposes_skills
  run_live_tests
  run_dispatch_live_tests
  run_cross_host_live_test
  log "All requested Codex checks passed"
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi
