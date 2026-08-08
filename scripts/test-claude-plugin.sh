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
RUN_DISPATCH_LIVE="${OH_NO_DISPATCH_LIVE:-0}"
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

Installs or updates the local Claude Code plugin, then runs deterministic checks.
Ordinary --live directly invokes each public non-Fusion skill and checks one
explicit read-only invariant. Separate --dispatch-live checks only the bounded
seven-scenario internal role-dispatch matrix.

Options:
  --live                 Run direct public-skill invariant smokes.
  --dispatch-live        Run the bounded internal role-dispatch matrix.
  --skip-live            Skip all live skill smokes. Default.
  --no-install           Do not add marketplace, install, or update plugin.
  --isolated-config      Create and clean a throwaway CLAUDE_CONFIG_DIR.
  --scope <scope>        Install/update scope: local, project, user, managed.
  --live-load <mode>     plugin-dir or installed. Default: plugin-dir.
  --marketplace-source <source>
  --model <model>        Claude model alias. Default: sonnet.
  --max-budget-usd <n>   Per-command max budget. Default: 3.00.
  -h, --help             Show this help.

Natural-routing, deep-summary, topology, worktree, and exhaustive-agent model
suites have been retired. Fusion Rescue remains deferred. Cross-host transport is
owned only by the Codex driver's separate --cross-host-live lane.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --live) RUN_LIVE=1; shift ;;
    --dispatch-live) RUN_DISPATCH_LIVE=1; shift ;;
    --skip-live) RUN_LIVE=0; RUN_DISPATCH_LIVE=0; shift ;;
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
case "$LIVE_LOAD_MODE" in plugin-dir|installed) ;; *) echo "--live-load must be plugin-dir or installed" >&2; exit 2 ;; esac
case "$REQUESTED_SCOPE" in ""|local|project|user|managed) ;; *) echo "--scope must be local, project, user, or managed" >&2; exit 2 ;; esac

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
  [[ "$LIVE_LOAD_MODE" == plugin-dir && ( "$RUN_LIVE" == 1 || "$RUN_DISPATCH_LIVE" == 1 ) ]]
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
# The always-on Claude orchestration block must carry the no-nested-host-plan
# boundary exactly once in the emitted (not just source) SessionStart output.
host_plan = [
    "Host-plan boundary:",
    "never auto-wrap Ralph-eligible Oh No Harness execution in EnterPlanMode or a host planning pass",
    "host plan mode needs explicit user request",
    "Usable approved/concrete execution contract goes straight to Ralph",
    "vague or plan-only work routes upstream to Oh No Harness planning",
    "no-route housekeeping stays direct",
]
missing_host_plan = [needle for needle in host_plan if needle not in text]
if missing_host_plan:
    raise SystemExit(f"Claude SessionStart is missing host-plan boundary semantics: {missing_host_plan}")
if text.count("Host-plan boundary:") != 1 or text.count("EnterPlanMode") != 1:
    raise SystemExit("Claude SessionStart host-plan boundary is not singular")
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

claude_direct_active_plugin_root() {
  local root
  if [[ "$LIVE_LOAD_MODE" == plugin-dir ]]; then
    root="$LIVE_PLUGIN_ROOT"
  else
    root="$(cached_plugin_root)"
    "$CLAUDE_BIN" plugin list --json | "$PYTHON_BIN" -c 'import json,sys
plugin_id, manifest_path = sys.argv[1:]
plugins = json.load(sys.stdin)
manifest = json.load(open(manifest_path, encoding="utf-8"))
version = manifest.get("version")
if not any(plugin.get("id") == plugin_id and plugin.get("enabled") is True and plugin.get("version") == version for plugin in plugins):
    raise SystemExit(f"installed Claude plugin {plugin_id} is missing, disabled, or version-mismatched")
' "$PLUGIN_ID" "$root/.claude-plugin/plugin.json"
  fi
  "$PYTHON_BIN" -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "$root"
}

assert_direct_installed_skill_identity() {
  "$PYTHON_BIN" - "$1" "$2" "$PLUGIN_NAME" <<'PY'
import json, re, sys
from pathlib import Path
root = Path(sys.argv[1]).resolve()
skill, plugin_name = sys.argv[2:]
manifest_path = root / ".claude-plugin" / "plugin.json"
try:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as exc:
    raise SystemExit(f"HARD FAIL [{skill}] unreadable active Claude plugin manifest: {exc}")
expected_entry = f"./skills-claude/{skill}/"
if manifest.get("name") != plugin_name or expected_entry not in (manifest.get("skills") or []):
    raise SystemExit(f"HARD FAIL [{skill}] active Claude plugin identity or skill path is wrong")
wrapper = root / "skills-claude" / skill / "SKILL.md"
command = root / "commands" / f"{skill}.md"
try:
    resolved = wrapper.resolve(strict=True)
    wrapper_text = wrapper.read_text(encoding="utf-8")
    command_text = command.read_text(encoding="utf-8")
except OSError as exc:
    raise SystemExit(f"HARD FAIL [{skill}] missing installed skill identity: {exc}")
if resolved.parent != wrapper.parent.resolve():
    raise SystemExit(f"HARD FAIL [{skill}] installed skill escaped its expected path: {resolved}")
if "oh-no-harness-generated-skill-wrapper" not in wrapper_text:
    raise SystemExit(f"HARD FAIL [{skill}] installed skill lacks generated-wrapper identity")
match = re.search(r"(?m)^name:[ \t]*([^\n]+)[ \t]*$", wrapper_text)
if match is None or match.group(1).strip() != skill:
    raise SystemExit(f"HARD FAIL [{skill}] installed skill frontmatter identity is wrong")
expected_read = f"${{CLAUDE_PLUGIN_ROOT}}/skills-claude/{skill}/SKILL.md"
if expected_read not in command_text:
    raise SystemExit(f"HARD FAIL [{skill}] installed command points at the wrong skill path")
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
    install-statusline) printf 'stop-no-change' ;;
    configure-subagents) printf 'report-status-and-stop' ;;
    *) fail "No direct invariant for skill: $1" ;;
  esac
}

