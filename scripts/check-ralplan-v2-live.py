#!/usr/bin/env python3
"""Verify Ralplan v2 live behavior from runtime events, not final prose."""

from __future__ import annotations

import argparse
import copy
import json
import re
import shlex
import sys
import tempfile
from collections import defaultdict
from pathlib import Path
from typing import Any


ROLES = ("planner", "plan-reviewer")
CONTRACT_START = "ACTIVE_PLAN_CONTRACT_BEGIN"
CONTRACT_END = "ACTIVE_PLAN_CONTRACT_END"
DRAFT_START = "PLANNER_DRAFT_BEGIN"
DRAFT_END = "PLANNER_DRAFT_END"
VERDICT_TOKEN = "VERDICT_APPROVE"
PROFILE_EXPECTED = {
    "Overall Ralph mode": "STANDARD",
    "Mode source": "ralplan",
    "Verification tier": "STANDARD",
    "Artifact policy": "session-verification",
    "Agent policy": "inline-only",
    "Parallel trigger": "none",
    "Worktree policy": "direct-automatic-worktree",
    "Worktree location": ".oh-no/worktrees/preferences-write-v2",
    "Cleanup policy": "not-needed",
}


def fail(message: str) -> None:
    raise SystemExit(message)


def collect_text(value: Any) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return "\n".join(collect_text(item) for item in value.values())
    if isinstance(value, list):
        return "\n".join(collect_text(item) for item in value)
    return ""


def append_unique_output(outputs: dict[str, list[str]], role: str, value: Any) -> None:
    text = collect_text(value).strip()
    if text and text not in outputs[role]:
        outputs[role].append(text)


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as fh:
        for line_number, line in enumerate(fh, 1):
            if not line.strip():
                continue
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError as exc:
                fail(f"{path}:{line_number} is not valid JSONL: {exc}")
    return events


def normalize(value: str) -> str:
    lines = value.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    return "\n".join(line.rstrip() for line in lines)


def assert_execution_profile(draft: str, platform: str) -> None:
    if len(re.findall(r"(?m)^Execution profile:\s*$", draft)) != 1:
        fail(f"{platform}: Planner draft must contain exactly one canonical Execution profile block")
    for label, expected in PROFILE_EXPECTED.items():
        matches = re.findall(rf"(?m)^- {re.escape(label)}:\s*(.+?)\s*$", draft)
        if matches != [expected]:
            fail(f"{platform}: invalid {label}; expected {expected!r}, got {matches!r}")
    for label in ("Task sizing", "Escalation triggers"):
        matches = re.findall(rf"(?m)^- {re.escape(label)}:\s*(.+?)\s*$", draft)
        if len(matches) != 1 or not matches[0].strip():
            fail(f"{platform}: Planner draft must contain one non-empty {label}")


def assert_handoff_nonce(draft: str, handoff_nonce: str, platform: str) -> None:
    expected = f"Handoff nonce: {handoff_nonce}"
    if re.findall(r"(?m)^Handoff nonce:\s*(\S+)\s*$", draft) != [handoff_nonce]:
        fail(f"{platform}: Planner draft does not contain the unique handoff nonce")
    if draft.count(expected) != 1:
        fail(f"{platform}: handoff nonce must occur exactly once in the Planner draft")


def assert_packet_nonce(packet: str, handoff_nonce: str, platform: str) -> None:
    matches = re.findall(r"(?m)^Handoff nonce:\s*(\S+)\s*$", packet)
    if not matches or set(matches) != {handoff_nonce}:
        fail(f"{platform}: role packet is missing the unique handoff nonce or carries another value")


def assert_approve_verdict(output: str, platform: str) -> None:
    matches = re.findall(r"(?m)\bVERDICT_(?:APPROVE|ITERATE|REJECT)\b", output)
    if matches != [VERDICT_TOKEN]:
        fail(f"{platform}: expected exactly one {VERDICT_TOKEN} and no conflicting machine verdict; got {matches!r}")


def extract_block(
    text: str, start: str, end: str, label: str, *, allow_repeats: bool = False
) -> str:
    matches = re.findall(
        rf"(?ms)^\s*{re.escape(start)}\s*$\n(.*?)^\s*{re.escape(end)}\s*$",
        text,
    )
    unique = {normalize(match) for match in matches}
    if len(unique) != 1 or (not allow_repeats and len(matches) != 1):
        fail(
            f"expected one unique {label}; matches={len(matches)} "
            f"unique={len(unique)}"
        )
    return next(iter(unique))


