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
artifact policy, agent policy, cleanup policy, and any escalation that happened
while working.

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
| `explore` | Find relevant files, existing tests, commands, and integration surfaces when they are not obvious. |
| `executor` | Implement scoped story work. |
| `architect` | Review architecture-sensitive, security-sensitive, broad, or multi-system completion evidence. |
| `critic` | Adversarially review when the approach may be overcomplicated or the acceptance argument is weak; otherwise skip. |
| `verifier` | Package evidence against acceptance criteria and verification tiers. |
| `code-reviewer` | Review correctness, maintainability, regressions, and missing tests. |
| `security-reviewer` | Review auth, data, secrets, file system, network, policy, or injection risk. |
| `qa-tester` | Validate user-facing flows and scenario coverage when applicable. |

Whether a role is inline or dispatched is decided by `## Mode-Gated Agent Dispatch`.

`ai-slop-cleaner` is a skill, not an agent.

`verification-before-completion` and `systematic-debugging` are skills, not agents.

## Input Hardening

Before editing, make the executable scope explicit.

If the input lacks acceptance criteria, derive them from the approved request and record them in the PRD. Ask before editing when an assumption changes user-visible behavior, architecture, data handling, security posture, or delivery scope.

For each story, record:

- expected outcome
- acceptance criteria
- story execution mode
- owned files or investigation targets
- TDD requirement or exception
- verification command or evidence type

## Execution Loop

1. Read the PRD, plan, or spec.
2. Read `docs/shared/execution-modes.md`, `docs/shared/agent-tiers.md`, and `docs/shared/verification-tiers.md`.
3. Set or confirm the required execution mode before editing.
4. Record the mode source, verification tier, artifact policy, agent policy, cleanup policy, task sizing, and escalation triggers.
5. Select the next incomplete story or task.
6. Apply the task-level mode from the approved profile; if none exists, derive it from the overall mode and story risk.
7. Use `explore` when files, tests, or integration surfaces are not obvious.
8. Identify files and checks.
9. Identify safe parallelization opportunities only when the selected mode and agent policy allow it.
10. Classify the story's TDD requirement:
   - behavior-changing production code: TDD required
   - bug fix: reproduction test required
   - behavior-preserving refactor: characterization or regression coverage required
   - docs-only, config-only, generated code, throwaway prototype, or unavailable test harness: document the exception
11. If TDD is required, read and follow `test-driven-development` before editing production code.
12. Record RED, GREEN, post-refactor, or exception evidence according to the selected artifact policy.
13. Implement inline or dispatch `executor` according to `## Mode-Gated Agent Dispatch`.
14. Run the story-specific verification required by the selected mode and verification tier.
15. Mark the story complete only when acceptance criteria and required TDD or exception evidence pass.
16. Repeat until all stories or tasks pass.
17. Run review roles according to the selected mode, agent policy, and risk signals.
18. If a check fails or behavior is unexpected, read and follow `systematic-debugging` before attempting fixes.
19. Apply cleanup according to the selected cleanup policy.
20. Re-run verification after cleanup when cleanup changed files.
21. If cleanup changed non-trivial code, tests, or prompts, run the focused post-cleanup review required by the selected mode.
22. Read and follow `verification-before-completion` before claiming completion.
23. Write the final report.

## Mode-Gated Agent Dispatch

This section governs *agent role* dispatch only. Workflow-skill chaining (`interview` to `ralplan` to `ralph`, ralph as terminal) still follows `## Final Handoff` and the Skill Chaining contract in `using-oh-no-harness`. Do not auto-invoke a workflow skill here.

Ralph must follow the selected execution mode and agent policy:

- `LIGHT`: inline by default. Do not dispatch subagents unless the user requested delegation or a specific check cannot be credibly performed inline.
- `STANDARD`: inline by default, with targeted subagents only when they clearly improve evidence, reduce risk, or handle an isolated scope. Use `verifier` or `code-reviewer` for behavior-affecting or workflow changes when independent evidence is useful.
- `THOROUGH`: use the full role set warranted by the risk. Dispatch on subagent-capable platforms when allowed by the platform and user authorization; otherwise perform the roles inline while preserving role boundaries.

Respect the platform rules from `using-oh-no-harness`: Claude Code may use its Task/subagent mechanism; Codex may use `spawn_agent` only when the user explicitly requested subagents or parallel delegation.

Pick the lightest credible role tier from `docs/shared/agent-tiers.md` whenever a role is used. Do not collapse required review, verification, security, QA, or architecture roles into one mental pass in `THOROUGH` mode. The Parallel Subagent Policy below still governs when dispatches may run concurrently and when they must be sequential.

