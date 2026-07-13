---
name: ralph
description: Use when implementing or executing an approved plan, PRD, spec, story list, ticket, or concrete task with acceptance criteria, required verification, or multiple implementation steps.
argument-hint: "<approved plan, PRD path, spec path, or concrete task>"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Ralph for Claude Code

This generated file is the Claude Code-facing runtime skill document. Claude Code slash commands should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/ralph.md`
- `../../docs/platforms/claude-code-runtime.md`
- `../../docs/platforms/claude-code-ralph.md`

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

## Required Reading

Read always-active owners before the first story. Read a triggered owner
immediately before the first dependent gate. A path reference here is a
pointer, not a substitute for reading. If a listed file cannot be read, record
the blocker instead of proceeding past the gate that depends on it.

| Contract | Class | Trigger / timing |
|---|---|---|
| `docs/shared/execution-modes.md` | always | before mode, Direction Contract, active gates, and process budget are recorded |
| `docs/shared/worktree-isolation.md` | always | before the worktree decision |
| `docs/shared/verification-tiers.md` | always | before the acceptance-to-evidence ledger is planned |
| `docs/shared/ralph-subagent-policy.md` | triggered | before dispatch or maker-verifier independence is needed |
| `docs/shared/agent-tiers.md` | triggered | before selecting a role's scrutiny level |
| `docs/shared/validation-check.md` | triggered | when measurable evidence influences a decision or claim |
| `docs/shared/cross-host-review.md` | triggered | only when a named THOROUGH risk selects paired review |
| `docs/shared/failure-taxonomy.md` | triggered | when a non-obvious story risk needs classification |

## Artifacts

Use artifacts according to the selected execution mode from
`docs/shared/execution-modes.md`.

Full session artifacts are:

```text
.oh-no/sessions/{sessionId}/prd.json
.oh-no/sessions/{sessionId}/progress.md
.oh-no/sessions/{sessionId}/verification.md
```

Reuse the chain session directory established earlier in this run when one
exists; if the selected mode requires a session and no chain session directory
was established earlier in this run, create a timestamped directory under
`.oh-no/sessions/`. On resume, the session directory recorded in the run's
artifacts wins. `LIGHT` mode may use a compact session note instead of full PRD
scaffolding unless the input requires stories.

`verification.md` is the canonical acceptance-to-evidence ledger. PRD,
progress, review, and final-report sections point to its AC IDs and delta rather
than recreating unchanged mappings.

```text
Acceptance-to-evidence ledger:
- AC ID:
- Planned evidence:
- Actual evidence:
- Coverage strength: direct | indirect | manual | missing
- Status: planned | actual | audited | stale | blocked
- Freshness source:
- Reviewer findings by AC ID:
- Verifier audit:
- Residual risk:
```

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
  "directionContract": {
    "requirementsSource": "approved spec, plan, ticket, or request",
    "primaryGoal": "user-confirmed outcome",
    "requiredOutcomeIds": ["AC-1"],
    "nonGoals": [],
    "constraints": [],
    "protectedAssumptions": [],
    "directionChangeApprovalRule": "explicit user approval",
    "confirmationStatus": "confirmed | inferred | open"
  },
  "activeGates": ["worktree", "verification", "other triggered gates only"],
  "executionMode": {
    "overallRalphMode": "LIGHT | STANDARD | THOROUGH",
    "modeSource": "plan | spec | user | derived by Ralph",
    "verificationTier": "LIGHT | STANDARD | THOROUGH",
    "artifactPolicy": "compact | session-verification | full-prd-session",
    "agentPolicy": "inline-only | targeted-subagents | full-review-set",
    "parallelTrigger": "approved-plan-handoff | explicit-user-request | natural-dispatch | none",
    "worktreeDecision": "approved worktree | already in approved worktree | direct automatic worktree | light direct checkout | user declined/current checkout | ultrawork automatic worktree | read-only/not applicable | blocked",
    "worktreeLocation": ".oh-no/worktrees/<task-slug> | current checkout | not-applicable | explicit fallback path",
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

Product or maintainer outcomes are stories. Tests, review, cleanup, and evidence
remain activities under the AC-bearing story unless the user explicitly asked
for their infrastructure as a deliverable.

Both `user declined/current checkout` and `light direct checkout` runs record
`Worktree location: current checkout`.

If the selected artifact policy requires a PRD and one does not exist, scaffold
one from the approved input before editing.

## Agent Roles

Ralph uses these roles while preserving the current platform's rules for agent use:

| Agent | Use |
|---|---|
| `explore` | Find relevant files, existing tests, commands, and integration surfaces when they are not obvious. Independent read-only exploration targets may be dispatched as parallel `explore` subagents in one batch. |
| `executor` | Implement scoped story work. |
| `plan-reviewer` | Review architecture-sensitive, broad, or multi-system completion evidence; adversarially review when the approach may be overcomplicated or the acceptance argument is weak. Applies the senior-engineer overcomplication check against the current acceptance criteria. Security-specific risks go to `code-reviewer`'s security lens. Cross-host merge: one verdict. |
| `verifier` | Package evidence against acceptance criteria and verification tiers; apply the scenario lens to validate user-facing flows and scenario coverage when applicable. Required as an independent pass under the carve-out in `docs/shared/ralph-subagent-policy.md` when the proving tests/implementation were authored or accepted by the same agent. An unconditionally single self-host independent pass, never a cross-host or same-host pair. |
| `code-reviewer` | Review correctness, maintainability, regressions, and missing tests; apply the security lens to auth, data, secrets, file system, network, policy, and injection risk. Cross-host merge: merged findings. |

Whether a role is inline or dispatched is decided by `## Mode-Gated Agent Dispatch`.

