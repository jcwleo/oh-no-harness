---
name: ralph
description: Use when implementing or executing an approved plan, PRD, spec, story list, ticket, or concrete task with acceptance criteria, required verification, or multiple implementation steps.
argument-hint: "<approved plan, PRD path, spec path, or concrete task>"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Ralph for Codex

This generated file is the Codex-facing runtime skill document. Codex should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/ralph.md`
- `../../docs/platforms/codex-runtime.md`
- `../../docs/platforms/codex-ralph.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/ralph.md

# Ralph

Ralph is a mode-gated execution loop. It keeps working according to the selected
execution mode until acceptance criteria are satisfied, verification evidence is
recorded, required review and cleanup gates are handled, and the final report is
written.

## Software Development Stage

Ralph is the implementation and integration stage for LLM software development.

Use it after requirements are clear enough to execute: an approved `interview` spec, an approved `ralplan` plan, a PRD, ticket, or concrete task with acceptance criteria. Ralph owns execution mode selection or enforcement, story execution, TDD enforcement, debugging handoff, optional `fusion-rescue` escalation for stalled hard problems, verification, review, cleanup, and final reporting.

## When To Use

Use when:

- the user gives an approved plan, PRD, or concrete spec
- acceptance criteria exist or can be made explicit before editing
- an execution mode is provided or can be selected before editing
- the task needs durable progress tracking
- the work should not stop at "probably done"

Do not use when requirements are still vague. Use `interview` or `ralplan` first.

When entering directly from `interview`, accept the path only if the spec's provisional Ralph mode is `LIGHT`. If a non-LIGHT spec arrives without a `ralplan` plan, re-confirm with the user before editing — the interview-side gate should have routed to `ralplan` first.

## Artifacts

Use artifacts according to the selected execution mode from
`docs/shared/execution-modes.md`.

Full session artifacts are:

```text
.oh-no/sessions/{sessionId}/prd.json
.oh-no/sessions/{sessionId}/progress.md
.oh-no/sessions/{sessionId}/verification.md
```

If the selected mode requires a session and no session id exists, create a
timestamped directory under `.oh-no/sessions/`. `LIGHT` mode may use a compact
session note instead of full PRD scaffolding unless the input requires stories.

## Required Execution Mode

Read `docs/shared/execution-modes.md` before editing.

Ralph must set an execution mode before changing files and must follow the
selected mode during implementation, review, cleanup, and reporting.

Execution mode source priority:

1. approved `ralplan` execution profile
2. explicit user instruction
3. approved `interview` provisional sizing hint when direct Ralph was chosen
4. Ralph-derived mode using the Execution Mode Decision Prompt

If no approved plan profile exists, answer the Execution Mode Decision Prompt
from `docs/shared/execution-modes.md`, record the result, and continue with the
lightest credible mode. Ask before editing only when the mode depends on an
assumption that changes user-visible behavior, architecture, data handling,
security posture, or delivery scope.

The final report must include the selected mode, mode source, verification tier,
artifact policy, agent policy, parallel trigger, cleanup policy, and any
escalation that happened while working. It must also include the `Worktree
decision` from `docs/shared/worktree-isolation.md`.

## PRD Shape

Represent work as stories:

```json
{
  "title": "Task title",
  "executionMode": {
    "overallRalphMode": "LIGHT | STANDARD | THOROUGH",
    "modeSource": "plan | spec | user | derived by Ralph",
    "verificationTier": "LIGHT | STANDARD | THOROUGH",
    "artifactPolicy": "compact | session-verification | full-prd-session",
    "agentPolicy": "inline-only | targeted-subagents | full-review-set",
    "parallelTrigger": "approved-plan-handoff | explicit-user-request | natural-dispatch | none",
    "worktreeDecision": "approved worktree | already in approved worktree | direct automatic worktree | user declined/current checkout | ultrawork automatic worktree | read-only/not applicable | blocked",
    "worktreeLocation": ".oh-no/worktrees/<task-slug> | not-applicable | explicit fallback path",
    "cleanupPolicy": "not-needed | conditional | required"
  },
  "stories": [
    {
      "id": "story-1",
      "description": "User-visible or maintainer-visible outcome",
      "executionMode": "LIGHT | STANDARD | THOROUGH",
      "acceptanceCriteria": [
        "Concrete criterion"
      ],
      "status": "pending",
      "passes": false
    }
  ]
}
```

If the selected artifact policy requires a PRD and one does not exist, scaffold
one from the approved input before editing.

## Agent Roles

Ralph uses these roles while preserving the current platform's rules for agent use:

| Agent | Use |
|---|---|
| `explore` | Find relevant files, existing tests, commands, and integration surfaces when they are not obvious. Independent read-only exploration targets may be dispatched as parallel `explore` subagents in one batch. |
| `executor` | Implement scoped story work. |
| `plan-reviewer` | Review architecture-sensitive, broad, or multi-system completion evidence; adversarially review when the approach may be overcomplicated or the acceptance argument is weak. Applies the senior-engineer overcomplication check against the current acceptance criteria. Security-specific risks go to `code-reviewer`'s security lens. Cross-host merge: one verdict. |
| `verifier` | Package evidence against acceptance criteria and verification tiers; apply the scenario lens to validate user-facing flows and scenario coverage when applicable. Required as an independent pass under the carve-out in `docs/shared/ralph-subagent-policy.md` when the proving tests/implementation were authored or accepted by the same agent. Cross-host merge: union/conservative. |
| `code-reviewer` | Review correctness, maintainability, regressions, and missing tests; apply the security lens to auth, data, secrets, file system, network, policy, and injection risk. Cross-host merge: merged findings. |

