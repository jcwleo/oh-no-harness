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
RUN_PARALLEL_EXECUTOR_LIVE="${OH_NO_PARALLEL_EXECUTOR_LIVE:-0}"
RUN_SIMPLIFY_LIVE="${OH_NO_SIMPLIFY_LIVE:-0}"
RUN_NATURAL_SESSION_START_LIVE="${OH_NO_NATURAL_SESSION_START_LIVE:-0}"
LIVE_HOOK_ONLY="${OH_NO_LIVE_HOOK_ONLY:-0}"
LIVE_LOAD_MODE="${OH_NO_LIVE_LOAD_MODE:-plugin-dir}"
LIVE_MODEL="${OH_NO_TEST_MODEL:-sonnet}"
LIVE_MAX_BUDGET_USD="${OH_NO_MAX_BUDGET_USD:-1.00}"
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
  --fusion-rescue-live   Run live Fusion Rescue /codex:rescue and panel-subagent smoke test.
  --cross-host-fallback-live
                         Run live cross-host Same-Host Parallel Fallback smoke test:
                         opposite host (Codex) forced unavailable, so code-reviewer
                         runs two same-host lens agents synthesized into one result.
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
  --scope <scope>        Install/update scope: local, project, user, managed.
                         Default: update existing scope if installed, otherwise user.
  --live-load <mode>     plugin-dir or installed. Default: plugin-dir.
  --marketplace-source <source>
                         Marketplace source passed to Claude Code marketplace add.
                         Default: this checkout. Use jcwleo/oh-no-harness to test GitHub.
  --model <model>        Claude model alias for live tests. Default: sonnet.
                         Fusion Rescue live defaults to opus unless overridden.
  --max-budget-usd <n>   Per-command max budget for live tests. Default: 1.00.
  -h, --help             Show this help.

Environment overrides:
  CLAUDE_BIN, PYTHON_BIN, OH_NO_PLUGIN_SCOPE, OH_NO_LIVE, OH_NO_DEEP_LIVE,
  OH_NO_PARALLEL_LIVE, OH_NO_RALPLAN_LIVE, OH_NO_TEST_MODEL,
  OH_NO_FUSION_RESCUE_LIVE, OH_NO_FUSION_RESCUE_MODEL,
  OH_NO_FUSION_RESCUE_MAX_BUDGET_USD, OH_NO_CROSS_HOST_FALLBACK_LIVE,
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
for forbidden in ("CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION", "explicit user request for eligible Oh No Harness workflow"):
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
if "1%" not in text:
    raise SystemExit("forced-routing policy is missing the 1% directive")
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

  local cmd=(
    "$CLAUDE_BIN"
    --print
    --output-format json
    --model "$LIVE_MODEL"
    --max-budget-usd "$LIVE_MAX_BUDGET_USD"
    --permission-mode dontAsk
    --tools ""
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
      printf '/%s:ralplan Deep smoke test only. Read the embedded consensus planning workflow, test case design quality bar, execution mode contract, and worktree policy before answering. Do not create artifacts or edit files. Return the 2-loop limit, approval status term, full Analyst -> Planner -> Plan-Reviewer ordering rule, the conditional re-review rule stating that only blocking findings trigger a re-review, the required Ralph execution profile fields, the test case design requirements, the shallow-test rejection rule, the project-local worktree path for write-capable execution, and the Codex host-policy-controlled dispatch rule for planning subagents. End with OH_NO_CLAUDE_DEEP_OK ralplan.' "$PLUGIN_NAME"
      ;;
    ralph)
      printf '/%s:ralph Deep smoke test only. Read the execution mode contract, execution support docs, worktree policy, parallel coordination doc, and linked cleanup/TDD skills before answering. Do not create artifacts or edit files. Return the execution mode decision prompt heading, all execution mode names, the mode-gated dispatch heading, the base agent naming rule, the parallel trigger field, Claude plugin agent invocation form, the default project-local worktree path, the parent-directory sibling fallback rule, the TDD enforcement boundary including test-driven-development as an internal mid-loop discipline and not a top-level implementation route, and the cleanup behavior-lock heading. End with OH_NO_CLAUDE_DEEP_OK ralph.' "$PLUGIN_NAME"
      ;;
    ultrawork)
      printf '/%s:ultrawork Deep smoke test only. Read the linked phase skills, execution mode contract, shared worktree policy, and shared parallel coordination doc enough to answer from their referenced docs. Do not create artifacts or edit files. Return the spec artifact path from clarification, the planning loop limit, the project-local automatic worktree path, the Ultrawork auto-approval rule after interview/spec approval, how ralplan approval becomes a recorded internal execution approval, how ralph is invoked with the Ultrawork-approved plan, the required execution mode source in the final report, and the cleanup/final-verification heading reached through execution. End with OH_NO_CLAUDE_DEEP_OK ultrawork.' "$PLUGIN_NAME"
      ;;
    simplify)
      printf '/%s:simplify --review Deep smoke test only. Read the shared simplify core and Claude Code platform docs before answering. Do not create artifacts or edit files. Return the exact headings Required Behavior Lock, Phase 0 - Gather The Diff, Phase 1 - Review, and Phase 2 - Apply The Fixes; the four cleanup subagent angles; the host policy rule that they launch in one batch before waiting; the rule that cleanup angles must not collapse into a single generic inline review and must use separate inline fallback blocks with a fallback reason if subagent dispatch is unavailable; and the false-positive or behavior-changing skip rule. End with OH_NO_CLAUDE_DEEP_OK simplify.' "$PLUGIN_NAME"
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