STANDARD uses one dispatched reviewer instance when review is triggered.
Cross-host review (or the Same-Host Parallel Fallback) applies only when a named
THOROUGH risk selects paired `plan-reviewer` or `code-reviewer` review. The
confirming `verifier` is always one independent self-host pass and starts after
the selected code-review stage completes.

`simplify` is a skill, not an agent. Use the active platform's Simplify route
and cleanup invocation rules.

`verification-before-completion` and `systematic-debugging` are skills, not agents.

## Input Hardening

Before editing, make the executable scope explicit and choose the lightest
credible loop that can prove the work without skipping a stated requirement.

Copy the approved Direction Contract first. Every story, changed file, test,
review finding, and final claim must map to an AC ID, a safety invariant, or an
approved behavior-preserving cleanup boundary. If execution would change the
Direction Contract, stop for explicit approval instead of silently rescoping.

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
  (for example `contract-surface mismatch`, `semantic-lifecycle/state miss`, `hidden regression`)
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

A narrow LIGHT carve-out exists for direct Ralph: when every condition of the
LIGHT carve-out in `docs/shared/worktree-isolation.md` holds — it applies only
when "no approved-plan worktree policy applies to this run — Ralph derives and
owns the worktree decision" — record
`Worktree decision: light direct checkout` plus a one-line reason and edit in
the current checkout. If the task escalates
from LIGHT mid-run, stop editing immediately; continue only after the user
explicitly approves the current checkout (record
`user declined/current checkout` from that point) or an automatic worktree is
created for all further edits (re-record
`Worktree decision: direct automatic worktree` from that point), with
already-landed edits listed in the final report. STANDARD and THOROUGH work
keeps the automatic-worktree default.

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

1. Read the input artifact and the always-active contracts in `## Required
   Reading`. Copy the Direction Contract without reinterpretation, record active
   gates and budgets, and load triggered contracts only immediately before the
   dependent gate.
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
8. Recheck the `Scope Trace Gate`, `## Diff-Budget Gate`, and
   `## Process Budget Gate` thresholds against the actual diff. Mark the story complete only when acceptance criteria, TDD evidence
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

Follow the mode and agent policy from `docs/shared/execution-modes.md`: LIGHT
stays inline when context separation has no benefit; in STANDARD, use targeted
subagents on subagent-capable hosts only when their result can change the
implementation, review, verification, or ship/block decision; THOROUGH uses the
risk-warranted isolable roles.

An approved plan authorizes its eligible isolated roles, not every possible
role. Scan for safe exploration, disjoint implementation, test/log analysis,
review, and verification batches. In STANDARD and THOROUGH, proactively
partition disjoint executors only when ownership, dependency, TDD, and benefit
gates in `docs/shared/ralph-subagent-policy.md` hold. The independent verifier
audit remains required under the maker-verifier carve-out.

Record `Parallel trigger: approved-plan-handoff`, `explicit-user-request`,
`natural-dispatch`, or `none` from the actual source. Read the active adapter
before dispatch; use inline fallback only for a documented unavailable,
unsafe-to-isolate, or no-benefit case. Pick the lightest credible role tier and
preserve distinct required role boundaries.

## Codex Executor Delegation Boundary

When the Claude Code SessionStart policy rebinds the executor role to
`executor-codex`, treat that agent as a thin raw-output transport, not as an
evidence owner. The identity rebind does not change Ralph eligibility: only a
disjoint batch already admitted by the existing Batch Rule and Isolation
Contract may overlap at the outer `executor-codex` layer. Ineligible, unknown,
or unsafe work stays serial, and every inner companion transport remains one
foreground call. Wait for every started member before existing scope checks,
independent verification, and review; fallback and integration stay sequential.

