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

Use it after requirements are clear enough to execute: an approved `interview` spec, an approved `ralplan` plan, a PRD, ticket, or concrete task with acceptance criteria. Ralph owns execution mode selection or enforcement, story execution, TDD enforcement, debugging handoff, verification, review, cleanup, and final reporting.

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

Before writing those artifacts in a target repository, apply the `.oh-no/`
ignore hygiene from `docs/shared/worktree-isolation.md`. Session notes, plans,
test runs, and task worktrees are workflow state. They must not appear in the
deliverable diff unless the user explicitly asked to version them.

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
decision`, task branch or worktree path, integration checkout, and integration
status from `docs/shared/worktree-isolation.md`.

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
    "integrationStatus": "not merged by direct Ralph | merged by explicit user approval | handled by Ultrawork | not-applicable",
    "cleanupPolicy": "not-needed | conditional | required",
    "finiteDeliveryContract": "canonical fields from docs/shared/execution-modes.md"
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
| `plan-reviewer` | Review architecture-sensitive, broad, or multi-system completion evidence; adversarially review when the approach may be overcomplicated or the acceptance argument is weak. Applies the senior-engineer overcomplication check against the current acceptance criteria. Security-specific risks go to `code-reviewer`'s security lens. |
| `verifier` | Package evidence against acceptance criteria and verification tiers; apply the scenario lens to validate user-facing flows and scenario coverage when applicable. |
| `code-reviewer` | Review correctness, maintainability, regressions, and missing tests; apply the security lens to auth, data, secrets, file system, network, policy, and injection risk. |

Whether a role is inline or dispatched is decided by `## Mode-Gated Agent Dispatch`.

`simplify` is a skill, not an agent. On Claude Code, use the host built-in
`simplify` skill when available; on Codex, use the Oh No Harness `simplify`
skill.

`verification-before-completion` and `systematic-debugging` are skills, not agents.

## Input Hardening

Before editing, make the executable scope explicit.

If the input lacks acceptance criteria, derive them from the approved request and record them in the PRD. Ask before editing when an assumption changes user-visible behavior, architecture, data handling, security posture, or delivery scope.

For each story, record:

- expected outcome
- acceptance criteria
- story execution mode
- owned files or investigation targets
- scope trace: how each intended file or change class maps to the request,
  approved plan, acceptance criterion, TDD evidence, or cleanup behavior lock
- TDD requirement or exception
- Worktree decision and location, or the fact that the worktree gate has not yet been resolved
- verification command or evidence type
- acceptance-to-evidence mapping plan: which evidence will directly prove each
  criterion, and which criteria only have indirect or manual evidence
- story risk check: the most likely edge case, adjacent subsystem, or
  public contract a skeptical maintainer would test
- validation check when measurable evidence influenced the task: evidence,
  recurring software engineering failure mode, user or maintainer outcome, similar-work expectation,
  deliberately excluded case-specific details, and added process cost
- verification budget: the intended focused checks, broad checks, and stop rule
- finite delivery fields from `docs/shared/finite-delivery-contract.md`:
  baseline guard, baseline evidence record, contract-risk probes
  (compatibility baseline, runtime stability classification, executable
  contract probe status), review-loop budget, deliverable diff hygiene, and
  ship gate
- diff-budget expectation: expected changed-file scope and what would trigger a
  scope review before completion

## Worktree Isolation Gate

<HARD-GATE>
For write-capable execution, do not edit source files until a `Worktree
decision` is recorded.
</HARD-GATE>

Read `docs/shared/worktree-isolation.md` before editing.

Use the shared contract for allowed decisions, default location, command shape,
artifact handoff, fallback rules, and cleanup. Ralph must still record
Worktree decision and location in its session note or PRD before the first
source edit.

For direct Ralph execution, create or select a registered Git worktree using
`git worktree add .oh-no/worktrees/<task-slug> -b <branch-name>` by default and
record `Worktree decision: direct automatic worktree`; do not ask a worktree
approval question. Do not scatter automatic task worktrees into the parent
workspace directory, and do not use `git clone`, `cp -R`, a plain directory, or
a manual checkout as a substitute. Direct Ralph leaves the completed task
worktree or branch as the deliverable by default; it does not merge back into
the integration checkout unless the user explicitly approves an integration
step.

When invoked from `ultrawork`, record
`Worktree decision: ultrawork automatic worktree`, execute under
`.oh-no/worktrees/<task-slug>`, then return control to Ultrawork for the
integration checkout and post-merge verification. Preserve access to the
approved `.oh-no` spec, plan, or PRD before editing, because untracked artifacts
do not automatically appear in a new worktree.

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

