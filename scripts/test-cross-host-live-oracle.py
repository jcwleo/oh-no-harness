#!/usr/bin/env python3
"""Offline synthetic contracts for cross-host-live-oracle.py."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable


ORACLE = Path(sys.argv[1])
DRIVER = ORACLE.with_name("test-codex-plugin.sh")
PYTHON = sys.executable
PARENT = "11111111-1111-4111-8111-111111111111"
PARENT_NONCE = "PARENT-fixture-nonce"
RECEIVER_NONCE = "RECEIVER-fixture-nonce"
COMMAND = "python3 dispatch-fixture/invoke-claude.py"


def write_rows(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(json.dumps(row) for row in rows) + "\n", encoding="utf-8")


def nested_rows(*, nonce: str = RECEIVER_NONCE, success: bool = True, read_path: str = "dispatch-fixture/receiver-input.txt", correlate: bool = True, substantive: bool = True) -> list[dict[str, Any]]:
    final = (
        f"Receiver: claude-code\n{nonce}\nretry_non_idempotent_payment_capture=true\n"
        "Automatic retry of non-idempotent payment capture violates the must-never-retry acceptance rule."
        if substantive
        else f"Receiver: claude-code\n{nonce}\nretry_non_idempotent_payment_capture=true"
    )
    return [
        {"type": "assistant", "message": {"content": [{"type": "tool_use", "id": "read-1", "name": "Read", "input": {"file_path": read_path}}]}},
        {"type": "user", "message": {"content": [{"type": "tool_result", "tool_use_id": "read-1" if correlate else "wrong-read", "content": f"receiver_nonce={nonce}\nacceptance=non-idempotent payment capture must never be automatically retried\nretry_non_idempotent_payment_capture=true", "is_error": False}]}},
        {"type": "result", "subtype": "success" if success else "error_during_execution", "is_error": not success, "result": final},
    ]


def nested_output(**kwargs: Any) -> str:
    return "\n".join(json.dumps(row) for row in nested_rows(**kwargs)) + "\n"


def base_fixture(root: Path, shape: str = "command") -> list[str]:
    evidence = root / "evidence"
    sessions = root / "sessions"
    protected = root / "protected"
    workspace = root / "workspace"
    evidence.mkdir(parents=True)
    (sessions / "new").mkdir(parents=True)
    protected.mkdir()
    workspace.mkdir()
    (protected / "sentinel").write_text("unchanged", encoding="utf-8")
    prompt = evidence / "prompt.txt"
    prompt.write_text(f"Direct transport smoke. Parent nonce: {PARENT_NONCE}. Execute the exact launcher once.\n", encoding="utf-8")
    result = evidence / "result.txt"
    result.write_text(f"{PARENT_NONCE}\n{RECEIVER_NONCE}\n", encoding="utf-8")
    output = nested_output()
    events: list[dict[str, Any]] = [
        {"type": "thread.started", "thread_id": PARENT},
        {"type": "turn.started"},
    ]
    session_rows: list[dict[str, Any]] = [
        {"type": "session_meta", "payload": {"id": PARENT, "session_id": PARENT}},
        {"type": "response_item", "payload": {"type": "agent_message", "content": [{"type": "input_text", "text": "Inert instructions mention spawn_agent, collab_tool_call, parent_thread_id, agent_role, and agent_path but do not invoke them."}]}},
    ]
    if shape in {"command", "shell-wrapper"}:
        recorded_command = COMMAND if shape == "command" else "/bin/zsh -c 'python3 dispatch-fixture/invoke-claude.py'"
        events.extend([
            {"type": "item.started", "item": {"id": "command-1", "type": "command_execution", "command": recorded_command, "status": "in_progress"}},
            {"type": "item.completed", "item": {"id": "command-1", "type": "command_execution", "command": recorded_command, "status": "completed", "exit_code": 0, "aggregated_output": output}},
        ])
    elif shape == "function":
        session_rows.extend([
            {"type": "response_item", "payload": {"type": "function_call", "name": "exec_command", "call_id": "call-1", "arguments": json.dumps({"cmd": COMMAND})}},
            {"type": "response_item", "payload": {"type": "function_call_output", "call_id": "call-1", "output": "Process exited with code 0\nOutput:\n" + output}},
        ])
    elif shape == "custom":
        script = 'const r = await tools.exec_command({"cmd":"python3 dispatch-fixture/invoke-claude.py"});\ntext(r.output);\n'
        session_rows.extend([
            {"type": "response_item", "payload": {"type": "custom_tool_call", "name": "exec", "call_id": "call-1", "input": script}},
            {"type": "response_item", "payload": {"type": "custom_tool_call_output", "call_id": "call-1", "output": "Script completed\nOutput:\n" + output}},
        ])
    elif shape in {"async", "async-list"}:
        events.extend([
            {"type": "item.started", "item": {"id": "command-1", "type": "command_execution", "command": COMMAND, "status": "in_progress"}},
            {"type": "item.completed", "item": {"id": "command-1", "type": "command_execution", "command": COMMAND, "status": "completed", "exit_code": 0, "aggregated_output": "Script running with cell ID cell-7\nOutput:\n"}},
        ])
        wait_output: Any = json.dumps({"exit_code": 0, "output": output})
        if shape == "async-list":
            wait_output = [
                {"type": "input_text", "text": "Script completed\nOutput:\n"},
                {"type": "input_text", "text": json.dumps({"exit_code": 0, "output": output})},
            ]
        session_rows.extend([
            {"type": "response_item", "payload": {"type": "function_call", "name": "wait", "call_id": "wait-1", "arguments": json.dumps({"cell_id": "cell-7"})}},
            {"type": "response_item", "payload": {"type": "function_call_output", "call_id": "wait-1", "output": wait_output}},
        ])
    else:
        raise ValueError(shape)
    events.append({"type": "turn.completed", "usage": {}})
    event_path = evidence / "events.jsonl"
    write_rows(event_path, events)
    session_path = sessions / "new" / "rollout.jsonl"
    write_rows(session_path, session_rows)
    manifest = evidence / "new-sessions.json"
    manifest.write_text(json.dumps(["new/rollout.jsonl"]), encoding="utf-8")
    before = evidence / "before.json"
    after = evidence / "after.json"
    snapshot = [PYTHON, str(ORACLE), "snapshot", "--output", str(before), "--root", f"protected={protected}"]
    run(snapshot)
    after.write_bytes(before.read_bytes())
    return [
        PYTHON, str(ORACLE), "verify",
        "--events", str(event_path),
        "--result", str(result),
        "--sessions", str(sessions),
        "--session-manifest", str(manifest),
        "--parent-nonce", PARENT_NONCE,
        "--receiver-nonce", RECEIVER_NONCE,
        "--workspace", str(root / "workspace"),
        "--before", str(before),
        "--after", str(after),
    ]


def rows(path: Path) -> list[dict[str, Any]]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]


def run(command: list[str], expected: int = 0, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, text=True, capture_output=True, check=False, env=env)
    if result.returncode != expected:
        raise SystemExit(
            f"fixture expected rc={expected}, got {result.returncode}\nstdout={result.stdout}\nstderr={result.stderr}"
        )
    return result


def failure_case(root: Path, label: str, mutate: Callable[[Path], None], expected: int = 1) -> None:
    case_root = root / label
    command = base_fixture(case_root)
    mutate(case_root)
    run(command, expected)


with tempfile.TemporaryDirectory(prefix="cross-host-oracle-") as temp:
    root = Path(temp)
    for shape in ("command", "shell-wrapper", "function", "custom", "async", "async-list"):
        run(base_fixture(root / f"valid-{shape}", shape))

    compound_root = root / "compound-shell-wrapper"
    compound_command = base_fixture(compound_root, "shell-wrapper")
    compound_events = compound_root / "evidence/events.jsonl"
    compound_rows = rows(compound_events)
    for row in compound_rows:
        item = row.get("item", {})
        if item.get("type") == "command_execution":
            item["command"] = "/bin/zsh -c 'python3 dispatch-fixture/invoke-claude.py; other'"
    write_rows(compound_events, compound_rows)
    run(compound_command, 75)

    def missing_async_wait(case: Path) -> None:
        path = case / "sessions/new/rollout.jsonl"
        value = [row for row in rows(path) if row.get("payload", {}).get("name") != "wait" and row.get("payload", {}).get("call_id") != "wait-1"]
        write_rows(path, value)

    async_missing = root / "async-missing-wait"
    async_missing_command = base_fixture(async_missing, "async")
    missing_async_wait(async_missing)
    run(async_missing_command, 1)

    def wrong_async_wait(case: Path) -> None:
        path = case / "sessions/new/rollout.jsonl"
        value = rows(path)
        request = next(row["payload"] for row in value if row.get("payload", {}).get("name") == "wait")
        request["arguments"] = json.dumps({"cell_id": "wrong-cell"})
        write_rows(path, value)

    async_wrong = root / "async-wrong-wait"
    async_wrong_command = base_fixture(async_wrong, "async")
    wrong_async_wait(async_wrong)
    run(async_wrong_command, 1)

    def duplicate_async_wait(case: Path) -> None:
        path = case / "sessions/new/rollout.jsonl"
        value = rows(path)
        value.extend([
            {"type": "response_item", "payload": {"type": "function_call", "name": "wait", "call_id": "wait-2", "arguments": json.dumps({"cell_id": "cell-7"})}},
            {"type": "response_item", "payload": {"type": "function_call_output", "call_id": "wait-2", "output": json.dumps({"exit_code": 0, "output": nested_output()})}},
        ])
        write_rows(path, value)

    async_duplicate = root / "async-duplicate-wait"
    async_duplicate_command = base_fixture(async_duplicate, "async")
    duplicate_async_wait(async_duplicate)
    run(async_duplicate_command, 1)

    def duplicate(case: Path) -> None:
        path = case / "evidence/events.jsonl"
        value = rows(path)
        value.insert(-1, {"type": "item.completed", "item": {"id": "command-2", "type": "command_execution", "command": COMMAND, "status": "completed", "exit_code": 0, "aggregated_output": nested_output()}})
        write_rows(path, value)

    failure_case(root, "duplicate-launcher", duplicate, 75)

    def wrong(case: Path) -> None:
        path = case / "evidence/events.jsonl"
        value = rows(path)
        for row in value:
            item = row.get("item", {})
            if item.get("type") == "command_execution":
                item["command"] = "python3 dispatch-fixture/wrong.py"
        write_rows(path, value)

    failure_case(root, "wrong-launcher", wrong, 75)

    def missing_launcher_terminal(case: Path) -> None:
        path = case / "evidence/events.jsonl"
        value = [row for row in rows(path) if not (row.get("type") == "item.completed" and row.get("item", {}).get("type") == "command_execution")]
        write_rows(path, value)

    failure_case(root, "missing-launcher-terminal", missing_launcher_terminal)

    def missing_outer_completion(case: Path) -> None:
        path = case / "evidence/events.jsonl"
        write_rows(path, rows(path)[:-1])

    failure_case(root, "missing-outer-completion", missing_outer_completion)

    def subagent(case: Path) -> None:
        path = case / "evidence/events.jsonl"
        value = rows(path)
        value.insert(-1, {"type": "item.completed", "item": {"type": "collab_tool_call", "tool": "spawn_agent", "status": "completed"}})
        write_rows(path, value)

    failure_case(root, "subagent-event", subagent)

    def malformed_nested(case: Path) -> None:
        path = case / "evidence/events.jsonl"
        value = rows(path)
        value[-2]["item"]["aggregated_output"] = '{"type":"assistant"\n'
        write_rows(path, value)

    failure_case(root, "malformed-nested", malformed_nested)

    def nonzero_nested(case: Path) -> None:
        path = case / "evidence/events.jsonl"
        value = rows(path)
        value[-2]["item"]["aggregated_output"] = nested_output(success=False)
        write_rows(path, value)

    failure_case(root, "nonzero-nested-result", nonzero_nested)

    def wrong_read(case: Path) -> None:
        path = case / "evidence/events.jsonl"
        value = rows(path)
        value[-2]["item"]["aggregated_output"] = nested_output(read_path="receiver-input.txt")
        write_rows(path, value)

    failure_case(root, "wrong-read-path", wrong_read)

    def missing_correlation(case: Path) -> None:
        path = case / "evidence/events.jsonl"
        value = rows(path)
        value[-2]["item"]["aggregated_output"] = nested_output(correlate=False)
        write_rows(path, value)

    failure_case(root, "missing-read-correlation", missing_correlation)

    def nonce_prompt_only(case: Path) -> None:
        path = case / "evidence/events.jsonl"
        value = rows(path)
        stream = nested_rows()
        stream[-1]["result"] = str(stream[-1]["result"]).replace(RECEIVER_NONCE, "receiver-nonce-omitted")
        value[-2]["item"]["aggregated_output"] = "\n".join(json.dumps(row) for row in stream) + "\n"
        write_rows(path, value)
        with (case / "evidence/prompt.txt").open("a", encoding="utf-8") as handle:
            handle.write(RECEIVER_NONCE + "\n")

    failure_case(root, "nonce-only-in-prompt", nonce_prompt_only)

    def marker_only(case: Path) -> None:
        path = case / "evidence/events.jsonl"
        value = rows(path)
        value[-2]["item"]["aggregated_output"] = nested_output(substantive=False)
        write_rows(path, value)

    failure_case(root, "marker-only", marker_only)

    def mutation(case: Path) -> None:
        after = case / "evidence/after.json"
        payload = json.loads(after.read_text(encoding="utf-8"))
        payload["protected"]["sentinel"] = ["file", 420, "changed"]
        after.write_text(json.dumps(payload), encoding="utf-8")

    failure_case(root, "protected-config-mutation", mutation)

    export_root = root / "missing-result-export"
    base_fixture(export_root)
    (export_root / "evidence/result.txt").unlink()
    export_destination = export_root / "export"
    run([
        PYTHON, str(ORACLE), "export-evidence",
        "--events", str(export_root / "evidence/events.jsonl"),
        "--result", str(export_root / "evidence/result.txt"),
        "--prompt", str(export_root / "evidence/prompt.txt"),
        "--sessions", str(export_root / "sessions"),
        "--session-manifest", str(export_root / "evidence/new-sessions.json"),
        "--destination", str(export_destination),
    ])
    if not (export_destination / "events.jsonl").is_file() or not (export_destination / "prompt.txt").is_file() or not (export_destination / "sessions/new/rollout.jsonl").is_file() or (export_destination / "result.txt").exists():
        raise SystemExit("missing-result evidence export did not preserve only available safe artifacts")

    secret_root = root / "secret"
    secret_root.mkdir()
    auth = secret_root / "auth.json"
    artifact = secret_root / "artifact.jsonl"
    secret = "fixture-access-token-000000000001"
    auth.write_text(json.dumps({"access_token": secret}), encoding="utf-8")
    artifact.write_text(json.dumps({"message": secret}) + "\n", encoding="utf-8")
    secret_script = r'''
driver="$1"; auth="$2"; artifact="$3"
set --
source "$driver"
assert_no_codex_live_secret_leak "$auth" "$artifact"
'''
    run(["bash", "-c", secret_script, "fixture", str(DRIVER), str(auth), str(artifact)], 1)

print("ok - cross-host oracle synthetic fixtures passed")
