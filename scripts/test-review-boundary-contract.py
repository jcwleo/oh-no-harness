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


def move_bootstrap_orchestration_sentence(path: Path) -> None:
    sentence = (
        "Orchestration default: workflow main agents own .oh-no state and gate "
        "decisions; STANDARD/THOROUGH repository work-product mutations use "
        "executor roles, with inline mutation only for a recorded LIGHT-tiny "
        "or dispatch-unavailable fallback."
    )
    body = path.read_text(encoding="utf-8")
    if body.count(sentence) != 1:
        raise RuntimeError(f"expected one bootstrap orchestration sentence in {path}")
    body = body.replace(f"{sentence}\n\n", "", 1)
    anchor = "</OH_NO_FORCED_ROUTING>'"
    if body.count(anchor) != 1:
        raise RuntimeError(f"expected one forced-routing close anchor in {path}")
    path.write_text(
        body.replace(anchor, f"{sentence}\n{anchor}", 1),
        encoding="utf-8",
    )


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
        for name in (
            "test-codex-plugin.sh",
            "test-claude-plugin.sh",
            "generate-agent-wrappers.py",
        ):
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
    validator.assert_orchestration_ownership_contract(plugin_root)
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
        "Ralph executor-default mandate becomes optional",
        "executor-default orchestration contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "MUST dispatch `executor`",
            "MAY dispatch `executor`",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Ralph dispatch packet drops Artifacts",
        "dispatch packet Artifacts/identity contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "Artifacts: {verification ledger and read-only inputs; .oh-no state stays main-owned}",
            "Inputs: {selected context}",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Ralph packet drops persistent executor assignment identity",
        "dispatch packet Artifacts/identity contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "Executor assignment ID: {stable across one executor assignment or TDD cycle; not applicable for non-executor roles}",
            "Executor context: {optional prose}",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "fixed revision requests a second reviewer approval",
        "review-to-executor ownership contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "Reviewer approval of the fixed revision is NOT required and MUST NOT be requested",
            "Reviewer approval of the fixed revision is required before FINALIZE",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "executor result enum becomes free-form",
        "executor result envelope",
        lambda root: replace_once(
            root / "docs" / "agent-core" / "executor.md",
            "Result: implemented | blocked | failed",
            "Result: free-form summary",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "executor result drops assignment identity echo",
        "executor result envelope",
        lambda root: replace_once(
            root / "docs" / "agent-core" / "executor.md",
            "Executor assignment ID: <echo>",
            "Executor context: <summary>",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "executor drops received revision binding",
        "executor result envelope",
        lambda root: replace_once(
            root / "docs" / "agent-core" / "executor.md",
            "Target revision/diff fingerprint received: <echo>",
            "Target revision summary: <description>",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "code-reviewer drops reviewed revision binding",
        "code-reviewer verdict/revision envelope",
        lambda root: replace_once(
            root / "docs" / "agent-core" / "code-reviewer.md",
            "Reviewed revision/diff fingerprint: <exact inspected target>",
            "Reviewed target: <description>",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "verifier regains a write loophole",
        "verifier read-only verdict/revision envelope",
        lambda root: replace_once(
            root / "docs" / "agent-core" / "verifier.md",
            "Unconditionally read-only",
            "Read-only unless the caller assigns a write",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Ralplan overwrites a frozen none parallel trigger",
        "Ralplan frozen parallel-trigger handoff contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "preserves the plan path and\n  the exact frozen `Parallel trigger` value",
            "always changes the trigger to approved-plan-handoff",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Ralph overrides a frozen none parallel trigger",
        "executor-default orchestration contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "A frozen `none` remains `none`:",
            "A frozen `none` becomes `natural-dispatch`:",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "simplify applies cleanup without executor",
        "simplify executor-apply ownership",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "simplify.md",
            "dispatch one scoped `executor` assignment",
            "apply each cleanup directly",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "systematic debugging makes executor optional",
        "systematic-debugging executor-default ownership",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "systematic-debugging.md",
            "Apply the minimal fix through `executor` by default",
            "Apply the minimal fix inline by default",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "orchestration default moves into forced routing",
        "unconditional bootstrap_policy",
        lambda root: move_bootstrap_orchestration_sentence(
            root / "hooks" / "session-start"
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Ralph resume redispatches overlapping active work",
        "active-dispatch resume reconciliation",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "Never redispatch\noverlapping work while the prior entry remains pending.",
            "Redispatch overlapping work before reconciling the prior pending entry.",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "required verifier dispatch-unavailable satisfies completion",
        "required verifier fail-closed completion contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "`dispatch-unavailable` is a blocker\n  and cannot satisfy completion",
            "`dispatch-unavailable` is recorded and may satisfy completion",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "required Plan-Reviewer passes inline",
        "review-boundary marker",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "an inline review cannot satisfy the required pass",
            "an inline review may satisfy the required pass",
        ),
        assertion="assert_ralplan_review_boundary_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Diff-Budget remains valid after material mutation",
        "revision-bound marker",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "Any later material mutation marks the result `stale` and returns the gate to\n`pending`;",
            "Any later material mutation leaves the prior passed fingerprint valid;",
        ),
        assertion="assert_ralplan_review_boundary_contract",
    )

    expect_rejected(
        validator,
        plugin_root,
        "cross-host review restores retired Ralph policy reference",
        "stale ralph-subagent-policy reference",
        lambda root: replace_once(
            root / "docs" / "platforms" / "cross-host-review.md",
            "docs/skill-core/ralph.md",
            "docs/shared/ralph-subagent-policy.md",
        ),
        assertion="assert_orchestration_ownership_contract",
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
        "all-accepted branch reintroduces a closure review",
        "retains forbidden single-round review marker: 'delta closure review'",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "All accepted: create exactly one final Planner revision v2; run no further review — the Plan Approval Brief surfaces each accepted finding→fix mapping for the user.",
            "All accepted: create exactly one final Planner revision v2, then exactly one delta closure review; the Plan Approval Brief surfaces each accepted finding→fix mapping for the user.",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "rejected branch creates v2 before user resolution",
        "rejected must create no v2 before user resolution",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "Any rejected: return the disposition-only user-decision packet; create no v2 until the user resolves it.",
            "Any rejected: create revision v2 before the user resolves it.",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "deferred branch creates a revision while pending",
        "deferred must leave the plan pending with no v2",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "Any deferred: leave the plan pending in the disposition-only user-decision packet; create no v2.",
            "Any deferred: create revision v2 while the plan is pending.",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "mixed branch revises before resolving non-accepted blockers",
        "mixed blockers must resolve before one v2",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "Mixed: resolve every non-accepted blocker before exactly one v2.",
            "Mixed: revise accepted blockers before resolving the other dispositions.",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "waiver-only branch creates a revision",
        "permitted waiver with no body change must create no v2",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "Permitted waivers with no body change: keep the waivers visible; create no v2.",
            "Permitted waivers with no body change: create v2.",
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
        "direction-change branch reuses the old run",
        "direction change must start a new run",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "Direction change: update the requirements source, start a new planning run.",
            "Direction change: reuse the old planning run.",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "re-review rules section is restored",
        "retains forbidden single-round review marker: '## Re-Review Rules'",
        lambda root: append_before_heading(
            root / "docs" / "skill-core" / "ralplan.md",
            "## Findings Ledger Gate",
            "## Re-Review Rules\n\nFull-depth review is allowed with a stated reason for a change.",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "Claude review packets restore byte-identical wording",
        "missing amended review-packet marker",
        lambda root: replace_once(
            root / "docs" / "platforms" / "claude-code-ralph.md",
            "packet bodies MUST be identical except the single `Assigned perspective:` line",
            "packet bodies MUST be byte-identical",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "Ralph perspective pair regresses to one targeted reviewer",
        "missing fixed-revision completion marker: 'one perspective-diverse code-reviewer pair'",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "one perspective-diverse code-reviewer pair",
            "one targeted reviewer instance",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "Codex review packets restore identical redacted packet wording",
        "missing perspective-pair marker",
        lambda root: replace_once(
            root / "docs" / "platforms" / "codex-ralph.md",
            "The two review legs receive redacted packets identical except the single `Assigned perspective:` line.",
            "The two review legs receive the identical redacted packet.",
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
            'if next(iter(unique_reviewed)) != proof["draft_id"]:\n    raise SystemExit(\n        "Codex ralplan reviewer pair did not identify the dynamic draft id"\n    )',
            'if next(iter(unique_reviewed)).startswith(proof["draft_id"]):\n    raise SystemExit(\n        "Codex ralplan reviewer pair did not identify the dynamic draft id"\n    )',
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "duplicate Ralph Execution Loop Diff-Budget execution",
        "Execution Loop must schedule one Diff-Budget Gate per stabilized revision",
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
        "ralph conditional Diff-Budget execution",
        "makes final Diff-Budget execution conditional or repeated",
        lambda root: (
            append_before_heading(
                root / "docs" / "skill-core" / "ralph.md",
                "## Review Gate",
                "Run the Diff-Budget Gate only if thresholds are crossed.",
            )
        ),
    )

    print("ok - review-boundary mutations are rejected")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
