# Execution Modes

Execution mode controls how much process Ralph applies. It is separate from
agent selection tiers and verification tiers:

- execution mode decides artifacts, dispatch, review, cleanup, and persistence
- verification tier decides what evidence is enough for the claim
- agent tier decides how much scrutiny a role needs when a role is used
- worktree isolation decides where write-capable execution may edit files

Mode is required for every handoff to `ralph`.

## Direction Contract

The approved requirements source is the top execution contract. `interview`
captures it, `ralplan` carries it into the plan, and `ralph` copies it into the
session before implementation:

```text
Direction Contract:
- Requirements source:
- User-confirmed primary goal:
- Required outcomes / AC IDs:
- Non-goals:
- Constraints:
- Do-not-silently-change assumptions:
- Direction-change approval rule:
- Confirmation status: confirmed | inferred | open
```

Planning, tests, review, verification, cleanup, and prompt loading are
supporting evidence for this contract, not replacement deliverables. A role
proposal that changes one of these fields is a
`requested-direction-change: yes` and requires explicit user approval before it
is incorporated.

## Ownership

`interview` may write only a provisional sizing hint. It should identify
scope and risk signals, but it must not turn requirements discovery into an
implementation plan.

`ralplan` owns the authoritative execution profile. A plan that recommends
`ralph` must set an overall Ralph mode and task-level modes before approval.
It should mark the direct Ralph handoff as parallel-capable by recording
`Parallel trigger: approved-plan-handoff` when at least one isolated Ralph role
can provide decision-changing evidence as a subagent.

`ralph` must read the execution profile before editing. If no profile exists,
Ralph must select a mode with the decision prompt below, record `Mode source:
derived by Ralph`, and follow that mode. Ask before editing only when the mode
choice depends on an assumption that changes user-visible behavior,
architecture, data handling, security posture, or delivery scope.

Concurrency is a risk signal only when work introduces or changes concurrency
semantics, ownership, ordering, lifecycle, or safety. Reusing an existing
verified scheduler, eligibility decision, or concurrency owner is normally
STANDARD when the change is otherwise localized and bounded; the word
`concurrency` alone does not force THOROUGH.

Routine regeneration of already-validated generated wrappers is likewise not a
THOROUGH signal by itself. Generated artifacts force THOROUGH only when the
generated surface is itself the product change or when handwritten source and
generated outputs disagree.

## Process Budgets And Gate Governance

Every STANDARD or THOROUGH plan records expected changed-file groups, an
approximate handwritten diff size, focused verification, and the named triggers
for review, cleanup, broad suites, and optional shared-contract reads.

Default budgets:

- STANDARD uses one reviewer instance per required role. Paired cross-host or
  same-host review requires a named THOROUGH risk.
- Run one broad suite after behavior stabilizes; rerun only after a meaningful
  patch change or patch-related failure.
- LIGHT and STANDARD use one quick or combined cleanup scan. Four independent
  cleanup viewpoints require a named THOROUGH safety or broad-diff trigger.
- One original review plus one focused re-review after a blocker fix is the
  default cap. A second unresolved blocking round requires rescope or user
  direction.
- If the actual handwritten diff exceeds twice the estimate, generated outputs
  mix with unexpectedly broad handwritten changes, or supporting test and
  verification code grows to roughly three times the product/source-contract
  change, stop for scope review instead of automatically expanding proof
  machinery.
- The third implementation of the same invariant requires reuse, deletion, or
  explicit approval for duplication.

A new mandatory gate is incomplete unless it records:

```text
Mandatory gate proposal:
- Canonical owner:
- Trigger:
- Applicable modes:
- Added cost:
- Evidence of benefit:
- Not-applicable path:
- Retirement or merge condition:
- Duplicate prose/marker check:
```

The reviewed per-gate metadata inventory is a maintenance reference at
`docs/reference/mandatory-gate-inventory.md`; it is not runtime Required Reading.

## Execution Mode Decision Prompt

Before selecting a mode, answer these questions from the current request, spec,
plan, repository facts, and known verification commands:

1. What observable behavior, artifact, prompt, config, or documentation will
   change, and what actual public, caller, or verifier-facing surface validates
   it?
2. Is the change isolated, or does it cross modules, generated artifacts,
   manifests, scripts, docs, workflow routing, public plugin surface,
   acceptance gates, validation policy, support claims, or release surfaces?
   Does the change alter agent behavior, workflow routing, public plugin
   surface, command names, acceptance gates, validation policy, or support
   claims?
3. Could the change affect runtime behavior, user-facing behavior, persisted
   data, permissions, authentication, secrets, network or file-system access,
   external services, concurrency, migrations, or destructive operations?
