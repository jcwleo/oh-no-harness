# Codex Platform Rules

Use this file only from Codex-facing skill wrappers.

## Skill Loading

Codex-facing public skills live under `skills/`. Each wrapper applies the
matching `docs/skill-core/<skill>.md` file as the shared workflow source of
truth, then applies this Codex platform file.

## User Approval

When a core skill asks for approval, preference, scope, or next-step selection,
ask the user directly in the current Codex conversation. Present options as
actions the host agent will take. Do not tell the user to run a command manually
when the skill handoff expects the host agent to invoke the next skill.

## Auto Routing

The `auto-routing` skill can explain and preserve the config file shape in
Codex, but it does not add forced routing to Codex SessionStart. Codex native
skill loading remains the primary routing surface. If Codex-facing
SessionStart hooks run, they must stay compact and must not embed full skill
core bodies.

## OpenAI-Aligned Prompting

This file carries the runtime-sized OpenAI guidance for Codex. The longer
maintenance reference lives in `docs/providers/openai.md`, but Codex-facing
skill wrappers do not load provider docs as an extra runtime layer.

For OpenAI/Codex models, keep prompts outcome-first:

- state the desired outcome, acceptance criteria, non-goals or side effects,
  and expected evidence before detailed steps
- keep tool and role instructions close to the place where the tool or role is
  used
- specify output shape for plans, reviews, verification, and final reports
- use compact final answers unless the active skill requires an evidence log or
  approval brief
- preserve durable state in written artifacts before long work, compaction, or
  handoff

When the host exposes reasoning or verbosity controls, use the lightest setting
that can produce credible evidence. Raise effort for broad planning, deep code
review, hard debugging, or multi-agent integration; lower it for small,
mechanical, or already-isolated work.

## Role Dispatch

Codex role dispatch is host-policy controlled. Use `spawn_agent` only when the
current host tool definition exposes it, the active skill permits dispatch, and
the role has an isolated read-only scope, disjoint write ownership, or an
independent review or verification responsibility.

Explicit user or plan wording such as `subagent`, `spawn`, `delegate`,
`parallel agents`, `parallel subagents`, or `one agent per` is sufficient when
the host permits dispatch. Natural dispatch is allowed only when the host tool
definition permits it and the active skill explicitly allows natural dispatch
for the role.

When the user, plan, or skill states a standing preference to maximize
subagents, treat that as explicit authorization for eligible isolated roles
inside the active workflow. Keep Codex host-policy limits, but do not require
the user to repeat literal subagent wording on every step.

For `ralplan`, Planner, Architect, and Critic should run as sequential
subagents whenever dispatch is available because independent context improves
planning, review, and critique. Architect waits for Planner. Critic waits for
Architect.

When dispatch is unavailable, keep the same role boundary inline and record the
fallback reason when the core skill requires it.

## Role Prompt Embedding

Before every Codex role dispatch for an Oh No Harness role, read the matching
`agents/<role>.md` file and embed that prompt content in the spawned-agent
message. Do not rely on the role name alone.

Every Codex role dispatch must include:

```text
Agent prompt source: agents/<role>.md
Agent prompt content:
<matching agents/<role>.md prompt content>
```

For `ralph`, also apply `docs/platforms/codex-ralph.md`.
