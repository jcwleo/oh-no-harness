# Relationships

## Bootstrap

```text
Claude Code SessionStart
  -> hooks/run-hook.cmd session-start
  -> hooks/session-start
  -> compact native skill-loading bootstrap
  -> OH_NO_FORCED_ROUTING only when auto-routing is enabled

Claude Code UserPromptSubmit for Ralph
  -> hooks/run-hook.cmd ralph-platform-adapter
  -> hooks/ralph-platform-adapter
  -> docs/shared/ralph-subagent-policy.md
  -> docs/platforms/claude-code-ralph.md
  -> agents/<role>.md as Claude Code plugin-scoped subagents

Claude Code slash command
  -> commands/<skill>.md
  -> skills-claude/<skill>/SKILL.md with raw $ARGUMENTS
  -> docs/skill-core/<skill>.md
  -> docs/platforms/claude-code.md

Codex
  -> root .agents/plugins/marketplace.json
  -> plugins/oh-no-harness/.codex-plugin/plugin.json
  -> skills/
  -> hooks/run-hook.cmd session-start when plugin hooks are enabled
  -> hooks/session-start
  -> scripts/install-codex-agents --scope user --ensure --quiet as best-effort custom-agent ensure
  -> using-oh-no-harness through native skill discovery
  -> docs/skill-core/<skill>.md through the Codex-facing wrapper
  -> docs/platforms/codex.md
  -> docs/agent-core/<role>.md for spawned role prompt bodies
  -> optional docs/platforms/codex-agents/*.toml installed or refreshed by scripts/install-codex-agents

Codex UserPromptSubmit for Ralph when plugin hooks are enabled
  -> hooks/run-hook.cmd ralph-platform-adapter
  -> hooks/ralph-platform-adapter
  -> scripts/install-codex-agents --scope user --ensure --quiet as best-effort fallback preflight
  -> docs/shared/ralph-subagent-policy.md
  -> docs/platforms/codex-ralph.md
  -> docs/agent-core/<role>.md for Codex spawn_agent prompt embedding
```

## Skill Graph

```text
using-oh-no-harness
  -> explains local skills and explicit next-skill guidance

auto-routing
  -> writes persistent user preference for stronger SessionStart skill-selection guidance
  -> Claude Code hooks/session-start reads the setting and appends OH_NO_FORCED_ROUTING when enabled

interview
  -> explore for brownfield context
  -> docs/shared/execution-modes.md for provisional Ralph sizing
  -> ralplan after approval for consensus planning
  -> ralph after approval for direct execution
  -> autopilot after approval for end-to-end orchestration

ralplan
  -> embedded consensus planning workflow
  -> docs/shared/execution-modes.md for required Ralph execution profile
  -> explore when codebase context is needed
  -> analyst for hidden requirements, risks, and constraints
  -> planner
  -> architect
  -> critic
  -> ralph or autopilot after approval

ralph
  -> docs/shared/execution-modes.md before editing
  -> explore when files, tests, or integration surfaces are not obvious
  -> docs/shared/ralph-subagent-policy.md before subagent dispatch
  -> docs/shared/parallel-subagents.md as a short pointer for parallel dispatch
  -> docs/platforms/claude-code-ralph.md on Claude Code
  -> docs/platforms/codex-ralph.md on Codex
  -> test-driven-development before behavior-changing production edits
  -> systematic-debugging for failing checks, regressions, or unexpected behavior
  -> executor
  -> architect for architecture-sensitive or broad completion review
  -> critic for optional adversarial review
  -> verifier
  -> code-reviewer
  -> security-reviewer when risk requires
  -> qa-tester when workflow testing is required
  -> simplify after functional reviewer approval
  -> verification-before-completion before final completion claims

autopilot
  -> interview stage when requirements are vague
  -> ralplan for planning
  -> ralph for mode-gated execution and verification
  -> test-driven-development when execution is handled inline and behavior changes
  -> systematic-debugging when QA or verification fails
  -> verification-before-completion before the final report
  -> docs/shared/ralph-subagent-policy.md when inline phases can safely run in parallel
  -> docs/shared/parallel-subagents.md as a short pointer for parallel dispatch
  -> explore / analyst / planner / architect / critic / executor when phases are handled inline
  -> inline QA loop with debugger, verifier, qa-tester, code-reviewer, security-reviewer

test-driven-development
  -> no outbound skill dependency
  -> internal mid-loop discipline, not a top-level implementation skill
  -> ordinary implementation requests route through `ralph`, which invokes TDD internally when behavior changes
  -> evidence consumed by ralph, verifier, code-reviewer, debugger, and qa-tester

simplify
  -> no outbound skill dependency

verification-before-completion
  -> verifier for evidence packaging
  -> code-reviewer, security-reviewer, or qa-tester when risk requires

systematic-debugging
  -> debugger for root-cause investigation
  -> explore for codebase facts and working examples
  -> test-driven-development for bug reproduction tests
  -> executor for the minimal fix after root cause is known
  -> verifier and verification-before-completion for fix evidence
```