4. Are acceptance criteria, baseline or smoke evidence, direct semantic
   evidence, and what would a skeptical maintainer or user test before accepting
   the work already clear enough for a lighter loop?
5. What would force escalation while working: unknown root cause, wrong contract
   surface, semantic uncertainty, broader files, failing checks,
   security/data risk, unclear ownership, or reviewer rejection?
6. Can a lighter mode produce credible evidence without skipping a stated
   requirement?

Apply the `Validation check` from `docs/shared/validation-check.md` when
measurable evidence influenced the work.

Choose the lightest credible loop that can produce direct evidence without
skipping a stated requirement. If risk remains unclear after reading the
relevant files, choose the higher mode and record why.

## LIGHT

Use LIGHT for small, isolated work whose acceptance can be proven without a
durable PRD loop.

Typical signals:

- non-runtime documentation, comments, formatting, or metadata that does not
  alter agent behavior or public support claims
- one obvious file or a tightly bounded repeated edit
- clear acceptance criteria and a small inspection, syntax, formatting, or
  static check
- no behavior change, no data/security risk, no release-critical surface, and
  no unresolved design choice
- actual contract surface and baseline/smoke evidence are obvious or not
  applicable

Ralph behavior:

- record the selected mode and reason before editing
- keep direct implementation inline only for tiny edits or checks
  with no meaningful context-separation benefit
- skip PRD scaffolding unless the user or input explicitly requires it
- dispatch subagents for isolated read-heavy, review, or verification checks
  when the current platform policy allows it and context separation would keep
  the main thread cleaner
- document TDD as not applicable or as an exception when there is no behavior
  change
- run LIGHT verification from `docs/shared/verification-tiers.md`
- map each acceptance criterion to direct, indirect, manual, or missing
  evidence before the final claim
- record the `Worktree decision` before editing when the task is write-capable
- run `verification-before-completion` before the final claim
- run `simplify` when a quick diff or required review shows actual reuse,
  simplification, efficiency, or altitude cleanup candidates, or when candidate
  uncertainty remains after that scan; otherwise record cleanup as not needed

## STANDARD

Use STANDARD for localized implementation or instruction changes with a limited
blast radius.

Typical signals:

- localized feature work, bug fixes, refactors, config changes, or prompt/skill
  changes that alter agent behavior
- several files in one subsystem, or one public workflow with clear boundaries
- acceptance criteria are testable and verification commands are known or can be
  made explicit
- contract surface and likely semantic model are identified
- risk is real but bounded: no security-critical, data-migration,
  release-critical, or multi-subsystem uncertainty

Ralph behavior:

- record the selected mode, reason, verification tier, and task-level modes
- create a session directory and verification evidence file
- scaffold `prd.json` only when the input has multiple stories, unclear status,
  or a plan/spec already uses story structure
- use TDD for behavior-changing production edits and bug fixes; document narrow
  exceptions for docs-only, config-only, generated, or prompt-only work
- use targeted subagents for isolated exploration, review, verification, QA,
  security, or log/test analysis when the platform supports them, coordination
  cost is reasonable, and the result can change the implementation, review,
  verification, or ship/block decision
- proactively partition disjoint implementation into parallel `executor`
  batches when two or more stories have non-overlapping write scopes, no
  inter-dependency, and the dispatch/isolation gates hold, and run the
  post-batch per-executor scope check before integrating, per
  `docs/shared/ralph-subagent-policy.md`
- use `verifier` or `code-reviewer` for behavior-affecting or workflow changes
  where independent evidence is useful; when code review is required, use one
  reviewer instance unless a named THOROUGH risk applies
- run STANDARD verification from `docs/shared/verification-tiers.md`
- apply the verification budget policy: focused semantic evidence first, broad
  suites once after behavior stabilizes unless a patch-related failure requires
  rerun
- run the diff-budget gate when changed files, insertions, generated artifacts,
  public API surface, or package count exceeds the Ralph thresholds
- record the `Worktree decision` before editing when the task is write-capable
- run one combined `simplify` scan after the behavior lock exists and required
  review is satisfied, unless the user explicitly disabled it; fix only actual
  candidates and rerun relevant verification when cleanup changes files
- run `verification-before-completion` before the final claim

## THOROUGH

Use THOROUGH for broad, risky, externally visible, or release-critical work.

Typical signals:

- security-sensitive, data-sensitive, auth, permission, secret, file-system,
  network, migration, concurrency, or irreversible-operation changes
- public contracts, command surfaces, plugin packaging, release automation,
  support matrix claims, or acceptance transcript requirements
- changes spanning multiple subsystems, shared schemas, generated artifacts,
  lockfiles, or deployment surfaces
