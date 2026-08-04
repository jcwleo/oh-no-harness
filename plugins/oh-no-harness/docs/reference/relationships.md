# Relationships

## Bootstrap

```text
Native workflow discovery
  -> each workflow's frontmatter description
  -> matching destination workflow

SessionStart global boundary layer
  -> hooks/run-hook.cmd session-start
  -> hooks/session-start
  -> OH_NO_BOOTSTRAP unconditionally whenever the hook runs
  -> compact no-route, direct-edit, object-of-analysis, caller-owned child-packet, and approval-gated chaining boundaries; Claude Code runs this layer on every session and Codex when plugin hooks are enabled

Claude Code auto-routing overlay
  -> the same SessionStart appends OH_NO_FORCED_ROUTING only when auto-routing is enabled
  -> forced action ordering and essential precedence; installed workflow descriptions still select the destination; no Codex counterpart

Claude Code SessionStart support
  -> <OH_NO_MODEL_DIVERSITY> on every session, using validated stored top-tier/secondary settings or the built-in top-tier fallback
  -> scripts/configure-subagents reapply best-effort after plugin-cache updates

Claude Code slash command
  -> commands/<skill>.md
  -> skills-claude/<skill>/SKILL.md with raw $ARGUMENTS
  -> generated runtime document. Self-contained skills (interview, ralplan,
     ralph, systematic-debugging, ultrawork,
     verification-before-completion) compose docs/skill-core/<skill>.md plus
     the required docs/platforms/claude-code-<skill>.md adapter only; the
     remaining skills compose docs/skill-core/<skill>.md,
     docs/platforms/claude-code-runtime.md, and optional
     docs/platforms/claude-code-<skill>.md

Codex
  -> root .agents/plugins/marketplace.json
  -> plugins/oh-no-harness/.codex-plugin/plugin.json
  -> skills/
  -> native skill discovery loads each workflow's frontmatter description
  -> matching skills/<skill>/SKILL.md destination. Every workflow composes
     docs/platforms/codex-child-packet-floor.md. Self-contained skills
     (interview, ralplan, ralph, systematic-debugging, ultrawork,
     verification-before-completion) then compose their required
     docs/platforms/codex-<skill>.md adapter without codex-runtime.md; remaining
     skills compose docs/platforms/codex-runtime.md and any optional overlay
  -> hooks/run-hook.cmd session-start when plugin hooks are enabled
  -> hooks/session-start supplies the compatible global direct-dispatch boundary without forced routing
  -> scripts/install-codex-agents --scope user --ensure --quiet as best-effort custom-agent ensure
  -> docs/agent-core/<role>.md for spawned role prompt bodies
  -> optional docs/platforms/codex-agents/*.toml installed or refreshed by scripts/install-codex-agents

OpenCode npm runtime
  -> package.json exports opencode/index.js as the package entrypoint
  -> opencode/index.js config hook
  -> skills-opencode/ registered as a native skill path (10 workflows plus the separate OpenCode configure-subagents skill)
  -> opencode/generated/commands.json registers the same 11 command names on the oh-no primary
  -> opencode/generated/agents.json registers one oh-no primary carrying docs/platforms/opencode-main-agent.md and nine oh-no-<role> subagents carrying docs/agent-core/<role>.md
  -> built-in build and plan are disabled; an absent/build/plan default becomes oh-no, while an unrelated custom default is preserved
  -> subagent_depth is raised to 2 when lower or absent and a higher custom value is preserved
  -> no SessionStart dependency; startup config loading is deterministic and process-scoped
```

## Skill Graph