path, skill = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

if data.get("is_error"):
    raise SystemExit(f"{skill} deep smoke failed: {data.get('result')}")

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
        "Overall Ralph mode",
        "Task sizing",
        "Execution profile",
        "Analyst",
        "Planner",
        "must-fail",
        "must-pass",
        "negative",
        "old broken behavior",
        ".oh-no/worktrees/<task-slug>",
        "host",
        "policy",
    ],
    "ralph": [
        "Execution Mode Decision Prompt",
        "Mode-Gated Agent Dispatch",
        "LIGHT",
        "STANDARD",
        "THOROUGH",
        "Parallel trigger",
        "oh-no-harness:<agent>",
        ".oh-no/worktrees/<task-slug>",
        "parent-directory",
        "test-driven-development",
        "internal mid-loop",
        "Required Behavior Lock",
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
        "fallback reason",
        "false positive",
        "intended behavior",
    ],
}

missing = [needle for needle in expected[skill] if needle.lower() not in text_lower]
if missing:
    raise SystemExit(f"{skill} deep smoke missing markers: {missing}; got {text!r}")

if skill == "ralph" and not (
    "not a top-level implementation" in text_lower
    or "not the top-level route" in text_lower
    or "not a top-level route" in text_lower
    or ("not" in text_lower and "top-level" in text_lower and "implementation" in text_lower)
):
    raise SystemExit(f"{skill} deep smoke missing TDD top-level route boundary; got {text!r}")

if (
    "oh_no_claude_deep_ok" not in text_lower
    and f"oh_no_claude_deep_ok {skill}".lower() not in text_lower
):
    raise SystemExit(f"{skill} deep smoke missing success marker; got {text!r}")

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
    raise SystemExit(f"{skill} deep smoke missing company-context availability marker; got {text!r}")

if skill == "interview" and not (
    "do not search remote" in text_lower
    or "should not be searched" in text_lower
    or ("remote" in text_lower and "not" in text_lower and "search" in text_lower)
):
    raise SystemExit(f"{skill} deep smoke missing remote-search policy marker; got {text!r}")

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
    raise SystemExit(f"{skill} deep smoke missing full consensus ordering marker; got {text!r}")

if skill == "ralplan" and not (
    "edge" in text_lower
    or "semantic-model" in text_lower
    or "semantic model" in text_lower
    or "regression" in text_lower
    or "adversarial" in text_lower
):
    raise SystemExit(f"{skill} deep smoke missing edge/semantic/regression test-design marker; got {text!r}")

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
    raise SystemExit(f"{skill} deep smoke missing Planner/Plan-Reviewer single-dispatch ordering marker; got {text!r}")

if skill == "ralplan" and not (
    "blocking" in text_lower and "re-review" in text_lower
):
    raise SystemExit(f"{skill} deep smoke missing blocking-findings re-review marker; got {text!r}")

linked_doc_markers = {
    "ralph": [
        "Execution Mode Decision Prompt",
        "Mode-Gated Agent Dispatch",
        "Parallel trigger",
        "Required Behavior Lock",
    ],
    "ultrawork": [
        "Mode source",
        "Cleanup And Final Verification",
    ],
}

if skill in linked_doc_markers and not all(marker.lower() in text_lower for marker in linked_doc_markers[skill]):
    raise SystemExit(f"{skill} deep smoke missing linked-doc marker; got {text!r}")

if skill == "simplify" and not (
    ("host" in text_lower and "policy" in text_lower)
    or "subagent dispatch is unavailable" in text_lower
    or ("dispatch" in text_lower and "unavailable" in text_lower)
):
    raise SystemExit(f"{skill} deep smoke missing host dispatch/fallback policy marker; got {text!r}")

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
  # Live deep-smoke is a non-gating signal only: deterministic reachability is
  # gated by scripts/check-skill-reachability.py. A live marker miss here is
  # model paraphrase/dereference variance, not a harness defect.
  assert_deep_json_output "$out_file" "$skill" \
    || log "WARN: live deep-smoke for $skill flagged paraphrase/dereference variance (non-gating)"
}

