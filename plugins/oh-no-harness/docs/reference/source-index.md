# Source Index

This file records the source material used to build Oh No Harness.

## OMC-Derived Skills

| Oh No Harness file | Source file |
|---|---|
| `docs/skill-core/ralplan.md` | `omc/raw/skills/ralplan/SKILL.md` plus `omc/raw/skills/plan/SKILL.md` consensus workflow content |
| `docs/skill-core/interview.md` | OMC requirements-discovery skill content, renamed locally |
| `docs/skill-core/ralph.md` | `omc/raw/skills/ralph/SKILL.md` |
| `docs/skill-core/ultrawork.md` | `omc/raw/skills/autopilot/SKILL.md`, renamed locally from `autopilot` to `ultrawork` |

## Claude Code Built-In Skill Parity

| Oh No Harness file | Source file |
|---|---|
| `docs/skill-core/simplify.md` | Claude Code built-in `simplify` skill, adapted for Codex and Oh No Harness cleanup gates |

## OMC-Derived Agents

| Oh No Harness file | Source file |
|---|---|
| `docs/agent-core/explore.md` and `agents/explore.md` | `omc/raw/agents/explore.md` |
| `docs/agent-core/analyst.md` and `agents/analyst.md` | `omc/raw/agents/analyst.md` |
| `docs/agent-core/planner.md` and `agents/planner.md` | `omc/raw/agents/planner.md` |
| `docs/agent-core/plan-reviewer.md` and `agents/plan-reviewer.md` | merged from `omc/raw/agents/architect.md` and `omc/raw/agents/critic.md` |
| `docs/agent-core/executor.md` and `agents/executor.md` | `omc/raw/agents/executor.md` |
| `docs/agent-core/debugger.md` and `agents/debugger.md` | `omc/raw/agents/debugger.md` |
| `docs/agent-core/verifier.md` and `agents/verifier.md` | merged from `omc/raw/agents/verifier.md` and `omc/raw/agents/qa-tester.md` |
| `docs/agent-core/code-reviewer.md` and `agents/code-reviewer.md` | merged from `omc/raw/agents/code-reviewer.md` and `omc/raw/agents/security-reviewer.md` |

## OMC-Derived Shared Docs

| Oh No Harness file | Source file |
|---|---|
| `docs/shared/agent-tiers.md` | `omc/raw/docs/shared/agent-tiers.md` |
| `docs/shared/verification-tiers.md` | `omc/raw/docs/shared/verification-tiers.md` |
| `docs/shared/company-context-interface.md` | `omc/raw/docs/company-context-interface.md` |
| `docs/shared/parallel-subagents.md` | local pointer back to `docs/shared/ralph-subagent-policy.md` for parallel dispatch |
| `docs/shared/execution-modes.md` | local execution-intensity contract for Interview, Ralplan, Ralph, and Ultrawork |
| `docs/shared/ralph-subagent-policy.md` | local platform-neutral shared subagent dispatch and integration policy for Ralph-originated and other eligible Oh No Harness role workflows |
| `docs/shared/worktree-isolation.md` | local worktree hard gate, allowed decisions, default task-worktree location, and artifact handoff policy |
| `docs/shared/validation-check.md` | local validation template for evidence-informed improvements |
| `docs/shared/failure-taxonomy.md` | local recurring engineering failure labels used by validation, risk checks, review, and verification |

## Local Platform Adapter Docs

| Oh No Harness file | Purpose |
|---|---|
| `docs/platforms/claude-code-auto-routing.md` | Claude Code-specific Auto Routing config overlay included only in the generated Claude Code Auto Routing runtime document |
| `docs/platforms/codex-auto-routing.md` | Codex-specific Auto Routing behavior overlay included only in the generated Codex Auto Routing runtime document |
| `docs/platforms/claude-code-ralph.md` | Claude Code-specific Ralph subagent invocation adapter included only in the generated Claude Code Ralph runtime document |
| `docs/platforms/codex-ralph.md` | Codex-specific Ralph `spawn_agent` invocation adapter included only in the generated Codex Ralph runtime document |
| `docs/platforms/claude-code-fusion-rescue.md` | Claude Code-specific Fusion Rescue Codex consult adapter included only in the generated Claude Code Fusion Rescue runtime document |
| `docs/platforms/codex-fusion-rescue.md` | Codex-specific Fusion Rescue Claude Opus consult adapter included only in the generated Codex Fusion Rescue runtime document |
| `docs/platforms/claude-code-simplify.md` | Claude Code-specific Simplify cleanup dispatch overlay included only in the generated Claude Code Simplify runtime document |
| `docs/platforms/codex-simplify.md` | Codex-specific Simplify cleanup dispatch overlay included only in the generated Codex Simplify runtime document |
| `docs/platforms/claude-code-runtime.md` | compact Claude Code-specific runtime rules included in generated Claude Code skill documents |
| `docs/platforms/codex-runtime.md` | compact Codex-specific runtime rules included in generated Codex skill documents |
| `docs/platforms/claude-code.md` | longer Claude Code platform maintenance reference summarized into `docs/platforms/claude-code-runtime.md` |
| `docs/platforms/codex.md` | longer Codex platform maintenance reference summarized into `docs/platforms/codex-runtime.md` |
| `docs/platforms/codex-agents/*.toml` | Generated optional Codex custom-agent templates installable through `plugins/oh-no-harness/scripts/install-codex-agents`; generated from `docs/agent-core/*.md` by repository-root `scripts/generate-agent-wrappers.py`, include explicit model defaults to avoid user-specific inheritance, and set read-only sandbox for read-only roles such as `oh-no-explore` and `oh-no-fusion-rescue-analyst` |

