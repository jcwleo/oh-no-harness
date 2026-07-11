---
name: fusion-rescue
description: Use when a hard problem needs bounded inference-time ensemble analysis, cross-host consultation when available, adversarial critique, fallback-aware synthesis, or escalation from Ralph/systematic-debugging after ordinary analysis stalls.
argument-hint: "<problem, failed plan, bug, decision, or blocked workflow>"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Fusion Rescue for Claude Code

This generated file is the Claude Code-facing runtime skill document. Claude Code slash commands should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/fusion-rescue.md`
- `../../docs/platforms/claude-code-runtime.md`
- `../../docs/platforms/claude-code-fusion-rescue.md`

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
multi-agent/multi-host rescue analysis. Inside another workflow, use it only
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
- default multi-host deliberation for every task

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

When the opposite host is reachable, at least one of these three slots must use
an actual opposite-host response. Do not satisfy Fusion Rescue with three
current-host-only panels when the opposite host can provide bounded panel
evidence. The active platform-specific Fusion Rescue rules may pin a lens to
the current host or the opposite host. If no platform-specific Fusion Rescue
rule pins a lens, the current host may choose which panel slot uses the
opposite host.

When a platform-specific Fusion Rescue rule assigns one panel to collect the
opposite-host response, that panel receives exactly one permitted cross-host
consult. Other panels must remain current-host-only and must not call another
host.

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
  workflow skill, or any cross-host call except the single assigned cross-host
  consult when this panel owns the opposite-host response slot; same-host
  read-only subagents and read-only tools remain allowed
- explicit read-only instructions: do not edit files, run mutating commands,
  write state, or install plugins from a panel; same-host read-only analysis
  tools and subagents are allowed, but make no cross-host call beyond the single
  assigned cross-host consult
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

## Cross-Host Consult

Cross-host consultation is attempted for at least one panel in default mode and
is required when the caller explicitly asks for require-cross-host behavior.
The success condition is that a panel result includes a real assigned-lens
analysis from the opposite host, and the synthesis names which panel used that
response in panel availability/fallback notes.

Use the active platform-specific Fusion Rescue rules for the consult mechanism,
command or plugin capability, permission preflight, foreground or response
proof, and any lens pinning. A launch notice, queued-job message, background
acknowledgement, deferred status pointer, or proof that only says a job started
is not a valid opposite-host response. The consult call itself must return the
assigned panel analysis unless the platform-specific Fusion Rescue rules define
a stricter foreground response path.

The outbound prompt must request only the assigned lens fields. It must not ask
the opposite host to invoke public Fusion Rescue, another workflow skill, a
slash command, Task, Agent, Workflow, subagent, or a further host consult unless
the active platform-specific Fusion Rescue rules explicitly identify that named
capability as the single allowed opposite-host consult path. Even then, the
result must be the assigned panel output, not another nested rescue transcript.

If platform consult controls are unavailable, if they reject the read-only
boundary, if foreground response proof fails, or if the consult cannot return a
panel response, treat the cross-host consult as unavailable. The consult prompt
must include one assigned lens, a redacted and minimized problem packet, the
recursion guard, and the instruction to avoid nested rescue or host-to-host
ping-pong.

Before sending any cross-host consult packet:

- remove credentials, tokens, API keys, cookies, private keys, payment data,
  personal contact details, and unrelated user data
- replace secret-like values with labels such as `[REDACTED_TOKEN]`
- include only the minimal code/log/diff excerpts needed for the assigned lens
- omit raw auth/config file contents and environment dumps
- state `read-only consult: no edits, no writes, no installs; read-only
  analysis tools are allowed only when the active opposite host permits them`
- include `fusion depth: 1`

Do not hard-code absolute host binary paths. When command availability, auth,
plan, plugin install state, budget, or policy blocks cross-host consultation,
record only the failure class, command or plugin name, path/auth status, and
next local fallback. Do not record credential values, config contents, or full
environment output.

## Fallback Behavior

Default mode degrades instead of blocking:

- If the opposite host, auth, command/plugin, or response collection path is
  unavailable or cannot be proven, run all three panel slots on the current host
  and include a panel availability/fallback note that says no opposite-host
  response evidence was available.
- If a platform-specific permission, auth, budget, command, plugin, or
  foreground-response preflight fails, record the failure class and continue on
  the current host.
- If the opposite-host call returns only a launch notice, queued-job message,
  background acknowledgement, or status pointer instead of assigned panel
  analysis, record the missing response proof, treat the slot as having no
  opposite-host response, and run it on the current host in default mode.
- If platform-specific Fusion Rescue rules pin a lens to a host that is
  unavailable, run the pinned lens on the current host in default mode and state
  that it is not opposite-host evidence.

Require-cross-host mode blocks when the requested host cannot be reached. The
blocking output must include which host was required, what command or plugin was
attempted, failure class, and the next local fallback the user can approve.

## Recursion Guard

Every ordinary panel and every outbound cross-host consult packet must state:

```text
fusion depth: 1
Do not invoke rescue, fusion-rescue, cross-host consult, or another host from inside this panel.
Same-host read-only subagents and read-only tools are allowed; the prohibition above is the cross-host hop, not same-host fan-out.
Return your assigned lens analysis to the caller (a same-host read-only subagent or tool you used to produce it is fine).
```

`fusion depth: 1` is a cross-host-hop count: this panel sits one cross-host hop
from the caller and must not add another cross-host hop. The "from inside this
panel" prohibition above scopes to cross-host calls (rescue, fusion-rescue,
cross-host consult, or another host); a panel MAY use same-host read-only
subagents or read-only tools to form its assigned-lens analysis.

When a panel is assigned to collect the opposite-host response, its panel prompt
must state that the assigned consult is the only permitted cross-host call, and
the outbound consult prompt itself must contain the strict guard above.

This is a one-hop guard. The current host must not call the opposite host and
allow that host to call back into the current host or another host. The
cross-host block applies transitively: a same-host read-only subagent spawned by
a panel inherits the same no-further-cross-host-hop rule.

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

`panel availability/fallback notes` must state which panel used the
opposite-host response. If none did, it must state why the opposite host was
unavailable or unproven and whether default fallback or require-cross-host
blocking applied.

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

- Opposite host available: default mode must include at least one panel with an
  actual opposite-host response. Three current-host-only panels are insufficient
  unless availability or proof failed and fallback is disclosed.
- Intentional contradiction: `primary` recommends a path, `adversarial` shows
  why that path may violate a constraint, and `pragmatic` suggests a smaller
  reversible action. The synthesis must name the contradiction, decide what
  evidence matters, and recommend the smallest next check instead of merging
  incompatible advice.
- Missing opposite host: cross-host consult is unavailable in default mode. The
  workflow must still produce three current-host panel slots and include panel
  availability/fallback notes.
- Platform preflight denied: if the active platform-specific Fusion Rescue
  rules require permission, auth, budget, command, plugin, foreground, or
  response-proof preflight, a denied or missing preflight must prevent the
  consult. Default mode must use three current-host panel slots and disclose the
  failure class in panel availability/fallback notes.
- require-cross-host unavailable: the required host, command, plugin, auth, or
  budget is unavailable, or the opposite-host response cannot be collected or
  proven. The workflow must block with failure class, attempted command or
  plugin, path/auth status, proof status, and next local fallback, without
  exposing secret values.
- Recursive consult: a panel attempts to call rescue, `fusion-rescue`, or
  another host. The workflow must reject the nested call using `fusion depth: 1`
  and the one-hop guard. This rejection targets the nested CROSS-HOST call; a
  panel using same-host read-only subagents or read-only tools to form its
  assigned-lens analysis is not a recursive consult and is allowed.

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
- Opposite-host response path used, or the unavailable/unproven fallback reason.
- Panel summaries by `primary`, `adversarial`, and `pragmatic`.
- Judge synthesis with all required fields.
- Recommended next action.
- Confidence and why.
- Caller return target, when any.
- Residual risks or blocked cross-host requirements.

## Anti-Patterns

- Calling Fusion Rescue before the ordinary selected workflow has enough facts.
- Treating cross-host output as automatically better than local evidence.
- Hiding auth, path, plan, or plugin failures.
- Using a bridge hook, daemon, ledger, or background state to trigger rescue.
- Creating a separate consult role or judge role.
- Expanding from three default slots without a new approved plan.
- Claiming OpenRouter Fusion equivalence or weight fusion.

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

Dispatch only after the active skill's trigger fires, then read
`docs/platforms/claude-code.md` `## Role Dispatch` for the full host contract.
Prefer `oh-no-harness:<role>`, request the whole independent batch before
waiting, capture every final result, and clean up only after integration. An
approved-plan handoff is dispatch authorization for eligible isolated roles;
plugin-agent unavailability uses the documented embedded-role fallback.

