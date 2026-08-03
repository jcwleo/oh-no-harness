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
    "opencode": set(),
}
LIVE_OPTIONS = {
    "codex": {"--live", "--dispatch-live", "--cross-host-live"},
    "claude": {"--live", "--dispatch-live"},
    "opencode": set(),
}
STATIC_ROWS = {
    ("static", "scripts/release", "default"),
    ("static", "scripts/validate-plugin-files.py", "default"),
    ("static", "scripts/check-skill-reachability.py", "default"),
}
OPENCODE_AGENTS = (
    "oh-no", "oh-no-explore", "oh-no-analyst", "oh-no-planner",
    "oh-no-plan-reviewer", "oh-no-executor", "oh-no-debugger",
    "oh-no-verifier", "oh-no-code-reviewer", "oh-no-fusion-rescue-analyst",
)
OPENCODE_ROLES = (
    "explore", "analyst", "planner", "plan-reviewer", "executor", "debugger",
    "verifier", "code-reviewer", "fusion-rescue-analyst",
)
OPENCODE_COMMANDS = (
    "interview", "ralplan", "ralph", "ultrawork", "auto-routing",
    "test-driven-development", "simplify", "verification-before-completion",
    "systematic-debugging", "fusion-rescue", "configure-subagents",
)
OPENCODE_MATRIX_ROW = {
    "host": "opencode",
    "owner": "scripts/test-opencode-plugin.sh",
    "flag": "default",
    "release_status": "release-static",
    "hard_failures": [
        "source plugin load and pinned OpenCode runtime",
        "isolated XDG and OH_NO_CONFIG_DIR containment",
        "real OpenCode agent and skill discovery",
        "exact agent, command, skill, default, host-inherited global permission, primary/role restrictive ceilings, role hard-deny/task-topology, arbitrary restriction-preservation, and custom-tool contract",
        "custom-tool publication and unconfigured/configured restart model behavior",
        "read-only status and legacy CLI apply non-writing",
        "project mutation or non-serial OpenCode command execution",
    ],
    "warnings": [],
    "evidence_artifact": "isolated OpenCode 1.18.11 path, agent-list, and raw skill-discovery output; exact generated inventory, custom-tool schema/execution, and native global plus primary/role/package resolved permission assertions; custom-tool publication, read-only status, legacy CLI non-writing, restart-consumption fixtures; and unchanged project manifest and Git status",
    "non_proofs": [
        "marker-only output",
        "installed marketplace or package behavior",
        "provider-backed skill command or agent dispatch behavior",
        "complete parseable inventory from truncated raw debug skill output",
        "concurrent OpenCode startup safety",
    ],
}
OPENCODE_PACKAGE_MATRIX_ROW = {
    "host": "opencode",
    "owner": "scripts/test-opencode-package.sh",
    "flag": "default",
    "release_status": "release-static",
    "hard_failures": [
        "npm pack or dependency-free install",
        "package identity, entrypoint, or OpenCode-only inventory",
        "installed package resolution or default export",
        "installed artifact OpenCode runtime contract",
    ],
    "warnings": [],
    "evidence_artifact": "npm pack JSON and exact file allow/deny assertions; lifecycle-script-free disposable install; package resolution/default-export probe; and the full isolated OpenCode 1.18.11 runtime driver against the installed artifact",
    "non_proofs": [
        "marker-only output",
        "public registry availability",
        "provider-backed skill command or agent dispatch behavior",
    ],
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
    if host == "opencode":
        parser = re.search(r"while \[\[ \$# -gt 0 \]\]; do\s*case \"\$1\" in", text)
        options = parsed_options(text, path) if parser else set()
        for token in ("--live", "--dispatch-live", "--cross-host-live", "--model"):
            if token in text:
                die(f"{path} must not expose unsupported OpenCode option {token}")
    else:
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
    elif host == "codex":
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
    else:
        die(f"unsupported direct-smoke host: {host}")
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


def extract_js_string_array(text: str, name: str, path: Path) -> tuple[str, ...]:
    match = re.search(rf"const {re.escape(name)} = \[(.*?)\];", text, re.S)
    if not match:
        die(f"{path} is missing the {name} inventory")
    return tuple(re.findall(r'"([^"\\]+)"', match.group(1)))


def validate_opencode_contract(path: Path, text: str) -> None:
    for name, expected in {
        "expectedAgents": OPENCODE_AGENTS,
        "roles": OPENCODE_ROLES,
        "expectedCommands": OPENCODE_COMMANDS,
    }.items():
        actual = extract_js_string_array(text, name, path)
        if actual != expected:
            die(f"{path} {name} inventory mismatch: expected={list(expected)}, actual={list(actual)}")

    marker_groups = {
        "source runtime": (
            'PLUGIN_ROOT="${OH_NO_PLUGIN_ROOT:-$REPO_ROOT/plugins/oh-no-harness}"',
            'PLUGIN_INDEX="$PLUGIN_ROOT/opencode/index.js"',
            'CONFIGURATOR="$PLUGIN_ROOT/opencode/configure-opencode-subagents"',
            'PLUGIN_URL="$($NODE_BIN -e',
            'PLUGIN_ROOT_REAL="$($NODE_BIN -e',
            '[[ "$OPENCODE_VERSION" == "1.18.11" ]]',
        ),
        "isolated configuration": (
            'export XDG_CONFIG_HOME="$TEMP_ROOT/xdg-config"',
            'export XDG_DATA_HOME="$TEMP_ROOT/xdg-data"',
            'export XDG_CACHE_HOME="$TEMP_ROOT/xdg-cache"',
            'export XDG_STATE_HOME="$TEMP_ROOT/xdg-state"',
            'export OPENCODE_CONFIG_DIR="$TEMP_ROOT/opencode-config"',
            'export OH_NO_CONFIG_DIR="$TEMP_ROOT/oh-no-config"',
            "export OPENCODE_DISABLE_DEFAULT_PLUGINS=1",
            "export OPENCODE_DISABLE_EXTERNAL_SKILLS=1",
            "export OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1",
            "unset OPENCODE_CONFIG OPENCODE_CONFIG_CONTENT OPENCODE_PURE",
        ),
        "real OpenCode discovery": (
            'run_opencode_capture "$TEMP_ROOT/debug-paths.txt" debug paths',
            'run_opencode_capture "$TEMP_ROOT/agent-list-before.txt" agent list',
            'run_opencode_capture "$TEMP_ROOT/debug-skill.raw" debug skill',
            "real OpenCode discovers oh-no primary and all nine named subagents",
            "raw OpenCode host evidence reaches the generated skills-opencode path",
        ),
        "inventories, defaults, and permissions": (
            "assert.deepEqual(Object.keys(generatedAgents), expectedAgents);",
            "assert.deepEqual(Object.keys(generatedCommands), expectedCommands);",
            "assert.deepEqual(skillInventory.sort(), [...expectedCommands].sort());",
            'assert.equal(generatedAgents["oh-no"].mode, "primary");',
            '...Object.fromEntries(roles.map((role) => [`oh-no-${role}`, "allow"])),',
            'assert.equal(agent.mode, "subagent");',
            'assert.equal(Object.hasOwn(agent, "model"), false);',
            'assert.equal(Object.hasOwn(agent.permission, "edit"), false);',
            'assert.equal(agent.permission.oh_no_configure_subagents, "deny");',
            'assert.deepEqual(Object.keys(hooks.tool), ["oh_no_configure_subagents"]);',
            "const deniedRequest = [];",
            "host permission denial did not block custom tool publication",
            "assert.equal(allowedRequests.length, 1);",
            'assert.equal(configureTool.args[role].type, "string");',
            "assert.deepEqual(legacySchema.required, roles);",
            'assert.equal(config.agent["oh-no"].permission.oh_no_configure_subagents, "ask");',
            'if (["debugger", "verifier"].includes(role)) {',
            '"oh-no-explore": "allow",',
            '"oh-no-analyst": "allow",',
            'assert.equal(agent.permission.task, "deny");',
            'assert.equal(config.default_agent, "oh-no");',
            "assert.equal(config.subagent_depth, 2);",
            "assert.deepEqual(config.agent.build, {",
            'description: "User build replacement.", temperature: 0.25, disable: true,',
            "assert.deepEqual(config.agent.plan, {",
            'description: "User plan replacement.", temperature: 0.5, disable: true,',
            'const preserved = { default_agent: "custom-primary", subagent_depth: 4 };',
            'assert.equal(preserved.default_agent, "custom-primary");',
            "assert.equal(preserved.subagent_depth, 4);",
            "const perAgentRestricted = {",
            'assert.equal(perAgentRestricted.agent["oh-no-executor"].permission.edit, "deny");',
            "same-name oh-no per-agent {permission} deny was overridden",
            "same-name oh-no-executor per-agent edit deny was overridden",
            "same-name per-agent custom-tool deny was overridden",
            "const primaryCeiling = {",
            'assert.equal(permission.read, "deny", `${name} escaped the primary read ceiling`);',
            'assert.equal(permission["custom-tool"], "deny", `${name} dropped the primary custom-tool ceiling`);',
            "const roleSpecificCeiling = {",
            'assert.equal(roleSpecificCeiling.agent["oh-no-executor"].permission.webfetch, "deny");',
            '"primary-ceiling": {',
            '"role-specific-deny": {',
            "primary_ceiling = {",
            'raise SystemExit(f"{name} escaped primary {permission} deny")',
            'raise SystemExit(f"role-specific executor {permission} deny was overridden")',
            '"nested-target-overlap-global": {',
            '"outer-inner-overlap-global": {',
            '"native-global-output": {',
            "nested target overlap did not deny concrete x",
            "later nonmatching inner target erased Bash git-status deny",
            "plugin broadened native global host output",
            "Bash did not inherit the host policy/default",
            "edit did not inherit the host policy/default",
            "const ambiguousRestrictions = {",
            "Object.values(policy).every((action) => action === \"deny\")",
        ),
        "restart model behavior": (
            '[[ "$(<"$CHECK_OUTPUT")" == "STATUS: unconfigured" ]]',
            '|| fail "check unexpectedly created preferences"',
            'if "STATUS: configured" not in text or "RESTART REQUIRED" not in text:',
            '[[ "$(<"$TEMP_ROOT/check-configured.txt")" == "STATUS: configured" ]]',
            "# This is a new Node process after custom tool publication, matching OpenCode's startup-only",
            'for (const [role, model] of roles) assert.equal(config.agent[`oh-no-${role}`].model, model);',
            'run_opencode_capture "$output" debug agent "oh-no-$role"',
            "fresh direct and real OpenCode processes consume all nine exact provider/model IDs",
        ),
        "custom tool and read-only CLI": (
            'assert.equal(Object.hasOwn(hooks, "shell.env"), false);',
            "toolResult = await configureTool.execute(",
            'expect_status 2 "$TEMP_ROOT/legacy-apply.txt" "legacy apply"',
            '|| fail "legacy CLI apply wrote preferences"',
            'PLUGIN_URL="$PLUGIN_URL" "$NODE_BIN" --input-type=module >"$TEMP_ROOT/tool-valid.txt"',
            "const result = await hooks.tool.oh_no_configure_subagents.execute({",
            'expect_status 2 "$TEMP_ROOT/legacy-apply-existing.txt"',
            '|| fail "legacy CLI apply changed previous preference bytes"',
        ),
        "project immutability": (
            'PROJECT_MANIFEST_BEFORE="$(project_manifest)"',
            'PROJECT_STATUS_BEFORE="$(git -C "$PROJECT_ROOT" status --porcelain=v1 --untracked-files=all)"',
            '[[ "$PROJECT_MANIFEST_AFTER" == "$PROJECT_MANIFEST_BEFORE" ]]',
            '[[ "$PROJECT_STATUS_AFTER" == "$PROJECT_STATUS_BEFORE" ]]',
        ),
        "serial commands": (
            "Keep every invocation independent and serial.",
            'run_opencode "$@" >"$output" 2>&1',
        ),
    }
    for group, markers in marker_groups.items():
        for marker in markers:
            if marker not in text:
                die(f"{path} OpenCode {group} contract is missing {marker!r}")

    opencode_lines = [line.strip() for line in text.splitlines() if "$OPENCODE_BIN" in line]
    expected_lines = [
        'OPENCODE_CONFIG_DIR="$config_dir" "$OPENCODE_BIN" "$@"',
        'require_command "$OPENCODE_BIN"',
        'OPENCODE_VERSION="$($OPENCODE_BIN --version 2>&1)"',
    ]
    if opencode_lines != expected_lines:
        die(f"{path} must keep all OpenCode commands serial through run_opencode: {opencode_lines}")
    if re.search(r"(?m)(?<![>&])&\s*(?:#.*)?$|\bxargs\s+[^\n]*\s-P\s*\d|\bparallel\b", text):
        die(f"{path} must not run OpenCode driver work concurrently")


def validate_opencode_package_contract(path: Path, text: str) -> None:
    for marker in (
        '"$NPM_BIN" pack "$PLUGIN_ROOT" --json --pack-destination "$PACK_DIR"',
        '"$NPM_BIN" install --ignore-scripts --no-audit --no-fund',
        'require.resolve("oh-no-harness")',
        'typeof module.default !== "function"',
        'OH_NO_PLUGIN_ROOT="$INSTALLED_ROOT" "$REPO_ROOT/scripts/test-opencode-plugin.sh"',
        '"skills-opencode/configure-subagents/SKILL.md"',
        '"skills-claude/", "skills/"',
    ):
        if marker not in text:
            die(f"{path} OpenCode npm package contract is missing {marker!r}")
    if "npm publish" in text or '"$NPM_BIN" publish' in text:
        die(f"{path} package test must never publish")


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
        if key == ("opencode", "scripts/test-opencode-plugin.sh", "default") and row != OPENCODE_MATRIX_ROW:
            die("OpenCode default lane row does not match its deterministic source-runtime contract")
        if key == ("opencode", "scripts/test-opencode-package.sh", "default") and row != OPENCODE_PACKAGE_MATRIX_ROW:
            die("OpenCode package lane row does not match its packed-artifact contract")
    expected = set(STATIC_ROWS)
    for host in ("codex", "claude"):
        owner = f"scripts/test-{host}-plugin.sh"
        expected.add((host, owner, "default"))
        expected.update((host, owner, flag) for flag in option_sets[host] if flag not in CONTROL_OPTIONS[host])
    expected.add(("opencode", "scripts/test-opencode-plugin.sh", "default"))
    expected.add(("opencode", "scripts/test-opencode-package.sh", "default"))
    if keys != expected:
        die(f"lane matrix coverage mismatch: missing={sorted(expected-keys)}, extra={sorted(keys-expected)}")
    release = read_text(root / "scripts/release")
    for flag in {"--live", "--dispatch-live", "--cross-host-live"}:
        if re.search(rf"test-(?:claude|codex|opencode)-plugin[.]sh[^\n]*{re.escape(flag)}", release):
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
        for host in ("codex", "claude", "opencode")
    }
    options = {
        host: validate_options(host, root / f"scripts/test-{host}-plugin.sh", texts[host])
        for host in ("codex", "claude", "opencode")
    }
    for host in ("codex", "claude"):
        validate_direct_contract(host, root / f"scripts/test-{host}-plugin.sh", texts[host])
    validate_opencode_contract(root / "scripts/test-opencode-plugin.sh", texts["opencode"])
    package_test = root / "scripts/test-opencode-package.sh"
    validate_opencode_package_contract(package_test, read_text(package_test))
    validate_cross_host_contract(texts["codex"])
    validate_retained_safety(texts["codex"], texts["claude"])
    validate_matrix(root, plugin_root, options)
    print("ok - Claude/Codex direct lanes, OpenCode source/package lanes, retained safety gates, and inert deferred parser surfaces validated")


if __name__ == "__main__":
    main()
