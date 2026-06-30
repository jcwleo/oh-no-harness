---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, passing, implemented, verified, ready for review, safe to deliver, or when summarizing final status after edits or tests.
argument-hint: "<claim, task, plan, or changed-file scope>"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Verification Before Completion for Codex

This generated file is the Codex-facing runtime skill document. Codex should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/verification-before-completion.md`
- `../../docs/platforms/codex-runtime.md`

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

## Required Reading

Before acting on any gate below that routes a decision through a shared
contract, read that contract. A path reference here is a pointer, not a
substitute for reading: do not apply one of these rules from memory when this
skill hands a decision to it. If a listed file cannot be read, record the
blocker instead of proceeding past the gate that depends on it.

- `docs/shared/validation-check.md` — distinguishing measurable evidence from real acceptance.
- `docs/shared/ralph-subagent-policy.md` — the independent-verifier-audit carve-out.
- `docs/shared/cross-host-review.md` — the independence-mode recording for a dispatched verifier/code-reviewer and the secret-redaction convention.

## Agent Roles

| Agent | Use |
|---|---|
| `verifier` | Map the claim to evidence and run or inspect the required checks; apply the scenario lens to validate user-facing flows or scenario coverage. Cross-host merge: union/conservative. |
| `code-reviewer` | Review behavior-affecting code or workflow prompt changes when risk warrants it; apply the security lens to auth, data, file system, network, secrets, or policy-sensitive changes. Cross-host merge: merged findings. |

When the opposite host is available, run the dispatched verifier/code-reviewer roles as cross-host review per `docs/shared/cross-host-review.md` using each role's `Cross-host merge` value above; otherwise use the Same-Host Parallel Fallback.

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

<HARD-GATE>
No completion claim may be made without fresh, acceptance-mapped evidence verified in the current work pass.

Before making a completion claim, complete every step below; the claim is invalid if any step is skipped or rests on stale evidence:

1. State the exact claim to verify.
2. Identify the command, artifact, diff inspection, or checklist that can prove it.
3. Run or inspect the evidence fresh in the current work pass.
4. Read the output and exit status.
5. Compare evidence to acceptance criteria.
6. Complete the Risk Check Before Completion below.
7. Report skipped checks and residual risk.
8. For a STANDARD or THOROUGH behavior-changing claim whose proving tests or implementation were authored or accepted by the current agent, confirm an independent `verifier` audit ran per the carve-out in `docs/shared/ralph-subagent-policy.md` — this self-gate does not substitute for it (record the dispatch-unavailable fallback if the host cannot dispatch).
9. When a `verifier` or `code-reviewer` was dispatched for this claim, record its independence mode (`cross-host`, `same-host-parallel-fallback`, or `inline-fallback` with reason) per `docs/shared/cross-host-review.md`; a dispatched pass with no recorded independence mode is a named ledger gap, not a pass.
</HARD-GATE>

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
In STANDARD or THOROUGH mode, for user-facing or behavior-changing work, direct
evidence must be an artifact observed from the real surface — actual command
output, terminal or UI capture, an HTTP response body, or an equivalent observed
result. "Should work", "looks correct", and a printed or `--dry-run` command are
indirect evidence at best. This bar does not apply to LIGHT or trivial work such
as a pure-logic helper edit, which needs no captured real-surface artifact.
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
- A tautological test is not valid evidence: a test that only asserts a mock was
  called, pins a constant, or cannot fail under any plausible regression confirms
  itself, not the behavior.
- A new test does not replace a viable nearby baseline or smoke check for
  regression-sensitive work.
- For behavior-changing work, verify RED/GREEN/REFACTOR evidence or a documented TDD exception.
- When an agent reports success, inspect the changed files or artifacts before repeating the claim.
- A success status is not acceptance: an HTTP 2xx with an empty or error body,
  exit 0 with no state change, or a "done" log line without the observable
  effect is missing evidence, not a pass.
- Before recording a real-surface artifact, command output, or log as evidence —
  here or in any `.oh-no` file, PR body, or handoff — redact secrets and PII to a
  labeled placeholder, keeping only the non-sensitive shape needed (status line,
  lengths, hashes, short non-secret prefixes), per `docs/shared/cross-host-review.md`.

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
