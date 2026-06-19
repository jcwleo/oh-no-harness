---
name: systematic-debugging
description: Use when a bug, failing test, failing command, regression, flaky behavior, build failure, install failure, hook failure, unexpected output, or unknown root cause needs investigation before fixes.
argument-hint: "<failure, command, bug report, or unexpected behavior>"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Systematic Debugging for Codex

This generated file is the Codex-facing runtime skill document. Codex should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/systematic-debugging.md`
- `../../docs/platforms/codex.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/systematic-debugging.md

# Systematic Debugging

Find the root cause before changing behavior.

This skill is the direct debugging entry point for failures that do not need the full `ralph` execution loop.

## Software Development Stage

Systematic Debugging is the failure-investigation and repair stage.

Use it when tests, builds, runtime behavior, installs, hooks, or user reports show a concrete failure. It should establish reproduction and root cause before returning to implementation or verification.

## When To Use

Use for:

- failing tests, builds, installs, hooks, or smoke checks
- regressions and unexpected behavior
- flaky or environment-sensitive behavior
- performance or integration failures
- repeated unsuccessful fixes

Do not use for greenfield feature work. Use `ralplan` or `ralph` when the task is broader than a bounded failure.

## Agent Roles

Use the listed roles as the failure requires. On subagent-capable hosts, use
isolated diagnostic and evidence roles when they provide decision-changing
evidence, context separation, or latency benefit so logs, traces, and
exploratory output do not pollute the main thread. The normal flow is diagnostic first
(`debugger` and, when context is missing, `explore`), then the minimal fix
(`executor` subagent when the write scope is isolated, otherwise inline with a
recorded reason), then evidence (`verifier`). `plan-reviewer` is a
conditional escalation role, not a required final step: use it immediately when
three fix attempts fail, architecture-level coupling appears, or the apparent
fix would change broad APIs, product behavior, data handling, security, or
delivery scope. Dispatch is governed by the active skill's platform policy and
Ralph's `## Mode-Gated Agent Dispatch` when this debugging pass is inside Ralph.
For direct debugging outside Ralph, apply `docs/shared/ralph-subagent-policy.md`
and `docs/shared/parallel-subagents.md` for role isolation, fallback reasons, and
eligible batch dispatch.

Apply the active platform's dispatch authorization for this skill's diagnostic,
fix, evidence, and post-fix review roles. Do not ask for per-run subagent
approval when the active platform already supplies standing authorization for
eligible `debugger`, `explore`, isolated `executor`, `verifier`, conditional
`plan-reviewer`, or warranted post-fix review roles. Use inline fallback only
when dispatch is unavailable, unsafe to isolate, or too small to benefit, and
record the fallback reason.

Respect the active platform runtime document for dispatch versus inline
execution. Do not collapse diagnostic or evidence roles inline when the host can
dispatch them with an isolated scope. When any listed role is dispatched, apply
the active platform's role prompt and dispatch requirements before the
task-specific failure, scope, expected output, and verification responsibility.

| Agent | Dispatch (when) |
|---|---|
| `debugger` | Dispatch `debugger` subagent to reproduce the failure, identify root cause, and recommend the minimal fix. |
| `explore` | Dispatch `explore` subagent to gather codebase facts, related call sites, working examples, and commands. |
| `executor` | Dispatch `executor` subagent to apply the minimal fix only after root cause and reproduction evidence exist. |
| `verifier` | Dispatch `verifier` subagent to confirm the fix and package evidence; its scenario lens covers post-fix validation when the failure affects user-facing flows, scenarios, or acceptance criteria. |
| `plan-reviewer` | Dispatch `plan-reviewer` subagent as a conditional escalation to reassess direction after three failed fix attempts, when architecture-level coupling is exposed, or before broad API/product/data/security/scope changes. |
| `code-reviewer` | Dispatch `code-reviewer` post-fix when the changed code is nontrivial, shared, workflow-affecting, or maintainability-sensitive, or when its security lens is needed because auth, data, file system, network, secrets, sandbox, or policy-sensitive behavior is touched. |