Apply the complete caller-owned guard, scope-check, partial-change inspection,
and degrade rules in `docs/shared/ralph-subagent-policy.md` under
`## Delegated Codex Executor Boundary`; do not duplicate or replace that shared
contract here.

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
uses one targeted reviewer instance for behavior-affecting or workflow changes.
`THOROUGH` uses paired review only for a named security, data, destructive,
public-contract, release-critical, new-concurrency, migration, or broad
multi-system risk; otherwise it may also use one targeted reviewer.

Review-then-verify order: when both code review and an independent verifier are
required, run the selected code-review topology first, resolve or record its
blocking findings, and then run one independent verifier (never the maker).
Record `single-reviewer` for STANDARD. For a named THOROUGH pair, apply
`docs/shared/cross-host-review.md` and record `cross-host` or
`same-host-parallel-fallback`; an inline fallback always includes a reason.

Before dispatching review roles, build the Review Gate dependency graph and write
it into the PRD/progress ledger:

```text
Review Gate dependency graph:
- code-reviewer topology: not-required | single-reviewer | paired-thorough
- code-reviewer pass: pending | complete | blocked | not-required
- code-reviewer synthesis captured: yes | no | not-required
- blocking reviewer findings: resolved | blocking | none | not-reviewed
- verifier eligible to start: yes | no
- verifier started after reviewer completion: yes | no | not-required
- early verifier discarded and rerun: yes | no | not-applicable
```

`verifier eligible to start` is `yes` only after the selected code-review stage
has completed (or a compliant not-required/fallback reason is recorded), the
caller has captured its output or paired synthesis, and blocking findings are either
resolved or recorded as blocking. A verifier spawned before that point is stale
evidence for this Review Gate, must be recorded as discarded, and must be rerun
after the reviewer dependency is satisfied before it can count as the independent
verifier pass. When both code-reviewer and verifier are required, the Review
Gate ledger must show `verifier started after reviewer completion: yes` or the
verifier pass is stale and does not count.

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
  paired only for a named THOROUGH trigger per
  `docs/shared/cross-host-review.md`? Was STANDARD kept to one reviewer? Was the
  `verifier` run as the confirming pass after the selected code-review stage — an unconditionally single self-host
  independent pass (never a cross-host or same-host pair)? Does the ledger show
  `verifier started after reviewer completion: yes` or a compliant not-required
  reason?
- For behavior-changing work, does RED/GREEN/REFACTOR evidence exist, or is an exception documented with a specific, justified reason rather than a vague convenience claim?
- For STANDARD or THOROUGH behavior-changing work, were the applicable
  negative-path scenarios — malformed or boundary input, stale or cached state,
  cancel/resume or concurrency — probed when their trigger conditions hold, with
  the observable result recorded, or each ruled out with a one-line reason that
  names why no approved AC ID, named risk, adjacent regression surface, safety
  invariant, or directly changed semantic model triggers it?
- Are tests or verification sufficient for the risk?
- Did broad-suite verification add meaningful confidence, or should a focused
  semantic or baseline check replace another broad rerun?

Reviewer findings that do not map to the approved work under the `Scope Trace
Gate` — an AC ID, a safety invariant, a verification requirement, removal of
code made unused by the current change, or the approved behavior-preserving
cleanup boundary — are recorded as residual risk or follow-ups, not fixed in
this run; do not expand the diff for them without explicit user approval. A
regression or contract break caused by the current change always maps to the
approved scope and may block.

If review rejects the work, return to the relevant story and continue within the
review loop budget: one required review cycle using the selected topology and
one confirming `verifier` pass — at
STANDARD and THOROUGH on subagent-capable hosts the verifier pass is required
when execution produced or changed proving tests, or the implementation/tests
were authored or accepted by the same agent (record the fallback reason if the
host cannot dispatch), and otherwise when required by mode or risk; after a
blocker fix, run one focused re-check of the blocked scope. That focused
re-check is the single permitted re-review, not an addition to it; re-run only
the evidence the fix invalidated — the blocked scope's story verification and
any verifier or ledger rows whose covered files or behavior changed — while
evidence for untouched scopes stays fresh. Record
`single-reviewer` for STANDARD; for a named THOROUGH pair, record its
independence mode per `docs/shared/cross-host-review.md`
`## Recording the Independence Mode`. The single self-host verifier pass is governed by the carve-out and the `verifier started after reviewer completion` sequencing field, not the enum. Do not run more than one re-review after the original blocking
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
  line, lengths, hashes, short non-secret prefixes), per the evidence-redaction
  rule in `docs/shared/verification-tiers.md`.

