#!/usr/bin/env python3
"""Deterministic oracle for the Codex parent -> Claude Code transport smoke."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import shutil
import stat
import sys
from pathlib import Path
from typing import Any, NoReturn


LAUNCHER_COMMAND = "python3 dispatch-fixture/invoke-claude.py"
READ_PATH = "dispatch-fixture/receiver-input.txt"


def fail(message: str, code: int = 1) -> NoReturn:
    print(f"HARD FAIL [cross-host-live]: {message}", file=sys.stderr)
    raise SystemExit(code)


def retryable(message: str) -> NoReturn:
    print(f"RETRYABLE [cross-host-live]: {message}", file=sys.stderr)
    raise SystemExit(75)


def collect_text(value: Any) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(child) for child in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(child) for child in value)
    return ""


def json_rows(path: Path, label: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        stripped = line.strip()
        if not stripped:
            continue
        if not stripped.startswith("{"):
            continue
        try:
            row = json.loads(stripped)
        except json.JSONDecodeError as exc:
            fail(f"malformed {label} JSON at {path.name}:{number}: {exc}")
        if not isinstance(row, dict):
            fail(f"non-object {label} JSON at {path.name}:{number}")
        rows.append(row)
    return rows


def message_parts(row: dict[str, Any]) -> list[dict[str, Any]]:
    message = row.get("message")
    if not isinstance(message, dict):
        return []
    content = message.get("content")
    if not isinstance(content, list):
        return []
    return [part for part in content if isinstance(part, dict)]


def decoded_command(raw: Any) -> str:
    if isinstance(raw, dict):
        value = raw.get("cmd") or raw.get("command")
        return value if isinstance(value, str) else ""
    if not isinstance(raw, str):
        return ""
    try:
        value = json.loads(raw)
    except json.JSONDecodeError:
        value = None
    if isinstance(value, dict):
        command = value.get("cmd") or value.get("command")
        return command if isinstance(command, str) else ""
    match = re.fullmatch(
        r'\s*const\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*await\s+(?:tools|functions)[.]exec_command'
        r'\(\{"cmd":"python3 dispatch-fixture/invoke-claude[.]py"\}\);\s*text\(\1[.]output\);\s*',
        raw,
        re.DOTALL,
    )
    return LAUNCHER_COMMAND if match else ""


def retained_output(value: Any) -> tuple[int | None, str]:
    if isinstance(value, dict):
        status = value.get("exit_code")
        if not isinstance(status, int):
            status = value.get("exitCode")
        text = collect_text(value.get("aggregated_output") or value.get("output") or value.get("content"))
        return (status if isinstance(status, int) else None, text)
    text = collect_text(value)
    completed = re.search(r"(?m)^\s*Script completed\s*$", text)
    failed = re.search(r"(?m)^\s*Script failed\s*$", text)
    legacy = re.search(r"(?m)^\s*Process exited with code\s+(\d+)\s*$", text)
    body = re.search(r"(?ms)^Output:\s*\n(.*)\Z", text)
    if completed and not failed and not legacy:
        return 0, body.group(1) if body else ""
    if legacy and not completed and not failed:
        return int(legacy.group(1)), body.group(1) if body else ""
    return None, ""


def normalized_command_execution(command: str) -> str:
    if command == LAUNCHER_COMMAND:
        return command
    try:
        argv = shlex.split(command)
    except ValueError:
        return command
    if (
        len(argv) == 3
        and Path(argv[0]).name in {"zsh", "bash", "sh"}
        and argv[1] == "-c"
        and argv[2] == LAUNCHER_COMMAND
    ):
        return LAUNCHER_COMMAND
    return command


def execution_records(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    records: dict[str, dict[str, Any]] = {}
    pending: dict[str, dict[str, Any]] = {}
    for index, row in enumerate(rows):
        item_value = row.get("item")
        item = item_value if isinstance(item_value, dict) else {}
        if item.get("type") == "command_execution":
            identity = str(item.get("id") or f"command:{index}")
            record = records.setdefault(identity, {"id": identity, "index": index, "command": "", "outputs": []})
            command = item.get("command")
            if isinstance(command, str) and command:
                record["command"] = normalized_command_execution(command)
            if row.get("type") == "item.completed" or item.get("status") in {"completed", "failed"}:
                record["outputs"].append((index, item))

        payload_value = row.get("payload")
        payload = payload_value if isinstance(payload_value, dict) else {}
        payload_type = payload.get("type")
        if payload_type in {"function_call", "custom_tool_call"}:
            name = str(payload.get("name") or "")
            if name in {"exec", "functions.exec", "exec_command", "functions.exec_command"}:
                call_id = str(payload.get("call_id") or "")
                if call_id:
                    pending[call_id] = {
                        "id": call_id,
                        "index": index,
                        "command": decoded_command(payload.get("arguments") if "arguments" in payload else payload.get("input")),
                        "outputs": [],
                    }
        elif payload_type in {"function_call_output", "custom_tool_call_output"}:
            call_id = str(payload.get("call_id") or "")
            if call_id in pending:
                pending[call_id]["outputs"].append((index, payload.get("output")))
    records.update(pending)
    return list(records.values())


def async_wait_terminal(value: Any) -> tuple[int | None, str]:
    candidates: list[Any] = []
    if isinstance(value, str):
        try:
            candidates.append(json.loads(value))
        except json.JSONDecodeError:
            pass
    elif isinstance(value, list):
        for part in value:
            text = part.get("text") if isinstance(part, dict) and part.get("type") == "input_text" else None
            if isinstance(text, str):
                try:
                    candidates.append(json.loads(text))
                except json.JSONDecodeError:
                    pass
    elif isinstance(value, dict):
        candidates.append(value)
    terminals = [candidate for candidate in candidates if isinstance(candidate, dict) and isinstance(candidate.get("exit_code"), int) and isinstance(candidate.get("output"), str)]
    if len(terminals) == 1:
        return int(terminals[0]["exit_code"]), str(terminals[0]["output"])
    return retained_output(value)


def terminal_launcher_output(record: dict[str, Any], rows: list[dict[str, Any]]) -> str:
    outputs = record["outputs"]
    if len(outputs) != 1:
        fail(f"launcher execution had {len(outputs)} terminal/yield outputs, expected one")
    output_index, raw_output = outputs[0]
    output_text = collect_text(raw_output)
    cells = re.findall(r"(?i)Script running with cell ID\s+([A-Za-z0-9_-]+)", output_text)
    if not cells:
        status, text = retained_output(raw_output)
        if status != 0 or not text.strip():
            fail("launcher execution lacked one successful direct terminal output")
        return text
    if len(cells) != 1:
        fail("launcher execution yielded multiple async cell handles")
    cell = cells[0]

    requests: list[tuple[int, str, str]] = []
    results: dict[str, list[tuple[int, Any]]] = {}
    for index, row in enumerate(rows):
        payload_value = row.get("payload")
        payload = payload_value if isinstance(payload_value, dict) else {}
        payload_type = payload.get("type")
        if payload_type in {"function_call", "custom_tool_call"} and payload.get("name") == "wait":
            call_id = str(payload.get("call_id") or "")
            raw = payload.get("arguments") if "arguments" in payload else payload.get("input")
            try:
                arguments = json.loads(raw) if isinstance(raw, str) else raw
            except json.JSONDecodeError:
                arguments = None
            requested_cell = arguments.get("cell_id") if isinstance(arguments, dict) else None
            if call_id:
                requests.append((index, call_id, str(requested_cell or "")))
        elif payload_type in {"function_call_output", "custom_tool_call_output"}:
            call_id = str(payload.get("call_id") or "")
            if call_id:
                results.setdefault(call_id, []).append((index, payload.get("output")))
    later_requests = [request for request in requests if request[0] > output_index]
    if len(later_requests) != 1:
        fail(f"async launcher had {len(later_requests)} later wait requests, expected one")
    request_index, call_id, requested_cell = later_requests[0]
    if requested_cell != cell:
        fail(f"async launcher wait used wrong cell ID {requested_cell!r}, expected {cell!r}")
    correlated = results.get(call_id, [])
    if len(correlated) != 1:
        fail(f"async launcher wait had {len(correlated)} correlated terminal outputs")
    result_index, raw_result = correlated[0]
    if result_index <= request_index:
        fail("async launcher terminal wait output preceded its request")
    status, text = async_wait_terminal(raw_result)
    if status != 0 or not text.strip():
        fail("async launcher wait lacked a successful terminal output")
    return text


def nested_claude_rows(output: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for number, line in enumerate(output.splitlines(), 1):
        stripped = line.strip()
        if not stripped.startswith("{"):
            continue
        try:
            value = json.loads(stripped)
        except json.JSONDecodeError as exc:
            fail(f"malformed nested Claude stream JSON at launcher output line {number}: {exc}")
        if not isinstance(value, dict):
            fail(f"non-object nested Claude stream JSON at launcher output line {number}")
        rows.append(value)
    if not rows:
        fail("launcher terminal output contained no nested Claude stream")
    return rows


def semantic_finding(text: str) -> bool:
    normalized = " ".join(text.lower().split())
    automatic_retry = re.search(r"automat(?:ic|ically)\s+retr", normalized) is not None
    prohibition = re.search(r"(?:must\s+never|must\s+not|do\s+not|forbidden|not\s+allowed|violat\w*|unsafe)\b", normalized) is not None
    payment = "payment" in normalized and ("capture" in normalized or "non-idempotent" in normalized)
    return automatic_retry and prohibition and payment


def verify_nested(rows: list[dict[str, Any]], receiver_nonce: str, workspace: Path) -> str:
    uses: list[tuple[int, str]] = []
    results: dict[str, list[tuple[int, dict[str, Any]]]] = {}
    for row_index, row in enumerate(rows):
        for part in message_parts(row):
            if part.get("type") == "tool_use" and part.get("name") == "Read":
                tool_id = part.get("id")
                tool_input = part.get("input")
                path = tool_input.get("file_path") if isinstance(tool_input, dict) else None
                if isinstance(tool_id, str) and isinstance(path, str):
                    uses.append((row_index, tool_id))
                    expected = (workspace / READ_PATH).resolve()
                    observed = (workspace / path).resolve() if not Path(path).is_absolute() else Path(path).resolve()
                    if observed != expected:
                        fail(f"nested Claude Read used wrong path {path!r}")
            if part.get("type") == "tool_result":
                tool_id = part.get("tool_use_id")
                if isinstance(tool_id, str):
                    results.setdefault(tool_id, []).append((row_index, part))
    if len(uses) != 1:
        fail(f"nested Claude stream had {len(uses)} Read tool_use events, expected one")
    use_index, tool_id = uses[0]
    correlated = results.get(tool_id, [])
    if len(correlated) != 1:
        fail(f"nested Claude Read had {len(correlated)} correlated tool_result events")
    result_index, result = correlated[0]
    result_text = collect_text(result.get("content"))
    if result_index <= use_index or result.get("is_error") is True or not result_text.strip():
        fail("nested Claude Read tool_result was errored, empty, or out of order")
    for required in (receiver_nonce, "retry_non_idempotent_payment_capture=true"):
        if required not in result_text:
            fail(f"nested Claude Read tool_result omitted fixture value {required!r}")

    final_rows = [(index, row) for index, row in enumerate(rows) if row.get("type") == "result"]
    if len(final_rows) != 1:
        fail(f"nested Claude stream had {len(final_rows)} result events, expected one")
    final_index, final = final_rows[0]
    final_text = str(final.get("result") or "")
    if final_index <= result_index or final.get("subtype") != "success" or final.get("is_error") is not False:
        fail("nested Claude result was non-successful or preceded its Read result")
    for required in ("Receiver: claude-code", receiver_nonce, "retry_non_idempotent_payment_capture=true"):
        if required not in final_text:
            fail(f"nested Claude final omitted {required!r}")
    if not semantic_finding(final_text):
        fail("nested Claude final lacked a substantive automatic-no-retry violation finding")
    return final_text


def session_meta(path: Path) -> dict[str, Any]:
    rows = json_rows(path, "Codex session")
    metas = [row.get("payload") for row in rows if row.get("type") == "session_meta"]
    if len(metas) != 1 or not isinstance(metas[0], dict):
        fail("new Codex session JSONL lacked exactly one session_meta object")
    return metas[0]


def verify(args: argparse.Namespace) -> None:
    event_rows = json_rows(Path(args.events), "outer Codex event")
    if not event_rows or event_rows[-1].get("type") != "turn.completed":
        fail("outer Codex stream lacked terminal turn.completed")
    parent_ids = [str(row.get("thread_id")) for row in event_rows if row.get("type") == "thread.started" and row.get("thread_id")]
    if len(parent_ids) != 1:
        fail(f"outer Codex stream had {len(parent_ids)} parent thread starts, expected one")
    parent_id = parent_ids[0]

    manifest = json.loads(Path(args.session_manifest).read_text(encoding="utf-8"))
    if not isinstance(manifest, list) or len(manifest) != 1 or not isinstance(manifest[0], str):
        fail("cross-host lane did not create exactly one parent session JSONL")
    session_path = Path(args.sessions) / manifest[0]
    meta = session_meta(session_path)
    identity = meta.get("id") or meta.get("session_id")
    if identity != parent_id:
        fail("new parent session identity did not match outer thread")
    source_value = meta.get("source")
    source: dict[str, Any] = source_value if isinstance(source_value, dict) else {}
    subagent_value = source.get("subagent")
    subagent: dict[str, Any] = subagent_value if isinstance(subagent_value, dict) else {}
    spawn_value = subagent.get("thread_spawn")
    if any(meta.get(field) not in (None, "") for field in ("parent_thread_id", "agent_role", "agent_path")) or spawn_value not in (None, ""):
        fail("new Codex session was child-linked instead of a parent")
    session_rows = json_rows(session_path, "Codex parent session")
    all_rows = [*event_rows, *session_rows]
    child_tool_names = {
        "spawn_agent", "functions.spawn_agent", "collab", "functions.collab",
        "collab_tool", "collab_tool_call",
    }
    for row in all_rows:
        item_value = row.get("item")
        item = item_value if isinstance(item_value, dict) else {}
        if item.get("type") == "collab_tool_call":
            fail("outer parent emitted an actual collaboration item")
        payload_value = row.get("payload")
        payload = payload_value if isinstance(payload_value, dict) else {}
        if payload.get("type") in {"function_call", "custom_tool_call"} and payload.get("name") in child_tool_names:
            fail("outer parent emitted an actual child/subagent tool call")

    event_executions = execution_records(event_rows)
    session_executions = execution_records(session_rows)
    if not event_executions:
        for record in session_executions:
            record["index"] += len(event_rows)
            record["outputs"] = [(index + len(event_rows), value) for index, value in record["outputs"]]
    executions = event_executions if event_executions else session_executions
    launcher_records = [record for record in executions if record["command"] == LAUNCHER_COMMAND]
    wrong_records = [record for record in executions if record["command"] != LAUNCHER_COMMAND]
    if len(launcher_records) != 1 or wrong_records:
        retryable(
            f"expected exactly one execution of {LAUNCHER_COMMAND!r}; "
            f"exact={len(launcher_records)} wrong={len(wrong_records)}"
        )
    terminal_output = terminal_launcher_output(launcher_records[0], all_rows)
    verify_nested(nested_claude_rows(terminal_output), args.receiver_nonce, Path(args.workspace))

    result_path = Path(args.result)
    if not result_path.is_file() or result_path.is_symlink():
        fail("successful verification requires a regular outer parent result file")
    parent_final = result_path.read_text(encoding="utf-8", errors="replace")
    for required in (args.parent_nonce, args.receiver_nonce):
        if required not in parent_final:
            fail(f"outer parent final omitted {required!r}")

    before = json.loads(Path(args.before).read_text(encoding="utf-8"))
    after = json.loads(Path(args.after).read_text(encoding="utf-8"))
    if before != after:
        changed = sorted(key for key in set(before) | set(after) if before.get(key) != after.get(key))
        fail(f"protected workspace/config identities changed: {changed!r}")
    print(f"PASS - cross-host-live: parent={parent_id} launcher=1 receiver=claude-code")


def path_identity(path: Path) -> list[Any]:
    if not path.exists() and not path.is_symlink():
        return ["absent", ""]
    info = path.lstat()
    mode = stat.S_IMODE(info.st_mode)
    if stat.S_ISLNK(info.st_mode):
        return ["symlink", mode, os.readlink(path)]
    if stat.S_ISREG(info.st_mode):
        return ["file", mode, hashlib.sha256(path.read_bytes()).hexdigest()]
    if stat.S_ISDIR(info.st_mode):
        return ["dir", mode, ""]
    return ["other", mode, info.st_size]


def tree_identity(root: Path, excludes: set[str]) -> dict[str, list[Any]]:
    entries = {".": path_identity(root)}
    if not root.is_dir() or root.is_symlink():
        return entries
    for path in sorted(root.rglob("*"), key=lambda item: item.relative_to(root).as_posix()):
        relative = path.relative_to(root).as_posix()
        if any(relative == excluded or relative.startswith(excluded + "/") for excluded in excludes):
            continue
        entries[relative] = path_identity(path)
    return entries


def snapshot(args: argparse.Namespace) -> None:
    payload: dict[str, dict[str, list[Any]]] = {}
    excludes = set(args.exclude)
    for value in args.root:
        if "=" not in value:
            fail(f"snapshot root lacked label=path form: {value!r}")
        label, raw_path = value.split("=", 1)
        if not label or label in payload:
            fail(f"snapshot root label was empty or duplicated: {label!r}")
        payload[label] = tree_identity(Path(raw_path), excludes if label == "canonical" else set())
    Path(args.output).write_text(json.dumps(payload, sort_keys=True), encoding="utf-8")


def export_evidence(args: argparse.Namespace) -> None:
    destination = Path(args.destination)
    if destination.exists() or destination.is_symlink():
        fail("evidence destination already exists")
    manifest = json.loads(Path(args.session_manifest).read_text(encoding="utf-8"))
    if not isinstance(manifest, list) or len(manifest) != 1 or not isinstance(manifest[0], str):
        fail("evidence export requires exactly one new parent session JSONL")
    destination.mkdir(parents=True)
    for source_name in (args.prompt, args.events):
        source = Path(source_name)
        if source.is_symlink() or not source.is_file():
            fail(f"evidence source was not a regular file: {source.name}")
        shutil.copyfile(source, destination / source.name)
    result = Path(args.result)
    if result.exists() or result.is_symlink():
        if result.is_symlink() or not result.is_file():
            fail(f"evidence result source was not a regular file: {result.name}")
        shutil.copyfile(result, destination / result.name)
    source = Path(args.sessions) / manifest[0]
    if source.is_symlink() or not source.is_file():
        fail("new parent session evidence was not a regular file")
    target = destination / "sessions" / manifest[0]
    target.parent.mkdir(parents=True)
    shutil.copyfile(source, target)


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser()
    sub = root.add_subparsers(dest="command", required=True)
    snap = sub.add_parser("snapshot")
    snap.add_argument("--output", required=True)
    snap.add_argument("--root", action="append", required=True)
    snap.add_argument("--exclude", action="append", default=[])
    snap.set_defaults(func=snapshot)
    check = sub.add_parser("verify")
    for name in (
        "events", "result", "sessions", "session_manifest", "parent_nonce",
        "receiver_nonce", "workspace", "before", "after",
    ):
        check.add_argument("--" + name.replace("_", "-"), required=True)
    check.set_defaults(func=verify)
    export = sub.add_parser("export-evidence")
    for name in ("events", "result", "prompt", "sessions", "session_manifest", "destination"):
        export.add_argument("--" + name.replace("_", "-"), required=True)
    export.set_defaults(func=export_evidence)
    return root


def main() -> None:
    args = parser().parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
