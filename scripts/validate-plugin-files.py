#!/usr/bin/env python3
"""Static checks for Oh No Harness plugin files."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


PUBLIC_SKILLS = [
    "using-oh-no-harness",
    "deep-interview",
    "ralplan",
    "ralph",
    "autopilot",
    "auto-routing",
    "test-driven-development",
    "ai-slop-cleaner",
    "verification-before-completion",
    "systematic-debugging",
]

ALL_SKILLS = PUBLIC_SKILLS

AGENTS = [
    "explore",
    "analyst",
    "planner",
    "architect",
    "critic",
    "executor",
    "debugger",
    "verifier",
    "code-reviewer",
    "security-reviewer",
    "qa-tester",
]

REQUIRED_AGENT_FIELDS = {"name", "description", "tools", "model", "color"}
REQUIRED_SKILL_FIELDS = {"name", "description"}
WORKFLOW_SKILLS_REQUIRING_ARGUMENT_HINT = {
    "deep-interview",
    "ralplan",
    "ralph",
    "autopilot",
    "auto-routing",
    "test-driven-development",
    "ai-slop-cleaner",
    "verification-before-completion",
    "systematic-debugging",
}

# Skills whose body must declare a Next Skill Handoff section. The markers are
# structural: the heading tags the section, "HARD-GATE" tags the negative
# framing that forbids auto-invocation, and "Autopilot exception" tags the
# escape hatch documented for autopilot orchestration. Keep this contract in
# lockstep with skills/autopilot/SKILL.md and skills/using-oh-no-harness/SKILL.md.
NEXT_SKILL_GATE_REQUIRED = {"deep-interview", "ralplan"}
NEXT_SKILL_GATE_MARKERS = (
    "## Next Skill Handoff",
    "HARD-GATE",
    "Autopilot exception",
)
AUTOPILOT_EXCEPTION_HEADING = "## Autopilot Exception"

ROLE_POLICY_MARKERS = {
    "ralph": "## Mode-Gated Agent Dispatch",
    "ralplan": "Dispatch (when)",
    "systematic-debugging": "## Agent Roles",
    "autopilot": "## Agent Roles",
}
EXECUTION_MODE_SHARED_MARKERS = (
    "# Execution Modes",
    "Mode is required for every handoff to `ralph`.",
    "## Execution Mode Decision Prompt",
    "## LIGHT",
    "## STANDARD",
    "## THOROUGH",
    "`ralph` must read the execution profile before editing.",
    "What observable behavior, artifact, prompt, config, or documentation will",
    "Could the change affect runtime behavior",
    "Does the change alter agent behavior",
    "Can a lighter mode produce credible evidence",
    "What would force escalation while working",
)
EXECUTION_MODE_SKILL_MARKERS = {
    "using-oh-no-harness": (
        "required Ralph execution mode",
        "must set a `LIGHT`, `STANDARD`, or `THOROUGH` execution mode",
    ),
    "deep-interview": (
        "## Execution Sizing Hint",
        "Provisional Ralph mode",
        "docs/shared/execution-modes.md",
    ),
    "ralplan": (
        "## Execution Profile",
        "Overall Ralph mode",
        "Task sizing",
        "Execution profile recap",
        "immediately before `Approval needed`",
        "Ralph must follow this profile",
    ),
    "ralph": (
        "## Required Execution Mode",
        "## Mode-Gated Agent Dispatch",
        "Ralph must set an execution mode",
        "must follow the",
    ),
    "autopilot": (
        "docs/shared/execution-modes.md",
        "execution mode and mode source",
    ),
}
AGENT_SKILL_RELATIONSHIP_MARKERS = (
    "## Skill Relationship",
    "not a public workflow skill",
    "calling skill",
)
EXECUTION_MODE_AGENT_MARKERS = {
    "planner": (
        "execution profile",
        "task sizing",
    ),
    "architect": (
        "Ralph execution profile",
        "too light, too heavy",
    ),
    "critic": (
        "execution profile recap",
        "too light",
    ),
    "executor": (
        "assigned Ralph execution mode",
        "Execution mode followed",
    ),
    "verifier": (
        "selected execution mode",
        "Execution mode compliance",
    ),
    "security-reviewer": (
        "execution mode escalation",
    ),
    "qa-tester": (
        "heavier Ralph execution mode",
    ),
}


def die(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        die(f"missing file: {path}")


def parse_frontmatter(path: Path) -> dict[str, str]:
    text = read_text(path)
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        die(f"{path} is missing YAML frontmatter")

    frontmatter: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            return frontmatter
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            die(f"{path} has unsupported frontmatter line: {line}")
        key, value = line.split(":", 1)
        frontmatter[key.strip()] = value.strip().strip('"')

    die(f"{path} has unterminated YAML frontmatter")


def assert_skill(root: Path, skill: str) -> None:
    path = root / "skills" / skill / "SKILL.md"
    fm = parse_frontmatter(path)
    missing = REQUIRED_SKILL_FIELDS - set(fm)
    if missing:
        die(f"{path} missing frontmatter fields: {sorted(missing)}")
    expected_name = skill.split("/")[-1]
    if fm["name"] != expected_name:
        die(f"{path} name={fm['name']!r}, expected {expected_name!r}")
    if skill in WORKFLOW_SKILLS_REQUIRING_ARGUMENT_HINT and "argument-hint" not in fm:
        die(f"{path} should define argument-hint")
    if skill in NEXT_SKILL_GATE_REQUIRED:
        body = read_text(path)
        for marker in NEXT_SKILL_GATE_MARKERS:
            if marker not in body:
                die(f"{path} is missing required Next-Skill-Gate marker: {marker!r}")
    if skill == "autopilot":
        body = read_text(path)
        if AUTOPILOT_EXCEPTION_HEADING not in body:
            die(f"{path} is missing required heading: {AUTOPILOT_EXCEPTION_HEADING!r}")
    if skill in ROLE_POLICY_MARKERS:
        body = read_text(path)
        marker = ROLE_POLICY_MARKERS[skill]
        if marker not in body:
            die(f"{path} is missing required role-policy marker: {marker!r}")
    if skill in EXECUTION_MODE_SKILL_MARKERS:
        body = read_text(path)
        for marker in EXECUTION_MODE_SKILL_MARKERS[skill]:
            if marker not in body:
                die(f"{path} is missing required Execution-Mode marker: {marker!r}")


def assert_agent(root: Path, agent: str) -> None:
    path = root / "agents" / f"{agent}.md"
    fm = parse_frontmatter(path)
    missing = REQUIRED_AGENT_FIELDS - set(fm)
    if missing:
        die(f"{path} missing frontmatter fields: {sorted(missing)}")
    if fm["name"] != agent:
        die(f"{path} name={fm['name']!r}, expected {agent!r}")

    expected_model = "sonnet" if agent == "explore" else "inherit"
    if fm.get("model") != expected_model:
        die(f"{path} model={fm.get('model')!r}, expected {expected_model!r}")

    body = read_text(path)
    for marker in AGENT_SKILL_RELATIONSHIP_MARKERS:
        if marker not in body:
            die(f"{path} is missing required agent-skill boundary marker: {marker!r}")
    if agent in EXECUTION_MODE_AGENT_MARKERS:
        for marker in EXECUTION_MODE_AGENT_MARKERS[agent]:
            if marker not in body:
                die(f"{path} is missing required Execution-Mode agent marker: {marker!r}")


def assert_expected_references(root: Path) -> None:
    relationships = read_text(root / "docs/reference/relationships.md")
    for skill in PUBLIC_SKILLS:
        if not has_token(relationships, skill):
            die(f"relationships.md does not mention skill `{skill}`")
    for agent in AGENTS:
        if not has_token(relationships, agent):
            die(f"relationships.md does not mention agent `{agent}`")


def assert_execution_mode_contract(root: Path) -> None:
    path = root / "docs" / "shared" / "execution-modes.md"
    text = read_text(path)
    for marker in EXECUTION_MODE_SHARED_MARKERS:
        if marker not in text:
            die(f"{path} is missing required Execution-Mode contract marker: {marker!r}")


def assert_claude_manifest_skills(root: Path) -> None:
    path = root / ".claude-plugin/plugin.json"
    try:
        manifest = json.loads(read_text(path))
    except json.JSONDecodeError as exc:
        die(f"{path} is not valid JSON: {exc}")

    expected = [f"./skills/{skill}/" for skill in PUBLIC_SKILLS]
    actual = manifest.get("skills")
    if actual != expected:
        die(
            f"{path} skills array should list public skill directories in order. "
            f"expected={expected!r} actual={actual!r}"
        )


def has_token(text: str, token: str) -> bool:
    return re.search(rf"(^|[^A-Za-z0-9_-]){re.escape(token)}([^A-Za-z0-9_-]|$)", text) is not None


def assert_no_omc_runtime_coupling(root: Path) -> None:
    forbidden = [
        r"\bTask\(",
        r"\bSkill\(",
    ]
    checked_paths = list((root / "skills").glob("**/*.md")) + list((root / "agents").glob("*.md"))
    for path in checked_paths:
        text = read_text(path)
        for pattern in forbidden:
            if re.search(pattern, text, flags=re.IGNORECASE):
                die(f"{path} contains forbidden OMC-style runtime coupling pattern: {pattern}")


def assert_no_deprecated_artifact_paths(root: Path) -> None:
    checked_paths = (
        list((root / "skills").glob("**/*.md"))
        + list((root / "agents").glob("*.md"))
        + [
            root / "README.md",
            root / "AGENTS.md",
            root / "docs/reference/migration-from-omc.md",
            root / "docs/reference/relationships.md",
        ]
    )
    for path in checked_paths:
        text = read_text(path)
        if "docs/oh-no" in text:
            die(f"{path} contains deprecated artifact path `docs/oh-no`; use `.oh-no/specs`, `.oh-no/plans`, or `.oh-no/sessions`")


def main() -> None:
    if len(sys.argv) != 2:
        die("usage: validate-plugin-files.py <plugin-root>")

    root = Path(sys.argv[1]).resolve()
    for skill in ALL_SKILLS:
        assert_skill(root, skill)
    for agent in AGENTS:
        assert_agent(root, agent)
    assert_execution_mode_contract(root)
    assert_claude_manifest_skills(root)
    assert_expected_references(root)
    assert_no_omc_runtime_coupling(root)
    assert_no_deprecated_artifact_paths(root)
    print("ok - skill and agent files passed static checks")


if __name__ == "__main__":
    main()