```text
auto-routing
  -> configuration-only; never selects the current-turn destination
  -> writes a persistent user preference
  -> Claude Code hooks/session-start reads the setting on the next SessionStart and appends OH_NO_FORCED_ROUTING when enabled
  -> Codex stores the preference but gains no forced-routing semantics
  -> OpenCode keeps positive selection in native skill descriptions and the skill tool; the static oh-no primary always carries its orchestration boundaries
  -> docs/platforms/claude-code-auto-routing.md on Claude Code
  -> docs/platforms/codex-auto-routing.md on Codex
  -> docs/platforms/opencode-auto-routing.md on OpenCode

install-statusline
  -> user-invoked Claude-Code-only setup action; never model-invoked (disable-model-invocation: true on both the skill and the command wrapper)
  -> disable-model-invocation: true excludes it from native and forced destination candidates
  -> copies scripts/statusline-command to ~/.claude/statusline-command.sh and sets settings.json statusLine via scripts/install-statusline
  -> docs/platforms/claude-code-install-statusline.md on Claude Code (no Codex variant)

configure-subagents
  -> Claude Code branch: user-invoked setup action; never model-invoked (disable-model-invocation: true on both the skill and the command wrapper)
  -> Claude Code disable-model-invocation: true excludes it from native and forced destination candidates
  -> Claude Code collects a model and reasoning effort for each of the 9 subagents and rewrites the installed runtime agents/*.md in one recoverable transaction via scripts/configure-subagents (never the generator-owned canonical agents in a source checkout, never Codex TOMLs)
  -> Claude Code stores schema-versioned preferences outside the plugin cache, including the top-tier model set and optional native secondary model; never records or prints proxy credentials
  -> Claude Code hooks/session-start runs scripts/configure-subagents reapply best-effort after a plugin-cache update resets the runtime agents
  -> Claude Code hooks/session-start always injects <OH_NO_MODEL_DIVERSITY> so THOROUGH pairs and Fusion Rescue can use configured model diversity or the documented same-model fallback
  -> docs/platforms/claude-code-configure-subagents.md on Claude Code (no Codex variant)
  -> OpenCode uses a separate standalone docs/platforms/opencode-configure-subagents.md source with a current-explicit-user-request hard gate
  -> OpenCode first calls the read-only oh_no_get_model_catalog tool, then after final confirmation calls oh_no_configure_subagents once with all nine exact provider/model IDs and model-specific variants; the write tool reloads the catalog and writes separate opencode-subagent-models.conf preferences without Bash or a helper path
  -> OpenCode model changes require a full process restart; unconfigured roles inherit the oh-no primary and same-role/inherited calls do not prove model diversity

interview
  -> explore for brownfield context
  -> ralplan after approval for consensus planning
  -> ralph after approval for direct execution
  -> ultrawork after approval for end-to-end orchestration

ralplan
  -> embedded consensus planning workflow
  -> explore when codebase context is needed
  -> analyst for hidden requirements, risks, and constraints
  -> planner
  -> plan-reviewer
  -> ralph or ultrawork after approval

ralph
  -> explore when files, tests, or integration surfaces are not obvious
  -> docs/platforms/claude-code-ralph.md on Claude Code
  -> docs/platforms/codex-ralph.md on Codex
  -> test-driven-development before behavior-changing production edits
  -> systematic-debugging for failing checks, regressions, or unexpected behavior
  -> executor
  -> code-reviewer for execution correctness, architecture-sensitive implementation concerns, and optional adversarial or overcomplication review
  -> verifier including its scenario lens when workflow testing is required
  -> code-reviewer including its security lens when risk requires
  -> fusion-rescue when ordinary analysis or debugging stalls after credible evidence exists
  -> simplify after functional reviewer approval
  -> verification-before-completion before final completion claims
  -> user or ralplan when execution reveals the approved plan or an acceptance criterion is itself wrong or infeasible as written (present options; do not auto-invoke)

ultrawork
  -> interview stage when requirements are vague
  -> ralplan for planning
  -> ralph for mode-gated execution and verification
  -> test-driven-development when execution is handled inline and behavior changes
  -> systematic-debugging when QA or verification fails
  -> verification-before-completion before the final report
  -> explore / analyst / planner / executor when phases are handled inline; Ralplan alone owns its plan-reviewer phase
  -> QA loop via systematic-debugging, which owns debugger dispatch; verifier (scenario lens included), code-reviewer (security lens included)

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
  -> code-reviewer for post-fix review when risk requires (security lens included)
  -> verifier and verification-before-completion for fix evidence

fusion-rescue
  -> fusion-rescue-analyst for all three panel lenses
  -> Claude Code assigns panel identities from the <OH_NO_MODEL_DIVERSITY> block, using configured diversity or the same-model panel fallback
  -> Codex preserves the optional bounded Claude consult through its platform-specific Fusion Rescue adapter when host capability is available
  -> returns synthesis to ralph, systematic-debugging, ultrawork active phase, or the direct caller
```

## Provider Guidance

Provider guidance is a maintenance reference, not an extra runtime layer:

