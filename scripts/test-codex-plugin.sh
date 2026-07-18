#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

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
RUN_DEEP_LIVE="${OH_NO_DEEP_LIVE:-0}"
RUN_PARALLEL_LIVE="${OH_NO_PARALLEL_LIVE:-0}"
RUN_RALPLAN_LIVE="${OH_NO_RALPLAN_LIVE:-0}"
RUN_NAMED_AGENTS_LIVE="${OH_NO_NAMED_AGENTS_LIVE:-0}"
RUN_FUSION_RESCUE_LIVE="${OH_NO_FUSION_RESCUE_LIVE:-0}"
RUN_CROSS_HOST_FALLBACK_LIVE="${OH_NO_CODEX_CROSS_HOST_FALLBACK_LIVE:-0}"
RUN_SIMPLIFY_LIVE="${OH_NO_SIMPLIFY_LIVE:-0}"
RUN_NATURAL_SESSION_START_LIVE="${OH_NO_NATURAL_SESSION_START_LIVE:-0}"
RUN_WORKTREE_LIVE="${OH_NO_WORKTREE_LIVE:-0}"
LIVE_MODEL="${OH_NO_CODEX_TEST_MODEL:-}"
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
  run_ralplan_live_test
  run_named_agents_live_test
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
  using-oh-no-harness
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

Adds the Codex marketplace, exercises the same app-server plugin list/install
path used by /plugins, then verifies that Codex exposes the plugin skills.

Options:
  --live             Run live codex exec smoke tests after prompt exposure checks.
  --deep-live        Run live deep smoke tests that require linked support docs.
  --parallel-live    Run live Ralph explicit and SessionStart-natural subagent smoke tests.
  --ralplan-live     Run live Ralplan explicit and SessionStart-natural planning-subagent smoke tests.
                     Requires install mode and must run separately from other subagent live flags.
                     Requires install mode and runs separately from legacy --ralplan-live.
  --named-agents-live
                     Run live Codex custom-agent name spawn smoke test.
  --fusion-rescue-live
                     Run live Fusion Rescue cross-host and panel-subagent smoke test.
  --cross-host-fallback-live
                     Run live Codex cross-host Same-Host Parallel Fallback smoke test
                     (opposite host unavailable, two same-host agents synthesized).
  --simplify-live    Run live simplify explicit and SessionStart-natural cleanup-subagent smoke tests.
  --natural-session-start-live
                     Run live natural SessionStart role-worker smoke tests for Interview, Ultrawork,
                     Systematic Debugging, and Verification Before Completion.
  --worktree-live    Run live Ralph worktree-creation smoke test in a disposable repo.
  --skip-live        Skip live codex exec smoke tests. Default.
  --no-install       Skip the marketplace/app-server install step. Incompatible with --ralplan-live.
  --codex-home <dir> Use this Codex home instead of \$CODEX_HOME or ~/.codex.
  --model <model>    Model for live codex exec tests. Default: Codex config default.
  --marketplace-source <source>
                     Marketplace source passed to app-server marketplace/add.
                     Default: this checkout. Use jcwleo/oh-no-harness to test GitHub.
  -h, --help         Show this help.

Environment overrides:
  CODEX_BIN, PYTHON_BIN, CODEX_HOME, OH_NO_INSTALL, OH_NO_LIVE, OH_NO_DEEP_LIVE,
  OH_NO_PARALLEL_LIVE, OH_NO_RALPLAN_LIVE, OH_NO_CODEX_TEST_MODEL,
  OH_NO_ISOLATE_CODEX_HOME, OH_NO_LIVE_TIMEOUT_SECONDS, OH_NO_LIVE_TIMEOUT_GRACE_SECONDS,
  OH_NO_NAMED_AGENTS_LIVE, OH_NO_FUSION_RESCUE_LIVE, OH_NO_FUSION_RESCUE_MAX_BUDGET_USD,
  OH_NO_CODEX_CROSS_HOST_FALLBACK_LIVE,
  OH_NO_SIMPLIFY_LIVE, OH_NO_NATURAL_SESSION_START_LIVE, OH_NO_WORKTREE_LIVE, OH_NO_TEST_RUN_DIR,
  OH_NO_MARKETPLACE_SOURCE
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --live)
      RUN_LIVE=1
      shift
      ;;
    --deep-live)
      RUN_DEEP_LIVE=1
      shift
      ;;
    --parallel-live)
      RUN_PARALLEL_LIVE=1
      shift
      ;;
    --ralplan-live)
      RUN_RALPLAN_LIVE=1
      shift
      ;;
    --named-agents-live)
      RUN_NAMED_AGENTS_LIVE=1
      shift
      ;;
    --fusion-rescue-live)
      RUN_FUSION_RESCUE_LIVE=1
      shift
      ;;
    --cross-host-fallback-live)
      RUN_CROSS_HOST_FALLBACK_LIVE=1
      shift
      ;;
    --simplify-live)
      RUN_SIMPLIFY_LIVE=1
      shift
      ;;
    --natural-session-start-live)
      RUN_NATURAL_SESSION_START_LIVE=1
      shift
      ;;
    --worktree-live)
      RUN_WORKTREE_LIVE=1
      shift
      ;;
    --skip-live)
      RUN_LIVE=0
      shift
      ;;
    --no-install)
      INSTALL_MODE=0
      shift
      ;;
    --codex-home)
      CODEX_HOME_DIR="${2:-}"
      [[ -n "$CODEX_HOME_DIR" ]] || { echo "Missing value for --codex-home" >&2; exit 2; }
      shift 2
      ;;
    --model)
      LIVE_MODEL="${2:-}"
      [[ -n "$LIVE_MODEL" ]] || { echo "Missing value for --model" >&2; exit 2; }
      shift 2
      ;;
    --marketplace-source)
      MARKETPLACE_SOURCE="${2:-}"
      [[ -n "$MARKETPLACE_SOURCE" ]] || { echo "Missing value for --marketplace-source" >&2; exit 2; }
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

CODEX_ACTIVE_HOME_DIR="$CODEX_HOME_DIR"

isolated_codex_live_home_requested() {
  [[ "${RUN_RALPLAN_LIVE}" == "1" || "${FORCE_ISOLATED_CODEX_HOME}" == "1" ]]
}

validate_ralplan_live_option_compatibility() {
  [[ "${RUN_RALPLAN_LIVE}" == "1" ]] || return 0

  [[ "$INSTALL_MODE" == "1" ]] \
    || fail "Ralplan live lanes cannot be combined with --no-install because their isolated home requires current plugin and agent fixtures"

  local conflicting_flags=()
  [[ "$RUN_PARALLEL_LIVE" == "1" ]] && conflicting_flags+=(--parallel-live)
  [[ "$RUN_NAMED_AGENTS_LIVE" == "1" ]] && conflicting_flags+=(--named-agents-live)
  [[ "$RUN_FUSION_RESCUE_LIVE" == "1" ]] && conflicting_flags+=(--fusion-rescue-live)
  [[ "$RUN_CROSS_HOST_FALLBACK_LIVE" == "1" ]] && conflicting_flags+=(--cross-host-fallback-live)
  [[ "$RUN_SIMPLIFY_LIVE" == "1" ]] && conflicting_flags+=(--simplify-live)
  [[ "$RUN_NATURAL_SESSION_START_LIVE" == "1" ]] && conflicting_flags+=(--natural-session-start-live)
  if [[ "${#conflicting_flags[@]}" -gt 0 ]]; then
    fail "Ralplan live lanes use the Multi-Agent v2 event surface; run separately from: ${conflicting_flags[*]}"
  fi
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

run_live_process_with_timeout() {
  local live_home="$1"
  shift

  "$PYTHON_BIN" - "$live_home" "$LIVE_TIMEOUT_SECONDS" "$LIVE_TIMEOUT_GRACE_SECONDS" "$@" <<'PY'
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

run_in_verified_codex_live_home() {
  local live_home="$1"
  shift

  assert_codex_live_home_provenance "$live_home" || return $?
  local status=0
  run_live_process_with_timeout "$live_home" "$@" || status=$?
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
  printf 'developer_instructions = "fixture"\n' >"$source/agents/oh-no-planner.toml"
  printf 'sentinel\n' >"$external_agents/sentinel"

  clone_codex_live_home "$source" "$target"
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
    re.compile(r"sk-[A-Za-z0-9_-]{20,512}(?![A-Za-z0-9_-])"),
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

def visible_line_parts(line):
    try:
        value = json.loads(line)
    except json.JSONDecodeError:
        return line, [line]

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

    def collect_strings(item):
        if isinstance(item, str):
            return [item]
        if isinstance(item, dict):
            result = []
            for child in item.values():
                result.extend(collect_strings(child))
            return result
        if isinstance(item, list):
            result = []
            for child in item:
                result.extend(collect_strings(child))
            return result
        return []

    visible_value = redact_encrypted(value)
    return json.dumps(visible_value, sort_keys=True), collect_strings(visible_value)


def is_public_url_slug(text, match):
    parsed = urlsplit(text)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        return False
    authority_start = len(parsed.scheme) + 3
    netloc_start = text.find(parsed.netloc, authority_start)
    path_start = text.find(parsed.path, netloc_start + len(parsed.netloc)) if parsed.path else -1
    in_netloc = (
        netloc_start >= 0
        and netloc_start <= match.start() < match.end() <= netloc_start + len(parsed.netloc)
    )
    in_path = (
        path_start >= 0
        and path_start <= match.start() < match.end() <= path_start + len(parsed.path)
    )
    if not in_netloc and not in_path:
        return False
    return re.fullmatch(r"sk-(?:[a-z]+-){2,}[a-z]+", match.group(0)) is not None


for path in targets:
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError as exc:
        raise SystemExit(f"unable to inspect live artifact safely: {path.name}: {type(exc).__name__}")
    for line_number, line in enumerate(lines, 1):
        visible_line, visible_strings = visible_line_parts(line)
        if any(value in visible_line for value in secret_values):
            raise SystemExit(f"isolated auth value detected in {path.name} near line {line_number}")
        for visible_text in visible_strings:
            for pattern_index, pattern in enumerate(secret_patterns, 1):
                for match in pattern.finditer(visible_text):
                    if pattern_index == 1 and is_public_url_slug(visible_text, match):
                        continue
                    raise SystemExit(
                        f"secret-like pattern {pattern_index} detected in {path.name} near line {line_number}"
                    )
PY
}

validate_codex_live_secret_scanner() {
  local temp_root auth_file safe_file safe_url_file encrypted_file leak_file
  local access_token id_token session_token private_key credential long_nonsecret generic_secret
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-codex-secret-scan.XXXXXX")"
  CODEX_LIVE_TEMP_ROOTS+=("$temp_root")
  auth_file="$temp_root/auth.json"
  safe_file="$temp_root/safe.jsonl"
  safe_url_file="$temp_root/safe-url.jsonl"
  encrypted_file="$temp_root/encrypted.jsonl"
  leak_file="$temp_root/leak.jsonl"
  access_token="fixture-access-$(printf '%024d' 0)"
  id_token="fixture-id-$(printf '%024d' 1)"
  session_token="fixture-session-$(printf '%024d' 2)"
  private_key="fixture-private-$(printf '%024d' 3)"
  long_nonsecret="sk-$(printf '%0600d' 4)"
  generic_secret="sk-$(printf '%024d' 5)"

  printf '{"access_token":"%s","id_token":"%s","session_token":"%s","private_key":"%s"}\n' \
    "$access_token" "$id_token" "$session_token" "$private_key" >"$auth_file"
  printf 'safe live artifact\nopaque=%s\n' "$long_nonsecret" >"$safe_file"
  assert_no_codex_live_secret_leak "$auth_file" "$safe_file" \
    || fail "Codex live secret scanner rejected its safe fixture"

  printf '{"websiteUrl":"https://task-app-hub-content-chain.example.invalid/privacy"}\n' \
    >"$safe_url_file"
  assert_no_codex_live_secret_leak "$auth_file" "$safe_url_file" \
    || fail "Codex live secret scanner rejected a public URL slug"

  printf '{"type":"response_item","payload":{"type":"agent_message","content":[{"type":"encrypted_content","ciphertext":"%s-%s"}]}}\n' \
    "$generic_secret" "$access_token" >"$encrypted_file"
  assert_no_codex_live_secret_leak "$auth_file" "$encrypted_file" \
    || fail "Codex live secret scanner rejected opaque encrypted transcript content"

  printf 'visible=%s\n' "$generic_secret" >"$leak_file"
  if assert_no_codex_live_secret_leak "$auth_file" "$leak_file" >/dev/null 2>&1; then
    fail "Codex live secret scanner missed its visible secret-like fixture"
  fi

  printf '{"websiteUrl":"https://example.invalid/?token=%s"}\n' "$generic_secret" >"$leak_file"
  if assert_no_codex_live_secret_leak "$auth_file" "$leak_file" >/dev/null 2>&1; then
    fail "Codex live secret scanner ignored a secret-like URL query value"
  fi

  for credential in "$access_token" "$id_token" "$session_token" "$private_key"; do
    printf 'unlabeled=%s\n' "$credential" >"$leak_file"
    if assert_no_codex_live_secret_leak "$auth_file" "$leak_file" >/dev/null 2>&1; then
      fail "Codex live secret scanner missed its credential fixture"
    fi
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

validate_codex_hooks() {
  log "Validating Codex hook separation"
  assert_json_valid "$PLUGIN_ROOT/hooks/hooks.json"
  bash -n "$PLUGIN_ROOT/hooks/session-start"
  bash -n "$PLUGIN_ROOT/hooks/ralph-platform-adapter"

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
import json
import re
import sys
from pathlib import Path

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
output = data.get("hookSpecificOutput", {})
if output.get("hookEventName") != "SessionStart":
    raise SystemExit("Codex SessionStart emitted the wrong hook event")
text = output.get("additionalContext", "")
if "Use native skill loading to read the relevant Oh No Harness skill when it applies." not in text:
    raise SystemExit("Codex SessionStart is missing compact native skill-loading guidance")
required = [
    "Use oh-no-harness:test-driven-development only as an explicit TDD/test-first route or an internal guardrail",
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
if missing:
    raise SystemExit(f"Codex SessionStart missing Ralph/TDD routing markers: {missing}")
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
for forbidden in ("OH_NO_SKILL_CORE", "Below is the full content", "docs/skill-core/using-oh-no-harness.md"):
    if forbidden in text:
        raise SystemExit(f"Codex SessionStart embedded full using-oh-no-harness core content: {forbidden}")
for forbidden in (
    "About to make a behavior-changing production edit: oh-no-harness:test-driven-development",
    "behavior-changing edits go through test-driven-development",
):
    if forbidden in text:
        raise SystemExit(f"Codex SessionStart still routes ordinary implementation to TDD: {forbidden}")
if len(text) > 4000:
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

  OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/scripts/oh-no-config" on >/dev/null
  PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/hooks/run-hook.cmd" session-start \
    >"$temp_data/session-start-codex-routing-on.json"
  "$PYTHON_BIN" - "$temp_data/session-start-codex-routing-on.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
output = data.get("hookSpecificOutput", {})
text = output.get("additionalContext", "")
if "OH_NO_FORCED_ROUTING" in text:
    raise SystemExit("Codex SessionStart should not add forced routing when auto-routing is enabled")
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

  printf '{"hook_event_name":"UserPromptSubmit","prompt":"Run ralph on the approved plan."}\n' >"$temp_data/ralph-prompt.json"
  PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/ralph-prompt.json" >"$temp_data/ralph-adapter.json"
  "$PYTHON_BIN" - "$temp_data/ralph-adapter.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
output = data.get("hookSpecificOutput", {})
if output.get("hookEventName") != "UserPromptSubmit":
    raise SystemExit("Codex Ralph adapter emitted the wrong hook event")
text = output.get("additionalContext", "")
required = [
    "OH_NO_RALPH_PLATFORM_ADAPTER",
    "CODEX_ONLY_RALPH_ADAPTER",
    "docs/platforms/codex-ralph.md",
    "Agent prompt source: docs/agent-core/<role>.md",
    "Agent prompt content:",
    "spawn_agent",
    "wait_agent",
    "close_agent",
    "Codex custom-agent preflight",
    "quiet ensure",
    "Parallel trigger: approved-plan-handoff",
]
missing = [needle for needle in required if needle not in text]
if missing:
    raise SystemExit(f"Codex Ralph adapter missing markers: {missing}")
for forbidden in ("CLAUDE_CODE_ONLY_RALPH_ADAPTER", "docs/platforms/claude-code-ralph.md", "@agent-oh-no-harness:<agent>"):
    if forbidden in text:
        raise SystemExit(f"Codex Ralph adapter leaked Claude marker: {forbidden}")
for forbidden in ("Preflight output:", "installed:", "unchanged:"):
    if forbidden in text:
        raise SystemExit(f"Codex Ralph adapter leaked verbose preflight output: {forbidden}")
PY

  local hook_agent_count
  hook_agent_count="$(find "$CODEX_HOME/agents" -maxdepth 1 -type f -name 'oh-no-*.toml' | wc -l | tr -d ' ')"
  [[ "$hook_agent_count" == "9" ]] || fail "Codex Ralph adapter preflight installed ${hook_agent_count} user-scope agents, expected 9"
  grep -q 'oh-no-harness-installed-plugin-version:' "$CODEX_HOME/agents/oh-no-code-reviewer.toml" \
    || fail "Codex Ralph adapter preflight did not write installed plugin version marker"

  local manifest_version
  manifest_version="$(json_value version)"
  {
    printf '# oh-no-harness-installed-plugin-version: 0.0.0\n'
    printf '# oh-no-harness-generated-codex-agent\n'
    printf 'name = "oh-no-code-reviewer"\n'
    printf 'description = "stale generated file from hook test"\n'
    printf 'developer_instructions = "stale"\n'
  } >"$CODEX_HOME/agents/oh-no-code-reviewer.toml"
  printf '{"hook_event_name":"UserPromptSubmit","prompt":"Run ralph on the approved plan."}\n' >"$temp_data/ralph-stale-preflight-prompt.json"
  PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/ralph-stale-preflight-prompt.json" >"$temp_data/ralph-stale-preflight-adapter.json"
  grep -q "oh-no-harness-installed-plugin-version: ${manifest_version}" "$CODEX_HOME/agents/oh-no-code-reviewer.toml" \
    || fail "Codex Ralph adapter preflight did not refresh stale installed plugin version marker"
  grep -q '# Code Reviewer Agent' "$CODEX_HOME/agents/oh-no-code-reviewer.toml" \
    || fail "Codex Ralph adapter preflight did not refresh stale installed agent prompt"

  local blocked_codex_home
  blocked_codex_home="$temp_data/codex-home-blocked"
  mkdir -p "$blocked_codex_home/agents"
  printf 'user owned\n' >"$blocked_codex_home/agents/oh-no-code-reviewer.toml"
  printf '{"hook_event_name":"UserPromptSubmit","prompt":"Run ralph on the approved plan."}\n' >"$temp_data/ralph-blocked-preflight-prompt.json"
  CODEX_HOME="$blocked_codex_home" PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/ralph-blocked-preflight-prompt.json" >"$temp_data/ralph-blocked-preflight-adapter.json"
  "$PYTHON_BIN" - "$temp_data/ralph-blocked-preflight-adapter.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = data.get("hookSpecificOutput", {}).get("additionalContext", "")
required = [
    "CODEX_ONLY_RALPH_ADAPTER",
    "Codex custom-agent preflight: failed",
    "oh-no-* custom-agent dispatch remains required",
    "confirmed custom-agent unavailability",
]
missing = [needle for needle in required if needle not in text]
if missing:
    raise SystemExit(f"Codex blocked preflight did not preserve fallback context: {missing}")
PY
  [[ "$(cat "$blocked_codex_home/agents/oh-no-code-reviewer.toml")" == "user owned" ]] \
    || fail "Codex Ralph adapter preflight overwrote an unmarked user-owned agent file"

  printf '{"hook_event_name":"UserPromptSubmit","prompt":"Use oh-no-harness:ralph with Parallel trigger: approved-plan-handoff"}\n' >"$temp_data/ralph-approved-handoff-prompt.json"
  PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/ralph-approved-handoff-prompt.json" >"$temp_data/ralph-approved-handoff-adapter.json"
  "$PYTHON_BIN" - "$temp_data/ralph-approved-handoff-adapter.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = data.get("hookSpecificOutput", {}).get("additionalContext", "")
required = ["CODEX_ONLY_RALPH_ADAPTER", "Parallel trigger: approved-plan-handoff"]
missing = [needle for needle in required if needle not in text]
if missing:
    raise SystemExit(f"Codex approved-plan-handoff Ralph adapter missing markers: {missing}")
PY

  printf '{"hook_event_name":"UserPromptSubmit","prompt":"What does Parallel trigger: approved-plan-handoff mean?"}\n' >"$temp_data/approved-handoff-discussion-prompt.json"
  PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/approved-handoff-discussion-prompt.json" >"$temp_data/approved-handoff-discussion.out"
  if [[ -s "$temp_data/approved-handoff-discussion.out" ]]; then
    fail "Ralph adapter emitted context for marker-only Codex prompt"
  fi

  discussion_index=0
  for discussion_prompt in \
    "What is oh-no-harness:ralph?" \
    "Explain oh-no-harness:ralph before I choose it." \
    "What does Ralph do in the final review step?" \
    "Review the current diff, especially the ralph hook adapter." \
    "Compare ralplan and ralph before implementation." \
    "Should I run ralph?" \
    "Do not run ralph yet." \
    "When would you run ralph?" \
    "Can you explain how to run ralph?" \
    "ralph 로 진행하는 방법 알려줘" \
    "ralph로 구현하는 방법 알려줘" \
    "랄프로 진행하는 방법 알려줘"; do
    discussion_index=$((discussion_index + 1))
    printf '{"hook_event_name":"UserPromptSubmit","prompt":"%s"}\n' "$discussion_prompt" >"$temp_data/ralph-discussion-$discussion_index.json"
    PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
      <"$temp_data/ralph-discussion-$discussion_index.json" >"$temp_data/ralph-discussion-$discussion_index.out"
    if [[ -s "$temp_data/ralph-discussion-$discussion_index.out" ]]; then
      fail "Ralph adapter emitted context for generic Codex Ralph discussion prompt $discussion_index"
    fi
  done

  printf '{"hook_event_name":"UserPromptSubmit","prompt":"Please run ralph now."}\n' >"$temp_data/ralph-please-run-prompt.json"
  PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/ralph-please-run-prompt.json" >"$temp_data/ralph-please-run-adapter.json"
  "$PYTHON_BIN" - "$temp_data/ralph-please-run-adapter.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = data.get("hookSpecificOutput", {}).get("additionalContext", "")
if "CODEX_ONLY_RALPH_ADAPTER" not in text:
    raise SystemExit("Codex explicit please-run Ralph prompt did not inject adapter")
PY

  printf '{"hook_event_name":"UserPromptSubmit","prompt":"ralph 로 구현해줘"}\n' >"$temp_data/ralph-korean-implementation-prompt.json"
  PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/ralph-korean-implementation-prompt.json" >"$temp_data/ralph-korean-implementation-adapter.json"
  "$PYTHON_BIN" - "$temp_data/ralph-korean-implementation-adapter.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = data.get("hookSpecificOutput", {}).get("additionalContext", "")
if "CODEX_ONLY_RALPH_ADAPTER" not in text:
    raise SystemExit("Codex Korean Ralph implementation prompt did not inject adapter")
PY

  printf '{"hook_event_name":"UserPromptSubmit","prompt":"ralph 로 진행해줘"}\n' >"$temp_data/ralph-korean-progress-prompt.json"
  PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/ralph-korean-progress-prompt.json" >"$temp_data/ralph-korean-progress-adapter.json"
  "$PYTHON_BIN" - "$temp_data/ralph-korean-progress-adapter.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = data.get("hookSpecificOutput", {}).get("additionalContext", "")
if "CODEX_ONLY_RALPH_ADAPTER" not in text:
    raise SystemExit("Codex Korean Ralph progress prompt did not inject adapter")
PY

  printf '{"hook_event_name":"UserPromptSubmit","prompt":"랄프로 구현해줘"}\n' >"$temp_data/ralph-hangul-implementation-prompt.json"
  PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/ralph-hangul-implementation-prompt.json" >"$temp_data/ralph-hangul-implementation-adapter.json"
  "$PYTHON_BIN" - "$temp_data/ralph-hangul-implementation-adapter.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = data.get("hookSpecificOutput", {}).get("additionalContext", "")
if "CODEX_ONLY_RALPH_ADAPTER" not in text:
    raise SystemExit("Codex Hangul Ralph implementation prompt did not inject adapter")
PY

  printf '{"hook_event_name":"UserPromptSubmit","prompt":"oh-no-harness:ralph implement the approved plan"}\n' >"$temp_data/ralph-direct-command-prompt.json"
  PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/ralph-direct-command-prompt.json" >"$temp_data/ralph-direct-command-adapter.json"
  "$PYTHON_BIN" - "$temp_data/ralph-direct-command-adapter.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = data.get("hookSpecificOutput", {}).get("additionalContext", "")
if "CODEX_ONLY_RALPH_ADAPTER" not in text:
    raise SystemExit("Codex direct oh-no-harness:ralph command did not inject adapter")
PY

  printf '{"hook_event_name":"UserPromptSubmit","prompt":"Review the approved plan, then run ralph on it"}\n' >"$temp_data/ralph-review-then-run-prompt.json"
  PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/ralph-review-then-run-prompt.json" >"$temp_data/ralph-review-then-run-adapter.json"
  "$PYTHON_BIN" - "$temp_data/ralph-review-then-run-adapter.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = data.get("hookSpecificOutput", {}).get("additionalContext", "")
if "CODEX_ONLY_RALPH_ADAPTER" not in text:
    raise SystemExit("Codex review-then-run Ralph prompt did not inject adapter")
PY

  printf '{"hook_event_name":"UserPromptSubmit","prompt":"Explain the repository layout."}\n' >"$temp_data/non-ralph-prompt.json"
  PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/non-ralph-prompt.json" >"$temp_data/non-ralph-adapter.out"
  if [[ -s "$temp_data/non-ralph-adapter.out" ]]; then
    fail "Ralph adapter emitted context for a non-Ralph Codex prompt"
  fi

  if [[ "$had_codex_home" == "1" ]]; then
    export CODEX_HOME="$previous_codex_home"
  else
    unset CODEX_HOME
  fi
  rm -rf "$temp_data"
  ok "Codex hooks inject only Codex-specific Ralph context"
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

  log "Registering marketplace through Codex CLI"
  mkdir -p "$RUN_DIR" "$CODEX_HOME_DIR"
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
    assert proc.stdout is not None
    with log_path.open("w", encoding="utf-8") as log:
        for line in proc.stdout:
            log.write(line)
            log.flush()
            stdout_queue.put(line)
    stdout_queue.put(None)


def read_stderr() -> None:
    assert proc.stderr is not None
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

if proc.stdin:
    proc.stdin.close()
try:
    proc.wait(timeout=10)
except subprocess.TimeoutExpired:
    proc.terminate()
    proc.wait(timeout=5)

print(f"ok - Codex CLI marketplace add plus /plugins lists and installs {plugin_id} from {marketplace_source}")
PY
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

live_prompt_for_skill() {
  case "$1" in
    using-oh-no-harness)
      printf 'Use the oh-no-harness:using-oh-no-harness skill. Smoke test only. Do not edit files. Reply with exactly OH_NO_CODEX_SKILL_OK using-oh-no-harness.'
      ;;
    interview)
      printf 'Use the oh-no-harness:interview skill. Smoke test only. Do not edit files. Reply with exactly OH_NO_CODEX_SKILL_OK interview.'
      ;;
    ralplan)
      printf 'Use the oh-no-harness:ralplan skill. Smoke test only. Do not edit files. Reply with exactly OH_NO_CODEX_SKILL_OK ralplan.'
      ;;
    ralph)
      printf 'Use the oh-no-harness:ralph skill. Smoke test only. Do not edit files. Reply with exactly OH_NO_CODEX_SKILL_OK ralph.'
      ;;
    ultrawork)
      printf 'Use the oh-no-harness:ultrawork skill. Smoke test only. Do not edit files. Reply with exactly OH_NO_CODEX_SKILL_OK ultrawork.'
      ;;
    auto-routing)
      printf 'Use the oh-no-harness:auto-routing skill. Smoke test only. Do not edit files. Reply with exactly OH_NO_CODEX_SKILL_OK auto-routing.'
      ;;
    test-driven-development)
      printf 'Use the oh-no-harness:test-driven-development skill for an explicit TDD/test-first smoke request. Smoke test only. Do not edit files. Reply with exactly OH_NO_CODEX_SKILL_OK test-driven-development.'
      ;;
    simplify)
      printf 'Use the oh-no-harness:simplify skill for reuse, simplification, efficiency, and altitude cleanup. Smoke test only. Do not edit files. Reply with exactly OH_NO_CODEX_SKILL_OK simplify.'
      ;;
    verification-before-completion)
      printf 'Use the oh-no-harness:verification-before-completion skill. Smoke test only. Do not edit files. Reply with exactly OH_NO_CODEX_SKILL_OK verification-before-completion.'
      ;;
    systematic-debugging)
      printf 'Use the oh-no-harness:systematic-debugging skill. Smoke test only. Do not edit files. Reply with exactly OH_NO_CODEX_SKILL_OK systematic-debugging.'
      ;;
    fusion-rescue)
      printf 'Use the oh-no-harness:fusion-rescue skill. Smoke test only. Do not edit files. Reply with exactly OH_NO_CODEX_SKILL_OK fusion-rescue.'
      ;;
    *)
      fail "No live prompt for skill: $1"
      ;;
  esac
}