Record a `Validation check:` block using the canonical template in
`docs/shared/validation-check.md`.

Reject or narrow changes whose only justification is metric movement,
unseen-check guessing, task-name-specific guidance, fixture knowledge, or
process inflation that would not help a skeptical maintainer on a similar task.

## Execution Loop

This loop is the top-level shape. Detail for review, cleanup, agent dispatch, parallelism, and persistence lives in the dedicated sections below; do not duplicate it here.

Ralph owns execution mode selection or enforcement for ordinary implementation. Do not route concrete add/fix/refactor/implement requests directly to `test-driven-development`; Ralph invokes TDD internally when behavior-changing edits require it.

1. Read the input artifact (PRD, plan, or spec) and the shared references: `docs/shared/execution-modes.md`, `docs/shared/worktree-isolation.md`, `docs/shared/agent-tiers.md`, `docs/shared/verification-tiers.md`, `docs/shared/validation-check.md`, `docs/shared/finite-delivery-contract.md`, and `docs/shared/ralph-subagent-policy.md`.
2. Set or confirm the required execution mode before editing. Record mode
   source, verification tier, artifact policy, agent policy, parallel trigger,
   cleanup policy, task sizing, finite delivery contract fields, and escalation
   triggers. When the input is an approved `ralplan` plan and the user chooses
   ordinary `oh-no-harness:ralph`, treat that handoff as `Parallel trigger:
   approved-plan-handoff`; no separate "parallel Ralph" wording is needed.
3. Resolve the `## Worktree Isolation Gate` before editing. Record the `Worktree decision`, preserve approved artifact access when moving to a worktree, and stop if the decision is missing or blocked.
   Also record the execution checkout path, task branch, integration checkout
   path, and integration status from `docs/shared/worktree-isolation.md`, then
   confirm each source-editing command targets the execution checkout before
   applying patches.
4. Select the next incomplete story or task and apply its task-level mode — from the approved profile, or derived from the overall mode and story risk.
5. Use `explore` when files, tests, or integration surfaces are not obvious. Independent exploration targets may be dispatched as parallel `explore` subagents in one batch per `docs/shared/ralph-subagent-policy.md`. Apply the `Scope Trace Gate` and record why the intended edits are in scope.
6. Classify the story's TDD requirement (behavior change, bug-fix reproduction, refactor characterization, or documented exception). If TDD applies, read and follow `test-driven-development` before editing production code, and record RED/GREEN/REFACTOR or exception evidence per the artifact policy.
7. Implement inline or dispatch `executor` per `## Mode-Gated Agent Dispatch` (and `## Parallel Subagent Policy` when concurrent). Run the story-specific verification required by the selected mode and verification tier.
8. Recheck the `Scope Trace Gate`, `## Diff-Budget Gate`, and
   `docs/shared/finite-delivery-contract.md` against the actual diff. Mark the
   story complete only when acceptance, evidence mapping, TDD status, baseline
   guard, baseline evidence record when required, contract-risk probes,
   deliverable diff hygiene, story risk-check evidence, and any required
   validation check all pass or have explicit residual risk.
9. Repeat steps 4–8 for each remaining story, then run review per `## Review Gate`
   and `docs/shared/finite-delivery-contract.md`. If a check fails or behavior
   is unexpected, read and follow `systematic-debugging` before attempting
   fixes.
10. Apply cleanup per `## Cleanup And Final Verification` (which owns the cleanup policy, post-cleanup verification, and any focused post-cleanup review).
11. Read and follow `verification-before-completion` before any completion claim, then write the final report.

## Mode-Gated Agent Dispatch

This section governs *agent role* dispatch only. Workflow-skill chaining (`interview` to `ralplan` to `ralph`, ralph as terminal) still follows `## Final Handoff` and the Skill Chaining contract in `using-oh-no-harness`. Do not auto-invoke a workflow skill here.

Ralph must follow the selected execution mode and agent policy:

- `LIGHT`: stay inline only for tiny direct edits or checks with no meaningful
  context-separation benefit. Dispatch isolated read-heavy, review, or
  verification checks when they would keep the main thread cleaner.
- `STANDARD`: dispatch targeted subagents by default on subagent-capable hosts
  when they improve evidence, reduce risk, save context window, reduce latency,
  or handle an isolated scope. Use `verifier` or `code-reviewer` for
  behavior-affecting or workflow changes when independent evidence is useful.
