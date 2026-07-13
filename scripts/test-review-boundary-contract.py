#!/usr/bin/env python3
"""Bounded mutation tests for the Ralplan review and Ralph budget boundaries."""
from __future__ import annotations

import argparse
import contextlib
import importlib.util
import io
import shutil
import sys
import tempfile
from pathlib import Path


def load_validator(repo_root: Path):
    path = repo_root / "scripts" / "validate-plugin-files.py"
    spec = importlib.util.spec_from_file_location("oh_no_validate_plugin_files", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load validator: {path}")
    module = importlib.util.module_from_spec(spec)
    previous = sys.dont_write_bytecode
    sys.dont_write_bytecode = True
    try:
        spec.loader.exec_module(module)
    finally:
        sys.dont_write_bytecode = previous
    return module


def append_before_heading(path: Path, heading: str, text: str) -> None:
    body = path.read_text(encoding="utf-8")
    anchor = f"\n{heading}\n"
    if anchor not in body:
        raise RuntimeError(f"missing mutation anchor {heading!r} in {path}")
    path.write_text(
        body.replace(anchor, f"\n{text}\n\n{heading}\n", 1),
        encoding="utf-8",
    )


def expect_rejected(
    validator, plugin_root: Path, label: str, expected_error: str, mutate
) -> None:
    with tempfile.TemporaryDirectory(prefix="oh-no-review-boundary-") as temp_dir:
        copy = Path(temp_dir) / "plugin"
        shutil.copytree(plugin_root, copy)
        mutate(copy)
        stderr = io.StringIO()
        try:
            with contextlib.redirect_stderr(stderr):
                validator.assert_ralplan_review_boundary_contract(copy)
        except SystemExit as exc:
            failure = f"{exc}\n{stderr.getvalue()}"
            if expected_error not in failure:
                raise AssertionError(
                    f"mutation failed for the wrong reason: {label}: {failure!r}"
                )
            print(f"ok - rejected mutation: {label}")
            return
        raise AssertionError(f"mutation unexpectedly passed: {label}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plugin-root", required=True, type=Path)
    args = parser.parse_args()
    plugin_root = args.plugin_root.resolve()
    repo_root = plugin_root.parent.parent
    validator = load_validator(repo_root)
    validator.assert_ralplan_review_boundary_contract(plugin_root)

    expect_rejected(
        validator,
        plugin_root,
        "non-Ralplan direct plan-reviewer dispatch",
        "must not directly dispatch plan-reviewer outside Ralplan",
        lambda root: append_before_heading(
            root / "docs" / "skill-core" / "ralph.md",
            "## Input Hardening",
            "Dispatch `plan-reviewer` for Ralph completion review.",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "post-APPROVE non-blocking draft mutation",
        "contradicts APPROVE/non-blocking draft freeze",
        lambda root: append_before_heading(
            root / "docs" / "skill-core" / "ralplan.md",
            "## Planner Revision Contract",
            "After APPROVE, incorporate non-blocking findings into the Planner draft.",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "duplicate Ralph Execution Loop Diff-Budget execution",
        "Execution Loop must schedule Diff-Budget Gate exactly once",
        lambda root: (
            append_before_heading(
                root / "docs" / "skill-core" / "ralph.md",
                "## Mode-Gated Agent Dispatch",
                "Run the Diff-Budget Gate again when a threshold is crossed.",
            )
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "execution-modes conditional Diff-Budget execution",
        "execution-modes.md makes final Diff-Budget execution conditional or repeated",
        lambda root: (
            append_before_heading(
                root / "docs" / "shared" / "execution-modes.md",
                "## Execution Mode Decision Prompt",
                "Run the Diff-Budget Gate only if thresholds are crossed.",
            )
        ),
    )

    print("ok - review-boundary mutations are rejected")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