direct_prompt_for_skill() {
  case "$1" in
    interview) printf '/%s:interview A request says only "improve this tool" and omits users and constraints. Apply the directly invoked skill policy. Choose exactly one: clarify-before-planning | plan-now.' "$PLUGIN_NAME" ;;
    ralplan) printf '/%s:ralplan A reviewed plan is ready but the required user approval is still pending. Apply the directly invoked skill policy. Choose exactly one: wait-for-user-approval | execute-now.' "$PLUGIN_NAME" ;;
    ralph) printf '/%s:ralph The task has no usable acceptance contract. Apply the directly invoked skill policy. Choose exactly one: require-acceptance-contract | execute-without-contract.' "$PLUGIN_NAME" ;;
    ultrawork) printf '/%s:ultrawork Requirements remain unclear and spec-content approval has not occurred. Apply the directly invoked skill policy. Choose exactly one: wait-for-spec-approval | begin-autonomous-execution.' "$PLUGIN_NAME" ;;
    auto-routing) printf '/%s:auto-routing status The stored preference is changed during this turn. Apply the directly invoked skill policy. Choose exactly one: future-session-guidance-only | changes-current-turn.' "$PLUGIN_NAME" ;;
    test-driven-development) printf '/%s:test-driven-development A test-first change has no failing focused test yet. Apply the directly invoked skill policy. Choose exactly one: create-red-first | edit-production-first.' "$PLUGIN_NAME" ;;
    simplify) printf '/%s:simplify No behavior lock exists and no named THOROUGH expansion trigger is present. Apply the directly invoked skill policy. Choose exactly one: lock-behavior-then-combined-scan | run-four-way-cleanup-now.' "$PLUGIN_NAME" ;;
    verification-before-completion) printf '/%s:verification-before-completion One required acceptance criterion lacks direct evidence. Apply the directly invoked skill policy. Choose exactly one: withhold-completion | claim-complete.' "$PLUGIN_NAME" ;;
    systematic-debugging) printf '/%s:systematic-debugging A failing test has an unknown cause and has not been reproduced. Apply the directly invoked skill policy. Choose exactly one: reproduce-first | patch-first.' "$PLUGIN_NAME" ;;
    install-statusline) printf '/%s:install-statusline Hypothetical read-only policy scenario: the installer check has already returned `STATUS: installed-matching`. Apply the directly invoked skill policy. Choose exactly one: stop-no-change | apply-installer.' "$PLUGIN_NAME" ;;
    configure-subagents) printf '/%s:configure-subagents Hypothetical read-only policy scenario: invocation used the status-only branch and the configurator check has already returned `STATUS: matching`. Apply the directly invoked skill policy. Choose exactly one: report-status-and-stop | begin-interview.' "$PLUGIN_NAME" ;;
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

run_direct_smoke_classifier_offline_test() {
  local root file got
  root="$(mktemp -d)"; file="$root/evidence"
  for value in 'HTTP 429: credentials cooling down' 'quota exceeded' 'provider credits exhausted'; do
    printf '%s\n' "$value" >"$file"; got="$(direct_smoke_failure_class 1 "$file")"; [[ "$got" == provider-limited ]] || fail "provider exhaustion classifier fixture failed: $value"
  done
  : >"$file"; got="$(direct_smoke_failure_class 124 "$file")"; [[ "$got" == provider-limited ]] || fail "timeout classifier fixture failed"
  for value in 'Unknown command: /oh-no-harness:interview' 'permission denied' 'unknown option --bad' 'Unknown option: --rate-limit' 'unexpected argument --rate-limit'; do
    printf '%s\n' "$value" >"$file"; got="$(direct_smoke_failure_class 2 "$file")"; [[ "$got" == hard-fail ]] || fail "hard-failure classifier accepted: $value"
  done
  printf 'Skill: interview\nInvariant: plan-now\n' >"$file"
  if assert_direct_result_fields interview clarify-before-planning "$file" >/dev/null 2>&1; then fail "wrong finite invariant choice passed"; fi
  printf 'Skill: interview\nInvariant: clarify-before-planning\nNarration: extra\n' >"$file"
  if assert_direct_result_fields interview clarify-before-planning "$file" >/dev/null 2>&1; then fail "third direct-result line passed"; fi
  local plugin="$root/plugin" wrapper="$root/plugin/skills-claude/interview/SKILL.md"
  mkdir -p "$plugin/.claude-plugin" "$plugin/skills-claude/interview" "$plugin/commands"
  printf '{"name":"%s","skills":["./skills-claude/interview/"]}\n' "$PLUGIN_NAME" >"$plugin/.claude-plugin/plugin.json"
  printf '%s\n' '---' 'name: interview' '---' '<!-- oh-no-harness-generated-skill-wrapper -->' >"$wrapper"
  printf '%s\n' 'Read `${CLAUDE_PLUGIN_ROOT}/skills-claude/interview/SKILL.md`.' >"$plugin/commands/interview.md"
  assert_direct_installed_skill_identity "$plugin" interview || fail "valid installed skill identity fixture failed"
  mv "$wrapper" "$wrapper.saved"
  if assert_direct_installed_skill_identity "$plugin" interview >/dev/null 2>&1; then fail "missing installed skill identity passed"; fi
  mv "$wrapper.saved" "$wrapper"
  printf '%s\n' 'Read `${CLAUDE_PLUGIN_ROOT}/skills-claude/wrong/SKILL.md`.' >"$plugin/commands/interview.md"
  if assert_direct_installed_skill_identity "$plugin" interview >/dev/null 2>&1; then fail "wrong installed skill identity passed"; fi
  rm -rf "$root"; ok "direct smoke failure classes, exact output, and installed identity"
}