## Debugging Flow

1. Capture the exact failure command, input, environment, or user-visible symptom.
2. Reproduce the failure, or explain why it cannot be reproduced yet.
3. Read the relevant error output, logs, stack trace, and changed files.
4. Find the closest working example in the same codebase.
5. Build a hypothesis ledger before deep investigation:
   - For obvious, localized failures, record the single active hypothesis and
     why additional hypotheses would not change the next diagnostic step.
   - For unknown, nontrivial, flaky, repeated, or cross-boundary failures,
     record 2-3 plausible competing hypotheses before investigating any one
     deeply.
   - For each ledger entry, name the expected confirming evidence, expected
     refuting evidence, current confidence, and the smallest diagnostic step.
6. Select one active root-cause hypothesis from the ledger with evidence.
7. Test the active hypothesis with the smallest diagnostic step, update the
   ledger, and reject or replace the hypothesis when evidence contradicts it.
8. Trace the causal chain from the observed symptom back to the source that made
   the symptom possible. Do not accept a fix plan that only removes the visible
   trigger while leaving the failure mode latent.
9. For behavior fixes, read and follow `test-driven-development` to create a
   failing reproduction test before changing production code.
10. If reproduction and hypothesis evidence exist but the diagnosis remains
    contradictory, repeatedly inconclusive, or blocked after ordinary diagnostic
    passes, read and follow `fusion-rescue`. Return control to
    Systematic Debugging with the synthesis before applying a fix.
11. Apply the minimal fix with `executor` when the write scope is isolated; use
    inline work only with a recorded reason.
12. Dispatch warranted post-fix review roles when the changed scope or risk
    requires them.
13. Run the reproduction check, relevant regression checks, and
    `verification-before-completion` before claiming the failure is fixed. The
    verification evidence must show that the failure mode is gone, not only that
    the current trigger no longer appears in this environment.

Parallel hypothesis testing for steps 5-7: when reproduction is established and
two or more plausible root-cause hypotheses are independently testable, dispatch
one `debugger` subagent per hypothesis (cap 3) in a single batch. Step 6's
one-active-hypothesis rule applies per debugger agent: each parallel debugger
receives exactly one hypothesis, the confirming/refuting evidence it should look
for, and its read-only diagnostic scope. Each parallel debugger runs only
non-mutating diagnostics in disjoint scopes and returns evidence, confidence
movement, and rejected-hypothesis rationale; if diagnostics would mutate state
or scopes overlap, keep the sequential one-active-hypothesis flow above. The
main thread synthesizes the returned evidence, selects the confirmed root cause,
and a single `executor` applies the fix. Below two hypotheses, or when
hypotheses are not independently testable, the sequential flow above applies
unchanged.

## Stop Conditions

Stop and ask or escalate to `plan-reviewer` when:

- the failure cannot be reproduced and more data is needed from the user
- a `plan-reviewer` escalation trigger from `## Agent Roles` fires (repeated
  failed fix attempts; broad architecture or API scope; product behavior,
  data handling, security, or delivery-scope ambiguity)

## Anti-Patterns

- Changing code before reproducing or locating the failure.
- Fixing the stack-trace line when the bad value originated elsewhere.
- Bundling cleanup or refactors with a bug fix.
- Adding broad retries, catch-all handlers, or sleeps without evidence.
- Treating a later passing test as TDD evidence when no failing reproduction was
  observed first.
- Treating a passing trigger check as proof when the underlying failure mode or
  causal chain was not closed.
- Skipping competing hypotheses for an unknown or repeated failure because one
  log line looks familiar.

## Output

Return:

- Failure reproduced or reproduction blocker.
- Hypothesis ledger, including rejected hypotheses and evidence.
- Root cause and evidence.
- Causal chain and why the fix removes the failure mode.
- Reproduction test or documented exception.
- Fix summary.
- Verification commands and results.
- Residual risk.

## Next Skill Handoff

