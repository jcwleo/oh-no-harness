#!/usr/bin/env python3
"""Generate platform-specific agent wrappers from docs/agent-core."""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PLUGIN_ROOT = REPO_ROOT / "plugins" / "oh-no-harness"

DEFAULT_CODEX_MODEL = "gpt-5.6-sol"


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
    claude_only: bool = False


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
        role="executor-codex",
        claude_description=(
            "Use proactively inside active Oh No Harness workflows to run the "
            "write-capable Codex companion call for a scoped executor slice when "
            "executor delegation is on; the caller owns approval and handoff gates."
        ),
        claude_tools="Bash",
        claude_model="inherit",
        claude_color="red",
        codex_description=(
            "Oh No Harness executor-codex role: compile and forward one scoped executor "
            "slice through a foreground write-capable Codex companion call and return "
            "raw stdout without running verification, reviewing, or merging."
        ),
        # Claude-Code-only delegation agent: Claude delegates write work TO Codex.
        # On the Codex host there is nothing to delegate, so no Codex custom-agent
        # wrapper is emitted (a self-delegation degrade-to-native would be a no-op).
        claude_only=True,
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
    AgentMetadata(
        role="plan-reviewer-codex",
        claude_description=(
            "Use proactively inside active Oh No Harness workflows only when Ralplan's planning phase runs the "
            "read-only Codex companion call for the opposite-host leg of a "
            "cross-host plan-reviewer pair; the caller owns approval and handoff gates."
        ),
        claude_tools="Bash",
        claude_model="inherit",
        claude_color="orange",
        codex_description=(
            "Oh No Harness plan-reviewer-codex role: run the read-only Codex "
            "companion call that dispatches oh-no-plan-reviewer for the opposite-host "
            "leg of a cross-host plan review and return its role-owned result."
        ),
        # Claude-Code-only consult agent: Claude delegates the opposite-host review
        # leg TO Codex. On the Codex host there is nothing to delegate, so no Codex
        # custom-agent wrapper is emitted.
        claude_only=True,
    ),
    AgentMetadata(
        role="code-reviewer-codex",
        claude_description=(
            "Use proactively inside active Oh No Harness workflows to run the "
            "read-only Codex companion call for the opposite-host leg of a "
            "cross-host code-reviewer pair; the caller owns approval and handoff gates."
        ),
        claude_tools="Bash",
        claude_model="inherit",
        claude_color="pink",
        codex_description=(
            "Oh No Harness code-reviewer-codex role: run the read-only Codex "
            "companion call that dispatches oh-no-code-reviewer for the opposite-host "
            "leg of a cross-host code review and return its role-owned result."
        ),
        claude_only=True,
    ),
    AgentMetadata(
        role="debugger-codex",
        claude_description=(
            "Use proactively inside active Oh No Harness workflows to run the "
            "read-only Codex companion call for the opposite-host leg of a "
            "cross-host debugger pair; the caller owns approval and handoff gates."
        ),
        claude_tools="Bash",
        claude_model="inherit",
        claude_color="yellow",
        codex_description=(
            "Oh No Harness debugger-codex role: run the read-only Codex companion "
            "call that dispatches oh-no-debugger for the opposite-host leg of a "
            "cross-host root-cause pass and return its role-owned result."
        ),
        claude_only=True,
    ),
    AgentMetadata(
        role="fusion-codex",
        claude_description=(
            "Use proactively inside active Oh No Harness workflows to run the "
            "read-only Codex companion call for one assigned opposite-host Fusion "
            "Rescue panel lens; the caller owns approval and handoff gates."
        ),
        claude_tools="Bash",
        claude_model="inherit",
        claude_color="blue",
        codex_description=(
            "Oh No Harness fusion-codex role: run the read-only Codex companion "
            "call that dispatches oh-no-fusion-rescue-analyst for one assigned "
            "Fusion Rescue panel lens and return its exact panel fields."
        ),
        claude_only=True,
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


def expected_files(plugin_root: Path) -> dict[Path, str]:
    files: dict[Path, str] = {}
    for meta in AGENTS:
        files[plugin_root / "agents" / f"{meta.role}.md"] = render_claude_agent(
            plugin_root, meta
        )
        # Claude-only agents (Claude-Code delegation roles) get no Codex wrapper:
        # they are never registered as a Codex custom agent.
        if meta.claude_only:
            continue
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
