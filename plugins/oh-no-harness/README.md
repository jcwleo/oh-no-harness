# Oh No Harness Plugin Package

This directory is the source package for the `oh-no-harness` plugin.

The canonical user documentation lives at the repository root:

- [README](../../README.md)
- [Korean README](../../README.ko.md)

Plugin development conventions live next to this package:

- [Contributing](CONTRIBUTING.md)

This package contains the plugin manifests, runtime surface, and maintenance
references used by Claude Code and Codex:

- `.claude-plugin/plugin.json`
- `.codex-plugin/plugin.json`
- `skills/` (Codex-facing wrappers)
- `skills-claude/` (Claude Code-facing wrappers)
- `docs/skill-core/` (shared workflow core)
- `docs/agent-core/` (platform-neutral role prompt bodies and agent behavior source of truth)
- `docs/platforms/codex-agents/` (generated optional Codex custom-agent templates)
- `docs/providers/` (maintenance-only company prompt guidance for platform docs)
- `commands/`
- `agents/` (generated Claude Code-facing subagent wrappers)
- `hooks/`
- `scripts/`

The repository root remains the self-hosted marketplace. Its marketplace
manifests point here as the plugin source of truth.
