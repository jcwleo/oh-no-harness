#!/usr/bin/env python3
"""Mutation checks for first-class OpenCode static validation."""

from __future__ import annotations

import argparse
import importlib.util
import json
import tempfile
from pathlib import Path
from types import ModuleType
from typing import Callable

from plugin_fixture import copy_plugin_fixture


def load_validator(marketplace_root: Path) -> ModuleType:
    path = marketplace_root / "scripts" / "validate-plugin-files.py"
    spec = importlib.util.spec_from_file_location("oh_no_validator", path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"unable to load validator: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def expect_rejected(label: str, validate: Callable[[], None]) -> None:
    try:
        validate()
    except SystemExit:
        return
    raise SystemExit(f"mutation was not rejected: {label}")


def mutate_text(path: Path, old: str, new: str) -> Callable[[], None]:
    original = path.read_text(encoding="utf-8")
    if old not in original:
        raise SystemExit(f"mutation anchor missing in {path}: {old!r}")
    path.write_text(original.replace(old, new, 1), encoding="utf-8")
    return lambda: path.write_text(original, encoding="utf-8")


def assert_fixture_copy_excludes_runtime_state(temp_dir: str) -> None:
    source = Path(temp_dir) / "fixture-source"
    source.mkdir()
    (source / "tracked-marker.txt").write_text("tracked\n", encoding="utf-8")
    runtime_state = source / ".oh-no" / "test-runs"
    runtime_state.mkdir(parents=True)
    (runtime_state / "sentinel.txt").write_text("runtime\n", encoding="utf-8")

    destination = Path(temp_dir) / "fixture-copy"
    copy_plugin_fixture(source, destination)

    if (destination / "tracked-marker.txt").read_text(encoding="utf-8") != "tracked\n":
        raise SystemExit("fixture copy did not preserve tracked content")
    if (destination / ".oh-no").exists():
        raise SystemExit("fixture copy retained plugin-local .oh-no runtime state")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--marketplace-root", type=Path, required=True)
    parser.add_argument("--plugin-root", type=Path, required=True)
    args = parser.parse_args()
    validator = load_validator(args.marketplace_root.resolve())

    with tempfile.TemporaryDirectory() as temp_dir:
        assert_fixture_copy_excludes_runtime_state(temp_dir)
        root = Path(temp_dir) / "oh-no-harness"
        copy_plugin_fixture(args.plugin_root.resolve(), root)

        wrapper = root / "skills-opencode" / "ralph" / "SKILL.md"
        restore = mutate_text(wrapper, "# Ralph for OpenCode", "# Ralph for OpenCode\n\nTask(")
        expect_rejected(
            "Claude Task invocation in OpenCode wrapper",
            lambda: validator.assert_skill_wrapper(root, "ralph", "skills-opencode", "opencode"),
        )
        restore()

        restore = mutate_text(wrapper, "description:", "unknown-opencode-key: forbidden\ndescription:")
        expect_rejected(
            "unknown OpenCode frontmatter key",
            lambda: validator.assert_skill_wrapper(root, "ralph", "skills-opencode", "opencode"),
        )
        restore()

        main_source = root / "docs" / "platforms" / "opencode-main-agent.md"
        validator.assert_opencode_main_prompt_contract(root)

        restore = mutate_text(
            main_source,
            "No-route means no workflow transition, not no investigation",
            "No-route means no investigation",
        )
        expect_rejected(
            "OpenCode no-route investigation requirement weakened",
            lambda: validator.assert_opencode_main_prompt_contract(root),
        )
        restore()

        restore = mutate_text(
            main_source,
            "inspect relevant source-of-truth evidence with\ntools, even when no file is named",
            "consider repository evidence before answering",
        )
        expect_rejected(
            "OpenCode tool-before-fact grounding requirement removed",
            lambda: validator.assert_opencode_main_prompt_contract(root),
        )
        restore()

        restore = mutate_text(
            main_source,
            "Injected summaries, memory,\nnaming, and internal knowledge may guide lookup but are not repository evidence",
            "Injected summaries, memory,\nnaming, and internal knowledge are repository evidence",
        )
        expect_rejected(
            "OpenCode non-evidence lookup-aid requirement removed",
            lambda: validator.assert_opencode_main_prompt_contract(root),
        )
        restore()

        restore = mutate_text(
            main_source,
            "loaded runtime or configuration\nseparately from checkout source",
            "checkout source",
        )
        expect_rejected(
            "OpenCode active-runtime distinction removed",
            lambda: validator.assert_opencode_main_prompt_contract(root),
        )
        restore()

        restore = mutate_text(
            main_source,
            "label\nthe claim unverified rather than assert it",
            "assert the claim from available context",
        )
        expect_rejected(
            "OpenCode unverified fallback removed",
            lambda: validator.assert_opencode_main_prompt_contract(root),
        )
        restore()

        restore = mutate_text(
            main_source,
            "Stop when enough\ndirectly relevant evidence supports the answer or no next lookup is likely to\nmaterially change it; report remaining uncertainty",
            "Continue investigating until every repository detail is known",
        )
        expect_rejected(
            "OpenCode bounded evidence stop removed",
            lambda: validator.assert_opencode_main_prompt_contract(root),
        )
        restore()

        for label, old, new in (
            (
                "OpenCode named-file reading requirement qualified",
                "Read every relevant named file before\nanswering and do not speculate",
                "Read every relevant named file before\nanswering only when convenient and do not speculate",
            ),
            (
                "OpenCode unread-code speculation requirement qualified",
                "do not speculate about unread code. Injected",
                "do not speculate about unread code unless it seems likely. Injected",
            ),
            (
                "OpenCode observed-output grounding requirement qualified",
                "Ground material repository claims in\nobserved tool output;",
                "Ground material repository claims in\nobserved tool output when available;",
            ),
            (
                "OpenCode path-or-line evidence requirement qualified",
                "include relevant paths or lines when useful. Use",
                "include relevant paths or lines when useful only if convenient. Use",
            ),
            (
                "OpenCode bounded direct lookup requirement qualified",
                "read/search for a bounded question with a known location;",
                "read/search for a bounded question with a known location only after a workflow transition;",
            ),
            (
                "OpenCode explore escalation requirement qualified",
                "sizeable investigation to `oh-no-explore`.",
                "sizeable investigation to `oh-no-explore` only after a workflow transition.",
            ),
        ):
            restore = mutate_text(main_source, old, new)
            expect_rejected(
                label,
                lambda: validator.assert_opencode_main_prompt_contract(root),
            )
            restore()

        # These mutations preserve old section-local markers while weakening the
        # complete main-prompt contract. They must be rejected by the validator,
        # not merely by the source's current formatting.
        for label, old, new in (
            (
                "OpenCode forbidden role catalog relocated outside Orchestration",
                "## Models And Concurrency",
                "Role map:\n\n- `oh-no-explore`: read-only repository lookup and tracing\n\n## Models And Concurrency",
            ),
            (
                "OpenCode forbidden positive routing relocated outside Planning Boundary",
                "## Child Packet Floor",
                "A usable approved or concrete execution contract goes to `ralph`.\n\n## Child Packet Floor",
            ),
            (
                "OpenCode forbidden task schema relocated outside Models And Concurrency",
                "## Orchestration",
                "Each `task` dispatch uses exact `subagent_type: oh-no-<role>` and carries no per-call model value.\n\n## Orchestration",
            ),
            (
                "OpenCode forbidden same-turn task instruction relocated into a new section",
                "## Planning Boundary",
                "## Retired Task Mechanics\n\nIssue independent `task` calls in one assistant turn.\n\n## Planning Boundary",
            ),
            (
                "OpenCode repository-fact inspection qualified",
                "inspect relevant source-of-truth evidence with\ntools, even when no file is named.",
                "inspect relevant source-of-truth evidence with\ntools when convenient, even when no file is named.",
            ),
            (
                "OpenCode active-runtime inspection negated",
                "Claims about active behavior require inspecting loaded runtime or configuration\nseparately from checkout source;",
                "Claims about active behavior does not require inspecting loaded runtime or configuration\nseparately from checkout source;",
            ),
            (
                "OpenCode skill-use and deliverable boundary removed",
                "Use OpenCode's native `skill` tool to load the relevant Oh No Harness skill when\nit applies. A workflow name used only as the subject of analysis, explanation,\ncomparison, or critique is not an invocation trigger; route from the requested\ndeliverable.",
                "Workflow names may be loaded opportunistically.",
            ),
            (
                "OpenCode no-route definition weakened",
                "No-route lane: answer directly when the request neither creates nor changes\nrepository work products nor claims their completion.",
                "No-route lane: answer directly when the request does not necessarily create repository work products.",
            ),
            (
                "OpenCode direct-edit failover removed",
                "If\nany condition fails or becomes false, load `ralph`.",
                "If any condition fails or becomes false, continue the direct edit.",
            ),
            (
                "OpenCode caller ownership and executor floor weakened",
                "The main agent owns conversation flow, `.oh-no` state, gates, synthesis, and\nworkflow transitions. STANDARD and THOROUGH repository work-product mutations\nuse `oh-no-executor`; inline mutation is limited to a recorded LIGHT-tiny or\nconfirmed dispatch-unavailable fallback.",
                "External callers own workflow state and may mutate repository work products inline.",
            ),
            (
                "OpenCode Child Packet Floor obligation qualified",
                "Every role packet is proportional, self-contained English and states:",
                "Every role packet is proportional, self-contained English and states when convenient:",
            ),
            (
                "OpenCode workflow-internal role boundary weakened",
                "Planner, Plan-Reviewer, and Fusion Rescue panels remain workflow-internal.",
                "Planner, Plan-Reviewer, and Fusion Rescue panels may run outside workflows.",
            ),
            (
                "OpenCode unmatched defaults removed",
                "Outside a selected workflow, default unmatched read-only work to\n`oh-no-explore` and mutation to `oh-no-executor`.",
                "Outside a selected workflow, choose any role for unmatched work.",
            ),
            (
                "OpenCode inherited-model truth removed",
                "an\nunconfigured role inherits the current primary model.",
                "an unconfigured role chooses an arbitrary model.",
            ),
            (
                "OpenCode model-diversity truth reversed",
                "Never claim model\ndiversity without distinct runtime-proven model identities.",
                "Claim model diversity without distinct runtime-proven model identities.",
            ),
            (
                "OpenCode foreground lifecycle qualified",
                "Use foreground completion as the\nnormal wait, and consume every result.",
                "Use foreground completion as the\nnormal wait when convenient, and consume every result.",
            ),
            (
                "OpenCode no-poll and no-duplicate lifecycle reversed",
                "never poll, duplicate a slow task, or redo\ndelegated work inline.",
                "may poll, duplicate a slow task, or redo delegated work inline.",
            ),
            (
                "OpenCode approval wait/load/stop gate weakened",
                "Handoff, use `question`, wait for approval, then load the selected skill with\n`skill`; otherwise stop at the current skill's outcome.",
                "Handoff, use `question`, load the selected skill immediately, and otherwise continue.",
            ),
        ):
            restore = mutate_text(main_source, old, new)
            expect_rejected(
                label,
                lambda: validator.assert_opencode_main_prompt_contract(root),
            )
            restore()

        for label, old, new in (
            (
                "OpenCode static role catalog reintroduced",
                "Planner, Plan-Reviewer, and Fusion Rescue panels remain workflow-internal.",
                "Role map:\n\n- `oh-no-explore`: read-only repository lookup and tracing\n\nPlanner, Plan-Reviewer, and Fusion Rescue panels remain workflow-internal.",
            ),
            (
                "OpenCode concrete-work positive mapping reintroduced",
                "No-route housekeeping remains direct.",
                "A usable approved or concrete execution contract goes to `ralph`. No-route housekeeping remains direct.",
            ),
            (
                "OpenCode vague-work positive mapping reintroduced",
                "No-route housekeeping remains direct.",
                "Vague work goes to `interview`. No-route housekeeping remains direct.",
            ),
            (
                "OpenCode broad-work positive mapping reintroduced",
                "No-route housekeeping remains direct.",
                "Broad or strategy-unclear work with known requirements goes to `ralplan`. No-route housekeeping remains direct.",
            ),
            (
                "OpenCode task-schema mechanics reintroduced",
                "A configured role uses its stored provider/model ID",
                "Each `task` dispatch uses exact `subagent_type: oh-no-<role>` and carries no per-call model value. A configured role uses its stored provider/model ID",
            ),
            (
                "OpenCode same-turn independent task instruction reintroduced",
                "Run at most five subagents concurrently",
                "Issue independent `task` calls in one assistant turn. Run at most five subagents concurrently",
            ),
            (
                "OpenCode non-review need test removed",
                "One need test governs every non-review role",
                "Need tests are optional for non-review roles",
            ),
            (
                "OpenCode mandatory separate review context removed",
                "always uses a separate `task` context",
                "may run inline",
            ),
            (
                "OpenCode unmatched role defaults removed",
                "default unmatched read-only work to\n`oh-no-explore` and mutation to `oh-no-executor`",
                "choose any role for unmatched work",
            ),
            (
                "OpenCode independent-context withholding removed",
                "Initial independent review, verification, and debugging packets withhold maker\nconclusions",
                "Initial independent review, verification, and debugging packets share maker\nconclusions",
            ),
            (
                "OpenCode no-extra-host-plan boundary removed",
                "Do not switch to OpenCode's primary `plan` agent",
                "Switch to OpenCode's primary `plan` agent",
            ),
            (
                "OpenCode configured-model behavior removed",
                "A configured role uses its stored provider/model ID",
                "A configured role may use any model",
            ),
            (
                "OpenCode concurrency cap removed",
                "Run at most five subagents concurrently",
                "Run any number of subagents concurrently",
            ),
            (
                "OpenCode result-consumption requirement removed",
                "consume every result",
                "consider results when convenient",
            ),
            (
                "OpenCode dependent-role sequencing removed",
                "Dependent roles remain sequential.",
                "Dependent roles may overlap.",
            ),
            (
                "OpenCode approval-gated skill chaining removed",
                "otherwise stop at the current skill's outcome.",
                "otherwise continue without approval.",
            ),
        ):
            restore = mutate_text(main_source, old, new)
            expect_rejected(
                label,
                lambda: validator.assert_opencode_main_prompt_contract(root),
            )
            restore()

        agents_path = root / "opencode" / "generated" / "agents.json"
        agents = json.loads(agents_path.read_text(encoding="utf-8"))
        original_agents = agents_path.read_text(encoding="utf-8")
        agents["oh-no-explore"]["tools"] = {"read": True}
        agents_path.write_text(json.dumps(agents, indent=2) + "\n", encoding="utf-8")
        expect_rejected(
            "OpenCode tools agent field",
            lambda: validator.assert_opencode_generated_agents(root),
        )
        agents_path.write_text(original_agents, encoding="utf-8")

        agents = json.loads(original_agents)
        agents["oh-no"]["permission"]["oh_no_get_model_catalog"] = "allow"
        agents_path.write_text(json.dumps(agents, indent=2) + "\n", encoding="utf-8")
        expect_rejected(
            "OpenCode primary model catalog allow",
            lambda: validator.assert_opencode_generated_agents(root),
        )
        agents_path.write_text(original_agents, encoding="utf-8")

        agents = json.loads(original_agents)
        del agents["oh-no"]["permission"]["question"]
        agents_path.write_text(json.dumps(agents, indent=2) + "\n", encoding="utf-8")
        expect_rejected(
            "OpenCode primary without question allow",
            lambda: validator.assert_opencode_generated_agents(root),
        )
        agents_path.write_text(original_agents, encoding="utf-8")

        agents = json.loads(original_agents)
        agents["oh-no"]["permission"]["oh_no_configure_subagents"] = "allow"
        agents_path.write_text(json.dumps(agents, indent=2) + "\n", encoding="utf-8")
        expect_rejected(
            "OpenCode primary custom configurator allow",
            lambda: validator.assert_opencode_generated_agents(root),
        )
        agents_path.write_text(original_agents, encoding="utf-8")

        agents = json.loads(original_agents)
        agents["oh-no-executor"]["permission"]["oh_no_configure_subagents"] = "ask"
        agents_path.write_text(json.dumps(agents, indent=2) + "\n", encoding="utf-8")
        expect_rejected(
            "OpenCode subagent custom configurator ask",
            lambda: validator.assert_opencode_generated_agents(root),
        )
        agents_path.write_text(original_agents, encoding="utf-8")

        package_path = root / "package.json"
        restore = mutate_text(
            package_path,
            '"exports": "./opencode/index.js"',
            '"exports": "./opencode/preferences.js"',
        )
        expect_rejected(
            "npm package entrypoint drift",
            lambda: validator.assert_opencode_runtime_contract(root),
        )
        restore()

        setup_path = root / "opencode" / "setup.js"
        restore = mutate_text(
            setup_path,
            "refusing symbolic-link config",
            "following symbolic-link config",
        )
        expect_rejected(
            "setup CLI symlink refusal removed",
            lambda: validator.assert_opencode_runtime_contract(root),
        )
        restore()

        index_path = root / "opencode" / "index.js"
        restore = mutate_text(
            index_path,
            "const rolePermission = existingAgents[name]?.permission;",
            "const rolePermission = undefined;",
        )
        expect_rejected(
            "same-name per-agent permission intersection removed",
            lambda: validator.assert_opencode_runtime_contract(root),
        )
        restore()

        restore = mutate_text(
            index_path,
            "pattern: VARIANT_SCHEMA_PATTERN,",
            "pattern: \".*\",",
        )
        expect_rejected(
            "custom configurator exact variant schema removed",
            lambda: validator.assert_opencode_runtime_contract(root),
        )
        restore()

        restore = mutate_text(
            index_path,
            'if (tool.includes("*") || tool.includes("?")) {',
            "if (false) {",
        )
        expect_rejected(
            "wildcard permission patterns accepted as concrete tool names",
            lambda: validator.assert_opencode_runtime_contract(root),
        )
        restore()

        restore = mutate_text(
            index_path,
            'const primaryPermission = existingAgents["oh-no"]?.permission;',
            "const primaryPermission = undefined;",
        )
        expect_rejected(
            "package-primary permission ceiling removed from subagents",
            lambda: validator.assert_opencode_runtime_contract(root),
        )
        restore()

        restore = mutate_text(
            index_path,
            "const permission = restrictivePermission([...agentCeilings, packagePermission]);",
            "const permission = { ...packagePermission };",
        )
        expect_rejected(
            "arbitrary inherited permission preservation removed",
            lambda: validator.assert_opencode_runtime_contract(root),
        )
        restore()

        restore = mutate_text(
            index_path,
            'if (action !== "ask" && action !== "deny") return;',
            'if (action !== "allow" && action !== "ask" && action !== "deny") return;',
        )
        expect_rejected(
            "per-agent allow filtering removed",
            lambda: validator.assert_opencode_runtime_contract(root),
        )
        restore()

        restore = mutate_text(
            index_path,
            "if (candidate !== undefined) action = candidate;",
            "action = candidate;",
        )
        expect_rejected(
            "native flattened inner-target semantics removed",
            lambda: validator.assert_opencode_runtime_contract(root),
        )
        restore()

        restore = mutate_text(
            index_path,
            "pattern: MODEL_SCHEMA_PATTERN,",
            "pattern: \".*\",",
        )
        expect_rejected(
            "custom configurator exact model schema removed",
            lambda: validator.assert_opencode_runtime_contract(root),
        )
        restore()

        restore = mutate_text(
            index_path,
            "await context.ask({",
            "// host permission request removed",
        )
        expect_rejected(
            "custom configurator host ask removed",
            lambda: validator.assert_opencode_runtime_contract(root),
        )
        restore()

        writer_path = root / "opencode" / "preference-writer.js"
        restore = mutate_text(writer_path, "published = true;", "// publication tracking removed")
        expect_rejected(
            "post-rename publication tracking removed",
            lambda: validator.assert_opencode_runtime_contract(root),
        )
        restore()

        helper_path = root / "opencode" / "configure-opencode-subagents"
        restore = mutate_text(
            helper_path,
            'if (command !== "check" || args.length !== 0)',
            'if (!["check", "apply"].includes(command) || args.length !== 0)',
        )
        expect_rejected(
            "legacy CLI apply accepted",
            lambda: validator.assert_opencode_runtime_contract(root),
        )
        restore()

        setup_source = root / "docs" / "platforms" / "opencode-configure-subagents.md"
        restore = mutate_text(
            setup_source,
            "Continue only when the current user request explicitly asks to configure",
            "Continue when setup seems useful",
        )
        expect_rejected(
            "missing explicit-current-user setup gate",
            lambda: validator.assert_opencode_configure_subagents_contract(root),
        )
        restore()

        restore = mutate_text(
            setup_source,
            "call `oh_no_configure_subagents` exactly once",
            "call `oh_no_configure_subagents` once per role",
        )
        expect_rejected(
            "custom configurator exactly-once call removed",
            lambda: validator.assert_opencode_configure_subagents_contract(root),
        )
        restore()

        extra = root / "skills-opencode" / "install-statusline"
        extra.mkdir()
        (extra / "SKILL.md").write_text("unexpected\n", encoding="utf-8")
        expect_rejected(
            "extra OpenCode wrapper",
            lambda: validator.assert_exact_opencode_skill_inventory(root),
        )

    print("ok - OpenCode static mutation contracts reject targeted drift")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
