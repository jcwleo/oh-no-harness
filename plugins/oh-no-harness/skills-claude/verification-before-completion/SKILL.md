---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, passing, implemented, verified, ready for review, safe to deliver, or when summarizing final status after edits or tests.
argument-hint: "<claim, task, plan, or changed-file scope>"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Verification Before Completion for Claude Code

This generated file is the Claude Code-facing runtime skill document. Claude Code slash commands should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/verification-before-completion.md`
- `../../docs/platforms/claude-code.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/verification-before-completion.md

# Verification Before Completion

Do not claim success without fresh evidence.

This skill is both a standalone lightweight final gate and the final evidence gate inside `ralph` and `ultrawork`. When those stronger workflows are active, use this skill to verify the final claim without weakening their PRD, review, cleanup, or QA requirements.

## Software Development Stage

Verification Before Completion is the final evidence stage.

Use it after implementation, debugging, cleanup, and relevant review are done, immediately before claiming the work is complete, fixed, passing, ready, or safe to deliver.

## When To Use

Use before saying that:

- a task is complete
- a bug is fixed
- tests, lint, build, install, or smoke checks pass
- a plugin, skill, hook, or agent is ready
- a branch or artifact is ready for user review

Do not use as a substitute for `ralph` when the work needs PRD tracking, cleanup, and review loops.

## Agent Roles

| Agent | Use |
|---|---|
| `verifier` | Map the claim to evidence and run or inspect the required checks; apply the scenario lens to validate user-facing flows or scenario coverage. |
| `code-reviewer` | Review behavior-affecting code or workflow prompt changes when risk warrants it; apply the security lens to auth, data, file system, network, secrets, or policy-sensitive changes. |

On subagent-capable hosts, dispatch `verifier` for nontrivial completion claims
when independent evidence mapping can change the ship/block decision or expose
residual risk. Add a `code-reviewer` subagent (security lens included) when the
changed scope, selected verification tier, or user-facing risk warrants it;
`verifier` applies its scenario lens when user-facing behavior changed.
Inline verification is appropriate only for tiny direct checks with no
context-separation benefit or when dispatch is unavailable; record that fallback
or no-benefit reason before making the claim.

Apply the active platform's dispatch authorization for the eligible `verifier`
and risk-gated `code-reviewer` roles in this skill. Do not ask for per-run
subagent approval when the active platform already supplies standing
authorization for those evidence or review roles, the claim is nontrivial, risk
warrants them, and the role output can change the completion decision.

When any verification role is dispatched, apply the active platform's role
prompt and dispatch requirements before the claim, evidence scope, expected
output, and no-edit instruction for read-only review roles.

## Required Gate

Before making a completion claim:

1. State the exact claim to verify.
2. Identify the command, artifact, diff inspection, or checklist that can prove it.
3. Run or inspect the evidence fresh in the current work pass.
4. Read the output and exit status.
5. Compare evidence to acceptance criteria.
6. Complete the Risk Check Before Completion below.
7. Report skipped checks and residual risk.

If no meaningful command exists, inspect the changed files and write a manual verification checklist instead of implying automated confidence.

When measurable evidence influenced the work, also apply
`docs/shared/validation-check.md`. Treat that evidence as a diagnostic
signal, not as the acceptance criteria.

## Acceptance-To-Evidence Mapping

Do not treat a command list as proof by itself. Before claiming completion,
map each acceptance criterion or requested behavior to concrete evidence:

```text
Acceptance-to-evidence mapping:
- Criterion:
  - Evidence:
  - Coverage strength: direct | indirect | manual | missing
  - Gap or residual risk:
```

Direct evidence is a focused test, scenario, or inspection that would fail if
the requested behavior were absent or wrong. Indirect evidence, broad suites,
lint, typecheck, formatting, and compile checks are useful support, but they do
not replace direct acceptance evidence for behavior-changing work.
New tests are supporting evidence, not sufficient completion proof, when nearby
existing tests, smoke checks, or behavior-preserving inspections are available
and could catch regressions.

## Risk Check Before Completion

Before final completion, actively look for the most likely way local green
evidence could still miss the real user, maintainer, or uncovered behavior.
Keep the questions category-level and requirements-driven instead of
case-specific.

Record:

```text
Risk check before completion:
- Acceptance criteria covered by direct evidence:
- Acceptance criteria only covered indirectly:
- Contract surface and semantic model checked:
- Baseline guard: existing test, smoke, inspection, or no viable baseline reason:
- Likely failure-taxonomy risk a skeptical maintainer would test:
- One more useful failing test I would write if time allowed:
- Completion claim:
```

The completion claim should distinguish:

- complete with direct evidence, baseline guard satisfied or unavailable with reason, and no blocking review findings
- locally verified with explicit residual risk
- blocked or failed verification because evidence or review blockers remain

## Validation Check

For evidence-informed work, record a `Validation check` using the canonical
template in `docs/shared/validation-check.md`. Include the evidence used, the
supported acceptance criterion or user outcome, proof and gap, recurring risk
addressed, similar-work expectation, excluded case-specific details, added
process cost, and completion claim.

Reject completion claims whose only support is metric movement, unseen-check
guessing, task-name-specific guidance, or a measurable metric that does not match the
real user, maintainer, operator, or public contract.

## Evidence Rules

- A previous run is not fresh evidence unless no file or dependency changed since that run.
- A passing lint check does not prove tests pass.
- A passing unit test does not prove a user-facing flow works when the acceptance criteria require the flow.
- A broad suite pass does not prove a new semantic contract unless the new
  behavior is directly represented in that suite.
