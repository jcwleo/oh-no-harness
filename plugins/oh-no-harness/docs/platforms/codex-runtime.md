# Codex Runtime Rules

This compact platform section is embedded in generated Codex-facing skill
documents.

## Skill Loading

Codex-facing public skills live under `skills/`. Generated
`skills/<skill>/SKILL.md` files compose the matching skill core, this compact
runtime section, and any Codex skill-specific overlay such as
`docs/platforms/codex-<skill>.md`.

## User Approval And Prompting

Ask approval, preference, scope, or next-step questions directly in the Codex
conversation. Keep prompts outcome-first: state the desired outcome,
acceptance criteria, non-goals or side effects, expected evidence, and output
shape before detailed steps.

Use compact final answers unless the active skill requires a plan, review, or
verification report. Preserve durable state in written artifacts before long
work, compaction, or handoff.

## Role Dispatch

Dispatch only after the active skill's trigger fires, then read
`docs/platforms/codex.md` `## Role Dispatch` for the full host contract. Use
`spawn_agent(task_name="ralplan_planner_draft_01", agent_type="oh-no-planner", message=<self-contained packet>, fork_turns="none")` first; the legacy `spawn_agent(agent_type="oh-no-planner", ...)` shorthand is incomplete
(omitting `fork_turns="none"` defaults to a full-history fork, which rejects a custom
`agent_type`), do not combine it with `fork_context=true`, and use generic
prompt embedding only after the custom agent is actually rejected. The example encodes the Ralplan workflow, Planner role, draft phase, and stable ordinal; derive each caller's concrete identity the same way and keep sibling names unique. The task packet carries scope, ownership, expected
output, and lifecycle; task names match `^[a-z0-9_]+$`, use deterministic workflow/role/phase-or-lens/stable-ordinal sibling uniqueness, and never replace requested `agent_type` plus child `agent_role` and matching developer instructions as role proof.

Every dispatched result is a dependency: `wait_agent` must reach final status,
the caller captures and uses the output, and only then performs lifecycle
cleanup. Timeout, empty output, or "No agents completed yet" is not final; do
not close, redo inline, or use missing output as evidence.

## Generic Role Prompt Fallback

After confirmed custom-agent unavailability, embed
`docs/agent-core/<role>.md`; see the full platform doc for the fallback shape.

## Cross-Host Consult Channel

This channel is trigger-loaded, not embedded in every workflow decision. When a
named THOROUGH paired-review or Fusion Rescue trigger fires, read and apply
`docs/platforms/codex.md` `## Cross-Host Consult Channel` before dispatch. Until
then, do not preload opposite-host invocation details.
