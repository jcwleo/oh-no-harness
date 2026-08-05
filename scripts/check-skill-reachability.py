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
Phrases that are genuinely platform-asymmetric (for example Codex spawn_agent,
Claude agent naming, or OpenCode subagent_type) are tagged for their platform.

The reference graph is explicit (not regex over every backticked skill name) so a
required cross-skill rule only counts as reachable through a real handoff edge —
an incidental skill mention cannot satisfy it, and removing a genuine handoff
fails the check.

Usage:
    python3 scripts/check-skill-reachability.py --platform codex  [--plugin-root .]
    python3 scripts/check-skill-reachability.py --platform claude [--plugin-root .]
    python3 scripts/check-skill-reachability.py --platform opencode [--plugin-root .]
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

WRAPPER_DIR = {
    "codex": "skills",
    "claude": "skills-claude",
    "opencode": "skills-opencode",
}

BOTH, CODEX_CLAUDE = "both", "codex-claude"
CODEX, CLAUDE, OPENCODE = "codex", "claude", "opencode"
VALID_PLATFORMS = {BOTH, CODEX_CLAUDE, CODEX, CLAUDE, OPENCODE}

ALL_RUNTIME_PLATFORMS = frozenset({CODEX, CLAUDE, OPENCODE})
WORKFLOW_SKILLS = (
    "interview",
    "ralplan",
    "ralph",
    "ultrawork",
    "auto-routing",
    "test-driven-development",
    "simplify",
    "verification-before-completion",
    "systematic-debugging",
    "fusion-rescue",
)
SKILL_AVAILABILITY = {skill: ALL_RUNTIME_PLATFORMS for skill in WORKFLOW_SKILLS}
SKILL_AVAILABILITY.update(
    {
        "install-statusline": frozenset({CLAUDE}),
        "configure-subagents": frozenset({CLAUDE, OPENCODE}),
    }
)

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
    "ralph": (r"\bTHOROUGH alone may load or invoke `([a-z0-9-]+)`, and only when actual candidates or candidate uncertainty remain\.",),
    "ultrawork": (r"\bread and follow `([a-z0-9-]+)`",),
}