Record skipped broad checks and residual risk honestly. Do not claim stronger
coverage than the evidence supports.

## Process Budget Gate

This gate is the mid-run early-stop check; the `## Diff-Budget Gate` owns the
pre-completion blast-radius review.

Before implementation, copy the plan's expected handwritten changed-file groups,
approximate diff size, review topology/trigger, cleanup depth, broad-suite cap,
and review-round cap. If no plan supplied them, derive conservative values from
`docs/shared/execution-modes.md`.

Stop for rescope, simplify, or user approval when the actual handwritten diff
exceeds twice the estimate, generated output hides unexpectedly broad source
changes, supporting tests/validation grow to roughly three times the
product/source-contract change, a second blocking review round remains
unresolved, or the same invariant is being implemented a third time. A budget
breach never authorizes automatic expansion.

Measure the supporting-test ratio as changed test/validation lines versus
changed product or source-contract lines (for example from `git diff --stat`),
checked at each story's step-8 recheck. The ratio is a stop-and-rescope signal,
not a license to delete required negative, regression, or safety cases.

## Diff-Budget Gate

Ralph must check blast radius before marking work complete; mid-run early
stops belong to `## Process Budget Gate`. If the final diff
crosses any of these thresholds, run a scope review before completion:

- more than twice the plan's expected handwritten file or diff estimate
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

Cleanup is mode- and trigger-gated per `docs/shared/execution-modes.md`.
LIGHT and STANDARD use one quick or combined scan. THOROUGH expands to four
independent viewpoints only for a named safety or broad-diff trigger. Record the
trigger, candidates found, and fixes made; do not create cleanup work merely to
satisfy a pass count. Rerun relevant verification whenever cleanup changes files.

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
The run is invalid if the session does not show each required completion criterion below satisfied — including, named individually, the required reviewer pass, the independent verifier pass, simplify, and verification-before-completion (or an explicit missing-evidence blocker / not-required reason recorded for each); do not make a completion claim until every criterion is recorded. Evidence status lives in `verification.md`; PRD/progress point to its AC IDs. A silently omitted step is a named ledger gap, not a pass. Every review records its topology using the Review Gate dependency-graph values: `not-required` (with the compliant reason, including LIGHT direct-diff inspection), `single-reviewer` (STANDARD, or THOROUGH without a named pair trigger), or a named THOROUGH pair with `cross-host` / `same-host-parallel-fallback`; an inline fallback requires a reason. Missing review topology is a named ledger gap. The single self-host verifier pass is governed by the maker-verifier carve-out and sequencing field. When both code-reviewer and verifier are required, the ledger must show `verifier started after reviewer completion: yes` or the verifier pass is stale and does not count.
</HARD-GATE>

For a LIGHT run with no behavior change, the four named criteria may be
recorded as one combined ledger line when each part is actually true, for
example: `review: direct diff inspection; verifier: not-required (no
maker-authored proving tests); simplify: no candidates;
verification-before-completion: ran`.

Ship when all completion criteria are satisfied:

- the selected execution mode is recorded and followed
- every story or task has `passes: true`
- the canonical `verification.md` ledger has one row per AC ID, with planned and
  actual evidence, freshness, audit status, and direct evidence or explicitly classified
  indirect/manual gaps for every acceptance criterion
- required TDD evidence exists, or each exception is documented
- the reviewer (code-review) pass required by the selected mode is approved, or a blocking reason is documented
- the independent `verifier` pass required by the selected mode or the verifier carve-out ran (per the Review-then-verify order, never the maker), or its dispatch-unavailable or not-required reason is recorded
- the proportional `simplify` scan ran, was explicitly disabled, or recorded no
  candidates with the applicable mode/trigger
- post-cleanup verification passed when cleanup changed files
- a direct-Ralph automatic worktree was merged back with post-merge verification, or its task branch and handoff path were reported, or no direct-Ralph automatic worktree existed per the recorded `Worktree decision`
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
- Process budget outcome: planned versus actual tests/TDD cycles, role dispatch
  count and reasons, broad-suite count, and rescope events.

## Final Handoff

Ralph is the terminal workflow skill. After the final report, do NOT auto-invoke another workflow skill (`interview`, `ralplan`, `ultrawork`). Further work needs a fresh user request and a new skill selection.