## Local Provider Guidance

| Oh No Harness file | Purpose |
|---|---|
| `docs/providers/openai.md` | maintenance reference for OpenAI prompt guidance summarized in `docs/platforms/codex-runtime.md` |
| `docs/providers/anthropic.md` | maintenance reference for Anthropic prompt guidance summarized in `docs/platforms/claude-code-runtime.md` |

## Superpowers-Derived Runtime Pattern

| Oh No Harness file | Source file |
|---|---|
| `hooks/hooks.json` | `superpowers/raw/runtime/hooks/hooks.json` adapted for Oh No Harness |
| `hooks/run-hook.cmd` | `superpowers/raw/runtime/hooks/run-hook.cmd` copied as the cross-platform wrapper |
| `hooks/session-start` | `superpowers/raw/runtime/hooks/session-start` adapted to inject a compact native skill-loading bootstrap, Codex-only standing subagent authorization, Codex no-skill read-only inline boundary, and quiet user-scope custom-agent ensure |
| `hooks/ralph-platform-adapter` | local UserPromptSubmit adapter that injects only the active platform's Ralph subagent prompt and repeats Codex custom-agent ensure only as fallback |
| `plugins/oh-no-harness/.claude-plugin/plugin.json` | `superpowers/raw/runtime/.claude-plugin/plugin.json` structure adapted |
| root `.claude-plugin/marketplace.json` | `superpowers/raw/runtime/.claude-plugin/marketplace.json` structure adapted |
| `plugins/oh-no-harness/.codex-plugin/plugin.json` | `superpowers/raw/runtime/.codex-plugin/plugin.json` structure adapted |

## Superpowers-Derived Skills

| Oh No Harness file | Source file |
|---|---|
| `docs/skill-core/test-driven-development.md` | `superpowers/raw/md/skills/test-driven-development/SKILL.md` adapted for Oh No Harness |
| `docs/skill-core/verification-before-completion.md` | `superpowers/raw/md/skills/verification-before-completion/SKILL.md` adapted for Oh No Harness |
| `docs/skill-core/systematic-debugging.md` | `superpowers/raw/md/skills/systematic-debugging/SKILL.md` adapted for Oh No Harness |

## Local Skills And Scripts

| Oh No Harness file | Purpose |
|---|---|
| `commands/*.md` | local Claude Code slash-command wrappers that mirror public skills and delegate to generated `skills-claude/<name>/SKILL.md` runtime documents |
| `skills/<name>/SKILL.md` | generated Codex-facing runtime skill document composed from `docs/skill-core/<name>.md`, `docs/platforms/codex-runtime.md`, and optional `docs/platforms/codex-<name>.md` |
| `skills-claude/<name>/SKILL.md` | generated Claude Code-facing runtime skill document composed from `docs/skill-core/<name>.md`, `docs/platforms/claude-code-runtime.md`, and optional `docs/platforms/claude-code-<name>.md` |
| `docs/skill-core/auto-routing.md` | local configuration skill core for optional stronger bootstrap routing guidance |
| `docs/skill-core/fusion-rescue.md` | local bounded three-panel rescue workflow inspired by inference-time ensemble synthesis, with platform-neutral cross-host consultation contracts and no OpenRouter API integration |
| `docs/agent-core/fusion-rescue-analyst.md` | local panel-lens role body used by `fusion-rescue` for current-host analysis slots |
| `scripts/oh-no-config` | persistent user settings helper for hook-readable config |
| repository-root `scripts/generate-skill-wrappers.py` | regenerates Codex `skills/*/SKILL.md` and Claude Code `skills-claude/*/SKILL.md` runtime skill documents from `docs/skill-core/*.md` and `docs/platforms/*.md`; `--check` is enforced by validation and release |
| repository-root `scripts/generate-agent-wrappers.py` | regenerates Claude Code `agents/*.md` and Codex `docs/platforms/codex-agents/*.toml` wrappers from `docs/agent-core/*.md`; `--check` is enforced by validation and release |
| `scripts/install-codex-agents` | optional Codex custom-agent installer; user scope is default, SessionStart ensures generated files quietly, Ralph preflight is fallback, project scope is explicit |

## Local Design Documents

| File | Purpose |
|---|---|
| `docs/specs/2026-05-11-oh-no-harness-design.md` | approved project design |
| `docs/reference/relationships.md` | retained skill, agent, and hook graph |
| `docs/reference/migration-from-omc.md` | removed OMC features and migration policy |