Whether a role is inline or dispatched is decided by `## Mode-Gated Agent Dispatch`.

When the opposite host is available, run the dispatched review/verification roles as cross-host review per `docs/shared/cross-host-review.md` using each role's `Cross-host merge` value above; otherwise use the Same-Host Parallel Fallback. Exception: in the `## Review Gate` review-then-verify order the confirming `verifier` is single at STANDARD (a cross-host/parallel pair only at THOROUGH) — see that section and the review-then-verify exception in `docs/shared/cross-host-review.md`.

`simplify` is a skill, not an agent. Use the active platform's Simplify route
and cleanup invocation rules.

`verification-before-completion` and `systematic-debugging` are skills, not agents.

## Input Hardening

Before editing, make the executable scope explicit and choose the lightest
credible loop that can prove the work without skipping a stated requirement.

If the input lacks acceptance criteria, derive them from the approved request and record them in the PRD. Ask before editing when an assumption changes user-visible behavior, architecture, data handling, security posture, or delivery scope.

For each story, record (the named gate owns the detail — do not restate it here):

- expected outcome and acceptance criteria
- story execution mode
- owned files or investigation targets
- scope trace — see Scope Trace Gate
- contract surface: the actual public, caller, or verifier-facing entrypoint,
  schema, format, protocol, command, or prompt surface; the source used to
  identify it; and any compatibility constraint or uncertainty that blocks editing
- baseline guard: nearby existing tests, smoke checks, or behavior-preserving
  inspections that should still pass, or the reason no viable baseline exists
- TDD requirement or exception
- Worktree decision and location, or the fact that the worktree gate has not yet been resolved
- verification command or evidence type
- acceptance-to-evidence mapping plan and verification budget — see Verification
  Budget Policy
- story risk check — the most likely `docs/shared/failure-taxonomy.md` risk
  (contract-surface, semantic-model, baseline, adjacent-subsystem)
- validation check when measurable evidence influenced the task — see Validation Gate
- diff-budget expectation — see Diff-Budget Gate

## Worktree Isolation Gate

<HARD-GATE>
For write-capable execution, do not edit source files until a `Worktree
decision` is recorded.
</HARD-GATE>

Read `docs/shared/worktree-isolation.md` before editing.

`interview` and `ralplan` artifacts do not require a worktree by default, but
Ralph execution does. If the task will edit files, record exactly one allowed
decision from `docs/shared/worktree-isolation.md` before the first edit.

For direct Ralph execution, create or select a registered Git worktree using
`git worktree add .oh-no/worktrees/<task-slug> -b <branch-name>` by default
before editing and record `Worktree decision: direct automatic worktree`. Do not
ask a worktree approval question. Keep automatic task worktrees project-local
under `.oh-no/worktrees/` — not the parent workspace directory by default — and do
not use `git clone`, `cp -R`, a plain directory, or a manual checkout as a
substitute, per `docs/shared/worktree-isolation.md`.

When invoked from `ultrawork`, record `Worktree decision: ultrawork automatic worktree`,
create or select a registered Git worktree under `.oh-no/worktrees/<task-slug>`,
execute there, then return control to Ultrawork for merge into the
integration checkout and post-merge verification.

For direct Ralph execution that created an automatic worktree, completion is not
finished while the work sits in the worktree: after the verification, review, and
cleanup gates pass, carry out the merge-back, post-merge verification, branch/PR
handoff, and worktree-removal responsibilities in `docs/shared/worktree-isolation.md`.
If merge or post-merge verification fails, report the blocker and leave the
worktree intact instead of claiming completion.

When execution moves to a worktree, preserve access to the approved `.oh-no`
spec, plan, PRD, or task definition before editing by applying the artifact
handoff options in `docs/shared/worktree-isolation.md`.

If the worktree decision is missing, ambiguous, or cannot be recorded, stop and
report the blocker instead of editing.

## Scope Trace Gate

Before editing and before marking a story complete, Ralph must keep the change
set traceable to the approved work.

Every changed file and every meaningful changed line should map to at least one
of:

- the user's concrete request
- an approved `interview` spec, `ralplan` plan, PRD story, or ticket
- a test, acceptance criterion, or verification requirement
- removal of code made unused by the current change
- behavior-preserving cleanup protected by the current behavior lock

Do not improve adjacent code, reformat unrelated sections, add speculative
configuration, or delete pre-existing dead code unless that work is explicitly
in scope. If an unrelated problem is found, report it as residual risk or a
follow-up instead of folding it into the current diff.

## Validation Gate

Ralph must not treat metric movement or an internal shortcut as the acceptance criteria
for real software development work.

When measurable evidence influenced the task, apply
`docs/shared/validation-check.md` before marking the work complete. The
change is acceptable only if it maps to a recurring software engineering failure mode and
preserves the user, maintainer, operator, or public contract outcome as the
source of truth for acceptance.

Record a `Validation check` using the canonical template in
`docs/shared/validation-check.md`. At minimum, cover evidence used, supported
acceptance criterion or user outcome, proof and gap, recurring risk addressed,
similar-work expectation, excluded case-specific details, added process cost,
and completion claim.

Reject or narrow changes whose only justification is metric movement,
unseen-check guessing, task-name-specific guidance, fixture knowledge, or
process inflation that would not help a skeptical maintainer on a similar task.

## Execution Loop

This loop is the top-level shape. Detail for review, cleanup, agent dispatch, parallelism, and persistence lives in the dedicated sections below; do not duplicate it here.

Ralph owns execution mode selection or enforcement for ordinary implementation. Do not route concrete add/fix/refactor/implement requests directly to `test-driven-development`; Ralph invokes TDD internally when behavior-changing edits require it.

