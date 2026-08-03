#!/usr/bin/env python3
"""Deterministic oracle for the opt-in Claude role-dispatch live lane."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, NoReturn


ROLE_PREFIX = "oh-no-harness:"


def fail(message: str, code: int = 1) -> NoReturn:
    print(message, file=sys.stderr)
    raise SystemExit(code)


def collect_text(value: Any) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(child) for child in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(child) for child in value)
    return ""


def json_rows(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as exc:
            fail(f"HARD FAIL: malformed Claude stream event in {path.name} line {number}: {exc}")
        if not isinstance(row, dict):
            fail(f"HARD FAIL: non-object Claude stream event in {path.name} line {number}")
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


def verify(args: argparse.Namespace) -> None:
    prompt = Path(args.prompt).read_text(encoding="utf-8")
    token = f"/{args.plugin}:{args.skill}"
    if not prompt.startswith(token):
        fail(f"HARD FAIL [{args.skill}]: prompt did not begin with native token {token}")

    rows = json_rows(Path(args.events))
    result_rows = [(index, row) for index, row in enumerate(rows) if row.get("type") == "result"]
    saved_result = Path(args.result).read_text(encoding="utf-8", errors="replace")

    tool_uses: list[dict[str, Any]] = []
    tool_results: dict[str, list[dict[str, Any]]] = {}
    task_notifications: dict[str, list[dict[str, Any]]] = {}
    for row_index, row in enumerate(rows):
        for part_index, part in enumerate(message_parts(row)):
            if part.get("type") == "tool_use" and part.get("name") == "Agent":
                payload = part.get("input")
                if not isinstance(payload, dict):
                    fail(f"HARD FAIL [{args.skill}]: Agent tool_use lacked an input object")
                tool_id = part.get("id")
                role = payload.get("subagent_type")
                if not isinstance(tool_id, str) or not tool_id or not isinstance(role, str) or not role:
                    fail(f"HARD FAIL [{args.skill}]: Agent tool_use lacked id or subagent_type")
                tool_uses.append({"row": row_index, "part": part_index, "id": tool_id, "role": role})

    agent_ids = {tool["id"] for tool in tool_uses}
    for row_index, row in enumerate(rows):
        notification_id = row.get("tool_use_id")
        if row.get("type") == "system" and row.get("subtype") == "task_notification" and isinstance(notification_id, str) and notification_id in agent_ids:
            task_notifications.setdefault(notification_id, []).append({"row": row_index, "value": row})
        for part_index, part in enumerate(message_parts(row)):
            tool_id = part.get("tool_use_id")
            if part.get("type") != "tool_result" or not isinstance(tool_id, str) or tool_id not in agent_ids:
                continue
            terminal = row.get("tool_use_result")
            tool_results.setdefault(tool_id, []).append({
                "row": row_index,
                "part": part_index,
                "value": part,
                "terminal": terminal if isinstance(terminal, dict) else {},
            })

    expected_roles = [role for role in args.roles.split(",") if role]
    expected_scoped = [ROLE_PREFIX + role for role in expected_roles]
    actual_scoped = [record["role"] for record in tool_uses]
    if not expected_roles and actual_scoped:
        fail(f"HARD FAIL [{args.skill}]: zero-child control emitted Agent tool_use {actual_scoped!r}")
    if actual_scoped != expected_scoped:
        retryable = False
        if len(actual_scoped) < len(expected_scoped):
            retryable = True
        elif len(actual_scoped) == len(expected_scoped):
            retryable = True
        elif all(role in expected_scoped for role in actual_scoped):
            retryable = True
        if retryable:
            fail(
                f"RETRYABLE [{args.skill}]: expected Agent subagent_type sequence "
                f"{expected_scoped!r}; got {actual_scoped!r}",
                75,
            )
        fail(f"HARD FAIL [{args.skill}]: unexpected extra Agent subagent_type sequence {actual_scoped!r}")

    nonce_map = json.loads(args.child_nonces)
    if not isinstance(nonce_map, dict):
        fail(f"HARD FAIL [{args.skill}]: child nonce map was not an object")
    completion_indexes: dict[str, int] = {}
    child_nonces: list[str] = []
    for role, tool in zip(expected_roles, tool_uses):
        matches = tool_results.get(tool["id"], [])
        if len(matches) != 1:
            fail(f"HARD FAIL [{args.skill}]: Agent tool_use {tool['id']} had {len(matches)} correlated tool_results")
        receipt = matches[0]
        value = receipt["value"]
        terminal = receipt["terminal"]
        terminal_status = terminal.get("status")
        terminal_id = terminal.get("toolUseId")
        if int(receipt["row"]) <= int(tool["row"]) or value.get("is_error") is True:
            fail(f"HARD FAIL [{args.skill}]: Agent tool_use {tool['id']} returned an error or out-of-order result")
        if terminal_id not in (None, tool["id"]):
            fail(f"HARD FAIL [{args.skill}]: Agent terminal metadata had the wrong toolUseId")
        nonce = nonce_map.get(role)
        if not isinstance(nonce, str) or not nonce:
            fail(f"HARD FAIL [{args.skill}]: missing assigned nonce for {role}")
        child_nonces.append(nonce)
        if terminal_status == "async_launched":
            if not isinstance(terminal.get("agentId"), str) or not terminal.get("agentId") or not isinstance(terminal.get("outputFile"), str) or not terminal.get("outputFile"):
                fail(f"HARD FAIL [{args.skill}]: async Agent launch lacked agentId or outputFile")
            notifications = task_notifications.get(tool["id"], [])
            if len(notifications) != 1:
                fail(f"HARD FAIL [{args.skill}]: async Agent tool_use {tool['id']} had {len(notifications)} matching task notifications")
            notification = notifications[0]
            notification_value = notification["value"]
            if int(notification["row"]) <= int(receipt["row"]) or notification_value.get("status") != "completed":
                fail(f"HARD FAIL [{args.skill}]: async Agent tool_use {tool['id']} lacked a later completed task notification")
            if nonce not in collect_text(notification_value.get("summary")):
                fail(f"HARD FAIL [{args.skill}]: child {role} task notification omitted its assigned nonce")
            completion_indexes[role] = int(notification["row"])
        else:
            if terminal_status not in (None, "completed"):
                fail(f"HARD FAIL [{args.skill}]: Agent tool_use {tool['id']} returned an error")
            if nonce not in collect_text(value.get("content")):
                fail(f"HARD FAIL [{args.skill}]: child {role} tool_result omitted its assigned nonce")
            completion_indexes[role] = int(receipt["row"])

    if len(expected_roles) == 2:
        first_role, reviewer_role = expected_roles
        reviewer_use = next(tool for tool in tool_uses if tool["role"] == ROLE_PREFIX + reviewer_role)
        if reviewer_use["row"] <= completion_indexes[first_role]:
            fail(
                f"HARD FAIL [{args.skill}]: {reviewer_role} Agent tool_use occurred before "
                f"the completed {first_role} child result"
            )

    if not result_rows:
        fail(f"HARD FAIL [{args.skill}]: missing terminal parent result")
    final_result_index, final_result_row = result_rows[-1]
    stream_result = str(final_result_row.get("result") or "")
    if final_result_row.get("is_error") is True or not stream_result.strip():
        fail(f"HARD FAIL [{args.skill}]: last terminal parent result was errored or empty")
    if completion_indexes and final_result_index <= max(completion_indexes.values()):
        fail(f"HARD FAIL [{args.skill}]: final parent result preceded child completion")
    if stream_result.strip() != saved_result.strip():
        fail(f"HARD FAIL [{args.skill}]: saved final result did not match the last successful stream result")
    if args.parent_nonce not in saved_result:
        fail(f"HARD FAIL [{args.skill}]: parent final result omitted scenario nonce")
    for role, nonce in zip(expected_roles, child_nonces):
        if nonce not in saved_result:
            fail(f"HARD FAIL [{args.skill}]: parent final result omitted child {role} nonce")

    print(f"PASS - {args.skill}: children={','.join(expected_roles) or 'none'}")


def extract_result(args: argparse.Namespace) -> None:
    rows = json_rows(Path(args.events))
    results = [
        row for row in rows
        if row.get("type") == "result" and row.get("is_error") is not True and str(row.get("result") or "").strip()
    ]
    if not results:
        fail("HARD FAIL: missing successful terminal Claude result")
    Path(args.output).write_text(str(results[-1]["result"]), encoding="utf-8")


def tree_manifest(root: Path) -> dict[str, list[str]]:
    entries: dict[str, list[str]] = {}
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        if relative == ".git" or relative.startswith(".git/"):
            continue
        if path.is_symlink():
            entries[relative] = ["symlink", path.readlink().as_posix()]
        elif path.is_file():
            entries[relative] = ["file", hashlib.sha256(path.read_bytes()).hexdigest()]
        elif path.is_dir():
            entries[relative] = ["dir", ""]
    return entries


def snapshot(args: argparse.Namespace) -> None:
    Path(args.output).write_text(json.dumps(tree_manifest(Path(args.root)), sort_keys=True), encoding="utf-8")


def mutation(args: argparse.Namespace) -> None:
    before = json.loads(Path(args.before).read_text(encoding="utf-8"))
    after = json.loads(Path(args.after).read_text(encoding="utf-8"))
    changed = {key for key in set(before) | set(after) if before.get(key) != after.get(key)}
    allowed = {value for value in args.allow.split(",") if value}
    required = {value for value in args.require.split(",") if value}
    unexpected = sorted(changed - allowed)
    missing = sorted(required - changed)
    if unexpected:
        fail(f"HARD FAIL [{args.skill}]: mutation escaped allowlist: {unexpected!r}")
    if missing:
        fail(f"HARD FAIL [{args.skill}]: required successful outputs did not change: {missing!r}")


def path_is_within(value: str, root: Path) -> bool:
    if not value or not os.path.isabs(value):
        return False
    try:
        Path(value).resolve().relative_to(root)
        return True
    except (OSError, ValueError):
        return False


def environment_names(repo_root: Path) -> list[str]:
    names: list[str] = []
    for name, value in os.environ.items():
        if path_is_within(value, repo_root):
            names.append(name)
    return sorted(names)


def environment_unsets(args: argparse.Namespace) -> None:
    for name in environment_names(Path(args.repo_root).resolve()):
        print(name)


def environment_check(args: argparse.Namespace) -> None:
    names = environment_names(Path(args.repo_root).resolve())
    if names:
        fail(f"HARD FAIL: canonical checkout path leaked through environment variables: {names!r}")


def secret_scan(args: argparse.Namespace) -> None:
    blobs = [Path(path).read_text(encoding="utf-8", errors="replace") for path in args.paths]
    evidence = "\n".join(blobs)
    suspicious_names = ("TOKEN", "SECRET", "API_KEY", "ACCESS_KEY", "AUTH")
    leaked_names = sorted(
        name
        for name, value in os.environ.items()
        if len(value) >= 12 and any(marker in name.upper() for marker in suspicious_names) and value in evidence
    )
    lower = evidence.lower()
    structural = (
        "authorization: bearer " in lower
        or "api_key=" in lower
        or "access_token=" in lower
        or re.search(r"https://[^\s/@:]+:[^\s/@]+@", lower) is not None
    )
    if leaked_names or structural:
        fail(f"HARD FAIL: credential-like content found in dispatch evidence: env={leaked_names!r}")


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser()
    commands = root.add_subparsers(dest="command", required=True)

    verify_parser = commands.add_parser("verify")
    for name in ("events", "result", "prompt", "skill", "plugin", "roles", "child-nonces", "parent-nonce"):
        verify_parser.add_argument(f"--{name}", required=True)
    verify_parser.set_defaults(func=verify)

    result_parser = commands.add_parser("extract-result")
    result_parser.add_argument("events")
    result_parser.add_argument("output")
    result_parser.set_defaults(func=extract_result)

    snapshot_parser = commands.add_parser("snapshot")
    snapshot_parser.add_argument("root")
    snapshot_parser.add_argument("output")
    snapshot_parser.set_defaults(func=snapshot)

    mutation_parser = commands.add_parser("mutation")
    mutation_parser.add_argument("--skill", required=True)
    mutation_parser.add_argument("--before", required=True)
    mutation_parser.add_argument("--after", required=True)
    mutation_parser.add_argument("--allow", required=True)
    mutation_parser.add_argument("--require", default="")
    mutation_parser.set_defaults(func=mutation)

    for name, func in (("environment-unsets", environment_unsets), ("environment-check", environment_check)):
        environment_parser = commands.add_parser(name)
        environment_parser.add_argument("--repo-root", required=True)
        environment_parser.set_defaults(func=func)

    secret_parser = commands.add_parser("secret-scan")
    secret_parser.add_argument("paths", nargs="+")
    secret_parser.set_defaults(func=secret_scan)
    return root


def main() -> None:
    args = parser().parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
