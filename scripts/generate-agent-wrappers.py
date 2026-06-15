#!/usr/bin/env python3
"""Generate platform-specific agent wrappers from docs/agent-core."""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PLUGIN_ROOT = REPO_ROOT / "plugins" / "oh-no-harness"

CODEX_MODEL = "gpt-5.5"


@dataclass(frozen=True)
class AgentMetadata:
    role: str
    claude_description: str
    claude_tools: str
    claude_model: str
    claude_color: str
    codex_description: str
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
        claude_model="inherit",
        claude_color="blue",
        codex_description=(
            "Oh No Harness analyst role: analyze requirements, hidden constraints, "
            "risk, and product implications before planning."
        ),
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
            "Use proactively inside active Oh No Harness workflows to review plans "
            "and evidence; the caller owns approval and handoff gates."
        ),
        claude_tools="Read, Glob, Grep, Bash",
        claude_model="inherit",
        claude_color="orange",
        codex_description=(
            "Oh No Harness plan-reviewer role: review plans, technical direction, "
            "and completion evidence with ordered architecture and quality-gate passes."
        ),
    ),
    AgentMetadata(
        role="executor",
        claude_description=(
            "Use proactively inside active Oh No Harness workflows for scoped "
            "implementation; the caller owns approval and handoff gates."
        ),
        claude_tools="Read, Edit, Write, Bash, Grep, Glob",
        claude_model="inherit",
        claude_color="green",
        codex_description=(
            "Oh No Harness executor role: implement scoped tasks with clear ownership, "
            "acceptance criteria, and verification responsibility."
        ),
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
        f'model = "{CODEX_MODEL}"\n'
        f'model_reasoning_effort = "{meta.codex_reasoning_effort}"\n'
        f"{sandbox_mode}"
        'developer_instructions = """\n'
        f"Agent prompt source: docs/agent-core/{meta.role}.md\n"
        "Agent prompt content:\n"
        "\n"
        f"{body}"
        '"""\n'
    )


def expected_files(plugin_root: Path) -> dict[Path, str]:
    files: dict[Path, str] = {}
    for meta in AGENTS:
        files[plugin_root / "agents" / f"{meta.role}.md"] = render_claude_agent(
            plugin_root, meta
        )
        files[
            plugin_root / "docs" / "platforms" / "codex-agents" / f"oh-no-{meta.role}.toml"
        ] = render_codex_agent(plugin_root, meta)
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
        description="Generate Claude and Codex agent wrappers from docs/agent-core."
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
