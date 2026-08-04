# Oh No Harness Plugin Package

This directory is the source package for the `oh-no-harness` plugin.

The canonical user documentation lives at the repository root:

- [README](../../README.md)
- [Korean README](../../README.ko.md)

Plugin development conventions live next to this package:

- [Contributing](CONTRIBUTING.md)

This package contains the plugin manifests, runtime surface, and maintenance
references used by Claude Code, Codex, and the packaged OpenCode runtime:

- `.claude-plugin/plugin.json`
- `.codex-plugin/plugin.json`
- `package.json` (public `oh-no-harness` OpenCode npm package)
- `skills/` (10 generated Codex-facing runtime skill documents)
- `skills-claude/` (12 generated Claude Code-facing runtime skill documents)
- `skills-opencode/` (11 generated OpenCode-facing runtime skill documents)
- `docs/skill-core/` (shared workflow core)
- `docs/platforms/` (platform-wide runtime guidance and skill overlays)
- `docs/agent-core/` (platform-neutral role prompt bodies and agent behavior source of truth)
- `docs/platforms/codex-agents/` (generated optional Codex custom-agent templates)
- `docs/providers/` (maintenance-only company prompt guidance for platform docs)
- `commands/`
- `agents/` (9 generated Claude Code-facing subagent wrappers)
- `opencode/` (OpenCode config hook, preference helper, and generated agent/command JSON)
- `hooks/`
- `scripts/`

The repository root remains the self-hosted marketplace. Its marketplace
manifests point here as the plugin source of truth.

The OpenCode config hook loads one `oh-no` primary, nine `oh-no-<role>`
subagents, and the 11-skill OpenCode surface. The public npm package exports
`opencode/index.js`, exposes the one-time `oh-no-harness setup` binary, and
includes only the OpenCode adapter, generated OpenCode skills, package
documentation, notices, and license. Install and register it with
`npx --yes oh-no-harness@latest setup`, then quit and restart OpenCode. Run
`/configure-subagents` in OpenCode to choose each role's exact available model
and model-specific variant. Use `npx --yes oh-no-harness@latest setup --check`
for a read-only registration status check.
