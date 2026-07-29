# Codex Subagent Protocol Compatibility TODO

> Status: PROPOSAL / TODO — implementation handoff for a follow-up maintainer
> session. This document records the compatibility gap only; it does not change
> runtime skills, agent wrappers, generators, hooks, or tests.
>
> Motivating environment: `codex-cli 0.144.1`, observed 2026-07-10. Do not use
> this version as the dispatch switch; the active tool schema is the authority.

Backlog location: `backlog/`

## 2026-07-23 verified correction

A standalone physical-clone probe against `codex-cli 0.144.6` with the
`gpt-5.6-sol` model catalog verified the current V2 spawn contract:

- `task_name` and `message` are required; `agent_type` is an optional custom-agent
  selector, alongside `fork_turns`.
- Valid `task_name` values match `[a-z0-9_]+`.
- A dispatch using both `task_name` and `agent_type` produced a child with
  `agent_role=oh-no-explore`, model `gpt-5.6-terra`, and the exact developer
  source marker plus the full Explore instructions.

Therefore, the claims below that hosted V2 has no `agent_type` and must use a
generic embedded-role fallback are superseded for current `0.144.6`. The older
surface split, fallback design, acceptance criteria, and test proposal remain as
historical context but require re-review against the verified V2 contract.

### Follow-up: single shared platform owner

Do this as a separate task after current Task #37/T10/T11 are complete:

- Specify exact spawn syntax, task-name grammar and uniqueness, and `agent_role`
  proof in one shared Codex platform source only.
- Have the generator compose that source into every active Codex wrapper,
  including self-contained wrappers.
- Leave only workflow-specific role mappings and task-name slots in per-skill
  adapters; remove duplicated generic spawn syntax from them.
- Preserve Simplify's branch where `task_name` is required but `agent_type` is
  intentionally omitted.
- Make the validator enforce exactly one canonical owner and verify reachability
  and parity across all generated wrappers.
- Do not mix this follow-up with a release or routing change.

## TL;DR

Codex currently exposes two related but non-identical subagent surfaces:

1. **Local Codex custom agents** select installed roles such as
   `oh-no-code-reviewer` through an `agent_type`-capable spawn contract and load
   standalone TOML agent definitions from `~/.codex/agents/` or
   `.codex/agents/`.
2. **Hosted Responses Multi-agent** creates hierarchical task threads such as
   `/root/reviewer` through `spawn_agent(task_name, message, fork_turns)` and
   exposes hosted lifecycle actions such as `followup_task` and
   `interrupt_agent`. Its spawn action has no `agent_type`, and its documented
   action set has no `close_agent`.

Oh No Harness currently hard-codes the first surface in its Codex runtime
contracts. On the second surface, those instructions are impossible to follow:
`task_name="oh-no-code-reviewer"` names a thread but does **not** prove that the
installed `oh-no-code-reviewer` custom agent prompt was loaded. This can silently
degrade a required role dispatch into a generic subagent with a suggestive name.

The required improvement is a capability-selected dual protocol contract. The
runtime must inspect the spawn/lifecycle schema exposed in the current session,
select exactly one supported protocol, and preserve the same role-owned prompt
quality and lifecycle guarantees on both.

## Current Official Surfaces

### A. Local Codex custom-agent surface

Current Codex documentation supports standalone custom-agent TOML files under:

```text
~/.codex/agents/<agent>.toml
.codex/agents/<agent>.toml
```

Each agent requires at least:

```toml
name = "reviewer"
description = "When Codex should use this role."
developer_instructions = """
The role's stable behavior contract.
"""
```

Optional fields include `nickname_candidates`, `model`,
`model_reasoning_effort`, `sandbox_mode`, `mcp_servers`, and `skills.config`.
Oh No Harness already generates and installs nine `oh-no-*` agent files in this
shape.

Official reference:
<https://learn.chatgpt.com/docs/agent-configuration/subagents#custom-agents>

### B. Hosted Responses Multi-agent surface

The current hosted protocol identifies the root as `/root` and spawned threads
with hierarchical task paths such as `/root/reviewer`. The documented hosted
actions are:

