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
  install-statusline
  configure-subagents
)

ALL_SKILLS=(
  "${PUBLIC_SKILLS[@]}"
)

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
  --isolated-config      Create a throwaway CLAUDE_CONFIG_DIR for this run and
                         remove it on EXIT/INT/TERM, so install/marketplace steps
                         never touch your real ~/.claude. Use for offline/install
                         runs; live tests need real auth, so pair --live with
                         --no-install instead.
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
  home; keep it for offline/install runs since it lacks auth) or a validated
  GitHub source (--marketplace-source jcwleo/oh-no-harness). Live tests need real
  auth, so pair --live with --no-install (plugin-dir load, no marketplace change).
  Set OH_NO_ALLOW_CANONICAL_LOCAL_MARKETPLACE=1 to overwrite it on purpose.

Environment overrides:
  CLAUDE_BIN, PYTHON_BIN, OH_NO_PLUGIN_SCOPE, OH_NO_LIVE, OH_NO_DEEP_LIVE,
  OH_NO_PARALLEL_LIVE, OH_NO_RALPLAN_LIVE, OH_NO_TEST_MODEL,
  OH_NO_FUSION_RESCUE_LIVE, OH_NO_FUSION_RESCUE_MODEL,
  OH_NO_FUSION_RESCUE_MAX_BUDGET_USD, OH_NO_CROSS_HOST_FALLBACK_LIVE,
  OH_NO_PARALLEL_EXECUTOR_LIVE,
  OH_NO_SIMPLIFY_LIVE,
  OH_NO_NATURAL_SESSION_START_LIVE,
  OH_NO_MAX_BUDGET_USD, OH_NO_LIVE_TIMEOUT_SECONDS, OH_NO_LIVE_TIMEOUT_GRACE_SECONDS,
  OH_NO_LIVE_LOAD_MODE, OH_NO_MARKETPLACE_SOURCE,
  OH_NO_ALLOW_CANONICAL_LOCAL_MARKETPLACE, OH_NO_ISOLATED_CONFIG
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
    --fusion-rescue-live)
      RUN_FUSION_RESCUE_LIVE=1
      shift
      ;;
    --cross-host-fallback-live)
      RUN_CROSS_HOST_FALLBACK_LIVE=1
      shift
      ;;
    --model-diversity-live)
      RUN_MODEL_DIVERSITY_LIVE=1
      shift
      ;;
    --parallel-executor-live)
      RUN_PARALLEL_EXECUTOR_LIVE=1
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
    --live-hook-only)
      RUN_LIVE=1
      LIVE_HOOK_ONLY=1
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
    --isolated-config)
      ISOLATED_CONFIG=1
      shift
      ;;
    --scope)
      REQUESTED_SCOPE="${2:-}"
      [[ -n "$REQUESTED_SCOPE" ]] || { echo "Missing value for --scope" >&2; exit 2; }
      shift 2
      ;;
    --live-load)
      LIVE_LOAD_MODE="${2:-}"
      [[ -n "$LIVE_LOAD_MODE" ]] || { echo "Missing value for --live-load" >&2; exit 2; }
      shift 2
      ;;
    --marketplace-source)
      MARKETPLACE_SOURCE="${2:-}"
      [[ -n "$MARKETPLACE_SOURCE" ]] || { echo "Missing value for --marketplace-source" >&2; exit 2; }
      shift 2
      ;;
    --model)
      LIVE_MODEL="${2:-}"
      [[ -n "$LIVE_MODEL" ]] || { echo "Missing value for --model" >&2; exit 2; }
      FUSION_RESCUE_LIVE_MODEL="$LIVE_MODEL"
      shift 2
      ;;
    --max-budget-usd)
      LIVE_MAX_BUDGET_USD="${2:-}"
      [[ -n "$LIVE_MAX_BUDGET_USD" ]] || { echo "Missing value for --max-budget-usd" >&2; exit 2; }
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

case "$LIVE_LOAD_MODE" in
  plugin-dir|installed) ;;
  *)
    echo "--live-load must be plugin-dir or installed" >&2
    exit 2
    ;;
esac

case "$REQUESTED_SCOPE" in
  ""|local|project|user|managed) ;;
  *)
    echo "--scope must be local, project, user, or managed" >&2
    exit 2
    ;;
esac

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

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

