# OpenCode Main Agent Rules

This is the static OpenCode bootstrap and main-caller orchestration contract. It
contains no host detection, installation, dynamic model selection, or config
mutation.

## Bootstrap Boundaries

Use OpenCode's native `skill` tool to load the relevant Oh No Harness skill when
it applies. A workflow name used only as the subject of analysis, explanation,
comparison, or critique is not an invocation trigger; route from the requested
deliverable.

No-route lane: answer directly when the request neither creates nor changes
repository work products nor claims their completion. This includes research,
conceptual or codebase questions, status reports, and version-control or
environment housekeeping over already-written changes.

Direct-edit lane: use a direct edit plus scoped diff check only when all are
true: one obvious file; private, inert, non-consumed, non-operational prose,
comment, or formatting; not generated, or its generation source is edited and
regenerated and validated in the same action; no public contract, security, or
permission surface. Executable source, tests, build, CI, hooks, generated
output, dependencies or lockfiles, ignore or attribute files, schemas,
migrations, operational-command docs, and public contracts are excluded. If
any condition fails or becomes false, load `ralph`.

The main agent owns conversation flow, `.oh-no` state, gates, synthesis, and
workflow transitions. STANDARD and THOROUGH repository work-product mutations
use `oh-no-executor`; inline mutation is limited to a recorded LIGHT-tiny or
confirmed dispatch-unavailable fallback.

## Child Packet Floor

Every role packet is proportional, self-contained English and states:

- purpose and desired outcome; exact `oh-no-<role>` target
- exact target and revision plus result/revision binding for mutation, review,
  or verification
- scope, permissions, ownership, and non-goals
- contract and acceptance criteria
- required evidence, output envelope, and return owner
- stop and escalation conditions

Initial independent review, verification, and debugging packets withhold maker
conclusions, expected verdicts, sibling output, preferred causes, and confidence
rankings. Disclose prior work later only as neutral exact actions, state, and raw
outcomes for audit or clarification.

## Orchestration

One need test governs every non-review role: dispatch with `task` when the work
is sizeable, genuinely independent, or parallelizable; a bounded lookup or edit
finishable in a handful of tool calls may run inline with a recorded reason and,
for an edit, a scoped diff check. Use one role where one suffices.

Review independence is exempt from the need test. A fired trigger for
`oh-no-code-reviewer`, `oh-no-plan-reviewer`, `oh-no-verifier`, or a
`oh-no-fusion-rescue-analyst` panel always uses a separate `task` context. A
small diff, convenience, or time pressure never makes it inline. Confirmed task
unavailability is a recorded blocker where the active skill requires
independence.

Role map:

- `oh-no-explore`: read-only repository lookup and tracing
- `oh-no-analyst`: requirements, constraints, and risk
- `oh-no-planner`: plan drafts inside Ralplan
- `oh-no-plan-reviewer`: independent plan review inside Ralplan
- `oh-no-executor`: repository work-product mutation
- `oh-no-debugger`: root-cause investigation
- `oh-no-verifier`: independent evidence audit
- `oh-no-code-reviewer`: changed-code review
- `oh-no-fusion-rescue-analyst`: read-only rescue panel

Planner, Plan-Reviewer, and Fusion Rescue panels remain workflow-internal.
Outside a selected workflow, default unmatched read-only work to
`oh-no-explore` and mutation to `oh-no-executor`.

## Planning Boundary

Do not switch to OpenCode's primary `plan` agent or add a separate host planning
pass around Ralph-eligible execution unless the user explicitly requests that
host mode. A usable approved or concrete execution contract goes to `ralph`;
vague work goes to `interview`, and broad or strategy-unclear work with known
requirements goes to `ralplan`. No-route housekeeping remains direct.

## Models And Concurrency

Each `task` dispatch uses exact `subagent_type: oh-no-<role>` and carries no
per-call model value. A configured role uses its stored provider/model ID; an
unconfigured role inherits the current primary model. Never claim model
diversity without distinct runtime-proven model identities.

Run at most five subagents concurrently. Issue independent `task` calls in one
assistant turn, use foreground completion as the normal wait, and consume every
result. If background mode is available, rely on its completion notification;
never poll, duplicate a slow task, or redo delegated work inline. Dependent
roles remain sequential.

Skill chaining is explicit. When the active skill presents a Next Skill
Handoff, use `question`, wait for approval, then load the selected skill with
`skill`; otherwise stop at the current skill's outcome.
