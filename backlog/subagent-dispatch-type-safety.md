# TODO: Subagent Dispatch Type-Selection Safety (Claude Code adapter)

- Status: **text-only approach implemented** (`5c9e578`, unreleased). The Claude
  adapter blocks are now selector-first, generic types are barred while a
  matching role exists, and unmatched work defaults to `explore` / `executor`.
  A `PreToolUse` guard was NOT added, so wrong-type dispatch is discouraged but
  still not hard-blocked — the residual gap below stands.
- Platform: **Claude Code only.** This is a Claude Code Agent/Task tool behavior;
  it does not occur on Codex.
- Backlog: `backlog/`
- Scope: the **Claude Code adapter** — specifically the Claude-Code-only guidance
  blocks emitted by `hooks/session-start` (`OH_NO_SUBAGENT_ROLE_LABEL` and
  `OH_NO_MAIN_AGENT_ORCHESTRATION`, both already gated by `is_claude_code` and
  marked "Claude Code-only"), and optionally a new Claude-only `PreToolUse` guard
  hook. This item adds/reframes content **inside the Claude Code adapter layer
  only** — NOT platform-neutral skill/agent cores, and NOT the Codex adapter.
- Goal: make it structurally hard to dispatch an Oh No Harness role on the wrong
  agent type / wrong model on Claude Code, and loud (not silent) when it happens.

## Why Claude-Code-only

The observed failure is a property of the **Claude Code Agent/Task tool**: the
role is selected by the `subagent_type` parameter, and omitting it **silently**
falls back to a general-purpose agent inheriting the parent model. Codex uses a
different mechanism — `spawn_agent(agent_type="oh-no-<role>")` — documented
separately in the Codex adapter, and is **not** affected by this specific bug. So
the fix belongs in the Claude Code adapter, and the two guidance blocks it would
touch are already Claude-Code-only strings in `hooks/session-start` (they are not
shared with Codex and are not generated from `docs/`).

## Problem (observed)

While orchestrating a Ralph run, the main agent dispatched the `executor` role
through the Claude Code Agent tool but **omitted the `subagent_type` parameter**.
The call set only `description` (carrying the `[oh-no-harness:executor]` prefix)
and `prompt`. Result: the host launched a **general-purpose** agent inheriting
the **parent model (opus)** instead of the `oh-no-harness:executor` role prompt
on its configured model (`gpt-5.6-sol`). The run proceeded on the wrong agent and
model until the user noticed the model in the statusline and flagged it; the
mis-dispatched agent was stopped before it edited anything and re-dispatched
correctly.

### Root causes (three, overlapping)

1. **Label mistaken for type selection.** The `[oh-no-harness:<role>]` prefix in
   `description` is a statusline label only (`OH_NO_SUBAGENT_ROLE_LABEL`). The
   field that actually selects the role and its configured model is the separate
   `subagent_type`. Because the label string is identical to the type value,
   embedding the role name in the description created a false sense that the role
   was already selected.
2. **Attention diverted by a long packet + model decision.** Prior calls
   (explore, planner, plan-reviewer) set `subagent_type` correctly. The executor
   call had a long dispatch packet and focus was on "role is configured on
   gpt-5.6-sol, so do NOT add a `model` override" — which pulled attention away
   from confirming the required type field.
3. **Silent host fallback.** The Agent tool does not error on a missing
   `subagent_type`; it silently falls back to general-purpose, which inherits the
   parent model. Only "launch success" metadata returns, so nothing surfaced the
   mistake until a human read the statusline.

The core hazard is **fail-silent**: the wrong outcome looks identical to success
at dispatch time.

## Prevention options (all within the Claude Code adapter)

### Option A — `PreToolUse` guard hook (structural enforcement)

Add a Claude-only `PreToolUse` hook that intercepts Agent/Task calls before they
run and:

- if `description` contains `[oh-no-harness:<role>]` but `subagent_type` is absent
  or not that role → **block (fail-loud)** with a correction message
  ("re-issue with `subagent_type: oh-no-harness:<role>`");
- if the host permits `tool_input` rewriting → parse the role from the prefix and
  **auto-inject `subagent_type`**.