| Action | Meaning |
|---|---|
| `spawn_agent` | Create a child and assign its first task. |
| `send_message` | Queue information without starting a new turn. |
| `followup_task` | Assign more work and start or resume a child turn. |
| `wait_agent` | Wait for a mailbox update. |
| `interrupt_agent` | Interrupt an active turn without deleting context. |
| `list_agents` | Inspect the current agent tree and statuses. |

Its spawn payload is task-oriented:

```text
spawn_agent(
  task_name = "reviewer",
  message = "<self-contained task and role packet>",
  fork_turns = "none" | "all" | "<recent-turn-count>"
)
```

There is no documented `agent_type` selector or `close_agent` action in this
surface. Agents share the configured model and tool set unless the hosting
product adds another capability outside this protocol.

Official reference:
<https://developers.openai.com/api/docs/guides/tools-multi-agent>

## Observed Contract Mismatch

The following source surfaces currently assume the local custom-agent protocol:

- `docs/platforms/codex-runtime.md`
- `docs/platforms/codex.md`
- `docs/platforms/codex-ralph.md`
- generated `skills/*/SKILL.md` files that compose Codex runtime guidance
- SessionStart standing-authorization text emitted by `hooks/session-start`
- static/live assertions in `scripts/validate-plugin-files.py` and
  `scripts/test-codex-plugin.sh`

Examples of stale single-protocol assumptions include:

- requiring `spawn_agent(agent_type="oh-no-<role>", ...)` on every Codex host;
- referring to `fork_context` when the hosted surface exposes `fork_turns`;
- requiring `close_agent` even when no close action exists;
- treating a failed `agent_type` call as the only valid proof that custom roles
  are unavailable;
- allowing generic fallback only after an `agent_type` rejection, even though
  the hosted schema cannot express that call at all.

### Why this is correctness-sensitive

The mismatch is not cosmetic invocation syntax. It affects role ownership:

```text
task_name = "oh-no-code-reviewer"
  != custom agent type selected
  != ~/.codex/agents/oh-no-code-reviewer.toml loaded
```

Without an explicit hosted fallback contract, a workflow can claim that the
`oh-no-code-reviewer`, `oh-no-verifier`, or `oh-no-planner` role produced an
output when the child only received a task label and a short ad hoc prompt.
That weakens the exact role prompt, independence proof, output contract, and
review/verification gates.

## Required Design

### 1. Select a protocol from capabilities, not versions

Add one deterministic decision table to the Codex runtime source of truth:

| Exposed capability | Selected protocol |
|---|---|
| `spawn_agent` accepts `agent_type` | `local-custom-agent` |
| `spawn_agent` accepts `task_name` + `fork_turns` and has hosted collaboration actions | `hosted-task-agent` |
| neither recognized shape is available | `subagent-unavailable` |

Rules:

- Inspect the current tool schema every session.
- Do not infer the protocol from Codex version, model name, app/CLI label, or a
  remembered previous session.
- Never attempt parameters that the exposed schema cannot accept merely to
  manufacture an "unknown agent" failure.
- Record the selected protocol in workflow evidence whenever role ownership is
  required for a gate.

### 2. Preserve role prompt quality on both protocols

#### Local custom-agent protocol

- Prefer the installed `agent_type="oh-no-<role>"`.
- Pass only task-specific scope, constraints, acceptance criteria, dependencies,
  and expected output in the spawn message.
- Do not duplicate the stable role body when the custom type is proven selected.
- Preserve the current rule that full-history forking must not be combined with
  a custom role when it would duplicate or contaminate role context.

#### Hosted task-agent protocol

- Treat `task_name` only as a unique task/thread identifier.
- Compile the matching `docs/agent-core/<role>.md` body into the child message,
  followed by a clearly delimited task-specific packet.
- Use one versioned role-packet format so every skill does not invent its own
  fallback prompt.
- Prefer `fork_turns="none"` for fully self-contained role packets. Permit a
  bounded recent-turn fork only when the role explicitly needs conversational
  evidence that cannot be safely copied into the packet.
- Never claim that a local TOML custom agent was loaded on this surface unless a
  future hosted capability provides explicit proof.

Recommended hosted packet shape:

