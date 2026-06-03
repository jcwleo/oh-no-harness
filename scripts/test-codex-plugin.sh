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
RUN_SIMPLIFY_LIVE="${OH_NO_SIMPLIFY_LIVE:-0}"
RUN_WORKTREE_LIVE="${OH_NO_WORKTREE_LIVE:-0}"
LIVE_MODEL="${OH_NO_CODEX_TEST_MODEL:-}"
RUN_DIR="${OH_NO_TEST_RUN_DIR:-${MARKETPLACE_ROOT}/.oh-no/test-runs/$(date +%Y%m%d-%H%M%S)-codex}"

PUBLIC_SKILLS=(
  using-oh-no-harness
  interview
  ralplan
  ralph
  autopilot
  auto-routing
  test-driven-development
  simplify
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
  --parallel-live    Run live Ralph parallel-subagent smoke test.
  --ralplan-live     Run live Ralplan sequential planning-subagent smoke test.
  --simplify-live    Run live simplify cleanup-subagent smoke test.
  --worktree-live    Run live Ralph worktree-creation smoke test in a disposable repo.
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
  OH_NO_PARALLEL_LIVE, OH_NO_RALPLAN_LIVE, OH_NO_CODEX_TEST_MODEL,
  OH_NO_SIMPLIFY_LIVE, OH_NO_WORKTREE_LIVE, OH_NO_TEST_RUN_DIR,
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
    --simplify-live)
      RUN_SIMPLIFY_LIVE=1
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

  PLUGIN_ROOT="$PLUGIN_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" "$PLUGIN_ROOT/hooks/run-hook.cmd" session-start \
    >"$temp_data/session-start.json"
  "$PYTHON_BIN" - "$temp_data/session-start.json" <<'PY'
import json
import sys

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
]
missing = [needle for needle in required if needle not in text]
if missing:
    raise SystemExit(f"Codex SessionStart missing Ralph/TDD routing markers: {missing}")
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
PY

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
    "docs/shared/ralph-subagent-policy.md",
    "docs/platforms/codex-ralph.md",
    "Agent prompt source: docs/agent-core/<role>.md",
    "Agent prompt content:",
    "spawn_agent",
    "wait_agent",
    "close_agent",
    "Parallel trigger: approved-plan-handoff",
]
missing = [needle for needle in required if needle not in text]
if missing:
    raise SystemExit(f"Codex Ralph adapter missing markers: {missing}")
for forbidden in ("CLAUDE_CODE_ONLY_RALPH_ADAPTER", "docs/platforms/claude-code-ralph.md", "@agent-oh-no-harness:<agent>"):
    if forbidden in text:
        raise SystemExit(f"Codex Ralph adapter leaked Claude marker: {forbidden}")
PY

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
    "Can you explain how to run ralph?"; do
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

  rm -rf "$temp_data"
  ok "Codex hooks inject only Codex-specific Ralph context"
}

validate_codex_agent_installer() {
  log "Validating optional Codex custom-agent installer"

  local installer="$PLUGIN_ROOT/scripts/install-codex-agents"
  sh -n "$installer"

  local temp_data dry_run_count installed_count remaining_count force_status
  temp_data="$(mktemp -d)"

  "$installer" --scope project --dry-run >"$temp_data/project-dry-run.out"
  dry_run_count="$(grep -c '^would install: ' "$temp_data/project-dry-run.out")"
  [[ "$dry_run_count" == "11" ]] || fail "Codex agent project dry-run planned ${dry_run_count} installs, expected 11"

  HOME="$temp_data/home-install" "$installer" --scope user >"$temp_data/user-install.out"
  installed_count="$(find "$temp_data/home-install/.codex/agents" -type f -name 'oh-no-*.toml' | wc -l | tr -d ' ')"
  [[ "$installed_count" == "11" ]] || fail "Codex agent user install wrote ${installed_count} templates, expected 11"
  HOME="$temp_data/home-install" "$installer" --scope user --remove >"$temp_data/user-remove.out"
  remaining_count="$(find "$temp_data/home-install" -type f | wc -l | tr -d ' ')"
  [[ "$remaining_count" == "0" ]] || fail "Codex agent user remove left ${remaining_count} files"

  mkdir -p "$temp_data/home-unmarked/.codex/agents"
  printf 'user owned\n' >"$temp_data/home-unmarked/.codex/agents/oh-no-code-reviewer.toml"
  set +e
  HOME="$temp_data/home-unmarked" "$installer" --scope user --force \
    >"$temp_data/unmarked-force.out" 2>"$temp_data/unmarked-force.err"
  force_status=$?
  set -e
  [[ "$force_status" != "0" ]] || fail "Codex agent installer overwrote an unmarked file with --force"
  grep -q 'skip unmarked existing:' "$temp_data/unmarked-force.err" \
    || fail "Codex agent installer did not report unmarked overwrite protection"
  [[ "$(cat "$temp_data/home-unmarked/.codex/agents/oh-no-code-reviewer.toml")" == "user owned" ]] \
    || fail "Codex agent installer changed an unmarked user-owned file"

  rm -rf "$temp_data"
  ok "Codex custom-agent installer installs, removes, and protects unmarked files"
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
  ok "live outputs saved under ${RUN_DIR#$MARKETPLACE_ROOT/}"
}

