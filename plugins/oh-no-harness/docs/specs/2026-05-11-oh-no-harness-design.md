# Oh No Harness Design

> Current artifact policy: generated Oh No Harness specs belong under `.oh-no/specs/`, generated plans under `.oh-no/plans/`, session state under `.oh-no/sessions/`, and task worktrees under `.oh-no/worktrees/`.

## Goal

Build `oh-no-harness`, a lightweight dual-harness skill/plugin project that combines:

- Superpowers' simple packaging and bootstrap model
- OMC's strongest core workflows and agent prompts

The first version should support Claude Code and Codex, avoid OMC's runtime-heavy hook system, and keep the workflow understandable from Markdown alone.

## Design Summary

`oh-no-harness` is a small skill library with one SessionStart entrypoint and a focused OMC-derived workflow set. Native loading of each workflow's frontmatter description owns positive selection; the unconditional SessionStart bootstrap owns global no-route, direct-edit, object-of-analysis, and approval-gated chaining boundaries; and Claude auto-on may append a forced ordering and precedence overlay.

The project does not port OMC's keyword detector, persistent mode hooks, PreToolUse/PostToolUse bridge, Stop hook continuation, or `.omc/state` runtime authority.

The current external workflow surface is exactly 10 cross-platform skills:

- `interview`
- `ralplan`
- `ralph`
- `ultrawork`
- `auto-routing`
- `test-driven-development`
- `simplify`
- `verification-before-completion`
- `systematic-debugging`
- `fusion-rescue`

Claude Code additionally exposes the human-invoked setup skills `install-statusline` and `configure-subagents`, yielding 12 Claude-visible skills and 12 matching command wrappers.

The support surface includes only the Markdown needed for those skills to operate coherently:

- selected OMC agent prompts
- selected shared reference docs
- migration/relationship documentation

## Non-Goals

This version will not include:

- OMC keyword detector
- persistent-mode Stop hook
- PreToolUse/PostToolUse bridge
- mode authority/state ledger
- `team`
- legacy OMC `ultrawork` behavior/state machinery
- `ultraqa`
- `cancel`
- `ask`
- `autoresearch`
- external advisor CLI integrations
- automatic vague-prompt redirection by hook
- full OMC reference docs copied wholesale

These capabilities can be revisited later as optional extensions if the Markdown-only workflow proves insufficient.

## Harness Support

### Claude Code

Claude Code support follows the Superpowers pattern:

```text
root .claude-plugin/
  marketplace.json
plugins/oh-no-harness/.claude-plugin/
  plugin.json
hooks/
  hooks.json
  run-hook.cmd
  session-start
```

`hooks/hooks.json` registers one `SessionStart` entrypoint. It invokes
`hooks/session-start`, which always injects the compact global no-route,
direct-edit, object-of-analysis, and approval-gated chaining boundaries.
Workflow descriptions own positive destination selection; when Claude
auto-routing is enabled, the same SessionStart may additionally append the
Claude-only forced ordering and precedence overlay.

No skill-to-skill runtime enforcement hook will be installed.

### Codex

Codex support follows the Superpowers plugin manifest pattern:

```text
root .agents/plugins/marketplace.json
plugins/oh-no-harness/.codex-plugin/
  plugin.json
```

The manifest points to `./skills/`. Codex relies on native discovery of each destination workflow's frontmatter description. When plugin hooks are enabled, SessionStart may supply the same unconditional global boundary layer; Codex has no forced-routing overlay.

Treat `docs/reference/relationships.md` as the current runtime graph when it differs from this historical design snapshot.

### Shared Project Root

```text
README.md
AGENTS.md
plugins/oh-no-harness/
```

Root `AGENTS.md` provides marketplace-wrapper instructions. The plugin
instructions live in `plugins/oh-no-harness/AGENTS.md`.

## Directory Structure

Target structure:

```text
oh-no-harness/
  README.md
  AGENTS.md

  .claude-plugin/
    marketplace.json

  .agents/plugins/
    marketplace.json

  plugins/
    oh-no-harness/
      .claude-plugin/
        plugin.json
      .codex-plugin/
        plugin.json
      hooks/
        hooks.json
        run-hook.cmd
        session-start

      skills/
        interview/
          SKILL.md
        ralplan/
          SKILL.md
        ralph/
      SKILL.md
    ultrawork/
      SKILL.md
    simplify/
      SKILL.md
    internal/
      plan/
        SKILL.md

  agents/
    explore.md
    analyst.md
    planner.md
    architect.md
    critic.md
    executor.md
    debugger.md
    verifier.md
    code-reviewer.md
    security-reviewer.md
    qa-tester.md

  docs/
    specs/
      2026-05-11-oh-no-harness-design.md
    shared/
      agent-tiers.md
      verification-tiers.md
      company-context-interface.md
    reference/
      relationships.md
      migration-from-omc.md
```

## Core Workflow