```text
<oh_no_role_contract version="1" role="code-reviewer">
  <stable_role_prompt>
  Exact source body from docs/agent-core/code-reviewer.md.
  </stable_role_prompt>
  <task>
  One bounded assignment.
  </task>
  <scope>...</scope>
  <non_goals>...</non_goals>
  <permission_boundary>...</permission_boundary>
  <dependencies>...</dependencies>
  <expected_output>...</expected_output>
</oh_no_role_contract>
```

The compiled packet should be deterministic enough for static fixture tests to
compare required sections and role markers.

### 3. Normalize lifecycle semantics without inventing actions

Define platform-neutral lifecycle states and map them to each protocol:

| Lifecycle intent | Local custom-agent surface | Hosted task-agent surface |
|---|---|---|
| Spawn | `spawn_agent(agent_type=...)` | `spawn_agent(task_name=..., fork_turns=...)` |
| Add information | host-supported message/input action | `send_message` |
| Start follow-up turn | resume/send-input contract when available | `followup_task` |
| Wait | `wait_agent` | `wait_agent` |
| Stop active work | interrupt/close only as exposed | `interrupt_agent` |
| Inspect state | host-supported status/list action | `list_agents` |
| Cleanup completed thread | `close_agent` when exposed | record `close unavailable`; do not invent it |

Shared hard rules remain unchanged:

- timeout, empty wait, or no-update is not a final result;
- do not interrupt or close a slow dependency merely because it is slow;
- capture and use every required child result before advancing;
- do not redo delegated work inline or spawn a duplicate replacement;
- an absent close action is a recorded lifecycle capability, not a task failure;
- `interrupt_agent` is not a synonym for cleanup of a completed child.

### 4. Define protocol-specific role-ownership proof

#### Local proof

Record:

- requested `agent_type`;
- returned agent id/nickname when available;
- completed wait status;
- role-owned output and required terminator/fields.

#### Hosted proof

Record:

- selected protocol: `hosted-task-agent`;
- canonical task path returned by spawn (`/root/<task>`);
- requested role and versioned embedded role-contract marker;
- completed final message from that exact task path;
- required output fields/terminator.

Do not use `task_name` alone as proof. The proof is the combination of the
protocol selection, embedded stable role contract, canonical task path, and
captured final result.

### 5. Keep concurrency semantics surface-aware

- Local Codex uses `[agents] max_threads` and `max_depth` settings.
- Hosted Responses Multi-agent uses the host's
  `max_concurrent_subagents` limit across the tree.
- The runtime must honor the smaller limit visible to the active session and
  must not hard-code a global value such as three, four, or six.
- Batch rules and dependency ordering remain workflow-owned; protocol support
  must not make dependent roles parallel.

## Implementation TODO

### P0 — close false role-ownership claims

- [ ] Add the protocol capability decision table to
  `docs/platforms/codex-runtime.md`.
- [ ] Update `docs/platforms/codex.md` with full maintenance guidance and
  examples for both surfaces.
- [ ] Replace unconditional `agent_type`/`fork_context`/`close_agent` wording in
  `docs/platforms/codex-ralph.md` with protocol-specific branches.
- [ ] Define the hosted role-packet compiler contract using
  `docs/agent-core/<role>.md` as its stable prompt source.
- [ ] State explicitly that `task_name` is not an agent type and cannot prove a
  local TOML role was loaded.
- [ ] Update SessionStart standing authorization so it never commands a tool
  shape unavailable in the active session.

### P1 — align workflow and lifecycle policy

- [ ] Update `docs/shared/ralph-subagent-policy.md` with normalized lifecycle
  intents and protocol-specific mappings.
- [ ] Audit `ralplan`, `ralph`, `ultrawork`, `systematic-debugging`, `simplify`,
  `verification-before-completion`, and `fusion-rescue` for direct references to
  old action names.
- [ ] Preserve sequential role dependencies and cross-host recursion guards
  under both protocols.
- [ ] Define how an existing hosted child is reused through `followup_task`
  without weakening role/task boundaries.
- [ ] Define when `send_message` is informational versus when `followup_task` is
  required to start a new turn.
