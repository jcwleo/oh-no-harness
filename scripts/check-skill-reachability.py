#!/usr/bin/env python3
"""Deterministic deep-smoke: verify each skill's load-bearing workflow rules are
REACHABLE from its composed runtime wrapper plus the docs/shared files and
sub-skills it references.

This replaces the flaky live-model phrase-grep deep-smoke for GATING purposes:
the live test sampled one stochastic model answer and asserted exact substrings,
so a faithful model that paraphrased (or did not dereference a 2-hop link) failed
non-deterministically. What we actually want to gate on is "does the skill, as
composed, make the rule reachable" — a static, deterministic property.

For each skill we build a resolved text bag = the platform wrapper body + every
`docs/shared/<name>.md` it references + the same-platform wrapper of every public
skill it backtick-references (bounded depth, cycle-guarded), then assert each
required canonical rule phrase appears in that bag. Phrases that are genuinely
platform-asymmetric (e.g. Codex spawn_agent vs Claude agent naming) are tagged so
they are only required on their platform.

Usage:
    python3 scripts/check-skill-reachability.py --platform codex  [--plugin-root .]
    python3 scripts/check-skill-reachability.py --platform claude [--plugin-root .]
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

PUBLIC_SKILLS = [
    "interview", "ralplan", "ralph", "ultrawork", "simplify",
    "systematic-debugging", "verification-before-completion",
    "test-driven-development", "fusion-rescue", "using-oh-no-harness",
    "auto-routing",
]

WRAPPER_DIR = {"codex": "skills", "claude": "skills-claude"}

BOTH, CODEX, CLAUDE = "both", "codex", "claude"

# skill -> list of (canonical phrase, platform). platform=both unless the rule is
# genuinely platform-specific. Every phrase was rg-verified reachable on its
# platform(s); the checker re-verifies on each run, so drift fails loudly here
# instead of intermittently in a live test.
REQUIRED: dict[str, list[tuple[str, str]]] = {
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
        ("Re-reviews run only when the previous", BOTH),
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
        ("Required Behavior Lock", BOTH),  # reachable via the `simplify` reference
    ],
    "ultrawork": [
        (".oh-no/specs/", BOTH),
        (".oh-no/specs/interview-", BOTH),  # via the `interview` reference
        ("at most 2 loops", BOTH),  # via the `ralplan` reference
        (".oh-no/worktrees/<task-slug>", BOTH),
        ("git worktree add", BOTH),
        ("Worktree decision: ultrawork automatic worktree", BOTH),
        ("ultrawork automatic approval", BOTH),
        ("Read and follow `ralplan`", BOTH),
        ("Read and follow `ralph`", BOTH),
        ("Ultrawork-approved", BOTH),
        ("execution mode and mode source", BOTH),
        ("## Cleanup And Final Verification", BOTH),  # via the `ralph` reference
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
}


def find_plugin_root(start: Path) -> Path:
    """Accept either the plugin dir (has skills/) or a repo root."""
    if (start / "skills").is_dir() and (start / "docs").is_dir():
        return start
    nested = start / "plugins" / "oh-no-harness"
    if (nested / "skills").is_dir():
        return nested
    return start


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return ""


def resolve(root: Path, platform: str, skill: str, depth: int = 2,
            seen: set[str] | None = None) -> str:
    """Wrapper body + referenced shared docs + backtick-referenced sub-skills."""
    if seen is None:
        seen = set()
    if skill in seen or depth < 0:
        return ""
    seen.add(skill)
    text = read(root / WRAPPER_DIR[platform] / skill / "SKILL.md")
    parts = [text]
    for name in sorted(set(re.findall(r"docs/shared/([a-z0-9-]+)\.md", text))):
        parts.append(read(root / "docs" / "shared" / f"{name}.md"))
    if depth > 0:
        for sub in PUBLIC_SKILLS:
            if sub == skill or sub in seen:
                continue
            if re.search(r"`" + re.escape(sub) + r"`", text):
                parts.append(resolve(root, platform, sub, depth - 1, seen))
    return "\n".join(parts)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--platform", required=True, choices=["codex", "claude"])
    ap.add_argument("--plugin-root", default=".")
    args = ap.parse_args()
    root = find_plugin_root(Path(args.plugin_root))

    failures: list[str] = []
    checked = 0
    for skill, reqs in REQUIRED.items():
        bag = resolve(root, args.platform, skill).lower()
        if not bag.strip():
            failures.append(f"{skill}: composed wrapper not found under {WRAPPER_DIR[args.platform]}/")
            continue
        for phrase, platform in reqs:
            if platform not in (BOTH, args.platform):
                continue
            checked += 1
            if phrase.lower() not in bag:
                failures.append(f"{skill} [{args.platform}]: rule not reachable -> {phrase!r}")

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
