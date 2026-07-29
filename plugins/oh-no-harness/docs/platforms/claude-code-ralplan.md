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
strict sequence. For a fired paired-review gate at the pair-bearing topology
only, request both reviewer legs before waiting; the single-reviewer topology
requests exactly one leg. A dispatched result is a dependency: wait for final
status, capture and use the result, then clean up when the host exposes
cleanup. A notification, timeout, empty result, or queued/background
acknowledgement is not completion. Do not duplicate pending work inline.

## Model Diversity Pair

This section applies ONLY when the core selected `perspective-pair` after a
named paired-review trigger fired, or the caller explicitly demanded strict
diversity. It never applies to every dispatched THOROUGH review: ordinary
THOROUGH is `single-reviewer`, exactly like STANDARD, and must
dispatch exactly ONE full-role `plan-reviewer` using the declared stored
primary, with NO diversity leg, NO model override, and no
`Assigned perspective:` line.

Once a pair is actually selected,
dispatch two same-role instances in parallel and synthesize one verdict. Both legs MUST be
requested in a single batch: issue both subagent tool calls in the same
assistant turn (or with `Background: yes` for both) BEFORE waiting on either
result; a serial dispatch-wait-dispatch sequence is not a valid pair. The two legs'
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
  default mode, dispatch two independent same-model `plan-reviewer` instances
  and record the reason.
- `require-model-diversity`: an explicit caller demand for diversity is strict;
  if the diversity leg is unavailable or fails, transition to PAUSED. Do not
  substitute the same-model fallback.

## Approval Handoff

Use one user interaction for the four combined choices in the core's
`## Next Skill Handoff`. After explicit approve-and-run, invoke the selected
skill yourself with the exact frozen plan and execution profile. Under
Ultrawork, return the approved artifact and control to the caller instead of
opening a second prompt.

Before every phase transition, verify: final dependency result captured; and
at the pair-bearing topology, paired topology valid.
