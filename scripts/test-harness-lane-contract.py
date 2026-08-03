#!/usr/bin/env python3
"""Validate the small deterministic maintainer test-lane contract."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, NoReturn

PLUGIN_NAME = "oh-no-harness"
DOC_RELATIVE = Path("docs/reference/test-harness-lanes.md")

DIRECT_INVARIANTS = {
    "interview": "clarify-before-planning",
    "ralplan": "wait-for-user-approval",
    "ralph": "require-acceptance-contract",
    "ultrawork": "wait-for-spec-approval",
    "auto-routing": "future-session-guidance-only",
    "test-driven-development": "create-red-first",
    "simplify": "lock-behavior-then-combined-scan",
    "verification-before-completion": "withhold-completion",
    "systematic-debugging": "reproduce-first",
}
CLAUDE_SETUP_INVARIANTS = {
    "install-statusline": "stop-no-change",
    "configure-subagents": "report-status-and-stop",
}
OBSOLETE_OPTIONS = {
    "--deep-live",
    "--parallel-live",
    "--ralplan-live",
    "--named-agents-live",
    "--simplify-live",
    "--natural-session-start-live",
    "--worktree-live",
    "--model-diversity-live",
    "--parallel-executor-live",
    "--live-hook-only",
}
CONTROL_OPTIONS = {
    "codex": {"--skip-live", "--no-install", "--codex-home", "--model", "--marketplace-source"},
    "claude": {"--skip-live", "--no-install", "--isolated-config", "--scope", "--live-load", "--marketplace-source", "--model", "--max-budget-usd"},
}
LIVE_OPTIONS = {
    "codex": {"--live", "--dispatch-live", "--cross-host-live"},
    "claude": {"--live", "--dispatch-live"},
}
STATIC_ROWS = {
    ("static", "scripts/release", "default"),
    ("static", "scripts/validate-plugin-files.py", "default"),
    ("static", "scripts/check-skill-reachability.py", "default"),
}


def die(message: str) -> NoReturn:
    print(f"FAIL - {message}", file=sys.stderr)
    raise SystemExit(1)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        die(f"missing or unreadable file: {path} ({exc})")


def find_marketplace_root(start: Path) -> Path:
    for candidate in (start.resolve(), *start.resolve().parents):
        if (candidate / "scripts/test-codex-plugin.sh").is_file():
            return candidate
    die(f"could not locate marketplace root from {start}")


def find_plugin_root(marketplace_root: Path, requested: Path | None) -> Path:
    return requested.resolve() if requested else (marketplace_root / "plugins" / PLUGIN_NAME).resolve()


def extract_matrix(text: str, path: Path) -> list[dict[str, Any]]:
    match = re.search(r"```json\s*(\{.*?\})\s*```", text, re.S)
    if not match:
        die(f"{path} is missing its JSON lane matrix")
    try:
        data = json.loads(match.group(1))
    except json.JSONDecodeError as exc:
        die(f"{path} has invalid lane JSON: {exc}")
    if data.get("schema_version") != 1 or not isinstance(data.get("lanes"), list):
        die(f"{path} must define schema_version 1 and a lanes list")
    return data["lanes"]


def parsed_options(text: str, path: Path) -> set[str]:
    match = re.search(r"while \[\[ \$# -gt 0 \]\]; do\s*case \"\$1\" in(.*?)\n\s*esac\n\s*done", text, re.S)
    if not match:
        die(f"{path} top-level option parser was not found")
    return set(re.findall(r"(?m)^\s*(--[a-z0-9-]+)\)", match.group(1)))


def validate_options(host: str, path: Path, text: str) -> set[str]:
    options = parsed_options(text, path)
    present_obsolete = sorted(options & OBSOLETE_OPTIONS)
    if present_obsolete:
        die(f"{path} retains obsolete model-suite options: {present_obsolete}")
    expected = {*LIVE_OPTIONS[host], *CONTROL_OPTIONS[host]}
    missing = sorted(expected - options)
    extra = sorted(options - expected)
    if missing or extra:
        die(f"{path} option inventory mismatch: missing={missing}, extra={extra}")
    for token in OBSOLETE_OPTIONS:
        if token in text:
            die(f"{path} still advertises or aliases retired option {token}")
    return options


def validate_direct_contract(host: str, path: Path, text: str) -> None:
    invariants = dict(DIRECT_INVARIANTS)
    if host == "claude":
        invariants.update(CLAUDE_SETUP_INVARIANTS)
    required = (
        "direct_invariant_for_skill()",
        "direct_prompt_for_skill()",
        "run_live_skill_test()",
        "Skill:",
        "Invariant:",
        "forbidden project mutation",
        "INCONCLUSIVE(provider-limited)",
        "direct_smoke_failure_class()",
        "wrong finite invariant choice passed",
        "third direct-result line passed",
        "Choose exactly one:",
        "Unknown option: --rate-limit",
        "unexpected argument --rate-limit",
    )
    for marker in required:
        if marker not in text:
            die(f"{path} direct smoke contract is missing {marker!r}")
    for skill, invariant in invariants.items():
        if skill not in text or invariant not in text:
            die(f"{path} is missing direct invariant {skill}={invariant}")
    prompt_start = text.index("direct_prompt_for_skill()")
    prompt_end = text.index("direct_smoke_failure_class()", prompt_start)
    prompt_body = text[prompt_start:prompt_end]
    if "direct_invariant_for_skill" in prompt_body or "Invariant: %s" in prompt_body:
        die(f"{path} direct prompt supplies the expected invariant instead of a finite choice")
    if host == "claude":
        for marker in ("/%s:interview", "assert_direct_installed_skill_identity", "oh-no-harness-generated-skill-wrapper", "missing installed skill identity passed", "wrong installed skill identity passed", "STATUS: installed-matching", "STATUS: matching"):
            if marker not in text:
                die(f"{path} lacks Claude direct invocation/installed-identity evidence {marker!r}")
        for forbidden_read_proof in ('part.get("name") == "Read"', "missing wrapper Read evidence"):
            if forbidden_read_proof in text:
                die(f"{path} still requires model Read-event proof {forbidden_read_proof!r}")
        for operational in ("/%s:configure-subagents check", "/%s:install-statusline check"):
            if operational in text:
                die(f"{path} setup direct smoke must use a hypothetical read-only status, not operational {operational!r}")
        dispatch_body = text[text.index("dispatch_scenario_contract()") : text.index("run_claude_dispatch_oracle_offline_test()")]
        for marker in (
            "interview ralplan ralph verification-before-completion systematic-debugging auto-routing simplify",
            "7 parents, nominal 14 total model calls",
            "--model sonnet",
            "--isolated-config --no-install",
        ):
            if marker not in dispatch_body:
                die(f"{path} Claude dispatch-live matrix is missing {marker!r}")
        if "ultrawork" in dispatch_body:
            die(f"{path} Claude dispatch-live matrix must not include the Ultrawork zero-child scenario")
    else:
        for marker in ("$%s:interview", "--sandbox read-only", "assert_direct_installed_skill_identity", '"oh-no-harness-generated-skill-wrapper"', 'root / "skills" / skill / "SKILL.md"', "Reading additional input from stdin...", "UnknownProcessId", "WARNING [{skill}] ignored", "malformed JSON event candidate passed", "non-object JSON event passed", "hard CLI diagnostic passed with rc 0", "missing terminal event passed", 'rows[-1].get("type") != "turn.completed"', "missing installed skill identity passed", "wrong installed skill identity passed"):
            if marker not in text:
                die(f"{path} lacks Codex direct invocation/installed-identity evidence {marker!r}")
        for forbidden_read_proof in ("missing installed-wrapper identity read", "reader = re.compile", "command_execution"):
            if forbidden_read_proof in text[text.index("validate_codex_direct_result()"):text.index("run_direct_smoke_classifier_offline_test()")]:
                die(f"{path} still requires model Read-event proof {forbidden_read_proof!r}")
        dispatch_body = text[text.index("run_dispatch_live_tests()"):text.index("run_codex_dispatch_oracle_offline_test()")]
        for marker in (
            "interview ralplan ralph verification-before-completion systematic-debugging auto-routing simplify",
            "7 parents, nominal 14 total model calls",
        ):
            if marker not in dispatch_body:
                die(f"{path} dispatch-live matrix is missing {marker!r}")
        if "ultrawork" in dispatch_body:
            die(f"{path} dispatch-live matrix must not include the Ultrawork zero-child scenario")
    for forbidden in (
        "natural_session_start_prompt_for_skill",
        "run_deep_live_tests",
        "run_named_agents_live_test",
        "run_parallel_live_test",
        "run_ralplan_live_test",
        "run_simplify_live_test",
        "run_worktree_live_test",
        "run_model_diversity_live_test",
        "run_parallel_executor_live_test",
    ):
        if forbidden in text:
            die(f"{path} retains retired specialized runner {forbidden}")


def validate_cross_host_contract(codex: str) -> None:
    start = codex.index("run_cross_host_live_test()")
    end = codex.index("run_codex_safety_extraction_offline_test()", start)
    body = codex[start:end]
    for marker in (
        'codex-auth=$CODEX_HOME_DIR/auth.json',
        'codex-config-json=$CODEX_HOME_DIR/config.json',
        'codex-agents=$CODEX_HOME_DIR/agents',
        'assert_codex_live_home_provenance "$CODEX_HOME_DIR"',
    ):
        if marker not in body:
            die(f"Codex cross-host lane lacks protected identity marker {marker!r}")
    if "codex-config-toml=" in body:
        die("Codex cross-host lane must not snapshot runtime-owned cloned config.toml")


def validate_retained_safety(codex: str, claude: str) -> None:
    for marker in (
        "clone_codex_live_home()",
        "assert_codex_live_home_provenance()",
        "validate_codex_live_secret_scanner()",
        "codex_record_installed_identity()",
        "codex_active_plugin_root()",
        "run_fusion_rescue_live_test()",
        "run_codex_cross_host_fallback_live_test()",
        "run_cross_host_live_test()",
        "prepare_cross_host_fixture()",
        "cross-host-live-oracle.py",
        "def fusion_launcher_proof",
    ):
        if marker not in codex:
            die(f"Codex retained safety/deferred surface is missing {marker!r}")
    for marker in (
        "guard_canonical_local_marketplace()",
        "guard_real_claude_config_live()",
        "run_marketplace_isolation_offline_test()",
        "run_claude_state_isolation_offline_test()",
        "run_fusion_rescue_live_test()",
        "run_cross_host_fallback_live_test()",
    ):
        if marker not in claude:
            die(f"Claude retained safety/deferred surface is missing {marker!r}")


def validate_matrix(root: Path, plugin_root: Path, option_sets: dict[str, set[str]]) -> None:
    path = plugin_root / DOC_RELATIVE
    rows = extract_matrix(read_text(path), path)
    keys: set[tuple[str, str, str]] = set()
    for index, row in enumerate(rows):
        required = {"host", "owner", "flag", "release_status", "hard_failures", "warnings", "evidence_artifact", "non_proofs"}
        if not isinstance(row, dict) or set(row) != required:
            die(f"lane row {index} has the wrong fields")
        key = (row["host"], row["owner"], row["flag"])
        if key in keys:
            die(f"duplicate lane row {key}")
        keys.add(key)
        if "marker-only output" not in row["non_proofs"]:
            die(f"lane row {key} must list marker-only output as non-proof")
        if row["flag"] == "--live" and row["release_status"] != "opt-in-live":
            die(f"direct lane {key} must use opt-in-live")
    expected = set(STATIC_ROWS)
    for host in ("codex", "claude"):
        owner = f"scripts/test-{host}-plugin.sh"
        expected.add((host, owner, "default"))
        expected.update((host, owner, flag) for flag in option_sets[host] if flag not in CONTROL_OPTIONS[host])
    if keys != expected:
        die(f"lane matrix coverage mismatch: missing={sorted(expected-keys)}, extra={sorted(keys-expected)}")
    release = read_text(root / "scripts/release")
    for flag in {"--live", "--dispatch-live", "--cross-host-live"}:
        if re.search(rf"test-(?:claude|codex)-plugin[.]sh[^\n]*{re.escape(flag)}", release):
            die(f"release default command must not enable {flag}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--marketplace-root", type=Path)
    parser.add_argument("--plugin-root", type=Path)
    args = parser.parse_args()
    root = find_marketplace_root(args.marketplace_root or Path.cwd())
    plugin_root = find_plugin_root(root, args.plugin_root)
    texts = {
        host: read_text(root / f"scripts/test-{host}-plugin.sh")
        for host in ("codex", "claude")
    }
    options = {
        host: validate_options(host, root / f"scripts/test-{host}-plugin.sh", texts[host])
        for host in ("codex", "claude")
    }
    for host in ("codex", "claude"):
        validate_direct_contract(host, root / f"scripts/test-{host}-plugin.sh", texts[host])
    validate_cross_host_contract(texts["codex"])
    validate_retained_safety(texts["codex"], texts["claude"])
    validate_matrix(root, plugin_root, options)
    print("ok - direct-invocation lane contract, retained safety gates, and inert deferred parser surfaces validated")


if __name__ == "__main__":
    main()