# skill -> list of (canonical phrase, platform). platform=both unless the rule is
# genuinely platform-specific. Every phrase is re-verified reachable on each run,
# so drift fails loudly here instead of intermittently in a paid live test.
REQUIRED: dict[str, list[tuple[str, str]]] = {
    "auto-routing": [
        # Claude/Codex retain the shared persistence mechanism. OpenCode has an
        # always-present primary contract and deliberately implements no toggle.
        ("The bundled `scripts/oh-no-config` script resolves the data directory", CODEX_CLAUDE),
        ("\"<plugin-root>/scripts/oh-no-config\" on", CODEX_CLAUDE),
        ("\"<plugin-root>/scripts/oh-no-config\" off", CODEX_CLAUDE),
        ("OpenCode has no persistent Auto Routing toggle in this implementation", OPENCODE),
        ("there is no stored on/off state", OPENCODE),
        ("selected `oh-no` primary always carries its standing routing and orchestration contract", OPENCODE),
        ("For `on`, explain that it is a no-op", OPENCODE),
        ("For `off`, explain that it is a no-op", OPENCODE),
        ("Perform no write and do not claim changed state or require a restart", OPENCODE),
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
        ("Reference Ralph's canonical `LIGHT Eligibility — Risk Gate, Soft Size Screen`", BOTH),
        ("Risk-gated LIGHT has no hard size cap", BOTH),
        ("The canonical deterministic exclusion gate (`unknown = excluded`) guards this path", BOTH),
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
        ("trigger-loaded", CODEX_CLAUDE),
        ("exactly one final Planner revision v2", BOTH),
        ("finding→fix mapping", BOTH),
        # Plan length is a draft-contract rule, so its omission must fail a gate.
        ("calibrated to decision content, not to mode", BOTH),
        # 2026-07-29 artifact de-duplication: planning.md is snapshot + ledger,
        # and requirements/baseline/subagent material is pointed at, not copied.
        ("explore/analyst output\nare referenced by pointer", BOTH),
        ("Assigned perspective", BOTH),
        ("APPROVE freezes the exact reviewed Planner draft", BOTH),
        ("Blocking basis: <AC ID | safety invariant | Direction Contract field | applicable mandatory gate>", BOTH),
        ("Non-blocking findings", BOTH),
        ("optional follow-ups", BOTH),
        ("`Agent policy: inline-only` is valid", BOTH),
        ("executor ownership survives", BOTH),
        ("no concurrent batch, not inline mutation", BOTH),
        ("Plan-Reviewer: dispatch-unavailable", BOTH),
        ("work that qualifies under Ralph's canonical `LIGHT Eligibility —", BOTH),
        ("size may veto, never grant, LIGHT", BOTH),
        ("apply Ralph's complete canonical LIGHT predicate before defaulting to STANDARD", BOTH),
        # Platform-owned paired-review vocabulary. Claude proves the A1-amended
        # unoverridden-primary/native-secondary shape; Codex keeps cross-host.
        # CR-1 cross-host (M3.1): Claude pair mechanics are pair-only; the
        # ordinary single-reviewer path uses one stored primary, no diversity leg.
        ("This section applies ONLY when the core selected `perspective-pair` after a", CLAUDE),
        ("with NO diversity leg, NO model override, and no", CLAUDE),
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
        # CR-1: Codex adapters must state the single-reviewer default and that
        # pair mechanics apply only when the named trigger fired.
        ("recorded as single-reviewer; this is intentional single review", CODEX),
        ("Pair-specific mechanics apply ONLY when that named paired-review trigger", CODEX),
        ("same-host-perspective-pair", CODEX),
        ("same-host-parallel-fallback", CODEX),
        ("foreground Claude call", CODEX),
        ("Dispatch only after the active skill's trigger fires", CODEX),
        ("not to the plan body", BOTH),
        ("recorded as `single-reviewer`", BOTH),
        ("paired topology valid", CODEX_CLAUDE),
        ("with no further review", BOTH),
        ("same-model-perspective-pair", OPENCODE),
    ],
    "ralph": [
        ("Ralph's main agent is the orchestrator", BOTH),
        # 2026-07-29 artifact de-duplication: canonical ownership must stay
        # pinned, or artifacts silently re-derive the plan and this skill again.
        ("restating them as prose. `verification.md` owns AC-to-evidence, RED/GREEN,\ntest necessity, and the baseline gate table; the plan's test-design decisions\nare referenced by AC ID", BOTH),
        ("record the finding and its evidence pointer. Artifact\nlength is calibrated to resume and audit need, not to mode", BOTH),
        ("The session file set is closed to the files named above", BOTH),
        ("executor roles own default repository work-product mutation", BOTH),
        ("inline mutation is only a recorded LIGHT-tiny or dispatch-unavailable fallback", BOTH),
        ("Execution Mode Decision Prompt", BOTH),
        ("product-like simulator, oracle, or fixture factory", BOTH),
        ("needs separate user approval for that scope", BOTH),
        ("LIGHT | STANDARD | THOROUGH", BOTH),
        ("### LIGHT Eligibility — Risk Gate, Soft Size Screen", BOTH),
        ("LIGHT is the low-risk localized behavior change tier", BOTH),
        ("The hard exclusion UNION mirrors the surfaces protected by THOROUGH", BOTH),
        ("soft screen that can only route OUT of LIGHT, never grant it", BOTH),
        ("`D ? direct-edit : T ? THOROUGH : L ? LIGHT : STANDARD`", BOTH),
        ("an exclusion becoming present-or-unknown", BOTH),
        ("the edit set growing past a cohesive localized scope", BOTH),
        ("Mode-Gated Agent Dispatch", BOTH),
        ("One need test governs every non-review role in every mode", BOTH),
        ("Mode never decides the need test by itself", BOTH),
        ("Inline mutation changes WHO edits, never WHAT the edit owes", BOTH),
        ("Leaving the Mutation", BOTH),
        ("Review independence is the one exemption from the need test", BOTH),
        ("every repository work-product mutation shows dispatched-executor evidence", BOTH),
        ("Parallel trigger", BOTH),
        (".oh-no/worktrees/<task-slug>", BOTH),
        ("parent workspace directory", BOTH),
        ("Ralph invokes TDD internally when behavior-changing edits require it", BOTH),
        ("Required Behavior Lock", BOTH),  # reachable via the simplify handoff edge
        ("LIGHT/STANDARD run a caller-owned quick diff scan; never load, invoke, or dispatch `simplify`, even when actual candidates or candidate uncertainty remain.", BOTH),
        ("Record `simplify`: not-required (mode: LIGHT|STANDARD).", BOTH),
        ("THOROUGH alone may load or invoke `simplify`, and only when actual candidates or candidate uncertainty remain.", BOTH),
        ("four independent viewpoints only for a named safety or broad-diff trigger.", BOTH),
        ("When called by `ralph`, Simplify may be loaded or invoked only for eligible THOROUGH cleanup after Ralph's quick diff scan finds actual candidates or candidate uncertainty remains.", BOTH),
        ("Direct Simplify use remains independently selected by its own behavior lock and Cleanup Depth Decision.", BOTH),
        ("Only after the core selects eligible THOROUGH cleanup with actual candidates or candidate uncertainty may Codex load the `simplify` skill through the generated Codex Simplify runtime document.", CODEX),
        ("Only after the core selects eligible THOROUGH cleanup with actual candidates or candidate uncertainty may Claude Code load the host built-in `simplify` skill as the cleanup contract.", CLAUDE),
        # 2026-07-29: one canonical named-trigger predicate replaced the
        # mode/same-maker mandatory verifier, and STANDARD/ordinary THOROUGH
        # review with ONE full-role code-reviewer.
        ("### Independent Verifier Trigger Predicate", BOTH),
        ("This predicate is the ONLY authority that selects the independent `verifier`", BOTH),
        ("Explicit NON-TRIGGERS", BOTH),
        ("Independent verifier: not-required (no trigger fired: <reason>)", BOTH),
        ("ONE full-role `code-reviewer` for behavior-affecting or workflow", BOTH),
        ("Reviewer count is never a quality proxy", BOTH),
        ("code review is waived", BOTH),
        ("E8's `exactly one review round` MUST apply whenever a code-review stage runs at\nall, under `single-reviewer` and `perspective-pair` alike", BOTH),
        ("no fix-manifest step", BOTH),
        ("Delta fields are role-scoped", BOTH),
        ("post-cleanup review inspection", BOTH),
        ("CLEANUP/RECHECK to its verifier decision under", BOTH),
        ("The COMPLETION_AUDIT is EVIDENCE-ONLY", BOTH),
        ("Imminent completion is NOT a trigger", BOTH),
        ("Review Gate dependency graph", BOTH),  # verifier must not start before code-reviewer pair is synthesized
        ("verifier started after reviewer completion", BOTH),  # sequence ledger field, not just pass presence
        ("A verifier spawned before that point is stale", BOTH),  # early verifier cannot count
        ("trigger-loaded", CODEX_CLAUDE),
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
        ("main caller owns each complete child packet", BOTH),
        ("Ralph-specific assignment delta", BOTH),
        ("Reviewer packets are blind to maker conclusions", BOTH),
        ("verifier first records its evidence design", BOTH),
        ("audit obligations, not proof", BOTH),
        ("one bounded task and the minimal inseparable AC-ID set", BOTH),
        ("Mutation Manifest and Expansion Gate", BOTH),
        ("Expansion request", BOTH),
        ("Verification Contract and Test Necessity Gate", BOTH),
        ("why existing evidence is insufficient", BOTH),
        ("numeric size, ratio, dispatch, and test counts are anomaly signals", BOTH),
        ("Executor Assignment Completion Stop", BOTH),
        ("final run Completion Stop", BOTH),
        ("Any later mutation invalidates this final stop", BOTH),
        ("complete manifest fingerprint", BOTH),
        ("semantic RED/GREEN", BOTH),
        ("generated causality", BOTH),
        ("A frozen `none` remains `none`", BOTH),
        ("`dispatch-unavailable` is a blocker", BOTH),
        ("Assigned perspective", BOTH),
        # CR-1 cross-host (M3.1): Claude pair mechanics are pair-only; the
        # ordinary single-reviewer path uses one stored primary, no diversity leg.
        ("This section applies ONLY when the core selected `perspective-pair` after a", CLAUDE),
        ("with NO diversity leg, NO model override, and no", CLAUDE),
        ("model-diversity-pair", CLAUDE),
        ("identical except the single `Assigned perspective:` line", CLAUDE),
        ("serial dispatch-wait-dispatch", CLAUDE),
        ("primary leg is dispatched without a model override", CLAUDE),
        ("diversity leg uses an explicit NATIVE model override", CLAUDE),
        ("validated secondary top-tier model", CLAUDE),
        ("same-model-parallel-fallback", CLAUDE),
        ("require-model-diversity", CLAUDE),
        ("transition to PAUSED", CLAUDE),
        # CR-1: same single-reviewer default / triggered-pair rule on the Ralph adapter.
        ("ONE full-role code-reviewer on Codex when review is required", CODEX),
        ("Pair-specific mechanics apply ONLY when that named pair trigger actually fired", CODEX),
        ("same-host-perspective-pair", CODEX),
        ("same-host-parallel-fallback", CODEX),
        ("foreground Claude call", CODEX),
        ("same-model-perspective-pair", OPENCODE),
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
        # 2026-07-29: same authorship is now an explicit NON-trigger; Ultrawork
        # defers to VBC's named V4 predicate and defaults to one full reviewer.
        ("are explicit NON-triggers", BOTH),
        ("Independent verifier: not-required (no trigger fired: <reason>)", BOTH),
        ("ONE full-role `code-reviewer` by default and records\n`single-reviewer`", BOTH),
        ("Reviewer count is never a quality proxy", BOTH),
        ("Final Validation dependency graph", BOTH),  # verifier must not start before code-reviewer pair is synthesized
        ("verifier started after reviewer completion", BOTH),  # sequence ledger field, not just pass presence
        ("A verifier spawned before that point is stale", BOTH),  # early verifier cannot count
        ("ran after the selected Final Validation code-review stage completed", BOTH),  # Ralph verifier reuse is order-bound, not order-free
        ("otherwise dispatch one fresh self-host `verifier` pass", BOTH),  # reuse and fresh dispatch are mutually exclusive, not sequential commands
        ("Ralph's prior verifier is early/stale by construction, so reuse is unavailable", BOTH),  # a self-dispatched reviewer voids reuse
        ("verifier source: fresh | reused@<ralph ledger entry + revision binding>", BOTH),  # reuse must name its Ralph ledger entry + revision binding
        ("trigger-loaded", CODEX_CLAUDE),
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
        # V-1/V-2 (failed-verification correction): Codex Ultrawork implements only
        # the core-selected topology; ordinary Final Validation is single-reviewer.
        ("implements only the topology the core already selected", CODEX),
        ("dispatches exactly ONE full-role", CODEX),
        ("ralplan's risk-selected topology", BOTH),
        ("same-host-perspective-pair", CODEX),
        ("same-host-parallel-fallback", CODEX),
        ("foreground Claude call", CODEX),
        ("same-model-perspective-pair", OPENCODE),
    ],
    "test-driven-development": [
        ("Execution Ownership", BOTH),
        ("one stable `Executor assignment ID`", BOTH),
        ("RED, GREEN, and REFACTOR", BOTH),
        ("each Packet ID remains unique", BOTH),
        ("caller remains the orchestrator", BOTH),
    ],
    "simplify": [
        # CR-1 cross-host (M3.2): simplify composes the SHARED Claude runtime doc,
        # so it proves the shared pair mechanism stays dispatch-only there too.
        ("governs only how an ALREADY-SELECTED pair is dispatched", CLAUDE),
        ("never to every dispatched review", CLAUDE),
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
        # The post-fix verifier is selected by the same named-trigger predicate as
        # Ralph/VBC; same authorship is an explicit NON-trigger, not a requirement.
        ("This predicate is the ONLY authority that selects the post-fix `verifier`", BOTH),
        ("Explicit NON-TRIGGERS", BOTH),
        ("authored or\naccepted by the same agent", BOTH),
        ("Independent verifier: not-required (no trigger fired: <reason>)", BOTH),
        # Post-fix review is single by default; only a named trigger buys the pair.
        ("ONE full-role instance by default, escalating to a perspective-diverse pair only on the named high-risk trigger", BOTH),
        ("Reviewer count is never\na quality proxy", BOTH),
        ("records `single-reviewer` by default, or `perspective-pair` plus", BOTH),
        ("trigger-loaded", BOTH),
        ("Missing review topology is a named ledger gap", BOTH),  # proportional review-topology HARD-GATE clause
        ("do not directly dispatch\n    `plan-reviewer`", BOTH),
        ("executor-default minimal fix", BOTH),
        ("initial packet is symptom-first", BOTH),
        ("without a preferred cause or fix", BOTH),
        ("neutral exact action, state, and raw outcome", BOTH),
        ("Dispatch the complete eligible batch before waiting for any result", BOTH),
        ("Each initial fan-out packet names exactly one assigned hypothesis and its confirming/refuting evidence targets", BOTH),
        ("Every other hypothesis and the rest of the hypothesis ledger are withheld", BOTH),
        ("A debugger MUST NOT receive multiple eligible hypotheses", BOTH),
        ("at most 3 by default, extending toward 5 only when 3+ genuinely independent hypotheses are testable", BOTH),
        ("Keep investigation sequential for one hypothesis, dependent hypotheses, overlapping scopes, or state-mutating diagnostics", BOTH),
        ("Only when hypothesis fan-out is not active may a named THOROUGH trigger use two same-role", BOTH),
        ("hypothesis-fanout:<count>", BOTH),
        ("STANDARD dispatches one `debugger` per independently testable eligible hypothesis in the complete batch", CODEX),
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
        ("OpenCode has no per-task model override", OPENCODE),
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
        ("trigger-loaded", CODEX_CLAUDE),
        ("Missing review topology is a named ledger gap", BOTH),  # proportional review-topology HARD-GATE clause
        ("Assigned perspective", BOTH),
        # CR-1 cross-host (M3.1): Claude pair mechanics are pair-only; the
        # ordinary single-reviewer path uses one stored primary, no diversity leg.
        ("This section applies ONLY when the core selected `perspective-pair` after a", CLAUDE),
        ("with NO diversity leg, NO model override, and no", CLAUDE),
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
        ("same-model-perspective-pair", OPENCODE),
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
        ("same-model-parallel-fallback", OPENCODE),
        ("No opposite-host consult is defined", OPENCODE),
    ],
    # Configure Subagents is available on Claude and OpenCode, with independent
    # host-specific source contracts; Codex deliberately ships no wrapper.
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
        ("current user request explicitly", OPENCODE),
        ("Call `oh_no_get_model_catalog` exactly once", OPENCODE),
        ("one exact model and one exact variant", OPENCODE),
        ("`Cancel` stops with no", OPENCODE),
        ("call `oh_no_configure_subagents` exactly once", OPENCODE),
        ("Do not use Bash, a subprocess, `opencode models`", OPENCODE),
        ("quit and restart OpenCode", OPENCODE),
    ],
}