run_live_skill_test() {
  local skill="$1" expected out_file err_file evidence_file result_file before after prompt rc class active_root
  expected="$(direct_invariant_for_skill "$skill")"; out_file="$RUN_DIR/${skill}.jsonl"; err_file="$RUN_DIR/${skill}.err"; evidence_file="$RUN_DIR/${skill}.failure-evidence"; result_file="$RUN_DIR/${skill}.result"; prompt="$(direct_prompt_for_skill "$skill")"; active_root="$(claude_direct_active_plugin_root)"
  assert_direct_installed_skill_identity "$active_root" "$skill"
  before="$(git -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=all; git -C "$REPO_ROOT" diff --binary HEAD | shasum -a 256)"
  local cmd=("$CLAUDE_BIN" --print --verbose --output-format stream-json --model "$LIVE_MODEL" --max-budget-usd "$LIVE_MAX_BUDGET_USD" --permission-mode dontAsk --tools "Read" --no-session-persistence --system-prompt "$LIVE_SYSTEM_PROMPT")
  append_live_plugin_dir_arg; cmd+=("$prompt")
  rc=0; run_plugin_dir_live_process_with_timeout "${cmd[@]}" >"$out_file" 2>"$err_file" || rc=$?
  after="$(git -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=all; git -C "$REPO_ROOT" diff --binary HEAD | shasum -a 256)"
  [[ "$before" == "$after" ]] || fail "HARD FAIL [$skill] forbidden project mutation"
  if [[ "$rc" != 0 ]]; then
    { [[ ! -f "$out_file" ]] || command cat "$out_file"; [[ ! -f "$err_file" ]] || command cat "$err_file"; } >"$evidence_file"
    class="$(direct_smoke_failure_class "$rc" "$evidence_file")"
    if [[ "$class" == provider-limited ]]; then printf 'INCONCLUSIVE(provider-limited) - %s (command rc=%s)\n' "$skill" "$rc" >&2; return 0; fi
    fail "HARD FAIL [$skill] direct invocation failed (rc=$rc): $(tail -n 3 "$err_file" | tr '\n' ' ')"
  fi
  "$PYTHON_BIN" - "$out_file" "$skill" "$result_file" <<'PY'
import json, sys
path, skill, result_path = sys.argv[1:]
result = None; malformed = False
try:
    for raw in open(path, encoding="utf-8"):
        if not raw.strip(): continue
        row = json.loads(raw)
        if row.get("type") == "result":
            malformed = malformed or bool(row.get("is_error")); result = str(row.get("result", "")).strip()
except (OSError, json.JSONDecodeError) as exc: raise SystemExit(f"HARD FAIL [{skill}] malformed command result: {exc}")
if malformed or not result: raise SystemExit(f"HARD FAIL [{skill}] malformed command result")
if result.startswith("Unknown command:"): raise SystemExit(f"HARD FAIL [{skill}] direct slash invocation did not resolve")
open(result_path, "w", encoding="utf-8").write(result)
PY
  assert_direct_result_fields "$skill" "$expected" "$result_file"
  printf 'PASS - %s: %s\n' "$skill" "$expected"
}

run_live_tests() {
  if [[ "$RUN_LIVE" != "1" ]]; then
    log "Skipping live Claude direct skill smokes"; printf 'Run with --live or OH_NO_LIVE=1 for one direct read-only invariant per public non-Fusion skill.\n' >&2; printf 'SKIPPED/DEFERRED - fusion-rescue: Claude-host provider credits exhausted\n' >&2; return
  fi
  mkdir -p "$RUN_DIR"; log "Running direct Claude skill smokes (${LIVE_LOAD_MODE})"
  local skill
  for skill in "${PUBLIC_SKILLS[@]}"; do
    if [[ "$skill" == "fusion-rescue" ]]; then printf 'SKIPPED/DEFERRED - fusion-rescue: Claude-host provider credits exhausted\n' >&2; continue; fi
    run_live_skill_test "$skill"
  done
  ok "direct live outputs saved under ${RUN_DIR#$MARKETPLACE_ROOT/}"
}

dispatch_scenario_contract() {
  case "$1" in
    interview) printf '%s|%s|%s\n' 'explore' '' '' ;;
    ralplan) printf '%s|%s|%s\n' 'planner,plan-reviewer' '.oh-no/plans/task-56-ralplan-probe.md,.oh-no/sessions/task-56-dispatch-ralplan/planning.md' '.oh-no/plans/task-56-ralplan-probe.md' ;;
    ralph) printf '%s|%s|%s\n' 'executor,code-reviewer' 'dispatch-fixture/src/formatter.py,dispatch-fixture/tests/test_formatter.py,dispatch-fixture/.oh-no/sessions/task-56-dispatch-ralph/progress.md,dispatch-fixture/.oh-no/sessions/task-56-dispatch-ralph/verification.md' 'dispatch-fixture/src/formatter.py,dispatch-fixture/tests/test_formatter.py' ;;
    verification-before-completion) printf '%s|%s|%s\n' 'verifier' '' '' ;;
    systematic-debugging) printf '%s|%s|%s\n' 'debugger' '' '' ;;
    auto-routing|simplify) printf '%s|%s|%s\n' '' '' '' ;;
    *) fail "unknown Claude dispatch-live scenario: $1" ;;
  esac
}

prepare_claude_dispatch_fixture() {
  local skill="$1" workspace="$2" nonce="$3" fixture="$workspace/dispatch-fixture"
  mkdir -p "$fixture"
  case "$skill" in
    interview)
      printf 'Brownfield service fact: fixture protocol is kestrel-%s.\n' "$nonce" >"$fixture/FACTS.md"
      ;;
    ralplan)
      mkdir -p "$workspace/.oh-no/plans" "$workspace/.oh-no/sessions/task-56-dispatch-ralplan"
      printf 'Session ID: task-56-dispatch-ralplan\nMode: STANDARD\nApproval: planning scenario approved\n' >"$workspace/.oh-no/sessions/task-56-dispatch-ralplan/planning.md"
      printf 'Plan creation of dispatch-fixture/output.txt with content exactly %s plus one trailing newline. This is a private, inert, non-consumed fixture artifact with no public, runtime, generated, configuration, executable, security, or permission surface. There are no implementation choices or open questions. Planning only; do not implement.\n' "$nonce" >"$fixture/request.txt"
      ;;
    ralph)
      mkdir -p "$fixture/src" "$fixture/tests" "$fixture/.oh-no/sessions/task-56-dispatch-ralph"
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

