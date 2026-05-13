# Oh No Harness Marketplace

This repository is the self-hosted marketplace wrapper for Oh No Harness.

The plugin source of truth lives under:

```text
plugins/oh-no-harness/
```

Root marketplace manifests point to that plugin directory:

- `.claude-plugin/marketplace.json` for Claude Code
- `.agents/plugins/marketplace.json` for Codex

Install commands are unchanged:

```sh
claude plugin marketplace add jcwleo/oh-no-harness
claude plugin install oh-no-harness@oh-no-harness

codex plugin marketplace add jcwleo/oh-no-harness
```

For plugin usage, development, and release details, read:

- [Plugin README](plugins/oh-no-harness/README.md)
- [Contributing](plugins/oh-no-harness/CONTRIBUTING.md)
