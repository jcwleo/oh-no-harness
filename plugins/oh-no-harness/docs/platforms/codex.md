# Codex Platform Rules

This platform document is the longer Codex maintenance reference. Generated
Codex-facing workflow documents embed the compact main-caller floor from
`docs/platforms/codex-child-packet-floor.md`; non-self-contained wrappers also
embed `docs/platforms/codex-runtime.md`.

## Skill Loading

Codex-facing public skills live under `skills/`. Every generated workflow
wrapper composes its matching `docs/skill-core/<skill>.md` with
`docs/platforms/codex-child-packet-floor.md`. Self-contained skills then add
their required `docs/platforms/codex-<skill>.md` adapter; remaining skills add
`docs/platforms/codex-runtime.md` and any optional skill-specific overlay.

## User Approval

When a core skill asks for approval, preference, scope, or next-step selection,
ask the user directly in the current Codex conversation. Present options as
actions the host agent will take. Do not tell the user to run a command manually
when the skill handoff expects the host agent to invoke the next skill.

## Auto Routing

Codex native skill loading and descriptions remain the primary routing
surface. Hooks are opt-in. When hooks are disabled, every native workflow
wrapper still carries the dedicated main-caller child-packet floor. The
`auto-routing` skill stores and explains the preference, but enabling it does
not append forced routing or change current routing semantics. If Codex-facing
SessionStart hooks run, they must stay compact and must not embed full skill
core bodies.

## OpenAI-Aligned Prompting

This file carries extended OpenAI guidance for Codex maintainers. The compact
runtime-sized rules copied into generated skill documents live in
`docs/platforms/codex-runtime.md`. The longer provider reference lives in
`docs/providers/openai.md`, but generated Codex-facing runtime skill documents
do not include provider docs as an extra runtime source.

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

Codex exposes no per-call model parameter: `spawn_agent` takes no model
argument, and each role's model is fixed at install time in its generated
agent TOML. Model fidelity is therefore structural here, not an instruction.

Codex role dispatch is host-policy controlled. Use `spawn_agent` only when the
current host tool definition exposes it, the active skill permits dispatch, and
the role has an isolated read-only scope, disjoint write ownership, or an
independent review or verification responsibility.

When dispatching an Oh No Harness role in any Codex context, including active
skills, approved plan handoffs, or general user-requested subagent work outside
a selected skill, use the registered custom agent first. Derive every task name
from that dispatch's actual workflow or task, actual role, phase or lens, and
stable ordinal. For example, a maintenance inventory lookup uses
`spawn_agent(task_name="maintenance_explore_inventory_1", agent_type="oh-no-explore", message=<self-contained packet>, fork_turns="none")`; it is not a
reusable literal for other roles. Do not choose built-in `explorer`, `worker`,
`default`, or a prompt-embedded generic subagent for an Oh No Harness role while
the matching registered custom agent is available.
Do not infer custom-agent unavailability from rendered schema text, display
comments, or uncertainty. Generic/default fallback is allowed only inside an
active Oh No Harness workflow or explicit user-requested subagent task after an
actual `agent_type="oh-no-<role>"` attempt is rejected as unknown or unavailable
and the confirmed fallback reason is recorded. No-skill read-only repository
lookups may dispatch only the read-only `oh-no-explore` custom agent and must
not use generic/default fallback.

Spawn custom roles with `fork_turns = "none"`: omitting `fork_turns` defaults
to a full-history fork, and Codex full-history forks inherit the parent agent
configuration, so the custom `agent_type` is rejected. Do not combine
`agent_type = "oh-no-<role>"` with `fork_context = true` (unsupported on
current hosts) or any full-history fork request. Build the spawned-agent
message from the caller-owned floor embedded in every Codex workflow wrapper;
SessionStart supplies compatible direct-dispatch guidance when hooks are enabled.
Use one spawn payload shape only: prompt/message or items, never both. Derive
every task name from the actual dispatch; names must match `^[a-z0-9_]+$`, encode
the actual workflow or task, role, phase/lens, and stable ordinal, and preserve
deterministic sibling uniqueness under the same parent. A task name is routing
identity, not role proof: the legacy `spawn_agent(agent_type="oh-no-<role>", ...)`
shorthand is incomplete, and custom loading requires the requested `agent_type`,
expected child `agent_role`, and matching developer instructions.

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