claude_dispatch_prompt() {
  local skill="$1" nonce="$2" child_json="$3"
  local common="Every expected child task must require its assigned nonce in its final result. Wait for each expected child to complete and preserve its nonce-bearing Agent tool_result. Include scenario nonce $nonce and every child nonce in your final answer. Do not use generic agents or optional agents."
  case "$skill" in
    interview)
      printf '/%s:interview Tiny brownfield fact lookup. Read dispatch-fixture/FACTS.md only by dispatching exactly one subagent_type oh-no-harness:explore. Child nonces: %s. %s Do not change files.\n' "$PLUGIN_NAME" "$child_json" "$common" ;;
    ralplan)
      printf '/%s:ralplan Use fixed Session ID task-56-dispatch-ralplan in STANDARD mode. The approved planning state is in .oh-no/sessions/task-56-dispatch-ralplan/planning.md and the request is dispatch-fixture/request.txt. Dispatch exactly one oh-no-harness:planner to create .oh-no/plans/task-56-ralplan-probe.md, wait for Planner completion, then dispatch exactly one oh-no-harness:plan-reviewer to review that plan and wait for completion. Child nonces: %s. %s Stop immediately after one review; do not apply feedback, request v2, seek approval, or execute. Only the designated plan and planning.md may change.\n' "$PLUGIN_NAME" "$child_json" "$common" ;;
    ralph)
      printf '/%s:ralph Use STANDARD mode and fixed Session ID task-56-dispatch-ralph. Worktree decision: user declined; use the current disposable fixture checkout. Approved bounded change: normalize_label must trim outer whitespace and collapse internal whitespace. Dispatch exactly one oh-no-harness:executor to update only dispatch-fixture/src/formatter.py and dispatch-fixture/tests/test_formatter.py using python -B -m unittest discover -s tests, and wait for completion. Then dispatch exactly one oh-no-harness:code-reviewer to review once, wait for completion, and stop. Child nonces: %s. %s No verifier, commit, worktree, additional agent, or feedback application. Only those two fixture files plus dispatch-fixture/.oh-no/sessions/task-56-dispatch-ralph/progress.md and verification.md may change.\n' "$PLUGIN_NAME" "$child_json" "$common" ;;
    verification-before-completion)
      printf '/%s:verification-before-completion Independently verify immutable dispatch-fixture/evidence.txt by dispatching exactly one oh-no-harness:verifier. Child nonces: %s. %s Do not change files or claim broader completion.\n' "$PLUGIN_NAME" "$child_json" "$common" ;;
    systematic-debugging)
      printf '/%s:systematic-debugging The failure is reproduced and one active hypothesis is recorded in dispatch-fixture/failure.log. Diagnose only by dispatching exactly one oh-no-harness:debugger. Child nonces: %s. %s Do not patch or change files.\n' "$PLUGIN_NAME" "$child_json" "$common" ;;
    auto-routing)
      printf '/%s:auto-routing Report the read-only semantics/status from dispatch-fixture/status.txt. Dispatch zero children, change nothing, and include scenario nonce %s in the final answer.\n' "$PLUGIN_NAME" "$nonce" ;;
    simplify)
      printf '/%s:simplify Inspect the tiny behavior-locked clean diff under dispatch-fixture. Combined-depth expansion is not justified. Dispatch zero named children, do not edit, and include scenario nonce %s in the final answer.\n' "$PLUGIN_NAME" "$nonce" ;;
  esac
}

run_sanitized_claude_dispatch_command() (
  local launch_dir="$1"
  shift
  cd "$launch_dir"
  unset OLDPWD
  local name
  while IFS= read -r name; do
    [[ -n "$name" ]] && unset "$name"
  done < <("$PYTHON_BIN" "$SCRIPT_DIR/claude-dispatch-live-oracle.py" environment-unsets --repo-root "$REPO_ROOT")
  "$PYTHON_BIN" "$SCRIPT_DIR/claude-dispatch-live-oracle.py" environment-check --repo-root "$REPO_ROOT" || return $?
  export PYTHONDONTWRITEBYTECODE=1
  export PYTEST_ADDOPTS="${PYTEST_ADDOPTS:+$PYTEST_ADDOPTS }-p no:cacheprovider"
  run_plugin_dir_live_process_with_timeout "$@"
)

