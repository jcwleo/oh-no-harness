# Oh No Harness Plugin Package

This directory is the source package for the `oh-no-harness` plugin.

The canonical user documentation lives at the repository root:

- [README](../../README.md)
- [Korean README](../../README.ko.md)

Plugin development conventions live next to this package:

- [Contributing](CONTRIBUTING.md)

This package contains the plugin manifests and runtime surface used by Claude
Code and Codex:

- `.claude-plugin/plugin.json`
- `.codex-plugin/plugin.json`
- `skills/`
- `commands/`
- `agents/`
- `hooks/`
- `scripts/`

The repository root remains the self-hosted marketplace. Its marketplace
manifests point here as the plugin source of truth.