- [ ] Treat absent hosted cleanup as `close unavailable`, never as permission to
  interrupt a completed agent.

### P1 — validator and generator alignment

- [ ] Extend `scripts/validate-plugin-files.py` to reject unconditional
  single-protocol claims on Codex runtime surfaces.
- [ ] Validate that hosted role packets include the complete stable role body or
  an exact deterministic composition of it.
- [ ] Keep local generated custom-agent TOMLs fresh and continue enforcing the
  expected nine-agent count.
- [ ] Regenerate Codex-facing skill wrappers after source-doc changes.
- [ ] Ensure generated wrapper checks distinguish source changes from expected
  generated outputs.

### P1 — deterministic tests

- [ ] Add a local-schema fixture with `agent_type`, custom-agent selection, wait,
  and close lifecycle actions.
- [ ] Add a hosted-schema fixture with `task_name`, `fork_turns`,
  `followup_task`, `interrupt_agent`, and `list_agents`, without `agent_type` or
  `close_agent`.
- [ ] RED: prove the current runtime contract cannot satisfy the hosted fixture.
- [ ] GREEN: prove each fixture selects exactly one protocol and emits only
  arguments supported by that schema.
- [ ] Negative: a hosted dispatch named `oh-no-code-reviewer` without the
  embedded role contract must fail role-ownership validation.
- [ ] Negative: a hosted flow must not treat `interrupt_agent` as completed-child
  cleanup.
- [ ] Negative: a wait timeout/no-update must not count as completion on either
  protocol.
- [ ] Semantic: a final message from the wrong canonical task path must not
  satisfy a role dependency.
- [ ] Baseline: local named custom-agent installation and dispatch must continue
  working unchanged.

### P2 — live proof and release closure

- [ ] Retain the existing local `--named-agents-live` proof for installed
  `oh-no-*` custom agents.
- [ ] Add a hosted Multi-agent live lane that proves
  `spawn_agent(task_name, message, fork_turns)` plus wait/final-result capture.
- [ ] In the hosted lane, verify the role contract reached the child rather than
  accepting the task name as proof.
- [ ] Add lifecycle coverage for `send_message`, `followup_task`, and
  `interrupt_agent` only where each action's semantics are actually required.
- [ ] Record the exposed concurrency limit and prove the lane respects it.
- [ ] Update reference docs and release notes with the dual-protocol support
  boundary.

## Likely Source And Generated Files

Expected source scope:

```text
plugins/oh-no-harness/docs/platforms/codex-runtime.md
plugins/oh-no-harness/docs/platforms/codex.md
plugins/oh-no-harness/docs/platforms/codex-ralph.md
plugins/oh-no-harness/docs/shared/ralph-subagent-policy.md
plugins/oh-no-harness/docs/skill-core/{affected skills}.md
plugins/oh-no-harness/hooks/session-start
scripts/generate-skill-wrappers.py          # only if composition rules change
scripts/generate-agent-wrappers.py          # only if local TOML schema changes
scripts/validate-plugin-files.py
scripts/test-codex-plugin.sh
scripts/test-harness-lane-contract.py       # if a new live lane is added
plugins/oh-no-harness/docs/reference/test-harness-lanes.md
```

Expected generated outputs must be derived rather than hand-edited:

```text
plugins/oh-no-harness/skills/*/SKILL.md
plugins/oh-no-harness/docs/platforms/codex-agents/*.toml
```

The exact file list should be confirmed during planning. Do not touch every
skill core merely because it contains generated runtime text; prefer one shared
Codex runtime contract when that is sufficient.

## Acceptance Criteria

- The current `spawn_agent` schema deterministically selects one supported
  protocol without using the Codex version or model name.
- Hosted Multi-agent never claims that a local `oh-no-*` TOML agent was selected
  when no `agent_type` capability exists.
- Every hosted role dispatch receives the complete stable role contract plus a
  bounded task packet and returns role-owned output from the spawned canonical
  task path.
- Local custom-agent dispatch continues to select the installed `oh-no-*` type
  without duplicating the stable role prompt in the task message.
- No generated Codex skill instructs the model to call an action or parameter
  absent from the selected protocol.