def check_wrapper(path: Path, platform: str) -> None:
    text = path.read_text(encoding="utf-8")
    adapter = (
        "docs/platforms/codex-ralplan-v2.md"
        if platform == "codex"
        else "docs/platforms/claude-code-ralplan-v2.md"
    )
    expected_order = [
        "../../docs/skill-core/ralplan-v2.md",
        f"../../{adapter}",
    ]
    order_match = re.search(
        r"(?ms)^Source order:\s*\n(.*?)\nThe sections below are already composed",
        text,
    )
    if not order_match:
        fail(f"{path} is missing generated Source order metadata")
    actual_order = re.findall(r"^- `([^`]+)`$", order_match.group(1), re.MULTILINE)
    if actual_order != expected_order:
        fail(f"{path} source order mismatch: {actual_order!r}")

    source_headings = re.findall(r"^## Source: (.+)$", text, re.MULTILINE)
    expected_headings = ["docs/skill-core/ralplan-v2.md", adapter]
    if source_headings != expected_headings:
        fail(f"{path} source sections mismatch: {source_headings!r}")
    if "docs/platforms/codex-runtime.md" in text or "docs/platforms/claude-code-runtime.md" in text:
        fail(f"{path} unexpectedly embeds a common platform runtime")
    if not 20_000 <= len(text) <= 30_000:
        fail(f"{path} length {len(text)} is outside 20,000-30,000 characters")


def role_from_packet(text: str) -> str | None:
    matches = re.findall(r"(?m)^RALPLAN_V2_ROLE:\s*(planner|plan-reviewer)\s*$", text)
    unique = set(matches)
    return next(iter(unique)) if len(unique) == 1 else None


def assert_relational_handoff(
    role_packets: dict[str, str], role_outputs: dict[str, str], platform: str,
    handoff_nonce: str,
) -> None:
    planner_contract = extract_block(
        role_packets["planner"], CONTRACT_START, CONTRACT_END, "Planner contract"
    )
    reviewer_contract = extract_block(
        role_packets["plan-reviewer"], CONTRACT_START, CONTRACT_END,
        "Reviewer contract", allow_repeats=True,
    )
    if planner_contract != reviewer_contract:
        fail(f"{platform}: Planner and Reviewer received different Active Plan Contracts")

    planner_draft = extract_block(
        role_outputs["planner"], DRAFT_START, DRAFT_END, "Planner result draft", allow_repeats=True
    )
    reviewer_draft = extract_block(
        role_packets["plan-reviewer"], DRAFT_START, DRAFT_END, "Reviewer input draft"
    )
    if planner_draft != reviewer_draft:
        fail(f"{platform}: Reviewer did not receive the exact captured Planner draft")
    assert_execution_profile(role_packets["planner"], platform)
    assert_execution_profile(role_packets["plan-reviewer"], platform)
    assert_packet_nonce(role_packets["planner"], handoff_nonce, platform)
    assert_packet_nonce(role_packets["plan-reviewer"], handoff_nonce, platform)
    assert_execution_profile(planner_draft, platform)
    assert_handoff_nonce(planner_draft, handoff_nonce, platform)
    assert_approve_verdict(role_outputs["plan-reviewer"], platform)


def assert_relational_outputs(
    role_outputs: dict[str, str], platform: str, handoff_nonce: str
) -> None:
    planner_draft = extract_block(
        role_outputs["planner"], DRAFT_START, DRAFT_END,
        "Planner result draft", allow_repeats=True,
    )
    reviewer_draft = extract_block(
        role_outputs["plan-reviewer"], DRAFT_START, DRAFT_END,
        "Reviewer echoed draft", allow_repeats=True,
    )
    if planner_draft != reviewer_draft:
        fail(f"{platform}: Reviewer did not echo the exact captured Planner draft")
    reviewer_contract = extract_block(
        role_outputs["plan-reviewer"], CONTRACT_START, CONTRACT_END,
        "Reviewer output contract", allow_repeats=True,
    )
    if normalize(reviewer_contract) not in normalize(planner_draft):
        fail(f"{platform}: Reviewer contract is not contained in the captured Planner draft")
    assert_execution_profile(planner_draft, platform)
    assert_handoff_nonce(planner_draft, handoff_nonce, platform)
    assert_approve_verdict(role_outputs["plan-reviewer"], platform)


def is_generated_wrapper_read(item: dict[str, Any]) -> bool:
    command = str(item.get("command") or "")
    try:
        outer = shlex.split(command)
        inner = shlex.split(outer[2]) if len(outer) == 3 else []
    except ValueError:
        return False
    if outer[:2] not in (
        ["/bin/zsh", "-lc"], ["/bin/bash", "-lc"],
        ["/bin/zsh", "-c"], ["/bin/bash", "-c"],
    ):
        return False
    if inner == ["cat", "SKILL.md"]:
        # Native skill loading executes this exact command from the selected
        # generated skill directory; no path or shell composition is accepted.
        return True
    if not inner or not inner[-1].endswith("/skills/ralplan-v2/SKILL.md"):
        return False
    if inner[0] == "cat":
        return len(inner) == 2
    return (
        len(inner) == 4
        and inner[:2] == ["sed", "-n"]
        and re.fullmatch(r"[0-9]+,[0-9]+p", inner[2]) is not None
    )