1. Read the input artifact (PRD, plan, or spec) and the shared references: `docs/shared/execution-modes.md`, `docs/shared/worktree-isolation.md`, `docs/shared/agent-tiers.md`, `docs/shared/verification-tiers.md`, `docs/shared/validation-check.md`, and `docs/shared/ralph-subagent-policy.md`.
2. Set or confirm the required execution mode before editing. Record mode
   source, verification tier, artifact policy, agent policy, parallel trigger,
   cleanup policy, task sizing, and escalation triggers. When the input is an
   approved `ralplan` plan and the user chooses ordinary `oh-no-harness:ralph`,
   treat that handoff as `Parallel trigger: approved-plan-handoff`; no separate
   "parallel Ralph" wording is needed.
3. Resolve the `## Worktree Isolation Gate` before editing. Record the `Worktree decision`, preserve approved artifact access when moving to a worktree, and stop if the decision is missing or blocked.
4. Select the next incomplete story or task and apply its task-level mode — from the approved profile, or derived from the overall mode and story risk.
5. Use `explore` when files, tests, or integration surfaces are not obvious. Independent exploration targets may be dispatched as parallel `explore` subagents in one batch per `docs/shared/ralph-subagent-policy.md`. Apply the `Scope Trace Gate` and record why the intended edits are in scope.
6. Classify the story's TDD requirement (behavior change, bug-fix reproduction, refactor characterization, or documented exception). If TDD applies, read and follow `test-driven-development` before editing production code, and record RED/GREEN/REFACTOR or exception evidence per the artifact policy.
7. Implement inline or dispatch `executor` per `## Mode-Gated Agent Dispatch` (and `## Parallel Subagent Policy` when concurrent). Run the story-specific verification required by the selected mode and verification tier. In STANDARD and THOROUGH on subagent-capable hosts, scan remaining work for disjoint scopes before implementing serially: when two or more pending stories or tasks have non-overlapping write scopes and no inter-dependency, proactively partition disjoint implementation into one concurrent `executor` batch (recorded as `Parallel trigger: natural-dispatch`) per `## Parallel Subagent Policy` and `docs/shared/ralph-subagent-policy.md`, then apply the post-batch per-executor scope check before integrating. This is conditional on isolation, dependency safety, and benefit gates — never unconditional parallelism.
8. Recheck the `Scope Trace Gate` and `## Diff-Budget Gate` against the actual
   diff. Mark the story complete only when acceptance criteria, TDD evidence
   (or documented exception), scope-trace evidence, acceptance-to-evidence
   mapping, contract-surface evidence, baseline guard, story risk-check evidence,
   and any required validation check all pass or have explicit residual risk.
   If this story changed files or shared behavior that an already-completed
   story's acceptance depended on, re-verify that earlier story before
   continuing; never leave a stale `passes: true`.
9. Repeat steps 4–8 for each remaining story, then run review per `## Review Gate`. If a check fails or behavior is unexpected, read and follow `systematic-debugging` before attempting fixes. If ordinary Ralph analysis or systematic debugging stalls after credible evidence has been gathered, read and follow `fusion-rescue`, then return control to Ralph with the synthesis before editing or verifying further. Bound per-story attempts: if a story fails verification for the same root cause after one `systematic-debugging` pass and one further fix, stop — escalate to `fusion-rescue` or record `blocked`/`failed_verification` with the failure evidence instead of looping. If execution reveals the approved plan or an acceptance criterion is itself wrong or infeasible as written — not an unrelated adjacent problem — stop and route back to the user or `ralplan` (present the options; do not auto-invoke) with the evidence instead of silently improvising.
10. Apply cleanup per `## Cleanup And Final Verification` (which owns the cleanup policy, post-cleanup verification, and any focused post-cleanup review).
11. Read and follow `verification-before-completion` before any completion claim, then write the final report.

## Mode-Gated Agent Dispatch

This section governs *agent role* dispatch only. Workflow-skill chaining (`interview` to `ralplan` to `ralph`, ralph as terminal) still follows `## Final Handoff` and the Skill Chaining contract in `using-oh-no-harness`. Do not auto-invoke a workflow skill here.

Ralph must follow the selected execution mode and agent policy. The per-mode
dispatch behavior is defined under each mode's *Ralph behavior* in
`docs/shared/execution-modes.md` — follow it: `LIGHT` stays inline for tiny work
with no context-separation benefit; in `STANDARD`, use targeted subagents on
subagent-capable hosts when the result can change the implementation, review,
verification, or ship/block decision; `THOROUGH` dispatches every isolable
required role, inline only for documented subagent-unavailable or
unsafe-to-isolate cases.

Ralph execution is parallel-capable. An approved ralplan handoff to ordinary
`oh-no-harness:ralph` authorizes every eligible isolated role in the
plan's dispatch profile. Authorization is not an instruction to spawn every
possible role: dispatch when the result can change quality, risk, latency, or
context management enough to justify lifecycle and integration cost. Ralph should actively look for safe parallel batches
for exploration, disjoint executors, test/log analysis, verification (scenario
QA lens included), code review (security lens included), and other independent
review roles. In STANDARD and THOROUGH, treat disjoint implementation as first-class parallel work, not only review or exploration: scan remaining work for disjoint scopes and proactively partition disjoint executors into one batch when, and only when, the `docs/shared/ralph-subagent-policy.md` dispatch conditions, the `## Safe Parallel Work` isolation rules, and TDD/dependency safety all hold. Inline execution is the fallback, not the default, when
`agentPolicy` is not `inline-only`, but final narrow re-checks may stay inline
when a subagent result would not change the decision. The independent verifier
audit is not such a re-check under the carve-out in
`docs/shared/ralph-subagent-policy.md`: at STANDARD and THOROUGH on
subagent-capable hosts, when the proving tests or implementation were authored
or accepted by the same agent, dispatch an independent `verifier` (record the
fallback reason if the host cannot dispatch).