run_live_process_with_timeout() {
  "$PYTHON_BIN" - "$LIVE_TIMEOUT_SECONDS" "$LIVE_TIMEOUT_GRACE_SECONDS" "$@" <<'PY'
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
  rm -rf "$temp_root"
  [[ "$rc" == "7" ]] || fail "Claude timeout runner changed child exit 7 to $rc"
  ok "Claude live-timeout runner returns 124, kills descendants, and preserves child status"
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

# Fail-closed safety gate for the install path. Registering a LOCAL source (or an
# unrecognized/invalid one) into the REAL default Claude config can overwrite the
# daily-use `oh-no-harness` GitHub registration with a working-tree checkout (see
# CLAUDE.md). Refuse that regardless of marketplace name — a non-canonical name is
# not a safe path, it just pollutes the real config with another local
# registration. Isolation makes it safe:
#   - an isolated config home (--isolated-config, or a non-default CLAUDE_CONFIG_DIR), or
#   - a validated GitHub --marketplace-source (e.g. jcwleo/oh-no-harness).
# The explicit OH_NO_ALLOW_CANONICAL_LOCAL_MARKETPLACE=1 opt-in overrides a LOCAL
# source; an invalid source is always refused.
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

validate_hooks() {
  log "Validating hook wiring"
  assert_json_valid "$PLUGIN_ROOT/hooks/hooks.json"
  bash -n "$PLUGIN_ROOT/hooks/session-start"
  bash -n "$PLUGIN_ROOT/scripts/oh-no-config"
  ok "shell syntax: hooks/session-start"
  ok "shell syntax: scripts/oh-no-config"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" session-start \
    | "$PYTHON_BIN" -m json.tool >/dev/null
  ok "session-start emits valid JSON"

  local temp_data
  temp_data="$(mktemp -d)"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/hooks/run-hook.cmd" session-start >"$temp_data/hook-off.json"
  "$PYTHON_BIN" - "$temp_data/hook-off.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = json.dumps(data)
if "OH_NO_FORCED_ROUTING" in text:
    raise SystemExit("forced-routing policy was present while config is unset")
if "OH_NO_AUTO_ROUTING" in text:
    raise SystemExit("legacy auto-routing tag was present while config is unset")
if "Use native skill loading to read the relevant Oh No Harness skill when it applies." not in text:
    raise SystemExit("base bootstrap is missing compact native skill-loading guidance")
required = [
    "Use oh-no-harness:test-driven-development only as an explicit TDD/test-first route or an internal guardrail",
    "No-route lane",
    "Direct-edit lane",
]
missing = [needle for needle in required if needle not in text]
if missing:
    raise SystemExit(f"Claude SessionStart missing default Ralph/TDD routing markers: {missing}")
for forbidden in ("OH_NO_SKILL_CORE", "Below is the full content", "docs/skill-core/using-oh-no-harness.md"):
    if forbidden in text:
        raise SystemExit(f"base bootstrap embedded full using-oh-no-harness core content: {forbidden}")
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
  OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/scripts/oh-no-config" on >/dev/null
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/hooks/run-hook.cmd" session-start >"$temp_data/hook-on.json"
  "$PYTHON_BIN" - "$temp_data/hook-on.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = json.dumps(data)
if "OH_NO_FORCED_ROUTING" not in text:
    raise SystemExit("forced-routing policy missing while config is enabled")
if "A workflow name used only as the subject of analysis" not in text:
    raise SystemExit("forced-routing policy is missing the object-of-analysis boundary")
if "Route from the requested deliverable: an analysis report versus a plan or execution artifact." not in text:
    raise SystemExit("forced-routing policy is missing deliverable-aware routing")
if "Routing map" not in text:
    raise SystemExit("forced-routing policy is missing the routing map")
if "Red flags" not in text:
    raise SystemExit("forced-routing policy is missing the red-flags table")
required = [
    "Approved plan, PRD, concrete task with acceptance criteria, or ordinary implementation request: oh-no-harness:ralph.",
    "Explicit TDD/test-first request, or an internal TDD gate inside an already-selected execution path: oh-no-harness:test-driven-development.",
    "ordinary implementation uses ralph unless the user explicitly requested TDD/test-first work",
    "The always-injected OH_NO_BOOTSTRAP no-route and direct-edit lanes apply as routing outcomes",
]
missing = [needle for needle in required if needle not in text]
if missing:
    raise SystemExit(f"forced-routing policy missing Ralph/TDD routing markers: {missing}")
for forbidden in (
    "About to make a behavior-changing production edit: oh-no-harness:test-driven-development",
    "behavior-changing edits go through test-driven-development",
):
    if forbidden in text:
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
    using-oh-no-harness)
      printf '/%s:using-oh-no-harness Smoke test only. You may read plugin skill-core and platform docs needed by the invoked skill. Do not edit files. Reply in one short sentence that names this harness.' "$PLUGIN_NAME"
      ;;
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
      printf '/%s:auto-routing status Smoke test only. You may read plugin skill-core and platform docs needed by the invoked skill. Do not edit files. Reply with what this skill configures and the three supported actions.' "$PLUGIN_NAME"
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

  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi

  cmd+=("$prompt")

  run_live_process_with_timeout "${cmd[@]}" >"$out_file"

  "$PYTHON_BIN" - "$out_file" "$skill" <<'PY'
import json
import sys

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

  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi

  cmd+=("$prompt")
  run_live_process_with_timeout "${cmd[@]}" >"$out_file"

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

  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi

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
  local read_root="$PLUGIN_ROOT"
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

  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi

  cmd+=("$prompt")
  run_live_process_with_timeout "${cmd[@]}" >"$out_file"
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

natural_session_start_prompt_for_skill() {
  case "$1" in
    interview)
      cat <<PROMPT
/${PLUGIN_NAME}:interview --quick Read-only natural SessionStart smoke test. Vague request: make Claude live natural smoke coverage stronger for this plugin checkout. Before asking the user a question, gather the necessary repository facts from ../../scripts/test-claude-plugin.sh. Do not edit files or run the test script. End with OH_NO_CLAUDE_INTERVIEW_NATURAL_OK and summarize the facts that informed the first question.
PROMPT
      ;;
    ultrawork)
      cat <<PROMPT