Internal mid-loop skills used during the execution loop - `test-driven-development`, `fusion-rescue`, `simplify`, `verification-before-completion`, `systematic-debugging` - are part of Ralph's documented procedure and are NOT subject to the per-step transition question. The user has already opted into Ralph's loop by invoking it.

## Source: docs/platforms/claude-code-runtime.md

# Claude Code Runtime Rules

This compact platform section is embedded in generated Claude Code-facing skill
documents.

## Skill Loading

Claude Code-facing public skills live under `skills-claude/`. Generated
`skills-claude/<skill>/SKILL.md` files compose the matching skill core, this
compact runtime section, and any Claude Code skill-specific overlay such as
`docs/platforms/claude-code-<skill>.md`. Slash commands must delegate to the
matching generated skill document.

## User Approval, Tasks, And Prompting

Use the host's structured question tool when available for approval,
preference, scope, or next-step selection; otherwise ask one focused plain-text
question and wait. Present options as actions the host agent will take.

When a core skill has a multi-phase approval handoff and the host exposes task
tracking, create one task per phase and complete them sequentially.

Keep Claude prompts explicit and sectioned: state scope, non-goals,
constraints, approval gates, expected evidence, and output format. Preserve
long-running context in artifacts before compaction, task handoff, or subagent
dispatch.

## Role Dispatch

Dispatch only after the active skill's trigger fires, then read
`docs/platforms/claude-code.md` `## Role Dispatch` for the full host contract.
Prefer `oh-no-harness:<role>`, request the whole independent batch before
waiting, capture every final result, and clean up only after integration. An
approved-plan handoff is dispatch authorization for eligible isolated roles;
plugin-agent unavailability uses the documented embedded-role fallback.

## Cross-Host Consult Channel

This channel is trigger-loaded, not embedded in every workflow decision. When a
named THOROUGH paired-review or Fusion Rescue trigger fires, read and apply
`docs/platforms/claude-code.md` `## Cross-Host Consult Channel` before dispatch.
Until then, do not preload opposite-host invocation details.

## Source: docs/platforms/claude-code-ralph.md

# Claude Code Ralph Adapter

CLAUDE_CODE_ONLY_RALPH_ADAPTER

Use this adapter only on Claude Code. Do not apply it on Codex or other
platforms.

When Ralph reaches cleanup on Claude Code, use the host built-in `simplify`
skill when available as the cleanup contract.

## Invocation

When Ralph dispatches a role, use Claude Code's Task, Agent, Workflow `agent()`,
or subagent mechanism with the plugin-scoped agents from `agents/`.

An approved `ralplan` handoff to ordinary `oh-no-harness:ralph` is the default
parallel-capable execution path. Treat `Parallel trigger:
approved-plan-handoff` as authorization to use every eligible isolated role in
the approved plan; do not require a separate `ralph with parallel subagents`
choice. Authorization is not a command to dispatch roles whose output would not
change the implementation, review, verification, or ship/block decision.

Use `oh-no-harness:<agent>` as the agent name when the tool lists plugin agents.
When explicit prompt text or a user-facing manual mention is needed, use
`@agent-oh-no-harness:<agent>`.

For independent read-only, review, verification, QA, security, or exploration work — and for disjoint implementation (executor) work in STANDARD/THOROUGH, when write scopes are non-overlapping per `docs/shared/ralph-subagent-policy.md` — request background subagents and start the whole independent batch before waiting for any one result.

After each background subagent reaches a final status, capture its result and
changed-file set. When no further input is needed, close or clean up that
completed subagent with the Claude Code mechanism exposed by the host. If the
host does not expose explicit close or cleanup, record that no close mechanism
was available.

If a plugin-scoped agent is unavailable, keep the same role boundary by
embedding the matching `agents/<agent>.md` prompt into the available Claude Code
subagent mechanism.

## Ralph Prompt Shape

Every Claude Code Ralph dispatch should include:

```text
Role: oh-no-harness:<agent>
Story/task: <id and title>
Scope: <owned files/directories, or read-only areas>
Do not touch: <other agents' scopes>
Expected output: <patch, findings, evidence, or test result>
Verification responsibility: <command/evidence>
Background: <yes for independent work, no when sequential>
Lifecycle: caller captures the result, integrates or records it, then closes or
cleans up this completed subagent when the host exposes that mechanism
Coordination: You are not alone in the codebase. Do not revert or overwrite
other agents' work. Stay inside your assigned scope.
```

## Batch Discipline

For an eligible independent batch, issue all Claude Code subagent requests
before waiting. After they return, integrate their outputs in Ralph and run the
verification required by the selected execution mode. Close or clean up each
completed subagent after its output has been captured and no further input is
needed.