Respect the platform rules from the active public skill runtime document and
the Ralph platform adapter composed into that document. If no platform adapter
context is visible, read the active platform source document named by the
runtime composition metadata.
Without a dispatch-worthy role or scope, without host authorization, or in a
subagent-unavailable environment from `docs/shared/ralph-subagent-policy.md`,
perform roles inline and record `Parallel trigger: none` plus the fallback
reason. When dispatch comes from an approved ralplan handoff, record
`Parallel trigger: approved-plan-handoff`; when dispatch comes from a direct
user request or standing preference to maximize subagents, record
`Parallel trigger: explicit-user-request`. Preserve `Parallel trigger:
natural-dispatch` only when the host permits proactive dispatch and the active
skill policy itself authorizes eligible isolated roles without a ralplan
handoff. This includes proactive disjoint-executor batching mid-loop in STANDARD/THOROUGH: the active Ralph policy authorizes it, so record it as `natural-dispatch` even when the overall run arrived by another trigger.

Pick the lightest credible role tier from `docs/shared/agent-tiers.md` whenever a role is used. Do not collapse required review, verification, security, QA, or architecture roles into one mental pass in `THOROUGH` mode. The Parallel Subagent Policy below still governs when dispatches may run concurrently and when they must be sequential.

## Parallel Subagent Policy

Parallelize under the dispatch conditions and platform deference already set in
`## Mode-Gated Agent Dispatch`, once the work can be safely isolated. Read and
apply `docs/shared/ralph-subagent-policy.md`, then use only the active adapter named by the generated
runtime skill document.

Apply the `## Batch Rule` and `## Isolation Contract` from
`docs/shared/ralph-subagent-policy.md`: create the whole eligible batch before
waiting on any one result, and before dispatching partition the work into the
per-task fields that contract lists (id, role, owned and forbidden scope,
expected output, verification responsibility, dependencies, integration owner,
and start timing). Continue local critical-path work only when it does not
overlap with delegated scopes; the dispatch packet below adds the active
adapter's platform-invocation syntax.

Use the allowed and forbidden parallelization rules from
`docs/shared/ralph-subagent-policy.md`. In particular, do not parallelize
overlapping write scopes, dependent tasks, one behavior's TDD RED/GREEN order,
or unclear ownership.

Use this dispatch shape for every parallel subagent, with the active platform
adapter deciding whether the invocation is a registered custom agent, a
plugin-scoped agent, or a documented fallback:

````markdown
Role: {explore|executor|plan-reviewer|verifier|code-reviewer}
Story/task: {id and short title}
Scope: {owned files/directories, or read-only areas}
Do not touch: {files/directories owned by other agents}
Expected output: {patch, findings, evidence, or test result}
TDD responsibility: {RED/GREEN/REFACTOR step, exception, or none}
Verification responsibility: {command/evidence}
Platform invocation: {active adapter invocation syntax}
Lifecycle: caller captures a final result, integrates or records it, then closes or cleans up the completed subagent using the active platform mechanism; timeout/no-completion wait results are not final results and MUST NOT be used to close a running or pending subagent merely because it is slow
Coordination: You are not alone in the codebase. Do not revert, overwrite, or reformat work outside your scope. Report conflicts instead of resolving them silently.
````

After parallel work completes, integrate sequentially:

1. Inspect each subagent result and changed-file set. For executor results, apply the per-executor scope check defined in `docs/shared/ralph-subagent-policy.md` `## Integration` (owned-files-only, slice satisfied, no conflict) and escalate only a stray or risky slice before integrating.
2. Resolve conflicts deliberately.
3. Close or clean up each completed subagent after its output has been captured
   and integrated, rejected, or recorded as blocked.
4. Run story-specific verification.
5. Run cross-story verification when shared behavior could be affected.
6. Only then mark stories complete.

## Review Gate

Completion requires evidence, not confidence.

The reviewer pass is mode-gated. `LIGHT` may satisfy review through direct diff
inspection unless the selected mode or risk requires independence. `STANDARD`
uses targeted review for behavior-affecting or workflow changes. `THOROUGH`
uses independent review roles for the applicable risk.

Review-then-verify order — follow the canonical contract in
`docs/shared/cross-host-review.md` `## When It Applies` Exception; do not restate
it here. In short: when both code review and an independent verifier pass are
required (STANDARD and THOROUGH behavior-changing or workflow changes), run them
in that order, not concurrently — first the `code-reviewer` pair (cross-host, or
the Same-Host Parallel Fallback with a recorded note), integrating and resolving
blocking findings, then a confirming independent `verifier` pass: single at
STANDARD, or a cross-host/parallel pair at THOROUGH, never the maker, satisfying
the carve-out in `docs/shared/ralph-subagent-policy.md`. Record each pass's
independence mode (`cross-host`, `same-host-parallel-fallback`, or
`inline-fallback` with reason).

When review is required, the reviewer pass must answer:

- Do all stories satisfy their acceptance criteria?
- Does the evidence map each acceptance criterion to direct, indirect, manual,
  or missing evidence instead of only listing commands?
- Did Ralph complete a story risk check for likely maintainer or user-facing
  edge cases without adding case-specific solution hints?
- Did Ralph identify the actual contract surface, semantic model when
  applicable, and baseline guard before accepting local green evidence?