def is_generated_wrapper_mcp_read(item: dict[str, Any]) -> bool:
    if item.get("server") != "node_repl" or item.get("tool") != "js":
        return False
    code = str((item.get("arguments") or {}).get("code") or "")
    # Native Codex emits the same three-statement read either on one line or
    # with statement newlines. Canonicalize whitespace before applying the
    # full-string, read-only grammar; extra statements still fail the match.
    code = re.sub(r"\s+", " ", code.strip())
    match = re.fullmatch(
        r'var (?P<fs>[A-Za-z_][A-Za-z0-9_]*) = await import\("node:fs/promises"\); '
        r'var (?P<text>[A-Za-z_][A-Za-z0-9_]*) = await (?P=fs)[.]readFile\('
        r'"(?P<path>[^"\n]+/skills/ralplan-v2/SKILL[.]md)", "utf8"\); '
        r'nodeRepl[.]write\((?P=text)\);',
        code,
    )
    if match is None:
        return False
    path = Path(match.group("path"))
    return path.is_absolute() and ".." not in path.parts


def codex_parent_thread_id(events: list[dict[str, Any]]) -> str:
    ids = {
        str(event.get("thread_id"))
        for event in events
        if event.get("type") == "thread.started" and event.get("thread_id")
    }
    if len(ids) != 1:
        fail(f"codex: expected one parent thread id, got {sorted(ids)!r}")
    return next(iter(ids))


