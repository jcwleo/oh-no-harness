# Source Index

This file records the source material used to build Oh No Harness.

## OMC-Derived Skills

| Oh No Harness file | Source file |
|---|---|
| `skills/ai-slop-cleaner/SKILL.md` | `omc/raw/skills/ai-slop-cleaner/SKILL.md` |
| `skills/internal/plan/SKILL.md` | `omc/raw/skills/plan/SKILL.md` |
| `skills/ralplan/SKILL.md` | `omc/raw/skills/ralplan/SKILL.md` |
| `skills/deep-interview/SKILL.md` | `omc/raw/skills/deep-interview/SKILL.md` |
| `skills/ralph/SKILL.md` | `omc/raw/skills/ralph/SKILL.md` |
| `skills/autopilot/SKILL.md` | `omc/raw/skills/autopilot/SKILL.md` |

## OMC-Derived Agents

| Oh No Harness file | Source file |
|---|---|
| `agents/explore.md` | `omc/raw/agents/explore.md` |
| `agents/analyst.md` | `omc/raw/agents/analyst.md` |
| `agents/planner.md` | `omc/raw/agents/planner.md` |
| `agents/architect.md` | `omc/raw/agents/architect.md` |
| `agents/critic.md` | `omc/raw/agents/critic.md` |
| `agents/executor.md` | `omc/raw/agents/executor.md` |
| `agents/debugger.md` | `omc/raw/agents/debugger.md` |
| `agents/verifier.md` | `omc/raw/agents/verifier.md` |
| `agents/code-reviewer.md` | `omc/raw/agents/code-reviewer.md` |
| `agents/security-reviewer.md` | `omc/raw/agents/security-reviewer.md` |
| `agents/qa-tester.md` | `omc/raw/agents/qa-tester.md` |

## OMC-Derived Shared Docs

| Oh No Harness file | Source file |
|---|---|
| `docs/shared/agent-tiers.md` | `omc/raw/docs/shared/agent-tiers.md` |
| `docs/shared/verification-tiers.md` | `omc/raw/docs/shared/verification-tiers.md` |
| `docs/shared/company-context-interface.md` | `omc/raw/docs/company-context-interface.md` |
| `docs/shared/parallel-subagents.md` | local adaptation of OMC and Superpowers parallel-agent coordination guidance |

## Superpowers-Derived Runtime Pattern

| Oh No Harness file | Source file |
|---|---|
| `hooks/hooks.json` | `superpowers/raw/runtime/hooks/hooks.json` adapted for Oh No Harness |
| `hooks/run-hook.cmd` | `superpowers/raw/runtime/hooks/run-hook.cmd` copied as the cross-platform wrapper |
| `hooks/session-start` | `superpowers/raw/runtime/hooks/session-start` adapted to inject `using-oh-no-harness` |
| `.claude-plugin/plugin.json` | `superpowers/raw/runtime/.claude-plugin/plugin.json` structure adapted |
| `.claude-plugin/marketplace.json` | `superpowers/raw/runtime/.claude-plugin/marketplace.json` structure adapted |
| `.codex-plugin/plugin.json` | `superpowers/raw/runtime/.codex-plugin/plugin.json` structure adapted |

## Superpowers-Derived Skills

| Oh No Harness file | Source file |
|---|---|
| `skills/test-driven-development/SKILL.md` | `superpowers/raw/md/skills/test-driven-development/SKILL.md` adapted for Oh No Harness |
| `skills/verification-before-completion/SKILL.md` | `superpowers/raw/md/skills/verification-before-completion/SKILL.md` adapted for Oh No Harness |
| `skills/systematic-debugging/SKILL.md` | `superpowers/raw/md/skills/systematic-debugging/SKILL.md` adapted for Oh No Harness |

## Local Skills And Scripts

| Oh No Harness file | Purpose |
|---|---|
| `skills/auto-routing/SKILL.md` | local configuration skill for optional stronger bootstrap routing guidance |
| `scripts/oh-no-config` | persistent user settings helper for hook-readable config |

## Local Design Documents

| File | Purpose |
|---|---|
| `docs/specs/2026-05-11-oh-no-harness-design.md` | approved project design |
| `docs/plans/2026-05-11-oh-no-harness-implementation.md` | implementation plan |
| `docs/reference/relationships.md` | retained skill, agent, and hook graph |
| `docs/reference/migration-from-omc.md` | removed OMC features and migration policy |