- Is there a simpler or safer approach that still satisfies the PRD?
- Does every changed file and meaningful changed line trace to the approved
  scope, verification requirement, unused-code removal, or behavior-preserving
  cleanup lock?
- Did the implementation avoid speculative abstraction, configurability,
  dependencies, or generalization not required by the current acceptance
  criteria?
- Did code review or cleanup identify practical maintainability risks such as
  unclear ownership, brittle coupling, hidden state, fragile tests,
  generated-handwritten drift, or behavior-changing cleanup pressure?
- If auth, data, secrets, filesystem, shell, network, generated prompts,
  config, logs, sandbox, or destructive operations were touched, did
  `code-reviewer`'s security lens apply the Safety Trigger Checklist
  or was the risk explicitly ruled out?
- When the opposite host was available, were `plan-reviewer`/`code-reviewer`
  run as cross-host review (current-host + opposite-host instances synthesized) per
  `docs/shared/cross-host-review.md`, or was the Same-Host Parallel Fallback
  recorded? Was the `verifier` run as the confirming pass after the code-review
  pair (per the Review-then-verify order) — single at STANDARD, or a
  cross-host/parallel pair at THOROUGH?
- For behavior-changing work, does RED/GREEN/REFACTOR evidence exist, or is an exception documented with a specific, justified reason rather than a vague convenience claim?
- For STANDARD or THOROUGH behavior-changing work, were the applicable
  negative-path scenarios — malformed or boundary input, stale or cached state,
  cancel/resume or concurrency — probed when their trigger conditions hold, with
  the observable result recorded, or each ruled out with a one-line reason?
- Are tests or verification sufficient for the risk?
- Did broad-suite verification add meaningful confidence, or should a focused
  semantic or baseline check replace another broad rerun?

If review rejects the work, return to the relevant story and continue within the
review loop budget: one required review cycle (the parallel `code-reviewer` pair
per the Review-then-verify order) and one confirming `verifier` pass — at
STANDARD and THOROUGH on subagent-capable hosts the verifier pass is required
when execution produced or changed proving tests, or the implementation/tests
were authored or accepted by the same agent (record the fallback reason if the
host cannot dispatch), and otherwise when required by mode or risk; after a
blocker fix, run one focused re-check of the blocked scope. Record each pass's
independence mode per `docs/shared/cross-host-review.md`
`## Recording the Independence Mode`. Do not run more than one re-review after the original blocking
review unless the user explicitly authorizes it. If a blocker remains after that
budget, enter `systematic-debugging` for unknown root cause or report `blocked`
or `failed_verification` instead of looping.

## Verification Budget Policy

Ralph should be rigorous without confusing repeated broad commands for semantic
proof. For behavior-changing work:

- Apply the verification budget policy from `docs/shared/verification-tiers.md`:
  prove each acceptance criterion with focused evidence before broad suites,
  prefer a nearby baseline or smoke check over new tests alone, run a broad suite
  once after behavior stabilizes or when shared/public/generated/concurrency/
  persistence/cross-package surfaces could be affected, and do not rerun it
  without a patch-related reason; on a slow, flaky, or noisy suite, document the
  limitation and spend the next step on a smaller semantic check.
- Treat lint, typecheck, compile, formatting, and `git diff --check` as support
  evidence. They do not replace direct behavior evidence.
- In STANDARD or THOROUGH mode, for user-facing or behavior-changing stories,
  the direct evidence must be a real-surface artifact (actual command output,
  terminal or UI capture, or response body); a printed or `--dry-run` command is
  indirect at best. See `verification-before-completion`'s
  `## Acceptance-To-Evidence Mapping` for the full rule. This does not apply to
  LIGHT or trivial work.
- Inspect each real-surface artifact for silent failure: a success status (HTTP
  2xx, exit 0, a "done" log line) without the observable effect is missing
  evidence, not a pass. See `verification-before-completion`'s `## Evidence Rules`.
- Before writing a real-surface artifact, command output, or log into a `.oh-no`
  session file or the final report, redact secrets and PII to a labeled
  placeholder, keeping only the non-sensitive shape needed as evidence (status
  line, lengths, hashes, short non-secret prefixes), per the redaction convention
  in `docs/shared/cross-host-review.md`.

Record skipped broad checks and residual risk honestly. Do not claim stronger
coverage than the evidence supports.

## Diff-Budget Gate

Ralph must check blast radius before marking work complete. If the final diff
crosses any of these thresholds, run a scope review before completion:

- more than 20 changed files
- more than 500 insertions
- generated files mixed with handwritten logic
- public API changes across more than three subsystems
- multiple packages changed without explicit acceptance-to-evidence mapping

The scope review must answer:

```text
Diff-budget scope review:
- Why is this breadth necessary for the current acceptance criteria?
- Which changed files are essential?
- Which changed files are collateral or cleanup?
- Is there a narrower patch that would satisfy the request?
- What rollback boundary would a maintainer use?
```

If the breadth is not justified, narrow the patch or record a blocker instead of
presenting the work as complete.

## Cleanup And Final Verification

Cleanup happens only after the review required by the selected mode is satisfied
and a behavior lock exists.

Cleanup is mode-gated per each mode's *Ralph behavior* in
`docs/shared/execution-modes.md`: `LIGHT` may record cleanup as not needed after
the scan; `STANDARD` and `THOROUGH` set `Cleanup policy: required` (only LIGHT may
skip it as "not needed", and only an explicit user opt-out disables it), then
rerun the relevant verification — and at THOROUGH any focused post-cleanup review
the risk requires — after cleanup.

The post-cleanup pass must answer:

