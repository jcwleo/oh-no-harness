# Codex Ralph Adapter

CODEX_ONLY_RALPH_ADAPTER

<ADAPTER_CONTRACT>
This adapter binds the Ralph core to Codex. The core owns every semantic
decision; this file owns only host invocation and lifecycle mechanics. If
they conflict, the core wins. The generated core, dedicated Codex child-packet
floor, and this adapter are sufficient even when SessionStart hooks are disabled:
longer platform, shared, and agent documents are optional maintenance context,
never a runtime prerequisite. Do not apply it on Claude
Code or other platforms.
</ADAPTER_CONTRACT>

## Dispatch Decision

Ralph is parallel-capable on Codex when the host exposes `spawn_agent`.
Dispatch is trigger-loaded — dispatch only after the active skill's trigger
fires, within host policy and the core's isolation rules.

Sufficient dispatch signals: an approved `ralplan` handoff preserving
`Parallel trigger: approved-plan-handoff` (no separate subagent wording
needed); an explicit user phrase (`subagent`, `spawn`, `delegate`,
`parallel agents`, `one agent per`); or a standing user/plan preference to
maximize subagents — which authorizes eligible isolated roles for the whole
run, including read-heavy exploration, test/log analysis, verification,
review, and disjoint implementation (executor) work in STANDARD/THOROUGH
when write scopes are non-overlapping, but never roles whose output would
not change a decision. When no non-mutating dispatch-worthy role exists, it
may run inline under the core's role fallback rules; host denial must be
recorded. Record `Parallel trigger: none` when no concurrent batch is
admitted. Record `Parallel trigger: natural-dispatch` only when the host
permits proactive dispatch and the active skill policy authorizes it.

## Executor-Default Trigger

When the core records STANDARD/THOROUGH repository work-product mutation,
call `spawn_agent` for `oh-no-executor` even when `Parallel trigger: none`;
that trigger controls concurrency, not sequential executor ownership. The
same rule applies to REVIEW-to-EXECUTE focused fixes. Inline mutation is valid
only for the core's recorded LIGHT-tiny or dispatch-unavailable fallback, and
unavailability requires the failed named-agent attempt or equivalent current
host rejection described below.

## Invocation

Codex SessionStart is the sole automatic custom-agent preparation path: it
runs `scripts/install-codex-agents --scope user --ensure --quiet`. Installed
files carry the plugin version marker and pin role models. When a named
`oh-no-*` agent type is not recognized, resolve and run the installed installer,
then retry:

```bash
tab="$(printf '\t')"
cache="${CODEX_HOME:-$HOME/.codex}/plugins/cache"
# Codex exposes no skill-visible plugin root, so cache-newest is the only reachable
# path. Sort on the VERSION path component (full path only as tie-break) so a second
# marketplace identity cannot let an older version win.
script="$(find "$cache" -path '*/oh-no-harness/*/scripts/install-codex-agents' 2>/dev/null \
  | awk -F/ '{for(i=NF;i>0;i--) if($i=="scripts"){print $(i-1)"\t"$0; break}}' \
  | LC_ALL=C sort -t"$tab" -k1,1V -k2,2 | tail -n1 | cut -f2-)"
"$script" --scope user --ensure
```

Use generic prompt-embedded dispatch only after confirmed custom-agent
unavailability, and record the fallback reason.

Dispatch order:

- `oh-no-<role>` when the host recognizes that `agent_type`. This is
  required for Oh No Harness role dispatch, not just preferred.
- `explorer` for read-heavy exploration, `worker` for scoped implementation
  with a disjoint write set, `default` for specialized review/QA/security —
  ONLY when the host rejects `oh-no-<role>` as unknown or unavailable, or
  the work is not an Oh No Harness role. Record the fallback reason.

A failed `spawn_agent(agent_type="oh-no-<role>", ...)` attempt using that legacy shorthand is not a valid V2 attempt because it omits `task_name`.
Do not claim custom agents are unavailable until the full four-field call below
is rejected or the current host gives an equivalent rejection; do not infer
unavailability from rendered schema text, display comments, or missing shown parameters.

