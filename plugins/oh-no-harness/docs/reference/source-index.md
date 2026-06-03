# Source Index

This file records the source material used to build Oh No Harness.

## OMC-Derived Skills

| Oh No Harness file | Source file |
|---|---|
| `docs/skill-core/ralplan.md` | `omc/raw/skills/ralplan/SKILL.md` plus `omc/raw/skills/plan/SKILL.md` consensus workflow content |
| `docs/skill-core/interview.md` | OMC requirements-discovery skill content, renamed locally |
| `docs/skill-core/ralph.md` | `omc/raw/skills/ralph/SKILL.md` |
| `docs/skill-core/autopilot.md` | `omc/raw/skills/autopilot/SKILL.md` |

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
| `docs/agent-core/architect.md` and `agents/architect.md` | `omc/raw/agents/architect.md` |
| `docs/agent-core/critic.md` and `agents/critic.md` | `omc/raw/agents/critic.md` |
| `docs/agent-core/executor.md` and `agents/executor.md` | `omc/raw/agents/executor.md` |
| `docs/agent-core/debugger.md` and `agents/debugger.md` | `omc/raw/agents/debugger.md` |
| `docs/agent-core/verifier.md` and `agents/verifier.md` | `omc/raw/agents/verifier.md` |
| `docs/agent-core/code-reviewer.md` and `agents/code-reviewer.md` | `omc/raw/agents/code-reviewer.md` |
| `docs/agent-core/security-reviewer.md` and `agents/security-reviewer.md` | `omc/raw/agents/security-reviewer.md` |
| `docs/agent-core/qa-tester.md` and `agents/qa-tester.md` | `omc/raw/agents/qa-tester.md` |

## OMC-Derived Shared Docs

| Oh No Harness file | Source file |
|---|---|
| `docs/shared/agent-tiers.md` | `omc/raw/docs/shared/agent-tiers.md` |
| `docs/shared/verification-tiers.md` | `omc/raw/docs/shared/verification-tiers.md` |
| `docs/shared/company-context-interface.md` | `omc/raw/docs/company-context-interface.md` |
| `docs/shared/parallel-subagents.md` | local pointer back to `docs/shared/ralph-subagent-policy.md` for parallel dispatch |
| `docs/shared/execution-modes.md` | local execution-intensity contract for Interview, Ralplan, Ralph, and Autopilot |
| `docs/shared/ralph-subagent-policy.md` | local platform-neutral Ralph subagent dispatch and integration policy |

## Local Platform Adapter Docs

| Oh No Harness file | Purpose |
|---|---|
| `docs/platforms/claude-code-ralph.md` | Claude Code-specific Ralph subagent invocation adapter injected by the Ralph hook |
| `docs/platforms/codex-ralph.md` | Codex-specific Ralph `spawn_agent` invocation adapter injected by the Ralph hook |
| `docs/platforms/claude-code.md` | Claude Code-specific public skill wrapper rules |
| `docs/platforms/codex.md` | Codex-specific public skill wrapper rules |
| `docs/platforms/codex-agents/*.toml` | Optional Codex custom-agent templates installable through `scripts/install-codex-agents` |

## Local Provider Guidance

| Oh No Harness file | Purpose |
|---|---|
| `docs/providers/openai.md` | maintenance reference for OpenAI prompt guidance summarized in `docs/platforms/codex.md` |
| `docs/providers/anthropic.md` | maintenance reference for Anthropic prompt guidance summarized in `docs/platforms/claude-code.md` |

## Superpowers-Derived Runtime Pattern

| Oh No Harness file | Source file |
|---|---|
| `hooks/hooks.json` | `superpowers/raw/runtime/hooks/hooks.json` adapted for Oh No Harness |
| `hooks/run-hook.cmd` | `superpowers/raw/runtime/hooks/run-hook.cmd` copied as the cross-platform wrapper |
| `hooks/session-start` | `superpowers/raw/runtime/hooks/session-start` adapted to inject a compact native skill-loading bootstrap |
| `hooks/ralph-platform-adapter` | local UserPromptSubmit adapter that injects only the active platform's Ralph subagent prompt |
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
| `commands/*.md` | local Claude Code slash-command wrappers that mirror public skills and delegate to `skills-claude/<name>/SKILL.md` |
| `skills/<name>/SKILL.md` | Codex-facing public skill wrappers over `docs/skill-core/<name>.md` |
| `skills-claude/<name>/SKILL.md` | Claude Code-facing public skill wrappers over `docs/skill-core/<name>.md` |
| `docs/skill-core/auto-routing.md` | local configuration skill core for optional stronger bootstrap routing guidance |
| `scripts/oh-no-config` | persistent user settings helper for hook-readable config |
| `scripts/install-codex-agents` | optional Codex custom-agent installer for project or user scope |

## Local Design Documents

| File | Purpose |
|---|---|
| `docs/specs/2026-05-11-oh-no-harness-design.md` | approved project design |
| `docs/plans/2026-05-11-oh-no-harness-implementation.md` | implementation plan |
| `docs/reference/relationships.md` | retained skill, agent, and hook graph |
| `docs/reference/migration-from-omc.md` | removed OMC features and migration policy |
