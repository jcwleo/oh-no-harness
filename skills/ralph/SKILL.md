---
name: ralph
description: Use when implementing or executing an approved plan, PRD, spec, story list, ticket, or concrete task with acceptance criteria, required verification, or multiple implementation steps.
argument-hint: "<approved plan, PRD path, spec path, or concrete task>"
---

# Ralph

Ralph is a PRD-driven execution loop. It keeps working until each story is complete, verification passes, review is resolved, cleanup has run or been explicitly disabled, and the final report is written.

## When To Use

Use when:

- the user gives an approved plan, PRD, or concrete spec
- acceptance criteria exist or can be made explicit before editing
- the task needs durable progress tracking
- the work should not stop at "probably done"

Do not use when requirements are still vague. Use `deep-interview` or `ralplan` first.

## Artifacts

Use:

```text
.oh-no/sessions/{sessionId}/prd.json
.oh-no/sessions/{sessionId}/progress.md
.oh-no/sessions/{sessionId}/verification.md
```

If no session id exists, create a timestamped directory under `.oh-no/sessions/`.

## PRD Shape

Represent work as stories:

```json
{
  "title": "Task title",
  "stories": [
    {
      "id": "story-1",
      "description": "User-visible or maintainer-visible outcome",
      "acceptanceCriteria": [
        "Concrete criterion"
      ],
      "status": "pending",
      "passes": false
    }
  ]
}
```

If a PRD does not exist, scaffold one from the approved input before editing.

## Agent Roles

Ralph uses these roles while preserving the current platform's rules for agent use:

| Agent | Use |
|---|---|
| `explore` | Find relevant files, existing tests, commands, and integration surfaces before story implementation when they are not obvious. |
| `executor` | Implement scoped story work using the configured agent model. |
| `architect` | Review architecture-sensitive, security-sensitive, broad, or multi-system completion evidence. |
| `critic` | Optional adversarial review when the approach may be overcomplicated or the acceptance argument is weak. |
| `verifier` | Package evidence against acceptance criteria and verification tiers. |
| `code-reviewer` | Review correctness, maintainability, regressions, and missing tests. |
| `security-reviewer` | Review auth, data, secrets, file system, network, policy, or injection risk. |
| `qa-tester` | Validate user-facing flows and scenario coverage when applicable. |

`ai-slop-cleaner` is a skill, not an agent.

`verification-before-completion` and `systematic-debugging` are skills, not agents.

## Input Hardening

Before editing, make the executable scope explicit.

If the input lacks acceptance criteria, derive them from the approved request and record them in the PRD. Ask before editing when an assumption changes user-visible behavior, architecture, data handling, security posture, or delivery scope.

For each story, record:

- expected outcome
- acceptance criteria
- owned files or investigation targets
- TDD requirement or exception
- verification command or evidence type

## Execution Loop

1. Read the PRD, plan, or spec.
2. Read `docs/shared/agent-tiers.md` and `docs/shared/verification-tiers.md`.
3. Select the next incomplete story.
4. Use `explore` when files, tests, or integration surfaces are not obvious.
5. Identify files and checks.
6. Identify safe parallelization opportunities using the Parallel Subagent Policy below.
7. Classify the story's TDD requirement:
   - behavior-changing production code: TDD required
   - bug fix: reproduction test required
   - behavior-preserving refactor: characterization or regression coverage required
   - docs-only, config-only, generated code, throwaway prototype, or unavailable test harness: document the exception
8. If TDD is required, read and follow `test-driven-development` before editing production code.
9. Record RED, GREEN, and post-refactor evidence in `.oh-no/sessions/{sessionId}/verification.md`.
10. Use `executor` for scoped implementation or implement inline when the platform requires it.
11. Run the story-specific verification.
12. Mark the story complete only when acceptance criteria and required TDD evidence pass.
13. Repeat until all stories pass.
14. Run the functional review gate with `verifier`, `code-reviewer`, and when risk warrants it `architect`, `critic`, `security-reviewer`, or `qa-tester`.
15. If a check fails or behavior is unexpected, read and follow `systematic-debugging` before attempting fixes.
16. After functional reviewer approval, read and follow `ai-slop-cleaner` for the changed-file set unless the user explicitly disabled it.
17. Re-run verification after cleanup.
18. If cleanup changed non-trivial code or tests, run a focused post-cleanup `code-reviewer` or `verifier` pass.
19. Read and follow `verification-before-completion` before claiming completion.
20. Write the final report.

## Parallel Subagent Policy

Use subagents aggressively when the current platform supports them and the work can be safely isolated.

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

The reviewer pass must answer:

- Do all stories satisfy their acceptance criteria?
- Is there a simpler or safer approach that still satisfies the PRD?
- For behavior-changing work, does RED/GREEN/REFACTOR evidence exist or is an exception documented?
- Are TDD exceptions specific and justified rather than vague convenience claims?
- Are tests or verification sufficient for the risk?

If review rejects the work, return to the relevant story and continue.

## Cleanup And Final Verification

Cleanup happens only after functional review approval.

The post-cleanup pass must answer:

- Did cleanup preserve behavior?
- Did the behavior lock or relevant verification pass after cleanup?
- Did cleanup stay inside the changed-file scope?
- Is any additional code review required because cleanup changed structure, tests, or control flow?

## Persistence Rule

Continue until:

- every story has `passes: true`
- verification evidence exists
- required TDD evidence exists, or each exception is documented
- review is approved or a blocking reason is documented
- `ai-slop-cleaner` ran or was explicitly disabled
- post-cleanup verification passed
- `verification-before-completion` ran for the final completion claim
- final report was written

## Output

Return:

- Session directory.
- PRD path.
- Stories completed.
- Files changed.
- Cleanup status.
- Verification commands and results.
- Review verdict.
- Residual risk.

## Final Handoff

Ralph is the terminal workflow skill. After the final report, do NOT auto-invoke another workflow skill (`deep-interview`, `ralplan`, `autopilot`). Further work needs a fresh user request and a new skill selection.

Internal mid-loop skills used during the execution loop — `test-driven-development`, `ai-slop-cleaner`, `verification-before-completion`, `systematic-debugging` — are part of Ralph's documented procedure and are NOT subject to the per-step transition question. The user has already opted into Ralph's loop by invoking it.
