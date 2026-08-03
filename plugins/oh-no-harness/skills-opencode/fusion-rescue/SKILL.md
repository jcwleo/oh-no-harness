---
name: fusion-rescue
description: Use when the user explicitly requests rescue or multi-agent synthesis, or a hard problem remains stalled after ordinary analysis/debugging; not for first-pass planning/debugging or routine implementation.
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Fusion Rescue for OpenCode

This generated file is the OpenCode-facing runtime skill document. OpenCode should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/fusion-rescue.md`
- `../../docs/platforms/opencode-runtime.md`
- `../../docs/platforms/opencode-fusion-rescue.md`

The sections below are already composed for this platform. Do not ask the runtime model to load another platform's runtime document or invocation syntax.

## Source: docs/skill-core/fusion-rescue.md

# Fusion Rescue

Fusion Rescue is a bounded deliberation skill. It borrows the compound-model
shape of inference-time ensemble systems: multiple panel analyses first, then a
single judge/synthesis pass by the current host main agent.

It is not weight fusion, model merging, OpenRouter API integration, a bridge
daemon, or a hidden runtime. It is a Markdown workflow for difficult cases where
one normal analysis path has stopped producing useful progress.

## Software Development Stage

Fusion Rescue is an escalation and synthesis stage.

Use it standalone when the user explicitly asks for `fusion-rescue` or asks for
multi-agent rescue analysis. Inside another workflow, use it only
after the selected workflow's ordinary analysis, debugging, or review loop is
blocked, inconclusive, or repeatedly failing.

## When To Use

Use for:

- a hard implementation, debugging, architecture, or verification problem that
  has stalled
- a plan or fix where independent critique could change the next action
- contradictory evidence that needs synthesis rather than another linear pass
- `ralph` or `systematic-debugging` escalation after their own gates show the
  current path is not resolving the problem
- explicit user requests for fusion-style rescue analysis

Do not use for:

- ordinary implementation work that `ralph` can execute directly
- normal first-pass debugging before reproduction and hypotheses exist
- vague requirements before `interview`
- planning gaps that `ralplan` should handle
- quick one-file edits or tiny checks
- default multi-panel deliberation for every task

## Agent Roles

| Agent | Dispatch (when) |
|---|---|
| `fusion-rescue-analyst` | Use for current-host panel slots. Give each analyst one lens, the same evidence packet, non-goals, and the output fields below. |

If the active platform cannot dispatch the role, run separate inline panel
blocks and record the fallback reason. The current host main agent still owns
judge/synthesis.

## Panel Contract

Run exactly three default panel slots:

1. `primary`: the strongest constructive diagnosis or solution path.
2. `adversarial`: the strongest critique, failure mode search, and assumption
   attack.
3. `pragmatic`: the simplest viable next action, verification path, and
   rollback boundary.

Dispatch exactly three same-role `fusion-rescue-analyst` panels in parallel.
The three panel prompts use the same packet shape and evidence, differing only
in their assigned lens, then the current host main agent synthesizes all three
outputs. Panel-model assignment and any diversity mechanism are owned entirely
by the active platform rules; the core does not select models or hosts.

Each panel receives:

- the caller's Direction Contract, including required AC IDs, non-goals,
  protected assumptions, and direction-change approval rule
- the exact blocked decision that ordinary Ralph or Systematic Debugging could
  not resolve
- the remaining process budget for diagnostics, review, tests, and additional
  panel work
- problem statement and current workflow context
- relevant evidence, commands, logs, diffs, or plan excerpt after redaction and
  minimization
- non-goals and forbidden behavior
- any known budget, auth, safety, or environment constraints
- explicit instruction not to invoke nested rescue, `fusion-rescue`, another
  workflow skill, or another host; if the active platform assigns one bounded
  opposite-host consult, that assigned call is the only exception; same-host
  read-only subagents and read-only tools remain allowed
- explicit read-only instructions: do not edit files, run mutating commands,
  write state, or install plugins from a panel; same-host read-only analysis
  tools and subagents are allowed, but make no additional host call
- explicit instruction not to create a new proof architecture, scheduler,
  state machine, protocol, oracle, fixture system, or review layer outside the
  Direction Contract's goal and non-goals

Each panel returns:

- lens name
- strongest finding
- evidence used
- assumption under test
- likely failure mode
- recommended next action
- confidence and why
- what would change the conclusion

Use these exact field labels in panel output. Do not omit a field even when the
answer is short, synthetic, or read-only.

## Platform-Defined Consult

Only where the active platform rules define an opposite-host consult path may
one assigned panel collect an opposite-host response. That platform owns the
consult mechanism, preflight, response proof, lens assignment, redaction, and
fallback or strict-mode consequence. Without such a platform rule, no
opposite-host consult is attempted or required.

Any permitted consult remains read-only, bounded to one assigned lens, and
subject to the recursion guard. A launch notice, queued-job message, background
acknowledgement, deferred status pointer, or proof that only says a job started
is not a panel result.

## Fallback Behavior

The active platform owns panel-model assignment and the concrete diversity
mode names. In default mode, when its diversity composition is unavailable,
run three independent same-model panel instances using the platform-defined
fallback assignment and record the reason. When the caller explicitly demands
diversity, strict mode transitions to PAUSED instead of silently degrading.
The platform adapter defines the evidence and unblock details for that pause.

## Recursion Guard

Every panel packet must state:

```text
fusion depth: 1
Do not invoke rescue, fusion-rescue, another workflow skill, or another host from inside this panel.
Same-host read-only subagents and read-only tools are allowed.
Return your assigned lens analysis to the caller (a same-host read-only subagent or tool you used to produce it is fine).
```

If the active platform assigns one bounded opposite-host consult, the assigned
panel may make exactly that one call and no other host call. The guard applies
transitively to same-host read-only subagents. It never forbids same-host
read-only analysis used to produce the assigned lens.

## Judge And Synthesis

The current host main agent is the judge. Do not spawn a judge role.

The judge compares the three panel outputs and produces a synthesis with these
fields:

- `consensus`
- `contradictions`
- `unique insights`
- `blind spots`
- `recommended next action`
- `confidence and why`
- `panel availability/fallback notes`
- `fusion depth: 1`

`panel availability/fallback notes` must state the active platform's panel
assignment, which diversity or fallback path ran, and the recorded reason for
any unavailable leg. If strict mode paused, name the unavailable diversity leg
and the platform-defined unblock condition.

The synthesis must compare, decompose, and recombine the panels. It must not
only concatenate the answers. When panel findings conflict, name the conflict,
state which evidence decides it, and identify the smallest check that would
change the recommendation.

The synthesis may recommend a smaller diagnostic, an explicit approved
direction-change request, or a block. It must not spend beyond the recorded
remaining process budget or silently replace the Direction Contract with new
proof architecture.

## Semantic Scenario Checks

Before treating a Fusion Rescue update as verified, inspect the contract against
these scenarios:

- Three-panel shape: exactly three same-role panels receive the same packet
  shape with distinct assigned lenses, run in parallel, and return all required
  fields before synthesis.
- Intentional contradiction: `primary` recommends a path, `adversarial` shows
  why that path may violate a constraint, and `pragmatic` suggests a smaller
  reversible action. The synthesis must name the contradiction, decide what
  evidence matters, and recommend the smallest next check instead of merging
  incompatible advice.
- Diversity unavailable: the active platform's diversity composition cannot be
  used. Default mode must still produce three panel slots under the
  platform-defined fallback and disclose the reason; strict mode must PAUSE.
- Recursive consult: a panel attempts to call rescue, `fusion-rescue`, another
  workflow skill, or another host beyond an assigned bounded consult. The
  workflow must reject the nested call using `fusion depth: 1`. Same-host
  read-only subagents or read-only tools used to form the assigned-lens analysis
  remain allowed.

## Caller Return

Standalone mode returns analysis and recommendations only. Do not edit files
directly from standalone Fusion Rescue.

When called from `ralph`, return control to `ralph` with the synthesis,
recommended next story or verification step, and any blocked/residual risk.
Ralph remains responsible for edits, TDD, review, cleanup, and final
verification.

When called from `systematic-debugging`, return control to
`systematic-debugging` with the synthesized root-cause direction, competing
hypotheses, and smallest diagnostic or fix step. Systematic Debugging remains
responsible for reproduction, causal-chain closure, fix evidence, and
verification-before-completion.

When called from `ultrawork`, return the synthesis to the active phase instead
of changing the workflow stage directly.

## Output

Return:

- Mode: standalone or caller workflow.
- Panel availability and fallback notes.
- Platform-defined diversity or fallback path used, with the reason.
- Panel summaries by `primary`, `adversarial`, and `pragmatic`.
- Judge synthesis with all required fields.
- Recommended next action.
- Confidence and why.
- Caller return target, when any.
- Residual risks or blocked strict-diversity requirements.

## Anti-Patterns

- Calling Fusion Rescue before the ordinary selected workflow has enough facts.
- Treating a diversity leg as automatically better than the other panel evidence.
- Hiding auth, path, plan, or plugin failures.
- Using a bridge hook, daemon, ledger, or background state to trigger rescue.
- Creating a separate consult role or judge role.
- Expanding from three default slots without a new approved plan.
- Claiming OpenRouter Fusion equivalence or weight fusion.

## Source: docs/platforms/opencode-runtime.md

# OpenCode Runtime Rules

This compact section is embedded in generated OpenCode-facing skill documents.

## Native Skills And Questions

Load an applicable Oh No Harness workflow with OpenCode's native `skill` tool.
The loaded skill is the source of truth. When it names a next-skill handoff,
obtain the required approval with `question`, then load the selected skill
yourself and pass the artifact path and approved profile. Do not ask the user to
invoke it manually.

Use `question` for approval, preference, scope, and next-step choices. Ask one
focused question at a time unless the active skill explicitly combines
questions. Present a small set of mutually exclusive actions and wait for the
answer before crossing the gate.

## Role Dispatch

Dispatch an Oh No Harness role with OpenCode's `task` tool and exact
`subagent_type: oh-no-<role>`. The direct user form is `@oh-no-<role>`.
Do not substitute a built-in or generic subagent while the matching role is
available.

Use a self-contained packet with purpose, role, exact target and revision,
scope and permissions, non-goals, acceptance contract, required evidence and
output, and stop/escalation conditions. Foreground `task` is the default: its
completed return is the wait and result. For independent work, issue the whole
eligible batch in one assistant turn. If background tasks are exposed, wait for
their automatic completion notifications; do not poll, duplicate, or redo their
scope inline. Capture and use every final result before advancing.

The role's configured model is selected by its agent definition; never pass or
claim a per-call model override. An unconfigured role inherits the invoking
primary agent's model. Two calls to one role therefore prove independent
contexts, not model diversity.

## Configuration Activation

OpenCode loads skills, agents, and configuration at startup. After any Oh No
Harness configuration change, tell the user to quit and restart OpenCode; the
current process keeps its startup snapshot.

## Source: docs/platforms/opencode-fusion-rescue.md

# OpenCode Fusion Rescue Rules

This overlay follows the shared Fusion Rescue core and the OpenCode runtime.

## Panels

Issue exactly three `task` calls in one assistant turn with
`subagent_type: oh-no-fusion-rescue-analyst`. Each receives the same redacted,
read-only packet and exactly one distinct assigned lens: primary, adversarial,
or pragmatic. The direct user form is `@oh-no-fusion-rescue-analyst`.

Foreground task returns are the waits and final panel results. If background
mode is available, rely on automatic completion notifications; do not poll,
duplicate, or synthesize before all three results are captured. The main agent
is the judge and must use every panel result.

## Configuration State

OpenCode provides no per-task model override. When the role is configured, all
three panels use its one stored exact provider/model ID. When unconfigured, all
three inherit the invoking primary model. Neither case proves model diversity;
independent sessions and different lenses are perspective diversity only.

Record `same-model-parallel-fallback` and the applicable reason (`single
configured role model` or `unconfigured role inherited primary model`). Never
claim a model-diversity panel. If the caller requires model diversity, transition
to PAUSED and state that distinct runtime model identities cannot be guaranteed
by this binding.

No opposite-host consult is defined. Every packet retains the core recursion
guard, read-only boundary, and `fusion depth: 1`.
