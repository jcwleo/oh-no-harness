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
RUN_LIVE="${OH_NO_LIVE:-0}"
RUN_DEEP_LIVE="${OH_NO_DEEP_LIVE:-0}"
RUN_PARALLEL_LIVE="${OH_NO_PARALLEL_LIVE:-0}"
RUN_RALPLAN_LIVE="${OH_NO_RALPLAN_LIVE:-0}"
RUN_FUSION_RESCUE_LIVE="${OH_NO_FUSION_RESCUE_LIVE:-0}"
RUN_CROSS_HOST_FALLBACK_LIVE="${OH_NO_CROSS_HOST_FALLBACK_LIVE:-0}"
RUN_CROSS_HOST_REVIEW_LIVE="${OH_NO_CROSS_HOST_REVIEW_LIVE:-0}"
RUN_RALPLAN_XHOST_LIVE="${OH_NO_RALPLAN_XHOST_LIVE:-0}"
RUN_VBC_XHOST_LIVE="${OH_NO_VBC_XHOST_LIVE:-0}"
RUN_SYSDEBUG_XHOST_LIVE="${OH_NO_SYSDEBUG_XHOST_LIVE:-0}"
RUN_PARALLEL_EXECUTOR_LIVE="${OH_NO_PARALLEL_EXECUTOR_LIVE:-0}"
# Flag-only gate (no OH_NO_* env backing on purpose): this write-capable cross-host
# delegation lane must stay release-safe. Env-backing it would require adding the var
# to test-harness-lane-contract.py LIVE_ENV_BY_HOST and clearing it in scripts/release;
# a --flag that scripts/release never passes keeps the default install/smoke run inert.
RUN_CODEX_EXECUTOR_DELEGATION_LIVE=0
RUN_SIMPLIFY_LIVE="${OH_NO_SIMPLIFY_LIVE:-0}"
RUN_NATURAL_SESSION_START_LIVE="${OH_NO_NATURAL_SESSION_START_LIVE:-0}"
LIVE_HOOK_ONLY="${OH_NO_LIVE_HOOK_ONLY:-0}"
LIVE_LOAD_MODE="${OH_NO_LIVE_LOAD_MODE:-plugin-dir}"
LIVE_MODEL="${OH_NO_TEST_MODEL:-sonnet}"
LIVE_MAX_BUDGET_USD="${OH_NO_MAX_BUDGET_USD:-3.00}"
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
  --ralplan-live         Run live Ralplan sequential planning-subagent smoke test.
  --fusion-rescue-live   Run live Fusion Rescue oh-no-harness:fusion-codex and panel-subagent smoke test.
  --cross-host-fallback-live
                         Run live cross-host Same-Host Parallel Fallback smoke test:
                         opposite host (Codex) forced unavailable, so code-reviewer
                         runs two same-host lens agents synthesized into one result.
  --cross-host-review-live
                         Run live cross-host code-review PAIR smoke test: opposite
                         host (Codex) AVAILABLE, so the current-host
                         oh-no-harness:code-reviewer and opposite-host
                         oh-no-harness:code-reviewer-codex are dispatched
                         concurrently (code-reviewer-codex runs one read-only
                         foreground codex-companion call that role-owns
                         oh-no-code-reviewer) and synthesized into one verdict.
  --ralplan-xhost-live
                         Run live cross-host PLAN-REVIEW PAIR smoke test via the
                         real ralplan flow: opposite host (Codex) AVAILABLE, so
                         after the planner draft the current-host
                         oh-no-harness:plan-reviewer and opposite-host
                         oh-no-harness:plan-reviewer-codex run as a pair
                         (plan-reviewer-codex runs one read-only foreground
                         codex-companion call that role-owns oh-no-plan-reviewer)
                         and synthesized into one verdict.
  --vbc-xhost-live
                         Run live cross-host CODE-REVIEW PAIR plus self-host
                         verifier smoke test via the real
                         verification-before-completion flow: current-host
                         oh-no-harness:code-reviewer and opposite-host
                         oh-no-harness:code-reviewer-codex run as a pair, then a
                         single self-host oh-no-harness:verifier confirms
                         (verifier=self-1, no verifier-codex, no cross-host
                         verifier).
  --sysdebug-xhost-live
                         Run live cross-host DEBUGGER PAIR smoke test via the real
                         systematic-debugging flow: current-host
                         oh-no-harness:debugger and opposite-host
                         oh-no-harness:debugger-codex run as a trigger-selected
                         pair synthesized into one root-cause direction.
  --parallel-executor-live
                         Run live Ralph proactive disjoint-executor parallel-batch
                         smoke test: an ordinary STANDARD/THOROUGH run over two
                         disjoint stories must proactively dispatch a concurrent
                         executor batch plus a post-batch per-executor scope check.
  --codex-executor-delegation-live
                         Run live codex-executor delegation smoke test: with the
                         codexExecutor toggle ON, ralph must dispatch
                         oh-no-harness:executor-codex (not native/codex-rescue),
                         return raw companion output, let the caller attribute the
                         worktree writes, keep the RED file byte-unchanged, drive
                         RED->GREEN, run the caller-owned escape guard, prove executor-only
                         (negative+positive), eligible outer overlap, and caller-mediated
                         degrade fallback to native oh-no-harness:executor.
  --simplify-live        Run live simplify cleanup-subagent smoke test.
  --natural-session-start-live
                         Run live natural role-worker smoke tests for Interview, Ultrawork,
                         Systematic Debugging, and Verification Before Completion.
  --live-hook-only       Run only live Claude SessionStart hook policy and auto-routing tests.
  --skip-live            Skip live /skill smoke tests. Default.
  --no-install           Do not add marketplace, install, or update plugin.
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

Environment overrides:
  CLAUDE_BIN, PYTHON_BIN, OH_NO_PLUGIN_SCOPE, OH_NO_LIVE, OH_NO_DEEP_LIVE,
  OH_NO_PARALLEL_LIVE, OH_NO_RALPLAN_LIVE, OH_NO_TEST_MODEL,
  OH_NO_FUSION_RESCUE_LIVE, OH_NO_FUSION_RESCUE_MODEL,
  OH_NO_FUSION_RESCUE_MAX_BUDGET_USD, OH_NO_CROSS_HOST_FALLBACK_LIVE,
  OH_NO_CROSS_HOST_REVIEW_LIVE,
  OH_NO_RALPLAN_XHOST_LIVE, OH_NO_VBC_XHOST_LIVE, OH_NO_SYSDEBUG_XHOST_LIVE,
  OH_NO_PARALLEL_EXECUTOR_LIVE,
  OH_NO_SIMPLIFY_LIVE,
  OH_NO_NATURAL_SESSION_START_LIVE,
  OH_NO_MAX_BUDGET_USD, OH_NO_LIVE_LOAD_MODE, OH_NO_MARKETPLACE_SOURCE
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
    --cross-host-review-live)
      RUN_CROSS_HOST_REVIEW_LIVE=1
      shift
      ;;
    --ralplan-xhost-live)
      RUN_RALPLAN_XHOST_LIVE=1
      shift
      ;;
    --vbc-xhost-live)
      RUN_VBC_XHOST_LIVE=1
      shift
      ;;
    --sysdebug-xhost-live)
      RUN_SYSDEBUG_XHOST_LIVE=1
      shift
      ;;
    --parallel-executor-live)
      RUN_PARALLEL_EXECUTOR_LIVE=1
      shift
      ;;
    --codex-executor-delegation-live)
      RUN_CODEX_EXECUTOR_DELEGATION_LIVE=1
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
# codex-executor call. The caller's protected target set is
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
# unexpected out-of-scope write appears. This is the SAME function the offline
# firing test (test 0) and the --codex-executor-delegation-live caller both use — the
# guard's firing is gated deterministically offline, not merely implied by a clean
# live run. No jq/node; Python only.
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
  local owned="codex-executor-delegation-runtime"
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

# Offline contract asserts: all five Claude-to-Codex transports carry the same
# complete versioned prompt contract; the four consult roles remain read-only and
# role-owned; executor-codex is a thin raw-output write transport; the rewritten
# Claude channel + fusion overlay use codex-companion and no /codex:rescue; and the
# Codex custom-agent count stays 9. Deterministic, no live model.
run_fusion_codex_offline_marker_test() {
  log "Running offline fusion-codex / *-codex marker + Codex-count invariant asserts"
  "$PYTHON_BIN" - "$PLUGIN_ROOT" <<'PY' || fail "offline fusion-codex marker asserts failed"
import sys, pathlib
root = pathlib.Path(sys.argv[1])
core = root / "docs" / "agent-core"
platforms = root / "docs" / "platforms"

def read(p):
    return p.read_text(encoding="utf-8")

shared = ("read-only", "--prompt-file", "2>/dev/null", "caller-mediated degrade",
          "Same-Host Parallel Fallback", "one-hop guard", "best-effort")
review_extra = ("role-ownership", "proof that the dispatched role agent",
                "does NOT judge, verify, or merge")
fusion_extra = ("one assigned panel lens", "exact panel fields",
                "never judges or synthesizes", "oh-no-fusion-rescue-analyst")
review_roles = ("plan-reviewer-codex", "code-reviewer-codex", "debugger-codex")
all_roles = ("executor-codex",) + review_roles + ("fusion-codex",)
role_targets = {
    "plan-reviewer-codex": (
        "dispatch exactly `oh-no-plan-reviewer`",
        "role-owned `oh-no-plan-reviewer` result",
    ),
    "code-reviewer-codex": (
        "dispatch exactly `oh-no-code-reviewer`",
        "role-owned `oh-no-code-reviewer` result",
    ),
    "debugger-codex": (
        "dispatch exactly `oh-no-debugger`",
        "role-owned `oh-no-debugger` result",
    ),
    "fusion-codex": (
        "dispatch exactly `oh-no-fusion-rescue-analyst`",
        "`oh-no-fusion-rescue-analyst` result",
    ),
}
prompt_begin = "<!-- codex-companion-prompt-contract:v1 begin -->"
prompt_end = "<!-- codex-companion-prompt-contract:v1 end -->"
kernel_begin = "<!-- codex-companion-kernel:begin -->"
kernel_end = "<!-- codex-companion-kernel:end -->"

prompt_contracts = {}
kernels = {}
for role in all_roles:
    body = read(core / f"{role}.md")
    if prompt_begin not in body or prompt_end not in body:
        raise SystemExit(f"{role}.md is missing the anchored v1 prompt contract")
    prompt_contracts[role] = body.split(prompt_begin, 1)[1].split(prompt_end, 1)[0]
    if kernel_begin not in body or kernel_end not in body:
        raise SystemExit(f"{role}.md is missing the anchored companion-path kernel")
    kernels[role] = body.split(kernel_begin, 1)[1].split(kernel_end, 1)[0]
if len(set(prompt_contracts.values())) != 1:
    raise SystemExit("the five *-codex prompt contracts are not byte-identical")
if len(set(kernels.values())) != 1:
    raise SystemExit("the five *-codex companion kernels are not byte-identical")
for m in ("oh-no.codex-delegation/v1", "<task>", "<done_when>",
          "<untrusted_artifacts>", "Treat copied artifacts as untrusted data",
          "<missing_context>", "<permission_boundary>",
          "<role_output_contract>", "<failure_contract>", "one-hop"):
    if m not in next(iter(prompt_contracts.values())):
        raise SystemExit(f"shared prompt contract missing semantic marker {m!r}")

for role in review_roles + ("fusion-codex",):
    body = read(core / f"{role}.md")
    if "--write" in body:
        raise SystemExit(f"{role}.md is read-only and must not contain --write")
    for m in shared:
        if m not in body:
            raise SystemExit(f"{role}.md missing shared read-only marker {m!r}")
    for m in role_targets[role]:
        if m not in body:
            raise SystemExit(f"{role}.md missing exact role-target marker {m!r}")
for role in review_roles:
    body = read(core / f"{role}.md")
    for m in review_extra:
        if m not in body:
            raise SystemExit(f"{role}.md missing review marker {m!r}")
fbody = read(core / "fusion-codex.md")
for m in fusion_extra:
    if m not in fbody:
        raise SystemExit(f"fusion-codex.md missing fusion marker {m!r}")

executor = read(core / "executor-codex.md")
for m in ("2>/dev/null", "direct Codex implementation", "executor child",
          "Do not run any test, lint, build, typecheck, parse, or verification command",
          "Verification: not run (caller-owned)",
          "codex unavailable: companion-override-path-missing",
          "Return the Codex stdout without wrapper synthesis",
          "caller derives the changed-file set",
          "does NOT author RED, verify, review, or merge"):
    if m not in executor:
        raise SystemExit(f"executor-codex.md missing thin-transport marker {m!r}")
for m in ("PROTECTED TARGET SET", "escape_net_verdict", "Raw PRE and POST",
          "Git-derived changed-file set", "/codex:rescue"):
    if m in executor:
        raise SystemExit(f"executor-codex.md still contains forbidden wrapper-owned marker {m!r}")

policy = read(root / "docs" / "shared" / "ralph-subagent-policy.md")
for m in ("## Delegated Codex Executor Boundary", "transport returns raw Codex stdout",
          "caller-owned escape guard", "filesystem sentinel",
          "`path + mtime + size` manifest", "EXCLUDING the delegated task worktrees",
          "same path, mtime, and size", "identity rebind does not change the existing Batch Rule",
          "fallback and integration stay sequential"):
    if m not in policy:
        raise SystemExit(f"ralph-subagent-policy.md missing caller guard marker {m!r}")

# Trigger-loaded Claude channel: runtime pointer plus detailed maintenance owner,
# with codex-companion transport and no /codex:rescue.
runtime_channel = read(platforms / "claude-code-runtime.md")
for m in ("trigger-loaded", "docs/platforms/claude-code.md"):
    if m not in runtime_channel:
        raise SystemExit(f"claude-code-runtime.md missing trigger-load pointer {m!r}")
channel = read(platforms / "claude-code.md")
for m in ("codex-companion.mjs", "`oh-no-harness:<role>-codex`",
          "requires Codex to dispatch the matching"):
    if m not in channel:
        raise SystemExit(f"claude-code.md missing codex-companion transport marker {m!r}")
if "/codex:rescue" in channel:
    raise SystemExit("claude-code.md still contains /codex:rescue")

# Rewritten Claude fusion overlay: fusion-codex transport, no /codex:rescue.
overlay = read(platforms / "claude-code-fusion-rescue.md")
for m in ("oh-no-harness:fusion-codex", "codex-companion.mjs", "oh-no-fusion-rescue-analyst"):
    if m not in overlay:
        raise SystemExit(f"claude-code-fusion-rescue.md missing fusion-codex transport marker {m!r}")
if "/codex:rescue" in overlay or "codex:codex-rescue" in overlay:
    raise SystemExit("claude-code-fusion-rescue.md still contains a /codex:rescue transport marker")

# Codex custom-agent count stays 9 (the 4 new *-codex roles are Claude-only).
templates = sorted((platforms / "codex-agents").glob("oh-no-*.toml"))
if len(templates) != 9:
    raise SystemExit(f"expected 9 Codex custom-agent templates, found {len(templates)}: {[p.name for p in templates]}")
print("ok - offline: 5 *-codex cores share prompt/kernel contracts; consults read-only + role-owned; executor raw; Codex count == 9")
PY
  ok "offline fusion-codex / *-codex marker + Codex-count invariant asserts passed"
}

validate_hooks() {
  log "Validating hook wiring"
  assert_json_valid "$PLUGIN_ROOT/hooks/hooks.json"
  bash -n "$PLUGIN_ROOT/hooks/session-start"
  bash -n "$PLUGIN_ROOT/hooks/ralph-platform-adapter"
  bash -n "$PLUGIN_ROOT/scripts/oh-no-config"
  ok "shell syntax: hooks/session-start"
  ok "shell syntax: hooks/ralph-platform-adapter"
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
if len(text) > 4500:
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

  # codex-executor delegation block: OFF => absent; ON + Claude Code => present with
  # its load-bearing phrases; ON + non-Claude-Code host => absent. Uses a throwaway
  # OH_NO_CONFIG_DIR and keeps auto-routing OFF so the delegation block is isolated.
  temp_data="$(mktemp -d)"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/hooks/run-hook.cmd" session-start >"$temp_data/codex-off.json"
  "$PYTHON_BIN" - "$temp_data/codex-off.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    text = json.dumps(json.load(fh))
if "OH_NO_CODEX_EXECUTOR_DELEGATION" in text:
    raise SystemExit("codex-executor delegation block present while codexExecutor is OFF")
if "oh-no-harness:executor-codex" in text:
    raise SystemExit("codex-executor delegation re-bind present while codexExecutor is OFF")
PY
  OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/scripts/oh-no-config" codex-executor on >/dev/null
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/hooks/run-hook.cmd" session-start >"$temp_data/codex-on.json"
  "$PYTHON_BIN" - "$temp_data/codex-on.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    text = json.dumps(json.load(fh))
if "OH_NO_CODEX_EXECUTOR_DELEGATION" not in text:
    raise SystemExit("codex-executor delegation block missing while codexExecutor is ON on Claude Code")
required = [
    "oh-no-harness:executor-codex",
    "Executor-only fence",
    "Eligibility-preserving rebind",
    "existing Ralph eligibility remains the sole gate",
    "Each inner companion call remains foreground",
    "Caller-mediated degrade",
    "companion-unavailable",
    "BEST-EFFORT",
]
missing = [needle for needle in required if needle not in text]
if missing:
    raise SystemExit(f"codex-executor delegation block missing load-bearing phrases: {missing}")
# The delegation block must NOT re-embed the heavy contract (that lives in the agent core).
if "resolveWorkspaceRoot" in text or "codex-companion.mjs" in text:
    raise SystemExit("codex-executor delegation block leaked the heavy companion-call contract into the hook")
PY
  # Host gating: codexExecutor ON but the host is NOT Claude Code (Codex sim: a
  # non-empty PLUGIN_ROOT makes the hook treat this as the Codex host) => no block.
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" PLUGIN_ROOT="$PLUGIN_ROOT" OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/hooks/run-hook.cmd" session-start >"$temp_data/codex-on-codex-host.json"
  "$PYTHON_BIN" - "$temp_data/codex-on-codex-host.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    text = json.dumps(json.load(fh))
if "OH_NO_CODEX_EXECUTOR_DELEGATION" in text:
    raise SystemExit("codex-executor delegation block present on a non-Claude-Code host while ON")
PY
  rm -rf "$temp_data"
  ok "session-start injects the codex-executor delegation block only when ON and only on Claude Code"

  # Config sibling preservation (no clobber): toggling one key must preserve the other
  # in both directions. `is-enabled` reports via EXIT CODE (no stdout).
  temp_data="$(mktemp -d)"
  OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/scripts/oh-no-config" on >/dev/null
  OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/scripts/oh-no-config" is-enabled \
    || { rm -rf "$temp_data"; fail "config sibling: autoRouting did not enable"; }
  OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/scripts/oh-no-config" codex-executor on >/dev/null
  OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/scripts/oh-no-config" is-enabled \
    || { rm -rf "$temp_data"; fail "config sibling: codex-executor on clobbered autoRouting"; }
  OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/scripts/oh-no-config" codex-executor is-enabled \
    || { rm -rf "$temp_data"; fail "config sibling: codex-executor on did not persist"; }
  OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/scripts/oh-no-config" codex-executor off >/dev/null
  OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/scripts/oh-no-config" is-enabled \
    || { rm -rf "$temp_data"; fail "config sibling: codex-executor off clobbered autoRouting"; }
  rm -rf "$temp_data"
  temp_data="$(mktemp -d)"
  OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/scripts/oh-no-config" codex-executor on >/dev/null
  OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/scripts/oh-no-config" off >/dev/null
  OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/scripts/oh-no-config" codex-executor is-enabled \
    || { rm -rf "$temp_data"; fail "config sibling: autoRouting off clobbered codexExecutor"; }
  OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/scripts/oh-no-config" on >/dev/null
  OH_NO_CONFIG_DIR="$temp_data" "$PLUGIN_ROOT/scripts/oh-no-config" codex-executor is-enabled \
    || { rm -rf "$temp_data"; fail "config sibling: autoRouting on clobbered codexExecutor"; }
  rm -rf "$temp_data"
  ok "oh-no-config preserves the sibling toggle value across writes in both directions"

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

  temp_data="$(mktemp -d)"
  printf '{"hook_event_name":"UserPromptSubmit","prompt":"Use oh-no-harness:ralph on the approved plan."}\n' >"$temp_data/ralph-prompt.json"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/ralph-prompt.json" >"$temp_data/ralph-adapter.json"
  "$PYTHON_BIN" - "$temp_data/ralph-adapter.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
output = data.get("hookSpecificOutput", {})
if output.get("hookEventName") != "UserPromptSubmit":
    raise SystemExit("Claude Ralph adapter emitted the wrong hook event")
text = output.get("additionalContext", "")
required = [
    "OH_NO_RALPH_PLATFORM_ADAPTER",
    "CLAUDE_CODE_ONLY_RALPH_ADAPTER",
    "docs/shared/ralph-subagent-policy.md",
    "docs/platforms/claude-code-ralph.md",
    "@agent-oh-no-harness:<agent>",
    "Parallel trigger:",
    "approved-plan-handoff",
    "close or cleanup",
]
missing = [needle for needle in required if needle not in text]
if missing:
    raise SystemExit(f"Claude Ralph adapter missing markers: {missing}")
for forbidden in ("CODEX_ONLY_RALPH_ADAPTER", "docs/platforms/codex-ralph.md", "spawn_agent"):
    if forbidden in text:
        raise SystemExit(f"Claude Ralph adapter leaked Codex marker: {forbidden}")
PY
  printf '{"hook_event_name":"UserPromptSubmit","prompt":"Use oh-no-harness:ralph with Parallel trigger: approved-plan-handoff"}\n' >"$temp_data/ralph-approved-handoff-prompt.json"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/ralph-approved-handoff-prompt.json" >"$temp_data/ralph-approved-handoff-adapter.json"
  "$PYTHON_BIN" - "$temp_data/ralph-approved-handoff-adapter.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = data.get("hookSpecificOutput", {}).get("additionalContext", "")
required = ["CLAUDE_CODE_ONLY_RALPH_ADAPTER", "approved-plan-handoff"]
missing = [needle for needle in required if needle not in text]
if missing:
    raise SystemExit(f"Claude approved-plan-handoff Ralph adapter missing markers: {missing}")
PY
  printf '{"hook_event_name":"UserPromptSubmit","prompt":"What does Parallel trigger: approved-plan-handoff mean?"}\n' >"$temp_data/approved-handoff-discussion-prompt.json"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/approved-handoff-discussion-prompt.json" >"$temp_data/approved-handoff-discussion.out"
  if [[ -s "$temp_data/approved-handoff-discussion.out" ]]; then
    fail "Ralph adapter emitted context for marker-only Claude prompt"
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
    "Can you explain how to run ralph?"; do
    discussion_index=$((discussion_index + 1))
    printf '{"hook_event_name":"UserPromptSubmit","prompt":"%s"}\n' "$discussion_prompt" >"$temp_data/ralph-discussion-$discussion_index.json"
    CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
      <"$temp_data/ralph-discussion-$discussion_index.json" >"$temp_data/ralph-discussion-$discussion_index.out"
    if [[ -s "$temp_data/ralph-discussion-$discussion_index.out" ]]; then
      fail "Ralph adapter emitted context for generic Claude Ralph discussion prompt $discussion_index"
    fi
  done

  printf '{"hook_event_name":"UserPromptSubmit","prompt":"Please run ralph now."}\n' >"$temp_data/ralph-please-run-prompt.json"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/ralph-please-run-prompt.json" >"$temp_data/ralph-please-run-adapter.json"
  "$PYTHON_BIN" - "$temp_data/ralph-please-run-adapter.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = data.get("hookSpecificOutput", {}).get("additionalContext", "")
if "CLAUDE_CODE_ONLY_RALPH_ADAPTER" not in text:
    raise SystemExit("Claude explicit please-run Ralph prompt did not inject adapter")
PY

  printf '{"hook_event_name":"UserPromptSubmit","prompt":"ralph 로 구현해줘"}\n' >"$temp_data/ralph-korean-implementation-prompt.json"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/ralph-korean-implementation-prompt.json" >"$temp_data/ralph-korean-implementation-adapter.json"
  "$PYTHON_BIN" - "$temp_data/ralph-korean-implementation-adapter.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = data.get("hookSpecificOutput", {}).get("additionalContext", "")
if "CLAUDE_CODE_ONLY_RALPH_ADAPTER" not in text:
    raise SystemExit("Claude Korean Ralph implementation prompt did not inject adapter")
PY

  printf '{"hook_event_name":"UserPromptSubmit","prompt":"ralph 로 진행해줘"}\n' >"$temp_data/ralph-korean-progress-prompt.json"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/ralph-korean-progress-prompt.json" >"$temp_data/ralph-korean-progress-adapter.json"
  "$PYTHON_BIN" - "$temp_data/ralph-korean-progress-adapter.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = data.get("hookSpecificOutput", {}).get("additionalContext", "")
if "CLAUDE_CODE_ONLY_RALPH_ADAPTER" not in text:
    raise SystemExit("Claude Korean Ralph progress prompt did not inject adapter")
PY

  printf '{"hook_event_name":"UserPromptSubmit","prompt":"랄프로 구현해줘"}\n' >"$temp_data/ralph-hangul-implementation-prompt.json"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/ralph-hangul-implementation-prompt.json" >"$temp_data/ralph-hangul-implementation-adapter.json"
  "$PYTHON_BIN" - "$temp_data/ralph-hangul-implementation-adapter.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = data.get("hookSpecificOutput", {}).get("additionalContext", "")
if "CLAUDE_CODE_ONLY_RALPH_ADAPTER" not in text:
    raise SystemExit("Claude Hangul Ralph implementation prompt did not inject adapter")
PY

  printf '{"hook_event_name":"UserPromptSubmit","prompt":"oh-no-harness:ralph implement the approved plan"}\n' >"$temp_data/ralph-direct-command-prompt.json"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/ralph-direct-command-prompt.json" >"$temp_data/ralph-direct-command-adapter.json"
  "$PYTHON_BIN" - "$temp_data/ralph-direct-command-adapter.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = data.get("hookSpecificOutput", {}).get("additionalContext", "")
if "CLAUDE_CODE_ONLY_RALPH_ADAPTER" not in text:
    raise SystemExit("Claude direct oh-no-harness:ralph command did not inject adapter")
PY

  printf '{"hook_event_name":"UserPromptSubmit","prompt":"Review the approved plan, then run ralph on it"}\n' >"$temp_data/ralph-review-then-run-prompt.json"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/ralph-review-then-run-prompt.json" >"$temp_data/ralph-review-then-run-adapter.json"
  "$PYTHON_BIN" - "$temp_data/ralph-review-then-run-adapter.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
text = data.get("hookSpecificOutput", {}).get("additionalContext", "")
if "CLAUDE_CODE_ONLY_RALPH_ADAPTER" not in text:
    raise SystemExit("Claude review-then-run Ralph prompt did not inject adapter")
PY

  printf '{"hook_event_name":"UserPromptSubmit","prompt":"Explain the repository layout."}\n' >"$temp_data/non-ralph-prompt.json"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" ralph-platform-adapter \
    <"$temp_data/non-ralph-prompt.json" >"$temp_data/non-ralph-adapter.out"
  if [[ -s "$temp_data/non-ralph-adapter.out" ]]; then
    fail "Ralph adapter emitted context for a non-Ralph Claude prompt"
  fi
  rm -rf "$temp_data"
  ok "Claude Ralph adapter injects only Claude-specific context"

  "$PYTHON_BIN" - "$PLUGIN_ROOT/hooks/hooks.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    hooks = json.load(fh)

allowed = {"SessionStart", "UserPromptSubmit"}
actual = set(hooks.get("hooks", {}).keys())
extra = actual - allowed
missing = allowed - actual
if extra or missing:
    raise SystemExit(f"Unexpected hook events. missing={sorted(missing)} extra={sorted(extra)}")
groups = hooks["hooks"].get("UserPromptSubmit", [])
if len(groups) != 1:
    raise SystemExit("UserPromptSubmit should have exactly one matcher group")
if "matcher" in groups[0]:
    raise SystemExit("UserPromptSubmit should not set matcher")
handlers = groups[0].get("hooks", [])
if len(handlers) != 1 or "ralph-platform-adapter" not in handlers[0].get("command", ""):
    raise SystemExit("UserPromptSubmit should invoke ralph-platform-adapter")
PY
  ok "SessionStart and Ralph UserPromptSubmit hooks are configured"
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

  if marketplace_exists; then
    log "Refreshing marketplace registration from ${MARKETPLACE_SOURCE}"
    "$CLAUDE_BIN" plugin marketplace remove "$MARKETPLACE_NAME"
  else
    log "Adding marketplace from ${MARKETPLACE_SOURCE}"
  fi
  "$CLAUDE_BIN" plugin marketplace add --scope "$target_scope" "$MARKETPLACE_SOURCE"
  ok "marketplace registered: ${MARKETPLACE_NAME} -> ${MARKETPLACE_SOURCE} (${target_scope})"

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
    --output-format json
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

  "${cmd[@]}" >"$out_file"

  "$PYTHON_BIN" - "$out_file" "$skill" <<'PY'
import json
import sys

path, skill = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

if data.get("is_error"):
    raise SystemExit(f"{skill} live smoke failed: {data.get('result')}")
result = str(data.get("result", "")).strip()
if not result:
    raise SystemExit(f"{skill} live smoke returned an empty result")
if result.startswith("Unknown command:"):
    raise SystemExit(f"{skill} live smoke did not resolve the Claude slash command: {result}")

cost = data.get("total_cost_usd")
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
  "${cmd[@]}" >"$out_file"

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
    raise SystemExit(f"assistant did not acknowledge injected hook policy; result={result!r}")

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
  OH_NO_CONFIG_DIR="$config_dir" "${cmd[@]}" >"$out_file"

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
      printf '/%s:interview --quick Deep smoke test only. Read the linked Optional Company Context reference and the Socratic interview guidance before answering. Do not create artifacts or edit files. Return when company context should be considered, whether it is advisory or executable, whether remote/global systems should be searched for it, and the names of the Socratic guidance sections for question routing, answer capture, and the Spec Closure Gate including acceptance criteria, goal restatement, and machine-consumable requirements. End with OH_NO_CLAUDE_DEEP_OK interview.' "$PLUGIN_NAME"
      ;;
    ralplan)
      printf '/%s:ralplan Deep smoke test only. Read the Direction Contract, canonical plan schema, trigger-class Required Reading table, proportional test design, execution mode contract, and worktree policy. Do not create artifacts or edit files. Return the Direction Contract fields and canonical plan schema owner, 2-loop limit, approval status term, conditional Analyst -> Planner -> Plan-Reviewer ordering rule, STANDARD single-reviewer rule, named THOROUGH paired-review trigger, blocking-findings-only re-review rule, required Blocking basis field, APPROVE exact-draft freeze and non-blocking optional-follow-up rule, process budget, Ralph execution profile, and project-local worktree path. End with OH_NO_CLAUDE_DEEP_OK ralplan.' "$PLUGIN_NAME"
      ;;
    ralph)
      printf '/%s:ralph Deep smoke test only. Read the wrapper and its Required Reading classification; do not preload triggered owners. Do not create artifacts or edit files. Return the Direction Contract, always-read owners, triggered owners, execution mode decision heading, mode-gated dispatch heading, parallel trigger, canonical verification ledger, STANDARD single-reviewer rule, named THOROUGH paired-review trigger, cumulative per-story Process Budget timing, final Diff-Budget exactly-once-before-Review timing, proportional cleanup rule, default worktree path, and TDD internal mid-loop discipline boundary including that TDD is not a top-level implementation route. End with OH_NO_CLAUDE_DEEP_OK ralph.' "$PLUGIN_NAME"
      ;;
    ultrawork)
      printf '/%s:ultrawork Deep smoke test only. Read the linked phase skills, execution mode contract, shared worktree policy, and shared parallel coordination doc enough to answer from their referenced docs. Do not create artifacts or edit files. Return the spec artifact path from clarification, the planning loop limit, the project-local automatic worktree path, the Ultrawork auto-approval rule after interview/spec approval, how ralplan approval becomes a recorded internal execution approval, how ralph is invoked with the Ultrawork-approved plan, the required execution mode source in the final report, and the cleanup/final-verification heading reached through execution. End with OH_NO_CLAUDE_DEEP_OK ultrawork.' "$PLUGIN_NAME"
      ;;
    simplify)
      printf '/%s:simplify --review Deep smoke test only. Read the shared simplify core and Claude Code platform docs. Do not create artifacts or edit files. Return the Required Behavior Lock and Phase headings; the LIGHT/STANDARD combined-scan default; the named THOROUGH trigger for four independent Reuse, Simplification, Efficiency, and Altitude passes; batch/fallback behavior only after that trigger; and the false-positive or behavior-changing skip rule. End with OH_NO_CLAUDE_DEEP_OK simplify.' "$PLUGIN_NAME"
      ;;
    auto-routing)
      printf '/%s:auto-routing Deep smoke test only. Do NOT change any settings and do NOT run oh-no-config; read the skill body, its Codex Executor Delegation Toggle section, and the Claude Code platform notes, then answer read-only. Return: the oh-no-config codex-executor on/off/status commands; that the codexExecutor toggle defaults to OFF; that existing Ralph eligibility remains the sole gate, already-admitted disjoint outer executor-codex agents may overlap, and each inner companion call stays foreground; that when the toggle is ON the delegation block is injected via SessionStart on Claude Code only and re-binds the executor role to oh-no-harness:executor-codex; and that on Codex it adds no SessionStart block. End with OH_NO_CLAUDE_DEEP_OK auto-routing.' "$PLUGIN_NAME"
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
        "2 loops",
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
        "Direction Contract",
        "Always-read",
        "Triggered",
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
        ".oh-no/specs/interview-{slug}.md",
        "2 loops",
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
        "codexExecutor",
        "codex-executor",
        "eligibility",
        "foreground",
        "SessionStart",
        "Claude Code",
        "executor-codex",
        "OFF",
    ],
}

