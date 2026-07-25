# Interview Codex Adapter

<ADAPTER_CONTRACT>
This adapter binds the Interview core to Codex. The core owns every
semantic decision; this file owns only host invocation and lifecycle
mechanics. If they conflict, the core wins. The generated core plus this
adapter is sufficient: longer platform, shared, and agent documents are
optional maintenance context, never a runtime prerequisite.
</ADAPTER_CONTRACT>

## Explore Dispatch

Dispatch is trigger-loaded — dispatch only after the core's brownfield
trigger fires. If `spawn_agent` is exposed, first make the actual
registered-agent call:

```text
spawn_agent(task_name="interview_explore_discovery_1", agent_type="oh-no-explore", message=<self-contained packet>, fork_turns="none")
```

Do not infer unavailability from schema comments, displayed role lists, or
task names — only an actual unknown/unavailable `agent_type` rejection
confirms the custom role cannot be used; then use a generic `explorer`
agent with the `docs/agent-core/explore.md` prompt embedded and record the
fallback. Pass one payload shape (`message` or `items`), never both; no
`fork_context`. Each packet carries run/phase, the bounded read-only
question set, owned subsystem scope, and expected fact output with path
context. Spawn the whole independent batch before `wait_agent`; a timeout,
empty wait, or queued acknowledgement is not final — keep waiting, and
never use missing output as evidence. Close a completed receiver only if
the host exposes a close primitive; if none exists, closure is
host-managed — record that and continue.

## User Questions

Ask directly in the Codex conversation, one focused question or
confirmation per round. For Refine Confirmation, combine the confirmation
and the next question in one message (sequential fallback is the same
message flow). Auto-confirm notifications are non-blocking prose lines the
user can correct at any time.

## Approval Handoff

Phase 1 posts the spec-review request as a direct question and waits.
Phase 2 presents the core's four options in the conversation and ends with
`Which approach?`. On explicit selection, invoke the chosen installed skill
yourself with the spec path as context; never ask the user to type a
command. Under Ultrawork, return control after Phase 1 without a second
prompt.