run_live_skill_test() {
  local skill="$1"
  local out_file="$RUN_DIR/${skill}.txt"
  local log_file="$RUN_DIR/${skill}.log"
  local prompt
  prompt="$(live_prompt_for_skill "$skill")"

  # `git worktree add` writes Git metadata under `.git/refs` and `.git/worktrees`;
  # Codex workspace-write sandbox may block those writes even in this disposable repo.
  local cmd=(
    "$CODEX_BIN"
    --ask-for-approval never
    exec
    --cd "$PLUGIN_ROOT"
    --sandbox read-only
    --skip-git-repo-check
    --output-last-message "$out_file"
  )

  if [[ -n "$LIVE_MODEL" ]]; then
    cmd+=(--model "$LIVE_MODEL")
  fi

  cmd+=("$prompt")

  run_codex_live_command "$CODEX_HOME_DIR" "${cmd[@]}" >"$log_file" 2>&1

  "$PYTHON_BIN" - "$out_file" "$skill" <<'PY'
import sys

path, skill = sys.argv[1], sys.argv[2]
text = open(path, "r", encoding="utf-8").read()
expected = f"OH_NO_CODEX_SKILL_OK {skill}"
if expected not in text:
    raise SystemExit(f"{skill} live smoke did not return marker {expected!r}; got {text!r}")
print(f"ok - live Codex skill smoke: {skill}")
PY
}

run_live_tests() {
  if [[ "$RUN_LIVE" != "1" ]]; then
    log "Skipping live Codex skill smoke tests"
    printf 'Run with --live or OH_NO_LIVE=1 to invoke codex exec smoke tests.\n' >&2
    return
  fi

  log "Running live Codex skill smoke tests"
  mkdir -p "$RUN_DIR"
  for skill in "${PUBLIC_SKILLS[@]}"; do
    run_live_skill_test "$skill"
  done
  ok "live outputs saved under ${RUN_DIR#$MARKETPLACE_ROOT/}"
}

deep_prompt_for_skill() {
  case "$1" in
    interview)
      printf 'Use the oh-no-harness:interview skill. Deep smoke test only. Read the invariants, state machine, snapshot, company-context rules, and Socratic guidance in the wrapper. Do not edit files. Return when company context should be considered, whether it is advisory or executable, whether remote/global systems should be searched for it, and the names of the Socratic guidance sections for question routing, answer capture, and the Spec Closure Gate including acceptance criteria, goal restatement, and machine-consumable requirements. End with OH_NO_CODEX_DEEP_OK interview.'
      ;;
    ralplan)
      printf 'Use the oh-no-harness:ralplan skill. Deep smoke test only. Read the invariants, Direction Contract, planning-run snapshot, state machine, proportional test design, mode selection, and execution profile. Do not edit files. Return the Direction Contract fields and single canonical schema owner, loop limit, approval status term, conditional Analyst -> Planner -> Plan-Reviewer ordering rule, STANDARD single-reviewer rule, named THOROUGH paired-review trigger, blocking-findings-only re-review rule, required Blocking basis field, APPROVE exact-draft freeze and non-blocking optional-follow-up rule, process budget, Ralph execution profile, project-local worktree path, and trigger-loaded Codex dispatch rule. End with OH_NO_CODEX_DEEP_OK ralplan.'
      ;;
    ralph)
      printf 'Use the oh-no-harness:ralph skill. Deep smoke test only. Read the wrapper invariants, state machine, snapshot, and gates. Do not edit files. Return the Direction Contract, the four phases and three outcomes, execution mode decision heading, mode-gated dispatch heading, parallel trigger, canonical verification ledger, STANDARD single-reviewer rule, named THOROUGH paired-review trigger, cumulative per-story Process Budget timing, final Diff-Budget exactly-once-before-Review timing, proportional cleanup rule, default worktree path, and TDD internal mid-loop discipline boundary including that TDD is not a top-level implementation route. End with OH_NO_CODEX_DEEP_OK ralph.'
      ;;
    ultrawork)
      printf 'Use the oh-no-harness:ultrawork skill. Deep smoke test only. Read the wrapper invariants, heartbeat, state machine, and phase procedures, following the linked phase skills where needed. Do not edit files. Return the spec artifact path from clarification, the planning loop limit, the project-local automatic worktree path, the Ultrawork auto-approval rule after interview/spec approval, how ralplan approval becomes a recorded internal execution approval, how ralph is invoked with the Ultrawork-approved plan, the required execution mode source in the final report, and the cleanup/final-verification heading reached through execution. End with OH_NO_CODEX_DEEP_OK ultrawork.'
      ;;
    simplify)
      printf 'Use the oh-no-harness:simplify skill. Deep smoke test only. Read the shared simplify core and Codex platform docs. Do not edit files. Return the Required Behavior Lock and Phase headings; the LIGHT/STANDARD combined-scan default; the named THOROUGH trigger for four independent Reuse, Simplification, Efficiency, and Altitude passes; batch/fallback behavior only after that trigger; and the false-positive or behavior-changing skip rule. End with OH_NO_CODEX_DEEP_OK simplify.'
      ;;
    *)
      fail "No deep live prompt for skill: $1"
      ;;
  esac
}

assert_deep_output() {
  "$PYTHON_BIN" - "$1" "$2" <<'PY'
import sys

SEMANTIC_VARIANCE_EXIT = 88


def semantic_failure(message):
    print(message, file=sys.stderr)
    raise SystemExit(SEMANTIC_VARIANCE_EXIT)


path, skill = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as handle:
    text = handle.read()
if not text.strip():
    raise SystemExit(f"{skill} deep smoke returned an empty output artifact")
text_lower = text.lower()
text_plain = text_lower.translate(str.maketrans("", "", "`*_"))

expected = {
    "interview": [
        "OH_NO_CODEX_DEEP_OK interview",
        "advisory",
        "Question Routing",
        "Answer Capture",
        "Spec Closure Gate",
        "Acceptance criteria",
        "Goal restatement",
        "Machine-consumable",
    ],
    "ralplan": [
        "OH_NO_CODEX_DEEP_OK ralplan",
        "pending approval",
        "Direction Contract",
        "Overall Ralph mode",
        "Task sizing",
        "Execution profile",
        "Analyst",
        "Planner",
        "single-reviewer",
        "named THOROUGH",
        "process budget",
        ".oh-no/worktrees/<task-slug>",
    ],
    "ralph": [
        "OH_NO_CODEX_DEEP_OK ralph",
        "Direction Contract",
        "PREPARE",
        "FINALIZE",
        "Required Execution Mode",
        "Mode-Gated Agent Dispatch",
        "STANDARD",
        "THOROUGH",
        "Parallel trigger",
        "Acceptance-to-evidence ledger",
        "single-reviewer",
        "paired-review",
        "combined scan",
        ".oh-no/worktrees/<task-slug>",
        "test-driven-development",
        "internal mid-loop",
    ],
    "ultrawork": [
        "OH_NO_CODEX_DEEP_OK ultrawork",
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
        "OH_NO_CODEX_DEEP_OK simplify",
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
}

missing = [needle for needle in expected[skill] if needle.lower() not in text_lower]
if missing:
    semantic_failure(f"{skill} deep smoke missing markers: {missing}; got {text!r}")

if skill == "ralph" and not (
    "not a top-level implementation" in text_lower
    or "not the top-level route" in text_lower
    or "not a top-level route" in text_lower
    or ("not" in text_lower and "top-level" in text_lower and "implementation" in text_lower)
):
    semantic_failure(f"{skill} deep smoke missing TDD top-level route boundary; got {text!r}")

def terms_appear_in_order(*terms: str) -> bool:
    cursor = -1
    for term in terms:
        cursor = text_lower.find(term, cursor + 1)
        if cursor == -1:
            return False
    return True

if skill == "interview" and not (
    "already available" in text_lower or "already in session" in text_lower
    or "already in-session" in text_lower
    or "already in the session" in text_lower
    or "already present" in text_lower
):
    semantic_failure(f"{skill} deep smoke missing company-context availability marker; got {text!r}")

if skill == "interview" and not (
    "do not search remote" in text_lower
    or "should not be searched" in text_lower
    or ("remote" in text_lower and "not" in text_lower and "search" in text_lower)
):
    semantic_failure(f"{skill} deep smoke missing remote-search policy marker; got {text!r}")

plan_reviewer_token = "plan-reviewer" if "plan-reviewer" in text_lower else "plan reviewer"

if skill == "ralplan" and not (
    "analyst" in text_lower
    and "planner" in text_lower
    and plan_reviewer_token in text_lower
    and (
        f"analyst -> planner -> {plan_reviewer_token}" in text_lower
        or f"analyst, planner, {plan_reviewer_token}" in text_lower
        or f"analyst, planner, and {plan_reviewer_token}" in text_lower
        or (
            terms_appear_in_order("analyst", "planner", plan_reviewer_token)
            and ("first" in text_lower or "then" in text_lower or "sequential" in text_lower)
        )
        or (
            "analyst first" in text_lower
            and "planner second" in text_lower
            and f"{plan_reviewer_token} third" in text_lower
        )
    )
):
    semantic_failure(f"{skill} deep smoke missing full consensus ordering marker; got {text!r}")

if skill == "ralplan" and not (
    plan_reviewer_token in text_lower
    and (
        "single" in text_lower
        or "one dispatch" in text_lower
        or "one review dispatch" in text_lower
    )
    and "blocking" in text_lower
    and (
        "re-review" in text_lower
        or "re-reviewed" in text_lower
        or "review again" in text_lower
        or "second review" in text_lower
    )
):
    semantic_failure(f"{skill} deep smoke missing Plan-Reviewer single-dispatch/blocking-findings re-review marker; got {text!r}")

if skill == "ralplan" and not (
    "process budget" in text_lower and "named thorough" in text_lower
):
    semantic_failure(f"{skill} deep smoke missing proportional process-budget marker; got {text!r}")

if skill == "ralplan" and not (
    "blocking basis" in text_lower
    and "non-blocking" in text_lower
    and "optional" in text_lower
    and "approve" in text_lower
    and ("exact reviewed" in text_lower or "exact draft" in text_lower)
):
    semantic_failure(f"{skill} deep smoke missing exact-draft freeze/blocking-basis marker; got {text!r}")

if skill == "ralph" and not (
    "process budget" in text_lower
    and "cumulative" in text_lower
    and ("per-story" in text_lower or "per story" in text_lower)
    and "diff-budget" in text_lower
    and ("exactly once" in text_lower or "one time" in text_lower)
    and "before" in text_lower
    and "review" in text_lower
):
    semantic_failure(f"{skill} deep smoke missing process/diff budget timing marker; got {text!r}")

if skill in ("ralplan", "ultrawork") and not (
    "2 loops" in text_plain
    or "two loops" in text_plain
    or "2 complete loops" in text_plain
    or "two complete loops" in text_plain
    or "at most 2" in text_plain
    or "at most two" in text_plain
    or "max 2" in text_plain
    or "maximum of 2" in text_plain
    or "maximum of two" in text_plain
):
    semantic_failure(f"{skill} deep smoke missing 2-loop planning limit marker; got {text!r}")

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
}

if skill in linked_doc_markers and not all(marker.lower() in text_lower for marker in linked_doc_markers[skill]):
    semantic_failure(f"{skill} deep smoke missing linked-doc marker; got {text!r}")

if skill == "simplify" and not (
    (
        "standing" in text_lower
        and "authorization" in text_lower
        and "per-run" in text_lower
        and "subagent" in text_lower
    )
    and (
        ("host" in text_lower and "policy" in text_lower)
        or "subagent dispatch is unavailable" in text_lower
        or ("dispatch" in text_lower and "unavailable" in text_lower)
    )
):
    semantic_failure(f"{skill} deep smoke missing standing authorization or host dispatch/fallback policy marker; got {text!r}")

print(f"ok - deep Codex linked-doc smoke: {skill}")
PY
}

run_deep_live_skill_test() {
  local skill="$1"
  local out_file="$RUN_DIR/deep-${skill}.txt"
  local log_file="$RUN_DIR/deep-${skill}.log"
  local prompt
  prompt="$(deep_prompt_for_skill "$skill")"

  local cmd=(
    "$CODEX_BIN"
    --ask-for-approval never
    exec
    --cd "$PLUGIN_ROOT"
    --sandbox read-only
    --skip-git-repo-check
    --output-last-message "$out_file"
  )

  if [[ -n "$LIVE_MODEL" ]]; then
    cmd+=(--model "$LIVE_MODEL")
  fi

  cmd+=("$prompt")
  run_codex_live_command "$CODEX_HOME_DIR" "${cmd[@]}" >"$log_file" 2>&1
  # Only semantic marker/paraphrase variance is non-gating. Missing, empty, or
  # malformed artifacts and command/tool failures remain hard failures.
  local deep_rc=0
  assert_deep_output "$out_file" "$skill" || deep_rc=$?
  if [[ "$deep_rc" == "88" ]]; then
    log "WARN: live deep-smoke for $skill flagged paraphrase/dereference variance (non-gating)"
  elif [[ "$deep_rc" != "0" ]]; then
    return "$deep_rc"
  fi
}

run_deep_live_tests() {
  if [[ "$RUN_DEEP_LIVE" != "1" ]]; then
    log "Skipping deep Codex linked-doc smoke tests"
    printf 'Run with --deep-live or OH_NO_DEEP_LIVE=1 to verify linked support docs are read.\n' >&2
    return
  fi

  log "Running deep Codex linked-doc smoke tests"
  mkdir -p "$RUN_DIR"
  for skill in interview ralplan ralph ultrawork simplify; do
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

run_natural_prompt_guard_offline_test() {
  log "Running offline Codex natural-prompt causality guard fixtures"
  local allowed_prompt forbidden
  allowed_prompt="Read the repository facts, assess the requested outcome, and summarize the evidence without editing files."
  assert_natural_prompt_has_no_explicit_subagent_terms "allowed-fixture" "$allowed_prompt"

  for forbidden in \
    "subagent" "sub-agent" "spawn" "delegate" "delegation" "parallel agent" \
    "worker" "agent_type" "role:" "wave" "wait results" "wait_agent" \
    "close_agent" "clean up" "cleanup" "lifecycle"; do
    if (
      assert_natural_prompt_has_no_explicit_subagent_terms \
        "forbidden-fixture" "Read facts, then ${forbidden}, then summarize."
    ) >/dev/null 2>&1; then
      fail "Codex natural-prompt guard missed forbidden fixture: ${forbidden}"
    fi
  done
  ok "Codex natural-prompt guard accepts outcome-only prose and rejects dispatch mechanics"
}

assert_natural_spawn_smoke() {
  local out_file="$1"
  local err_file="$2"
  local expected_count="$3"
  local success_marker="$4"
  local label="$5"

  "$PYTHON_BIN" - "$out_file" "$err_file" "$expected_count" "$success_marker" "$label" "$CODEX_HOME_DIR" <<'PY'
import json
import sys
from pathlib import Path

out_path, err_path, expected_count, success_marker, label, live_home = sys.argv[1:7]
expected_count = int(expected_count)

def collect_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(item) for item in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(item) for item in value)
    return ""

with open(err_path, "r", encoding="utf-8") as fh:
    err_text = fh.read()
if (
    "spawn failed" in err_text.lower()
    or "agent thread limit reached" in err_text.lower()
    or "full-history forked agents inherit" in err_text.lower()
    or "provide either message or items" in err_text.lower()
):
    raise SystemExit(f"{label} natural smoke saw spawn failure in stderr: {err_text[:2000]!r}")

spawn_receivers = []
failed_spawns = []
receiver_ids = set()
waited_receivers = set()
wait_result_by_receiver = {}
closed_receivers = set()
marker = False
all_text_parts = []
parent_thread_id = None

with open(out_path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        if data.get("type") == "thread.started":
            parent_thread_id = data.get("thread_id") or parent_thread_id
        item = data.get("item") or {}
        event_text = collect_text(data)
        if item.get("type") == "agent_message":
            all_text_parts.append(event_text)
        if success_marker in event_text:
            marker = True
        if item.get("type") != "collab_tool_call":
            continue
        tool = item.get("tool")
        status = item.get("status")
        if tool == "spawn_agent" and status == "failed":
            failed_spawns.append((index, collect_text(item)[:2000]))
        if tool == "spawn_agent" and status == "completed":
            receivers = item.get("receiver_thread_ids") or []
            spawn_receivers.append((index, tuple(receivers)))
            receiver_ids.update(receivers)
        if status == "completed" and tool in {"wait", "wait_agent", "close_agent"}:
            text = collect_text(item)
            mentioned = set(item.get("receiver_thread_ids") or [])
            mentioned.update(receiver for receiver in receiver_ids if receiver in text)
            mentioned.update(
                receiver for receiver in (item.get("agents_states") or {})
                if receiver in receiver_ids
            )
            if tool in {"wait", "wait_agent"}:
                for receiver in mentioned:
                    state = (item.get("agents_states") or {}).get(receiver) or {}
                    if state.get("status") == "completed" and state.get("message"):
                        waited_receivers.add(receiver)
                        wait_result_by_receiver.setdefault(receiver, str(state.get("message")))
            if tool == "close_agent":
                closed_receivers.update(mentioned)

if failed_spawns:
    raise SystemExit(f"{label} natural smoke saw failed spawn_agent calls: {failed_spawns!r}")
if len(spawn_receivers) < expected_count:
    if spawn_receivers:
        raise SystemExit(
            f"{label} natural smoke emitted only a partial collab event stream: {spawn_receivers!r}"
        )
    if not parent_thread_id:
        raise SystemExit(f"{label} natural smoke lacked both collab events and a parent thread id")
    typed_children = []
    sessions_root = Path(live_home) / "sessions"
    for transcript_path in sessions_root.rglob("*.jsonl"):
        meta = None
        completed = False
        final_output = ""
        for transcript_line in transcript_path.read_text(encoding="utf-8", errors="replace").splitlines():
            if not transcript_line.strip():
                continue
            candidate = json.loads(transcript_line)
            payload = candidate.get("payload") or {}
            if candidate.get("type") == "session_meta":
                meta = payload
            elif candidate.get("type") == "event_msg" and payload.get("type") == "task_complete":
                completed = True
                final_output = collect_text(payload.get("last_agent_message")) or final_output
            elif (
                candidate.get("type") == "response_item"
                and payload.get("type") == "message"
                and payload.get("role") == "assistant"
            ):
                final_output = collect_text(payload.get("content")) or final_output
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
        if parent != parent_thread_id or not isinstance(agent_role, str) or not agent_role.startswith("oh-no-"):
            continue
        if not completed or not final_output:
            raise SystemExit(
                f"{label} natural smoke typed child {agent_role} lacked completed final output"
            )
        typed_children.append((agent_role, meta.get("id") or meta.get("session_id")))
    if len(typed_children) < expected_count:
        raise SystemExit(
            f"{label} natural smoke expected at least {expected_count} typed child sessions, "
            f"got {typed_children!r}"
        )
    if not marker:
        raise SystemExit(f"{label} natural smoke typed children completed but parent omitted {success_marker}")
    print(f"ok - {label} natural smoke proved by typed child transcripts (collab events unavailable)")
    raise SystemExit(0)
if len(receiver_ids) < expected_count:
    raise SystemExit(f"{label} natural smoke expected at least {expected_count} receiver threads, got {receiver_ids!r}")
missing_wait_results = sorted(receiver_ids - waited_receivers)
missing_closes = sorted(receiver_ids - closed_receivers)
all_text = "\n".join(all_text_parts)
if missing_wait_results:
    raise SystemExit(
        f"{label} natural smoke did not capture final wait_agent results for receivers: {missing_wait_results!r}"
    )
if missing_closes and "close/cleanup was not available" not in all_text.lower():
    raise SystemExit(
        f"{label} natural smoke left receivers without close evidence or an unavailable-cleanup record: "
        f"{missing_closes!r}"
    )
if not marker:
    raise SystemExit(f"{label} natural smoke did not return success marker {success_marker}")

print(f"ok - {label} natural smoke spawned via SessionStart standing authorization")
PY
}

natural_session_start_prompt_for_skill() {
  case "$1" in
    interview)
      cat <<'PROMPT'
Use the oh-no-harness:interview skill. Read-only natural SessionStart smoke test. Vague request: make Codex live natural smoke coverage stronger for this plugin checkout. Before asking the user a question, gather the necessary repository facts from ../../scripts/test-codex-plugin.sh. Do not edit files or run the test script. End with OH_NO_CODEX_INTERVIEW_NATURAL_OK and summarize the facts that informed the first question.
PROMPT
      ;;
    ultrawork)
      cat <<'PROMPT'
Use the oh-no-harness:ultrawork skill. Read-only natural SessionStart smoke test. Approved synthetic low-risk internal goal: assess whether ../../scripts/test-codex-plugin.sh identifies the expected natural smoke coverage surface for a local maintainer note. This message is the complete approved requirements source. Scope only the current natural smoke cases; success is a read-only summary of repository facts, the smallest planning direction, and final evidence status. No product, architecture, public-contract, security, migration, concurrency, or release decision is in scope. Perform a dry run only: do not create artifacts, edit files, or execute changes. End with OH_NO_CODEX_ULTRAWORK_NATURAL_OK and summarize repository facts, planning readiness, and final evidence.
PROMPT
      ;;
    systematic-debugging)
      cat <<'PROMPT'
Use the oh-no-harness:systematic-debugging skill. Read-only natural SessionStart smoke test. Synthetic failure: a live natural smoke check for ../../scripts/test-codex-plugin.sh returned no marker even though the output file existed. Diagnose the likely cause and assess what evidence would verify it. Do not edit files or run the test script. End with OH_NO_CODEX_SYSTEMATIC_DEBUGGING_NATURAL_OK and summarize the diagnosis and evidence status.
PROMPT
      ;;
    verification-before-completion)
      cat <<'PROMPT'
Use the oh-no-harness:verification-before-completion skill. Read-only natural SessionStart smoke test. Verify the claim that ../../scripts/test-codex-plugin.sh exposes verification-before-completion in PUBLIC_SKILLS and has live smoke plumbing that another lane can extend. Do not edit files or run the test script. End with OH_NO_CODEX_VERIFICATION_NATURAL_OK and summarize the evidence and any skipped checks.
PROMPT
      ;;
    *)
      fail "No natural SessionStart prompt for skill: $1"
      ;;
  esac
}

assert_natural_role_spawn_smoke() {
  local out_file="$1"
  local err_file="$2"
  local success_marker="$3"
  local label="$4"
  local role_marker_specs="$5"
  local forbidden_markers="${6:-}"
  local role_order_mode="${7:-exact}"
  local minimum_role_count="${8:-1}"

  "$PYTHON_BIN" - "$out_file" "$err_file" "$success_marker" "$label" "$role_marker_specs" "$forbidden_markers" "$CODEX_HOME_DIR" "$role_order_mode" "$minimum_role_count" <<'PY'
import json
import re
import sys
from pathlib import Path

(
    out_path,
    err_path,
    success_marker,
    label,
    role_marker_specs,
    forbidden_markers,
    live_home,
    role_order_mode,
    minimum_role_count,
) = sys.argv[1:10]
minimum_role_count = int(minimum_role_count)
role_markers = []
optional_roles = set()
for spec in role_marker_specs.split(","):
    if not spec:
        continue
    role, marker = spec.split(":", 1)
    if role.endswith("?"):
        role = role[:-1]
        optional_roles.add(role)
    role_markers.append((role, marker))
expected_roles = [role for role, _ in role_markers]
required_roles = [role for role in expected_roles if role not in optional_roles]
forbidden = [marker for marker in forbidden_markers.split(",") if marker]

def collect_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(item) for item in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(item) for item in value)
    return ""

def has_marker_line(text, marker):
    return re.search(rf"(?im)^\s*Marker:\s*{re.escape(marker)}\s*$", text) is not None

def mentioned_receivers(item, known_receivers):
    text = collect_text(item)
    mentioned = set(item.get("receiver_thread_ids") or [])
    mentioned.update(receiver for receiver in known_receivers if receiver in text)
    mentioned.update(
        receiver for receiver in (item.get("agents_states") or {})
        if receiver in known_receivers
    )
    return mentioned

