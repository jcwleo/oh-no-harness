#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
PLUGIN_NAME="${OH_NO_PLUGIN_NAME:-oh-no-harness}"
MARKETPLACE_NAME="${OH_NO_MARKETPLACE_NAME:-oh-no-harness-dev}"
PLUGIN_ID="${PLUGIN_NAME}@${MARKETPLACE_NAME}"
REQUESTED_SCOPE="${OH_NO_PLUGIN_SCOPE:-}"
INSTALL_MODE="${OH_NO_INSTALL:-1}"
RUN_LIVE="${OH_NO_LIVE:-0}"
RUN_DEEP_LIVE="${OH_NO_DEEP_LIVE:-0}"
LIVE_HOOK_ONLY="${OH_NO_LIVE_HOOK_ONLY:-0}"
LIVE_LOAD_MODE="${OH_NO_LIVE_LOAD_MODE:-plugin-dir}"
LIVE_MODEL="${OH_NO_TEST_MODEL:-sonnet}"
LIVE_MAX_BUDGET_USD="${OH_NO_MAX_BUDGET_USD:-1.00}"
LIVE_SYSTEM_PROMPT="${OH_NO_SYSTEM_PROMPT:-You are a concise smoke test runner. Do not edit files or use tools.}"
RUN_DIR="${OH_NO_TEST_RUN_DIR:-${PLUGIN_ROOT}/.oh-no/test-runs/$(date +%Y%m%d-%H%M%S)}"

PUBLIC_SKILLS=(
  using-oh-no-harness
  deep-interview
  ralplan
  ralph
  autopilot
  auto-routing
  test-driven-development
  ai-slop-cleaner
  verification-before-completion
  systematic-debugging
)

ALL_SKILLS=(
  "${PUBLIC_SKILLS[@]}"
)

AGENTS=(
  explore
  analyst
  planner
  architect
  critic
  executor
  debugger
  verifier
  code-reviewer
  security-reviewer
  qa-tester
)

usage() {
  cat <<USAGE
Usage: scripts/test-claude-plugin.sh [options]

Installs or updates the local Claude Code plugin, then runs structural checks.
Live Claude Code skill smoke tests are opt-in because they spend model budget.

Options:
  --live                 Run live /skill smoke tests after static checks.
  --deep-live            Run live deep smoke tests that require linked support docs.
  --live-hook-only       Run only live Claude SessionStart hook policy and auto-routing tests.
  --skip-live            Skip live /skill smoke tests. Default.
  --no-install           Do not add marketplace, install, or update plugin.
  --scope <scope>        Install/update scope: local, project, user, managed.
                         Default: update existing scope if installed, otherwise local.
  --live-load <mode>     plugin-dir or installed. Default: plugin-dir.
  --model <model>        Claude model alias for live tests. Default: sonnet.
  --max-budget-usd <n>   Per-command max budget for live tests. Default: 1.00.
  -h, --help             Show this help.

Environment overrides:
  CLAUDE_BIN, PYTHON_BIN, OH_NO_PLUGIN_SCOPE, OH_NO_LIVE, OH_NO_DEEP_LIVE,
  OH_NO_TEST_MODEL, OH_NO_MAX_BUDGET_USD, OH_NO_LIVE_LOAD_MODE
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
    --model)
      LIVE_MODEL="${2:-}"
      [[ -n "$LIVE_MODEL" ]] || { echo "Missing value for --model" >&2; exit 2; }
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
  "$PYTHON_BIN" "$PLUGIN_ROOT/scripts/validate-plugin-files.py" "$PLUGIN_ROOT"
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
    ".claude-plugin/marketplace.json",
    ".codex-plugin/plugin.json",
]
include_dirs = ["skills", "commands", "agents", "hooks", "scripts", "docs"]

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
if "Before any response or action, including clarification questions" not in text:
    raise SystemExit("base bootstrap is missing skill-before-clarification guidance")