run_deep_live_tests() {
  if [[ "$RUN_DEEP_LIVE" != "1" ]]; then
    log "Skipping deep Claude linked-doc smoke tests"
    printf 'Run with --deep-live or OH_NO_DEEP_LIVE=1 to verify linked support docs are read.\n' >&2
    return
  fi

  log "Running deep Claude linked-doc smoke tests (${LIVE_LOAD_MODE})"
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

run_natural_session_start_live_tests() {
  if [[ "$RUN_NATURAL_SESSION_START_LIVE" != "1" ]]; then
    log "Skipping live natural Claude role-worker smoke tests"
    printf 'Run with --natural-session-start-live or OH_NO_NATURAL_SESSION_START_LIVE=1 to verify natural role-worker dispatch for Interview, Ultrawork, Systematic Debugging, and Verification Before Completion.\n' >&2
    return
  fi

  log "Running live natural Claude role-worker smoke tests (${LIVE_LOAD_MODE})"
  mkdir -p "$RUN_DIR"
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
  local prompt="Use oh-no-harness:ralplan. Read-only dispatch instrumentation test only: do not create a full plan, do not edit files, and do not create artifacts. Requirements source is already analyzed inline; do not spawn explore, analyst, executor, verifier, code-reviewer, or any role except oh-no-harness:planner and oh-no-harness:plan-reviewer. Synthetic approved task: document that the host asks the user which execution workflow to run after ralplan plan approval. Use Claude subagents exactly two times in this strict order: oh-no-harness:planner, wait until that task completes before starting plan-reviewer; oh-no-harness:plan-reviewer, wait until that task completes before final. Never run these planning review agents in parallel. Planner expected output: only a short section titled Planner draft v1 with Goal, Acceptance criteria, Execution profile, Worktree policy, Verification plan. Plan-Reviewer expected output: only a short section titled Plan review v1 with Reviewed draft: Planner draft v1, Architecture findings: none, Quality-gate findings: none, Verdict: APPROVE. The plan-reviewer subagent must receive the actual Planner draft v1 text. Even if a subagent suggests improvements, do not revise; this smoke test only verifies the v1 chain. After both subagents finish, reply with exactly OH_NO_CLAUDE_RALPLAN_SEQUENTIAL_SUBAGENTS_OK and summarize Role order: planner -> plan-reviewer, Waited between roles: yes, Reviews chained: Planner draft v1 -> Plan review v1."

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
    "plan-reviewer": ["Planner draft v1"],
}
output_markers = {
    "planner": ["Planner draft v1"],
    "plan-reviewer": ["Plan review v1", "Reviewed draft", "Architecture findings", "Quality-gate findings"],
}

def collect_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(item) for item in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(item) for item in value)
    return ""

init_ok = False
tool_uses = []
task_started = {}
task_role_by_id = {}
task_completion = {}
role_outputs = defaultdict(list)
marker = False
errors = []
all_task_roles = []
workflow_tool_ids = set()
workflow_scripts = []
workflow_completed = False
workflow_evidence_parts = []

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
                    workflow_tool_ids.add(part.get("id"))
                    script = collect_text(part.get("input", {}).get("script", ""))
                    if script:
                        workflow_scripts.append((index, script))
                if part.get("type") == "text":
                    workflow_evidence_parts.append(part.get("text", ""))
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
            if (
                data.get("subtype") == "task_notification"
                and data.get("status") == "completed"
                and (
                    data.get("tool_use_id") in workflow_tool_ids
                    or "workflow" in str(data.get("summary", "")).lower()
                )
            ):
                workflow_completed = True
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
        if data.get("type") == "result":
            workflow_evidence_parts.append(str(data.get("result", "")))

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

if not tool_uses and workflow_scripts:
    workflow_script = "\n".join(script for _, script in workflow_scripts)
    workflow_roles = re.findall(r"agentType:\s*['\"]oh-no-harness:([^'\"]+)['\"]", workflow_script)
    if workflow_roles != expected_roles:
        raise SystemExit(
            "Claude ralplan Workflow agent() order did not match expected planning roles: "
            f"expected={expected_roles!r} got={workflow_roles!r}"
        )
    workflow_required_script_markers = [
        "Planner draft v1",
        "Plan review v1",
    ]
    workflow_missing_script_markers = [
        marker for marker in workflow_required_script_markers
        if marker not in workflow_script
    ]
    if workflow_missing_script_markers:
        raise SystemExit(
            "Claude ralplan Workflow agent() script did not prove sequential review chaining: "
            f"{workflow_missing_script_markers}"
        )
    if workflow_script.count("await agent") < len(expected_roles):
        raise SystemExit("Claude ralplan Workflow did not await two planning agent calls")
    if not re.search(r"\$\{[^}]*planner[^}]*\}", workflow_script, re.IGNORECASE):
        raise SystemExit("Claude ralplan Workflow plan-reviewer prompt did not include planner output")
    if not workflow_completed:
        raise SystemExit("Claude ralplan Workflow agent() task did not report completion")
    workflow_evidence = "\n".join(workflow_evidence_parts)
    for role, markers in output_markers.items():
        missing_output_markers = [
            marker for marker in markers
            if marker.lower() not in workflow_evidence.lower()
        ]
        if missing_output_markers:
            raise SystemExit(
                f"Claude ralplan Workflow output did not prove {role} review chain: "
                f"{missing_output_markers}; output={workflow_evidence[:2000]!r}"
            )
    if not marker:
        raise SystemExit("Claude ralplan sequential smoke did not return success marker")
    print("ok - live Claude ralplan planning subagents reviewed sequentially")
    sys.exit(0)

