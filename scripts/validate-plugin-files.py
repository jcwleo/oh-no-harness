#!/usr/bin/env python3
"""Static checks for Oh No Harness plugin files."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


PUBLIC_SKILLS = [
    "using-oh-no-harness",
    "interview",
    "ralplan",
    "ralph",
    "autopilot",
    "auto-routing",
    "test-driven-development",
    "simplify",
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
REQUIRED_COMMAND_FIELDS = {"description", "argument-hint"}
WORKFLOW_SKILLS_REQUIRING_ARGUMENT_HINT = {
    "using-oh-no-harness",
    "interview",
    "ralplan",
    "ralph",
    "autopilot",
    "auto-routing",
    "test-driven-development",
    "simplify",
    "verification-before-completion",
    "systematic-debugging",
}
COMMAND_WRAPPERS = PUBLIC_SKILLS
COMMAND_DELEGATION_MARKER = (
    "Read the file at `${{CLAUDE_PLUGIN_ROOT}}/skills-claude/{skill}/SKILL.md` using the Read tool "
    "and follow its instructions exactly."
)
PLUGIN_NAME = "oh-no-harness"
MARKETPLACE_PLUGIN_PATH = f"./plugins/{PLUGIN_NAME}"
CODEX_SKILL_ROOT = "skills"
CLAUDE_SKILL_ROOT = "skills-claude"
SKILL_CORE_ROOT = "docs/skill-core"
PROVIDER_DOC_ROOT = "docs/providers"

# Skills whose body must declare a Next Skill Handoff section. The markers are
# structural: the heading tags the section, "HARD-GATE" tags the negative
# framing that forbids auto-invocation, and "Autopilot exception" tags the
# escape hatch documented for autopilot orchestration. Keep this contract in
# lockstep with skills/autopilot/SKILL.md and skills/using-oh-no-harness/SKILL.md.
NEXT_SKILL_GATE_REQUIRED = {"interview", "ralplan"}
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
PLATFORM_SUBAGENT_MARKERS = {
    "using-oh-no-harness": (
        "This core file does not define platform invocation syntax",
        "matching platform file named by that wrapper",
        "Agents remain role prompts inside a selected skill",
    ),
    "ralph": (
        "Parallel trigger",
        "dispatch targeted subagents by default",
        "whole eligible batch",
        "active adapter invocation syntax",
        "Role: {explore|executor|architect|critic|verifier|code-reviewer|security-reviewer|qa-tester}",
        "Agent prompt source: agents/{role}.md",
    ),
    "ralplan": (
        "ralph with parallel subagents",
        "Run ralph with parallel subagents",
        "must run as sequential subagents",
        "parallel subagent dispatch plan",
        "active platform wrapper's dispatch policy",
        "Planner Draft Contract",
        "Architect Review Contract",
        "Critic Review Contract",
        "Planner Revision Contract",
    ),
    "autopilot": (
        "independent context",
        "Parallel trigger: natural-dispatch",
    ),
}
PLATFORM_RULE_DOC_MARKERS = {
    "codex.md": (
        "# Codex Platform Rules",
        "## Skill Loading",
        "## User Approval",
        "## Auto Routing",
        "## OpenAI-Aligned Prompting",
        "docs/providers/openai.md",
        "outcome-first",
        "## Role Dispatch",
        "spawn_agent",
        "## Role Prompt Embedding",
        "Agent prompt source: agents/<role>.md",
        "docs/platforms/codex-ralph.md",
    ),
    "claude-code.md": (
        "# Claude Code Platform Rules",
        "## Skill Loading",
        "skills-claude/",
        "## User Approval",
        "## Auto Routing",
        "CLAUDE_PLUGIN_ROOT",
        "## Task Tracking",
        "## Anthropic-Aligned Prompting",
        "docs/providers/anthropic.md",
        "sectioned",
        "## Role Dispatch",
        "Workflow `agent()`",
        "oh-no-harness:<role>",
        "docs/platforms/claude-code-ralph.md",
    ),
}
PROVIDER_DOC_MARKERS = {
    "openai.md": (
        "# OpenAI Provider Prompt Guidance",
        "maintenance reference",
        "company-scoped, not model-scoped",
        "docs/platforms/codex.md",
        "https://developers.openai.com/api/docs/guides/latest-model",
        "https://developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide",
        "Do not create model-named provider files",
    ),
    "anthropic.md": (
        "# Anthropic Provider Prompt Guidance",
        "maintenance reference",
        "company-scoped, not model-scoped",
        "docs/platforms/claude-code.md",
        "https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-8",
        "https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices",
        "https://code.claude.com/docs/en/subagents",
        "Do not create model-named provider files",
    ),
}
PLATFORM_SUBAGENT_DOC_MARKERS = {
    "agent-tiers.md": (
        "docs/shared/ralph-subagent-policy.md",
        "docs/platforms/codex-ralph.md",
    ),
    "execution-modes.md": (
        "Parallel trigger",
        "docs/shared/ralph-subagent-policy.md",
    ),
    "parallel-subagents.md": (
        "## Platform Invocation",
        "docs/shared/ralph-subagent-policy.md",
        "batch dispatch, subagent",
        "docs/platforms/claude-code-ralph.md",
        "docs/platforms/codex-ralph.md",
    ),
}
RALPH_SUBAGENT_POLICY_MARKERS = (
    "# Ralph Subagent Policy",
    "## Subagent Bias",
    "use subagents as much as possible",
    "dispatch by default",
    "## Subagent-Unavailable Environments",
    "prefer dispatch over silently compressing every role",
    "platform's subagent",
    "## Batch Rule",
    "eligible batch first",
    "They must not revert, overwrite, reformat, or broaden work outside their",
)
PLATFORM_ADAPTER_DOC_MARKERS = {
    "claude-code-ralph.md": (
        "CLAUDE_CODE_ONLY_RALPH_ADAPTER",
        "Workflow `agent()`",
        "oh-no-harness:<agent>",
        "@agent-oh-no-harness:<agent>",
        "background subagents",
    ),
    "codex-ralph.md": (
        "CODEX_ONLY_RALPH_ADAPTER",
        "## Dispatch Decision",
        "## Role Prompt Embedding",
        "Agent prompt source: agents/<role>.md",
        "Agent prompt content:",
        "spawn_agent",
        "wait_agent",
        "Parallel trigger: none",
        "Parallel trigger: natural-dispatch",
    ),
}
PLATFORM_ADAPTER_FORBIDDEN_MARKERS = {
    "claude-code-ralph.md": ("spawn_agent", "CODEX_ONLY_RALPH_ADAPTER"),
    "codex-ralph.md": ("@agent-oh-no-harness:<agent>", "CLAUDE_CODE_ONLY_RALPH_ADAPTER"),
}
WORKTREE_SHARED_MARKERS = (
    "# Worktree Isolation",
    "## HARD-GATE",
    "`interview` and `ralplan` do not need to run inside a worktree by default",
    "`Worktree decision`",
    "Profile policy values:",
    "`direct-automatic-worktree`",
    "`autopilot` also uses automatic worktree execution",
    "integration checkout",
    "post-merge verification",
)
WORKTREE_SKILL_MARKERS = {
    "using-oh-no-harness": (
        "## Worktree Isolation Default",
        "docs/shared/worktree-isolation.md",
        "Worktree decision: direct automatic worktree",
        "Worktree decision: autopilot automatic worktree",
    ),
    "ralplan": (
        "Worktree policy",
        "docs/shared/worktree-isolation.md",
    ),
    "ralph": (
        "## Worktree Isolation Gate",
        "<HARD-GATE>",
        "Worktree decision: direct automatic worktree",
        "Worktree decision: autopilot automatic worktree",
        "integration checkout and post-merge verification",
    ),
    "autopilot": (
        "## Automatic Worktree Execution",
        "Worktree decision: autopilot automatic worktree",
        "post-merge verification",
    ),
}
WORKTREE_AGENT_MARKERS = {
    "planner": (
        "Worktree policy",
        "direct-automatic-worktree",
        "automatic-worktree-merge",
    ),
    "architect": (
        "Worktree policy",
        "automatic worktree execution plus merge",
    ),
    "critic": (
        "Worktree policy",
        "automatic worktree execution and merge responsibility",
    ),
    "executor": (
        "Worktree decision",
        "docs/shared/worktree-isolation.md",
    ),
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
    "Worktree policy",
    "Worktree decision",
)
EXECUTION_MODE_SKILL_MARKERS = {
    "using-oh-no-harness": (
        "required Ralph execution mode",
        "must set a `LIGHT`, `STANDARD`, or `THOROUGH` execution mode",
    ),
    "interview": (
        "## Execution Sizing Hint",
        "## Socratic Interview Method",
        "## Question Routing",
        "## Answer Capture",
        "## Dialectic Rhythm Guard",
        "## Spec Readiness Guard",
        "## Goal Restatement Gate",
        "Provisional Ralph mode",
        "docs/shared/execution-modes.md",
    ),
    "ralplan": (
        "## Execution Profile",
        "## Test Case Design Quality",
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
        "active platform wrapper",
    ),
}
SKILL_REQUIRED_AGENT_ROLES = {
    "interview": ("explore",),
    "ralplan": ("explore", "analyst", "planner", "architect", "critic"),
    "ralph": (
        "explore",
        "executor",
        "architect",
        "critic",
        "verifier",
        "code-reviewer",
        "security-reviewer",
        "qa-tester",
    ),
    "autopilot": (
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
    ),
    "systematic-debugging": (
        "debugger",
        "explore",
        "executor",
        "verifier",
        "architect",
    ),
    "verification-before-completion": (
        "verifier",
        "code-reviewer",
        "security-reviewer",
        "qa-tester",
    ),
}
SKILLS_WITHOUT_REQUIRED_AGENT_DEPENDENCY: set[str] = set()
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

SIMPLICITY_SCOPE_SKILL_MARKERS = {
    "ralplan": (
        "minimal viable approach",
        "rejected speculative complexity",
    ),
    "ralph": (
        "## Scope Trace Gate",
        "Every changed file and every meaningful changed line",
        "speculative abstraction",
    ),
    "simplify": (
        "Speculative abstraction",
    ),
}
SIMPLIFY_PARALLEL_MARKERS = (
    "requires four cleanup subagents",
    "Always launch the Reuse",
    "subagents in parallel",
    "Do not replace this with an inline review pass",
    "cannot dispatch",
    "stop and report",
    "Launch four independent cleanup subagents in parallel",
    "in one batch before",
    "Do not run these four review angles inline",
    "Wait for all four cleanup subagents to complete",
)
SIMPLIFY_WRAPPER_MARKERS = (
    "requires four parallel cleanup subagents",
    "Do not replace them",
    "cannot run as designed",
)
SIMPLICITY_SCOPE_AGENT_MARKERS = {
    "planner": (
        "smallest approach",
        "Rejected speculative complexity",
    ),
    "architect": (
        "Simplest sufficient approach assessment",
    ),
    "critic": (
        "speculative abstraction",
        "untraceable changes",
        "senior-engineer overcomplication check",
    ),
    "executor": (
        "Scope trace summary",
        "Match the surrounding code style",
    ),
    "code-reviewer": (
        "untraceable changes",
        "drive-by formatting",
    ),
}
APPROVED_DIRECTION_AGENT_MARKERS = {
    "architect": (
        "approved interview spec",
        "user-approved plan direction",
        "Direction-preservation concerns",
        "silently replace it with your own direction",
    ),
    "critic": (
        "interview spec",
        "user-approved plan direction",
        "Direction-preservation findings",
        "do not replace it with your own direction",
    ),
}
RALPLAN_CONSENSUS_MARKERS = (
    "## Consensus Order Gate",
    "## Direction Preservation Gate",
    "## Test Case Design Quality",
    "Ralplan has no basic planning mode",
    "## Requirements Source And Analyst Gate",
    "## Planner Draft Contract",
    "## Architect Review Contract",
    "## Critic Review Contract",
    "## Planner Revision Contract",
    "Planner draft v1",
    "Architect review v1",
    "Critic review v1",
    "Planner revision v2",
    "Analyst -> Planner -> Architect -> Critic",
    "The plan is invalid if it contains only Planner output",
    "The plan is invalid if Architect or Critic only add comments",
    "consensus loop log showing Analyst -> Planner -> Architect -> Critic in order",
    "requested direction change",
    "do not incorporate the new direction into the plan unless the user explicitly",
    "must-fail-before-implementation",
    "must-pass-after-implementation",
    "negative or forbidden-behavior case",
    "edge, boundary, or regression case",
    "only check marker strings",
)
RALPLAN_AGENT_CONTRACT_MARKERS = {
    "planner": (
        "Planner Draft Contract",
        "Planner Revision Contract",
        "Feedback disposition",
        "Accepted feedback must be reflected in the plan body",
        "smallest meaningful test set",
        "must-fail before implementation",
    ),
    "architect": (
        "Reviewed draft:",
        "must not produce a replacement plan",
        "Required changes",
        "Architect Review Contract",
    ),
    "critic": (
        "Architect review consumed",
        "APPROVE | ITERATE | REJECT",
        "reject when accepted feedback is only logged",
        "Critic Review Contract",
        "AI-slop",
        "would pass against the old broken behavior",
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


def markdown_section(text: str, heading: str) -> str:
    lines = text.splitlines()
    start = None
    for index, line in enumerate(lines):
        if line.strip() == heading:
            start = index + 1
            break
    if start is None:
        return ""

    end = len(lines)
    for index in range(start, len(lines)):
        stripped = lines[index].strip()
        if stripped.startswith("## ") and stripped != heading:
            end = index
            break
    return "\n".join(lines[start:end])


def assert_skill_frontmatter(path: Path, skill: str) -> dict[str, str]:
    fm = parse_frontmatter(path)
    missing = REQUIRED_SKILL_FIELDS - set(fm)
    if missing:
        die(f"{path} missing frontmatter fields: {sorted(missing)}")
    expected_name = skill.split("/")[-1]
    if fm["name"] != expected_name:
        die(f"{path} name={fm['name']!r}, expected {expected_name!r}")
    if skill in WORKFLOW_SKILLS_REQUIRING_ARGUMENT_HINT and "argument-hint" not in fm:
        die(f"{path} should define argument-hint")
    return fm


def assert_skill_wrapper(root: Path, skill: str, skill_root: str, platform: str) -> None:
    path = root / skill_root / skill / "SKILL.md"
    assert_skill_frontmatter(path, skill)
    body = read_text(path)
    core_marker = f"../../{SKILL_CORE_ROOT}/{skill}.md"
    if core_marker not in body:
        die(f"{path} should reference shared skill core: {core_marker!r}")

    if platform == "codex":
        required = "docs/platforms/codex.md"
        forbidden = (
            "docs/platforms/claude-code.md",
            "docs/platforms/claude-code-ralph.md",
            "docs/providers/",
            "CLAUDE_PLUGIN_ROOT",
        )
        if skill == "ralph" and "docs/platforms/codex-ralph.md" not in body:
            die(f"{path} should reference Codex Ralph adapter")
    elif platform == "claude":
        required = "docs/platforms/claude-code.md"
        forbidden = (
            "docs/platforms/codex.md",
            "docs/platforms/codex-ralph.md",
            "docs/providers/",
            "spawn_agent",
        )
        if skill == "ralph" and "docs/platforms/claude-code-ralph.md" not in body:
            die(f"{path} should reference Claude Code Ralph adapter")
    else:
        die(f"unknown platform for wrapper validation: {platform}")

    if required not in body:
        die(f"{path} should reference platform rules: {required!r}")
    for marker in forbidden:
        if marker in body:
            die(f"{path} contains forbidden cross-platform wrapper marker: {marker!r}")


def assert_skill(root: Path, skill: str) -> None:
    assert_skill_wrapper(root, skill, CODEX_SKILL_ROOT, "codex")
    assert_skill_wrapper(root, skill, CLAUDE_SKILL_ROOT, "claude")

    path = root / SKILL_CORE_ROOT / f"{skill}.md"
    assert_skill_frontmatter(path, skill)
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
    if skill in SKILL_REQUIRED_AGENT_ROLES:
        body = read_text(path)
        agent_roles_section = markdown_section(body, "## Agent Roles")
        if not agent_roles_section:
            die(f"{path} is missing required Agent Roles section")
        for role in SKILL_REQUIRED_AGENT_ROLES[skill]:
            if not has_token(agent_roles_section, role):
                die(f"{path} Agent Roles section is missing required role reference: {role!r}")
    if skill in SKILLS_WITHOUT_REQUIRED_AGENT_DEPENDENCY:
        body = read_text(path)
        agent_roles_section = markdown_section(body, "## Agent Roles")
        if "no required agent dependency" not in agent_roles_section:
            die(f"{path} Agent Roles section should explicitly declare no required agent dependency")
    if skill in SIMPLICITY_SCOPE_SKILL_MARKERS:
        body = read_text(path)
        for marker in SIMPLICITY_SCOPE_SKILL_MARKERS[skill]:
            if marker not in body:
                die(f"{path} is missing required Simplicity-Scope marker: {marker!r}")
    if skill == "simplify":
        body = read_text(path)
        for marker in SIMPLIFY_PARALLEL_MARKERS:
            if marker not in body:
                die(f"{path} is missing required Simplify-Parallel marker: {marker!r}")
        for wrapper_root in (CODEX_SKILL_ROOT, CLAUDE_SKILL_ROOT):
            wrapper_path = root / wrapper_root / skill / "SKILL.md"
            wrapper_body = read_text(wrapper_path)
            for marker in SIMPLIFY_WRAPPER_MARKERS:
                if marker not in wrapper_body:
                    die(f"{wrapper_path} is missing required Simplify-Wrapper marker: {marker!r}")
    if skill in PLATFORM_SUBAGENT_MARKERS:
        body = read_text(path)
        for marker in PLATFORM_SUBAGENT_MARKERS[skill]:
            if marker not in body:
                die(f"{path} is missing required Platform-Subagent marker: {marker!r}")
    if skill == "ralplan":
        body = read_text(path)
        for marker in RALPLAN_CONSENSUS_MARKERS:
            if marker not in body:
                die(f"{path} is missing required Ralplan-Consensus marker: {marker!r}")
    if skill in WORKTREE_SKILL_MARKERS:
        body = read_text(path)
        for marker in WORKTREE_SKILL_MARKERS[skill]:
            if marker not in body:
                die(f"{path} is missing required Worktree marker: {marker!r}")


def assert_command(root: Path, skill: str) -> None:
    path = root / "commands" / f"{skill}.md"
    fm = parse_frontmatter(path)
    missing = REQUIRED_COMMAND_FIELDS - set(fm)
    if missing:
        die(f"{path} missing frontmatter fields: {sorted(missing)}")
    if fm.get("disable-model-invocation") != "false":
        die(f"{path} should set disable-model-invocation: false")

    skill_fm = parse_frontmatter(root / CLAUDE_SKILL_ROOT / skill / "SKILL.md")
    if fm["argument-hint"] != skill_fm.get("argument-hint"):
        die(
            f"{path} argument-hint should mirror {CLAUDE_SKILL_ROOT}/{skill}/SKILL.md. "
            f"expected={skill_fm.get('argument-hint')!r} actual={fm['argument-hint']!r}"
        )

    body = read_text(path)
    expected_marker = COMMAND_DELEGATION_MARKER.format(skill=skill)
    for marker in (expected_marker, "## User Input", "$ARGUMENTS"):
        if marker not in body:
            die(f"{path} is missing required command delegation marker: {marker!r}")


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
    if not fm["description"].startswith("Use proactively"):
        die(f"{path} description should start with 'Use proactively' to encourage Claude Code delegation")
    for marker in AGENT_SKILL_RELATIONSHIP_MARKERS:
        if marker not in body:
            die(f"{path} is missing required agent-skill boundary marker: {marker!r}")
    if agent in EXECUTION_MODE_AGENT_MARKERS:
        for marker in EXECUTION_MODE_AGENT_MARKERS[agent]:
            if marker not in body:
                die(f"{path} is missing required Execution-Mode agent marker: {marker!r}")
    if agent in SIMPLICITY_SCOPE_AGENT_MARKERS:
        for marker in SIMPLICITY_SCOPE_AGENT_MARKERS[agent]:
            if marker not in body:
                die(f"{path} is missing required Simplicity-Scope agent marker: {marker!r}")
    if agent in APPROVED_DIRECTION_AGENT_MARKERS:
        for marker in APPROVED_DIRECTION_AGENT_MARKERS[agent]:
            if marker not in body:
                die(f"{path} is missing required Approved-Direction agent marker: {marker!r}")
    if agent in WORKTREE_AGENT_MARKERS:
        for marker in WORKTREE_AGENT_MARKERS[agent]:
            if marker not in body:
                die(f"{path} is missing required Worktree agent marker: {marker!r}")
    if agent in RALPLAN_AGENT_CONTRACT_MARKERS:
        for marker in RALPLAN_AGENT_CONTRACT_MARKERS[agent]:
            if marker not in body:
                die(f"{path} is missing required Ralplan-Agent-Contract marker: {marker!r}")


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
    shared_root = root / "docs" / "shared"
    for filename, markers in PLATFORM_SUBAGENT_DOC_MARKERS.items():
        doc = shared_root / filename
        doc_text = read_text(doc)
        for marker in markers:
            if marker not in doc_text:
                die(f"{doc} is missing required Platform-Subagent marker: {marker!r}")
    policy_path = shared_root / "ralph-subagent-policy.md"
    policy_text = read_text(policy_path)
    for marker in RALPH_SUBAGENT_POLICY_MARKERS:
        if marker not in policy_text:
            die(f"{policy_path} is missing required Ralph-Subagent-Policy marker: {marker!r}")
    platform_root = root / "docs" / "platforms"
    for filename, markers in PLATFORM_RULE_DOC_MARKERS.items():
        doc = platform_root / filename
        doc_text = read_text(doc)
        for marker in markers:
            if marker not in doc_text:
                die(f"{doc} is missing required Platform-Rules marker: {marker!r}")
    for filename, markers in PLATFORM_ADAPTER_DOC_MARKERS.items():
        doc = platform_root / filename
        doc_text = read_text(doc)
        for marker in markers:
            if marker not in doc_text:
                die(f"{doc} is missing required Platform-Adapter marker: {marker!r}")
        for marker in PLATFORM_ADAPTER_FORBIDDEN_MARKERS[filename]:
            if marker in doc_text:
                die(f"{doc} contains forbidden cross-platform adapter marker: {marker!r}")


def assert_provider_guidance(root: Path) -> None:
    provider_root = root / PROVIDER_DOC_ROOT
    if not provider_root.is_dir():
        die(f"{provider_root} should exist for company-scoped provider guidance")

    expected = set(PROVIDER_DOC_MARKERS)
    actual = {path.name for path in provider_root.glob("*.md")}
    if actual != expected:
        die(
            f"{provider_root} should contain only company-scoped provider docs. "
            f"expected={sorted(expected)!r} actual={sorted(actual)!r}"
        )

    for filename, markers in PROVIDER_DOC_MARKERS.items():
        doc = provider_root / filename
        doc_text = read_text(doc)
        for marker in markers:
            if marker not in doc_text:
                die(f"{doc} is missing required Provider-Guidance marker: {marker!r}")


def assert_worktree_contract(root: Path) -> None:
    path = root / "docs" / "shared" / "worktree-isolation.md"
    text = read_text(path)
    for marker in WORKTREE_SHARED_MARKERS:
        if marker not in text:
            die(f"{path} is missing required Worktree contract marker: {marker!r}")


def assert_hook_contract(root: Path) -> None:
    hooks_path = root / "hooks" / "hooks.json"
    try:
        hooks = json.loads(read_text(hooks_path))
    except json.JSONDecodeError as exc:
        die(f"{hooks_path} is not valid JSON: {exc}")

    events = hooks.get("hooks")
    if not isinstance(events, dict):
        die(f"{hooks_path} should define a hooks object")

    required_events = {"SessionStart", "UserPromptSubmit"}
    actual_events = set(events)
    missing = required_events - actual_events
    if missing:
        die(f"{hooks_path} is missing hook events: {sorted(missing)}")

    user_prompt_groups = events.get("UserPromptSubmit")
    if not isinstance(user_prompt_groups, list) or len(user_prompt_groups) != 1:
        die(f"{hooks_path} should define exactly one UserPromptSubmit group")
    group = user_prompt_groups[0]
    if "matcher" in group:
        die(f"{hooks_path} UserPromptSubmit should omit matcher because the event ignores it")
    handlers = group.get("hooks")
    if not isinstance(handlers, list) or len(handlers) != 1:
        die(f"{hooks_path} UserPromptSubmit should define exactly one hook handler")
    handler = handlers[0]
    if handler.get("type") != "command":
        die(f"{hooks_path} UserPromptSubmit handler should be type=command")
    if "ralph-platform-adapter" not in handler.get("command", ""):
        die(f"{hooks_path} UserPromptSubmit should invoke ralph-platform-adapter")
    if handler.get("async") is not False:
        die(f"{hooks_path} UserPromptSubmit handler should set async=false")

    script_path = root / "hooks" / "ralph-platform-adapter"
    script_text = read_text(script_path)
    for marker in (
        "OH_NO_RALPH_PLATFORM_ADAPTER",
        "CLAUDE_CODE_ONLY_RALPH_ADAPTER",
        "CODEX_ONLY_RALPH_ADAPTER",
        "docs/shared/ralph-subagent-policy.md",
        "docs/platforms/claude-code-ralph.md",
        "docs/platforms/codex-ralph.md",
        "hookEventName\": \"UserPromptSubmit",
    ):
        if marker not in script_text:
            die(f"{script_path} is missing required hook marker: {marker!r}")

    session_start_path = root / "hooks" / "session-start"
    session_start_text = read_text(session_start_path)
    for marker in (
        "OH_NO_RG_SEARCH_TOOLING",
        "command -v rg",
        "rg --files",
        "Use native skill loading",
        "using-oh-no-harness",
        "OH_NO_FORCED_ROUTING",
    ):
        if marker not in session_start_text:
            die(f"{session_start_path} is missing required session-start marker: {marker!r}")
    for forbidden in (
        "OH_NO_SKILL_CORE",
        "Below is the full content",
        "using_oh_no_core",
    ):
        if forbidden in session_start_text:
            die(f"{session_start_path} still embeds full using-oh-no-harness core content: {forbidden!r}")


def assert_claude_manifest_skills(root: Path) -> None:
    path = root / ".claude-plugin/plugin.json"
    try:
        manifest = json.loads(read_text(path))
    except json.JSONDecodeError as exc:
        die(f"{path} is not valid JSON: {exc}")

    expected = [f"./{CLAUDE_SKILL_ROOT}/{skill}/" for skill in PUBLIC_SKILLS]
    actual = manifest.get("skills")
    if actual != expected:
        die(
            f"{path} skills array should list public skill directories in order. "
            f"expected={expected!r} actual={actual!r}"
        )
    if manifest.get("commands") != "./commands/":
        die(f"{path} should declare commands='./commands/' for Claude slash-command wrappers")


def assert_claude_marketplace(root: Path) -> None:
    path = root / ".claude-plugin/marketplace.json"
    try:
        manifest = json.loads(read_text(path))
    except json.JSONDecodeError as exc:
        die(f"{path} is not valid JSON: {exc}")

    plugins = manifest.get("plugins")
    if not isinstance(plugins, list):
        die(f"{path} should define a plugins array")

    matches = [plugin for plugin in plugins if plugin.get("name") == PLUGIN_NAME]
    if len(matches) != 1:
        die(f"{path} should define exactly one {PLUGIN_NAME} plugin entry")

    source = matches[0].get("source")
    if source != MARKETPLACE_PLUGIN_PATH:
        die(
            f"{path} {PLUGIN_NAME} source should point to "
            f"{MARKETPLACE_PLUGIN_PATH!r}, actual={source!r}"
        )


def assert_codex_marketplace(root: Path) -> None:
    path = root / ".agents/plugins/marketplace.json"
    try:
        manifest = json.loads(read_text(path))
    except json.JSONDecodeError as exc:
        die(f"{path} is not valid JSON: {exc}")

    plugins = manifest.get("plugins")
    if not isinstance(plugins, list):
        die(f"{path} should define a plugins array")

    matches = [plugin for plugin in plugins if plugin.get("name") == PLUGIN_NAME]
    if len(matches) != 1:
        die(f"{path} should define exactly one {PLUGIN_NAME} plugin entry")

    entry = matches[0]
    source = entry.get("source")
    if source != {"source": "local", "path": MARKETPLACE_PLUGIN_PATH}:
        die(
            f"{path} {PLUGIN_NAME} source should point to "
            f"{MARKETPLACE_PLUGIN_PATH!r}, actual={source!r}"
        )
    if entry.get("policy", {}).get("installation") != "AVAILABLE":
        die(f"{path} {PLUGIN_NAME} should be installable with policy.installation=AVAILABLE")
    if entry.get("policy", {}).get("authentication") != "ON_INSTALL":
        die(f"{path} {PLUGIN_NAME} should use policy.authentication=ON_INSTALL")


def assert_codex_manifest(root: Path) -> None:
    path = root / ".codex-plugin/plugin.json"
    try:
        manifest = json.loads(read_text(path))
    except json.JSONDecodeError as exc:
        die(f"{path} is not valid JSON: {exc}")

    if manifest.get("skills") != f"./{CODEX_SKILL_ROOT}/":
        die(f"{path} should declare skills='./{CODEX_SKILL_ROOT}/'")
    if manifest.get("hooks") != "./hooks/hooks.json":
        die(f"{path} should declare hooks='./hooks/hooks.json' for Codex plugin hooks")


def has_token(text: str, token: str) -> bool:
    return re.search(rf"(^|[^A-Za-z0-9_-]){re.escape(token)}([^A-Za-z0-9_-]|$)", text) is not None


def assert_no_omc_runtime_coupling(root: Path) -> None:
    forbidden = [
        r"\bTask\(",
        r"\bSkill\(",
    ]
    checked_paths = (
        list((root / CODEX_SKILL_ROOT).glob("**/*.md"))
        + list((root / CLAUDE_SKILL_ROOT).glob("**/*.md"))
        + list((root / SKILL_CORE_ROOT).glob("*.md"))
        + list((root / "agents").glob("*.md"))
        + list((root / "commands").glob("*.md"))
    )
    for path in checked_paths:
        text = read_text(path)
        for pattern in forbidden:
            if re.search(pattern, text, flags=re.IGNORECASE):
                die(f"{path} contains forbidden OMC-style runtime coupling pattern: {pattern}")


def assert_no_deprecated_artifact_paths(root: Path) -> None:
    checked_paths = (
        list((root / CODEX_SKILL_ROOT).glob("**/*.md"))
        + list((root / CLAUDE_SKILL_ROOT).glob("**/*.md"))
        + list((root / SKILL_CORE_ROOT).glob("*.md"))
        + list((root / "agents").glob("*.md"))
        + list((root / "commands").glob("*.md"))
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
    if len(sys.argv) not in (2, 3):
        die("usage: validate-plugin-files.py <marketplace-root> [plugin-root]")

    marketplace_root = Path(sys.argv[1]).resolve()
    if len(sys.argv) == 3:
        root = Path(sys.argv[2]).resolve()
    else:
        nested = marketplace_root / "plugins" / PLUGIN_NAME
        root = nested if nested.exists() else marketplace_root

    for skill in ALL_SKILLS:
        assert_skill(root, skill)
    for skill in COMMAND_WRAPPERS:
        assert_command(root, skill)
    for agent in AGENTS:
        assert_agent(root, agent)
    assert_execution_mode_contract(root)
    assert_provider_guidance(root)
    assert_worktree_contract(root)
    assert_hook_contract(root)
    assert_claude_manifest_skills(root)
    assert_codex_manifest(root)
    assert_claude_marketplace(marketplace_root)
    assert_codex_marketplace(marketplace_root)
    assert_expected_references(root)
    assert_no_omc_runtime_coupling(root)
    assert_no_deprecated_artifact_paths(root)
    print("ok - skill and agent files passed static checks")


if __name__ == "__main__":
    main()