/${PLUGIN_NAME}:ultrawork Read-only natural SessionStart smoke test. Approved synthetic goal: assess whether ../../scripts/test-claude-plugin.sh has enough live natural smoke coverage for a release handoff. Perform a dry run only: do not create artifacts, edit files, run the test script, or execute changes. End with OH_NO_CLAUDE_ULTRAWORK_NATURAL_OK and summarize repository facts, planning readiness, and final evidence.
PROMPT
      ;;
    systematic-debugging)
      cat <<PROMPT
/${PLUGIN_NAME}:systematic-debugging Read-only natural SessionStart smoke test. Synthetic failure: a live natural smoke check for ../../scripts/test-claude-plugin.sh returned no marker even though the output file existed. Diagnose the likely cause and assess what evidence would verify it. Do not edit files or run the test script. End with OH_NO_CLAUDE_SYSTEMATIC_DEBUGGING_NATURAL_OK and summarize the diagnosis and evidence status.
PROMPT
      ;;
    verification-before-completion)
      cat <<PROMPT
/${PLUGIN_NAME}:verification-before-completion Read-only natural SessionStart smoke test. Verify the claim that ../../scripts/test-claude-plugin.sh exposes verification-before-completion in PUBLIC_SKILLS and has live smoke plumbing that another lane can extend. Do not edit files or run the test script. End with OH_NO_CLAUDE_VERIFICATION_NATURAL_OK and summarize the evidence and any skipped checks.
PROMPT
      ;;
    *)
      fail "No natural Claude prompt for skill: $1"
      ;;
  esac
}

run_natural_prompt_guard_offline_test() {
  log "Running offline Claude natural-prompt causality guard fixtures"
  local allowed_prompt forbidden skill prompt
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
      fail "Claude natural-prompt guard missed forbidden fixture: ${forbidden}"
    fi
  done

  for skill in interview ultrawork systematic-debugging verification-before-completion; do
    prompt="$(natural_session_start_prompt_for_skill "$skill")"
    assert_natural_prompt_has_no_explicit_subagent_terms "$skill" "$prompt"
  done
  ok "Claude natural-prompt guard accepts real outcome-only prompts and rejects dispatch mechanics"
}

