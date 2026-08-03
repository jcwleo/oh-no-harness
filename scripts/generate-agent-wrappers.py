#!/usr/bin/env python3
"""Generate platform-specific agent wrappers from docs/agent-core."""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PLUGIN_ROOT = REPO_ROOT / "plugins" / "oh-no-harness"

DEFAULT_CODEX_MODEL = "gpt-5.6-sol"
OPEN_CODE_MAIN_AGENT_SOURCE = "docs/platforms/opencode-main-agent.md"
OPEN_CODE_SKILLS = [
    "interview",
    "ralplan",
    "ralph",
    "ultrawork",
    "auto-routing",
    "test-driven-development",
    "simplify",
    "verification-before-completion",
    "systematic-debugging",
    "fusion-rescue",
    "configure-subagents",
]
OPEN_CODE_CONFIGURE_TOOL = "oh_no_configure_subagents"


@dataclass(frozen=True)
class AgentMetadata:
    role: str
    claude_description: str
    claude_tools: str
    claude_model: str
    claude_color: str
    codex_description: str
    codex_model: str = DEFAULT_CODEX_MODEL
    codex_sandbox_mode: str | None = None
    codex_reasoning_effort: str = "xhigh"


AGENTS = [
    AgentMetadata(
        role="explore",
        claude_description=(
            "Use proactively inside active Oh No Harness workflows for read-only "
            "codebase exploration; the caller owns approval and handoff gates."
        ),
        claude_tools="Read, Glob, Grep, Bash",
        claude_model="sonnet",
        claude_color="cyan",
        codex_description=(
            "Oh No Harness explore role: perform read-only repository exploration, "
            "symbol discovery, dependency tracing, and factual implementation research."
        ),
        codex_model="gpt-5.6-terra",
        codex_sandbox_mode="read-only",
        codex_reasoning_effort="medium",
    ),
    AgentMetadata(
        role="analyst",
        claude_description=(
            "Use proactively inside active Oh No Harness workflows to analyze "
            "requirements and risks; the caller owns approval and handoff gates."
        ),
        claude_tools="Read, Glob, Grep",
        claude_model="opus",
        claude_color="blue",
        codex_description=(
            "Oh No Harness analyst role: analyze requirements, hidden constraints, "
            "risk, and product implications before planning."
        ),
        codex_reasoning_effort="high",
    ),
    AgentMetadata(
        role="planner",
        claude_description=(
            "Use proactively inside active Oh No Harness workflows to turn approved "
            "scope into a plan; the caller owns approval and handoff gates."
        ),
        claude_tools="Read, Glob, Grep, Bash, Write",
        claude_model="inherit",
        claude_color="purple",
        codex_description=(
            "Oh No Harness planner role: turn approved scope into sequenced, "
            "verifiable implementation work."
        ),
    ),
    AgentMetadata(
        role="plan-reviewer",
        claude_description=(
            "Use proactively inside active Oh No Harness workflows only when Ralplan's "
            "planning phase reviews the exact Planner draft; the caller owns approval and handoff gates."
        ),
        claude_tools="Read, Glob, Grep, Bash",
        claude_model="inherit",
        claude_color="orange",
        codex_description=(
            "Oh No Harness plan-reviewer role: review exact Ralplan Planner drafts "
            "with ordered architecture and quality-gate passes."
        ),
    ),
    AgentMetadata(
        role="executor",
        claude_description=(
            "Use proactively inside active Oh No Harness workflows for scoped "
            "implementation; the caller owns approval and handoff gates."
        ),
        claude_tools="Read, Edit, Write, Bash, Grep, Glob",
        claude_model="opus",
        claude_color="green",
        codex_description=(
            "Oh No Harness executor role: implement scoped tasks with clear ownership, "
            "acceptance criteria, and verification responsibility."
        ),
        codex_reasoning_effort="high",
    ),
    AgentMetadata(
        role="debugger",
        claude_description=(
            "Use proactively inside active Oh No Harness workflows for root-cause "
            "analysis; the caller owns approval and handoff gates."
        ),
        claude_tools="Read, Bash, Grep, Glob",
        claude_model="inherit",
        claude_color="yellow",
        codex_description=(
            "Oh No Harness debugger role: reproduce failures, compare expected and "
            "actual behavior, trace root cause, and recommend minimal fixes."
        ),
    ),
    AgentMetadata(
        role="verifier",
        claude_description=(
            "Use proactively inside active Oh No Harness workflows to verify claims "
            "with evidence; the caller owns approval and handoff gates."
        ),
        claude_tools="Read, Bash, Grep, Glob",
        claude_model="inherit",
        claude_color="cyan",
        codex_description=(
            "Oh No Harness verifier role: check acceptance criteria, commands, "
            "artifacts, verification evidence, and user-facing scenario coverage "
            "before completion claims."
        ),
        codex_sandbox_mode="read-only",
    ),
    AgentMetadata(
        role="code-reviewer",
        claude_description=(
            "Use proactively inside active Oh No Harness workflows to review changed "
            "code or prompts; the caller owns approval and handoff gates."
        ),
        claude_tools="Read, Bash, Grep, Glob",
        claude_model="inherit",
        claude_color="pink",
        codex_description=(
            "Oh No Harness code-reviewer role: review changed code for correctness, "
            "maintainability, regressions, missing tests, and security risks through "
            "ordered lenses."
        ),
        codex_sandbox_mode="read-only",
    ),
    AgentMetadata(
        role="fusion-rescue-analyst",
        claude_description=(
            "Use proactively inside active Oh No Harness workflows for an assigned "
            "Fusion Rescue panel lens; the caller owns approval and handoff gates."
        ),
        claude_tools="Read, Glob, Grep",
        claude_model="inherit",
        claude_color="blue",
        codex_description=(
            "Oh No Harness fusion-rescue-analyst role: analyze one assigned rescue "
            "panel lens and return bounded evidence for host synthesis."
        ),
        codex_sandbox_mode="read-only",
    ),
]


