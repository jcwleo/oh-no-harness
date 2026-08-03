# Contributing

This repository root is only the marketplace wrapper and release/test tooling.
Do not maintain duplicate plugin content at the root.

Edit the plugin under:

```text
plugins/oh-no-harness/
```

Use the root scripts for validation and release:

```sh
python3 scripts/validate-plugin-files.py .
# The Claude smoke script fails closed unless it is isolated from your real
# ~/.claude, so run it with --isolated-config (a throwaway config home the
# script creates and cleans up automatically):
scripts/test-claude-plugin.sh --isolated-config
scripts/test-codex-plugin.sh --codex-home "$(mktemp -d)"
scripts/test-opencode-plugin.sh
scripts/test-opencode-package.sh
```

The first OpenCode lane exercises the source runtime. The package lane creates
the exact npm tarball, installs it without lifecycle scripts, and reruns the
deterministic OpenCode host-loading checks against the installed artifact.

Detailed plugin development conventions live in
[plugins/oh-no-harness/CONTRIBUTING.md](plugins/oh-no-harness/CONTRIBUTING.md).
