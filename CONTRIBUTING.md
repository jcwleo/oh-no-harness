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
scripts/test-claude-plugin.sh
scripts/test-codex-plugin.sh --codex-home "$(mktemp -d)"
```

Detailed plugin development conventions live in
[plugins/oh-no-harness/CONTRIBUTING.md](plugins/oh-no-harness/CONTRIBUTING.md).