def read_agent_core(plugin_root: Path, role: str) -> str:
    path = plugin_root / "docs" / "agent-core" / f"{role}.md"
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        raise SystemExit(f"missing agent core file: {path}") from None


def render_claude_agent(plugin_root: Path, meta: AgentMetadata) -> str:
    body = read_agent_core(plugin_root, meta.role)
    return (
        "---\n"
        f"name: {meta.role}\n"
        f"description: {meta.claude_description}\n"
        f"tools: {meta.claude_tools}\n"
        f"model: {meta.claude_model}\n"
        f"color: {meta.claude_color}\n"
        "---\n"
        "\n"
        "<!-- Generated from docs/agent-core; do not edit by hand. -->\n"
        f"<!-- Source: plugins/oh-no-harness/docs/agent-core/{meta.role}.md -->\n"
        "<!-- Run: python3 scripts/generate-agent-wrappers.py --write -->\n"
        "\n"
        f"{body}"
    )


def render_codex_agent(plugin_root: Path, meta: AgentMetadata) -> str:
    body = read_agent_core(plugin_root, meta.role)
    if '"""' in body:
        raise SystemExit(
            f"docs/agent-core/{meta.role}.md contains triple quotes, which cannot "
            "be embedded in the current TOML template"
        )
    sandbox_mode = (
        f'sandbox_mode = "{meta.codex_sandbox_mode}"\n'
        if meta.codex_sandbox_mode is not None
        else ""
    )
    return (
        "# oh-no-harness-generated-codex-agent\n"
        "# Generated from docs/agent-core; do not edit by hand.\n"
        "# Run: python3 scripts/generate-agent-wrappers.py --write\n"
        f"# Source: plugins/oh-no-harness/docs/agent-core/{meta.role}.md\n"
        "\n"
        f'name = "oh-no-{meta.role}"\n'
        f'description = "{meta.codex_description}"\n'
        f'model = "{meta.codex_model}"\n'
        f'model_reasoning_effort = "{meta.codex_reasoning_effort}"\n'
        f"{sandbox_mode}"
        'developer_instructions = """\n'
        f"Agent prompt source: docs/agent-core/{meta.role}.md\n"
        "Agent prompt content:\n"
        "\n"
        f"{body}"
        '"""\n'
    )


def read_text(plugin_root: Path, relative_path: str) -> str:
    path = plugin_root / relative_path
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        raise SystemExit(f"missing OpenCode source file: {path}") from None