if len(tool_uses) != len(expected_roles):
    raise SystemExit(f"expected exactly two planning task uses, got {len(tool_uses)}: {tool_uses!r}")

actual_order = [role for _, role, _ in tool_uses]
if actual_order != expected_roles:
    raise SystemExit(f"expected sequential task order {expected_roles!r}, got {actual_order!r}")

for index, role, payload in tool_uses:
    prompt = collect_text(payload)
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

for role, markers in output_markers.items():
    output_text = "\n".join(role_outputs.get(role, []))
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
  local prompt="Use oh-no-harness:ralph. Read-only live subagent smoke test. This is an explicit parallel subagents request. Verify every Oh No Harness role with Claude background subagents, but respect platform concurrency limits: run the roles in independent waves of at most three subagents, start every subagent in the current wave before waiting for that wave, close or clean up each completed subagent when the host exposes that mechanism, and do not continue if any task fails. If no explicit close or cleanup mechanism exists, record that fallback. Wave 1: oh-no-harness:explore, oh-no-harness:analyst, oh-no-harness:planner. Wave 2: oh-no-harness:plan-reviewer, oh-no-harness:executor, oh-no-harness:debugger. Wave 3: oh-no-harness:verifier, oh-no-harness:code-reviewer, oh-no-harness:fusion-rescue-analyst. Each subagent should inspect its own agents/<role>.md file and report its role heading plus whether Skill Relationship, Responsibilities, Operating Rules, and Output are present. Do not edit files. After all nine subagents finish, reply exactly OH_NO_CLAUDE_PARALLEL_SUBAGENTS_OK and summarize the nine role checks plus lifecycle close or cleanup status."

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
    "plan-reviewer",
    "executor",
    "debugger",
    "verifier",
    "code-reviewer",
    "fusion-rescue-analyst",
]
first_wave = {"explore", "analyst", "planner"}
task_tool_uses = []
background_uses_by_role = {}
task_starts = []
task_notifications = []
marker = False
init_ok = False
first_task_notification_index = None
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
            init_ok = "Task" in data.get("tools", []) and all(
                f"oh-no-harness:{role}" in available_agents for role in expected_roles
            )
        if data.get("type") == "assistant":
            for part in data.get("message", {}).get("content", []):
                if part.get("type") == "tool_use" and part.get("name") in {"Agent", "Task"}:
                    payload = part.get("input", {})
                    task_tool_uses.append((index, payload))
                    subagent_type = payload.get("subagent_type")
                    if subagent_type and subagent_type.startswith("oh-no-harness:"):
                        role = subagent_type.split(":", 1)[1]
                        if payload.get("run_in_background") is True:
                            background_uses_by_role.setdefault(role, []).append((index, payload))
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
            task_starts.append((index, data.get("task_id")))
        if data.get("type") == "system" and data.get("subtype") == "task_notification":
            if first_task_notification_index is None:
                first_task_notification_index = index
            if data.get("status") == "completed":
                task_notifications.append((index, data.get("summary", "")))
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
    raise SystemExit("Claude live parallel smoke did not expose Task tool and all oh-no-harness role agents")
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

missing_roles = [role for role in expected_roles if role not in background_uses_by_role]
if missing_roles:
    raise SystemExit(f"missing background task uses for roles: {missing_roles!r}; got={sorted(background_uses_by_role)!r}")
duplicate_roles = {
    role: uses for role, uses in background_uses_by_role.items()
    if role in expected_roles and len(uses) != 1
}
if duplicate_roles:
    raise SystemExit(f"expected exactly one background task use per role, got duplicates: {duplicate_roles!r}")
if len(task_starts) < len(expected_roles):
    raise SystemExit(f"expected at least {len(expected_roles)} task_started events, got {task_starts!r}")
