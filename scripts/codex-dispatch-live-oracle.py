#!/usr/bin/env python3
"""Deterministic oracle for the opt-in Codex role-dispatch live lane."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
from pathlib import Path
from typing import Any, NoReturn


ROLE_PREFIX = "oh-no-"
HARD_ERROR_RE = re.compile(
    r"failed to spawn|spawn_agent.{0,80}failed|permission denied|protocol error|"
    r"unknown (?:tool|agent|role)|invalid agent",
    re.IGNORECASE | re.DOTALL,
)
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
        stripped = line.strip()
        if not stripped:
            continue
        if not stripped.startswith("{"):
            try:
                value = json.loads(stripped)
            except json.JSONDecodeError:
                continue
            if not isinstance(value, dict):
                fail(f"HARD FAIL: non-object JSON event in {path.name} line {number}")
            fail(f"HARD FAIL: JSON event did not start with '{{' in {path.name} line {number}")
        try:
            value = json.loads(stripped)
        except json.JSONDecodeError as exc:
            fail(f"HARD FAIL: malformed JSON event in {path.name} line {number}: {exc}")
        if not isinstance(value, dict):
            fail(f"HARD FAIL: non-object JSON event in {path.name} line {number}")
        rows.append(value)
    return rows


def nested_values(meta: dict[str, Any], key: str) -> list[Any]:
    source_value = meta.get("source")
    source = source_value if isinstance(source_value, dict) else {}
    subagent_value = source.get("subagent")
    subagent = subagent_value if isinstance(subagent_value, dict) else {}
    spawn_value = subagent.get("thread_spawn")
    spawn = spawn_value if isinstance(spawn_value, dict) else {}
    values = [layer[key] for layer in (meta, spawn) if key in layer and layer[key] not in (None, "")]
    distinct: list[Any] = []
    for value in values:
        if value not in distinct:
            distinct.append(value)
    if len(distinct) > 1:
        fail(f"HARD FAIL: conflicting session metadata for {key}: {distinct!r}")
    return distinct


def session_identity(meta: dict[str, Any]) -> str:
    identity = meta.get("id")
    if not isinstance(identity, str) or not identity:
        fail("HARD FAIL: session metadata lacks required payload.id identity")
    return identity


def session_records(sessions_root: Path) -> dict[str, dict[str, Any]]:
    records: dict[str, dict[str, Any]] = {}
    if not sessions_root.exists():
        return records
    for path in sessions_root.rglob("*.jsonl"):
        rows = json_rows(path)
        metas = [row.get("payload") for row in rows if row.get("type") == "session_meta"]
        if not metas:
            continue
        if len(metas) != 1 or not isinstance(metas[0], dict):
            fail(f"HARD FAIL: expected one session_meta in {path}")
        meta = metas[0]
        identity = session_identity(meta)
        parent_values = nested_values(meta, "parent_thread_id")
        role_values = nested_values(meta, "agent_role")
        agent_path_values = nested_values(meta, "agent_path")
        final_messages: list[str] = []
        completed = False
        for row in rows:
            payload_value = row.get("payload")
            payload: dict[str, Any] = payload_value if isinstance(payload_value, dict) else {}
            if row.get("type") == "event_msg" and payload.get("type") == "task_complete":
                completed = True
                message = collect_text(payload.get("last_agent_message"))
                if message:
                    final_messages.append(message)
        records[identity] = {
            "identity": identity,
            "path": path,
            "rows": rows,
            "parent": str(parent_values[0]) if parent_values else "",
            "role": str(role_values[0]) if role_values else "",
            "agent_path": str(agent_path_values[0]) if agent_path_values else "",
            "completed": completed,
            "final": final_messages[-1] if final_messages else "",
        }
    return records


def tool_records(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    pending: dict[str, tuple[int, str, str]] = {}
    for index, row in enumerate(rows, 1):
        item_value = row.get("item")
        item: dict[str, Any] = item_value if isinstance(item_value, dict) else {}
        if item.get("type") == "collab_tool_call":
            records.append(
                {
                    "index": index,
                    "tool": str(item.get("tool") or ""),
                    "status": str(item.get("status") or ""),
                    "input": collect_text(item.get("input") or item.get("arguments") or item),
                    "output": collect_text(item),
                    "receivers": [str(value) for value in item.get("receiver_thread_ids") or []],
                    "explicit_receivers": True,
                }
            )
        payload_value = row.get("payload")
        payload: dict[str, Any] = payload_value if isinstance(payload_value, dict) else {}
        payload_type = payload.get("type")
        if payload_type in {"custom_tool_call", "function_call"}:
            call_id = str(payload.get("call_id") or "")
            pending[call_id] = (
                index,
                str(payload.get("name") or ""),
                collect_text(payload.get("input") if "input" in payload else payload.get("arguments")),
            )
        elif payload_type in {"custom_tool_call_output", "function_call_output"}:
            call_id = str(payload.get("call_id") or "")
            if call_id in pending:
                call_index, name, call_input = pending[call_id]
                output = collect_text(payload.get("output"))
                records.append(
                    {
                        "index": call_index,
                        "result_index": index,
                        "tool": name,
                        "status": "completed",
                        "input": call_input,
                        "output": output,
                        "receivers": [],
                        "explicit_receivers": False,
                    }
                )
    return records


def child_authored_receipts(rows: list[dict[str, Any]], offset: int) -> list[dict[str, Any]]:
    receipts: list[dict[str, Any]] = []
    for index, row in enumerate(rows, 1):
        if row.get("type") != "response_item":
            continue
        payload_value = row.get("payload")
        payload: dict[str, Any] = payload_value if isinstance(payload_value, dict) else {}
        if payload.get("type") != "agent_message":
            continue
        author = payload.get("author")
        if not isinstance(author, str) or not author:
            continue
        receipts.append({"index": offset + index, "author": author, "text": collect_text(payload.get("content"))})
    return receipts


def role_from_text(text: str) -> str:
    assigned = re.findall(
        r"agent_(?:type|role)[\"']?\s*[:=]\s*[\"']?(oh-no-[a-z][a-z-]*)",
        text,
        re.IGNORECASE,
    )
    if assigned:
        return assigned[0].lower()
    roles = re.findall(r"\boh-no-[a-z][a-z-]*\b", text)
    return roles[0] if len(set(roles)) == 1 else ""


def verify(args: argparse.Namespace) -> None:
    event_text_raw = Path(args.events).read_text(encoding="utf-8", errors="replace")
    if HARD_ERROR_RE.search(event_text_raw):
        fail(f"HARD FAIL [{args.skill}]: failed spawn, fallback, permission, or protocol error observed")
    event_rows = json_rows(Path(args.events))
    if not event_rows or event_rows[-1].get("type") != "turn.completed":
        fail(f"HARD FAIL [{args.skill}]: missing successful terminal turn.completed event")
    parent_ids = [str(row.get("thread_id")) for row in event_rows if row.get("type") == "thread.started" and row.get("thread_id")]
    if len(set(parent_ids)) != 1:
        fail(f"HARD FAIL [{args.skill}]: expected one current parent thread, got {parent_ids!r}")
    parent_id = parent_ids[0]

    prompt = Path(args.prompt).read_text(encoding="utf-8")
    token = f"${args.plugin}:{args.skill}"
    if not prompt.startswith(token):
        fail(f"HARD FAIL [{args.skill}]: prompt did not begin with native token {token}")
    result = Path(args.result).read_text(encoding="utf-8", errors="replace")
    if args.parent_nonce not in result:
        fail(f"HARD FAIL [{args.skill}]: parent final result omitted scenario nonce")

    sessions = session_records(Path(args.sessions))
    if parent_id not in sessions:
        fail(f"HARD FAIL [{args.skill}]: current parent transcript {parent_id} was not persisted")
    parent_rows = sessions[parent_id]["rows"]
    event_tools = tool_records(event_rows)
    parent_tools = tool_records(parent_rows)
    for record in parent_tools:
        record["index"] += len(event_rows)
        if "result_index" in record:
            record["result_index"] += len(event_rows)
    tools = event_tools + parent_tools
    parent_receipts = child_authored_receipts(parent_rows, len(event_rows))
    evidence_text = "\n".join(collect_text(row) for row in event_rows)
    if HARD_ERROR_RE.search(evidence_text):
        fail(f"HARD FAIL [{args.skill}]: failed spawn, fallback, permission, or protocol error observed")

    expected_roles = [role for role in args.roles.split(",") if role]
    children = [record for identity, record in sessions.items() if identity != parent_id and record["parent"] == parent_id]
    actual_roles = [record["role"] for record in children]
    unexpected = [role for role in actual_roles if role not in expected_roles]
    if unexpected:
        if expected_roles and len(actual_roles) == len(expected_roles):
            fail(f"RETRYABLE [{args.skill}]: wrong expected parent-linked child roles {actual_roles!r}", 75)
        fail(f"HARD FAIL [{args.skill}]: unexpected parent-linked child roles {unexpected!r}")
    if len(actual_roles) > len(expected_roles) or any(actual_roles.count(role) > expected_roles.count(role) for role in set(actual_roles)):
        fail(f"RETRYABLE [{args.skill}]: duplicate expected parent-linked children {actual_roles!r}", 75)

    spawn_records = [record for record in tools if record["tool"] == "spawn_agent" and record["status"] == "completed"]
    failed_spawns = [record for record in tools if record["tool"] == "spawn_agent" and record["status"] == "failed"]
    if failed_spawns:
        fail(f"HARD FAIL [{args.skill}]: failed spawn_agent event observed")
    receiver_records = [record for record in spawn_records if record["explicit_receivers"]]
    if not receiver_records:
        receiver_records = spawn_records
    spawned_receivers = {
        receiver
        for record in receiver_records
        for receiver in record["receivers"]
    }
    for receiver in spawned_receivers:
        if receiver not in sessions:
            fail(f"RETRYABLE [{args.skill}]: spawned receiver {receiver} lacked expected linkage", 75)
        if sessions[receiver]["parent"] != parent_id:
            fail(
                f"RETRYABLE [{args.skill}]: receiver {receiver} had wrong parent linkage",
                75,
            )
    spawn_sequence: list[str] = []
    spawn_indexes: dict[str, list[int]] = {}
    for spawn in sorted(spawn_records, key=lambda record: record["index"]):
        role = role_from_text(spawn["input"])
        if not role:
            role = role_from_text(spawn["output"])
        if role:
            spawn_sequence.append(role)
            spawn_indexes.setdefault(role, []).append(spawn["index"])
    # Duplicate representations from the exec stream and persisted parent transcript
    # are collapsed only when they describe the same adjacent role sequence.
    if len(spawn_sequence) == 2 * len(expected_roles) and spawn_sequence[: len(expected_roles)] == spawn_sequence[len(expected_roles) :]:
        spawn_sequence = spawn_sequence[: len(expected_roles)]
    if spawn_sequence != expected_roles or sorted(actual_roles) != sorted(expected_roles):
        fail(
            f"RETRYABLE [{args.skill}]: expected dispatch sequence {expected_roles!r}; "
            f"spawn={spawn_sequence!r} linked={actual_roles!r}",
            75,
        )

    wait_records = [
        record for record in tools
        if record["tool"] in {"wait", "wait_agent"} and record["status"] == "completed"
        and not re.search(r'"timed_out"\s*:\s*true', record["output"], re.IGNORECASE)
    ]
    close_records = [record for record in tools if record["tool"] == "close_agent" and record["status"] == "completed"]
    nonce_map = json.loads(args.child_nonces)
    receipt_indexes: dict[str, list[int]] = {}
    for role in expected_roles:
        matches = [record for record in children if record["role"] == role]
        if len(matches) != 1:
            fail(f"RETRYABLE [{args.skill}]: role {role} did not have exactly one linked child", 75)
        child = matches[0]
        if not child["completed"]:
            fail(f"HARD FAIL [{args.skill}]: child {role} lacked task_complete")
        nonce = str(nonce_map[role])
        if nonce not in child["final"]:
            fail(f"HARD FAIL [{args.skill}]: child {role} final result omitted its nonce")
        if nonce not in result:
            fail(f"HARD FAIL [{args.skill}]: parent result omitted child {role} nonce")
        nonce_waits = [record for record in wait_records if nonce in record["output"]]
        agent_path = child["agent_path"]
        authored_receipts = [
            receipt for receipt in parent_receipts
            if agent_path and receipt["author"] == agent_path and nonce in receipt["text"]
            and any(wait["index"] < receipt["index"] for wait in wait_records)
        ]
        role_receipts = [record["index"] for record in nonce_waits] + [receipt["index"] for receipt in authored_receipts]
        if not role_receipts:
            fail(f"HARD FAIL [{args.skill}]: parent lacked a completed nonce-bearing receipt from child {role}")
        receipt_indexes[role] = role_receipts
        matching_closes = [record for record in close_records if child["identity"] in record["input"] + record["output"]]
        if matching_closes and min(record["index"] for record in matching_closes) <= min(role_receipts):
            fail(f"HARD FAIL [{args.skill}]: child {role} was closed before its completed receipt")

    if len(expected_roles) == 2:
        first_role, reviewer_role = expected_roles
        if min(receipt_indexes[first_role]) >= min(spawn_indexes[reviewer_role]):
            fail(
                f"HARD FAIL [{args.skill}]: {reviewer_role} was dispatched before the "
                f"completed {first_role} receipt"
            )

    print(f"PASS - {args.skill}: parent={parent_id} children={','.join(expected_roles) or 'none'}")


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
    changed = set(key for key in set(before) | set(after) if before.get(key) != after.get(key))
    allowed = set(value for value in args.allow.split(",") if value)
    required = set(value for value in args.require.split(",") if value)
    outside = sorted(changed - allowed)
    if outside:
        fail(f"HARD FAIL [{args.skill}]: workspace changed paths outside allowlist: {outside!r}")
    missing = sorted(required - changed)
    if missing:
        fail(f"HARD FAIL [{args.skill}]: successful run missed required mutations: {missing!r}")


def selected_manifest(root: Path, relative_paths: list[str]) -> dict[str, list[str]]:
    entries: dict[str, list[str]] = {}
    for relative in relative_paths:
        path = root / relative
        if path.is_symlink():
            entries[relative] = ["symlink", path.readlink().as_posix()]
        elif path.is_file():
            entries[relative] = ["file", hashlib.sha256(path.read_bytes()).hexdigest()]
        elif path.is_dir():
            digest = hashlib.sha256()
            for child in sorted(path.rglob("*")):
                digest.update(child.relative_to(path).as_posix().encode() + b"\0")
                if child.is_symlink():
                    digest.update(b"L" + child.readlink().as_posix().encode())
                elif child.is_file():
                    digest.update(b"F" + child.read_bytes())
                elif child.is_dir():
                    digest.update(b"D")
                digest.update(b"\0")
            entries[relative] = ["dir", digest.hexdigest()]
        else:
            entries[relative] = ["absent", ""]
    return entries


def selected_snapshot(args: argparse.Namespace) -> None:
    payload = selected_manifest(Path(args.root), args.paths)
    Path(args.output).write_text(json.dumps(payload, sort_keys=True), encoding="utf-8")


def compare_snapshots(args: argparse.Namespace) -> None:
    before = json.loads(Path(args.before).read_text(encoding="utf-8"))
    after = json.loads(Path(args.after).read_text(encoding="utf-8"))
    if before != after:
        changed = sorted(key for key in set(before) | set(after) if before.get(key) != after.get(key))
        fail(f"HARD FAIL [{args.skill}]: canonical counterpart paths changed: {changed!r}")


def path_within(value: str, root: Path) -> bool:
    if not value or not Path(value).expanduser().is_absolute():
        return False
    try:
        return os.path.commonpath((str(Path(value).expanduser().resolve()), str(root))) == str(root)
    except (OSError, ValueError):
        return False


def environment_unsets(args: argparse.Namespace) -> None:
    root = Path(args.repo_root).resolve()
    for name, value in sorted(os.environ.items()):
        if name.startswith("OH_NO_") and path_within(value, root):
            print(name)


def environment_check(args: argparse.Namespace) -> None:
    root = str(Path(args.repo_root).resolve())
    exposed = sorted(
        name for name, value in os.environ.items()
        if root in value or path_within(value, Path(root))
    )
    if exposed:
        fail(f"HARD FAIL: dispatch environment exposes canonical checkout via variables: {exposed!r}")


def git_state(args: argparse.Namespace) -> None:
    repo = Path(args.repo)
    head = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()
    branch_result = subprocess.run(
        ["git", "-C", str(repo), "symbolic-ref", "-q", "--short", "HEAD"],
        text=True,
        capture_output=True,
        check=False,
    )
    branch = branch_result.stdout.strip() if branch_result.returncode == 0 else "DETACHED"
    if head != args.head or branch != args.branch:
        fail(
            f"HARD FAIL [{args.skill}]: fixture Git history moved "
            f"(HEAD changed={head != args.head}, branch state changed={branch != args.branch})"
        )


def session_inventory(root: Path) -> list[str]:
    inventory: list[str] = []
    if not root.exists() or root.is_symlink():
        return inventory
    for directory, names, files in os.walk(root, followlinks=False):
        directory_path = Path(directory)
        names[:] = [name for name in names if not (directory_path / name).is_symlink()]
        for name in files:
            path = directory_path / name
            if not name.endswith(".jsonl") or path.is_symlink():
                continue
            try:
                mode = path.lstat().st_mode
            except OSError:
                continue
            if stat.S_ISREG(mode):
                inventory.append(path.relative_to(root).as_posix())
    return sorted(inventory)


def session_inventory_command(args: argparse.Namespace) -> None:
    Path(args.output).write_text(json.dumps(session_inventory(Path(args.sessions))), encoding="utf-8")


def new_session_manifest(args: argparse.Namespace) -> None:
    before = set(json.loads(Path(args.before).read_text(encoding="utf-8")))
    current = set(session_inventory(Path(args.sessions)))
    Path(args.output).write_text(json.dumps(sorted(current - before)), encoding="utf-8")


def session_paths(args: argparse.Namespace) -> None:
    root = Path(args.sessions)
    relatives = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    for relative in relatives:
        path = root / relative
        if relative not in session_inventory(root):
            fail(f"HARD FAIL: new session evidence is no longer a regular JSONL file: {relative!r}")
        sys.stdout.buffer.write(str(path).encode("utf-8") + b"\0")


def export_evidence(args: argparse.Namespace) -> None:
    destination = Path(args.destination)
    if destination.exists() or destination.is_symlink():
        fail(f"HARD FAIL: dispatch evidence destination already exists: {destination.name}")
    session_root = Path(args.sessions)
    relatives = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    current = set(session_inventory(session_root))
    if any(relative not in current for relative in relatives):
        fail("HARD FAIL: dispatch session evidence changed before export")
    evidence_sources: list[Path] = []
    for source_name in (args.prompt, args.result, args.events):
        source = Path(source_name)
        if not source.exists():
            continue
        if source.is_symlink() or not stat.S_ISREG(source.lstat().st_mode):
            fail(f"HARD FAIL: dispatch evidence source is not a regular file: {source.name}")
        evidence_sources.append(source)
    session_sources: list[tuple[str, Path]] = []
    for relative in relatives:
        source = session_root / relative
        if source.is_symlink() or not stat.S_ISREG(source.lstat().st_mode):
            fail(f"HARD FAIL: dispatch session source is not a regular file: {relative!r}")
        session_sources.append((relative, source))
    destination.mkdir(parents=True)
    for source in evidence_sources:
        shutil.copyfile(source, destination / source.name)
    for relative, source in session_sources:
        target = destination / "sessions" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser()
    sub = root.add_subparsers(dest="command", required=True)
    snap = sub.add_parser("snapshot")
    snap.add_argument("root")
    snap.add_argument("output")
    snap.set_defaults(func=snapshot)
    mut = sub.add_parser("mutation")
    mut.add_argument("--skill", required=True)
    mut.add_argument("--before", required=True)
    mut.add_argument("--after", required=True)
    mut.add_argument("--allow", default="")
    mut.add_argument("--require", default="")
    mut.set_defaults(func=mutation)
    selected = sub.add_parser("selected-snapshot")
    selected.add_argument("root")
    selected.add_argument("output")
    selected.add_argument("paths", nargs="+")
    selected.set_defaults(func=selected_snapshot)
    compare = sub.add_parser("compare-snapshots")
    compare.add_argument("--skill", required=True)
    compare.add_argument("--before", required=True)
    compare.add_argument("--after", required=True)
    compare.set_defaults(func=compare_snapshots)
    env_unsets = sub.add_parser("environment-unsets")
    env_unsets.add_argument("--repo-root", required=True)
    env_unsets.set_defaults(func=environment_unsets)
    env_check = sub.add_parser("environment-check")
    env_check.add_argument("--repo-root", required=True)
    env_check.set_defaults(func=environment_check)
    git = sub.add_parser("git-state")
    git.add_argument("--skill", required=True)
    git.add_argument("--repo", required=True)
    git.add_argument("--head", required=True)
    git.add_argument("--branch", required=True)
    git.set_defaults(func=git_state)
    inventory = sub.add_parser("session-inventory")
    inventory.add_argument("--sessions", required=True)
    inventory.add_argument("--output", required=True)
    inventory.set_defaults(func=session_inventory_command)
    new_sessions = sub.add_parser("new-session-manifest")
    new_sessions.add_argument("--sessions", required=True)
    new_sessions.add_argument("--before", required=True)
    new_sessions.add_argument("--output", required=True)
    new_sessions.set_defaults(func=new_session_manifest)
    paths = sub.add_parser("session-paths")
    paths.add_argument("--sessions", required=True)
    paths.add_argument("--manifest", required=True)
    paths.set_defaults(func=session_paths)
    export = sub.add_parser("export-evidence")
    export.add_argument("--sessions", required=True)
    export.add_argument("--manifest", required=True)
    export.add_argument("--destination", required=True)
    export.add_argument("--prompt", required=True)
    export.add_argument("--result", required=True)
    export.add_argument("--events", required=True)
    export.set_defaults(func=export_evidence)
    check = sub.add_parser("verify")
    for name in ("events", "result", "prompt", "sessions", "skill", "plugin", "roles", "child_nonces", "parent_nonce"):
        check.add_argument("--" + name.replace("_", "-"), required=True)
    check.set_defaults(func=verify)
    return root


def main() -> None:
    args = parser().parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