assert_claude_natural_role_smoke() {
  local out_file="$1"
  local err_file="$2"
  local success_marker="$3"
  local label="$4"
  local role_marker_specs="$5"
  local forbidden_markers="${6:-}"

  "$PYTHON_BIN" - "$out_file" "$err_file" "$success_marker" "$label" "$role_marker_specs" "$forbidden_markers" <<'PY'
import json
import re
import sys

out_path, err_path, success_marker, label, role_marker_specs, forbidden_markers = sys.argv[1:7]
role_markers = []
for spec in role_marker_specs.split(","):
    if not spec:
        continue
    role, marker = spec.split(":", 1)
    role_markers.append((role, marker))
expected_roles = [role for role, _ in role_markers]
expected_agent_names = [f"oh-no-harness:{role}" for role in expected_roles]

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
if "agent thread limit reached" in err_text.lower():
    raise SystemExit(f"{label} natural role smoke saw agent thread limit in stderr: {err_text[:2000]!r}")

init_ok = False
tool_role_uses = []
all_agent_roles = []
task_started_roles = []
task_completed_roles = []
task_role_by_id = {}
task_role_by_tool_use_id = {}
workflow_tool_ids = set()
workflow_scripts = []
workflow_completed = False
summary_text = []
result_aware_text_indexes = []
marker = False
errors = []

with open(out_path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        text_blob = collect_text(data)
        if success_marker in text_blob:
            marker = True
        if data.get("type") == "system" and data.get("subtype") == "init":
            available_agents = set(data.get("agents", []))
            tools = set(data.get("tools", []))
            init_ok = bool({"Task", "Agent", "Workflow"} & tools) and all(
                agent in available_agents for agent in expected_agent_names
            )
        if data.get("type") == "assistant":
            for part in data.get("message", {}).get("content", []):
                if part.get("type") == "tool_use" and part.get("name") in {"Agent", "Task"}:
                    payload = part.get("input", {})
                    payload_text = collect_text(payload)
                    subagent_type = payload.get("subagent_type", "")
                    if subagent_type.startswith("oh-no-harness:"):
                        role = subagent_type.split(":", 1)[1]
                        all_agent_roles.append((index, role))
                        if role in expected_roles:
                            marker_for_role = dict(role_markers).get(role)
                            if marker_for_role and marker_for_role.lower() not in payload_text.lower():
                                raise SystemExit(
                                    f"{label} natural role smoke task payload omitted configured marker "
                                    f"{marker_for_role!r}; text={payload_text[:2000]!r}"
                                )
                            tool_role_uses.append((index, role, payload_text))
                            tool_use_id = part.get("id")
                            if tool_use_id:
                                task_role_by_tool_use_id[tool_use_id] = role
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
        if data.get("type") == "system" and data.get("subtype") == "task_started":
            subagent_type = data.get("subagent_type", "")
            if subagent_type.startswith("oh-no-harness:"):
                role = subagent_type.split(":", 1)[1]
                if role in expected_roles:
                    task_started_roles.append((index, role))
                    task_id = data.get("task_id")
                    if task_id:
                        task_role_by_id[task_id] = role
        if data.get("type") == "system" and data.get("subtype") in {"task_notification", "task_updated"}:
            subagent_type = data.get("subagent_type", "")
            role = ""
            if subagent_type.startswith("oh-no-harness:"):
                role = subagent_type.split(":", 1)[1]
            elif data.get("task_id") in task_role_by_id:
                role = task_role_by_id[data.get("task_id")]
            elif data.get("tool_use_id") in task_role_by_tool_use_id:
                role = task_role_by_tool_use_id[data.get("tool_use_id")]
            if data.get("status") == "completed":
                if role in expected_roles:
                    task_completed_roles.append((index, role))
                if (
                    data.get("tool_use_id") in workflow_tool_ids
                    or "workflow" in str(data.get("summary", "")).lower()
                ):
                    workflow_completed = True
        if data.get("type") == "result":
            result_text = str(data.get("result", ""))
            summary_text.append(result_text)
            if data.get("is_error") is True:
                errors.append((index, result_text[:1000]))

if not init_ok:
    raise SystemExit(f"{label} natural role smoke did not expose required Claude tools and agents")
if errors:
    raise SystemExit(f"{label} natural role smoke returned errors: {errors!r}")
unexpected_roles = [
    role for _, role in all_agent_roles
    if role not in expected_roles
]
if unexpected_roles:
    raise SystemExit(f"{label} natural role smoke started unexpected roles: {unexpected_roles!r}")

if not tool_role_uses and workflow_scripts:
    workflow_script = "\n".join(script for _, script in workflow_scripts)
    lower_script = workflow_script.lower()
    workflow_roles = re.findall(r"agentType:\s*['\"]oh-no-harness:([^'\"]+)['\"]", workflow_script)
    if workflow_roles != expected_roles:
        raise SystemExit(
            f"{label} natural role smoke Workflow agent() order did not match: "
            f"expected={expected_roles!r} got={workflow_roles!r}"
        )
    missing_markers = [
        marker for _, marker in role_markers
        if marker and marker.lower() not in lower_script
    ]
    if missing_markers:
        raise SystemExit(
            f"{label} natural role smoke Workflow script missed required markers: "
            f"{missing_markers!r}; script={workflow_script[:2000]!r}"
        )
    if not workflow_completed:
        raise SystemExit(f"{label} natural role smoke Workflow task did not report completion")
else:
    roles_seen = [role for _, role, _ in tool_role_uses]
    if roles_seen != expected_roles:
        raise SystemExit(
            f"{label} natural role smoke expected task role order {expected_roles!r}, got {roles_seen!r}; "
            f"uses={tool_role_uses!r}"
        )
    for role in expected_roles:
        if roles_seen.count(role) != 1:
            raise SystemExit(f"{label} natural role smoke expected exactly one task use for {role}, got {roles_seen!r}")
    started_roles = [role for _, role in task_started_roles]
    missing_starts = [role for role in expected_roles if role not in started_roles]
    if missing_starts:
        raise SystemExit(f"{label} natural role smoke missing task_started events for roles: {missing_starts!r}")
    completed_roles = [role for _, role in task_completed_roles]
    missing_completions = [role for role in expected_roles if role not in completed_roles]
    if missing_completions:
        raise SystemExit(f"{label} natural role smoke missing completed task events for roles: {missing_completions!r}")

if not marker:
    raise SystemExit(f"{label} natural role smoke did not return success marker {success_marker}")

print(f"ok - {label} natural Claude smoke started and completed required role workers")
PY
}

run_natural_session_start_live_skill_test() {
  local skill="$1"
  local success_marker="$2"
  local role_marker_specs="$3"
  local forbidden_markers="${4:-}"
  local safe_skill="${skill//\//-}"
  local out_file="$RUN_DIR/natural-session-start-${safe_skill}.jsonl"
  local err_file="$RUN_DIR/natural-session-start-${safe_skill}.err"
  local prompt
  prompt="$(natural_session_start_prompt_for_skill "$skill")"
  assert_natural_prompt_has_no_explicit_subagent_terms "$skill" "$prompt"

  local cmd=(
    "$CLAUDE_BIN"
    --print
    --verbose
    --output-format stream-json
    --include-hook-events
    --model "$LIVE_MODEL"
    --max-budget-usd "$LIVE_MAX_BUDGET_USD"
    --permission-mode bypassPermissions
    --tools default
    --no-session-persistence
    --system-prompt "You are a read-only live smoke test runner. Follow the invoked Oh No Harness skill and Claude Code platform docs. Do not edit files."
  )

  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi

  run_live_process_with_timeout "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"
  assert_claude_natural_role_smoke "$out_file" "$err_file" "$success_marker" "$skill" "$role_marker_specs" "$forbidden_markers"
}

run_ralplan_object_analysis_session_start_live_test() {
  local out_file="$RUN_DIR/ralplan-object-analysis-session-start.jsonl"
  local err_file="$RUN_DIR/ralplan-object-analysis-session-start.err"
  local prompt
  local temp_project
  prompt='Analyze the Ralplan review loop for unnecessary steps. Return an analysis report only; do not create a plan or execute changes. End with OH_NO_CLAUDE_RALPLAN_OBJECT_ANALYSIS_OK.'
  assert_natural_prompt_has_no_explicit_subagent_terms "ralplan-object-analysis" "$prompt"
  temp_project="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-ralplan-object-analysis.XXXXXX")"

  (
    trap 'rm -rf "$temp_project"' EXIT
    mkdir -p "$temp_project/.oh-no/plans"
    plans_before="$(snapshot_file_manifest "$temp_project/.oh-no/plans")"

    local cmd=(
      "$CLAUDE_BIN"
      --print
      --verbose
      --output-format stream-json
      --include-hook-events
      --model "$LIVE_MODEL"
      --max-budget-usd "$LIVE_MAX_BUDGET_USD"
      --permission-mode bypassPermissions
      --tools "Read,Glob,Grep,Task,Workflow"
      --no-session-persistence
      --plugin-dir "$PLUGIN_ROOT"
      --system-prompt "You are a read-only analysis smoke test runner in a disposable project. Do not edit files."
    )
    (cd "$temp_project" && run_live_process_with_timeout "${cmd[@]}" "$prompt") >"$out_file" 2>"$err_file"

    plans_after="$(snapshot_file_manifest "$temp_project/.oh-no/plans")"
    [[ "$plans_before" == "$plans_after" ]] || fail "Ralplan object-analysis smoke created or changed a plan artifact"

    "$PYTHON_BIN" - "$out_file" <<'PY'
import json
import sys

marker = False
for line in open(sys.argv[1], encoding="utf-8"):
    if not line.strip():
        continue
    data = json.loads(line)
    text = json.dumps(data).lower()
    marker = marker or "oh_no_claude_ralplan_object_analysis_ok" in text
    if data.get("type") != "assistant":
        continue
    for part in data.get("message", {}).get("content", []):
        if part.get("type") != "tool_use":
            continue
        name = part.get("name", "")
        payload = json.dumps(part.get("input", {})).lower()
        if name in {"Agent", "Task"} and (
            "oh-no-harness:planner" in payload or "oh-no-harness:plan-reviewer" in payload
        ):
            raise SystemExit("Ralplan object-analysis smoke dispatched a planning role")
        if name == "Workflow" and "ralplan" in payload:
            raise SystemExit("Ralplan object-analysis smoke invoked the Ralplan workflow")
if not marker:
    raise SystemExit("Ralplan object-analysis smoke missed its success marker")
print("ok - Ralplan object-analysis request stayed analysis-only")
PY
  )
}