- `THOROUGH`: use the full role set warranted by the risk. Dispatch every
  required role that can be isolated on subagent-capable platforms; inline only
  for documented subagent-unavailable or unsafe-to-isolate cases.

Apply the dispatch gate from `docs/shared/finite-delivery-contract.md` before
starting late review, cleanup, or verification roles. Do not spawn optional
agents after the ship gate is already satisfied; record their work as follow-up
unless a blocker, selected mode, approved plan, or risk requires the role.

Default Ralph execution is parallel-capable. An approved ralplan handoff to
ordinary `oh-no-harness:ralph` authorizes every eligible isolated role in the
plan's dispatch profile. Ralph should actively look for safe parallel batches
for exploration, disjoint executors, test/log analysis, verification (scenario
QA lens included), code review (security lens included), and other independent
review roles. Inline execution is the fallback, not the default, when
`agentPolicy` is not `inline-only`.

Respect the platform rules from the active public skill wrapper and the Ralph
platform adapter. A `UserPromptSubmit` hook injects the active adapter
immediately before Ralph runs when plugin hooks are enabled; if no hook context
is visible, read the active platform document named by the wrapper directly.
Without a dispatch-worthy role or scope, without host authorization, or in a
subagent-unavailable environment from `docs/shared/ralph-subagent-policy.md`,
perform roles inline and record `Parallel trigger: none` plus the fallback
reason. When dispatch comes from an approved ralplan handoff, record
`Parallel trigger: approved-plan-handoff`; when dispatch comes from a direct
user request or standing preference to maximize subagents, record
`Parallel trigger: explicit-user-request`. Preserve `Parallel trigger:
natural-dispatch` only when the host permits proactive dispatch and the active
skill policy itself authorizes eligible isolated roles without a ralplan
handoff.

Pick the lightest credible role tier from `docs/shared/agent-tiers.md` whenever a role is used. Do not collapse required review, verification, security, QA, or architecture roles into one mental pass in `THOROUGH` mode. The Parallel Subagent Policy below still governs when dispatches may run concurrently and when they must be sequential.

## Parallel Subagent Policy

Use parallel subagents by default when the selected execution mode and agent
policy allow dispatch, the current platform supports it, and the work can be
safely isolated.

Respect the same active platform dispatch policy noted in
`## Mode-Gated Agent Dispatch`. Read and apply
`docs/shared/ralph-subagent-policy.md`; `docs/shared/parallel-subagents.md` is
only a quick pointer back to that source of truth. Then use only the active
adapter named by the public skill wrapper.

If two or more roles or scopes are independent and the platform policy allows
subagents, create the whole eligible batch before waiting for any one result.
Continue local critical-path work only when it does not overlap with delegated
scopes.

Use the allowed and forbidden parallelization rules from the shared policy. In
particular, do not parallelize overlapping write scopes, dependent tasks, one
behavior's TDD RED/GREEN order, or unclear ownership.

Record the partition fields from the shared policy and the active adapter
invocation syntax. For every dispatched role, preserve this compact dispatch
shape:

````markdown
Role: {explore|executor|plan-reviewer|verifier|code-reviewer}
Story/task: {id and short title}
Scope: {owned files/directories, or read-only areas}
Do not touch: {files/directories owned by other agents}
Expected output: {patch, findings, evidence, or test result}
Verification responsibility: {command/evidence}
Platform invocation: {active adapter invocation syntax}
Lifecycle: caller captures a final result, integrates or records it, then closes or cleans up the completed subagent using the active platform mechanism; timeout/no-completion wait results are not final results and MUST NOT be used to close a running or pending subagent merely because it is slow
Coordination: You are not alone in the codebase. Do not revert, overwrite, or reformat work outside your scope. Report conflicts instead of resolving them silently.
````

After parallel work completes, integrate sequentially:

1. Inspect each subagent result and changed-file set.
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

Apply the review-loop budget from
`docs/shared/finite-delivery-contract.md`: one required review pass when review
is required, one narrow re-review for blocking findings after a meaningful fix,
and no extra loops for optional cleanup or confidence seeking. Escalate beyond
that only for security, data, public API, packaging, architecture direction
conflict, repeated failed fixes, or user-approved broader scope.

When review is required, the reviewer pass must answer:

- Do all stories satisfy their acceptance criteria?
- Does the evidence map each acceptance criterion to direct, indirect, manual,
  or missing evidence instead of only listing commands?