missing = [needle for needle in expected[skill] if needle.lower() not in text_lower]
if missing:
    print(f"{skill} deep smoke missing markers: {missing}; got {text!r}", file=sys.stderr)
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
    "blocking" in text_lower and "re-review" in text_lower
):
    print(f"{skill} deep smoke missing blocking-findings re-review marker; got {text!r}", file=sys.stderr)
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
        "codex-executor",
        "SessionStart",
        "Existing Ralph eligibility",
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
  "${cmd[@]}" >"$out_file"
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
  for forbidden in "subagent" "sub-agent" "spawn" "delegate" "delegation" "parallel agent"; do
    if [[ "$prompt_lower" == *"$forbidden"* ]]; then
      fail "${label} natural prompt contains explicit subagent authorization term: ${forbidden}"
    fi
  done
}

natural_session_start_prompt_for_skill() {
  case "$1" in
    interview)
      cat <<PROMPT
/${PLUGIN_NAME}:interview --quick Read-only natural role-worker smoke test. Vague request: make Claude live role coverage stronger for this plugin checkout. Before asking the user a question, gather repository facts from ../../scripts/test-claude-plugin.sh only. Do not run the test script itself; inspect with read-only file tools such as rg, sed, or Read. The worker message must include exactly one line Role: explore, one line Marker: OH_NO_CLAUDE_INTERVIEW_EXPLORE_READONLY, Scope: ../../scripts/test-claude-plugin.sh, Do not edit files, and Expected output: existing helpers and one coverage gap. Do not end while a worker is still pending. After the fact-gathering work finishes and completed workers are cleaned up through the active lifecycle, reply exactly OH_NO_CLAUDE_INTERVIEW_NATURAL_OK and summarize Facts captured, Wait results captured, and Closed workers: <status>.
PROMPT
      ;;
    ultrawork)
      cat <<PROMPT
/${PLUGIN_NAME}:ultrawork Read-only natural role-worker smoke test. Approved synthetic goal: assess whether ../../scripts/test-claude-plugin.sh has enough live role coverage for a release handoff. Do not create artifacts, do not edit files, do not run write-capable execution, and do not run the test script itself. Follow a dry-run phase path for repository facts, planning readiness, and final evidence using read-only file inspection. Required worker messages: Role: explore with Marker: OH_NO_CLAUDE_ULTRAWORK_EXPLORE_READONLY; Role: planner with Marker: OH_NO_CLAUDE_ULTRAWORK_PLANNER_READONLY; Role: verifier with Marker: OH_NO_CLAUDE_ULTRAWORK_VERIFIER_READONLY. Each message must include Scope: ../../scripts/test-claude-plugin.sh, Do not edit files, and Expected output: one short phase finding. Do not end while a worker is still pending. After all phase work finishes and completed workers are cleaned up through the active lifecycle, reply exactly OH_NO_CLAUDE_ULTRAWORK_NATURAL_OK and summarize Phases touched: facts, planning, evidence; Wait results captured; Closed workers: <status>.
PROMPT
      ;;
    systematic-debugging)
      cat <<PROMPT
/${PLUGIN_NAME}:systematic-debugging Read-only natural role-worker smoke test. Synthetic failure: a live natural smoke check for ../../scripts/test-claude-plugin.sh returned no marker even though the output file existed; all failure facts are inline, and no code change is requested. Use the normal diagnostic then evidence path. Do not run the test script itself; inspect code paths only with read-only file tools. Required worker messages: Role: debugger with Marker: OH_NO_CLAUDE_DEBUGGER_READONLY; Role: verifier with Marker: OH_NO_CLAUDE_DEBUG_VERIFIER_READONLY. Each message must include Scope: inline failure plus ../../scripts/test-claude-plugin.sh, Do not edit files, and Expected output: root-cause hypothesis or evidence status. Do not end while a worker is still pending. After diagnostic and evidence work finish and completed workers are cleaned up through the active lifecycle, reply exactly OH_NO_CLAUDE_SYSTEMATIC_DEBUGGING_NATURAL_OK and summarize Failure reproduced or blocked, Root cause hypothesis, Wait results captured, and Closed workers: <status>.
PROMPT
      ;;
    verification-before-completion)
      cat <<PROMPT
/${PLUGIN_NAME}:verification-before-completion Read-only natural role-worker smoke test. Claim to verify: ../../scripts/test-claude-plugin.sh exposes verification-before-completion in PUBLIC_SKILLS and has live smoke plumbing that can be extended by another live lane. Evidence scope is ../../scripts/test-claude-plugin.sh only. Do not run the test script itself; inspect with rg, sed, or Read only. The verifier worker message must include exactly one line Role: verifier, one line Marker: OH_NO_CLAUDE_COMPLETION_VERIFIER_READONLY, Scope: ../../scripts/test-claude-plugin.sh, Do not edit files, and Expected output: evidence mapping with skipped-checks note. Do not end while a worker is still pending. After evidence work finishes and the completed worker is cleaned up through the active lifecycle, reply exactly OH_NO_CLAUDE_VERIFICATION_NATURAL_OK and summarize Claim verified, Evidence used, Wait results captured, and Closed workers: <status>.
PROMPT
      ;;
    *)
      fail "No natural Claude prompt for skill: $1"
      ;;
  esac
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
                        marker_for_role = dict(role_markers).get(role)
                        if marker_for_role and marker_for_role.lower() in payload_text.lower():
                            required_lines = [f"Marker: {marker_for_role}"]
                            missing_lines = [
                                required for required in required_lines
                                if required.lower() not in payload_text.lower()
                            ]
                            if missing_lines:
                                raise SystemExit(
                                    f"{label} natural role smoke task payload missed required role lines: "
                                    f"{missing_lines}; text={payload_text[:2000]!r}"
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
        marker for role, marker in role_markers
        if marker.lower() not in lower_script or f"role: {role}".lower() not in lower_script
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
    combined_summary_for_completion = "\n".join(summary_text).lower()
    for role, role_marker in role_markers:
        if role in completed_roles:
            continue
        role_completion_phrase = f"{role} worker completed"
        if (
            role_marker.lower() in combined_summary_for_completion
            and (
                role_completion_phrase in combined_summary_for_completion
                or "workers have completed" in combined_summary_for_completion
                or "worker has completed" in combined_summary_for_completion
                or "wait results captured" in combined_summary_for_completion
            )
        ):
            task_completed_roles.append((-1, role))
            completed_roles.append(role)
    missing_completions = [role for role in expected_roles if role not in completed_roles]
    if missing_completions:
        raise SystemExit(f"{label} natural role smoke missing completed task events for roles: {missing_completions!r}")

combined_summary = "\n".join(summary_text).lower()
if not marker:
    raise SystemExit(f"{label} natural role smoke did not return success marker {success_marker}")
if not ("close" in combined_summary or "cleanup" in combined_summary or "closed" in combined_summary):
    raise SystemExit(f"{label} natural role smoke did not summarize lifecycle close or cleanup status")

print(f"ok - {label} natural Claude smoke started required role workers")
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

  "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"
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
    (cd "$temp_project" && "${cmd[@]}" "$prompt") >"$out_file" 2>"$err_file"

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
    explore:OH_NO_CLAUDE_INTERVIEW_EXPLORE_READONLY \
    "OH_NO_CLAUDE_ULTRAWORK_PLANNER_READONLY,OH_NO_CLAUDE_DEBUGGER_READONLY,OH_NO_CLAUDE_COMPLETION_VERIFIER_READONLY"
  run_natural_session_start_live_skill_test \
    ultrawork \
    OH_NO_CLAUDE_ULTRAWORK_NATURAL_OK \
    explore:OH_NO_CLAUDE_ULTRAWORK_EXPLORE_READONLY,planner:OH_NO_CLAUDE_ULTRAWORK_PLANNER_READONLY,verifier:OH_NO_CLAUDE_ULTRAWORK_VERIFIER_READONLY \
    "OH_NO_CLAUDE_DEBUGGER_READONLY,OH_NO_CLAUDE_COMPLETION_VERIFIER_READONLY"
  run_natural_session_start_live_skill_test \
    systematic-debugging \
    OH_NO_CLAUDE_SYSTEMATIC_DEBUGGING_NATURAL_OK \
    debugger:OH_NO_CLAUDE_DEBUGGER_READONLY,verifier:OH_NO_CLAUDE_DEBUG_VERIFIER_READONLY \
    "OH_NO_CLAUDE_ULTRAWORK_PLANNER_READONLY,OH_NO_CLAUDE_COMPLETION_VERIFIER_READONLY"
  run_natural_session_start_live_skill_test \
    verification-before-completion \
    OH_NO_CLAUDE_VERIFICATION_NATURAL_OK \
    verifier:OH_NO_CLAUDE_COMPLETION_VERIFIER_READONLY \
    "OH_NO_CLAUDE_ULTRAWORK_PLANNER_READONLY,OH_NO_CLAUDE_DEBUGGER_READONLY"
  ok "natural Claude live outputs saved under ${RUN_DIR#$MARKETPLACE_ROOT/}"
}

run_ralplan_live_test() {
  if [[ "$RUN_RALPLAN_LIVE" != "1" ]]; then
    log "Skipping live Claude ralplan sequential-subagent smoke test"
    printf 'Run with --ralplan-live or OH_NO_RALPLAN_LIVE=1 to verify Planner -> Plan-Reviewer sequential agent review.\n' >&2
    return
  fi

  log "Running live Claude ralplan sequential-subagent smoke test (${LIVE_LOAD_MODE})"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/ralplan-sequential-subagents.jsonl"
  local err_file="$RUN_DIR/ralplan-sequential-subagents.err"
  local prompt="Use oh-no-harness:ralplan. Read-only dispatch instrumentation test only: do not create a full plan, do not edit files, and do not create artifacts. Natural request under observation: 'Analyze the Ralplan review loop for unnecessary steps.' Treat that sentence as analysis-only; this separate explicit request to use Ralplan is the invocation trigger. Requirements source is already analyzed inline; do not spawn explore, analyst, executor, verifier, code-reviewer, or any role except oh-no-harness:planner and oh-no-harness:plan-reviewer. Synthetic approved task: document that the host asks the user which execution workflow to run after ralplan plan approval. Derive one compact Active plan contract. In both direct Task/Agent messages include exactly one identical serialized contract block between unindented delimiter lines ACTIVE_PLAN_CONTRACT_BEGIN and ACTIVE_PLAN_CONTRACT_END. Use direct Claude Task/Agent subagents exactly two times in this strict order and do not use Workflow in this instrumentation lane: oh-no-harness:planner, wait until that task completes before starting plan-reviewer; oh-no-harness:plan-reviewer, wait until that task completes before final. Never run these planning review agents in parallel. Planner expected output: only one block between unindented delimiter lines PLANNER_DRAFT_BEGIN and PLANNER_DRAFT_END; inside include Planner draft id: Planner draft v1, Active plan contract, Goal, Acceptance criteria, Execution profile, Worktree policy, and Verification plan. After Planner completes, copy that exact captured Planner draft block, including its id, into the Plan-Reviewer Task/Agent message between the same PLANNER_DRAFT_BEGIN and PLANNER_DRAFT_END lines; normalize transport whitespace only and do not summarize or reconstruct it. Plan-Reviewer expected output: only a short section titled Plan review v1 with Reviewed draft: Planner draft v1, Architecture findings: NB1 | severity: non-blocking | suggestion: shorten one explanatory sentence, Quality-gate findings: none blocking, Verdict: APPROVE. APPROVE freezes the exact reviewed Planner draft; NB1 is an optional follow-up and must not mutate it before approval. Do not revise or dispatch Planner again: this smoke test verifies the non-blocking-only v1 approval path and skips revision/re-review. After both subagents finish, reply with exactly OH_NO_CLAUDE_RALPLAN_SEQUENTIAL_SUBAGENTS_OK and summarize Object-of-analysis boundary: analysis-only, Exact Active contract equality: yes, Exact Planner draft handoff: yes, Role order: planner -> plan-reviewer, Waited between roles: yes, Reviews chained: Planner draft v1 -> Plan review v1, Optional follow-up: NB1, Planner revision: not run."

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
    --system-prompt "You are a read-only live smoke test runner. You may use subagents only for the requested sequential ralplan verification. Do not edit files."
  )

  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi

  "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

  "$PYTHON_BIN" - "$out_file" <<'PY'
import json
import re
import sys
from collections import defaultdict

