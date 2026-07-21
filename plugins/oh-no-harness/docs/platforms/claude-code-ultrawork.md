# Ultrawork Claude Code Adapter

<ADAPTER_CONTRACT>
This adapter binds the Ultrawork core to Claude Code. The core owns every
semantic decision; this file owns only host invocation and lifecycle
mechanics. If they conflict, the core wins. The generated core plus this
adapter is sufficient: longer platform, shared, and agent documents are
optional maintenance context, never a runtime prerequisite.
</ADAPTER_CONTRACT>

## Sub-Skill Invocation

Invoke `interview`, `ralplan`, and `ralph` through the host skill
mechanism with the artifact path as context; never ask the user to type a
command. The sub-skill's own generated wrapper is its source of truth —
do not restate its rules in the handoff prompt.

## Phase-Agent Dispatch

Dispatch phase agents through the exposed Task, Agent, Workflow `agent()`,
or subagent primitive with the plugin agents from `agents/`
(`oh-no-harness:<agent>`; manual mention `@agent-oh-no-harness:<agent>`).
Dispatch is trigger-loaded — dispatch only after the active phase's trigger
fires. Pass the core-defined role envelope and phase delta unchanged. Batch
independent background agents before waiting; a notification,
timeout, or empty wait result is not a final status. Capture each result
and changed-file set, then close or clean up the completed subagent when
the host exposes that mechanism; record when no close mechanism exists. If
a plugin-scoped agent is unavailable, embed the matching `agents/<agent>.md`
prompt into the available subagent mechanism.

## Model Diversity Pair

For any dispatched Final Validation `code-reviewer` pair (every dispatched
review), dispatch two same-role instances in parallel and synthesize one verdict.
Both legs MUST be requested in a single batch: issue both subagent tool calls in
the same assistant turn (or with `Background: yes` for both) BEFORE waiting on
either result; a serial dispatch-wait-dispatch sequence is not a valid pair. The two legs' packet bodies MUST be identical except the single `Assigned perspective:` line
(Lens A on the primary leg, Lens B on the diversity leg); leg identity
(`primary` vs `diversity`) is carried ONLY by the host dispatch metadata (the
description field and the model override), never inside the packet text. Read
the role's declared stored primary and the validated secondary top-tier model
from the session `<OH_NO_MODEL_DIVERSITY>` block.

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

## Worktree Commands

Use ordinary `git worktree add .oh-no/worktrees/<task-slug> -b <branch>`
from the integration checkout; inspect task changes with
`git -C .oh-no/worktrees/<task-slug> status`. Remove the worktree only
after integration and post-merge verification complete.
