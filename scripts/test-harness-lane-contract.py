#!/usr/bin/env python3
"""Validate deterministic Oh No Harness test-lane semantics.

This check is intentionally static and fixture-backed. It does not ask a model
to reproduce exact smoke-test wording; it verifies that each harness lane has a
machine-readable owner/flag contract and that hard failures cannot be converted
into soft variance by marker-only evidence.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

PLUGIN_NAME = "oh-no-harness"
DOC_RELATIVE = Path("docs/reference/test-harness-lanes.md")

REQUIRED_FIELDS = {
    "host",
    "owner",
    "flag",
    "release_status",
    "hard_failures",
    "warnings",
    "evidence_artifact",
    "non_proofs",
}

STATIC_ROWS = {
    ("static", "scripts/release", "default"),
    ("static", "scripts/validate-plugin-files.py", "default"),
    ("static", "scripts/check-skill-reachability.py", "default"),
}

CONTROL_FLAGS = {
    "codex": {
        "--skip-live",
        "--no-install",
        "--codex-home",
        "--model",
        "--marketplace-source",
        "--help",
    },
    "claude": {
        "--skip-live",
        "--no-install",
        "--scope",
        "--live-load",
        "--marketplace-source",
        "--model",
        "--max-budget-usd",
        "--help",
    },
}

VARIANCE_WARNINGS = {
    "model paraphrase variance",
    "semantic marker variance",
    "AskUserQuestion tool-list exposure",
    "auto-routing model echo",
    "post-completion observation gap",
}

HARD_CLASSES = {
    "install/load",
    "command invocation",
    "tool/permission",
    "lifecycle",
    "malformed output",
    "host-boundary",
    "containment",
    "worktree",
    "forensic invariant",
    "hook policy",
    "generated-wrapper freshness",
    "manifest/source assertion",
    "reachability-contract",
    "release default expansion",
}

RELEASE_STATUSES = {
    "release-static",
    "default-static",
    "opt-in-live",
}

LIVE_HARD_REQUIREMENTS = {
    "--live": {"malformed output"},
    "--deep-live": {"malformed output"},
    "--parallel-live": {"lifecycle", "forensic invariant"},
    "--ralplan-live": {"lifecycle", "forensic invariant"},
    "--named-agents-live": {"lifecycle", "forensic invariant"},
    "--fusion-rescue-live": {"lifecycle", "host-boundary", "forensic invariant"},
    "--cross-host-fallback-live": {"lifecycle", "host-boundary", "containment", "forensic invariant"},
    "--cross-host-review-live": {"lifecycle", "host-boundary", "forensic invariant"},
    "--ralplan-xhost-live": {"lifecycle", "host-boundary", "forensic invariant"},
    "--vbc-xhost-live": {"lifecycle", "host-boundary", "forensic invariant"},
    "--sysdebug-xhost-live": {"lifecycle", "host-boundary", "forensic invariant"},
    "--simplify-live": {"lifecycle", "forensic invariant"},
    "--natural-session-start-live": {"lifecycle", "hook policy", "forensic invariant"},
    "--worktree-live": {"lifecycle", "worktree", "containment", "forensic invariant"},
    "--live-hook-only": {"hook policy", "malformed output"},
    "--parallel-executor-live": {"lifecycle", "containment", "forensic invariant"},
    "--codex-executor-delegation-live": {
        "lifecycle",
        "containment",
        "worktree",
        "host-boundary",
        "forensic invariant",
    },
}

LIVE_BASELINE_HARD_REQUIREMENTS = {"install/load", "command invocation", "tool/permission"}

SEMANTIC_WARNINGS = {
    "model paraphrase variance",
    "semantic marker variance",
}

LIVE_ENV_BY_HOST = {
    "codex": {
        "OH_NO_LIVE",
        "OH_NO_DEEP_LIVE",
        "OH_NO_PARALLEL_LIVE",
        "OH_NO_RALPLAN_LIVE",
        "OH_NO_RALPLAN_V2_LIVE",
        "OH_NO_NAMED_AGENTS_LIVE",
        "OH_NO_FUSION_RESCUE_LIVE",
        "OH_NO_CODEX_CROSS_HOST_FALLBACK_LIVE",
        "OH_NO_SIMPLIFY_LIVE",
        "OH_NO_NATURAL_SESSION_START_LIVE",
        "OH_NO_WORKTREE_LIVE",
    },
    "claude": {
        "OH_NO_LIVE",
        "OH_NO_DEEP_LIVE",
        "OH_NO_PARALLEL_LIVE",
        "OH_NO_RALPLAN_LIVE",
        "OH_NO_RALPLAN_V2_LIVE",
        "OH_NO_FUSION_RESCUE_LIVE",
        "OH_NO_CROSS_HOST_FALLBACK_LIVE",
        "OH_NO_CROSS_HOST_REVIEW_LIVE",
        "OH_NO_RALPLAN_XHOST_LIVE",
        "OH_NO_VBC_XHOST_LIVE",
        "OH_NO_SYSDEBUG_XHOST_LIVE",
        "OH_NO_PARALLEL_EXECUTOR_LIVE",
        "OH_NO_SIMPLIFY_LIVE",
        "OH_NO_NATURAL_SESSION_START_LIVE",
        "OH_NO_LIVE_HOOK_ONLY",
    },
}


def die(message: str) -> None:
    print(f"FAIL - {message}", file=sys.stderr)
    raise SystemExit(1)


def find_marketplace_root(start: Path) -> Path:
    start = start.resolve()
    candidates = [start, *start.parents]
    for candidate in candidates:
        if (
            (candidate / "scripts" / "test-codex-plugin.sh").is_file()
            and (candidate / "scripts" / "test-claude-plugin.sh").is_file()
            and (candidate / "scripts" / "release").is_file()
        ):
            return candidate
    die(f"could not locate marketplace root from {start}")


def find_plugin_root(marketplace_root: Path, plugin_root: Path | None) -> Path:
    if plugin_root is not None:
        return plugin_root.resolve()
    nested = marketplace_root / "plugins" / PLUGIN_NAME
    if nested.exists():
        return nested.resolve()
    return marketplace_root.resolve()


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        die(f"missing or unreadable file: {path} ({exc})")


def extract_matrix_json(doc_text: str, doc_path: Path) -> dict[str, Any]:
    match = re.search(r"```json\s*(\{.*?\})\s*```", doc_text, flags=re.S)
    if not match:
        die(f"{doc_path} is missing a fenced JSON lane matrix")
    try:
        data = json.loads(match.group(1))
    except json.JSONDecodeError as exc:
        die(f"{doc_path} has invalid lane matrix JSON: {exc}")
    if not isinstance(data, dict):
        die(f"{doc_path} lane matrix must be a JSON object")
    return data


def top_level_case_block(script_text: str, script_path: Path) -> str:
    match = re.search(
        r"while \[\[ \$# -gt 0 \]\]; do\s*case \"\$1\" in(?P<body>.*?)\n\s*esac\n\s*done",
        script_text,
        flags=re.S,
    )
    if not match:
        die(f"{script_path} top-level option parser was not found")
    return match.group("body")


def parsed_top_level_options(script_path: Path) -> set[str]:
    body = top_level_case_block(read_text(script_path), script_path)
    options: set[str] = set()
    for line in body.splitlines():
        stripped = line.strip()
        if ")" not in stripped:
            continue
        head = stripped.split(")", 1)[0]
        for part in head.split("|"):
            part = part.strip()
            if re.fullmatch(r"--[a-z0-9-]+", part):
                options.add(part)
    return options


def expected_lane_keys(marketplace_root: Path) -> set[tuple[str, str, str]]:
    codex_script = marketplace_root / "scripts" / "test-codex-plugin.sh"
    claude_script = marketplace_root / "scripts" / "test-claude-plugin.sh"
    codex_flags = parsed_top_level_options(codex_script) - CONTROL_FLAGS["codex"]
    claude_flags = parsed_top_level_options(claude_script) - CONTROL_FLAGS["claude"]
    expected = set(STATIC_ROWS)
    expected.add(("codex", "scripts/test-codex-plugin.sh", "default"))
    expected.add(("claude", "scripts/test-claude-plugin.sh", "default"))
    expected.update(("codex", "scripts/test-codex-plugin.sh", flag) for flag in sorted(codex_flags))
    expected.update(("claude", "scripts/test-claude-plugin.sh", flag) for flag in sorted(claude_flags))
    return expected


def validate_row_shape(row: Any, index: int) -> dict[str, Any]:
    if not isinstance(row, dict):
        die(f"lane row {index} must be an object")
    missing = REQUIRED_FIELDS - row.keys()
    extra = row.keys() - REQUIRED_FIELDS
    if missing:
        die(f"lane row {index} is missing fields: {sorted(missing)}")
    if extra:
        die(f"lane row {index} has unsupported fields: {sorted(extra)}")
    for field in ("host", "owner", "flag", "release_status", "evidence_artifact"):
        if not isinstance(row[field], str) or not row[field].strip():
            die(f"lane row {index} field {field!r} must be a non-empty string")
    if row["release_status"] not in RELEASE_STATUSES:
        die(f"lane row {index} has unsupported release_status: {row['release_status']!r}")
    for field in ("hard_failures", "warnings", "non_proofs"):
        if not isinstance(row[field], list) or not all(isinstance(item, str) and item.strip() for item in row[field]):
            die(f"lane row {index} field {field!r} must be a list of non-empty strings")
    unknown_hard = set(row["hard_failures"]) - HARD_CLASSES
    if unknown_hard:
        die(f"lane row {index} has unknown hard failure classes: {sorted(unknown_hard)}")
    unknown_warnings = set(row["warnings"]) - VARIANCE_WARNINGS
    if unknown_warnings:
        die(f"lane row {index} has unsupported warning classes: {sorted(unknown_warnings)}")
    if "marker-only output" not in row["non_proofs"]:
        die(f"lane row {index} must explicitly list marker-only output as a non-proof")
    return row


def expected_release_status(row: dict[str, Any]) -> str:
    if row["host"] == "static":
        return "default-static"
    if row["flag"] == "default":
        return "release-static"
    return "opt-in-live"


def validate_row_semantics(row: dict[str, Any]) -> None:
    expected_status = expected_release_status(row)
    if row["release_status"] != expected_status:
        die(
            f"lane {(row['host'], row['owner'], row['flag'])} has "
            f"release_status={row['release_status']!r}, expected {expected_status!r}"
        )
    required_hard = set()
    if row["host"] in {"codex", "claude"} and row["flag"] == "default":
        required_hard = {"install/load", "manifest/source assertion", "generated-wrapper freshness", "hook policy"}
    elif row["host"] in {"codex", "claude"}:
        extra_hard = LIVE_HARD_REQUIREMENTS.get(row["flag"])
        if extra_hard is None:
            die(f"lane {(row['host'], row['owner'], row['flag'])} is missing a live hard-class policy entry")
        required_hard = LIVE_BASELINE_HARD_REQUIREMENTS | extra_hard
    elif row["owner"] == "scripts/release":
        required_hard = {"generated-wrapper freshness", "manifest/source assertion", "release default expansion"}
    elif row["owner"] == "scripts/validate-plugin-files.py":
        required_hard = {"generated-wrapper freshness", "manifest/source assertion", "reachability-contract", "hook policy"}
    elif row["owner"] == "scripts/check-skill-reachability.py":
        required_hard = {"reachability-contract", "manifest/source assertion"}
    missing = sorted(required_hard - set(row["hard_failures"]))
    if missing:
        die(f"lane {(row['host'], row['owner'], row['flag'])} is missing required hard classes: {missing}")


def load_lanes(plugin_root: Path) -> tuple[list[dict[str, Any]], str, Path]:
    doc_path = plugin_root / DOC_RELATIVE
    text = read_text(doc_path)
    data = extract_matrix_json(text, doc_path)
    if data.get("schema_version") != 1:
        die(f"{doc_path} schema_version must be 1")
    lanes = data.get("lanes")
    if not isinstance(lanes, list):
        die(f"{doc_path} lane matrix must define a lanes list")
    return [validate_row_shape(row, index) for index, row in enumerate(lanes)], text, doc_path


def lane_map(lanes: list[dict[str, Any]]) -> dict[tuple[str, str, str], dict[str, Any]]:
    result: dict[tuple[str, str, str], dict[str, Any]] = {}
    for row in lanes:
        key = (row["host"], row["owner"], row["flag"])
        if key in result:
            die(f"duplicate lane row: {key}")
        result[key] = row
    return result


def validate_matrix_coverage(marketplace_root: Path, lanes: list[dict[str, Any]]) -> dict[tuple[str, str, str], dict[str, Any]]:
    expected = expected_lane_keys(marketplace_root)
    indexed = lane_map(lanes)
    for row in indexed.values():
        validate_row_semantics(row)
    actual = set(indexed)
    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    if missing:
        die(f"lane matrix is missing current lane rows: {missing}")
    if extra:
        die(f"lane matrix contains rows with no current lane owner/flag: {extra}")
    return indexed


def logical_shell_lines(text: str) -> list[str]:
    result: list[str] = []
    current = ""
    for raw_line in text.splitlines():
        stripped = raw_line.rstrip()
        if not stripped or stripped.lstrip().startswith("#"):
            if current:
                result.append(current.strip())
                current = ""
            continue
        if stripped.endswith("\\"):
            current += stripped[:-1] + " "
            continue
        current += stripped
        result.append(current.strip())
        current = ""
    if current:
        result.append(current.strip())
    return result


def release_test_commands(release_text: str) -> dict[str, list[str]]:
    commands = {"codex": [], "claude": []}
    for command in logical_shell_lines(release_text):
        if "run scripts/test-codex-plugin.sh" in command:
            commands["codex"].append(command)
        if "run scripts/test-claude-plugin.sh" in command:
            commands["claude"].append(command)
    return commands


def assert_release_default_live_safe(marketplace_root: Path, lanes: dict[tuple[str, str, str], dict[str, Any]]) -> None:
    release_text = read_text(marketplace_root / "scripts" / "release")
    opt_in_flags = {
        flag
        for host, owner, flag in lanes
        if host in {"codex", "claude"} and owner.startswith("scripts/test-") and flag.startswith("--")
    }
    commands = release_test_commands(release_text)
    for host in ("codex", "claude"):
        if not commands[host]:
            die(f"scripts/release is missing the default {host} install test command")
        for command in commands[host]:
            forbidden = sorted(flag for flag in opt_in_flags if re.search(rf"(?<!\S){re.escape(flag)}(?!\S)", command))
            if forbidden:
                die(f"scripts/release default test command must not include opt-in live flag(s): {forbidden}")
            missing_env = sorted(name for name in LIVE_ENV_BY_HOST[host] if f"{name}=0" not in command)
            if missing_env:
                die(f"scripts/release default {host} test command must clear live env vars: {missing_env}")


def assert_codex_natural_session_role_order_wiring(marketplace_root: Path) -> None:
    script_path = marketplace_root / "scripts" / "test-codex-plugin.sh"
    script_text = read_text(script_path)
    wrapper = re.search(
        r"run_natural_session_start_live_skill_test\(\) \{(?P<body>.*?)\n\}",
        script_text,
        flags=re.S,
    )
    if not wrapper:
        die(f"{script_path} is missing run_natural_session_start_live_skill_test")
    body = wrapper.group("body")
    required_fragments = (
        'local role_order_mode="${5:-exact}"',
        '"$role_order_mode"',
    )
    for fragment in required_fragments:
        if fragment not in body:
            die(f"{script_path} natural SessionStart wrapper must preserve role_order_mode: missing {fragment!r}")

    systematic_call = re.search(
        r"run_natural_session_start_live_skill_test\s+\\\s*\n"
        r"\s+systematic-debugging\s+\\(?P<body>.*?grouped-fanout)",
        script_text,
        flags=re.S,
    )
    if not systematic_call:
        die(f"{script_path} systematic-debugging natural SessionStart lane must opt into grouped-fanout")

    ultrawork_call = re.search(
        r"run_natural_session_start_live_skill_test\s+\\\s*\n"
        r"\s+ultrawork\s+\\(?P<body>.*?ordered-optional)",
        script_text,
        flags=re.S,
    )
    if not ultrawork_call or "explore:,analyst?:,planner:,verifier:" not in ultrawork_call.group("body"):
        die(
            f"{script_path} Ultrawork natural SessionStart lane must allow only the "
            "source-authorized optional Analyst gap check"
        )
    for fragment in (
        'if role.endswith("?"):',
        "optional_roles.add(role)",
        'elif role_order_mode == "ordered-optional":',
        "expected_present_order = [role for role in expected_roles if role in ordered_roles]",
        "expected_present_order = [role for role in expected_roles if role in roles_seen]",
    ):
        if fragment not in script_text:
            die(
                f"{script_path} natural role parser must preserve ordered optional roles: "
                f"missing {fragment!r}"
            )


CODEX_HOME_ASSIGNMENT_RE = re.compile(
    r"(?m)(?:^|[;&|()\s])(?:export\s+)?CODEX_HOME\s*="
)


def shell_function_bodies(script_text: str) -> dict[str, str]:
    starts = list(
        re.finditer(
            r"(?m)^(?P<name>[A-Za-z_][A-Za-z0-9_]*)\(\) \{",
            script_text,
        )
    )
    bodies: dict[str, str] = {}
    for index, match in enumerate(starts):
        end = starts[index + 1].start() if index + 1 < len(starts) else len(script_text)
        bodies[match.group("name")] = script_text[match.end():end]
    return bodies


def codex_live_launch_policy_errors(script_text: str) -> list[str]:
    functions = shell_function_bodies(script_text)
    live_functions = {
        name: body
        for name, body in functions.items()
        if re.fullmatch(r"run_[a-z0-9_]*live[a-z0-9_]*tests?", name)
    }
    registry_match = re.search(
        r"(?ms)^ISOLATED_CODEX_LIVE_FUNCTIONS=\(\s*(?P<body>.*?)^\)",
        script_text,
    )
    if registry_match is None:
        return ["missing isolated Codex live-function registry"]
    isolated_functions = re.findall(
        r"(?m)^\s*(run_[a-z0-9_]+_live_test)\s*$", registry_match.group("body")
    )
    errors: list[str] = []
    if len(isolated_functions) != len(set(isolated_functions)):
        errors.append("isolated Codex live-function registry contains duplicates")

    for function_name, function_body in live_functions.items():
        if CODEX_HOME_ASSIGNMENT_RE.search(function_body):
            errors.append(
                f"{function_name} directly assigns CODEX_HOME instead of using a live-home runner"
            )
        if '"$CODEX_BIN"' in function_body and not any(
            runner in function_body
            for runner in (
                "run_codex_live_command",
                "run_in_verified_codex_live_home",
            )
        ):
            errors.append(
                f"{function_name} constructs a Codex launch without a live-home runner"
            )
        if (
            "clone_codex_live_home" in function_body
            and function_name not in isolated_functions
        ):
            errors.append(
                f"{function_name} clones a live home but is absent from the isolation registry"
            )

    for function_name in isolated_functions:
        function_body = live_functions.get(function_name)
        if function_body is None:
            errors.append(f"isolation registry names missing function {function_name}")
        elif "run_in_verified_codex_live_home" not in function_body:
            errors.append(
                f"{function_name} does not use run_in_verified_codex_live_home"
            )
    return errors


def assert_codex_live_isolation_contract(marketplace_root: Path) -> None:
    script_path = marketplace_root / "scripts" / "test-codex-plugin.sh"
    script_text = read_text(script_path)

    required_fragments = (
        "CODEX_HOME_SOURCE_DIR",
        "CODEX_ACTIVE_HOME_DIR",
        "CODEX_LIVE_TEMP_ROOTS",
        "CODEX_LIVE_CLONE_MARKER",
        "OH_NO_ISOLATE_CODEX_HOME",
        "OH_NO_ISOLATE_CODEX_HOME must be 0 or 1",
        "ISOLATED_CODEX_LIVE_FUNCTIONS",
        "isolated_codex_live_home_requested()",
        "validate_ralplan_live_option_compatibility()",
        "clone_codex_live_home()",
        "assert_codex_live_home_provenance()",
        "run_in_verified_codex_live_home()",
        "run_codex_live_command()",
        "validate_codex_live_clone_safety()",
        "Codex live command runner accepted an unverified disposable home",
        "active Codex agents root must not be a symlink",
        "active Codex config or agents changed during isolated live test",
        "prepare_isolated_codex_live_home()",
        "assert_no_codex_live_secret_leak()",
        "validate_codex_live_secret_scanner()",
        "Codex live secret scanner missed its credential fixture",
        "visible_line_parts",
        "is_public_url_slug",
        "public URL slug",
        "secret-like URL query value",
        "opaque encrypted transcript content",
        "visible secret-like fixture",
        "id_token",
        "session_token",
        "private_key",
        "trap cleanup_codex_live_temp_roots EXIT",
        'rm -rf "$dir"',
        'cp -p "$source_home/$config_file" "$target_home/$config_file"',
        'cp -Rp "$source_home/agents" "$target_home/agents"',
        "source_agents != target_agents",
        "isolated Codex live clone content mismatch",
        'chmod 600 "$target_home/auth.json"',
        'clone_codex_live_home "$CODEX_HOME_SOURCE_DIR" "$CODEX_HOME_DIR"',
        'clone_codex_live_home "$CODEX_HOME_DIR" "$live_home"',
        'run_in_verified_codex_live_home "$live_home"',
        'CODEX_HOME="$CODEX_HOME_DIR" "$PLUGIN_ROOT/scripts/install-codex-agents"',
    )
    for fragment in required_fragments:
        if fragment not in script_text:
            die(f"{script_path} Codex Ralplan live isolation is missing {fragment!r}")

    request_predicate = re.search(
        r"isolated_codex_live_home_requested\(\) \{(?P<body>.*?)\n\}",
        script_text,
        flags=re.S,
    )
    if not request_predicate:
        die(f"{script_path} is missing the Ralplan live isolation predicate")
    for required_flag in ("RUN_RALPLAN_LIVE", "FORCE_ISOLATED_CODEX_HOME"):
        if required_flag not in request_predicate.group("body"):
            die(f"{script_path} must scope cloned-home isolation to {required_flag}")
    for unrelated_flag in (
        "RUN_PARALLEL_LIVE",
        "RUN_NAMED_AGENTS_LIVE",
        "RUN_FUSION_RESCUE_LIVE",
        "RUN_CROSS_HOST_FALLBACK_LIVE",
        "RUN_SIMPLIFY_LIVE",
        "RUN_NATURAL_SESSION_START_LIVE",
    ):
        if unrelated_flag in request_predicate.group("body"):
            die(f"{script_path} must not force the Ralplan V2 home onto {unrelated_flag}")

    compatibility = re.search(
        r"validate_ralplan_live_option_compatibility\(\) \{(?P<body>.*?)\n\}",
        script_text,
        flags=re.S,
    )
    if not compatibility:
        die(f"{script_path} is missing Ralplan live option compatibility validation")
    for fragment in ("--no-install", "--parallel-live", "--named-agents-live", "--fusion-rescue-live", "--cross-host-fallback-live", "--simplify-live", "--natural-session-start-live"):
        if fragment not in compatibility.group("body"):
            die(f"{script_path} Ralplan V2 compatibility guard is missing {fragment}")

    main = re.search(r"main\(\) \{(?P<body>.*?)\n\}", script_text, flags=re.S)
    if not main:
        die(f"{script_path} is missing main")
    main_body = main.group("body")
    scanner_index = main_body.find("validate_codex_live_secret_scanner")
    clone_safety_index = main_body.find("validate_codex_live_clone_safety")
    compatibility_index = main_body.find("validate_ralplan_live_option_compatibility")
    prepare_index = main_body.find("prepare_isolated_codex_live_home")
    install_index = main_body.find("install_via_codex_plugins")
    if (
        scanner_index == -1
        or clone_safety_index == -1
        or compatibility_index == -1
        or prepare_index == -1
        or install_index == -1
        or not scanner_index < clone_safety_index < compatibility_index < prepare_index < install_index
    ):
        die(
            f"{script_path} must validate clone safety and prepare the isolated "
            "Codex Ralplan home before plugin installation"
        )

    policy_errors = codex_live_launch_policy_errors(script_text)
    if policy_errors:
        die(f"{script_path} Codex live-home policy violations: {policy_errors!r}")

    functions = shell_function_bodies(script_text)
    for function_name, lane_name, expected_scans in (
        ("run_parallel_live_test", "Parallel", 2),
        ("run_simplify_live_test", "Simplify", 2),
        ("run_fusion_rescue_live_test", "Fusion Rescue", 2),
        ("run_codex_cross_host_fallback_live_test", "cross-host fallback", 1),
    ):
        body = functions.get(function_name, "")
        if "--ephemeral" in body:
            die(
                f"{script_path} {lane_name} transcript-dependent live lane must "
                "persist child sessions instead of using --ephemeral"
            )
        if body.count("assert_no_codex_live_secret_leak") != expected_scans:
            die(
                f"{script_path} {lane_name} live lane must scan all "
                "transcript-dependent artifacts for credential leaks"
            )
        if body.count('"$CODEX_HOME_DIR/sessions"') < expected_scans:
            die(
                f"{script_path} {lane_name} live credential guards must scan "
                "persisted Codex child sessions"
            )

    for function_name, lane_name, minimum_count in (
        ("run_fusion_rescue_live_test", "Fusion Rescue", 2),
        ("run_codex_cross_host_fallback_live_test", "cross-host fallback", 1),
    ):
        body = functions.get(function_name, "")
        for fragment in (
            'payload.get("type") == "agent_message"',
            'item.get("type") == "encrypted_content"',
            'task_complete_messages[-1]',
            '"encrypted_task_messages": encrypted_task_messages',
            'isinstance(meta.get("source"), dict)',
            'isinstance(source.get("subagent"), dict)',
        ):
            if body.count(fragment) < minimum_count:
                die(
                    f"{script_path} {lane_name} transcript fallback must preserve "
                    f"encrypted task and authoritative completion evidence: missing {fragment!r}"
                )

    fusion_body = functions.get("run_fusion_rescue_live_test", "")
    for fragment in (
        'payload.get("type") == "custom_tool_call"',
        'payload.get("name") == "exec"',
        'payload.get("type") == "custom_tool_call_output"',
        "command_from_payload(payload)",
    ):
        if fragment not in fusion_body:
            die(
                f"{script_path} Fusion Rescue must inspect Codex custom exec tool "
                f"events for Claude-call provenance: missing {fragment!r}"
            )

    cross_host_body = functions.get("run_codex_cross_host_fallback_live_test", "")
    for fragment in (
        "def missing_panel_evidence(text):",
        're.search(r"(?im)^\\s*blocking finding ids:',
        "missing_fields = missing_panel_evidence(result_text)",
    ):
        if fragment not in cross_host_body:
            die(
                f"{script_path} cross-host fallback must accept semantic code-reviewer "
                f"panel evidence without exact field labels: missing {fragment!r}"
            )

    parallel_body = functions.get("run_parallel_live_test", "")
    parallel_transcript_requirements = (
        'payload.get("type") == "agent_message"',
        'item.get("type") == "encrypted_content"',
        'task_complete_messages[-1]',
        '"encrypted_task_messages": encrypted_task_messages',
        'def has_role_heading(text, role):',
        'normalized.startswith("role heading:")',
        'normalized.startswith("role:")',
        'marker in normalized and heading in normalized',
        'Child lifetimes do not reveal when the parent issued wait_agent',
        'invalid_lifetimes',
    )
    for fragment in parallel_transcript_requirements:
        if fragment not in parallel_body:
            die(
                f"{script_path} Parallel transcript fallback must preserve encrypted "
                f"task and authoritative completion evidence: missing {fragment!r}"
            )

    simplify_body = functions.get("run_simplify_live_test", "")
    simplify_transcript_requirements = {
        'payload.get("type") == "agent_message"': 2,
        'item.get("type") == "encrypted_content"': 2,
        'task_complete_messages[-1]': 2,
        'linked_children != len(expected_angles)': 2,
        '"encrypted_task_messages": encrypted_task_messages': 2,
        'expected_agent_nodes = {': 1,
        'allowed_discovery_roles = {': 1,
        'thread_spawn.get("agent_path")': 1,
        'agent_role not in allowed_discovery_roles': 1,
        'contradicted its typed': 1,
        'no (?:cleanup )?(?:candidates?|findings?)': 1,
    }
    for fragment, minimum_count in simplify_transcript_requirements.items():
        if simplify_body.count(fragment) < minimum_count:
            die(
                f"{script_path} Simplify transcript fallback must preserve encrypted "
                f"task and authoritative completion evidence: missing {fragment!r}"
            )
    if "Named THOROUGH broad-diff maintainability trigger." not in simplify_body:
        die(
            f"{script_path} Simplify natural prompt must use an outcome-only "
            "maintainability trigger"
        )
    if "prompt='Named THOROUGH broad-diff cleanup trigger." in simplify_body:
        die(
            f"{script_path} Simplify natural prompt must not prescribe cleanup "
            "dispatch mechanics"
        )

    registry_match = re.search(
        r"(?ms)^ISOLATED_CODEX_LIVE_FUNCTIONS=\(\s*(?P<body>.*?)^\)",
        script_text,
    )
    assert registry_match is not None
    isolated_functions = re.findall(
        r"(?m)^\s*(run_[a-z0-9_]+_live_test)\s*$", registry_match.group("body")
    )
    for required in (
        "run_ralplan_live_test",
        "run_named_agents_live_test",
    ):
        if required not in isolated_functions:
            die(f"{script_path} isolated Codex live registry is missing {required}")

    named_agents = re.search(
        r"run_named_agents_live_test\(\) \{(?P<body>.*?)\n\}\n\nrun_fusion_rescue_live_test\(\)",
        script_text,
        flags=re.S,
    )
    if not named_agents:
        die(f"{script_path} is missing run_named_agents_live_test")
    named_agents_body = named_agents.group("body")
    for fragment in (
        'payload.get("type") == "agent_message"',
        'item.get("type") == "encrypted_content"',
        '"encrypted_task_messages": encrypted_task_messages',
        'child["encrypted_task_messages"] != 1',
        "nor one encrypted inter-agent task message",
    ):
        if fragment not in named_agents_body:
            die(
                f"{script_path} named-agent transcript fallback must preserve encrypted "
                f"task-channel evidence: missing {fragment!r}"
            )

    for fragment in (
        "Approved synthetic low-risk internal goal",
        "This message is the complete approved requirements source.",
        "No product, architecture, public-contract, security, migration, concurrency, or release decision is in scope.",
    ):
        if fragment not in script_text:
            die(
                f"{script_path} Ultrawork natural smoke must stay bounded and avoid "
                f"activating a THOROUGH release workflow: missing {fragment!r}"
            )
    if "enough live natural smoke coverage for a release handoff" in script_text:
        die(
            f"{script_path} Ultrawork natural smoke still activates the release-risk "
            "planning topology"
        )

    assignment_mutations = (
        'CODEX_HOME="$live_home" codex exec',
        'CODEX_HOME="${live_home}" codex exec',
        "CODEX_HOME=$live_home codex exec",
        "CODEX_HOME=${live_home} codex exec",
        "export CODEX_HOME=$live_home; codex exec",
    )
    for mutation in assignment_mutations:
        if CODEX_HOME_ASSIGNMENT_RE.search(mutation) is None:
            die(
                "Codex isolated-home assignment guard missed mutation fixture: "
                f"{mutation!r}"
            )

    unregistered_lane_mutation = script_text + r'''

run_future_isolated_live_skill_test() {
  local future_home
  future_home="$(mktemp -d)"
  CODEX_HOME="${future_home}" "$CODEX_BIN" exec --json "future fixture"
}
'''
    mutation_errors = codex_live_launch_policy_errors(unregistered_lane_mutation)
    if not any("run_future_isolated_live_skill_test" in error for error in mutation_errors):
        die(
            "Codex live-home policy accepted an unregistered future lane using "
            "a disposable CODEX_HOME"
        )

    ralplan = re.search(
        r"run_ralplan_live_test\(\) \{(?P<body>.*?)\n\}\n\nrun_named_agents_live_test\(\)",
        script_text,
        flags=re.S,
    )
    if not ralplan:
        die(f"{script_path} is missing run_ralplan_live_test")
    body = ralplan.group("body")
    if "--ephemeral" in body:
        die(f"{script_path} Ralplan subagent live lane must preserve parent transcripts in its isolated home")
    for fragment in (
        'fork_turns "none"',
        "OH_NO_RALPLAN_PLANNER_PROOF_REQUEST",
        "OH_NO_RALPLAN_REVIEW_PROOF_REQUEST",
        "Planner draft id: ${draft_id}",
        "REVIEWED_PLANNER_DRAFT_BEGIN",
        "typed Plan-Reviewer did not echo the exact Planner draft",
        "inspected test-only proof material",
        "transcript_children = {role: [] for role in expected_roles}",
        "if not 1 <= len(reviewer_sessions) <= 4:",
        "at most one THOROUGH pair per round",
        '"last_task_timestamp": task_timestamps[-1] if task_timestamps else ""',
        "final_reviewer_evidence",
        "if len(final_reviewer_evidence) not in (1, 2):",
        "reviewer_task and reviewer_task <= planner_final_completion",
        "max(final_review_dispatches) >= min(final_review_completions)",
        'acceptance_markers = ("acceptance", "required outcomes", "success criteria")',
        'ac_ids = set(re.findall(r"(?i)\\bAC[- ]?([0-9]+)\\b", planner_output))',
        "Codex ralplan natural final Plan-Reviewer {reviewer_index} task had neither",
        "Codex ralplan natural Planner output lacked one stable draft id",
        "canonical_draft_id",
        'strip("` *_")',
        "semantic_lines",
        "planner_coverage < 0.85",
        "Codex ralplan natural parent did not preserve the complete Planner draft",
        "Codex ralplan natural parent Planner draft did not identify the final draft id",
        "Codex ralplan natural parent Planner draft omitted acceptance outcome ids",
        "Codex ralplan natural parent review synthesis did not identify the final Planner draft id",
        "Codex ralplan natural parent omitted evidence that it synthesized the reviewer pair",
        "Codex ralplan natural typed child {role} lacked task_complete",
        '"encrypted_task_messages": encrypted_task_messages',
        "parent did not preserve the exact Planner output",
        "assert_no_codex_live_secret_leak",
        "Close/cleanup was not available.",
    ):
        if fragment not in body:
            die(f"{script_path} Ralplan V2 proof contract is missing {fragment!r}")

    for forbidden in (
        "then wait for and close planner before plan-reviewer",
        "After both subagents finish and both completed planning agents are closed",
        "natural transcript proof found duplicate typed child sessions for",
        "if len(reviewer_sessions) not in (1, 2):",
        "Plan-Reviewer {reviewer_index} did not identify the final Planner draft id",
        "natural parent did not preserve the Planner payload",
        "natural parent did not preserve the Plan-Reviewer decision payload",
    ):
        if forbidden in body:
            die(f"{script_path} Ralplan prompt still contains a conflicting legacy lifecycle rule: {forbidden!r}")

    if body.count("assert_no_codex_live_secret_leak") != 2:
        die(f"{script_path} must secret-scan both explicit and natural Ralplan live artifacts")
    if "err_text[:2000]" in body:
        die(f"{script_path} Ralplan live parser must not interpolate raw stderr into failures")
    if re.search(r"command_events[.]append\([^\n]*\[:2000\]", body):
        die(f"{script_path} Ralplan test-only proof taint scan must inspect complete command events")

    instrumented_prompts = re.findall(
        r"IFS= read -r -d '' prompt <<PROMPT \|\| true\n(.*?)\nPROMPT",
        body,
        flags=re.S,
    )
    natural_prompts = re.findall(
        r"IFS= read -r -d '' prompt <<'PROMPT' \|\| true\n(.*?)\nPROMPT",
        body,
        flags=re.S,
    )
    if len(instrumented_prompts) != 1 or len(natural_prompts) != 1:
        die(
            f"{script_path} Ralplan live lane must contain one instrumented prompt "
            "and one standalone natural prompt"
        )
    natural_forbidden_terms = (
        "subagent",
        "sub-agent",
        "spawn",
        "delegate",
        "delegation",
        "parallel agent",
        "worker",
        "agent_type",
        "role:",
        "wave",
        "wait results",
        "wait_agent",
        "close_agent",
        "clean up",
        "cleanup",
        "lifecycle",
    )
    natural_prompt_lower = natural_prompts[0].lower()
    leaked_terms = [
        term for term in natural_forbidden_terms if term in natural_prompt_lower
    ]
    if leaked_terms:
        die(
            f"{script_path} Ralplan natural prompt prescribes dispatch mechanics: "
            f"{leaked_terms!r}"
        )
    prompts = (*instrumented_prompts, *natural_prompts)
    prompt_limits = (2600, 1500)
    for index, (prompt, limit) in enumerate(zip(prompts, prompt_limits), 1):
        if len(prompt) > limit:
            die(
                f"{script_path} Ralplan prompt {index} exceeds its audited size budget: "
                f"{len(prompt)}>{limit}"
            )


def assert_codex_parallel_transcript_fixture(marketplace_root: Path) -> None:
    script_path = marketplace_root / "scripts" / "test-codex-plugin.sh"
    script_text = read_text(script_path)
    function_start = script_text.find("run_parallel_live_test() {")
    function_end = script_text.find("\nrun_simplify_live_test() {", function_start)
    if function_start == -1 or function_end == -1:
        die(f"{script_path} is missing the Parallel live function boundary")
    function_body = script_text[function_start:function_end]
    parser_sources = re.findall(r"<<'PY'\n(.*?)\nPY(?:\n|$)", function_body, re.S)
    if len(parser_sources) != 1:
        die(
            f"{script_path} must expose exactly one Parallel transcript parser; "
            f"found {len(parser_sources)}"
        )

    role_waves = (
        ("explore", "analyst", "planner"),
        ("executor", "debugger"),
        ("verifier", "code-reviewer", "fusion-rescue-analyst"),
    )
    role_headings = {
        "explore": "# Explore Agent",
        "analyst": "# Analyst Agent",
        "planner": "# Planner Agent",
        "executor": "# Executor Agent",
        "debugger": "# Debugger Agent",
        "verifier": "# Verifier Agent",
        "code-reviewer": "# Code Reviewer Agent",
        "fusion-rescue-analyst": "# Fusion Rescue Analyst Agent",
    }

    with tempfile.TemporaryDirectory(prefix="oh-no-parallel-parser-") as temp:
        root = Path(temp)
        sessions = root / "sessions"
        sessions.mkdir()
        parent_thread_id = "fixture-parent-thread"
        parent_markers = [
            f"OH_NO_PARALLEL_RESULT {role}"
            for wave in role_waves
            for role in wave
        ]
        out_path = root / "out.jsonl"
        out_path.write_text(
            "\n".join(
                json.dumps(row)
                for row in (
                    {"type": "thread.started", "thread_id": parent_thread_id},
                    {
                        "type": "item.completed",
                        "item": {
                            "type": "agent_message",
                            "text": (
                                "OH_NO_CODEX_PARALLEL_SUBAGENTS_OK\n"
                                + "\n".join(parent_markers)
                            ),
                        },
                    },
                )
            )
            + "\n",
            encoding="utf-8",
        )
        err_path = root / "err.txt"
        err_path.write_text("", encoding="utf-8")

        session_index = 0
        for wave_index, wave in enumerate(role_waves):
            for role_index, role in enumerate(wave):
                if wave_index == 0:
                    started = f"2026-07-18T00:00:{2 * role_index:02d}.000000Z"
                    completed = f"2026-07-18T00:00:{2 * role_index + 1:02d}.000000Z"
                else:
                    started = f"2026-07-18T00:0{wave_index}:{role_index:02d}.000000Z"
                    completed = f"2026-07-18T00:0{wave_index}:{10 + role_index:02d}.000000Z"
                if role == "fusion-rescue-analyst":
                    heading_line = "Role heading: Fusion Rescue Analyst Agent"
                elif role == "verifier":
                    heading_line = "- OH_NO_PARALLEL_RESULT verifier — **Verifier Agent**"
                elif role == "analyst":
                    heading_line = "Role: analyst"
                else:
                    heading_line = role_headings[role]
                output = "\n".join(
                    (
                        f"OH_NO_PARALLEL_RESULT {role}",
                        heading_line,
                        "Skill Relationship: present",
                        "Responsibilities: present",
                        "Operating Rules: present",
                        "Output: present",
                    )
                )
                rows = (
                    {
                        "type": "session_meta",
                        "timestamp": started,
                        "payload": {
                            "timestamp": started,
                            "parent_thread_id": parent_thread_id,
                            "agent_role": f"oh-no-{role}",
                        },
                    },
                    {
                        "type": "response_item",
                        "timestamp": started,
                        "payload": {
                            "type": "message",
                            "role": "user",
                            "content": [
                                {
                                    "type": "input_text",
                                    "text": "bootstrap context without task fields",
                                }
                            ],
                        },
                    },
                    {
                        "type": "response_item",
                        "timestamp": started,
                        "payload": {
                            "type": "agent_message",
                            "content": [
                                {"type": "encrypted_content", "ciphertext": "fixture"}
                            ],
                        },
                    },
                    {
                        "type": "event_msg",
                        "timestamp": completed,
                        "payload": {
                            "type": "task_complete",
                            "last_agent_message": output,
                        },
                    },
                )
                (sessions / f"rollout-{session_index}.jsonl").write_text(
                    "\n".join(json.dumps(row) for row in rows) + "\n",
                    encoding="utf-8",
                )
                session_index += 1

        result = subprocess.run(
            [sys.executable, "-", str(out_path), str(err_path), str(root)],
            input=parser_sources[0],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            die(
                f"{script_path} Parallel encrypted-task transcript fixture failed:\n"
                f"{result.stdout}{result.stderr}"
            )


def assert_codex_simplify_transcript_fixtures(marketplace_root: Path) -> None:
    script_path = marketplace_root / "scripts" / "test-codex-plugin.sh"
    script_text = read_text(script_path)
    function_start = script_text.find("run_simplify_live_test() {")
    function_end = script_text.find("\nrun_worktree_live_test() {", function_start)
    if function_start == -1 or function_end == -1:
        die(f"{script_path} is missing the Simplify live function boundary")
    function_body = script_text[function_start:function_end]
    parser_sources = re.findall(r"<<'PY'\n(.*?)\nPY(?:\n|$)", function_body, re.S)
    if len(parser_sources) != 2:
        die(
            f"{script_path} must expose exactly two Simplify transcript parsers; "
            f"found {len(parser_sources)}"
        )

    angles = ["Reuse", "Simplification", "Efficiency", "Altitude"]
    markers = {
        "Reuse": "OH_NO_SIMPLIFY_REUSE_READONLY",
        "Simplification": "OH_NO_SIMPLIFY_SIMPLIFICATION_READONLY",
        "Efficiency": "OH_NO_SIMPLIFY_EFFICIENCY_READONLY",
        "Altitude": "OH_NO_SIMPLIFY_ALTITUDE_READONLY",
    }
    agent_nodes = {
        "Reuse": "simplify_reuse",
        "Simplification": "simplify_simplification",
        "Efficiency": "simplify_efficiency",
        "Altitude": "simplify_altitude",
    }

    def run_fixture(
        parser_source: str,
        natural: bool,
        contradictory_output: bool = False,
    ) -> None:
        with tempfile.TemporaryDirectory(prefix="oh-no-simplify-parser-") as temp:
            root = Path(temp)
            sessions = root / "sessions"
            sessions.mkdir()
            parent_thread_id = "fixture-parent-thread"
            if natural:
                parent_text = "OH_NO_CODEX_SIMPLIFY_NATURAL_OK\n" + "\n".join(angles)
            else:
                parent_text = (
                    "OH_NO_CODEX_SIMPLIFY_SUBAGENTS_OK\n"
                    + "\n".join(markers.values())
                )
            out_path = root / "out.jsonl"
            out_path.write_text(
                "\n".join(
                    json.dumps(row)
                    for row in (
                        {"type": "thread.started", "thread_id": parent_thread_id},
                        {
                            "type": "item.completed",
                            "item": {"type": "agent_message", "text": parent_text},
                        },
                    )
                )
                + "\n",
                encoding="utf-8",
            )
            err_path = root / "err.txt"
            err_path.write_text("", encoding="utf-8")

            for index, angle in enumerate(angles):
                if angle == "Altitude":
                    started = "2026-07-18T00:01:00.000000Z"
                    completed = "2026-07-18T00:01:10.000000Z"
                else:
                    started = f"2026-07-18T00:00:{index:02d}.000000Z"
                    completed = f"2026-07-18T00:00:{10 + index:02d}.000000Z"
                output_lines = [] if natural else [markers[angle]]
                if natural:
                    if contradictory_output and angle == "Altitude":
                        output_lines.append("## Reuse review")
                    if angle == "Reuse":
                        output_lines.append(
                            "- `docs/reference/source-index.md:29` — Repeated platform wording. Concrete cost: synchronized edits can drift."
                        )
                    else:
                        output_lines.extend(
                            (
                                "Location: docs/reference/source-index.md",
                                "Key findings: no candidates",
                            )
                        )
                else:
                    output_lines.extend(
                        (
                            f"Angle: {angle}",
                            "File: docs/reference/source-index.md",
                            "Line: 1",
                            "Summary: no candidate",
                            "Concrete cost: none",
                        )
                    )
                rows = (
                    {
                        "type": "session_meta",
                        "timestamp": started,
                        "payload": {
                            "timestamp": started,
                            "parent_thread_id": parent_thread_id,
                            "agent_role": "oh-no-explore",
                            "source": {
                                "subagent": {
                                    "thread_spawn": {
                                        "parent_thread_id": parent_thread_id,
                                        "agent_role": "oh-no-explore",
                                        "agent_path": f"/root/{agent_nodes[angle]}",
                                    }
                                }
                            },
                        },
                    },
                    {
                        "type": "response_item",
                        "timestamp": started,
                        "payload": {
                            "type": "message",
                            "role": "user",
                            "content": [
                                {
                                    "type": "input_text",
                                    "text": "bootstrap context without task fields",
                                }
                            ],
                        },
                    },
                    {
                        "type": "response_item",
                        "timestamp": started,
                        "payload": {
                            "type": "agent_message",
                            "content": [
                                {"type": "encrypted_content", "ciphertext": "fixture"}
                            ],
                        },
                    },
                    {
                        "type": "event_msg",
                        "timestamp": completed,
                        "payload": {
                            "type": "task_complete",
                            "last_agent_message": "\n".join(output_lines),
                        },
                    },
                )
                (sessions / f"rollout-{index}.jsonl").write_text(
                    "\n".join(json.dumps(row) for row in rows) + "\n",
                    encoding="utf-8",
                )

            result = subprocess.run(
                [
                    sys.executable,
                    "-",
                    str(out_path),
                    str(err_path),
                    str(root),
                ],
                input=parser_source,
                capture_output=True,
                text=True,
            )
            lane = "natural" if natural else "explicit"
            if contradictory_output:
                if result.returncode == 0:
                    die(
                        f"{script_path} Simplify {lane} transcript fixture accepted "
                        "output that contradicted its typed agent-path identity"
                    )
                return
            if result.returncode != 0:
                die(
                    f"{script_path} Simplify {lane} encrypted-task transcript fixture "
                    f"failed:\n{result.stdout}{result.stderr}"
                )

    run_fixture(parser_sources[0], natural=False)
    run_fixture(parser_sources[1], natural=True)
    run_fixture(parser_sources[1], natural=True, contradictory_output=True)


def assert_claude_live_budget_floor(marketplace_root: Path) -> None:
    script_path = marketplace_root / "scripts" / "test-claude-plugin.sh"
    script_text = read_text(script_path)
    match = re.search(r'LIVE_MAX_BUDGET_USD="\$\{OH_NO_MAX_BUDGET_USD:-(?P<budget>[0-9.]+)\}"', script_text)
    if not match:
        die(f"{script_path} is missing the live max-budget default")
    try:
        budget = float(match.group("budget"))
    except ValueError:
        die(f"{script_path} has an invalid live max-budget default: {match.group('budget')!r}")
    if budget < 3.0:
        die(f"{script_path} live max-budget default must be at least 3.00 for subagent lifecycle lanes")


def assert_claude_fusion_rescue_readonly_guard(marketplace_root: Path) -> None:
    script_path = marketplace_root / "scripts" / "test-claude-plugin.sh"
    script_text = read_text(script_path)
    required_fragments = (
        "codex-companion Bash command MUST NOT include --write",
        "the fusion-codex agent runs codex-companion read-only by design (no --write flag)",
        "codex_write_commands",
        "invoked codex-companion with --write",
        "invoked codex-companion with --background",
        # Inspect actual codex-companion task invocation lines rather than
        # matching --write text copied inside the prompt-file heredoc.
        "companion_call_lines = [",
        "pending_background_events",
        "late_pending_background_events",
        "left background/still-running work after Codex",
        "expected exactly one codex-companion.mjs Bash invocation",
        "expected exactly one successful codex-companion.mjs Bash result",
        "did not return success marker OH_NO_FUSION_CODEX_PANEL_OK{detail}",
        "matched_result_markers",
    )
    for fragment in required_fragments:
        if fragment not in script_text:
            die(f"{script_path} Claude Fusion Rescue live read-only guard is missing {fragment!r}")
    # All five companion lanes (fusion, cross-host-review, ralplan-xhost,
    # vbc-xhost, sysdebug-xhost) must inspect the actual task invocation line;
    # packet prose such as "no --write" must not become a false positive.
    invocation_scan = "companion_call_lines = ["
    scan_count = script_text.count(invocation_scan)
    if scan_count < 5:
        die(
            f"{script_path} must inspect codex-companion task invocation flags "
            f"in all five live lanes (found {scan_count})"
        )


def assert_claude_deep_live_hard_failure_guard(marketplace_root: Path) -> None:
    script_path = marketplace_root / "scripts" / "test-claude-plugin.sh"
    script_text = read_text(script_path)
    required_fragments = (
        "SEMANTIC_VARIANCE_EXIT = 88",
        'data.get("permission_denials")',
        "deep smoke had permission denials",
        'if [[ "$deep_rc" == "88" ]]',
        'elif [[ "$deep_rc" != "0" ]]',
        "Tool,",
        "permission, malformed-output, and command failures remain hard failures",
    )
    for fragment in required_fragments:
        if fragment not in script_text:
            die(f"{script_path} Claude deep-live hard-failure guard is missing {fragment!r}")


def assert_goal_preservation_and_proportional_lane_contract(marketplace_root: Path) -> None:
    codex_path = marketplace_root / "scripts" / "test-codex-plugin.sh"
    claude_path = marketplace_root / "scripts" / "test-claude-plugin.sh"
    codex = read_text(codex_path)
    claude = read_text(claude_path)

    for fragment in (
        "Direction Contract:",
        "AC-OVERLAP-1",
        "no new scheduler",
        "direction_packet_gaps",
        "missing_final_direction",
    ):
        if fragment not in claude:
            die(f"{claude_path} goal-preservation lane is missing {fragment!r}")
    if claude.count("Direction Contract:") < 2:
        die(f"{claude_path} must carry Direction Contract in both disjoint-executor lanes")

    for path, body in ((codex_path, codex), (claude_path, claude)):
        if "Named THOROUGH broad-diff cleanup trigger" not in body:
            die(f"{path} four-viewpoint Simplify lane lacks a named THOROUGH trigger")
        if "combined-scan default" not in body:
            die(f"{path} deep smoke does not assert the proportional Simplify default")

    if "Pairing is trigger-driven" not in codex:
        die(f"{codex_path} cross-host fallback lane lacks a named pairing trigger")
    if claude.lower().count("pairing is trigger-driven") < 4:
        die(f"{claude_path} paired-review lanes must state trigger-driven pairing")
    if "Dual-host is the default for the debugger" in claude:
        die(f"{claude_path} still encodes the retired debugger pair-by-default policy")


def assert_claude_parallel_executor_hard_guards(marketplace_root: Path) -> None:
    script_path = marketplace_root / "scripts" / "test-claude-plugin.sh"
    script_text = read_text(script_path)
    function_start = script_text.find("run_parallel_executor_live_test()")
    function_end = script_text.find("run_codex_executor_delegation_live_test()", function_start)
    if function_start == -1 or function_end == -1:
        die(f"{script_path} is missing the parallel-executor function boundary")
    function_body = script_text[function_start:function_end]
    required_fragments = (
        "permission_denials",
        "Claude parallel-executor live had permission denials",
        "completion-observation gaps are hard failures for",
        "FORBIDDEN_ENV_OR_HOME_REF",
        "INTERPRETER_WRITE_PATTERNS",
        "interpreter_write_targets",
        "command_write_escape_reasons",
        "out-of-fixture containment escapes",
        "absolute path in write-capable command outside fixture",
        "command invocation failed despite parser-accepted transcript",
        'if [[ "$run_rc" != "0" ]]',
    )
    for fragment in required_fragments:
        if fragment not in function_body:
            die(f"{script_path} Claude parallel-executor hard guard is missing {fragment!r}")
    forbidden_fragments = (
        "WARN (non-gating): parallel-executor",
        "raise SystemExit(0)",
    )
    for fragment in forbidden_fragments:
        if fragment in function_body:
            die(f"{script_path} Claude parallel-executor must not soft-pass hard failures via {fragment!r}")


def assert_claude_parallel_executor_containment_fixtures(marketplace_root: Path) -> None:
    script_path = marketplace_root / "scripts" / "test-claude-plugin.sh"
    script_text = read_text(script_path)
    function_start = script_text.find("run_parallel_executor_live_test()")
    if function_start == -1:
        die(f"{script_path} is missing run_parallel_executor_live_test")
    heredoc_start = script_text.find("<<'PY'", function_start)
    if heredoc_start == -1:
        die(f"{script_path} is missing the parallel-executor parser heredoc")
    parser_start = script_text.find("\n", heredoc_start) + 1
    parser_end = script_text.find("\nPY\n", parser_start)
    if parser_end == -1:
        die(f"{script_path} parallel-executor parser heredoc is not closed")
    parser_source = script_text[parser_start:parser_end] + "\n"

    escape_commands = {
        "python-open-tmp": "python3 -c \"open('/tmp/oh-no-x','w').write('x')\"",
        "nested-bash-tmp": "bash -lc 'touch /tmp/oh-no-x'",
        "tmpdir-redirection": 'echo x > "$TMPDIR/oh-no-x"',
        "home-touch": 'touch "$HOME/oh-no-x"',
        "tilde-touch": "touch ~/oh-no-x",
        "path-home-write": "python3 -c \"from pathlib import Path; Path.home().joinpath('oh-no-x').write_text('x')\"",
        "path-alias-write": "python3 -c \"from pathlib import Path as P; P('/tmp/oh-no-x').write_text('x')\"",
        "open-os-environ-home": "python3 -c \"import os; open(os.environ['HOME'] + '/oh-no-x', 'w').close()\"",
        "open-mode-keyword": "python3 -c \"open('/tmp/oh-no-x', mode='w').write('x')\"",
        "open-file-mode-keywords": "python3 -c \"open(file='/tmp/oh-no-x', mode='w').write('x')\"",
        "open-os-environ-get-home": "python3 -c \"import os; open(os.environ.get('HOME') + '/oh-no-x', mode='w').write('x')\"",
        "path-private-var-tmp": "python3 -c \"from pathlib import Path; Path('/private/var/tmp/oh-no-x').write_text('x')\"",
        "path-var-folders": "python3 -c \"from pathlib import Path; Path('/var/folders/oh-no-x').write_text('x')\"",
        "tempfile-default": "python3 -c \"import tempfile; tempfile.NamedTemporaryFile(delete=False).write(b'x')\"",
    }

    for label, command in escape_commands.items():
        with tempfile.TemporaryDirectory() as tmp:
            fixture_dir = Path(tmp) / "work"
            fixture_dir.mkdir()
            out_path = Path(tmp) / "out.jsonl"
            err_path = Path(tmp) / "err.txt"
            summary_path = Path(tmp) / "summary.json"
            transcript = [
                {
                    "type": "system",
                    "subtype": "init",
                    "tools": ["Task"],
                    "agents": ["oh-no-harness:executor"],
                },
                {
                    "type": "assistant",
                    "message": {
                        "content": [
                            {
                                "type": "tool_use",
                                "name": "Bash",
                                "input": {"command": command},
                            }
                        ]
                    },
                },
            ]
            out_path.write_text(
                "\n".join(json.dumps(row) for row in transcript) + "\n",
                encoding="utf-8",
            )
            err_path.write_text("", encoding="utf-8")
            env = os.environ.copy()
            env.update(
                {
                    "OH_NO_PEXEC_STATUS_BEFORE": "",
                    "OH_NO_PEXEC_STATUS_AFTER": "",
                    "OH_NO_PEXEC_SENTINEL_BEFORE": "{}",
                    "OH_NO_PEXEC_SENTINEL_AFTER": "{}",
                }
            )
            result = subprocess.run(
                [
                    sys.executable,
                    "-",
                    str(out_path),
                    str(err_path),
                    str(summary_path),
                    "opus",
                    str(fixture_dir),
                    str(marketplace_root),
                ],
                input=parser_source,
                capture_output=True,
                text=True,
                env=env,
            )
            combined = result.stdout + result.stderr
            if result.returncode == 0:
                die(f"{script_path} parallel-executor containment fixture {label} unexpectedly passed")
            if "out-of-fixture containment escapes" not in combined:
                die(
                    f"{script_path} parallel-executor containment fixture {label} "
                    f"failed for the wrong reason:\n{combined}"
                )

    benign_commands = {
        "stdout-write-path-text": "python3 -c \"import sys; sys.stdout.write('/tmp/diagnostic-only')\"",
        "stderr-write-path-text": "python3 -c \"import sys; sys.stderr.write('/var/folders/diagnostic-only')\"",
        "shell-local-write-path-text": "printf '/tmp/diagnostic-only\\n' > module_a.py",
        "path-local-write-path-text": "python3 -c \"from pathlib import Path; Path('module_a.py').write_text('/tmp/diagnostic-only')\"",
    }
    for label, command in benign_commands.items():
        with tempfile.TemporaryDirectory() as tmp:
            fixture_dir = Path(tmp) / "work"
            fixture_dir.mkdir()
            out_path = Path(tmp) / "out.jsonl"
            err_path = Path(tmp) / "err.txt"
            summary_path = Path(tmp) / "summary.json"
            transcript = [
                {
                    "type": "system",
                    "subtype": "init",
                    "tools": ["Task"],
                    "agents": ["oh-no-harness:executor"],
                },
                {
                    "type": "assistant",
                    "message": {
                        "content": [
                            {
                                "type": "tool_use",
                                "name": "Bash",
                                "input": {"command": command},
                            }
                        ]
                    },
                },
            ]
            out_path.write_text(
                "\n".join(json.dumps(row) for row in transcript) + "\n",
                encoding="utf-8",
            )
            err_path.write_text("", encoding="utf-8")
            env = os.environ.copy()
            env.update(
                {
                    "OH_NO_PEXEC_STATUS_BEFORE": "",
                    "OH_NO_PEXEC_STATUS_AFTER": "",
                    "OH_NO_PEXEC_SENTINEL_BEFORE": "{}",
                    "OH_NO_PEXEC_SENTINEL_AFTER": "{}",
                }
            )
            result = subprocess.run(
                [
                    sys.executable,
                    "-",
                    str(out_path),
                    str(err_path),
                    str(summary_path),
                    "opus",
                    str(fixture_dir),
                    str(marketplace_root),
                ],
                input=parser_source,
                capture_output=True,
                text=True,
                env=env,
            )
            combined = result.stdout + result.stderr
            if "out-of-fixture containment escapes" in combined:
                die(
                    f"{script_path} parallel-executor containment benign fixture {label} "
                    f"false-positive failed:\n{combined}"
                )


def classification(row: dict[str, Any], fixture: dict[str, Any]) -> str:
    hard = set(row["hard_failures"])
    warnings = set(row["warnings"])
    non_proofs = set(row["non_proofs"])

    if fixture.get("hard_failure") in hard:
        return "HARD"
    if fixture.get("malformed_transcript") and "malformed output" in hard:
        return "HARD"
    if fixture.get("host_boundary_breach") and "host-boundary" in hard:
        return "HARD"
    if fixture.get("containment_breach") and "containment" in hard:
        return "HARD"
    if fixture.get("forensic_invariant_breach") and "forensic invariant" in hard:
        return "HARD"
    if fixture.get("marker_only") and "marker-only output" in non_proofs:
        return "HARD"

    if fixture.get("semantic_marker_absent"):
        if (
            fixture.get("valid_artifact_shape")
            and fixture.get("contract_evidence")
            and warnings & SEMANTIC_WARNINGS
        ):
            return "WARN"
        return "HARD"

    if fixture.get("valid_artifact_shape") and fixture.get("contract_evidence"):
        return "PASS"
    return "HARD"


def require_classification(
    lanes: dict[tuple[str, str, str], dict[str, Any]],
    key: tuple[str, str, str],
    fixture: dict[str, Any],
    expected: str,
) -> None:
    row = lanes.get(key)
    if row is None:
        die(f"fixture references missing lane row: {key}")
    actual = classification(row, fixture)
    if actual != expected:
        die(f"fixture {fixture['name']} for {key} classified {actual}, expected {expected}")


def validate_classification_fixtures(
    marketplace_root: Path,
    lanes: dict[tuple[str, str, str], dict[str, Any]],
    doc_text: str,
    doc_path: Path,
) -> None:
    hard_fixture_map = {
        "malformed output": {"name": "malformed output", "malformed_transcript": True},
        "host-boundary": {"name": "host-boundary breach", "host_boundary_breach": True},
        "containment": {"name": "containment breach", "containment_breach": True},
        "forensic invariant": {"name": "forensic invariant breach", "forensic_invariant_breach": True},
        "lifecycle": {"name": "generic lifecycle hard failure", "hard_failure": "lifecycle"},
        "install/load": {"name": "generic install/load hard failure", "hard_failure": "install/load"},
        "command invocation": {"name": "generic command invocation hard failure", "hard_failure": "command invocation"},
        "tool/permission": {"name": "generic tool/permission hard failure", "hard_failure": "tool/permission"},
    }
    require_classification(
        lanes,
        ("codex", "scripts/test-codex-plugin.sh", "--live"),
        {
            "name": "marker-only hard-lane proof",
            "marker_only": True,
            "valid_artifact_shape": False,
            "contract_evidence": False,
        },
        "HARD",
    )
    require_classification(
        lanes,
        ("codex", "scripts/test-codex-plugin.sh", "--deep-live"),
        {
            "name": "deep semantic paraphrase",
            "semantic_marker_absent": True,
            "valid_artifact_shape": True,
            "contract_evidence": True,
        },
        "WARN",
    )
    for key, row in sorted(lanes.items()):
        for hard_class, fixture in hard_fixture_map.items():
            if hard_class not in row["hard_failures"]:
                continue
            require_classification(
                lanes,
                key,
                fixture | {"valid_artifact_shape": True, "contract_evidence": True},
                "HARD",
            )
    require_classification(
        lanes,
        ("claude", "scripts/test-claude-plugin.sh", "--live"),
        {
            "name": "non-semantic warning does not hide semantic miss",
            "semantic_marker_absent": True,
            "valid_artifact_shape": True,
            "contract_evidence": True,
        },
        "HARD",
    )
    require_classification(
        lanes,
        ("codex", "scripts/test-codex-plugin.sh", "--parallel-live"),
        {
            "name": "generic lifecycle hard failure",
            "hard_failure": "lifecycle",
            "valid_artifact_shape": True,
            "contract_evidence": True,
        },
        "HARD",
    )
    require_classification(
        lanes,
        ("codex", "scripts/test-codex-plugin.sh", "--live"),
        {
            "name": "valid hard-lane artifact",
            "valid_artifact_shape": True,
            "contract_evidence": True,
        },
        "PASS",
    )

    release = lanes.get(("static", "scripts/release", "default"))
    if release is None:
        die("static release row is missing")
    if release["release_status"] != "default-static":
        die("scripts/release default row must be release_status=default-static")
    if "live model smoke" not in release["non_proofs"]:
        die("scripts/release default row must keep live model smoke as a non-proof")
    if "release default expansion" not in release["hard_failures"]:
        die("scripts/release default row must hard-fail release default expansion")

    assert_release_default_live_safe(marketplace_root, lanes)
    assert_codex_natural_session_role_order_wiring(marketplace_root)
    assert_codex_live_isolation_contract(marketplace_root)
    assert_codex_parallel_transcript_fixture(marketplace_root)
    assert_codex_simplify_transcript_fixtures(marketplace_root)
    assert_claude_live_budget_floor(marketplace_root)
    assert_claude_fusion_rescue_readonly_guard(marketplace_root)
    assert_claude_deep_live_hard_failure_guard(marketplace_root)
    assert_goal_preservation_and_proportional_lane_contract(marketplace_root)
    assert_claude_parallel_executor_hard_guards(marketplace_root)
    assert_claude_parallel_executor_containment_fixtures(marketplace_root)

    boundary_markers = (
        "Deterministically checked",
        "Intentionally excluded",
        "Requires user approval to expand",
        "Full public support for every PUBLIC_SKILLS entry",
    )
    for marker in boundary_markers:
        if marker not in doc_text:
            die(f"{doc_path} reachability boundary is missing marker: {marker!r}")
    forbidden_claims = (
        "all public skills are proven",
        "all PUBLIC_SKILLS entries are proven",
        "reachability proves semantic correctness",
    )
    lowered = doc_text.lower()
    for claim in forbidden_claims:
        if claim.lower() in lowered:
            die(f"{doc_path} contains overbroad reachability claim: {claim!r}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--marketplace-root", default=".")
    parser.add_argument("--plugin-root")
    args = parser.parse_args()

    marketplace_root = find_marketplace_root(Path(args.marketplace_root))
    plugin_root = find_plugin_root(marketplace_root, Path(args.plugin_root) if args.plugin_root else None)
    lanes, doc_text, doc_path = load_lanes(plugin_root)
    indexed = validate_matrix_coverage(marketplace_root, lanes)
    validate_classification_fixtures(marketplace_root, indexed, doc_text, doc_path)
    print(f"ok - test harness lane contract: {len(indexed)} lanes checked")
    return 0


if __name__ == "__main__":
    sys.exit(main())