```text
Codex runtime
  -> skills/<skill>/SKILL.md generated from docs/skill-core/<skill>.md
  -> every workflow: docs/platforms/codex-child-packet-floor.md
  -> self-contained skills: required docs/platforms/codex-<skill>.md adapter, without codex-runtime.md
  -> remaining skills: docs/platforms/codex-runtime.md and optional docs/platforms/codex-<skill>.md
  -> docs/platforms/codex-auto-routing.md for auto-routing only
  -> docs/platforms/codex-fusion-rescue.md for fusion-rescue only
  -> docs/platforms/codex-simplify.md for simplify only
  -> summarized OpenAI guidance from docs/providers/openai.md

Claude Code runtime
  -> skills-claude/<skill>/SKILL.md generated from docs/skill-core/<skill>.md
  -> self-contained skills: required docs/platforms/claude-code-<skill>.md adapter only
  -> remaining skills: docs/platforms/claude-code-runtime.md and optional docs/platforms/claude-code-<skill>.md
  -> docs/platforms/claude-code-auto-routing.md for auto-routing only
  -> docs/platforms/claude-code-fusion-rescue.md for fusion-rescue only
  -> docs/platforms/claude-code-simplify.md for simplify only
  -> summarized Anthropic guidance from docs/providers/anthropic.md

OpenCode runtime
  -> skills-opencode/<skill>/SKILL.md generated from docs/skill-core/<skill>.md for the 10 workflows
  -> self-contained skills: required docs/platforms/opencode-<skill>.md adapter only
  -> remaining workflows: docs/platforms/opencode-runtime.md and optional docs/platforms/opencode-<skill>.md
  -> configure-subagents: standalone docs/platforms/opencode-configure-subagents.md only
  -> no provider-company guidance document and no per-task model override
```

Do not add `docs/providers/*.md` as generated runtime sources. Update provider
docs first when official company guidance changes, then copy only stable,
runtime-critical rules into the matching compact platform runtime doc and
regenerate skill runtime documents with
`scripts/generate-skill-wrappers.py --write`.

## Agent Relationship Summary

Skills are public workflow entrypoints. The main caller builds each self-contained child packet under the applicable host floor; the 9 agents contain only role behavior selected by those skills or by the current platform's subagent mechanism. `docs/agent-core/<role>.md` is the platform-neutral role body and source of truth for agent behavior. `agents/<role>.md` is a generated Claude Code wrapper with YAML frontmatter, while Codex dispatch embeds the frontmatter-free body or uses the same 9 generated TOML templates ensured by `scripts/install-codex-agents`; Codex SessionStart is the sole automatic user-scope ensure point before named custom-agent dispatch. OpenCode generates those nine bodies as `oh-no-<role>` subagents in `opencode/generated/agents.json`, alongside one `oh-no` primary sourced from `docs/platforms/opencode-main-agent.md`; its config hook registers both at startup. Claude-host single-round review pairs combine role-specific perspective diversity with configuration-driven model diversity through Claude's `configure-subagents` and SessionStart diversity block. OpenCode uses separate exact provider/model and variant preferences loaded at startup; an unconfigured role inherits the primary, and independent contexts alone are not model diversity. Regenerate wrappers and both OpenCode JSON inventories with `scripts/generate-agent-wrappers.py --write` after changing agent-core content, the OpenCode main-agent source, or wrapper metadata. Agent outputs may recommend another role or workflow skill to the caller, but the active skill still owns approval gates, artifact updates, and any `Next Skill Handoff`. Agent arrows below mean "recommend or return evidence for the caller to route," not hidden auto-invocation.

| Agent | Main inbound use | Main outbound recommendations |
|---|---|---|
| `explore` | `interview`, `ralplan`, `ralph`, `ultrawork` | `analyst`, `planner`, `debugger`, `verifier`; Ralplan owns any plan-reviewer dispatch |
| `analyst` | `ralplan`, `ultrawork` | `interview`, `ralplan`, `planner` |
| `planner` | `ralplan` | `explore`, `analyst`, `plan-reviewer` |
| `plan-reviewer` | `ralplan` planning review only, including when another workflow invokes or uses Ralplan | `planner` (blocking findings and optional follow-ups) |
| `executor` | `ralph`, implementation phases | `explore`, `ralplan` when the approved plan is invalid, `debugger`, `verifier` |
| `debugger` | `systematic-debugging`, QA, or failing checks | `explore`, `ralplan` when planning must be revisited, `executor`, `verifier` |
| `verifier` | `ralph`, `ultrawork`, `systematic-debugging`, `verification-before-completion`, user-facing validation, final evidence | `code-reviewer`, `debugger` for failing scenarios |
| `code-reviewer` | `ralph`, `ultrawork`, `verification-before-completion` validation, `systematic-debugging` (post-fix), security-sensitive validation | `verifier`, `simplify` recommendation |
| `fusion-rescue-analyst` | `fusion-rescue` panel analysis | returns one assigned panel lens to the caller for current-host synthesis |

## Hook Boundary

The Claude Code/Codex plugin surface includes one hook entrypoint: the compact
`SessionStart` bootstrap. OpenCode instead uses the startup `config` hook in
`opencode/index.js`; it loads static local definitions and does not add a daemon.

The `SessionStart` hook does not inspect submitted prompts, activate workflow
state, bridge skill calls, prevent stopping, or mutate a mode ledger. It runs
no background process.