- A local test that would pass against the wrong public, caller, or
  verifier-facing surface does not prove the real contract.
- A new test does not replace a viable nearby baseline or smoke check for
  regression-sensitive work.
- For behavior-changing work, verify RED/GREEN/REFACTOR evidence or a documented TDD exception.
- When an agent reports success, inspect the changed files or artifacts before repeating the claim.

## Output

Return:

- Claim verified.
- Evidence used.
- Commands or inspections performed.
- Acceptance criteria status.
- Acceptance-to-evidence mapping.
- Contract surface and baseline guard status.
- Risk check before completion and completion claim.
- Validation check and risk from metric-only evidence when applicable.
- Skipped checks and reason.
- Residual risk.

## Next Skill Handoff

None — this is the final evidence gate. Return the result to the caller (`ralph`, `ultrawork`, or direct invocation). Do not chain to another workflow skill.

## Source: docs/platforms/claude-code.md

# Claude Code Platform Rules

This platform section is source content for generated Claude Code-facing
runtime skill documents.

## Skill Loading

Claude Code-facing public skills live under `skills-claude/`. Files in
`skills-claude/<skill>/SKILL.md` are generated runtime documents composed from
the matching `docs/skill-core/<skill>.md` file, this Claude Code platform file,
and any Claude Code skill-specific overlay such as
`docs/platforms/claude-code-<skill>.md`.

Claude slash commands must delegate to `skills-claude/<skill>/SKILL.md` so the
model sees the generated Claude Code runtime document for that skill.

## User Approval

When asking the user for approval, preference, scope, or next-step selection,
use the available structured question tool when the host exposes one. Prefer one
focused question at a time. For option questions, provide a small set of
mutually exclusive choices and put the recommended option first when there is a
clear recommendation.

If a structured question tool is unavailable, ask in plain text and wait for the
user's answer. Present options as actions the host agent will take. Do not tell
the user to run a command manually when the skill handoff expects the host agent
to invoke the next skill.

## Task Tracking

When a core skill has a multi-phase approval handoff and the host exposes task
tracking, create one task per phase and complete them sequentially. Do not
collapse content approval and next-step selection into one hidden step.

## Auto Routing

The `auto-routing` skill controls whether the Claude Code SessionStart hook adds
stronger skill-selection guidance to `using-oh-no-harness`.

Preferred config location:

```text
$HOME/.claude/plugins/data/<oh-no-harness-*>/config.json
```

When `CLAUDE_PLUGIN_ROOT` is set, use:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" status
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" on
"${CLAUDE_PLUGIN_ROOT}/scripts/oh-no-config" off
```

Changes take effect on the next Claude Code `SessionStart`, such as a new
session, app restart, `/clear`, or compaction.

## Anthropic-Aligned Prompting

This file carries the runtime-sized Anthropic guidance for Claude Code. The
longer maintenance reference lives in `docs/providers/anthropic.md`, but
generated Claude Code-facing runtime skill documents do not include provider
docs as an extra runtime source.

For Anthropic/Claude models, keep instructions explicit and sectioned:

- state scope, non-goals, constraints, approval gates, and expected evidence in
  stable headings or tagged sections
- avoid relying on implication; say what the agent may do, must not do, and must
  ask before changing
- give one focused user question at a time when approval or direction is needed
- preserve long-running context in artifacts before compaction, task handoff, or
  subagent dispatch
- keep final answers concise unless the active skill requires a structured plan,
  review, or verification report

When the host exposes extended thinking or effort controls, use higher effort
for agentic coding, architecture review, plan critique, and ambiguous debugging.
Use lower effort for small, already-bounded edits.

## Role Dispatch

Claude Code subagent descriptions are delegation metadata. Generated
`agents/*.md` descriptions may keep the `Use proactively` trigger so Claude can
select useful role agents, but they must bind that proactivity to active Oh No
Harness workflows and caller-owned approval and handoff gates. The agent body
contains the stable role contract; the Task, Agent, or Workflow prompt supplies
the current story scope, acceptance criteria, contract surface, baseline guard,
expected output, and lifecycle.

Use the available Task, Agent, Workflow `agent()`, or subagent mechanism for
role dispatch. Prefer plugin-scoped agents named `oh-no-harness:<role>` when
the host lists them.

For independent read-only, review, verification, QA, security, or exploration
work, request background subagents and start the whole independent batch before
waiting for any one result.
When a skill requires an atomic same-phase batch, prefer Workflow `Promise.all`
if available; direct Task or Agent background notifications may arrive before
the model has emitted later task requests, so do not inspect or summarize those
results until the full intended batch has been requested.

After a Claude Code subagent reaches a final status, capture the output and any
changed-file set before cleanup. When no further input is needed, close or clean
up the completed subagent with the mechanism exposed by the host; if none is
available, record that fallback.

For approved `ralplan` handoffs to ordinary `oh-no-harness:ralph`, treat
`Parallel trigger: approved-plan-handoff` as dispatch authorization for
eligible isolated roles. Do not require a separate `ralph with parallel
subagents` option when the plan already lists roles whose output can change the
implementation, review, verification, or ship/block decision.

If plugin-scoped agents are unavailable, keep the same role boundary by
embedding the matching `agents/<role>.md` prompt into the available subagent
mechanism. If no dispatch mechanism is available, keep the role inline and
record the fallback reason when the core skill requires it.
