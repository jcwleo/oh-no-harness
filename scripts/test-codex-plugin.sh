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

Installs or updates the local Codex plugin cache, enables the plugin in
\$CODEX_HOME/config.toml, then verifies that Codex exposes the plugin skills.

Codex CLI currently has marketplace add/upgrade commands, but no public
plugin install/list command equivalent to Claude Code. This script mirrors
Codex's enabled plugin cache layout directly:

  \$CODEX_HOME/plugins/cache/<marketplace>/<plugin>/<version>/
  [plugins."<plugin>@<marketplace>"]
  enabled = true

Options:
  --live             Run live codex exec smoke tests after prompt exposure checks.
  --deep-live        Run live deep smoke tests that require linked support docs.
  --skip-live        Skip live codex exec smoke tests. Default.
  --no-install       Do not sync the plugin cache or edit Codex config.
  --codex-home <dir> Use this Codex home instead of \$CODEX_HOME or ~/.codex.
  --model <model>    Model for live codex exec tests. Default: Codex config default.
  -h, --help         Show this help.

Environment overrides:
  CODEX_BIN, PYTHON_BIN, CODEX_HOME, OH_NO_INSTALL, OH_NO_LIVE, OH_NO_DEEP_LIVE,
  OH_NO_CODEX_TEST_MODEL, OH_NO_TEST_RUN_DIR
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

sync_plugin_cache() {
  [[ "$INSTALL_MODE" == "1" ]] || { log "Skipping Codex install/update (--no-install)"; return; }

  local version cache_parent target
  version="$(json_value version)"
  cache_parent="${CODEX_HOME_DIR}/plugins/cache/${MARKETPLACE_NAME}/${PLUGIN_NAME}"
  target="${cache_parent}/${version}"
  [[ -n "$version" ]] || fail "plugin version is empty"
  [[ "$target" == "${CODEX_HOME_DIR}/plugins/cache/${MARKETPLACE_NAME}/${PLUGIN_NAME}/"* ]] \
    || fail "refusing to sync outside Codex plugin cache: ${target}"

  log "Installing/updating Codex plugin cache"
  mkdir -p "$cache_parent"
  rm -rf "$target"
  mkdir -p "$target"

  rsync -a --delete \
    --exclude '.git/' \
    --exclude '.oh-no/' \
    --exclude '.claude/' \
    "$PLUGIN_ROOT/" "$target/"

  find "$cache_parent" -mindepth 1 -maxdepth 1 -type d ! -name "$version" -exec rm -rf {} +
  ok "plugin cache synced: ${target}"
}

enable_codex_plugin() {
  [[ "$INSTALL_MODE" == "1" ]] || return 0

  log "Enabling Codex plugin in config"
  mkdir -p "$CODEX_HOME_DIR"
  local config_path="${CODEX_HOME_DIR}/config.toml"

  "$PYTHON_BIN" - "$config_path" "$PLUGIN_ID" <<'PY'
from __future__ import annotations

import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

config_path = Path(sys.argv[1])
plugin_id = sys.argv[2]

text = config_path.read_text(encoding="utf-8") if config_path.exists() else ""
original = text
section = f'[plugins."{plugin_id}"]'
header_re = re.compile(r'^\[.*\]\s*$', re.MULTILINE)

if section in text:
    start = text.index(section)
    match = header_re.search(text, start + len(section))
    end = match.start() if match else len(text)
    body = text[start:end]
    if re.search(r'(?m)^enabled\s*=', body):
        body = re.sub(r'(?m)^enabled\s*=.*$', 'enabled = true', body)
    else:
        body = body.rstrip() + "\nenabled = true\n"
    text = text[:start] + body + text[end:]
else:
    separator = "\n" if text.endswith("\n") or not text else "\n\n"
    text = text + separator + f'{section}\nenabled = true\n'

if text != original:
    config_path.parent.mkdir(parents=True, exist_ok=True)
    if config_path.exists():
        stamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
        shutil.copy2(config_path, config_path.with_suffix(config_path.suffix + f".bak-{stamp}"))
    config_path.write_text(text, encoding="utf-8")
PY

  ok "plugin enabled: ${PLUGIN_ID}"
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
  sync_plugin_cache
  enable_codex_plugin
  assert_codex_prompt_exposes_skills
  run_live_tests
  run_deep_live_tests
  log "All requested Codex checks passed"
}

main "$@"
