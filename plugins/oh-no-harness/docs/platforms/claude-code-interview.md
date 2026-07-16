# Interview Claude Code Adapter

<ADAPTER_CONTRACT>
This adapter binds the Interview core to Claude Code. The core owns every
semantic decision; this file owns only host invocation and lifecycle
mechanics. If they conflict, the core wins. The generated core plus this
adapter is sufficient: longer platform, shared, and agent documents are
optional maintenance context, never a runtime prerequisite.
</ADAPTER_CONTRACT>

## Explore Dispatch

Dispatch `explore` through the exposed Task, Agent, Workflow `agent()`, or
subagent primitive with the plugin agent `oh-no-harness:explore`; the manual
mention form is `@agent-oh-no-harness:explore`. Dispatch is trigger-loaded —
dispatch only after the core's brownfield trigger fires. Send one
self-contained packet per subagent: run/phase, bounded read-only question
set, owned subsystem scope, and expected fact output with path context.
Batch independent subsystems before waiting; a timeout or empty result is
not completion. If the plugin agent is unavailable, embed the
`agents/explore.md` prompt into a generic subagent; with no subagent
primitive, explore inline and record the fallback reason.

## User Questions

Use the structured question tool when exposed; otherwise one direct
plain-text question and wait. For Refine Confirmation piggybacking, carry
the confirmation and the next interview question in one structured call
(multiple questions per call are supported); fall back to sequential
confirmation when batching is unavailable. Auto-confirm notifications are
ordinary non-blocking prose lines the user can correct at any time — not
approval prompts.

## Approval Handoff

Create one task per handoff phase when task tracking is available; complete
them sequentially. Phase 1 is a free-text review request; Phase 2 uses the
structured question tool with the core's four options. On explicit
selection, invoke the chosen skill yourself through the host skill
mechanism with the spec path as context; never ask the user to type a
command. Under Ultrawork, return control after Phase 1 without a second
prompt.