def opencode_subagent_permission(role: str) -> dict[str, object]:
    permission: dict[str, object] = {}
    if role not in {"executor", "planner"}:
        permission["edit"] = "deny"
    if role in {"debugger", "verifier"}:
        permission["task"] = {
            "*": "deny",
            "oh-no-explore": "allow",
            "oh-no-analyst": "allow",
        }
    else:
        permission["task"] = "deny"
    if role in {
        "analyst",
        "planner",
        "plan-reviewer",
        "code-reviewer",
        "fusion-rescue-analyst",
    }:
        permission["bash"] = "deny"
    permission[OPEN_CODE_CONFIGURE_TOOL] = "deny"
    return permission


def render_opencode_agents(plugin_root: Path) -> str:
    agents: dict[str, object] = {
        "oh-no": {
            "description": (
                "Primary Oh No Harness workflow orchestrator for planning, "
                "implementation, debugging, review, and verification."
            ),
            "mode": "primary",
            "prompt": read_text(plugin_root, OPEN_CODE_MAIN_AGENT_SOURCE),
            "permission": {
                "question": "allow",
                "task": {
                    "*": "deny",
                    **{
                        f"oh-no-{meta.role}": "allow"
                        for meta in AGENTS
                    },
                },
                OPEN_CODE_CONFIGURE_TOOL: "ask",
            },
        }
    }
    for meta in AGENTS:
        agents[f"oh-no-{meta.role}"] = {
            "description": meta.codex_description,
            "mode": "subagent",
            "prompt": read_agent_core(plugin_root, meta.role),
            "permission": opencode_subagent_permission(meta.role),
        }
    return json.dumps(agents, indent=2, ensure_ascii=False) + "\n"


def render_opencode_commands() -> str:
    commands: dict[str, object] = {}
    for skill in OPEN_CODE_SKILLS:
        template = (
            f"Load the `{skill}` skill and follow it exactly. Preserve and pass "
            "through the user's raw arguments unchanged:\n\n$ARGUMENTS"
        )
        if skill == "configure-subagents":
            template = (
                "Load the `configure-subagents` skill and follow it exactly. This "
                "command is interactive only; never treat arguments as confirmation "
                "or as a bypass of its apply gate. Preserve and pass through the "
                "user's raw arguments unchanged:\n\n$ARGUMENTS"
            )
        commands[skill] = {
            "description": f"Run the Oh No Harness {skill} skill.",
            "agent": "oh-no",
            "template": template,
        }
    return json.dumps(commands, indent=2, ensure_ascii=False) + "\n"


def expected_files(plugin_root: Path) -> dict[Path, str]:
    files: dict[Path, str] = {}
    for meta in AGENTS:
        files[plugin_root / "agents" / f"{meta.role}.md"] = render_claude_agent(
            plugin_root, meta
        )
        files[
            plugin_root / "docs" / "platforms" / "codex-agents" / f"oh-no-{meta.role}.toml"
        ] = render_codex_agent(plugin_root, meta)
    files[plugin_root / "opencode" / "generated" / "agents.json"] = (
        render_opencode_agents(plugin_root)
    )
    files[plugin_root / "opencode" / "generated" / "commands.json"] = (
        render_opencode_commands()
    )
    return files


def check(plugin_root: Path) -> int:
    stale: list[Path] = []
    for path, expected in expected_files(plugin_root).items():
        actual = path.read_text(encoding="utf-8") if path.exists() else None
        if actual != expected:
            stale.append(path)
    if stale:
        print("agent wrappers are stale; run:", file=sys.stderr)
        print("  python3 scripts/generate-agent-wrappers.py --write", file=sys.stderr)
        for path in stale:
            print(f"stale: {path}", file=sys.stderr)
        return 1
    print("ok - generated agent wrappers are fresh")
    return 0


def write(plugin_root: Path) -> int:
    for path, expected in expected_files(plugin_root).items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(expected, encoding="utf-8")
        print(f"wrote: {path}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Generate Claude, Codex, and OpenCode agent and command wrappers."
        )
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="fail when wrappers are stale")
    mode.add_argument("--write", action="store_true", help="regenerate wrappers")
    parser.add_argument(
        "--plugin-root",
        type=Path,
        default=DEFAULT_PLUGIN_ROOT,
        help="path to plugins/oh-no-harness",
    )
    args = parser.parse_args()

    plugin_root = args.plugin_root.resolve()
    if args.write:
        return write(plugin_root)
    return check(plugin_root)


if __name__ == "__main__":
    raise SystemExit(main())
