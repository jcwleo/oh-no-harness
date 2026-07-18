# Ralplan Claude Code Adapter

<ADAPTER_CONTRACT>
This adapter binds the Ralplan core to Claude Code. The core owns every
semantic decision; this file owns only host invocation and lifecycle
mechanics. If they conflict, the core wins. The generated core plus this
adapter is sufficient: longer platform, shared, and agent documents are
optional maintenance context, never a runtime prerequisite.
</ADAPTER_CONTRACT>

## Host Bindings

```text
user_choice      = structured question tool when exposed; otherwise one direct
                   plain-text question and wait
native_role(r)   = plugin agent `oh-no-harness:<r>` through the exposed Task,
                   Agent, Workflow agent(), or equivalent subagent primitive;
                   manual mention form is `@agent-oh-no-harness:<r>`
roles            = explore | analyst | planner | plan-reviewer
cross_host_role  = `oh-no-harness:plan-reviewer-codex`
next_skill       = invoke the installed Ralph or Ultrawork skill through the
                   host skill mechanism; never ask the user to type a command
```

Follow the active platform runtime document's dispatch policy for role
dispatch: dispatch is trigger-loaded — dispatch only after the active skill's
trigger fires. For each dispatch, send one self-contained packet containing:
run/phase; role; exact bounded task; requirements source; Direction Contract;
Active plan contract; draft id and full draft/path when applicable;
scope/non-goals; required output; and dependency/return owner. Do not assume
inherited conversation.

If the plugin agent is unavailable, use a generic subagent with the matching
`agents/<role>.md` prompt embedded. If no subagent primitive exists, optional
roles may use the core's visibly separate inline fallback. A required
Plan-Reviewer instead reports `dispatch-unavailable` to the core so the skill
records the blocker and transitions PAUSED; the adapter must not substitute an
inline pass.

## Lifecycle

Dispatch Analyst, Planner, and Plan-Reviewer only at their core phase and in
strict sequence. For a fired paired-review gate only, request both reviewer
legs before waiting. A dispatched result is a dependency: wait for final
status, capture and use the result, then clean up when the host exposes
cleanup. A notification, timeout, empty result, or queued/background
acknowledgement is not completion. Do not duplicate pending work inline.

## Cross-Host Consult Channel

On a named THOROUGH paired risk, dispatch the current-host `plan-reviewer`
and `plan-reviewer-codex` with the identical review packet. The Codex consult
is read-only, foreground/synchronous, one hop, and returns the actual Codex
Plan-Reviewer result — not a launch notice or Claude-authored substitute.
Neither reviewer may make another cross-host hop.

```text
opposite-host success -> synthesize both host-tagged results into one verdict
opposite-host unavailable + default -> second independent Claude
                                       plan-reviewer; record same-host fallback
opposite-host unavailable + require-cross-host -> PAUSED
```

## Approval Handoff

Use one user interaction for the four combined choices in the core's
`## Next Skill Handoff`. After explicit approve-and-run, invoke the selected
skill yourself with the exact frozen plan and execution profile. Under
Ultrawork, return the approved artifact and control to the caller instead of
opening a second prompt.

Before every phase transition, verify: correct role identity; exact contract
and draft; final dependency result captured; paired topology valid; no
premature next-skill invocation.