This is the only mechanism that converts the silent fallback into a loud
rejection / auto-correction at spawn time.

**Honest cost.** The plugin deliberately runs **one `SessionStart` hook only — no
`PreToolUse`/`PostToolUse`** (a principle reaffirmed when the `UserPromptSubmit`
hook was removed, and stated in `CLAUDE.md` / `AGENTS.md`). Adding a `PreToolUse`
hook reverses that principle and adds overhead to every tool call. It is naturally
Claude-only (Codex has no equivalent interception point), which fits this
Claude-Code-only item, but the single-hook reversal is an owner-level
architecture trade-off, not a free win.

### Option B — Type-first reframe of the Claude adapter blocks (text-only)

Keep the single-hook architecture and edit the Claude-Code-only guidance strings
in `hooks/session-start`:

- In `OH_NO_SUBAGENT_ROLE_LABEL`, describe the prefix as a **mirror of the
  `subagent_type` field**, not an independent step. Add explicitly: "This prefix
  is a display label only and does NOT select the agent; the role is chosen by
  `subagent_type: oh-no-harness:<role>`. A prefix without the type field silently
  runs a generic agent on the parent model."
- In `OH_NO_MAIN_AGENT_ORCHESTRATION`, present dispatch as a **single atomic
  template with `subagent_type` first**, so the type is the leading, unmissable
  element rather than a field competing with a long packet.

Reduces probability; provides **no enforcement**. Applies only to the Claude Code
adapter (these blocks are Claude-Code-only), matching the platform scope of the
bug.

### Option C — Post-dispatch verification (weak, complementary)

Add one line to `OH_NO_MAIN_AGENT_ORCHESTRATION`: "immediately after dispatch,
confirm the launched row is the intended `oh-no-harness:<role>` on its configured
model (not a generic type / parent model) before relying on the result." This is
after-the-fact and depends on the agent noticing, so it is a backstop, not a fix.

### What the plugin cannot fix

The host's silent-fallback-on-missing-type is **Claude Code tool behavior**; the
plugin cannot change it. Options A/B/C only wrap around it.

## Recommendation

- If the owner accepts reversing the single-hook principle for enforcement →
  **Option A** (loudest).
- If the single-hook principle is preserved (likely, per current direction) →
  **Option B** as the primary fix, with **Option C** as a cheap complementary
  line. Keep additions to roughly two lines given the repo's minimal/
  canonical-prose norm.

Either way the change is confined to the Claude Code adapter; the Codex adapter is
untouched.

## Acceptance criteria

- The `OH_NO_SUBAGENT_ROLE_LABEL` block (Claude Code adapter) states that the
  prefix is display-only and names `subagent_type` as the actual selector,
  including the silent-generic-fallback consequence.
- The `OH_NO_MAIN_AGENT_ORCHESTRATION` block presents role dispatch type-first so
  the type field cannot be read as satisfied by the description prefix alone.
- (If Option A is chosen) a Claude-only `PreToolUse` guard blocks or auto-corrects
  a role-prefixed Agent/Task call that lacks the matching `subagent_type`, with a
  documented, tested behavior; the single-hook-architecture docs
  (`CLAUDE.md` / `AGENTS.md`) are updated to reflect the reversal.
- Changes land in `hooks/session-start` (and hook config for Option A); no
  platform-neutral core or Codex adapter is modified; existing validator /
  reachability / hook tests stay green.

## Non-goals

- Any change to the Codex adapter or Codex `spawn_agent` dispatch guidance (Codex
  is unaffected by this bug).
- Changing per-role configured models or the model-diversity pairing rules.
- Adding a persistent state ledger or background process.
- (Under Option B) claiming enforcement that text guidance cannot provide.

## Notes

- Individual feedback lesson ("role dispatch = `subagent_type` required; prefix is
  a label") is already recorded in agent memory; this backlog item is the
  systemic Claude-adapter prompt/hook fix.
- Must be handled as an independent change with a fresh scope decision — do NOT
  fold into the in-flight force-latest-cache plan (it is approved/frozen and this
  would break its scope trace).