deep_prompt_for_skill() {
  case "$1" in
    interview)
      printf 'Use the oh-no-harness:interview skill. Deep smoke test only. Read the linked Optional Company Context reference and the Socratic interview guidance before answering. Do not edit files. Return when company context should be considered, whether it is advisory or executable, whether remote/global systems should be searched for it, and the names of the Socratic guidance sections for question routing, answer capture, readiness, and goal restatement. End with OH_NO_CODEX_DEEP_OK interview.'
      ;;
    ralplan)
      printf 'Use the oh-no-harness:ralplan skill. Deep smoke test only. Read the embedded consensus planning workflow, test case design quality bar, execution mode contract, and worktree policy before answering. Do not edit files. Return the loop limit, approval status term, full Analyst -> Planner -> Architect -> Critic ordering rule, the required Ralph execution profile fields, the test case design requirements, the shallow-test rejection rule, the project-local worktree path for write-capable execution, and the Codex host-policy-controlled dispatch rule for planning subagents. End with OH_NO_CODEX_DEEP_OK ralplan.'
      ;;
    ralph)
      printf 'Use the oh-no-harness:ralph skill. Deep smoke test only. Read the execution mode contract, execution support docs, worktree policy, parallel coordination doc, and linked cleanup/TDD skills before answering. Do not edit files. Return the execution mode decision prompt heading, all execution mode names, the mode-gated dispatch heading, the base agent naming rule, the parallel trigger field, Codex spawn-agent host-policy rule, the default project-local worktree path, the parent-directory sibling fallback rule, the TDD enforcement boundary including test-driven-development as an internal mid-loop discipline and not a top-level implementation route, and the cleanup behavior-lock heading. End with OH_NO_CODEX_DEEP_OK ralph.'
      ;;
    autopilot)
      printf 'Use the oh-no-harness:autopilot skill. Deep smoke test only. Read the linked phase skills, execution mode contract, shared worktree policy, and shared parallel coordination doc enough to answer from their referenced docs. Do not edit files. Return the spec artifact path from clarification, the planning loop limit, the project-local automatic worktree path, the required execution mode source in the final report, and the cleanup/final-verification heading reached through execution. End with OH_NO_CODEX_DEEP_OK autopilot.'
      ;;
    simplify)
      printf 'Use the oh-no-harness:simplify skill. Deep smoke test only. Read the shared simplify core and Codex platform docs before answering. Do not edit files. Return the exact headings Required Behavior Lock, Phase 0 - Gather The Diff, Phase 1 - Review, and Phase 2 - Apply The Fixes; the four cleanup subagent angles; the host policy rule that they launch in one batch before waiting; the rule that cleanup angles must not collapse into a single generic inline review and must use separate inline fallback blocks with a fallback reason if subagent dispatch is unavailable; and the false-positive or behavior-changing skip rule. End with OH_NO_CODEX_DEEP_OK simplify.'
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
text_lower = text.lower()

