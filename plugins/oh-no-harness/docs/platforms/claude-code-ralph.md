# Claude Code Ralph Adapter

CLAUDE_CODE_ONLY_RALPH_ADAPTER

<ADAPTER_CONTRACT>
This adapter binds the Ralph core to Claude Code. The core owns every
semantic decision; this file owns only host invocation and lifecycle
mechanics. If they conflict, the core wins. The generated core plus this
adapter is sufficient: longer platform, shared, and agent documents are
optional maintenance context, never a runtime prerequisite. Do not apply it
on Codex or other platforms.
</ADAPTER_CONTRACT>

## Invocation

When Ralph dispatches a role, use Claude Code's Task, Agent, Workflow
`agent()`, or subagent mechanism with the plugin-scoped agents from
`agents/`. Use `oh-no-harness:<agent>` as the agent name when the tool lists
plugin agents; when explicit prompt text or a user-facing manual mention is
needed, use `@agent-oh-no-harness:<agent>`. Dispatch is trigger-loaded —
dispatch only after the active skill's trigger fires.

An approved `ralplan` handoff to ordinary `oh-no-harness:ralph` is the
default parallel-capable execution path: treat
`Parallel trigger: approved-plan-handoff` as authorization for every
eligible isolated role in the approved plan, without a separate "parallel
subagents" choice. Authorization is not a command to dispatch roles whose
output would not change the implementation, review, verification, or
ship/block decision.

## Executor-Default Trigger

When the core records STANDARD/THOROUGH repository work-product mutation,
dispatch `oh-no-harness:executor` even when `Parallel trigger: none`; that
trigger controls concurrency, not sequential executor ownership. The same
rule applies to REVIEW-to-EXECUTE focused fixes. Inline mutation is valid only
for the core's recorded LIGHT-tiny or dispatch-unavailable fallback.

For independent read-only, review, verification, QA, security, or
exploration work — and for disjoint implementation (executor) work in
STANDARD/THOROUGH when write scopes are non-overlapping — request background
subagents and start the whole independent batch before waiting for any one
result.

If a plugin-scoped agent is unavailable, keep the same role boundary by
embedding the matching `agents/<agent>.md` prompt into the available Claude
Code subagent mechanism.

## Dispatch Packet Additions

Add to the core dispatch packet:

```text
Claude agent: oh-no-harness:<agent>
Background: <yes for independent work, no when sequential>
```

## Lifecycle

After each background subagent reaches a final status, capture its result
and changed-file set. When no further input is needed, close or clean up
that completed subagent with the Claude Code mechanism exposed by the host;
if the host does not expose explicit close or cleanup, record that no close
mechanism was available. A notification, timeout, or empty wait result is
not a final status.

## Model Diversity Pair

For any dispatched `code-reviewer` pair (every dispatched review), dispatch two
same-role instances in parallel and synthesize one verdict. Both legs MUST be
requested in a single batch: issue both subagent tool calls in the same assistant
turn (or with `Background: yes` for both) BEFORE waiting on either result; a
serial dispatch-wait-dispatch sequence is not a valid pair. The two legs'
packet bodies MUST be identical except the single `Assigned perspective:` line
(Lens A on the primary leg, Lens B on the diversity leg); leg identity (`primary`
vs `diversity`) is carried ONLY by the host dispatch metadata (the description
field and the model override), never inside the packet text. Read the role's declared stored primary
and the validated secondary top-tier model from the session
`<OH_NO_MODEL_DIVERSITY>` block.

- `model-diversity-pair`: the primary leg is dispatched without a model
  override and therefore uses the concrete declared-frontmatter primary; the
  diversity leg uses an explicit NATIVE model override for the validated
  secondary. The primary must not be `host-default`, and the secondary must
  differ from the declared stored primary.
- `same-model-parallel-fallback`: when no valid diversity configuration exists,
  the declared primary cannot be applied, or the secondary override fails in
  default mode, dispatch two independent same-model `code-reviewer` instances
  and record the reason.
- `require-model-diversity`: an explicit caller demand for diversity is strict;
  if the diversity leg is unavailable or fails, transition to PAUSED. Do not
  substitute the same-model fallback.

## Cleanup

When Ralph reaches the CLEANUP checkpoint on Claude Code, use the host
built-in `simplify` skill when available as the cleanup contract.