path = sys.argv[1]
expected_roles = ["planner", "plan-reviewer"]
expected_agent_names = [f"oh-no-harness:{role}" for role in expected_roles]
dependency_prompt_markers = {
    "plan-reviewer": ["Planner draft v1", "Active plan contract"],
}
output_markers = {
    "planner": ["Planner draft v1", "Active plan contract"],
    "plan-reviewer": ["Plan review v1", "Reviewed draft", "Architecture findings", "NB1", "non-blocking", "Quality-gate findings"],
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
task_started = {}
task_role_by_id = {}
task_completion = {}
role_outputs = defaultdict(list)
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
                            tool_uses.append((index, role, payload))
                if part.get("type") == "tool_use" and part.get("name") == "Workflow":
                    script = collect_text(part.get("input", {}).get("script", ""))
                    workflow_scripts.append((index, script))
                if part.get("type") == "text":
                    subagent_type = data.get("subagent_type", "")
                    if subagent_type.startswith("oh-no-harness:"):
                        role = subagent_type.split(":", 1)[1]
                        if role in expected_roles:
                            role_outputs[role].append(part.get("text", ""))
        if data.get("type") == "system" and data.get("subtype") == "task_started":
            subagent_type = data.get("subagent_type", "")
            if subagent_type.startswith("oh-no-harness:"):
                role = subagent_type.split(":", 1)[1]
                task_id = data.get("task_id")
                if role in expected_roles and task_id:
                    task_started[role] = index
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
                text = collect_text(tool_result.get("content", tool_result))
                if text:
                    role_outputs[role].append(text)
                if tool_result.get("status") == "completed":
                    task_completion.setdefault(role, index)
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
    raise SystemExit(f"expected exactly two planning task uses, got {len(tool_uses)}: {tool_uses!r}")

actual_order = [role for _, role, _ in tool_uses]
if actual_order != expected_roles:
    raise SystemExit(f"expected sequential task order {expected_roles!r}, got {actual_order!r}")

role_payload_text = {}
for index, role, payload in tool_uses:
    prompt = collect_text(payload)
    role_payload_text[role] = prompt
    missing_prompt_markers = [
        marker for marker in dependency_prompt_markers.get(role, [])
        if marker.lower() not in prompt.lower()
    ]
    if missing_prompt_markers:
        raise SystemExit(
            f"Claude ralplan task prompt for {role} did not include required review input markers: "
            f"{missing_prompt_markers}; prompt={prompt[:2000]!r}"
        )

for previous, following in zip(tool_uses, tool_uses[1:]):
    _, previous_role, _ = previous
    following_index, following_role, _ = following
    completion_index = task_completion.get(previous_role)
    if completion_index is None:
        raise SystemExit(f"no completion event captured for {previous_role}")
    if completion_index >= following_index:
        raise SystemExit(
            f"expected {previous_role} completion before starting {following_role}; "
            f"completion={completion_index} following_start={following_index}"
        )

role_output_text = {}
for role, markers in output_markers.items():
    output_text = "\n".join(role_outputs.get(role, []))
    role_output_text[role] = output_text
    if not output_text:
        raise SystemExit(f"no output captured for {role}")
    missing_output_markers = [
        marker for marker in markers
        if marker.lower() not in output_text.lower()
    ]
    if missing_output_markers:
        raise SystemExit(
            f"Claude ralplan {role} output did not prove the review chain: "
            f"{missing_output_markers}; output={output_text[:2000]!r}"
        )

planner_contract = extract_delimited_block(
    role_payload_text["planner"], CONTRACT_START, CONTRACT_END, "Planner Active plan contract"
)
reviewer_contract = extract_delimited_block(
    role_payload_text["plan-reviewer"], CONTRACT_START, CONTRACT_END, "Plan-Reviewer Active plan contract"
)
if planner_contract != reviewer_contract:
    raise SystemExit("Claude ralplan role payloads did not carry the exact same Active plan contract")

captured_draft = extract_delimited_block(
    role_output_text["planner"], DRAFT_START, DRAFT_END, "captured Planner draft", allow_repeats=True
)
reviewer_draft = extract_delimited_block(
    role_payload_text["plan-reviewer"], DRAFT_START, DRAFT_END, "Plan-Reviewer input draft"
)
if captured_draft != reviewer_draft:
    raise SystemExit("Claude ralplan Plan-Reviewer payload did not carry the exact captured Planner draft")
draft_id = re.search(r"(?m)^Planner draft id:\s*(\S.*)$", captured_draft)
if not draft_id:
    raise SystemExit("Claude ralplan captured Planner draft omitted its draft id")
captured_draft_id = normalize_transport_whitespace(draft_id.group(1))
reviewed_draft_matches = re.findall(
    r"(?m)^Reviewed draft:[ \t]*(.*?)[ \t]*$",
    role_output_text["plan-reviewer"],
)
if len(reviewed_draft_matches) != 1:
    raise SystemExit("Claude ralplan Plan-Reviewer output must contain exactly one anchored Reviewed draft field")
reviewed_draft_id = normalize_transport_whitespace(reviewed_draft_matches[0])
if reviewed_draft_id != captured_draft_id:
    raise SystemExit("Claude ralplan Plan-Reviewer output did not identify the exact captured Planner draft id")

if not marker:
    raise SystemExit("Claude ralplan sequential smoke did not return success marker")

print("ok - live Claude ralplan planning subagents reviewed sequentially")
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
  local prompt="Use oh-no-harness:ralph. Read-only live subagent smoke test. This is an explicit parallel subagents request. Verify every Ralph-eligible Oh No Harness role with Claude background subagents, but respect platform concurrency limits: run the roles in independent waves of at most three subagents, start every subagent in the current wave before waiting for that wave, close or clean up each completed subagent when the host exposes that mechanism, and do not continue if any task fails. If no explicit close or cleanup mechanism exists, record that fallback. Wave 1: oh-no-harness:explore, oh-no-harness:analyst, oh-no-harness:planner. Wave 2: oh-no-harness:executor, oh-no-harness:debugger. Wave 3: oh-no-harness:verifier, oh-no-harness:code-reviewer, oh-no-harness:fusion-rescue-analyst. Wave 4: oh-no-harness:executor-codex. Do not dispatch oh-no-harness:plan-reviewer: only the Ralplan planning phase owns that role, and the separate Ralplan live smoke covers it. Each subagent should inspect its own agents/<role>.md file and report its role heading plus whether Skill Relationship, Responsibilities, Operating Rules, and Output are present. Do not edit files. After all nine subagents finish, reply exactly OH_NO_CLAUDE_PARALLEL_SUBAGENTS_OK and summarize the nine role checks plus lifecycle close or cleanup status."

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

  "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

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
    "executor-codex",
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
                        # Role is the segment after the last ":" so
                        # "oh-no-harness:executor-codex" -> "executor-codex".
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

# Default-mode degrade sub-run: force the Codex companion UNRESOLVABLE (a
# nonexistent OH_NO_CODEX_COMPANION_PATH is the deterministic degrade lever in
# the *-codex resolution kernel). fusion-codex must signal companion-unavailable
# and return without a panel; the main agent runs the adversarial slot on the
# current host (Same-Host Parallel Fallback / three current-host panels) and
# records `Codex adversarial unavailable`. No successful codex-companion Bash,
# no --write.
run_fusion_codex_degrade_sub_run() {
  log "Running live fusion-codex default-mode degrade sub-run (companion unresolvable)"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/fusion-codex-degrade.jsonl"
  local err_file="$RUN_DIR/fusion-codex-degrade.err"
  local prompt
  prompt=$(cat <<'PROMPT'
/oh-no-harness:fusion-rescue default-mode read-only live integration smoke test only. Do not edit files, do not create artifacts, do not install plugins, and do not run nested rescue.

Synthetic smoke-test problem all panels must analyze meaningfully: a CI pipeline has an intermittently failing integration test two days before release. Discuss release risk, CI signal, quarantine, auto-retry, and root-cause evidence.

This run is DEFAULT mode. The Codex companion is UNRESOLVABLE (OH_NO_CODEX_COMPANION_PATH points at a nonexistent file). Dispatch the opposite-host adversarial slot with subagent_type oh-no-harness:fusion-codex; it MUST detect the unresolvable companion, signal companion-unavailable, and return WITHOUT a panel and WITHOUT any successful node codex-companion.mjs call. Then run the adversarial lens on the current Claude host (Same-Host Parallel Fallback) and synthesize as the current-host judge.

Final answer must contain exactly the marker OH_NO_FUSION_CODEX_DEGRADE_OK and must include: panel availability/fallback notes: Codex adversarial unavailable; degrade path: current-host adversarial panel; fusion depth: 1; consensus; recommended next action.
PROMPT
)
  local cmd=(
    "$CLAUDE_BIN"
    --print
    --verbose
    --output-format stream-json
    --include-hook-events
    --model "$FUSION_RESCUE_LIVE_MODEL"
    --max-budget-usd "$FUSION_RESCUE_MAX_BUDGET_USD"
    --permission-mode bypassPermissions
    --allowedTools "Bash(node *)"
    --tools default
    --no-session-persistence
    --system-prompt "You are a read-only live smoke test runner. The Codex companion is unavailable; take the default-mode Same-Host Parallel Fallback. Do not edit files."
  )
  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi
  OH_NO_CODEX_COMPANION_PATH="$RUN_DIR/nonexistent/codex-companion.mjs" \
    "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

  "$PYTHON_BIN" - "$out_file" <<'PY'
import json, sys
out_path = sys.argv[1]
non_user = []
codex_write_commands = []
codex_bash_success = []
with open(out_path, "r", encoding="utf-8") as fh:
    for line in fh:
        if not line.strip():
            continue
        data = json.loads(line)
        if data.get("type") == "assistant":
            for part in data.get("message", {}).get("content", []):
                if part.get("type") == "text":
                    non_user.append(part.get("text", ""))
                if part.get("type") == "tool_use" and part.get("name") == "Bash":
                    command = str(part.get("input", {}).get("command", ""))
                    if "codex-companion" in command and "--write" in command:
                        codex_write_commands.append(command[:500])
        if data.get("type") == "result":
            non_user.append(str(data.get("result", "")))
        if data.get("type") == "user":
            for part in data.get("message", {}).get("content", []):
                if isinstance(part, dict) and "codex-companion.mjs" in str(part) and not part.get("is_error"):
                    codex_bash_success.append(True)
blob = "\n".join(non_user)
if codex_write_commands:
    raise SystemExit(f"fusion-codex degrade sub-run invoked codex-companion with --write: {codex_write_commands!r}")
if "OH_NO_FUSION_CODEX_DEGRADE_OK" not in blob:
    raise SystemExit("fusion-codex degrade sub-run did not return OH_NO_FUSION_CODEX_DEGRADE_OK (default-mode Same-Host Parallel Fallback)")
if "codex adversarial unavailable" not in blob.lower():
    raise SystemExit("fusion-codex degrade sub-run did not record 'Codex adversarial unavailable'")
print("ok - fusion-codex default-mode degrade produced the current-host Same-Host Parallel Fallback")
PY
}

# require-cross-host block sub-run: same unresolvable companion, but in
# require-cross-host mode the run must BLOCK (no synthesized success marker) and
# name the current-host three-panel fallback.
run_fusion_codex_block_sub_run() {
  log "Running live fusion-codex require-cross-host block sub-run (companion unresolvable)"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/fusion-codex-block.jsonl"
  local err_file="$RUN_DIR/fusion-codex-block.err"
  local prompt
  prompt=$(cat <<'PROMPT'
/oh-no-harness:fusion-rescue require-cross-host read-only live integration smoke test only. Do not edit files, do not create artifacts, do not install plugins, and do not run nested rescue.

Synthetic smoke-test problem: a CI pipeline has an intermittently failing integration test two days before release.

This run is require-cross-host mode. The Codex companion is UNRESOLVABLE (OH_NO_CODEX_COMPANION_PATH points at a nonexistent file). Dispatch the opposite-host adversarial slot with subagent_type oh-no-harness:fusion-codex; it MUST detect the unresolvable companion and signal companion-unavailable WITHOUT any successful node codex-companion.mjs call. Because this is require-cross-host mode, you MUST BLOCK: do NOT synthesize a passing panel and do NOT emit any success marker. Report the block and name the current-host three-panel fallback the user can approve.

Final answer must contain exactly the marker OH_NO_FUSION_CODEX_BLOCK_OK and must include: blocked: require-cross-host; Codex adversarial unavailable; current-host three-panel fallback. It must NOT contain OH_NO_FUSION_CODEX_PANEL_OK.
PROMPT
)
  local cmd=(
    "$CLAUDE_BIN"
    --print
    --verbose
    --output-format stream-json
    --include-hook-events
    --model "$FUSION_RESCUE_LIVE_MODEL"
    --max-budget-usd "$FUSION_RESCUE_MAX_BUDGET_USD"
    --permission-mode bypassPermissions
    --allowedTools "Bash(node *)"
    --tools default
    --no-session-persistence
    --system-prompt "You are a read-only live smoke test runner. The Codex companion is unavailable and this is require-cross-host mode; block and name the current-host fallback. Do not edit files."
  )
  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi
  OH_NO_CODEX_COMPANION_PATH="$RUN_DIR/nonexistent/codex-companion.mjs" \
    "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

  "$PYTHON_BIN" - "$out_file" <<'PY'
import json, sys
out_path = sys.argv[1]
non_user = []
with open(out_path, "r", encoding="utf-8") as fh:
    for line in fh:
        if not line.strip():
            continue
        data = json.loads(line)
        if data.get("type") == "assistant":
            for part in data.get("message", {}).get("content", []):
                if part.get("type") == "text":
                    non_user.append(part.get("text", ""))
        if data.get("type") == "result":
            non_user.append(str(data.get("result", "")))
blob = "\n".join(non_user)
if "OH_NO_FUSION_CODEX_BLOCK_OK" not in blob:
    raise SystemExit("fusion-codex block sub-run did not return OH_NO_FUSION_CODEX_BLOCK_OK (require-cross-host block)")
if "OH_NO_FUSION_CODEX_PANEL_OK" in blob:
    raise SystemExit("fusion-codex block sub-run synthesized a passing panel in require-cross-host mode instead of blocking")
if "current-host three-panel fallback" not in blob.lower():
    raise SystemExit("fusion-codex block sub-run did not name the current-host three-panel fallback")
print("ok - fusion-codex require-cross-host block did not synthesize a passing panel")
PY
}

run_fusion_rescue_live_test() {
  if [[ "$RUN_FUSION_RESCUE_LIVE" != "1" ]]; then
    log "Skipping live Claude Fusion Rescue fusion-codex smoke test"
    printf 'Run with --fusion-rescue-live or OH_NO_FUSION_RESCUE_LIVE=1 to verify Fusion Rescue panel subagents plus the oh-no-harness:fusion-codex read-only Codex consult.\n' >&2
    return
  fi

  log "Running live Claude Fusion Rescue fusion-codex smoke test (${LIVE_LOAD_MODE}, model ${FUSION_RESCUE_LIVE_MODEL})"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/fusion-rescue-claude-codex.jsonl"
  local err_file="$RUN_DIR/fusion-rescue-claude-codex.err"
  local summary_file="$RUN_DIR/fusion-rescue-claude-codex.summary.json"
  local prompt
  prompt=$(cat <<'PROMPT'
/oh-no-harness:fusion-rescue require-cross-host read-only live integration smoke test only. Do not edit files, do not create artifacts, do not install plugins, and do not run nested rescue.

Synthetic smoke-test problem all panels must analyze meaningfully: a CI pipeline has an intermittently failing integration test two days before release. The team must choose whether to quarantine the test, add automatic retries, or root-cause/fix the failure before release. Every panel result must discuss release risk, CI signal, quarantine, auto-retry, and root-cause evidence rather than only saying the smoke test is formatted correctly.

Build exactly three panel slots and then synthesize as the current Claude main judge.

Panel 1 primary must be a Claude current-host subagent using oh-no-harness:fusion-rescue-analyst. Its task prompt must include exactly these lines: Lens: primary; Marker: OH_NO_CLAUDE_FUSION_PANEL_PRIMARY; fusion depth: 1; Do not invoke rescue, fusion-rescue, cross-host consult, or another host from inside this panel; Scope: synthetic CI release-risk problem only; Do not edit files; Expected output: marker line plus exact assigned lens fields only: lens name; strongest finding; evidence used; assumption under test; likely failure mode; recommended next action; confidence and why; what would change the conclusion. It must provide constructive analysis of quarantine, auto-retry, root-cause, CI signal, and release risk.

Panel 2 adversarial must be exactly one Codex opposite-host response through the dedicated read-only consult agent, dispatched with subagent_type oh-no-harness:fusion-codex. A valid live result requires oh-no-harness:fusion-codex to perform exactly one required Bash call to node codex-companion.mjs in the foreground, set Bash timeout to at least 600000 ms, wait for completion, and return Codex companion stdout; a marker generated locally by the wrapper, returned after a Bash approval failure, returned while Bash is still running in the background without a later captured foreground codex-companion stdout completion, or returned after a Stop hook still says a Codex task is running after codex-companion stdout completion is not valid. The harness parser, not you, verifies the Bash event stream and codex-companion stdout after the run. Therefore do not call SendMessage, ToolSearch, status, result, or a second oh-no-harness:fusion-codex task for liveness checking. Do not retry the Codex panel if it returns a marker; if it reports a failure, block without success. The fusion-codex packet must instruct Codex to dispatch oh-no-fusion-rescue-analyst for the one assigned adversarial lens and return the role-owned result of that analyst, and it must include the marker request OH_NO_FUSION_CODEX_RETURN_OK plus role-ownership proof that the analyst, not a parent inline Codex answer, produced it. The codex-companion Bash command MUST NOT include --write and MUST NOT include --background; the fusion-codex agent runs codex-companion read-only by design (no --write flag) and synchronously in the foreground, and a permission denial from an attempted --write command is a test failure even if a later retry succeeds. The Codex packet: --prompt-file with a redacted packet, explicitly read-only behavior; no edits, no writes, no installs; fusion depth: 1; do not invoke rescue, fusion-rescue, cross-host consult, Claude, or another host; dispatch oh-no-fusion-rescue-analyst to analyze this CI release-risk problem adversarially; return exactly OH_NO_FUSION_CODEX_RETURN_OK plus lens name adversarial, strongest finding, evidence used, assumption under test, likely failure mode, recommended next action, confidence and why, and what would change the conclusion. If oh-no-harness:fusion-codex cannot run exactly one node codex-companion.mjs Bash call without approval or foreground completion, or cannot prove oh-no-fusion-rescue-analyst role ownership, do not synthesize success and do not include OH_NO_FUSION_CODEX_PANEL_OK.

Panel 3 pragmatic must be a Claude current-host subagent using oh-no-harness:fusion-rescue-analyst. Its task prompt must include exactly these lines: Lens: pragmatic; Marker: OH_NO_CLAUDE_FUSION_PANEL_PRAGMATIC; fusion depth: 1; Do not invoke rescue, fusion-rescue, cross-host consult, or another host from inside this panel; Scope: synthetic CI release-risk problem only; Do not edit files; Expected output: marker line plus exact assigned lens fields only: lens name; strongest finding; evidence used; assumption under test; likely failure mode; recommended next action; confidence and why; what would change the conclusion. It must recommend the simplest reversible next step and verification path for the CI release-risk decision.

Start the two Claude panel subagents before waiting when possible. Wait for exactly these three panel results, and do not end while a worker is still pending. After the single Codex fusion-codex consult returns and both Claude panel subagents finish, synthesize immediately rather than concatenate or recheck liveness. Final answer must contain exactly the marker OH_NO_FUSION_CODEX_PANEL_OK and must include: panels completed: primary, adversarial, pragmatic; Codex marker: OH_NO_FUSION_CODEX_RETURN_OK; Claude markers: OH_NO_CLAUDE_FUSION_PANEL_PRIMARY, OH_NO_CLAUDE_FUSION_PANEL_PRAGMATIC; consensus; contradictions; unique insights; blind spots; recommended next action; confidence and why; panel availability/fallback notes: Claude primary available, Codex adversarial available via opposite-host response oh-no-harness:fusion-codex, Claude pragmatic available; fusion depth: 1.
PROMPT
)

  local cmd=(
    "$CLAUDE_BIN"
    --print
    --verbose
    --output-format stream-json
    --include-hook-events
    --model "$FUSION_RESCUE_LIVE_MODEL"
    --max-budget-usd "$FUSION_RESCUE_MAX_BUDGET_USD"
    --permission-mode bypassPermissions
    --allowedTools "Bash(node *)"
    --tools default
    --no-session-persistence
    --system-prompt "You are a read-only live smoke test runner. Use the invoked Oh No Harness Fusion Rescue skill. You may use Claude subagents and the oh-no-harness:fusion-codex read-only consult agent only for this requested verification. Do not edit files."
  )

  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi

  "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

  "$PYTHON_BIN" - "$out_file" "$err_file" "$summary_file" "$FUSION_RESCUE_LIVE_MODEL" <<'PY'
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

out_path, err_path, summary_path, fusion_model = sys.argv[1:5]
expected_claude_markers = {
    "primary": "OH_NO_CLAUDE_FUSION_PANEL_PRIMARY",
    "pragmatic": "OH_NO_CLAUDE_FUSION_PANEL_PRAGMATIC",
}
required_final_markers = [
    "OH_NO_FUSION_CODEX_PANEL_OK",
    "OH_NO_FUSION_CODEX_RETURN_OK",
    "OH_NO_CLAUDE_FUSION_PANEL_PRIMARY",
    "OH_NO_CLAUDE_FUSION_PANEL_PRAGMATIC",
    "panels completed",
    "primary, adversarial, pragmatic",
    "panel availability/fallback notes",
    "opposite-host response",
    "oh-no-harness:fusion-codex",
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
required_codex_result_fields = [
    "adversarial",
    "evidence used",
    "assumption under test",
    "likely failure mode",
    "recommended next action",
    "confidence",
    "change",
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
secret_patterns = [
    re.compile(r"(?<![A-Za-z0-9])sk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"(?i)(api[_-]?key|access[_-]?token|refresh[_-]?token|private[_-]?key|cookie)[ \t]*[:=][ \t]*['\"]?[A-Za-z0-9_./+=-]{12,}"),
]
forbidden_write_tool_names = {"Edit", "Write", "NotebookEdit"}
forbidden_fallbacks = [
    "Codex adversarial unavailable",
    "codex unavailable",
    "codex rescue unavailable",
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

def assert_meaningful_domain_analysis(label, text):
    lower_text = text.lower()
    hits = [marker for marker in domain_markers if marker in lower_text]
    if len(hits) < 4:
        raise SystemExit(
            f"Claude Fusion Rescue live {label} did not include meaningful CI release-risk analysis; "
            f"domain_hits={hits!r} text={text[:2000]!r}"
        )
    weak_markers = (
        "no substantive problem packet",
        "only format",
        "format/scope smoke",
        "no actionable problem packet",
        "does the cross-host fusion rescue panel integration work",
    )
    for marker in weak_markers:
        if marker in lower_text:
            raise SystemExit(
                f"Claude Fusion Rescue live {label} returned weak/non-substantive analysis marker "
                f"{marker!r}; text={text[:2000]!r}"
            )
    # "only smoke" flags a panel that treats the task as merely a smoke check.
    # Exclude legitimate analysis phrasing like "read-only smoke scope", where
    # the substring "only smoke" appears inside "read-only" without being weak.
    if re.search(r"(?<!read-)only smoke", lower_text):
        raise SystemExit(
            f"Claude Fusion Rescue live {label} returned weak/non-substantive analysis marker "
            f"'only smoke'; text={text[:2000]!r}"
        )

with open(err_path, "r", encoding="utf-8") as fh:
    err_text = fh.read()
if "unknown command" in err_text.lower() or "unknown agent" in err_text.lower():
    raise SystemExit(f"Claude Fusion Rescue live saw unavailable command/agent in stderr: {err_text[:2000]!r}")

init_slash_commands = set()
init_agents = set()
init_tools = set()
errors = []
claude_panel_uses = defaultdict(list)
claude_panel_results = {}
fusion_codex_uses = []
unexpected_task_uses = []
unexpected_write_uses = []
task_started_roles = []
task_completed_roles = []
codex_bash_tool_ids = set()
codex_bash_success_texts = []
codex_bash_success_indexes = []
codex_bash_failures = []
codex_write_commands = []
codex_background_commands = []
workflow_tool_ids = set()
workflow_scripts = []
workflow_completed = False
non_user_text_parts = []
permission_denials = []
pending_background_events = []

with open(out_path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        text = collect_text(data)
        if data.get("type") == "system" and (
            "Command running in background" in text
            or ("Codex task" in text and "still running" in text)
        ):
            pending_background_events.append((index, text[:2000]))
        if any(pattern.search(text) for pattern in secret_patterns):
            raise SystemExit(f"Claude Fusion Rescue live transcript exposed a secret-like value near line {index}")
        if data.get("type") == "system" and data.get("subtype") == "init":
            init_slash_commands.update(data.get("slash_commands", []))
            init_agents.update(data.get("agents", []))
            init_tools.update(data.get("tools", []))
        if data.get("type") == "assistant":
            non_user_text_parts.append(text)
            for part in data.get("message", {}).get("content", []):
                if part.get("type") == "tool_use" and part.get("name") in forbidden_write_tool_names:
                    unexpected_write_uses.append((index, part.get("name"), collect_text(part.get("input", ""))[:1000]))
                if part.get("type") == "tool_use" and part.get("name") == "Bash":
                    payload = part.get("input", {})
                    command = str(payload.get("command", ""))
                    if "codex-companion.mjs" in command:
                        # The --write/--background forbids cover EVERY
                        # codex-companion command, including a rogue call that
                        # inlines the packet instead of using --prompt-file.
                        if re.search(r"(?<!\S)--write(?!\S)", command):
                            codex_write_commands.append((index, command[:2000]))
                        if re.search(r"(?<!\S)--background(?!\S)", command):
                            codex_background_commands.append((index, command[:2000]))
                        # Count only the actual delegation `task` call (which
                        # passes the packet via --prompt-file), not the read-only
                        # companion-path resolution probes (ls / [ -f ] / versions
                        # checks) the kernel runs first to resolve/verify the
                        # companion before delegating.
                        if "--prompt-file" in command:
                            codex_bash_tool_ids.add(part.get("id"))
                if part.get("type") == "tool_use" and part.get("name") in {"Agent", "Task"}:
                    payload = part.get("input", {})
                    payload_text = collect_text(payload)
                    subagent_type = payload.get("subagent_type", "")
                    if subagent_type == "oh-no-harness:fusion-rescue-analyst":
                        matched = [
                            lens for lens, marker in expected_claude_markers.items()
                            if marker in payload_text
                        ]
                        if len(matched) != 1:
                            raise SystemExit(
                                "Claude Fusion Rescue live expected each fusion analyst task "
                                f"to contain one lens marker; line={index} markers={matched!r} "
                                f"payload={payload_text[:2000]!r}"
                            )
                        claude_panel_uses[matched[0]].append((index, payload_text))
                    elif subagent_type == "oh-no-harness:fusion-codex":
                        fusion_codex_uses.append((index, payload_text))
                    else:
                        unexpected_task_uses.append((index, subagent_type, payload_text[:1000]))
                if part.get("type") == "tool_use" and part.get("name") == "Workflow":
                    workflow_tool_ids.add(part.get("id"))
                    script = collect_text(part.get("input", {}).get("script", ""))
                    if script:
                        workflow_scripts.append((index, script))
                if part.get("type") == "text":
                    part_text = part.get("text", "")
                    non_user_text_parts.append(part_text)
                    matched_result_markers = [
                        lens for lens, marker in expected_claude_markers.items()
                        if marker in part_text
                    ]
                    if len(matched_result_markers) == 1:
                        claude_panel_results.setdefault(matched_result_markers[0], part_text)
        if data.get("type") == "system" and data.get("subtype") == "task_started":
            subagent_type = data.get("subagent_type", "")
            if subagent_type:
                task_started_roles.append((index, subagent_type))
        if data.get("type") == "system" and data.get("subtype") in {"task_updated", "task_notification"}:
            if data.get("status") == "completed":
                subagent_type = data.get("subagent_type", "")
                if subagent_type:
                    task_completed_roles.append((index, subagent_type))
                if (
                    data.get("tool_use_id") in workflow_tool_ids
                    or "workflow" in str(data.get("summary", "")).lower()
                ):
                    workflow_completed = True
            non_user_text_parts.append(text)
        tool_result = data.get("tool_use_result") or {}
        if data.get("type") == "user":
            for part in data.get("message", {}).get("content", []):
                if not isinstance(part, dict):
                    continue
                tool_use_id = part.get("tool_use_id")
                if tool_use_id not in codex_bash_tool_ids:
                    continue
                result_text = collect_text(part)
                is_error = bool(part.get("is_error"))
                if "Command running in background" in result_text or (
                    "Codex task" in result_text and "still running" in result_text
                ):
                    raise SystemExit(
                        "Claude Fusion Rescue live codex-companion Bash did not complete "
                        f"in the foreground: {result_text[:1000]!r}"
                    )
                if is_error:
                    codex_bash_failures.append((index, result_text[:1000]))
                else:
                    codex_bash_success_indexes.append(index)
                    codex_bash_success_texts.append(result_text)
        if isinstance(tool_result, dict):
            agent_type = tool_result.get("agentType", "")
            if agent_type:
                non_user_text_parts.append(collect_text(tool_result))
                if tool_result.get("status") == "completed":
                    task_completed_roles.append((index, agent_type))
                    if agent_type == "oh-no-harness:fusion-rescue-analyst":
                        result_text = collect_text(tool_result.get("content", ""))
                        matched = [
                            lens for lens, marker in expected_claude_markers.items()
                            if marker in result_text
                        ]
                        if len(matched) != 1:
                            raise SystemExit(
                                "Claude Fusion Rescue live expected each completed fusion analyst "
                                f"result to contain one lens marker; line={index} markers={matched!r} "
                                f"result={result_text[:2000]!r}"
                            )
                        claude_panel_results[matched[0]] = result_text
        if data.get("type") == "result":
            permission_denials.extend(data.get("permission_denials") or [])
        if data.get("type") == "result":
            non_user_text_parts.append(str(data.get("result", "")))
            if data.get("is_error") is True:
                errors.append((index, str(data.get("result", ""))[:1000]))

if errors:
    raise SystemExit(f"Claude Fusion Rescue live returned errors: {errors!r}")
if unexpected_write_uses:
    raise SystemExit(f"Claude Fusion Rescue live used write-capable tools: {unexpected_write_uses!r}")
if codex_write_commands:
    raise SystemExit(f"Claude Fusion Rescue live invoked codex-companion with --write: {codex_write_commands!r}")
if codex_background_commands:
    raise SystemExit(f"Claude Fusion Rescue live invoked codex-companion with --background: {codex_background_commands!r}")
if permission_denials:
    raise SystemExit(f"Claude Fusion Rescue live had permission denials: {permission_denials!r}")
if "oh-no-harness:fusion-codex" not in init_agents:
    raise SystemExit(
        "Claude Fusion Rescue live did not expose oh-no-harness:fusion-codex agent; "
        f"got={sorted(agent for agent in init_agents if 'codex' in agent or 'fusion' in agent)!r}"
    )
if "oh-no-harness:fusion-rescue-analyst" not in init_agents:
    raise SystemExit("Claude Fusion Rescue live did not expose oh-no-harness:fusion-rescue-analyst agent")
if not ({"Task", "Agent", "Workflow"} & init_tools):
    raise SystemExit(f"Claude Fusion Rescue live did not expose subagent tooling; tools={sorted(init_tools)!r}")

if workflow_scripts or workflow_completed:
    raise SystemExit("Claude Fusion Rescue live used Workflow instead of directly observable panel subagents")
if unexpected_task_uses:
    raise SystemExit(f"Claude Fusion Rescue live started unexpected Task/Agent subagents: {unexpected_task_uses!r}")
missing_lenses = sorted(set(expected_claude_markers) - set(claude_panel_uses))
if missing_lenses:
    raise SystemExit(f"Claude Fusion Rescue live did not start Claude panel lenses: {missing_lenses!r}")
duplicate_lenses = {
    lens: uses for lens, uses in claude_panel_uses.items()
    if len(uses) != 1
}
if duplicate_lenses:
    raise SystemExit(f"Claude Fusion Rescue live expected one task per Claude panel lens: {duplicate_lenses!r}")
missing_results = sorted(set(expected_claude_markers) - set(claude_panel_results))
if missing_results:
    raise SystemExit(f"Claude Fusion Rescue live did not capture completed panel results: {missing_results!r}")
for lens, result_text in claude_panel_results.items():
    lower_result_text = result_text.lower()
    if lens not in lower_result_text:
        raise SystemExit(
            f"Claude Fusion Rescue live panel {lens} result did not name its lens; "
            f"result={result_text[:2000]!r}"
        )
    for field in required_panel_fields:
        if field not in lower_result_text:
            raise SystemExit(
                f"Claude Fusion Rescue live panel {lens} result missed field {field!r}; "
                f"result={result_text[:2000]!r}"
            )
    assert_meaningful_domain_analysis(f"panel {lens}", result_text)
if len(fusion_codex_uses) != 1:
    raise SystemExit(f"Claude Fusion Rescue live expected one oh-no-harness:fusion-codex task, got {fusion_codex_uses!r}")
codex_payload = fusion_codex_uses[0][1]
# Role-ownership: the fusion-codex packet must instruct Codex to dispatch
# oh-no-fusion-rescue-analyst (not answer inline) and must request the return
# marker; the read-only packet must not authorize a write flag.
for marker in ("oh-no-fusion-rescue-analyst", "OH_NO_FUSION_CODEX_RETURN_OK", "read-only", "fusion depth: 1"):
    if marker.lower() not in codex_payload.lower():
        raise SystemExit(
            f"Claude Fusion Rescue live fusion-codex payload missed role-ownership marker {marker!r}; "
            f"payload={codex_payload[:2000]!r}"
        )
started_role_names = [role for _, role in task_started_roles]
if "oh-no-harness:fusion-codex" not in started_role_names and not workflow_scripts:
    raise SystemExit(f"Claude Fusion Rescue live did not start oh-no-harness:fusion-codex task; starts={task_started_roles!r}")
completed_role_names = [role for _, role in task_completed_roles]
if (
    "oh-no-harness:fusion-codex" not in completed_role_names
    and "OH_NO_FUSION_CODEX_RETURN_OK" not in "\n".join(non_user_text_parts)
):
    raise SystemExit(f"Claude Fusion Rescue live did not complete fusion-codex or capture its marker; completions={task_completed_roles!r}")
if not codex_bash_tool_ids:
    raise SystemExit("Claude Fusion Rescue live did not invoke codex-companion.mjs through oh-no-harness:fusion-codex Bash")
if len(codex_bash_tool_ids) != 1:
    raise SystemExit(f"Claude Fusion Rescue live expected exactly one codex-companion.mjs Bash invocation, got {sorted(codex_bash_tool_ids)!r}")
if codex_bash_failures:
    raise SystemExit(f"Claude Fusion Rescue live codex-companion Bash failed: {codex_bash_failures!r}")
if len(codex_bash_success_indexes) != 1:
    raise SystemExit(f"Claude Fusion Rescue live expected exactly one successful codex-companion.mjs Bash result, got {codex_bash_success_indexes!r}")
codex_bash_text = "\n".join(codex_bash_success_texts)
if "OH_NO_FUSION_CODEX_RETURN_OK" not in codex_bash_text:
    raise SystemExit(
        "Claude Fusion Rescue live did not capture OH_NO_FUSION_CODEX_RETURN_OK "
        "from codex-companion.mjs stdout"
    )
# Role-ownership proof: the returned Codex stdout must show the assigned role
# agent (oh-no-fusion-rescue-analyst) owned the panel, not a parent inline answer.
if "oh-no-fusion-rescue-analyst" not in codex_bash_text.lower():
    raise SystemExit(
        "Claude Fusion Rescue live codex-companion stdout did not prove "
        "oh-no-fusion-rescue-analyst role ownership (possible parent inline answer)"
    )
last_codex_bash_success_index = max(codex_bash_success_indexes) if codex_bash_success_indexes else None
late_pending_background_events = [
    event for event in pending_background_events
    if last_codex_bash_success_index is None or event[0] > last_codex_bash_success_index
]
if late_pending_background_events:
    raise SystemExit(
        "Claude Fusion Rescue live left background/still-running work after Codex "
        f"foreground completion: {late_pending_background_events!r}"
    )
lower_codex_bash_text = codex_bash_text.lower()
for field in required_codex_result_fields:
    if field not in lower_codex_bash_text:
        raise SystemExit(
            f"Claude Fusion Rescue live Codex companion stdout missed field {field!r}; "
            f"stdout={codex_bash_text[:2000]!r}"
        )
assert_meaningful_domain_analysis("Codex adversarial panel", codex_bash_text)

non_user_text = "\n".join(non_user_text_parts)
for forbidden in (
    "This command requires approval",
    "permission denied",
    "sandbox approval gate",
    "forwarded Codex output is unavailable",
    "returned directly from this wrapper",
    "CODEX_RESCUE_PERMISSION_BLOCKED",
):
    if forbidden.lower() in non_user_text.lower():
        raise SystemExit(f"Claude Fusion Rescue live saw non-live Codex rescue evidence: {forbidden!r}")
success_text = "\n".join(
    part for part in non_user_text_parts
    if "OH_NO_FUSION_CODEX_PANEL_OK" in part
)
if not success_text:
    detail = f"; pending events={pending_background_events!r}" if pending_background_events else ""
    raise SystemExit(f"Claude Fusion Rescue live did not return success marker OH_NO_FUSION_CODEX_PANEL_OK{detail}")
lower_success_text = success_text.lower()
for marker in required_final_markers:
    if marker.lower() not in lower_success_text:
        raise SystemExit(f"Claude Fusion Rescue live missing final marker/text: {marker!r}")
for field in required_synthesis_fields:
    if field.lower() not in lower_success_text:
        raise SystemExit(f"Claude Fusion Rescue live missing synthesis field: {field!r}")
for marker in forbidden_fallbacks:
    if marker.lower() in lower_success_text:
        raise SystemExit(f"Claude Fusion Rescue live reported forbidden fallback marker: {marker!r}")

summary = {
    "status": "passed",
    "model": fusion_model,
    "claude_panel_results": [
        {
            "lens": lens,
            "subagent_type": "oh-no-harness:fusion-rescue-analyst",
            "returned_marker": expected_claude_markers[lens],
        }
        for lens in sorted(claude_panel_results)
    ],
    "fusion_codex": {
        "subagent_type": "oh-no-harness:fusion-codex",
        "codex_side_role": "oh-no-fusion-rescue-analyst",
        "bash_tool_uses": len(codex_bash_tool_ids),
        "returned_marker": "OH_NO_FUSION_CODEX_RETURN_OK",
        "permission_denials": len(permission_denials),
    },
    "final_marker": "OH_NO_FUSION_CODEX_PANEL_OK",
}
Path(summary_path).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print("ok - live Claude Fusion Rescue used oh-no-harness:fusion-codex (read-only codex-companion, no --write/--background), captured Codex output, and synthesized")
PY

  run_fusion_codex_degrade_sub_run
  run_fusion_codex_block_sub_run
}

run_cross_host_fallback_live_test() {
  if [[ "$RUN_CROSS_HOST_FALLBACK_LIVE" != "1" ]]; then
    log "Skipping live Claude cross-host Same-Host Parallel Fallback smoke test"
    printf 'Run with --cross-host-fallback-live or OH_NO_CROSS_HOST_FALLBACK_LIVE=1 to verify the default-mode opposite-host-unavailable two-same-host-agent fallback.\n' >&2
    return
  fi

  log "Running live Claude cross-host Same-Host Parallel Fallback smoke test (${LIVE_LOAD_MODE}, model ${FUSION_RESCUE_LIVE_MODEL})"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/cross-host-fallback-claude.jsonl"
  local err_file="$RUN_DIR/cross-host-fallback-claude.err"
  local summary_file="$RUN_DIR/cross-host-fallback-claude.summary.json"
  local read_root="$PLUGIN_ROOT"

  if [[ "$LIVE_LOAD_MODE" == "installed" ]]; then
    read_root="$(cached_plugin_root)"
  fi

  local prompt
  prompt=$(cat <<PROMPT
/${PLUGIN_NAME}:simplify --review Read-only live cross-host fallback smoke test only. Do not edit files, do not create artifacts, do not install plugins, and do not run any write-capable command.

Named THOROUGH trigger: security-sensitive public authentication contract review. Pairing is trigger-driven, not availability-driven.

First, read ${read_root}/docs/shared/cross-host-review.md, paying attention to its "## Same-Host Parallel Fallback" and "## Parallel Execution And Synthesis" sections. This run is in DEFAULT mode (NOT require-cross-host). The opposite host (Codex) is UNAVAILABLE: the oh-no-harness:*-codex cross-host consult agents and their codex-companion transport are not available or authorized in this run, so you MUST NOT attempt any cross-host hop, must NOT dispatch oh-no-harness:plan-reviewer-codex, oh-no-harness:code-reviewer-codex, oh-no-harness:debugger-codex, oh-no-harness:fusion-codex, rescue, fusion-rescue, or any opposite-host or another-host call. Treat the opposite host as unavailable and take the default-mode Same-Host Parallel Fallback, NOT the cross-host path.

Lightweight contract pre-check (read-only). From ${read_root}/docs/shared/cross-host-review.md, confirm and state, behind the marker OH_NO_CLAUDE_DEEP_OK cross-host-fallback, all of: (1) in default mode when the opposite host is unavailable the review dispatches EXACTLY TWO same-host agents of the same role synthesized into one result rather than a single pass; (2) require-cross-host mode still BLOCKS instead of using this fallback. Include the exact phrases "exactly two same-host agents" and "require-cross-host" so this pre-check is machine-checkable.

Behavioral fallback task. Drive the code-reviewer role over this tiny fixed diff under the Same-Host Parallel Fallback. The diff under review (treat as the stable diff):
--- a/auth.py
+++ b/auth.py
@@
-def is_admin(user):
-    return user.role == "admin"
+def is_admin(user):
+    return user.role == "admin" or user.get("debug", False)
The reviewed change adds a debug bypass to an admin check. Because the opposite host is unavailable in default mode, dispatch EXACTLY TWO same-host code-reviewer agents in parallel, each running the COMPLETE code-reviewer role, differing only by lens emphasis, then synthesize as the current-host main judge.

Same-host agent Lens A must be an adversarial correctness + security skeptic ("what breaks or is exploitable"). Its task prompt must include exactly these lines: Lens: A adversarial correctness and security; Marker: OH_NO_XHOST_FALLBACK_LENS_A; Scope: the fixed auth.py diff only; Do not edit files; Do not make any cross-host or opposite-host call; Expected output: marker line plus strongest finding, evidence used, likely failure mode, recommended next action.

Same-host agent Lens B must be a maintainability + coverage completeness reviewer ("what is missing or regresses"). Its task prompt must include exactly these lines: Lens: B maintainability and coverage; Marker: OH_NO_XHOST_FALLBACK_LENS_B; Scope: the fixed auth.py diff only; Do not edit files; Do not make any cross-host or opposite-host call; Expected output: marker line plus strongest finding, evidence used, likely failure mode, recommended next action.

Start both same-host agents before waiting when possible. Wait for exactly these two same-host results and do not end while a worker is still pending. After both finish, synthesize immediately as the current-host main judge rather than concatenate. The final answer must contain exactly the marker OH_NO_XHOST_FALLBACK_OK and must include: same-host agents: 2; lens markers: OH_NO_XHOST_FALLBACK_LENS_A, OH_NO_XHOST_FALLBACK_LENS_B; a single synthesis block marked OH_NO_XHOST_FALLBACK_SYNTHESIS with consensus, contradictions, and recommended next action; and a fallback note stating the opposite host (Codex) was treated as unavailable and the review ran via the Same-Host Parallel Fallback of two same-host agents rather than as a single current-host pass or a cross-host consult. Do NOT emit any Codex or opposite-host success marker and do NOT claim a cross-host consult occurred.
PROMPT
)

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
    --add-dir "$read_root"
    --no-session-persistence
    --system-prompt "You are a read-only live smoke test runner. Use the invoked Oh No Harness skill and Claude same-host subagents only. The opposite host (Codex) and the oh-no-harness:*-codex cross-host consult agents are unavailable and not authorized in this run; do not attempt any cross-host or opposite-host call. Do not edit files."
  )

  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi

  "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

  "$PYTHON_BIN" - "$out_file" "$err_file" "$summary_file" "$FUSION_RESCUE_LIVE_MODEL" <<'PY'
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

out_path, err_path, summary_path, model = sys.argv[1:5]

expected_lens_markers = {
    "A": "OH_NO_XHOST_FALLBACK_LENS_A",
    "B": "OH_NO_XHOST_FALLBACK_LENS_B",
}
required_final_markers = [
    "OH_NO_XHOST_FALLBACK_OK",
    "OH_NO_XHOST_FALLBACK_LENS_A",
    "OH_NO_XHOST_FALLBACK_LENS_B",
    "OH_NO_XHOST_FALLBACK_SYNTHESIS",
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
    "OH_NO_CODEX_RESCUE_RETURN_OK",
    "OH_NO_CLAUDE_FUSION_RESCUE_CODEX_OK",
]
secret_patterns = [
    re.compile(r"(?<![A-Za-z0-9])sk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"(?i)(api[_-]?key|access[_-]?token|refresh[_-]?token|private[_-]?key|cookie)[ \t]*[:=][ \t]*['\"]?[A-Za-z0-9_./+=-]{12,}"),
]
forbidden_write_tool_names = {"Edit", "Write", "NotebookEdit"}

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
if "unknown command" in err_text.lower() or "unknown agent" in err_text.lower():
    raise SystemExit(f"Claude cross-host fallback live saw unavailable command/agent in stderr: {err_text[:2000]!r}")

errors = []
lens_task_uses = defaultdict(list)
codex_agent_uses = []
codex_bash_uses = []
unexpected_write_uses = []
permission_denials = []
non_user_text_parts = []

with open(out_path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        text = collect_text(data)
        if any(pattern.search(text) for pattern in secret_patterns):
            raise SystemExit(f"Claude cross-host fallback live transcript exposed a secret-like value near line {index}")
        if data.get("type") == "assistant":
            non_user_text_parts.append(text)
            for part in data.get("message", {}).get("content", []):
                if part.get("type") == "tool_use" and part.get("name") in forbidden_write_tool_names:
                    unexpected_write_uses.append((index, part.get("name"), collect_text(part.get("input", ""))[:1000]))
                if part.get("type") == "tool_use" and part.get("name") == "Bash":
                    command = str(part.get("input", {}).get("command", ""))
                    if "codex-companion.mjs" in command or "codex" in command.lower():
                        codex_bash_uses.append((index, command[:500]))
                if part.get("type") == "tool_use" and part.get("name") in {"Agent", "Task"}:
                    payload = part.get("input", {})
                    payload_text = collect_text(payload)
                    subagent_type = str(payload.get("subagent_type", ""))
                    if "codex" in subagent_type.lower():
                        codex_agent_uses.append((index, subagent_type, payload_text[:1000]))
                        continue
                    matched = [
                        lens for lens, marker in expected_lens_markers.items()
                        if marker in payload_text
                    ]
                    if len(matched) == 1:
                        lens_task_uses[matched[0]].append((index, payload_text))
                if part.get("type") == "text":
                    non_user_text_parts.append(part.get("text", ""))
        tool_result = data.get("tool_use_result") or {}
        if isinstance(tool_result, dict) and tool_result.get("agentType", ""):
            non_user_text_parts.append(collect_text(tool_result))
        if data.get("type") == "system":
            non_user_text_parts.append(text)
        if data.get("type") == "result":
            permission_denials.extend(data.get("permission_denials") or [])
            non_user_text_parts.append(str(data.get("result", "")))
            if data.get("is_error") is True:
                errors.append((index, str(data.get("result", ""))[:1000]))

if errors:
    raise SystemExit(f"Claude cross-host fallback live returned errors: {errors!r}")
if unexpected_write_uses:
    raise SystemExit(f"Claude cross-host fallback live used write-capable tools: {unexpected_write_uses!r}")
if permission_denials:
    raise SystemExit(f"Claude cross-host fallback live had permission denials: {permission_denials!r}")

# Wrong-surface guard: the fallback path, not the cross-host hop, must have run.
if codex_agent_uses:
    raise SystemExit(
        "Claude cross-host fallback live took the cross-host path instead of the "
        f"Same-Host Parallel Fallback (codex agent dispatched): {codex_agent_uses!r}"
    )
if codex_bash_uses:
    raise SystemExit(
        "Claude cross-host fallback live invoked a Codex/opposite-host command instead "
        f"of staying same-host: {codex_bash_uses!r}"
    )

non_user_text = "\n".join(non_user_text_parts)
lower_non_user_text = non_user_text.lower()
for marker in forbidden_crosshost_markers:
    if marker.lower() in lower_non_user_text:
        raise SystemExit(
            "Claude cross-host fallback live exposed an opposite-host success marker "
            f"(cross-host path taken, not the fallback): {marker!r}"
        )

# Two distinct same-host lens agents (two agents, not one pass).
missing_lenses = sorted(set(expected_lens_markers) - set(lens_task_uses))
if missing_lenses:
    raise SystemExit(
        "Claude cross-host fallback live did not dispatch both same-host lens agents; "
        f"missing={missing_lenses!r} got={ {k: len(v) for k, v in lens_task_uses.items()} !r}"
    )
duplicate_lenses = {lens: uses for lens, uses in lens_task_uses.items() if len(uses) != 1}
if duplicate_lenses:
    raise SystemExit(
        f"Claude cross-host fallback live expected exactly one task per same-host lens: {duplicate_lenses!r}"
    )

# Final synthesized success marker and its required content.
success_text = "\n".join(
    part for part in non_user_text_parts
    if "OH_NO_XHOST_FALLBACK_OK" in part
)
if not success_text:
    raise SystemExit("Claude cross-host fallback live did not return success marker OH_NO_XHOST_FALLBACK_OK")
lower_success_text = success_text.lower()
for marker in required_final_markers:
    if marker.lower() not in lower_success_text:
        raise SystemExit(f"Claude cross-host fallback live missing final marker/text: {marker!r}")

# At least one synthesis marker across the transcript. The model may legitimately
# reference the marker more than once (e.g. a synthesis heading plus the final
# OH_NO_XHOST_FALLBACK_OK summary); a raw "exactly one" count is brittle. The
# required_synthesis_fields check below proves a real synthesis block exists, not
# just a marker echo, and the dispatch-based two-lens guard above stays strict.
synthesis_count = non_user_text.count("OH_NO_XHOST_FALLBACK_SYNTHESIS")
if synthesis_count < 1:
    raise SystemExit(
        f"Claude cross-host fallback live expected at least one synthesis marker, got {synthesis_count}"
    )
for field in required_synthesis_fields:
    if field.lower() not in lower_success_text:
        raise SystemExit(f"Claude cross-host fallback live missing synthesis field: {field!r}")

# Fallback note: the opposite host was treated as unavailable.
if not (
    ("unavailable" in lower_success_text)
    and ("same-host" in lower_success_text or "same host" in lower_success_text)
    and ("opposite host" in lower_success_text or "codex" in lower_success_text)
):
    raise SystemExit(
        "Claude cross-host fallback live missing fallback note that the opposite host was "
        f"unavailable and the review ran via the Same-Host Parallel Fallback; success_text={success_text[:2000]!r}"
    )

# Lightweight contract pre-check (deep-live-style read-only assertion).
deep_text = "\n".join(
    part for part in non_user_text_parts
    if "OH_NO_CLAUDE_DEEP_OK" in part
)
if not deep_text:
    raise SystemExit(
        "Claude cross-host fallback live did not return the contract pre-check marker "
        "OH_NO_CLAUDE_DEEP_OK cross-host-fallback"
    )
lower_deep_text = deep_text.lower()
for needle in (
    "exactly two same-host agents",
    "require-cross-host",
):
    if needle not in lower_deep_text:
        raise SystemExit(
            f"Claude cross-host fallback live contract pre-check missing {needle!r}; deep_text={deep_text[:2000]!r}"
        )

summary = {
    "status": "passed",
    "model": model,
    "same_host_lens_agents": [
        {"lens": lens, "returned_marker": expected_lens_markers[lens]}
        for lens in sorted(lens_task_uses)
    ],
    "opposite_host": "unavailable",
    "codex_agent_uses": len(codex_agent_uses),
    "synthesis_marker": "OH_NO_XHOST_FALLBACK_SYNTHESIS",
    "final_marker": "OH_NO_XHOST_FALLBACK_OK",
    "contract_precheck_marker": "OH_NO_CLAUDE_DEEP_OK cross-host-fallback",
}
Path(summary_path).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print("ok - live Claude cross-host Same-Host Parallel Fallback dispatched two same-host lens agents and synthesized")
PY
}

run_cross_host_review_live_test() {
  if [[ "$RUN_CROSS_HOST_REVIEW_LIVE" != "1" ]]; then
    log "Skipping live Claude cross-host code-review PAIR smoke test"
    printf 'Run with --cross-host-review-live or OH_NO_CROSS_HOST_REVIEW_LIVE=1 to verify the opposite-host-available cross-host code-review pair (current-host oh-no-harness:code-reviewer plus opposite-host oh-no-harness:code-reviewer-codex, dispatched concurrently and synthesized into one verdict).\n' >&2
    return
  fi

  log "Running live Claude cross-host code-review PAIR smoke test (${LIVE_LOAD_MODE}, model ${FUSION_RESCUE_LIVE_MODEL})"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/cross-host-review-claude.jsonl"
  local err_file="$RUN_DIR/cross-host-review-claude.err"
  local summary_file="$RUN_DIR/cross-host-review-claude.summary.json"
  local read_root="$PLUGIN_ROOT"

  if [[ "$LIVE_LOAD_MODE" == "installed" ]]; then
    read_root="$(cached_plugin_root)"
  fi

  # NOTE: unquoted heredoc (expands ${read_root}/${PLUGIN_NAME}) inside $(...).
  # Bash tracks single-quote parity across the whole substitution, so the prompt
  # text MUST NOT contain apostrophes or an unintended $ (both break `bash -n`).
  local prompt
  prompt=$(cat <<PROMPT
/${PLUGIN_NAME}:simplify --review require-cross-host read-only live cross-host code-review PAIR smoke test only. Do not edit files, do not create artifacts, do not install plugins, and do not run any write-capable command.

Named THOROUGH trigger: security-sensitive public authentication contract review. Read ${read_root}/docs/platforms/claude-code.md Cross-Host Consult Channel before dispatch; pairing is trigger-driven, not availability-driven.

First, read ${read_root}/docs/shared/cross-host-review.md, paying attention to its "## Parallel Execution And Synthesis", "## Role-Owned Review Instances", and "## Reuse Of The Cross-Host Mechanism" sections, and read ${read_root}/docs/platforms/claude-code-runtime.md paying attention to its "## Cross-Host Consult Channel" section. In this run the opposite host (Codex) is AVAILABLE and authorized: the oh-no-harness:code-reviewer-codex cross-host consult agent and its node codex-companion.mjs transport are available. Run the code-reviewer role as a CROSS-HOST review pair, NOT the Same-Host Parallel Fallback. Exercise ONLY the cross-host code-reviewer pair: dispatch no other role (no verifier, explore, analyst, planner, debugger, or plan-reviewer) and no other opposite-host consult agent.

The diff under review (treat as the stable diff):
--- a/session.py
+++ b/session.py
@@
-def verify_token(token, expected):
-    return token == expected
+def verify_token(token, expected):
+    if token == expected:
+        return True
+    return len(token) == len(expected)
The reviewed change weakens token verification: on a mismatch it now returns True whenever the two lengths match, which is an authentication bypass. Every review instance must analyze this security regression meaningfully (authentication bypass, constant-time comparison, correctness, and test coverage) rather than only stating the smoke test is formatted correctly.

Dispatch BOTH review instances of the SAME code-reviewer role CONCURRENTLY, starting both before waiting for either result:

Current-host instance: a Claude current-host subagent using subagent_type oh-no-harness:code-reviewer. Its task prompt must include exactly these lines: Instance: current-host; Marker: OH_NO_XHOST_REVIEW_CURRENT_OK; Scope: the fixed session.py diff only; Do not edit files; Do not make any cross-host or opposite-host call; Run the complete code-reviewer role over the diff; Expected output: marker line plus findings with file, line, issue, severity, evidence, and recommended fix.

Opposite-host instance: exactly one Codex response through the dedicated read-only consult agent, dispatched with subagent_type oh-no-harness:code-reviewer-codex. A valid live result requires oh-no-harness:code-reviewer-codex to perform exactly one required Bash call to node codex-companion.mjs task in the foreground, wait for completion, and return the Codex companion stdout; a marker generated locally by the wrapper, a background acknowledgement, or a status pointer is not valid. The harness parser, not you, verifies the Bash event stream and codex-companion stdout after the run, so do not poll status, fetch a deferred result, or run a second codex-companion or consult call for liveness. The codex-companion Bash command MUST NOT include --write and MUST NOT include --background; the code-reviewer-codex agent runs codex-companion read-only by design (no --write flag) and synchronously in the foreground, and a permission denial from an attempted --write command is a test failure even if a later retry succeeds. The code-reviewer-codex packet MUST use --prompt-file with a redacted packet that: is explicitly read-only with no edits, no writes, and no installs; forbids further rescue, another workflow skill, and any host-to-host call back to Claude or a third host (one cross-host hop); instructs Codex to dispatch the oh-no-code-reviewer role agent to run the complete code-reviewer role over this same session.py diff; and requires Codex to return the role-owned result of oh-no-code-reviewer plus role-ownership proof that oh-no-code-reviewer, not a parent inline Codex answer, produced it, ending with exactly the marker OH_NO_XHOST_REVIEW_CODEX_RETURN_OK. If oh-no-harness:code-reviewer-codex cannot run exactly one node codex-companion.mjs Bash call in the foreground, or cannot prove oh-no-code-reviewer role ownership, do not synthesize success.

Start both instances before waiting when possible. Wait for both results and do not end while a worker is still pending. After the current-host oh-no-harness:code-reviewer subagent and the single opposite-host oh-no-harness:code-reviewer-codex consult both return, synthesize immediately as the current-host main judge into ONE merged findings verdict rather than concatenate: merge the two finding sets, deduplicate by file and line, and record host provenance on each finding. The final answer must contain exactly the marker OH_NO_CLAUDE_CROSS_HOST_REVIEW_OK and must include, as its own lines: both instances dispatched: current-host code-reviewer and opposite-host code-reviewer-codex; started-concurrently: yes; opposite-host codex-companion foreground read-only call: yes; role ownership (oh-no-code-reviewer) proven: yes; synthesized one verdict: yes; the instance markers OH_NO_XHOST_REVIEW_CURRENT_OK and OH_NO_XHOST_REVIEW_CODEX_RETURN_OK; and a single merged findings block recording consensus, contradictions, unique insights, blind spots, and recommended next action.
PROMPT
)

  local cmd=(
    "$CLAUDE_BIN"
    --print
    --verbose
    --output-format stream-json
    --include-hook-events
    --model "$FUSION_RESCUE_LIVE_MODEL"
    --max-budget-usd "$FUSION_RESCUE_MAX_BUDGET_USD"
    --permission-mode bypassPermissions
    --allowedTools "Bash(node *)"
    --tools default
    --add-dir "$read_root"
    --no-session-persistence
    --system-prompt "You are a read-only live smoke test runner. Use the invoked Oh No Harness skill, one Claude current-host oh-no-harness:code-reviewer subagent, and the oh-no-harness:code-reviewer-codex read-only consult agent only for this requested cross-host code-review pair. The opposite host (Codex) is available. Do not edit files."
  )

  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi

  "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

  "$PYTHON_BIN" - "$out_file" "$err_file" "$summary_file" "$FUSION_RESCUE_LIVE_MODEL" <<'PY'
import json
import re
import sys
from pathlib import Path

out_path, err_path, summary_path, model = sys.argv[1:5]

CURRENT_MARKER = "OH_NO_XHOST_REVIEW_CURRENT_OK"
CODEX_RETURN_MARKER = "OH_NO_XHOST_REVIEW_CODEX_RETURN_OK"
FINAL_MARKER = "OH_NO_CLAUDE_CROSS_HOST_REVIEW_OK"
CURRENT_ROLE = "oh-no-harness:code-reviewer"
CODEX_ROLE = "oh-no-harness:code-reviewer-codex"
CODEX_SIDE_ROLE = "oh-no-code-reviewer"

required_final_markers = [
    FINAL_MARKER,
    CURRENT_MARKER,
    CODEX_RETURN_MARKER,
    "current-host code-reviewer",
    "opposite-host code-reviewer-codex",
    "started-concurrently: yes",
    "foreground read-only call: yes",
    CODEX_SIDE_ROLE,
    "synthesized one verdict: yes",
]
required_synthesis_fields = [
    "consensus",
    "contradictions",
    "unique insights",
    "blind spots",
    "recommended next action",
]
secret_patterns = [
    re.compile(r"(?<![A-Za-z0-9])sk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"(?i)(api[_-]?key|access[_-]?token|refresh[_-]?token|private[_-]?key|cookie)[ \t]*[:=][ \t]*['\"]?[A-Za-z0-9_./+=-]{12,}"),
]
forbidden_write_tool_names = {"Edit", "Write", "NotebookEdit"}

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
if "unknown command" in err_text.lower() or "unknown agent" in err_text.lower():
    raise SystemExit(f"Claude cross-host review live saw unavailable command/agent in stderr: {err_text[:2000]!r}")

init_agents = set()
init_tools = set()
errors = []
current_dispatches = []            # (index, payload_text)
codex_dispatches = []              # (index, payload_text)
unexpected_write_uses = []
codex_bash_tool_ids = set()
codex_write_commands = []
codex_background_commands = []
codex_bash_success_texts = []
codex_bash_success_indexes = []
codex_bash_failures = []
permission_denials = []
non_user_text_parts = []
pending_background_events = []
# Concurrency lifecycle for the two reviewer instances only. A task_started per
# reviewer subagent + a task_notification(status=="completed") per reviewer lets
# the peak-in-flight walk below prove the two instances overlapped (a serial run
# peaks at 1). Mirrors the parallel/fusion lanes' concurrency-detection approach.
reviewer_task_ids = set()
reviewer_started_indices = []
reviewer_completed_ids = set()
reviewer_completion_indices = []

with open(out_path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        text = collect_text(data)
        if data.get("type") == "system" and (
            "Command running in background" in text
            or ("Codex task" in text and "still running" in text)
        ):
            pending_background_events.append((index, text[:2000]))
        if any(pattern.search(text) for pattern in secret_patterns):
            raise SystemExit(f"Claude cross-host review live transcript exposed a secret-like value near line {index}")
        if data.get("type") == "system" and data.get("subtype") == "init":
            init_agents.update(data.get("agents", []))
            init_tools.update(data.get("tools", []))
        if data.get("type") == "assistant":
            non_user_text_parts.append(text)
            for part in data.get("message", {}).get("content", []):
                if part.get("type") == "tool_use" and part.get("name") in forbidden_write_tool_names:
                    unexpected_write_uses.append((index, part.get("name"), collect_text(part.get("input", ""))[:1000]))
                if part.get("type") == "tool_use" and part.get("name") == "Bash":
                    command = str(part.get("input", {}).get("command", ""))
                    if "codex-companion.mjs" in command:
                        # The --write/--background forbids cover EVERY
                        # codex-companion command, including a rogue call that
                        # inlines the packet instead of using --prompt-file.
                        if re.search(r"(?<!\S)--write(?!\S)", command):
                            codex_write_commands.append((index, command[:2000]))
                        if re.search(r"(?<!\S)--background(?!\S)", command):
                            codex_background_commands.append((index, command[:2000]))
                        # Count only the actual delegation `task` call (which
                        # passes the packet via --prompt-file), not the read-only
                        # companion-path resolution probes (ls / [ -f ] / versions
                        # checks) the kernel runs first to resolve/verify the
                        # companion before delegating.
                        if "--prompt-file" in command:
                            codex_bash_tool_ids.add(part.get("id"))
                if part.get("type") == "tool_use" and part.get("name") in {"Agent", "Task"}:
                    payload = part.get("input", {})
                    payload_text = collect_text(payload)
                    subagent_type = str(payload.get("subagent_type", ""))
                    if subagent_type == CODEX_ROLE:
                        codex_dispatches.append((index, payload_text))
                    elif subagent_type == CURRENT_ROLE:
                        current_dispatches.append((index, payload_text))
                if part.get("type") == "text":
                    non_user_text_parts.append(part.get("text", ""))
        if data.get("type") == "system" and data.get("subtype") == "task_started":
            started_type = str(data.get("subagent_type", "") or "")
            if started_type in {CURRENT_ROLE, CODEX_ROLE}:
                reviewer_task_ids.add(data.get("task_id"))
                reviewer_started_indices.append((index, data.get("task_id")))
        if data.get("type") == "system" and data.get("subtype") in {"task_updated", "task_notification"}:
            # Some task_updated events carry status under patch.status (see the
            # natural-session lane precedent); accept both so a completion is
            # never silently dropped.
            if (data.get("status") or (data.get("patch") or {}).get("status")) == "completed":
                completed_task_id = data.get("task_id")
                if (
                    completed_task_id in reviewer_task_ids
                    and completed_task_id not in reviewer_completed_ids
                ):
                    reviewer_completed_ids.add(completed_task_id)
                    reviewer_completion_indices.append((index, completed_task_id))
            non_user_text_parts.append(text)
        if data.get("type") == "user":
            for part in data.get("message", {}).get("content", []):
                if not isinstance(part, dict):
                    continue
                if part.get("tool_use_id") not in codex_bash_tool_ids:
                    continue
                result_text = collect_text(part)
                if "Command running in background" in result_text or (
                    "Codex task" in result_text and "still running" in result_text
                ):
                    raise SystemExit(
                        "Claude cross-host review live codex-companion Bash did not complete "
                        f"in the foreground: {result_text[:1000]!r}"
                    )
                if bool(part.get("is_error")):
                    codex_bash_failures.append((index, result_text[:1000]))
                else:
                    codex_bash_success_indexes.append(index)
                    codex_bash_success_texts.append(result_text)
        tool_result = data.get("tool_use_result") or {}
        if isinstance(tool_result, dict) and tool_result.get("agentType", ""):
            non_user_text_parts.append(collect_text(tool_result))
        if data.get("type") == "result":
            permission_denials.extend(data.get("permission_denials") or [])
            non_user_text_parts.append(str(data.get("result", "")))
            if data.get("is_error") is True:
                errors.append((index, str(data.get("result", ""))[:1000]))

if errors:
    raise SystemExit(f"Claude cross-host review live returned errors: {errors!r}")
if unexpected_write_uses:
    raise SystemExit(f"Claude cross-host review live used write-capable tools: {unexpected_write_uses!r}")
if codex_write_commands:
    raise SystemExit(f"Claude cross-host review live invoked codex-companion with --write: {codex_write_commands!r}")
if codex_background_commands:
    raise SystemExit(f"Claude cross-host review live invoked codex-companion with --background: {codex_background_commands!r}")
if permission_denials:
    raise SystemExit(f"Claude cross-host review live had permission denials: {permission_denials!r}")

# The dedicated opposite-host consult agent must be exposed by the plugin load.
if CODEX_ROLE not in init_agents:
    raise SystemExit(
        f"Claude cross-host review live did not expose {CODEX_ROLE} agent; "
        f"got={sorted(agent for agent in init_agents if 'code-reviewer' in agent)!r}"
    )
if not ({"Task", "Agent", "Workflow"} & init_tools):
    raise SystemExit(f"Claude cross-host review live did not expose subagent tooling; tools={sorted(init_tools)!r}")

# (a) BOTH instances of the same reviewer role were dispatched (exactly one each).
if len(current_dispatches) != 1:
    raise SystemExit(
        f"Claude cross-host review live expected exactly one {CURRENT_ROLE} dispatch, got {current_dispatches!r}"
    )
if len(codex_dispatches) != 1:
    raise SystemExit(
        f"Claude cross-host review live expected exactly one {CODEX_ROLE} dispatch, got {codex_dispatches!r}"
    )

# The outbound opposite-host packet must preserve role ownership + read-only.
codex_payload = codex_dispatches[0][1]
for marker in (CODEX_SIDE_ROLE, CODEX_RETURN_MARKER, "read-only"):
    if marker.lower() not in codex_payload.lower():
        raise SystemExit(
            f"Claude cross-host review live code-reviewer-codex packet missed role-ownership marker {marker!r}; "
            f"payload={codex_payload[:2000]!r}"
        )

# (b) The two reviewer instances were started concurrently (peak in-flight >= 2).
# A purely serial run (start, complete, start, complete) never exceeds 1 in flight.
CONCURRENCY_MIN = 2
lifecycle = sorted(
    [(idx, 1) for idx, _ in reviewer_started_indices]
    + [(idx, -1) for idx, _ in reviewer_completion_indices]
)
in_flight = 0
peak_in_flight = 0
for _, delta in lifecycle:
    in_flight += delta
    if in_flight > peak_in_flight:
        peak_in_flight = in_flight
if peak_in_flight < CONCURRENCY_MIN:
    raise SystemExit(
        "Claude cross-host review live did not prove the reviewer pair was dispatched "
        f"concurrently: peak in-flight reviewer instances was {peak_in_flight} (need >= {CONCURRENCY_MIN}); "
        f"started={len(reviewer_started_indices)} completed={len(reviewer_completion_indices)}. "
        "A purely serial run peaks at 1 in flight."
    )

# (c) The code-reviewer-codex made exactly one read-only foreground codex-companion call.
if not codex_bash_tool_ids:
    raise SystemExit("Claude cross-host review live did not invoke codex-companion.mjs through oh-no-harness:code-reviewer-codex Bash")
if len(codex_bash_tool_ids) != 1:
    raise SystemExit(f"Claude cross-host review live expected exactly one codex-companion.mjs Bash invocation, got {sorted(codex_bash_tool_ids)!r}")
if codex_bash_failures:
    raise SystemExit(f"Claude cross-host review live codex-companion Bash failed: {codex_bash_failures!r}")
if len(codex_bash_success_indexes) != 1:
    raise SystemExit(f"Claude cross-host review live expected exactly one successful codex-companion.mjs Bash result, got {codex_bash_success_indexes!r}")

# (d) The returned opposite-host result proves oh-no-code-reviewer role ownership.
codex_bash_text = "\n".join(codex_bash_success_texts)
if CODEX_RETURN_MARKER not in codex_bash_text:
    raise SystemExit(
        f"Claude cross-host review live did not capture {CODEX_RETURN_MARKER} from codex-companion.mjs stdout"
    )
if CODEX_SIDE_ROLE not in codex_bash_text.lower():
    raise SystemExit(
        "Claude cross-host review live codex-companion stdout did not prove "
        f"{CODEX_SIDE_ROLE} role ownership (possible parent inline Codex answer)"
    )
last_codex_bash_success_index = max(codex_bash_success_indexes) if codex_bash_success_indexes else None
late_pending_background_events = [
    event for event in pending_background_events
    if last_codex_bash_success_index is None or event[0] > last_codex_bash_success_index
]
if late_pending_background_events:
    raise SystemExit(
        "Claude cross-host review live left background/still-running work after the Codex "
        f"foreground completion: {late_pending_background_events!r}"
    )

# (e) Final synthesized success marker and its required merged-verdict content.
success_text = "\n".join(part for part in non_user_text_parts if FINAL_MARKER in part)
if not success_text:
    detail = f"; pending events={pending_background_events!r}" if pending_background_events else ""
    raise SystemExit(f"Claude cross-host review live did not return success marker {FINAL_MARKER}{detail}")
lower_success_text = success_text.lower()
for marker in required_final_markers:
    if marker.lower() not in lower_success_text:
        raise SystemExit(f"Claude cross-host review live missing final marker/text: {marker!r}")
for field in required_synthesis_fields:
    if field.lower() not in lower_success_text:
        raise SystemExit(f"Claude cross-host review live missing synthesis field: {field!r}")

summary = {
    "status": "passed",
    "model": model,
    "current_host_instance": {
        "subagent_type": CURRENT_ROLE,
        "returned_marker": CURRENT_MARKER,
    },
    "opposite_host_instance": {
        "subagent_type": CODEX_ROLE,
        "codex_side_role": CODEX_SIDE_ROLE,
        "bash_tool_uses": len(codex_bash_tool_ids),
        "returned_marker": CODEX_RETURN_MARKER,
        "permission_denials": len(permission_denials),
    },
    "started_concurrently": True,
    "peak_in_flight": peak_in_flight,
    "final_marker": FINAL_MARKER,
}
Path(summary_path).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print("ok - live Claude cross-host code-review pair dispatched oh-no-harness:code-reviewer + oh-no-harness:code-reviewer-codex concurrently (read-only foreground codex-companion, role-owned oh-no-code-reviewer) and synthesized one verdict")
PY
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
    "${cmd[@]}" "$prompt"
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
    re.compile(r"(?<![A-Za-z0-9])sk-[A-Za-z0-9_-]{20,}"),
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
executor_direction_gaps = []
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
                            executor_direction_gaps.append((index, matched[0], missing_direction))
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

if executor_direction_gaps:
    raise SystemExit(
        "Claude parallel-executor live failed Direction Contract carry-forward "
        f"into executor packets: {executor_direction_gaps!r}"
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

run_codex_executor_delegation_live_test() {
  if [[ "$RUN_CODEX_EXECUTOR_DELEGATION_LIVE" != "1" ]]; then
    log "Skipping live Claude codex-executor delegation smoke test"
    printf 'Run with --codex-executor-delegation-live to verify ralph dispatches an eligible outer executor-codex overlap, preserves one foreground raw companion call per slice, keeps caller attribution and escape guards, drives RED->GREEN, enforces executor-only routing, and performs caller-mediated sequential degrade fallback.\n' >&2
    return
  fi

  log "Running live Claude codex-executor delegation smoke test (${LIVE_LOAD_MODE}, model ${FUSION_RESCUE_LIVE_MODEL})"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/codex-executor-delegation.jsonl"
  local err_file="$RUN_DIR/codex-executor-delegation.err"
  local degrade_out_file="$RUN_DIR/codex-executor-delegation-degrade.jsonl"
  local degrade_err_file="$RUN_DIR/codex-executor-delegation-degrade.err"
  local summary_file="$RUN_DIR/codex-executor-delegation.summary.json"

  # PINNED feature-runtime worktree slug, DISTINCT from this plan's implementation
  # worktree slug (codex-executor-delegation) per QC-N3/Q5 so discovery is
  # deterministic and never collides with the run that authored this lane.
  local owned_slug="codex-executor-delegation-runtime"
  local sibling_slug="codex-executor-delegation-sibling"

  # Private, write-capable INTEGRATION CHECKOUT outside this repo/marketplace. It is
  # a real git repo so the caller-owned escape guard's git-status arm and the worktree
  # attribution snapshot operate on real surfaces (never a hand-built dict).
  local integration
  integration="$(mktemp -d)"
  local _codex_deleg_cleanup_done=0
  _codex_deleg_cleanup() {
    if [[ "$_codex_deleg_cleanup_done" == "0" && -n "$integration" && -d "$integration" ]]; then
      # Remove registered worktrees first so the base repo removal is clean.
      git -C "$integration" worktree remove --force ".oh-no/worktrees/$owned_slug" >/dev/null 2>&1 || true
      git -C "$integration" worktree remove --force ".oh-no/worktrees/$sibling_slug" >/dev/null 2>&1 || true
      rm -rf "$integration"
      _codex_deleg_cleanup_done=1
    fi
  }
  trap '_codex_deleg_cleanup' RETURN EXIT INT TERM

  (
    cd "$integration"
    git init -q
    git config user.email codex-executor-delegation@example.com
    git config user.name "codex-executor-delegation smoke"
    mkdir -p src tests .oh-no/plans .oh-no/sessions .oh-no/test-runs
    # gitignore .oh-no/ so the synthetic repo mirrors PRODUCTION: `git status` is blind
    # to the .oh-no/ subtree, so the caller guard's filesystem SENTINEL arm (not the
    # git-status arm) is what covers it here, exactly as at feature runtime (C1
    # corollary). Without this the .oh-no/ subtree would be tracked and the lane would
    # not exercise the sentinel arm the way production does.
    printf '.oh-no/\n' >.gitignore
    printf 'def add(x, y):\n    raise NotImplementedError\n' >src/calc.py
    printf 'from src.calc import add\n\n\ndef test_add():\n    assert add(2, 3) == 5\n' >tests/test_calc.py
    printf 'plan seed\n' >.oh-no/plans/seed.md
    git add -A
    git commit -qm "seed: failing RED test for the delegated slice"
    # Register the delegated slice's worktree AND a sibling worktree from the
    # integration checkout (never nested inside another worktree), per
    # worktree-isolation.md. The sibling proves the caller guard covers siblings.
    git worktree add -q ".oh-no/worktrees/$owned_slug" -b "$owned_slug" >/dev/null
    git worktree add -q ".oh-no/worktrees/$sibling_slug" -b "$sibling_slug" >/dev/null
  )

  local worktree="$integration/.oh-no/worktrees/$owned_slug"
  local red_file="$worktree/tests/test_calc.py"

  # ATTRIBUTION: worktree git state + RED-file hash captured immediately BEFORE the
  # delegated call, so the in-worktree delta is provably Codex's and the RED file
  # can be proven byte-UNCHANGED afterwards.
  local worktree_status_before red_hash_before red_rc_before
  worktree_status_before="$(git -C "$worktree" status --porcelain 2>/dev/null || true)"
  red_hash_before="$("$PYTHON_BIN" - "$red_file" <<'PY'
import hashlib, sys
print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())
PY
)"
  # RED must fail BEFORE Codex's patch.
  red_rc_before=0
  ( cd "$worktree" && "$PYTHON_BIN" -m pytest -q tests/test_calc.py ) >/dev/null 2>&1 || red_rc_before=$?
  if [[ "$red_rc_before" == "0" ]]; then
    _codex_deleg_cleanup
    trap - RETURN EXIT INT TERM
    fail "codex-executor delegation live: RED test unexpectedly passed before the delegated patch (no RED to drive)"
  fi

  # CALLER-OWNED ESCAPE GUARD pre-snapshot of the protected target set (integration
  # git-status + filesystem sentinel over the ignored .oh-no/ subtree and each
  # sibling worktree, EXCLUDING the delegated slice's own worktree). This is the
  # SAME pure function the offline firing test (test 0) exercises.
  local pre_snapshot
  pre_snapshot="$(snapshot "$integration" "$owned_slug")"

  # Enable the codexExecutor toggle in a throwaway config dir so the SessionStart
  # delegation block fires for this run only.
  local config_dir
  config_dir="$(mktemp -d)"
  OH_NO_CONFIG_DIR="$config_dir" "$PLUGIN_ROOT/scripts/oh-no-config" codex-executor on >/dev/null

  # Two genuinely disjoint executor-eligible slices so outer overlap can be
  # observed without changing Ralph's existing eligibility rules.
  local prompt
  prompt=$(cat <<PROMPT
Use ${PLUGIN_NAME}:ralph in STANDARD mode with the codexExecutor delegation toggle ON. Work entirely inside the registered task worktree at ${worktree}; do not touch the integration checkout at ${integration}, its .oh-no/ subtree, or the sibling worktree at ${integration}/.oh-no/worktrees/${sibling_slug}.

Direction Contract: requirements source is this approved smoke packet; primary goal is AC-OVERLAP-1, reuse Ralph existing verified disjoint eligibility decision to allow eligible outer executor overlap; non-goals are no new scheduler, state machine, protocol, Git oracle, duplicate fixture system, or concurrent fallback/commit/integration; constraints are each inner companion remains foreground and single-shot while fallback, commit, and integration remain serial; direction changes require explicit caller approval. Carry AC-OVERLAP-1 and these non-goals into the Ralph session, every executor/reviewer/verifier packet, and the final summary.

There are two disjoint executor-eligible slices. Slice 1: implement add(x, y) in src/calc.py so tests/test_calc.py passes; the marker for this slice is OH_NO_CODEX_DELEG_SLICE_1. Slice 2: add a module docstring to a sibling helper file src/util.py containing the marker OH_NO_CODEX_DELEG_SLICE_2. The two slices touch different files and neither depends on the other.

Delegation contract: when you dispatch the executor role, dispatch oh-no-harness:executor-codex (NOT the native oh-no-harness:executor and NOT codex:codex-rescue). executor-codex is a thin transport: it returns raw Codex stdout and must not calculate snapshots, escape verdicts, changed files, or verification evidence. YOU are the caller: derive the worktree diff, own the protected-target escape guard, and halt before merge on an unexpected target change. Do NOT author RED, verify, review, or merge on the executor-codex channel; keep RED authoring, every test/lint/build/parse/typecheck command, verification (oh-no-harness:verifier), and review (oh-no-harness:code-reviewer) on the native independent roles. Each executor-codex packet may carry the read-only RED path for context but MUST NOT ask Codex to run a verification command, report a test outcome, or put caller verification commands/outcomes in <done_when>; require the exact final stdout line "Verification: not run (caller-owned)". Do NOT modify tests/test_calc.py (the RED file). Apply the existing Ralph eligibility, Batch Rule, and Isolation Contract without inventing a separate scheduler.

When both slices are implemented, RED goes green, and a native verifier and native code-reviewer have run, restate AC-OVERLAP-1 and the non-goals unchanged, emit the exact token OH_NO_CODEX_DELEG_POST_CHECK followed by, for each slice, the file it owns and its marker, then emit the exact final marker OH_NO_CODEX_DELEG_OK on its own line.
PROMPT
)

  local cmd=(
    "$CLAUDE_BIN"
    --print
    --verbose
    --output-format stream-json
    --include-hook-events
    --model "$FUSION_RESCUE_LIVE_MODEL"
    --max-budget-usd "$FUSION_RESCUE_MAX_BUDGET_USD"
    --permission-mode bypassPermissions
    --add-dir "$integration"
    --tools default
    --no-session-persistence
    --system-prompt "You are a live smoke test runner for an Oh No Harness codex-executor delegation run. Write only inside the registered task worktree at ${worktree}. Do not edit, create, or delete any file in the integration checkout, its .oh-no/ subtree, or the sibling worktree. Do not install plugins."
  )
  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi

  local run_rc=0
  if (
    cd "$worktree"
    CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" OH_NO_CONFIG_DIR="$config_dir" "${cmd[@]}" "$prompt"
  ) >"$out_file" 2>"$err_file"; then
    run_rc=0
  else
    run_rc=$?
    log "Claude codex-executor delegation live invocation exited non-zero (rc=$run_rc); proceeding to parser for diagnosis"
  fi

  # CALLER-OWNED ESCAPE GUARD post-snapshot + verdict. A HALT is a HARD/GATING failure
  # (unexpected integration-checkout / ignored-.oh-no/ / sibling-worktree write),
  # modeled on the fusion lane's stream assertions — NOT the model-variance WARN.
  local post_snapshot escape_verdict escape_rc
  post_snapshot="$(snapshot "$integration" "$owned_slug")"
  escape_rc=0
  escape_verdict="$(escape_net_verdict "$pre_snapshot" "$post_snapshot" "$owned_slug")" || escape_rc=$?

  # ATTRIBUTION AFTER: worktree delta is provably Codex's; RED file byte-UNCHANGED.
  local worktree_status_after red_hash_after red_rc_after
  worktree_status_after="$(git -C "$worktree" status --porcelain 2>/dev/null || true)"
  red_hash_after="$("$PYTHON_BIN" - "$red_file" <<'PY'
import hashlib, sys
print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())
PY
)"
  red_rc_after=0
  ( cd "$worktree" && "$PYTHON_BIN" -m pytest -q tests/test_calc.py ) >/dev/null 2>&1 || red_rc_after=$?

  # HARD gate: caller-owned escape guard.
  if [[ "$escape_rc" != "0" ]]; then
    _codex_deleg_cleanup
    rm -rf "$config_dir"
    trap - RETURN EXIT INT TERM
    fail "codex-executor delegation live: caller-owned escape guard HALTed on a protected-target-set write: ${escape_verdict}"
  fi
  # HARD gate: RED file byte-UNCHANGED (Codex must not mutate the RED test file).
  if [[ "$red_hash_before" != "$red_hash_after" ]]; then
    _codex_deleg_cleanup
    rm -rf "$config_dir"
    trap - RETURN EXIT INT TERM
    fail "codex-executor delegation live: RED file was mutated by the delegated run (before=${red_hash_before} after=${red_hash_after})"
  fi
  # HARD gate: RED->GREEN (RED failed before, passes after Codex's patch).
  if [[ "$red_rc_after" != "0" ]]; then
    _codex_deleg_cleanup
    rm -rf "$config_dir"
    trap - RETURN EXIT INT TERM
    fail "codex-executor delegation live: RED did not go GREEN after the delegated patch (pytest rc=${red_rc_after})"
  fi

  # DEGRADE sub-run: force the codex companion UNAVAILABLE DETERMINISTICALLY via the
  # OH_NO_CODEX_COMPANION_PATH override (the named ARCH-3 lever). Per the executor-codex
  # resolution contract, a set-but-NONEXISTENT OH_NO_CODEX_COMPANION_PATH takes
  # precedence and is treated as UNAVAILABLE (no fall-through to the cache), so
  # executor-codex signals `codex unavailable` and the CALLER (main ralph agent) falls
  # back to native oh-no-harness:executor and records a warning. executor-codex has no
  # dispatch tool, so it must NOT self-dispatch.
  local degrade_prompt
  degrade_prompt=$(cat <<PROMPT
Use ${PLUGIN_NAME}:ralph in STANDARD mode with the codexExecutor delegation toggle ON. Work only inside ${worktree}. Implement a one-line helper is_even(n) in src/util2.py that returns n % 2 == 0; marker OH_NO_CODEX_DELEG_DEGRADE_SLICE.

The codex companion is UNAVAILABLE in this run because the configured override path does not exist. First dispatch executor-codex exactly once. It must make its one foreground Bash resolution attempt, make no repository write, and return exactly "codex unavailable: companion-override-path-missing" with no other text. executor-codex must NOT self-dispatch.

After that exact failure result and BEFORE native fallback, YOU (the main ralph agent, the caller) must run one read-only Bash inspection command containing the literal shell comment "# OH_NO_CODEX_DELEG_DEGRADE_INSPECTION". That command must inspect partial task-worktree change with "git -C ${worktree} status --porcelain -- src/util2.py", inspect integration status with "git -C ${integration} status --porcelain", and inspect the protected .oh-no filesystem with "find ${integration}/.oh-no -not -path '${worktree}/*'". The src/util2.py porcelain section must be empty; the harness separately compares the caller-owned before/after protected-target snapshots.

Only after that inspection may YOU fall back to dispatching the native oh-no-harness:executor for the slice. The native executor must create src/util2.py with exactly three lines: a marker comment "# OH_NO_CODEX_DELEG_DEGRADE_SLICE", then "def is_even(n):", then four spaces followed by "return n % 2 == 0"; it must not omit the marker. Record a warning containing the exact token OH_NO_CODEX_DELEG_DEGRADE_FALLBACK. When the slice is done via the native executor fallback, emit the exact final marker OH_NO_CODEX_DELEG_DEGRADE_OK on its own line.
PROMPT
)
  # Caller-owned protected-target guard for the complete degrade attempt and
  # fallback. The owned task worktree is excluded, matching runtime policy.
  local degrade_pre_snapshot degrade_post_snapshot degrade_escape_verdict degrade_escape_rc
  degrade_pre_snapshot="$(snapshot "$integration" "$owned_slug")"

  local degrade_rc=0
  if (
    cd "$worktree"
    CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" OH_NO_CONFIG_DIR="$config_dir" \
      OH_NO_CODEX_COMPANION_PATH="$integration/.oh-no/nonexistent/codex-companion.mjs" \
      OH_NO_CODEX_COMPANION_CACHE_DIR="$integration/.oh-no/nonexistent-cache" \
      "${cmd[@]}" "$degrade_prompt"
  ) >"$degrade_out_file" 2>"$degrade_err_file"; then
    degrade_rc=0
  else
    degrade_rc=$?
    log "Claude codex-executor delegation degrade sub-run exited non-zero (rc=$degrade_rc); proceeding to parser for diagnosis"
  fi

  degrade_post_snapshot="$(snapshot "$integration" "$owned_slug")"
  degrade_escape_rc=0
  degrade_escape_verdict="$(escape_net_verdict "$degrade_pre_snapshot" "$degrade_post_snapshot" "$owned_slug")" || degrade_escape_rc=$?
  if [[ "$degrade_escape_rc" != "0" ]]; then
    _codex_deleg_cleanup
    rm -rf "$config_dir"
    trap - RETURN EXIT INT TERM
    fail "codex-executor delegation degrade sub-run: caller-owned escape guard HALTed before fallback completion: ${degrade_escape_verdict}"
  fi

  local parser_rc=0
  if OH_NO_CODEX_DELEG_WT_STATUS_BEFORE="$worktree_status_before" \
    OH_NO_CODEX_DELEG_WT_STATUS_AFTER="$worktree_status_after" \
    OH_NO_CODEX_DELEG_ESCAPE_VERDICT="$escape_verdict" \
    OH_NO_CODEX_DELEG_DEGRADE_ESCAPE_VERDICT="$degrade_escape_verdict" \
    "$PYTHON_BIN" - "$out_file" "$err_file" "$degrade_out_file" "$degrade_err_file" "$summary_file" <<'PY'
import json
import os
import re
import sys

out_path, err_path, degrade_out_path, degrade_err_path, summary_path = sys.argv[1:6]

WRITE_ROLE = "executor-codex"          # the delegated write-capable channel
NATIVE_EXECUTOR = "executor"           # native fallback role
SLICE_MARKERS = ("OH_NO_CODEX_DELEG_SLICE_1", "OH_NO_CODEX_DELEG_SLICE_2")
POST_CHECK_MARKER = "OH_NO_CODEX_DELEG_POST_CHECK"
FINAL_MARKER = "OH_NO_CODEX_DELEG_OK"
DEGRADE_FALLBACK_MARKER = "OH_NO_CODEX_DELEG_DEGRADE_FALLBACK"
DEGRADE_FINAL_MARKER = "OH_NO_CODEX_DELEG_DEGRADE_OK"
DEGRADE_INSPECTION_MARKER = "OH_NO_CODEX_DELEG_DEGRADE_INSPECTION"
DEGRADE_EXPECTED_FAILURE = "codex unavailable: companion-override-path-missing"
EXECUTOR_NO_VERIFY_LINE = "Verification: not run (caller-owned)"
DIRECTION_MARKERS = (
    "AC-OVERLAP-1",
    "no new scheduler",
    "state machine",
    "protocol",
    "Git oracle",
    "foreground",
    "single-shot",
    "serial",
)
# Roles that MUST NOT be routed to the write-capable executor-codex channel.
FORBIDDEN_ON_WRITE_CHANNEL = ("verifier", "code-reviewer", "reviewer", "merge")


def collect_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(item) for item in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(item) for item in value)
    return ""


def role_of(subagent_type):
    st = str(subagent_type or "")
    if st.startswith("oh-no-harness:"):
        return st.split(":", 1)[1]
    return st


def load_lines(path):
    rows = []
    with open(path, "r", encoding="utf-8") as fh:
        for index, line in enumerate(fh, 1):
            if not line.strip():
                continue
            rows.append((index, json.loads(line)))
    return rows


def delegated_result_text(content):
    """Return the role result, excluding Claude's host-added agent metadata."""
    if not isinstance(content, list):
        return collect_text(content)
    chunks = []
    for item in content:
        if not isinstance(item, dict) or item.get("type") != "text":
            continue
        value = str(item.get("text", ""))
        if value.startswith("agentId:") or value.startswith("<usage>"):
            continue
        chunks.append(value)
    return "\n".join(chunks)


def raw_equal(left, right):
    # Claude may normalize only the final newline when relaying a tool result.
    return left.rstrip("\n") == right.rstrip("\n")


COMPANION_INVOCATION_RE = re.compile(
    r'\bnode\s+(?:"\$\{?COMPANION\}?"|\$\{?COMPANION\}?|"?[^\s";|&]*codex-companion(?:\.mjs)?"?)'
    r'\s+([a-z][a-z0-9-]*)'
)


# ---- Primary delegated run ----
main_rows = load_lines(out_path)
with open(err_path, "r", encoding="utf-8") as fh:
    err_text = fh.read()
if "unknown command" in err_text.lower() or "unknown agent" in err_text.lower():
    raise SystemExit(f"codex-executor delegation live saw unavailable command/agent in stderr: {err_text[:2000]!r}")

init_ok = False
executor_codex_dispatches = []     # (index, payload_text, Agent tool-use id)
executor_codex_tool_ids = set()
outer_task_starts = {}             # Agent tool-use id -> [(index, task id)]
outer_task_notifications = {}      # Agent tool-use id -> [(index, task id, status, summary)]
invalid_executor_payloads = []
direction_packet_gaps = []
native_verifier_dispatches = []
native_code_reviewer_dispatches = []
codex_rescue_on_write = []
forbidden_write_channel = []       # (index, role)
executor_bash_calls = []           # (index, parent Task id, Bash tool-use id, command, background)
companion_bash_parents = {}        # Bash tool-use id -> executor Task id
companion_bash_outputs = {}        # Bash tool-use id -> [(index, is_error, text)]
invalid_companion_shapes = []      # wrong command count/subcommand/flags/redirect shape
primary_native_executor = []       # native oh-no-harness:executor dispatches (C3)
post_check_seen = False
final_marker_seen = False
final_marker_text = []
permission_denials = []
errors = []

for index, data in main_rows:
    if data.get("type") == "system" and data.get("subtype") == "init":
        agents = set(data.get("agents", []))
        init_ok = "Task" in data.get("tools", []) and "oh-no-harness:executor-codex" in agents
    if data.get("type") == "system" and data.get("subtype") == "task_started":
        tool_use_id = str(data.get("tool_use_id") or "")
        outer_task_starts.setdefault(tool_use_id, []).append(
            (index, str(data.get("task_id") or ""))
        )
    if data.get("type") == "system" and data.get("subtype") == "task_notification":
        tool_use_id = str(data.get("tool_use_id") or "")
        outer_task_notifications.setdefault(tool_use_id, []).append(
            (
                index,
                str(data.get("task_id") or ""),
                str(data.get("status") or ""),
                str(data.get("summary") or ""),
            )
        )
    if data.get("type") == "assistant":
        for part in data.get("message", {}).get("content", []):
            ptype = part.get("type")
            if ptype == "tool_use" and part.get("name") in {"Agent", "Task"}:
                payload = part.get("input", {})
                payload_text = collect_text(payload)
                role = role_of(payload.get("subagent_type"))
                if role in {WRITE_ROLE, "verifier", "code-reviewer"}:
                    missing_direction = [m for m in DIRECTION_MARKERS if m.lower() not in payload_text.lower()]
                    if missing_direction:
                        direction_packet_gaps.append((index, role, missing_direction))
                if role == WRITE_ROLE:
                    tool_use_id = str(part.get("id", ""))
                    executor_codex_dispatches.append(
                        (index, payload_text, tool_use_id)
                    )
                    executor_codex_tool_ids.add(tool_use_id)
                    payload_markers = [marker for marker in SLICE_MARKERS if marker in payload_text]
                    if len(payload_markers) != 1:
                        invalid_executor_payloads.append((index, tool_use_id, payload_markers))
                    payload_lower = payload_text.lower()
                    payload_lines = payload_lower.splitlines()
                    for forbidden_prompt_marker in (
                        "optionally running",
                        "test outcome if you ran it",
                    ):
                        if forbidden_prompt_marker in payload_lower:
                            invalid_executor_payloads.append(
                                (index, tool_use_id, f"caller verification leaked into executor packet: {forbidden_prompt_marker}")
                            )
                    for verification_command in ("python3 -m pytest", "ast.parse("):
                        for payload_line in payload_lines:
                            if verification_command not in payload_line:
                                continue
                            if any(
                                negation in payload_line
                                for negation in ("do not", "must not", "never", "not run")
                            ):
                                continue
                            invalid_executor_payloads.append(
                                (
                                    index,
                                    tool_use_id,
                                    f"caller verification command leaked into executor packet: {verification_command}",
                                )
                            )
                    for forbidden in FORBIDDEN_ON_WRITE_CHANNEL:
                        # Only flag when the payload actually assigns the forbidden
                        # role's work to the write channel, not an incidental mention.
                        if f"role: {forbidden}" in payload_text.lower() or f"{forbidden} role" in payload_text.lower():
                            forbidden_write_channel.append((index, forbidden))
                if role == "verifier":
                    native_verifier_dispatches.append(index)
                if role == "code-reviewer":
                    native_code_reviewer_dispatches.append(index)
                if role == NATIVE_EXECUTOR:
                    primary_native_executor.append(index)
                if str(payload.get("subagent_type", "")).startswith("codex:codex-rescue"):
                    codex_rescue_on_write.append(index)
            if ptype == "tool_use" and part.get("name") == "Bash":
                command = str(part.get("input", {}).get("command", ""))
                parent_id = str(data.get("parent_tool_use_id") or "")
                if parent_id in executor_codex_tool_ids:
                    bash_tool_id = str(part.get("id", ""))
                    run_in_background = part.get("input", {}).get("run_in_background") is True
                    executor_bash_calls.append(
                        (index, parent_id, bash_tool_id, command, run_in_background)
                    )
                    companion_bash_parents[bash_tool_id] = parent_id
                    invocation_matches = list(COMPANION_INVOCATION_RE.finditer(command))
                    invocations = [match.group(1) for match in invocation_matches]
                    reasons = []
                    if run_in_background:
                        reasons.append("run_in_background is forbidden on the inner companion call")
                    if len(invocations) != 1:
                        reasons.append(f"expected exactly one companion invocation, saw {invocations!r}")
                    elif invocations[0] != "task":
                        reasons.append(f"only the task subcommand is allowed, saw {invocations[0]!r}")
                    else:
                        match = invocation_matches[0]
                        line_start = command.rfind("\n", 0, match.start()) + 1
                        line_end = command.find("\n", match.end())
                        if line_end < 0:
                            line_end = len(command)
                        invocation_line = command[line_start:line_end]
                        for required in ("--write", "--cwd", "--prompt-file", "2>/dev/null"):
                            if required not in invocation_line:
                                reasons.append(f"task invocation missing {required}")
                        if "--background" in invocation_line:
                            reasons.append("background is forbidden on the task invocation")
                    if reasons:
                        invalid_companion_shapes.append(
                            (index, parent_id, bash_tool_id, reasons, command)
                        )
            if ptype == "text":
                if POST_CHECK_MARKER in part.get("text", ""):
                    post_check_seen = True
                if FINAL_MARKER in part.get("text", ""):
                    final_marker_seen = True
                    final_marker_text.append(part.get("text", ""))
    if data.get("type") == "user":
        for part in data.get("message", {}).get("content", []):
            if part.get("type") != "tool_result":
                continue
            tool_use_id = str(part.get("tool_use_id", ""))
            if tool_use_id in companion_bash_parents:
                companion_bash_outputs.setdefault(tool_use_id, []).append(
                    (index, part.get("is_error"), collect_text(part.get("content", "")))
                )
    if data.get("type") == "result":
        permission_denials.extend(data.get("permission_denials") or [])
        result_text = str(data.get("result", ""))
        if POST_CHECK_MARKER in result_text:
            post_check_seen = True
        if FINAL_MARKER in result_text:
            final_marker_seen = True
            final_marker_text.append(result_text)
        if data.get("is_error") is True:
            errors.append((index, result_text[:1000]))

if not init_ok:
    raise SystemExit("codex-executor delegation live did not expose the Task tool and the oh-no-harness:executor-codex agent")
if errors:
    raise SystemExit(f"codex-executor delegation live returned errors: {errors!r}")
if permission_denials:
    raise SystemExit(f"codex-executor delegation live had permission denials: {permission_denials!r}")
if invalid_executor_payloads:
    raise SystemExit(
        "codex-executor delegation live could not attribute exactly one slice marker "
        f"to each executor-codex dispatch: {invalid_executor_payloads!r}"
    )
if direction_packet_gaps:
    raise SystemExit(
        "codex-executor delegation live dropped Direction Contract markers from role packets: "
        f"{direction_packet_gaps!r}"
    )
if invalid_companion_shapes:
    raise SystemExit(
        "codex-executor delegation live observed a non-rescue-thin companion shape "
        "(exactly one task command with write/cwd/prompt-file, stderr-only discard, "
        f"and no background/status/result/retry required): {invalid_companion_shapes!r}"
    )

# HARD: delegation must actually occur when ON (fail-to-delegate-when-ON).
if len(executor_codex_dispatches) != len(SLICE_MARKERS):
    raise SystemExit(
        "codex-executor delegation live must dispatch oh-no-harness:executor-codex "
        "exactly once for each disjoint slice (no missing dispatch and no caller retry); "
        f"dispatches={len(executor_codex_dispatches)} expected={len(SLICE_MARKERS)}"
    )
outer_lifecycle_failures = []
for dispatch_index, _payload, parent_id in executor_codex_dispatches:
    starts = outer_task_starts.get(parent_id, [])
    notifications = outer_task_notifications.get(parent_id, [])
    if len(starts) != 1 or len(notifications) != 1:
        outer_lifecycle_failures.append(
            (parent_id, "start/terminal-count", len(starts), len(notifications))
        )
        continue
    start_index, start_task_id = starts[0]
    terminal_index, terminal_task_id, _status, _summary = notifications[0]
    if (
        not start_task_id
        or start_task_id != terminal_task_id
        or not (dispatch_index < start_index < terminal_index)
    ):
        outer_lifecycle_failures.append(
            (
                parent_id,
                "outer-task-identity/order",
                dispatch_index,
                starts[0],
                notifications[0][:3],
            )
        )
if outer_lifecycle_failures:
    raise SystemExit(
        "codex-executor delegation live outer Agent lifecycle is invalid: "
        f"{outer_lifecycle_failures!r}"
    )

first_terminal_notification = min(
    outer_task_notifications[parent_id][0][0]
    for parent_id in executor_codex_tool_ids
)
outer_start_indices = [
    outer_task_starts[parent_id][0][0]
    for parent_id in executor_codex_tool_ids
]
if len(outer_start_indices) != len(SLICE_MARKERS) or any(
    start_index >= first_terminal_notification for start_index in outer_start_indices
):
    raise SystemExit(
        "codex-executor delegation live outer parallelism is invalid: both "
        "task_started events must precede the first terminal notification; "
        f"starts={outer_start_indices!r} first_terminal={first_terminal_notification}"
    )
# HARD: the write channel must be executor-codex, never codex:codex-rescue.
if codex_rescue_on_write:
    raise SystemExit(
        f"codex-executor delegation live routed the delegated write through codex:codex-rescue instead of executor-codex: {codex_rescue_on_write!r}"
    )
# HARD (executor-only, negative): no verify/review/merge on the write channel.
if forbidden_write_channel:
    raise SystemExit(
        f"codex-executor delegation live routed a non-executor role onto the write-capable executor-codex channel: {forbidden_write_channel!r}"
    )
# HARD (C3): each executor-codex Task must expose exactly one nested Bash call.
# Fail closed instead of scanning arbitrary transcript text: that fallback could
# mistake a different consult role's command or a quoted command for real execution.
calls_by_parent = {}
for call in executor_bash_calls:
    calls_by_parent.setdefault(call[1], []).append(call)
bad_call_counts = {
    parent_id: len(calls_by_parent.get(parent_id, []))
    for parent_id in executor_codex_tool_ids
    if len(calls_by_parent.get(parent_id, [])) != 1
}
if bad_call_counts or len(executor_bash_calls) != len(executor_codex_dispatches):
    raise SystemExit(
        "codex-executor delegation live requires exactly one nested Bash companion "
        "task per executor-codex dispatch; separate resolution, status/result, or retry "
        f"calls are forbidden; per_parent={bad_call_counts!r} total_calls={len(executor_bash_calls)}"
    )

# HARD (C3/raw boundary): launch acknowledgements are not completion evidence.
# Each Bash call must finish before its outer terminal notification, whose summary
# must preserve the Bash stdout apart from final-newline normalization.
raw_boundary_failures = []
primary_unavailable = []
unavailable_re = re.compile(r"(?i)(codex unavailable:|usage[- ]limit|you've hit your usage limit)")
for call_index, parent_id, bash_tool_id, _command, _background in executor_bash_calls:
    bash_results = companion_bash_outputs.get(bash_tool_id, [])
    terminal_results = outer_task_notifications.get(parent_id, [])
    if len(bash_results) != 1:
        raw_boundary_failures.append((parent_id, "bash-result-count", len(bash_results)))
        continue
    if len(terminal_results) != 1:
        raw_boundary_failures.append((parent_id, "terminal-count", len(terminal_results)))
        continue
    _bash_index, bash_is_error, bash_stdout = bash_results[0]
    terminal_index, _task_id, terminal_status, terminal_summary = terminal_results[0]
    if not (call_index < _bash_index < terminal_index):
        raw_boundary_failures.append(
            (parent_id, "invalid-call-result-order", call_index, _bash_index, terminal_index)
        )
    elif (
        bash_is_error is True
        or terminal_status != "completed"
        or unavailable_re.search(bash_stdout)
        or unavailable_re.search(terminal_summary)
    ):
        primary_unavailable.append(
            (
                parent_id,
                terminal_status,
                bash_is_error,
                bash_stdout[-240:],
                terminal_summary[-240:],
            )
        )
    elif not bash_stdout.strip():
        raw_boundary_failures.append((parent_id, "empty-companion-stdout"))
    elif not terminal_summary.strip():
        raw_boundary_failures.append((parent_id, "empty-terminal-summary"))
    elif bash_stdout.rstrip("\n").splitlines()[-1] != EXECUTOR_NO_VERIFY_LINE:
        raw_boundary_failures.append(
            (parent_id, "missing-exact-caller-owned-verification-line", bash_stdout[-240:])
        )
    elif (
        "pytest" in bash_stdout.lower()
        or re.search(r"\b\d+\s+passed\b", bash_stdout.lower())
        or "test passed" in bash_stdout.lower()
        or "tests passed" in bash_stdout.lower()
    ):
        raw_boundary_failures.append((parent_id, "executor-reported-running-verification", bash_stdout[:240]))
    elif not raw_equal(terminal_summary, bash_stdout):
        raw_boundary_failures.append(
            (
                parent_id,
                "wrapper-synthesis-or-truncation",
                bash_stdout[:240],
                terminal_summary[:240],
            )
        )
if primary_unavailable:
    raise SystemExit(f"primary companion unavailable: {primary_unavailable!r}")
if raw_boundary_failures:
    raise SystemExit(
        "codex-executor delegation live did not preserve the raw Codex stdout "
        f"boundary: {raw_boundary_failures!r}"
    )
last_executor_result_index = max(
    outer_task_notifications[parent_id][0][0] for parent_id in executor_codex_tool_ids
)
# HARD (executor-only, positive): BOTH native verifier and native code-reviewer
# must actually run after every outer executor task reaches its terminal notification.
if not native_verifier_dispatches or not native_code_reviewer_dispatches:
    raise SystemExit(
        "codex-executor delegation live requires both native verifier and native "
        "code-reviewer roles; "
        f"verifier={native_verifier_dispatches!r} code_reviewer={native_code_reviewer_dispatches!r}"
    )
if (
    min(native_verifier_dispatches) < last_executor_result_index
    or min(native_code_reviewer_dispatches) < last_executor_result_index
):
    raise SystemExit(
        "codex-executor delegation live dispatched native verifier/reviewer before "
        "both executor-codex results completed; "
        f"last_executor_result={last_executor_result_index} verifier={native_verifier_dispatches!r} "
        f"code_reviewer={native_code_reviewer_dispatches!r}"
    )
# HARD (C3): the PRIMARY (non-degrade) run must NOT fall back to the native executor.
if primary_native_executor:
    raise SystemExit(
        "codex-executor delegation live PRIMARY run dispatched the native "
        f"oh-no-harness:executor at {primary_native_executor!r}; the primary "
        "(non-degrade) run must prove real Codex delegation, not native fallback (C3)"
    )

if not post_check_seen:
    raise SystemExit(f"codex-executor delegation live did not emit the post-batch scope-check marker {POST_CHECK_MARKER}")
if not final_marker_seen:
    raise SystemExit(f"codex-executor delegation live did not return the final marker {FINAL_MARKER}")
missing_final_direction = [
    marker for marker in DIRECTION_MARKERS
    if marker.lower() not in "\n".join(final_marker_text).lower()
]
if missing_final_direction:
    raise SystemExit(
        "codex-executor delegation live final report dropped Direction Contract markers: "
        f"{missing_final_direction!r}"
    )

# ---- Degrade sub-run: CALLER-mediated fallback to native executor ----
degrade_rows = load_lines(degrade_out_path)
degrade_executor_dispatches = []   # (index, payload, Task tool-use id)
degrade_executor_ids = set()
degrade_native_executor = []       # (index, payload, Task tool-use id)
degrade_nested_dispatches = []
degrade_executor_bash_calls = []   # (index, parent Task id, Bash tool-use id, command, background)
degrade_bash_parents = {}
degrade_bash_outputs = {}
degrade_task_outputs = {}
degrade_native_outputs = {}
degrade_inspections = []           # (index, Bash tool-use id, command)
degrade_inspection_ids = set()
degrade_inspection_outputs = {}
degrade_fallback_warning = False
degrade_final_marker = False
for index, data in degrade_rows:
    if data.get("type") == "assistant":
        for part in data.get("message", {}).get("content", []):
            ptype = part.get("type")
            if ptype == "tool_use" and part.get("name") in {"Agent", "Task"}:
                payload = part.get("input", {})
                payload_text = collect_text(payload)
                tool_use_id = str(part.get("id", ""))
                parent_id = str(data.get("parent_tool_use_id") or "")
                if parent_id in degrade_executor_ids:
                    degrade_nested_dispatches.append((index, parent_id, tool_use_id))
                role = role_of(payload.get("subagent_type"))
                if role == WRITE_ROLE:
                    degrade_executor_dispatches.append((index, payload_text, tool_use_id))
                    degrade_executor_ids.add(tool_use_id)
                if role == NATIVE_EXECUTOR:
                    degrade_native_executor.append((index, payload_text, tool_use_id))
            if ptype == "tool_use" and part.get("name") == "Bash":
                command = str(part.get("input", {}).get("command", ""))
                bash_tool_id = str(part.get("id", ""))
                parent_id = str(data.get("parent_tool_use_id") or "")
                if parent_id in degrade_executor_ids:
                    degrade_executor_bash_calls.append(
                        (
                            index,
                            parent_id,
                            bash_tool_id,
                            command,
                            part.get("input", {}).get("run_in_background") is True,
                        )
                    )
                    degrade_bash_parents[bash_tool_id] = parent_id
                elif not parent_id and DEGRADE_INSPECTION_MARKER in command:
                    degrade_inspections.append((index, bash_tool_id, command))
                    degrade_inspection_ids.add(bash_tool_id)
            if ptype == "text":
                if DEGRADE_FALLBACK_MARKER in part.get("text", ""):
                    degrade_fallback_warning = True
                if DEGRADE_FINAL_MARKER in part.get("text", ""):
                    degrade_final_marker = True
    if data.get("type") == "user":
        for part in data.get("message", {}).get("content", []):
            if part.get("type") != "tool_result":
                continue
            tool_use_id = str(part.get("tool_use_id", ""))
            result = (
                index,
                part.get("is_error"),
                collect_text(part.get("content", "")),
            )
            if tool_use_id in degrade_bash_parents:
                degrade_bash_outputs.setdefault(tool_use_id, []).append(result)
            if tool_use_id in degrade_executor_ids:
                degrade_task_outputs.setdefault(tool_use_id, []).append(
                    (
                        index,
                        part.get("is_error"),
                        delegated_result_text(part.get("content", "")),
                    )
                )
            if tool_use_id in degrade_inspection_ids:
                degrade_inspection_outputs.setdefault(tool_use_id, []).append(result)
            if any(tool_use_id == native_id for _, _, native_id in degrade_native_executor):
                degrade_native_outputs.setdefault(tool_use_id, []).append(result)
    if data.get("type") == "result":
        result_text = str(data.get("result", ""))
        if DEGRADE_FALLBACK_MARKER in result_text:
            degrade_fallback_warning = True
        if DEGRADE_FINAL_MARKER in result_text:
            degrade_final_marker = True

# HARD: exactly one delegated attempt must precede exactly one native fallback.
if len(degrade_executor_dispatches) != 1:
    raise SystemExit(
        "codex-executor delegation degrade sub-run requires exactly one "
        f"executor-codex attempt, saw {degrade_executor_dispatches!r}"
    )
if len(degrade_native_executor) != 1:
    raise SystemExit(
        "codex-executor delegation degrade sub-run requires exactly one native "
        f"oh-no-harness:executor fallback, saw {degrade_native_executor!r}"
    )
if degrade_nested_dispatches:
    raise SystemExit(
        "executor-codex self-dispatched during degrade despite its Bash-only "
        f"transport contract: {degrade_nested_dispatches!r}"
    )

attempt_index, attempt_payload, attempt_id = degrade_executor_dispatches[0]
if DEGRADE_EXPECTED_FAILURE not in attempt_payload:
    raise SystemExit(
        "degrade executor-codex packet did not pin the exact failure "
        f"signal: {attempt_payload[:1200]!r}"
    )
if len(degrade_executor_bash_calls) != 1:
    raise SystemExit(
        "degrade executor-codex must make exactly one foreground Bash resolution "
        f"attempt, saw {degrade_executor_bash_calls!r}"
    )
_bash_index, bash_parent_id, bash_tool_id, bash_command, bash_background = degrade_executor_bash_calls[0]
if bash_parent_id != attempt_id or bash_background or "--background" in bash_command:
    raise SystemExit(
        "degrade executor-codex Bash attempt had the wrong parent/background shape: "
        f"parent={bash_parent_id!r} expected={attempt_id!r}"
    )
bash_results = degrade_bash_outputs.get(bash_tool_id, [])
task_results = degrade_task_outputs.get(attempt_id, [])
if len(bash_results) != 1 or len(task_results) != 1:
    raise SystemExit(
        "degrade executor-codex must expose exactly one Bash result and one raw "
        f"Task result; bash={bash_results!r} task={task_results!r}"
    )
failure_result_index, task_is_error, task_failure = task_results[0]
_bash_result_index, bash_is_error, bash_failure = bash_results[0]
if bash_is_error is True or task_is_error is True:
    raise SystemExit(
        "degrade executor-codex resolution attempt returned a tool error instead "
        f"of the canonical signal: bash={bash_is_error!r} task={task_is_error!r}"
    )
if not bash_failure.strip() or not re.search(
    r"(?i)(missing|not[ -]?found|unresolvable)", bash_failure
):
    raise SystemExit(
        "degrade executor-codex Bash did not prove the configured override path "
        f"was missing: {bash_failure!r}"
    )
if task_failure.strip() != DEGRADE_EXPECTED_FAILURE:
    raise SystemExit(
        "degrade executor-codex did not classify the missing-path observation as "
        f"the exact canonical failure signal: bash={bash_failure!r} task={task_failure!r}"
    )

# HARD: caller inspection and protected-target guard must finish AFTER the exact
# failure and BEFORE native fallback. This proves partial-change inspection is not
# merely mentioned after the fact.
if len(degrade_inspections) != 1:
    raise SystemExit(
        "degrade caller must run exactly one marked pre-fallback inspection, saw "
        f"{degrade_inspections!r}"
    )
inspection_index, inspection_tool_id, inspection_command = degrade_inspections[0]
for required in (
    DEGRADE_INSPECTION_MARKER,
    "git -C",
    "status --porcelain",
    "src/util2.py",
    ".oh-no",
    "find ",
    "-not -path",
):
    if required not in inspection_command:
        raise SystemExit(
            "degrade caller inspection missed a required partial-change/guard "
            f"operation {required!r}: {inspection_command!r}"
        )
inspection_results = degrade_inspection_outputs.get(inspection_tool_id, [])
if len(inspection_results) != 1:
    raise SystemExit(
        "degrade caller inspection did not return exactly one result: "
        f"{inspection_results!r}"
    )
inspection_result_index, inspection_is_error, inspection_output = inspection_results[0]
if inspection_is_error is True or re.search(
    r"(?m)^.{2}\s+src/util2\.py$", inspection_output
):
    raise SystemExit(
        "degrade caller inspection found a partial src/util2.py change before fallback: "
        f"{inspection_output!r}"
    )
native_index, native_payload, native_id = degrade_native_executor[0]
if not (
    attempt_index < failure_result_index < inspection_index
    and inspection_result_index < native_index
):
    raise SystemExit(
        "degrade ordering must be executor attempt -> exact failure -> completed "
        "caller inspection/guard -> native fallback; "
        f"attempt={attempt_index} failure={failure_result_index} "
        f"inspection={inspection_index}/{inspection_result_index} native={native_index}"
    )
if "OH_NO_CODEX_DELEG_DEGRADE_SLICE" not in native_payload:
    raise SystemExit("native degrade fallback packet lost the assigned slice marker")
native_results = degrade_native_outputs.get(native_id, [])
if len(native_results) != 1 or "OH_NO_CODEX_DELEG_DEGRADE_SLICE" not in native_results[0][2]:
    raise SystemExit(
        "native degrade fallback did not complete its assigned slice with observable "
        f"output: {native_results!r}"
    )
if os.environ.get("OH_NO_CODEX_DELEG_DEGRADE_ESCAPE_VERDICT", "") != "clean":
    raise SystemExit(
        "degrade caller-owned protected-target guard was not clean: "
        f"{os.environ.get('OH_NO_CODEX_DELEG_DEGRADE_ESCAPE_VERDICT', '')!r}"
    )
if not degrade_fallback_warning:
    raise SystemExit(
        f"codex-executor delegation degrade sub-run did not record the fallback warning {DEGRADE_FALLBACK_MARKER}"
    )
if not degrade_final_marker:
    raise SystemExit(
        f"codex-executor delegation degrade sub-run did not return {DEGRADE_FINAL_MARKER}"
    )

summary = {
    "status": "passed",
    "caller_escape_guard_verdict": os.environ.get("OH_NO_CODEX_DELEG_ESCAPE_VERDICT", ""),
    "executor_codex_dispatches": len(executor_codex_dispatches),
    "real_companion_write_calls": len(executor_bash_calls),
    "raw_stdout_boundary": True,
    "native_verifier_dispatches": len(native_verifier_dispatches),
    "native_code_reviewer_dispatches": len(native_code_reviewer_dispatches),
    "outer_overlap": True,
    "post_check_marker": POST_CHECK_MARKER,
    "final_marker": FINAL_MARKER,
    "worktree_delta_before": os.environ.get("OH_NO_CODEX_DELEG_WT_STATUS_BEFORE", ""),
    "worktree_delta_after": os.environ.get("OH_NO_CODEX_DELEG_WT_STATUS_AFTER", ""),
    "degrade_native_executor_fallback": bool(degrade_native_executor),
    "degrade_executor_attempts": len(degrade_executor_dispatches),
    "degrade_exact_failure_signal": task_failure.strip(),
    "degrade_inspection_before_fallback": True,
    "degrade_caller_escape_guard_verdict": os.environ.get(
        "OH_NO_CODEX_DELEG_DEGRADE_ESCAPE_VERDICT", ""
    ),
    "degrade_fallback_warning": degrade_fallback_warning,
}
with open(summary_path, "w", encoding="utf-8") as fh:
    fh.write(json.dumps(summary, indent=2, sort_keys=True) + "\n")

print("ok - live Claude codex-executor delegation: eligible outer executor-codex overlap, one foreground raw companion call per slice, caller attribution + escape guard clean, RED->GREEN, executor-only routing, caller-mediated sequential degrade")
PY
  then
    parser_rc=0
  else
    parser_rc=$?
  fi

  _codex_deleg_cleanup
  rm -rf "$config_dir"
  trap - RETURN EXIT INT TERM

  if [[ "$parser_rc" != "0" ]]; then
    return "$parser_rc"
  fi
  if [[ "$run_rc" != "0" ]]; then
    log "Claude codex-executor delegation live command invocation failed despite parser-accepted transcript (rc=$run_rc)"
    return "$run_rc"
  fi
  if [[ "$degrade_rc" != "0" ]]; then
    log "Claude codex-executor delegation degrade sub-run failed despite parser-accepted transcript (rc=$degrade_rc)"
    return "$degrade_rc"
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
  prompt="Use /${PLUGIN_NAME}:simplify --review. Read-only dispatch instrumentation test only: do not edit files, do not create artifacts, do not apply cleanup fixes, and do not run Phase 2. Verify Phase 1 dispatch only. Do not inspect repository files, do not run Bash or Read, and do not start helper workers beyond the four cleanup angle workers. Use this synthetic one-line diff for every worker: plugins/oh-no-harness/docs/skill-core/simplify.md: Phase 1 dispatch contract changed for smoke verification. Use Claude Workflow with Promise.all and exactly four agent() calls when Workflow is available; otherwise use Claude background Task or Agent workers exactly four times, but request all four before inspecting or summarizing any task result. The four cleanup subagent angles must be exactly Reuse, Simplification, Efficiency, and Altitude. Each task or agent prompt MUST include exactly one line of the form Angle: <angle>, one matching marker line, plus these literal lines: Scope: synthetic dispatch diff; Do not edit files; Do not create artifacts; Do not apply cleanup fixes; Do not run Phase 2; Expected output: dispatch marker observed with file, line, summary, concrete cost. Marker lines by angle: Reuse uses Marker: OH_NO_SIMPLIFY_REUSE_READONLY; Simplification uses Marker: OH_NO_SIMPLIFY_SIMPLIFICATION_READONLY; Efficiency uses Marker: OH_NO_SIMPLIFY_EFFICIENCY_READONLY; Altitude uses Marker: OH_NO_SIMPLIFY_ALTITUDE_READONLY. Each cleanup subagent should return only Angle <angle>: no behavior change; dispatch marker observed, plus file, line, summary, and concrete cost fields. After each cleanup subagent result is captured, close or clean up that completed subagent when the host exposes that mechanism; if no explicit close or cleanup mechanism exists, record that fallback. After all four cleanup subagents finish, reply exactly OH_NO_CLAUDE_SIMPLIFY_SUBAGENTS_OK and summarize Review angles: Reuse, Simplification, Efficiency, Altitude; Launched before waiting: yes; lifecycle close or cleanup status."
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

  "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

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
    "Expected output: dispatch marker observed with file, line, summary, concrete cost",
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
bad_background_payloads = []
unexpected_task_uses = []
task_starts = []
first_task_notification_index = None
workflow_tool_ids = set()
workflow_scripts = []
workflow_completed = False
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
        if data.get("type") == "system" and data.get("subtype") == "task_started":
            task_starts.append((index, data.get("task_id")))
        if data.get("type") == "system" and data.get("subtype") in {"task_notification", "task_updated"}:
            if first_task_notification_index is None:
                first_task_notification_index = index
            if (
                data.get("status") == "completed"
                and (
                    data.get("tool_use_id") in workflow_tool_ids
                    or "workflow" in str(data.get("summary", "")).lower()
                )
            ):
                workflow_completed = True
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
    # A backgrounded Workflow may not surface a status=="completed" task event in the
    # --print stream; the success marker is emitted only after all four cleanup subagents
    # finish, so an emitted marker is itself sufficient proof the Workflow completed.
    if not workflow_completed and not marker:
        raise SystemExit("Claude simplify Workflow task did not report completion")
    if not marker:
        raise SystemExit("Claude simplify cleanup smoke did not return success marker")
    combined_summary_text = "\n".join(summary_text).lower()
    missing_summary_angles = [
        angle for angle in expected_angles
        if angle.lower() not in combined_summary_text
    ]
    if missing_summary_angles:
        raise SystemExit(
            "Claude simplify Workflow success summary did not mention every cleanup angle: "
            f"{missing_summary_angles!r}"
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
combined_summary_text = "\n".join(summary_text).lower()
missing_summary_angles = [
    angle for angle in expected_angles
    if angle.lower() not in combined_summary_text
]
if missing_summary_angles:
    raise SystemExit(
        "Claude simplify cleanup success summary did not mention every cleanup angle: "
        f"{missing_summary_angles!r}"
    )

print("ok - live Claude simplify cleanup subagents spawned in one batch")
PY
}

run_ralplan_xhost_live_test() {
  if [[ "$RUN_RALPLAN_XHOST_LIVE" != "1" ]]; then
    log "Skipping live Claude cross-host PLAN-REVIEW PAIR smoke test (real ralplan flow)"
    printf 'Run with --ralplan-xhost-live or OH_NO_RALPLAN_XHOST_LIVE=1 to verify the real ralplan flow dispatching the cross-host plan-review pair (current-host oh-no-harness:plan-reviewer plus opposite-host oh-no-harness:plan-reviewer-codex) after the planner draft, synthesized into one verdict.\n' >&2
    return
  fi

  log "Running live Claude cross-host PLAN-REVIEW PAIR smoke test via real ralplan (${LIVE_LOAD_MODE}, model ${FUSION_RESCUE_LIVE_MODEL})"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/ralplan-xhost-claude.jsonl"
  local err_file="$RUN_DIR/ralplan-xhost-claude.err"
  local summary_file="$RUN_DIR/ralplan-xhost-claude.summary.json"
  local read_root="$PLUGIN_ROOT"

  if [[ "$LIVE_LOAD_MODE" == "installed" ]]; then
    read_root="$(cached_plugin_root)"
  fi

  # NOTE: unquoted heredoc (expands ${read_root}/${PLUGIN_NAME}) inside $(...).
  # Bash tracks single-quote parity across the whole substitution, so the prompt
  # text MUST NOT contain apostrophes or an unintended $ (both break `bash -n`).
  local prompt
  prompt=$(cat <<PROMPT
/${PLUGIN_NAME}:ralplan require-cross-host read-only live cross-host PLAN-REVIEW PAIR smoke test only. Do not edit files, do not create artifacts, do not create a full plan, do not install plugins, and do not run any write-capable command. The requirements source is already analyzed inline; do not spawn explore, analyst, executor, verifier, code-reviewer, or debugger. Use only oh-no-harness:planner, oh-no-harness:plan-reviewer, and oh-no-harness:plan-reviewer-codex.

Named THOROUGH trigger: public workflow contract planning. Read ${read_root}/docs/platforms/claude-code.md Cross-Host Consult Channel before dispatch; pairing is trigger-driven, not availability-driven.

First, read ${read_root}/docs/shared/cross-host-review.md, paying attention to its "## Parallel Execution And Synthesis", "## Role-Owned Review Instances", and "## Reuse Of The Cross-Host Mechanism" sections, and read ${read_root}/docs/platforms/claude-code-runtime.md paying attention to its "## Cross-Host Consult Channel" section. In this run the opposite host (Codex) is AVAILABLE and authorized: the oh-no-harness:plan-reviewer-codex cross-host consult agent and its node codex-companion.mjs transport are available. Run the Plan Review stage as a CROSS-HOST review pair, NOT the Same-Host Parallel Fallback. Exercise ONLY the planner then the cross-host plan-reviewer pair: dispatch no other role and no other opposite-host consult agent.

Synthetic approved task (already analyzed): document that the host asks the user which execution workflow to run after ralplan plan approval.

Step 1 (sequential, per ralplan): dispatch exactly one oh-no-harness:planner subagent FIRST and wait for it to complete before any plan review. Planner expected output: only a short section titled Planner draft v1 with Goal, Acceptance criteria, Execution profile, Worktree policy, Verification plan. Do not revise the draft after review.

Step 2 (plan-review PAIR, after the Planner draft v1 is captured): dispatch BOTH plan-review instances of the SAME plan-reviewer role over the SAME Planner draft v1 text, starting both before waiting for either result:

Current-host instance: a Claude current-host subagent using subagent_type oh-no-harness:plan-reviewer. Its task prompt must include exactly these lines: Instance: current-host; Marker: OH_NO_XHOST_RALPLAN_CURRENT_OK; Scope: the Planner draft v1 only; Do not edit files; Do not make any cross-host or opposite-host call; Run the complete plan-reviewer role over the draft; Expected output: marker line plus a Plan review v1 section with architecture findings, quality-gate findings, and a verdict.

Opposite-host instance: exactly one Codex response through the dedicated read-only consult agent, dispatched with subagent_type oh-no-harness:plan-reviewer-codex. A valid live result requires oh-no-harness:plan-reviewer-codex to perform exactly one required Bash call to node codex-companion.mjs task in the foreground, wait for completion, and return the Codex companion stdout; a marker generated locally by the wrapper, a background acknowledgement, or a status pointer is not valid. The harness parser, not you, verifies the Bash event stream and codex-companion stdout after the run, so do not poll status, fetch a deferred result, or run a second codex-companion or consult call for liveness. The codex-companion Bash command MUST NOT include --write and MUST NOT include --background; the plan-reviewer-codex agent runs codex-companion read-only by design (no --write flag) and synchronously in the foreground, and a permission denial from an attempted --write command is a test failure even if a later retry succeeds. The plan-reviewer-codex packet MUST use --prompt-file with a redacted packet that: is explicitly read-only with no edits, no writes, and no installs; forbids further rescue, another workflow skill, and any host-to-host call back to Claude or a third host (one cross-host hop); instructs Codex to dispatch the oh-no-plan-reviewer role agent to run the complete plan-reviewer role over this same Planner draft v1; and requires Codex to return the role-owned result of oh-no-plan-reviewer plus role-ownership proof that oh-no-plan-reviewer, not a parent inline Codex answer, produced it, ending with exactly the marker OH_NO_XHOST_RALPLAN_CODEX_RETURN_OK. If oh-no-harness:plan-reviewer-codex cannot run exactly one node codex-companion.mjs Bash call in the foreground, or cannot prove oh-no-plan-reviewer role ownership, do not synthesize success.

Start both plan-review instances before waiting when possible. Wait for both results and do not end while a worker is still pending. After the current-host oh-no-harness:plan-reviewer subagent and the single opposite-host oh-no-harness:plan-reviewer-codex consult both return, synthesize immediately as the current-host main judge into ONE merged plan-review verdict rather than concatenate: merge the two finding sets, deduplicate, and record host provenance on each finding. The final answer must contain exactly the marker OH_NO_CLAUDE_RALPLAN_XHOST_OK and must include, as its own lines: role order: planner then plan-reviewer pair; both instances dispatched: current-host plan-reviewer and opposite-host plan-reviewer-codex; started-concurrently: yes; foreground read-only call: yes; role ownership (oh-no-plan-reviewer) proven: yes; synthesized one verdict: yes; the instance markers OH_NO_XHOST_RALPLAN_CURRENT_OK and OH_NO_XHOST_RALPLAN_CODEX_RETURN_OK; and a single merged verdict block recording consensus, contradictions, unique insights, blind spots, and recommended next action.
PROMPT
)

  local cmd=(
    "$CLAUDE_BIN"
    --print
    --verbose
    --output-format stream-json
    --include-hook-events
    --model "$FUSION_RESCUE_LIVE_MODEL"
    --max-budget-usd "$FUSION_RESCUE_MAX_BUDGET_USD"
    --permission-mode bypassPermissions
    --allowedTools "Bash(node *)"
    --tools default
    --add-dir "$read_root"
    --no-session-persistence
    --system-prompt "You are a read-only live smoke test runner. Use the invoked Oh No Harness skill, one Claude current-host oh-no-harness:planner subagent, one Claude current-host oh-no-harness:plan-reviewer subagent, and the oh-no-harness:plan-reviewer-codex read-only consult agent only for this requested planner-then-cross-host plan-review pair. The opposite host (Codex) is available. Do not edit files."
  )

  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi

  "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

  "$PYTHON_BIN" - "$out_file" "$err_file" "$summary_file" "$FUSION_RESCUE_LIVE_MODEL" <<'PY'
import json
import re
import sys
from pathlib import Path

out_path, err_path, summary_path, model = sys.argv[1:5]

CURRENT_MARKER = "OH_NO_XHOST_RALPLAN_CURRENT_OK"
CODEX_RETURN_MARKER = "OH_NO_XHOST_RALPLAN_CODEX_RETURN_OK"
FINAL_MARKER = "OH_NO_CLAUDE_RALPLAN_XHOST_OK"
PLANNER_ROLE = "oh-no-harness:planner"
CURRENT_ROLE = "oh-no-harness:plan-reviewer"
CODEX_ROLE = "oh-no-harness:plan-reviewer-codex"
CODEX_SIDE_ROLE = "oh-no-plan-reviewer"

required_final_markers = [
    FINAL_MARKER,
    CURRENT_MARKER,
    CODEX_RETURN_MARKER,
    "current-host plan-reviewer",
    "opposite-host plan-reviewer-codex",
    "foreground read-only call: yes",
    CODEX_SIDE_ROLE,
    "synthesized one verdict: yes",
]
required_synthesis_fields = [
    "consensus",
    "contradictions",
    "unique insights",
    "blind spots",
    "recommended next action",
]
secret_patterns = [
    re.compile(r"(?<![A-Za-z0-9])sk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"(?i)(api[_-]?key|access[_-]?token|refresh[_-]?token|private[_-]?key|cookie)[ \t]*[:=][ \t]*['\"]?[A-Za-z0-9_./+=-]{12,}"),
]
forbidden_write_tool_names = {"Edit", "Write", "NotebookEdit"}

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
if "unknown command" in err_text.lower() or "unknown agent" in err_text.lower():
    raise SystemExit(f"Claude ralplan cross-host review live saw unavailable command/agent in stderr: {err_text[:2000]!r}")

init_agents = set()
init_tools = set()
errors = []
planner_dispatch_indexes = []
# Lifecycle proof (mirrors the cross-host-review lane): task_started +
# task_notification(status=="completed") per plan-reviewer instance feed the
# peak-in-flight walk that proves the pair overlapped, and the planner must
# COMPLETE before the first reviewer instance starts (dispatch order alone
# cannot prove either).
reviewer_task_ids = set()
reviewer_started_indices = []
reviewer_completed_ids = set()
reviewer_completion_indices = []
planner_task_ids = set()
planner_completion_indices = []
current_dispatches = []
codex_dispatches = []
unexpected_write_uses = []
codex_bash_tool_ids = set()
codex_write_commands = []
codex_background_commands = []
codex_bash_success_texts = []
codex_bash_success_indexes = []
codex_bash_failures = []
permission_denials = []
non_user_text_parts = []
pending_background_events = []

with open(out_path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        text = collect_text(data)
        if data.get("type") == "system" and (
            "Command running in background" in text
            or ("Codex task" in text and "still running" in text)
        ):
            pending_background_events.append((index, text[:2000]))
        if any(pattern.search(text) for pattern in secret_patterns):
            raise SystemExit(f"Claude ralplan cross-host review live transcript exposed a secret-like value near line {index}")
        if data.get("type") == "system" and data.get("subtype") == "init":
            init_agents.update(data.get("agents", []))
            init_tools.update(data.get("tools", []))
        if data.get("type") == "assistant":
            non_user_text_parts.append(text)
            for part in data.get("message", {}).get("content", []):
                if part.get("type") == "tool_use" and part.get("name") in forbidden_write_tool_names:
                    unexpected_write_uses.append((index, part.get("name"), collect_text(part.get("input", ""))[:1000]))
                if part.get("type") == "tool_use" and part.get("name") == "Bash":
                    command = str(part.get("input", {}).get("command", ""))
                    if "codex-companion.mjs" in command:
                        # The --write/--background forbids cover EVERY
                        # codex-companion command, including a rogue call that
                        # inlines the packet instead of using --prompt-file.
                        if re.search(r"(?<!\S)--write(?!\S)", command):
                            codex_write_commands.append((index, command[:2000]))
                        if re.search(r"(?<!\S)--background(?!\S)", command):
                            codex_background_commands.append((index, command[:2000]))
                        # Count only the actual delegation `task` call (which
                        # passes the packet via --prompt-file), not the read-only
                        # companion-path resolution probes (ls / [ -f ] / versions
                        # checks) the kernel runs first to resolve/verify the
                        # companion before delegating.
                        if "--prompt-file" in command:
                            codex_bash_tool_ids.add(part.get("id"))
                if part.get("type") == "tool_use" and part.get("name") in {"Agent", "Task"}:
                    payload = part.get("input", {})
                    payload_text = collect_text(payload)
                    subagent_type = str(payload.get("subagent_type", ""))
                    if subagent_type == CODEX_ROLE:
                        codex_dispatches.append((index, payload_text))
                    elif subagent_type == CURRENT_ROLE:
                        current_dispatches.append((index, payload_text))
                    elif subagent_type == PLANNER_ROLE:
                        planner_dispatch_indexes.append(index)
                if part.get("type") == "text":
                    non_user_text_parts.append(part.get("text", ""))
        if data.get("type") == "system" and data.get("subtype") == "task_started":
            started_type = str(data.get("subagent_type", "") or "")
            if started_type in {CURRENT_ROLE, CODEX_ROLE}:
                reviewer_task_ids.add(data.get("task_id"))
                reviewer_started_indices.append((index, data.get("task_id")))
            elif started_type == PLANNER_ROLE:
                planner_task_ids.add(data.get("task_id"))
        if data.get("type") == "system" and data.get("subtype") in {"task_updated", "task_notification"}:
            # Some task_updated events carry status under patch.status (see the
            # natural-session lane precedent); accept both so a completion is
            # never silently dropped.
            if (data.get("status") or (data.get("patch") or {}).get("status")) == "completed":
                completed_task_id = data.get("task_id")
                if (
                    completed_task_id in reviewer_task_ids
                    and completed_task_id not in reviewer_completed_ids
                ):
                    reviewer_completed_ids.add(completed_task_id)
                    reviewer_completion_indices.append((index, completed_task_id))
                if completed_task_id in planner_task_ids:
                    planner_completion_indices.append((index, completed_task_id))
            non_user_text_parts.append(text)
        if data.get("type") == "user":
            for part in data.get("message", {}).get("content", []):
                if not isinstance(part, dict):
                    continue
                if part.get("tool_use_id") not in codex_bash_tool_ids:
                    continue
                result_text = collect_text(part)
                if "Command running in background" in result_text or (
                    "Codex task" in result_text and "still running" in result_text
                ):
                    raise SystemExit(
                        "Claude ralplan cross-host review live codex-companion Bash did not complete "
                        f"in the foreground: {result_text[:1000]!r}"
                    )
                if bool(part.get("is_error")):
                    codex_bash_failures.append((index, result_text[:1000]))
                else:
                    codex_bash_success_indexes.append(index)
                    codex_bash_success_texts.append(result_text)
        tool_result = data.get("tool_use_result") or {}
        if isinstance(tool_result, dict) and tool_result.get("agentType", ""):
            non_user_text_parts.append(collect_text(tool_result))
        if data.get("type") == "result":
            permission_denials.extend(data.get("permission_denials") or [])
            non_user_text_parts.append(str(data.get("result", "")))
            if data.get("is_error") is True:
                errors.append((index, str(data.get("result", ""))[:1000]))

if errors:
    raise SystemExit(f"Claude ralplan cross-host review live returned errors: {errors!r}")
if unexpected_write_uses:
    raise SystemExit(f"Claude ralplan cross-host review live used write-capable tools: {unexpected_write_uses!r}")
if codex_write_commands:
    raise SystemExit(f"Claude ralplan cross-host review live invoked codex-companion with --write: {codex_write_commands!r}")
if codex_background_commands:
    raise SystemExit(f"Claude ralplan cross-host review live invoked codex-companion with --background: {codex_background_commands!r}")
if permission_denials:
    raise SystemExit(f"Claude ralplan cross-host review live had permission denials: {permission_denials!r}")

if CODEX_ROLE not in init_agents:
    raise SystemExit(
        f"Claude ralplan cross-host review live did not expose {CODEX_ROLE} agent; "
        f"got={sorted(agent for agent in init_agents if 'plan-reviewer' in agent)!r}"
    )
if not ({"Task", "Agent", "Workflow"} & init_tools):
    raise SystemExit(f"Claude ralplan cross-host review live did not expose subagent tooling; tools={sorted(init_tools)!r}")

# Native plan-reviewer AND plan-reviewer-codex both dispatched (exactly one each).
if len(current_dispatches) != 1:
    raise SystemExit(
        f"Claude ralplan cross-host review live expected exactly one {CURRENT_ROLE} dispatch, got {current_dispatches!r}"
    )
if len(codex_dispatches) != 1:
    raise SystemExit(
        f"Claude ralplan cross-host review live expected exactly one {CODEX_ROLE} dispatch, got {codex_dispatches!r}"
    )

# Planner ran first, sequentially, before the plan-review pair (per ralplan).
if not planner_dispatch_indexes:
    raise SystemExit(f"Claude ralplan cross-host review live did not dispatch {PLANNER_ROLE} before the plan-review pair")
first_planner_index = min(planner_dispatch_indexes)
current_index = current_dispatches[0][0]
codex_index = codex_dispatches[0][0]
if not (first_planner_index < current_index and first_planner_index < codex_index):
    raise SystemExit(
        "Claude ralplan cross-host review live did not run the planner before the plan-review pair: "
        f"planner_index={first_planner_index} current_index={current_index} codex_index={codex_index}"
    )

# Lifecycle proof (fail closed): the planner COMPLETED before the first
# reviewer instance STARTED — dispatch-index order alone cannot prove the
# reviewers saw a finished draft.
if not planner_completion_indices:
    raise SystemExit(
        "Claude ralplan cross-host review live captured no planner completion event "
        "(cannot prove the planner finished before the plan-review pair started)"
    )
if len(reviewer_started_indices) < 2:
    raise SystemExit(
        "Claude ralplan cross-host review live captured task_started for "
        f"{len(reviewer_started_indices)} plan-reviewer instances (need 2)"
    )
first_planner_completion = min(idx for idx, _ in planner_completion_indices)
first_reviewer_start = min(idx for idx, _ in reviewer_started_indices)
if not (first_planner_completion < first_reviewer_start):
    raise SystemExit(
        "Claude ralplan cross-host review live started the plan-review pair before the planner completed: "
        f"planner_completion={first_planner_completion} first_reviewer_start={first_reviewer_start}"
    )

# The two plan-reviewer instances overlapped (peak in-flight >= 2). A purely
# serial run (start, complete, start, complete) never exceeds 1 in flight.
CONCURRENCY_MIN = 2
lifecycle = sorted(
    [(idx, 1) for idx, _ in reviewer_started_indices]
    + [(idx, -1) for idx, _ in reviewer_completion_indices]
)
in_flight = 0
peak_in_flight = 0
for _, delta in lifecycle:
    in_flight += delta
    if in_flight > peak_in_flight:
        peak_in_flight = in_flight
if peak_in_flight < CONCURRENCY_MIN:
    raise SystemExit(
        "Claude ralplan cross-host review live did not prove the plan-review pair overlapped: "
        f"peak in-flight was {peak_in_flight} (need >= {CONCURRENCY_MIN}); "
        f"started={len(reviewer_started_indices)} completed={len(reviewer_completion_indices)}. "
        "A purely serial run peaks at 1 in flight."
    )

# The outbound opposite-host packet must preserve role ownership + read-only.
codex_payload = codex_dispatches[0][1]
for marker in (CODEX_SIDE_ROLE, CODEX_RETURN_MARKER, "read-only"):
    if marker.lower() not in codex_payload.lower():
        raise SystemExit(
            f"Claude ralplan cross-host review live plan-reviewer-codex packet missed role-ownership marker {marker!r}; "
            f"payload={codex_payload[:2000]!r}"
        )

# The plan-reviewer-codex made exactly one read-only foreground codex-companion call.
if not codex_bash_tool_ids:
    raise SystemExit("Claude ralplan cross-host review live did not invoke codex-companion.mjs through oh-no-harness:plan-reviewer-codex Bash")
if len(codex_bash_tool_ids) != 1:
    raise SystemExit(f"Claude ralplan cross-host review live expected exactly one codex-companion.mjs Bash invocation, got {sorted(codex_bash_tool_ids)!r}")
if codex_bash_failures:
    raise SystemExit(f"Claude ralplan cross-host review live codex-companion Bash failed: {codex_bash_failures!r}")
if len(codex_bash_success_indexes) != 1:
    raise SystemExit(f"Claude ralplan cross-host review live expected exactly one successful codex-companion.mjs Bash result, got {codex_bash_success_indexes!r}")

# The returned opposite-host result proves oh-no-plan-reviewer role ownership.
codex_bash_text = "\n".join(codex_bash_success_texts)
if CODEX_RETURN_MARKER not in codex_bash_text:
    raise SystemExit(
        f"Claude ralplan cross-host review live did not capture {CODEX_RETURN_MARKER} from codex-companion.mjs stdout"
    )
if CODEX_SIDE_ROLE not in codex_bash_text.lower():
    raise SystemExit(
        "Claude ralplan cross-host review live codex-companion stdout did not prove "
        f"{CODEX_SIDE_ROLE} role ownership (possible parent inline Codex answer)"
    )
last_codex_bash_success_index = max(codex_bash_success_indexes) if codex_bash_success_indexes else None
late_pending_background_events = [
    event for event in pending_background_events
    if last_codex_bash_success_index is None or event[0] > last_codex_bash_success_index
]
if late_pending_background_events:
    raise SystemExit(
        "Claude ralplan cross-host review live left background/still-running work after the Codex "
        f"foreground completion: {late_pending_background_events!r}"
    )

# Final synthesized success marker and its required merged-verdict content.
success_text = "\n".join(part for part in non_user_text_parts if FINAL_MARKER in part)
if not success_text:
    detail = f"; pending events={pending_background_events!r}" if pending_background_events else ""
    raise SystemExit(f"Claude ralplan cross-host review live did not return success marker {FINAL_MARKER}{detail}")
lower_success_text = success_text.lower()
for marker in required_final_markers:
    if marker.lower() not in lower_success_text:
        raise SystemExit(f"Claude ralplan cross-host review live missing final marker/text: {marker!r}")
for field in required_synthesis_fields:
    if field.lower() not in lower_success_text:
        raise SystemExit(f"Claude ralplan cross-host review live missing synthesis field: {field!r}")

summary = {
    "status": "passed",
    "model": model,
    "planner_first_index": first_planner_index,
    "current_host_instance": {
        "subagent_type": CURRENT_ROLE,
        "returned_marker": CURRENT_MARKER,
    },
    "opposite_host_instance": {
        "subagent_type": CODEX_ROLE,
        "codex_side_role": CODEX_SIDE_ROLE,
        "bash_tool_uses": len(codex_bash_tool_ids),
        "returned_marker": CODEX_RETURN_MARKER,
        "permission_denials": len(permission_denials),
    },
    "final_marker": FINAL_MARKER,
}
Path(summary_path).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print("ok - live Claude real ralplan flow dispatched planner then cross-host plan-review pair oh-no-harness:plan-reviewer + oh-no-harness:plan-reviewer-codex (read-only foreground codex-companion, role-owned oh-no-plan-reviewer) and synthesized one verdict")
PY
}

run_vbc_xhost_live_test() {
  if [[ "$RUN_VBC_XHOST_LIVE" != "1" ]]; then
    log "Skipping live Claude cross-host CODE-REVIEW PAIR plus self-host verifier smoke test (real verification-before-completion flow)"
    printf 'Run with --vbc-xhost-live or OH_NO_VBC_XHOST_LIVE=1 to verify the real verification-before-completion flow dispatching the cross-host code-review pair (current-host oh-no-harness:code-reviewer plus opposite-host oh-no-harness:code-reviewer-codex) followed by a single self-host oh-no-harness:verifier (verifier=self-1, no verifier-codex).\n' >&2
    return
  fi

  log "Running live Claude cross-host CODE-REVIEW PAIR plus self-host verifier smoke test via real verification-before-completion (${LIVE_LOAD_MODE}, model ${FUSION_RESCUE_LIVE_MODEL})"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/vbc-xhost-claude.jsonl"
  local err_file="$RUN_DIR/vbc-xhost-claude.err"
  local summary_file="$RUN_DIR/vbc-xhost-claude.summary.json"
  local read_root="$PLUGIN_ROOT"

  if [[ "$LIVE_LOAD_MODE" == "installed" ]]; then
    read_root="$(cached_plugin_root)"
  fi

  # NOTE: unquoted heredoc (expands ${read_root}/${PLUGIN_NAME}) inside $(...).
  # Bash tracks single-quote parity across the whole substitution, so the prompt
  # text MUST NOT contain apostrophes or an unintended $ (both break `bash -n`).
  local prompt
  prompt=$(cat <<PROMPT
/${PLUGIN_NAME}:verification-before-completion require-cross-host read-only live cross-host CODE-REVIEW PAIR plus confirming SELF-HOST verifier smoke test only. Do not edit files, do not create artifacts, do not install plugins, and do not run any write-capable command.

Named THOROUGH trigger: authentication and session safety review. Read ${read_root}/docs/platforms/claude-code.md Cross-Host Consult Channel before dispatch; pairing is trigger-driven, not availability-driven.

First, read ${read_root}/docs/shared/cross-host-review.md, paying attention to its "## When It Applies", "## Sequencing Preserved", "## Role-Owned Review Instances", and "## Reuse Of The Cross-Host Mechanism" sections, and read ${read_root}/docs/platforms/claude-code-runtime.md paying attention to its "## Cross-Host Consult Channel" section. In this run the opposite host (Codex) is AVAILABLE and authorized: the oh-no-harness:code-reviewer-codex cross-host consult agent and its node codex-companion.mjs transport are available. The verifier role is out of cross-host scope: it is an unconditional SINGLE self-host pass with ZERO cross-host consults, dispatched only AFTER the code-reviewer pair completes and is synthesized. Exercise ONLY the cross-host code-reviewer pair and then the single self-host verifier: dispatch no other role and no other opposite-host consult agent.

Risk-gated completion claim to verify: I changed auth and session logic; verify it is safe to ship. The reviewed change is this diff (treat as the stable diff):
--- a/session.py
+++ b/session.py
@@
-def verify_token(token, expected):
-    return token == expected
+def verify_token(token, expected):
+    if token == expected:
+        return True
+    return len(token) == len(expected)
The reviewed change weakens token verification: on a mismatch it now returns True whenever the two lengths match, which is an authentication bypass. Every review instance must analyze this security regression meaningfully (authentication bypass, constant-time comparison, correctness, and test coverage) rather than only stating the smoke test is formatted correctly.

Stage 1 (code-review PAIR, FIRST): dispatch BOTH code-review instances of the SAME code-reviewer role over the SAME diff CONCURRENTLY, starting both before waiting for either result:

Current-host instance: a Claude current-host subagent using subagent_type oh-no-harness:code-reviewer. Its task prompt must include exactly these lines: Instance: current-host; Marker: OH_NO_XHOST_VBC_CURRENT_OK; Scope: the fixed session.py diff only; Do not edit files; Do not make any cross-host or opposite-host call; Run the complete code-reviewer role over the diff; Expected output: marker line plus findings with file, line, issue, severity, evidence, and recommended fix.

Opposite-host instance: exactly one Codex response through the dedicated read-only consult agent, dispatched with subagent_type oh-no-harness:code-reviewer-codex. A valid live result requires oh-no-harness:code-reviewer-codex to perform exactly one required Bash call to node codex-companion.mjs task in the foreground, wait for completion, and return the Codex companion stdout; a marker generated locally by the wrapper, a background acknowledgement, or a status pointer is not valid. The harness parser, not you, verifies the Bash event stream and codex-companion stdout after the run, so do not poll status, fetch a deferred result, or run a second codex-companion or consult call for liveness. The codex-companion Bash command MUST NOT include --write and MUST NOT include --background; the code-reviewer-codex agent runs codex-companion read-only by design (no --write flag) and synchronously in the foreground, and a permission denial from an attempted --write command is a test failure even if a later retry succeeds. The code-reviewer-codex packet MUST use --prompt-file with a redacted packet that: is explicitly read-only with no edits, no writes, and no installs; forbids further rescue, another workflow skill, and any host-to-host call back to Claude or a third host (one cross-host hop); instructs Codex to dispatch the oh-no-code-reviewer role agent to run the complete code-reviewer role over this same session.py diff; and requires Codex to return the role-owned result of oh-no-code-reviewer plus role-ownership proof that oh-no-code-reviewer, not a parent inline Codex answer, produced it, ending with exactly the marker OH_NO_XHOST_VBC_CODEX_RETURN_OK. If oh-no-harness:code-reviewer-codex cannot run exactly one node codex-companion.mjs Bash call in the foreground, or cannot prove oh-no-code-reviewer role ownership, do not synthesize success.

Stage 2 (confirming verifier, AFTER the code-reviewer pair returns and is synthesized): dispatch EXACTLY ONE self-host subagent using subagent_type oh-no-harness:verifier. Do NOT dispatch oh-no-harness:verifier-codex, do NOT run any codex-companion or cross-host call for the verifier, and do NOT run a second or fallback verifier instance: the confirming verifier is a single self-host pass with zero cross-host consults. Its task prompt must include exactly these lines: Role: verifier; Marker: OH_NO_XHOST_VBC_VERIFIER_OK; Scope: confirm the synthesized code-review verdict for the session.py diff; Do not edit files; Do not make any cross-host or opposite-host call; Expected output: marker line plus a ship or do-not-ship evidence judgement.

Wait for all results and do not end while a worker is still pending. Keep the review-then-verify order: the single self-host verifier is dispatched only after both code-reviewer instances return and are synthesized. After the code-reviewer pair is synthesized and the single self-host verifier returns, reply as the current-host main judge with exactly the marker OH_NO_CLAUDE_VBC_XHOST_OK and include, as its own lines: both review instances dispatched: current-host code-reviewer and opposite-host code-reviewer-codex; started-concurrently: yes; foreground read-only call: yes; role ownership (oh-no-code-reviewer) proven: yes; confirming verifier: single self-host oh-no-harness:verifier; cross-host verifier consults: zero; review-then-verify order: yes; synthesized one verdict: yes; the instance markers OH_NO_XHOST_VBC_CURRENT_OK, OH_NO_XHOST_VBC_CODEX_RETURN_OK, and OH_NO_XHOST_VBC_VERIFIER_OK; and a single merged verdict block recording consensus, contradictions, unique insights, blind spots, and recommended next action.
PROMPT
)

  local cmd=(
    "$CLAUDE_BIN"
    --print
    --verbose
    --output-format stream-json
    --include-hook-events
    --model "$FUSION_RESCUE_LIVE_MODEL"
    --max-budget-usd "$FUSION_RESCUE_MAX_BUDGET_USD"
    --permission-mode bypassPermissions
    --allowedTools "Bash(node *)"
    --tools default
    --add-dir "$read_root"
    --no-session-persistence
    --system-prompt "You are a read-only live smoke test runner. Use the invoked Oh No Harness skill, one Claude current-host oh-no-harness:code-reviewer subagent, the oh-no-harness:code-reviewer-codex read-only consult agent, and one self-host oh-no-harness:verifier subagent only for this requested cross-host code-review pair plus confirming self-host verifier. The opposite host (Codex) is available. Do not edit files."
  )

  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi

  "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

  "$PYTHON_BIN" - "$out_file" "$err_file" "$summary_file" "$FUSION_RESCUE_LIVE_MODEL" <<'PY'
import json
import re
import sys
from pathlib import Path

out_path, err_path, summary_path, model = sys.argv[1:5]

CURRENT_MARKER = "OH_NO_XHOST_VBC_CURRENT_OK"
CODEX_RETURN_MARKER = "OH_NO_XHOST_VBC_CODEX_RETURN_OK"
VERIFIER_MARKER = "OH_NO_XHOST_VBC_VERIFIER_OK"
FINAL_MARKER = "OH_NO_CLAUDE_VBC_XHOST_OK"
CURRENT_ROLE = "oh-no-harness:code-reviewer"
CODEX_ROLE = "oh-no-harness:code-reviewer-codex"
CODEX_SIDE_ROLE = "oh-no-code-reviewer"
VERIFIER_ROLE = "oh-no-harness:verifier"
VERIFIER_CODEX_ROLE = "oh-no-harness:verifier-codex"

required_final_markers = [
    FINAL_MARKER,
    CURRENT_MARKER,
    CODEX_RETURN_MARKER,
    VERIFIER_MARKER,
    "current-host code-reviewer",
    "opposite-host code-reviewer-codex",
    "foreground read-only call: yes",
    CODEX_SIDE_ROLE,
    "single self-host oh-no-harness:verifier",
    "cross-host verifier consults: zero",
    "review-then-verify order: yes",
    "synthesized one verdict: yes",
]
required_synthesis_fields = [
    "consensus",
    "contradictions",
    "unique insights",
    "blind spots",
    "recommended next action",
]
secret_patterns = [
    re.compile(r"(?<![A-Za-z0-9])sk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"(?i)(api[_-]?key|access[_-]?token|refresh[_-]?token|private[_-]?key|cookie)[ \t]*[:=][ \t]*['\"]?[A-Za-z0-9_./+=-]{12,}"),
]
forbidden_write_tool_names = {"Edit", "Write", "NotebookEdit"}

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
if "unknown command" in err_text.lower() or "unknown agent" in err_text.lower():
    raise SystemExit(f"Claude VBC cross-host review live saw unavailable command/agent in stderr: {err_text[:2000]!r}")

init_agents = set()
init_tools = set()
errors = []
current_dispatches = []
codex_dispatches = []
verifier_dispatches = []
verifier_codex_dispatches = []
# Lifecycle proof (mirrors the cross-host-review lane): task_started +
# task_notification(status=="completed") per reviewer instance feed the
# peak-in-flight walk that proves the pair overlapped, and the confirming
# verifier must START only after BOTH reviewer instances COMPLETED (dispatch
# order alone cannot prove either).
reviewer_task_ids = set()
reviewer_started_indices = []
reviewer_completed_ids = set()
reviewer_completion_indices = []
verifier_started_indices = []
unexpected_write_uses = []
codex_bash_tool_ids = set()
codex_write_commands = []
codex_background_commands = []
codex_bash_success_texts = []
codex_bash_success_indexes = []
codex_bash_failures = []
permission_denials = []
non_user_text_parts = []
pending_background_events = []

with open(out_path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        text = collect_text(data)
        if data.get("type") == "system" and (
            "Command running in background" in text
            or ("Codex task" in text and "still running" in text)
        ):
            pending_background_events.append((index, text[:2000]))
        if any(pattern.search(text) for pattern in secret_patterns):
            raise SystemExit(f"Claude VBC cross-host review live transcript exposed a secret-like value near line {index}")
        if data.get("type") == "system" and data.get("subtype") == "init":
            init_agents.update(data.get("agents", []))
            init_tools.update(data.get("tools", []))
        if data.get("type") == "assistant":
            non_user_text_parts.append(text)
            for part in data.get("message", {}).get("content", []):
                if part.get("type") == "tool_use" and part.get("name") in forbidden_write_tool_names:
                    unexpected_write_uses.append((index, part.get("name"), collect_text(part.get("input", ""))[:1000]))
                if part.get("type") == "tool_use" and part.get("name") == "Bash":
                    command = str(part.get("input", {}).get("command", ""))
                    if "codex-companion.mjs" in command:
                        # The --write/--background forbids cover EVERY
                        # codex-companion command, including a rogue call that
                        # inlines the packet instead of using --prompt-file.
                        if re.search(r"(?<!\S)--write(?!\S)", command):
                            codex_write_commands.append((index, command[:2000]))
                        if re.search(r"(?<!\S)--background(?!\S)", command):
                            codex_background_commands.append((index, command[:2000]))
                        # Count only the actual delegation `task` call (which
                        # passes the packet via --prompt-file), not the read-only
                        # companion-path resolution probes (ls / [ -f ] / versions
                        # checks) the kernel runs first to resolve/verify the
                        # companion before delegating.
                        if "--prompt-file" in command:
                            codex_bash_tool_ids.add(part.get("id"))
                if part.get("type") == "tool_use" and part.get("name") in {"Agent", "Task"}:
                    payload = part.get("input", {})
                    payload_text = collect_text(payload)
                    subagent_type = str(payload.get("subagent_type", ""))
                    if subagent_type == CODEX_ROLE:
                        codex_dispatches.append((index, payload_text))
                    elif subagent_type == CURRENT_ROLE:
                        current_dispatches.append((index, payload_text))
                    elif subagent_type == VERIFIER_CODEX_ROLE:
                        verifier_codex_dispatches.append((index, payload_text))
                    elif subagent_type == VERIFIER_ROLE:
                        verifier_dispatches.append((index, payload_text))
                if part.get("type") == "text":
                    non_user_text_parts.append(part.get("text", ""))
        if data.get("type") == "system" and data.get("subtype") == "task_started":
            started_type = str(data.get("subagent_type", "") or "")
            if started_type in {CURRENT_ROLE, CODEX_ROLE}:
                reviewer_task_ids.add(data.get("task_id"))
                reviewer_started_indices.append((index, data.get("task_id")))
            elif started_type == VERIFIER_ROLE:
                verifier_started_indices.append((index, data.get("task_id")))
        if data.get("type") == "system" and data.get("subtype") in {"task_updated", "task_notification"}:
            # Some task_updated events carry status under patch.status (see the
            # natural-session lane precedent); accept both so a completion is
            # never silently dropped.
            if (data.get("status") or (data.get("patch") or {}).get("status")) == "completed":
                completed_task_id = data.get("task_id")
                if (
                    completed_task_id in reviewer_task_ids
                    and completed_task_id not in reviewer_completed_ids
                ):
                    reviewer_completed_ids.add(completed_task_id)
                    reviewer_completion_indices.append((index, completed_task_id))
            non_user_text_parts.append(text)
        if data.get("type") == "user":
            for part in data.get("message", {}).get("content", []):
                if not isinstance(part, dict):
                    continue
                if part.get("tool_use_id") not in codex_bash_tool_ids:
                    continue
                result_text = collect_text(part)
                if "Command running in background" in result_text or (
                    "Codex task" in result_text and "still running" in result_text
                ):
                    raise SystemExit(
                        "Claude VBC cross-host review live codex-companion Bash did not complete "
                        f"in the foreground: {result_text[:1000]!r}"
                    )
                if bool(part.get("is_error")):
                    codex_bash_failures.append((index, result_text[:1000]))
                else:
                    codex_bash_success_indexes.append(index)
                    codex_bash_success_texts.append(result_text)
        tool_result = data.get("tool_use_result") or {}
        if isinstance(tool_result, dict) and tool_result.get("agentType", ""):
            non_user_text_parts.append(collect_text(tool_result))
        if data.get("type") == "result":
            permission_denials.extend(data.get("permission_denials") or [])
            non_user_text_parts.append(str(data.get("result", "")))
            if data.get("is_error") is True:
                errors.append((index, str(data.get("result", ""))[:1000]))

if errors:
    raise SystemExit(f"Claude VBC cross-host review live returned errors: {errors!r}")
if unexpected_write_uses:
    raise SystemExit(f"Claude VBC cross-host review live used write-capable tools: {unexpected_write_uses!r}")
if codex_write_commands:
    raise SystemExit(f"Claude VBC cross-host review live invoked codex-companion with --write: {codex_write_commands!r}")
if codex_background_commands:
    raise SystemExit(f"Claude VBC cross-host review live invoked codex-companion with --background: {codex_background_commands!r}")
if permission_denials:
    raise SystemExit(f"Claude VBC cross-host review live had permission denials: {permission_denials!r}")

if CODEX_ROLE not in init_agents:
    raise SystemExit(
        f"Claude VBC cross-host review live did not expose {CODEX_ROLE} agent; "
        f"got={sorted(agent for agent in init_agents if 'code-reviewer' in agent)!r}"
    )
if not ({"Task", "Agent", "Workflow"} & init_tools):
    raise SystemExit(f"Claude VBC cross-host review live did not expose subagent tooling; tools={sorted(init_tools)!r}")

# (a) code-reviewer + code-reviewer-codex both dispatched (exactly one each).
if len(current_dispatches) != 1:
    raise SystemExit(
        f"Claude VBC cross-host review live expected exactly one {CURRENT_ROLE} dispatch, got {current_dispatches!r}"
    )
if len(codex_dispatches) != 1:
    raise SystemExit(
        f"Claude VBC cross-host review live expected exactly one {CODEX_ROLE} dispatch, got {codex_dispatches!r}"
    )

# (b) verifier=self-1: EXACTLY ONE self-host verifier, ZERO verifier-codex.
if len(verifier_dispatches) != 1:
    raise SystemExit(
        f"Claude VBC cross-host review live expected exactly one self-host {VERIFIER_ROLE} dispatch "
        f"(verifier=self-1), got {verifier_dispatches!r}"
    )
if verifier_codex_dispatches:
    raise SystemExit(
        f"Claude VBC cross-host review live dispatched {VERIFIER_CODEX_ROLE} (verifier must be self-host only): "
        f"{verifier_codex_dispatches!r}"
    )

# (c) review-then-verify order: the confirming verifier runs after the reviewer pair.
current_index = current_dispatches[0][0]
codex_index = codex_dispatches[0][0]
verifier_index = verifier_dispatches[0][0]
if not (verifier_index > current_index and verifier_index > codex_index):
    raise SystemExit(
        "Claude VBC cross-host review live did not keep the review-then-verify order (verifier before the "
        f"reviewer pair): current_index={current_index} codex_index={codex_index} verifier_index={verifier_index}"
    )

# (c2) Completion-based review-then-verify proof (fail closed): the verifier
# may START only after BOTH reviewer instances COMPLETED. A verifier dispatched
# while the pair was still running would still sort later in the stream, so the
# dispatch-index check above cannot prove this on its own.
if len(reviewer_started_indices) < 2:
    raise SystemExit(
        "Claude VBC cross-host review live captured task_started for "
        f"{len(reviewer_started_indices)} reviewer instances (need 2)"
    )
if len(reviewer_completed_ids) < 2:
    raise SystemExit(
        "Claude VBC cross-host review live captured completion for "
        f"{len(reviewer_completed_ids)} reviewer instances (need 2; cannot prove the verifier waited)"
    )
if not verifier_started_indices:
    raise SystemExit(
        "Claude VBC cross-host review live captured no verifier task_started event "
        "(cannot prove the review-then-verify order on completions)"
    )
last_reviewer_completion = max(idx for idx, _ in reviewer_completion_indices)
first_verifier_start = min(idx for idx, _ in verifier_started_indices)
if not (first_verifier_start > last_reviewer_completion):
    raise SystemExit(
        "Claude VBC cross-host review live started the verifier before both reviewer instances completed: "
        f"last_reviewer_completion={last_reviewer_completion} first_verifier_start={first_verifier_start}"
    )

# (c3) The two reviewer instances overlapped (peak in-flight >= 2). A purely
# serial run (start, complete, start, complete) never exceeds 1 in flight.
CONCURRENCY_MIN = 2
lifecycle = sorted(
    [(idx, 1) for idx, _ in reviewer_started_indices]
    + [(idx, -1) for idx, _ in reviewer_completion_indices]
)
in_flight = 0
peak_in_flight = 0
for _, delta in lifecycle:
    in_flight += delta
    if in_flight > peak_in_flight:
        peak_in_flight = in_flight
if peak_in_flight < CONCURRENCY_MIN:
    raise SystemExit(
        "Claude VBC cross-host review live did not prove the reviewer pair overlapped: "
        f"peak in-flight was {peak_in_flight} (need >= {CONCURRENCY_MIN}); "
        f"started={len(reviewer_started_indices)} completed={len(reviewer_completion_indices)}. "
        "A purely serial run peaks at 1 in flight."
    )

# The outbound opposite-host packet must preserve role ownership + read-only.
codex_payload = codex_dispatches[0][1]
for marker in (CODEX_SIDE_ROLE, CODEX_RETURN_MARKER, "read-only"):
    if marker.lower() not in codex_payload.lower():
        raise SystemExit(
            f"Claude VBC cross-host review live code-reviewer-codex packet missed role-ownership marker {marker!r}; "
            f"payload={codex_payload[:2000]!r}"
        )

# (d) The code-reviewer-codex made exactly one read-only foreground codex-companion call.
# Exactly one total codex-companion delegation also proves ZERO cross-host verifier delegation.
if not codex_bash_tool_ids:
    raise SystemExit("Claude VBC cross-host review live did not invoke codex-companion.mjs through oh-no-harness:code-reviewer-codex Bash")
if len(codex_bash_tool_ids) != 1:
    raise SystemExit(
        "Claude VBC cross-host review live expected exactly one codex-companion.mjs Bash invocation "
        f"(the code-reviewer one; a second would mean a cross-host verifier), got {sorted(codex_bash_tool_ids)!r}"
    )
if codex_bash_failures:
    raise SystemExit(f"Claude VBC cross-host review live codex-companion Bash failed: {codex_bash_failures!r}")
if len(codex_bash_success_indexes) != 1:
    raise SystemExit(f"Claude VBC cross-host review live expected exactly one successful codex-companion.mjs Bash result, got {codex_bash_success_indexes!r}")

# (e) The returned opposite-host result proves oh-no-code-reviewer role ownership.
codex_bash_text = "\n".join(codex_bash_success_texts)
if CODEX_RETURN_MARKER not in codex_bash_text:
    raise SystemExit(
        f"Claude VBC cross-host review live did not capture {CODEX_RETURN_MARKER} from codex-companion.mjs stdout"
    )
if CODEX_SIDE_ROLE not in codex_bash_text.lower():
    raise SystemExit(
        "Claude VBC cross-host review live codex-companion stdout did not prove "
        f"{CODEX_SIDE_ROLE} role ownership (possible parent inline Codex answer)"
    )
last_codex_bash_success_index = max(codex_bash_success_indexes) if codex_bash_success_indexes else None
late_pending_background_events = [
    event for event in pending_background_events
    if last_codex_bash_success_index is None or event[0] > last_codex_bash_success_index
]
if late_pending_background_events:
    raise SystemExit(
        "Claude VBC cross-host review live left background/still-running work after the Codex "
        f"foreground completion: {late_pending_background_events!r}"
    )

# (f) Final synthesized success marker and its required merged-verdict content.
success_text = "\n".join(part for part in non_user_text_parts if FINAL_MARKER in part)
if not success_text:
    detail = f"; pending events={pending_background_events!r}" if pending_background_events else ""
    raise SystemExit(f"Claude VBC cross-host review live did not return success marker {FINAL_MARKER}{detail}")
lower_success_text = success_text.lower()
for marker in required_final_markers:
    if marker.lower() not in lower_success_text:
        raise SystemExit(f"Claude VBC cross-host review live missing final marker/text: {marker!r}")
for field in required_synthesis_fields:
    if field.lower() not in lower_success_text:
        raise SystemExit(f"Claude VBC cross-host review live missing synthesis field: {field!r}")

summary = {
    "status": "passed",
    "model": model,
    "current_host_instance": {
        "subagent_type": CURRENT_ROLE,
        "returned_marker": CURRENT_MARKER,
    },
    "opposite_host_instance": {
        "subagent_type": CODEX_ROLE,
        "codex_side_role": CODEX_SIDE_ROLE,
        "bash_tool_uses": len(codex_bash_tool_ids),
        "returned_marker": CODEX_RETURN_MARKER,
        "permission_denials": len(permission_denials),
    },
    "confirming_verifier": {
        "subagent_type": VERIFIER_ROLE,
        "dispatches": len(verifier_dispatches),
        "verifier_codex_dispatches": len(verifier_codex_dispatches),
        "cross_host_verifier_delegations": 0,
        "returned_marker": VERIFIER_MARKER,
    },
    "review_then_verify": True,
    "final_marker": FINAL_MARKER,
}
Path(summary_path).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print("ok - live Claude real verification-before-completion flow dispatched cross-host code-review pair oh-no-harness:code-reviewer + oh-no-harness:code-reviewer-codex (read-only foreground codex-companion, role-owned oh-no-code-reviewer) then a single self-host oh-no-harness:verifier (verifier=self-1, zero cross-host verifier) and synthesized one verdict")
PY
}

run_sysdebug_xhost_live_test() {
  if [[ "$RUN_SYSDEBUG_XHOST_LIVE" != "1" ]]; then
    log "Skipping live Claude cross-host DEBUGGER PAIR smoke test (real systematic-debugging flow)"
    printf 'Run with --sysdebug-xhost-live or OH_NO_SYSDEBUG_XHOST_LIVE=1 to verify the real systematic-debugging flow dispatching the cross-host debugger pair (current-host oh-no-harness:debugger plus opposite-host oh-no-harness:debugger-codex) synthesized into one root-cause direction.\n' >&2
    return
  fi

  log "Running live Claude cross-host DEBUGGER PAIR smoke test via real systematic-debugging (${LIVE_LOAD_MODE}, model ${FUSION_RESCUE_LIVE_MODEL})"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/sysdebug-xhost-claude.jsonl"
  local err_file="$RUN_DIR/sysdebug-xhost-claude.err"
  local summary_file="$RUN_DIR/sysdebug-xhost-claude.summary.json"
  local read_root="$PLUGIN_ROOT"

  if [[ "$LIVE_LOAD_MODE" == "installed" ]]; then
    read_root="$(cached_plugin_root)"
  fi

  # NOTE: unquoted heredoc (expands ${read_root}/${PLUGIN_NAME}) inside $(...).
  # Bash tracks single-quote parity across the whole substitution, so the prompt
  # text MUST NOT contain apostrophes or an unintended $ (both break `bash -n`).
  local prompt
  prompt=$(cat <<PROMPT
/${PLUGIN_NAME}:systematic-debugging require-cross-host read-only live cross-host DEBUGGER PAIR smoke test only. Do not edit files, do not create artifacts, do not install plugins, do not run any write-capable command, and do not run the failing command itself; reason only from the inline failure facts.

Named THOROUGH trigger: repeated intermittent failure under new concurrency semantics. Read ${read_root}/docs/platforms/claude-code.md Cross-Host Consult Channel before dispatch; pairing is trigger-driven, not the debugger default.

First, read ${read_root}/docs/shared/cross-host-review.md and ${read_root}/docs/platforms/claude-code.md Cross-Host Consult Channel. In this run the opposite host (Codex) is AVAILABLE and authorized: the oh-no-harness:debugger-codex consult owner and codex-companion transport are available. The named THOROUGH repeated-failure and concurrency trigger selects a CROSS-HOST debugger pair, NOT the Same-Host Parallel Fallback. Exercise ONLY that pair: dispatch no other role and no other opposite-host consult agent.

Synthetic bug (all failure facts inline; no code change requested): a request handler intermittently returns HTTP 200 with an empty body under concurrent load. The response builder writes the body inside a background task, but the handler returns its response object before that background task has finished writing, so the body is occasionally empty. Reproduction: 50 concurrent requests, roughly 1 in 20 returns an empty body. There is no stack trace; logs show the background writer completing AFTER the response is flushed to the client.

Dispatch BOTH debugger instances of the SAME debugger role over the SAME failure and evidence packet CONCURRENTLY, starting both before waiting for either result:

Current-host instance: a Claude current-host subagent using subagent_type oh-no-harness:debugger. Its task prompt must include exactly these lines: Instance: current-host; Marker: OH_NO_XHOST_SYSDEBUG_CURRENT_OK; Scope: the inline failure and evidence packet only; Do not edit files; Do not make any cross-host or opposite-host call; Run the complete debugger root-cause investigation; Expected output: marker line plus a ranked root-cause hypothesis with supporting evidence.

Opposite-host instance: exactly one Codex response through the dedicated read-only consult agent, dispatched with subagent_type oh-no-harness:debugger-codex. A valid live result requires oh-no-harness:debugger-codex to perform exactly one required Bash call to node codex-companion.mjs task in the foreground, wait for completion, and return the Codex companion stdout; a marker generated locally by the wrapper, a background acknowledgement, or a status pointer is not valid. The harness parser, not you, verifies the Bash event stream and codex-companion stdout after the run, so do not poll status, fetch a deferred result, or run a second codex-companion or consult call for liveness. The codex-companion Bash command MUST NOT include --write and MUST NOT include --background; the debugger-codex agent runs codex-companion read-only by design (no --write flag) and synchronously in the foreground, and a permission denial from an attempted --write command is a test failure even if a later retry succeeds. The debugger-codex packet MUST use --prompt-file with a redacted packet that: is explicitly read-only with no edits, no writes, and no installs; forbids further rescue, another workflow skill, and any host-to-host call back to Claude or a third host (one cross-host hop); instructs Codex to dispatch the oh-no-debugger role agent to run the complete debugger root-cause investigation over this same failure and evidence packet; and requires Codex to return the role-owned result of oh-no-debugger plus role-ownership proof that oh-no-debugger, not a parent inline Codex answer, produced it, ending with exactly the marker OH_NO_XHOST_SYSDEBUG_CODEX_RETURN_OK. If oh-no-harness:debugger-codex cannot run exactly one node codex-companion.mjs Bash call in the foreground, or cannot prove oh-no-debugger role ownership, do not synthesize success.

Start both instances before waiting when possible. Wait for both results and do not end while a worker is still pending. After the current-host oh-no-harness:debugger subagent and the single opposite-host oh-no-harness:debugger-codex consult both return, synthesize immediately as the current-host main judge into ONE root-cause direction rather than concatenate: reconcile the competing hypotheses, deduplicate, and record host provenance on each finding. The final answer must contain exactly the marker OH_NO_CLAUDE_SYSDEBUG_XHOST_OK and must include, as its own lines: both instances dispatched: current-host debugger and opposite-host debugger-codex; started-concurrently: yes; foreground read-only call: yes; role ownership (oh-no-debugger) proven: yes; synthesized one root-cause direction: yes; the instance markers OH_NO_XHOST_SYSDEBUG_CURRENT_OK and OH_NO_XHOST_SYSDEBUG_CODEX_RETURN_OK; and a single merged root-cause block recording consensus, contradictions, unique insights, blind spots, and recommended next action.
PROMPT
)

  local cmd=(
    "$CLAUDE_BIN"
    --print
    --verbose
    --output-format stream-json
    --include-hook-events
    --model "$FUSION_RESCUE_LIVE_MODEL"
    --max-budget-usd "$FUSION_RESCUE_MAX_BUDGET_USD"
    --permission-mode bypassPermissions
    --allowedTools "Bash(node *)"
    --tools default
    --add-dir "$read_root"
    --no-session-persistence
    --system-prompt "You are a read-only live smoke test runner. Use the invoked Oh No Harness skill, one Claude current-host oh-no-harness:debugger subagent, and the oh-no-harness:debugger-codex read-only consult agent only for this requested cross-host debugger pair. The opposite host (Codex) is available. Do not edit files."
  )

  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi

  "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

  "$PYTHON_BIN" - "$out_file" "$err_file" "$summary_file" "$FUSION_RESCUE_LIVE_MODEL" <<'PY'
import json
import re
import sys
from pathlib import Path

out_path, err_path, summary_path, model = sys.argv[1:5]

CURRENT_MARKER = "OH_NO_XHOST_SYSDEBUG_CURRENT_OK"
CODEX_RETURN_MARKER = "OH_NO_XHOST_SYSDEBUG_CODEX_RETURN_OK"
FINAL_MARKER = "OH_NO_CLAUDE_SYSDEBUG_XHOST_OK"
CURRENT_ROLE = "oh-no-harness:debugger"
CODEX_ROLE = "oh-no-harness:debugger-codex"
CODEX_SIDE_ROLE = "oh-no-debugger"

required_final_markers = [
    FINAL_MARKER,
    CURRENT_MARKER,
    CODEX_RETURN_MARKER,
    "current-host debugger",
    "opposite-host debugger-codex",
    "foreground read-only call: yes",
    CODEX_SIDE_ROLE,
    "synthesized one root-cause direction: yes",
]
required_synthesis_fields = [
    "consensus",
    "contradictions",
    "unique insights",
    "blind spots",
    "recommended next action",
]
secret_patterns = [
    re.compile(r"(?<![A-Za-z0-9])sk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"(?i)(api[_-]?key|access[_-]?token|refresh[_-]?token|private[_-]?key|cookie)[ \t]*[:=][ \t]*['\"]?[A-Za-z0-9_./+=-]{12,}"),
]
forbidden_write_tool_names = {"Edit", "Write", "NotebookEdit"}

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
if "unknown command" in err_text.lower() or "unknown agent" in err_text.lower():
    raise SystemExit(f"Claude systematic-debugging cross-host live saw unavailable command/agent in stderr: {err_text[:2000]!r}")

init_agents = set()
init_tools = set()
errors = []
current_dispatches = []
codex_dispatches = []
unexpected_write_uses = []
codex_bash_tool_ids = set()
codex_write_commands = []
codex_background_commands = []
codex_bash_success_texts = []
codex_bash_success_indexes = []
codex_bash_failures = []
permission_denials = []
non_user_text_parts = []
pending_background_events = []
# Lifecycle proof (mirrors the cross-host-review lane): task_started +
# task_notification(status=="completed") per debugger instance feed the
# peak-in-flight walk that proves the pair overlapped (dispatch order alone
# cannot prove concurrency).
reviewer_task_ids = set()
reviewer_started_indices = []
reviewer_completed_ids = set()
reviewer_completion_indices = []

with open(out_path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        text = collect_text(data)
        if data.get("type") == "system" and (
            "Command running in background" in text
            or ("Codex task" in text and "still running" in text)
        ):
            pending_background_events.append((index, text[:2000]))
        if any(pattern.search(text) for pattern in secret_patterns):
            raise SystemExit(f"Claude systematic-debugging cross-host live transcript exposed a secret-like value near line {index}")
        if data.get("type") == "system" and data.get("subtype") == "init":
            init_agents.update(data.get("agents", []))
            init_tools.update(data.get("tools", []))
        if data.get("type") == "assistant":
            non_user_text_parts.append(text)
            for part in data.get("message", {}).get("content", []):
                if part.get("type") == "tool_use" and part.get("name") in forbidden_write_tool_names:
                    unexpected_write_uses.append((index, part.get("name"), collect_text(part.get("input", ""))[:1000]))
                if part.get("type") == "tool_use" and part.get("name") == "Bash":
                    command = str(part.get("input", {}).get("command", ""))
                    if "codex-companion.mjs" in command:
                        # The --write/--background forbids cover EVERY
                        # codex-companion command, including a rogue call that
                        # inlines the packet instead of using --prompt-file.
                        if re.search(r"(?<!\S)--write(?!\S)", command):
                            codex_write_commands.append((index, command[:2000]))
                        if re.search(r"(?<!\S)--background(?!\S)", command):
                            codex_background_commands.append((index, command[:2000]))
                        # Count only the actual delegation `task` call (which
                        # passes the packet via --prompt-file), not the read-only
                        # companion-path resolution probes (ls / [ -f ] / versions
                        # checks) the kernel runs first to resolve/verify the
                        # companion before delegating.
                        if "--prompt-file" in command:
                            codex_bash_tool_ids.add(part.get("id"))
                if part.get("type") == "tool_use" and part.get("name") in {"Agent", "Task"}:
                    payload = part.get("input", {})
                    payload_text = collect_text(payload)
                    subagent_type = str(payload.get("subagent_type", ""))
                    if subagent_type == CODEX_ROLE:
                        codex_dispatches.append((index, payload_text))
                    elif subagent_type == CURRENT_ROLE:
                        current_dispatches.append((index, payload_text))
                if part.get("type") == "text":
                    non_user_text_parts.append(part.get("text", ""))
        if data.get("type") == "system" and data.get("subtype") == "task_started":
            started_type = str(data.get("subagent_type", "") or "")
            if started_type in {CURRENT_ROLE, CODEX_ROLE}:
                reviewer_task_ids.add(data.get("task_id"))
                reviewer_started_indices.append((index, data.get("task_id")))
        if data.get("type") == "system" and data.get("subtype") in {"task_updated", "task_notification"}:
            # Some task_updated events carry status under patch.status (see the
            # natural-session lane precedent); accept both so a completion is
            # never silently dropped.
            if (data.get("status") or (data.get("patch") or {}).get("status")) == "completed":
                completed_task_id = data.get("task_id")
                if (
                    completed_task_id in reviewer_task_ids
                    and completed_task_id not in reviewer_completed_ids
                ):
                    reviewer_completed_ids.add(completed_task_id)
                    reviewer_completion_indices.append((index, completed_task_id))
            non_user_text_parts.append(text)
        if data.get("type") == "user":
            for part in data.get("message", {}).get("content", []):
                if not isinstance(part, dict):
                    continue
                if part.get("tool_use_id") not in codex_bash_tool_ids:
                    continue
                result_text = collect_text(part)
                if "Command running in background" in result_text or (
                    "Codex task" in result_text and "still running" in result_text
                ):
                    raise SystemExit(
                        "Claude systematic-debugging cross-host live codex-companion Bash did not complete "
                        f"in the foreground: {result_text[:1000]!r}"
                    )
                if bool(part.get("is_error")):
                    codex_bash_failures.append((index, result_text[:1000]))
                else:
                    codex_bash_success_indexes.append(index)
                    codex_bash_success_texts.append(result_text)
        tool_result = data.get("tool_use_result") or {}
        if isinstance(tool_result, dict) and tool_result.get("agentType", ""):
            non_user_text_parts.append(collect_text(tool_result))
        if data.get("type") == "result":
            permission_denials.extend(data.get("permission_denials") or [])
            non_user_text_parts.append(str(data.get("result", "")))
            if data.get("is_error") is True:
                errors.append((index, str(data.get("result", ""))[:1000]))

if errors:
    raise SystemExit(f"Claude systematic-debugging cross-host live returned errors: {errors!r}")
if unexpected_write_uses:
    raise SystemExit(f"Claude systematic-debugging cross-host live used write-capable tools: {unexpected_write_uses!r}")
if codex_write_commands:
    raise SystemExit(f"Claude systematic-debugging cross-host live invoked codex-companion with --write: {codex_write_commands!r}")
if codex_background_commands:
    raise SystemExit(f"Claude systematic-debugging cross-host live invoked codex-companion with --background: {codex_background_commands!r}")
if permission_denials:
    raise SystemExit(f"Claude systematic-debugging cross-host live had permission denials: {permission_denials!r}")

if CODEX_ROLE not in init_agents:
    raise SystemExit(
        f"Claude systematic-debugging cross-host live did not expose {CODEX_ROLE} agent; "
        f"got={sorted(agent for agent in init_agents if 'debugger' in agent)!r}"
    )
if not ({"Task", "Agent", "Workflow"} & init_tools):
    raise SystemExit(f"Claude systematic-debugging cross-host live did not expose subagent tooling; tools={sorted(init_tools)!r}")

# debugger AND debugger-codex both dispatched (exactly one each).
if len(current_dispatches) != 1:
    raise SystemExit(
        f"Claude systematic-debugging cross-host live expected exactly one {CURRENT_ROLE} dispatch, got {current_dispatches!r}"
    )
if len(codex_dispatches) != 1:
    raise SystemExit(
        f"Claude systematic-debugging cross-host live expected exactly one {CODEX_ROLE} dispatch, got {codex_dispatches!r}"
    )

# The two debugger instances overlapped (peak in-flight >= 2). A purely serial
# run (start, complete, start, complete) never exceeds 1 in flight.
if len(reviewer_started_indices) < 2:
    raise SystemExit(
        "Claude systematic-debugging cross-host live captured task_started for "
        f"{len(reviewer_started_indices)} debugger instances (need 2)"
    )
CONCURRENCY_MIN = 2
lifecycle = sorted(
    [(idx, 1) for idx, _ in reviewer_started_indices]
    + [(idx, -1) for idx, _ in reviewer_completion_indices]
)
in_flight = 0
peak_in_flight = 0
for _, delta in lifecycle:
    in_flight += delta
    if in_flight > peak_in_flight:
        peak_in_flight = in_flight
if peak_in_flight < CONCURRENCY_MIN:
    raise SystemExit(
        "Claude systematic-debugging cross-host live did not prove the debugger pair overlapped: "
        f"peak in-flight was {peak_in_flight} (need >= {CONCURRENCY_MIN}); "
        f"started={len(reviewer_started_indices)} completed={len(reviewer_completion_indices)}. "
        "A purely serial run peaks at 1 in flight."
    )

# The outbound opposite-host packet must preserve role ownership + read-only.
codex_payload = codex_dispatches[0][1]
for marker in (CODEX_SIDE_ROLE, CODEX_RETURN_MARKER, "read-only"):
    if marker.lower() not in codex_payload.lower():
        raise SystemExit(
            f"Claude systematic-debugging cross-host live debugger-codex packet missed role-ownership marker {marker!r}; "
            f"payload={codex_payload[:2000]!r}"
        )

# The debugger-codex made exactly one read-only foreground codex-companion call.
if not codex_bash_tool_ids:
    raise SystemExit("Claude systematic-debugging cross-host live did not invoke codex-companion.mjs through oh-no-harness:debugger-codex Bash")
if len(codex_bash_tool_ids) != 1:
    raise SystemExit(f"Claude systematic-debugging cross-host live expected exactly one codex-companion.mjs Bash invocation, got {sorted(codex_bash_tool_ids)!r}")
if codex_bash_failures:
    raise SystemExit(f"Claude systematic-debugging cross-host live codex-companion Bash failed: {codex_bash_failures!r}")
if len(codex_bash_success_indexes) != 1:
    raise SystemExit(f"Claude systematic-debugging cross-host live expected exactly one successful codex-companion.mjs Bash result, got {codex_bash_success_indexes!r}")

# The returned opposite-host result proves oh-no-debugger role ownership.
codex_bash_text = "\n".join(codex_bash_success_texts)
if CODEX_RETURN_MARKER not in codex_bash_text:
    raise SystemExit(
        f"Claude systematic-debugging cross-host live did not capture {CODEX_RETURN_MARKER} from codex-companion.mjs stdout"
    )
if CODEX_SIDE_ROLE not in codex_bash_text.lower():
    raise SystemExit(
        "Claude systematic-debugging cross-host live codex-companion stdout did not prove "
        f"{CODEX_SIDE_ROLE} role ownership (possible parent inline Codex answer)"
    )
last_codex_bash_success_index = max(codex_bash_success_indexes) if codex_bash_success_indexes else None
late_pending_background_events = [
    event for event in pending_background_events
    if last_codex_bash_success_index is None or event[0] > last_codex_bash_success_index
]
if late_pending_background_events:
    raise SystemExit(
        "Claude systematic-debugging cross-host live left background/still-running work after the Codex "
        f"foreground completion: {late_pending_background_events!r}"
    )

# Final synthesized single root-cause direction marker and its required content.
success_text = "\n".join(part for part in non_user_text_parts if FINAL_MARKER in part)
if not success_text:
    detail = f"; pending events={pending_background_events!r}" if pending_background_events else ""
    raise SystemExit(f"Claude systematic-debugging cross-host live did not return success marker {FINAL_MARKER}{detail}")
lower_success_text = success_text.lower()
for marker in required_final_markers:
    if marker.lower() not in lower_success_text:
        raise SystemExit(f"Claude systematic-debugging cross-host live missing final marker/text: {marker!r}")
for field in required_synthesis_fields:
    if field.lower() not in lower_success_text:
        raise SystemExit(f"Claude systematic-debugging cross-host live missing synthesis field: {field!r}")

summary = {
    "status": "passed",
    "model": model,
    "current_host_instance": {
        "subagent_type": CURRENT_ROLE,
        "returned_marker": CURRENT_MARKER,
    },
    "opposite_host_instance": {
        "subagent_type": CODEX_ROLE,
        "codex_side_role": CODEX_SIDE_ROLE,
        "bash_tool_uses": len(codex_bash_tool_ids),
        "returned_marker": CODEX_RETURN_MARKER,
        "permission_denials": len(permission_denials),
    },
    "final_marker": FINAL_MARKER,
}
Path(summary_path).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print("ok - live Claude real systematic-debugging flow dispatched cross-host debugger pair oh-no-harness:debugger + oh-no-harness:debugger-codex (read-only foreground codex-companion, role-owned oh-no-debugger) and synthesized one root-cause direction")
PY
}


main() {
  cd "$PLUGIN_ROOT"
  require_command "$CLAUDE_BIN"
  require_command "$PYTHON_BIN"

  log "Testing ${PLUGIN_ID} from ${PLUGIN_ROOT}"
  validate_manifests
  validate_hooks
  run_escape_net_offline_test
  run_active_stale_scan_reader_offline_test
  run_fusion_codex_offline_marker_test
  validate_frontmatter
  install_or_update_plugin
  run_live_tests
  run_deep_live_tests
  run_ralplan_live_test
  run_parallel_live_test
  run_fusion_rescue_live_test
  run_cross_host_fallback_live_test
  run_cross_host_review_live_test
  run_ralplan_xhost_live_test
  run_vbc_xhost_live_test
  run_sysdebug_xhost_live_test
  run_parallel_executor_live_test
  run_codex_executor_delegation_live_test
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
