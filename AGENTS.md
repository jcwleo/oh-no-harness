# Agent Instructions

This repository is a Markdown-first skill harness.

Keep the external skill surface limited to:

- `using-oh-no-harness`
- `deep-interview`
- `ralplan`
- `ralph`
- `autopilot`
- `auto-routing`
- `test-driven-development`
- `ai-slop-cleaner`
- `verification-before-completion`
- `systematic-debugging`

When adapting OMC content:

- Keep only dependencies required by the retained skills.
- Use `.oh-no/specs/` for generated specs.
- Use `.oh-no/plans/` for generated plans.
- Use `.oh-no/sessions/` for transient workflow state.
- Do not add OMC keyword detection, persistent mode hooks, bridge hooks, or state ledger behavior.
- Do not reintroduce `team`, `ultrawork`, `ultraqa`, `cancel`, `ask`, or `autoresearch`.

When editing skills, make skill chaining explicit in Markdown. Do not rely on hidden automation.
