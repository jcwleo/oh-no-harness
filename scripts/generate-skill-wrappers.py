#!/usr/bin/env python3
"""Generate platform-specific runtime skill docs from shared skill sources."""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PLUGIN_ROOT = REPO_ROOT / "plugins" / "oh-no-harness"

PUBLIC_SKILLS = [
    "using-oh-no-harness",
    "interview",
    "ralplan",
    "ralplan-v2",
    "ralph",
    "ultrawork",
    "auto-routing",
    "test-driven-development",
    "simplify",
    "verification-before-completion",
    "systematic-debugging",
    "fusion-rescue",
    "install-statusline",
]

# Skills that ship a Claude Code wrapper only (no Codex wrapper). The Codex
# platform is skipped for these in expected_files(); the validator mirrors this
# set and asserts the Codex wrapper is absent. Keep this set identical to the
# one in scripts/validate-plugin-files.py (the validator runs `--check` here as
# a subprocess, so any divergence fails loudly).
CLAUDE_ONLY_SKILLS = {"install-statusline"}

# These skills carry every required host binding in a required skill-specific
# adapter. Embedding the common platform runtime would duplicate those bindings
# and reintroduce external-document reads that the self-contained core removed.
SELF_CONTAINED_ADAPTER_SKILLS = {"ralplan-v2"}
MODEL_UNINVOCABLE_SKILLS = {"ralplan-v2", "install-statusline"}


@dataclass(frozen=True)
class PlatformSpec:
    key: str
    display_name: str
    skill_root: str
    platform_doc: str
    source_prefix: str
    runtime_note: str


PLATFORMS = (
    PlatformSpec(
        key="codex",
        display_name="Codex",
        skill_root="skills",
        platform_doc="docs/platforms/codex-runtime.md",
        source_prefix="codex",
        runtime_note=(
            "This generated file is the Codex-facing runtime skill document. "
            "Codex should read this file directly; maintainers edit the source "
            "documents listed below instead."
        ),
    ),
    PlatformSpec(
        key="claude",
        display_name="Claude Code",
        skill_root="skills-claude",
        platform_doc="docs/platforms/claude-code-runtime.md",
        source_prefix="claude-code",
        runtime_note=(
            "This generated file is the Claude Code-facing runtime skill "
            "document. Claude Code slash commands should read this file directly; "
            "maintainers edit the source documents listed below instead."
        ),
    ),
)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        raise SystemExit(f"missing source file: {path}") from None


def parse_frontmatter(path: Path) -> tuple[dict[str, str], str]:
    text = read_text(path)
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        raise SystemExit(f"{path} is missing YAML frontmatter")

    frontmatter: dict[str, str] = {}
    for index, line in enumerate(lines[1:], start=1):
        if line.strip() == "---":
            body = "\n".join(lines[index + 1 :]).strip() + "\n"
            return frontmatter, body
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            raise SystemExit(f"{path} has unsupported frontmatter line: {line}")
        key, value = line.split(":", 1)
        frontmatter[key.strip()] = value.strip().strip('"')

    raise SystemExit(f"{path} has unterminated YAML frontmatter")


def require_frontmatter(path: Path, frontmatter: dict[str, str], skill: str) -> None:
    required = {"name", "description", "argument-hint"}
    missing = required - set(frontmatter)
    if missing:
        raise SystemExit(f"{path} missing frontmatter fields: {sorted(missing)}")
    if frontmatter["name"] != skill:
        raise SystemExit(f"{path} name={frontmatter['name']!r}, expected {skill!r}")
    if (
        skill in MODEL_UNINVOCABLE_SKILLS
        and frontmatter.get("disable-model-invocation") != "true"
    ):
        raise SystemExit(
            f"{path} must set disable-model-invocation: true before wrapper generation"
        )


def skill_title(skill: str) -> str:
    return " ".join(part.capitalize() for part in skill.split("-"))


def optional_overlay_paths(plugin_root: Path, platform: PlatformSpec, skill: str) -> list[Path]:
    overlay = plugin_root / "docs" / "platforms" / f"{platform.source_prefix}-{skill}.md"
    return [overlay] if overlay.exists() else []


