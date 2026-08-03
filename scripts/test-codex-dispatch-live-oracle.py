#!/usr/bin/env python3
"""Offline synthetic contracts for codex-dispatch-live-oracle.py."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


ORACLE = Path(sys.argv[1])
DRIVER = ORACLE.with_name("test-codex-plugin.sh")
PYTHON = sys.executable


def write_rows(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(json.dumps(row) for row in rows) + "\n", encoding="utf-8")


def session(
    path: Path,
    identity: str,
    parent: str = "",
    role: str = "",
    nonce: str = "",
    completed: bool = True,
    include_id: bool = True,
) -> None:
    meta = {"session_id": parent or identity}
    if include_id:
        meta["id"] = identity
    if parent:
        meta["parent_thread_id"] = parent
        meta["agent_role"] = role
        meta["agent_path"] = f"/root/{role.removeprefix('oh-no-')}-fixture"
    rows = [{"type": "session_meta", "payload": meta}]
    if completed:
        rows.append({"type": "event_msg", "payload": {"type": "task_complete", "last_agent_message": f"done {nonce}"}})
    write_rows(path, rows)


def fixture(root: Path, roles: list[str]) -> list[str]:
    parent = "11111111-1111-4111-8111-111111111111"
    workspace = root / "workspace"
    sessions = root / "sessions"
    workspace.mkdir(parents=True)
    (workspace / ".codex-plugin").mkdir()
    prompt = root / "prompt.txt"
    prompt.write_text("$oh-no-harness:interview fixture", encoding="utf-8")
    nonces = {role: f"nonce-{index}" for index, role in enumerate(roles, 1)}
    result = root / "result.txt"
    result.write_text("parent-nonce\n" + "\n".join(nonces.values()), encoding="utf-8")
    events: list[dict] = [
        {"type": "thread.started", "thread_id": parent},
        {"type": "turn.started"},
        {"type": "turn.completed", "usage": {}},
    ]
    parent_rows: list[dict] = [{"type": "session_meta", "payload": {"id": parent, "session_id": parent}}]
    for index, role in enumerate(roles, 1):
        receiver = f"22222222-2222-4222-8222-{index:012d}"
        agent_path = f"/root/{role.removeprefix('oh-no-')}-fixture"
        spawn_call = f"spawn-{index}"
        wait_call = f"wait-{index}"
        parent_rows.extend([
            {"type": "response_item", "payload": {"type": "function_call", "name": "spawn_agent", "call_id": spawn_call, "arguments": json.dumps({"agent_type": role})}},
            {"type": "response_item", "payload": {"type": "function_call_output", "call_id": spawn_call, "output": json.dumps({"task_name": agent_path})}},
            {"type": "response_item", "payload": {"type": "function_call", "name": "wait_agent", "call_id": wait_call, "arguments": json.dumps({"timeout_ms": 3600000})}},
            {"type": "response_item", "payload": {"type": "function_call_output", "call_id": wait_call, "output": json.dumps({"message": "Wait completed.", "timed_out": False})}},
            {"type": "response_item", "payload": {"type": "agent_message", "author": agent_path, "content": [{"type": "input_text", "text": f"Receipt: {nonces[role]}"}]}},
        ])
        session(sessions / f"child-{index}.jsonl", receiver, parent, role, nonces[role])
    write_rows(root / "events.jsonl", events)
    write_rows(sessions / "parent.jsonl", parent_rows)
    return [
        PYTHON,
        str(ORACLE),
        "verify",
        "--events", str(root / "events.jsonl"),
        "--result", str(result),
        "--prompt", str(prompt),
        "--sessions", str(sessions),
        "--skill", "interview",
        "--plugin", "oh-no-harness",
        "--roles", ",".join(roles),
        "--child-nonces", json.dumps(nonces),
        "--parent-nonce", "parent-nonce",
    ]


def run(command: list[str], expected: int = 0, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, text=True, capture_output=True, check=False, env=env)
    if result.returncode != expected:
        raise SystemExit(
            f"fixture expected rc={expected}, got {result.returncode}\nstdout={result.stdout}\nstderr={result.stderr}"
        )
    return result


with tempfile.TemporaryDirectory(prefix="codex-dispatch-oracle-") as temp:
    root = Path(temp)
    valid = root / "valid"
    command = fixture(valid, ["oh-no-explore"])
    run(command)  # Codex 0.146 child id differs from root session_id; persisted spawn proves dispatch.

    missing_id = root / "missing-id"
    missing_id_command = fixture(missing_id, ["oh-no-explore"])
    child_path = missing_id / "sessions" / "child-1.jsonl"
    rows = [json.loads(line) for line in child_path.read_text().splitlines()]
    rows[0]["payload"].pop("id")
    write_rows(child_path, rows)
    run(missing_id_command, 1)

    parent_conflict = root / "parent-conflict"
    parent_conflict_command = fixture(parent_conflict, ["oh-no-explore"])
    child_path = parent_conflict / "sessions" / "child-1.jsonl"
    rows = [json.loads(line) for line in child_path.read_text().splitlines()]
    rows[0]["payload"]["source"] = {"subagent": {"thread_spawn": {"parent_thread_id": "conflicting-parent"}}}
    write_rows(child_path, rows)
    run(parent_conflict_command, 1)

    missing_completion = root / "missing-completion"
    missing_command = fixture(missing_completion, ["oh-no-explore"])
    child_path = missing_completion / "sessions" / "child-1.jsonl"
    rows = [json.loads(line) for line in child_path.read_text().splitlines()]
    write_rows(child_path, rows[:1])
    run(missing_command, 1)

    wrong_parent = root / "wrong-parent"
    wrong_parent_command = fixture(wrong_parent, ["oh-no-explore"])
    child_path = wrong_parent / "sessions" / "child-1.jsonl"
    rows = [json.loads(line) for line in child_path.read_text().splitlines()]
    rows[0]["payload"]["parent_thread_id"] = "33333333-3333-4333-8333-333333333333"
    write_rows(child_path, rows)
    run(wrong_parent_command, 75)

    wrong_role = root / "wrong-role"
    wrong_role_command = fixture(wrong_role, ["oh-no-explore"])
    child_path = wrong_role / "sessions" / "child-1.jsonl"
    rows = [json.loads(line) for line in child_path.read_text().splitlines()]
    rows[0]["payload"]["agent_role"] = "oh-no-debugger"
    write_rows(child_path, rows)
    run(wrong_role_command, 75)

    missing_nonce = root / "missing-nonce"
    missing_nonce_command = fixture(missing_nonce, ["oh-no-explore"])
    child_path = missing_nonce / "sessions" / "child-1.jsonl"
    rows = [json.loads(line) for line in child_path.read_text().splitlines()]
    rows[-1]["payload"]["last_agent_message"] = "done without correlation"
    write_rows(child_path, rows)
    run(missing_nonce_command, 1)

    for label, author, receipt_text in (
        ("missing-author", None, "Receipt: nonce-1"),
        ("wrong-author", "/root/other-agent", "Receipt: nonce-1"),
        ("receipt-missing-nonce", "/root/explore-fixture", "Receipt omitted"),
    ):
        receipt_root = root / label
        receipt_command = fixture(receipt_root, ["oh-no-explore"])
        parent_path = receipt_root / "sessions" / "parent.jsonl"
        parent_rows = [json.loads(line) for line in parent_path.read_text().splitlines()]
        receipt = next(row["payload"] for row in parent_rows if row.get("payload", {}).get("type") == "agent_message")
        if author is None:
            receipt.pop("author")
        else:
            receipt["author"] = author
        receipt["content"][0]["text"] = receipt_text
        write_rows(parent_path, parent_rows)
        run(receipt_command, 1)

    legacy_wait = root / "legacy-wait"
    legacy_command = fixture(legacy_wait, ["oh-no-explore"])
    parent_path = legacy_wait / "sessions" / "parent.jsonl"
    parent_rows = [json.loads(line) for line in parent_path.read_text().splitlines()]
    parent_rows = [row for row in parent_rows if row.get("payload", {}).get("type") != "agent_message"]
    wait_output = next(row["payload"] for row in parent_rows if row.get("payload", {}).get("call_id") == "wait-1" and row.get("payload", {}).get("type") == "function_call_output")
    wait_output["output"] = json.dumps({"message": "completed nonce-1", "timed_out": False})
    write_rows(parent_path, parent_rows)
    run(legacy_command)

    unexpected = root / "unexpected"
    unexpected_command = fixture(unexpected, ["oh-no-explore"])
    parent = "11111111-1111-4111-8111-111111111111"
    session(
        unexpected / "sessions" / "unexpected.jsonl",
        "44444444-4444-4444-8444-444444444444",
        parent,
        "oh-no-debugger",
        "unexpected",
    )
    run(unexpected_command, 1)

    mutation_root = root / "mutation-root"
    mutation_root.mkdir()
    (mutation_root / "allowed.txt").write_text("before", encoding="utf-8")
    before = root / "before.json"
    after = root / "after.json"
    run([PYTHON, str(ORACLE), "snapshot", str(mutation_root), str(before)])
    (mutation_root / "allowed.txt").write_text("after", encoding="utf-8")
    run([PYTHON, str(ORACLE), "snapshot", str(mutation_root), str(after)])
    run([
        PYTHON, str(ORACLE), "mutation", "--skill", "fixture",
        "--before", str(before), "--after", str(after), "--allow", "allowed.txt",
    ])
    run([
        PYTHON, str(ORACLE), "mutation", "--skill", "fixture",
        "--before", str(before), "--after", str(after), "--allow", "",
    ], 1)

    ralph_path_contract = r'''
driver="$1"
set --
source "$driver"
IFS='|' read -r roles sandbox allow require <<<"$(dispatch_scenario_contract ralph)"
expected_allow='dispatch-fixture/src/formatter.py,dispatch-fixture/tests/test_formatter.py,dispatch-fixture/.oh-no/sessions/task-53-dispatch-ralph/progress.md,dispatch-fixture/.oh-no/sessions/task-53-dispatch-ralph/verification.md'
[[ "$roles" == 'oh-no-executor,oh-no-code-reviewer' ]]
[[ "$sandbox" == workspace-write ]]
[[ "$allow" == "$expected_allow" ]]
[[ "$require" == 'dispatch-fixture/src/formatter.py,dispatch-fixture/tests/test_formatter.py' ]]
prompt="$(dispatch_prompt ralph fixture-nonce '{}')"
[[ "$prompt" == *'Only dispatch-fixture/src/formatter.py, dispatch-fixture/tests/test_formatter.py, dispatch-fixture/.oh-no/sessions/task-53-dispatch-ralph/progress.md, and dispatch-fixture/.oh-no/sessions/task-53-dispatch-ralph/verification.md may change.'* ]]
'''
    run(["bash", "-c", ralph_path_contract, "fixture", str(DRIVER)])

    # A provider-failed run may make no allowed mutations; RC0 separately requires
    # its core outputs.
    run([
        PYTHON, str(ORACLE), "mutation", "--skill", "fixture",
        "--before", str(before), "--after", str(before), "--allow", "allowed.txt",
    ])
    run([
        PYTHON, str(ORACLE), "mutation", "--skill", "fixture",
        "--before", str(before), "--after", str(before), "--allow", "allowed.txt",
        "--require", "allowed.txt",
    ], 1)

    duplicate = root / "duplicate"
    duplicate_command = fixture(duplicate, ["oh-no-explore"])
    parent = "11111111-1111-4111-8111-111111111111"
    duplicate_receiver = "55555555-5555-4555-8555-555555555555"
    session(duplicate / "sessions" / "duplicate.jsonl", duplicate_receiver, parent, "oh-no-explore", "nonce-1")
    event_path = duplicate / "events.jsonl"
    event_rows = [json.loads(line) for line in event_path.read_text().splitlines()]
    event_rows.insert(-1, {
        "type": "item.completed",
        "item": {
            "type": "collab_tool_call", "tool": "spawn_agent", "status": "completed",
            "input": "agent_type=oh-no-explore", "receiver_thread_ids": [duplicate_receiver],
        },
    })
    write_rows(event_path, event_rows)
    run(duplicate_command, 75)

    early_review = root / "early-review"
    early_command = fixture(early_review, ["oh-no-executor", "oh-no-code-reviewer"])
    parent_path = early_review / "sessions" / "parent.jsonl"
    parent_rows = [json.loads(line) for line in parent_path.read_text().splitlines()]
    reviewer_spawn = parent_rows[6:8]
    del parent_rows[6:8]
    parent_rows[5:5] = reviewer_spawn
    write_rows(parent_path, parent_rows)
    run(early_command, 1)

    ordered_review = root / "ordered-review"
    ordered_review_command = fixture(ordered_review, ["oh-no-executor", "oh-no-code-reviewer"])
    run(ordered_review_command)

    selected_root = root / "selected-root"
    selected_root.mkdir()
    selected_path = selected_root / ".oh-no" / "sessions" / "probe" / "progress.md"
    selected_path.parent.mkdir(parents=True)
    selected_path.write_text("before", encoding="utf-8")
    selected_before = root / "selected-before.json"
    selected_after = root / "selected-after.json"
    selected_args = [".oh-no/sessions/probe/progress.md", ".oh-no/worktrees/probe"]
    run([PYTHON, str(ORACLE), "selected-snapshot", str(selected_root), str(selected_before), *selected_args])
    run([PYTHON, str(ORACLE), "selected-snapshot", str(selected_root), str(selected_after), *selected_args])
    run([PYTHON, str(ORACLE), "compare-snapshots", "--skill", "fixture", "--before", str(selected_before), "--after", str(selected_after)])
    selected_path.write_text("after", encoding="utf-8")
    run([PYTHON, str(ORACLE), "selected-snapshot", str(selected_root), str(selected_after), *selected_args])
    run([PYTHON, str(ORACLE), "compare-snapshots", "--skill", "fixture", "--before", str(selected_before), "--after", str(selected_after)], 1)

    environment = os.environ.copy()
    environment["OH_NO_PLUGIN_ROOT"] = str(selected_root)
    unset_result = run([PYTHON, str(ORACLE), "environment-unsets", "--repo-root", str(selected_root)], env=environment)
    if unset_result.stdout.strip() != "OH_NO_PLUGIN_ROOT":
        raise SystemExit(f"environment unset fixture returned {unset_result.stdout!r}")
    environment.pop("OH_NO_PLUGIN_ROOT")
    run([PYTHON, str(ORACLE), "environment-check", "--repo-root", str(selected_root)], env=environment)
    resolved_selected_root = selected_root.resolve()
    environment["SAFE_LOOKING_LEAK"] = str(resolved_selected_root / "child")
    leak_result = run([PYTHON, str(ORACLE), "environment-check", "--repo-root", str(selected_root)], 1, environment)
    if "SAFE_LOOKING_LEAK" not in leak_result.stderr or str(resolved_selected_root) in leak_result.stderr:
        raise SystemExit("environment containment diagnostic leaked a path or omitted the variable name")

    fake_python = root / "fake-python"
    fake_python.write_text(
        "#!/usr/bin/env bash\n"
        "[[ \"${2:-}\" == environment-unsets ]] && exit 0\n"
        "[[ \"${2:-}\" == environment-check ]] && exit 23\n"
        "exit 99\n",
        encoding="utf-8",
    )
    fake_python.chmod(0o755)
    marker = root / "live-command-invoked"
    guard_script = r'''
driver="$1"
fake_python="$2"
marker="$3"
launch_dir="$4"
set --
source "$driver"
PYTHON_BIN="$fake_python"
run_codex_live_command() { : >"$marker"; }
rc=0
run_sanitized_dispatch_command "$launch_dir" fixture-command || rc=$?
[[ "$rc" == 23 ]]
[[ ! -e "$marker" ]]
'''
    run(["bash", "-c", guard_script, "fixture", str(DRIVER), str(fake_python), str(marker), str(root)])

    git_root = root / "git-state"
    git_root.mkdir()
    run(["git", "-C", str(git_root), "init", "-q"])
    (git_root / "value.txt").write_text("one", encoding="utf-8")
    run(["git", "-C", str(git_root), "add", "value.txt"])
    run(["git", "-C", str(git_root), "-c", "user.name=fixture", "-c", "user.email=fixture.invalid", "commit", "-qm", "base"])
    baseline_head = subprocess.check_output(["git", "-C", str(git_root), "rev-parse", "HEAD"], text=True).strip()
    baseline_branch = subprocess.check_output(["git", "-C", str(git_root), "symbolic-ref", "-q", "--short", "HEAD"], text=True).strip()
    git_check = [PYTHON, str(ORACLE), "git-state", "--skill", "ralph", "--repo", str(git_root), "--head", baseline_head, "--branch", baseline_branch]
    run(git_check)
    (git_root / "value.txt").write_text("two", encoding="utf-8")
    run(["git", "-C", str(git_root), "add", "value.txt"])
    run(["git", "-C", str(git_root), "-c", "user.name=fixture", "-c", "user.email=fixture.invalid", "commit", "-qm", "unauthorized"])
    moved_head = subprocess.check_output(["git", "-C", str(git_root), "rev-parse", "HEAD"], text=True).strip()
    if moved_head == baseline_head:
        raise SystemExit("Git history fixture did not move HEAD")
    run(git_check, 1)

print("ok - dispatch oracle synthetic fixtures passed")