None — this is a failure-investigation mid-loop skill. It may use
`fusion-rescue` as a bounded internal escalation when ordinary diagnostics
stall, then return to this debugging flow. After verification, return the result
to the caller (`ralph`, `ultrawork`, or direct invocation). Do not chain to
another workflow skill.

## Source: docs/platforms/codex.md

# Codex Platform Rules

This platform section is source content for generated Codex-facing runtime
skill documents.

## Skill Loading

Codex-facing public skills live under `skills/`. Files in
`skills/<skill>/SKILL.md` are generated runtime documents composed from the
matching `docs/skill-core/<skill>.md` file, this Codex platform file, and any
Codex skill-specific overlay such as `docs/platforms/codex-<skill>.md`.

## User Approval

When a core skill asks for approval, preference, scope, or next-step selection,
ask the user directly in the current Codex conversation. Present options as
actions the host agent will take. Do not tell the user to run a command manually
when the skill handoff expects the host agent to invoke the next skill.

## Auto Routing

The `auto-routing` skill can explain and preserve the config file shape in
Codex, but it does not add forced routing to Codex SessionStart. Codex native
skill loading remains the primary routing surface. If Codex-facing
SessionStart hooks run, they must stay compact and must not embed full skill
core bodies.

## OpenAI-Aligned Prompting

This file carries the runtime-sized OpenAI guidance for Codex. The longer
maintenance reference lives in `docs/providers/openai.md`, but generated
Codex-facing runtime skill documents do not include provider docs as an extra
runtime source.

For OpenAI/Codex models, keep prompts outcome-first:

- state the desired outcome, acceptance criteria, non-goals or side effects,
  and expected evidence before detailed steps
- keep tool and role instructions close to the place where the tool or role is
  used
- specify output shape for plans, reviews, verification, and final reports
- use compact final answers unless the active skill requires an evidence log or
  approval brief
- preserve durable state in written artifacts before long work, compaction, or
  handoff

When the host exposes reasoning or verbosity controls, use the lightest setting
that can produce credible evidence. Raise effort for broad planning, deep code
review, hard debugging, or multi-agent integration; lower it for small,
mechanical, or already-isolated work.

## Role Dispatch

Codex role dispatch is host-policy controlled. Use `spawn_agent` only when the
current host tool definition exposes it, the active skill permits dispatch, and
the role has an isolated read-only scope, disjoint write ownership, or an
independent review or verification responsibility.

When dispatching an Oh No Harness role in any Codex context, including active
skills, approved plan handoffs, SessionStart-authorized read-only exploration,
or general user-requested subagent work outside a selected skill, use the
registered custom agent first. If the host recognizes or accepts
`oh-no-<role>`, call
`spawn_agent(agent_type="oh-no-<role>", ...)`. Do not choose built-in
`explorer`, `worker`, `default`, or a prompt-embedded generic subagent for an Oh
No Harness role while the matching registered custom agent is available.
Do not infer custom-agent unavailability from rendered schema text, display
comments, or uncertainty. Generic/default fallback is allowed only inside an
active Oh No Harness workflow or explicit user-requested subagent task after an
actual `agent_type="oh-no-<role>"` attempt is rejected as unknown or unavailable
and the confirmed fallback reason is recorded. The no-skill read-only
exploration lane below must not use generic/default fallback.

Do not combine `agent_type = "oh-no-<role>"` with `fork_context = true` or any
full-history fork request. Codex full-history forks inherit the parent agent
configuration and cannot be used with a custom role agent type. Put the required
scope, constraints, and evidence context in the spawned-agent message instead.
Use one spawn payload shape only: prompt/message or items, never both.

Explicit user or plan wording such as `subagent`, `spawn`, `delegate`,
`parallel agents`, `parallel subagents`, or `one agent per` is sufficient when
the host permits dispatch. A user standing preference, approved plan profile, or
active Oh No Harness skill policy to use eligible subagents proactively is also
workflow-level authorization, so the user does not need to repeat literal
subagent wording on every Ralph step. Eligibility still depends on isolation and
decision-changing value, not authorization alone.