The Codex SessionStart block named
`CODEX_ONLY_OH_NO_READONLY_EXPLORATION_DELEGATION` governs simple read-only
repository fact lookup prompts when no active Oh No Harness workflow or explicit
user-requested subagent task exists. Eligible work includes locating logic,
tracing a symbol, identifying related tests, or summarizing an existing
file/config path. This no-skill lane may dispatch the registered read-only
`oh-no-explore` custom agent, as many as the lookup needs and not capped at one.
If `oh-no-explore` is unknown or unavailable, answer inline; do not fall back to
a generic or prompt-embedded subagent for this lane. When this lane dispatches
`oh-no-explore`, each dispatched result is a dependency: use `wait_agent` until
that receiver reaches final status `completed`, capture the result, and use it
before the next action; a timeout, empty wait, or no-completion result is not
final and is not captured evidence, and you must not call `close_agent` for a
running or pending subagent merely because it is slow. It does not authorize
planning, debugging, implementation, review (security lens included), scenario
QA, completion verification, ambiguous-requirements work, or file edits. It must
not read or reproduce secrets unless the user explicitly asks for that
sensitive lookup, and credential values must be redacted in any output.

For approved `ralplan` handoffs to ordinary `oh-no-harness:ralph`, treat
`Parallel trigger: approved-plan-handoff` as dispatch authorization for
eligible isolated roles. Do not require a separate `ralph with parallel
subagents` option when the plan already lists roles whose output can change the
implementation, review, verification, or ship/block decision.

For `ralplan`, which is the only workflow context that owns Plan-Reviewer,
Planner and Plan-Reviewer keep sequential role boundaries:
Planner produces the draft, then Plan-Reviewer reviews that draft. Dispatch them
as sequential subagents when the active host supports dispatch and independent
context can improve planning or review; otherwise keep separate inline role
blocks. No re-review dispatch exists: the single Planner revision v2 is final and goes to the approval brief.

After `wait_agent` returns a final status for any Codex-dispatched role,
capture the output and any changed-file set before cleanup. A timeout, empty
wait result, or "No agents completed yet" result is not a final status and is
not permission to close the subagent. Hard rule: MUST NOT call `close_agent`
for a running or pending subagent merely because it is slow. Once a role is
dispatched, its assigned scope, role, and expected output become a workflow
dependency. The caller must wait until every in-scope dispatched subagent reaches
a final status, capture its result, and use that result in synthesis,
implementation, review, verification, or an explicit blocked/abandoned record
before advancing past the dependent step or claiming completion. While waiting,
continue only genuinely non-overlapping local work. Do not redo the delegated
work inline, do not spawn a duplicate replacement, and do not let the parent
agent's own inline analysis substitute for the subagent result merely because
the subagent is slow. Close
without a captured final result only when the user explicitly cancels or stops
that subagent, the task scope invalidates the work, the spawn was duplicate or
mis-scoped, or continuing creates a safety, security, or filesystem risk. Record
that close as cancelled or abandoned and never use missing output as completion
evidence. When no further input is needed for a completed, failed, cancelled,
user-cancelled, scope-invalidated, or unsafe subagent and the host exposes
`close_agent`, call it and record the result; if no close primitive exists
(newer Codex CLIs manage closure themselves), record that closure is
host-managed and continue.

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

### Resolving the bundled installer path

Codex has no skill-visible plugin root, so resolve the newest installed cache copy:

```bash
tab="$(printf '\t')"
cache="${CODEX_HOME:-$HOME/.codex}/plugins/cache"
# Codex exposes no skill-visible plugin root, so cache-newest is the only reachable
# path. Sort on the VERSION path component (full path only as tie-break) so a second
# marketplace identity cannot let an older version win.
script="$(find "$cache" -path '*/oh-no-harness/*/scripts/install-codex-agents' 2>/dev/null \
  | awk -F/ '{for(i=NF;i>0;i--) if($i=="scripts"){print $(i-1)"\t"$0; break}}' \
  | LC_ALL=C sort -t"$tab" -k1,1V -k2,2 | tail -n1 | cut -f2-)"
"$script" --scope user --ensure
```

SessionStart is the only automatic custom-agent ensure. Generated files include
the installed plugin version marker, so a later plugin update can refresh stale
`oh-no-*` agent definitions during SessionStart without requiring a repeated
user prompt. If ensure fails or an unmarked user file blocks it, record the
ensure failure but do not treat that failure alone as permission for generic
prompt-embedded fallback. Continue with `agent_type = "oh-no-<role>"` if the
current host recognizes that custom agent. If it does not, run the resolver above
with `--scope user --ensure` and retry; use generic prompt-embedded fallback only
after confirmed custom-agent
unavailability and record that fallback reason.

Files ensured on disk are not the same thing as same-session named-agent
availability. Use `agent_type = "oh-no-<role>"` whenever the current Codex host
recognizes that registered custom agent. Inside an active Oh No Harness
workflow, use the generic prompt-embedded fallback below or built-in `explorer`
only after the host returns `unknown agent_type` or an equivalent explicit
rejection for `oh-no-<role>`, or the user-scope templates are unavailable and
the host cannot recognize the custom agent. Outside an active workflow or
explicit user-requested subagent task, the no-skill read-only repository lookup
lane may dispatch the registered read-only `oh-no-explore` agent when the host
recognizes it, and must wait for each dispatched result before the next action.
The generated read-only role templates (`oh-no-explore`, `oh-no-verifier`,
`oh-no-code-reviewer`, and `oh-no-fusion-rescue-analyst`) set
`sandbox_mode = "read-only"` so their write
boundary does not rely on prompt text alone. The no-skill repository lookup
lane remains limited to `oh-no-explore`.