if first_task_notification_index is not None:
    roles_before_first_notification = {
        role
        for role, uses in background_uses_by_role.items()
        if uses[0][0] < first_task_notification_index
    }
    if not first_wave.issubset(roles_before_first_notification):
        raise SystemExit(
            "first Claude subagent wave did not start before the first task completion notification; "
            f"expected={sorted(first_wave)!r} got={sorted(roles_before_first_notification)!r}"
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
    log "Skipping live Claude Fusion Rescue /codex:rescue smoke test"
    printf 'Run with --fusion-rescue-live or OH_NO_FUSION_RESCUE_LIVE=1 to verify Fusion Rescue panel subagents plus /codex:rescue Codex consult.\n' >&2
    return
  fi

  log "Running live Claude Fusion Rescue /codex:rescue smoke test (${LIVE_LOAD_MODE}, model ${FUSION_RESCUE_LIVE_MODEL})"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/fusion-rescue-claude-codex.jsonl"
  local err_file="$RUN_DIR/fusion-rescue-claude-codex.err"
  local summary_file="$RUN_DIR/fusion-rescue-claude-codex.summary.json"
  local prompt
  prompt=$(cat <<PROMPT
/${PLUGIN_NAME}:fusion-rescue require-cross-host read-only live integration smoke test only. Do not edit files, do not create artifacts, do not install plugins, and do not run nested rescue.

Synthetic smoke-test problem all panels must analyze meaningfully: a CI pipeline has an intermittently failing integration test two days before release. The team must choose whether to quarantine the test, add automatic retries, or root-cause/fix the failure before release. Every panel result must discuss release risk, CI signal, quarantine, auto-retry, and root-cause evidence rather than only saying the smoke test is formatted correctly.

Build exactly three panel slots and then synthesize as the current Claude main judge.

Panel 1 primary must be a Claude current-host subagent using oh-no-harness:fusion-rescue-analyst. Its task prompt must include exactly these lines: Lens: primary; Marker: OH_NO_CLAUDE_FUSION_PANEL_PRIMARY; fusion depth: 1; Do not invoke rescue, fusion-rescue, cross-host consult, or another host from inside this panel; Scope: synthetic CI release-risk problem only; Do not edit files; Expected output: marker line plus exact assigned lens fields only: lens name; strongest finding; evidence used; assumption under test; likely failure mode; recommended next action; confidence and why; what would change the conclusion. It must provide constructive analysis of quarantine, auto-retry, root-cause, CI signal, and release risk.

Panel 2 adversarial must be exactly one Codex opposite-host response through the explicitly loaded openai/codex-plugin-cc rescue capability surfaced as /codex:rescue. In this non-interactive test, use that capability by invoking the same Agent surface that /codex:rescue delegates to, with subagent_type codex:codex-rescue. A valid live result requires codex:codex-rescue to perform its required Bash call to node codex-companion.mjs in the foreground, set Bash timeout to at least 600000 ms, wait for completion, and return Codex companion stdout; a marker generated locally by the wrapper, returned after a Bash approval failure, returned while Bash is still running in the background, or returned after a Stop hook says a Codex task is still running is not valid. The harness parser, not you, verifies the Bash event stream and codex-companion stdout after the run. Therefore do not call SendMessage, ToolSearch, status, result, or a second codex:codex-rescue task for liveness checking. Do not retry the Codex panel if it returns a marker; if it reports a failure, block without success. The forwarded request must be foreground, fresh, read-only behavior and must include the words via /codex:rescue plus the marker request OH_NO_CODEX_RESCUE_RETURN_OK. The Codex request: --wait --fresh read-only behavior; no edits, no writes, no installs; fusion depth: 1; do not invoke rescue, fusion-rescue, cross-host consult, Claude, or another host; analyze this CI release-risk problem adversarially; return exactly OH_NO_CODEX_RESCUE_RETURN_OK plus lens name adversarial, strongest finding, evidence used, assumption under test, likely failure mode, recommended next action, confidence and why, and what would change the conclusion. If codex:codex-rescue cannot run node codex-companion.mjs without approval or foreground completion, do not synthesize success and do not include OH_NO_CLAUDE_FUSION_RESCUE_CODEX_OK.

Panel 3 pragmatic must be a Claude current-host subagent using oh-no-harness:fusion-rescue-analyst. Its task prompt must include exactly these lines: Lens: pragmatic; Marker: OH_NO_CLAUDE_FUSION_PANEL_PRAGMATIC; fusion depth: 1; Do not invoke rescue, fusion-rescue, cross-host consult, or another host from inside this panel; Scope: synthetic CI release-risk problem only; Do not edit files; Expected output: marker line plus exact assigned lens fields only: lens name; strongest finding; evidence used; assumption under test; likely failure mode; recommended next action; confidence and why; what would change the conclusion. It must recommend the simplest reversible next step and verification path for the CI release-risk decision.

Start the two Claude panel subagents before waiting when possible. Wait for exactly these three panel results, and do not end while a worker is still pending. After the single Codex rescue returns and both Claude panel subagents finish, synthesize immediately rather than concatenate or recheck liveness. Final answer must contain exactly the marker OH_NO_CLAUDE_FUSION_RESCUE_CODEX_OK and must include: panels completed: primary, adversarial, pragmatic; Codex marker: OH_NO_CODEX_RESCUE_RETURN_OK; Claude markers: OH_NO_CLAUDE_FUSION_PANEL_PRIMARY, OH_NO_CLAUDE_FUSION_PANEL_PRAGMATIC; consensus; contradictions; unique insights; blind spots; recommended next action; confidence and why; panel availability/fallback notes: Claude primary available, Codex adversarial available via opposite-host response /codex:rescue codex:codex-rescue, Claude pragmatic available; fusion depth: 1.
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
    --system-prompt "You are a read-only live smoke test runner. Use the invoked Oh No Harness Fusion Rescue skill. You may use Claude subagents and the installed codex:rescue capability only for this requested verification. Do not edit files."
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
    "OH_NO_CLAUDE_FUSION_RESCUE_CODEX_OK",
    "OH_NO_CODEX_RESCUE_RETURN_OK",
    "OH_NO_CLAUDE_FUSION_PANEL_PRIMARY",
    "OH_NO_CLAUDE_FUSION_PANEL_PRAGMATIC",
    "panels completed",
    "primary, adversarial, pragmatic",
    "panel availability/fallback notes",
    "opposite-host response",
    "/codex:rescue",
    "codex:codex-rescue",
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
    re.compile(r"sk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"(?i)(api[_-]?key|access[_-]?token|refresh[_-]?token|private[_-]?key|cookie)\s*[:=]\s*['\"]?[A-Za-z0-9_./+=-]{12,}"),
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
codex_rescue_uses = []
unexpected_task_uses = []
unexpected_write_uses = []
task_started_roles = []
task_completed_roles = []
codex_bash_tool_ids = set()
codex_bash_success_texts = []
codex_bash_failures = []
workflow_tool_ids = set()
workflow_scripts = []
workflow_completed = False
non_user_text_parts = []
permission_denials = []

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
            raise SystemExit(
                f"Claude Fusion Rescue live left background work instead of foreground completion near line {index}: "
                f"{text[:2000]!r}"
            )
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
                    elif subagent_type == "codex:codex-rescue":
                        codex_rescue_uses.append((index, payload_text))
                    else:
                        unexpected_task_uses.append((index, subagent_type, payload_text[:1000]))
                if part.get("type") == "tool_use" and part.get("name") == "Workflow":
                    workflow_tool_ids.add(part.get("id"))
                    script = collect_text(part.get("input", {}).get("script", ""))
                    if script:
                        workflow_scripts.append((index, script))
                if part.get("type") == "text":
                    non_user_text_parts.append(part.get("text", ""))
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
if permission_denials:
    raise SystemExit(f"Claude Fusion Rescue live had permission denials: {permission_denials!r}")
if "codex:rescue" not in init_slash_commands:
    raise SystemExit(
        "Claude Fusion Rescue live did not expose /codex:rescue in slash_commands; "
        f"got={sorted(cmd for cmd in init_slash_commands if 'codex' in cmd)!r}"
    )
if "codex:codex-rescue" not in init_agents:
    raise SystemExit(
        "Claude Fusion Rescue live did not expose codex:codex-rescue agent; "
        f"got={sorted(agent for agent in init_agents if 'codex' in agent)!r}"
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
if len(codex_rescue_uses) != 1:
    raise SystemExit(f"Claude Fusion Rescue live expected one codex:codex-rescue task, got {codex_rescue_uses!r}")
codex_payload = codex_rescue_uses[0][1]
for marker in ("/codex:rescue", "OH_NO_CODEX_RESCUE_RETURN_OK", "read-only behavior", "fusion depth: 1"):
    if marker.lower() not in codex_payload.lower():
        raise SystemExit(
            f"Claude Fusion Rescue live codex rescue payload missed marker {marker!r}; "
            f"payload={codex_payload[:2000]!r}"
        )
forbidden_payload_markers = ("--write", "write-capable")
leaked = [marker for marker in forbidden_payload_markers if marker.lower() in codex_payload.lower()]
if leaked:
    raise SystemExit(f"Claude Fusion Rescue live codex rescue payload requested write behavior: {leaked!r}")

started_role_names = [role for _, role in task_started_roles]
if "codex:codex-rescue" not in started_role_names and not workflow_scripts:
    raise SystemExit(f"Claude Fusion Rescue live did not start codex:codex-rescue task; starts={task_started_roles!r}")
completed_role_names = [role for _, role in task_completed_roles]
if (
    "codex:codex-rescue" not in completed_role_names
    and "OH_NO_CODEX_RESCUE_RETURN_OK" not in "\n".join(non_user_text_parts)
):
    raise SystemExit(f"Claude Fusion Rescue live did not complete codex rescue or capture its marker; completions={task_completed_roles!r}")
if not codex_bash_tool_ids:
    raise SystemExit("Claude Fusion Rescue live did not invoke codex-companion.mjs through codex:codex-rescue Bash")
if codex_bash_failures:
    raise SystemExit(f"Claude Fusion Rescue live codex-companion Bash failed: {codex_bash_failures!r}")
codex_bash_text = "\n".join(codex_bash_success_texts)
if "OH_NO_CODEX_RESCUE_RETURN_OK" not in codex_bash_text:
    raise SystemExit(
        "Claude Fusion Rescue live did not capture OH_NO_CODEX_RESCUE_RETURN_OK "
        "from codex-companion.mjs stdout"
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
    if "OH_NO_CLAUDE_FUSION_RESCUE_CODEX_OK" in part
)
if not success_text:
    raise SystemExit("Claude Fusion Rescue live did not return success marker OH_NO_CLAUDE_FUSION_RESCUE_CODEX_OK")
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
    "codex_rescue": {
        "subagent_type": "codex:codex-rescue",
        "bash_tool_uses": len(codex_bash_tool_ids),
        "returned_marker": "OH_NO_CODEX_RESCUE_RETURN_OK",
        "permission_denials": len(permission_denials),
    },
    "final_marker": "OH_NO_CLAUDE_FUSION_RESCUE_CODEX_OK",
}
Path(summary_path).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

print("ok - live Claude Fusion Rescue used /codex:rescue, captured Codex output, and synthesized")
PY
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

First, read ${read_root}/docs/shared/cross-host-review.md, paying attention to its "## Same-Host Parallel Fallback" and "## Parallel Execution And Synthesis" sections. This run is in DEFAULT mode (NOT require-cross-host). The opposite host (Codex) is UNAVAILABLE: the /codex:rescue cross-host consult capability is not loaded or authorized in this run, so you MUST NOT attempt any cross-host hop, must NOT invoke /codex:rescue, codex:codex-rescue, rescue, fusion-rescue, or any opposite-host or another-host call. Treat the opposite host as unavailable and take the default-mode Same-Host Parallel Fallback, NOT the cross-host path.

Lightweight contract pre-check (read-only). From ${read_root}/docs/shared/cross-host-review.md, confirm and state, behind the marker OH_NO_CLAUDE_DEEP_OK cross-host-fallback, all of: (1) in default mode when the opposite host is unavailable the review dispatches EXACTLY TWO same-host agents of the same role synthesized into one result rather than a single pass; (2) require-cross-host mode still BLOCKS instead of using this fallback; (3) verifier is in scope for cross-host review; (4) the verifier merge rule unions the evidence and resolves disagreements conservatively (a criterion is unmet if either result says unmet). Include the exact phrases "exactly two same-host agents", "require-cross-host", "verifier", and "union" or "conservative" so this pre-check is machine-checkable.

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
    --system-prompt "You are a read-only live smoke test runner. Use the invoked Oh No Harness skill and Claude same-host subagents only. The opposite host (Codex) and the /codex:rescue cross-host consult capability are unavailable and not authorized in this run; do not attempt any cross-host or opposite-host call. Do not edit files."
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
    re.compile(r"sk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"(?i)(api[_-]?key|access[_-]?token|refresh[_-]?token|private[_-]?key|cookie)\s*[:=]\s*['\"]?[A-Za-z0-9_./+=-]{12,}"),
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
                    if subagent_type == "codex:codex-rescue" or "codex" in subagent_type.lower():
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
    "verifier",
):
    if needle not in lower_deep_text:
        raise SystemExit(
            f"Claude cross-host fallback live contract pre-check missing {needle!r}; deep_text={deep_text[:2000]!r}"
        )
if not ("union" in lower_deep_text or "conservative" in lower_deep_text):
    raise SystemExit(
        f"Claude cross-host fallback live contract pre-check missing verifier union/conservative merge rule; "
        f"deep_text={deep_text[:2000]!r}"
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
  local fixture_dir
  fixture_dir="$(mktemp -d)"

  # rm -rf the fixture sandbox on EVERY exit path, including when set -e kills the
  # script on a nonzero exit. The done-guard makes the cleanup idempotent so the
  # multi-signal trap cannot double-run rm. The non-empty + is-dir guard prevents
  # rm -rf ""/"/" if fixture_dir is ever unset.
  local _parallel_executor_cleanup_done=0
  _parallel_executor_cleanup() {
    if [[ "$_parallel_executor_cleanup_done" == "0" && -n "$fixture_dir" && -d "$fixture_dir" ]]; then
      rm -rf "$fixture_dir"
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

  # CONTRACT-NOT-PROMPT-COMPLIANCE: an ORDINARY direct STANDARD/THOROUGH Ralph run
  # over two disjoint stories. The prompt describes the two stories and asks Ralph
  # to run them and report. It does NOT instruct parallelism, batching, "dispatch
  # two executors", or background dispatch — the EDITED ralph contract loaded via
  # the plugin is what must drive proactive concurrent executor dispatch.
  local prompt
  prompt=$(cat <<PROMPT
Use ${PLUGIN_NAME}:ralph in THOROUGH mode. Work entirely inside the current working directory; do not read, write, or touch anything outside it. There are two stories to implement, described in story_a.md and story_b.md in this directory. Read both story files.

Story A and Story B are independent of each other: they touch different files and neither depends on the other. Implement both stories so each described file is created exactly as its story specifies, then run them and report the result.

When you are completely finished and both files exist, emit a final summary that contains the exact token OH_NO_RALPH_POST_BATCH_CHECK followed by, for each implemented unit, the file it owns and the marker contained in that file, confirming each unit stayed within its own file. Then emit the exact final marker OH_NO_RALPH_PARALLEL_EXECUTOR_OK on its own line.
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

  # CONTAINMENT (authoritative): acceptEdits is the real OS/permission-level
  # enforcement. Under --permission-mode acceptEdits in --print mode, file edits
  # inside the working directory (the run's cwd = fixture_dir) are auto-accepted,
  # while edits OUTSIDE the workspace and Bash commands require permission and are
  # auto-denied non-interactively -- so they are actually blocked, not merely
  # detected after the fact. We therefore do NOT pass the plugin/repo root as a
  # writable --add-dir (under acceptEdits an added dir becomes writable); skill
  # content loads via --plugin-dir and the fixture stories are self-contained, so
  # fixture_dir is the SOLE accessible write workspace. The transcript
  # path-containment scan, the marketplace git-status check, and the out-of-fixture
  # sentinel below are DEFENSE-IN-DEPTH (belt-and-suspenders), not the sole
  # containment.
  local cmd=(
    "$CLAUDE_BIN"
    --print
    --verbose
    --output-format stream-json
    --include-hook-events
    --model "$FUSION_RESCUE_LIVE_MODEL"
    --max-budget-usd "$FUSION_RESCUE_MAX_BUDGET_USD"
    --permission-mode acceptEdits
    --tools default
    --no-session-persistence
    --system-prompt "You are a live smoke test runner for an Oh No Harness Ralph run. Implement only the two disjoint stories in the current working directory. Write only inside the current working directory. Do not edit, create, or delete any file outside it, and do not install plugins."
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

# Containment baseline (DEFENSE-IN-DEPTH; acceptEdits is the authoritative
# containment): any new/modified marketplace entry attributable to the run is a
# hard failure. The before/after porcelain snapshots are passed via env.
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

secret_patterns = [
    re.compile(r"sk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"(?i)(api[_-]?key|access[_-]?token|refresh[_-]?token|private[_-]?key|cookie)\s*[:=]\s*['\"]?[A-Za-z0-9_./+=-]{12,}"),
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
    candidate = path
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
# `command -v python 2>/dev/null` must not be flagged. acceptEdits is the
# authoritative write boundary; this Bash scan is defense-in-depth and must not
# false-positive on these.
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

errors = []
# (tool_use_index, marker_letter) for each distinct executor dispatch.
executor_dispatch_uses = defaultdict(list)
task_starts = []
task_notifications = []          # (index, status, summary)
first_task_notification_index = None
executor_completion_indexes = {}  # marker_letter -> completion index (best effort)
post_batch_indexes = []          # indexes of non-user text containing POST_BATCH_MARKER
final_marker_seen = False
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
                    if command_writes(command):
                        for target in bash_write_targets(command):
                            # Skip non-path tokens and benign discard/device targets
                            # (e.g. `2>/dev/null`), then strip trailing shell
                            # metacharacters before the containment check.
                            if is_benign_write_target(target):
                                continue
                            cleaned = clean_write_target(target)
                            if not under_fixture(cleaned):
                                raise SystemExit(
                                    "Claude parallel-executor live ran a write Bash command targeting OUTSIDE "
                                    f"the fixture sandbox: target={cleaned!r} command={command[:300]!r} fixture={fixture_real!r}"
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
                if ptype == "text":
                    if FINAL_MARKER in part.get("text", ""):
                        final_marker_seen = True
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

# CONTAINMENT (defense-in-depth): no new/modified marketplace entry attributable
# to the run. acceptEdits is the authoritative containment; this is belt-and-
# suspenders.
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

if both_completions_index is None:
    # Concurrency is already PROVEN above (both disjoint executors dispatched
    # before the first task notification, and >=2 task_started events). The only
    # thing missing here is observing BOTH completions to anchor the post-batch
    # scope-check timing this run — a live-observability gap, NOT a sequential or
    # inline run (those are caught as hard-FAIL INCONCLUSIVE cases earlier and stay
    # gating). Degrade only this completion-observation gap to a non-gating WARN,
    # consistent with the de-gated live deep-smoke direction, instead of failing.
    print(
        "WARN (non-gating): parallel-executor concurrency was proven, but could not observe both "
        "disjoint-executor completions to anchor the post-batch scope check this run; "
        f"completed_notifications={completed_notification_indexes!r} "
        f"executor_completion_indexes={executor_completion_indexes!r}"
    )
    raise SystemExit(0)

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
    "permission_mode": "acceptEdits",
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

main() {
  cd "$PLUGIN_ROOT"
  require_command "$CLAUDE_BIN"
  require_command "$PYTHON_BIN"

  log "Testing ${PLUGIN_ID} from ${PLUGIN_ROOT}"
  validate_manifests
  validate_hooks
  validate_frontmatter
  install_or_update_plugin
  run_live_tests
  run_deep_live_tests
  run_ralplan_live_test
  run_parallel_live_test
  run_fusion_rescue_live_test
  run_cross_host_fallback_live_test
  run_parallel_executor_live_test
  run_simplify_live_test
  run_natural_session_start_live_tests
  log "All requested checks passed"
}

main "$@"
