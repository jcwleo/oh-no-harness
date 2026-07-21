#!/usr/bin/env python3
"""Deterministic deep-smoke: verify each skill's load-bearing workflow rules are
REACHABLE from its composed runtime wrapper plus the docs/shared files and the
sub-skills it hands off to.

This replaces the flaky live-model phrase-grep deep-smoke for GATING purposes:
the live test sampled one stochastic model answer and asserted exact substrings,
so a faithful model that paraphrased (or did not dereference a 2-hop link) failed
non-deterministically. What we actually want to gate on is "does the skill, as
composed, make the rule reachable" — a static, deterministic property.

For each skill we build a resolved text bag = the platform wrapper body + every
`docs/shared/<name>.md` it references + the same-platform wrapper of every skill
it hands off to via the explicit SKILL_REFERENCES graph (bounded depth,
cycle-guarded), then assert each required canonical rule phrase appears there.
Phrases that are genuinely platform-asymmetric (e.g. Codex spawn_agent vs Claude
agent naming) are tagged so they are only required on their platform.

The reference graph is explicit (not regex over every backticked skill name) so a
required cross-skill rule only counts as reachable through a real handoff edge —
an incidental skill mention cannot satisfy it, and removing a genuine handoff
fails the check.

Usage:
    python3 scripts/check-skill-reachability.py --platform codex  [--plugin-root .]
    python3 scripts/check-skill-reachability.py --platform claude [--plugin-root .]
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

WRAPPER_DIR = {"codex": "skills", "claude": "skills-claude"}

BOTH, CODEX, CLAUDE = "both", "codex", "claude"
VALID_PLATFORMS = {BOTH, CODEX, CLAUDE}

# Claude-Code-only skills ship no Codex wrapper, so they are only resolvable (and
# only checked) on the claude platform. Keep this identical to CLAUDE_ONLY_SKILLS
# in scripts/validate-plugin-files.py and scripts/generate-skill-wrappers.py.
CLAUDE_ONLY_SKILLS = {"install-statusline", "configure-subagents"}

# Explicit handoff edges that a required cross-skill phrase is reached through.
# Only these edges are followed when resolving a skill's reachable text, so an
# incidental backtick mention cannot satisfy a required rule. The source patterns
# below derive the same graph from the operational handoff prose and main() rejects
# any divergence before checking phrase reachability.
SKILL_REFERENCES: dict[str, list[str]] = {
    "ralph": ["simplify"],                       # 'Required Behavior Lock'
    "ultrawork": ["interview", "ralplan", "ralph"],  # spec path / single round / cleanup heading
}

SOURCE_HANDOFF_PATTERNS: dict[str, tuple[str, ...]] = {
    "ralph": (r"\binvoke `([a-z0-9-]+)` \(one combined scan\)",),
    "ultrawork": (r"\bread and follow `([a-z0-9-]+)`",),
}

# skill -> list of (canonical phrase, platform). platform=both unless the rule is
# genuinely platform-specific. Every phrase is re-verified reachable on each run,
# so drift fails loudly here instead of intermittently in a paid live test.
REQUIRED: dict[str, list[tuple[str, str]]] = {
    "using-oh-no-harness": [
        ("Orchestration Ownership Boundary", BOTH),
        ("repository work-product mutation is", BOTH),
        ("orchestration state, not inline implementation", BOTH),
    ],
    "auto-routing": [
        # The retired executor-delegation toggle has no replacement in this
        # skill. Keep only the persistent routing-setting contract reachable.
        ("The bundled `scripts/oh-no-config` script resolves the data directory", BOTH),
        ("\"<plugin-root>/scripts/oh-no-config\" on", BOTH),
        ("\"<plugin-root>/scripts/oh-no-config\" off", BOTH),
    ],
    "interview": [
        ("consider advisory context", BOTH),
        ("## Question Routing", BOTH),
        ("## Answer Capture", BOTH),
        ("## Spec Closure Gate", BOTH),
        ("acceptance criteria are testable enough for", BOTH),
        ("Restate the agreed goal in one sentence", BOTH),
        ("Machine-consumable requirements for Standard and Deep", BOTH),
        ("When Quick mode recommends direct Ralph", BOTH),
        ("Assign a stable ID to every acceptance criterion", BOTH),
        ("redact credentials, tokens, secrets, PII, and raw customer data", BOTH),
        ("Classify the request as brownfield or greenfield before asking", BOTH),
        ("technology-stack questions when brownfield repository facts already make", BOTH),
        ("Recommendation requested: yes | no", BOTH),
        ("Skill chaining in Oh No Harness is approval-gated, not automatic", BOTH),
        # Self-contained rewrite: the sizing hint resolves in the core, not a shared doc.
        ("Provisional Ralph mode: LIGHT | STANDARD | THOROUGH | UNKNOWN", BOTH),
    ],
    "ralplan": [
        ("Review runs exactly once", BOTH),
        ("pending approval", BOTH),
        ("Overall Ralph mode", BOTH),
        ("Task sizing", BOTH),
        ("Execution profile", BOTH),
        ("Analyst -> Planner -> Plan-Reviewer", BOTH),
        ("When `Recommendation requested` is `yes`", BOTH),
        ("2-3 viable technology", BOTH),
        ("tradeoffs and one recommended default", BOTH),
        ("requires approval through the existing Plan Approval Brief before Ralph", BOTH),
        ("must-fail-before-implementation case", BOTH),
        ("must-pass-after-implementation case", BOTH),
        ("negative or forbidden-behavior case", BOTH),
        ("old broken behavior", BOTH),
        (".oh-no/worktrees/<task-slug>", BOTH),
        ("Model Diversity Pair", CLAUDE),
        ("Cross-Host Consult Channel", CODEX),
        ("trigger-loaded", BOTH),
        ("exactly one final Planner revision v2", BOTH),
        ("finding→fix mapping", BOTH),
        ("Assigned perspective", BOTH),
        ("APPROVE freezes the exact reviewed Planner draft", BOTH),
        ("Blocking basis: <AC ID | safety invariant | Direction Contract field | applicable mandatory gate>", BOTH),
        ("Non-blocking findings", BOTH),
        ("optional follow-ups", BOTH),
        ("`Agent policy: inline-only` is valid", BOTH),
        ("executor ownership survives", BOTH),
        ("no concurrent batch, not inline mutation", BOTH),
        ("Plan-Reviewer: dispatch-unavailable", BOTH),
        # Platform-owned paired-review vocabulary. Claude proves the A1-amended
        # unoverridden-primary/native-secondary shape; Codex keeps cross-host.
        ("model-diversity-pair", CLAUDE),
        ("identical except the single `Assigned perspective:` line", CLAUDE),
        ("serial dispatch-wait-dispatch", CLAUDE),
        ("primary leg is dispatched without a model override", CLAUDE),
        ("diversity leg uses an explicit NATIVE model override", CLAUDE),
        ("validated secondary top-tier model", CLAUDE),
        ("same-model-parallel-fallback", CLAUDE),
        ("require-model-diversity", CLAUDE),
        ("transition to PAUSED", CLAUDE),
        ("require-cross-host", CODEX),
        ("same-host-perspective-pair", CODEX),
        ("same-host-parallel-fallback", CODEX),
        ("foreground Claude call", CODEX),
        ("Dispatch only after the active skill's trigger fires", CODEX),
    ],
    "ralph": [
        ("Execution Mode Decision Prompt", BOTH),
        ("LIGHT | STANDARD | THOROUGH", BOTH),
        ("Mode-Gated Agent Dispatch", BOTH),
        ("Parallel trigger", BOTH),
        (".oh-no/worktrees/<task-slug>", BOTH),
        ("parent workspace directory", BOTH),
        ("Ralph invokes TDD internally when behavior-changing edits require it", BOTH),
        ("Required Behavior Lock", BOTH),  # reachable via the simplify handoff edge
        ("authored or accepted by the same agent", BOTH),  # STANDARD/THOROUGH verifier-required carve-out (ralph.md Review Gate)
        ("Review Gate dependency graph", BOTH),  # verifier must not start before code-reviewer pair is synthesized
        ("verifier started after reviewer completion", BOTH),  # sequence ledger field, not just pass presence
        ("A verifier spawned before that point is stale", BOTH),  # early verifier cannot count
        ("trigger-loaded", BOTH),
        ("read and follow `verification-before-completion`", BOTH),  # G1 thin VBC reference (FINALIZE COMPLETION_AUDIT checkpoint)
        ("before any completion claim", BOTH),
        ("The run is invalid if the session does not show each required completion criterion below satisfied", BOTH),  # ralph Persistence Rule ledger-invalidation chokepoint
        ("the required reviewer pass, the independent verifier pass, simplify, and verification-before-completion", BOTH),  # presence: 4 completion steps named individually so a skip is a named ledger gap
        ("Missing review topology is a named ledger gap", BOTH),  # proportional review-topology HARD-GATE clause
        ("run the `## Diff-Budget Gate` once for the current", BOTH),
        ("cumulative per-story mid-run early-stop check", BOTH),
        ("Run this final gate once for the current stabilized revision", BOTH),
        ("that revision-bound evaluation expands into the", BOTH),
        ("expands into the detailed scope review", BOTH),
        ("main agent is the orchestrator", BOTH),
        ("executor-default trigger", BOTH),
        ("Packet ID:", BOTH),
        ("Executor assignment ID:", BOTH),
        ("Artifacts:", BOTH),
        ("Direction Contract binding:", BOTH),
        ("source pointer alone is an incomplete Direction Contract packet", BOTH),
        ("Target revision/diff fingerprint:", BOTH),
        ("Reject stale or misrouted results", BOTH),
        ("Active dispatches:", BOTH),
        ("Mark it `final` only after", BOTH),
        ("A frozen `none` remains `none`", BOTH),
        ("`dispatch-unavailable` is a blocker", BOTH),
        ("verifier bound revision: reviewed | fixed", BOTH),
        ("Assigned perspective", BOTH),
        ("model-diversity-pair", CLAUDE),
        ("identical except the single `Assigned perspective:` line", CLAUDE),
        ("serial dispatch-wait-dispatch", CLAUDE),
        ("primary leg is dispatched without a model override", CLAUDE),
        ("diversity leg uses an explicit NATIVE model override", CLAUDE),
        ("validated secondary top-tier model", CLAUDE),
        ("same-model-parallel-fallback", CLAUDE),
        ("require-model-diversity", CLAUDE),
        ("transition to PAUSED", CLAUDE),
        ("same-host-perspective-pair", CODEX),
        ("same-host-parallel-fallback", CODEX),
        ("foreground Claude call", CODEX),
    ],
    "ultrawork": [
        (".oh-no/specs/", BOTH),
        (".oh-no/specs/interview-", BOTH),  # via the interview handoff edge
        ("one-round review budget", BOTH),  # via the ralplan handoff edge
        (".oh-no/worktrees/<task-slug>", BOTH),
        ("git worktree add", BOTH),
        ("Worktree decision: ultrawork automatic worktree", BOTH),
        ("ultrawork automatic approval", BOTH),
        ("Read and follow `ralplan`", BOTH),
        ("Read and follow `ralph`", BOTH),
        ("Ultrawork-approved", BOTH),
        ("mode and mode source", BOTH),
        ("## Cleanup And Final Verification", BOTH),  # via the ralph handoff edge
        ("authored or accepted by the same agent", BOTH),  # verifier independence carve-out (ultrawork.md body + Ralph core)
        ("Final Validation dependency graph", BOTH),  # verifier must not start before code-reviewer pair is synthesized
        ("verifier started after reviewer completion", BOTH),  # sequence ledger field, not just pass presence
        ("A verifier spawned before that point is stale", BOTH),  # early verifier cannot count
        ("trigger-loaded", BOTH),
        ("Run `verification-before-completion` before any completion claim or final report", BOTH),  # G1 thin VBC reference (ultrawork Phase 5)
        ("The run is invalid if the session ledger does not show each required phase gate satisfied", BOTH),  # ultrawork Phase 5 ledger-invalidation chokepoint
        ("reviewer pass, independent verifier pass, simplify/cleanup, and VBC", BOTH),  # presence: 4 completion steps named individually so a skip is a named ledger gap
        ("worktree_gate: no source file edit until a", BOTH),  # ultrawork worktree_gate (G2 reference, carries worktree-isolation path token)
        ("requirements_gate: planning must not start until the requirements source is recorded", BOTH),  # ultrawork requirements_gate
        ("Missing review topology is a named ledger gap", BOTH),  # proportional review-topology HARD-GATE clause
        ("`code-reviewer` dispatched only for additional orchestration risk", BOTH),
        ("Ralph-unavailable fallback", BOTH),
        ("Ultrawork still owns `.oh-no` state", BOTH),
        ("executor ownership", BOTH),
        ("inline evidence cannot satisfy it", BOTH),
        ("Assigned perspective", BOTH),
        ("model-diversity-pair", CLAUDE),
        ("identical except the single `Assigned perspective:` line", CLAUDE),
        ("serial dispatch-wait-dispatch", CLAUDE),
        ("primary leg is dispatched without a model override", CLAUDE),
        ("diversity leg uses an explicit NATIVE model override", CLAUDE),
        ("validated secondary top-tier model", CLAUDE),
        ("same-model-parallel-fallback", CLAUDE),
        ("require-model-diversity", CLAUDE),
        ("transition to PAUSED", CLAUDE),
        ("same-host-perspective-pair", CODEX),
        ("same-host-parallel-fallback", CODEX),
        ("foreground Claude call", CODEX),
    ],
    "test-driven-development": [
        ("Execution Ownership", BOTH),
        ("one stable `Executor assignment ID`", BOTH),
        ("RED, GREEN, and REFACTOR", BOTH),
        ("each Packet ID remains unique", BOTH),
        ("caller remains the orchestrator", BOTH),
    ],
    "simplify": [
        ("Required Behavior Lock", BOTH),
        ("Phase 0 - Gather The Diff", BOTH),
        ("Phase 1 - Review", BOTH),
        ("Phase 2 - Apply The Fixes", BOTH),
        ("Reuse", BOTH),
        ("Simplification", BOTH),
        ("Efficiency", BOTH),
        ("Altitude", BOTH),
        ("subagent", BOTH),
        ("Cleanup Depth Decision", BOTH),
        ("one quick or combined scan", BOTH),
        ("four independent cleanup subagents in\none batch", BOTH),
        ("dispatch-unavailable reason", BOTH),
        ("false positive", BOTH),
        ("intended behavior", BOTH),
        ("Maintainability Debt Boundary", BOTH),
        ("read-only discovery", BOTH),
        ("scoped `executor` assignment", BOTH),
        ("Mutation fallback: dispatch-unavailable", BOTH),
    ],
    "systematic-debugging": [
        ("Find the root cause before changing behavior", BOTH),
        ("hypothesis ledger", BOTH),
        ("causal toggle", BOTH),  # the falsifiable root-cause confirmation gate
        ("the failure mode is gone", BOTH),
        ("verification-before-completion", BOTH),
        ("authored or accepted by the same agent", BOTH),  # verifier independence carve-out (Ralph core, path-referenced)
        ("trigger-loaded", BOTH),
        ("Missing review topology is a named ledger gap", BOTH),  # proportional review-topology HARD-GATE clause
        ("do not directly dispatch\n    `plan-reviewer`", BOTH),
        ("executor-default minimal fix", BOTH),
        ("Apply the minimal fix through `executor` by default", BOTH),
        ("Mutation fallback: LIGHT-tiny", BOTH),
        ("Assigned perspective", BOTH),
        ("model-diversity-pair", CLAUDE),
        ("identical except the single `Assigned perspective:` line", CLAUDE),
        ("serial dispatch-wait-dispatch", CLAUDE),
        ("primary leg is dispatched without a model override", CLAUDE),
        ("diversity leg uses an explicit NATIVE model override", CLAUDE),
        ("validated secondary top-tier model", CLAUDE),
        ("same-model-parallel-fallback", CLAUDE),
        ("require-model-diversity", CLAUDE),
        ("transition to PAUSED", CLAUDE),
        ("same-host-perspective-pair", CODEX),
        ("same-host-parallel-fallback", CODEX),
        ("foreground Claude", CODEX),
    ],
    "verification-before-completion": [
        ("No completion claim may be made without fresh, acceptance-mapped evidence verified in the current work pass", BOTH),  # G1 canonical home invariant (HARD-GATE)
        ("confirm a separate-context independent `verifier` audit ran", BOTH),  # required maker-authored STANDARD/THOROUGH audit cannot fall back inline
        ("target role's required identity/result envelope", BOTH),
        ("Do not claim success without fresh evidence", BOTH),
        ("Acceptance-To-Evidence Mapping", BOTH),
        ("Risk Check Before Completion", BOTH),
        ("A success status is not acceptance", BOTH),  # the silent-success gate
        ("A previous run is not fresh evidence", BOTH),
        ("redact secrets", BOTH),  # the evidence-redaction rule
        ("trigger-loaded", BOTH),
        ("Missing review topology is a named ledger gap", BOTH),  # proportional review-topology HARD-GATE clause
        ("Assigned perspective", BOTH),
        ("model-diversity-pair", CLAUDE),
        ("identical except the single `Assigned perspective:` line", CLAUDE),
        ("serial dispatch-wait-dispatch", CLAUDE),
        ("primary leg is dispatched without a model override", CLAUDE),
        ("diversity leg uses an explicit NATIVE model override", CLAUDE),
        ("validated secondary top-tier model", CLAUDE),
        ("same-model-parallel-fallback", CLAUDE),
        ("require-model-diversity", CLAUDE),
        ("transition to PAUSED", CLAUDE),
        ("same-host-perspective-pair", CODEX),
        ("same-host-parallel-fallback", CODEX),
        ("foreground Claude call", CODEX),
    ],
    "fusion-rescue": [
        ("exactly three same-role `fusion-rescue-analyst` panels in parallel", CLAUDE),
        ("All three panel identities MUST be members of the block's resolved top-tier list", CLAUDE),
        ("explicit NATIVE model override", CLAUDE),
        ("declared-frontmatter primary", CLAUDE),
        ("otherwise it is the first NATIVE entry of the top-tier list", CLAUDE),
        ("assign exactly two panels the explicit NATIVE secondary override", CLAUDE),
        ("assign exactly one panel a distinct top-tier identity", CLAUDE),
        ("Degenerate configured case", CLAUDE),
        ("3 × panel-default (top-tier)", CLAUDE),
        ("require-model-diversity` transitions to PAUSED", CLAUDE),
        ("Unconfigured case", CLAUDE),
        ("Claude Code defines no opposite-host consult path for Fusion Rescue", CLAUDE),
        ("require-cross-host", CODEX),
        ("Claude consult", CODEX),
        ("current-host Codex panel agents in default mode", CODEX),
    ],
    # Claude-Code-only setup skill: checked on claude only (skipped on codex,
    # which ships no wrapper for it). Every phrase lives in the shared skill core
    # so it composes into the Claude wrapper regardless of the platform overlay.
    "configure-subagents": [
        ("human-invoke-only", CLAUDE),  # never model-invoked
        ("`explore`, `analyst`, `planner`, `plan-reviewer`, `executor`, `debugger`, `verifier`, `code-reviewer`, `fusion-rescue-analyst`", CLAUDE),  # exact 9-agent order
        ("GPT primary models are offered only after an explicit CLIProxyAPI", CLAUDE),  # proxy gate
        ("`fable`, `opus`, `sonnet`", CLAUDE),  # primary native model vocab
        ("native aliases `fable`, `opus`, `sonnet`, and `haiku`", CLAUDE),  # secondary native-only vocab
        ("`top_tier_models`", CLAUDE),
        ("`secondary_top_model`", CLAUDE),
        ("require the selection to be present in `top_tier_models`", CLAUDE),
        ("`max`, `xhigh`, `high`, `medium`", CLAUDE),  # effort vocab
        ("No file is written before that confirmation", CLAUDE),  # final-confirmation-before-write
        ("all 9 agents and the diversity settings change in one", CLAUDE),  # one transaction
        ("reapplies stored preferences best-effort", CLAUDE),  # SessionStart drift repair
        ("No proxy URL or token value is ever stored or printed", CLAUDE),  # credential safety
    ],
}


def find_plugin_root(start: Path) -> Path:
    """Accept either the plugin dir (has skills/) or a repo root."""
    if (start / "skills").is_dir() and (start / "docs").is_dir():
        return start
    nested = start / "plugins" / "oh-no-harness"
    if (nested / "skills").is_dir():
        return nested
    return start


def read(path: Path) -> str | None:
    """Return file text, or None if the path is missing."""
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return None


def source_skill_references(root: Path) -> dict[str, list[str]]:
    derived: dict[str, list[str]] = {}
    for skill, patterns in SOURCE_HANDOFF_PATTERNS.items():
        core_path = root / "docs" / "skill-core" / f"{skill}.md"
        text = read(core_path)
        if text is None:
            raise SystemExit(f"missing handoff source: {core_path}")
        targets = {
            match
            for pattern in patterns
            for match in re.findall(pattern, text, flags=re.IGNORECASE)
        }
        if targets:
            derived[skill] = sorted(targets)
    return derived


def assert_reference_graph_matches_source(root: Path) -> None:
    declared = {
        skill: sorted(set(targets))
        for skill, targets in SKILL_REFERENCES.items()
        if targets
    }
    derived = source_skill_references(root)
    if declared != derived:
        raise SystemExit(
            "SKILL_REFERENCES diverged from source handoff directives: "
            f"declared={declared!r} derived={derived!r}"
        )


def resolve(root: Path, platform: str, skill: str, depth: int = 2,
            seen: set[str] | None = None, missing: list[str] | None = None) -> str:
    """Wrapper body + referenced shared docs + explicit handoff sub-skills."""
    if seen is None:
        seen = set()
    if missing is None:
        missing = []
    if skill in seen or depth < 0:
        return ""
    seen.add(skill)
    wrapper = root / WRAPPER_DIR[platform] / skill / "SKILL.md"
    text = read(wrapper)
    if text is None:
        missing.append(str(wrapper))
        return ""
    parts = [text]
    for name in sorted(set(re.findall(r"docs/shared/([a-z0-9-]+)\.md", text))):
        shared = read(root / "docs" / "shared" / f"{name}.md")
        if shared is None:
            missing.append(f"docs/shared/{name}.md (referenced by {skill})")
        else:
            parts.append(shared)
    if depth > 0:
        for sub in SKILL_REFERENCES.get(skill, []):
            if sub not in seen:
                parts.append(resolve(root, platform, sub, depth - 1, seen, missing))
    return "\n".join(parts)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--platform", required=True, choices=["codex", "claude"])
    ap.add_argument("--plugin-root", default=".")
    args = ap.parse_args()
    root = find_plugin_root(Path(args.plugin_root))
    assert_reference_graph_matches_source(root)

    # Fail on a typo'd platform tag rather than silently skipping a check.
    for skill, reqs in REQUIRED.items():
        for phrase, platform in reqs:
            if platform not in VALID_PLATFORMS:
                print(f"FAIL - invalid platform tag {platform!r} for {skill}: {phrase!r}")
                return 1

    failures: list[str] = []
    warnings: list[str] = []
    checked = 0
    for skill, reqs in REQUIRED.items():
        # Claude-only skills have no Codex wrapper; skip them on the codex run so
        # a deliberately absent wrapper is not reported as unreachable.
        if skill in CLAUDE_ONLY_SKILLS and args.platform != CLAUDE:
            continue
        missing: list[str] = []
        bag = " ".join(resolve(root, args.platform, skill, missing=missing).lower().split())
        warnings.extend(missing)
        if not bag:
            failures.append(f"{skill}: composed wrapper not found under {WRAPPER_DIR[args.platform]}/")
            continue
        for phrase, platform in reqs:
            if platform not in (BOTH, args.platform):
                continue
            checked += 1
            normalized_phrase = " ".join(phrase.lower().split())
            if normalized_phrase not in bag:
                failures.append(f"{skill} [{args.platform}]: rule not reachable -> {phrase!r}")

    # Platform vocabulary is mutually exclusive. Check every generated wrapper,
    # not only REQUIRED entries, so a future skill cannot leak the other host's
    # strict-mode terms without being added to this table first.
    forbidden_terms = (
        ("model-diversity-pair", "require-model-diversity")
        if args.platform == CODEX
        else ("require-cross-host",)
    )
    wrapper_root = root / WRAPPER_DIR[args.platform]
    for wrapper in sorted(wrapper_root.glob("*/SKILL.md")):
        text = read(wrapper)
        if text is None:
            continue
        lowered = text.lower()
        for term in forbidden_terms:
            if term in lowered:
                failures.append(
                    f"{wrapper.parent.name} [{args.platform}]: forbidden platform term -> {term!r}"
                )

    for w in sorted(set(warnings)):
        print(f"WARN - missing referenced doc/wrapper: {w}", file=sys.stderr)

    if failures:
        print(f"FAIL - skill reachability ({args.platform}): {len(failures)} issue(s)")
        for f in failures:
            print(f"  - {f}")
        return 1
    print(f"ok - skill reachability ({args.platform}): "
          f"{checked} workflow rules reachable across {len(REQUIRED)} skills")
    return 0


if __name__ == "__main__":
    sys.exit(main())