When the Codex SessionStart context includes
`CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION`, treat that standing
authorization as the explicit user request for Oh No Harness sub-agents,
delegation, and parallel agent work in the current session. Do not ask a
separate per-run approval question merely to use eligible subagents inside an
active Oh No Harness workflow.

When the user, plan, or skill states a standing preference to maximize
subagents, treat that as explicit authorization for eligible isolated roles
inside the active workflow. Keep Codex host-policy limits, but do not require
the user to repeat literal subagent wording on every step. Do not dispatch a
role whose output would not change the implementation, review, verification, or
ship/block decision.

When no explicit request, standing preference, approved plan trigger, or active
skill dispatch policy exists, do not spawn Codex subagents merely because a role
could be named. Keep the role inline and record the fallback reason when the
core skill requires it.

The only no-skill exception is the Codex SessionStart block named
`CODEX_ONLY_OH_NO_READONLY_EXPLORATION_DELEGATION`. It authorizes one
exploration subagent for simple read-only repository fact lookup prompts such as
locating logic, tracing a symbol, identifying related tests, or summarizing an
existing file/config path. It does not authorize planning, debugging,
implementation, review (security lens included), scenario QA, completion
verification, ambiguous-requirements work, or file edits. It must not read or
reproduce secrets unless the user explicitly asks for that sensitive lookup, and
credential values must be redacted in subagent output. This no-skill lane may
dispatch only the registered read-only `oh-no-explore` custom agent when the
current host recognizes it; if that agent is unavailable, answer inline instead
of falling back to a generic or prompt-embedded subagent. If `agent_type =
"oh-no-explore"` is rejected as unknown or unavailable, do not retry with a
generic subagent for this lane. When this lane spawns `oh-no-explore`, use
`wait_agent` as the next lifecycle tool for that receiver, repeated until it
returns that receiver with final status `completed`, before calling
`close_agent`; a timeout, empty wait, or no-completion result is not captured
evidence. `close_agent` output is not a substitute for the required wait result
and must not be the first result capture. The forbidden order is `spawn_agent`
then `close_agent`. Even if `close_agent` returns output, that output is not
valid first result capture. If you will not call `wait_agent` first, do not
spawn; perform the lookup inline.

For approved `ralplan` handoffs to ordinary `oh-no-harness:ralph`, treat
`Parallel trigger: approved-plan-handoff` as dispatch authorization for
eligible isolated roles. Do not require a separate `ralph with parallel
subagents` option when the plan already lists roles whose output can change the
implementation, review, verification, or ship/block decision.

For `ralplan`, Planner and Plan-Reviewer keep sequential role boundaries:
Planner produces the draft, then Plan-Reviewer reviews that draft. Dispatch them
as sequential subagents when the active host supports dispatch and independent
context can improve planning or review; otherwise keep separate inline role
blocks. A re-review dispatch happens only when blocking findings require a
Planner revision.

After `wait_agent` returns a final status for any Codex-dispatched role,
capture the output and any changed-file set before cleanup. A timeout, empty
wait result, or "No agents completed yet" result is not a final status and is
not permission to close the subagent. Hard rule: MUST NOT call `close_agent`
for a running or pending subagent merely because it is slow. Leave the subagent
running, wait longer when its result is still needed, continue with
non-overlapping local work, or record the role as pending or blocked. Close
without a captured final result only when the user explicitly cancels or stops
that subagent, the task scope invalidates the work, the spawn was duplicate or
mis-scoped, or continuing creates a safety, security, or filesystem risk. Record
that close as cancelled or abandoned and never use missing output as completion
evidence. When no further input is needed for a completed, failed, cancelled,
user-cancelled, scope-invalidated, or unsafe subagent, call `close_agent` and
record the result.

When dispatch is unavailable, keep the same role boundary inline and record the
fallback reason when the core skill requires it.

## Optional Named Custom Agents

