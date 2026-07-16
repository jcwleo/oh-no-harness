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


def replace_once(path: Path, old: str, new: str) -> None:
    body = path.read_text(encoding="utf-8")
    if body.count(old) != 1:
        raise RuntimeError(
            f"expected one mutation anchor in {path}: {old!r}; found {body.count(old)}"
        )
    path.write_text(body.replace(old, new, 1), encoding="utf-8")


def expect_rejected(
    validator,
    plugin_root: Path,
    label: str,
    expected_error: str,
    mutate,
    assertion="assert_ralplan_review_boundary_contract",
) -> None:
    with tempfile.TemporaryDirectory(prefix="oh-no-review-boundary-") as temp_dir:
        repo_copy = Path(temp_dir) / "repo"
        copy = repo_copy / "plugins" / plugin_root.name
        copy.parent.mkdir(parents=True)
        shutil.copytree(plugin_root, copy)
        scripts_copy = repo_copy / "scripts"
        scripts_copy.mkdir()
        source_scripts = plugin_root.parent.parent / "scripts"
        for name in ("test-codex-plugin.sh", "test-claude-plugin.sh"):
            shutil.copy2(source_scripts / name, scripts_copy / name)
        mutate(copy)
        stderr = io.StringIO()
        try:
            with contextlib.redirect_stderr(stderr):
                getattr(validator, assertion)(copy)
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
    validator.assert_workflow_object_routing_contract(plugin_root)
    validator.assert_ralplan_review_boundary_contract(plugin_root)

    expect_rejected(
        validator,
        plugin_root,
        "forced routing overrides workflow object-of-analysis boundary",
        "object-of-analysis routing boundary",
        lambda root: replace_once(
            root / "hooks" / "session-start",
            "A workflow name used only as the subject of analysis, explanation, comparison, or critique is not an invocation trigger.",
            "A workflow name used as the subject of analysis still forces that workflow.",
        ),
        assertion="assert_workflow_object_routing_contract",
    )

    expect_rejected(
        validator,
        plugin_root,
        "non-Ralplan direct plan-reviewer dispatch",
        "must not directly dispatch plan-reviewer outside Ralplan",
        lambda root: append_before_heading(
            root / "docs" / "skill-core" / "ralph.md",
            "## Scope Trace Gate",
            "Dispatch `plan-reviewer` for Ralph completion review.",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "canonical active projection obligation growth",
        "derived active obligation count exceeds audited baseline",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "Direction Contract; success ownership/signals; confidence",
            "Direction Contract; success ownership/signals; confidence; rollout telemetry",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "Reviewer requires an inactive role-only field",
        "reviewer entitlement to active fields",
        lambda root: append_before_heading(
            root / "docs" / "agent-core" / "plan-reviewer.md",
            "## Operating Rules",
            "Require every draft to include rollout telemetry even when the Active plan contract omits it.",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "unsupported false-rejection bias",
        "unsupported false rejection",
        lambda root: replace_once(
            root / "docs" / "agent-core" / "plan-reviewer.md",
            "an\nunsupported false rejection is also a contract failure",
            "a false approval is worse than a false rejection",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "blocker missing exact draft pointer",
        "exact draft pointer",
        lambda root: replace_once(
            root / "docs" / "agent-core" / "plan-reviewer.md",
            "exact draft pointer",
            "draft context",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "all-accepted branch omits its single closure review",
        "all-accepted must create exactly one v2 and one closure review",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "All accepted: create exactly one Planner revision v2, then exactly one delta closure review.",
            "All accepted: create one revision v2 without a closure review.",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "rejected branch creates v2 before user resolution",
        "rejected must create no v2 or review before user resolution",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "Any rejected: return the disposition-only user-decision packet; create no v2 and run no review v2 until the user resolves it.",
            "Any rejected: create revision v2 before the user resolves it.",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "deferred branch continues into review",
        "deferred must leave the plan pending with no v2 or review",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "Any deferred: leave the plan pending in the disposition-only user-decision packet; create no v2 and run no review v2.",
            "Any deferred: create revision v2 and run review v2 while the plan is pending.",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "mixed branch revises before resolving non-accepted blockers",
        "mixed blockers must resolve before one v2 and closure review",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "Mixed: resolve every non-accepted blocker before exactly one v2; no closure review starts earlier.",
            "Mixed: revise accepted blockers before resolving the other dispositions.",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "waiver-only branch creates revision and re-review",
        "permitted waiver with no body change must create no v2 or review",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "Permitted waivers with no body change: keep the waivers visible; create no v2 and run no review v2.",
            "Permitted waivers with no body change: create v2 and run review v2.",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "non-waivable gate permits execution while pending",
        "non-waivable gate must remain pending with no execution",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "Non-waivable gate: keep the plan pending and prohibit execution until its owner-defined obligation passes or direction changes.",
            "Non-waivable gate: permit execution while its obligation is pending.",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "direction-change branch consumes the old closure review",
        "direction change must start a new run without old closure review",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "Direction change: update the requirements source, start a new planning run, and do not run or consume the old run's closure review.",
            "Direction change: reuse the old run and consume its closure review.",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "reason-free full-depth re-review",
        "named material change",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "Full-depth review\nis allowed only for a named material change",
            "Full-depth review is allowed with a stated reason for a change",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "new v2 blocker omits first-visible explanation",
        "Why first raised now",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "Why first raised now",
            "Late blocker note",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "late-blocker rule suppresses revision-created defect",
        "revision-created material defect",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "A revision-created material defect",
            "A revision-created preference",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "out-of-scope preference promoted to blocking",
        "smallest AC-sufficient correction",
        lambda root: append_before_heading(
            root / "docs" / "agent-core" / "plan-reviewer.md",
            "## Operating Rules",
            "Block on preferred future-proofing even without an active AC or safety basis.",
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
        "Ralph compact phase attribution uses an inexact label",
        "missing exact compact phase-attribution format",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "implementation-code=<n>",
            "implementation=<n>",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "Reviewed draft id suffix passes a prefix comparison",
        "must compare exact normalized Reviewed draft id",
        lambda root: replace_once(
            root.parent.parent / "scripts" / "test-codex-plugin.sh",
            "if reviewed_draft_id != captured_draft_id:",
            "if not reviewed_draft_id.startswith(captured_draft_id):",
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