The generated templates pin the current 5.6 family and a per-agent
`model_reasoning_effort` so custom-agent role files do not depend on inheriting
a user-specific model layer. `oh-no-explore` uses `gpt-5.6-terra` at `medium`;
`oh-no-analyst` and `oh-no-executor` use `gpt-5.6-sol` at `high`; the remaining
Codex custom agents use `gpt-5.6-sol` at `xhigh`.

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

## Custom-Agent Spawn Troubleshooting

Load this section only after an actual Codex subagent spawn or wait failure.
Classify the failure before declaring custom agents unavailable or selecting a
fallback. Do not edit the user's Codex config automatically, and do not recommend
the selector workaround for every subagent failure.

| Failure evidence | Meaning and response |
|---|---|
| The model-visible tool has a hidden or unavailable `agent_type` selector | Explain that Multi-Agent v2 routing metadata is hidden. Recommend the selector recovery below, then require a Codex restart and a new task. |
| A reserved `collaboration.spawn_agent` schema mismatch rejects routing fields | Recommend the selector recovery below. The non-reserved `agents` namespace allows the expanded routing schema. |
| The host reports an unknown agent type such as `unknown agent_type 'oh-no-explore'` | This is an agent registration or installation failure, not a selector failure. Run the resolver above with `--scope user --ensure`, then retry in a fresh task. |
| The host reports `Provide either message or items, but not both` | Retry with one spawn payload shape only. Do not change the user's Codex config. |
| A custom agent conflicts with a full-history fork | Omit `fork_context` and use `fork_turns = "none"`; put required scope and evidence in the spawn message. |
| A wait times out, returns empty, or reports no completed agents | The child is not proven complete. Keep waiting or continue only non-overlapping work; never close a running or pending child merely because it is slow. |
| The host reports a thread or concurrency limit | Wait for an in-scope child to finish and capture its result before starting more work, or reduce the next eligible batch. Do not apply the selector workaround. |

For the hidden-selector and reserved-schema cases only, tell the user to add
this table to `$CODEX_HOME/config.toml`, or to `~/.codex/config.toml` when
`CODEX_HOME` is unset:

```toml
[features.multi_agent_v2]
hide_spawn_agent_metadata = false
tool_namespace = "agents"
```

Do not add a separate `multi_agent_v2 = true` feature flag or use
`--enable multi_agent_v2` solely for this recovery. After saving the options,
restart Codex and open a new task because an existing task keeps the tool schema
created for that session.

After retrying, prove the requested `agent_type` from runtime evidence rather
than a task label. The child rollout should record the expected `agent_role`,
and its developer messages should contain the registered role's
`developer_instructions`. A matching task name alone is not role-ownership
proof.

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

## Cross-Host Consult Channel

Load this section only after a named THOROUGH paired-review or Fusion Rescue
trigger. On Codex, the opposite host is Claude Code.

Consult Claude only when the active permission state is exactly
`danger-full-access`; otherwise treat it as unavailable and apply the calling
skill's fallback. For shared review, the Codex parent must not run
`${CLAUDE_BIN:-claude}` inline. Derive the transport-owner identity from the
actual caller and role: for example,
`spawn_agent(task_name="ralplan_plan_reviewer_cross_host_1", agent_type="oh-no-plan-reviewer", message=<self-contained redacted packet>, fork_turns="none")`,
`spawn_agent(task_name="ralph_code_reviewer_cross_host_1", agent_type="oh-no-code-reviewer", message=<self-contained redacted packet>, fork_turns="none")`, or
`spawn_agent(task_name="systematic_debugging_debugger_cross_host_1", agent_type="oh-no-debugger", message=<self-contained redacted packet>, fork_turns="none")`.
The verifier has no cross-host leg. The parent waits for the role-owned result
before synthesis.

The role owner invokes Claude as an argument vector:
`${CLAUDE_BIN:-claude}`, `--print`, `--model`, `opus`, `--permission-mode`,
`dontAsk`, `--no-session-persistence`, then the redacted packet. The response
must contain the synchronous assigned analysis; a launch notice, queued job,
background acknowledgement, or status pointer is unavailable evidence. The
packet forbids edits, installs, mutating commands, nested rescue, and any second
cross-host hop. Redact secrets and PII; record only failure class and
command/path/auth status on failure. A parent inline Claude consult is not a
valid shared cross-host review pass.
