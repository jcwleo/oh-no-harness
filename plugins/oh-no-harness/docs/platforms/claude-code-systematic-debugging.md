# Systematic Debugging Claude Code Adapter

<ADAPTER_CONTRACT>
This adapter binds the Systematic Debugging core to Claude Code. The core
owns every semantic decision; this file owns only host invocation and
lifecycle mechanics. If they conflict, the core wins. The generated core
plus this adapter is sufficient: longer platform, shared, and agent
documents are optional maintenance context, never a runtime prerequisite.
</ADAPTER_CONTRACT>

## Role Dispatch

Dispatch roles through the exposed Task, Agent, Workflow `agent()`, or
subagent primitive with the plugin agents from `agents/`
(`oh-no-harness:<agent>`; manual mention `@agent-oh-no-harness:<agent>`).
Dispatch is trigger-loaded — dispatch only after the core's trigger fires.
Pass the core-defined role envelope and debugging delta unchanged. Parallel
hypothesis debuggers are one batch — request all before waiting. A notification,
timeout, or empty wait result is not a final status; capture each result,
then close or clean up the completed subagent when the host exposes that
mechanism. If a plugin-scoped agent is unavailable, embed the matching
`agents/<agent>.md` prompt into the available subagent mechanism; with no
subagent primitive, keep the role boundary inline and record the fallback.

## Model Diversity Pair

This section applies ONLY when the core selected `perspective-pair` after a
named trigger fired, selected a named THOROUGH paired `debugger`, or the caller
explicitly demanded strict diversity. It never applies to every dispatched
review. For the default `single-reviewer` post-fix review, dispatch exactly ONE
full-role `code-reviewer` using the declared stored primary, with NO diversity
leg, NO model override, and no `Assigned perspective:` line.

Once a pair is actually selected, dispatch two same-role instances in parallel
and synthesize one result. Both legs MUST be requested in a single batch: issue
both subagent tool calls in the same assistant turn (or with `Background: yes`
for both) BEFORE waiting on either result; a serial dispatch-wait-dispatch
sequence is not a valid pair. The two legs' packet bodies MUST be identical except the single `Assigned perspective:` line
(Lens A on the primary leg, Lens B on the diversity leg); leg identity (`primary` vs `diversity`) is carried ONLY by
the host dispatch metadata (the description field and the model override), never
inside the packet text. Read
that role's declared stored primary and the validated secondary top-tier model
from the session `<OH_NO_MODEL_DIVERSITY>` block.

- `model-diversity-pair`: the primary leg is dispatched without a model
  override and therefore uses the concrete declared-frontmatter primary; the
  diversity leg uses an explicit NATIVE model override for the validated
  secondary. The primary must not be `host-default`, and the secondary must
  differ from the declared stored primary.
- `same-model-parallel-fallback`: when no valid diversity configuration exists,
  the declared primary cannot be applied, or the secondary override fails in
  default mode, dispatch two independent same-model instances of the selected
  role and record the reason.
- `require-model-diversity`: an explicit caller demand for diversity is strict;
  if the diversity leg is unavailable or fails, transition to PAUSED. Do not
  substitute the same-model fallback.
