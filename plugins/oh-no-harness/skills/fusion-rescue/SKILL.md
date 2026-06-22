---
name: fusion-rescue
description: Use when a hard problem needs bounded inference-time ensemble analysis, cross-host consultation when available, adversarial critique, fallback-aware synthesis, or escalation from Ralph/systematic-debugging after ordinary analysis stalls.
argument-hint: "<problem, failed plan, bug, decision, or blocked workflow>"
---

<!-- oh-no-harness-generated-skill-wrapper -->
<!-- DO NOT EDIT. Run: python3 scripts/generate-skill-wrappers.py --write -->

# Fusion Rescue for Codex

This generated file is the Codex-facing runtime skill document. Codex should read this file directly; maintainers edit the source documents listed below instead.

## Generated Runtime Composition

Source order:

- `../../docs/skill-core/fusion-rescue.md`
- `../../docs/platforms/codex-runtime.md`
- `../../docs/platforms/codex-fusion-rescue.md`

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
Claude: treat the opposite host as unavailable, degrade to current-host-only in
default mode, and block only in require-cross-host mode while naming the failure
class and the current-host fallback.

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

## Source: docs/platforms/codex-fusion-rescue.md

# Codex Fusion Rescue Rules

This platform overlay is source content for the generated Codex-facing
`fusion-rescue` runtime document, after the shared core and
`docs/platforms/codex-runtime.md`.

## Lens Ownership

Codex remains responsible for the `adversarial` lens when Codex is available.
From Codex, when the Claude consult preflight succeeds, assign exactly one
non-adversarial panel slot to collect the Claude response. That slot may be
owned by a Codex `fusion-rescue-analyst` panel subagent, and it may call Claude
Code exactly once to collect the Claude response for that panel. Claude Code
does not need to spawn another nested subagent for the panel to count. If the
preflight fails, use the documented default fallback or require-cross-host block
instead of pretending an opposite-host response was collected.

## Claude Consult Path

From Codex, ask Claude Code through `${CLAUDE_BIN:-claude} -p` when available.
Before assigning a Claude consult panel, the Codex main agent must inspect the
active Codex permission/sandbox context. Claude consult is allowed only when the
current Codex permission state is exactly `danger-full-access`. If the state is
missing, unknown, `read-only`, `workspace-write`, or anything other than
`danger-full-access`, do not call Claude. State that Claude is unavailable
because the Codex permission state is not `danger-full-access`, then use three
current-host Codex panel agents in default mode. In `require-cross-host` mode,
block instead of pretending an opposite-host response was collected, and name
the current-host three-panel fallback as the next local option the user can
approve.

When the Codex permission preflight confirms `danger-full-access`, build the
Claude command as an argument vector, not through shell string interpolation.
The argument vector is `${CLAUDE_BIN:-claude}`, `--print`, `--model`, `opus`,
`--permission-mode`, `dontAsk`, `--no-session-persistence`, then the prompt
packet, unless the user explicitly supplied a different Claude model for this
rescue. Do not specify a Claude tools override by default: Claude Code may need
its own permitted tools to perform the read-only analysis for the assigned lens.
The read-only boundary is enforced by the redacted prompt packet and the active
host permissions, not by stripping tools from the consult. The Claude prompt and
active host permissions must still forbid file edits, writes, installs, mutating
commands, Codex calls, nested rescue, and any host-to-host ping-pong.

From Codex, this is direct Opus panel review, not a request for Claude Code to
run its public Fusion Rescue workflow. Claude Opus must answer the assigned
panel directly. The Claude prompt must not ask Claude Code to invoke
`/oh-no-harness:fusion-rescue`, `oh-no-harness:fusion-rescue`,
`/codex:rescue`, `codex:codex-rescue`, Task, Agent, Workflow, subagents, or any
Claude-side skill or slash command. It must request only the assigned lens
analysis fields from Claude Opus.

For Codex-hosted Fusion Rescue, the cross-host slot may be a Codex panel
subagent whose only special responsibility is to run that Claude command and
return Claude's response as its panel output. If the active Claude binary rejects
those controls, cannot enforce them, or cannot return a panel response, treat
the cross-host consult as unavailable. The Claude prompt must include one
assigned lens, a redacted and minimized problem packet, the shared recursion
guard, and the instruction to avoid nested rescue, Codex calls, or host-to-host
ping-pong.

## Fallback Notes

Default mode degrades instead of blocking:

- If Claude is unavailable from Codex, record the command/path/auth failure
  class or missing response proof and continue.
- If the Codex permission state is not exactly `danger-full-access`, record
  `Claude unavailable: Codex permission state is not danger-full-access` and run
  all three panel slots on the current Codex host in default mode.

Require-cross-host mode blocks when the Claude consult path cannot return the
assigned panel output. The blocking output must include the attempted command,
permission state class, response-proof status, and current-host three-panel
fallback.