if "Do not ask raw clarification questions for vague work before reading `deep-interview`" not in text:
    raise SystemExit("base bootstrap is missing deep-interview-before-clarification guidance")
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
PY
  rm -rf "$temp_data"
  ok "session-start respects auto-routing config"

  "$PYTHON_BIN" - "$PLUGIN_ROOT/hooks/hooks.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    hooks = json.load(fh)

allowed = {"SessionStart"}
actual = set(hooks.get("hooks", {}).keys())
extra = actual - allowed
missing = allowed - actual
if extra or missing:
    raise SystemExit(f"Unexpected hook events. missing={sorted(missing)} extra={sorted(extra)}")
PY
  ok "only SessionStart hook is configured"
}

validate_manifests() {
  log "Validating plugin manifests"
  assert_json_valid "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  assert_json_valid "$PLUGIN_ROOT/.claude-plugin/marketplace.json"
  assert_json_valid "$PLUGIN_ROOT/.codex-plugin/plugin.json"
  "$CLAUDE_BIN" plugin validate "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  "$CLAUDE_BIN" plugin validate "$PLUGIN_ROOT/.claude-plugin/marketplace.json"
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
    target_scope="${REQUESTED_SCOPE:-local}"
    ok "plugin not installed; target scope is ${target_scope}"
  fi

  if [[ -n "$REQUESTED_SCOPE" ]]; then
    target_scope="$REQUESTED_SCOPE"
  fi

  if [[ "$target_scope" == "managed" && -z "$installed_scope" ]]; then
    fail "managed scope can only update an existing managed install; choose local, project, or user for a new install"
  fi

  if marketplace_exists; then
    "$CLAUDE_BIN" plugin marketplace update "$MARKETPLACE_NAME"
    ok "marketplace updated: ${MARKETPLACE_NAME}"
  else
    "$CLAUDE_BIN" plugin marketplace add --scope "$target_scope" "$PLUGIN_ROOT"
    ok "marketplace added: ${MARKETPLACE_NAME} (${target_scope})"
  fi

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
      printf '/using-oh-no-harness Smoke test only. Do not use tools or edit files. Reply in one short sentence that names this harness.'
      ;;
    deep-interview)
      printf '/deep-interview --quick Build a tiny note-taking feature. Smoke test only; do not use tools or edit files. Reply with the first clarification question you would ask.'
      ;;
    ralplan)
      printf '/ralplan Add a small smoke-test feature to an existing app. Smoke test only; do not use tools or edit files. Reply with the planning artifact you would create and the approval gate.'
      ;;
    ralph)
      printf '/ralph Approved no-op smoke-test plan: inspect scope, make no file changes, and report verification approach. Smoke test only; do not use tools or edit files. Reply with how execution would proceed.'
      ;;
    autopilot)
      printf '/autopilot Deliver a small smoke-test workflow from vague request to verification. Smoke test only; do not use tools or edit files. Reply with the workflow stages you would orchestrate.'
      ;;
    auto-routing)
      printf '/auto-routing status Smoke test only. Do not use tools or edit files. Reply with what this skill configures and the three supported actions.'
      ;;
    test-driven-development)
      printf '/test-driven-development Implement a small behavior change. Smoke test only; do not use tools or edit files. Reply with the TDD cycle steps you would follow.'
      ;;
    ai-slop-cleaner)
      printf '/ai-slop-cleaner --review Review a small diff for AI-generated code slop. Smoke test only; do not use tools or edit files. Reply with the cleanup categories you would check.'
      ;;
    verification-before-completion)
      printf '/verification-before-completion Smoke test only; do not use tools or edit files. Reply with the evidence gate you would apply before claiming completion.'
      ;;
    systematic-debugging)
      printf '/systematic-debugging A smoke test command is failing. Smoke test only; do not use tools or edit files. Reply with the debugging phases you would follow before fixing.'
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
if not str(data.get("result", "")).strip():
    raise SystemExit(f"{skill} live smoke returned an empty result")

cost = data.get("total_cost_usd")
print(f"ok - live skill smoke: {skill} cost={cost}")
PY
}

