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


def weaken_verifier_trigger_predicate(root: Path) -> None:
    """Turn the canonical named-trigger predicate back into a mode/maker default.

    The 2026-07-29 policy makes ONE predicate the sole verifier selector. This
    mutation restores the retired "same author => mandatory audit" rule and
    deletes the explicit non-triggers, which is exactly the regression the
    predicate contract must catch.
    """
    path = root / "docs" / "skill-core" / "ralph.md"
    replace_once(
        path,
        "The verifier audit is required exactly when\n`### Independent Verifier Trigger Predicate` fires, in any mode. Same authorship\nof the proving tests or implementation is explicitly NOT such a trigger.",
        "The verifier audit is required at STANDARD/THOROUGH when the proving tests or\nimplementation were authored or accepted by the same agent.",
    )
    replace_once(
        path,
        "Explicit NON-TRIGGERS",
        "Additional advisory considerations",
    )


def waive_triggered_verifier_independence(root: Path) -> None:
    """Let a FIRED verifier trigger be satisfied inline instead of fail-closed."""
    path = root / "docs" / "skill-core" / "ralph.md"
    replace_once(
        path,
        "A triggered audit MUST run in a separate context",
        "A triggered audit SHOULD run in a separate context when convenient",
    )
    replace_once(
        path,
        "they cannot\ncount as a triggered independent audit",
        "they may\ncount as a triggered independent audit",
    )


def allow_unrecorded_inline_completion(root: Path) -> None:
    """Let an inline mutation complete without any recorded fallback reason.

    Since 2026-07-30 inline mutation is permitted by the need test, so the
    defended property is no longer "dispatch or fail" but "dispatch evidence OR
    exactly one recorded inline reason". Silence is the regression: it makes an
    undisclosed inline edit indistinguishable from a dispatched one.
    """
    replace_once(
        root / "docs" / "skill-core" / "ralph.md",
        "every repository work-product mutation shows dispatched-executor evidence, or\n"
        "  one recorded inline fallback reason (LIGHT-tiny or dispatch-unavailable) per\n"
        "  inline edit; an unrecorded inline mutation cannot complete in any mode",
        "a run may complete without recording how each mutation was performed",
    )


def force_light_cleanup_through_reviewer(root: Path) -> None:
    path = root / "docs" / "skill-core" / "ralph.md"
    replace_once(
        path,
        "The post-cleanup review inspection and the `single review round`\nlanguage apply whenever a code-review stage runs, under `single-reviewer` or\n`perspective-pair`.",
        "The post-cleanup review inspection and the `single review round`\nlanguage apply to every mode, including LIGHT.",
    )
    replace_once(
        path,
        "proceeds\ndirectly from CLEANUP/RECHECK to its verifier decision under",
        "proceeds from\nCLEANUP/RECHECK through a reviewer stage before its verifier decision under",
    )


def blur_light_reviewer_verifier_boundary(root: Path) -> None:
    """Erase the LIGHT code-review waiver by relabelling it as a review round."""
    path = root / "docs" / "skill-core" / "ralph.md"
    replace_once(
        path,
        "not-required (LIGHT: code review waived)",
        "perspective-pair (LIGHT: reviewer pair equivalent)",
    )
    replace_once(
        path,
        "a verifier joins that path only when the predicate fires",
        "a verifier never joins that path in LIGHT",
    )


def weaken_light_hard_exclusions(root: Path) -> None:
    path = root / "docs" / "skill-core" / "ralph.md"
    replace_once(
        path,
        "`unknown = excluded (fail closed)`",
        "`unknown = allowed`",
    )
    replace_once(
        path,
        "generated files or generation\ninputs",
        "generated files are eligible without checking generation inputs",
    )
    replace_once(
        path,
        "materiality of the controlled VALUE",
        "technical type alone determines whether the controlled value is eligible",
    )


def remove_light_tdd_no_exception_rule(root: Path) -> None:
    path = root / "docs" / "skill-core" / "ralph.md"
    replace_once(
        path,
        "behavior-LIGHT gets NO TDD-exception escape",
        "behavior-LIGHT may record a TDD exception",
    )


def let_size_shortcut_into_light(root: Path) -> None:
    path = root / "docs" / "skill-core" / "ralph.md"
    replace_once(
        path,
        "Size alone\nNEVER grants LIGHT",
        "Size alone\nMAY grant LIGHT",
    )
    replace_once(
        path,
        "the exclusion gate runs regardless of size",
        "the exclusion gate runs only after the size shortcut",
    )
    append_before_heading(
        path,
        "### STANDARD Small-Task Carve-Out",
        "Changes of 2 files or fewer may enter LIGHT without the exclusion gate.",
    )


def remove_light_escalation_triggers(root: Path) -> None:
    path = root / "docs" / "skill-core" / "ralph.md"
    replace_once(
        path,
        "an exclusion becoming present-or-unknown",
        "a previously recorded concern becoming severe",
    )
    replace_once(
        path,
        "the edit set growing past a cohesive localized scope",
        "the implementation becoming inconvenient",
    )


def add_hard_numeric_light_bounds(root: Path) -> None:
    append_before_heading(
        root / "docs" / "skill-core" / "ralph.md",
        "### STANDARD Small-Task Carve-Out",
        "LIGHT eligibility is restricted to at most 3 files. "
        "Changes of 2 files or fewer automatically qualify for LIGHT.",
    )


def move_bootstrap_orchestration_sentence(path: Path) -> None:
    sentence = (
        "Orchestration default: main agents own .oh-no state/gates; "
        "STANDARD/THOROUGH repository mutations use executors, except recorded "
        "LIGHT-tiny or dispatch-unavailable inline fallback."
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


def copy_contract_fixture(plugin_root: Path, temp_dir: str) -> Path:
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
        "generate-skill-wrappers.py",
    ):
        shutil.copy2(source_scripts / name, scripts_copy / name)
    return copy


def expect_rejected(
    validator,
    plugin_root: Path,
    label: str,
    expected_error: str,
    mutate,
    assertion="assert_ralplan_review_boundary_contract",
) -> None:
    with tempfile.TemporaryDirectory(prefix="oh-no-review-boundary-") as temp_dir:
        copy = copy_contract_fixture(plugin_root, temp_dir)
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