```text
Native workflow discovery
  -> each workflow's frontmatter description
  -> matching destination workflow

SessionStart
  -> unconditional OH_NO_BOOTSTRAP
  -> global no-route, direct-edit, object-of-analysis, and approval-gated chaining boundaries

Claude Code auto-routing enabled
  -> next SessionStart appends OH_NO_FORCED_ROUTING
  -> forced action ordering and essential precedence
  -> destination selection remains description-owned
```

The workflow should remain explicit. If a skill hands off to another skill, the handoff must be written in the skill body and should not depend on hidden hook behavior.

## Skill Design

### Historical: retired `using-oh-no-harness`

The initial design centralized skill-loading and handoff guidance in a bootstrap skill. That public router was later retired: positive selection now belongs to destination descriptions, global lanes belong to SessionStart, and approval-gated handoffs remain owned by the selected workflows.

### `interview`

Derived from OMC requirements-discovery workflow content, but simplified:

- Keep Socratic interview, ambiguity scoring, prompt-safe summaries, brownfield exploration, and approval-gated handoff.
- Add lightweight Socratic safeguards from Ouroboros-style interview flows: route code facts, research facts, and user-judgment questions separately; preserve material answers as decisions, reasoning, constraints, non-goals, and code context; require a spec-readiness check and one-sentence goal restatement before handoff.
- Keep `explore` agent usage for brownfield context.
- Remove `autoresearch` path.
- Remove `team` path.
- Use `.oh-no/specs/interview-{slug}.md` for durable specs.
- Replace `state_write` persistence with lightweight written artifacts only.
- Handoff options:
  - refine with `ralplan`
  - execute with `ralph`
  - execute with `ultrawork`

### `ralplan`

Derived from OMC `ralplan` and `plan --consensus`.

Key change: `ralplan` should no longer be a thin alias that depends on an external `/oh-my-claudecode:plan` command. The consensus planning workflow is embedded directly in `ralplan/SKILL.md` so there is a single planning skill surface.

Remove:

- `team` approval path
- `compact` path
- `ask codex` external advisor path
- `state_write/state_clear`
- hook-based ralplan-first gate claims

Keep:

- Planner -> Architect -> Critic consensus loop
- Architect before Critic, never parallel
- final plan marked pending approval unless user explicitly approves execution
- approval handoff to `ralph` or `ultrawork`

### `ralph`

Derived from OMC `ralph`, but converted into a solo persistence loop.

Remove:

- legacy OMC `ultrawork` state machinery
- `cancel`
- `ask codex`
- `.omc/state` mode state
- linked ultrawork state

Keep:

- PRD/story model
- acceptance criteria validation
- executor delegation
- verification tiers
- reviewer approval before completion
- mandatory `simplify` pass unless explicitly disabled
- final verification report

Ralph should use project-local artifacts, for example:

```text
.oh-no/sessions/{sessionId}/prd.json
.oh-no/sessions/{sessionId}/progress.md
.oh-no/sessions/{sessionId}/verification.md
```

If no session id exists, use a timestamped session directory.

### `ultrawork`

Derived from OMC `autopilot`, renamed locally to `ultrawork`, and simplified
into a Markdown-visible orchestration flow.

Remove:

- legacy OMC `ultrawork` behavior/state machinery
- `ultraqa`
- `cancel`
- OMC runtime pipeline adapters
- OMC state cleanup instructions

Keep:

- vague request expansion through `interview`
- planning through `ralplan`
- execution/verification through `ralph`
- analyst/architect/critic/executor/debugger/reviewer agent roles
- build/lint/test QA loop, inline inside `ultrawork`

Ultrawork should detect existing `interview` specs and `ralplan` plans using the new artifact paths, not `.omc/` paths.

### `simplify`

Adapted from Claude Code's built-in `simplify` skill for Codex parity.

Keep it as a skill, not an agent. `ralph` calls it as a mid-loop cleanup skill after reviewer approval and before final verification.

No hook detection is included. Users can also invoke it directly as a normal skill.

## Agent Design

The project should include only agents needed by the retained skills.

Required agents:

- `explore`
- `analyst`
- `planner`
- `architect`
- `critic`
- `executor`
- `debugger`
- `verifier`
- `code-reviewer`
- `security-reviewer`
- `qa-tester`

The agent prompts should be adapted from OMC, but all OMC-specific references must be normalized:

- Replace `/oh-my-claudecode:*` commands with local skill references.
- Replace `.omc/` artifact paths with `.oh-no/`.
- Remove `team`, legacy OMC `ultrawork` behavior, and external advisor handoffs.
- Replace OMC tier-specific agent names such as `executor-low`, `executor-high`, `architect-medium`, and `explore-high` with base agent names plus task scope, risk level, and evidence expectations.

Example:

```text
Dispatch `executor` through the current platform's subagent mechanism with light, standard, or high-scrutiny scope.
If the platform does not support or allow subagents, perform the same role inline and preserve the role boundary in the report.
```

## Shared References

### `agent-tiers.md`

Adapt from OMC `docs/shared/agent-tiers.md`.

The new version should preserve the decision guidance but simplify names:

