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
- `../../docs/platforms/codex.md`
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
Return only your assigned lens analysis to the caller.
```

When a panel is assigned to collect the opposite-host response, its panel prompt
must state that the assigned consult is the only permitted cross-host call, and
the outbound consult prompt itself must contain the strict guard above.

This is a one-hop guard. The current host must not call the opposite host and
allow that host to call back into the current host or another host.

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

## Source: docs/platforms/codex-fusion-rescue.md

# Codex Fusion Rescue Rules

This platform overlay is source content for the generated Codex-facing
`fusion-rescue` runtime document, after the shared core and
`docs/platforms/codex.md`.

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
The argument vector must enforce a read-only, non-persistent consult boundary:
`${CLAUDE_BIN:-claude}`, `--print`, `--model`, `opus`, `--permission-mode`,
`dontAsk`, `--tools`, `""`, `--no-session-persistence`, then the prompt packet,
unless the user explicitly supplied a different Claude model for this rescue.
The empty `--tools` value is the mechanical read-only boundary: Claude Opus must
answer from the redacted prompt packet and must not receive file, shell, network,
write, Task, Agent, Workflow, or plugin tools for this consult. If the active
Claude binary rejects `--tools ""`, cannot enforce a no-tools consult, or needs
write-capable permissions to run, treat the cross-host consult as unavailable.
The Claude prompt and active host permissions must still forbid file edits,
writes, installs, mutating commands, Codex calls, nested rescue, and any
host-to-host ping-pong.

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