- Lifecycle evidence distinguishes waiting, follow-up, interruption, and
  completed-thread cleanup; no timeout/no-update is accepted as final.
- Static tests cover both schemas, wrong-protocol calls, false role ownership,
  and wrong-task-path results.
- Local named-agent live proof and hosted task-agent live proof both pass.
- Generated wrappers are fresh and the local Codex custom-agent count remains
  nine unless a separately approved scope changes it.

## TDD And Verification Design

### Must fail before implementation

1. Feed the hosted tool-schema fixture to the current contract validator.
2. Assert that unconditional `agent_type`, `fork_context`, and `close_agent`
   requirements are unsatisfiable.
3. Assert that `task_name="oh-no-verifier"` without an embedded verifier role
   contract cannot pass role-ownership proof.

### Must pass after implementation

- Local fixture selects `local-custom-agent` and emits only its supported
  invocation/lifecycle shape.
- Hosted fixture selects `hosted-task-agent`, embeds the requested stable role
  contract, and emits only hosted actions/arguments.
- Unrecognized fixture selects `subagent-unavailable` and records a concrete
  fallback/blocker instead of guessing.

### Suggested verification commands

```bash
python3 scripts/generate-agent-wrappers.py --check
python3 scripts/generate-skill-wrappers.py --check
python3 scripts/validate-plugin-files.py .
python3 scripts/check-skill-reachability.py --platform codex --plugin-root .
python3 scripts/test-harness-lane-contract.py \
  --marketplace-root . --plugin-root plugins/oh-no-harness
bash scripts/test-codex-plugin.sh --skip-live --no-install
bash scripts/test-claude-plugin.sh --skip-live --no-install
git diff --check
```

Opt-in live verification should run only after static and non-live gates pass.

## Non-Goals

- Do not remove local Codex custom agents or replace their TOML definitions with
  hosted task names.
- Do not make Claude Code `*-codex` transport agents depend on the Responses
  Multi-agent API; that is a different host-to-host path.
- Do not key behavior to GPT-5.6, Codex CLI `0.144.1`, dates, or product labels.
- Do not add hidden daemons or a second runtime state ledger.
- Do not silently broaden `agents.max_depth` or hosted recursive fan-out.
- Do not treat a friendly nickname, task label, or prompt claim as role-ownership
  proof.
- Do not require `close_agent` on a surface that does not expose it.

## Risks And Open Questions

1. **Tool-schema visibility:** confirm every supported Codex surface gives the
   model enough schema information to choose the protocol reliably. If not, the
   host must inject an explicit capability profile.
2. **Hosted custom-role support:** verify whether a future hosted API adds an
   explicit custom-agent selector. Until then, prompt embedding is the honest
   fallback.
3. **Prompt size:** embedding a full role core in every hosted child costs
   tokens. Optimize only after exact role fidelity is proven; do not replace it
   with a few marker strings.
4. **Context propagation:** decide whether `fork_turns="none"` is sufficient for
   every role. Any exception should be role-specific and bounded.
5. **Shared filesystem writes:** hosted agents share the same workspace in the
   observed environment. Preserve existing disjoint ownership and sequential
   TDD constraints.
6. **Cross-host review:** the opposite-host consult owner must still be a
   role-owned child. Hosted task-agent proof must be accepted only when the
   embedded role contract and canonical task result are both present.
7. **Installed cache freshness:** local custom-agent TOML updates may require a
   fresh Codex session. Hosted role-packet changes should take effect from the
   current plugin source loaded into the session; document the difference.

## Recommended Delivery Sequence

```text
Confirm both live tool schemas
  -> write dual-protocol runtime contract
  -> add RED fixtures for each schema and false role ownership
  -> implement deterministic protocol selection
  -> align lifecycle and role-proof rules
  -> regenerate wrappers
  -> static/non-live verification
  -> local named-agent live proof
  -> hosted task-agent live proof
  -> cross-host review + independent verifier
  -> release/install freshness check
```

Use a task worktree for implementation. This is a public workflow-contract and
role-ownership change, so the follow-up execution should use THOROUGH mode with
cross-host code review and a single independent verifier after review findings
are closed.