## Provider Guidance

Provider guidance is a maintenance reference, not an extra runtime layer:

```text
Codex runtime
  -> docs/skill-core/<skill>.md
  -> docs/platforms/codex.md
  -> summarized OpenAI guidance from docs/providers/openai.md

Claude Code runtime
  -> docs/skill-core/<skill>.md
  -> docs/platforms/claude-code.md
  -> summarized Anthropic guidance from docs/providers/anthropic.md
```

Do not make skill wrappers load `docs/providers/*.md` directly. Update provider
docs first when official company guidance changes, then copy only stable,
runtime-critical rules into the matching platform doc.

## Agent Relationship Summary

Skills are public workflow entrypoints. Agents are role prompts selected by those skills or by the current platform's subagent mechanism. `docs/agent-core/<role>.md` is the platform-neutral role body and source of truth for agent behavior. `agents/<role>.md` is a generated Claude Code wrapper with YAML frontmatter, while Codex dispatch embeds the frontmatter-free body or uses generated TOML templates ensured by `scripts/install-codex-agents`; Codex SessionStart is the primary user-scope ensure point and Ralph preflight is only a fallback before named custom-agent dispatch. Regenerate wrappers with `scripts/generate-agent-wrappers.py --write` after changing agent-core content or wrapper metadata. Agent outputs may recommend another role or workflow skill to the caller, but the active skill still owns approval gates, artifact updates, and any `Next Skill Handoff`. Agent arrows below mean "recommend or return evidence for the caller to route," not hidden auto-invocation.

| Agent | Main inbound use | Main outbound recommendations |
|---|---|---|
| `explore` | `interview`, `ralplan`, `ralph`, `autopilot` | `analyst`, `planner`, `architect`, `debugger`, `verifier` |
| `analyst` | `ralplan`, `autopilot` | `interview`, `ralplan`, `planner`, `architect`, `critic` |
| `planner` | `ralplan` | `explore`, `analyst`, `architect`, `critic` |
| `architect` | `ralplan`, `ralph`, `autopilot` | `critic`, `qa-tester`, `verifier` |
| `critic` | `ralplan`, optional Ralph review, review gates | `planner`, `analyst`, `architect`, `executor`, `security-reviewer` |
| `executor` | `ralph`, implementation phases | `explore`, `architect`, `debugger`, `verifier` |
| `debugger` | `systematic-debugging`, QA, or failing checks | `explore`, `architect`, `executor`, `verifier` |
| `verifier` | `ralph`, `autopilot`, `systematic-debugging`, `verification-before-completion`, final evidence | `code-reviewer`, `security-reviewer`, `qa-tester` |
| `code-reviewer` | `ralph`, `autopilot`, `verification-before-completion` validation | `verifier`, `security-reviewer`, `simplify` recommendation |
| `cleanup-reuse` | `simplify` Phase 1 Reuse cleanup pass | `code-reviewer`, `security-reviewer`, `architect`, `verifier` |
| `cleanup-simplification` | `simplify` Phase 1 Simplification cleanup pass | `code-reviewer`, `security-reviewer`, `architect`, `verifier` |
| `cleanup-efficiency` | `simplify` Phase 1 Efficiency cleanup pass | `code-reviewer`, `security-reviewer`, `architect`, `verifier` |
| `cleanup-altitude` | `simplify` Phase 1 Altitude cleanup pass | `architect`, `code-reviewer`, `security-reviewer`, `verifier` |
| `security-reviewer` | security-sensitive validation | `verifier`, `code-reviewer` |
| `qa-tester` | user-facing validation | `debugger`, `verifier` |

## Hook Boundary

Oh No Harness includes a SessionStart bootstrap hook and a narrow Ralph
UserPromptSubmit adapter hook.

The Ralph adapter hook inspects only the submitted prompt text for a Ralph
invocation, injects shared Ralph subagent policy plus the current platform's
adapter, and exits without output for non-Ralph prompts. It does not activate
workflow state, bridge skill calls, prevent stopping, or mutate a mode ledger.
