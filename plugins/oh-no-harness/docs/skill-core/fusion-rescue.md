---
name: fusion-rescue
description: Use when a hard problem needs bounded inference-time ensemble analysis, cross-host consultation when available, adversarial critique, fallback-aware synthesis, or escalation from Ralph/systematic-debugging after ordinary analysis stalls.
argument-hint: "<problem, failed plan, bug, decision, or blocked workflow>"
---

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
   attack. Codex performs the adversarial lens when Codex is available.
3. `pragmatic`: the simplest viable next action, verification path, and
   rollback boundary.

When the opposite host is reachable, at least one of these three slots must use
an actual opposite-host response. Do not satisfy Fusion Rescue with three
current-host-only panels when the opposite host can provide bounded panel
evidence. The current host may choose which non-adversarial lens uses the
opposite host unless the platform rule below pins a lens:

- Codex remains responsible for the `adversarial` lens when Codex is available.
- From Codex, a Codex `fusion-rescue-analyst` panel subagent may own the
  cross-host consult slot and call Claude Code once to collect the Claude
  response for that panel. Claude Code does not need to spawn another nested
  subagent for the panel to count.
- From Claude Code, `/codex:rescue` or `codex:codex-rescue` is sufficient
  opposite-host response evidence.

Each panel receives:

- problem statement and current workflow context
- relevant evidence, commands, logs, diffs, or plan excerpt after redaction and
  minimization
- non-goals and forbidden behavior
- any known budget, auth, safety, or environment constraints
- explicit instruction not to invoke nested rescue, `fusion-rescue`, another
  workflow skill, or any host-to-host call except the single assigned
  cross-host consult when this panel owns the opposite-host response slot
- explicit read-only instructions: do not edit files, run mutating commands,
  write state, install plugins, or make extra network calls from a panel beyond
  the single assigned cross-host consult

Each panel returns:

- lens name
- strongest finding
- evidence used
- assumption under test
- likely failure mode
- recommended next action
- confidence and why
- what would change the conclusion

## Cross-Host Consult

Cross-host consultation is attempted for at least one panel in default mode and
is required when the caller explicitly asks for require-cross-host behavior.
The success condition is that a panel result includes a real response from the
opposite host, and the synthesis names which panel used that response in panel
availability/fallback notes.

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
The argument vector must enforce a read-only, non-persistent consult boundary:
`${CLAUDE_BIN:-claude}`, `--print`, `--model`, `opus`, `--permission-mode`,
`dontAsk`, `--no-session-persistence`, then the prompt packet, unless the user
explicitly supplied a different Claude model for this rescue. Do not specify a
Claude tools override by default: Claude Code may need its own permitted tools
for read-only analysis. The Claude prompt and active host permissions must
still forbid file edits, writes, installs, mutating commands, Codex calls,
nested rescue, and any host-to-host ping-pong.
For Codex-hosted Fusion Rescue, the cross-host slot may be a Codex panel
subagent whose only special responsibility is to run that Claude command and
return Claude's response as its panel output. If the active Claude binary rejects
those controls, cannot enforce them, or cannot return a panel response, treat
the cross-host consult as unavailable. The Claude prompt must include one
assigned lens, a redacted and minimized problem packet, the recursion guard, and
the instruction to avoid nested rescue, Codex calls, or host-to-host ping-pong.

From Claude Code, consult Codex only through an available and explicitly loaded
`openai/codex-plugin-cc` rescue capability, surfaced as `/codex:rescue` when
that plugin is installed. If that capability is unavailable, record it as
unavailable and use current-host analysis for the affected slot in default
mode. In require-cross-host mode, the run blocks unless `/codex:rescue` or
`codex:codex-rescue` returns the assigned panel output.

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
- If Claude is unavailable from Codex, record the command/path/auth failure
  class or missing response proof and continue.
- If the Codex permission state is not exactly `danger-full-access`, record
  `Claude unavailable: Codex permission state is not danger-full-access` and run
  all three panel slots on the current Codex host in default mode.
- If Codex is unavailable from Claude Code, record
  `Codex adversarial unavailable` and run the adversarial lens on the current
  host.
- If Codex is available, the adversarial lens stays Codex-side even when other
  lenses use another host.

Require-cross-host mode blocks when the requested host cannot be reached. The
blocking output must include which host was required, what command or plugin was
attempted, failure class, and the next local fallback the user can approve.

## Recursion Guard

Every ordinary panel and every outbound cross-host consult packet must state:

```text
fusion depth: 1
Do not invoke rescue, fusion-rescue, cross-host consult, or another host from inside this panel.
Return only your assigned lens analysis to the caller.
```

When a Codex panel subagent is assigned to collect the Claude response, its
panel prompt must state that the Claude CLI call is the only permitted
cross-host call, and the Claude prompt itself must contain the strict guard
above.

This is a one-hop guard. Codex must not call Claude, then let Claude call Codex
again; Claude Code must not call Codex, then let Codex call Claude again.

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
- Codex permission below `danger-full-access`: from Codex, the workflow must
  check the current permission state before any Claude consult. If it is not
  exactly `danger-full-access`, it must not call Claude; default mode must spawn
  three current-host Codex panel agents and state that Claude is unavailable
  because the Codex permission state is not `danger-full-access`.
- require-cross-host unavailable: the required host, command, plugin, auth, or
  budget is unavailable, or the opposite-host response cannot be collected or
  proven. The workflow must block with failure class, attempted command or
  plugin, path/auth status, proof status, and next local fallback, without
  exposing secret values.
- Recursive consult: a panel attempts to call rescue, `fusion-rescue`, or
  another host. The workflow must reject the nested call using `fusion depth: 1`
  and the one-hop guard.

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
