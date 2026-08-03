#!/usr/bin/env python3
"""Offline synthetic contracts for claude-dispatch-live-oracle.py."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


ORACLE = Path(sys.argv[1])
DRIVER = ORACLE.with_name("test-claude-plugin.sh")
PYTHON = sys.executable


def write_rows(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(json.dumps(row) for row in rows) + "\n", encoding="utf-8")


def fixture(root: Path, roles: list[str], skill: str = "ralph") -> list[str]:
    root.mkdir(parents=True)
    nonces = {role: f"CHILD-{index}" for index, role in enumerate(roles, 1)}
    prompt = root / "prompt.txt"
    result = root / "result.txt"
    events = root / "events.jsonl"
    prompt.write_text(f"/oh-no-harness:{skill} fixture", encoding="utf-8")
    result.write_text("PARENT-NONCE\n" + "\n".join(nonces.values()), encoding="utf-8")
    rows: list[dict[str, object]] = []
    for index, role in enumerate(roles, 1):
        tool_id = f"tool-{index}"
        rows.append({
            "type": "assistant",
            "message": {"content": [{
                "type": "tool_use",
                "name": "Agent",
                "id": tool_id,
                "input": {"subagent_type": f"oh-no-harness:{role}", "prompt": f"Return {nonces[role]}"},
            }]},
        })
        rows.append({
            "type": "user",
            "message": {"content": [{
                "type": "tool_result",
                "tool_use_id": tool_id,
                "is_error": False,
                "content": f"completed {nonces[role]}",
            }]},
        })
    rows.append({"type": "result", "is_error": False, "result": result.read_text(encoding="utf-8")})
    write_rows(events, rows)
    return [
        PYTHON, str(ORACLE), "verify",
        "--events", str(events),
        "--result", str(result),
        "--prompt", str(prompt),
        "--skill", skill,
        "--plugin", "oh-no-harness",
        "--roles", ",".join(roles),
        "--child-nonces", json.dumps(nonces),
        "--parent-nonce", "PARENT-NONCE",
    ]


def async_fixture(root: Path, roles: list[str], skill: str = "ralph") -> list[str]:
    command = fixture(root, roles, skill)
    nonces = {role: f"CHILD-{index}" for index, role in enumerate(roles, 1)}
    rows: list[dict[str, object]] = []
    for index, role in enumerate(roles, 1):
        tool_id = f"tool-{index}"
        rows.append({
            "type": "assistant",
            "message": {"content": [{
                "type": "tool_use",
                "name": "Agent",
                "id": tool_id,
                "input": {"subagent_type": f"oh-no-harness:{role}", "prompt": f"Return {nonces[role]}"},
            }]},
        })
        rows.append({
            "type": "user",
            "message": {"content": [{
                "type": "tool_result",
                "tool_use_id": tool_id,
                "is_error": False,
                "content": "Async agent launched successfully",
            }]},
            "tool_use_result": {
                "isAsync": True,
                "status": "async_launched",
                "agentId": f"agent-{index}",
                "outputFile": f"/tmp/agent-{index}.jsonl",
            },
        })
        if index == 1:
            rows.append({"type": "result", "is_error": False, "result": "waiting for child"})
        rows.append({
            "type": "system",
            "subtype": "task_notification",
            "tool_use_id": tool_id,
            "status": "completed",
            "summary": f"completed {nonces[role]}",
        })
    final_result = (root / "result.txt").read_text(encoding="utf-8")
    rows.append({"type": "result", "is_error": False, "origin": {"kind": "task-notification"}, "result": final_result})
    write_rows(root / "events.jsonl", rows)
    return command


def rows_for(root: Path) -> list[dict[str, object]]:
    return [json.loads(line) for line in (root / "events.jsonl").read_text(encoding="utf-8").splitlines()]


def run(command: list[str], expected: int = 0, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, text=True, capture_output=True, check=False, env=env)
    if result.returncode != expected:
        raise SystemExit(
            f"fixture expected rc={expected}, got {result.returncode}\nstdout={result.stdout}\nstderr={result.stderr}"
        )
    return result


with tempfile.TemporaryDirectory(prefix="claude-dispatch-oracle-") as raw_temp:
    root = Path(raw_temp)

    run(fixture(root / "valid-one", ["explore"], "interview"))
    run(fixture(root / "valid-two", ["executor", "code-reviewer"]))
    run(fixture(root / "valid-zero", [], "auto-routing"))

    read_before_agent = root / "read-before-agent"
    read_before_agent_command = fixture(read_before_agent, ["explore"], "interview")
    read_before_agent_rows = rows_for(read_before_agent)
    read_before_agent_rows[:0] = [
        {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Read", "id": "read-before-agent", "input": {"file_path": "FACTS.md"}}]}},
        {"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": "read-before-agent", "is_error": False, "content": "facts"}]}},
    ]
    write_rows(read_before_agent / "events.jsonl", read_before_agent_rows)
    run(read_before_agent_command)

    read_zero_agent = root / "read-zero-agent"
    read_zero_agent_command = fixture(read_zero_agent, [], "auto-routing")
    read_zero_agent_rows = rows_for(read_zero_agent)
    read_zero_agent_rows[:0] = [
        {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Read", "id": "read-zero-agent", "input": {"file_path": "status.txt"}}]}},
        {"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": "read-zero-agent", "is_error": False, "content": "ready"}]}},
    ]
    write_rows(read_zero_agent / "events.jsonl", read_zero_agent_rows)
    run(read_zero_agent_command)

    async_valid = root / "async-valid"
    async_valid_command = async_fixture(async_valid, ["explore"], "interview")
    run(async_valid_command)
    extracted = async_valid / "extracted-result.txt"
    run([PYTHON, str(ORACLE), "extract-result", str(async_valid / "events.jsonl"), str(extracted)])
    if extracted.read_text(encoding="utf-8") != (async_valid / "result.txt").read_text(encoding="utf-8"):
        raise SystemExit("async fixture did not extract the final successful result")

    async_missing = root / "async-missing-notification"
    async_missing_command = async_fixture(async_missing, ["explore"], "interview")
    async_missing_rows = [row for row in rows_for(async_missing) if row.get("subtype") != "task_notification"]
    write_rows(async_missing / "events.jsonl", async_missing_rows)
    run(async_missing_command, 1)

    async_wrong = root / "async-wrong-notification"
    async_wrong_command = async_fixture(async_wrong, ["explore"], "interview")
    async_wrong_rows = rows_for(async_wrong)
    next(row for row in async_wrong_rows if row.get("subtype") == "task_notification")["tool_use_id"] = "wrong-tool"
    write_rows(async_wrong / "events.jsonl", async_wrong_rows)
    run(async_wrong_command, 1)

    async_errored = root / "async-errored-notification"
    async_errored_command = async_fixture(async_errored, ["explore"], "interview")
    async_errored_rows = rows_for(async_errored)
    next(row for row in async_errored_rows if row.get("subtype") == "task_notification")["status"] = "failed"
    write_rows(async_errored / "events.jsonl", async_errored_rows)
    run(async_errored_command, 1)

    async_nonce = root / "async-missing-nonce"
    async_nonce_command = async_fixture(async_nonce, ["explore"], "interview")
    async_nonce_rows = rows_for(async_nonce)
    next(row for row in async_nonce_rows if row.get("subtype") == "task_notification")["summary"] = "completed without receipt"
    write_rows(async_nonce / "events.jsonl", async_nonce_rows)
    run(async_nonce_command, 1)

    async_early = root / "async-reviewer-early"
    async_early_command = async_fixture(async_early, ["executor", "code-reviewer"])
    async_early_rows = rows_for(async_early)
    reviewer_use = async_early_rows.pop(4)
    async_early_rows.insert(3, reviewer_use)
    write_rows(async_early / "events.jsonl", async_early_rows)
    run(async_early_command, 1)

    shell_contract = r'''
driver="$1"
set --
source "$driver"
for spec in \
  'interview|explore' \
  'ralplan|planner,plan-reviewer' \
  'ralph|executor,code-reviewer' \
  'verification-before-completion|verifier' \
  'systematic-debugging|debugger' \
  'auto-routing|' \
  'simplify|'; do
  skill="${spec%%|*}"; expected="${spec#*|}"
  IFS='|' read -r roles allow require <<<"$(dispatch_scenario_contract "$skill")"
  [[ "$roles" == "$expected" ]]
  prompt="$(claude_dispatch_prompt "$skill" PARENT-fixture '{}')"
  [[ "$prompt" == "/oh-no-harness:$skill"* ]]
done
IFS='|' read -r roles allow require <<<"$(dispatch_scenario_contract ralph)"
[[ "$allow" == 'dispatch-fixture/src/formatter.py,dispatch-fixture/tests/test_formatter.py,dispatch-fixture/.oh-no/sessions/task-56-dispatch-ralph/progress.md,dispatch-fixture/.oh-no/sessions/task-56-dispatch-ralph/verification.md' ]]
[[ "$require" == 'dispatch-fixture/src/formatter.py,dispatch-fixture/tests/test_formatter.py' ]]
scenario_source="$(declare -f run_claude_dispatch_live_scenario)"
[[ "$scenario_source" == *'escape_net_verdict "$escape_before" "$escape_after" __claude_dispatch_no_owned_worktree__'*'secret-scan "$prompt_file" "$events_file" "$evidence/stderr.txt"'*'cp "$prompt_file" "$events_file" "$evidence/stderr.txt" "$export_dir/"'*'mutation --skill "$skill"'*'extract-result "$events_file" "$result_file"'*'cp "$result_file" "$export_dir/"'* ]]
'''
    run(["bash", "-c", shell_contract, "fixture", str(DRIVER)])

    wrong = root / "wrong"
    wrong_command = fixture(wrong, ["explore"], "interview")
    wrong_rows = rows_for(wrong)
    wrong_rows[0]["message"]["content"][0]["input"]["subagent_type"] = "oh-no-harness:debugger"  # type: ignore[index]
    write_rows(wrong / "events.jsonl", wrong_rows)
    run(wrong_command, 75)

    missing = root / "missing"
    missing_command = fixture(missing, ["explore"], "interview")
    write_rows(missing / "events.jsonl", rows_for(missing)[2:])
    run(missing_command, 75)

    duplicate = root / "duplicate"
    duplicate_command = fixture(duplicate, ["explore"], "interview")
    duplicate_rows = rows_for(duplicate)
    duplicate_rows[2:2] = [duplicate_rows[1]]
    write_rows(duplicate / "events.jsonl", duplicate_rows)
    run(duplicate_command, 1)

    extra = root / "extra"
    extra_command = fixture(extra, ["explore"], "interview")
    extra_rows = rows_for(extra)
    extra_rows[2:2] = [
        {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Agent", "id": "tool-extra", "input": {"subagent_type": "oh-no-harness:debugger"}}]}},
        {"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": "tool-extra", "is_error": False, "content": "extra"}]}},
    ]
    write_rows(extra / "events.jsonl", extra_rows)
    run(extra_command, 1)

    no_result = root / "no-result"
    no_result_command = fixture(no_result, ["explore"], "interview")
    write_rows(no_result / "events.jsonl", [rows_for(no_result)[0], rows_for(no_result)[-1]])
    run(no_result_command, 1)

    errored = root / "errored"
    errored_command = fixture(errored, ["explore"], "interview")
    errored_rows = rows_for(errored)
    errored_rows[1]["message"]["content"][0]["is_error"] = True  # type: ignore[index]
    write_rows(errored / "events.jsonl", errored_rows)
    run(errored_command, 1)

    nonce_omission = root / "nonce-omission"
    nonce_command = fixture(nonce_omission, ["explore"], "interview")
    nonce_rows = rows_for(nonce_omission)
    nonce_rows[1]["message"]["content"][0]["content"] = "completed without receipt"  # type: ignore[index]
    write_rows(nonce_omission / "events.jsonl", nonce_rows)
    run(nonce_command, 1)

    parent_omission = root / "parent-omission"
    parent_command = fixture(parent_omission, ["explore"], "interview")
    (parent_omission / "result.txt").write_text("PARENT-NONCE\n", encoding="utf-8")
    run(parent_command, 1)

    early = root / "early"
    early_command = fixture(early, ["executor", "code-reviewer"])
    early_rows = rows_for(early)
    early_rows[1:3] = [early_rows[2], early_rows[1]]
    write_rows(early / "events.jsonl", early_rows)
    run(early_command, 1)

    zero_child = root / "zero-child"
    zero_command = fixture(zero_child, [], "simplify")
    zero_rows = rows_for(zero_child)
    zero_rows[:0] = [
        {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Agent", "id": "tool-zero", "input": {"subagent_type": "oh-no-harness:explore"}}]}},
        {"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": "tool-zero", "is_error": False, "content": "unexpected"}]}},
    ]
    write_rows(zero_child / "events.jsonl", zero_rows)
    run(zero_command, 1)

    mutation_root = root / "mutation"
    mutation_root.mkdir()
    (mutation_root / "allowed.txt").write_text("before", encoding="utf-8")
    before = root / "before.json"
    after = root / "after.json"
    run([PYTHON, str(ORACLE), "snapshot", str(mutation_root), str(before)])
    (mutation_root / "allowed.txt").write_text("after", encoding="utf-8")
    run([PYTHON, str(ORACLE), "snapshot", str(mutation_root), str(after)])
    run([PYTHON, str(ORACLE), "mutation", "--skill", "fixture", "--before", str(before), "--after", str(after), "--allow", "allowed.txt", "--require", "allowed.txt"])
    run([PYTHON, str(ORACLE), "mutation", "--skill", "fixture", "--before", str(before), "--after", str(after), "--allow", ""], 1)
    run([PYTHON, str(ORACLE), "mutation", "--skill", "fixture", "--before", str(before), "--after", str(before), "--allow", "allowed.txt", "--require", "allowed.txt"], 1)

    environment = os.environ.copy()
    environment["OH_NO_PLUGIN_ROOT"] = str(mutation_root)
    unset_result = run([PYTHON, str(ORACLE), "environment-unsets", "--repo-root", str(mutation_root)], env=environment)
    if unset_result.stdout.strip() != "OH_NO_PLUGIN_ROOT":
        raise SystemExit(f"environment unset fixture returned {unset_result.stdout!r}")
    environment.pop("OH_NO_PLUGIN_ROOT")
    run([PYTHON, str(ORACLE), "environment-check", "--repo-root", str(mutation_root)], env=environment)
    environment["SAFE_LOOKING_LEAK"] = str(mutation_root / "child")
    leak = run([PYTHON, str(ORACLE), "environment-check", "--repo-root", str(mutation_root)], 1, environment)
    if "SAFE_LOOKING_LEAK" not in leak.stderr or str(mutation_root.resolve()) in leak.stderr:
        raise SystemExit("environment containment diagnostic leaked a path or omitted the variable name")

    failed_check_root = root / "failed-environment-check"
    failed_check_root.mkdir()
    fake_python = failed_check_root / "fake-python"
    fake_python.write_text(
        "#!/bin/sh\n"
        "case \"$2\" in\n"
        "  environment-unsets) exit 0 ;;\n"
        "  environment-check) exit 42 ;;\n"
        "  *) exit 99 ;;\n"
        "esac\n",
        encoding="utf-8",
    )
    fake_python.chmod(0o755)
    launch_marker = failed_check_root / "live-command-launched"
    fake_live = failed_check_root / "fake-live-command"
    fake_live.write_text(f"#!/bin/sh\nprintf 'launched\\n' >{launch_marker!s}\n", encoding="utf-8")
    fake_live.chmod(0o755)
    fail_closed_contract = r'''
set -uo pipefail
driver="$1"; fake_python="$2"; launch_dir="$3"; fake_live="$4"; marker="$5"
set --
source "$driver"
PYTHON_BIN="$fake_python"
run_plugin_dir_live_process_with_timeout() { "$@"; }
rc=0
run_sanitized_claude_dispatch_command "$launch_dir" "$fake_live" || rc=$?
[[ "$rc" == 42 && ! -e "$marker" ]]
'''
    run(["bash", "-c", fail_closed_contract, "fixture", str(DRIVER), str(fake_python), str(failed_check_root), str(fake_live), str(launch_marker)])

    cache_root = root / "cache-suppression"
    cache_root.mkdir()
    cache_python = cache_root / "fake-python"
    cache_python.write_text(
        "#!/bin/sh\n"
        "case \"$2\" in\n"
        "  environment-unsets|environment-check) exit 0 ;;\n"
        "  *) exit 99 ;;\n"
        "esac\n",
        encoding="utf-8",
    )
    cache_python.chmod(0o755)
    cache_live = cache_root / "fake-live-command"
    cache_live.write_text(
        "#!/bin/sh\n"
        "printf '%s\\n%s\\n' \"${PYTHONDONTWRITEBYTECODE-}\" \"${PYTEST_ADDOPTS-}\" >\"$CACHE_ENV_LOG\"\n",
        encoding="utf-8",
    )
    cache_live.chmod(0o755)
    cache_log = cache_root / "cache-environment.txt"
    cache_contract = r'''
set -uo pipefail
driver="$1"; fake_python="$2"; launch_dir="$3"; fake_live="$4"; cache_log="$5"
set --
source "$driver"
PYTHON_BIN="$fake_python"
export CACHE_ENV_LOG="$cache_log" PYTEST_ADDOPTS='-q'
run_plugin_dir_live_process_with_timeout() { "$@"; }
run_sanitized_claude_dispatch_command "$launch_dir" "$fake_live"
{ IFS= read -r bytecode; IFS= read -r pytest_opts; } <"$cache_log"
[[ "$bytecode" == 1 && "$pytest_opts" == *'-p no:cacheprovider'* ]]
'''
    run(["bash", "-c", cache_contract, "fixture", str(DRIVER), str(cache_python), str(cache_root), str(cache_live), str(cache_log)])

    safe_evidence = root / "safe-evidence.txt"
    safe_evidence.write_text("prompt and nonce only", encoding="utf-8")
    run([PYTHON, str(ORACLE), "secret-scan", str(safe_evidence)])
    unsafe_evidence = root / "unsafe-evidence.txt"
    unsafe_evidence.write_text("Authorization: Bearer fixture-secret-value", encoding="utf-8")
    run([PYTHON, str(ORACLE), "secret-scan", str(unsafe_evidence)], 1)

print("ok - Claude dispatch oracle synthetic fixtures passed")
