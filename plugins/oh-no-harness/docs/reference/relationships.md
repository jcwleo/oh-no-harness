# Relationships

## Bootstrap

```text
Claude Code SessionStart
  -> hooks/run-hook.cmd session-start
  -> hooks/session-start
  -> skills/using-oh-no-harness/SKILL.md

Claude Code slash command
  -> commands/<skill>.md
  -> skills/<skill>/SKILL.md with raw $ARGUMENTS

Codex
  -> root .agents/plugins/marketplace.json
  -> plugins/oh-no-harness/.codex-plugin/plugin.json
  -> skills/
  -> using-oh-no-harness through native skill discovery
```

## Skill Graph

```text
using-oh-no-harness
  -> explains local skills and explicit next-skill guidance

auto-routing
  -> writes persistent user preference for stronger SessionStart skill-selection guidance
  -> hooks/session-start reads the setting and appends OH_NO_FORCED_ROUTING when enabled

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
  -> docs/shared/parallel-subagents.md before parallel dispatch
  -> test-driven-development before behavior-changing production edits
  -> systematic-debugging for failing checks, regressions, or unexpected behavior
  -> executor
  -> architect for architecture-sensitive or broad completion review
  -> critic for optional adversarial review
  -> verifier
  -> code-reviewer
  -> security-reviewer when risk requires
  -> qa-tester when workflow testing is required
  -> ai-slop-cleaner after functional reviewer approval
  -> verification-before-completion before final completion claims

autopilot
  -> interview stage when requirements are vague
  -> ralplan for planning
  -> ralph for mode-gated execution and verification
  -> test-driven-development when execution is handled inline and behavior changes
  -> systematic-debugging when QA or verification fails
  -> verification-before-completion before the final report
  -> docs/shared/parallel-subagents.md when inline phases can safely run in parallel
  -> explore / analyst / planner / architect / critic / executor when phases are handled inline
  -> inline QA loop with debugger, verifier, qa-tester, code-reviewer, security-reviewer

test-driven-development
  -> no outbound skill dependency
  -> evidence consumed by ralph, verifier, code-reviewer, debugger, and qa-tester

ai-slop-cleaner
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

## Agent Relationship Summary

Skills are public workflow entrypoints. Agents are role prompts selected by those skills or by the current platform's subagent mechanism. Agent outputs may recommend another role or workflow skill to the caller, but the active skill still owns approval gates, artifact updates, and any `Next Skill Handoff`. Agent arrows below mean "recommend or return evidence for the caller to route," not hidden auto-invocation.

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
| `code-reviewer` | `ralph`, `autopilot`, `verification-before-completion` validation | `verifier`, `security-reviewer`, `ai-slop-cleaner` recommendation |
| `security-reviewer` | security-sensitive validation | `verifier`, `code-reviewer` |
| `qa-tester` | user-facing validation | `debugger`, `verifier` |

## Hook Boundary

Oh No Harness includes only the bootstrap hook.

No hook inspects prompts, activates workflow state, bridges skill calls, prevents stopping, or mutates a mode ledger.
