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
  -> generated runtime document composed from docs/skill-core/<skill>.md,
     docs/platforms/claude-code.md, and optional
     docs/platforms/claude-code-<skill>.md

Codex
  -> root .agents/plugins/marketplace.json
  -> plugins/oh-no-harness/.codex-plugin/plugin.json
  -> skills/
  -> hooks/run-hook.cmd session-start when plugin hooks are enabled
  -> hooks/session-start
  -> scripts/install-codex-agents --scope user --ensure --quiet as best-effort custom-agent ensure
  -> using-oh-no-harness through native skill discovery
  -> skills/<skill>/SKILL.md generated runtime document composed from
     docs/skill-core/<skill>.md, docs/platforms/codex.md, and optional
     docs/platforms/codex-<skill>.md
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
  -> ultrawork after approval for end-to-end orchestration

ralplan
  -> embedded consensus planning workflow
  -> docs/shared/execution-modes.md for required Ralph execution profile
  -> explore when codebase context is needed
  -> analyst for hidden requirements, risks, and constraints
  -> planner
  -> plan-reviewer
  -> ralph or ultrawork after approval

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
  -> plan-reviewer for architecture-sensitive completion review and optional adversarial or overcomplication review
  -> verifier including its scenario lens when workflow testing is required
  -> code-reviewer including its security lens when risk requires
  -> fusion-rescue when ordinary analysis or debugging stalls after credible evidence exists
  -> simplify after functional reviewer approval
  -> verification-before-completion before final completion claims

ultrawork
  -> interview stage when requirements are vague
  -> ralplan for planning
  -> ralph for mode-gated execution and verification
  -> test-driven-development when execution is handled inline and behavior changes
  -> systematic-debugging when QA or verification fails
  -> verification-before-completion before the final report
  -> docs/shared/ralph-subagent-policy.md when inline phases can safely run in parallel
  -> docs/shared/parallel-subagents.md as a short pointer for parallel dispatch
  -> explore / analyst / planner / plan-reviewer / executor when phases are handled inline
  -> inline QA loop with debugger, verifier (scenario lens included), code-reviewer (security lens included)

test-driven-development
  -> no outbound skill dependency
  -> internal mid-loop discipline, not a top-level implementation skill
  -> ordinary implementation requests route through `ralph`, which invokes TDD internally when behavior changes
  -> evidence consumed by ralph, verifier, code-reviewer, and debugger

simplify
  -> no outbound skill dependency

verification-before-completion
  -> verifier for evidence packaging and scenario coverage
  -> code-reviewer (security lens included) when risk requires

systematic-debugging
  -> debugger for root-cause investigation
  -> explore for codebase facts and working examples
  -> test-driven-development for bug reproduction tests
  -> executor for the minimal fix after root cause is known
  -> fusion-rescue when competing hypotheses remain contradictory or stalled after ordinary diagnostics
  -> verifier and verification-before-completion for fix evidence

fusion-rescue
  -> fusion-rescue-analyst for current-host panel lenses
  -> optional bounded cross-host consult through the active platform-specific
     Fusion Rescue adapter when the host capability is available
  -> returns synthesis to ralph, systematic-debugging, ultrawork active phase, or the direct caller
```

## Provider Guidance

Provider guidance is a maintenance reference, not an extra runtime layer:

```text
Codex runtime
  -> skills/<skill>/SKILL.md generated from docs/skill-core/<skill>.md
  -> docs/platforms/codex.md and optional docs/platforms/codex-<skill>.md
  -> docs/platforms/codex-fusion-rescue.md for fusion-rescue only
  -> docs/platforms/codex-simplify.md for simplify only
  -> summarized OpenAI guidance from docs/providers/openai.md

Claude Code runtime
  -> skills-claude/<skill>/SKILL.md generated from docs/skill-core/<skill>.md
  -> docs/platforms/claude-code.md and optional docs/platforms/claude-code-<skill>.md
  -> docs/platforms/claude-code-fusion-rescue.md for fusion-rescue only
  -> docs/platforms/claude-code-simplify.md for simplify only
  -> summarized Anthropic guidance from docs/providers/anthropic.md
```

Do not add `docs/providers/*.md` as generated runtime sources. Update provider
docs first when official company guidance changes, then copy only stable,
runtime-critical rules into the matching platform doc and regenerate skill
runtime documents with `scripts/generate-skill-wrappers.py --write`.

## Agent Relationship Summary

Skills are public workflow entrypoints. Agents are role prompts selected by those skills or by the current platform's subagent mechanism. `docs/agent-core/<role>.md` is the platform-neutral role body and source of truth for agent behavior. `agents/<role>.md` is a generated Claude Code wrapper with YAML frontmatter, while Codex dispatch embeds the frontmatter-free body or uses generated TOML templates ensured by `scripts/install-codex-agents`; Codex SessionStart is the primary user-scope ensure point and Ralph preflight is only a fallback before named custom-agent dispatch. Regenerate wrappers with `scripts/generate-agent-wrappers.py --write` after changing agent-core content or wrapper metadata. Agent outputs may recommend another role or workflow skill to the caller, but the active skill still owns approval gates, artifact updates, and any `Next Skill Handoff`. Agent arrows below mean "recommend or return evidence for the caller to route," not hidden auto-invocation.

| Agent | Main inbound use | Main outbound recommendations |
|---|---|---|
| `explore` | `interview`, `ralplan`, `ralph`, `ultrawork` | `analyst`, `planner`, `plan-reviewer`, `debugger`, `verifier` |
| `analyst` | `ralplan`, `ultrawork` | `interview`, `ralplan`, `planner`, `plan-reviewer` |
| `planner` | `ralplan` | `explore`, `analyst`, `plan-reviewer` |
| `plan-reviewer` | `ralplan`, `ralph` completion review, `ultrawork` final validation, `systematic-debugging` escalation | `planner` (findings and dispositions), `verifier`, `code-reviewer` |
| `executor` | `ralph`, implementation phases | `explore`, `plan-reviewer`, `debugger`, `verifier` |
| `debugger` | `systematic-debugging`, QA, or failing checks | `explore`, `plan-reviewer`, `executor`, `verifier` |
| `verifier` | `ralph`, `ultrawork`, `systematic-debugging`, `verification-before-completion`, user-facing validation, final evidence | `code-reviewer`, `debugger` for failing scenarios |
| `code-reviewer` | `ralph`, `ultrawork`, `verification-before-completion` validation, security-sensitive validation | `verifier`, `simplify` recommendation |
| `fusion-rescue-analyst` | `fusion-rescue` panel analysis | returns one assigned panel lens to the caller for current-host synthesis |

## Hook Boundary

Oh No Harness includes a SessionStart bootstrap hook and a narrow Ralph
UserPromptSubmit adapter hook.

The Ralph adapter hook inspects only the submitted prompt text for a Ralph
invocation, injects shared Ralph subagent policy plus the current platform's
adapter, and exits without output for non-Ralph prompts. It does not activate
workflow state, bridge skill calls, prevent stopping, or mutate a mode ledger.
