# Execution Modes

Execution mode controls how much process Ralph applies. It is separate from
agent selection tiers and verification tiers:

- execution mode decides artifacts, dispatch, review, cleanup, and persistence
- verification tier decides what evidence is enough for the claim
- agent tier decides how much scrutiny a role needs when a role is used
- worktree isolation decides where write-capable execution may edit files

Mode is required for every handoff to `ralph`.

## Ownership

`interview` may write only a provisional sizing hint. It should identify
scope and risk signals, but it must not turn requirements discovery into an
implementation plan.

`ralplan` owns the authoritative execution profile. A plan that recommends
`ralph` must set an overall Ralph mode and task-level modes before approval.
It should default the direct Ralph handoff to aggressive eligible parallel
subagent use by recording `Parallel trigger: approved-plan-handoff` whenever an
isolated Ralph role can safely run as a subagent.

`ralph` must read the execution profile before editing. If no profile exists,
Ralph must select a mode with the decision prompt below, record `Mode source:
derived by Ralph`, and follow that mode. Ask before editing only when the mode
choice depends on an assumption that changes user-visible behavior,
architecture, data handling, security posture, or delivery scope.

## Execution Mode Decision Prompt

Before selecting a mode, answer these questions from the current request, spec,
plan, repository facts, and known verification commands:

1. What observable behavior, artifact, prompt, config, or documentation will
   change?
2. Is the change limited to one obvious file or isolated surface, or does it
   cross modules, packages, generated artifacts, manifests, scripts, or docs?
3. Could the change affect runtime behavior, user-facing behavior, persisted
   data, permissions, authentication, secrets, network access, file-system
   access, external services, concurrency, migrations, or releases?
4. Does the change alter agent behavior, workflow routing, public plugin
   surface, command names, acceptance gates, validation policy, or support
   claims?
5. Are acceptance criteria and the smallest credible verification command
   already clear?
6. Which acceptance criteria need direct evidence, and which likely edge case
   would a skeptical maintainer or user test before accepting the work?
7. Is the root cause known, or does the work start from a failing command,
   flaky behavior, or uncertain bug report?
8. Can a lighter mode produce credible evidence without skipping a stated
   requirement?
9. What would force escalation while working: broader files, failing checks,
   unexpected behavior, security/data risk, unclear ownership, or reviewer
   rejection?
10. For write-capable execution, what `Worktree policy` applies from
   `docs/shared/worktree-isolation.md`?
11. If measurable evidence influenced the work, what `Validation check` from
    `docs/shared/validation-check.md` keeps the change tied to a recurring
    software engineering failure mode instead of a local check?

Choose the lightest mode that gives credible evidence. If risk remains unclear
after reading the relevant files, choose the higher mode and record why.

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
- risk is real but bounded: no security-critical, data-migration,
  release-critical, or multi-subsystem uncertainty

Ralph behavior:

- record the selected mode, reason, verification tier, and task-level modes
- create a session directory and verification evidence file
- scaffold `prd.json` only when the input has multiple stories, unclear status,
  or a plan/spec already uses story structure
- use TDD for behavior-changing production edits and bug fixes; document narrow
  exceptions for docs-only, config-only, generated, or prompt-only work
- dispatch targeted subagents by default for isolated exploration, review,
  verification, QA, security, or log/test analysis when the platform supports
  them and coordination cost is reasonable
- use `verifier` or `code-reviewer` for behavior-affecting or workflow changes
  where independent evidence is useful
- run STANDARD verification from `docs/shared/verification-tiers.md`
- apply the verification budget policy: focused semantic evidence first, broad
  suites once after behavior stabilizes unless a patch-related failure requires
  rerun
- run the diff-budget gate when changed files, insertions, generated artifacts,
  public API surface, or package count exceeds the Ralph thresholds
- record the `Worktree decision` before editing when the task is write-capable
- run cleanup only after the behavior lock exists and a quick diff or required
  review shows cleanup candidates, or when candidate uncertainty remains after
  that scan; rerun the relevant verification after cleanup
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
- run reviewer roles for correctness and maintainability; add architect,
  security, QA, or critic review when the risk signal matches
- apply `docs/shared/parallel-subagents.md` before any parallel dispatch
- run THOROUGH verification from `docs/shared/verification-tiers.md`
- require acceptance-to-evidence mapping, risk checks before completion,
  verification budget decisions, and diff-budget scope review in the final
  evidence
- record the `Worktree decision` before editing when the task is write-capable
- run `simplify` after required review is satisfied unless explicitly disabled,
  then rerun verification and any needed focused review
- run `verification-before-completion` before the final claim

## Escalation And De-Escalation

Escalate from LIGHT to STANDARD when the work changes runtime behavior, agent
behavior, workflow routing, validation policy, or more files than expected.

Escalate from STANDARD to THOROUGH when the work touches security, data,
permissions, public contracts, releases, generated artifacts, concurrency, or
multiple subsystems, or when verification reveals unexpected behavior.

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
