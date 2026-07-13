# Ralplan v2 Codex Adapter

<ADAPTER_CONTRACT>
This adapter binds the Ralplan v2 core to Codex. The core owns every semantic
decision; this file owns only host invocation and lifecycle mechanics. If they
conflict, the core wins. The generated core plus this adapter is sufficient:
longer platform, shared, and agent documents are optional maintenance context,
never a runtime prerequisite.
</ADAPTER_CONTRACT>

## CUSTOM-AGENT-FIRST BINDING

If `spawn_agent` is exposed, first make the actual registered-agent call below.
Do not infer unavailability from schema comments, displayed role lists, task
names, product/version assumptions, or uncertainty. A task name is never proof
that the registered role loaded.

```text
spawn_agent(agent_type="oh-no-<role>", message=<self-contained packet>,
            fork_turns="none")
```

Roles are `explore`, `analyst`, `planner`, and `plan-reviewer`; use those exact
`oh-no-*` types. Pass one payload shape (`message` or `items`), never both. Do
not request `fork_context`, a full-history fork, or inherited conversation.

Only an actual unknown/unavailable `agent_type` rejection confirms that the
custom role cannot be used in this task. Then record the failure and, when the
core permits fallback, use an exposed generic agent with the complete role
capsule and packet; otherwise run a separate inline role block. Never label a
generic child as a custom agent.

Classify other failures instead of treating all failures as unavailability:

```text
message + items conflict   -> retry once with exactly one payload shape
custom + history conflict  -> retry without history; keep fork_turns="none"
timeout / empty wait       -> still pending; keep waiting
thread / concurrency limit -> capture an existing dependency before new spawn
hidden selector/schema     -> record host primitive unavailable; do not edit config
```

```text
explore       = read-only repository facts and evidence; no requirements or plan ownership
analyst       = requirement gaps, risks, constraints, and open decisions; no plan body
planner       = canonical plan body and blocker dispositions; writes only .oh-no/plans/
plan-reviewer = read-only exact-draft two-pass review and verdict; never replacement plan
```

Every custom or fallback packet contains: run/state; role; exact bounded task; requirements source;
Direction Contract; Active Plan Contract; draft id and full draft/path when
applicable; scope/non-goals; permission boundary; required output; and
dependency/return owner. A generic packet also embeds the applicable role
capsule below. Copy only the core sections needed by that role.

## LIFECYCLE

Dispatch Analyst, Planner, and Plan-Reviewer only at their core state and in
strict sequence. Only a fired paired-review gate permits concurrent reviewers;
spawn both legs before waiting. After dispatch, wait through the exposed
lifecycle primitive until final status, capture and use the result, then clean
up only if an actual cleanup action exists. Timeout, empty/no-update, or a
queued acknowledgement is not final. Never interrupt a slow dependency, redo
it inline, invent `close_agent`, or use missing output as evidence.

Final role failure may use the core-allowed inline role fallback with the
failure recorded. Pending work may not. Missing required output after fallback
pauses the blocked transition.

## PAIRED REVIEW

On a named THOROUGH paired risk, start one Codex Plan-Reviewer and one independent
transport-owner Plan-Reviewer with the identical review packet. The
transport owner makes exactly one foreground Claude call when subprocess
permission, `${CLAUDE_BIN:-claude}`, and auth are available:

```text
claude --print --model opus --permission-mode dontAsk
       --no-session-persistence <redacted exact-review packet>
```

The packet carries the core reviewer capsule, forbids edits/installs/nested
workflow or another host hop, and requires the synchronous two-pass result.
The Codex parent must not make this call inline. A launch notice, background
acknowledgement, empty output, or status pointer is unavailable evidence.

```text
opposite-host success -> synthesize both host-tagged results under core section 8
opposite-host unavailable + default -> run a second independent Codex
                                      plan-reviewer and record same-host fallback
opposite-host unavailable + require-cross-host -> PAUSED
```

## USER CHOICE AND HANDOFF

Ask the core section 15 choice directly in the Codex conversation. On
explicit approve-and-run, invoke the selected installed Ralph or Ultrawork skill
yourself with the exact frozen plan/profile; do not ask the user to type a
command. Under Ultrawork, return control and the approved artifact to the caller
without another approval prompt.

Before every state transition, verify: actual custom-agent attempt or recorded fallback; correct role identity;
exact contract and draft; final dependency result captured; paired topology
valid; no premature next-skill invocation.
