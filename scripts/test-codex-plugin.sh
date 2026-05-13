#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

CODEX_BIN="${CODEX_BIN:-codex}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
CODEX_HOME_DIR="${CODEX_HOME:-${HOME}/.codex}"
PLUGIN_NAME="${OH_NO_PLUGIN_NAME:-oh-no-harness}"
MARKETPLACE_NAME="${OH_NO_MARKETPLACE_NAME:-oh-no-harness}"
PLUGIN_ID="${PLUGIN_NAME}@${MARKETPLACE_NAME}"
MARKETPLACE_SOURCE="${OH_NO_MARKETPLACE_SOURCE:-$PLUGIN_ROOT}"
INSTALL_MODE="${OH_NO_INSTALL:-1}"
RUN_LIVE="${OH_NO_LIVE:-0}"
RUN_DEEP_LIVE="${OH_NO_DEEP_LIVE:-0}"
LIVE_MODEL="${OH_NO_CODEX_TEST_MODEL:-}"
RUN_DIR="${OH_NO_TEST_RUN_DIR:-${PLUGIN_ROOT}/.oh-no/test-runs/$(date +%Y%m%d-%H%M%S)-codex}"

PUBLIC_SKILLS=(
  using-oh-no-harness
  interview
  ralplan
  ralph
  autopilot
  auto-routing
  test-driven-development
  ai-slop-cleaner
  verification-before-completion
  systematic-debugging
)

usage() {
  cat <<USAGE
Usage: scripts/test-codex-plugin.sh [options]

Adds the Codex marketplace, exercises the same app-server plugin list/install
path used by /plugins, then verifies that Codex exposes the plugin skills.

Options:
  --live             Run live codex exec smoke tests after prompt exposure checks.
  --deep-live        Run live deep smoke tests that require linked support docs.
  --skip-live        Skip live codex exec smoke tests. Default.
  --no-install       Skip the marketplace/app-server install step.
  --codex-home <dir> Use this Codex home instead of \$CODEX_HOME or ~/.codex.
  --model <model>    Model for live codex exec tests. Default: Codex config default.
  --marketplace-source <source>
                     Marketplace source passed to app-server marketplace/add.
                     Default: this checkout. Use jcwleo/oh-no-harness to test GitHub.
  -h, --help         Show this help.

Environment overrides:
  CODEX_BIN, PYTHON_BIN, CODEX_HOME, OH_NO_INSTALL, OH_NO_LIVE, OH_NO_DEEP_LIVE,
  OH_NO_CODEX_TEST_MODEL, OH_NO_TEST_RUN_DIR, OH_NO_MARKETPLACE_SOURCE
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
  "$PYTHON_BIN" "$PLUGIN_ROOT/scripts/validate-plugin-files.py" "$PLUGIN_ROOT"

  local manifest_name manifest_version
  manifest_name="$(json_value name)"
  manifest_version="$(json_value version)"
  [[ "$manifest_name" == "$PLUGIN_NAME" ]] || fail "manifest name is ${manifest_name}, expected ${PLUGIN_NAME}"
  [[ "$manifest_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "manifest version is not semver: ${manifest_version}"
  ok "Codex manifest identity: ${manifest_name} ${manifest_version}"
}

assert_codex_bundle_synced() {
  log "Verifying Codex marketplace bundle"
  "$PLUGIN_ROOT/scripts/sync-codex-plugin-bundle" --check
}

install_via_codex_plugins() {
  [[ "$INSTALL_MODE" == "1" ]] || { log "Skipping Codex marketplace install (--no-install)"; return; }

  log "Adding marketplace through Codex CLI"
  mkdir -p "$RUN_DIR" "$CODEX_HOME_DIR"
  CODEX_HOME="$CODEX_HOME_DIR" "$CODEX_BIN" plugin marketplace add "$MARKETPLACE_SOURCE"
  ok "Codex marketplace added from ${MARKETPLACE_SOURCE}"

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
    autopilot)
      printf 'Use the oh-no-harness:autopilot skill. Smoke test only. Do not edit files. Reply with exactly OH_NO_CODEX_SKILL_OK autopilot.'
      ;;
    auto-routing)
      printf 'Use the oh-no-harness:auto-routing skill. Smoke test only. Do not edit files. Reply with exactly OH_NO_CODEX_SKILL_OK auto-routing.'
      ;;
    test-driven-development)
      printf 'Use the oh-no-harness:test-driven-development skill. Smoke test only. Do not edit files. Reply with exactly OH_NO_CODEX_SKILL_OK test-driven-development.'
      ;;
    ai-slop-cleaner)
      printf 'Use the oh-no-harness:ai-slop-cleaner skill. Smoke test only. Do not edit files. Reply with exactly OH_NO_CODEX_SKILL_OK ai-slop-cleaner.'
      ;;
    verification-before-completion)
      printf 'Use the oh-no-harness:verification-before-completion skill. Smoke test only. Do not edit files. Reply with exactly OH_NO_CODEX_SKILL_OK verification-before-completion.'
      ;;
    systematic-debugging)
      printf 'Use the oh-no-harness:systematic-debugging skill. Smoke test only. Do not edit files. Reply with exactly OH_NO_CODEX_SKILL_OK systematic-debugging.'
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

  local cmd=(
    "$CODEX_BIN"
    --ask-for-approval never
    exec
    --cd "$PLUGIN_ROOT"
    --sandbox read-only
    --ephemeral
    --skip-git-repo-check
    --output-last-message "$out_file"
  )

  if [[ -n "$LIVE_MODEL" ]]; then
    cmd+=(--model "$LIVE_MODEL")
  fi

  cmd+=("$prompt")

  CODEX_HOME="$CODEX_HOME_DIR" "${cmd[@]}" >"$log_file" 2>&1

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
  ok "live outputs saved under ${RUN_DIR#$PLUGIN_ROOT/}"
}