- unknown root cause, repeated failed fixes, high regression risk, or unclear
  ownership

Ralph behavior:

- create the full session artifacts: `prd.json`, `progress.md`, and
  `verification.md`
- execute story by story and keep task-level modes visible inside the PRD
- use TDD or explicit approved exceptions for behavior changes
- dispatch every required role that can be isolated according to platform
  policy, available host subagent support, `docs/shared/agent-tiers.md`,
  `docs/shared/ralph-subagent-policy.md`, and the active platform adapter;
  inline only for documented subagent-unavailable or unsafe-to-isolate cases
- proactively partition disjoint implementation into parallel `executor`
  batches when write scopes are non-overlapping and the dispatch/isolation
  gates hold, and run the post-batch per-executor scope check before
  integrating, per `docs/shared/ralph-subagent-policy.md`
- run reviewer roles for correctness and maintainability; paired review is
  reserved for a named security, data, destructive, public-contract,
  release-critical, new-concurrency, or broad multi-system risk; add plan-reviewer
  review, the code-reviewer security lens, or the verifier scenario lens when
  the risk signal matches
- apply `docs/shared/parallel-subagents.md` before any parallel dispatch
- run THOROUGH verification from `docs/shared/verification-tiers.md`
- require acceptance-to-evidence mapping, risk checks before completion,
  verification budget decisions, and diff-budget scope review in the final
  evidence
- record the `Worktree decision` before editing when the task is write-capable
- run `simplify` after required review is satisfied. Use four independent
  viewpoints only when the THOROUGH risk or broad diff justifies them; otherwise
  use the combined scan. Then rerun verification and any needed focused review
- run `verification-before-completion` before the final claim

## Escalation And De-Escalation

Escalate from LIGHT to STANDARD when the work changes runtime behavior, agent
behavior, workflow routing, validation policy, or more files than expected.

Escalate from STANDARD to THOROUGH when the work touches security, data,
permissions, public contracts, releases, generated artifacts (beyond routine
regeneration of already-validated wrappers), new or changed concurrency
semantics, or multiple subsystems, or when verification reveals unexpected
behavior.

Do not de-escalate below the mode set by an approved plan unless the user
approves the change or the plan explicitly allows per-task lighter modes. Ralph
may apply a lighter task-level mode inside a broader plan only when the plan
already lists that task as lighter and the task does not affect the broader
risk surface.

## Artifact Fields

Interview specs should include:

```text
Execution sizing hint:
- Provisional Ralph mode: LIGHT | STANDARD | THOROUGH | UNKNOWN
- Reason:
- Direct Ralph allowed: yes | no
- Planning required: yes | no
- Escalation triggers:
```

Ralplan plans must include:

```text
Execution profile:
- Overall Ralph mode: LIGHT | STANDARD | THOROUGH
- Mode source: ralplan
- Verification tier: LIGHT | STANDARD | THOROUGH
- Artifact policy: compact | session-verification | full-prd-session
- Agent policy: inline-only | targeted-subagents | full-review-set
- Parallel trigger: approved-plan-handoff | explicit-user-request | natural-dispatch | none
- Worktree policy: direct-automatic-worktree | automatic-worktree-merge | not-applicable
- Worktree location: .oh-no/worktrees/<task-slug> | not-applicable
- Cleanup policy: not-needed | conditional | required
- Task sizing:
  - T1: LIGHT | STANDARD | THOROUGH - reason
- Escalation triggers:
```

Use `approved-plan-handoff` as the default trigger for approved `ralplan` plans
that hand off to ordinary `ralph`; this is the normal parallel-capable execution
path, not a separate advanced option. Use `explicit-user-request` when the user
directly asks for subagents or states a standing preference to maximize
subagents without an approved plan profile. Preserve `natural-dispatch` only
when the host permits proactive dispatch and the active skill policy itself
authorizes eligible isolated roles for a direct Ralph request. Use `none` only
for inline-only plans, missing host support, or documented unsafe-to-isolate
work.

`Cleanup policy: conditional` is LIGHT-only: cleanup depends on LIGHT's quick
diff scan, and the executing Ralph resolves it in the session ledger to
`required` (candidates or uncertainty remain) or `not-needed`. STANDARD and
THOROUGH plans record `required`.

Ralph session notes or PRDs must include:

```text
Execution mode:
- Overall Ralph mode: LIGHT | STANDARD | THOROUGH
- Mode source: plan | spec | user | derived by Ralph
- Verification tier:
- Artifact policy:
- Agent policy:
- Parallel trigger:
- Worktree decision:
- Worktree location:
- Cleanup policy:
- Task sizing:
- Escalation triggers:
```