run_claude_dispatch_live_scenario() {
  local skill="$1" active_root contract roles allow require attempt
  active_root="$(claude_direct_active_plugin_root)"
  contract="$(dispatch_scenario_contract "$skill")"
  IFS='|' read -r roles allow require <<<"$contract"
  for attempt in 1 2; do
    local root workspace evidence prompt_file events_file result_file before_file after_file export_dir
    local nonce parent_nonce child_json role role_nonce rc class oracle_rc canonical_before canonical_after escape_before escape_after
    local baseline_head='' baseline_branch=''
    root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-claude-dispatch-${skill}.XXXXXX")"
    workspace="$root/plugin"; evidence="$root/evidence"; mkdir -p "$workspace" "$evidence"
    cp -Rp "$active_root/." "$workspace/"
    nonce="$($PYTHON_BIN -c 'import secrets; print(secrets.token_hex(12))')"
    parent_nonce="PARENT-$nonce"; child_json='{'; local first=1
    IFS=',' read -ra expected_roles <<<"$roles"
    for role in "${expected_roles[@]:-}"; do
      [[ -n "$role" ]] || continue
      role_nonce="CHILD-${role}-$nonce"
      (( first == 1 )) || child_json+=','
      child_json+="\"$role\":\"$role_nonce\""; first=0
    done
    child_json+='}'
    prepare_claude_dispatch_fixture "$skill" "$workspace" "$parent_nonce"
    if [[ "$skill" == ralph ]]; then
      baseline_head="$(git -C "$workspace/dispatch-fixture" rev-parse HEAD)"
      baseline_branch="$(git -C "$workspace/dispatch-fixture" symbolic-ref -q --short HEAD || printf DETACHED)"
    fi
    prompt_file="$evidence/prompt.txt"; claude_dispatch_prompt "$skill" "$parent_nonce" "$child_json" >"$prompt_file"
    events_file="$evidence/events.jsonl"; result_file="$evidence/result.txt"
    before_file="$evidence/before.json"; after_file="$evidence/after.json"
    "$PYTHON_BIN" "$SCRIPT_DIR/claude-dispatch-live-oracle.py" snapshot "$workspace" "$before_file"
    canonical_before="$(git -C "$REPO_ROOT" rev-parse HEAD; git -C "$REPO_ROOT" branch --show-current; git -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=all; git -C "$REPO_ROOT" diff --binary HEAD | shasum -a 256)"
    escape_before="$(snapshot "$REPO_ROOT" __claude_dispatch_no_owned_worktree__)"
    assert_direct_installed_skill_identity "$workspace" "$skill"
    local cmd=("$CLAUDE_BIN" --print --verbose --output-format stream-json --model sonnet --max-budget-usd "$LIVE_MAX_BUDGET_USD" --permission-mode bypassPermissions --tools default --no-session-persistence --system-prompt "Run only the bounded dispatch fixture. Preserve nonce receipts and obey the mutation allowlist.")
    cmd+=(--plugin-dir "$workspace" "$(<"$prompt_file")")
    rc=0; run_sanitized_claude_dispatch_command "$workspace" "${cmd[@]}" >"$events_file" 2>"$evidence/stderr.txt" || rc=$?
    canonical_after="$(git -C "$REPO_ROOT" rev-parse HEAD; git -C "$REPO_ROOT" branch --show-current; git -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=all; git -C "$REPO_ROOT" diff --binary HEAD | shasum -a 256)"
    escape_after="$(snapshot "$REPO_ROOT" __claude_dispatch_no_owned_worktree__)"
    [[ "$canonical_before" == "$canonical_after" ]] || fail "HARD FAIL [$skill] canonical checkout HEAD, branch, tracked diff, or untracked state changed"
    escape_net_verdict "$escape_before" "$escape_after" __claude_dispatch_no_owned_worktree__ >/dev/null || fail "HARD FAIL [$skill] canonical checkout containment breached"
    export_dir="$RUN_DIR/dispatch-live/$skill/attempt-$attempt"
    [[ ! -e "$export_dir" ]] || fail "HARD FAIL [$skill] dispatch evidence destination already exists"
    "$PYTHON_BIN" "$SCRIPT_DIR/claude-dispatch-live-oracle.py" secret-scan "$prompt_file" "$events_file" "$evidence/stderr.txt"
    mkdir -p "$export_dir"; cp "$prompt_file" "$events_file" "$evidence/stderr.txt" "$export_dir/"
    "$PYTHON_BIN" "$SCRIPT_DIR/claude-dispatch-live-oracle.py" snapshot "$workspace" "$after_file"
    "$PYTHON_BIN" "$SCRIPT_DIR/claude-dispatch-live-oracle.py" mutation --skill "$skill" --before "$before_file" --after "$after_file" --allow "$allow"
    if [[ "$skill" == ralph ]]; then
      [[ "$baseline_head" == "$(git -C "$workspace/dispatch-fixture" rev-parse HEAD)" && "$baseline_branch" == "$(git -C "$workspace/dispatch-fixture" symbolic-ref -q --short HEAD || printf DETACHED)" ]] || fail "HARD FAIL [ralph] disposable fixture HEAD or branch changed"
    fi
    if [[ "$rc" != 0 ]]; then
      class="$(direct_smoke_failure_class "$rc" "$evidence/stderr.txt")"
      if [[ "$class" == provider-limited ]]; then printf 'INCONCLUSIVE(provider-limited) - Claude dispatch %s (command rc=%s)\n' "$skill" "$rc" >&2; rm -rf "$root"; return 0; fi
      fail "HARD FAIL [$skill] Claude dispatch invocation failed (rc=$rc)"
    fi
    "$PYTHON_BIN" "$SCRIPT_DIR/claude-dispatch-live-oracle.py" extract-result "$events_file" "$result_file"
    "$PYTHON_BIN" "$SCRIPT_DIR/claude-dispatch-live-oracle.py" secret-scan "$result_file"
    cp "$result_file" "$export_dir/"
    "$PYTHON_BIN" "$SCRIPT_DIR/claude-dispatch-live-oracle.py" mutation --skill "$skill" --before "$before_file" --after "$after_file" --allow "$allow" --require "$require"
    oracle_rc=0
    "$PYTHON_BIN" "$SCRIPT_DIR/claude-dispatch-live-oracle.py" verify --events "$events_file" --result "$result_file" --prompt "$prompt_file" --skill "$skill" --plugin "$PLUGIN_NAME" --roles "$roles" --child-nonces "$child_json" --parent-nonce "$parent_nonce" || oracle_rc=$?
    rm -rf "$root"
    if [[ "$oracle_rc" == 0 ]]; then return 0; fi
    if [[ "$oracle_rc" == 75 && "$attempt" == 1 ]]; then printf 'WARNING [%s] retrying once after dispatch variance\n' "$skill" >&2; continue; fi
    return "$oracle_rc"
  done
}

run_claude_dispatch_live_tests() {
  if [[ "$RUN_DISPATCH_LIVE" != 1 ]]; then
    log "Skipping Claude internal role-dispatch live matrix"
    printf 'Run with --dispatch-live or OH_NO_DISPATCH_LIVE=1 for the bounded seven-scenario dispatch matrix.\n' >&2
    return
  fi
  [[ "$INSTALL_MODE" == 0 && "$LIVE_LOAD_MODE" == plugin-dir && -n "$ISOLATED_CONFIG_HOME" ]] || fail "Claude --dispatch-live requires --isolated-config --no-install with plugin-dir loading"
  mkdir -p "$RUN_DIR"
  log "Running minimal Claude internal role-dispatch matrix with Sonnet"
  local skill
  for skill in interview ralplan ralph verification-before-completion systematic-debugging auto-routing simplify; do
    run_claude_dispatch_live_scenario "$skill"
  done
  ok "Claude dispatch-live matrix completed (7 parents, nominal 14 total model calls)"
}