run_live_hook_test() {
  local out_file="$RUN_DIR/hook-policy-${LIVE_LOAD_MODE}.jsonl"
  local prompt="Smoke test only. Inspect your session-start instructions, not this user message. If they include both a Claude Code-only policy telling you to use AskUserQuestion for clarification, preference, scope, or approval questions when available, and Oh No Harness guidance to check local skills before clarification questions and read deep-interview before raw vague-work clarifications, reply exactly OH_NO_HOOK_POLICY_PRESENT. Otherwise reply exactly OH_NO_HOOK_POLICY_MISSING."

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
            has_skill_first_policy = (
                "Before any response or action, including clarification questions" in output
                and "Do not ask raw clarification questions for vague work before reading `deep-interview`" in output
            )
            if data.get("outcome") == "success" and has_question_policy and has_skill_first_policy:
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
    raise SystemExit("SessionStart hook did not emit both the AskUserQuestion and skill-before-clarification policies")
if not loaded_oh_no_plugin:
    raise SystemExit("oh-no-harness plugin was not reported as loaded")
if not ask_user_question_available:
    raise SystemExit("AskUserQuestion was not available in the Claude Code tool list")
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
  local prompt="Smoke test only. Inspect your session-start instructions, not this user message. If those instructions include an active Oh No Harness forced-routing policy, reply exactly OH_NO_FORCED_ROUTING_PRESENT. Otherwise reply exactly OH_NO_FORCED_ROUTING_MISSING."

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
            if "OH_NO_FORCED_ROUTING_PRESENT" in text:
                assistant_present = True
            if "OH_NO_FORCED_ROUTING_MISSING" in text:
                assistant_missing = True
        if data.get("type") == "result":
            result = data.get("result")
            cost = data.get("total_cost_usd")

if session_start_hooks < 1:
    raise SystemExit(f"auto-routing {state}: no SessionStart hook was observed")

if expected == "present":
    if not hook_policy_present:
        raise SystemExit("auto-routing enabled but hook output did not contain OH_NO_FORCED_ROUTING")
    if not assistant_present or assistant_missing:
        raise SystemExit(f"auto-routing enabled but assistant did not report PRESENT; result={result!r}")
else:
    if hook_policy_present:
        raise SystemExit("auto-routing disabled but hook output contained OH_NO_FORCED_ROUTING")
    if not assistant_missing or assistant_present:
        raise SystemExit(f"auto-routing disabled but assistant did not report MISSING; result={result!r}")

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
    ok "live hook output saved under ${RUN_DIR#$PLUGIN_ROOT/}"
    return
  fi

  log "Running live Claude skill smoke tests (${LIVE_LOAD_MODE})"
  for skill in "${PUBLIC_SKILLS[@]}"; do
    run_live_skill_test "$skill"
  done
  ok "live outputs saved under ${RUN_DIR#$PLUGIN_ROOT/}"
}