## Cross-Host Consult Channel

This channel is trigger-loaded, not embedded in every workflow decision. When a
named THOROUGH paired-review or Fusion Rescue trigger fires, read and apply
`docs/platforms/claude-code.md` `## Cross-Host Consult Channel` before dispatch.
Until then, do not preload opposite-host invocation details.

## Source: docs/platforms/claude-code-fusion-rescue.md

# Claude Code Fusion Rescue Rules

This platform overlay is source content for the generated Claude Code-facing
`fusion-rescue` runtime document, after the shared core and
`docs/platforms/claude-code-runtime.md`.

## Codex Consult Path

From Claude Code, consult Codex for a panel slot only by dispatching the
dedicated read-only consult agent `oh-no-harness:fusion-codex`. That agent
resolves the Codex companion path and runs one read-only `codex-companion.mjs`
call whose packet instructs Codex to dispatch `oh-no-fusion-rescue-analyst` for
one assigned lens and return that analyst's exact panel fields. If the companion
is unavailable or unresolvable, record it as unavailable and use current-host
analysis for the affected slot in default mode. In `require-cross-host` mode, the
run blocks unless `oh-no-harness:fusion-codex` returns the assigned panel output.

From Claude Code, the Codex consult must run synchronously and return Codex's
actual panel analysis as the panel output. The `oh-no-harness:fusion-codex` agent
runs the `codex-companion.mjs` call read-only: it omits the write flag so the
companion sandbox is read-only (best-effort, not a guarantee — see the consult
agent core), and it must omit `--background` so the call runs in the
foreground, not as a detached background job. Do not authorize write-capable edits
for an analysis-only panel.

The consult agent must require role-ownership proof that
`oh-no-fusion-rescue-analyst`, not a parent inline Codex answer, produced the
returned panel. A parent inline Codex answer is not a valid opposite-host panel
response. A response that only acknowledges a queued or background job, for
example text that says a task started in the background and points to a status
command for a job id, is not a valid opposite-host panel response. Treat such a
job-launch acknowledgment or an unproven inline answer as no Codex response: in
default mode, record the failure class and run the affected slot on the current
host; in require-cross-host mode, block and name the current-host three-panel
fallback. Do not poll status or fetch a deferred result from inside the panel to
compensate; the consult call itself must return the analysis.

## Lens Ownership And Fallback

When Codex is available, use the `oh-no-harness:fusion-codex` consult for the
`adversarial` lens unless the caller supplied a stricter lens assignment and the
synthesis records why it changed. If Codex is unavailable from Claude Code, record
`Codex adversarial unavailable` and run the adversarial lens on the current Claude
Code host.

If the Codex consult returns only a background job-launch acknowledgment instead
of analysis, or cannot prove `oh-no-fusion-rescue-analyst` role ownership, record
`Codex consult returned no analysis (background job acknowledgment only)`, treat
the slot as having no opposite-host response, and run it on the current host in
default mode.