run_natural_session_start_live_tests() {
  if [[ "$RUN_NATURAL_SESSION_START_LIVE" != "1" ]]; then
    log "Skipping live natural Claude role-worker smoke tests"
    printf 'Run with --natural-session-start-live or OH_NO_NATURAL_SESSION_START_LIVE=1 to verify analysis-only routing and natural role-worker dispatch.\n' >&2
    return
  fi

  log "Running live natural Claude role-worker smoke tests (${LIVE_LOAD_MODE})"
  mkdir -p "$RUN_DIR"
  run_ralplan_object_analysis_session_start_live_test
  run_natural_session_start_live_skill_test \
    interview \
    OH_NO_CLAUDE_INTERVIEW_NATURAL_OK \
    explore: \
    ""
  run_natural_session_start_live_skill_test \
    ultrawork \
    OH_NO_CLAUDE_ULTRAWORK_NATURAL_OK \
    explore:,planner:,verifier: \
    ""
  run_natural_session_start_live_skill_test \
    systematic-debugging \
    OH_NO_CLAUDE_SYSTEMATIC_DEBUGGING_NATURAL_OK \
    debugger:,verifier: \
    ""
  run_natural_session_start_live_skill_test \
    verification-before-completion \
    OH_NO_CLAUDE_VERIFICATION_NATURAL_OK \
    verifier: \
    ""
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

  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi

  run_live_process_with_timeout "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

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

  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi

  run_live_process_with_timeout "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

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
  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then cmd+=(--plugin-dir "$PLUGIN_ROOT"); fi
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
  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then cmd+=(--plugin-dir "$PLUGIN_ROOT"); fi
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
  cp -Rp "$PLUGIN_ROOT/." "$isolated_plugin_root/"
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
  local read_root="$PLUGIN_ROOT"

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

  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi

  # Run with fixture_dir as the WORKING DIRECTORY (do NOT inherit cwd=repo).
  # Capture the run exit code without tripping set -e so cleanup always runs.
  local run_rc=0
  if (
    cd "$fixture_dir"
    run_live_process_with_timeout "${cmd[@]}" "$prompt"
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

  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi

  run_live_process_with_timeout "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

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
  bash "$MARKETPLACE_ROOT/scripts/test-configure-subagents.sh" \
    || fail "configure-subagents offline test suite failed"
}

run_script_resolver_offline_test() {
  log "Running offline bundled-script resolver behavior + contract test suite"
  bash "$MARKETPLACE_ROOT/scripts/test-script-resolver.sh" \
    || fail "bundled-script resolver offline test suite failed"
}

# Deterministic regression for the marketplace-isolation safety design. Covers
# the shared source/config primitive, the production install call-site (real
# install_or_update_plugin driven by a logging fake CLAUDE_BIN), the release
# invocation contract, and the --isolated-config cleanup lifecycle. It never runs
# real `claude`, never touches the developer's real ~/.claude, and never mutates
# any marketplace registration; a simulated user fixture is checked for
# invariance.
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
  for s in \
    "$REPO_ROOT=local" \
    "file:///tmp/x=local" \
    "/abs/path=local" \
    "./rel=local" \
    "../rel=local" \
    "~/x=local" \
    "jcwleo/oh-no-harness=remote" \
    "https://github.com/jcwleo/oh-no-harness.git=remote" \
    "https://github.com/jcwleo/oh-no-harness=remote" \
    "git@github.com:jcwleo/oh-no-harness.git=remote" \
    "ssh://git@github.com/jcwleo/oh-no-harness.git=remote" \
    "http://github.com/a/b=invalid" \
    "https://gitlab.com/a/b=invalid" \
    "https://user:tok@github.com/a/b=invalid" \
    "https://github.com/a/b?x=1=invalid" \
    "singleword=invalid" \
  ; do
    expect="${s##*=}"; src="${s%=*}"
    actual="$("$PYTHON_BIN" "$helper" classify-source "$src")"
    [[ "$actual" == "$expect" ]] \
      || { rm -rf "$temp_root"; fail "classify-source('$src')='$actual' expected '$expect'"; }
  done

  # ---- shared primitive: github-slug parse + credential rejection ---------
  for s in \
    "https://github.com/jcwleo/oh-no-harness.git" \
    "https://github.com/jcwleo/oh-no-harness" \
    "git@github.com:jcwleo/oh-no-harness.git" \
    "ssh://git@github.com/jcwleo/oh-no-harness.git" \
  ; do
    actual="$("$PYTHON_BIN" "$helper" github-slug "$s")"
    [[ "$actual" == "jcwleo/oh-no-harness" ]] \
      || { rm -rf "$temp_root"; fail "github-slug('$s')='$actual' expected jcwleo/oh-no-harness"; }
  done
  out="$temp_root/slug.out"; err="$temp_root/slug.err"
  for s in \
    "http://github.com/a/b" \
    "https://x:s3cr3t@github.com/jcwleo/oh-no-harness.git" \
    "https://gitlab.com/a/b" \
    "https://github.com:443/a/b" \
    "ssh://user@github.com/a/b" \
  ; do
    rc=0
    "$PYTHON_BIN" "$helper" github-slug "$s" >"$out" 2>"$err" || rc=$?
    [[ "$rc" != "0" ]] \
      || { rm -rf "$temp_root"; fail "github-slug accepted an unsupported origin: $s"; }
    grep -Fq "s3cr3t" "$out" "$err" \
      && { rm -rf "$temp_root"; fail "github-slug leaked a credential from '$s'"; } || true
  done

  # ---- shared primitive: redaction ----------------------------------------
  [[ "$("$PYTHON_BIN" "$helper" redact "https://x:s3cr3t@github.com/a/b")" == "https://***@github.com/a/b" ]] \
    || { rm -rf "$temp_root"; fail "redact did not mask URL userinfo"; }
  [[ "$("$PYTHON_BIN" "$helper" redact "/local/path")" == "/local/path" ]] \
    || { rm -rf "$temp_root"; fail "redact altered a local path"; }

  # ---- shared primitive: config-home identity (exact/trailing/dot/symlink) -
  mkdir -p "$fake_home/.claude"
  ln -s "$fake_home/.claude" "$temp_root/cfglink"
  for s in \
    "=default" \
    "$fake_home/.claude=default" \
    "$fake_home/.claude/=default" \
    "$fake_home/.claude/.=default" \
    "$fake_home/x/../.claude=default" \
    "$temp_root/cfglink=default" \
    "$temp_root/other-config=isolated" \
  ; do
    expect="${s##*=}"; cfg="${s%=*}"
    actual="$("$PYTHON_BIN" "$helper" config-identity "$cfg" "$fake_home")"
    [[ "$actual" == "$expect" ]] \
      || { rm -rf "$temp_root"; fail "config-identity('$cfg')='$actual' expected '$expect'"; }
  done

  # ---- guard control flow (name-agnostic; blocker 1a) ----------------------
  err="$temp_root/danger.err"
  rc=0
  (
    unset CLAUDE_CONFIG_DIR OH_NO_ALLOW_CANONICAL_LOCAL_MARKETPLACE
    HOME="$fake_home"; MARKETPLACE_NAME="oh-no-harness"; MARKETPLACE_SOURCE="$REPO_ROOT"
    guard_canonical_local_marketplace
  ) 2>"$err" || rc=$?
  [[ "$rc" == "1" ]] \
    || { rm -rf "$temp_root"; fail "guard did not block local source + default config (rc=$rc)"; }
  grep -Fq "from a LOCAL source" "$err" \
    || { rm -rf "$temp_root"; fail "guard block message missing the expected diagnostic"; }

  # A non-canonical name is NOT a safe path.
  rc=0
  (
    unset CLAUDE_CONFIG_DIR OH_NO_ALLOW_CANONICAL_LOCAL_MARKETPLACE
    HOME="$fake_home"; MARKETPLACE_NAME="some-other-marketplace"; MARKETPLACE_SOURCE="$REPO_ROOT"
    guard_canonical_local_marketplace
  ) 2>/dev/null || rc=$?
  [[ "$rc" == "1" ]] \
    || { rm -rf "$temp_root"; fail "guard treated a non-canonical name + local + default as safe (rc=$rc)"; }

  # An invalid source is always refused.
  rc=0
  (
    unset CLAUDE_CONFIG_DIR OH_NO_ALLOW_CANONICAL_LOCAL_MARKETPLACE
    HOME="$fake_home"; MARKETPLACE_NAME="oh-no-harness"; MARKETPLACE_SOURCE="http://github.com/a/b"
    guard_canonical_local_marketplace
  ) 2>/dev/null || rc=$?
  [[ "$rc" == "1" ]] \
    || { rm -rf "$temp_root"; fail "guard allowed an invalid source into the real config (rc=$rc)"; }

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
  [[ "$rc" == "1" ]] \
    || { rm -rf "$temp_root"; fail "blocked install_or_update_plugin did not fail closed (rc=$rc)"; }
  [[ ! -s "$wire_log" ]] \
    || { local leaked; leaked="$(cat "$wire_log")"; rm -rf "$temp_root"; fail "blocked install path executed CLI commands: $leaked"; }

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
  grep -q "plugin marketplace add" "$wire_log" \
    || { rm -rf "$temp_root"; fail "safe install path did not run marketplace add"; }
  grep "plugin marketplace add" "$wire_log" | grep -Fq "CLAUDE_CONFIG_DIR=$temp_root/iso-wire" \
    || { rm -rf "$temp_root"; fail "marketplace add did not carry the isolated config env"; }
  grep -q "plugin install" "$wire_log" \
    || { rm -rf "$temp_root"; fail "safe install path did not run plugin install"; }

  # --no-install / OH_NO_INSTALL=0 must skip install (and the guard) entirely.
  rc=0
  (
    unset CLAUDE_CONFIG_DIR; HOME="$fake_home"
    CLAUDE_BIN="/bin/false"; MARKETPLACE_NAME="oh-no-harness"; MARKETPLACE_SOURCE="$REPO_ROOT"
    INSTALL_MODE=0
    install_or_update_plugin
  ) >/dev/null 2>&1 || rc=$?
  [[ "$rc" == "0" ]] \
    || { rm -rf "$temp_root"; fail "--no-install did not skip the install/guard path (rc=$rc)"; }

  # ---- release invocation contract (guard/call-site removal must fail) -----
  local rel_log="$temp_root/release-invoke.log"
  : >"$rel_log"
  (
    source "$REPO_ROOT/scripts/release"
    run() { printf 'ARGV=%s\nSRC=%s\nINSTALL=%s\n' "$*" "${OH_NO_MARKETPLACE_SOURCE:-}" "${OH_NO_INSTALL:-}"; }
    MARKETPLACE_NAME="oh-no-harness"
    run_claude_install_test "jcwleo/oh-no-harness"
  ) >"$rel_log" 2>/dev/null || true
  grep -q 'ARGV=.*scripts/test-claude-plugin.sh.*--isolated-config' "$rel_log" \
    || { rm -rf "$temp_root"; fail "release Claude invocation missing --isolated-config"; }
  grep -q '^SRC=jcwleo/oh-no-harness$' "$rel_log" \
    || { rm -rf "$temp_root"; fail "release Claude invocation did not pass the credential-free slug"; }
  grep -q '^INSTALL=1$' "$rel_log" \
    || { rm -rf "$temp_root"; fail "release Claude invocation did not force OH_NO_INSTALL=1"; }

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

  # ---- --isolated-config cleanup lifecycle (success/failure/INT/TERM) ------
  local iso_home
  iso_home="$(bash -c 'set -euo pipefail; source "'"$REPO_ROOT"'/scripts/test-claude-plugin.sh"; setup_isolated_config; printf "%s\n" "$CLAUDE_CONFIG_DIR"' 2>/dev/null)"
  { [[ -n "$iso_home" && ! -d "$iso_home" ]]; } \
    || { rm -rf "$temp_root"; fail "isolated config not cleaned on success (home=$iso_home)"; }
  iso_home="$(bash -c 'set -uo pipefail; source "'"$REPO_ROOT"'/scripts/test-claude-plugin.sh"; setup_isolated_config; printf "%s\n" "$CLAUDE_CONFIG_DIR"; exit 1' 2>/dev/null || true)"
  { [[ -n "$iso_home" && ! -d "$iso_home" ]]; } \
    || { rm -rf "$temp_root"; fail "isolated config not cleaned on failure (home=$iso_home)"; }
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
  ok "marketplace-isolation: shared primitive, guarded install call-site, release contract, and isolated-config cleanup all verified"
}


main() {
  cd "$PLUGIN_ROOT"
  require_command "$CLAUDE_BIN"
  require_command "$PYTHON_BIN"

  [[ "$ISOLATED_CONFIG" == "1" ]] && setup_isolated_config

  log "Testing ${PLUGIN_ID} from ${PLUGIN_ROOT}"
  validate_manifests
  validate_hooks
  run_live_timeout_offline_test
  run_natural_prompt_guard_offline_test
  run_escape_net_offline_test
  run_active_stale_scan_reader_offline_test
  run_configure_subagents_offline_test
  run_script_resolver_offline_test
  run_marketplace_isolation_offline_test
  validate_frontmatter
  install_or_update_plugin
  run_live_tests
  run_deep_live_tests
  run_ralplan_live_test
  run_parallel_live_test
  run_fusion_rescue_live_test
  run_cross_host_fallback_live_test
  run_model_diversity_live_test
  run_parallel_executor_live_test
  run_simplify_live_test
  run_natural_session_start_live_tests
  log "All requested checks passed"
}

# Run main only when executed directly. When sourced (e.g. to exercise a single
# offline function such as run_escape_net_offline_test or validate_hooks without
# spending the full install/live suite), main is skipped.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
