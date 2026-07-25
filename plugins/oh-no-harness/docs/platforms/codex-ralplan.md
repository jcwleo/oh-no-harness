# Ralplan Codex Adapter

<ADAPTER_CONTRACT>
This adapter binds the Ralplan core to Codex. The core owns every semantic
decision; this file owns only host invocation and lifecycle mechanics. If
they conflict, the core wins. The generated core plus this adapter is
sufficient: longer platform, shared, and agent documents are optional
maintenance context, never a runtime prerequisite.
</ADAPTER_CONTRACT>

## Custom-Agent-First Binding

Follow the active platform runtime document's dispatch policy: dispatch is
trigger-loaded — dispatch only after the active skill's trigger fires. If
`spawn_agent` is exposed, first make the actual registered-agent call below.
Do not infer unavailability from schema comments, displayed role lists, task
names, or uncertainty; a task name is never proof that the registered role
loaded.

Derive each name from the actual Ralplan role and phase or review lens. For the
planner and its two sibling review legs, use distinct identities such as:

```text
spawn_agent(task_name="ralplan_planner_draft_1", agent_type="oh-no-planner", message=<self-contained packet>, fork_turns="none")
spawn_agent(task_name="ralplan_plan_reviewer_feasibility_1", agent_type="oh-no-plan-reviewer", message=<self-contained packet>, fork_turns="none")
spawn_agent(task_name="ralplan_plan_reviewer_coverage_1", agent_type="oh-no-plan-reviewer", message=<self-contained packet>, fork_turns="none")
```

Roles are `explore`, `analyst`, `planner`, and `plan-reviewer`; use those exact
`oh-no-*` types and derive role-correct equivalents for every other dispatch.
Pass one payload shape (`message` or `items`), never both. Do not request
`fork_context` or inherited conversation.

Only an actual unknown/unavailable `agent_type` rejection confirms the
custom role cannot be used. Then record the failure and use an exposed
generic agent with the matching `docs/agent-core/<role>.md` prompt embedded.
If no separate agent context exists, optional roles may use the core's recorded
inline fallback; a required Plan-Reviewer instead reports
`dispatch-unavailable` so the core records the blocker and transitions PAUSED.
Never label a generic child as a custom agent or substitute an inline required
review. Classify other failures:

```text
message + items conflict   -> retry once with exactly one payload shape
custom + history conflict  -> retry without history; keep fork_turns="none"
timeout / empty wait       -> still pending; keep waiting
thread / concurrency limit -> capture an existing dependency before new spawn
```

Every packet contains: run/phase; role; exact bounded task; requirements
source; Direction Contract; Active plan contract; draft id and full
draft/path when applicable; scope/non-goals; required output; and
dependency/return owner.

## Lifecycle

Dispatch Analyst, Planner, and Plan-Reviewer only at their core phase and in
strict sequence. Every dispatched Plan-Reviewer review runs as a concurrent
perspective pair; spawn both legs before waiting. Wait through the exposed
lifecycle primitive until final status, capture and use the result, then
clean up only if an actual cleanup action exists. Timeout, empty/no-update,
or a queued acknowledgement is not final. Never interrupt a slow dependency,
redo it inline, or use missing output as evidence.

## Cross-Host Consult Channel

On a named THOROUGH paired risk, start one Codex Plan-Reviewer and one
transport-owner Plan-Reviewer. The two review legs receive redacted packets identical except the single `Assigned perspective:` line.
The transport owner makes exactly one foreground Claude call when subprocess
permission, `${CLAUDE_BIN:-claude}`, and auth are available:

```text
claude --print --model opus --permission-mode dontAsk
       --no-session-persistence <redacted exact-review packet>
```

The packet forbids edits, installs, nested workflows, or another host hop,
and requires the synchronous two-pass result. A launch notice, background
acknowledgement, empty output, or status pointer is unavailable evidence.

```text
opposite-host success -> synthesize both host-tagged results into one verdict
opposite-host unavailable + default -> second independent Codex
                                       plan-reviewer; record same-host fallback
opposite-host unavailable + require-cross-host -> PAUSED
```

## Re-Homed Core Pair Rules

| Cross-host review | named THOROUGH paired-review trigger | trigger and topology; synthesis evidence | never required in STANDARD or without trigger |

Plan-Reviewer receives the exact Active plan contract, draft id, and full
draft or path, then runs the architecture pass and the quality-gate pass in
one dispatch [R3]. Every required Plan-Reviewer pass runs in a separate
context. If the named role is unavailable, use a generic separate subagent or
the existing same-host/cross-host fallback. If no separate context exists,
record `Plan-Reviewer: dispatch-unavailable` as a blocker and transition to
PAUSED; an inline review cannot satisfy the required pass. The compliant LIGHT
no-review carve-out remains unchanged.

```text
STANDARD -> one perspective-diverse Plan-Reviewer pair on Codex, recorded as
            same-host-perspective-pair; this is intentional same-host review,
            so no fallback reason is required.
THOROUGH -> the same perspective-diverse pair. A named security/data/destructive,
            public/release-contract, concurrency, migration, or comparable
            multi-system trigger selects cross-host review when available, or
            same-host-parallel-fallback when the opposite host is unavailable;
            record the fallback reason. `require-cross-host` pauses instead.
```

The two review legs receive redacted packets identical except the single `Assigned perspective:` line.

A required Plan-Reviewer is
the exception: it must use a separate context, with a generic separate subagent
or the existing same-host/cross-host fallback when the named role is
unavailable; if none exists, record the blocker and transition PAUSED instead
of reviewing inline.

## Approval Handoff

Ask the core's `## Next Skill Handoff` combined choice directly in the Codex
conversation. On explicit approve-and-run, invoke the selected installed
Ralph or Ultrawork skill yourself with the exact frozen plan and profile; do
not ask the user to type a command. Under Ultrawork, return control and the
approved artifact to the caller without another approval prompt.

Before every phase transition, verify: actual custom-agent attempt or
recorded fallback; correct role identity; exact contract and draft; final
dependency result captured; paired topology valid; no premature next-skill
invocation.
