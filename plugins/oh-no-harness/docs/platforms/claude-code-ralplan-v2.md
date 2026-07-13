# Ralplan v2 Claude Code Adapter

<ADAPTER_CONTRACT>
This adapter binds the Ralplan v2 core to Claude Code. The core owns every
semantic decision; this file owns only host invocation and lifecycle mechanics.
If they conflict, the core wins. The generated core plus this adapter is
sufficient: longer platform, shared, and agent documents are optional
maintenance context, never a runtime prerequisite.
</ADAPTER_CONTRACT>

## HOST BINDINGS

```text
user_choice      = structured question tool when exposed; otherwise one direct
                   plain-text question and wait
native_role(r)   = plugin agent `oh-no-harness:<r>` through the exposed Task,
                   Agent, Workflow agent(), or equivalent subagent primitive
roles            = explore | analyst | planner | plan-reviewer
cross_host_role  = `oh-no-harness:plan-reviewer-codex`
next_skill       = invoke the installed Ralph or Ultrawork skill through the
                   host skill mechanism; never ask the user to type a command
```

For each dispatch, send one self-contained packet containing: run/state;
role; exact bounded task; requirements source; Direction Contract; Active Plan
Contract; draft id and full draft/path when applicable; scope/non-goals;
permission boundary; required output; and dependency/return owner. Copy only
the core sections needed by that role. Do not assume inherited conversation.

If the plugin agent is unavailable, use a generic subagent with this role
capsule; if no subagent primitive exists, execute the same capsule in a visibly
separate inline role block and record the fallback:

```text
explore       = read-only repository facts and evidence; no requirements or plan ownership
analyst       = requirement gaps, risks, constraints, and open decisions; no plan body
planner       = canonical plan body and blocker dispositions; writes only .oh-no/plans/
plan-reviewer = read-only exact-draft two-pass review and verdict; never replacement plan
```

## LIFECYCLE

Dispatch Analyst, Planner, and Plan-Reviewer only at their core state and in
strict sequence. For a fired paired-review gate only, request both reviewer
legs before waiting. A dispatched result is a dependency: wait for final
status, capture and use the result, and then clean up only if the host exposes
cleanup. A notification, timeout, empty result, or queued/background
acknowledgement is not completion. Do not duplicate pending work inline.

Final role failure may use the core-allowed inline fallback with the failure
recorded. Pending work may not. Missing required output after fallback pauses
the blocked transition.

## PAIRED REVIEW

On a named THOROUGH paired risk, dispatch the ordinary current-host
`plan-reviewer` and `plan-reviewer-codex` with the identical review packet. The
Codex consult is read-only, foreground/synchronous, one hop, and returns the
actual Codex Plan-Reviewer result, not a launch notice or Claude-authored
substitute. Neither reviewer may make another cross-host hop.

```text
opposite-host success -> synthesize both host-tagged results under core section 8
opposite-host unavailable + default -> run a second independent Claude
                                      plan-reviewer and record same-host fallback
opposite-host unavailable + require-cross-host -> PAUSED
```

## APPROVAL HANDOFF

Use one user interaction for the four direct choices required by core section
15. After explicit approve-and-run, invoke the selected skill yourself with the
exact frozen plan and execution profile. Under Ultrawork, return the approved
artifact and control to the caller instead of opening a second user prompt.

Before every state transition, verify: correct role identity; exact contract and
draft; final dependency result captured; paired topology valid; no premature
next-skill invocation.