run_claude_dispatch_oracle_offline_test() {
  log "Running offline Claude dispatch-live oracle fixtures"
  "$PYTHON_BIN" "$SCRIPT_DIR/test-claude-dispatch-live-oracle.py" "$SCRIPT_DIR/claude-dispatch-live-oracle.py"
  ok "Claude dispatch oracle pins role sequence, terminal correlation, nonce, ordering, zero-child, mutation, secret, and containment gates"
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
  [[ "$(grep -Ec '^[[:space:]]*append_live_plugin_dir_arg$' "$source")" == 2 && "$main_source" == *"validate_live_plugin_root"* ]] || { rm -rf "$temp_root"; fail "one or more model-bearing live call sites bypass the live-root selector"; }
  canonical_arg='--plugin-dir "$PLUGIN''_ROOT"'
  ! grep -Fq -- "$canonical_arg" "$source" && declare -f append_live_plugin_dir_arg | grep -Fq 'LIVE_PLUGIN_ROOT' || { rm -rf "$temp_root"; fail "canonical plugin root leaked into direct live plugin-dir routing"; }
  declare -f validate_manifests | grep -Fq 'PLUGIN_ROOT' && ! declare -f validate_manifests | grep -Fq 'LIVE_PLUGIN_ROOT' || { rm -rf "$temp_root"; fail "source validation was rebound from the canonical plugin root"; }
  for case_spec in relative "$missing" "$malformed" "$live:install"; do
    rm -f "$launch"; rc=0; root="${case_spec%:install}"; args=(--isolated-config --no-install --live); [[ "$case_spec" == *:install ]] && args=(--isolated-config --live)
    ( OH_NO_LIVE_PLUGIN_ROOT="$root" CLAUDE_BIN="$fake" FAKE_LAUNCH_LOG="$launch" "$driver" "${args[@]}" ) >/dev/null 2>&1 || rc=$?
    [[ "$rc" == 1 && ! -e "$launch" ]] || { rm -rf "$temp_root"; fail "invalid/install-mode live-root case launched an executable: $case_spec"; }
  done
  rm -rf "$temp_root"
  ok "live-only plugin root: canonical validation, all live argv, defaults, shape, and install guard verified"
}

