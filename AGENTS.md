# Agent Instructions

This repository root is a marketplace wrapper for the Oh No Harness plugin.

The plugin source of truth is:

```text
plugins/oh-no-harness/
```

When editing skills, commands, agents, hooks, docs, or plugin manifests, work
inside that plugin directory and follow
`plugins/oh-no-harness/AGENTS.md`.

Root files should stay limited to marketplace manifests, repository metadata,
and release/test tooling. Do not reintroduce root-level duplicate plugin
content such as `skills/`, `commands/`, `agents/`, `hooks/`, `docs/`,
`.codex-plugin/plugin.json`, or `.claude-plugin/plugin.json`.