- Did cleanup preserve behavior?
- Did the behavior lock or relevant verification pass after cleanup?
- Did cleanup stay inside the changed-file scope?
- Is any additional code review required because cleanup changed structure, tests, or control flow?

## Resume Protocol

Ralph's loop is long and may resume after an interruption or context compaction.
On re-entry, do not trust working memory — reconstruct state from artifacts first:

1. Re-read the input artifact and `.oh-no/sessions/{sessionId}/prd.json`,
   `progress.md`, and `verification.md` when present.
2. Recompute the incomplete-story set from each story's `status`/`passes`, not
   from memory.
3. Re-confirm the execution mode and recorded `Worktree decision` and location
   before any further edit.
4. Treat any story in progress when the loop stopped as unverified — its evidence
   may be stale or partial: re-run its story-specific verification before marking
   it complete.
5. If the worktree diverged since the last pass (a `git status`/`git diff` shows
   changes not attributable to recorded work — a rebase, manual edit, or conflict
   resolution), re-verify any already-completed story whose acceptance depended on
   the changed files before trusting its `passes: true`.
6. Resume the Execution Loop at the first incomplete story.

## Persistence Rule

<HARD-GATE>
The run is invalid if the PRD or progress ledger does not show each required completion criterion below satisfied — including, named individually, the required reviewer pass, the independent verifier pass, simplify, and verification-before-completion (or an explicit missing-evidence blocker / not-required reason recorded for each); do not make a completion claim until every criterion is recorded. A silently omitted step is a named ledger gap, not a pass.
</HARD-GATE>

Ship when all completion criteria are satisfied:

- the selected execution mode is recorded and followed
- every story or task has `passes: true`
- verification evidence exists, with direct evidence or explicitly classified
  indirect/manual gaps for every acceptance criterion
- required TDD evidence exists, or each exception is documented
- the reviewer (code-review) pass required by the selected mode is approved, or a blocking reason is documented
- the independent `verifier` pass required by the selected mode or the verifier carve-out ran (per the Review-then-verify order, never the maker), or its dispatch-unavailable or not-required reason is recorded
- `simplify` ran, was explicitly disabled by the user, or — in LIGHT only — was recorded as not needed
- post-cleanup verification passed when cleanup changed files
- a direct-Ralph automatic worktree was merged back with post-merge verification, or its task branch and handoff path were reported
- `verification-before-completion` ran for the final completion claim
- acceptance-to-evidence mapping, contract-surface evidence, baseline guard,
  story risk checks, and the final risk check before completion were completed
  or a missing-evidence blocker was recorded
- final report was written

If those criteria pass and only optional cleanup, optional re-review, or
non-blocking follow-up remains, record the residual risk and stop instead of
continuing the loop.

## Output

Return:

- Session directory.
- PRD path.
- Execution mode, mode source, parallel trigger, and policy decisions.
- Worktree decision, worktree location, and integration checkout status.
- Stories completed.
- Files changed.
- Cleanup status.
- Verification commands and results.
- Acceptance-to-evidence mapping.
- Contract surface and baseline guard status.
- Risk check before completion and completion claim.
- Validation check and risk from metric-only evidence when applicable.
- Diff-budget scope review status.
- Review verdict.
- Residual risk.

## Final Handoff

Ralph is the terminal workflow skill. After the final report, do NOT auto-invoke another workflow skill (`interview`, `ralplan`, `ultrawork`). Further work needs a fresh user request and a new skill selection.

Internal mid-loop skills used during the execution loop - `test-driven-development`, `fusion-rescue`, `simplify`, `verification-before-completion`, `systematic-debugging` - are part of Ralph's documented procedure and are NOT subject to the per-step transition question. The user has already opted into Ralph's loop by invoking it.

## Source: docs/platforms/codex-runtime.md

# Codex Runtime Rules

This compact platform section is embedded in generated Codex-facing skill
documents.

## Skill Loading

Codex-facing public skills live under `skills/`. Generated
`skills/<skill>/SKILL.md` files compose the matching skill core, this compact
runtime section, and any Codex skill-specific overlay such as
`docs/platforms/codex-<skill>.md`.

## User Approval And Prompting

Ask approval, preference, scope, or next-step questions directly in the Codex
conversation. Keep prompts outcome-first: state the desired outcome,
acceptance criteria, non-goals or side effects, expected evidence, and output
shape before detailed steps.

Use compact final answers unless the active skill requires a plan, review, or
verification report. Preserve durable state in written artifacts before long
work, compaction, or handoff.

## Role Dispatch

Codex role dispatch is host-policy controlled. Use `spawn_agent` only when the
host exposes it, the active skill permits dispatch, and the role has isolated
read-only scope, disjoint write ownership, or an independent review or
verification responsibility.

For Oh No Harness roles, use the registered custom agent first:
`spawn_agent(agent_type="oh-no-<role>", ...)`. Generic fallback is allowed only
inside an active Oh No Harness workflow or explicit user-requested subagent
task after an actual `agent_type="oh-no-<role>"` attempt is rejected as unknown
or unavailable, and the fallback reason is recorded. Do not infer custom-agent
unavailability from rendered schema text, display comments, or uncertainty.

Do not combine `agent_type="oh-no-<role>"` with `fork_context=true` or any
full-history fork request. Pass the current scope, constraints, expected output,
and lifecycle in the spawned-agent message, using one payload shape only.

The Codex SessionStart standing authorization, a user standing preference, an
approved plan profile, or an active Oh No Harness skill policy is workflow-level
authorization for eligible isolated subagents. Do not ask another per-run
approval question only to dispatch those roles. Dispatch only when the result
can change implementation, review, verification, latency, context management,
or the ship/block decision.