def codex_rollouts(sessions_root: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for path in sessions_root.rglob("*.jsonl"):
        events = load_jsonl(path)
        meta = next((event for event in events if event.get("type") == "session_meta"), None)
        if meta is None:
            continue
        payload = meta.get("payload") or {}
        source = payload.get("source") or {}
        spawn = source.get("subagent", {}).get("thread_spawn", {}) if isinstance(source, dict) else {}
        completion = next(
            (
                event for event in reversed(events)
                if event.get("type") == "event_msg"
                and (event.get("payload") or {}).get("type") == "task_complete"
            ),
            None,
        )
        forbidden_calls: list[str] = []
        collaboration_calls: list[dict[str, str]] = []
        developer_text: list[str] = []
        models: set[str] = set()
        for event in events:
            item = event.get("payload") or {}
            if event.get("type") == "turn_context" and item.get("model"):
                models.add(str(item["model"]))
            if event.get("type") == "response_item" and item.get("type") == "function_call":
                name = str(item.get("name") or "unknown")
                if item.get("namespace") in {"agents", "collaboration"}:
                    collaboration_calls.append(
                        {"name": name, "timestamp": str(event.get("timestamp") or "")}
                    )
                else:
                    forbidden_calls.append(name)
            if (
                event.get("type") == "response_item"
                and item.get("type") == "message"
                and item.get("role") == "developer"
            ):
                developer_text.extend(
                    str(part.get("text") or "")
                    for part in item.get("content") or []
                    if isinstance(part, dict) and part.get("type") == "input_text"
                )
        records.append(
            {
                "path": path,
                "id": payload.get("id"),
                "parent": payload.get("parent_thread_id") or spawn.get("parent_thread_id"),
                "agent_path": spawn.get("agent_path") or payload.get("agent_path"),
                "agent_role": spawn.get("agent_role") or payload.get("agent_role"),
                "started": payload.get("timestamp") or meta.get("timestamp"),
                "completed": completion.get("timestamp") if completion else None,
                "model": next(iter(models)) if len(models) == 1 else None,
                "output": ((completion.get("payload") or {}).get("last_agent_message") if completion else "") or "",
                "forbidden_calls": forbidden_calls,
                "collaboration_calls": collaboration_calls,
                "developer_text": "\n".join(developer_text),
            }
        )
    return records


def codex_rollout_graph(
    events: list[dict[str, Any]], sessions_root: Path
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    parent_id = codex_parent_thread_id(events)
    records = codex_rollouts(sessions_root)
    parents = [record for record in records if record["id"] == parent_id]
    if len(parents) != 1:
        fail(f"codex: expected one stored parent rollout {parent_id}, got {len(parents)}")
    children = sorted(
        (record for record in records if record["parent"] == parent_id),
        key=lambda record: str(record["started"]),
    )
    return parents[0], children


def write_codex_evidence(
    path: Path | None, parent: dict[str, Any], children: list[dict[str, Any]]
) -> None:
    if path is None:
        return
    evidence = {
        "parent": {
            "id": parent["id"],
            "started": parent["started"],
            "completed": parent["completed"],
            "model": parent["model"],
            "collaboration_calls": parent["collaboration_calls"],
            "task_packet_observability": "encrypted-unavailable",
        },
        "children": [
            {
                "id": child["id"],
                "parent": child["parent"],
                "agent_path": child["agent_path"],
                "agent_role": child["agent_role"],
                "started": child["started"],
                "completed": child["completed"],
                "model": child["model"],
                "registered_prompt_marker": (
                    "Agent prompt source: docs/agent-core/" in child["developer_text"]
                ),
                "forbidden_calls": child["forbidden_calls"],
                "output": child["output"],
            }
            for child in children
        ],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(evidence, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def assert_codex_models(
    parent: dict[str, Any], children: list[dict[str, Any]], expected_model: str | None,
    label: str,
) -> None:
    actual_models = [parent.get("model"), *(child.get("model") for child in children)]
    if any(not model for model in actual_models):
        fail(f"{label}: one or more stored rollouts lack turn_context model provenance")
    unique_models = set(actual_models)
    if len(unique_models) != 1:
        fail(f"{label}: parent and child rollout models differ: {actual_models!r}")
    if expected_model and unique_models != {expected_model}:
        fail(
            f"{label}: runtime model {next(iter(unique_models))!r} does not match "
            f"requested model {expected_model!r}"
        )


def check_codex_selector(
    events: list[dict[str, Any]], sessions_root: Path, evidence_output: Path | None,
    expected_model: str | None = None,
) -> None:
    parent, children = codex_rollout_graph(events, sessions_root)
    write_codex_evidence(evidence_output, parent, children)
    assert_codex_models(parent, children, expected_model, "codex selector")
    if len(children) != 1:
        fail(f"codex selector: expected one direct child rollout, got {len(children)}")
    selector_calls = [call["name"] for call in parent["collaboration_calls"]]
    if selector_calls != ["spawn_agent", "wait_agent"]:
        fail(f"codex selector: unexpected stored collaboration sequence {selector_calls!r}")
    child = children[0]
    if child["agent_role"] != "oh-no-planner":
        fail(f"codex selector: expected registered oh-no-planner role, got {child['agent_role']!r}")
    if "Agent prompt source: docs/agent-core/planner.md" not in child["developer_text"]:
        fail("codex selector: stored child rollout lacks the registered Planner developer prompt")
    if not child["completed"] or not child["output"].strip():
        fail("codex selector: child did not produce a captured final result")
    if child["forbidden_calls"]:
        fail(f"codex selector: child used tools {child['forbidden_calls']!r}")
    if not parent["completed"] or str(child["completed"]) > str(parent["completed"]):
        fail("codex selector: parent completed before the child final result")


def check_codex(
    events: list[dict[str, Any]], sessions_root: Path, evidence_output: Path | None,
    handoff_nonce: str, expected_model: str | None = None,
) -> None:
    forbidden_commands: list[int] = []

    for index, data in enumerate(events, 1):
        item = data.get("item") or {}
        payload = data.get("payload") or {}
        if item.get("type") == "command_execution" and not is_generated_wrapper_read(item):
            forbidden_commands.append(index)
        if item.get("type") == "mcp_tool_call" and not is_generated_wrapper_mcp_read(item):
            forbidden_commands.append(index)
        if payload.get("type") == "function_call" and payload.get("name") in {
            "exec_command",
            "functions.exec_command",
        }:
            forbidden_commands.append(index)
    if forbidden_commands:
        fail(f"codex: read-only v2 lane executed shell commands at events {forbidden_commands}")
    parent, children = codex_rollout_graph(events, sessions_root)
    write_codex_evidence(evidence_output, parent, children)
    assert_codex_models(parent, children, expected_model, "codex")
    expected_roles = ["oh-no-planner", "oh-no-plan-reviewer"]
    actual_roles = [child["agent_role"] for child in children]
    if actual_roles != expected_roles:
        fail(f"codex: expected registered role order {expected_roles!r}, got {actual_roles!r}")
    planner, reviewer = children
    expected_calls = ["spawn_agent", "wait_agent", "spawn_agent", "wait_agent"]
    actual_calls = [call["name"] for call in parent["collaboration_calls"]]
    if actual_calls != expected_calls:
        fail(f"codex: expected stored collaboration sequence {expected_calls!r}, got {actual_calls!r}")
    expected_role_prompts = (
        (planner, "Agent prompt source: docs/agent-core/planner.md"),
        (reviewer, "Agent prompt source: docs/agent-core/plan-reviewer.md"),
    )
    for child, marker in expected_role_prompts:
        if marker not in child["developer_text"]:
            fail(f"codex: registered role prompt marker missing from {child['agent_role']!r} rollout")
    if not planner["completed"] or not reviewer["completed"]:
        fail("codex: one or more role children lack task_complete evidence")
    if str(planner["completed"]) >= str(reviewer["started"]):
        fail("codex: Plan-Reviewer started before Planner task_complete")
    if str(parent["collaboration_calls"][2]["timestamp"]) <= str(planner["completed"]):
        fail("codex: stored Plan-Reviewer spawn did not follow Planner task_complete")
    if not parent["completed"] or str(reviewer["completed"]) > str(parent["completed"]):
        fail("codex: parent completed before Plan-Reviewer task_complete")
    for child in children:
        if child["forbidden_calls"]:
            fail(f"codex: role child used tools {child['forbidden_calls']!r}")
    role_outputs = {
        "planner": str(planner["output"]),
        "plan-reviewer": str(reviewer["output"]),
    }
    if any(not value.strip() for value in role_outputs.values()):
        fail(f"codex: missing role outputs: {role_outputs!r}")
    assert_relational_outputs(role_outputs, "codex", handoff_nonce)


def check_claude(events: list[dict[str, Any]], handoff_nonce: str) -> None:
    tool_uses: list[tuple[int, str, dict[str, Any]]] = []
    all_agent_calls: list[tuple[int, str]] = []
    started: dict[str, int] = {}
    task_role: dict[str, str] = {}
    completed: dict[str, int] = {}
    outputs: dict[str, list[str]] = defaultdict(list)
    forbidden_tools: list[tuple[int, str]] = []
    init_agents: set[str] = set()
    init_tools: set[str] = set()
    init_permission_mode: str | None = None
    parent_completed: int | None = None
    permission_denials: list[Any] = []

    for index, data in enumerate(events, 1):
        if data.get("type") == "system" and data.get("subtype") == "init":
            init_agents = set(data.get("agents", []))
            init_tools = set(data.get("tools", []))
            init_permission_mode = data.get("permissionMode")
        if data.get("type") == "result" and data.get("subtype") == "success":
            parent_completed = index
            permission_denials.extend(data.get("permission_denials") or [])
        if data.get("type") == "assistant":
            for part in data.get("message", {}).get("content", []):
                if part.get("type") == "text":
                    subagent = data.get("subagent_type", "")
                    if subagent.startswith("oh-no-harness:"):
                        append_unique_output(
                            outputs, subagent.split(":", 1)[1], part.get("text", "")
                        )
                    continue
                if part.get("type") != "tool_use":
                    continue
                name = part.get("name", "")
                payload = part.get("input") or {}
                if name in {"Agent", "Task"}:
                    subagent = str(payload.get("subagent_type", ""))
                    all_agent_calls.append((index, subagent))
                    if subagent.startswith("oh-no-harness:"):
                        role = subagent.split(":", 1)[1]
                        tool_uses.append((index, role, payload))
                elif name == "Read":
                    read_path = str(payload.get("file_path") or payload.get("path") or "")
                    if not read_path.endswith("skills-claude/ralplan-v2/SKILL.md"):
                        forbidden_tools.append((index, f"Read:{read_path}"))
                else:
                    forbidden_tools.append((index, name))
        if data.get("type") == "system" and data.get("subtype") == "task_started":
            subagent = data.get("subagent_type", "")
            if subagent.startswith("oh-no-harness:"):
                role = subagent.split(":", 1)[1]
                task_id = data.get("task_id")
                if task_id:
                    started[role] = index
                    task_role[task_id] = role
        if data.get("type") == "system" and data.get("subtype") in {
            "task_updated",
            "task_notification",
        }:
            role = task_role.get(data.get("task_id"))
            status = data.get("status") or (data.get("patch") or {}).get("status")
            if role:
                if status == "completed":
                    completed.setdefault(role, index)
        result = data.get("tool_use_result") or {}
        if isinstance(result, dict):
            subagent = result.get("agentType", "")
            if subagent.startswith("oh-no-harness:"):
                role = subagent.split(":", 1)[1]
                append_unique_output(outputs, role, result.get("content", result))
                if result.get("status") == "completed":
                    completed.setdefault(role, index)

    required_agents = {f"oh-no-harness:{role}" for role in ROLES}
    if not required_agents.issubset(init_agents):
        fail(f"claude: required plugin agents unavailable: {sorted(required_agents - init_agents)}")
    unexpected_capabilities = init_tools - {"Read", "Task", "Agent"}
    if unexpected_capabilities:
        fail(f"claude: v2 lane exposed non-allowlisted tools: {sorted(unexpected_capabilities)!r}")
    if init_permission_mode != "dontAsk":
        fail(f"claude: v2 lane must run without bypass under dontAsk, got {init_permission_mode!r}")
    if permission_denials:
        fail(f"claude: v2 lane had permission denials: {permission_denials!r}")
    if forbidden_tools:
        fail(f"claude: v2 lane used forbidden tools or external reads: {forbidden_tools!r}")
    if len(all_agent_calls) != 2:
        fail(f"claude: expected exactly two total Agent/Task calls, got {all_agent_calls!r}")
    if [role for _, role, _ in tool_uses] != list(ROLES):
        fail(f"claude: expected exactly {list(ROLES)!r}, got {[t[1] for t in tool_uses]!r}")
    if set(started) != set(ROLES) or set(completed) != set(ROLES):
        fail(f"claude: missing started/completed role evidence: started={started!r} completed={completed!r}")
    if completed["planner"] >= tool_uses[1][0]:
        fail("claude: Plan-Reviewer started before Planner completion")
    if parent_completed is None or completed["plan-reviewer"] >= parent_completed:
        fail("claude: parent completed before Plan-Reviewer completion")

    role_packets = {role: collect_text(payload) for _, role, payload in tool_uses}
    role_outputs = {role: "\n".join(outputs[role]) for role in ROLES}
    if any(not value for value in role_outputs.values()):
        fail(f"claude: missing role outputs: {role_outputs!r}")
    assert_relational_handoff(role_packets, role_outputs, "claude", handoff_nonce)


def expect_failure(callback: Any, label: str) -> None:
    try:
        callback()
    except SystemExit:
        return
    fail(f"self-test mutation unexpectedly passed: {label}")


def claude_self_test_events(handoff_nonce: str) -> list[dict[str, Any]]:
    contract = "\n".join(
        (
            CONTRACT_START,
            "Goal: persist bounded preference updates",
            "AC1: valid writes return 200",
            "AC2: storage failures return 503",
            CONTRACT_END,
        )
    )
    profile = "\n".join(
        (
            "Execution profile:",
            "- Overall Ralph mode: STANDARD",
            "- Mode source: ralplan",
            "- Verification tier: STANDARD",
            "- Artifact policy: session-verification",
            "- Agent policy: inline-only",
            "- Parallel trigger: none",
            "- Worktree policy: direct-automatic-worktree",
            "- Worktree location: .oh-no/worktrees/preferences-write-v2",
            "- Cleanup policy: not-needed",
            "- Task sizing: T1 STANDARD - bounded behavior change",
            "- Escalation triggers: ownership contradiction; public-contract drift",
        )
    )
    draft = "\n".join(
        (
            DRAFT_START,
            "Planner draft id: live-v2-draft",
            f"Handoff nonce: {handoff_nonce}",
            contract,
            "Approach: update handler and storage boundary",
            "Verification: focused AC-mapped tests",
            profile,
            DRAFT_END,
        )
    )
    planner_packet = "\n".join(
        (
            "RALPLAN_V2_ROLE: planner",
            f"Handoff nonce: {handoff_nonce}",
            contract,
            profile,
        )
    )
    reviewer_packet = "\n".join(
        (
            "RALPLAN_V2_ROLE: plan-reviewer",
            contract,
            draft,
        )
    )
    reviewer_output = "\n".join((contract, draft, VERDICT_TOKEN))
    return [
        {
            "type": "system",
            "subtype": "init",
            "tools": ["Read", "Agent"],
            "agents": ["oh-no-harness:planner", "oh-no-harness:plan-reviewer"],
            "permissionMode": "dontAsk",
        },
        {
            "type": "assistant",
            "message": {"content": [{"type": "tool_use", "name": "Agent", "input": {
                "subagent_type": "oh-no-harness:planner", "prompt": planner_packet,
            }}]},
        },
        {"type": "system", "subtype": "task_started", "task_id": "p", "subagent_type": "oh-no-harness:planner"},
        {
            "type": "assistant",
            "subagent_type": "oh-no-harness:planner",
            "message": {"content": [{"type": "text", "text": draft}]},
        },
        {"type": "system", "subtype": "task_notification", "task_id": "p", "status": "completed"},
        {
            "type": "assistant",
            "message": {"content": [{"type": "tool_use", "name": "Agent", "input": {
                "subagent_type": "oh-no-harness:plan-reviewer", "prompt": reviewer_packet,
            }}]},
        },
        {"type": "system", "subtype": "task_started", "task_id": "r", "subagent_type": "oh-no-harness:plan-reviewer"},
        {
            "type": "assistant",
            "subagent_type": "oh-no-harness:plan-reviewer",
            "message": {"content": [{"type": "text", "text": reviewer_output}]},
        },
        {"type": "system", "subtype": "task_notification", "task_id": "r", "status": "completed"},
        {"type": "result", "subtype": "success"},
    ]


def write_jsonl(path: Path, events: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "".join(json.dumps(event, ensure_ascii=False) + "\n" for event in events),
        encoding="utf-8",
    )


def codex_self_test_fixture(
    root: Path, handoff_nonce: str, mutation: str | None = None
) -> tuple[list[dict[str, Any]], Path, Path]:
    contract = "\n".join(
        (
            CONTRACT_START,
            "Goal: persist bounded preference updates",
            "AC1: valid writes return 200",
            "AC2: storage failures return 503",
            CONTRACT_END,
        )
    )
    profile = "\n".join(
        (
            "Execution profile:",
            "- Overall Ralph mode: STANDARD",
            "- Mode source: ralplan",
            "- Verification tier: STANDARD",
            "- Artifact policy: session-verification",
            "- Agent policy: inline-only",
            "- Parallel trigger: none",
            "- Worktree policy: direct-automatic-worktree",
            "- Worktree location: .oh-no/worktrees/preferences-write-v2",
            "- Cleanup policy: not-needed",
            "- Task sizing: T1 STANDARD - bounded behavior change",
            "- Escalation triggers: ownership contradiction; public-contract drift",
        )
    )
    draft = "\n".join(
        (
            DRAFT_START,
            "Planner draft id: live-v2-draft",
            f"Handoff nonce: {handoff_nonce}",
            contract,
            "Approach: update handler and storage boundary",
            "Verification: focused AC-mapped tests",
            profile,
            DRAFT_END,
        )
    )
    reviewer_output = "\n".join((contract, draft, VERDICT_TOKEN))
    sessions_root = root / "sessions"
    parent_id = "codex-self-test-parent"

    parent_events: list[dict[str, Any]] = [
        {
            "timestamp": "2026-01-01T00:00:00Z",
            "type": "session_meta",
            "payload": {
                "id": parent_id,
                "timestamp": "2026-01-01T00:00:00Z",
                "source": {},
            },
        },
        {
            "timestamp": "2026-01-01T00:00:00.100000Z",
            "type": "turn_context",
            "payload": {"model": "gpt-5.6-sol"},
        },
        {
            "timestamp": "2026-01-01T00:00:01Z",
            "type": "response_item",
            "payload": {"type": "function_call", "namespace": "agents", "name": "spawn_agent"},
        },
        {
            "timestamp": "2026-01-01T00:00:02Z",
            "type": "response_item",
            "payload": {"type": "function_call", "namespace": "agents", "name": "wait_agent"},
        },
        {
            "timestamp": "2026-01-01T00:00:04Z",
            "type": "response_item",
            "payload": {"type": "function_call", "namespace": "agents", "name": "spawn_agent"},
        },
        {
            "timestamp": "2026-01-01T00:00:05Z",
            "type": "response_item",
            "payload": {"type": "function_call", "namespace": "agents", "name": "wait_agent"},
        },
        {
            "timestamp": "2026-01-01T00:00:10Z",
            "type": "event_msg",
            "payload": {"type": "task_complete", "last_agent_message": "parent complete"},
        },
    ]

    def child_events(
        child_id: str,
        role: str,
        started: str,
        completed: str,
        prompt_marker: str,
        output: str,
    ) -> list[dict[str, Any]]:
        return [
            {
                "timestamp": started,
                "type": "session_meta",
                "payload": {
                    "id": child_id,
                    "parent_thread_id": parent_id,
                    "timestamp": started,
                    "source": {
                        "subagent": {
                            "thread_spawn": {
                                "parent_thread_id": parent_id,
                                "agent_path": f"/tmp/{role}.toml",
                                "agent_role": role,
                            }
                        }
                    },
                },
            },
            {
                "timestamp": started,
                "type": "turn_context",
                "payload": {"model": "gpt-5.6-sol"},
            },
            {
                "timestamp": started,
                "type": "response_item",
                "payload": {
                    "type": "message",
                    "role": "developer",
                    "content": [{"type": "input_text", "text": prompt_marker}],
                },
            },
            {
                "timestamp": completed,
                "type": "event_msg",
                "payload": {"type": "task_complete", "last_agent_message": output},
            },
        ]

    planner_events = child_events(
        "codex-self-test-planner",
        "oh-no-planner",
        "2026-01-01T00:00:01.100000Z",
        "2026-01-01T00:00:03Z",
        "Agent prompt source: docs/agent-core/planner.md",
        draft,
    )
    reviewer_events = child_events(
        "codex-self-test-reviewer",
        "oh-no-plan-reviewer",
        "2026-01-01T00:00:04.100000Z",
        "2026-01-01T00:00:06Z",
        "Agent prompt source: docs/agent-core/plan-reviewer.md",
        reviewer_output,
    )

    if mutation == "role-order":
        planner_events[0]["payload"]["source"]["subagent"]["thread_spawn"]["agent_role"] = "oh-no-plan-reviewer"
        reviewer_events[0]["payload"]["source"]["subagent"]["thread_spawn"]["agent_role"] = "oh-no-planner"
    elif mutation == "collaboration-sequence":
        del parent_events[4]
    elif mutation == "reviewer-before-planner-complete":
        reviewer_events[0]["timestamp"] = "2026-01-01T00:00:02.500000Z"
        reviewer_events[0]["payload"]["timestamp"] = "2026-01-01T00:00:02.500000Z"
    elif mutation == "forbidden-child-tool":
        planner_events.insert(
            -1,
            {
                "timestamp": "2026-01-01T00:00:02Z",
                "type": "response_item",
                "payload": {"type": "function_call", "namespace": "functions", "name": "exec_command"},
            },
        )
    elif mutation == "missing-reviewer-completion":
        reviewer_events = [
            event
            for event in reviewer_events
            if not (
                event.get("type") == "event_msg"
                and (event.get("payload") or {}).get("type") == "task_complete"
            )
        ]
    elif mutation == "model-mismatch":
        reviewer_events[1]["payload"]["model"] = "unexpected-model"
    elif mutation is not None:
        fail(f"unknown Codex self-test mutation: {mutation}")

    write_jsonl(sessions_root / "parent.jsonl", parent_events)
    write_jsonl(sessions_root / "planner.jsonl", planner_events)
    write_jsonl(sessions_root / "reviewer.jsonl", reviewer_events)
    transcript = [{"type": "thread.started", "thread_id": parent_id}]
    evidence = root / "evidence.json"
    return transcript, sessions_root, evidence


def run_self_test() -> None:
    nonce = "0123456789abcdef01234567"
    valid = claude_self_test_events(nonce)
    check_claude(valid, nonce)

    extra_agent = copy.deepcopy(valid)
    extra_agent.insert(
        -1,
        {"type": "assistant", "message": {"content": [{
            "type": "tool_use", "name": "Agent",
            "input": {"subagent_type": "general-purpose", "prompt": "unexpected"},
        }]}},
    )
    expect_failure(lambda: check_claude(extra_agent, nonce), "generic extra Agent call")

    missing_reviewer_completion = [
        event for event in copy.deepcopy(valid)
        if not (
            event.get("subtype") == "task_notification"
            and event.get("task_id") == "r"
        )
    ]
    expect_failure(
        lambda: check_claude(missing_reviewer_completion, nonce),
        "missing Reviewer completion",
    )

    extra_capability = copy.deepcopy(valid)
    extra_capability[0]["tools"].append("Bash")
    expect_failure(lambda: check_claude(extra_capability, nonce), "extra exposed capability")

    malformed_profile = copy.deepcopy(valid)
    for event in malformed_profile:
        serialized = json.dumps(event)
        serialized = serialized.replace(
            "- Agent policy: inline-only", "- Agent policy: full-review-set"
        )
        event.clear()
        event.update(json.loads(serialized))
    expect_failure(lambda: check_claude(malformed_profile, nonce), "malformed execution profile")

    missing_nonce = copy.deepcopy(valid)
    for event in missing_nonce:
        serialized = json.dumps(event).replace(f"Handoff nonce: {nonce}\\n", "")
        event.clear()
        event.update(json.loads(serialized))
    expect_failure(lambda: check_claude(missing_nonce, nonce), "missing handoff nonce")

    conflicting_verdict = copy.deepcopy(valid)
    conflicting_verdict[-3]["message"]["content"][0]["text"] += "\nVERDICT_REJECT"
    expect_failure(lambda: check_claude(conflicting_verdict, nonce), "conflicting verdict token")

    safe_mcp_read = {
        "server": "node_repl",
        "tool": "js",
        "arguments": {
            "code": (
                'var fsV2 = await import("node:fs/promises"); '
                'var textV2 = await fsV2.readFile('
                '"/tmp/codex-home/plugins/cache/oh-no/1/skills/ralplan-v2/SKILL.md", '
                '"utf8"); nodeRepl.write(textV2);'
            )
        },
    }
    if not is_generated_wrapper_mcp_read(safe_mcp_read):
        fail("self-test safe native MCP wrapper read was rejected")
    multiline_mcp_read = copy.deepcopy(safe_mcp_read)
    multiline_mcp_read["arguments"]["code"] = multiline_mcp_read["arguments"]["code"].replace(
        "; ", ";\n"
    )
    if not is_generated_wrapper_mcp_read(multiline_mcp_read):
        fail("self-test multiline native MCP wrapper read was rejected")
    unsafe_mcp_read = copy.deepcopy(safe_mcp_read)
    unsafe_mcp_read["arguments"]["code"] += ' await fsV2.writeFile("/tmp/x", textV2);'
    if is_generated_wrapper_mcp_read(unsafe_mcp_read):
        fail("self-test write-capable MCP wrapper mutation unexpectedly passed")

    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        codex_events, sessions_root, evidence = codex_self_test_fixture(
            root / "valid", nonce
        )
        check_codex(codex_events, sessions_root, evidence, nonce, "gpt-5.6-sol")
        evidence_payload = json.loads(evidence.read_text(encoding="utf-8"))
        if (
            evidence_payload.get("parent", {}).get("task_packet_observability")
            != "encrypted-unavailable"
        ):
            fail("Codex evidence self-test overstated encrypted task-packet visibility")

        for mutation, label in (
            ("role-order", "Codex registered role order"),
            ("collaboration-sequence", "Codex stored collaboration sequence"),
            ("reviewer-before-planner-complete", "Codex role completion order"),
            ("forbidden-child-tool", "Codex forbidden child tool"),
            ("missing-reviewer-completion", "Codex missing Reviewer completion"),
            ("model-mismatch", "Codex parent/child model mismatch"),
        ):
            mutated_events, mutated_sessions, mutated_evidence = codex_self_test_fixture(
                root / mutation, nonce, mutation
            )
            expect_failure(
                lambda events=mutated_events, sessions=mutated_sessions, evidence_path=mutated_evidence: check_codex(
                    events, sessions, evidence_path, nonce, "gpt-5.6-sol"
                ),
                label,
            )
    print("ok - Ralplan v2 live checker mutation self-tests")


def main() -> None:
    if sys.argv[1:] == ["--self-test"]:
        run_self_test()
        return

    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", choices=("codex", "claude"), required=True)
    parser.add_argument("--phase", choices=("selector", "workflow"), default="workflow")
    parser.add_argument("--wrapper", type=Path)
    parser.add_argument("--transcript", type=Path, required=True)
    parser.add_argument("--sessions-root", type=Path)
    parser.add_argument("--evidence-output", type=Path)
    parser.add_argument("--handoff-nonce")
    parser.add_argument("--expected-model")
    args = parser.parse_args()

    events = load_jsonl(args.transcript)
    if args.phase == "selector":
        if args.platform != "codex" or args.sessions_root is None:
            fail("selector phase requires --platform codex and --sessions-root")
        check_codex_selector(
            events, args.sessions_root, args.evidence_output, args.expected_model
        )
        print("ok - live Codex custom-agent selector and role ownership")
        return

    if args.wrapper is None:
        fail("workflow phase requires --wrapper")
    if not args.handoff_nonce:
        fail("workflow phase requires --handoff-nonce")
    check_wrapper(args.wrapper, args.platform)
    if args.platform == "codex":
        if args.sessions_root is None:
            fail("--sessions-root is required for Codex role-ownership proof")
        check_codex(
            events, args.sessions_root, args.evidence_output, args.handoff_nonce,
            args.expected_model,
        )
    else:
        check_claude(events, args.handoff_nonce)
    print(f"ok - live {args.platform} Ralplan v2 runtime-event contract")


if __name__ == "__main__":
    main()
