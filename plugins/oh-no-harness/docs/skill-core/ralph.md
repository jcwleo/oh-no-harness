---
name: ralph
description: Use when implementing or executing an approved plan, PRD, spec, story list, ticket, or concrete task with acceptance criteria, required verification, or multiple implementation steps.
argument-hint: "<approved plan, PRD path, spec path, or concrete task>"
---

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
| `plan-reviewer` | Review architecture-sensitive, broad, or multi-system completion evidence; adversarially review when the approach may be overcomplicated or the acceptance argument is weak. Applies the senior-engineer overcomplication check against the current acceptance criteria. Security-specific risks go to `code-reviewer`'s security lens. When the opposite host is available, run this review as cross-host review per `docs/shared/cross-host-review.md` (current-host + opposite-host instances synthesized into one verdict; otherwise use the Same-Host Parallel Fallback). |
| `verifier` | Package evidence against acceptance criteria and verification tiers; apply the scenario lens to validate user-facing flows and scenario coverage when applicable. When the opposite host is available, run this verification as cross-host review per `docs/shared/cross-host-review.md` (current-host + opposite-host instances, union/conservative merged result); otherwise use the Same-Host Parallel Fallback. |
| `code-reviewer` | Review correctness, maintainability, regressions, and missing tests; apply the security lens to auth, data, secrets, file system, network, policy, and injection risk. When the opposite host is available, run this review as cross-host review per `docs/shared/cross-host-review.md` (current-host + opposite-host instances, merged findings; otherwise use the Same-Host Parallel Fallback). |

Whether a role is inline or dispatched is decided by `## Mode-Gated Agent Dispatch`.

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
before editing and record
`Worktree decision: direct automatic worktree`. Do not ask a worktree approval
question. Keep automatic task worktrees project-local under `.oh-no/worktrees/`
unless the shared policy allows and records an explicit fallback. Do not use
the parent workspace directory by default, and do not use `git clone`, `cp -R`,
a plain directory, or a manual checkout as a substitute.

When invoked from `ultrawork`, record `Worktree decision: ultrawork automatic worktree`,
create or select a registered Git worktree under `.oh-no/worktrees/<task-slug>`,
execute there, then return control to Ultrawork for merge into the
integration checkout and post-merge verification.

For direct Ralph execution that created an automatic worktree, completion is not
finished while the work sits in the worktree. After the verification, review, and
cleanup gates pass, either merge the task branch back into the originating
checkout and run post-merge verification, or — when the user asked for a branch or
PR handoff — leave the task branch intact and report its name and the merge or PR
path. Remove the task worktree only after a successful merge and post-merge
verification, or on explicit user cancellation, per
`docs/shared/worktree-isolation.md`. If merge or post-merge verification fails,
report the blocker and leave the worktree intact instead of claiming completion.

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
9. Repeat steps 4–8 for each remaining story, then run review per `## Review Gate`. If a check fails or behavior is unexpected, read and follow `systematic-debugging` before attempting fixes. If ordinary Ralph analysis or systematic debugging stalls after credible evidence has been gathered, read and follow `fusion-rescue`, then return control to Ralph with the synthesis before editing or verifying further. Bound per-story implementation attempts: if a story still fails its verification for the same root cause after one `systematic-debugging` pass and one further fix attempt, stop retrying it — escalate to `fusion-rescue` or record `blocked`/`failed_verification` with the failure evidence instead of looping. If execution reveals that the approved plan or an acceptance criterion is wrong or infeasible as written — not merely an unrelated adjacent problem — stop and route back to the user or `ralplan` with the evidence instead of silently improvising a different approach.
10. Apply cleanup per `## Cleanup And Final Verification` (which owns the cleanup policy, post-cleanup verification, and any focused post-cleanup review).
11. Read and follow `verification-before-completion` before any completion claim, then write the final report.

## Mode-Gated Agent Dispatch

This section governs *agent role* dispatch only. Workflow-skill chaining (`interview` to `ralplan` to `ralph`, ralph as terminal) still follows `## Final Handoff` and the Skill Chaining contract in `using-oh-no-harness`. Do not auto-invoke a workflow skill here.

Ralph must follow the selected execution mode and agent policy:

- `LIGHT`: stay inline only for tiny direct edits or checks with no meaningful
  context-separation benefit. Dispatch isolated read-heavy, review, or
  verification checks when they would keep the main thread cleaner.
- `STANDARD`: use targeted subagents on subagent-capable hosts when they improve
  evidence, reduce risk, save context window, reduce latency, or handle an
  isolated scope, and when the result can change the implementation, review,
  verification, or ship/block decision. Use `verifier` or `code-reviewer` for
  behavior-affecting or workflow changes when independent evidence is useful.
- `THOROUGH`: use the full role set warranted by the risk. Dispatch every
  required role that can be isolated on subagent-capable platforms; inline only
  for documented subagent-unavailable or unsafe-to-isolate cases.

Ralph execution is parallel-capable. An approved ralplan handoff to ordinary
`oh-no-harness:ralph` authorizes every eligible isolated role in the
plan's dispatch profile. Authorization is not an instruction to spawn every
possible role: dispatch when the result can change quality, risk, latency, or
context management enough to justify lifecycle and integration cost. Ralph should actively look for safe parallel batches
for exploration, disjoint executors, test/log analysis, verification (scenario
QA lens included), code review (security lens included), and other independent
review roles. In STANDARD and THOROUGH, treat disjoint implementation as first-class parallel work, not only review or exploration: scan remaining work for disjoint scopes and proactively partition disjoint executors into one batch when, and only when, the `docs/shared/ralph-subagent-policy.md` dispatch conditions, the `## Safe Parallel Work` isolation rules, and TDD/dependency safety all hold. Inline execution is the fallback, not the default, when
`agentPolicy` is not `inline-only`, but final narrow re-checks may stay inline
when a subagent result would not change the decision.

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
apply `docs/shared/ralph-subagent-policy.md` (`docs/shared/parallel-subagents.md`
only points back to it), then use only the active adapter named by the generated
runtime skill document.