run_claude_state_isolation_offline_test() (
  log "Running offline Claude process state-isolation canary"
  local temp_root synthetic_home home_state fake records rejected_records rejected_config driver canonical_plugin canonical_marketplace live_plugin interview_prompt prompt actual_before home_before source_marker success_config failure_config cleanup_cmd rc
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-claude-state-canary.XXXXXX")"; printf -v cleanup_cmd 'rm -rf -- %q' "$temp_root"; trap "$cleanup_cmd" EXIT
  synthetic_home="$temp_root/home"; home_state="$synthetic_home/.claude.json"; mkdir -p "$synthetic_home"; printf 'synthetic home sentinel\n' >"$home_state"
  actual_before="$(file_identity "$HOME/.claude.json")"; home_before="$(file_identity "$home_state")"
  fake="$temp_root/fake-claude.py"; records="$temp_root/records.jsonl"; rejected_records="$temp_root/rejected.jsonl"; rejected_config="$temp_root/rejected-config"; driver="$REPO_ROOT/scripts/test-claude-plugin.sh"
  canonical_plugin="$PLUGIN_ROOT"; canonical_marketplace="$MARKETPLACE_ROOT"; live_plugin="$LIVE_PLUGIN_ROOT"; interview_prompt="$(direct_prompt_for_skill interview)"
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
    print(json.dumps({"type":"result","is_error":False,"result":"Skill: interview\nInvariant: clarify-before-planning","total_cost_usd":0}))
    raise SystemExit(0)
raise SystemExit(97)
PY
  chmod +x "$fake"
  export FAKE_CLAUDE_LOG="$records" FAKE_VALIDATE_PLUGIN="$canonical_plugin/.claude-plugin/plugin.json" FAKE_VALIDATE_MARKETPLACE="$canonical_marketplace/.claude-plugin/marketplace.json" FAKE_LIVE_PLUGIN_ROOT="$live_plugin" FAKE_INTERVIEW_PROMPT="$interview_prompt"
  source_marker="$temp_root/source-only-observed"; rc=0
  ( export CLAUDE_BIN="$temp_root/missing-claude"; set --; source "$driver"; printf 'observed\n' >"$source_marker" ) >/dev/null 2>&1 || rc=$?
  [[ "$rc" == 0 && -s "$source_marker" ]] || fail "Claude state-isolation same-file source re-entered the driver (rc=$rc)"
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
  rc=0; ( unset CLAUDE_CONFIG_DIR OH_NO_CONFIG_DIR OH_NO_ALLOW_REAL_CLAUDE_CONFIG_LIVE; HOME="$live_home" CLAUDE_BIN="$fake_live" FAKE_LIVE_LOG="$launch_log" "$REPO_ROOT/scripts/test-claude-plugin.sh" --no-install --live ) >/dev/null 2>"$temp_root/live.err" || rc=$?
  [[ "$rc" == 1 && ! -e "$launch_log" && "$live_before" == "$(shasum -a 256 "$live_registry")" && "$live_mtime" == "$("$PYTHON_BIN" -c 'import os,sys; print(os.stat(sys.argv[1]).st_mtime_ns)' "$live_registry")" ]] || { rm -rf "$temp_root"; fail "real-default-config plugin-dir live path launched before the fail-closed guard"; }
  grep -Fq "ordinary Claude startup plugin sync" "$temp_root/live.err" || { rm -rf "$temp_root"; fail "real-config live guard omitted the startup-sync risk"; }
  for s in RUN_LIVE; do
    rc=0; ( unset CLAUDE_CONFIG_DIR OH_NO_ALLOW_REAL_CLAUDE_CONFIG_LIVE; HOME="$live_home"; RUN_LIVE=0; printf -v "$s" 1; LIVE_LOAD_MODE=plugin-dir; guard_real_claude_config_live ) 2>/dev/null || rc=$?
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
# Offline release-safety contract: the four publication hazards the release
# helper must fail closed on. Uses throwaway Git repos plus fake npm/gh
# commands only; never touches a real remote, registry, or GitHub Release.
run_release_safety_offline_test() {
  log "Running offline release-safety contract regression"
  local temp_root repo repo2 bare rc out err staged
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/oh-no-release-safety.XXXXXX")"
  die() { rm -rf "$temp_root"; fail "$*"; }
  repo="$temp_root/repo"
  repo2="$temp_root/resume-repo"
  bare="$temp_root/origin.git"
  out="$temp_root/out"; err="$temp_root/err"

  git init -q "$repo"
  mkdir -p "$repo/plugins/oh-no-harness/.claude-plugin" "$repo/plugins/oh-no-harness/.codex-plugin"
  printf '{\n  "version": "1.0.0"\n}\n' >"$repo/plugins/oh-no-harness/.claude-plugin/plugin.json"
  printf '{\n  "version": "1.0.0"\n}\n' >"$repo/plugins/oh-no-harness/.codex-plugin/plugin.json"
  printf '{\n  "version": "1.0.0"\n}\n' >"$repo/plugins/oh-no-harness/package.json"
  printf 'docs\n' >"$repo/plugins/oh-no-harness/README.md"
  printf 'plugins/oh-no-harness/ignored.txt\n' >"$repo/.gitignore"
  git -C "$repo" add -A
  git -C "$repo" -c user.email=t@example.com -c user.name=t commit -qm init
  git -C "$repo" remote add origin https://github.com/jcwleo/oh-no-harness.git

  # ---- (1) untracked plugin content rejection + exact release staging ------
  ( source "$REPO_ROOT/scripts/release"; declare -F assert_no_untracked_plugin_content >/dev/null ) \
    || die "release does not expose assert_no_untracked_plugin_content"
  printf 'stray\n' >"$repo/plugins/oh-no-harness/stray.json"
  rc=0
  ( cd "$repo"; source "$REPO_ROOT/scripts/release"; assert_no_untracked_plugin_content ) >/dev/null 2>&1 || rc=$?
  [[ "$rc" != "0" ]] || die "release accepted untracked content under the plugin root"
  rm -f "$repo/plugins/oh-no-harness/stray.json"
  printf 'ignored\n' >"$repo/plugins/oh-no-harness/ignored.txt"
  rc=0
  ( cd "$repo"; source "$REPO_ROOT/scripts/release"; assert_no_untracked_plugin_content ) >/dev/null 2>&1 || rc=$?
  [[ "$rc" == "0" ]] || die "release rejected an ignored untracked plugin path (rc=$rc)"

  ( source "$REPO_ROOT/scripts/release"; declare -F stage_release_version_files >/dev/null ) \
    || die "release does not expose stage_release_version_files"
  printf '{\n  "version": "1.0.1"\n}\n' >"$repo/plugins/oh-no-harness/.claude-plugin/plugin.json"
  printf '{\n  "version": "1.0.1"\n}\n' >"$repo/plugins/oh-no-harness/.codex-plugin/plugin.json"
  printf '{\n  "version": "1.0.1"\n}\n' >"$repo/plugins/oh-no-harness/package.json"
  printf 'unrelated edit\n' >"$repo/plugins/oh-no-harness/README.md"
  ( cd "$repo"; source "$REPO_ROOT/scripts/release"; stage_release_version_files ) >/dev/null 2>&1 \
    || die "stage_release_version_files failed on a valid version bump"
  staged="$(git -C "$repo" diff --cached --name-only | sort | tr '\n' ' ')"
  [[ "$staged" == "plugins/oh-no-harness/.claude-plugin/plugin.json plugins/oh-no-harness/.codex-plugin/plugin.json plugins/oh-no-harness/package.json " ]] \
    || die "release staged unexpected paths: $staged"
  git -C "$repo" reset -q --hard
  rm -f "$repo/plugins/oh-no-harness/ignored.txt"

  # ---- (2) exact-tarball publish + registry integrity postflight ----------
  local fake_bin="$temp_root/bin" npm_log="$temp_root/npm.log" tarball="$temp_root/oh-no-harness-1.0.0.tgz"
  mkdir -p "$fake_bin"
  printf 'tarball\n' >"$tarball"
  cat >"$fake_bin/npm" <<'FAKE_NPM'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_NPM_LOG"
case "$1" in
  view) [[ -f "$FAKE_NPM_STATE" ]] && cat "$FAKE_NPM_STATE" ;;
  publish) printf '%s\n' "$FAKE_NPM_REGISTRY_INTEGRITY" >"$FAKE_NPM_STATE" ;;
esac
exit 0
FAKE_NPM
  chmod +x "$fake_bin/npm"

  : >"$npm_log"
  rc=0
  (
    export FAKE_NPM_LOG="$npm_log" FAKE_NPM_STATE="$temp_root/npm-state-a" FAKE_NPM_REGISTRY_INTEGRITY="sha512-LOCAL"
    NPM_BIN="$fake_bin/npm"
    source "$REPO_ROOT/scripts/release"
    NPM_BIN="$fake_bin/npm"
    publish_npm_package "oh-no-harness@1.0.0" "$tarball" "sha512-LOCAL"
  ) >/dev/null 2>&1 || rc=$?
  [[ "$rc" == "0" ]] || die "publish of a matching exact tarball failed (rc=$rc)"
  grep -Fq "publish $tarball --access public" "$npm_log" \
    || die "release did not publish the exact packed tarball: $(cat "$npm_log")"

  : >"$npm_log"
  rc=0
  (
    export FAKE_NPM_LOG="$npm_log" FAKE_NPM_STATE="$temp_root/npm-state-b" FAKE_NPM_REGISTRY_INTEGRITY="sha512-DIVERGENT"
    NPM_BIN="$fake_bin/npm"
    source "$REPO_ROOT/scripts/release"
    NPM_BIN="$fake_bin/npm"
    publish_npm_package "oh-no-harness@1.0.0" "$tarball" "sha512-LOCAL"
  ) >/dev/null 2>&1 || rc=$?
  [[ "$rc" != "0" ]] || die "release accepted a registry integrity that differs from the published tarball"

  # ---- (3) GitHub prerequisites fail closed before any side effect --------
  local gh_log="$temp_root/gh.log"
  cat >"$fake_bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_GH_LOG"
