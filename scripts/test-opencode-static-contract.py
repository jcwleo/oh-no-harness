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
        restore = mutate_text(
            main_source,
            "No-route means no workflow transition, not no investigation",
            "No-route means no investigation",
        )
        expect_rejected(
            "OpenCode no-route investigation requirement weakened",
            lambda: validator.assert_opencode_main_grounding_contract(root),
        )
        restore()

        restore = mutate_text(
            main_source,
            "Ground material repository claims in observed tool output",
            "Consider repository evidence before answering",
        )
        expect_rejected(
            "OpenCode observed-output grounding requirement removed",
            lambda: validator.assert_opencode_main_grounding_contract(root),
        )
        restore()

        restore = mutate_text(
            main_source,
            "sizeable investigation to `oh-no-explore`",
            "sizeable investigation directly",
        )
        expect_rejected(
            "OpenCode investigation escalation requirement removed",
            lambda: validator.assert_opencode_main_grounding_contract(root),
        )
        restore()

        for label, old, new in (
            (
                "OpenCode named-file reading requirement qualified",
                "read every named file before answering and do not speculate",
                "read every named file before answering only when convenient and do not speculate",
            ),
            (
                "OpenCode unread-code speculation requirement qualified",
                "do not speculate\nabout unread code. Ground",
                "do not speculate\nabout unread code unless it seems likely. Ground",
            ),
            (
                "OpenCode observed-output grounding requirement qualified",
                "Ground material repository claims in observed tool output;",
                "Ground material repository claims in observed tool output when available;",
            ),
            (
                "OpenCode path-or-line evidence requirement qualified",
                "include relevant paths or lines when useful. Use",
                "include relevant paths or lines when useful only if convenient. Use",
            ),
            (
                "OpenCode bounded direct lookup requirement qualified",
                "Use direct read/search for a\nbounded question with a known location;",
                "Use direct read/search for a\nbounded question with a known location only after a workflow transition;",
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
                lambda: validator.assert_opencode_main_grounding_contract(root),
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