def receiver_agent_role(receiver):
    sessions_root = Path(live_home) / "sessions"
    session_candidates = list(sessions_root.rglob(f"*{receiver}*.jsonl"))
    if not session_candidates:
        raise SystemExit(f"{label} natural role smoke could not find session transcript for receiver: {receiver}")
    for path in session_candidates:
        with path.open("r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
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
                return payload.get("agent_role") or thread_spawn.get("agent_role")
    raise SystemExit(f"{label} natural role smoke transcript for receiver lacked session_meta: {receiver}")

def command_text_from_event(data):
    item = data.get("item") or {}
    payload = data.get("payload") or {}
    if item.get("type") == "command_execution":
        return str(item.get("command") or "")
    if payload.get("type") == "function_call" and payload.get("name") in {"exec_command", "functions.exec_command"}:
        arguments_text = str(payload.get("arguments") or "")
        try:
            arguments_data = json.loads(arguments_text) if arguments_text else {}
        except json.JSONDecodeError:
            arguments_data = {}
        if isinstance(arguments_data, dict):
            return str(arguments_data.get("cmd") or "")
    return ""

with open(err_path, "r", encoding="utf-8") as fh:
    err_text = fh.read()
if (
    "spawn failed" in err_text.lower()
    or "agent thread limit reached" in err_text.lower()
    or "full-history forked agents inherit" in err_text.lower()
    or "provide either message or items" in err_text.lower()
):
    raise SystemExit(f"{label} natural role smoke saw spawn failure in stderr: {err_text[:2000]!r}")

successful_role_spawns = []
failed_spawns = []
all_spawn_receivers = set()
receiver_to_role = {}
wait_index_by_receiver = {}
wait_result_by_receiver = {}
close_index_by_receiver = {}
marker = False
all_text_parts = []
forbidden_hits = []
pending_receiver_to_role = {}
overlapping_inline_scope_events = []
parent_thread_id = None
delegated_scope_pattern = re.compile(r"(?:\.\./\.\./|/)?scripts/test-codex-plugin\.sh")

with open(out_path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        if data.get("type") == "thread.started":
            parent_thread_id = data.get("thread_id") or parent_thread_id
        item = data.get("item") or {}
        event_text = collect_text(data)
        if item.get("type") == "agent_message":
            all_text_parts.append(event_text)
            if success_marker in event_text:
                marker = True
        command_text = command_text_from_event(data)
        if command_text and pending_receiver_to_role and delegated_scope_pattern.search(command_text):
            overlapping_inline_scope_events.append(
                (index, sorted(pending_receiver_to_role.items()), command_text[:1000])
            )
        if item.get("type") != "collab_tool_call":
            continue
        tool = item.get("tool")
        status = item.get("status")
        if status == "completed" and tool in {"wait", "wait_agent", "close_agent"}:
            receivers = mentioned_receivers(item, all_spawn_receivers)
            if tool in {"wait", "wait_agent"}:
                for receiver in receivers:
                    state = (item.get("agents_states") or {}).get(receiver) or {}
                    if state.get("status") == "completed" and state.get("message"):
                        wait_index_by_receiver.setdefault(receiver, index)
                        wait_result_by_receiver.setdefault(receiver, str(state.get("message")))
                        pending_receiver_to_role.pop(receiver, None)
            if tool == "close_agent":
                for receiver in receivers:
                    close_index_by_receiver.setdefault(receiver, index)
        if tool == "spawn_agent" and status == "failed":
            failed_spawns.append((index, collect_text(item)[:2000]))
        if tool == "spawn_agent" and status == "completed":
            receivers = item.get("receiver_thread_ids") or []
            spawn_text = collect_text(item)
            all_spawn_receivers.update(receivers)
            forbidden_hits.extend(
                (index, forbidden_marker)
                for forbidden_marker in forbidden
                if has_marker_line(spawn_text, forbidden_marker)
            )
            matched = [
                (role, role_marker)
                for role, role_marker in role_markers
                if role_marker and has_marker_line(spawn_text, role_marker)
            ]
            if not matched and len(receivers) == 1:
                actual_agent_role = receiver_agent_role(receivers[0])
                if isinstance(actual_agent_role, str) and actual_agent_role.startswith("oh-no-"):
                    actual_role = actual_agent_role.removeprefix("oh-no-")
                    if actual_role in expected_roles:
                        matched = [(actual_role, dict(role_markers).get(actual_role, ""))]
            if not matched:
                raise SystemExit(
                    f"{label} natural role smoke saw an unexpected successful spawn; "
                    f"line={index} receivers={receivers!r} text={spawn_text[:2000]!r}"
                )
            if len(matched) != 1:
                raise SystemExit(
                    f"{label} natural role smoke expected one role marker per matched spawn; "
                    f"line={index} matches={matched!r} text={spawn_text[:2000]!r}"
                )
            if len(receivers) != 1:
                raise SystemExit(
                    f"{label} natural role smoke matched spawn must have exactly one receiver; "
                    f"line={index} receivers={receivers!r} text={spawn_text[:2000]!r}"
                )
            role, role_marker = matched[0]
            required_lines = []
            if role_marker:
                required_lines = [f"Role: {role}", f"Marker: {role_marker}"]
            missing_lines = [
                required for required in required_lines
                if required.lower() not in spawn_text.lower()
            ]
            if missing_lines:
                raise SystemExit(
                    f"{label} natural role smoke spawn payload missed required role lines: "
                    f"{missing_lines}; text={spawn_text[:2000]!r}"
                )
            successful_role_spawns.append((index, role, receivers[0], spawn_text))
            receiver_to_role[receivers[0]] = role
            pending_receiver_to_role[receivers[0]] = role

if not successful_role_spawns:
    if not parent_thread_id:
        raise SystemExit(f"{label} natural role smoke lacked both collab events and a parent thread id")
    transcript_children = []
    sessions_root = Path(live_home) / "sessions"
    duplicate_role_modes = {"grouped-fanout", "unordered-allowed-fanout"}
    for transcript_path in sessions_root.rglob("*.jsonl"):
        rows = [
            json.loads(line)
            for line in transcript_path.read_text(encoding="utf-8", errors="replace").splitlines()
            if line.strip()
        ]
        meta = next(
            (row.get("payload") or {} for row in rows if row.get("type") == "session_meta"),
            None,
        )
        if not isinstance(meta, dict):
            continue
        source = meta.get("source") if isinstance(meta.get("source"), dict) else {}
        subagent = source.get("subagent") if isinstance(source.get("subagent"), dict) else {}
        thread_spawn = subagent.get("thread_spawn") if isinstance(subagent.get("thread_spawn"), dict) else {}
        parent = meta.get("parent_thread_id") or thread_spawn.get("parent_thread_id")
        agent_role = meta.get("agent_role") or thread_spawn.get("agent_role")
        if parent != parent_thread_id or not isinstance(agent_role, str) or not agent_role.startswith("oh-no-"):
            continue
        role = agent_role.removeprefix("oh-no-")
        if role not in expected_roles:
            raise SystemExit(f"{label} natural role smoke started unexpected typed child role: {role!r}")
        if (
            role_order_mode not in duplicate_role_modes
            and any(child["role"] == role for child in transcript_children)
        ):
            raise SystemExit(f"{label} natural role smoke found duplicate typed child sessions for {role}")
        completed = False
        completion_timestamp = ""
        final_output = ""
        for row in rows:
            payload = row.get("payload") or {}
            if row.get("type") == "event_msg" and payload.get("type") == "task_complete":
                completed = True
                completion_timestamp = row.get("timestamp", "") or completion_timestamp
                final_output = collect_text(payload.get("last_agent_message")) or final_output
            elif (
                row.get("type") == "response_item"
                and payload.get("type") == "message"
                and payload.get("role") == "assistant"
            ):
                final_output = collect_text(payload.get("content")) or final_output
        if not completed or not final_output:
            raise SystemExit(f"{label} natural role smoke typed child {role} lacked completed final output")
        transcript_children.append(
            {
                "role": role,
                "started": meta.get("timestamp", ""),
                "completed": completion_timestamp,
                "output": final_output,
            }
        )
    ordered_children = sorted(transcript_children, key=lambda child: child["started"])
    ordered_roles = [child["role"] for child in ordered_children]
    if len(ordered_roles) < minimum_role_count:
        raise SystemExit(
            f"{label} natural role smoke expected at least {minimum_role_count} typed children, "
            f"got {ordered_roles!r}"
        )
    if role_order_mode != "unordered-allowed-fanout":
        missing_roles = sorted(set(required_roles) - set(ordered_roles))
        if missing_roles:
            raise SystemExit(f"{label} natural role smoke omitted required typed child roles: {missing_roles!r}")
    if role_order_mode == "exact":
        if ordered_roles != expected_roles:
            raise SystemExit(
                f"{label} natural role smoke typed child order differed: "
                f"expected={expected_roles!r} got={ordered_roles!r}"
            )
    elif role_order_mode == "unordered-exact":
        if sorted(ordered_roles) != sorted(expected_roles) or len(ordered_roles) != len(expected_roles):
            raise SystemExit(
                f"{label} natural role smoke typed child roles differed: "
                f"expected={expected_roles!r} got={ordered_roles!r}"
            )
    elif role_order_mode == "ordered-optional":
        if len(set(ordered_roles)) != len(ordered_roles):
            raise SystemExit(
                f"{label} natural role smoke repeated a role in ordered-optional mode: {ordered_roles!r}"
            )
        expected_present_order = [role for role in expected_roles if role in ordered_roles]
        if ordered_roles != expected_present_order:
            raise SystemExit(
                f"{label} natural role smoke optional role order differed: "
                f"allowed={expected_roles!r} got={ordered_roles!r}"
            )
    elif role_order_mode == "grouped-fanout":
        role_groups = []
        for role in ordered_roles:
            if not role_groups or role_groups[-1] != role:
                role_groups.append(role)
        if role_groups != expected_roles:
            raise SystemExit(
                f"{label} natural role smoke typed child groups differed: "
                f"expected={expected_roles!r} got={role_groups!r}"
            )
    elif role_order_mode != "unordered-allowed-fanout":
        raise SystemExit(f"unsupported role_order_mode for {label}: {role_order_mode!r}")
    if not marker:
        raise SystemExit(f"{label} natural role smoke typed children completed but parent omitted {success_marker}")
    print(f"ok - {label} natural role smoke proved by typed child transcripts")
    raise SystemExit(0)

if forbidden_hits:
    raise SystemExit(f"{label} natural role smoke saw forbidden role markers in spawn payloads: {forbidden_hits!r}")
if overlapping_inline_scope_events:
    raise SystemExit(
        f"{label} natural role smoke saw parent inline commands against worker scope while worker results were pending: "
        f"{overlapping_inline_scope_events!r}"
    )

roles_seen = [role for _, role, _, _ in successful_role_spawns]
if len(roles_seen) < minimum_role_count:
    raise SystemExit(
        f"{label} natural role smoke expected at least {minimum_role_count} spawned workers, "
        f"got {roles_seen!r}"
    )
if role_order_mode != "unordered-allowed-fanout":
    missing_roles = sorted(set(required_roles) - set(roles_seen))
    if missing_roles:
        raise SystemExit(
            f"{label} natural role smoke omitted required spawned roles: {missing_roles!r}"
        )
if role_order_mode == "exact":
    if roles_seen != expected_roles:
        raise SystemExit(
            f"{label} natural role smoke expected role order {expected_roles!r}, got {roles_seen!r}; "
            f"spawns={successful_role_spawns!r}"
        )
    for role in expected_roles:
        if roles_seen.count(role) != 1:
            raise SystemExit(f"{label} natural role smoke expected exactly one spawn for {role}, got {roles_seen!r}")
elif role_order_mode == "unordered-exact":
    if sorted(roles_seen) != sorted(expected_roles) or len(roles_seen) != len(expected_roles):
        raise SystemExit(
            f"{label} natural role smoke expected exactly roles {expected_roles!r}, got {roles_seen!r}; "
            f"spawns={successful_role_spawns!r}"
        )
    for role in expected_roles:
        if roles_seen.count(role) != 1:
            raise SystemExit(f"{label} natural role smoke expected exactly one spawn for {role}, got {roles_seen!r}")
elif role_order_mode == "ordered-optional":
    if len(set(roles_seen)) != len(roles_seen):
        raise SystemExit(
            f"{label} natural role smoke repeated a role in ordered-optional mode: {roles_seen!r}"
        )
    expected_present_order = [role for role in expected_roles if role in roles_seen]
    if roles_seen != expected_present_order:
        raise SystemExit(
            f"{label} natural role smoke optional role order differed: "
            f"allowed={expected_roles!r} got={roles_seen!r}; spawns={successful_role_spawns!r}"
        )
elif role_order_mode == "unordered-allowed-fanout":
    pass
elif role_order_mode == "grouped-fanout":
    role_groups = []
    for role in roles_seen:
        if role not in expected_roles:
            raise SystemExit(
                f"{label} natural role smoke saw unexpected role {role!r}; "
                f"expected grouped fan-out roles {expected_roles!r}; spawns={successful_role_spawns!r}"
            )
        if not role_groups or role_groups[-1] != role:
            role_groups.append(role)
    if role_groups != expected_roles:
        raise SystemExit(
            f"{label} natural role smoke expected grouped role order {expected_roles!r}, got groups {role_groups!r} "
            f"from roles {roles_seen!r}; spawns={successful_role_spawns!r}"
        )
    for role in expected_roles:
        if roles_seen.count(role) < 1:
            raise SystemExit(f"{label} natural role smoke expected at least one spawn for {role}, got {roles_seen!r}")
else:
    raise SystemExit(f"unsupported role_order_mode for {label}: {role_order_mode!r}")

for receiver, role in receiver_to_role.items():
    expected_agent_role = f"oh-no-{role}"
    actual_agent_role = receiver_agent_role(receiver)
    if actual_agent_role != expected_agent_role:
        raise SystemExit(
            f"{label} natural role smoke spawned receiver {receiver} with agent_role={actual_agent_role!r}, "
            f"expected {expected_agent_role!r}; generic/default dispatch is not acceptable"
        )

required_receivers = set(receiver_to_role)
missing_wait_results = sorted(required_receivers - set(wait_index_by_receiver))
missing_closes = sorted(required_receivers - set(close_index_by_receiver))
all_text = "\n".join(all_text_parts)
if missing_wait_results:
    raise SystemExit(f"{label} natural role smoke did not capture final wait_agent results for receivers: {missing_wait_results!r}")
if missing_closes and "close/cleanup was not available" not in all_text.lower():
    raise SystemExit(
        f"{label} natural role smoke left receivers without close evidence or an unavailable-cleanup record: "
        f"{missing_closes!r}"
    )
early_closes = {
    receiver: (wait_index_by_receiver[receiver], close_index_by_receiver[receiver])
    for receiver in required_receivers
    if receiver in close_index_by_receiver
    and close_index_by_receiver[receiver] <= wait_index_by_receiver[receiver]
}
if early_closes:
    raise SystemExit(
        f"{label} natural role smoke closed workers before wait_agent results were captured: {early_closes!r}"
    )
if not marker:
    raise SystemExit(f"{label} natural role smoke did not return success marker {success_marker}")

print(f"ok - {label} natural SessionStart smoke spawned required role workers")
PY
}

run_natural_session_start_live_skill_test() {
  local skill="$1"
  local success_marker="$2"
  local role_marker_specs="$3"
  local forbidden_markers="${4:-}"
  local role_order_mode="${5:-exact}"
  local safe_skill="${skill//\//-}"
  local out_file="$RUN_DIR/natural-session-start-${safe_skill}.jsonl"
  local err_file="$RUN_DIR/natural-session-start-${safe_skill}.err"
  local prompt
  prompt="$(natural_session_start_prompt_for_skill "$skill")"
  assert_natural_prompt_has_no_explicit_subagent_terms "$skill" "$prompt"

  local cmd=(
    "$CODEX_BIN"
    --enable plugin_hooks
    --ask-for-approval never
    exec
    --json
    --cd "$PLUGIN_ROOT"
    --sandbox read-only
    --skip-git-repo-check
  )

  if [[ -n "$LIVE_MODEL" ]]; then
    cmd+=(--model "$LIVE_MODEL")
  fi

  run_codex_live_command "$CODEX_HOME_DIR" "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"
  assert_natural_role_spawn_smoke "$out_file" "$err_file" "$success_marker" "$skill" "$role_marker_specs" "$forbidden_markers" "$role_order_mode"
}

run_no_skill_readonly_session_start_live_test() {
  local out_file="$RUN_DIR/no-skill-readonly-session-start.jsonl"
  local err_file="$RUN_DIR/no-skill-readonly-session-start.err"
  local prompt
  prompt='Read-only repository lookup. In this checkout, find the files that define Codex dispatch policy and summarize each one briefly. Follow AGENTS.md and do not edit files. Finish with the marker OH_NO_CODEX_NOSKILL_READONLY_OK.'
  assert_natural_prompt_has_no_explicit_subagent_terms "no-skill-readonly" "$prompt"

  local cmd=(
    "$CODEX_BIN"
    --enable plugin_hooks
    --ask-for-approval never
    exec
    --json
    --cd "$PLUGIN_ROOT"
    --sandbox read-only
    --skip-git-repo-check
  )

  if [[ -n "$LIVE_MODEL" ]]; then
    cmd+=(--model "$LIVE_MODEL")
  fi

  run_codex_live_command "$CODEX_HOME_DIR" "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

  "$PYTHON_BIN" - "$out_file" "$err_file" "$CODEX_HOME_DIR" <<'PY'
import json
import sys
from pathlib import Path

out_path, err_path, live_home = sys.argv[1:4]

def collect_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(item) for item in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(item) for item in value)
    return ""

def receiver_agent_role(receiver):
    sessions_root = Path(live_home) / "sessions"
    session_candidates = list(sessions_root.rglob(f"*{receiver}*.jsonl"))
    if not session_candidates:
        raise SystemExit(f"no-skill read-only smoke could not find session transcript for receiver: {receiver}")
    for path in session_candidates:
        with path.open("r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
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
                return payload.get("agent_role") or thread_spawn.get("agent_role")
    raise SystemExit(f"no-skill read-only smoke transcript lacked session_meta: {receiver}")

with open(err_path, "r", encoding="utf-8") as fh:
    err_text = fh.read()
if (
    "spawn failed" in err_text.lower()
    or "agent thread limit reached" in err_text.lower()
    or "full-history forked agents inherit" in err_text.lower()
    or "provide either message or items" in err_text.lower()
):
    raise SystemExit(f"no-skill read-only smoke saw spawn failure in stderr: {err_text[:2000]!r}")

failed_spawns = []
receiver_ids = set()
wait_index_by_receiver = {}
wait_result_by_receiver = {}
close_index_by_receiver = {}
marker = False
all_text_parts = []
parent_thread_id = None

with open(out_path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        if data.get("type") == "thread.started":
            parent_thread_id = data.get("thread_id") or parent_thread_id
        item = data.get("item") or {}
        event_text = collect_text(data)
        if item.get("type") == "agent_message":
            all_text_parts.append(event_text)
        if "OH_NO_CODEX_NOSKILL_READONLY_OK" in event_text:
            marker = True
        if item.get("type") != "collab_tool_call":
            continue
        tool = item.get("tool")
        status = item.get("status")
        if tool == "spawn_agent" and status == "failed":
            failed_spawns.append((index, collect_text(item)[:2000]))
        if tool == "spawn_agent" and status == "completed":
            receivers = item.get("receiver_thread_ids") or []
            receiver_ids.update(receivers)
        if status == "completed" and tool in {"wait", "wait_agent", "close_agent"}:
            text = collect_text(item)
            mentioned = set(item.get("receiver_thread_ids") or [])
            mentioned.update(receiver for receiver in receiver_ids if receiver in text)
            mentioned.update(
                receiver for receiver in (item.get("agents_states") or {})
                if receiver in receiver_ids
            )
            if tool in {"wait", "wait_agent"}:
                for receiver in mentioned:
                    state = (item.get("agents_states") or {}).get(receiver) or {}
                    if state.get("status") == "completed" and state.get("message"):
                        wait_index_by_receiver.setdefault(receiver, index)
                        wait_result_by_receiver.setdefault(receiver, str(state.get("message")))
            if tool == "close_agent":
                for receiver in mentioned:
                    close_index_by_receiver.setdefault(receiver, index)

if failed_spawns:
    raise SystemExit(f"no-skill read-only smoke saw failed spawn_agent calls: {failed_spawns!r}")
for receiver in receiver_ids:
    actual_role = receiver_agent_role(receiver)
    if actual_role != "oh-no-explore":
        raise SystemExit(
            f"no-skill read-only smoke dispatched unexpected agent_role={actual_role!r} for receiver {receiver}"
        )
transcript_children = []
if parent_thread_id:
    for transcript_path in (Path(live_home) / "sessions").rglob("*.jsonl"):
        rows = [
            json.loads(line)
            for line in transcript_path.read_text(encoding="utf-8", errors="replace").splitlines()
            if line.strip()
        ]
        meta = next(
            (row.get("payload") or {} for row in rows if row.get("type") == "session_meta"),
            None,
        )
        if not isinstance(meta, dict):
            continue
        source = meta.get("source") if isinstance(meta.get("source"), dict) else {}
        subagent = source.get("subagent") if isinstance(source.get("subagent"), dict) else {}
        thread_spawn = subagent.get("thread_spawn") if isinstance(subagent.get("thread_spawn"), dict) else {}
        parent = meta.get("parent_thread_id") or thread_spawn.get("parent_thread_id")
        role = meta.get("agent_role") or thread_spawn.get("agent_role")
        if parent != parent_thread_id:
            continue
        if role != "oh-no-explore":
            raise SystemExit(f"no-skill read-only smoke started unexpected hidden child role: {role!r}")
        completed = any(
            row.get("type") == "event_msg"
            and (row.get("payload") or {}).get("type") == "task_complete"
            for row in rows
        )
        if not completed:
            raise SystemExit("no-skill read-only smoke hidden explore child lacked task_complete")
        transcript_children.append(transcript_path)
if not marker:
    raise SystemExit("no-skill read-only smoke did not return success marker OH_NO_CODEX_NOSKILL_READONLY_OK")
all_text = "\n".join(all_text_parts)
for receiver in sorted(receiver_ids):
    wait_idx = wait_index_by_receiver.get(receiver)
    close_idx = close_index_by_receiver.get(receiver)
    if wait_idx is None:
        raise SystemExit(
            f"no-skill read-only smoke dispatched receiver {receiver!r} but never captured its final result"
        )
    if close_idx is not None and close_idx < wait_idx:
        raise SystemExit(
            f"no-skill read-only smoke closed receiver {receiver!r} before its waited result"
        )

observed_children = max(len(receiver_ids), len(transcript_children))
if observed_children:
    print(
        "ok - no-skill read-only SessionStart smoke dispatched "
        f"{observed_children} typed oh-no-explore receiver(s)"
    )
else:
    print("ok - no-skill read-only SessionStart smoke answered inline (no dispatch)")
PY
}

run_ralplan_object_analysis_session_start_live_test() {
  local out_file="$RUN_DIR/ralplan-object-analysis-session-start.jsonl"
  local err_file="$RUN_DIR/ralplan-object-analysis-session-start.err"
  local prompt
  local plans_before
  local plans_after
  prompt='Analyze the Ralplan review loop for unnecessary steps. Return an analysis report only; do not create a plan or execute changes. End with OH_NO_CODEX_RALPLAN_OBJECT_ANALYSIS_OK.'
  assert_natural_prompt_has_no_explicit_subagent_terms "ralplan-object-analysis" "$prompt"
  plans_before="$(snapshot_file_manifest "$MARKETPLACE_ROOT/.oh-no/plans")"

  local cmd=(
    "$CODEX_BIN"
    --enable plugin_hooks
    --ask-for-approval never
    exec
    --json
    --cd "$PLUGIN_ROOT"
    --sandbox read-only
    --skip-git-repo-check
  )
  if [[ -n "$LIVE_MODEL" ]]; then
    cmd+=(--model "$LIVE_MODEL")
  fi
  run_codex_live_command "$CODEX_HOME_DIR" "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

  plans_after="$(snapshot_file_manifest "$MARKETPLACE_ROOT/.oh-no/plans")"
  [[ "$plans_before" == "$plans_after" ]] || fail "Ralplan object-analysis smoke created or changed a plan artifact"

  "$PYTHON_BIN" - "$out_file" "$CODEX_HOME_DIR" <<'PY'
import json
import sys
from pathlib import Path

out_path, live_home = sys.argv[1:3]
marker = False
parent_thread_id = None
for line in open(out_path, encoding="utf-8"):
    if not line.strip():
        continue
    data = json.loads(line)
    if data.get("type") == "thread.started":
        parent_thread_id = data.get("thread_id") or parent_thread_id
    text = json.dumps(data).lower()
    marker = marker or "oh_no_codex_ralplan_object_analysis_ok" in text
    item = data.get("item") or {}
    if item.get("type") == "collab_tool_call" and item.get("tool") == "spawn_agent":
        if "oh-no-planner" in text or "oh-no-plan-reviewer" in text:
            raise SystemExit("Ralplan object-analysis smoke dispatched a planning role")
if parent_thread_id:
    for transcript_path in (Path(live_home) / "sessions").rglob("*.jsonl"):
        meta = None
        for transcript_line in transcript_path.read_text(encoding="utf-8", errors="replace").splitlines():
            if not transcript_line.strip():
                continue
            row = json.loads(transcript_line)
            if row.get("type") == "session_meta":
                meta = row.get("payload") or {}
                break
        if not isinstance(meta, dict):
            continue
        source = meta.get("source") if isinstance(meta.get("source"), dict) else {}
        subagent = source.get("subagent") if isinstance(source.get("subagent"), dict) else {}
        thread_spawn = subagent.get("thread_spawn") if isinstance(subagent.get("thread_spawn"), dict) else {}
        parent = meta.get("parent_thread_id") or thread_spawn.get("parent_thread_id")
        role = meta.get("agent_role") or thread_spawn.get("agent_role")
        if parent == parent_thread_id and role in {"oh-no-planner", "oh-no-plan-reviewer"}:
            raise SystemExit(f"Ralplan object-analysis smoke started hidden planning child role: {role}")
if not marker:
    raise SystemExit("Ralplan object-analysis smoke missed its success marker")
print("ok - Ralplan object-analysis request stayed analysis-only")
PY
}

run_natural_session_start_live_tests() {
  if [[ "$RUN_NATURAL_SESSION_START_LIVE" != "1" ]]; then
    log "Skipping live natural SessionStart role-worker smoke tests"
    printf 'Run with --natural-session-start-live or OH_NO_NATURAL_SESSION_START_LIVE=1 to verify analysis-only routing, no-skill read-only, and natural role dispatch.\n' >&2
    return
  fi

  log "Running live natural SessionStart role-worker smoke tests"
  mkdir -p "$RUN_DIR"
  run_no_skill_readonly_session_start_live_test
  run_ralplan_object_analysis_session_start_live_test
  run_natural_session_start_live_skill_test \
    interview \
    OH_NO_CODEX_INTERVIEW_NATURAL_OK \
    explore: \
    ""
  run_natural_session_start_live_skill_test \
    ultrawork \
    OH_NO_CODEX_ULTRAWORK_NATURAL_OK \
    explore:,analyst?:,planner:,verifier: \
    "" \
    ordered-optional
  run_natural_session_start_live_skill_test \
    systematic-debugging \
    OH_NO_CODEX_SYSTEMATIC_DEBUGGING_NATURAL_OK \
    debugger:,verifier: \
    "" \
    grouped-fanout
  run_natural_session_start_live_skill_test \
    verification-before-completion \
    OH_NO_CODEX_VERIFICATION_NATURAL_OK \
    verifier: \
    ""
  ok "natural SessionStart live outputs saved under ${RUN_DIR#$MARKETPLACE_ROOT/}"
}


run_ralplan_live_test() {
  if [[ "$RUN_RALPLAN_LIVE" != "1" ]]; then
    log "Skipping live Codex ralplan sequential-subagent smoke test"
    printf 'Run with --ralplan-live or OH_NO_RALPLAN_LIVE=1 to verify Planner -> Plan-Reviewer sequential spawn_agent review.\n' >&2
    return
  fi

  log "Running live Codex ralplan sequential-subagent smoke test"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/ralplan-sequential-subagents.jsonl"
  local err_file="$RUN_DIR/ralplan-sequential-subagents.err"
  local proof_file="$RUN_DIR/ralplan-handoff-proof.json"
  local request_nonce draft_id
  request_nonce="$("$PYTHON_BIN" - <<'PY'
import secrets
print(secrets.token_hex(12))
PY
)"
  draft_id="ralplan-draft-${request_nonce}"
  "$PYTHON_BIN" - "$proof_file" "$request_nonce" "$draft_id" <<'PY'
import json
import sys
from pathlib import Path

proof_path = Path(sys.argv[1])
request_nonce = sys.argv[2]
draft_id = sys.argv[3]
active_contract = """ACTIVE_PLAN_CONTRACT_BEGIN
Mode: LIGHT
Always required: Direction and acceptance core; Minimal scope trace; Core evidence
Mode-required: none
Trigger-required: Execution handoff; Planning-role evidence
Explicitly not applicable: none
Reviewer entitlement: missing-field blocking is limited to the active fields above
ACTIVE_PLAN_CONTRACT_END"""
proof_path.write_text(
    json.dumps(
        {
            "request_nonce": request_nonce,
            "draft_id": draft_id,
            "active_contract": active_contract,
        },
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)
PY
  chmod 600 "$proof_file"
  local prompt
  IFS= read -r -d '' prompt <<PROMPT || true
Use oh-no-harness:ralplan for a read-only typed-role probe. No edits, artifacts, full plan, or roles beyond the two below.
Task: analyze unnecessary Ralplan review steps and document the host's post-approval execution-workflow choice.

Run sequentially, with no generic role, retry, or parallelism:
1. spawn_agent agent_type "oh-no-planner", fork_turns "none"; wait for its final result.
2. spawn_agent agent_type "oh-no-plan-reviewer", fork_turns "none"; wait for its final result.

Each role message needs Role, Codex agent type, Scope, Expected output, Verification responsibility, and Lifecycle.
The Planner message must include this exact request and contract:
OH_NO_RALPLAN_PLANNER_PROOF_REQUEST ${request_nonce}
ACTIVE_PLAN_CONTRACT_BEGIN
Mode: LIGHT
Always required: Direction and acceptance core; Minimal scope trace; Core evidence
Mode-required: none
Trigger-required: Execution handoff; Planning-role evidence
Explicitly not applicable: none
Reviewer entitlement: missing-field blocking is limited to the active fields above
ACTIVE_PLAN_CONTRACT_END
Planner output: one PLANNER_DRAFT_BEGIN/PLANNER_DRAFT_END envelope with the exact line Planner draft id: ${draft_id} and fields Goal, Acceptance criteria, Execution profile, Worktree policy, and Verification plan. Other prose may vary.

Copy that complete Planner envelope unchanged into the Plan-Reviewer message, which must also include:
OH_NO_RALPLAN_REVIEW_PROOF_REQUEST ${request_nonce}
Reviewer output: echo the unchanged Planner envelope inside REVIEWED_PLANNER_DRAFT_BEGIN/REVIEWED_PLANNER_DRAFT_END, then one PLAN_REVIEWER_DECISION_BEGIN/PLAN_REVIEWER_DECISION_END envelope with exact line Reviewed draft: ${draft_id}. Keep NB1 non-blocking; APPROVE with no Planner revision. APPROVE freezes the exact reviewed Planner draft. Optional follow-up: NB1. Planner revision: not run.

Copy both complete role results unchanged into the parent final response, Planner then Plan-Reviewer. Use cleanup only if exposed; otherwise include exactly: Close/cleanup was not available. End with OH_NO_CODEX_RALPLAN_SEQUENTIAL_SUBAGENTS_OK and report role order, exact handoff, no revision, and cleanup.
PROMPT

  local cmd=(
    "$CODEX_BIN"
    --enable plugin_hooks
    --ask-for-approval never
    exec
    --json
    --cd "$PLUGIN_ROOT"
    --sandbox read-only
    --skip-git-repo-check
  )

  if [[ -n "$LIVE_MODEL" ]]; then
    cmd+=(--model "$LIVE_MODEL")
  fi

  run_in_verified_codex_live_home "$CODEX_HOME_DIR" "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"
  if ! assert_no_codex_live_secret_leak \
    "$CODEX_HOME_DIR/auth.json" \
    "$out_file" \
    "$err_file" \
    "$CODEX_HOME_DIR/sessions"; then
    rm -f "$out_file" "$err_file" "$proof_file"
    fail "Codex Ralplan explicit live artifacts failed the credential-leak guard and were removed"
  fi

  "$PYTHON_BIN" - "$out_file" "$err_file" "$CODEX_HOME_DIR" "$proof_file" <<'PY'
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

path = sys.argv[1]
err_path = sys.argv[2]
live_home = sys.argv[3]
proof_path = sys.argv[4]
proof = json.loads(Path(proof_path).read_text(encoding="utf-8"))

expected_roles = ["planner", "plan-reviewer"]
role_headings = {
    "planner": "# Planner Agent",
    "plan-reviewer": "# Plan Reviewer Agent",
}
required_prompt_markers = [
    "## Skill Relationship",
    "## Responsibilities",
    "## Operating Rules",
    "## Output",
]
dependency_prompt_markers = {
    "plan-reviewer": ["PLANNER_DRAFT_BEGIN", "Active plan contract"],
}
output_markers = {
    "planner": [
        "PLANNER_DRAFT_BEGIN",
        "Planner draft id:",
        "Goal:",
        "Acceptance criteria:",
        "Execution profile:",
        "Worktree policy:",
        "Verification plan:",
        "PLANNER_DRAFT_END",
    ],
    "plan-reviewer": [
        "REVIEWED_PLANNER_DRAFT_BEGIN",
        "REVIEWED_PLANNER_DRAFT_END",
        "PLAN_REVIEWER_DECISION_BEGIN",
        "Reviewed draft:",
        "Architecture findings",
        "NB1",
        "Quality-gate findings",
        "PLAN_REVIEWER_DECISION_END",
    ],
}
CONTRACT_START = "ACTIVE_PLAN_CONTRACT_BEGIN"
CONTRACT_END = "ACTIVE_PLAN_CONTRACT_END"
DRAFT_START = "PLANNER_DRAFT_BEGIN"
DRAFT_END = "PLANNER_DRAFT_END"
REVIEWED_DRAFT_START = "REVIEWED_PLANNER_DRAFT_BEGIN"
REVIEWED_DRAFT_END = "REVIEWED_PLANNER_DRAFT_END"
DECISION_START = "PLAN_REVIEWER_DECISION_BEGIN"
DECISION_END = "PLAN_REVIEWER_DECISION_END"

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
            f"Codex ralplan sequential smoke expected one unique {label} block; "
            f"matches={len(matches)} unique={len(normalized)}"
        )
    return next(iter(normalized))

def roles_in_text(text):
    lower = text.lower()
    return [
        role for role in expected_roles
        if f"Codex agent type: oh-no-{role}".lower() in lower
    ]

def mentioned_receivers(item):
    text = collect_text(item)
    mentioned = set(item.get("receiver_thread_ids") or [])
    mentioned.update((item.get("agents_states") or {}).keys())
    mentioned.update(
        receiver for receiver in receiver_to_role
        if receiver in text
    )
    return mentioned & set(receiver_to_role)

def receiver_agent_role(receiver):
    sessions_root = Path(live_home) / "sessions"
    session_candidates = list(sessions_root.rglob(f"*{receiver}*.jsonl"))
    if not session_candidates:
        raise SystemExit(f"Codex ralplan sequential smoke could not find session transcript for receiver: {receiver}")
    for path in session_candidates:
        with path.open("r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
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
                return payload.get("agent_role") or thread_spawn.get("agent_role")
    raise SystemExit(f"Codex ralplan sequential smoke transcript lacked session_meta: {receiver}")

with open(err_path, "r", encoding="utf-8") as fh:
    err_text = fh.read()
if (
    "spawn failed" in err_text.lower()
    or "agent thread limit reached" in err_text.lower()
    or "full-history forked agents inherit" in err_text.lower()
    or "provide either message or items" in err_text.lower()
):
    raise SystemExit("Codex ralplan sequential smoke saw a spawn failure; inspect the secret-scanned stderr artifact")

successful_spawns = []
failed_spawns = []
events = []
command_events = []
receiver_to_role = {}
role_outputs = defaultdict(list)
wait_index_by_receiver = {}
close_index_by_receiver = {}
marker = False
all_text_parts = []
parent_thread_id = None
transcript_fallback = False

with open(path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        if data.get("type") == "thread.started":
            parent_thread_id = data.get("thread_id") or parent_thread_id
        item = data.get("item") or {}
        if item.get("type") == "agent_message":
            all_text_parts.append(collect_text(data))
        payload = data.get("payload") or {}
        if item.get("type") == "command_execution":
            command_events.append((index, collect_text(item)))
        if payload.get("type") == "function_call" and payload.get("name") in {
            "exec_command",
            "functions.exec_command",
        }:
            command_events.append((index, collect_text(payload)))
        if "OH_NO_CODEX_RALPLAN_SEQUENTIAL_SUBAGENTS_OK" in collect_text(data):
            marker = True
        if item.get("type") != "collab_tool_call":
            continue

        tool = item.get("tool")
        status = item.get("status")
        if tool == "spawn_agent" and status == "failed":
            failed_spawns.append((index, collect_text(item)[:2000]))
        if tool == "spawn_agent" and status == "completed":
            receivers = item.get("receiver_thread_ids") or []
            if not receivers:
                continue
            spawn_text = collect_text(item)
            matched_roles = roles_in_text(spawn_text)
            if len(matched_roles) != 1:
                raise SystemExit(
                    "expected each completed spawn_agent payload to contain exactly one planning role prompt source; "
                    f"line={index} roles={matched_roles!r} text={spawn_text[:2000]!r}"
                )
            role = matched_roles[0]
            successful_spawns.append((index, role, tuple(receivers), spawn_text))
            for receiver in receivers:
                receiver_to_role[receiver] = role
            events.append((index, "spawn", role))
        if tool in {"wait", "wait_agent", "close_agent"} and status == "completed":
            receivers = set(item.get("receiver_thread_ids") or []) | mentioned_receivers(item)
            completed_receivers = set()
            if tool in {"wait", "wait_agent"}:
                for receiver, state in (item.get("agents_states") or {}).items():
                    role = receiver_to_role.get(receiver)
                    if not role or not isinstance(state, dict):
                        continue
                    message = collect_text(state.get("message"))
                    if state.get("status") == "completed" and message:
                        completed_receivers.add(receiver)
                        wait_index_by_receiver.setdefault(receiver, index)
                        role_outputs[role].append(message)
            if tool == "close_agent":
                for receiver in receivers:
                    close_index_by_receiver.setdefault(receiver, index)
            event_receivers = completed_receivers if tool in {"wait", "wait_agent"} else receivers
            roles = {receiver_to_role.get(receiver) for receiver in event_receivers}
            for role in roles:
                if role:
                    events.append((index, tool, role))

if failed_spawns:
    raise SystemExit(f"Codex ralplan sequential smoke saw failed spawn_agent calls: {failed_spawns!r}")
tainted_command_events = [
    event for event in command_events
    if "ralplan-handoff-proof.json" in event[1]
    or "/agents/oh-no-planner.toml" in event[1]
    or "/agents/oh-no-plan-reviewer.toml" in event[1]
]
if tainted_command_events:
    tainted_lines = sorted({event[0] for event in tainted_command_events})
    raise SystemExit(
        "Codex ralplan sequential smoke inspected test-only proof material instead of relying on typed-role output: "
        f"event lines {tainted_lines!r}"
    )
all_text = "\n".join(all_text_parts)
if not successful_spawns:
    transcript_fallback = True
    if not parent_thread_id:
        raise SystemExit("Codex ralplan sequential smoke lacked both collab events and a parent thread id")
    transcript_children = {}
    sessions_root = Path(live_home) / "sessions"
    for transcript_path in sessions_root.rglob("*.jsonl"):
        transcript_rows = []
        meta = None
        for transcript_line in transcript_path.read_text(encoding="utf-8", errors="replace").splitlines():
            if not transcript_line.strip():
                continue
            candidate = json.loads(transcript_line)
            transcript_rows.append(candidate)
            if candidate.get("type") == "session_meta":
                meta = candidate.get("payload") or {}
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
        if parent != parent_thread_id or not isinstance(agent_role, str):
            continue
        if not agent_role.startswith("oh-no-"):
            continue
        role = agent_role.removeprefix("oh-no-")
        if role not in expected_roles:
            continue
        if role in transcript_children:
            raise SystemExit(f"Codex ralplan sequential smoke found duplicate typed child sessions for {role}")
        assistant_messages = []
        task_complete_messages = []
        user_messages = []
        encrypted_task_messages = 0
        completed = False
        completion_timestamp = ""
        for candidate in transcript_rows:
            payload = candidate.get("payload") or {}
            if candidate.get("type") == "event_msg" and payload.get("type") == "task_complete":
                completed = True
                completion_timestamp = candidate.get("timestamp", "") or completion_timestamp
                final_message = collect_text(payload.get("last_agent_message"))
                if final_message:
                    task_complete_messages.append(final_message)
            if candidate.get("type") != "response_item":
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
            if payload.get("role") == "assistant":
                assistant_messages.append(collect_text(payload.get("content")))
            elif payload.get("role") == "user":
                user_messages.append(collect_text(payload.get("content")))
        if not completed:
            raise SystemExit(f"Codex ralplan sequential smoke typed child {role} lacked task_complete")
        transcript_children[role] = {
            "timestamp": meta.get("timestamp", ""),
            "completion_timestamp": completion_timestamp,
            "input": "\n".join(user_messages),
            "encrypted_task_messages": encrypted_task_messages,
            "output": (
                task_complete_messages[-1]
                if task_complete_messages
                else "\n".join(dict.fromkeys(assistant_messages))
            ),
        }
    missing_children = sorted(set(expected_roles) - set(transcript_children))
    if missing_children:
        raise SystemExit(
            "Codex ralplan sequential smoke omitted typed child session proof for roles: "
            f"{missing_children!r}"
        )
    planner_time = transcript_children["planner"]["timestamp"]
    planner_completion = transcript_children["planner"]["completion_timestamp"]
    reviewer_time = transcript_children["plan-reviewer"]["timestamp"]
    if (
        not planner_time
        or not planner_completion
        or not reviewer_time
        or planner_time >= reviewer_time
        or planner_completion >= reviewer_time
    ):
        raise SystemExit(
            "Codex ralplan sequential smoke typed child completion did not precede Plan-Reviewer creation"
        )
    planner_input = normalize_transport_whitespace(transcript_children["planner"]["input"])
    reviewer_input = normalize_transport_whitespace(transcript_children["plan-reviewer"]["input"])
    planner_output = normalize_transport_whitespace(transcript_children["planner"]["output"])
    reviewer_output = normalize_transport_whitespace(transcript_children["plan-reviewer"]["output"])
    parent_output = normalize_transport_whitespace(all_text)
    planner_request = f"OH_NO_RALPLAN_PLANNER_PROOF_REQUEST {proof['request_nonce']}"
    reviewer_request = f"OH_NO_RALPLAN_REVIEW_PROOF_REQUEST {proof['request_nonce']}"
    planner_input_visible = planner_request.lower() in planner_input.lower()
    reviewer_input_visible = reviewer_request.lower() in reviewer_input.lower()
    planner_input_encrypted = transcript_children["planner"]["encrypted_task_messages"] == 1
    reviewer_input_encrypted = transcript_children["plan-reviewer"]["encrypted_task_messages"] == 1
    if not planner_input_visible and not planner_input_encrypted:
        raise SystemExit(
            "Codex ralplan sequential smoke Planner task had neither visible proof request "
            "nor one encrypted inter-agent task message"
        )
    if not reviewer_input_visible and not reviewer_input_encrypted:
        raise SystemExit(
            "Codex ralplan sequential smoke Plan-Reviewer task had neither visible proof request "
            "nor one encrypted inter-agent task message"
        )
    for role, output_text in (
        ("planner", planner_output),
        ("plan-reviewer", reviewer_output),
    ):
        if not output_text:
            raise SystemExit(f"Codex ralplan sequential smoke typed child {role} returned no final output")
        missing = [
            value for value in output_markers[role]
            if value.lower() not in output_text.lower()
        ]
        if missing:
            raise SystemExit(
                f"Codex ralplan sequential smoke typed child {role} lacked output proof: {missing!r}"
            )
    planner_draft_ids = re.findall(r"(?m)^Planner draft id:\s*(\S.*)$", planner_output)
    if planner_draft_ids != [proof["draft_id"]]:
        raise SystemExit(
            "Codex ralplan sequential smoke typed Planner did not return the exact dynamic draft id"
        )
    planner_draft = extract_delimited_block(
        planner_output, DRAFT_START, DRAFT_END, "typed child Planner draft"
    )
    planner_draft_envelope = normalize_transport_whitespace(
        f"{DRAFT_START}\n{planner_draft}\n{DRAFT_END}"
    )
    reviewed_planner_draft = extract_delimited_block(
        reviewer_output,
        REVIEWED_DRAFT_START,
        REVIEWED_DRAFT_END,
        "Plan-Reviewer echoed Planner draft",
    )
    if reviewed_planner_draft != planner_draft_envelope:
        raise SystemExit(
            "Codex ralplan sequential smoke typed Plan-Reviewer did not echo the exact Planner draft"
        )
    reviewer_decision = extract_delimited_block(
        reviewer_output, DECISION_START, DECISION_END, "Plan-Reviewer decision"
    )
    reviewed_draft_ids = [
        normalize_transport_whitespace(value)
        for value in re.findall(r"(?m)^Reviewed draft:[ \t]*(.*?)[ \t]*$", reviewer_decision)
    ]
    unique_reviewed = set(reviewed_draft_ids)
    if len(reviewed_draft_ids) != 1 or len(unique_reviewed) != 1:
        raise SystemExit(
            "Codex ralplan sequential smoke typed Plan-Reviewer did not return one anchored Reviewed draft field"
        )
    if next(iter(unique_reviewed)) != proof["draft_id"]:
        raise SystemExit(
            "Codex ralplan sequential smoke typed Plan-Reviewer did not identify the dynamic draft id"
        )
    reviewer_lower = reviewer_decision.lower()
    reviewer_non_blocking = (
        "non-blocking" in reviewer_lower
        or (
            "optional follow-up" in reviewer_lower
            and "required changes for planner: none" in reviewer_lower
        )
    )
    if not reviewer_non_blocking:
        raise SystemExit("Codex ralplan sequential smoke typed child plan-reviewer did not keep NB1 non-blocking")
    if reviewer_input_visible:
        reviewer_input_draft = extract_delimited_block(
            reviewer_input, DRAFT_START, DRAFT_END, "Plan-Reviewer input draft", allow_repeats=True
        )
        if planner_draft != reviewer_input_draft:
            raise SystemExit("Codex ralplan sequential smoke Plan-Reviewer input changed the captured Planner draft")
    elif not reviewer_input_encrypted:
        raise SystemExit("Codex ralplan sequential smoke Plan-Reviewer task transport was not auditable")
    parent_draft = extract_delimited_block(
        parent_output, DRAFT_START, DRAFT_END, "parent Planner draft", allow_repeats=True
    )
    if planner_draft != parent_draft:
        raise SystemExit("Codex ralplan sequential smoke parent changed the captured Planner draft")
    if planner_output not in parent_output:
        raise SystemExit("Codex ralplan sequential smoke parent did not preserve the exact Planner output")
    if reviewer_output not in parent_output:
        raise SystemExit("Codex ralplan sequential smoke parent did not preserve the exact Plan-Reviewer output")
    if parent_output.index(planner_output) >= parent_output.index(reviewer_output):
        raise SystemExit("Codex ralplan sequential smoke parent reversed the typed child outputs")
    parent_review_markers = ("Reviewed draft", "APPROVE", "NB1")
    missing_parent_review = [
        value for value in parent_review_markers
        if value.lower() not in parent_output.lower()
    ]
    if missing_parent_review:
        raise SystemExit(
            "Codex ralplan sequential smoke parent omitted Plan-Reviewer decision evidence: "
            f"{missing_parent_review!r}"
        )
    parent_lower = parent_output.lower()
    parent_non_blocking = (
        "non-blocking" in parent_lower
        or (
            "optional follow-up" in parent_lower
            and "required changes for planner: none" in parent_lower
        )
    )
    if not parent_non_blocking:
        raise SystemExit("Codex ralplan sequential smoke parent did not preserve NB1 as non-blocking")
    parent_draft_end = parent_output.index(DRAFT_END)
    parent_review_start = parent_output.lower().find("reviewed draft", parent_draft_end)
    if parent_review_start < 0:
        raise SystemExit("Codex ralplan sequential smoke parent reversed Planner -> Plan-Reviewer output order")
    for required in (
        "OH_NO_CODEX_RALPLAN_SEQUENTIAL_SUBAGENTS_OK",
        "Close/cleanup was not available",
    ):
        if required.lower() not in parent_output.lower():
            raise SystemExit(f"Codex ralplan sequential smoke parent omitted {required!r}")
    print("ok - live Codex ralplan typed child transcripts proved sequential review")
    raise SystemExit(0)
if len(successful_spawns) != len(expected_roles):
    raise SystemExit(
        f"expected exactly {len(expected_roles)} completed planning spawn_agent calls, "
        f"got {len(successful_spawns)}: {successful_spawns!r}"
    )
receiver_ids = {rid for _, _, receivers, _ in successful_spawns for rid in receivers}
missing_wait_results = sorted(receiver_ids - set(wait_index_by_receiver))
missing_closes = sorted(receiver_ids - set(close_index_by_receiver))
if missing_wait_results:
    raise SystemExit(f"Codex ralplan sequential smoke did not capture wait_agent results for receivers: {missing_wait_results!r}")
if missing_closes and "close/cleanup was not available" not in all_text.lower():
    raise SystemExit(
        "Codex ralplan sequential smoke left receivers without close evidence or an unavailable-cleanup record: "
        f"{missing_closes!r}"
    )
early_closes = {
    receiver: (wait_index_by_receiver[receiver], close_index_by_receiver[receiver])
    for receiver in receiver_ids
    if receiver in close_index_by_receiver
    and close_index_by_receiver[receiver] <= wait_index_by_receiver[receiver]
}
if early_closes:
    raise SystemExit(
        "Codex ralplan sequential smoke closed agents before their wait_agent results were captured: "
        f"{early_closes!r}"
    )

actual_order = [role for _, role, _, _ in successful_spawns]
if actual_order != expected_roles:
    raise SystemExit(f"expected sequential spawn order {expected_roles!r}, got {actual_order!r}")

for receiver, role in receiver_to_role.items():
    expected_agent_role = f"oh-no-{role}"
    actual_agent_role = receiver_agent_role(receiver)
    if actual_agent_role != expected_agent_role:
        raise SystemExit(
            f"Codex ralplan sequential smoke spawned receiver {receiver} with agent_role={actual_agent_role!r}, "
            f"expected {expected_agent_role!r}; generic/default dispatch is not acceptable"
        )

role_payload_text = {}
for role, payloads in {
    role: [spawn for spawn in successful_spawns if spawn[1] == role]
    for role in expected_roles
}.items():
    if len(payloads) != 1:
        raise SystemExit(f"expected exactly one successful spawn_agent payload for {role}, got {len(payloads)}")
    _, _, _, role_text = payloads[0]
    role_payload_text[role] = role_text
    required_role_markers = list(dependency_prompt_markers.get(role, []))
    if not transcript_fallback:
        required_role_markers.insert(0, f"Codex agent type: oh-no-{role}")
    missing_prompt_markers = [
        marker for marker in required_role_markers
        if marker.lower() not in role_text.lower()
    ]
    if missing_prompt_markers:
        raise SystemExit(
            f"Codex ralplan spawn_agent payload for {role} did not use the required custom-agent prompt/review markers: "
            f"{missing_prompt_markers}; spawn_text={role_text[:2000]!r}"
        )
    forbidden_frontmatter_markers = [
        "\n---\n",
        "\ntools:",
        "\nmodel:",
        "\ncolor:",
        "Agent prompt content:",
        f"Agent prompt source: docs/agent-core/{role}.md",
    ]
    leaked = [marker for marker in forbidden_frontmatter_markers if marker in role_text]
    if leaked:
        raise SystemExit(
            f"Codex ralplan spawn_agent payload for {role} leaked Claude YAML frontmatter markers: "
            f"{leaked}; spawn_text={role_text[:2000]!r}"
        )

planner_request = f"OH_NO_RALPLAN_PLANNER_PROOF_REQUEST {proof['request_nonce']}"
reviewer_request = f"OH_NO_RALPLAN_REVIEW_PROOF_REQUEST {proof['request_nonce']}"
if planner_request not in role_payload_text["planner"]:
    raise SystemExit("Codex ralplan Planner payload omitted its dynamic request marker")
if reviewer_request not in role_payload_text["plan-reviewer"]:
    raise SystemExit("Codex ralplan Plan-Reviewer payload omitted its dynamic request marker")
if f"Planner draft id: {proof['draft_id']}" not in role_payload_text["plan-reviewer"]:
    raise SystemExit("Codex ralplan Plan-Reviewer payload omitted the dynamic Planner draft id")

for previous, following in zip(successful_spawns, successful_spawns[1:]):
    previous_index, previous_role, _, _ = previous
    following_index, following_role, _, _ = following
    has_barrier = any(
        previous_index < event_index < following_index
        and event_type in {"wait", "wait_agent"}
        and role == previous_role
        for event_index, event_type, role in events
    )
    if not has_barrier:
        raise SystemExit(
            f"expected wait/close for {previous_role} between {previous_role} spawn and "
            f"{following_role} spawn; events={events!r}"
        )

role_output_text = {}
for role, markers in output_markers.items():
    output_text = "\n".join(dict.fromkeys(role_outputs.get(role, [])))
    role_output_text[role] = output_text
    if not output_text:
        raise SystemExit(f"no completed wait/close output captured for {role}")
    missing_output_markers = [
        marker for marker in markers
        if marker.lower() not in output_text.lower()
    ]
    if missing_output_markers:
        raise SystemExit(
            f"Codex ralplan {role} output did not prove the review chain: "
            f"{missing_output_markers}; output={output_text[:2000]!r}"
        )
planner_draft_ids = re.findall(
    r"(?m)^Planner draft id:\s*(\S.*)$",
    role_output_text["planner"],
)
if planner_draft_ids != [proof["draft_id"]]:
    raise SystemExit("Codex ralplan Planner output did not identify the dynamic draft id")
reviewer_decision = extract_delimited_block(
    role_output_text["plan-reviewer"],
    DECISION_START,
    DECISION_END,
    "Plan-Reviewer decision",
)
reviewed_draft_ids = [
    normalize_transport_whitespace(value)
    for value in re.findall(r"(?m)^Reviewed draft:[ \t]*(.*?)[ \t]*$", reviewer_decision)
]
unique_reviewed = set(reviewed_draft_ids)
if len(reviewed_draft_ids) != 1 or len(unique_reviewed) != 1:
    raise SystemExit("Codex ralplan Plan-Reviewer output must contain one anchored Reviewed draft field")
if next(iter(unique_reviewed)) != proof["draft_id"]:
    raise SystemExit("Codex ralplan Plan-Reviewer output did not identify the dynamic draft id")
reviewer_output_lower = reviewer_decision.lower()
if not (
    "non-blocking" in reviewer_output_lower
    or (
        "optional follow-up" in reviewer_output_lower
        and "required changes for planner: none" in reviewer_output_lower
    )
):
    raise SystemExit("Codex ralplan Plan-Reviewer output did not keep NB1 non-blocking")

planner_contract = extract_delimited_block(
    role_payload_text["planner"], CONTRACT_START, CONTRACT_END, "Planner Active plan contract"
)
reviewer_contract = extract_delimited_block(
    role_payload_text["plan-reviewer"], CONTRACT_START, CONTRACT_END, "Plan-Reviewer Active plan contract"
)
if planner_contract != reviewer_contract:
    raise SystemExit("Codex ralplan role payloads did not carry the exact same Active plan contract")
expected_contract = extract_delimited_block(
    proof["active_contract"], CONTRACT_START, CONTRACT_END, "expected Active plan contract"
)
if planner_contract != expected_contract:
    raise SystemExit("Codex ralplan role payloads changed the expected Active plan contract")

captured_draft = extract_delimited_block(
    role_output_text["planner"], DRAFT_START, DRAFT_END, "captured Planner draft"
)
reviewer_draft = extract_delimited_block(
    role_payload_text["plan-reviewer"], DRAFT_START, DRAFT_END, "Plan-Reviewer input draft"
)
if captured_draft != reviewer_draft:
    raise SystemExit("Codex ralplan Plan-Reviewer payload did not carry the exact captured Planner draft")
captured_draft_envelope = normalize_transport_whitespace(
    f"{DRAFT_START}\n{captured_draft}\n{DRAFT_END}"
)
reviewer_echo = extract_delimited_block(
    role_output_text["plan-reviewer"],
    REVIEWED_DRAFT_START,
    REVIEWED_DRAFT_END,
    "Plan-Reviewer echoed Planner draft",
)
if reviewer_echo != captured_draft_envelope:
    raise SystemExit("Codex ralplan Plan-Reviewer output did not echo the exact captured Planner draft")
parent_output = normalize_transport_whitespace(all_text)
planner_final = normalize_transport_whitespace(role_output_text["planner"])
reviewer_final = normalize_transport_whitespace(role_output_text["plan-reviewer"])
if planner_final not in parent_output:
    raise SystemExit("Codex ralplan parent did not preserve the exact Planner output")
if reviewer_final not in parent_output:
    raise SystemExit("Codex ralplan parent did not preserve the exact Plan-Reviewer output")
if parent_output.index(planner_final) >= parent_output.index(reviewer_final):
    raise SystemExit("Codex ralplan parent reversed Planner -> Plan-Reviewer output order")

if not marker:
    raise SystemExit("Codex ralplan sequential smoke did not return success marker")

print("ok - live Codex ralplan planning subagents reviewed sequentially")
PY

  log "Running live Codex ralplan natural SessionStart-dispatch smoke test"
  out_file="$RUN_DIR/ralplan-natural-session-start.jsonl"
  err_file="$RUN_DIR/ralplan-natural-session-start.err"
  IFS= read -r -d '' prompt <<'PROMPT' || true
Use the oh-no-harness:ralplan skill for a read-only natural planning smoke test.
Requirements are already analyzed. Produce a compact approved plan for documenting that the host asks which approved execution workflow to run after plan approval.
Do not edit files, create artifacts, or execute the plan. Follow the skill's normal planning and review path without additional procedural instructions from this prompt.
In the final response, preserve the complete planning draft and review decision in their natural order, report whether the review approved or blocked the draft, and end with OH_NO_CODEX_RALPLAN_NATURAL_OK.
PROMPT
  assert_natural_prompt_has_no_explicit_subagent_terms "ralplan" "$prompt"
  run_in_verified_codex_live_home "$CODEX_HOME_DIR" "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"
  if ! assert_no_codex_live_secret_leak \
    "$CODEX_HOME_DIR/auth.json" \
    "$out_file" \
    "$err_file" \
    "$CODEX_HOME_DIR/sessions"; then
    rm -f "$out_file" "$err_file"
    fail "Codex Ralplan natural live artifacts failed the credential-leak guard and were removed"
  fi
  "$PYTHON_BIN" - "$out_file" "$err_file" "$CODEX_HOME_DIR" <<'PY'
import json
import re
import sys
from pathlib import Path

out_path, err_path, live_home = sys.argv[1:4]
expected_roles = ("planner", "plan-reviewer")


def collect_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(item) for item in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(item) for item in value)
    return ""


def normalize(value):
    lines = value.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    return "\n".join(line.rstrip() for line in lines)


def payload_from(value, prefixes):
    lines = normalize(value).split("\n")
    for index, line in enumerate(lines):
        if any(line.strip().lower().startswith(prefix.lower()) for prefix in prefixes):
            return normalize("\n".join(lines[index:]))
    return ""


def canonical_draft_id(value):
    draft_id = normalize(value).strip("` *_").rstrip(".").strip("` *_")
    version = re.fullmatch(
        r"(?i)(?:planner\s+)?(?:draft|revision)\s+(v[0-9]+)",
        draft_id,
    )
    return version.group(1).lower() if version else draft_id


err_text = Path(err_path).read_text(encoding="utf-8", errors="replace")
for marker in (
    "spawn failed",
    "agent thread limit reached",
    "full-history forked agents inherit",
    "provide either message or items",
):
    if marker in err_text.lower():
        raise SystemExit("Codex ralplan natural transcript proof saw a spawn failure; inspect the secret-scanned stderr artifact")

rows = [json.loads(line) for line in Path(out_path).read_text(encoding="utf-8").splitlines() if line.strip()]
parent_thread_id = next(
    (row.get("thread_id") for row in rows if row.get("type") == "thread.started"),
    None,
)
if not parent_thread_id:
    raise SystemExit("Codex ralplan natural transcript proof lacked a parent thread id")
parent_messages = [
    collect_text(row)
    for row in rows
    if (row.get("item") or {}).get("type") == "agent_message"
]
parent_output = normalize("\n".join(parent_messages))
final_parent_output = normalize(parent_messages[-1]) if parent_messages else ""

transcript_children = {role: [] for role in expected_roles}
for transcript_path in (Path(live_home) / "sessions").rglob("*.jsonl"):
    transcript_rows = [
        json.loads(line)
        for line in transcript_path.read_text(encoding="utf-8", errors="replace").splitlines()
        if line.strip()
    ]
    meta = next(
        (row.get("payload") or {} for row in transcript_rows if row.get("type") == "session_meta"),
        None,
    )
    if not isinstance(meta, dict):
        continue
    source = meta.get("source") if isinstance(meta.get("source"), dict) else {}
    subagent = source.get("subagent") if isinstance(source.get("subagent"), dict) else {}
    thread_spawn = subagent.get("thread_spawn") if isinstance(subagent.get("thread_spawn"), dict) else {}
    parent = meta.get("parent_thread_id") or thread_spawn.get("parent_thread_id")
    agent_role = meta.get("agent_role") or thread_spawn.get("agent_role")
    if parent != parent_thread_id or not isinstance(agent_role, str) or not agent_role.startswith("oh-no-"):
        continue
    role = agent_role.removeprefix("oh-no-")
    if role not in expected_roles:
        continue
    assistant_messages = []
    task_complete_messages = []
    user_messages = []
    task_timestamps = []
    encrypted_task_messages = 0
    completed = False
    first_completion_timestamp = ""
    last_completion_timestamp = ""
    for row in transcript_rows:
        payload = row.get("payload") or {}
        if row.get("type") == "event_msg" and payload.get("type") == "task_complete":
            completed = True
            completion_timestamp = row.get("timestamp", "")
            if not first_completion_timestamp:
                first_completion_timestamp = completion_timestamp
            last_completion_timestamp = completion_timestamp or last_completion_timestamp
            final_message = collect_text(payload.get("last_agent_message"))
            if final_message:
                task_complete_messages.append(final_message)
        if row.get("type") != "response_item":
            continue
        if payload.get("type") == "agent_message":
            if row.get("timestamp"):
                task_timestamps.append(row["timestamp"])
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
        if payload.get("role") == "assistant":
            assistant_messages.append(collect_text(payload.get("content")))
        elif payload.get("role") == "user":
            if row.get("timestamp"):
                task_timestamps.append(row["timestamp"])
            user_messages.append(collect_text(payload.get("content")))
    if not completed:
        raise SystemExit(f"Codex ralplan natural typed child {role} lacked task_complete")
    transcript_children[role].append(
        {
            "timestamp": meta.get("timestamp", ""),
            "first_completion_timestamp": first_completion_timestamp,
            "last_completion_timestamp": last_completion_timestamp,
            "last_task_timestamp": task_timestamps[-1] if task_timestamps else "",
            "input": normalize("\n".join(user_messages)),
            "encrypted_task_messages": encrypted_task_messages,
            "output": normalize(
                task_complete_messages[-1]
                if task_complete_messages
                else "\n".join(dict.fromkeys(assistant_messages))
            ),
        }
    )

missing_roles = sorted(role for role in expected_roles if not transcript_children[role])
if missing_roles:
    raise SystemExit(f"Codex ralplan natural transcript proof omitted typed child roles: {missing_roles!r}")
planner_sessions = transcript_children["planner"]
reviewer_sessions = transcript_children["plan-reviewer"]
if len(planner_sessions) != 1:
    raise SystemExit(
        "Codex ralplan natural transcript proof expected one reusable Planner context; "
        f"found {len(planner_sessions)}"
    )
if not 1 <= len(reviewer_sessions) <= 4:
    raise SystemExit(
        "Codex ralplan natural transcript proof exceeded two review rounds with "
        f"at most one THOROUGH pair per round; found {len(reviewer_sessions)} sessions"
    )
planner = planner_sessions[0]
planner_time = planner["timestamp"]
planner_first_completion = planner["first_completion_timestamp"]
reviewer_starts = [reviewer["timestamp"] for reviewer in reviewer_sessions]
if (
    not planner_time
    or not planner_first_completion
    or not all(reviewer_starts)
    or planner_time >= min(reviewer_starts)
    or planner_first_completion >= min(reviewer_starts)
):
    raise SystemExit(
        "Codex ralplan natural initial Planner completion did not precede "
        "the first Plan-Reviewer creation"
    )

planner_output = planner["output"]
if not planner_output:
    raise SystemExit("Codex ralplan natural typed child planner returned no output")
planner_output_lower = planner_output.lower()
if "goal" not in planner_output_lower:
    raise SystemExit("Codex ralplan natural typed child planner lacked a goal")
acceptance_markers = ("acceptance", "required outcomes", "success criteria")
ac_ids = set(re.findall(r"(?i)\bAC[- ]?([0-9]+)\b", planner_output))
if not any(marker in planner_output_lower for marker in acceptance_markers) or not ac_ids:
    raise SystemExit(
        "Codex ralplan natural typed child planner lacked structured acceptance outcomes"
    )
planner_ids = {
    canonical_draft_id(value)
    for value in re.findall(
        r"(?mi)^\s*(?:-\s*)?Planner (?:draft |revision )?id:\s*(.*?)\s*$",
        planner_output,
    )
    if normalize(value).strip("` ")
}
if len(planner_ids) != 1:
    raise SystemExit(
        f"Codex ralplan natural Planner output lacked one stable draft id: {sorted(planner_ids)!r}"
    )

reviewer_evidence = []
for reviewer_index, reviewer in enumerate(reviewer_sessions, start=1):
    reviewer_output = reviewer["output"]
    if not reviewer_output:
        raise SystemExit(
            f"Codex ralplan natural typed Plan-Reviewer {reviewer_index} returned no output"
        )
    if "review" not in reviewer_output.lower():
        raise SystemExit(
            f"Codex ralplan natural typed Plan-Reviewer {reviewer_index} lacked review evidence"
        )
    if not any(
        token in reviewer_output.lower()
        for token in ("approve", "block", "iterate", "reject", "revision")
    ):
        raise SystemExit(
            f"Codex ralplan natural Plan-Reviewer {reviewer_index} output omitted its decision"
        )
    reviewed_ids = {
        canonical_draft_id(value)
        for value in re.findall(
            r"(?mi)^\s*(?:-\s*)?Reviewed draft:\s*(.*?)\s*$",
            reviewer_output,
        )
        if normalize(value).strip("` ")
    }
    if len(reviewed_ids) != 1:
        raise SystemExit(
            f"Codex ralplan natural Plan-Reviewer {reviewer_index} output lacked one "
            f"Reviewed draft id: {sorted(reviewed_ids)!r}"
        )
    reviewer_evidence.append(
        {
            "index": reviewer_index,
            "reviewer": reviewer,
            "output": reviewer_output,
            "reviewed_ids": reviewed_ids,
        }
    )

final_reviewer_evidence = [
    evidence
    for evidence in reviewer_evidence
    if evidence["reviewed_ids"] == planner_ids
]
if len(final_reviewer_evidence) not in (1, 2):
    observed_ids = sorted(
        next(iter(evidence["reviewed_ids"])) for evidence in reviewer_evidence
    )
    raise SystemExit(
        "Codex ralplan natural final Planner draft lacked one STANDARD review or "
        "one THOROUGH reviewer pair; "
        f"final={sorted(planner_ids)!r} observed={observed_ids!r}"
    )
planner_final_completion = planner["last_completion_timestamp"]
if not planner_final_completion:
    raise SystemExit("Codex ralplan natural final Planner draft lacked task_complete timing")
for evidence in final_reviewer_evidence:
    reviewer = evidence["reviewer"]
    reviewer_index = evidence["index"]
    reviewer_completion = reviewer["last_completion_timestamp"]
    reviewer_task = reviewer["last_task_timestamp"]
    if not reviewer_completion or reviewer_completion <= planner_final_completion:
        raise SystemExit(
            f"Codex ralplan natural final Plan-Reviewer {reviewer_index} completed "
            "before the final Planner draft"
        )
    if reviewer_task and reviewer_task <= planner_final_completion:
        raise SystemExit(
            f"Codex ralplan natural final Plan-Reviewer {reviewer_index} task was "
            "dispatched before the final Planner draft"
        )
    reviewer_input = reviewer["input"]
    reviewer_input_encrypted = reviewer["encrypted_task_messages"] >= 1
    if planner_output not in reviewer_input and not reviewer_input_encrypted:
        raise SystemExit(
            f"Codex ralplan natural final Plan-Reviewer {reviewer_index} task had neither "
            "the visible Planner payload nor an encrypted inter-agent task channel"
        )
if len(final_reviewer_evidence) == 2:
    final_review_dispatches = [
        evidence["reviewer"]["last_task_timestamp"]
        or evidence["reviewer"]["timestamp"]
        for evidence in final_reviewer_evidence
    ]
    final_review_completions = [
        evidence["reviewer"]["last_completion_timestamp"]
        for evidence in final_reviewer_evidence
    ]
    if (
        not all(final_review_dispatches)
        or not all(final_review_completions)
        or max(final_review_dispatches) >= min(final_review_completions)
    ):
        raise SystemExit(
            "Codex ralplan natural final THOROUGH reviewer pair was not dispatched "
            "before either review completed"
        )

def semantic_lines(value):
    lines = set()
    for line in normalize(value).splitlines():
        semantic = re.sub(r"^\s*(?:#{1,6}\s+|[-*]\s+)", "", line).strip()
        if semantic and semantic != "```":
            lines.add(semantic)
    return lines


planner_payload = normalize(planner_output)
planner_lines = semantic_lines(planner_payload)
parent_lines = semantic_lines(final_parent_output)
shared_planner_lines = planner_lines & parent_lines
planner_coverage = (
    len(shared_planner_lines) / len(planner_lines) if planner_lines else 0.0
)
if len(planner_lines) < 12 or planner_coverage < 0.85:
    raise SystemExit(
        "Codex ralplan natural parent did not preserve the complete Planner draft "
        f"(semantic line coverage {planner_coverage:.1%})"
    )
parent_planner_ids = {
    canonical_draft_id(value)
    for value in re.findall(
        r"(?mi)^\s*(?:-\s*)?Planner (?:draft |revision )?id:\s*(.*?)\s*$",
        final_parent_output,
    )
    if normalize(value).strip("` ")
}
if parent_planner_ids != planner_ids:
    raise SystemExit(
        "Codex ralplan natural parent Planner draft did not identify the final draft id"
    )
parent_ac_ids = set(re.findall(r"(?i)\bAC[- ]?([0-9]+)\b", final_parent_output))
if not ac_ids.issubset(parent_ac_ids):
    raise SystemExit(
        "Codex ralplan natural parent Planner draft omitted acceptance outcome ids"
    )
parent_reviewed_ids = {
    canonical_draft_id(value)
    for value in re.findall(
        r"(?mi)^\s*(?:-\s*)?Reviewed draft:\s*(.*?)\s*$",
        final_parent_output,
    )
    if normalize(value).strip("` ")
}
if parent_reviewed_ids != planner_ids:
    raise SystemExit(
        "Codex ralplan natural parent review synthesis did not identify the final Planner draft id"
    )
parent_planner_match = re.search(
    r"(?mi)^\s*(?:#{1,6}\s+Planner draft\b|(?:-\s*)?Planner (?:draft |revision )?id:)",
    final_parent_output,
)
parent_review_match = re.search(
    r"(?mi)^\s*(?:-\s*)?Reviewed draft:\s*.*$",
    final_parent_output,
)
if (
    not parent_planner_match
    or not parent_review_match
    or parent_planner_match.start() >= parent_review_match.start()
):
    raise SystemExit("Codex ralplan natural parent reversed Planner -> review synthesis order")
parent_review_text = final_parent_output[parent_review_match.start():]
if "review" not in parent_review_text.lower() or not any(
    token in parent_review_text.lower()
    for token in ("approve", "block", "iterate", "reject", "revision")
):
    raise SystemExit("Codex ralplan natural parent omitted the synthesized review decision")
if len(final_reviewer_evidence) == 2 and not any(
    marker in parent_review_text.lower()
    for marker in ("paired review", "paired-review", "both reviewers", "two reviewers")
):
    raise SystemExit(
        "Codex ralplan natural parent omitted evidence that it synthesized the reviewer pair"
    )
if not final_parent_output.rstrip().endswith("OH_NO_CODEX_RALPLAN_NATURAL_OK"):
    raise SystemExit("Codex ralplan natural parent did not end with its success marker")

print(
    "ok - live Codex ralplan natural typed child transcripts proved "
    "sequential planning and valid review topology"
)
PY
}

run_named_agents_live_test() {
  if [[ "$RUN_NAMED_AGENTS_LIVE" != "1" ]]; then
    log "Skipping live Codex named custom-agent smoke test"
    printf 'Run with --named-agents-live or OH_NO_NAMED_AGENTS_LIVE=1 to verify actual Codex agent_type=oh-no-* custom-agent spawns.\n' >&2
    return
  fi

  log "Running live Codex named custom-agent smoke test"
  mkdir -p "$RUN_DIR"

  local agent_type safe_agent out_file err_file prompt
  local expected_agents=(
    oh-no-analyst
    oh-no-code-reviewer
    oh-no-debugger
    oh-no-executor
    oh-no-explore
    oh-no-fusion-rescue-analyst
    oh-no-plan-reviewer
    oh-no-planner
    oh-no-verifier
  )

  local named_agent_temp_root
  named_agent_temp_root="$(mktemp -d)"
  CODEX_LIVE_TEMP_ROOTS+=("$named_agent_temp_root")

  local negative_home="$named_agent_temp_root/named-agents-negative-home"
  local negative_project_root="$named_agent_temp_root/named-agents-negative-project"
  local negative_out_file="$RUN_DIR/named-agents-negative.jsonl"
  local negative_err_file="$RUN_DIR/named-agents-negative.err"
  local negative_prompt
  rm -rf "$negative_home" "$negative_project_root"
  clone_codex_live_home "$CODEX_HOME_DIR" "$negative_home"
  rm -rf "$negative_home/agents"
  mkdir -p "$negative_project_root"

  negative_prompt='Codex custom-agent negative control. Do not edit files. Use spawn_agent exactly once with agent_type "oh-no-code-reviewer" and fork_turns "none" (never a full-history fork). Do not omit agent_type. Do not use a generic/default fallback. If spawn_agent fails because the requested agent_type is unavailable, report the exact failure and reply with OH_NO_CODEX_NAMED_AGENT_NEGATIVE_OK. If the spawn succeeds, close the receiver and reply with OH_NO_CODEX_NAMED_AGENT_NEGATIVE_FAILED.'

  local negative_cmd=(
    "$CODEX_BIN"
    --enable plugin_hooks
    --ask-for-approval never
    exec
    --json
    --cd "$negative_project_root"
    --sandbox read-only
    --skip-git-repo-check
  )

  if [[ -n "$LIVE_MODEL" ]]; then
    negative_cmd+=(--model "$LIVE_MODEL")
  fi

  run_in_verified_codex_live_home "$negative_home" "${negative_cmd[@]}" "$negative_prompt" >"$negative_out_file" 2>"$negative_err_file" || true

  "$PYTHON_BIN" - "$negative_out_file" "$negative_err_file" <<'PY'
import json
import sys

out_path = sys.argv[1]
err_path = sys.argv[2]

with open(err_path, "r", encoding="utf-8") as fh:
    err_text = fh.read()

text = ""
completed_receivers = []
if out_path:
    with open(out_path, "r", encoding="utf-8") as fh:
        for line in fh:
            if not line.strip():
                continue
            data = json.loads(line)
            item = data.get("item") or {}
            text += "\n" + (item.get("text") or data.get("result") or "")
            if (
                item.get("type") == "collab_tool_call"
                and item.get("tool") == "spawn_agent"
                and item.get("status") == "completed"
            ):
                completed_receivers.extend(item.get("receiver_thread_ids") or [])

combined = f"{err_text}\n{text}"
if completed_receivers:
    raise SystemExit(
        "Codex named-agent negative control unexpectedly spawned receivers without "
        f"user-scope or project-scope custom agents: {completed_receivers!r}"
    )
if "OH_NO_CODEX_NAMED_AGENT_NEGATIVE_FAILED" in combined:
    raise SystemExit("Codex named-agent negative control reported unexpected success")
if "unknown agent_type" not in combined.lower():
    raise SystemExit(
        "Codex named-agent negative control did not prove missing custom agents "
        f"produce unknown agent_type; stderr/text={combined[:2000]!r}"
    )
if "OH_NO_CODEX_NAMED_AGENT_NEGATIVE_OK" not in combined:
    raise SystemExit("Codex named-agent negative control did not return success marker")

print("ok - Codex named custom-agent negative control requires an installed custom agent")
PY

  local live_home="$named_agent_temp_root/named-agents-live-home"
  local live_project_root="$named_agent_temp_root/named-agents-live-project"
  rm -rf "$live_home" "$live_project_root"
  clone_codex_live_home "$CODEX_HOME_DIR" "$live_home"
  mkdir -p "$live_project_root"

  log "Installing isolated user-scope Codex custom agents for named-agent live test"
  run_in_verified_codex_live_home "$live_home" "$PLUGIN_ROOT/scripts/install-codex-agents" --scope user --force \
    >"$RUN_DIR/named-agents-live-user-install.out" \
    2>"$RUN_DIR/named-agents-live-user-install.err" || {
      cat "$RUN_DIR/named-agents-live-user-install.err" >&2
      fail "Codex named-agent live test could not install isolated user-scope custom agents"
    }

  local proof_map_file="$RUN_DIR/named-agent-proof-map.tsv"
  "$PYTHON_BIN" - "$live_home/agents" "$proof_map_file" "${expected_agents[@]}" <<'PY'
from pathlib import Path
import secrets
import sys

agents_dir = Path(sys.argv[1])
proof_map = Path(sys.argv[2])
rows = []
for agent_type in sys.argv[3:]:
    path = agents_dir / f"{agent_type}.toml"
    text = path.read_text(encoding="utf-8")
    needle = 'developer_instructions = """\n'
    nonce = secrets.token_hex(12)
    request = f"OH_NO_NAMED_AGENT_PROOF_REQUEST {nonce}"
    ok = f"OH_NO_NAMED_AGENT_PROOF_OK {agent_type} {nonce}"
    proof = (
        f"Live named-agent proof for {agent_type}.\n"
        f"If your task message is exactly \"{request}\", return exactly \"{ok}\" "
        f"and do not inspect files or add explanation.\n\n"
    )
    if needle not in text:
        raise SystemExit(f"{path} is missing developer_instructions header")
    path.write_text(text.replace(needle, needle + proof, 1), encoding="utf-8")
    rows.append(f"{agent_type}\t{request}\t{ok}\n")
proof_map.write_text("".join(rows), encoding="utf-8")
PY

  local cmd=(
    "$CODEX_BIN"
    --enable plugin_hooks
    --ask-for-approval never
    exec
    --json
    --cd "$live_project_root"
    --sandbox read-only
    --skip-git-repo-check
  )

  if [[ -n "$LIVE_MODEL" ]]; then
    cmd+=(--model "$LIVE_MODEL")
  fi

  for agent_type in "${expected_agents[@]}"; do
    safe_agent="${agent_type//[^A-Za-z0-9_]/_}"
    out_file="$RUN_DIR/named-agent-${safe_agent}.jsonl"
    err_file="$RUN_DIR/named-agent-${safe_agent}.err"
    proof_request="$(awk -F '\t' -v a="$agent_type" '$1 == a {print $2}' "$proof_map_file")"
    proof_ok="$(awk -F '\t' -v a="$agent_type" '$1 == a {print $3}' "$proof_map_file")"
    [[ -n "$proof_request" && -n "$proof_ok" ]] || fail "Codex named-agent live test could not load proof mapping for ${agent_type}"
    prompt="Codex custom agent name registration live probe for ${agent_type}. Do not edit files. Your FIRST tool call must be spawn_agent, called exactly once with agent_type \"${agent_type}\", fork_turns \"none\" (never a full-history fork), and message \"${proof_request}\". Do not omit agent_type. Do not call wait, close, or any other tool before that spawn_agent call succeeds. Do not inspect available-role comments or rendered schema text before spawning; the tool accepts agent_type as a string and the negative control already proved missing custom agents fail. You MUST attempt the spawn_agent tool call before reporting any failure, and you MUST NOT infer unavailability from schema comments or your own schema summary. Do not use generic/default agents. If the attempted spawn_agent call is rejected by the tool runtime, do not retry with a generic agent; reply OH_NO_CODEX_NAMED_AGENT_FAILED ${agent_type} with the exact failure. If spawn_agent succeeds, wait for that receiver, then close that receiver if a close tool exists; if no close/close_agent tool is available in this runtime, skip closing and include exactly: Close/cleanup was not available. Reply OH_NO_CODEX_NAMED_AGENT_OK ${agent_type} only after the wait completed. Do not mention any expected child output."

    run_in_verified_codex_live_home "$live_home" "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

    "$PYTHON_BIN" - "$agent_type" "$proof_request" "$proof_ok" "$live_home" "$out_file" "$err_file" <<'PY'
import json
import sys
from pathlib import Path

agent_type, proof_request, proof_ok, live_home, out_path, err_path = sys.argv[1:7]
role = agent_type.removeprefix("oh-no-")
nonce = proof_request.rsplit(" ", 1)[-1]

with open(err_path, "r", encoding="utf-8") as fh:
    err_text = fh.read()
for marker in ("unknown agent_type", "spawn failed", "agent thread limit reached", "full-history forked agents inherit", "provide either message or items"):
    if marker in err_text.lower():
        raise SystemExit(f"{agent_type} smoke saw spawn failure in stderr: {err_text[:2000]!r}")

spawn_events = []
failed_spawns = []
waited_receivers = {}
closed_receivers = {}
final_ok = False
parent_thread_id = None
all_text_parts = []

def collect_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(item) for item in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(item) for item in value)
    return ""

def parse_child_transcript(path):
    text = path.read_text(encoding="utf-8", errors="replace")
    rows = [json.loads(line) for line in text.splitlines() if line.strip()]
    meta = next(
        (row.get("payload") or {} for row in rows if row.get("type") == "session_meta"),
        {},
    )
    source = meta.get("source") if isinstance(meta.get("source"), dict) else {}
    subagent = source.get("subagent") if isinstance(source.get("subagent"), dict) else {}
    thread_spawn = (
        subagent.get("thread_spawn")
        if isinstance(subagent.get("thread_spawn"), dict)
        else {}
    )
    agent_role = meta.get("agent_role") or thread_spawn.get("agent_role")
    parent = meta.get("parent_thread_id") or thread_spawn.get("parent_thread_id")
    user_messages = []
    assistant_messages = []
    encrypted_task_messages = 0
    completed = False
    for row in rows:
        payload = row.get("payload") or {}
        if row.get("type") == "event_msg" and payload.get("type") == "task_complete":
            completed = True
            final_message = collect_text(payload.get("last_agent_message"))
            if final_message:
                assistant_messages.append(final_message)
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
    return {
        "text": text,
        "agent_role": agent_role,
        "parent": parent,
        "input": "\n".join(user_messages),
        "encrypted_task_messages": encrypted_task_messages,
        "output": "\n".join(dict.fromkeys(assistant_messages)),
        "completed": completed,
    }


def receiver_transcript(receiver):
    sessions_root = Path(live_home) / "sessions"
    session_candidates = list(sessions_root.rglob(f"*{receiver}*.jsonl"))
    if not session_candidates:
        raise SystemExit(f"{agent_type} could not find session transcript for receiver: {receiver}")
    parsed = [parse_child_transcript(path) for path in session_candidates]
    matches = [child for child in parsed if child["agent_role"] == agent_type]
    if len(matches) != 1:
        raise SystemExit(f"{agent_type} expected one typed transcript for receiver {receiver}, got {len(matches)}")
    return matches[0]

with open(out_path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        event_text = collect_text(data)
        if data.get("type") == "thread.started":
            parent_thread_id = data.get("thread_id") or parent_thread_id
        item = data.get("item") or {}
        if item.get("type") == "agent_message":
            all_text_parts.append(event_text)
        text = item.get("text") or data.get("result") or ""
        if f"OH_NO_CODEX_NAMED_AGENT_OK {agent_type}" in text:
            final_ok = True
        if "OH_NO_CODEX_NAMED_AGENT_FAILED" in text:
            raise SystemExit(f"{agent_type} smoke returned failure marker: {text[:2000]!r}")
        if item.get("type") != "collab_tool_call":
            continue
        tool = item.get("tool")
        status = item.get("status")
        if tool == "spawn_agent" and status == "completed":
            spawn_events.append(
                {
                    "index": index,
                    "prompt": item.get("prompt"),
                    "receivers": list(item.get("receiver_thread_ids") or []),
                }
            )
        if tool == "spawn_agent" and status == "failed":
            failed_spawns.append((index, collect_text(item)[:2000]))
        if tool in {"wait", "wait_agent"} and status == "completed":
            for receiver, state in (item.get("agents_states") or {}).items():
                if state.get("status") == "completed":
                    waited_receivers[receiver] = {
                        "index": index,
                        "message": state.get("message"),
                    }
        if tool == "close_agent" and status == "completed":
            for receiver in item.get("receiver_thread_ids") or []:
                closed_receivers[receiver] = {
                    "index": index,
                    "message": None,
                }
            for receiver, state in (item.get("agents_states") or {}).items():
                if state.get("status") == "completed":
                    closed_receivers[receiver] = {
                        "index": index,
                        "message": state.get("message"),
                    }

if failed_spawns:
    raise SystemExit(f"{agent_type} smoke saw failed spawn_agent calls: {failed_spawns!r}")

custom_prompt_marker = f"Agent prompt source: docs/agent-core/{role}.md"

def find_spawned_child_sessions():
    # Newer Codex CLIs (>= 0.144) stop emitting spawn_agent collab_tool_call
    # events in the exec --json stream, so the spawn proof must come from the
    # child session transcripts written under the isolated live home.
    sessions_root = Path(live_home) / "sessions"
    matches = []
    for path in sorted(sessions_root.rglob("rollout-*.jsonl")):
        child = parse_child_transcript(path)
        if child["agent_role"] != agent_type:
            continue
        if parent_thread_id and child["parent"] != parent_thread_id:
            continue
        matches.append((path, child))
    return matches

if spawn_events:
    if len(spawn_events) != 1:
        raise SystemExit(f"{agent_type} expected one completed spawn_agent call, got {spawn_events!r}")
    spawn_event = spawn_events[0]
    if spawn_event["prompt"] != proof_request:
        raise SystemExit(
            f"{agent_type} spawn prompt was {spawn_event['prompt']!r}, expected {proof_request!r}"
        )
    spawn_receivers = set(spawn_event["receivers"])
    if len(spawn_receivers) != 1:
        raise SystemExit(f"{agent_type} expected one spawned receiver, got {spawn_receivers!r}")
    for receiver in sorted(spawn_receivers):
        wait = waited_receivers.get(receiver)
        if wait is None:
            raise SystemExit(f"{agent_type} did not capture wait result for receiver: {receiver}")
        child_message = wait["message"] or ""
        if proof_ok not in child_message:
            raise SystemExit(
                f"{agent_type} child message was {child_message!r}, expected exact proof reply {proof_ok!r}"
            )
        child = receiver_transcript(receiver)
        if not child["completed"]:
            raise SystemExit(f"{agent_type} receiver {receiver} lacked task_complete")
        if proof_request not in child["input"] and child["encrypted_task_messages"] != 1:
            raise SystemExit(
                f"{agent_type} receiver {receiver} had neither the visible exact proof request "
                "nor one encrypted inter-agent task message"
            )
        if proof_ok not in child["output"]:
            raise SystemExit(f"{agent_type} receiver {receiver} did not produce the exact proof reply")
        if custom_prompt_marker not in child["text"]:
            raise SystemExit(
                f"{agent_type} receiver transcript did not include custom role prompt marker "
                f"{custom_prompt_marker!r}; generic/default agent dispatch would not satisfy this proof"
            )
        close = closed_receivers.get(receiver)
        if close is None and "close/cleanup was not available" not in "\n".join(all_text_parts).lower():
            raise SystemExit(
                f"{agent_type} left receiver {receiver} without close evidence or an unavailable-cleanup record"
            )
        if close is not None and wait["index"] >= close["index"]:
            raise SystemExit(
                f"{agent_type} close_agent completed before wait_agent captured the proof result"
            )
else:
    children = find_spawned_child_sessions()
    if len(children) != 1:
        raise SystemExit(
            f"{agent_type} expected exactly one spawned child session with "
            f"agent_role={agent_type!r} under the isolated live home, got "
            f"{[str(path) for path, _ in children]!r}; the stream also carried no "
            "spawn_agent collab events, so no named-agent dispatch was proven"
        )
    child_path, child = children[0]
    if not child["completed"]:
        raise SystemExit(f"{agent_type} child session {child_path} lacked task_complete")
    if proof_request not in child["input"] and child["encrypted_task_messages"] != 1:
        raise SystemExit(
            f"{agent_type} child session {child_path} had neither the visible exact proof request "
            "nor one encrypted inter-agent task message"
        )
    if proof_ok not in child["output"]:
        raise SystemExit(
            f"{agent_type} child session {child_path} never produced the proof reply "
            f"{proof_ok!r}; the custom developer_instructions were not applied"
        )
    if custom_prompt_marker not in child["text"]:
        raise SystemExit(
            f"{agent_type} child session {child_path} did not include custom role prompt "
            f"marker {custom_prompt_marker!r}; generic/default agent dispatch would not "
            "satisfy this proof"
        )
if not final_ok:
    raise SystemExit(f"{agent_type} did not return success marker")
PY
  done

  print_ok_count="${#expected_agents[@]}"
  ok "live Codex named custom agents spawned, waited, and lifecycle-cleaned by ${print_ok_count} oh-no-* agent_type values"
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

Panel 1 primary must be a Codex current-host subagent using spawn_agent with agent_type "oh-no-fusion-rescue-analyst". This is the cross-host consult panel, and it is allowed only because the Codex main agent has confirmed danger-full-access. Its message must include exactly these lines: Lens: primary; Marker: OH_NO_FUSION_PANEL_PRIMARY_CLAUDE; fusion depth: 1; Scope: this synthetic CI release-risk problem only; Do not edit files; Expected output: marker line plus assigned lens fields and the Claude response marker; Codex permission preflight: danger-full-access confirmed. This subagent must invoke \${CLAUDE_BIN:-claude} exactly once as an argument vector, not a shell-interpolated string, with these controls: --print, --model opus, --max-budget-usd ${FUSION_RESCUE_MAX_BUDGET_USD}, --permission-mode dontAsk, --no-session-persistence. Do not pass a --tools override: Claude Opus may use its own read-only tools to analyze, but the prompt and host permissions must forbid file edits, writes, installs, and mutating commands. Do not require Claude Task/Agent proof. Do not ask Claude Code to run a slash command, public workflow skill, Task, Agent, Workflow, subagent, /codex:rescue, codex:codex-rescue, or Claude-side fusion-rescue. The Claude prompt must be read-only and must state that Claude Opus must answer the assigned panel directly. It must return OH_NO_CLAUDE_FUSION_PANEL_OK plus lens name primary, strongest finding, evidence used, assumption under test, likely failure mode, recommended next action, confidence and why, what would change the conclusion, and fusion depth: 1. The Claude prompt must also state: this consult is read-only; do not edit files, write state, install plugins, run mutating commands, invoke rescue, fusion-rescue, cross-host consult, Codex, or another host from inside this panel. The primary Codex subagent must return OH_NO_FUSION_PANEL_PRIMARY_CLAUDE plus the Claude marker and a substantive summary of the Claude CI integration-test release analysis mentioning at least quarantine, auto-retry, root-cause, and release risk.

Panel 2 adversarial must be a Codex current-host subagent using spawn_agent with agent_type "oh-no-fusion-rescue-analyst". Its message must include exactly these lines: Lens: adversarial; Marker: OH_NO_FUSION_PANEL_ADVERSARIAL; fusion depth: 1; Do not invoke rescue, fusion-rescue, cross-host consult, or another host from inside this panel; Scope: this synthetic CI release-risk problem only; Do not edit files; Expected output: marker line plus assigned lens fields only. It must attack the assumptions behind quarantine, auto-retry, and shipping without root cause.

Panel 3 pragmatic must be a second Codex current-host subagent using spawn_agent with agent_type "oh-no-fusion-rescue-analyst". Its message must include exactly these lines: Lens: pragmatic; Marker: OH_NO_FUSION_PANEL_PRAGMATIC; fusion depth: 1; Do not invoke rescue, fusion-rescue, cross-host consult, or another host from inside this panel; Scope: this synthetic CI release-risk problem only; Do not edit files; Expected output: marker line plus assigned lens fields only. It must recommend the simplest reversible next step and verification path for the CI release-risk decision.

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

  run_codex_live_command "$CODEX_HOME_DIR" "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"
  if ! assert_no_codex_live_secret_leak \
    "$CODEX_HOME_DIR/auth.json" \
    "$out_file" \
    "$err_file" \
    "$CODEX_HOME_DIR/sessions"; then
    rm -f "$out_file" "$err_file" "$summary_file"
    fail "Codex Fusion Rescue live artifacts failed the credential-leak guard and were removed"
  fi

  "$PYTHON_BIN" - "$out_file" "$err_file" "$CODEX_HOME_DIR" "$FUSION_RESCUE_MAX_BUDGET_USD" "$summary_file" <<'PY'
import json
import re
import sys
from pathlib import Path

out_path, err_path, live_home, budget, summary_path = sys.argv[1:6]
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
    re.compile(r"sk-[A-Za-z0-9_-]{20,512}(?![A-Za-z0-9_-])"),
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
    tool_text_parts = []
    command_outputs = []
    claude_call_events = []
    event_shapes = []

    def command_from_payload(payload):
        raw = (
            payload.get("arguments")
            or payload.get("input")
            or payload.get("command")
            or payload.get("content")
            or ""
        )
        if isinstance(raw, str):
            try:
                decoded = json.loads(raw) if raw else {}
            except json.JSONDecodeError:
                return raw
        else:
            decoded = raw
        if isinstance(decoded, dict):
            for key in ("cmd", "command", "argv"):
                value = decoded.get(key)
                if isinstance(value, list):
                    return " ".join(str(item) for item in value)
                if value:
                    return str(value)
        if isinstance(decoded, list):
            return " ".join(str(item) for item in decoded)
        return str(decoded or "")

    for line_number, line in enumerate(transcript.splitlines(), 1):
        if not line.strip():
            continue
        data = json.loads(line)
        event_text = collect_text(data)
        if any(pattern.search(event_text) for pattern in secret_patterns):
            raise SystemExit(f"Fusion Rescue Codex live primary transcript exposed a secret-like value near line {line_number}")
        item = data.get("item") or {}
        payload = data.get("payload") or {}
        item_type_lower = str(item.get("type") or data.get("type") or "").lower()
        tool_lower = str(item.get("tool") or item.get("name") or data.get("tool") or data.get("name") or "").lower()
        command_text = str(item.get("command") or "")
        event_shapes.append(
            {
                "line": line_number,
                "data_type": data.get("type"),
                "item_type": item.get("type"),
                "item_tool": item.get("tool") or item.get("name"),
                "payload_type": payload.get("type"),
                "payload_name": payload.get("name"),
            }
        )
        if payload.get("type") == "function_call":
            tool_lower = str(payload.get("name") or tool_lower).lower()
            command_text = command_from_payload(payload) or command_text
        elif payload.get("type") == "custom_tool_call":
            tool_lower = str(payload.get("name") or tool_lower).lower()
            command_text = command_from_payload(payload) or command_text
        is_exec_command_call = (
            (
                payload.get("type") == "function_call"
                and payload.get("name") in {"exec_command", "functions.exec_command"}
            )
            or (
                payload.get("type") == "custom_tool_call"
                and payload.get("name") == "exec"
            )
            or (
                item_type_lower == "command_execution"
                and item.get("status") == "completed"
            )
        )
        if is_exec_command_call and command_text and any(
            pattern.search(command_text) for pattern in claude_command_patterns
        ):
            claude_call_events.append((line_number, command_text[:1000]))
        if item_type_lower in forbidden_write_tools or tool_lower in forbidden_write_tools:
            raise SystemExit(
                f"Fusion Rescue Codex live primary subagent saw write-capable event at line {line_number}: "
                f"type={item_type_lower!r} tool={tool_lower!r}"
            )
        if (
            item_type_lower == "command_execution"
            or (payload.get("type") == "function_call" and payload.get("name") in {"exec_command", "functions.exec_command"})
        ) and any(
            pattern.search(command_text) for pattern in forbidden_command_patterns
        ):
            raise SystemExit(
                f"Fusion Rescue Codex live primary subagent saw write-like command at line {line_number}: "
                f"{command_text[:1000]!r}"
            )
        item_type = item.get("type") or data.get("type")
        tool_name = item.get("tool") or item.get("name") or data.get("tool") or data.get("name") or ""
        if (
            "claude" in event_text.lower()
            and (
                is_exec_command_call
                or (
                    item_type in {"collab_tool_call", "function_call", "tool_call", "tool_use"}
                    and tool_name not in {"spawn_agent", "wait", "wait_agent", "close_agent"}
                )
            )
        ):
            tool_text_parts.append(event_text)
        if (
            item.get("type") == "command_execution"
            and item.get("status") == "completed"
            and "OH_NO_CLAUDE_FUSION_PANEL_OK" in str(item.get("aggregated_output") or "")
        ):
            command_outputs.append(str(item.get("aggregated_output") or ""))
        if (
            payload.get("type") == "function_call_output"
            and "OH_NO_CLAUDE_FUSION_PANEL_OK" in str(payload.get("output") or "")
        ):
            command_outputs.append(str(payload.get("output") or ""))
        if payload.get("type") == "custom_tool_call_output":
            custom_output = collect_text(payload)
            if "OH_NO_CLAUDE_FUSION_PANEL_OK" in custom_output:
                command_outputs.append(custom_output)

    tool_text = "\n".join(tool_text_parts)
    if not tool_text:
        raise SystemExit(
            "Fusion Rescue Codex live primary subagent did not expose a Claude CLI "
            f"tool call; event_shapes={event_shapes!r}"
        )
    if len(claude_call_events) != 1:
        raise SystemExit(
            "Fusion Rescue Codex live primary subagent must invoke Claude exactly once; "
            f"saw {len(claude_call_events)} candidate command call(s): {claude_call_events!r}"
        )
    for marker in required_claude_argv:
        if marker.lower() not in tool_text.lower():
            raise SystemExit(
                f"Fusion Rescue Codex live primary Claude tool call missed argv marker {marker!r}; "
                f"tool_text={tool_text[:2000]!r}"
            )
    tool_text_lower = tool_text.lower()
    missing_direct_terms = [
        term for term in required_claude_direct_prompt_terms if term not in tool_text_lower
    ]
    if missing_direct_terms:
        raise SystemExit(
            "Fusion Rescue Codex live primary Claude prompt missed a direct Opus panel-review instruction; "
            f"missing_terms={missing_direct_terms!r}; "
            f"tool_text={tool_text[:2000]!r}"
        )
    forbidden_prompt_hits = [
        pattern.pattern for pattern in forbidden_claude_prompt_patterns
        if pattern.search(tool_text)
    ]
    if forbidden_prompt_hits:
        raise SystemExit(
            "Fusion Rescue Codex live primary Claude prompt appears to delegate to "
            f"Claude-side workflow tooling instead of direct Opus review: {forbidden_prompt_hits!r}; "
            f"tool_text={tool_text[:2000]!r}"
        )
    if "--print" not in tool_text and " -p" not in tool_text:
        raise SystemExit(
            "Fusion Rescue Codex live primary Claude tool call did not use --print or -p; "
            f"tool_text={tool_text[:2000]!r}"
        )
    command_output = "\n".join(command_outputs)
    if "OH_NO_CLAUDE_FUSION_PANEL_OK" not in command_output:
        raise SystemExit("Fusion Rescue Codex live primary subagent did not capture Claude marker in command output")
    return tool_text, command_output

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

missing_waits = sorted(set(receiver_to_lens) - set(wait_index_by_receiver))
missing_closes = sorted(set(receiver_to_lens) - set(close_index_by_receiver))
all_non_user_text = "\n".join(non_user_text_parts)
if missing_waits:
    raise SystemExit(f"Fusion Rescue Codex live did not capture wait_agent results: {missing_waits!r}")
if (
    missing_closes
    and not used_transcript_fallback
    and "close/cleanup was not available" not in all_non_user_text.lower()
):
    raise SystemExit(
        "Fusion Rescue Codex live left receivers without close evidence or an unavailable-cleanup record: "
        f"{missing_closes!r}"
    )
early_closes = {
    receiver: (wait_index_by_receiver[receiver], close_index_by_receiver[receiver])
    for receiver in receiver_to_lens
    if receiver in close_index_by_receiver
    and close_index_by_receiver[receiver] <= wait_index_by_receiver[receiver]
}
if early_closes:
    raise SystemExit(f"Fusion Rescue Codex live closed receivers before wait results: {early_closes!r}")

for receiver, lens in receiver_to_lens.items():
    result_text = panel_result_by_receiver.get(receiver, "")
    lower_result_text = result_text.lower()
    marker = expected_markers[lens]
    if marker not in result_text:
        raise SystemExit(
            f"Fusion Rescue Codex live panel {lens} did not return marker {marker!r} "
            f"in wait result; result={result_text[:2000]!r}"
        )
    if lens not in lower_result_text:
        raise SystemExit(
            f"Fusion Rescue Codex live panel {lens} wait result did not name its lens; "
            f"result={result_text[:2000]!r}"
        )
    for field in required_panel_fields:
        if field not in lower_result_text:
            raise SystemExit(
                f"Fusion Rescue Codex live panel {lens} wait result missed field {field!r}; "
                f"result={result_text[:2000]!r}"
            )
    assert_meaningful_domain_analysis(f"panel {lens}", result_text)

primary_receivers = [receiver for receiver, lens in receiver_to_lens.items() if lens == "primary"]
if len(primary_receivers) != 1:
    raise SystemExit(f"Fusion Rescue Codex live expected exactly one primary receiver, got {primary_receivers!r}")
primary_receiver = primary_receivers[0]
primary_result = panel_result_by_receiver.get(primary_receiver, "")
if "OH_NO_CLAUDE_FUSION_PANEL_OK" not in primary_result:
    raise SystemExit(
        "Fusion Rescue Codex live primary Codex subagent result did not include Claude marker "
        "OH_NO_CLAUDE_FUSION_PANEL_OK"
    )
primary_claude_tool_text, claude_panel_output = inspect_primary_claude_call(receiver_transcripts[primary_receiver])
combined_claude_evidence = primary_result + "\n" + claude_panel_output
lower_claude_panel_output = combined_claude_evidence.lower()
if "OH_NO_CLAUDE_FUSION_PANEL_OK" not in combined_claude_evidence:
    raise SystemExit("Fusion Rescue Codex live did not capture Claude panel return marker")
for field in required_panel_fields:
    if field not in lower_claude_panel_output:
        raise SystemExit(
            f"Fusion Rescue Codex live Claude evidence missed field {field!r}; "
            f"output={combined_claude_evidence[:2000]!r}"
        )
assert_meaningful_domain_analysis("Claude primary panel", combined_claude_evidence)

non_user_text = "\n".join(non_user_text_parts)
success_text = "\n".join(
    part for part in non_user_text_parts
    if "OH_NO_CODEX_FUSION_RESCUE_LIVE_OK" in part
)
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
    "status": "passed",
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
        "tools": "disabled",
        "path": "Codex primary subagent -> Claude CLI",
        "primary_receiver": primary_receiver,
        "session_persistence": "disabled",
        "marker": "OH_NO_CLAUDE_FUSION_PANEL_OK",
        "tool_call_preview": primary_claude_tool_text[:1000],
    },
    "final_marker": "OH_NO_CODEX_FUSION_RESCUE_LIVE_OK",
}
Path(summary_path).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print("ok - live Codex Fusion Rescue spawned three panel agents, primary called Claude Opus, and main synthesized")
PY

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

Panel 1 primary must be a Codex current-host subagent using spawn_agent with agent_type "oh-no-fusion-rescue-analyst". Its message must include exactly these lines: Lens: primary; Marker: OH_NO_FUSION_PANEL_PRIMARY_SELF; fusion depth: 1; Do not invoke rescue, fusion-rescue, cross-host consult, Claude, or another host from inside this panel; Scope: this synthetic CI release-risk problem only; Do not edit files; Expected output: marker line plus assigned lens fields only. It must provide the strongest constructive diagnosis for quarantine, auto-retry, root-cause, CI signal, and release risk.

Panel 2 adversarial must be a Codex current-host subagent using spawn_agent with agent_type "oh-no-fusion-rescue-analyst". Its message must include exactly these lines: Lens: adversarial; Marker: OH_NO_FUSION_PANEL_ADVERSARIAL; fusion depth: 1; Do not invoke rescue, fusion-rescue, cross-host consult, Claude, or another host from inside this panel; Scope: this synthetic CI release-risk problem only; Do not edit files; Expected output: marker line plus assigned lens fields only. It must attack the assumptions behind quarantine, auto-retry, and shipping without root cause.

Panel 3 pragmatic must be a Codex current-host subagent using spawn_agent with agent_type "oh-no-fusion-rescue-analyst". Its message must include exactly these lines: Lens: pragmatic; Marker: OH_NO_FUSION_PANEL_PRAGMATIC; fusion depth: 1; Do not invoke rescue, fusion-rescue, cross-host consult, Claude, or another host from inside this panel; Scope: this synthetic CI release-risk problem only; Do not edit files; Expected output: marker line plus assigned lens fields only. It must recommend the simplest reversible next step and verification path for the CI release-risk decision.

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

  run_codex_live_command "$CODEX_HOME_DIR" "${fallback_cmd[@]}" "$fallback_prompt" >"$fallback_out_file" 2>"$fallback_err_file"
  if ! assert_no_codex_live_secret_leak \
    "$CODEX_HOME_DIR/auth.json" \
    "$fallback_out_file" \
    "$fallback_err_file" \
    "$CODEX_HOME_DIR/sessions"; then
    rm -f "$fallback_out_file" "$fallback_err_file" "$fallback_summary_file"
    fail "Codex Fusion Rescue permission-fallback artifacts failed the credential-leak guard and were removed"
  fi

  "$PYTHON_BIN" - "$fallback_out_file" "$fallback_err_file" "$CODEX_HOME_DIR" "$fallback_summary_file" <<'PY'
import json
import re
import sys
from pathlib import Path

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
    re.compile(r"sk-[A-Za-z0-9_-]{20,512}(?![A-Za-z0-9_-])"),
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
        is_exec_command_call = (
            item_type_lower == "command_execution"
            or (
                payload.get("type") == "function_call"
                and payload.get("name") in {"exec_command", "functions.exec_command"}
            )
        )
        if not is_exec_command_call:
            continue
        if any(pattern.search(command_text) for pattern in forbidden_command_patterns):
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
        if (
            item_type_lower == "command_execution"
            or (payload.get("type") == "function_call" and payload.get("name") in {"exec_command", "functions.exec_command"})
        ):
            if any(pattern.search(command_text) for pattern in forbidden_command_patterns):
                raise SystemExit(
                    f"Fusion Rescue Codex permission fallback saw write-like command at line {index}: "
                    f"{command_text[:1000]!r}"
                )
            if any(pattern.search(command_text) for pattern in claude_command_patterns):
                claude_command_hits.append((index, command_text[:1000]))
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
  local prompt
  mkdir -p "$live_workspace"
  prompt=$(cat <<'PROMPT'
Use the oh-no-harness:simplify skill with cross-host review. Read-only live cross-host fallback smoke test only: do not edit files, do not create artifacts, do not install plugins, and do not run nested rescue. This run is in DEFAULT mode (NOT require-cross-host).

Named THOROUGH trigger: security-sensitive public authentication contract review. Pairing is trigger-driven, not availability-driven.

This run is intentionally launched with Codex read-only sandbox permissions. Before any cross-host review or opposite-host consult, inspect the current Codex permission/sandbox context. Because the permission state is not danger-full-access, the Claude Code cross-host consult is UNAVAILABLE and UNAUTHORIZED: you must NOT invoke ${CLAUDE_BIN:-claude}, must NOT shell out to claude, must NOT make any cross-host or opposite-host hop, and must NOT invoke /codex:rescue, codex:codex-rescue, rescue, fusion-rescue, or another host. Treat the opposite host (Claude Code) as unavailable and take the default-mode Same-Host Parallel Fallback (two same-host Codex agents synthesized), NOT the cross-host path.

The diff under review (treat as the stable diff):
--- a/auth.py
+++ b/auth.py
@@
-def is_admin(user):
-    return user.role == "admin"
+def is_admin(user):
+    return user.role == "admin" or user.get("debug", False)
The reviewed change adds a debug bypass to an admin check. Because the opposite host is unavailable in default mode, dispatch EXACTLY TWO same-host Codex code-reviewer agents in parallel under distinct lenses, each running the COMPLETE code-reviewer role differing only by lens emphasis, then synthesize as the current Codex main judge.

Same-host agent Lens A must be a Codex current-host subagent using spawn_agent with agent_type "oh-no-code-reviewer", an adversarial correctness + security skeptic ("what breaks or is exploitable"). Its message must include exactly these lines: Lens: A adversarial correctness and security; Marker: OH_NO_XHOST_FALLBACK_LENS_A; Scope: the fixed auth.py diff only; Do not edit files; Do not invoke rescue, fusion-rescue, cross-host consult, Claude, or another host from inside this agent; Expected output: marker line plus strongest finding, evidence used, likely failure mode, recommended next action.

Same-host agent Lens B must be a second Codex current-host subagent using spawn_agent with agent_type "oh-no-code-reviewer", a maintainability + coverage completeness reviewer ("what is missing or regresses"). Its message must include exactly these lines: Lens: B maintainability and coverage; Marker: OH_NO_XHOST_FALLBACK_LENS_B; Scope: the fixed auth.py diff only; Do not edit files; Do not invoke rescue, fusion-rescue, cross-host consult, Claude, or another host from inside this agent; Expected output: marker line plus strongest finding, evidence used, likely failure mode, recommended next action.

Start both Codex subagents before waiting when possible. Wait for each receiver until completed, capture both results, then close both completed receivers only when the host exposes close_agent; otherwise include exactly: Close/cleanup was not available. If wait_agent returns no agents completed yet, wait longer; MUST NOT close a running or pending receiver. After both same-host agents finish, synthesize immediately as the current Codex main judge rather than concatenate. Final answer must contain exactly the marker OH_NO_XHOST_FALLBACK_OK and must include: Codex permission preflight: not danger-full-access; Claude unavailable: Codex permission state is not danger-full-access; same-host agents: 2; lens markers: OH_NO_XHOST_FALLBACK_LENS_A, OH_NO_XHOST_FALLBACK_LENS_B; a single synthesis block marked OH_NO_XHOST_FALLBACK_SYNTHESIS with consensus, contradictions, and recommended next action; and a fallback note stating the opposite host (Claude Code) was treated as unavailable and the review ran via the Same-Host Parallel Fallback of two same-host agents rather than as a single current-host pass or a cross-host consult. Do NOT emit OH_NO_CLAUDE_FUSION_PANEL_OK or any Claude/opposite-host success marker and do NOT claim a cross-host consult occurred.
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

  "$PYTHON_BIN" - "$out_file" "$err_file" "$CODEX_HOME_DIR" "$summary_file" <<'PY'
import json
import re
import sys
from pathlib import Path

out_path, err_path, live_home, summary_path = sys.argv[1:5]
expected_lens_markers = {
    "A": "OH_NO_XHOST_FALLBACK_LENS_A",
    "B": "OH_NO_XHOST_FALLBACK_LENS_B",
}
required_final_markers = [
    "OH_NO_XHOST_FALLBACK_OK",
    "OH_NO_XHOST_FALLBACK_LENS_A",
    "OH_NO_XHOST_FALLBACK_LENS_B",
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
required_panel_fields = [
    "strongest finding",
    "evidence used",
    "likely failure mode",
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
    re.compile(r"sk-[A-Za-z0-9_-]{20,512}(?![A-Za-z0-9_-])"),
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


def missing_panel_evidence(text):
    lower_text = text.lower()
    checks = {
        "strongest finding": bool(
            "strongest finding" in lower_text
            or re.search(r"(?im)^\s*blocking finding ids:\s*(?!none\b)\S+", text)
            or re.search(r"(?im)^\s*[-*]\s*[A-Z]+-[0-9]+\s*[—-]\s*(?:critical|high)\b", text)
        ),
        "evidence used": bool(
            "evidence used" in lower_text
            or re.search(r"(?im)^\s*(?:[-*]\s*)?evidence\s*:", text)
            or re.search(r"(?im)^\s*reviewed revision/diff fingerprint\s*:", text)
        ),
        "likely failure mode": bool(
            "likely failure mode" in lower_text
            or re.search(r"(?im)^\s*(?:[-*]\s*)?(?:failure mode|regression)\s*:", text)
        ),
        "recommended next action": bool(
            "recommended next action" in lower_text
            or re.search(r"(?im)^\s*(?:[-*]\s*)?(?:required mitigations?|safe (?:cleanup )?action)\s*:", text)
        ),
    }
    return [field for field, present in checks.items() if not present]


def role_of_event(data):
    item = data.get("item") or {}
    message = data.get("message") or {}
    return item.get("role") or data.get("role") or message.get("role") or ""

def receiver_transcript_and_agent_role(receiver):
    sessions_root = Path(live_home) / "sessions"
    session_candidates = list(sessions_root.rglob(f"*{receiver}*.jsonl"))
    if not session_candidates:
        raise SystemExit(f"Codex cross-host fallback live could not find session transcript for receiver: {receiver}")
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
    raise SystemExit(f"Codex cross-host fallback live transcript lacked session_meta: {receiver}")


def parent_linked_lens_transcripts(parent_thread_id):
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
        if parent != parent_thread_id or agent_role != "oh-no-code-reviewer":
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
            lens for lens, marker in expected_lens_markers.items()
            if marker in task_output
        ]
        if len(matched_output) != 1:
            raise SystemExit(
                "Codex cross-host fallback parent-linked child output did not identify "
                f"exactly one lens: {matched_output!r}"
            )
        lens = matched_output[0]
        matched_input = [
            candidate for candidate, marker in expected_lens_markers.items()
            if marker in task_input
        ]
        if encrypted_task_messages < 1 and matched_input != [lens]:
            raise SystemExit(
                f"Codex cross-host fallback plaintext task did not match {lens} and "
                f"lacked encrypted task-channel evidence: {matched_input!r}"
            )
        if lens in children:
            raise SystemExit(f"Codex cross-host fallback found duplicate parent-linked transcripts for lens {lens}")
        if not completed:
            raise SystemExit(f"Codex cross-host fallback parent-linked lens {lens} child lacked task_complete")
        receiver = meta.get("id") or meta.get("session_id") or path.stem
        children[lens] = {
            "receiver": receiver,
            "text": text,
            "role": agent_role,
            "input": task_input if matched_input == [lens] else "",
            "encrypted_task_messages": encrypted_task_messages,
            "output": task_output,
        }
    if linked_children != len(expected_lens_markers):
        raise SystemExit(
            "Codex cross-host fallback expected exactly two parent-linked lens sessions, "
            f"found {linked_children}"
        )
    return children


def inspect_fallback_receiver_transcript(receiver, lens, transcript):
    host_command_hits = []
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
        is_exec_command_call = (
            item_type_lower == "command_execution"
            or (
                payload.get("type") == "function_call"
                and payload.get("name") in {"exec_command", "functions.exec_command"}
            )
        )
        if not is_exec_command_call:
            continue
        if any(pattern.search(command_text) for pattern in forbidden_command_patterns):
            raise SystemExit(
                f"Codex cross-host fallback live receiver {receiver} ({lens}) saw write-like command "
                f"at line {line_number}: {command_text[:1000]!r}"
            )
        if any(pattern.search(command_text) for pattern in claude_command_patterns):
            host_command_hits.append((line_number, "claude", command_text[:1000]))
    if host_command_hits:
        raise SystemExit(
            f"Codex cross-host fallback live receiver {receiver} ({lens}) invoked a forbidden Claude/opposite-host command: "
            f"{host_command_hits!r}"
        )

with open(err_path, "r", encoding="utf-8") as fh:
    err_text = fh.read()
if "spawn failed" in err_text.lower() or "agent thread limit reached" in err_text.lower():
    raise SystemExit(f"Codex cross-host fallback live saw spawn failure in stderr: {err_text[:2000]!r}")

failed_spawns = []
all_spawn_receivers = []
receiver_to_lens = {}
receiver_agent_roles = {}
receiver_transcripts = {}
agent_result_by_receiver = {}
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
        if (
            item_type_lower == "command_execution"
            or (payload.get("type") == "function_call" and payload.get("name") in {"exec_command", "functions.exec_command"})
        ):
            if any(pattern.search(command_text) for pattern in forbidden_command_patterns):
                raise SystemExit(
                    f"Codex cross-host fallback live saw write-like command at line {index}: "
                    f"{command_text[:1000]!r}"
                )
            if any(pattern.search(command_text) for pattern in claude_command_patterns):
                claude_command_hits.append((index, command_text[:1000]))
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
            matched = [lens for lens, marker in expected_lens_markers.items() if marker in spawn_text]
            if not matched:
                raise SystemExit(
                    "Codex cross-host fallback live saw an unexpected spawn_agent call "
                    f"without a required lens marker at line {index}: {spawn_text[:2000]!r}"
                )
            if len(matched) != 1:
                raise SystemExit(
                    f"Codex cross-host fallback live spawn payload matched multiple lenses {matched!r}; "
                    f"text={spawn_text[:2000]!r}"
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
    missing_transcript_lenses = sorted(set(expected_lens_markers) - set(transcript_children))
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
        wait_index_by_receiver[receiver] = 0
        all_spawn_receivers.append(receiver)

# Two distinct same-host lens agents (two agents, not one pass).
missing_lenses = sorted(set(expected_lens_markers) - set(receiver_to_lens.values()))
if missing_lenses:
    raise SystemExit(
        f"Codex cross-host fallback live did not dispatch both same-host lens agents; "
        f"missing={missing_lenses!r} got={receiver_to_lens!r}"
    )
if len(receiver_to_lens) != len(expected_lens_markers):
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
    marker = expected_lens_markers[lens]
    if marker not in result_text:
        raise SystemExit(
            f"Codex cross-host fallback live lens {lens} did not return marker {marker!r}; "
            f"result={result_text[:2000]!r}"
        )
    for forbidden in forbidden_crosshost_markers:
        if forbidden in result_text:
            raise SystemExit(
                f"Codex cross-host fallback live lens {lens} returned forbidden opposite-host marker {forbidden!r}"
            )
    missing_fields = missing_panel_evidence(result_text)
    if missing_fields:
        raise SystemExit(
            f"Codex cross-host fallback live lens {lens} wait result lacked semantic "
            f"panel evidence: {missing_fields!r}; result={result_text[:2000]!r}"
        )

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
            "returned_marker": expected_lens_markers[receiver_to_lens[receiver]],
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

run_parallel_live_test() {
  if [[ "$RUN_PARALLEL_LIVE" != "1" ]]; then
    log "Skipping live Codex parallel-subagent smoke test"
    printf 'Run with --parallel-live or OH_NO_PARALLEL_LIVE=1 to verify actual Codex spawn_agent use and agent-prompt embedding.\n' >&2
    return
  fi

  log "Running live Codex parallel-subagent smoke test"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/parallel-subagents.jsonl"
  local err_file="$RUN_DIR/parallel-subagents.err"
  local prompt
  prompt='Use the oh-no-harness:ralph skill. Read-only live subagent smoke test. This is an explicit parallel subagents request. Verify every Ralph-eligible Oh No Harness role with Codex spawn_agent custom agents, but respect platform concurrency limits: run the roles in independent waves of at most three subagents, start every subagent in the current wave before waiting for that wave, call close_agent for every completed agent before starting the next wave when the host exposes it; otherwise include exactly: Close/cleanup was not available. Do not continue if any spawn fails. For every receiver thread, call wait_agent until that receiver appears in a completed final-status wait result before calling close_agent; do not use close_agent as the first result capture for any receiver, and if wait_agent returns no agents completed yet then wait longer. MUST NOT call close_agent for a running or pending agent merely because it is slow. Wave 1: explore, analyst, planner. Wave 2: executor, debugger. Wave 3: verifier, code-reviewer, fusion-rescue-analyst. Do not dispatch plan-reviewer: only the Ralplan planning phase owns that role, and the separate Ralplan live smoke covers it. For every Codex spawn_agent call, set agent_type to the matching registered custom agent oh-no-<role>, omit model/reasoning overrides, and do not fork full history. Do not use generic/default agents and do not embed docs/agent-core prompt bodies while the registered oh-no-* custom agent is available. Each spawned-agent message MUST include Role: <role>, Codex agent type: oh-no-<role>, Scope, Expected output, Verification responsibility, Lifecycle, and Result marker: OH_NO_PARALLEL_RESULT <role> lines. Each custom agent should report the exact OH_NO_PARALLEL_RESULT <role> marker, its role heading, and whether Skill Relationship, Responsibilities, Operating Rules, and Output are present. Do not edit files. Preserve every role-specific result marker in the parent final response. After all eight subagents finish and completed agents are closed when supported, or unavailable cleanup is recorded, reply exactly OH_NO_CODEX_PARALLEL_SUBAGENTS_OK and summarize the eight role checks plus Used custom agent types: 8; Wait results captured: 8; Lifecycle cleanup: closed | unavailable.'
  prompt="${prompt} The host accepts agent_type as a string even if rendered schema text or display comments omit it; do not inspect schema comments or block on missing displayed agent_type. Attempt each requested oh-no-* agent_type call first, and only treat custom agents as unavailable after an actual unknown/unavailable rejection."

  local cmd=(
    "$CODEX_BIN"
    --enable plugin_hooks
    --ask-for-approval never
    exec
    --json
    --cd "$PLUGIN_ROOT"
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
    rm -f "$out_file" "$err_file"
    fail "Codex Parallel explicit live artifacts failed the credential-leak guard and were removed"
  fi

  "$PYTHON_BIN" - "$out_file" "$err_file" "$CODEX_HOME_DIR" <<'PY'
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

path = sys.argv[1]
err_path = sys.argv[2]
live_home = sys.argv[3]
successful_spawns = []
failed_spawns = []
spawn_texts = []
spawn_texts_by_role = defaultdict(list)
first_wait_index = None
receiver_to_role = {}
wait_index_by_receiver = {}
wait_result_by_receiver = {}
close_index_by_receiver = {}
marker = False
all_text_parts = []
parent_thread_id = None

def collect_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(item) for item in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(item) for item in value)
    return ""

with open(err_path, "r", encoding="utf-8") as fh:
    err_text = fh.read()
if (
    "spawn failed" in err_text.lower()
    or "agent thread limit reached" in err_text.lower()
    or "full-history forked agents inherit" in err_text.lower()
    or "provide either message or items" in err_text.lower()
):
    raise SystemExit(f"Codex live parallel smoke saw spawn failure in stderr: {err_text[:2000]!r}")

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
role_headings = {
    "explore": "# Explore Agent",
    "analyst": "# Analyst Agent",
    "planner": "# Planner Agent",
    "executor": "# Executor Agent",
    "debugger": "# Debugger Agent",
    "verifier": "# Verifier Agent",
    "code-reviewer": "# Code Reviewer Agent",
    "fusion-rescue-analyst": "# Fusion Rescue Analyst Agent",
}
role_waves = [
    ("explore", "analyst", "planner"),
    ("executor", "debugger"),
    ("verifier", "code-reviewer", "fusion-rescue-analyst"),
]
required_prompt_markers = [
    "## Skill Relationship",
    "## Responsibilities",
    "## Operating Rules",
    "## Output",
]

def roles_in_text(text):
    return [
        role for role in expected_roles
        if f"Codex agent type: oh-no-{role}".lower() in text.lower()
    ]


def has_role_heading(text, role):
    heading = role_headings[role].lstrip("#").strip().lower()
    role_identity = re.sub(r"[-_]+", " ", role).strip().lower()
    marker = f"OH_NO_PARALLEL_RESULT {role}".lower()
    for line in text.splitlines():
        normalized = re.sub(r"^\s*[-+]\s*", "", line)
        normalized = normalized.replace("`", "").replace("*", "")
        normalized = re.sub(r"^\s*#{1,6}\s*", "", normalized).strip().lower()
        if normalized == heading:
            return True
        if normalized.startswith("role heading:") and heading in normalized:
            return True
        if normalized.startswith("role:"):
            reported_role = re.sub(
                r"[-_]+",
                " ",
                normalized.removeprefix("role:").strip(),
            )
            if reported_role in {role_identity, heading.removesuffix(" agent")}:
                return True
        if marker in normalized and heading in normalized:
            return True
        if normalized.startswith(heading) and normalized[len(heading):].strip(" :;-") == "present":
            return True
    return False


def mentioned_receivers(item):
    text = collect_text(item)
    mentioned = set(item.get("receiver_thread_ids") or [])
    mentioned.update((item.get("agents_states") or {}).keys())
    mentioned.update(
        receiver for receiver in receiver_to_role
        if receiver in text
    )
    return mentioned & set(receiver_to_role)

def receiver_agent_role(receiver):
    sessions_root = Path(live_home) / "sessions"
    session_candidates = list(sessions_root.rglob(f"*{receiver}*.jsonl"))
    if not session_candidates:
        raise SystemExit(f"Codex live parallel smoke could not find session transcript for receiver: {receiver}")
    for path in session_candidates:
        with path.open("r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
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
                return payload.get("agent_role") or thread_spawn.get("agent_role")
    raise SystemExit(f"Codex live parallel smoke transcript lacked session_meta: {receiver}")

events = []
with open(path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        if data.get("type") == "thread.started":
            parent_thread_id = data.get("thread_id") or parent_thread_id
        item = data.get("item") or {}
        event_text = collect_text(data)
        if item.get("type") == "agent_message":
            all_text_parts.append(event_text)
            if "OH_NO_CODEX_PARALLEL_SUBAGENTS_OK" in event_text:
                marker = True
        if (
            item.get("type") == "collab_tool_call"
            and item.get("tool") in {"wait", "wait_agent"}
            and first_wait_index is None
        ):
            first_wait_index = index
        if item.get("type") == "collab_tool_call" and item.get("tool") == "spawn_agent" and item.get("status") == "completed":
            receivers = item.get("receiver_thread_ids") or []
            if receivers:
                successful_spawns.append((index, tuple(receivers)))
                spawn_text = collect_text(item)
                spawn_texts.append(spawn_text)
                matched_roles = roles_in_text(spawn_text)
                if len(matched_roles) != 1:
                    raise SystemExit(
                        "expected each completed spawn_agent payload to contain exactly one role prompt source; "
                        f"line={index} roles={matched_roles!r} text={spawn_text[:2000]!r}"
                    )
                role = matched_roles[0]
                spawn_texts_by_role[role].append(spawn_text)
                for receiver in receivers:
                    receiver_to_role[receiver] = role
                events.append((index, "spawn", role))
        if item.get("type") == "collab_tool_call" and item.get("tool") == "spawn_agent" and item.get("status") == "failed":
            failed_spawns.append((index, collect_text(item)[:2000]))
        if item.get("type") == "collab_tool_call" and item.get("status") == "completed":
            tool = item.get("tool")
            receivers = mentioned_receivers(item)
            if tool in {"wait", "wait_agent"}:
                for receiver in receivers:
                    state = (item.get("agents_states") or {}).get(receiver) or {}
                    if state.get("status") == "completed" and state.get("message"):
                        wait_index_by_receiver.setdefault(receiver, index)
                        wait_result_by_receiver.setdefault(receiver, str(state.get("message")))
            if tool == "close_agent":
                for receiver in receivers:
                    close_index_by_receiver.setdefault(receiver, index)

if failed_spawns:
    raise SystemExit(f"Codex live parallel smoke saw failed spawn_agent calls: {failed_spawns!r}")
if len(successful_spawns) < len(expected_roles):
    if successful_spawns:
        raise SystemExit(
            "Codex live parallel smoke emitted only a partial collab event stream: "
            f"{successful_spawns!r}"
        )
    if not parent_thread_id:
        raise SystemExit("Codex live parallel smoke lacked both collab events and a parent thread id")

    transcript_children = {}
    sessions_root = Path(live_home) / "sessions"
    for transcript_path in sessions_root.rglob("*.jsonl"):
        rows = [
            json.loads(line)
            for line in transcript_path.read_text(encoding="utf-8", errors="replace").splitlines()
            if line.strip()
        ]
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
        if parent != parent_thread_id or not isinstance(agent_role, str):
            continue
        if not agent_role.startswith("oh-no-"):
            continue
        role = agent_role.removeprefix("oh-no-")
        if role not in expected_roles:
            continue
        if role in transcript_children:
            raise SystemExit(f"Codex live parallel smoke found duplicate child sessions for {role}")
        completed = False
        completion_timestamp = ""
        assistant_messages = []
        task_complete_messages = []
        user_messages = []
        encrypted_task_messages = 0
        for row in rows:
            payload = row.get("payload") or {}
            if row.get("type") == "event_msg" and payload.get("type") == "task_complete":
                completed = True
                completion_timestamp = row.get("timestamp", "") or completion_timestamp
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
            if payload.get("role") == "assistant":
                assistant_messages.append(collect_text(payload.get("content")))
            elif payload.get("role") == "user":
                user_messages.append(collect_text(payload.get("content")))
        if not completed:
            raise SystemExit(f"Codex live parallel typed child {role} lacked task_complete")
        transcript_children[role] = {
            "started": meta.get("timestamp", ""),
            "completed": completion_timestamp,
            "input": "\n".join(user_messages),
            "encrypted_task_messages": encrypted_task_messages,
            "output": (
                task_complete_messages[-1]
                if task_complete_messages
                else "\n".join(dict.fromkeys(assistant_messages))
            ),
        }

    missing_children = sorted(set(expected_roles) - set(transcript_children))
    if missing_children:
        raise SystemExit(
            "Codex live parallel smoke omitted typed child session proof for roles: "
            f"{missing_children!r}"
        )
    parent_text = "\n".join(all_text_parts)
    if not marker:
        raise SystemExit("Codex live parallel typed children completed but parent omitted the success marker")
    completion_markers = (
        "Skill Relationship: present",
        "Responsibilities: present",
        "Operating Rules: present",
        "Output: present",
    )
    for role, child in transcript_children.items():
        required_input = (f"Result marker: OH_NO_PARALLEL_RESULT {role}",)
        missing_input = [
            value for value in required_input
            if value.lower() not in child["input"].lower()
        ]
        if missing_input and child["encrypted_task_messages"] < 1:
            raise SystemExit(
                f"Codex live parallel typed child {role} task omitted its result protocol "
                f"and lacked encrypted task-channel evidence: {missing_input!r}"
            )
        required_output = (
            f"OH_NO_PARALLEL_RESULT {role}",
            *completion_markers,
        )
        missing_output = [value for value in required_output if value.lower() not in child["output"].lower()]
        if not has_role_heading(child["output"], role):
            missing_output.append(f"role heading: {role_headings[role]}")
        if missing_output:
            raise SystemExit(
                f"Codex live parallel typed child {role} lacked role-owned output evidence: {missing_output!r}"
            )
        if f"OH_NO_PARALLEL_RESULT {role}" not in parent_text:
            raise SystemExit(f"Codex live parallel parent omitted the captured result marker for {role}")
    # Child lifetimes do not reveal when the parent issued wait_agent: a fast
    # child may finish before the last sequential spawn call without any wait.
    # The collab-event branch proves spawn-before-wait when those events exist;
    # this fallback proves valid child lifetimes and hard inter-wave barriers.
    for wave in role_waves:
        wave_starts = [transcript_children[role]["started"] for role in wave]
        wave_completions = [transcript_children[role]["completed"] for role in wave]
        if not all(wave_starts) or not all(wave_completions):
            raise SystemExit(
                "Codex live parallel typed child wave lacked lifecycle timestamps: "
                f"wave={wave!r} starts={wave_starts!r} completions={wave_completions!r}"
            )
        invalid_lifetimes = {
            role: (
                transcript_children[role]["started"],
                transcript_children[role]["completed"],
            )
            for role in wave
            if transcript_children[role]["started"] >= transcript_children[role]["completed"]
        }
        if invalid_lifetimes:
            raise SystemExit(
                "Codex live parallel typed child lifecycle timestamps were invalid: "
                f"{invalid_lifetimes!r}"
            )
    for earlier_wave, later_wave in zip(role_waves, role_waves[1:]):
        earlier_completions = [transcript_children[role]["completed"] for role in earlier_wave]
        later_starts = [transcript_children[role]["started"] for role in later_wave]
        if (
            not all(earlier_completions)
            or not all(later_starts)
            or max(earlier_completions) >= min(later_starts)
        ):
            raise SystemExit(
                "Codex live parallel typed child completion barriers violated the requested waves: "
                f"earlier_completions={earlier_completions!r} later_starts={later_starts!r}"
            )
    print("ok - live Codex role subagents proved by typed child transcripts (collab events unavailable)")
    raise SystemExit(0)
receiver_ids = {rid for _, receivers in successful_spawns[:len(expected_roles)] for rid in receivers}
if len(receiver_ids) < len(expected_roles):
    raise SystemExit(f"expected {len(expected_roles)} distinct spawned receiver threads, got {receiver_ids!r}")
for receiver in receiver_ids:
    role = receiver_to_role.get(receiver)
    expected_agent_role = f"oh-no-{role}"
    actual_agent_role = receiver_agent_role(receiver)
    if actual_agent_role != expected_agent_role:
        raise SystemExit(
            f"Codex live parallel smoke spawned receiver {receiver} with agent_role={actual_agent_role!r}, "
            f"expected {expected_agent_role!r}; generic/default dispatch is not acceptable"
        )
missing_wait_results = sorted(receiver_ids - set(wait_index_by_receiver))
missing_closes = sorted(receiver_ids - set(close_index_by_receiver))
all_text = "\n".join(all_text_parts)
if missing_wait_results:
    raise SystemExit(f"Codex live parallel smoke did not capture final wait_agent results for receivers: {missing_wait_results!r}")
if missing_closes and "close/cleanup was not available" not in all_text.lower():
    raise SystemExit(
        "Codex live parallel smoke left receivers without close evidence or an unavailable-cleanup record: "
        f"{missing_closes!r}"
    )
early_closes = {
    receiver: (wait_index_by_receiver[receiver], close_index_by_receiver[receiver])
    for receiver in receiver_ids
    if receiver in close_index_by_receiver
    and close_index_by_receiver[receiver] <= wait_index_by_receiver[receiver]
}
if early_closes:
    raise SystemExit(
        "Codex live parallel smoke closed agents before their wait_agent results were captured: "
        f"{early_closes!r}"
    )
spawn_index_by_role = {
    role: index for index, event_type, role in events if event_type == "spawn"
}
receiver_by_role = {role: receiver for receiver, role in receiver_to_role.items()}
for wave in role_waves:
    first_wave_wait = min(wait_index_by_receiver[receiver_by_role[role]] for role in wave)
    late_spawns = {
        role: spawn_index_by_role[role]
        for role in wave
        if spawn_index_by_role[role] >= first_wave_wait
    }
    if late_spawns:
        raise SystemExit(
            "Codex live parallel smoke did not start every role in a wave before waiting: "
            f"wave={wave!r} first_wait={first_wave_wait} late_spawns={late_spawns!r}"
        )
for earlier_wave, later_wave in zip(role_waves, role_waves[1:]):
    later_start = min(spawn_index_by_role[role] for role in later_wave)
    late_results = {
        role: wait_index_by_receiver.get(receiver_by_role[role])
        for role in earlier_wave
        if wait_index_by_receiver.get(receiver_by_role[role], later_start) >= later_start
    }
    if late_results:
        raise SystemExit(
            "Codex live parallel smoke started a later wave before every prior result completed: "
            f"later_start={later_start} late_results={late_results!r}"
        )
    late_closes = {
        role: close_index_by_receiver[receiver_by_role[role]]
        for role in earlier_wave
        if receiver_by_role[role] in close_index_by_receiver
        and close_index_by_receiver[receiver_by_role[role]] >= later_start
    }
    if late_closes:
        raise SystemExit(
            "Codex live parallel smoke started a later wave before closing completed prior receivers: "
            f"later_start={later_start} late_closes={late_closes!r}"
        )
for role in expected_roles:
    role_payloads = spawn_texts_by_role.get(role, [])
    if len(role_payloads) != 1:
        raise SystemExit(f"expected exactly one successful spawn_agent payload for {role}, got {len(role_payloads)}")
    role_text = role_payloads[0]
    missing_prompt_markers = [
        marker for marker in [
            f"Codex agent type: oh-no-{role}",
            f"Result marker: OH_NO_PARALLEL_RESULT {role}",
        ]
        if marker.lower() not in role_text.lower()
    ]
    if missing_prompt_markers:
        raise SystemExit(
            f"Codex spawn_agent payload for {role} did not use required custom-agent markers: "
            f"{missing_prompt_markers}; spawn_text={role_text[:2000]!r}"
        )
    forbidden_frontmatter_markers = [
        "\n---\n",
        "\ntools:",
        "\nmodel:",
        "\ncolor:",
        "Agent prompt content:",
        f"Agent prompt source: docs/agent-core/{role}.md",
    ]
    leaked = [marker for marker in forbidden_frontmatter_markers if marker in role_text]
    if leaked:
        raise SystemExit(
            f"Codex spawn_agent payload for {role} leaked Claude YAML frontmatter markers: "
            f"{leaked}; spawn_text={role_text[:2000]!r}"
        )
receiver_by_role = {role: receiver for receiver, role in receiver_to_role.items()}
for role in expected_roles:
    receiver = receiver_by_role.get(role)
    if not receiver:
        raise SystemExit(f"Codex live parallel smoke lacked a receiver for {role}")
    result = wait_result_by_receiver.get(receiver, "")
    required_result = (
        f"OH_NO_PARALLEL_RESULT {role}",
        "Skill Relationship: present",
        "Responsibilities: present",
        "Operating Rules: present",
        "Output: present",
    )
    missing_result = [value for value in required_result if value.lower() not in result.lower()]
    if not has_role_heading(result, role):
        missing_result.append(f"role heading: {role_headings[role]}")
    if missing_result:
        raise SystemExit(
            f"Codex live parallel result for {role} lacked role-owned evidence: "
            f"{missing_result!r}; result={result[:2000]!r}"
        )
    if f"OH_NO_PARALLEL_RESULT {role}" not in all_text:
        raise SystemExit(f"Codex live parallel parent omitted the captured result marker for {role}")
if not marker:
    raise SystemExit("Codex live parallel smoke did not return success marker")

print("ok - live Codex role subagents spawned with role-owned result evidence")
PY

  log "Running live Codex Ralph natural SessionStart-dispatch smoke test"
  out_file="$RUN_DIR/ralph-natural-session-start.jsonl"
  err_file="$RUN_DIR/ralph-natural-session-start.err"
  prompt='Use the oh-no-harness:ralph skill. Read-only natural SessionStart smoke test. Named THOROUGH request: assess whether this plugin checkout is ready for a release-facing test-harness change. Perform only the normal initial repository assessment and implementation-readiness analysis; do not edit files, execute changes, or continue into verification. End with OH_NO_CODEX_RALPH_NATURAL_OK and summarize the evidence gathered and the proposed implementation direction.'
  assert_natural_prompt_has_no_explicit_subagent_terms "ralph" "$prompt"
  run_codex_live_command "$CODEX_HOME_DIR" "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"
  if ! assert_no_codex_live_secret_leak \
    "$CODEX_HOME_DIR/auth.json" \
    "$out_file" \
    "$err_file" \
    "$CODEX_HOME_DIR/sessions"; then
    rm -f "$out_file" "$err_file"
    fail "Codex Parallel natural live artifacts failed the credential-leak guard and were removed"
  fi
  assert_natural_role_spawn_smoke \
    "$out_file" \
    "$err_file" \
    "OH_NO_CODEX_RALPH_NATURAL_OK" \
    "ralph" \
    "explore:,analyst:,planner:" \
    "" \
    unordered-allowed-fanout \
    2
}

run_simplify_live_test() {
  if [[ "$RUN_SIMPLIFY_LIVE" != "1" ]]; then
    log "Skipping live Codex simplify cleanup-subagent smoke test"
    printf 'Run with --simplify-live or OH_NO_SIMPLIFY_LIVE=1 to verify actual Codex simplify cleanup subagents.\n' >&2
    return
  fi

  log "Running live Codex simplify cleanup-subagent smoke test"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/simplify-cleanup-subagents.jsonl"
  local err_file="$RUN_DIR/simplify-cleanup-subagents.err"
  local prompt
  prompt='Use the oh-no-harness:simplify skill. Read-only dispatch instrumentation test only: do not edit files, do not create artifacts, do not apply cleanup fixes, and do not run Phase 2. Verify Phase 1 dispatch only. Use Codex spawn_agent exactly four times in two host-bounded waves. Wave 1: launch Reuse, Simplification, and Efficiency before any wait, wait_agent, or close_agent call; wait and capture all three. Wave 2: launch Altitude, then wait and capture it. The four cleanup subagent angles must be exactly Reuse, Simplification, Efficiency, and Altitude. For every Codex spawn_agent call, omit agent_type/model/reasoning overrides and do not fork full history. Each spawned-agent message MUST include exactly one line of the form Angle: <angle>, one matching marker line, plus these literal lines: Scope: current diff; Do not edit files; Do not create artifacts; Do not apply cleanup fixes; Do not run Phase 2; Expected output: matching marker plus Angle, File, Line, Summary, Concrete cost fields. Marker lines by angle: Reuse uses Marker: OH_NO_SIMPLIFY_REUSE_READONLY; Simplification uses Marker: OH_NO_SIMPLIFY_SIMPLIFICATION_READONLY; Efficiency uses Marker: OH_NO_SIMPLIFY_EFFICIENCY_READONLY; Altitude uses Marker: OH_NO_SIMPLIFY_ALTITUDE_READONLY. Each cleanup subagent must return its matching marker and labeled Angle, File, Line, Summary, and Concrete cost fields. For every receiver thread, call wait_agent until that receiver appears in a completed final-status result with its output captured; do not use close_agent as the first result capture for any receiver. After each result is captured, call close_agent only if the host exposes it; otherwise include exactly: Close/cleanup was not available. After all four cleanup subagents finish, include each matching marker in the final response as captured-result evidence. After lifecycle cleanup is closed or recorded unavailable, reply exactly OH_NO_CODEX_SIMPLIFY_SUBAGENTS_OK and summarize Review angles: Reuse, Simplification, Efficiency, Altitude; Host-bounded waves: 3+1; Wait results captured: 4; Lifecycle cleanup: closed | unavailable.'
  prompt="Named THOROUGH broad-diff cleanup trigger. ${prompt}"

  local cmd=(
    "$CODEX_BIN"
    --enable plugin_hooks
    --ask-for-approval never
    exec
    --json
    --cd "$PLUGIN_ROOT"
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
    rm -f "$out_file" "$err_file"
    fail "Codex Simplify explicit live artifacts failed the credential-leak guard and were removed"
  fi

  "$PYTHON_BIN" - "$out_file" "$err_file" "$CODEX_HOME_DIR" <<'PY'
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

path = sys.argv[1]
err_path = sys.argv[2]
live_home = sys.argv[3]
expected_angles = ["Reuse", "Simplification", "Efficiency", "Altitude"]
required_payload_markers = [
    "Scope: current diff",
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

def mentioned_receivers(item):
    text = collect_text(item)
    return {
        receiver
        for receiver in receiver_to_angle
        if receiver in text
    }

with open(err_path, "r", encoding="utf-8") as fh:
    err_text = fh.read()
if (
    "spawn failed" in err_text.lower()
    or "agent thread limit reached" in err_text.lower()
    or "full-history forked agents inherit" in err_text.lower()
    or "provide either message or items" in err_text.lower()
):
    raise SystemExit(f"Codex simplify cleanup smoke saw spawn failure in stderr: {err_text[:2000]!r}")

successful_spawns = []
failed_spawns = []
spawns_by_angle = defaultdict(list)
wait_or_close_indexes = []
receiver_to_angle = {}
wait_index_by_receiver = {}
wait_result_by_receiver = {}
close_index_by_receiver = {}
marker = False
all_text_parts = []
parent_thread_id = None

with open(path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        if data.get("type") == "thread.started":
            parent_thread_id = data.get("thread_id") or parent_thread_id
        item = data.get("item") or {}
        event_text = collect_text(data)
        if item.get("type") == "agent_message":
            all_text_parts.append(event_text)
        if "OH_NO_CODEX_SIMPLIFY_SUBAGENTS_OK" in event_text:
            marker = True
        if item.get("type") != "collab_tool_call":
            continue

        tool = item.get("tool")
        status = item.get("status")
        if tool in {"wait", "wait_agent", "close_agent"}:
            wait_or_close_indexes.append(index)
        if status == "completed":
            receivers = mentioned_receivers(item)
            if tool in {"wait", "wait_agent"}:
                for receiver in receivers:
                    state = (item.get("agents_states") or {}).get(receiver) or {}
                    if state.get("status") == "completed" and state.get("message"):
                        wait_index_by_receiver.setdefault(receiver, index)
                        wait_result_by_receiver.setdefault(receiver, str(state.get("message")))
            if tool == "close_agent":
                for receiver in receivers:
                    close_index_by_receiver.setdefault(receiver, index)
        if tool == "spawn_agent" and status == "failed":
            failed_spawns.append((index, collect_text(item)[:2000]))
        if tool == "spawn_agent" and status == "completed":
            receivers = item.get("receiver_thread_ids") or []
            spawn_text = collect_text(item)
            if len(receivers) != 1:
                raise SystemExit(
                    f"completed Codex simplify spawn_agent call must have exactly one receiver thread id; "
                    f"line={index} receivers={receivers!r} text={spawn_text[:2000]!r}"
                )
            matched_angles = angles_in_payload(spawn_text)
            if len(matched_angles) != 1:
                raise SystemExit(
                    "expected each completed simplify spawn_agent payload to contain exactly one Angle line; "
                    f"line={index} angles={matched_angles!r} text={spawn_text[:2000]!r}"
                )
            angle = matched_angles[0]
            successful_spawns.append((index, angle, tuple(receivers), spawn_text))
            spawns_by_angle[angle].append((index, spawn_text))
            for receiver in receivers:
                receiver_to_angle[receiver] = angle

if failed_spawns:
    raise SystemExit(f"Codex simplify cleanup smoke saw failed spawn_agent calls: {failed_spawns!r}")
if not successful_spawns:
    if not parent_thread_id:
        raise SystemExit("Codex simplify cleanup smoke lacked both collab events and a parent thread id")
    transcript_children = {}
    linked_children = 0
    for transcript_path in (Path(live_home) / "sessions").rglob("*.jsonl"):
        rows = [
            json.loads(line)
            for line in transcript_path.read_text(encoding="utf-8", errors="replace").splitlines()
            if line.strip()
        ]
        meta = next(
            (row.get("payload") or {} for row in rows if row.get("type") == "session_meta"),
            None,
        )
        if not isinstance(meta, dict):
            continue
        source = meta.get("source") if isinstance(meta.get("source"), dict) else {}
        subagent = source.get("subagent") if isinstance(source.get("subagent"), dict) else {}
        thread_spawn = subagent.get("thread_spawn") if isinstance(subagent.get("thread_spawn"), dict) else {}
        parent = meta.get("parent_thread_id") or thread_spawn.get("parent_thread_id")
        if parent != parent_thread_id:
            continue
        linked_children += 1
        user_messages = []
        encrypted_task_messages = 0
        assistant_messages = []
        task_complete_messages = []
        completed = False
        completion_timestamp = ""
        for row in rows:
            payload = row.get("payload") or {}
            if row.get("type") == "event_msg" and payload.get("type") == "task_complete":
                completed = True
                completion_timestamp = row.get("timestamp", "") or completion_timestamp
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
            if payload.get("role") == "assistant":
                assistant_messages.append(collect_text(payload.get("content")))
            elif payload.get("role") == "user":
                user_messages.append(collect_text(payload.get("content")))
        assistant_output = (
            task_complete_messages[-1]
            if task_complete_messages
            else "\n".join(dict.fromkeys(assistant_messages))
        )
        if not completed or not assistant_output:
            raise SystemExit("Codex simplify parent-linked child lacked completed final output")
        output_angles = angles_in_payload(assistant_output)
        marker_angles = [
            angle for angle in expected_angles
            if angle_markers[angle] in assistant_output
        ]
        if len(output_angles) != 1 or marker_angles != output_angles:
            raise SystemExit(
                "Codex simplify parent-linked child output did not identify exactly one "
                f"matching angle and marker: angles={output_angles!r} markers={marker_angles!r}"
            )
        angle = output_angles[0]
        if angle in transcript_children:
            raise SystemExit(f"Codex simplify transcript proof found duplicate children for {angle}")
        user_input = "\n".join(user_messages)
        input_angles = angles_in_payload(user_input)
        if input_angles and input_angles != [angle]:
            raise SystemExit(
                f"Codex simplify plaintext child task did not match its {angle} output: "
                f"{input_angles!r}"
            )
        if not input_angles and encrypted_task_messages < 1:
            raise SystemExit(
                f"Codex simplify child {angle} lacked plaintext or encrypted task-channel evidence"
            )
        task_input = user_input if input_angles == [angle] else ""
        transcript_children[angle] = {
            "started": meta.get("timestamp", ""),
            "completed": completion_timestamp,
            "input": task_input,
            "encrypted_task_messages": encrypted_task_messages,
            "output": assistant_output,
        }
    if linked_children != len(expected_angles):
        raise SystemExit(
            "Codex simplify transcript proof expected exactly four parent-linked child sessions, "
            f"found {linked_children}"
        )
    missing_children = sorted(set(expected_angles) - set(transcript_children))
    if missing_children:
        raise SystemExit(f"Codex simplify transcript proof omitted angles: {missing_children!r}")
    first_wave_completions = [transcript_children[angle]["completed"] for angle in expected_angles[:3]]
    altitude_start = transcript_children["Altitude"]["started"]
    if not all(first_wave_completions) or not altitude_start or max(first_wave_completions) >= altitude_start:
        raise SystemExit(
            "Codex simplify transcript proof violated the host-bounded 3+1 completion barrier"
        )
    parent_text = "\n".join(all_text_parts)
    for angle in expected_angles:
        child = transcript_children[angle]
        required_input = (f"Marker: {angle_markers[angle]}", *required_payload_markers)
        if child["input"]:
            missing_input = [
                value for value in required_input
                if value.lower() not in child["input"].lower()
            ]
            if missing_input:
                raise SystemExit(
                    f"Codex simplify plaintext child {angle} task omitted protocol fields: "
                    f"{missing_input!r}"
                )
        elif child["encrypted_task_messages"] < 1:
            raise SystemExit(
                f"Codex simplify child {angle} lacked encrypted task-channel evidence"
            )
        required_output = (
            angle_markers[angle],
            f"Angle: {angle}",
            "File:",
            "Line:",
            "Summary:",
            "Concrete cost:",
        )
        missing_output = [value for value in required_output if value.lower() not in child["output"].lower()]
        if missing_output:
            raise SystemExit(f"Codex simplify typed child {angle} lacked result fields: {missing_output!r}")
        if angle_markers[angle] not in parent_text:
            raise SystemExit(f"Codex simplify parent omitted the captured {angle} result marker")
    if not marker:
        raise SystemExit("Codex simplify typed children completed but parent omitted the success marker")
    print("ok - live Codex simplify proved by typed child transcripts in host-bounded 3+1 waves")
    raise SystemExit(0)
if len(successful_spawns) != len(expected_angles):
    raise SystemExit(
        f"expected exactly {len(expected_angles)} completed simplify spawn_agent calls, "
        f"got {len(successful_spawns)}: {successful_spawns!r}"
    )
missing_angles = [angle for angle in expected_angles if angle not in spawns_by_angle]
duplicate_angles = {
    angle: payloads for angle, payloads in spawns_by_angle.items()
    if len(payloads) != 1
}
if missing_angles or duplicate_angles:
    raise SystemExit(
        "Codex simplify cleanup angles did not match the required set: "
        f"missing={missing_angles!r} duplicates={duplicate_angles!r}"
    )
receiver_ids = {receivers[0] for _, _, receivers, _ in successful_spawns}
if len(receiver_ids) != len(expected_angles):
    raise SystemExit(f"expected {len(expected_angles)} distinct simplify receiver threads, got {receiver_ids!r}")
missing_wait_results = sorted(receiver_ids - set(wait_index_by_receiver))
missing_closes = sorted(receiver_ids - set(close_index_by_receiver))
all_text = "\n".join(all_text_parts)
if missing_wait_results:
    raise SystemExit(f"Codex simplify cleanup smoke did not capture final wait_agent results for receivers: {missing_wait_results!r}")
if missing_closes and "close/cleanup was not available" not in all_text.lower():
    raise SystemExit(
        "Codex simplify cleanup smoke left receivers without close evidence or an unavailable-cleanup record: "
        f"{missing_closes!r}"
    )
early_closes = {
    receiver: (wait_index_by_receiver[receiver], close_index_by_receiver[receiver])
    for receiver in receiver_ids
    if receiver in close_index_by_receiver
    and close_index_by_receiver[receiver] <= wait_index_by_receiver[receiver]
}
if early_closes:
    raise SystemExit(
        "Codex simplify cleanup smoke closed agents before their wait_agent results were captured: "
        f"{early_closes!r}"
    )
if not wait_or_close_indexes:
    raise SystemExit("Codex simplify cleanup smoke did not wait for or close spawned cleanup subagents")
first_wave_angles = expected_angles[:3]
spawn_index_by_angle = {
    angle: index for index, angle, _, _ in successful_spawns
}
receiver_by_angle = {
    angle: receivers[0] for _, angle, receivers, _ in successful_spawns
}
first_wait_or_close = min(wait_or_close_indexes)
last_first_wave_spawn = max(spawn_index_by_angle[angle] for angle in first_wave_angles)
if first_wait_or_close < last_first_wave_spawn:
    raise SystemExit(
        "Codex simplify cleanup first wave did not launch all three viewpoints before waiting; "
        f"first_wait_or_close={first_wait_or_close} last_first_wave_spawn={last_first_wave_spawn}"
    )
altitude_spawn = spawn_index_by_angle["Altitude"]
late_first_wave_results = {
    angle: wait_index_by_receiver[receiver_by_angle[angle]]
    for angle in first_wave_angles
    if wait_index_by_receiver[receiver_by_angle[angle]] >= altitude_spawn
}
if late_first_wave_results:
    raise SystemExit(
        "Codex simplify cleanup launched Altitude before capturing every first-wave result; "
        f"altitude_spawn={altitude_spawn} first_wave_waits={late_first_wave_results!r}"
    )
late_first_wave_closes = {
    angle: close_index_by_receiver[receiver_by_angle[angle]]
    for angle in first_wave_angles
    if receiver_by_angle[angle] in close_index_by_receiver
    and close_index_by_receiver[receiver_by_angle[angle]] >= altitude_spawn
}
if late_first_wave_closes:
    raise SystemExit(
        "Codex simplify cleanup launched Altitude before closing completed first-wave receivers: "
        f"altitude_spawn={altitude_spawn} first_wave_closes={late_first_wave_closes!r}"
    )
for angle, payloads in spawns_by_angle.items():
    _, payload = payloads[0]
    missing_markers = [
        marker for marker in [
            f"Angle: {angle}",
            f"Marker: {angle_markers[angle]}",
            *required_payload_markers,
        ]
        if marker.lower() not in payload.lower()
    ]
    if missing_markers:
        raise SystemExit(
            f"Codex simplify spawn_agent payload for {angle} missed required prompt markers: "
            f"{missing_markers}; payload={payload[:2000]!r}"
        )
for angle in expected_angles:
    receiver = receiver_by_angle[angle]
    result = wait_result_by_receiver[receiver]
    required_result_patterns = (
        rf"(?im)^\s*{re.escape(angle_markers[angle])}\s*$",
        rf"(?im)^\s*Angle:\s*{re.escape(angle)}\s*$",
        r"(?im)^\s*File:\s*\S.+$",
        r"(?im)^\s*Line:\s*\S.+$",
        r"(?im)^\s*Summary:\s*\S.+$",
        r"(?im)^\s*Concrete cost:\s*\S.+$",
    )
    missing_result_fields = [
        pattern for pattern in required_result_patterns
        if re.search(pattern, result) is None
    ]
    if missing_result_fields:
        raise SystemExit(
            f"Codex simplify cleanup result for {angle} lacked structured evidence: "
            f"{missing_result_fields!r}; result={result[:2000]!r}"
        )
    if angle_markers[angle] not in all_text:
        raise SystemExit(
            f"Codex simplify cleanup parent did not preserve the captured {angle} result marker"
        )
if not marker:
    raise SystemExit("Codex simplify cleanup smoke did not return success marker")

print("ok - live Codex simplify cleanup subagents spawned in host-bounded 3+1 waves")
PY

  log "Running live Codex simplify natural SessionStart-dispatch smoke test"
  out_file="$RUN_DIR/simplify-natural-session-start.jsonl"
  err_file="$RUN_DIR/simplify-natural-session-start.err"
  prompt='Named THOROUGH broad-diff maintainability trigger. Use the oh-no-harness:simplify skill for a read-only natural SessionStart smoke test. Review only docs/reference/source-index.md through the normal Phase 1 path. Do not inspect other changed files, edit files, create artifacts, apply fixes, or continue to Phase 2. End with OH_NO_CODEX_SIMPLIFY_NATURAL_OK and summarize the Reuse, Simplification, Efficiency, and Altitude findings.'

  assert_natural_prompt_has_no_explicit_subagent_terms "simplify" "$prompt"

  local natural_cmd=(
    "$CODEX_BIN"
    --enable plugin_hooks
    --ask-for-approval never
    exec
    --json
    --cd "$PLUGIN_ROOT"
    --sandbox read-only
    --skip-git-repo-check
  )

  if [[ -n "$LIVE_MODEL" ]]; then
    natural_cmd+=(--model "$LIVE_MODEL")
  fi

  run_codex_live_command "$CODEX_HOME_DIR" "${natural_cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"
  if ! assert_no_codex_live_secret_leak \
    "$CODEX_HOME_DIR/auth.json" \
    "$out_file" \
    "$err_file" \
    "$CODEX_HOME_DIR/sessions"; then
    rm -f "$out_file" "$err_file"
    fail "Codex Simplify natural live artifacts failed the credential-leak guard and were removed"
  fi

  "$PYTHON_BIN" - "$out_file" "$err_file" "$CODEX_HOME_DIR" <<'PY'
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

path = sys.argv[1]
err_path = sys.argv[2]
live_home = sys.argv[3]
expected_angles = ["Reuse", "Simplification", "Efficiency", "Altitude"]
expected_agent_nodes = {
    "Reuse": "simplify_reuse",
    "Simplification": "simplify_simplification",
    "Efficiency": "simplify_efficiency",
    "Altitude": "simplify_altitude",
}
allowed_discovery_roles = {
    "oh-no-analyst",
    "oh-no-code-reviewer",
    "oh-no-explore",
}
required_payload_markers = [
    "Do not edit files",
    "Do not apply cleanup fixes",
    "Do not run Phase 2",
]
def collect_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(item) for item in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(item) for item in value)
    return ""

def angles_in_payload(text):
    exact = [
        angle for angle in expected_angles
        if re.search(rf"(?im)^\s*Angle:\s*{re.escape(angle)}\s*$", text)
    ]
    if exact:
        return exact
    structural = [
        angle for angle in expected_angles
        if re.search(
            rf"(?im)^\s*(?:#{{1,6}}\s*)?(?:(?:viewpoint|perspective|lens)\s*:\s*)?"
            rf"{re.escape(angle)}(?:\s+(?:review|findings?|analysis|pass))?\s*:?[ \t]*$",
            text,
        )
    ]
    if structural:
        return structural
    prefix = text[:1200]
    return [
        angle for angle in expected_angles
        if re.search(rf"(?i)\b{re.escape(angle)}\b", prefix)
    ]

def missing_result_evidence(text):
    lower_text = text.lower()
    no_candidate = bool(
        re.search(r"(?i)\bno (?:cleanup )?(?:candidates?|findings?)\b", text)
    )
    structured_finding = bool(
        re.search(r"(?im)^\s*(?:key\s+)?findings?\s*:", text)
        and re.search(r"(?im)^\s*[-*]\s+.*source-index\.md", text)
    )
    inline_finding = bool(
        re.search(
            r"(?im)^\s*[-*]\s+.*source-index\.md(?::[0-9]+|#L[0-9]+).*?\s+[—-]\s+\S+",
            text,
        )
    )
    checks = {
        "file": "docs/reference/source-index.md" in lower_text,
        "line": bool(
            no_candidate
            or re.search(r"(?i)\blines?\s*:?[ \t]*(?:[0-9]+|n/?a|none)\b", text)
            or re.search(r"(?i)source-index\.md(?::[0-9]+|#L[0-9]+)", text)
        ),
        "summary": bool(
            re.search(r"(?im)^\s*(?:[-*]\s*)?(?:summary|finding)\s*:", text)
            or no_candidate
            or structured_finding
            or inline_finding
        ),
        "concrete cost": bool(
            no_candidate
            or re.search(r"(?i)\b(?:concrete\s+cost|cost\s+if\s+ignored|cost)\b", text)
        ),
    }
    return [field for field, present in checks.items() if not present]


def mentioned_receivers(item):
    text = collect_text(item)
    return {receiver for receiver in receiver_to_angle if receiver in text}

with open(err_path, "r", encoding="utf-8") as fh:
    err_text = fh.read()
if (
    "spawn failed" in err_text.lower()
    or "agent thread limit reached" in err_text.lower()
    or "full-history forked agents inherit" in err_text.lower()
    or "provide either message or items" in err_text.lower()
):
    raise SystemExit(f"Codex simplify natural smoke saw spawn failure in stderr: {err_text[:2000]!r}")

successful_spawns = []
failed_spawns = []
spawns_by_angle = defaultdict(list)
wait_or_close_indexes = []
receiver_to_angle = {}
wait_index_by_receiver = {}
wait_result_by_receiver = {}
close_index_by_receiver = {}
marker = False
all_text_parts = []
parent_thread_id = None

with open(path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        if data.get("type") == "thread.started":
            parent_thread_id = data.get("thread_id") or parent_thread_id
        item = data.get("item") or {}
        event_text = collect_text(data)
        if item.get("type") == "agent_message":
            all_text_parts.append(event_text)
        if "OH_NO_CODEX_SIMPLIFY_NATURAL_OK" in event_text:
            marker = True
        if item.get("type") != "collab_tool_call":
            continue

        tool = item.get("tool")
        status = item.get("status")
        if tool in {"wait", "wait_agent", "close_agent"}:
            wait_or_close_indexes.append(index)
        if status == "completed":
            receivers = mentioned_receivers(item)
            if tool in {"wait", "wait_agent"}:
                for receiver in receivers:
                    state = (item.get("agents_states") or {}).get(receiver) or {}
                    if state.get("status") == "completed" and state.get("message"):
                        wait_index_by_receiver.setdefault(receiver, index)
                        wait_result_by_receiver.setdefault(receiver, str(state.get("message")))
            if tool == "close_agent":
                for receiver in receivers:
                    close_index_by_receiver.setdefault(receiver, index)
        if tool == "spawn_agent" and status == "failed":
            failed_spawns.append((index, collect_text(item)[:2000]))
        if tool == "spawn_agent" and status == "completed":
            receivers = item.get("receiver_thread_ids") or []
            spawn_text = collect_text(item)
            if len(receivers) != 1:
                raise SystemExit(
                    f"completed Codex simplify natural spawn_agent call must have exactly one receiver thread id; "
                    f"line={index} receivers={receivers!r} text={spawn_text[:2000]!r}"
                )
            matched_angles = angles_in_payload(spawn_text)
            if len(matched_angles) != 1:
                raise SystemExit(
                    "expected each completed natural simplify spawn_agent payload to contain exactly one Angle line; "
                    f"line={index} angles={matched_angles!r} text={spawn_text[:2000]!r}"
                )
            angle = matched_angles[0]
            successful_spawns.append((index, angle, tuple(receivers), spawn_text))
            spawns_by_angle[angle].append((index, spawn_text))
            for receiver in receivers:
                receiver_to_angle[receiver] = angle

if failed_spawns:
    raise SystemExit(f"Codex simplify natural smoke saw failed spawn_agent calls: {failed_spawns!r}")
if not successful_spawns:
    if not parent_thread_id:
        raise SystemExit("Codex simplify natural smoke lacked both collab events and a parent thread id")
    transcript_children = {}
    linked_children = 0
    for transcript_path in (Path(live_home) / "sessions").rglob("*.jsonl"):
        rows = [
            json.loads(line)
            for line in transcript_path.read_text(encoding="utf-8", errors="replace").splitlines()
            if line.strip()
        ]
        meta = next(
            (row.get("payload") or {} for row in rows if row.get("type") == "session_meta"),
            None,
        )
        if not isinstance(meta, dict):
            continue
        source = meta.get("source") if isinstance(meta.get("source"), dict) else {}
        subagent = source.get("subagent") if isinstance(source.get("subagent"), dict) else {}
        thread_spawn = subagent.get("thread_spawn") if isinstance(subagent.get("thread_spawn"), dict) else {}
        parent = meta.get("parent_thread_id") or thread_spawn.get("parent_thread_id")
        if parent != parent_thread_id:
            continue
        linked_children += 1
        user_messages = []
        encrypted_task_messages = 0
        assistant_messages = []
        task_complete_messages = []
        completed = False
        completion_timestamp = ""
        for row in rows:
            payload = row.get("payload") or {}
            if row.get("type") == "event_msg" and payload.get("type") == "task_complete":
                completed = True
                completion_timestamp = row.get("timestamp", "") or completion_timestamp
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
            if payload.get("role") == "assistant":
                assistant_messages.append(collect_text(payload.get("content")))
            elif payload.get("role") == "user":
                user_messages.append(collect_text(payload.get("content")))
        assistant_output = (
            task_complete_messages[-1]
            if task_complete_messages
            else "\n".join(dict.fromkeys(assistant_messages))
        )
        if not completed or not assistant_output:
            raise SystemExit(
                "Codex simplify natural parent-linked child lacked completed final output"
            )
        agent_role = meta.get("agent_role") or thread_spawn.get("agent_role")
        if agent_role not in allowed_discovery_roles:
            raise SystemExit(
                "Codex simplify natural parent-linked child used a non-discovery "
                f"typed role: {agent_role!r}"
            )
        agent_path = str(meta.get("agent_path") or thread_spawn.get("agent_path") or "")
        agent_node = agent_path.rstrip("/").rsplit("/", 1)[-1]
        metadata_angles = [
            angle for angle, expected_node in expected_agent_nodes.items()
            if agent_node == expected_node
        ]
        if len(metadata_angles) != 1:
            raise SystemExit(
                "Codex simplify natural parent-linked child metadata did not identify "
                f"exactly one viewpoint: agent_path={agent_path!r} matches={metadata_angles!r}"
            )
        angle = metadata_angles[0]
        output_angles = angles_in_payload(assistant_output)
        if len(output_angles) > 1 or (output_angles and output_angles != [angle]):
            raise SystemExit(
                f"Codex simplify natural {angle} child output contradicted its typed "
                f"agent-path identity: {output_angles!r}"
            )
        if angle in transcript_children:
            raise SystemExit(f"Codex simplify natural transcript proof found duplicate children for {angle}")
        user_input = "\n".join(user_messages)
        input_angles = angles_in_payload(user_input)
        if encrypted_task_messages >= 1:
            task_input = ""
        elif input_angles == [angle]:
            task_input = user_input
        else:
            raise SystemExit(
                f"Codex simplify natural plaintext child task did not match its {angle} "
                f"output and lacked encrypted task-channel evidence: {input_angles!r}"
            )
        transcript_children[angle] = {
            "started": meta.get("timestamp", ""),
            "completed": completion_timestamp,
            "input": task_input,
            "encrypted_task_messages": encrypted_task_messages,
            "output": assistant_output,
        }
    if linked_children != len(expected_angles):
        raise SystemExit(
            "Codex simplify natural transcript proof expected exactly four parent-linked "
            f"child sessions, found {linked_children}"
        )
    missing_children = sorted(set(expected_angles) - set(transcript_children))
    if missing_children:
        raise SystemExit(f"Codex simplify natural transcript proof omitted angles: {missing_children!r}")
    first_wave_completions = [transcript_children[angle]["completed"] for angle in expected_angles[:3]]
    altitude_start = transcript_children["Altitude"]["started"]
    if not all(first_wave_completions) or not altitude_start or max(first_wave_completions) >= altitude_start:
        raise SystemExit(
            "Codex simplify natural transcript proof violated the host-bounded 3+1 completion barrier"
        )
    parent_text = "\n".join(all_text_parts)
    for angle in expected_angles:
        child = transcript_children[angle]
        if child["input"]:
            missing_input = [
                value for value in (f"Angle: {angle}", *required_payload_markers)
                if value.lower() not in child["input"].lower()
            ]
            if missing_input:
                raise SystemExit(
                    f"Codex simplify natural plaintext child {angle} task omitted "
                    f"skill-owned fields: {missing_input!r}"
                )
        elif child["encrypted_task_messages"] < 1:
            raise SystemExit(
                f"Codex simplify natural child {angle} lacked encrypted task-channel evidence"
            )
        missing_output = missing_result_evidence(child["output"])
        if missing_output:
            raise SystemExit(
                f"Codex simplify natural typed child {angle} lacked semantic result "
                f"evidence: {missing_output!r}"
            )
        if angle.lower() not in parent_text.lower():
            raise SystemExit(f"Codex simplify natural parent omitted the {angle} disposition")
    if not marker:
        raise SystemExit("Codex simplify natural typed children completed but parent omitted the success marker")
    print("ok - live Codex simplify natural path proved by typed child transcripts")
    raise SystemExit(0)
if len(successful_spawns) != len(expected_angles):
    raise SystemExit(
        f"expected exactly {len(expected_angles)} completed natural simplify spawn_agent calls from SessionStart authorization, "
        f"got {len(successful_spawns)}: {successful_spawns!r}"
    )
missing_angles = [angle for angle in expected_angles if angle not in spawns_by_angle]
duplicate_angles = {
    angle: payloads for angle, payloads in spawns_by_angle.items()
    if len(payloads) != 1
}
if missing_angles or duplicate_angles:
    raise SystemExit(
        "Codex simplify natural cleanup angles did not match the required set: "
        f"missing={missing_angles!r} duplicates={duplicate_angles!r}"
    )
receiver_ids = {receivers[0] for _, _, receivers, _ in successful_spawns}
missing_wait_results = sorted(receiver_ids - set(wait_index_by_receiver))
missing_closes = sorted(receiver_ids - set(close_index_by_receiver))
all_text = "\n".join(all_text_parts)
if missing_wait_results:
    raise SystemExit(f"Codex simplify natural smoke did not capture final wait_agent results for receivers: {missing_wait_results!r}")
if missing_closes and "close/cleanup was not available" not in all_text.lower():
    raise SystemExit(
        "Codex simplify natural smoke left receivers without close evidence or an unavailable-cleanup record: "
        f"{missing_closes!r}"
    )
early_closes = {
    receiver: (wait_index_by_receiver[receiver], close_index_by_receiver[receiver])
    for receiver in receiver_ids
    if receiver in close_index_by_receiver
    and close_index_by_receiver[receiver] <= wait_index_by_receiver[receiver]
}
if early_closes:
    raise SystemExit(
        "Codex simplify natural smoke closed agents before their wait_agent results were captured: "
        f"{early_closes!r}"
    )
if not wait_or_close_indexes:
    raise SystemExit("Codex simplify natural smoke did not wait for or close spawned cleanup workers")
first_wave_angles = expected_angles[:3]
spawn_index_by_angle = {
    angle: index for index, angle, _, _ in successful_spawns
}
receiver_by_angle = {
    angle: receivers[0] for _, angle, receivers, _ in successful_spawns
}
first_wait_or_close = min(wait_or_close_indexes)
last_first_wave_spawn = max(spawn_index_by_angle[angle] for angle in first_wave_angles)
if first_wait_or_close < last_first_wave_spawn:
    raise SystemExit(
        "Codex simplify natural first wave did not launch all three viewpoints before waiting; "
        f"first_wait_or_close={first_wait_or_close} last_first_wave_spawn={last_first_wave_spawn}"
    )
altitude_spawn = spawn_index_by_angle["Altitude"]
late_first_wave_results = {
    angle: wait_index_by_receiver[receiver_by_angle[angle]]
    for angle in first_wave_angles
    if wait_index_by_receiver[receiver_by_angle[angle]] >= altitude_spawn
}
if late_first_wave_results:
    raise SystemExit(
        "Codex simplify natural smoke launched Altitude before capturing every first-wave result; "
        f"altitude_spawn={altitude_spawn} first_wave_waits={late_first_wave_results!r}"
    )
late_first_wave_closes = {
    angle: close_index_by_receiver[receiver_by_angle[angle]]
    for angle in first_wave_angles
    if receiver_by_angle[angle] in close_index_by_receiver
    and close_index_by_receiver[receiver_by_angle[angle]] >= altitude_spawn
}
if late_first_wave_closes:
    raise SystemExit(
        "Codex simplify natural smoke launched Altitude before closing completed first-wave receivers: "
        f"altitude_spawn={altitude_spawn} first_wave_closes={late_first_wave_closes!r}"
    )
for angle, payloads in spawns_by_angle.items():
    _, payload = payloads[0]
    missing_markers = [
        marker for marker in required_payload_markers
        if marker.lower() not in payload.lower()
    ]
    if missing_markers:
        raise SystemExit(
            f"Codex simplify natural spawn_agent payload for {angle} missed skill-owned prompt markers: "
            f"{missing_markers}; payload={payload[:2000]!r}"
        )
for angle in expected_angles:
    receiver = receiver_by_angle[angle]
    result = wait_result_by_receiver[receiver]
    result_angles = angles_in_payload(result)
    if result_angles != [angle]:
        raise SystemExit(
            f"Codex simplify natural result did not identify exactly {angle}: "
            f"{result_angles!r}"
        )
    missing_result_fields = missing_result_evidence(result)
    if missing_result_fields:
        raise SystemExit(
            f"Codex simplify natural result for {angle} lacked semantic evidence: "
            f"{missing_result_fields!r}; result={result[:2000]!r}"
        )
    if angle.lower() not in all_text.lower():
        raise SystemExit(f"Codex simplify natural parent omitted the {angle} disposition")
if not marker:
    raise SystemExit("Codex simplify natural smoke did not return success marker")

print("ok - live Codex simplify spawned cleanup subagents from SessionStart standing authorization")
PY
}

run_worktree_live_test() {
  if [[ "$RUN_WORKTREE_LIVE" != "1" ]]; then
    log "Skipping live Codex Ralph worktree-creation smoke test"
    printf 'Run with --worktree-live or OH_NO_WORKTREE_LIVE=1 to verify Ralph creates a project-local task worktree.\n' >&2
    return 0
  fi

  log "Running live Codex Ralph worktree-creation smoke test"
  mkdir -p "$RUN_DIR"

  local repo="$RUN_DIR/worktree-live-repo"
  local out_file="$RUN_DIR/worktree-live.txt"
  local log_file="$RUN_DIR/worktree-live.log"
  rm -rf "$repo"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email "oh-no-harness@example.invalid"
  git -C "$repo" config user.name "Oh No Harness Test"
  printf '.oh-no/\n' >"$repo/.gitignore"
  printf '# Worktree Live Fixture\n' >"$repo/README.md"
  git -C "$repo" add .gitignore README.md
  git -C "$repo" commit -q -m "initial fixture"

  local prompt
  prompt='Use the oh-no-harness:ralph skill. Live worktree creation smoke test. This repository is disposable. Concrete task: create src/worktree-live.txt containing exactly OH_NO_CODEX_WORKTREE_CONTENT and a trailing newline. Acceptance criteria: the file exists in a registered Git worktree created by git worktree add, the content matches exactly, and the original integration checkout is not edited. Follow Ralph worktree isolation before any source edit: run git worktree add .oh-no/worktrees/<task-slug> -b <branch-name> or select an already registered project-local Git worktree under .oh-no/worktrees/<task-slug>, record Worktree decision: direct automatic worktree, and do not create a parent-directory sibling worktree. git clone, cp -R, mkdir-only directories, and manual checkouts are invalid for this test. Do not merge back; leave the task worktree in place for external inspection. Run verification from the task worktree, including git worktree list --porcelain from the integration checkout. End the final response with OH_NO_CODEX_WORKTREE_LIVE_OK and include the exact Worktree location.'

  local cmd=(
    "$CODEX_BIN"
    --ask-for-approval never
    exec
    --cd "$repo"
    --sandbox danger-full-access
    --output-last-message "$out_file"
  )

  if [[ -n "$LIVE_MODEL" ]]; then
    cmd+=(--model "$LIVE_MODEL")
  fi

  run_codex_live_command "$CODEX_HOME_DIR" "${cmd[@]}" "$prompt" >"$log_file" 2>&1

  "$PYTHON_BIN" - "$repo" "$out_file" <<'PY'
import subprocess
import sys
from pathlib import Path

repo = Path(sys.argv[1]).resolve()
out_file = Path(sys.argv[2])
text = out_file.read_text(encoding="utf-8") if out_file.exists() else ""

if "OH_NO_CODEX_WORKTREE_LIVE_OK" not in text:
    raise SystemExit(f"worktree live smoke missing success marker; got {text!r}")

root_file = repo / "src" / "worktree-live.txt"
if root_file.exists():
    raise SystemExit(f"Ralph edited integration checkout instead of only task worktree: {root_file}")

worktree_root = repo / ".oh-no" / "worktrees"
candidates = sorted(worktree_root.rglob("src/worktree-live.txt")) if worktree_root.exists() else []
if not candidates:
    raise SystemExit(f"no task worktree file found under {worktree_root}")

valid_candidates = [
    path for path in candidates
    if path.read_text(encoding="utf-8") == "OH_NO_CODEX_WORKTREE_CONTENT\n"
]
if not valid_candidates:
    details = {str(path): path.read_text(encoding="utf-8", errors="replace") for path in candidates}
    raise SystemExit(f"task worktree file content did not match: {details!r}")

porcelain = subprocess.check_output(
    ["git", "-C", str(repo), "worktree", "list", "--porcelain"],
    text=True,
)
registered = [
    Path(line.split(" ", 1)[1]).resolve()
    for line in porcelain.splitlines()
    if line.startswith("worktree ")
]
project_local = [
    path for path in registered
    if path != repo and str(path).startswith(str(worktree_root.resolve()) + "/")
]
if not project_local:
    raise SystemExit(f"no registered project-local task worktree in git worktree list: {porcelain!r}")

if not any(any(str(candidate.resolve()).startswith(str(worktree) + "/") for worktree in project_local) for candidate in valid_candidates):
    raise SystemExit(
        "matching file was not inside a registered project-local worktree; "
        f"candidates={valid_candidates!r} registered={project_local!r}"
    )

print("ok - live Codex Ralph created project-local task worktree")
PY
}

main() {
  cd "$PLUGIN_ROOT"
  require_command "$CODEX_BIN"
  require_command "$PYTHON_BIN"
  run_live_timeout_offline_test
  run_natural_prompt_guard_offline_test
  validate_codex_live_secret_scanner
  validate_codex_live_clone_safety
  validate_ralplan_live_option_compatibility
  prepare_isolated_codex_live_home

  log "Testing ${PLUGIN_ID} for Codex from ${PLUGIN_ROOT}"
  validate_codex_manifest
  validate_codex_hooks
  validate_codex_agent_installer
  install_via_codex_plugins
  install_codex_agents_user_scope
  assert_codex_prompt_exposes_skills
  run_live_tests
  run_deep_live_tests
  run_ralplan_live_test
  run_named_agents_live_test
  run_fusion_rescue_live_test
  run_codex_cross_host_fallback_live_test
  run_parallel_live_test
  run_simplify_live_test
  run_natural_session_start_live_tests
  run_worktree_live_test
  log "All requested Codex checks passed"
}

# Run main only when executed directly so deterministic offline functions can be
# sourced and exercised without installing the plugin or spending model budget.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
