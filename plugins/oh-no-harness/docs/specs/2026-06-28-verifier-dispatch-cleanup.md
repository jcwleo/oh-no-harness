# Verifier Role Dispatch Cleanup

> Status: PROPOSAL — handoff for a follow-up Claude Code session to implement.
> Author context: drafted 2026-06-28 from a live ultrawork run where the
> independent `verifier` pass was folded inline until the user flagged it.
> Scope: documentation/policy edits to Oh No Harness skill-core + shared docs.
> NOT a code change to any downstream project.

## TL;DR

The `verifier` role is allowed to be folded inline by the same agent that wrote
or accepted the implementation, even when the implementation's proving tests
were authored by the executor (maker). This defeats the verifier's core value —
independence. The fix is **not** to split the role, but to (1) name the
verifier's two operating modes, (2) make the independence-dependent mode
non-inline-eligible when the maker authored the artifacts, and (3) promote the
verifier from "Recommended" to conditionally **Required** at STANDARD/THOROUGH.

## Motivating incident

During an `ultrawork` run (interview → ralplan → ralph execute → QA → final
validation), the orchestrator:

- dispatched `executor` (which implemented the feature **and wrote its own
  tests**),
- dispatched `code-reviewer`,
- but performed the `verifier` work **inline**: it re-ran `tsc`/`jest`/the full
  suite directly and treated green as sufficient.

Re-running the commands inline was fine (identical evidence). But the
acceptance-to-evidence mapping and the adversarial "do these maker-written tests
actually prove the ACs / would they pass a wrong implementation?" audit were
skipped, and the rules technically permitted that. The user correctly pushed
back. A dedicated independent `verifier` was then dispatched.

The rules permitted the inline shortcut because:

- `ultrawork` says "Maker roles do not self-approve; inline checker fallback is
  still checker output" — and the orchestrator is not the maker, so an inline
  check satisfies that clause.
- multiple docs allow inline when a "final narrow re-check ... with equal
  evidence" applies.

Neither rule distinguishes the verifier's two functions.

## Root cause: one escape clause, four docs, no carve-out

The verifier conflates two functions with different dispatch necessity:

1. **Evidence re-run mode** — run/inspect the exact checks (lint, typecheck,
   unit, scenario, full suite). Inline by the orchestrator yields *identical*
   evidence to a subagent. The "equal evidence" inline allowance is legitimate
   here.
2. **Independence audit mode** — acceptance-criteria → evidence mapping;
   adversarial test-genuineness check (are the maker's tests self-confirming /
   AI-slop / would they pass a wrong-surface impl?); contract-surface and
   baseline-guard risk check. This derives its value from being done by an agent
   that did **not** author or accept the implementation/tests. Inline by the
   maker/acceptor is **not** equal evidence.

The current docs apply the mode-1 escape clause to the whole role, so mode 2 gets
silently waived.

### Exact anchors (verify line numbers before editing — they drift)

Re-locate with:
```
cd plugins/oh-no-harness
grep -nEi "equal evidence|narrow re-check|narrow checklist|recommend|verifier|self-approve" \
  docs/shared/ralph-subagent-policy.md docs/shared/verification-tiers.md \
  docs/skill-core/ultrawork.md docs/skill-core/ralph.md docs/agent-core/verifier.md
```

- `docs/shared/ralph-subagent-policy.md` — **the load-bearing clause** (everything
  else inherits it):
  - "Subagent Bias": *"Inline execution is appropriate when work is too small to
    benefit, cannot be isolated, requires tight TDD sequencing, lacks host
    support, has been explicitly made inline-only, **or can be checked with an
    equally credible final narrow checklist.**"*
  - "Subagent-Unavailable Environments" list bullets: *"remaining work is a final
    narrow re-check that an inline checklist can cover with equal evidence"* and
    *"the role output would not change the implementation, review, verification,
    or ship/block decision"*.
- `docs/shared/verification-tiers.md` — verifier is only **"Recommended agents"**
  at LIGHT, STANDARD, and THOROUGH; never required.
- `docs/skill-core/ultrawork.md`:
  - Agent Roles preamble (~line 162): *"... final narrow re-checks may stay
    inline when they have equal evidence."*
  - (~line 117): *"Maker roles do not self-approve; inline checker fallback is
    still checker output."*
  - Final Validation table row (~line 171): dispatch `verifier` *"only for
    additional orchestration-level risk not already covered by Ralph's satisfied
    gates."*
- `docs/skill-core/ralph.md`:
  - (~line 302): *"Inline execution is the fallback, not the default, when
    `agentPolicy` is not `inline-only`, but final narrow re-checks may stay
    inline ..."*
  - review-loop budget (~line 425): *"one required review pass and one verifier
    pass when ..."* (the conditional weakens it).
  - Agent Roles table `verifier` row (~line 121).
- `docs/agent-core/verifier.md` — Responsibilities list does not state that the
  acceptance/test-genuineness audit is **inherently** an independence function.

## Decision: clarify, do not split

Keep `verifier` as one role. A split into two roles only adds handoff/table
overhead; in practice one independent verifier does both modes together. The
problem is wording, not role count. Fix the escape clause + the tier table + the
role contract so the dispatch rule keys on **independence need**, not on role
identity.

## Proposed edits

> These are the intended changes; the implementing session should adapt exact
> wording to surrounding prose. Source docs are authoritative; the
> `skills-claude/*/SKILL.md` and `agents/*.md` files are GENERATED — regenerate
> them after editing (see Verification).