expected = {
    "interview": [
        "OH_NO_CODEX_DEEP_OK interview",
        "advisory",
        "Question Routing",
        "Answer Capture",
        "Spec Readiness Guard",
        "Goal Restatement Gate",
    ],
    "ralplan": [
        "OH_NO_CODEX_DEEP_OK ralplan",
        "five complete",
        "pending approval",
        "Overall Ralph mode",
        "Task sizing",
        "Execution profile",
        "Analyst",
        "Planner",
        "must-fail",
        "must-pass",
        "negative",
        "edge",
        "old broken behavior",
        ".oh-no/worktrees/<task-slug>",
        "host",
        "policy",
    ],
    "ralph": [
        "OH_NO_CODEX_DEEP_OK ralph",
        "Execution Mode Decision Prompt",
        "Mode-Gated Agent Dispatch",
        "LIGHT",
        "STANDARD",
        "THOROUGH",
        "Parallel trigger",
        "host",
        "policy",
        ".oh-no/worktrees/<task-slug>",
        "parent-directory",
        "test-driven-development",
        "internal mid-loop",
        "not a top-level implementation",
        "Required Behavior Lock",
    ],
    "autopilot": [
        "OH_NO_CODEX_DEEP_OK autopilot",
        ".oh-no/specs/interview-{slug}.md",
        "five complete",
        ".oh-no/worktrees/<task-slug>",
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
        "subagents",
        "one batch",
        "before waiting",
        "inline fallback",
        "fallback reason",
        "false positive",
        "intended behavior",
    ],
}

missing = [needle for needle in expected[skill] if needle.lower() not in text_lower]
if missing:
    raise SystemExit(f"{skill} deep smoke missing markers: {missing}; got {text!r}")

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
    and "architect" in text_lower
    and "critic" in text_lower
    and (
        "analyst -> planner -> architect -> critic" in text_lower
        or "analyst, planner, architect, critic" in text_lower
        or "analyst, planner, architect, and critic" in text_lower
        or (
            terms_appear_in_order("analyst", "planner", "architect", "critic")
            and ("first" in text_lower or "then" in text_lower or "sequential" in text_lower)
        )
        or (
            "analyst first" in text_lower
            and "planner second" in text_lower
            and "architect third" in text_lower
            and "critic fourth" in text_lower
        )
    )
):
    raise SystemExit(f"{skill} deep smoke missing full consensus ordering marker; got {text!r}")

if skill == "ralplan" and not (
    ("architect" in text_lower and "critic" in text_lower)
    and (
        "sequential" in text_lower
        or "only after architect" in text_lower
        or "architect first" in text_lower
        or "never run them in parallel" in text_lower
    )
):
    raise SystemExit(f"{skill} deep smoke missing Architect/Critic ordering marker; got {text!r}")

