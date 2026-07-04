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

# Explicit handoff edges that a required cross-skill phrase is reached through.
# Only these edges are followed when resolving a skill's reachable text, so an
# incidental backtick mention cannot satisfy a required rule and dropping a real
# handoff fails the check.
SKILL_REFERENCES: dict[str, list[str]] = {
    "ralph": ["simplify"],                       # 'Required Behavior Lock'
    "ultrawork": ["interview", "ralplan", "ralph"],  # spec path / 2 loops / cleanup heading
}

# skill -> list of (canonical phrase, platform). platform=both unless the rule is
# genuinely platform-specific. Every phrase is re-verified reachable on each run,
# so drift fails loudly here instead of intermittently in a paid live test.
REQUIRED: dict[str, list[tuple[str, str]]] = {
    "auto-routing": [
        # Shared codexExecutor toggle facts from the skill core (both platforms).
        ("executor role's implementation work to Codex", BOTH),
        ("Default OFF.", BOTH),
        ("they run one at a time, not in parallel", BOTH),  # serial-forced fact
        ("escape-DETECTION net", BOTH),
        ("not a sandbox guarantee", BOTH),  # honest best-effort, not-a-guarantee framing
        ("oh-no-config codex-executor on|off|status", BOTH),  # command token
        # Claude-Code-only overlay: the delegation block is injected via
        # SessionStart and dispatches executor-codex. Tagged CLAUDE so it is NOT
        # required on Codex (Codex has no such SessionStart block).
        ("injected via `SessionStart` on Claude Code only", CLAUDE),
        ("dispatches `oh-no-harness:executor-codex` in place of", CLAUDE),
        # Codex overlay: no Codex SessionStart block; delegated role stays native.
        ("adds NO Codex SessionStart block", CODEX),
        ("executor role behaves as the native `oh-no-executor`", CODEX),
    ],
    "interview": [
        ("consider advisory context", BOTH),
        ("## Question Routing", BOTH),
        ("## Answer Capture", BOTH),
        ("## Spec Closure Gate", BOTH),
        ("acceptance criteria are testable enough for", BOTH),
        ("Restate the agreed goal in one sentence", BOTH),
        ("Machine-consumable requirements for Standard and Deep", BOTH),
        ("Skill chaining in Oh No Harness is approval-gated, not automatic", BOTH),
        ("Read `docs/shared/execution-modes.md` before writing the final spec", BOTH),
    ],
    "ralplan": [
        ("Stop after at most 2 loops", BOTH),
        ("pending approval", BOTH),
        ("Overall Ralph mode", BOTH),
        ("Task sizing", BOTH),
        ("Execution profile", BOTH),
        ("Analyst -> Planner -> Plan-Reviewer", BOTH),
        ("must-fail-before-implementation case", BOTH),
        ("must-pass-after-implementation case", BOTH),
        ("negative or forbidden-behavior case", BOTH),
        ("old broken behavior", BOTH),
        (".oh-no/worktrees/<task-slug>", BOTH),
        ("Parent inline opposite-host consult is not a valid cross-host\nreview response", BOTH),
        ("Re-reviews run only when the previous", BOTH),
        ("authored or accepted by the same agent", BOTH),  # verifier independence carve-out (ralph-subagent-policy.md, path-referenced)
        ("Codex role dispatch is host-policy controlled", CODEX),
    ],
    "ralph": [
        ("Execution Mode Decision Prompt", BOTH),
        ("LIGHT | STANDARD | THOROUGH", BOTH),
        ("Mode-Gated Agent Dispatch", BOTH),
        ("Parallel trigger", BOTH),
        (".oh-no/worktrees/<task-slug>", BOTH),
        ("parent-directory siblings", BOTH),
        ("Ralph invokes TDD internally when behavior-changing edits require it", BOTH),
        ("Required Behavior Lock", BOTH),  # reachable via the simplify handoff edge
        ("authored or accepted by the same agent", BOTH),  # verifier independence carve-out (ralph.md body + ralph-subagent-policy.md)
        ("the implementing or accepting agent is not sufficient", BOTH),  # STANDARD/THOROUGH verifier-required rule (verification-tiers.md, path-referenced)
        ("cross-host/parallel pair at THOROUGH", BOTH),  # Edit 8 THOROUGH verifier-pair branch (guards multi-surface drift)
        ("Review Gate dependency graph", BOTH),  # verifier must not start before code-reviewer pair is synthesized
        ("verifier started after reviewer completion", BOTH),  # sequence ledger field, not just pass presence
        ("A verifier spawned before that point is stale", BOTH),  # early verifier cannot count
        ("Parent inline opposite-host consult is not a valid cross-host\nreview response", BOTH),
        ("A parent inline Claude\nconsult is not a valid shared cross-host review pass", CODEX),
        ("A direct Codex parent answer is not a\nvalid opposite-host shared review response", CLAUDE),
        ("Read and follow `verification-before-completion` before any completion claim", BOTH),  # G1 thin VBC reference (ralph.md:274)
        ("The run is invalid if the PRD or progress ledger does not show each required completion criterion below satisfied", BOTH),  # ralph Persistence Rule ledger-invalidation chokepoint
        ("the required reviewer pass, the independent verifier pass, simplify, and verification-before-completion", BOTH),  # presence: 4 completion steps named individually so a skip is a named ledger gap
        ("no recorded independence mode is a named ledger gap", BOTH),  # Layer-2 independence-mode HARD-GATE clause (Persistence Rule)
    ],
    "ultrawork": [
        (".oh-no/specs/", BOTH),
        (".oh-no/specs/interview-", BOTH),  # via the interview handoff edge
        ("at most 2 loops", BOTH),  # via the ralplan handoff edge
        (".oh-no/worktrees/<task-slug>", BOTH),
        ("git worktree add", BOTH),
        ("Worktree decision: ultrawork automatic worktree", BOTH),
        ("ultrawork automatic approval", BOTH),
        ("Read and follow `ralplan`", BOTH),
        ("Read and follow `ralph`", BOTH),
        ("Ultrawork-approved", BOTH),
        ("execution mode and mode source", BOTH),
        ("## Cleanup And Final Verification", BOTH),  # via the ralph handoff edge
        ("authored or accepted by the same agent", BOTH),  # verifier independence carve-out (ultrawork.md body + ralph-subagent-policy.md)
        ("cross-host/parallel pair at THOROUGH", BOTH),  # Edit 8 THOROUGH verifier-pair branch (guards multi-surface drift)
        ("Final Validation dependency graph", BOTH),  # verifier must not start before code-reviewer pair is synthesized
        ("verifier started after reviewer completion", BOTH),  # sequence ledger field, not just pass presence
        ("A verifier spawned before that point is stale", BOTH),  # early verifier cannot count
        ("Parent inline opposite-host consult is not a valid cross-host\nreview response", BOTH),
        ("A parent inline Claude\nconsult is not a valid shared cross-host review pass", CODEX),
        ("A direct Codex parent answer is not a\nvalid opposite-host shared review response", CLAUDE),
        ("Run `verification-before-completion` before any completion claim or final report", BOTH),  # G1 thin VBC reference (ultrawork Phase 5)
        ("The run is invalid if the session ledger does not show each required phase gate satisfied", BOTH),  # ultrawork Phase 5 ledger-invalidation chokepoint
        ("reviewer pass, independent verifier pass, simplify/cleanup, and VBC", BOTH),  # presence: 4 completion steps named individually so a skip is a named ledger gap
        ("worktree_gate: no source file edit until a", BOTH),  # ultrawork worktree_gate (G2 reference, carries worktree-isolation path token)
        ("requirements_gate: planning must not start until the requirements source is recorded", BOTH),  # ultrawork requirements_gate
        ("no recorded independence mode is a named ledger gap", BOTH),  # Layer-2 independence-mode HARD-GATE clause (Phase 5 Report gate)
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
        ("Start them in one batch", BOTH),
        ("before waiting for any result", BOTH),
        ("run the four passes inline", BOTH),
        ("fallback reason", BOTH),
        ("false positive", BOTH),
        ("intended behavior", BOTH),
        ("Maintainability Debt Boundary", BOTH),
    ],
    "systematic-debugging": [
        ("Find the root cause before changing behavior", BOTH),
        ("hypothesis ledger", BOTH),
        ("causal toggle", BOTH),  # the falsifiable root-cause confirmation gate
        ("the failure mode is gone", BOTH),
        ("verification-before-completion", BOTH),
        ("authored or accepted by the same agent", BOTH),  # verifier independence carve-out (ralph-subagent-policy.md, path-referenced)
        ("Parent inline opposite-host consult is not a valid cross-host\nreview response", BOTH),
        ("no recorded independence mode is a named ledger gap", BOTH),  # Layer-2 independence-mode HARD-GATE clause (Output Gate)
    ],
    "verification-before-completion": [
        ("No completion claim may be made without fresh, acceptance-mapped evidence verified in the current work pass", BOTH),  # G1 canonical home invariant (HARD-GATE)
        ("confirm an independent `verifier` audit ran per the carve-out", BOTH),  # standalone-VBC check-for: maker-authored STANDARD/THOROUGH must confirm the independent verifier ran (not a substitute)
        ("Do not claim success without fresh evidence", BOTH),
        ("Acceptance-To-Evidence Mapping", BOTH),
        ("Risk Check Before Completion", BOTH),
        ("A success status is not acceptance", BOTH),  # the silent-success gate
        ("A previous run is not fresh evidence", BOTH),
        ("redact secrets", BOTH),  # the evidence-redaction rule
        ("Parent inline opposite-host consult is not a valid cross-host\nreview response", BOTH),
        ("no recorded independence mode is a named ledger gap", BOTH),  # Layer-2 independence-mode HARD-GATE clause (Required Gate step 9)
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
        missing: list[str] = []
        bag = resolve(root, args.platform, skill, missing=missing).lower()
        warnings.extend(missing)
        if not bag.strip():
            failures.append(f"{skill}: composed wrapper not found under {WRAPPER_DIR[args.platform]}/")
            continue
        for phrase, platform in reqs:
            if platform not in (BOTH, args.platform):
                continue
            checked += 1
            if phrase.lower() not in bag:
                failures.append(f"{skill} [{args.platform}]: rule not reachable -> {phrase!r}")

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