After `wait_agent` returns a final status, capture the output and any
changed-file set before cleanup. A timeout, empty wait, or "No agents completed
yet" result is not final and is not permission to close the subagent. Once a
role is dispatched, its assigned scope, role, and expected output become a
workflow dependency. Wait until every in-scope dispatched subagent reaches final
status, capture its result, and use that result in synthesis, implementation,
review, verification, or an explicit blocked/abandoned record before advancing
past the dependent step or claiming completion. While waiting, continue only
genuinely non-overlapping local work. Do not redo delegated work inline, spawn
a duplicate replacement, or let parent inline analysis substitute for the
subagent result merely because the subagent is slow. Never use missing output
as completion evidence.

Close or clean up a subagent without a captured final result only when the user
explicitly cancels or stops that subagent, the task scope invalidates the work,
the spawn was duplicate or mis-scoped, or continuing creates a safety, security,
or filesystem risk. Record that close as cancelled or abandoned.

## Generic Role Prompt Fallback

When generic Codex agent types are used after confirmed custom-agent
unavailability, embed the matching `docs/agent-core/<role>.md` prompt body in
the spawned-agent message. If only `agents/<role>.md` exists, strip Claude Code
YAML frontmatter before embedding.

## Cross-Host Consult Channel

This is the shared cross-host consult mechanism used by Fusion Rescue and by
cross-host review (`docs/shared/cross-host-review.md`). On Codex the opposite
host is Claude Code. This section carries only the Codex-to-Claude invocation;
the activation, synthesis, and recursion-guard semantics live in the calling
skill core and the shared doc.

From Codex, consult Claude Code through `${CLAUDE_BIN:-claude}` only when the
active Codex permission state is exactly `danger-full-access`. If the state is
missing, unknown, `read-only`, `workspace-write`, or anything else, do not call
Claude: treat the opposite host as unavailable; in default mode the calling skill
applies the shared cross-host contract's Same-Host Parallel Fallback
(`docs/shared/cross-host-review.md`), and require-cross-host mode blocks while
naming the failure class and the current-host fallback.

When the `danger-full-access` preflight confirms, build the Claude command as an
argument vector, not shell string interpolation: `${CLAUDE_BIN:-claude}`,
`--print`, `--model`, `opus`, `--permission-mode`, `dontAsk`,
`--no-session-persistence`, then the redacted prompt packet, unless the user
supplied a different Claude model. Do not strip Claude's tools by default; Claude
may need its own read-only tools to produce the assigned analysis. The read-only
boundary is enforced by the redacted packet and host permissions, not by
removing tools.

The consult must return Claude's actual assigned analysis synchronously. A launch
notice, queued-job message, background acknowledgement, or status pointer is not
a valid opposite-host response; treat it as unavailable. The Claude prompt must
request only the assigned analysis and must forbid file edits, writes, installs,
mutating commands, nested rescue, and any host-to-host ping-pong back to Codex or
a third host (one cross-host hop). Redact secrets before sending; on failure
record only the failure class and command/path/auth status, never secret values.

## Source: docs/platforms/codex-ralph.md

# Codex Ralph Adapter

CODEX_ONLY_RALPH_ADAPTER

Use this adapter only on Codex. Do not apply it on Claude Code or other
platforms.

## Dispatch Decision

Ralph is parallel-capable on Codex when the host exposes `spawn_agent`. Codex
must still respect host policy and isolation rules: use subagents when the
current Codex host tool definition permits dispatch and Ralph's selected
execution mode, agent policy, task risk, and scope isolation make delegation
useful for context-window management, independent evidence, latency, or a
ship/block decision.

Explicit user or plan phrases that are sufficient dispatch signals include:

- `subagent`
- `spawn`
- `delegate`
- `parallel agents`
- `parallel subagents`
- `one agent per`
- `ralph with parallel subagents` (legacy wording; do not require this separate
  option)

Explicit subagent phrases are not required for approved `ralplan` handoffs: the
ordinary `oh-no-harness:ralph` choice should preserve
`Parallel trigger: approved-plan-handoff` and use the plan's dispatch profile as
authorization for every eligible isolated role. They are also not required when
the user has stated a standing preference to maximize subagents or when the
active Oh No Harness skill policy records proactive eligible dispatch as
workflow-level authorization for a concrete isolated scope. When no
dispatch-worthy role or scope exists, or when host policy does not authorize dispatch, Ralph must
perform roles inline and record `Parallel trigger: none`. When dispatch is
selected by an active skill dispatch policy without a ralplan handoff or direct
subagent wording, record `Parallel trigger: natural-dispatch` only if the host
permits proactive dispatch; otherwise record the explicit standing preference,
approved profile, or fallback reason.

A standing user or plan preference to maximize subagents is an explicit dispatch
signal for the whole eligible Ralph run. Use it to dispatch isolated roles when they provide decision-changing benefit within Codex host-policy limits, especially read-heavy exploration, test/log analysis, verification, QA, security, code review, other independent review roles, and disjoint implementation (executor) work in STANDARD/THOROUGH when write scopes are non-overlapping per `docs/shared/ralph-subagent-policy.md`. It is not a command
to spawn roles whose output would not change the implementation, review,
verification, or ship/block decision.

When Ralph reaches cleanup on Codex, use the Oh No Harness `simplify` skill.
Apply `docs/platforms/codex-simplify.md` through the generated Codex Simplify
runtime document.

## Invocation

When dispatch is selected, use Codex `spawn_agent`.