case "$1 $2" in
  "auth status")
    if [[ "$FAKE_GH_MODE" == "auth-fail" ]]; then
      printf 'Token: ghp_s3cr3ttoken\n'
      printf 'not logged in\n' >&2
      exit 1
    fi
    printf 'Logged in\n'
    ;;
  "repo view")
    [[ "$FAKE_GH_MODE" == "wrong-repo" ]] && { printf 'someone/else\n'; exit 0; }
    printf 'jcwleo/oh-no-harness\n'
    ;;
  "release view")
    [[ "$FAKE_GH_MODE" == "release-exists" ]] && { printf 'v1.0.1\n'; exit 0; }
    printf 'release not found\n' >&2
    exit 1
    ;;
esac
exit 0
FAKE_GH
  chmod +x "$fake_bin/gh"

  ( source "$REPO_ROOT/scripts/release"; declare -F preflight_github_release >/dev/null ) \
    || die "release does not expose preflight_github_release"

  local mode
  for mode in auth-fail wrong-repo release-exists; do
    : >"$gh_log"
    rc=0
    (
      cd "$repo"
      export FAKE_GH_LOG="$gh_log" FAKE_GH_MODE="$mode" PATH="$fake_bin:$PATH"
      source "$REPO_ROOT/scripts/release"
      preflight_github_release "v1.0.1"
    ) >"$out" 2>"$err" || rc=$?
    [[ "$rc" != "0" ]] || die "GitHub preflight accepted mode '$mode'"
    grep -q "release create" "$gh_log" && die "GitHub preflight created a release in mode '$mode'"
    grep -Fq "ghp_s3cr3ttoken" "$out" "$err" && die "GitHub preflight leaked credential output in mode '$mode'"
  done

  : >"$gh_log"
  rc=0
  (
    cd "$repo"
    export FAKE_GH_LOG="$gh_log" FAKE_GH_MODE="ok" PATH="$fake_bin:$PATH"
    source "$REPO_ROOT/scripts/release"
    preflight_github_release "v1.0.1"
  ) >/dev/null 2>&1 || rc=$?
  [[ "$rc" == "0" ]] || die "GitHub preflight rejected a healthy authenticated repository (rc=$rc)"

  rc=0
  (
    cd "$repo"
    export FAKE_GH_LOG="$gh_log" FAKE_GH_MODE="ok" PATH="$temp_root/empty-bin:$PATH"
    mkdir -p "$temp_root/empty-bin"
    unalias gh 2>/dev/null || true
    PATH="$temp_root/empty-bin:/usr/bin:/bin"
    source "$REPO_ROOT/scripts/release"
    preflight_github_release "v1.0.1"
  ) >/dev/null 2>&1 || rc=$?
  [[ "$rc" != "0" ]] || die "GitHub preflight passed without a gh executable"

  # ---- (4) matching annotated-tag forward completion only -----------------
  ( source "$REPO_ROOT/scripts/release"; declare -F release_forward_completion_ready >/dev/null ) \
    || die "release does not expose release_forward_completion_ready"
  git init -q --bare "$bare"
  git init -q -b main "$repo2"
  printf 'one\n' >"$repo2/file.txt"
  git -C "$repo2" add -A
  git -C "$repo2" -c user.email=t@example.com -c user.name=t commit -qm one
  printf 'two\n' >>"$repo2/file.txt"
  git -C "$repo2" add -A
  git -C "$repo2" -c user.email=t@example.com -c user.name=t commit -qm two
  git -C "$repo2" remote add origin "$bare"
  git -C "$repo2" push -q origin main
  git -C "$repo2" tag v1.0.0                                  # lightweight at HEAD
  git -C "$repo2" -c user.email=t@example.com -c user.name=t tag -a v1.0.1 -m v1.0.1   # annotated, local only
  git -C "$repo2" -c user.email=t@example.com -c user.name=t tag -a v1.0.2 -m v1.0.2   # annotated at HEAD, pushed
  git -C "$repo2" -c user.email=t@example.com -c user.name=t tag -a v1.0.3 -m v1.0.3 HEAD~1  # annotated, older commit
  git -C "$repo2" push -q origin v1.0.0 v1.0.2 v1.0.3

  local tag_case
  for tag_case in "v0.9.9=1" "v1.0.0=1" "v1.0.1=1" "v1.0.3=1" "v1.0.2=0"; do
    rc=0
    (
      cd "$repo2"
      source "$REPO_ROOT/scripts/release"
      release_forward_completion_ready "${tag_case%=*}"
    ) >/dev/null 2>&1 || rc=$?
    if [[ "${tag_case##*=}" == "0" ]]; then
      [[ "$rc" == "0" ]] || die "forward completion rejected a matching annotated tag ${tag_case%=*} (rc=$rc)"
    else
      [[ "$rc" != "0" ]] || die "forward completion accepted unsafe tag state ${tag_case%=*}"
    fi
  done

  rm -rf "$temp_root"
  unset -f die
  ok "release safety: untracked/staging, exact-tarball publish integrity, GitHub preflight, and tag forward completion verified"
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
  run_live_timeout_offline_test; run_direct_smoke_classifier_offline_test; run_claude_dispatch_oracle_offline_test
  run_escape_net_offline_test; run_active_stale_scan_reader_offline_test
  run_configure_subagents_offline_test; run_script_resolver_offline_test
  run_live_plugin_root_offline_test; run_marketplace_isolation_offline_test; run_claude_state_isolation_offline_test
  run_release_safety_offline_test
  validate_frontmatter; install_or_update_plugin
  run_live_tests; run_claude_dispatch_live_tests
  log "All requested checks passed"
}
if [[ "${BASH_SOURCE[0]}" == "${0}" && "${#BASH_SOURCE[@]}" -eq 1 ]]; then main "$@"; fi