# Skill-specific stale clauses that would contradict reachable canonical rules.
FORBIDDEN: dict[str, list[tuple[str, str]]] = {
    "ralph": [
        ("invoke `simplify` (one combined scan) only when actual candidates or candidate uncertainty remain;", BOTH),
        ("When Ralph reaches the CLEANUP checkpoint on Codex, use the Oh No Harness\n`simplify` skill", CODEX),
        ("When Ralph reaches the CLEANUP checkpoint on Claude Code, use the host\nbuilt-in `simplify` skill", CLAUDE),
    ],
    "auto-routing": [
        ("OpenCode persists an Auto Routing toggle", OPENCODE),
        ("OpenCode persists the Auto Routing toggle", OPENCODE),
        ("OpenCode writes an Auto Routing preference", OPENCODE),
        ("OpenCode Auto Routing changes require a restart", OPENCODE),
        ("restart OpenCode to activate Auto Routing", OPENCODE),
    ],
    "systematic-debugging": [
        ("STANDARD keeps one dispatched `debugger` instance", CODEX),
        ("`single-reviewer` for a STANDARD debugger", CODEX),
        # M4 item 1: the retired same-maker verifier trigger and the retired
        # post-fix pair-by-default topology must not become reachable again.
        ("required when the proving tests or fix were authored or accepted by the same agent", BOTH),
        ("when dispatched, runs as the perspective-diverse pair", BOTH),
        ("always runs as the\nperspective-diverse pair", BOTH),
        ("Every dispatched post-fix `code-reviewer` review\ninstead runs as an intentional same-host perspective pair", CODEX),
        ("(every dispatched review)", CLAUDE),
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


def applies_to(platform_tag: str, platform: str) -> bool:
    return (
        platform_tag == BOTH
        or platform_tag == platform
        or (platform_tag == CODEX_CLAUDE and platform in {CODEX, CLAUDE})
    )


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
    ap.add_argument(
        "--platform", required=True, choices=["codex", "claude", "opencode"]
    )
    ap.add_argument("--plugin-root", default=".")
    args = ap.parse_args()
    root = find_plugin_root(Path(args.plugin_root))
    assert_reference_graph_matches_source(root)

    # Fail on a typo'd platform tag rather than silently skipping a check.
    for rules in (REQUIRED, FORBIDDEN):
        for skill, reqs in rules.items():
            for phrase, platform in reqs:
                if platform not in VALID_PLATFORMS:
                    print(f"FAIL - invalid platform tag {platform!r} for {skill}: {phrase!r}")
                    return 1

    failures: list[str] = []
    warnings: list[str] = []
    checked = 0
    for skill, reqs in REQUIRED.items():
        if args.platform not in SKILL_AVAILABILITY[skill]:
            continue
        missing: list[str] = []
        bag = " ".join(resolve(root, args.platform, skill, missing=missing).lower().split())
        warnings.extend(missing)
        if not bag:
            failures.append(f"{skill}: composed wrapper not found under {WRAPPER_DIR[args.platform]}/")
            continue
        for phrase, platform in reqs:
            if not applies_to(platform, args.platform):
                continue
            checked += 1
            normalized_phrase = " ".join(phrase.lower().split())
            if normalized_phrase not in bag:
                failures.append(f"{skill} [{args.platform}]: rule not reachable -> {phrase!r}")
        for phrase, platform in FORBIDDEN.get(skill, []):
            if not applies_to(platform, args.platform):
                continue
            checked += 1
            normalized_phrase = " ".join(phrase.lower().split())
            if normalized_phrase in bag:
                failures.append(f"{skill} [{args.platform}]: stale conflicting rule reachable -> {phrase!r}")

    # Platform vocabulary is mutually exclusive. Check every generated wrapper,
    # not only REQUIRED entries, so a future skill cannot leak the other host's
    # strict-mode terms without being added to this table first.
    if args.platform == CODEX:
        required_terms: tuple[str, ...] = ()
        forbidden_terms = ("model-diversity-pair", "require-model-diversity")
    elif args.platform == CLAUDE:
        required_terms = ()
        forbidden_terms = ("require-cross-host",)
    elif args.platform == OPENCODE:
        required_terms = ("subagent_type: oh-no-",)
        forbidden_terms = (
            "spawn_agent(",
            "wait_agent",
            "close_agent",
            "claude_plugin_root",
            "workflow `agent()`",
            "@agent-",
            "task(",
            "require-cross-host",
            "model-diversity-pair",
        )
    else:
        raise SystemExit(f"unsupported platform vocabulary branch: {args.platform}")
    wrapper_root = root / WRAPPER_DIR[args.platform]
    for wrapper in sorted(wrapper_root.glob("*/SKILL.md")):
        text = read(wrapper)
        if text is None:
            continue
        lowered = text.lower()
        skill = wrapper.parent.name
        wrapper_required_terms = required_terms
        if args.platform == OPENCODE and skill == "configure-subagents":
            wrapper_required_terms = (
                "current user request explicitly",
                "oh_no_get_model_catalog",
                "oh_no_configure_subagents",
                "do not use bash",
            )
        for term in wrapper_required_terms:
            if term not in lowered:
                failures.append(
                    f"{skill} [{args.platform}]: required platform term not reachable -> {term!r}"
                )
        for term in forbidden_terms:
            if term in lowered:
                failures.append(
                    f"{skill} [{args.platform}]: forbidden platform term -> {term!r}"
                )

        if args.platform == OPENCODE and skill == "auto-routing":
            contradictory_claims = (
                r"\bopencode\s+(?:auto routing\s+)?(?:persists?|stores?|writes?)\b.{0,100}\b(?:toggle|preference|state)\b",
                r"\bopencode\s+auto routing\b.{0,100}\b(?:requires?|needs?)\b.{0,40}\brestart\b",
                r"\brestart opencode\b.{0,60}\b(?:activate|apply|enable)\b.{0,60}\b(?:auto routing|routing (?:toggle|change|preference))\b",
            )
            for pattern in contradictory_claims:
                if re.search(pattern, lowered, flags=re.DOTALL):
                    failures.append(
                        f"{skill} [{args.platform}]: forbidden persisted-toggle/restart claim -> {pattern!r}"
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