deep_prompt_for_skill() {
  case "$1" in
    deep-interview)
      printf '/deep-interview --quick Deep smoke test only. Read the linked Optional Company Context reference before answering. Do not create artifacts or edit files. Return when company context should be considered, whether it is advisory or executable, and whether remote/global systems should be searched for it. End with OH_NO_CLAUDE_DEEP_OK deep-interview.'
      ;;
    ralplan)
      printf '/ralplan Deep smoke test only. Read the embedded consensus planning workflow and execution mode contract before answering. Do not create artifacts or edit files. Return the loop limit, approval status term, Architect/Critic ordering rule, and the required Ralph execution profile fields. End with OH_NO_CLAUDE_DEEP_OK ralplan.'
      ;;
    ralph)
      printf '/ralph Deep smoke test only. Read the execution mode contract, execution support docs, parallel coordination doc, and linked cleanup/TDD skills before answering. Do not create artifacts or edit files. Return the execution mode decision prompt heading, all execution mode names, the mode-gated dispatch heading, the base agent naming rule, and the cleanup behavior-lock heading. End with OH_NO_CLAUDE_DEEP_OK ralph.'
      ;;
    autopilot)
      printf '/autopilot Deep smoke test only. Read the linked phase skills, execution mode contract, and shared parallel coordination doc enough to answer from their referenced docs. Do not create artifacts or edit files. Return the spec artifact path from clarification, the planning loop limit, the required execution mode source in the final report, and the cleanup/final-verification heading reached through execution. End with OH_NO_CLAUDE_DEEP_OK autopilot.'
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
expected = {
    "deep-interview": [
        "OH_NO_CLAUDE_DEEP_OK deep-interview",
        "already available",
        "advisory",
        "Do not search remote systems",
    ],
    "ralplan": [
        "OH_NO_CLAUDE_DEEP_OK ralplan",
        "five complete loops",
        "pending approval",
        "sequential",
        "Overall Ralph mode",
        "Task sizing",
        "Execution profile recap",
    ],
    "ralph": [
        "OH_NO_CLAUDE_DEEP_OK ralph",
        "Execution Mode Decision Prompt",
        "Mode-Gated Agent Dispatch",
        "Use base agent names",
        "LIGHT",
        "STANDARD",
        "THOROUGH",
        "Required Behavior Lock",
    ],
    "autopilot": [
        "OH_NO_CLAUDE_DEEP_OK autopilot",
        ".oh-no/specs/deep-interview-{slug}.md",
        "five complete loops",
        "execution mode and mode source",
        "Cleanup And Final Verification",
    ],
}

missing = [needle for needle in expected[skill] if needle not in text]
if missing:
    raise SystemExit(f"{skill} deep smoke missing markers: {missing}; got {text!r}")

linked_doc_markers = {
    "ralph": [
        "Execution Mode Decision Prompt",
        "Mode-Gated Agent Dispatch",
        "Required Behavior Lock",
    ],
    "autopilot": [
        "execution mode and mode source",
        "Cleanup And Final Verification",
    ],
}

if skill in linked_doc_markers and not all(marker in text for marker in linked_doc_markers[skill]):
    raise SystemExit(f"{skill} deep smoke missing linked-doc marker; got {text!r}")

print(f"ok - deep Claude linked-doc smoke: {skill} cost={data.get('total_cost_usd')}")
PY
}

run_deep_live_skill_test() {
  local skill="$1"
  local out_file="$RUN_DIR/deep-${skill}.json"
  local prompt
  prompt="$(deep_prompt_for_skill "$skill")"

  local cmd=(
    "$CLAUDE_BIN"
    --print
    --output-format json
    --model "$LIVE_MODEL"
    --max-budget-usd "$LIVE_MAX_BUDGET_USD"
    --permission-mode dontAsk
    --tools default
    --no-session-persistence
    --system-prompt "You are a read-only deep smoke test runner. You may read local files needed by the invoked skill. Do not edit files or create artifacts."
  )

  if [[ "$LIVE_LOAD_MODE" == "plugin-dir" ]]; then
    cmd+=(--plugin-dir "$PLUGIN_ROOT")
  fi

  cmd+=("$prompt")
  "${cmd[@]}" >"$out_file"
  assert_deep_json_output "$out_file" "$skill"
}

run_deep_live_tests() {
  if [[ "$RUN_DEEP_LIVE" != "1" ]]; then
    log "Skipping deep Claude linked-doc smoke tests"
    printf 'Run with --deep-live or OH_NO_DEEP_LIVE=1 to verify linked support docs are read.\n' >&2
    return
  fi

  log "Running deep Claude linked-doc smoke tests (${LIVE_LOAD_MODE})"
  mkdir -p "$RUN_DIR"
  for skill in deep-interview ralplan ralph autopilot; do
    run_deep_live_skill_test "$skill"
  done
  ok "deep live outputs saved under ${RUN_DIR#$PLUGIN_ROOT/}"
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
  log "All requested checks passed"
}

main "$@"