- `executor` + scope/risk/evidence prompt instead of `executor-low/high`
- `architect` + scope/risk/evidence prompt instead of `architect-low/medium`
- `security-reviewer` + scope/risk/evidence prompt instead of `security-reviewer-low`
- `explore` + scope/risk/evidence prompt instead of `explore-high`

### `verification-tiers.md`

Adapt from OMC `docs/shared/verification-tiers.md`.

Keep LIGHT/STANDARD/THOROUGH verification decision logic. Update agent names to the simplified local set.

### `company-context-interface.md`

Include as an optional contract document because the retained OMC skills reference company-context behavior.

First version should not implement a runtime company-context tool. The document should state that company-context is optional, prompt-level, advisory, and never executable instruction.

## Artifact Paths

The project should not write `.omc/` paths.

Use:

```text
.oh-no/
  specs/
  plans/
  sessions/
  worktrees/
  test-runs/
```

Durable specs and plans should use `.oh-no/specs/` and `.oh-no/plans/`. Transient workflow state should use `.oh-no/sessions/`. Task worktrees should use `.oh-no/worktrees/`. Harness test logs should use `.oh-no/test-runs/`.

## Hook Design

One hook class is included:

```text
SessionStart -> unconditional OH_NO_BOOTSTRAP global boundaries
             -> conditional Claude-only OH_NO_FORCED_ROUTING when auto-routing is enabled
```

No hook should:

- inspect submitted prompts
- redirect prompts
- activate skill state
- prevent Stop
- persist workflow mode authority
- mutate skill ledger state

If a future version adds enforcement hooks, they should be opt-in and documented as a separate runtime layer.

## Migration Rules From OMC

When copying OMC files, apply these rules:

1. Rename commands and skill references.
   - `/oh-my-claudecode:ralph` -> `oh-no-harness:ralph`
   - OMC runtime skill calls -> explicit Markdown handoff to the local skill name

2. Remove unsupported skills.
   - `team`
   - legacy OMC `ultrawork` behavior/state machinery
   - `ultraqa`
   - `cancel`
   - `ask`
   - `autoresearch`

3. Replace unsupported runtime mechanisms.
   - `state_write/state_read/state_clear` -> explicit artifact files
   - persistent-mode continuation -> skill body instruction
   - keyword detector -> native description discovery plus unconditional global boundaries and the optional Claude-only ordering/precedence overlay

4. Normalize artifacts.
   - `.omc/` -> `.oh-no/` for transient state
   - `.oh-no/specs/` for specs
   - `.oh-no/plans/` for plans
   - `.oh-no/worktrees/` for task worktrees

5. Simplify agent tiers.
   - tiered agent names become model hints on one base agent prompt.

## Risks

### Risk: Removing hooks weakens persistence

Ralph and ultrawork may stop earlier than OMC did because there is no Stop hook. Mitigation: make continuation rules explicit in `ralph` and `ultrawork`, and require final verification reports.

### Risk: OMC docs contain hidden runtime assumptions

Direct copy could preserve references to removed skills or `.omc/state`. Mitigation: run text checks for unsupported terms after migration.

### Risk: Codex and Claude use different skill invocation semantics

Mitigation: keep positive selection in shared workflow descriptions, and isolate host behavior in platform overlays plus the SessionStart host branch; Codex receives no forced-routing overlay.

### Risk: Too much OMC content leaks back in

Mitigation: keep the external skill surface explicit in manifests and
validators, and move only required support docs.

## Acceptance Criteria

- `plugins/oh-no-harness/` has Claude Code and Codex plugin metadata.
- One SessionStart entrypoint exists for Claude Code.
- Codex manifest points to `./skills/`.
- No keyword detector, persistent-mode hook, bridge hook, or Stop hook exists.
- The 10 cross-platform workflow skills are exactly:
  - `interview`
  - `ralplan`
  - `ralph`
  - `ultrawork`
  - `auto-routing`
  - `test-driven-development`
  - `simplify`
  - `verification-before-completion`
  - `systematic-debugging`
  - `fusion-rescue`
- Claude Code additionally exposes `install-statusline` and `configure-subagents`, for 12 Claude-visible skills and 12 command wrappers.
- The plan consensus workflow is fully embedded into `ralplan`.
- Required agent prompts exist.
- Shared docs exist:
  - `agent-tiers.md`
  - `verification-tiers.md`
  - `company-context-interface.md`
- No retained skill requires `team`, legacy OMC `ultrawork` behavior,
  `ultraqa`, `cancel`, `ask`, or `autoresearch`.
- No retained skill writes `.omc/` paths.
- Relationship and migration docs explain what was removed and why.

## Historical Implementation Notes

The original implementation proceeded in small stages:

1. Create skeleton and plugin metadata.
2. Create bootstrap hook and original, now-retired bootstrap skill.
3. Copy/adapt shared docs.
4. Copy/adapt agents.
5. Copy/adapt skills in dependency order:
   - `simplify`
   - `ralplan`
   - `interview`
   - `ralph`
   - `ultrawork`
6. Run unsupported-reference scans.
7. Write relationship/migration docs.

Because the current workspace is not a git repository, the design document cannot be committed here unless a repository is initialized later.