linked_doc_markers = {
    "ralph": [
        "Execution Mode Decision Prompt",
        "Mode-Gated Agent Dispatch",
        "Parallel trigger",
        "Required Behavior Lock",
    ],
    "autopilot": [
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
  for skill in interview ralplan ralph autopilot simplify; do
    run_deep_live_skill_test "$skill"
  done
  ok "deep live outputs saved under ${RUN_DIR#$MARKETPLACE_ROOT/}"
}

run_ralplan_live_test() {
  if [[ "$RUN_RALPLAN_LIVE" != "1" ]]; then
    log "Skipping live Codex ralplan sequential-subagent smoke test"
    printf 'Run with --ralplan-live or OH_NO_RALPLAN_LIVE=1 to verify Planner -> Architect -> Critic sequential spawn_agent review.\n' >&2
    return
  fi

  log "Running live Codex ralplan sequential-subagent smoke test"
  mkdir -p "$RUN_DIR"
  local out_file="$RUN_DIR/ralplan-sequential-subagents.jsonl"
  local err_file="$RUN_DIR/ralplan-sequential-subagents.err"
  local prompt
  prompt='Use the oh-no-harness:ralplan skill. Read-only dispatch instrumentation test only: do not create a full plan, do not edit files, and do not create artifacts. Requirements source is already analyzed inline; do not spawn explore, analyst, executor, verifier, code-reviewer, security-reviewer, qa-tester, or any role except planner, architect, and critic. Synthetic approved task: document that the host asks the user which execution workflow to run after ralplan plan approval. Use Codex spawn_agent exactly three times in this strict order: planner, then wait for and close planner before architect; architect, then wait for and close architect before critic; critic, then wait for and close critic before final. Never run these planning review agents in parallel. For every Codex spawn_agent call, omit agent_type/model/reasoning overrides and do not fork full history. Each spawned-agent message MUST include Agent prompt source and Agent prompt content copied from the matching docs/agent-core/<role>.md file. Planner expected output: only a short section titled Planner draft v1 with Goal, Acceptance criteria, Execution profile, Worktree policy, Verification plan. Architect expected output: only a short section titled Architect review v1 with Reviewed draft: Planner draft v1, Verdict: approve, Required changes: none. Critic expected output: only a short section titled Critic review v1 with Reviewed draft: Planner draft v1, Architect review consumed: yes, Verdict: APPROVE. The architect subagent must receive the actual Planner draft v1 text. The critic subagent must receive the actual Planner draft v1 and Architect review v1 text. Even if a subagent suggests improvements, do not revise; this smoke test only verifies the v1 chain. After all three subagents finish and all three completed planning agents are closed, reply with exactly OH_NO_CODEX_RALPLAN_SEQUENTIAL_SUBAGENTS_OK and summarize Role order: planner -> architect -> critic, Waited between roles: yes, Reviews chained: Planner draft v1 -> Architect review v1 -> Critic review v1, Closed planning agents: 3.'

  local cmd=(
    "$CODEX_BIN"
    --enable plugin_hooks
    --ask-for-approval never
    exec
    --json
    --cd "$PLUGIN_ROOT"
    --sandbox read-only
    --ephemeral
    --skip-git-repo-check
  )

  if [[ -n "$LIVE_MODEL" ]]; then
    cmd+=(--model "$LIVE_MODEL")
  fi

  CODEX_HOME="$CODEX_HOME_DIR" "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

  "$PYTHON_BIN" - "$out_file" "$err_file" <<'PY'
import json
import sys
from collections import defaultdict

path = sys.argv[1]
err_path = sys.argv[2]
expected_roles = ["planner", "architect", "critic"]
role_headings = {
    "planner": "# Planner Agent",
    "architect": "# Architect Agent",
    "critic": "# Critic Agent",
}
required_prompt_markers = [
    "## Skill Relationship",
    "## Responsibilities",
    "## Operating Rules",
    "## Output",
]
dependency_prompt_markers = {
    "architect": ["Planner draft v1"],
    "critic": ["Planner draft v1", "Architect review v1"],
}
output_markers = {
    "planner": ["Planner draft v1"],
    "architect": ["Architect review v1", "Reviewed draft", "Planner draft v1"],
    "critic": ["Critic review v1", "Architect review consumed"],
}

def collect_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(item) for item in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(item) for item in value)
    return ""

def roles_in_text(text):
    lower = text.lower()
    return [
        role for role in expected_roles
        if f"Agent prompt source: docs/agent-core/{role}.md".lower() in lower
    ]

def mentioned_receivers(item):
    text = collect_text(item)
    return {
        receiver
        for receiver in receiver_to_role
        if receiver in text
    }

with open(err_path, "r", encoding="utf-8") as fh:
    err_text = fh.read()
if "spawn failed" in err_text.lower() or "agent thread limit reached" in err_text.lower():
    raise SystemExit(f"Codex ralplan sequential smoke saw spawn failure in stderr: {err_text[:2000]!r}")

successful_spawns = []
failed_spawns = []
events = []
receiver_to_role = {}
role_outputs = defaultdict(list)
wait_index_by_receiver = {}
close_index_by_receiver = {}
marker = False

with open(path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        item = data.get("item") or {}
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
            if tool in {"wait", "wait_agent"}:
                for receiver in receivers:
                    wait_index_by_receiver.setdefault(receiver, index)
            if tool == "close_agent":
                for receiver in receivers:
                    close_index_by_receiver.setdefault(receiver, index)
            roles = {receiver_to_role.get(receiver) for receiver in receivers}
            for role in roles:
                if role:
                    events.append((index, tool, role))
            for receiver, state in (item.get("agents_states") or {}).items():
                role = receiver_to_role.get(receiver)
                if role:
                    state_message = state.get("message", state) if isinstance(state, dict) else state
                    message = collect_text(state_message)
                    if message:
                        role_outputs[role].append(message)

if failed_spawns:
    raise SystemExit(f"Codex ralplan sequential smoke saw failed spawn_agent calls: {failed_spawns!r}")
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
if missing_closes:
    raise SystemExit(f"Codex ralplan sequential smoke did not close spawned receivers: {missing_closes!r}")
early_closes = {
    receiver: (wait_index_by_receiver[receiver], close_index_by_receiver[receiver])
    for receiver in receiver_ids
    if close_index_by_receiver[receiver] <= wait_index_by_receiver[receiver]
}
if early_closes:
    raise SystemExit(
        "Codex ralplan sequential smoke closed agents before their wait_agent results were captured: "
        f"{early_closes!r}"
    )

actual_order = [role for _, role, _, _ in successful_spawns]
if actual_order != expected_roles:
    raise SystemExit(f"expected sequential spawn order {expected_roles!r}, got {actual_order!r}")

for role, payloads in {
    role: [spawn for spawn in successful_spawns if spawn[1] == role]
    for role in expected_roles
}.items():
    if len(payloads) != 1:
        raise SystemExit(f"expected exactly one successful spawn_agent payload for {role}, got {len(payloads)}")
    _, _, _, role_text = payloads[0]
    missing_prompt_markers = [
        marker for marker in [
            f"Agent prompt source: docs/agent-core/{role}.md",
            role_headings[role],
            *required_prompt_markers,
            *dependency_prompt_markers.get(role, []),
        ]
        if marker.lower() not in role_text.lower()
    ]
    if missing_prompt_markers:
        raise SystemExit(
            f"Codex ralplan spawn_agent payload for {role} did not embed required prompt/review markers: "
            f"{missing_prompt_markers}; spawn_text={role_text[:2000]!r}"
        )
    forbidden_frontmatter_markers = ["\n---\n", "\ntools:", "\nmodel:", "\ncolor:"]
    leaked = [marker for marker in forbidden_frontmatter_markers if marker in role_text]
    if leaked:
        raise SystemExit(
            f"Codex ralplan spawn_agent payload for {role} leaked Claude YAML frontmatter markers: "
            f"{leaked}; spawn_text={role_text[:2000]!r}"
        )

for previous, following in zip(successful_spawns, successful_spawns[1:]):
    previous_index, previous_role, _, _ = previous
    following_index, following_role, _, _ = following
    has_barrier = any(
        previous_index < event_index < following_index
        and event_type in {"wait", "wait_agent", "close_agent"}
        and role == previous_role
        for event_index, event_type, role in events
    )
    if not has_barrier:
        raise SystemExit(
            f"expected wait/close for {previous_role} between {previous_role} spawn and "
            f"{following_role} spawn; events={events!r}"
        )

for role, markers in output_markers.items():
    output_text = "\n".join(role_outputs.get(role, []))
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

if not marker:
    raise SystemExit("Codex ralplan sequential smoke did not return success marker")

print("ok - live Codex ralplan planning subagents reviewed sequentially")
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
  prompt='Use the oh-no-harness:ralph skill. Read-only live subagent smoke test. This is an explicit parallel subagents request. Verify every Oh No Harness role with Codex spawn_agent, but respect platform concurrency limits: run the roles in independent waves of at most three subagents, start every subagent in the current wave before waiting for that wave, call close_agent for every completed agent before starting the next wave, and do not continue if any spawn fails. For every receiver thread, call wait_agent until that receiver appears in a completed wait result before calling close_agent; do not use close_agent as the first result capture for any receiver. Wave 1: explore, analyst, planner. Wave 2: architect, critic, executor. Wave 3: debugger, verifier, code-reviewer. Wave 4: security-reviewer, qa-tester. For every Codex spawn_agent call, omit agent_type/model/reasoning overrides and do not fork full history. Each spawned-agent message MUST include Agent prompt source and Agent prompt content copied from the matching docs/agent-core/<role>.md file. Each subagent should inspect its own docs/agent-core/<role>.md file and report its role heading plus whether Skill Relationship, Responsibilities, Operating Rules, and Output are present. Do not edit files. After all eleven subagents finish and all completed agents are closed, reply exactly OH_NO_CODEX_PARALLEL_SUBAGENTS_OK and summarize the eleven role checks plus Wait results captured: 11; Closed agents: 11.'

  local cmd=(
    "$CODEX_BIN"
    --enable plugin_hooks
    --ask-for-approval never
    exec
    --json
    --cd "$PLUGIN_ROOT"
    --sandbox read-only
    --ephemeral
    --skip-git-repo-check
  )

  if [[ -n "$LIVE_MODEL" ]]; then
    cmd+=(--model "$LIVE_MODEL")
  fi

  CODEX_HOME="$CODEX_HOME_DIR" "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

  "$PYTHON_BIN" - "$out_file" "$err_file" <<'PY'
import json
import sys
from collections import defaultdict

path = sys.argv[1]
err_path = sys.argv[2]
successful_spawns = []
failed_spawns = []
spawn_texts = []
spawn_texts_by_role = defaultdict(list)
first_wait_index = None
receiver_to_role = {}
wait_index_by_receiver = {}
close_index_by_receiver = {}
marker = False

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
if "spawn failed" in err_text.lower() or "agent thread limit reached" in err_text.lower():
    raise SystemExit(f"Codex live parallel smoke saw spawn failure in stderr: {err_text[:2000]!r}")

expected_roles = [
    "explore",
    "analyst",
    "planner",
    "architect",
    "critic",
    "executor",
    "debugger",
    "verifier",
    "code-reviewer",
    "security-reviewer",
    "qa-tester",
]
role_headings = {
    "explore": "# Explore Agent",
    "analyst": "# Analyst Agent",
    "planner": "# Planner Agent",
    "architect": "# Architect Agent",
    "critic": "# Critic Agent",
    "executor": "# Executor Agent",
    "debugger": "# Debugger Agent",
    "verifier": "# Verifier Agent",
    "code-reviewer": "# Code Reviewer Agent",
    "security-reviewer": "# Security Reviewer Agent",
    "qa-tester": "# QA Tester Agent",
}
role_waves = [
    ("explore", "analyst", "planner"),
    ("architect", "critic", "executor"),
    ("debugger", "verifier", "code-reviewer"),
    ("security-reviewer", "qa-tester"),
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
        if f"Agent prompt source: docs/agent-core/{role}.md".lower() in text.lower()
    ]

def mentioned_receivers(item):
    text = collect_text(item)
    return {
        receiver
        for receiver in receiver_to_role
        if receiver in text
    }

events = []
with open(path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        item = data.get("item") or {}
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
                    wait_index_by_receiver.setdefault(receiver, index)
            if tool == "close_agent":
                for receiver in receivers:
                    close_index_by_receiver.setdefault(receiver, index)
        text = item.get("text") or data.get("result", "")
        if "OH_NO_CODEX_PARALLEL_SUBAGENTS_OK" in text:
            marker = True

if failed_spawns:
    raise SystemExit(f"Codex live parallel smoke saw failed spawn_agent calls: {failed_spawns!r}")
if len(successful_spawns) < len(expected_roles):
    raise SystemExit(
        f"expected at least {len(expected_roles)} completed spawn_agent calls with receiver threads, "
        f"got {len(successful_spawns)}: {successful_spawns!r}"
    )
receiver_ids = {rid for _, receivers in successful_spawns[:len(expected_roles)] for rid in receivers}
if len(receiver_ids) < len(expected_roles):
    raise SystemExit(f"expected {len(expected_roles)} distinct spawned receiver threads, got {receiver_ids!r}")
missing_wait_results = sorted(receiver_ids - set(wait_index_by_receiver))
missing_closes = sorted(receiver_ids - set(close_index_by_receiver))
if missing_wait_results:
    raise SystemExit(f"Codex live parallel smoke did not capture wait_agent results for receivers: {missing_wait_results!r}")
if missing_closes:
    raise SystemExit(f"Codex live parallel smoke did not close spawned receivers: {missing_closes!r}")
early_closes = {
    receiver: (wait_index_by_receiver[receiver], close_index_by_receiver[receiver])
    for receiver in receiver_ids
    if close_index_by_receiver[receiver] <= wait_index_by_receiver[receiver]
}
if early_closes:
    raise SystemExit(
        "Codex live parallel smoke closed agents before their wait_agent results were captured: "
        f"{early_closes!r}"
    )
if first_wait_index is not None:
    first_wave = set(role_waves[0])
    roles_before_first_wait = {
        role for index, event_type, role in events
        if event_type == "spawn" and index < first_wait_index
    }
    if not first_wave.issubset(roles_before_first_wait):
        raise SystemExit(
            "first Codex spawn wave did not complete before the first wait; "
            f"expected={sorted(first_wave)!r} got={sorted(roles_before_first_wait)!r}"
        )
for role in expected_roles:
    role_payloads = spawn_texts_by_role.get(role, [])
    if len(role_payloads) != 1:
        raise SystemExit(f"expected exactly one successful spawn_agent payload for {role}, got {len(role_payloads)}")
    role_text = role_payloads[0]
    missing_prompt_markers = [
        marker for marker in [
            f"Agent prompt source: docs/agent-core/{role}.md",
            role_headings[role],
            *required_prompt_markers,
        ]
        if marker.lower() not in role_text.lower()
    ]
    if missing_prompt_markers:
        raise SystemExit(
            f"Codex spawn_agent payload for {role} did not embed required agent prompt content: "
            f"{missing_prompt_markers}; spawn_text={role_text[:2000]!r}"
        )
    forbidden_frontmatter_markers = ["\n---\n", "\ntools:", "\nmodel:", "\ncolor:"]
    leaked = [marker for marker in forbidden_frontmatter_markers if marker in role_text]
    if leaked:
        raise SystemExit(
            f"Codex spawn_agent payload for {role} leaked Claude YAML frontmatter markers: "
            f"{leaked}; spawn_text={role_text[:2000]!r}"
        )
if not marker:
    raise SystemExit("Codex live parallel smoke did not return success marker")

print("ok - live Codex role subagents spawned with per-role prompt embedding")
PY
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
  prompt='Use the oh-no-harness:simplify skill. Read-only dispatch instrumentation test only: do not edit files, do not create artifacts, do not apply cleanup fixes, and do not run Phase 2. Verify Phase 1 dispatch only. Use Codex spawn_agent exactly four times in one batch before any wait, wait_agent, or close_agent call. The four cleanup subagent angles must be exactly Reuse, Simplification, Efficiency, and Altitude. For every Codex spawn_agent call, omit agent_type/model/reasoning overrides and do not fork full history. Each spawned-agent message MUST include exactly one line of the form Angle: <angle>, one matching marker line, plus these literal lines: Scope: current diff; Do not edit files; Do not create artifacts; Do not apply cleanup fixes; Do not run Phase 2; Expected output: findings with file, line, summary, concrete cost. Marker lines by angle: Reuse uses Marker: OH_NO_SIMPLIFY_REUSE_READONLY; Simplification uses Marker: OH_NO_SIMPLIFY_SIMPLIFICATION_READONLY; Efficiency uses Marker: OH_NO_SIMPLIFY_EFFICIENCY_READONLY; Altitude uses Marker: OH_NO_SIMPLIFY_ALTITUDE_READONLY. Each cleanup subagent should return only one short read-only finding summary for its assigned angle. For every receiver thread, call wait_agent until that receiver appears in a completed wait result before calling close_agent; do not use close_agent as the first result capture for any receiver. After each cleanup subagent result is captured through wait_agent, call close_agent for that completed agent. After all four cleanup subagents finish and all completed cleanup agents are closed, reply exactly OH_NO_CODEX_SIMPLIFY_SUBAGENTS_OK and summarize Review angles: Reuse, Simplification, Efficiency, Altitude; Launched before waiting: yes; Wait results captured: 4; Closed cleanup agents: 4.'

  local cmd=(
    "$CODEX_BIN"
    --enable plugin_hooks
    --ask-for-approval never
    exec
    --json
    --cd "$PLUGIN_ROOT"
    --sandbox read-only
    --ephemeral
    --skip-git-repo-check
  )

  if [[ -n "$LIVE_MODEL" ]]; then
    cmd+=(--model "$LIVE_MODEL")
  fi

  CODEX_HOME="$CODEX_HOME_DIR" "${cmd[@]}" "$prompt" >"$out_file" 2>"$err_file"

  "$PYTHON_BIN" - "$out_file" "$err_file" <<'PY'
import json
import re
import sys
from collections import defaultdict

path = sys.argv[1]
err_path = sys.argv[2]
expected_angles = ["Reuse", "Simplification", "Efficiency", "Altitude"]
required_payload_markers = [
    "Scope: current diff",
    "Do not edit files",
    "Do not create artifacts",
    "Do not apply cleanup fixes",
    "Do not run Phase 2",
    "Expected output: findings with file, line, summary, concrete cost",
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
if "spawn failed" in err_text.lower() or "agent thread limit reached" in err_text.lower():
    raise SystemExit(f"Codex simplify cleanup smoke saw spawn failure in stderr: {err_text[:2000]!r}")

successful_spawns = []
failed_spawns = []
spawns_by_angle = defaultdict(list)
wait_or_close_indexes = []
receiver_to_angle = {}
wait_index_by_receiver = {}
close_index_by_receiver = {}
marker = False

with open(path, "r", encoding="utf-8") as fh:
    for index, line in enumerate(fh, 1):
        if not line.strip():
            continue
        data = json.loads(line)
        item = data.get("item") or {}
        if "OH_NO_CODEX_SIMPLIFY_SUBAGENTS_OK" in collect_text(data):
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
                    wait_index_by_receiver.setdefault(receiver, index)
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
if missing_wait_results:
    raise SystemExit(f"Codex simplify cleanup smoke did not capture wait_agent results for receivers: {missing_wait_results!r}")
if missing_closes:
    raise SystemExit(f"Codex simplify cleanup smoke did not close spawned receivers: {missing_closes!r}")
early_closes = {
    receiver: (wait_index_by_receiver[receiver], close_index_by_receiver[receiver])
    for receiver in receiver_ids
    if close_index_by_receiver[receiver] <= wait_index_by_receiver[receiver]
}
if early_closes:
    raise SystemExit(
        "Codex simplify cleanup smoke closed agents before their wait_agent results were captured: "
        f"{early_closes!r}"
    )
if not wait_or_close_indexes:
    raise SystemExit("Codex simplify cleanup smoke did not wait for or close spawned cleanup subagents")
first_wait_or_close = min(wait_or_close_indexes)
last_spawn = max(index for index, _, _, _ in successful_spawns)
if first_wait_or_close < last_spawn:
    raise SystemExit(
        "Codex simplify cleanup subagents were not launched as one batch before waiting; "
        f"first_wait_or_close={first_wait_or_close} last_spawn={last_spawn}"
    )
for angle, payloads in spawns_by_angle.items():
    _, payload = payloads[0]
    missing_markers = [
        marker for marker in [f"Angle: {angle}", f"Marker: {angle_markers[angle]}", *required_payload_markers]
        if marker.lower() not in payload.lower()
    ]
    if missing_markers:
        raise SystemExit(
            f"Codex simplify spawn_agent payload for {angle} missed required prompt markers: "
            f"{missing_markers}; payload={payload[:2000]!r}"
        )
if not marker:
    raise SystemExit("Codex simplify cleanup smoke did not return success marker")

print("ok - live Codex simplify cleanup subagents spawned in one batch")
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

  CODEX_HOME="$CODEX_HOME_DIR" "${cmd[@]}" "$prompt" >"$log_file" 2>&1

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

  log "Testing ${PLUGIN_ID} for Codex from ${PLUGIN_ROOT}"
  validate_codex_manifest
  validate_codex_hooks
  validate_codex_agent_installer
  install_via_codex_plugins
  assert_codex_prompt_exposes_skills
  run_live_tests
  run_deep_live_tests
  run_ralplan_live_test
  run_parallel_live_test
  run_simplify_live_test
  run_worktree_live_test
  log "All requested Codex checks passed"
}

main "$@"
