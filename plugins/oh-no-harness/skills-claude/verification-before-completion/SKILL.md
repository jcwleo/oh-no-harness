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
- `../../docs/platforms/claude-code-runtime.md`

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
- `docs/shared/cross-host-review.md` — the independence-mode recording for a dispatched `code-reviewer` and the secret-redaction convention.
- `docs/shared/failure-taxonomy.md` — the risk labels the Risk Check Before Completion records.

## Agent Roles

| Agent | Use |
|---|---|
| `verifier` | Map the claim to evidence and run or inspect the required checks; apply the scenario lens to validate user-facing flows or scenario coverage. An unconditionally single self-host independent pass, never a cross-host or same-host pair. |
| `code-reviewer` | Review behavior-affecting code or workflow prompt changes when risk warrants it; apply the security lens to auth, data, file system, network, secrets, or policy-sensitive changes. Cross-host merge: merged findings. |

When the opposite host is available, run the dispatched `code-reviewer` role as cross-host review per `docs/shared/cross-host-review.md` using its `Cross-host merge` value above; otherwise use the Same-Host Parallel Fallback. The dispatched `verifier` is out of cross-host scope — an unconditionally single self-host independent pass (never a cross-host or same-host pair) — governed by the maker-verifier carve-out.

On subagent-capable hosts, dispatch `verifier` for nontrivial completion claims
when independent evidence mapping can change the ship/block decision or expose
residual risk. Add a `code-reviewer` subagent (security lens included) when the
changed scope, selected verification tier, or user-facing risk warrants it;
`verifier` applies its scenario lens when user-facing behavior changed.
Inline verification is appropriate only for tiny direct checks with no
context-separation benefit or when dispatch is unavailable; record that fallback
or no-benefit reason before making the claim.

Confirming-verifier reuse: when this skill runs as the final gate inside
`ralph` or `ultrawork` and the caller already completed the required
independent confirming `verifier` pass for the same final claim, and no file,
dependency, or evidence changed after that pass (the Evidence Rules'
unchanged-evidence bar: a previous run is not fresh evidence unless nothing it
depends on changed), do not dispatch a second `verifier` for that claim. A
compliant pass ran as an independent dispatch (never the maker) after the
code-reviewer pair completed, per the maker-verifier carve-out in
`docs/shared/ralph-subagent-policy.md`. Record the reused pass (as a reference to
the caller's ledger entry for it) and that it ran after reviewer completion under
the carve-out. This reuse satisfies only the verifier-dispatch expectation above: every
Required Gate step still executes in full (currently steps 1–9), and this
clause never licenses skipping this skill itself. Dispatch a fresh `verifier`
when evidence changed after the caller's pass or when no compliant pass
exists.

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
9. When a `code-reviewer` was dispatched for this claim, record its independence mode (`cross-host`, `same-host-parallel-fallback`, or `inline-fallback` with reason) per `docs/shared/cross-host-review.md`; a dispatched pass with no recorded independence mode is a named ledger gap, not a pass.
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
- Likely `docs/shared/failure-taxonomy.md` risk a skeptical maintainer would test:
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

Use the available Task, Agent, Workflow `agent()`, or subagent mechanism for
role dispatch. Prefer plugin-scoped agents named `oh-no-harness:<role>` when
the host lists them.

For independent read-only, review, verification, QA, security, or exploration
work, request background subagents and start the whole independent batch before
waiting for any one result. When a skill requires an atomic same-phase batch,
prefer Workflow `Promise.all` if available; otherwise do not inspect or
summarize early task results until the full intended batch has been requested.

After a Claude Code subagent reaches final status, capture the output and any
changed-file set before cleanup. When no further input is needed, close or
clean up the completed subagent with the mechanism exposed by the host; if none
is available, record that fallback.

For approved `ralplan` handoffs to ordinary `oh-no-harness:ralph`, treat
`Parallel trigger: approved-plan-handoff` as dispatch authorization for
eligible isolated roles. Do not require a separate `ralph with parallel
subagents` option when the plan already lists roles whose output can change the
implementation, review, verification, or ship/block decision.

If plugin-scoped agents are unavailable, keep the same role boundary by
embedding the matching `agents/<role>.md` prompt into the available subagent
mechanism. If no dispatch mechanism is available, keep the role inline and
record the fallback reason when the core skill requires it.

## Cross-Host Consult Channel

This is the shared cross-host consult mechanism used by Fusion Rescue and by
cross-host review (`docs/shared/cross-host-review.md`). On Claude Code the
opposite host is Codex. This section carries only the Claude-to-Codex
invocation; the activation, synthesis, and recursion-guard semantics live in the
calling skill core and the shared doc.

From Claude Code, the current-host main agent consults Codex only by dispatching
the dedicated read-only consult agent `oh-no-harness:<role>-codex` for the
assigned opposite-host leg, where `<role>` is `plan-reviewer`, `code-reviewer`,
or `debugger` for shared cross-host review, or `fusion` for a Fusion Rescue panel
slot. That consult agent resolves the Codex companion path and runs one
synchronous, read-only `codex-companion.mjs task` call: it omits the write flag
so the companion sandbox is read-only — best-effort, not a guarantee: per host
limits shell execs are not guaranteed confined, and the caller accepts that
residual risk (see the consult agent cores) — and it never runs the call as a
detached background job. If the companion is unavailable or unresolvable, treat the
opposite host as unavailable; in default mode the calling skill applies the
shared cross-host contract's Same-Host Parallel Fallback
(`docs/shared/cross-host-review.md`), and require-cross-host mode blocks. Name the
failure class and the current-host fallback.

The consult must return Codex's actual assigned analysis synchronously. The
`codex-companion.mjs` call passes the scoped, redacted packet with `--prompt-file`
and must not run in the background. A response that only acknowledges a queued or
background job — text that a task started in the background with a status command
for a job id — is not a valid opposite-host response; treat it as no Codex
response and degrade (default) or block (require-cross-host). Do not poll status
or fetch a deferred result to compensate; the consult call itself must return the
analysis.

For shared cross-host review, the packet the `oh-no-harness:<role>-codex` agent
sends must instruct Codex to dispatch the matching `oh-no-<role>` role agent for
the assigned opposite-host pass, where `<role>` is `plan-reviewer`,
`code-reviewer`, or `debugger`. Codex must wait for that dispatched role agent and
return its assigned role result, and the consult agent must require role-ownership
proof that the dispatched role agent — not a parent inline Codex answer — produced
it. A direct Codex parent answer is not a
valid opposite-host shared review response. If Codex cannot dispatch the matching
role agent, or the role-ownership proof is missing, treat the opposite host as
unavailable in default mode or block in require-cross-host mode; do not accept
inline Codex parent analysis as the cross-host pass. Role ownership is best-effort
— there is no host selector that forces it — so it is required and proven, not
assumed.

Fusion Rescue panel slots remain governed by the Fusion Rescue panel contract;
the role-agent requirement above applies only to shared cross-host review. The
`oh-no-harness:fusion-codex` panel slot dispatches `oh-no-fusion-rescue-analyst`
for one assigned lens (see `docs/platforms/claude-code-fusion-rescue.md`).

The outbound packet must request only the assigned analysis and must forbid the
opposite host from invoking further rescue, another workflow skill, or any
host-to-host call back to Claude Code or a third host (one cross-host hop).
Redact secrets before sending; on failure record only the failure class and
companion/path/auth status, never secret values.