- Did Ralph complete a story risk check for likely maintainer or user-facing
  edge cases without adding case-specific solution hints?
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
- For behavior-changing work, does RED/GREEN/REFACTOR evidence exist or is an exception documented?
- Are TDD exceptions specific and justified rather than vague convenience claims?
- Are tests or verification sufficient for the risk?
- Did broad-suite verification add meaningful confidence, or should a focused
  semantic test replace another broad rerun?
- Does `docs/shared/finite-delivery-contract.md` pass: baseline guard, baseline
  evidence record, executable contract probe status for named risks,
  deliverable diff hygiene, review-loop budget, and ship gate?

If review rejects the work, return to the relevant story and continue.

## Verification Budget Policy

Ralph should be rigorous without confusing repeated broad commands for semantic
proof. For behavior-changing work:

- Prefer a focused test, scenario, or inspection that directly proves each
  acceptance criterion before running broad suites.
- Run a broad suite once after the behavior stabilizes, or when shared code,
  public APIs, generated artifacts, concurrency, persistence, or cross-package
  behavior could be affected.
- Apply the contract-risk probes from `docs/shared/finite-delivery-contract.md`
  when applicable, including baseline evidence, runtime stability
  classification, and executable contract probe status for named risks.
- Do not rerun the same broad suite repeatedly unless it failed for a reason
  likely caused by the current patch or the rerun follows a meaningful change
  that could affect broad behavior.
- Apply the patch-change rerun gate and expensive-evidence reuse rules from
  `docs/shared/finite-delivery-contract.md` before repeating broad commands.
- When a broad suite is slow, flaky, external-service-dependent, or noisy,
  document the limitation and spend the next verification step on a smaller
  semantic check.
- Treat lint, typecheck, compile, formatting, and `git diff --check` as support
  evidence. They do not replace direct behavior evidence.

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
  reuse, simplification, efficiency, or altitude cleanup candidates; otherwise
  record cleanup as not needed.
- `STANDARD`: run cleanup when behavior is locked and a quick diff or required
  review shows concrete cleanup candidates; otherwise record cleanup as not
  needed. Rerun relevant verification only if cleanup changed files.
- `THOROUGH`: run `simplify` after required review only when the review or a
  quick diff scan shows concrete cleanup candidates, or when the approved plan
  explicitly requires cleanup. Otherwise record cleanup as not needed. Rerun
  relevant verification only if cleanup changed files that the evidence
  exercised, and use the patch-change rerun gate before another broad suite.

The post-cleanup pass must answer:

- Did cleanup preserve behavior?
- Did the behavior lock or relevant verification pass after cleanup?
- Did cleanup stay inside the changed-file scope?
- Is any additional code review required because cleanup changed structure, tests, or control flow?

## Persistence Rule

Continue until:

- the selected execution mode is recorded and followed
- every story or task has `passes: true`
- verification evidence exists
- baseline guard, baseline evidence record, executable contract probes,
  deliverable diff hygiene, review-loop budget, and ship gate from
  `docs/shared/finite-delivery-contract.md` are satisfied or have an explicit
  terminal blocker
- required TDD evidence exists, or each exception is documented
- review required by the selected mode is approved or a blocking reason is documented
- `simplify` ran, was explicitly disabled, or was recorded as not needed by the selected mode
- post-cleanup verification passed when cleanup changed files
- `verification-before-completion` ran for the final completion claim
- acceptance-to-evidence mapping, story risk checks, and the final risk check
  before completion were completed or a
  missing-evidence blocker was recorded
- final report was written

## Output

Return:

- Session directory.
- PRD path.
- Execution mode, mode source, parallel trigger, and policy decisions.
- Worktree decision, worktree location, task branch, integration checkout, and
  integration status.
- Stories completed.
- Files changed.
- Cleanup status.
- Verification commands and results.
- Acceptance-to-evidence mapping.
- Risk check before completion and completion claim.
- Validation check and risk from metric-only evidence when applicable.
- Baseline guard, review-loop budget, dispatch gate, and ship gate status.
- Baseline evidence record and deliverable diff hygiene status.
- Executable contract probe status for named risks.
- Diff-budget scope review status.
- Review verdict.
- Residual risk.

## Final Handoff

Ralph is the terminal workflow skill. After the final report, do NOT auto-invoke another workflow skill (`interview`, `ralplan`, `ultrawork`). Further work needs a fresh user request and a new skill selection.

Internal mid-loop skills used during the execution loop - `test-driven-development`, `simplify`, `verification-before-completion`, `systematic-debugging` - are part of Ralph's documented procedure and are NOT subject to the per-step transition question. The user has already opted into Ralph's loop by invoking it.