Oh No Harness Codex custom-agent templates are installed in user scope by
default with `scripts/install-codex-agents`. User scope means
`$CODEX_HOME/agents` when `CODEX_HOME` is set, otherwise
`$HOME/.codex/agents`. Project scope means `.codex/agents`.

Custom agents are standalone TOML files under those `agents/` directories; they
are not defined inside `config.toml`. Codex `[agents]` config entries are global
subagent settings, not individual Oh No Harness role definitions.
Generated Codex custom-agent descriptions stay role-only. Their
`developer_instructions` provide the stable role contract, while the
`spawn_agent` message supplies the current story scope, acceptance criteria,
contract surface, baseline guard, expected output, and lifecycle.

Codex `SessionStart` runs a best-effort user-scope quiet ensure with
`scripts/install-codex-agents --scope user --ensure --quiet`. It installs
missing generated files and refreshes stale generated files without adding
success output to the session context. If installation fails or an unmarked user
file blocks ensure, SessionStart keeps running and adds only a compact fallback
warning.

When a Codex Ralph prompt is detected, the Ralph platform adapter repeats the
same quiet ensure as a fallback before injecting dispatch guidance. Generated
files include the installed plugin version marker, so a later plugin update can
refresh stale `oh-no-*` agent definitions during SessionStart or Ralph fallback
without requiring a repeated user prompt. If ensure fails or an unmarked user
file blocks it, record the ensure failure but do not treat that failure alone
as permission for generic prompt-embedded fallback. Continue with
`agent_type = "oh-no-<role>"` if the current host recognizes that custom agent;
use generic prompt-embedded fallback only after confirmed custom-agent
unavailability and record that fallback reason.

Files ensured on disk are not the same thing as same-session named-agent
availability. Use `agent_type = "oh-no-<role>"` whenever the current Codex host
recognizes that registered custom agent. Inside an active Oh No Harness
workflow, use the generic prompt-embedded fallback below or built-in `explorer`
only after the host returns `unknown agent_type` or an equivalent explicit
rejection for `oh-no-<role>`, or the user-scope templates are unavailable and
the host cannot recognize the custom agent. Outside an active workflow, the
no-skill read-only exploration lane must stay inline unless registered
`oh-no-explore` is available.
The generated `oh-no-explore` template sets `sandbox_mode = "read-only"` so the
no-skill exploration lane does not rely on prompt text alone for write
isolation.

The generated templates pin `gpt-5.5` and a per-agent
`model_reasoning_effort` so custom-agent role files do not depend on
inheriting a user-specific model layer.

When the active Codex host recognizes a registered custom agent, `agent_type =
"oh-no-<role>"` is the required path for Oh No Harness role dispatch. If the
host returns an unknown `agent_type`, or if the user-scope templates are not
installed and the host cannot recognize the agent, fall back to the
prompt-embedded dispatch contract below and record the confirmed fallback
reason. Do not infer unavailability from memory, stale examples, display names,
rendered schema comments, or uncertainty about the schema.

Custom-agent dispatch must pass context through the message and leave
full-history forking disabled. If a role truly needs the entire parent history,
keep that role inline or use a host-supported non-custom fork path and record the
fallback reason. Do not send both message and items in one spawn request.

## Role Prompt Embedding

When using generic Codex agent types, read the matching
`docs/agent-core/<role>.md` file and embed that platform-neutral prompt body in
the spawned-agent message. Do not rely on the role name alone unless the
registered `oh-no-<role>` custom agent supplies the role developer
instructions.

If `docs/agent-core/<role>.md` is unavailable but `agents/<role>.md` exists,
strip the Claude Code YAML frontmatter before embedding. Claude-only
frontmatter such as `tools`, `model`, `background`, `isolation`, or `color` is
metadata for Claude Code and must not be included in Codex spawned-agent prompt
content.

Every generic Codex role dispatch must include:

```text
Agent prompt source: docs/agent-core/<role>.md
Agent prompt content:
<matching docs/agent-core/<role>.md prompt content>
```