## Parallel Subagent Policy

Use parallel subagents only when the selected execution mode and agent policy
allow dispatch, the current platform supports it, and the work can be safely
isolated.

Respect the platform rules from `using-oh-no-harness`: Claude Code may use its Task/subagent mechanism; Codex may use `spawn_agent` only when the user explicitly requested subagents or parallel delegation.

Read and apply `docs/shared/parallel-subagents.md` before dispatching parallel work.

Before dispatching parallel subagents, partition the work and write down:

- story or task id
- owned files, directories, or read-only scope
- expected output
- verification responsibility
- dependencies on other subagents

Parallelize only when write scopes are disjoint or read-only:

- multiple `explore` agents over different subsystems
- independent `executor` agents for stories touching separate files or modules
- review agents after implementation when they read the same final diff but do not edit
- `qa-tester`, `security-reviewer`, and `code-reviewer` in parallel after the implementation is stable

Do not parallelize when:

- two agents would edit the same file, directory, schema, migration, generated artifact, lockfile, or shared config
- one task depends on another task's output
- TDD RED/GREEN order for a behavior would be split across agents
- the plan does not define file ownership clearly enough
- a reviewer has found unresolved issues that an implementer is still fixing

Implementation subagents must know they are not alone in the codebase. Tell them not to revert or overwrite others' work and to stay inside their assigned write scope.

Use this dispatch shape for every parallel subagent:

````markdown
Role: {explore|executor|verifier|code-reviewer|security-reviewer|qa-tester}
Story/task: {id and short title}
Scope: {owned files/directories, or read-only areas}
Do not touch: {files/directories owned by other agents}
Expected output: {patch, findings, evidence, or test result}
TDD responsibility: {RED/GREEN/REFACTOR step, exception, or none}
Verification responsibility: {command/evidence}
Coordination: You are not alone in the codebase. Do not revert, overwrite, or reformat work outside your scope. Report conflicts instead of resolving them silently.
````

After parallel work completes, integrate sequentially:

1. Inspect each subagent result and changed-file set.
2. Resolve conflicts deliberately.
3. Run story-specific verification.
4. Run cross-story verification when shared behavior could be affected.
5. Only then mark stories complete.

## Review Gate

Completion requires evidence, not confidence.

The reviewer pass is mode-gated. `LIGHT` may satisfy review through direct diff
inspection unless the selected mode or risk requires independence. `STANDARD`
uses targeted review for behavior-affecting or workflow changes. `THOROUGH`
uses independent review roles for the applicable risk.

When review is required, the reviewer pass must answer:

- Do all stories satisfy their acceptance criteria?
- Is there a simpler or safer approach that still satisfies the PRD?
- For behavior-changing work, does RED/GREEN/REFACTOR evidence exist or is an exception documented?
- Are TDD exceptions specific and justified rather than vague convenience claims?
- Are tests or verification sufficient for the risk?

If review rejects the work, return to the relevant story and continue.

## Cleanup And Final Verification

Cleanup happens only after functional review approval.

Cleanup is mode-gated:

- `LIGHT`: run `ai-slop-cleaner` only when changed files show actual cleanup candidates; otherwise record cleanup as not needed.
- `STANDARD`: run cleanup when behavior is locked and the changed files show cleanup candidates; rerun relevant verification afterward.
- `THOROUGH`: run `ai-slop-cleaner` after functional review unless explicitly disabled, then rerun verification and any focused post-cleanup review required by risk.

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
- required TDD evidence exists, or each exception is documented
- review required by the selected mode is approved or a blocking reason is documented
- `ai-slop-cleaner` ran, was explicitly disabled, or was recorded as not needed by the selected mode
- post-cleanup verification passed when cleanup changed files
- `verification-before-completion` ran for the final completion claim
- final report was written

## Output

Return:

- Session directory.
- PRD path.
- Execution mode, mode source, and policy decisions.
- Stories completed.
- Files changed.
- Cleanup status.
- Verification commands and results.
- Review verdict.
- Residual risk.

## Final Handoff

Ralph is the terminal workflow skill. After the final report, do NOT auto-invoke another workflow skill (`interview`, `ralplan`, `autopilot`). Further work needs a fresh user request and a new skill selection.

Internal mid-loop skills used during the execution loop — `test-driven-development`, `ai-slop-cleaner`, `verification-before-completion`, `systematic-debugging` — are part of Ralph's documented procedure and are NOT subject to the per-step transition question. The user has already opted into Ralph's loop by invoking it.