def render_skill(plugin_root: Path, platform: PlatformSpec, skill: str) -> str:
    core_path = plugin_root / "docs" / "skill-core" / f"{skill}.md"
    frontmatter, core_body = parse_frontmatter(core_path)
    require_frontmatter(core_path, frontmatter, skill)

    overlay_paths = optional_overlay_paths(plugin_root, platform, skill)
    if skill in SELF_CONTAINED_ADAPTER_SKILLS:
        if not overlay_paths:
            expected = (
                plugin_root
                / "docs"
                / "platforms"
                / f"{platform.source_prefix}-{skill}.md"
            )
            raise SystemExit(f"missing required self-contained adapter: {expected}")
        source_paths = [core_path, *overlay_paths]
    else:
        source_paths = [core_path, plugin_root / platform.platform_doc, *overlay_paths]

    source_labels = [
        f"../../{path.relative_to(plugin_root).as_posix()}" for path in source_paths
    ]
    sections = []
    for path in source_paths:
        relative = path.relative_to(plugin_root).as_posix()
        body = core_body.rstrip() if path == core_path else read_text(path).strip()
        sections.append(f"## Source: {relative}\n\n{body}\n")

    source_list = "\n".join(f"- `{label}`" for label in source_labels)
    generated_header = (
        "<!-- oh-no-harness-generated-skill-wrapper -->\n"
        "<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->\n"
        "\n"
        f"# {skill_title(skill)} for {platform.display_name}\n\n"
        f"{platform.runtime_note}\n\n"
        "## Generated Runtime Composition\n\n"
        "Source order:\n\n"
        f"{source_list}\n\n"
        "The sections below are already composed for this platform. Do not ask the "
        "runtime model to load another platform's runtime document or invocation syntax.\n"
    )

    frontmatter_text = (
        "---\n"
        f"name: {frontmatter['name']}\n"
        f"description: {frontmatter['description']}\n"
        f"argument-hint: \"{frontmatter['argument-hint']}\"\n"
    )
    # Propagate disable-model-invocation only when the skill core sets it, so
    # wrappers for skills that omit it stay byte-identical after regeneration.
    if "disable-model-invocation" in frontmatter:
        frontmatter_text += (
            f"disable-model-invocation: {frontmatter['disable-model-invocation']}\n"
        )
    frontmatter_text += "---\n"
    return f"{frontmatter_text}\n{generated_header}\n" + "\n".join(sections)


def expected_files(plugin_root: Path) -> dict[Path, str]:
    files: dict[Path, str] = {}
    for platform in PLATFORMS:
        for skill in PUBLIC_SKILLS:
            if platform.key == "codex" and skill in CLAUDE_ONLY_SKILLS:
                continue  # Claude-Code-only skill ships no Codex wrapper.
            files[plugin_root / platform.skill_root / skill / "SKILL.md"] = render_skill(
                plugin_root, platform, skill
            )
    return files


def check(plugin_root: Path) -> int:
    stale: list[Path] = []
    for path, expected in expected_files(plugin_root).items():
        actual = path.read_text(encoding="utf-8") if path.exists() else None
        if actual != expected:
            stale.append(path)
    if stale:
        print("skill wrappers are stale; run:", file=sys.stderr)
        print("  python3 scripts/generate-skill-wrappers.py --write", file=sys.stderr)
        for path in stale:
            print(f"stale: {path}", file=sys.stderr)
        return 1
    print("ok - generated skill wrappers are fresh")
    return 0


def write(plugin_root: Path) -> int:
    for path, expected in expected_files(plugin_root).items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(expected, encoding="utf-8")
        print(f"wrote: {path}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate Codex and Claude Code runtime skill docs."
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="verify generated wrappers")
    mode.add_argument("--write", action="store_true", help="rewrite generated wrappers")
    parser.add_argument(
        "--plugin-root",
        type=Path,
        default=DEFAULT_PLUGIN_ROOT,
        help="plugin root containing docs/skill-core and docs/platforms",
    )
    args = parser.parse_args()

    plugin_root = args.plugin_root.resolve()
    return check(plugin_root) if args.check else write(plugin_root)


if __name__ == "__main__":
    raise SystemExit(main())