Spawn with `fork_turns="none"` and derive every name from the actual Ralph role
and phase; for example, use `spawn_agent(task_name="ralph_executor_implementation_1", agent_type="oh-no-executor", message=<self-contained packet>, fork_turns="none")`
for the first implementation executor and role-correct unique equivalents for
other or sibling dispatches. Omitting `fork_turns` defaults to a full-history
fork, and forked agents inherit the parent agent type, so the custom `agent_type`
is rejected. Do not use `fork_context` (unsupported) or any full-history fork
with `agent_type = "oh-no-<role>"`. Send the relevant plan, scope, ownership,
and evidence context in the spawn message, one payload shape only
(prompt/message or items, never both). The generated
`oh-no-explore`, `oh-no-verifier`, and `oh-no-code-reviewer` templates set
`sandbox_mode = "read-only"`; other Ralph role templates inherit the host
sandbox and stay scoped by the core dispatch packet.

Spawn every independent agent in the eligible batch before calling
`wait_agent`.

## Lifecycle

After `wait_agent` returns a final status, capture the result and inspect
any changed-file set. A timeout, empty wait result, or "No agents completed
yet" is not a final status. Hard rule: MUST NOT call `close_agent` for a
running or pending Ralph subagent after timeout, no-completion, or empty
wait output — leave it running, wait longer when its result is needed,
continue non-overlapping work, or record the role as pending or blocked.
Close without a captured final result only on explicit user cancel, scope
invalidation, duplicate/mis-scoped spawn, or a safety/security/filesystem
risk; record that close as cancelled or abandoned and never use missing
output as completion evidence. When no more input is needed for a completed
subagent and the host exposes `close_agent`, call it; if it reports already
closed or unavailable, record that instead of retrying. If the host exposes
no explicit close, record that closure is host-managed or unavailable.

## Role Prompt Embedding

Codex display names are not stable role identifiers; registered custom-agent
names and the dispatch message are the source of truth. For a registered
`oh-no-<role>` agent, the TOML `developer_instructions` already supplies the
role prompt — keep the task prompt focused on the core dispatch packet plus:

```text
Codex agent type: oh-no-<role>   # or <explorer|worker|default> fallback
```

For a generic fallback, add the embedded role prompt:

```text
Agent prompt source: docs/agent-core/<role>.md
Agent prompt content:
<matching docs/agent-core/<role>.md prompt content>
```

The embedded or registered prompt must preserve the role's Skill
Relationship, Responsibilities, Operating Rules, and Output sections. If
`docs/agent-core/<role>.md` is unavailable but `agents/<role>.md` exists,
strip the Claude Code YAML frontmatter before embedding — Claude-only
frontmatter (`tools`, `model`, `background`, `isolation`, `color`) must not
enter Codex prompt content. For `worker` tasks give each agent an explicit
ownership boundary; read-only reviewers must not edit files.

## Cross-Host Consult Channel

A fired named THOROUGH review trigger on Codex starts one Codex `code-reviewer`
and one transport-owner reviewer making exactly one foreground Claude call.
The two review legs receive redacted packets identical except the single `Assigned perspective:` line.
A launch notice, background acknowledgement, or empty output is unavailable
evidence; on opposite-host unavailability run `same-host-parallel-fallback` and
record the required fallback reason.

## Re-Homed Core Pair Rules

```text
STANDARD -> one perspective-diverse code-reviewer pair when review is required,
            recorded as same-host-perspective-pair; this is intentional
            same-host review, so no fallback reason is required.
THOROUGH -> the same perspective-diverse pair. A named security, data,
            destructive, public-contract, release-critical, new-concurrency,
            migration, or broad multi-system risk selects cross-host review when
            available, or same-host-parallel-fallback when the opposite host is
            unavailable; record the fallback reason.
```

Both the STANDARD and THOROUGH pairs follow the same packet rule stated in the
Cross-Host Consult Channel: the two legs differ only by their `Assigned
perspective:` line.

## Cleanup

When Ralph reaches the CLEANUP checkpoint on Codex, use the Oh No Harness
`simplify` skill through the generated Codex Simplify runtime document.