If two or more roles or scopes are independent and the platform policy allows
subagents, create the whole eligible batch before waiting for any one result.
Continue local critical-path work only when it does not overlap with delegated
scopes.

Before dispatching, partition the work and write down:

- story or task id
- owned files, directories, or read-only scope
- files or directories that must not be touched
- expected output
- verification responsibility
- dependencies on other subagents
- lifecycle owner: who captures output and closes or cleans up the completed
  subagent
- platform invocation: active adapter invocation syntax
- start timing: foreground, background, or sequential after another role

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
- When the opposite host was available, were `plan-reviewer`/`code-reviewer`/`verifier`
  run as cross-host review (current-host + opposite-host instances synthesized) per
  `docs/shared/cross-host-review.md`, or was the Same-Host Parallel Fallback
  recorded?
- For behavior-changing work, does RED/GREEN/REFACTOR evidence exist, or is an exception documented with a specific, justified reason rather than a vague convenience claim?
- For STANDARD or THOROUGH behavior-changing work, were the applicable
  negative-path scenarios — malformed or boundary input, stale or cached state,
  cancel/resume or concurrency — probed when their trigger conditions hold, with
  the observable result recorded, or each ruled out with a one-line reason?
- Are tests or verification sufficient for the risk?
- Did broad-suite verification add meaningful confidence, or should a focused
  semantic or baseline check replace another broad rerun?

If review rejects the work, return to the relevant story and continue within the
review loop budget: one required review pass and one verifier pass when
required by mode or risk; after a blocker fix, run one focused re-check of the
blocked scope. Do not run more than one re-review after the original blocking
review unless the user explicitly authorizes it. If a blocker remains after that
budget, enter `systematic-debugging` for unknown root cause or report `blocked`
or `failed_verification` instead of looping.

## Verification Budget Policy

Ralph should be rigorous without confusing repeated broad commands for semantic
proof. For behavior-changing work:

- Prefer a focused test, scenario, or inspection that directly proves each
  acceptance criterion before running broad suites.
- Run nearby existing tests, smoke checks, or behavior-preserving inspections
  from the baseline guard when they exist. New tests alone are insufficient
  when a viable existing baseline could catch regressions.
- Run a broad suite once after the behavior stabilizes, or when shared code,
  public APIs, generated artifacts, concurrency, persistence, or cross-package
  behavior could be affected.
- Do not rerun the same broad suite repeatedly unless it failed for a reason
  likely caused by the current patch or the rerun follows a meaningful change
  that could affect broad behavior.
- When a broad suite is slow, flaky, external-service-dependent, or noisy,
  document the limitation and spend the next verification step on a smaller
  semantic check.
- Treat lint, typecheck, compile, formatting, and `git diff --check` as support
  evidence. They do not replace direct behavior evidence.
- In STANDARD or THOROUGH mode, for user-facing or behavior-changing stories,
  the direct evidence must be a real-surface artifact (actual command output,
  terminal or UI capture, or response body); a printed or `--dry-run` command is
  indirect at best. See `verification-before-completion`'s
  `## Acceptance-To-Evidence Mapping` for the full rule. This does not apply to
  LIGHT or trivial work.
- Inspect each real-surface artifact for silent failure: a success status is not
  acceptance. Confirm the intended effect actually appears — not HTTP 2xx with an
  empty or error body, not exit 0 with no state change, not a log line that only
  says "done". A success code without the observable effect is missing evidence,
  not a pass.
- Before writing a real-surface artifact, command output, or log into a `.oh-no`
  session file or the final report, redact secrets and sensitive data: replace
  tokens, credentials, API keys, cookies, auth headers, and PII with a labeled
  placeholder such as `[REDACTED_TOKEN]`, keeping only the non-sensitive shape
  needed as evidence (status line, lengths, hashes, short non-secret prefixes).
  Use the redaction convention from `docs/shared/cross-host-review.md`.

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

Cleanup is mode-gated:

- `LIGHT`: run `simplify` when a quick diff or required review shows actual
  reuse, simplification, efficiency, or altitude cleanup candidates, or when
  candidate uncertainty remains after that scan; otherwise record cleanup as not
  needed.
- `STANDARD`: run `simplify` after behavior is locked and required review is
  satisfied, unless the user explicitly disabled it; a STANDARD plan sets
  `Cleanup policy: required` and "not needed" is a LIGHT-only skip. Rerun relevant
  verification afterward.
- `THOROUGH`: run `simplify` after required review; a THOROUGH plan sets
  `Cleanup policy: required`, so cleanup is not skippable as "not needed" (only
  LIGHT may skip) — only an explicit user opt-out disables it. Then rerun
  verification and any focused post-cleanup review required by risk.

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
2. Recompute the set of incomplete stories from each story's `status`/`passes`,
   not from memory.
3. Re-confirm the selected execution mode and the recorded `Worktree decision`
   and location before any further edit.
4. Treat any story that was in progress when the loop stopped as unverified:
   re-run its story-specific verification before marking it complete, because its
   evidence may be stale or partial.
5. Resume the Execution Loop at the first incomplete story.

## Persistence Rule

Ship when all completion criteria are satisfied:

- the selected execution mode is recorded and followed
- every story or task has `passes: true`
- verification evidence exists, with direct evidence or explicitly classified
  indirect/manual gaps for every acceptance criterion
- required TDD evidence exists, or each exception is documented
- review required by the selected mode is approved or a blocking reason is documented
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