### Edit 1 — `docs/shared/ralph-subagent-policy.md` (highest leverage)

Scope the "equal evidence / narrow re-check" inline exception to command
re-execution only, and add an explicit carve-out. Add a short paragraph (in
"Subagent Bias" and mirrored in the "Subagent-Unavailable Environments" note):

> The equal-evidence / final-narrow-checklist inline exception covers
> **re-running or re-inspecting verification commands** only. It does **not**
> cover the acceptance-to-evidence mapping or the adversarial test-genuineness
> audit when the proving tests or the implementation were authored or accepted
> by the same agent (executor/maker or the orchestrator that accepted the
> executor's output). That audit lacks equal inline evidence because it is a
> self-review of maker artifacts, and MUST be dispatched to an independent
> `verifier` on subagent-capable hosts. "Equal evidence" refers to identical
> command output, not to a self-assessment of one's own tests.

### Edit 2 — `docs/shared/verification-tiers.md`

Promote verifier from "Recommended" to conditionally **Required**. Under
STANDARD and THOROUGH "Required evidence", add:

> - When the change is behavior-changing AND the executor/maker authored or
>   modified the proving tests, an **independent `verifier` pass is required** on
>   subagent-capable hosts: acceptance-to-evidence mapping plus an adversarial
>   test-genuineness audit. Command success or an inline re-run by the
>   implementing/accepting agent is not sufficient. Record the fallback reason if
>   the host cannot dispatch.

Optionally keep the "Recommended agents" line for the evidence-re-run mode but
cross-reference the new requirement.

### Edit 3 — `docs/skill-core/ultrawork.md`

- Agent Roles preamble (~162): append to the "final narrow re-checks may stay
  inline" sentence: *"; this inline allowance does not extend to the independent
  verifier audit of maker-authored tests, which is not inline-eligible."*
- (~117): append to the "inline checker fallback is still checker output"
  sentence: *"— but an inline check by the maker or by the agent that accepted
  the maker's output does not satisfy the independent verifier audit when the
  maker authored the proving tests."*
- Final Validation row (~171): change the verifier from an "only for additional
  risk" dispatch to a **required** dispatch whenever execution produced or
  changed tests (independent of extra orchestration risk).

### Edit 4 — `docs/skill-core/ralph.md`

- (~302): add the same carve-out clause to the "final narrow re-checks may stay
  inline" sentence.
- review-loop budget (~425): make "one verifier pass" **required when execution
  produced or changed tests**, not merely conditional.

### Edit 5 — `docs/agent-core/verifier.md`

Add a lead line under the role title or top of Responsibilities:

> Your acceptance-to-evidence mapping and test-genuineness audit derive their
> value from independence. They are not validly performed inline by the agent
> that authored or accepted the implementation or its tests. The command-re-run
> portion of your work may be performed inline by others; the independence audit
> may not.

## Acceptance criteria for this improvement

- A reader of the four policy/skill docs cannot find a path that waives the
  independent verifier audit when the maker wrote the proving tests on a
  subagent-capable host.
- The "equal evidence" inline exception is explicitly limited to command
  re-execution in `ralph-subagent-policy.md`.
- `verification-tiers.md` STANDARD and THOROUGH list the independent verifier
  audit as required (with a documented dispatch-unavailable fallback).
- `ultrawork.md` and `ralph.md` reference the trigger consistently; no doc still
  reads "verifier only if extra risk" for the test-authored case.
- Generated `skills-claude/*/SKILL.md` and `agents/verifier.md` reflect the
  edits.

## Verification

1. Regenerate wrappers after editing source docs:
   ```
   python3 scripts/generate-skill-wrappers.py --write
   python3 scripts/generate-agent-wrappers.py --write   # if verifier.md changed
   ```
2. Re-run reachability/lint helpers if present:
   ```
   python3 scripts/check-skill-reachability.py
   ```
3. Grep audit — confirm the carve-out is present and the bare escape clause no
   longer stands alone:
   ```
   grep -nEi "equal evidence|narrow re-check|independence|maker authored|self-review" \
     docs/shared/ralph-subagent-policy.md docs/shared/verification-tiers.md \
     docs/skill-core/ultrawork.md docs/skill-core/ralph.md docs/agent-core/verifier.md
   ```
4. Dry-run scenario check: re-read the ultrawork Phase 4 + ralph review-loop +
   subagent-policy as if orchestrating a STANDARD feature where the executor
   wrote the tests. Confirm the only compliant path now dispatches an independent
   verifier.

## Open questions for the implementing session

- Should the requirement key on "executor authored the tests" specifically, or
  more broadly on "maker authored OR maker-accepted"? (Draft uses the broader
  form; confirm it does not over-trigger for trivial LIGHT edits.)
- Should LIGHT remain fully inline-eligible? (Draft leaves LIGHT unchanged;
  independence audit requirement starts at STANDARD.)
- Does `simplify` / `systematic-debugging` (which also reference
  `ralph-subagent-policy.md`) need a parallel carve-out, or is the verifier-only
  scope enough? Check inheritance.
- Cross-host review (`docs/shared/cross-host-review.md`): does the independence
  requirement interact with the same-host fallback wording? Confirm consistency.

## Cross-references

- `docs/shared/ralph-subagent-policy.md`
- `docs/shared/verification-tiers.md`
- `docs/skill-core/ultrawork.md`
- `docs/skill-core/ralph.md`
- `docs/agent-core/verifier.md`
- generators: `scripts/generate-skill-wrappers.py`, `scripts/generate-agent-wrappers.py`