def append_text(path: Path, text: str) -> None:
    path.write_text(path.read_text(encoding="utf-8") + text, encoding="utf-8")


def reintroduce_common_fragment(root: Path) -> None:
    (root / "docs/agent-core/_global-context-capsule.md").write_text(
        "# Global Context Capsule\n", encoding="utf-8"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plugin-root", required=True, type=Path)
    args = parser.parse_args()
    plugin_root = args.plugin_root.resolve()
    repo_root = plugin_root.parent.parent
    validator = load_validator(repo_root)
    validator.assert_workflow_object_routing_contract(plugin_root)
    validator.assert_child_packet_ownership_contract(plugin_root)
    validator.assert_direct_dispatch_compatibility_contract(plugin_root)
    validator.assert_codex_child_packet_floor_contract(plugin_root)
    validator.assert_ralph_live_heading_references(plugin_root)
    validator.assert_orchestration_ownership_contract(plugin_root)
    validator.assert_ralplan_review_boundary_contract(plugin_root)

    packet_assertion = "assert_child_packet_ownership_contract"
    expect_rejected(
        validator, plugin_root, "common agent-core fragment is reintroduced",
        "must be absent", reintroduce_common_fragment, packet_assertion,
    )
    expect_rejected(
        validator, plugin_root, "SessionStart child packet loses proportional purpose",
        "purpose/outcome", lambda root: replace_once(
            root / "hooks/session-start", "purpose/outcome", "task summary"), packet_assertion,
    )
    expect_rejected(
        validator, plugin_root, "SessionStart loses selective disclosure",
        "withholds maker conclusions", lambda root: replace_once(
            root / "hooks/session-start",
            "withholds maker conclusions, expected verdicts, sibling output, preferred causes",
            "includes every available conclusion"), packet_assertion,
    )
    expect_rejected(
        validator, plugin_root, "generator restores common-fragment scaffolding",
        "forbidden common-fragment composition", lambda root: append_text(
            root.parent.parent / "scripts/generate-agent-wrappers.py",
            "\nCOMMON_AGENT_CORE = '_global-context-capsule.md'\n"), packet_assertion,
    )
    expect_rejected(
        validator, plugin_root, "role core copies the former capsule header",
        "former shared receiver contract", lambda root: append_before_heading(
            root / "docs/agent-core/explore.md", "## Operating Rules",
            "# Global Context Capsule"), packet_assertion,
    )
    expect_rejected(
        validator, plugin_root, "generated role prompt copies the former capsule header",
        "former shared receiver contract", lambda root: append_text(
            root / "agents/explore.md", "\n# Global Context Capsule\n"), packet_assertion,
    )
    expect_rejected(
        validator, plugin_root, "Ralph reviewer packet is no longer blind",
        "Reviewer packets are blind to maker conclusions", lambda root: replace_once(
            root / "docs/skill-core/ralph.md",
            "Reviewer packets are blind to maker conclusions",
            "Reviewer packets include maker conclusions"), packet_assertion,
    )
    expect_rejected(
        validator, plugin_root, "verifier skips evidence design before audit",
        "First design the required evidence", lambda root: replace_once(
            root / "docs/agent-core/verifier.md",
            "First design the required evidence",
            "First accept the supplied proof"), packet_assertion,
    )
    expect_rejected(
        validator, plugin_root, "debugging packet exposes a preferred cause initially",
        "initial packet is symptom-first", lambda root: replace_once(
            root / "docs/skill-core/systematic-debugging.md",
            "initial packet is symptom-first",
            "initial packet includes the preferred cause"), packet_assertion,
    )
    expect_rejected(
        validator, plugin_root, "child instruction prose is not English",
        "non-English child instruction prose", lambda root: append_before_heading(
            root / "docs/agent-core/debugger.md", "## Operating Rules",
            "원인을 먼저 추측하세요."), packet_assertion,
    )

    direct_assertion = "assert_direct_dispatch_compatibility_contract"
    expect_rejected(
        validator, plugin_root, "direct executor packet loses exact revision safety",
        "direct-dispatch safety contract", lambda root: replace_once(
            root / "docs/agent-core/executor.md",
            "require the target role, exact\n  target revision/diff fingerprint",
            "require the target role and descriptive target summary"), direct_assertion,
    )
    expect_rejected(
        validator, plugin_root, "direct verifier restores mandatory workflow IDs",
        "hard-requires workflow IDs", lambda root: append_before_heading(
            root / "docs/agent-core/verifier.md", "## Output",
            "Before verification, require Packet ID, Run/session ID, Story/task ID."),
        direct_assertion,
    )

    codex_floor_assertion = "assert_codex_child_packet_floor_contract"
    expect_rejected(
        validator, plugin_root, "Codex hook-disabled floor loses selective disclosure",
        "Codex child-packet floor marker", lambda root: replace_once(
            root / "docs/platforms/codex-child-packet-floor.md",
            "withhold maker\nconclusions, expected verdicts, sibling outputs, and preferred root-cause\nhypotheses",
            "include every available conclusion"), codex_floor_assertion,
    )
    expect_rejected(
        validator, plugin_root, "self-contained Codex wrapper loses shared caller floor",
        "hook-disabled caller floor marker", lambda root: replace_once(
            root / "skills/ralph/SKILL.md",
            "../../docs/platforms/codex-child-packet-floor.md",
            "../../docs/platforms/codex-ralph.md"), codex_floor_assertion,
    )

    expect_rejected(
        validator, plugin_root, "retired Ralph heading reference returns",
        "retired Ralph heading reference", lambda root: append_before_heading(
            root / "docs/skill-core/ralph.md", "## Output",
            "See the retired Scope Trace Gate for scope decisions."),
        assertion="assert_ralph_live_heading_references",
    )

    expect_rejected(
        validator, plugin_root, "Ralph permits out-of-manifest mutation",
        "Expansion request", lambda root: replace_once(
            root / "docs/skill-core/ralph.md", "stops before editing and\nreturns an `Expansion request`",
            "continues editing and records the expansion later"), packet_assertion,
    )
    for label, marker, replacement in (
        ("unmapped test is admitted", "Map every new or changed test", "admit tests without an AC or failure-mode map"),
        ("duplicate test variant is admitted", "duplicate variants", "repeated inputs are encouraged"),
        ("implementation-detail-only test is admitted", "implementation-detail-only assertions", "private helper checks are accepted"),
        ("defensive combination explosion is admitted", "combination explosion", "cross-product expansion is accepted"),
        ("new helper framework is admitted", "unapproved helper/framework/fixture expansion", "new test infrastructure is accepted"),
    ):
        expect_rejected(
            validator, plugin_root, label, marker,
            lambda root, marker=marker, replacement=replacement: replace_once(
                root / "docs/skill-core/ralph.md", marker, replacement), packet_assertion,
        )
    expect_rejected(
        validator, plugin_root, "final run Completion Stop precedes mutation-capable cleanup",
        "final run Completion Stop ordering requires exactly one '## Completion Stop'",
        lambda root: append_before_heading(
            root / "docs/skill-core/ralph.md", "## Cleanup And Final Verification",
            "## Completion Stop\n\nRecord final run Completion Stop only after mutation-capable cleanup, the sole review round and any one focused review fix, any triggered final verifier, and the exact final complete manifest fingerprint. Any later mutation invalidates this final stop and requires reevaluation and reverification on the new revision."), packet_assertion,
    )
    expect_rejected(
        validator, plugin_root, "independent verifier audit loses necessity mapping",
        "Test Necessity mapping", lambda root: replace_once(
            root / "docs/skill-core/ralph.md", "Test Necessity mapping",
            "test count"), packet_assertion,
    )

    expect_rejected(
        validator,
        plugin_root,
        "unconditional bootstrap loses canonical workflow object boundary",
        "object-owner: unconditional OH_NO_BOOTSTRAP is missing 'A workflow name used only as the subject of analysis, explanation, comparison, or critique is not an invocation trigger.'",
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
        "Claude orchestration drops the no-nested-host-plan boundary",
        "host-plan: Claude OH_NO_MAIN_AGENT_ORCHESTRATION is missing 'Host-plan boundary:'",
        lambda root: replace_once(
            root / "hooks" / "session-start",
            "Host-plan boundary: never auto-wrap",
            "Host planning is fine: freely auto-wrap",
        ),
        assertion="assert_workflow_object_routing_contract",
    )
    # Polarity-only flips: every original token survives, so a substring or
    # keyword check would pass. Only verbatim clause pinning rejects these.
    expect_rejected(
        validator,
        plugin_root,
        "host-plan no-auto-wrap clause flips to a permitted host planning wrapper",
        "host-plan: canonical clause altered or missing (no automatic host planning wrapper)",
        lambda root: replace_once(
            root / "hooks" / "session-start",
            "never auto-wrap Ralph-eligible Oh No Harness execution in EnterPlanMode",
            "always auto-wrap Ralph-eligible Oh No Harness execution in EnterPlanMode",
        ),
        assertion="assert_workflow_object_routing_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "host-plan routes a usable execution contract away from Ralph",
        "host-plan: canonical clause altered or missing "
        "(usable approved/concrete execution contract runs Ralph directly)",
        lambda root: replace_once(
            root / "hooks" / "session-start",
            "Usable approved/concrete execution contract goes straight to Ralph",
            "Usable approved/concrete execution contract goes straight to host plan mode",
        ),
        assertion="assert_workflow_object_routing_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "host-plan suppresses the upstream planning route for vague work",
        "host-plan: canonical clause altered or missing (vague or plan-only work routes upstream)",
        lambda root: replace_once(
            root / "hooks" / "session-start",
            "vague or plan-only work routes upstream to Oh No Harness planning",
            "vague or plan-only work routes to host plan mode",
        ),
        assertion="assert_workflow_object_routing_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "host-plan suppresses no-route housekeeping directness",
        "host-plan: canonical clause altered or missing (no-route housekeeping stays direct)",
        lambda root: replace_once(
            root / "hooks" / "session-start",
            "no-route housekeeping stays direct",
            "no-route housekeeping enters host plan mode",
        ),
        assertion="assert_workflow_object_routing_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "host-plan drops the explicit-user-request carve-out for host plan mode",
        "host-plan: canonical clause altered or missing "
        "(host plan mode requires explicit user request)",
        lambda root: replace_once(
            root / "hooks" / "session-start",
            "host plan mode needs explicit user request",
            "host plan mode needs no user request",
        ),
        assertion="assert_workflow_object_routing_contract",
    )

    expect_rejected(
        validator,
        plugin_root,
        "model fidelity narrows from every role back to executor-only",
        "missing required session-start marker: 'Model fidelity: every role dispatch'",
        lambda root: replace_once(
            root / "hooks" / "session-start",
            "Model fidelity: every role dispatch",
            "Model fidelity: every executor dispatch",
        ),
        assertion="assert_hook_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "model fidelity permits an arbitrary per-call model value",
        "missing required session-start marker: 'carries no per-call model value'",
        lambda root: replace_once(
            root / "hooks" / "session-start",
            "carries no per-call model value",
            "may carry any per-call model value",
        ),
        assertion="assert_hook_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "model fidelity narrows the carve-out to review pairs only",
        "missing required session-start marker: "
        "'the sole exception is a prescribed model-diversity leg or panel'",
        lambda root: replace_once(
            root / "hooks" / "session-start",
            "the sole exception is a prescribed model-diversity leg or panel",
            "the sole exception is the diversity leg of a review pair",
        ),
        assertion="assert_hook_contract",
    )

    # 2026-07-30 one need test for every non-review role, mutation included.
    # The defended property is the TEST, not a polarity: both extremes regress by
    # reusing the same tokens. Restoring an absolute never-inline rule
    # over-delegates a two-tool-call edit; deleting the test licenses unrecorded
    # inline maker work; and dropping the one-suffices floor lets a single
    # bounded question fan out across redundant subagents.
    expect_rejected(
        validator,
        plugin_root,
        "SessionStart restores the absolute never-inline read-only rule",
        "restores the retired absolute never-inline read-only rule",
        lambda root: replace_once(
            root / "hooks" / "session-start",
            "One need test governs every non-review role, repository work-product "
            "mutation included: work dispatches a role subagent when sizeable, "
            "genuinely independent, or parallelizable; a bounded lookup or edit "
            "finishable in a handful of tool calls may run inline, with a recorded "
            "reason and, for an edit, a scoped diff check. Use one subagent where "
            "one suffices, not several; keep spawn counts low.",
            "it never performs exploration, investigation, analysis, or repository "
            "work-product mutation inline when a role subagent can do it.",
        ),
        assertion="assert_hook_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "SessionStart drops the one-suffices spawn-count floor",
        "missing required session-start marker: "
        "'Use one subagent where one suffices, not several; keep spawn counts low'",
        lambda root: replace_once(
            root / "hooks" / "session-start",
            " Use one subagent where one suffices, not several; keep spawn counts low.",
            "",
        ),
        assertion="assert_hook_contract",
    )
    # Opposite extreme: deleting the need test entirely, so nothing distinguishes
    # a sizeable independent track from a two-tool-call edit.
    expect_rejected(
        validator,
        plugin_root,
        "SessionStart deletes the mutation need test",
        "missing required session-start marker: "
        "'One need test governs every non-review role, repository work-product "
        "mutation included'",
        lambda root: replace_once(
            root / "hooks" / "session-start",
            "One need test governs every non-review role, repository work-product "
            "mutation included: work dispatches a role subagent when sizeable, "
            "genuinely independent, or parallelizable; a bounded lookup or edit "
            "finishable in a handful of tool calls may run inline, with a recorded "
            "reason and, for an edit, a scoped diff check.",
            "Any work may run inline whenever that is faster.",
        ),
        assertion="assert_hook_contract",
    )
    # Review independence must NOT inherit the relaxation: a fired review or
    # audit trigger exists for independence, not throughput, so folding it into
    # the need test would let a small diff silently self-review.
    expect_rejected(
        validator,
        plugin_root,
        "SessionStart subjects review independence to the need test",
        "missing required session-start marker: "
        "'Review independence is exempt from the need test'",
        lambda root: replace_once(
            root / "hooks" / "session-start",
            "Review independence is exempt from the need test:",
            "Review roles follow the same need test:",
        ),
        assertion="assert_hook_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "SessionStart lets convenience collapse a fired review trigger",
        "missing required session-start marker: "
        "'Convenience, a small diff, or time pressure never collapses it'",
        lambda root: replace_once(
            root / "hooks" / "session-start",
            "Convenience, a small diff, or time pressure never collapses it; only "
            "confirmed dispatch-unavailability does, recorded as a blocker.",
            "Collapse it inline when the diff is small.",
        ),
        assertion="assert_hook_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Ralph explore step drops the one-when-one-suffices floor",
        "one-when-one-suffices explore floor",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "one `explore` when one covers the question, scaling to genuinely\n"
            "   independent targets as one parallel batch (up to 5); never split a small\n"
            "   bounded lookup into multiple dispatches",
            "one `explore` per candidate target as one parallel batch (up to 5)",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Ralph batch rule drops the single-agent floor",
        "one-when-one-suffices batch floor",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "Dispatch a single agent when one covers the work, and scale out only\n"
            "across genuinely independent targets; a small bounded lookup is never split\n"
            "into multiple dispatches.",
            "Fan out across every candidate target.",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Ralplan planning roles drop the one-when-one-suffices floor",
        "one-when-one-suffices planning-role floor",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "one instance when one covers the question, fanning out to one per "
            "genuinely independent subsystem (up to 5), batched",
            "one per candidate subsystem (up to 5), batched",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Interview brownfield explore drops the one-when-one-suffices floor",
        "one-when-one-suffices planning-role floor",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "interview.md",
            "one instance when one covers the question, fanning out to one per "
            "genuinely independent subsystem (up to 5), batched",
            "one per candidate subsystem (up to 5), batched",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # 2026-07-30: the floor must stay in the `explore` ROLE ROW too. A reader
    # consulting only the role table previously saw `up to 5` with no lower
    # bound, so a single bounded question could fan out to five subagents.
    expect_rejected(
        validator,
        plugin_root,
        "systematic-debugging explore row drops the one-when-one-suffices floor",
        "one-when-one-suffices explore-row floor",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "systematic-debugging.md",
            "one instance when one covers the question, fanning out to one per "
            "genuinely independent subsystem (up to 5), batched",
            "one per candidate subsystem (up to 5), batched",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Ralph explore row drops the one-when-one-suffices floor",
        "one-when-one-suffices explore-row floor",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "one instance when one covers the question, fanning out to genuinely "
            "independent read-only targets as one parallel batch (up to 5)",
            "independent read-only targets as one parallel batch (up to 5)",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # 2026-07-30: inline mutation must owe the same maker contract as a dispatched
    # executor. Without the inheritance clause, "this edit is small" becomes a way
    # to opt out of the manifest, scope, and test-necessity gates entirely.
    expect_rejected(
        validator,
        plugin_root,
        "inline mutation stops owing the executor contract",
        "inline-mutation executor-contract inheritance",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "Inline mutation changes WHO edits, never WHAT the edit owes. The "
            "`executor`\ncontract in `docs/agent-core/executor.md` applies UNCHANGED "
            "to an inline edit:",
            "Inline mutation is exempt from the executor contract:",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # The manifest-exit rule has no Expansion-request substitute inline, because
    # there is no child to address. Letting an inline edit continue past the
    # manifest would silently widen scope with no authorization step at all.
    expect_rejected(
        validator,
        plugin_root,
        "inline mutation continues past the Mutation Manifest",
        "inline-mutation executor-contract inheritance",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "Leaving the Mutation\nManifest ENDS inline eligibility",
            "Leaving the Mutation\nManifest keeps inline eligibility",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # Ralplan optional roles must keep the need-based inline reason; without it
    # only host-unavailability and structural ineligibility justify inline, so a
    # small bounded planning lookup is forced into a subagent.
    expect_rejected(
        validator,
        plugin_root,
        "Ralplan optional roles drop the need-based inline reason",
        "planning-role need-based inline reason",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            ", or the work is too\nsmall to benefit from context separation",
            "",
        ),
        assertion="assert_orchestration_ownership_contract",
    )

    expect_rejected(
        validator,
        plugin_root,
        "Ultrawork reverts to order-free Ralph verifier reuse",
        "retains order-free Ralph verifier reuse wording",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ultrawork.md",
            "Reuse Ralph's independent `verifier` pass only when\nall hold: it covers the same final claim and revision",
            "Reuse Ralph's independent `verifier` pass when it covers\nthe final orchestrated revision",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # Token-preserving flips of the mutually exclusive decision.
    expect_rejected(
        validator,
        plugin_root,
        "Ultrawork allows Ralph verifier reuse even when no reuse condition holds",
        "Ultrawork mutually exclusive verifier reuse contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ultrawork.md",
            "pass only when\nall hold:",
            "pass even when\nnone hold:",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Ultrawork drops the otherwise-fresh-dispatch alternative",
        "Ultrawork mutually exclusive verifier reuse contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ultrawork.md",
            "changed since that pass; otherwise dispatch one fresh self-host `verifier` pass.",
            "changed since that pass.",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "reused Ralph verifier remains valid after an Ultrawork-dispatched code-reviewer",
        "Ultrawork mutually exclusive verifier reuse contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ultrawork.md",
            "Ralph's prior verifier is\nearly/stale by construction, so reuse is unavailable and the fresh self-host",
            "Ralph's prior verifier\nremains valid, so reuse is still available and no fresh self-host",
        ),
        assertion="assert_orchestration_ownership_contract",
    )

    expect_rejected(
        validator,
        plugin_root,
        "Ralph executor-default mandate becomes optional",
        "executor-default orchestration contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "`executor` is the DEFAULT owner of\nrepository work-product mutation",
            "`executor` is one optional owner of\nrepository work-product mutation",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # Opposite extreme for the same contract: re-binding the need test to mode
    # would restore the retired per-mode absolute that forced a subagent onto a
    # two-tool-call edit purely because the run was recorded as LIGHT.
    expect_rejected(
        validator,
        plugin_root,
        "Ralph re-binds the need test to execution mode",
        "executor-default orchestration contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "Mode never decides the need test by itself",
            "Mode alone decides dispatch",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # Ralph-side review-independence exemption: a fired Review Gate predicate or
    # audit trigger must stay outside the relaxation.
    expect_rejected(
        validator,
        plugin_root,
        "Ralph subjects review independence to the need test",
        "review-independence need-test exemption contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "Review independence is the one exemption from the need test.",
            "Review roles follow the same need test.",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Ralph lets size collapse a fired review or audit trigger",
        "review-independence need-test exemption contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "Size, convenience, and time pressure never collapse a fired\nreview or audit trigger",
            "A small edit set collapses a fired\nreview or audit trigger",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Ralph assignment delta drops read-only artifact pointers",
        "caller-owned child packet and Ralph assignment-delta contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "Plan/PRD and read-only artifact pointers: {authoritative inputs; .oh-no state stays main-owned}",
            "Inputs: {selected context}",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Ralph packet drops persistent executor assignment identity",
        "caller-owned child packet and Ralph assignment-delta contract",
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
        "LIGHT permits an unknown, generated-surface, or value-materiality exclusion",
        "LIGHT hard exclusion contract",
        weaken_light_hard_exclusions,
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "behavior-LIGHT regains a TDD exception escape",
        "LIGHT behavior RED/GREEN no-exception contract",
        remove_light_tdd_no_exception_rule,
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "size or a hard numeric cap shortcuts into LIGHT",
        "LIGHT size-never-shortcuts-eligibility contract",
        let_size_shortcut_into_light,
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "a run completes through inline mutation with no recorded fallback reason",
        "mutation-evidence completion contract",
        allow_unrecorded_inline_completion,
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "verifier predicate reverts to a mode/same-maker default",
        "canonical verifier trigger-predicate contract",
        weaken_verifier_trigger_predicate,
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "a fired verifier trigger becomes satisfiable inline",
        # The separate-context requirement is pinned by the review-to-executor
        # ownership contract first; either contract failing is a correct reject.
        "review-to-executor ownership contract",
        waive_triggered_verifier_independence,
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "LIGHT code-review waiver is relabelled as a reviewer pair",
        "LIGHT reviewer-waived + trigger-gated verifier contract",
        blur_light_reviewer_verifier_boundary,
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "LIGHT post-cleanup flow is forced through a reviewer stage",
        "LIGHT cleanup-to-verifier topology contract",
        force_light_cleanup_through_reviewer,
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "LIGHT loses either mid-run escalation trigger",
        "LIGHT eligibility escalation contract",
        remove_light_escalation_triggers,
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "LIGHT regains hard numeric file bounds in grant and restrict polarity",
        "LIGHT no-hard-cap contract",
        add_hard_numeric_light_bounds,
        assertion="assert_orchestration_ownership_contract",
    )
    # 2026-07-29: `implemented` must never ride along with an unfinished mutation.
    expect_rejected(
        validator,
        plugin_root,
        "executor may report implemented with a partial mutation",
        "executor result envelope",
        lambda root: replace_once(
            root / "docs" / "agent-core" / "executor.md",
            "a partial mutation\nis `blocked` or `failed`, never completion",
            "a partial mutation\nmay still be reported as implemented",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # 2026-07-29: the completion audit reads evidence and must not grow proof
    # merely because the run is nearly done.
    expect_rejected(
        validator,
        plugin_root,
        "completion audit may dispatch or rerun because completion is imminent",
        "evidence-only completion-audit contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "Imminent completion is NOT a trigger",
            "Imminent completion is itself a trigger",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # 2026-07-29: an approved expansion binds to a new manifest revision before
    # any mutation, and direction-class expansion is never caller-approvable.
    expect_rejected(
        validator,
        plugin_root,
        "expansion may mutate under a superseded manifest revision",
        "## Mutation Manifest and Expansion Gate",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "Mutation under a superseded manifest revision is out-of-scope work",
            "Mutation may continue under the previous manifest revision",
        ),
        assertion="assert_child_packet_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Ralph self-approves direction-class expansion without the user",
        "## Mutation Manifest and Expansion Gate",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "Ralph MUST pause and return to the user, or to `ralplan` for a plan-level\nchange",
            "Ralph MAY approve as caller without returning to the user",
        ),
        assertion="assert_child_packet_ownership_contract",
    )
    # 2026-07-29: blocking requires a demonstrated CURRENT material failure.
    expect_rejected(
        validator,
        plugin_root,
        "code-reviewer regains the speculative future-regression blocking route",
        "code-reviewer demonstrated-failure and single/paired depth contract",
        lambda root: replace_once(
            root / "docs" / "agent-core" / "code-reviewer.md",
            "A speculative or plausible FUTURE regression, absent\n  a demonstrated current failure, is non-blocking",
            "A plausible future regression is blocking",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # 2026-07-29: a paired leg owns depth but must still disclose an obvious
    # material blocker outside its assigned perspective.
    for role, anchor in (
        (
            "code-reviewer",
            "Still report any obvious material blocker you\nnotice outside your perspective",
        ),
        (
            "plan-reviewer",
            "Still report any obvious material blocker you notice outside\nyour perspective",
        ),
    ):
        expect_rejected(
            validator,
            plugin_root,
            f"{role} assigned perspective becomes a blocker-suppressing filter",
            f"{role} "
            + (
                "demonstrated-failure and single/paired depth contract"
                if role == "code-reviewer"
                else "draft-oriented quality gate and single/paired depth contract"
            ),
            lambda root, role=role, anchor=anchor: replace_once(
                root / "docs" / "agent-core" / f"{role}.md",
                anchor,
                "Report only findings inside your assigned perspective",
            ),
            assertion="assert_orchestration_ownership_contract",
        )
    # 2026-07-29: pass 2 is a draft-oriented quality gate, not a self-audit.
    expect_rejected(
        validator,
        plugin_root,
        "plan-reviewer pass 2 regresses to re-auditing its own pass-1 conclusions",
        "plan-reviewer draft-oriented quality gate and single/paired depth contract",
        lambda root: replace_once(
            root / "docs" / "agent-core" / "plan-reviewer.md",
            "Do not re-verify, re-litigate, or restate your pass-1 conclusions",
            "Re-examine pass 1 for rubber-stamping and unsupported severity",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # 2026-07-29: VBC must not reinstate nontriviality/self-authorship defaults
    # or re-prove fresh evidence just because a claim is imminent.
    expect_rejected(
        validator,
        plugin_root,
        "VBC verifier dispatch reverts to a nontriviality default",
        "verification-before-completion trigger-gated verifier and evidence-reuse contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "verification-before-completion.md",
            "Dispatch `verifier` only when a named V4 trigger fires; nontriviality alone is\nnot one",
            "Dispatch `verifier` by default for nontrivial completion claims",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "VBC lets imminent completion force reruns of fresh evidence",
        "verification-before-completion trigger-gated verifier and evidence-reuse contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "verification-before-completion.md",
            "Completion imminence alone never justifies a rerun, an added\n    test, or a fresh dispatch",
            "Completion imminence justifies rerunning every check again",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # CR-1: the Codex adapters must not re-home a pair-by-default topology that
    # contradicts the core's single-reviewer default.
    for adapter, anchor, replacement, label in (
        (
            "codex-ralph.md",
            "ONE full-role code-reviewer on Codex when review is required",
            "one perspective-diverse code-reviewer pair when review is required",
            "Codex Ralph adapter regains a pair-by-default topology",
        ),
        (
            "codex-ralplan.md",
            "ONE required full-role Plan-Reviewer instance on Codex by default",
            "one perspective-diverse Plan-Reviewer pair, unconditionally, on Codex",
            "Codex Ralplan adapter regains an unconditional THOROUGH pair",
        ),
        (
            "codex-verification-before-completion.md",
            "ONE full-role instance by default, escalating to a perspective-diverse pair only on the named trigger",
            "every dispatched review runs as a perspective-diverse pair",
            "Codex VBC adapter regains pair-by-default review",
        ),
    ):
        expect_rejected(
            validator,
            plugin_root,
            label,
            "codex adapter single-reviewer default contract",
            lambda root, adapter=adapter, anchor=anchor, replacement=replacement: replace_once(
                root / "docs" / "platforms" / adapter,
                anchor,
                replacement,
            ),
            assertion="assert_orchestration_ownership_contract",
        )
    # CR-1 cross-host (M3.1): the three Claude adapters must not restore
    # pair-by-default Model Diversity Pair wording, and must keep the ordinary
    # single-reviewer (one stored-primary, no diversity leg) path explicit.
    for adapter, anchor, replacement, label in (
        (
            "claude-code-ralph.md",
            "This section applies ONLY when the core selected `perspective-pair` after a",
            "For any dispatched `code-reviewer` pair (every dispatched review), after a",
            "Claude Ralph adapter restores pair-by-default diversity dispatch",
        ),
        (
            "claude-code-ralplan.md",
            "This section applies ONLY when the core selected `perspective-pair` after a",
            "For the THOROUGH `plan-reviewer` pair (every dispatched THOROUGH review), after a",
            "Claude Ralplan adapter restores unconditional THOROUGH pair dispatch",
        ),
        (
            "claude-code-verification-before-completion.md",
            "This section applies ONLY when the core selected `perspective-pair` after a",
            "For any dispatched `code-reviewer` pair (every dispatched review), after a",
            "Claude VBC adapter restores pair-by-default diversity dispatch",
        ),
    ):
        expect_rejected(
            validator,
            plugin_root,
            label,
            "claude adapter pair-only diversity contract",
            lambda root, adapter=adapter, anchor=anchor, replacement=replacement: replace_once(
                root / "docs" / "platforms" / adapter,
                anchor,
                replacement,
            ),
            assertion="assert_orchestration_ownership_contract",
        )
    # V-1 (failed-verification correction): the Codex Ultrawork adapter must not
    # revert to a pair-by-default Final Validation review.
    expect_rejected(
        validator,
        plugin_root,
        "Codex Ultrawork adapter reverts to pair-by-default Final Validation",
        "codex ultrawork single-reviewer default contract",
        lambda root: replace_once(
            root / "docs" / "platforms" / "codex-ultrawork.md",
            "ONLY after the core's named paired-review trigger fired",
            "Every dispatched Final Validation `code-reviewer` review runs as one pair, and after the trigger fired",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # V-2 / V-3: topology must stay risk-selected, never mode-selected.
    for stale_core, anchor, replacement, label in (
        (
            "ultrawork.md",
            "ralplan's risk-selected topology",
            "ralplan's mode-selected topology",
            "Ultrawork PLANNING row reverts to mode-selected topology",
        ),
        (
            "ralplan.md",
            "at the risk-selected topology",
            "at the mode-selected topology",
            "Ralplan agent-role row reverts to mode-selected topology",
        ),
    ):
        expect_rejected(
            validator,
            plugin_root,
            label,
            "retains stale mode-selected review topology",
            lambda root, stale_core=stale_core, anchor=anchor, replacement=replacement: replace_once(
                root / "docs" / "skill-core" / stale_core,
                anchor,
                replacement,
            ),
            assertion="assert_orchestration_ownership_contract",
        )
    # The named trigger decides whether the pair EXISTS, not just its diversity.
    expect_rejected(
        validator,
        plugin_root,
        "Ultrawork reduces the named trigger to diversity-only escalation",
        "selects only escalated platform diversity",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ultrawork.md",
            "while a named paired-review trigger selects whether the pair exists and then the platform's diversity mechanics",
            "while a named THOROUGH risk selects only escalated platform diversity",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # CR-1 cross-host (M3.2): the SHARED Claude runtime doc must not revert to
    # pair-by-default, since it injects into many generated skills at once.
    expect_rejected(
        validator,
        plugin_root,
        "shared Claude runtime doc reverts to pair-by-default review",
        "shared runtime pair-only diversity contract",
        lambda root: replace_once(
            root / "docs" / "platforms" / "claude-code-runtime.md",
            "such a selected `code-reviewer` pair,",
            "any dispatched `code-reviewer` pair (every dispatched review),",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # It must also keep topology selection with the active core, not itself.
    expect_rejected(
        validator,
        plugin_root,
        "shared Claude runtime doc claims review-topology selection",
        "claude-code-runtime.md is missing required Platform-Rules marker",
        lambda root: replace_once(
            root / "docs" / "platforms" / "claude-code-runtime.md",
            "governs only how an ALREADY-SELECTED pair is dispatched; it never selects review\ntopology itself",
            "selects the review topology for each dispatched review",
        ),
        assertion="assert_execution_mode_contract",
    )
    # The ordinary single-reviewer leg must not lose its no-diversity-leg rule.
    expect_rejected(
        validator,
        plugin_root,
        "Claude adapters drop the single-reviewer no-diversity-leg rule",
        "claude adapter pair-only diversity contract",
        lambda root: replace_once(
            root / "docs" / "platforms" / "claude-code-ralph.md",
            "with NO diversity leg, NO model override, and no",
            "optionally adding a diversity leg and model override, plus no",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # CR-2: Ultrawork must not reinstate same-maker verifier triggers or an
    # unconditional Final Validation pair.
    expect_rejected(
        validator,
        plugin_root,
        "Ultrawork reinstates same-author as an independent verifier trigger",
        "ultrawork trigger-gated Final Validation contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ultrawork.md",
            "having been authored or accepted by the same agent, are explicit NON-triggers",
            "having been authored or accepted by the same agent, require the audit",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Ultrawork Final Validation review reverts to an unconditional pair",
        "ultrawork trigger-gated Final Validation contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ultrawork.md",
            "it runs as ONE full-role `code-reviewer` by default and records\n`single-reviewer`",
            "it runs as the perspective-diverse pair and records\n`perspective-pair`",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # M4 item 1: systematic-debugging must not reinstate the same-maker verifier
    # trigger or a pair-by-default post-fix review, in the core or either adapter.
    expect_rejected(
        validator,
        plugin_root,
        "systematic-debugging reinstates same-author as a verifier trigger",
        "systematic-debugging trigger-gated review and verifier contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "systematic-debugging.md",
            "the proving reproduction tests or fix having been authored or\naccepted by the same agent",
            "the proving reproduction tests or fix authored or accepted by the same agent requiring the audit",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "systematic-debugging post-fix review reverts to a pair by default",
        "systematic-debugging trigger-gated review and verifier contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "systematic-debugging.md",
            "is ONE full-role instance by\ndefault, recorded `single-reviewer`",
            "always runs as the\nperspective-diverse pair",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Codex systematic-debugging adapter regains pair-by-default post-fix review",
        "codex systematic-debugging single-reviewer default contract",
        lambda root: replace_once(
            root / "docs" / "platforms" / "codex-systematic-debugging.md",
            "spawns exactly ONE full-role Codex reviewer, recorded as single-reviewer",
            "instead runs as an intentional same-host perspective pair",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Claude systematic-debugging adapter restores pair-by-default diversity dispatch",
        "claude systematic-debugging pair-only diversity contract",
        lambda root: replace_once(
            root / "docs" / "platforms" / "claude-code-systematic-debugging.md",
            "This section applies ONLY when the core selected `perspective-pair` after a",
            "For any dispatched post-fix `code-reviewer` pair (every dispatched review), after a",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # M4 item 2: compaction follows what actually ran, never the tier alone.
    expect_rejected(
        validator,
        plugin_root,
        "Ralph compaction narrows back to LIGHT-only runs",
        "proportional completion-ledger compaction contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "ANY run may compact the four named criteria into one combined ledger line when",
            "A LIGHT run with no behavior change may compact the four named criteria into one combined ledger line when",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Ralph compaction hides a step that actually ran",
        "proportional completion-ledger compaction contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "Whenever\none of the four actually ran or blocked, that entry stays individual with its own\nevidence.",
            "A dispatched or blocked entry may also be folded into that combined line.",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # M4 item 3: the hand-maintained references must not restate pair-by-default
    # review or an unconditional confirming verifier.
    expect_rejected(
        validator,
        plugin_root,
        "cross-host reference restores pair-by-default review",
        "cross-host reference proportional review contract",
        lambda root: replace_once(
            root / "docs" / "platforms" / "cross-host-review.md",
            "is ONE full-role instance\nby default and records `single-reviewer`",
            "uses a\nperspective-diverse pair",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "cross-host reference restores an unconditional confirming verifier",
        "cross-host reference proportional review contract",
        lambda root: replace_once(
            root / "docs" / "platforms" / "cross-host-review.md",
            "A `verifier` is a dependent later stage that exists\nonly when the calling skill's named verifier trigger predicate fires",
            "The confirming `verifier` is an unconditionally required dependent later stage",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "Claude reference doc restores pair-by-default diversity loading",
        "claude reference proportional review contract",
        lambda root: replace_once(
            root / "docs" / "platforms" / "claude-code.md",
            "Load this section only after the active core actually SELECTED a pair",
            "Load this section after any dispatched `code-reviewer` pair (every dispatched review)",
        ),
        assertion="assert_orchestration_ownership_contract",
    )
    # CR-3: the expansion lifecycle must persist an approval owner, route any
    # named risk needing broader authority, and stay off retired capsule terms.
    expect_rejected(
        validator,
        plugin_root,
        "expansion snapshot drops its approval owner",
        "## Mutation Manifest and Expansion Gate",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "An expansion\nwhose approval owner is unrecorded is unapproved.",
            "The approval owner may be left implicit.",
        ),
        assertion="assert_child_packet_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "expansion routing drops generic named-risk authority escalation",
        "## Mutation Manifest and Expansion Gate",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "That list is illustrative, not exhaustive: ANY named or approved risk",
            "That list is exhaustive: only a listed risk",
        ),
        assertion="assert_child_packet_ownership_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "completion criteria revert to stale current-capsule terminology",
        "expansion manifest-revision completion contract",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "records its approval owner, was approved, and was bound to a revised Mutation\n  Manifest ID recorded in the snapshot and reissued to the executor as\n  `Expansion status: approved@<revision id> -> incorporated before mutation`\n  before any mutation",
            "approved and reflected in the current capsule before mutation",
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
            "Executor assignment ID: <echo when supplied | not supplied — direct workflow>",
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
        "plan-reviewer regains a write loophole",
        "plan-reviewer read-only review envelope",
        lambda root: replace_once(
            root / "docs" / "agent-core" / "plan-reviewer.md",
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
            "## Mutation Manifest and Expansion Gate",
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
            "the confirmed Direction Contract; who owns success and the observable "
            "signal; confidence and what would lower it",
            "the confirmed Direction Contract; who owns success and the observable "
            "signal; confidence and what would lower it; rollout telemetry",
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
            "an unsupported false rejection is also a contract failure",
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
    # 2026-07-29 inverted this pair of controls. STANDARD/ordinary THOROUGH now
    # review with ONE full-role reviewer, so the regressions worth catching are
    # (a) losing the single full-role reviewer entirely and (b) making the
    # escalated pair unreachable, i.e. a named trigger that can never fire.
    expect_rejected(
        validator,
        plugin_root,
        "Ralph drops the required single full-role reviewer",
        "missing fixed-revision completion marker: "
        "'ONE full-role `code-reviewer` for behavior-affecting or workflow'",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "ONE full-role `code-reviewer` for behavior-affecting or workflow",
            "an optional reviewer for behavior-affecting or workflow",
        ),
    )
    expect_rejected(
        validator,
        plugin_root,
        "Ralph makes the triggered escalated review pair unreachable",
        "missing fixed-revision completion marker: "
        "'escalates to one perspective-diverse pair'",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralph.md",
            "escalates to one perspective-diverse pair",
            "is reviewed by the same single reviewer",
        ),
    )
    # The Plan-Reviewer markers live in RALPLAN_CONSENSUS_MARKERS and in
    # assert_proportional_workflow_contract's ralplan entry, so these cases MUST
    # name that assertion explicitly — the default
    # assert_ralplan_review_boundary_contract never reads it and would report
    # `mutation unexpectedly passed`.
    expect_rejected(
        validator,
        plugin_root,
        "ralplan drops the required single full-role THOROUGH reviewer",
        "ralplan.md is missing proportional-workflow marker: "
        "'THOROUGH -> one required full-role Plan-Reviewer instance by default'",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "THOROUGH -> one required full-role Plan-Reviewer instance by default",
            "THOROUGH -> review is optional at the caller's discretion",
        ),
        assertion="assert_proportional_workflow_contract",
    )
    expect_rejected(
        validator,
        plugin_root,
        "ralplan makes the triggered Plan-Reviewer pair unreachable",
        "ralplan.md is missing proportional-workflow marker: "
        "'selects one perspective-diverse Plan-Reviewer'",
        lambda root: replace_once(
            root / "docs" / "skill-core" / "ralplan.md",
            "selects one perspective-diverse Plan-Reviewer",
            "still selects only the single Plan-Reviewer",
        ),
        assertion="assert_proportional_workflow_contract",
    )
    # Reviewer count must never become a quality proxy again: a mode or a
    # "nontrivial" judgement alone cannot authorize a second instance.
    for core in ("ralph", "ralplan"):
        expect_rejected(
            validator,
            plugin_root,
            f"{core} lets mode alone authorize a second reviewer instance",
            f"{core}.md is missing proportional-workflow marker: "
            "'Reviewer count is never a quality proxy'",
            lambda root, core=core: replace_once(
                root / "docs" / "skill-core" / f"{core}.md",
                "Reviewer count is never a quality proxy",
                "More reviewers generally means a safer review",
            ),
            assertion="assert_proportional_workflow_contract",
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