Codex SessionStart is the primary custom-agent preparation path. It runs
`scripts/install-codex-agents --scope user --ensure --quiet` so missing
generated `oh-no-*` agents install and stale ones refresh quietly; the Codex
Ralph adapter repeats the same best-effort user-scope ensure as a fallback.
Installed files carry the plugin version marker (so they refresh after a plugin
update without the user re-requesting installation) and pin `gpt-5.5` plus a
per-agent `model_reasoning_effort` so they do not depend on a user-specific
model config. If ensure fails, named custom-agent dispatch stays the default
whenever the host still recognizes `agent_type = "oh-no-<role>"`; record the
ensure failure and use the generic prompt-embedded fallback only after confirmed
custom-agent unavailability.

Use this dispatch order:

- `oh-no-<role>` when Oh No Harness Codex custom agents are installed in user
  scope and the current host recognizes that `agent_type`. This is required for
  Oh No Harness role dispatch, not just preferred.
- `explorer` for read-heavy repository exploration
- `worker` for scoped implementation with a disjoint write set
- `default` for specialized reviews, QA, security, verification, or critique
  when embedding the role prompt is clearer than a built-in type

Use `explorer`, `worker`, or `default` for an Oh No Harness role only when the
host rejects `oh-no-<role>` as unknown or unavailable, or the work is not an Oh
No Harness role. Record the fallback reason. Do not claim custom agents are
unavailable without a failed `spawn_agent(agent_type="oh-no-<role>", ...)`
attempt or an equivalent current host rejection. Do not infer unavailability
from rendered schema text, display comments, or missing shown parameters; the
first check is the actual `agent_type` call.

Do not use `fork_context = true` or a full-history fork with
`agent_type = "oh-no-<role>"`. Custom Ralph roles must receive the relevant
plan, scope, ownership, and evidence context in the spawn message, using one
payload shape only: prompt/message or items, never both. If a role cannot run
without the whole parent history, keep it inline or record a non-custom fallback
that the host explicitly supports.

The generated `oh-no-explore` custom-agent template sets
`sandbox_mode = "read-only"`. Other Oh No Harness role templates inherit the
active host sandbox and must still be scoped by the Ralph dispatch contract.

Spawn every independent non-blocking agent in the eligible batch before calling
`wait_agent`. Do not spawn one agent, wait, then spawn the rest.

After `wait_agent` returns a final status, capture the result and inspect any
changed-file set. A timeout, empty wait result, or "No agents completed yet" is
not a final status and is not result capture. Do not close a running subagent
merely because it is slow. Hard rule: MUST NOT call `close_agent` for a running
or pending Ralph subagent after timeout, no-completion, or empty wait output —
leave it running, wait longer when its result is needed, continue
non-overlapping work, or record the role as pending or blocked. Close without a
captured final result only when the user explicitly cancels or stops that
subagent, the task scope invalidates the work, the spawn was duplicate or
mis-scoped, or continuing creates a safety, security, or filesystem risk; record
that close as cancelled or abandoned and never use missing output as completion
evidence. When no more input is needed for a completed, failed, cancelled,
user-cancelled, scope-invalidated, or unsafe subagent and the host exposes
`close_agent`, call it. If `close_agent` reports the agent was already closed or
unavailable, record that instead of retrying. If the host exposes no explicit
close, record that closure is host-managed or unavailable.

## Role Prompt Embedding

Codex display names are not stable role identifiers. Registered Oh No Harness
custom-agent names and the dispatch message are the source of truth.

When using a generic Codex agent type, read the matching
`docs/agent-core/<role>.md` file and embed that platform-neutral prompt body in
the spawned agent message. Do not rely on the role name alone unless the
registered `oh-no-<role>` custom agent supplies the role developer
instructions. The embedded or registered prompt must preserve the role's
`Skill Relationship`, `Responsibilities`, `Operating Rules`, and `Output`
sections so the spawned agent receives the same behavioral contract as the
Claude Code plugin-scoped agent.

If `docs/agent-core/<role>.md` is unavailable but `agents/<role>.md` exists,
strip the Claude Code YAML frontmatter before embedding. Claude-only
frontmatter such as `tools`, `model`, `background`, `isolation`, or `color` is
metadata for Claude Code and must not be included in Codex spawned-agent prompt
content.

If the role is handled inline, keep the same role boundary in the caller's
notes. If the role is dispatched with a generic Codex agent type, the
spawned-agent message must embed the role prompt using the generic shape in
Prompt Shape below.

## Prompt Shape

Every role dispatch should include this task shape:

```text
Role: <explore|analyst|planner|plan-reviewer|executor|debugger|verifier|code-reviewer>
Codex agent type: oh-no-<role>   # or <explorer|worker|default> for the generic fallback
Story/task: <id and title>
Scope: <owned files/directories, or read-only areas>
Do not touch: <other agents' scopes>
Expected output: <patch, findings, evidence, or test result>
Verification responsibility: <command/evidence>
Lifecycle: caller captures the result, integrates or records it, then calls
close_agent for this completed subagent when the host exposes close_agent
Coordination: You are not alone in the codebase. Do not revert or overwrite
other agents' work. Stay inside your assigned scope.
```

For a registered `oh-no-<role>` custom agent, the TOML `developer_instructions`
already supplies the role prompt body, so keep the task prompt focused on the
fields above. For a generic `explorer`/`worker`/`default` fallback, add the
embedded role prompt:

```text
Agent prompt source: docs/agent-core/<role>.md
Agent prompt content:
<matching docs/agent-core/<role>.md prompt content>
```

If the host rejects `oh-no-<role>`, retry only through this generic
prompt-embedded path and record the fallback. For `worker` tasks, give each
agent an explicit ownership boundary; for read-only reviewers, state that they
must not edit files.
