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

## Local Platform Adapter Docs

| Oh No Harness file | Purpose |
|---|---|
| `docs/platforms/claude-code-auto-routing.md` | Claude Code-specific Auto Routing config overlay included only in the generated Claude Code Auto Routing runtime document |
| `docs/platforms/codex-auto-routing.md` | Codex-specific Auto Routing behavior overlay included only in the generated Codex Auto Routing runtime document |
| `docs/platforms/claude-code-ralph.md` | Claude Code-specific Ralph subagent invocation adapter included only in the generated Claude Code Ralph runtime document |
| `docs/platforms/codex-ralph.md` | Codex-specific Ralph `spawn_agent` invocation adapter included only in the generated Codex Ralph runtime document |
| `docs/platforms/claude-code-fusion-rescue.md` | Claude Code-specific Fusion Rescue model-diversity panel adapter included only in the generated Claude Code Fusion Rescue runtime document |
| `docs/platforms/codex-fusion-rescue.md` | Codex-specific Fusion Rescue Claude Opus consult adapter included only in the generated Codex Fusion Rescue runtime document |
| `docs/platforms/claude-code-simplify.md` | Claude Code-specific Simplify cleanup dispatch overlay included only in the generated Claude Code Simplify runtime document |
| `docs/platforms/codex-simplify.md` | Codex-specific Simplify cleanup dispatch overlay included only in the generated Codex Simplify runtime document |
| `docs/platforms/claude-code-runtime.md` | compact Claude Code-specific runtime rules included in generated Claude Code skill documents |
| `docs/platforms/codex-child-packet-floor.md` | compact Codex main-caller child-packet floor included in every generated Codex workflow document, including hook-disabled native-skill execution |
| `docs/platforms/codex-runtime.md` | compact Codex-specific runtime rules included in non-self-contained generated Codex skill documents |
| `docs/platforms/claude-code.md` | longer Claude Code platform maintenance reference summarized into `docs/platforms/claude-code-runtime.md` |
| `docs/platforms/codex.md` | longer Codex platform maintenance reference summarized into `docs/platforms/codex-runtime.md` |
| `docs/platforms/codex-agents/*.toml` | Generated optional Codex custom-agent templates installable through `plugins/oh-no-harness/scripts/install-codex-agents`; generated from `docs/agent-core/*.md` by repository-root `scripts/generate-agent-wrappers.py`, include explicit model defaults to avoid user-specific inheritance, and set read-only sandbox for read-only roles such as `oh-no-explore`, `oh-no-verifier`, `oh-no-code-reviewer`, and `oh-no-fusion-rescue-analyst` |
| `docs/platforms/opencode-runtime.md` | compact OpenCode-native skill, question, task, model-inheritance, and restart rules included in non-self-contained generated OpenCode skill documents |
| `docs/platforms/opencode-interview.md`, `opencode-ralplan.md`, `opencode-ralph.md`, `opencode-systematic-debugging.md`, `opencode-ultrawork.md`, `opencode-verification-before-completion.md` | required OpenCode adapters for the six self-contained workflow cores |
| `docs/platforms/opencode-auto-routing.md`, `opencode-fusion-rescue.md`, `opencode-simplify.md` | OpenCode-specific overlays for the named generated workflow documents |
| `docs/platforms/opencode-configure-subagents.md` | standalone explicit-user-only OpenCode Configure Subagents source; generated without the shared Claude setup core or common OpenCode runtime |
| `docs/platforms/opencode-main-agent.md` | static orchestration contract source for the generated OpenCode `oh-no` primary agent |
| `docs/platforms/opencode.md` | longer OpenCode platform maintenance reference; not a generated runtime source |

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
| `hooks/session-start` | `superpowers/raw/runtime/hooks/session-start` adapted to inject compact native skill-loading and caller-owned child-packet guidance; on Claude Code it always adds the configuration-derived model-diversity block and best-effort subagent preference reapply, while on Codex it adds standing subagent authorization, the no-skill read-only inline boundary, and quiet user-scope custom-agent ensure. OpenCode uses its separate config hook instead. |
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
| `skills/<name>/SKILL.md` | 10 generated Codex workflow documents; every wrapper composes its shared core and child-packet floor, then either the required self-contained adapter or the common runtime plus optional overlay |
| `skills-claude/<name>/SKILL.md` | 12 generated Claude Code documents: 10 workflow wrappers composed from shared cores and exact Claude adapters/runtime sources, plus the two Claude setup wrappers (`install-statusline`, `configure-subagents`) |
| `skills-opencode/<name>/SKILL.md` | 11 generated OpenCode-facing runtime skill documents: the 10 workflow skills composed from shared cores plus OpenCode sources, and standalone `configure-subagents` composed only from `docs/platforms/opencode-configure-subagents.md` |
| `docs/skill-core/auto-routing.md` | local configuration skill core for optional stronger bootstrap routing guidance |
| `docs/skill-core/install-statusline.md` | local Claude-Code-only, human-invoke-only setup skill core (`disable-model-invocation: true`) for installing the developer statusline |
| `docs/platforms/claude-code-install-statusline.md` | Claude Code-specific Install Statusline overlay included only in the generated Claude Code Install Statusline runtime document (no Codex variant) |
| `docs/skill-core/configure-subagents.md` | local Claude-Code-only, human-invoke-only setup skill core (`disable-model-invocation: true`) for configuring the installed subagents' model and reasoning effort |
| `docs/platforms/claude-code-configure-subagents.md` | Claude Code-specific Configure Subagents overlay included only in the generated Claude Code Configure Subagents runtime document (no Codex variant) |
| `docs/platforms/opencode-configure-subagents.md` | separate OpenCode Configure Subagents source for exact `provider/model-id` assignments; explicit-user-only and restart-required, with no Codex variant |
| `docs/skill-core/fusion-rescue.md` | local bounded three-panel rescue workflow inspired by inference-time ensemble synthesis, with platform-neutral panel orchestration, platform-owned diversity/consult policy, and no OpenRouter API integration |
| `docs/agent-core/fusion-rescue-analyst.md` | local panel-lens role body used by `fusion-rescue` for current-host analysis slots |
| `scripts/oh-no-config` | persistent user settings helper for hook-readable config |
| `scripts/statusline-command` | bundled developer statusline payload copied to `~/.claude/statusline-command.sh` by `install-statusline` |
| `scripts/install-statusline` | installer for the `install-statusline` skill; `check`/`apply [--replace]` modes, jq non-clobbering settings.json merge, timestamped backups, refuses without jq or on invalid JSON |
| `scripts/configure-subagents` | runtime configurator for the `configure-subagents` skill; `check`/`apply --proxy`/`reapply` modes, 9-role model/effort settings plus top-tier/secondary diversity preferences, physical-root confinement, byte-exact frontmatter transform, lock-serialized recoverable transaction (per-file atomic rename + backup + journal), best-effort SessionStart reapply; never stores or prints proxy credentials |
| `opencode/index.js` | handwritten OpenCode source entrypoint; its config hook registers `skills-opencode/`, generated commands, one `oh-no` primary and nine `oh-no-<role>` subagents, leaves the user's global permission unchanged while mirroring only its restrictive portions into package agents so local last-match rules cannot weaken it, preserves restrictive primary/same-role patterns as child ceilings, and applies only role hard denies, finite task topology, primary question, and custom-tool rules; it also disables built-in `build`/`plan`, preserves unrelated custom defaults, and requires subagent depth 2 or higher |
| `opencode/model-catalog.js` | read-only configured-provider catalog adapter; normalizes exact model-specific variants, identifies current/primary choices, emits bounded provider pages, and validates all assignments against a freshly loaded catalog |
| `opencode/preferences.js` | handwritten schema-v1 migration and schema-v2 JSON-line parser, exact role/model/variant validator, and safe reader for separate `opencode-subagent-models.conf` assignments; unconfigured roles receive no model field and inherit the primary |
| `opencode/preference-writer.js` | shared OpenCode-only POSIX publisher used by the custom tool and focused tests; enforces secure directories, no-follow handles, atomic rename, file/directory fsync, and distinct post-publication indeterminate-durability status |
| `opencode/configure-opencode-subagents` | read-only `check` command for user-visible preference status; all other commands, including legacy `apply`, return usage without writing |
| `opencode/setup.js` | explicit one-time `npx oh-no-harness setup` binary; discovers the effective global config, preserves JSON/JSONC and comments, creates a mode-0600 backup, atomically registers the package, hands off to OpenCode `/configure-subagents` for catalog-backed model setup, and supports read-only `setup --check` |
| `opencode/generated/agents.json` | generated exact OpenCode inventory: one `oh-no` primary from `docs/platforms/opencode-main-agent.md` plus nine `oh-no-<role>` subagents from `docs/agent-core/*.md`; no static model fields |
| `opencode/generated/commands.json` | generated exact 11-command OpenCode inventory: the 10 workflow skills plus OpenCode `configure-subagents`, all routed to `oh-no` |
| `package.json` | public `oh-no-harness` npm package metadata; exports `opencode/index.js`, exposes `opencode/setup.js` as the setup binary, includes only the OpenCode runtime and package documentation, and stays version-locked with both marketplace manifests |
| repository-root `scripts/generate-skill-wrappers.py` | regenerates 10 Codex `skills/*/SKILL.md`, 12 Claude Code `skills-claude/*/SKILL.md`, and 11 OpenCode `skills-opencode/*/SKILL.md` runtime documents from their exact source compositions; `--check` is enforced by validation |
| repository-root `scripts/generate-agent-wrappers.py` | regenerates nine Claude Code `agents/*.md`, nine Codex `docs/platforms/codex-agents/*.toml`, and OpenCode `opencode/generated/{agents,commands}.json`; `--check` is enforced by validation |
| `scripts/install-codex-agents` | optional Codex custom-agent installer; user scope is default, SessionStart is the sole automatic ensure path, and manual or project-scope runs are explicit |
| repository-root `scripts/test-opencode-plugin.sh` | isolated deterministic OpenCode 1.18.12 source-loading test for real host discovery, exact inventories, the native global permission ceiling, primary/role restrictive ceilings, role hard denies, finite task topology, arbitrary restriction preservation, model preferences, restart consumption, transaction safety, and project immutability; no provider credential or model call |
| repository-root `scripts/test-opencode-package.sh` | packs the exact public npm artifact, verifies its OpenCode-only file inventory, installs it without lifecycle scripts into a disposable root, verifies package resolution/default export, and reruns the isolated OpenCode driver against the installed package |
| repository-root `scripts/test-opencode-setup.mjs` | disposable setup CLI fixtures for absent/existing JSON and JSONC, comments and provider preservation, backup/mode behavior, idempotence, model-setup handoff, file precedence, invalid input, symlink refusal, XDG resolution, and CLI usage |
| repository-root `scripts/test-opencode-static-contract.py` | deterministic mutation tests for OpenCode wrapper frontmatter, generated agents, host-as-ceiling permission handling, setup hard gates, and inventory closure |

## Local Design Documents

| File | Purpose |
|---|---|
| `docs/specs/2026-05-11-oh-no-harness-design.md` | approved project design |
| `docs/reference/relationships.md` | retained skill, agent, and hook graph |
| `docs/reference/migration-from-omc.md` | removed OMC features and migration policy |
| `docs/reference/test-harness-lanes.md` | deterministic smoke, live, and deep-live lane contract matrix used by `scripts/test-harness-lane-contract.py` |