deep_prompt_for_skill() {
  case "$1" in
    interview)
      printf 'Use the oh-no-harness:interview skill. Deep smoke test only. Read the linked Optional Company Context reference and the Socratic interview guidance before answering. Do not edit files. Return when company context should be considered, whether it is advisory or executable, whether remote/global systems should be searched for it, and the names of the Socratic guidance sections for question routing, answer capture, readiness, and goal restatement. End with OH_NO_CODEX_DEEP_OK interview.'
      ;;
    ralplan)
      printf 'Use the oh-no-harness:ralplan skill. Deep smoke test only. Read the embedded consensus planning workflow and execution mode contract before answering. Do not edit files. Return the loop limit, approval status term, Architect/Critic ordering rule, and the required Ralph execution profile fields. End with OH_NO_CODEX_DEEP_OK ralplan.'
      ;;
    ralph)
      printf 'Use the oh-no-harness:ralph skill. Deep smoke test only. Read the execution mode contract, execution support docs, parallel coordination doc, and linked cleanup/TDD skills before answering. Do not edit files. Return the execution mode decision prompt heading, all execution mode names, the mode-gated dispatch heading, the base agent naming rule, and the cleanup behavior-lock heading. End with OH_NO_CODEX_DEEP_OK ralph.'
      ;;
    autopilot)
      printf 'Use the oh-no-harness:autopilot skill. Deep smoke test only. Read the linked phase skills, execution mode contract, and shared parallel coordination doc enough to answer from their referenced docs. Do not edit files. Return the spec artifact path from clarification, the planning loop limit, the required execution mode source in the final report, and the cleanup/final-verification heading reached through execution. End with OH_NO_CODEX_DEEP_OK autopilot.'
      ;;
    *)
      fail "No deep live prompt for skill: $1"
      ;;
  esac
}

assert_deep_output() {
  "$PYTHON_BIN" - "$1" "$2" <<'PY'
import sys

path, skill = sys.argv[1], sys.argv[2]
text = open(path, "r", encoding="utf-8").read()

expected = {
    "interview": [
        "OH_NO_CODEX_DEEP_OK interview",
        "already available",
        "advisory",
        "Do not search remote systems",
        "Question Routing",
        "Answer Capture",
        "Spec Readiness Guard",
        "Goal Restatement Gate",
    ],
    "ralplan": [
        "OH_NO_CODEX_DEEP_OK ralplan",
        "five complete loops",
        "pending approval",
        "sequential",
        "Overall Ralph mode",
        "Task sizing",
        "Execution profile recap",
    ],
    "ralph": [
        "OH_NO_CODEX_DEEP_OK ralph",
        "Execution Mode Decision Prompt",
        "Mode-Gated Agent Dispatch",
        "Use base agent names",
        "LIGHT",
        "STANDARD",
        "THOROUGH",
        "Required Behavior Lock",
    ],
    "autopilot": [
        "OH_NO_CODEX_DEEP_OK autopilot",
        ".oh-no/specs/interview-{slug}.md",
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
    --ephemeral
    --skip-git-repo-check
    --output-last-message "$out_file"
  )

  if [[ -n "$LIVE_MODEL" ]]; then
    cmd+=(--model "$LIVE_MODEL")
  fi

  cmd+=("$prompt")
  CODEX_HOME="$CODEX_HOME_DIR" "${cmd[@]}" >"$log_file" 2>&1
  assert_deep_output "$out_file" "$skill"
}

run_deep_live_tests() {
  if [[ "$RUN_DEEP_LIVE" != "1" ]]; then
    log "Skipping deep Codex linked-doc smoke tests"
    printf 'Run with --deep-live or OH_NO_DEEP_LIVE=1 to verify linked support docs are read.\n' >&2
    return
  fi

  log "Running deep Codex linked-doc smoke tests"
  mkdir -p "$RUN_DIR"
  for skill in interview ralplan ralph autopilot; do
    run_deep_live_skill_test "$skill"
  done
  ok "deep live outputs saved under ${RUN_DIR#$PLUGIN_ROOT/}"
}

main() {
  cd "$PLUGIN_ROOT"
  require_command "$CODEX_BIN"
  require_command "$PYTHON_BIN"
  require_command rsync

  log "Testing ${PLUGIN_ID} for Codex from ${PLUGIN_ROOT}"
  validate_codex_manifest
  assert_codex_bundle_synced
  install_via_codex_plugins
  assert_codex_prompt_exposes_skills
  run_live_tests
  run_deep_live_tests
  log "All requested Codex checks passed"
}

main "$@"
