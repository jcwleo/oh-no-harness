# Migration From OMC

Oh No Harness keeps selected OMC workflow content and removes the OMC runtime layer.

## Kept

- `interview`
- `ralplan`
- `ralph`
- `ultrawork`
- `simplify` cleanup, adapted from Claude Code's built-in skill for Codex parity
- `plan --consensus` behavior embedded directly in `ralplan`
- `test-driven-development`, `verification-before-completion`, and `systematic-debugging` as Superpowers-derived safety workflows
- selected agents needed by those skills
- shared agent tier, verification tier, and company context guidance

## Removed

- keyword detector
- persistent-mode Stop hook
- PreToolUse/PostToolUse bridge hook
- mode state ledger
- automatic vague-prompt redirection
- `team`
- legacy OMC `ultrawork` behavior/state machinery
- `ultraqa`
- `cancel`
- `ask`
- `autoresearch`

## Path Mapping

| OMC path | Oh No Harness path |
|---|---|
| `.omc/state/` | `.oh-no/sessions/` |
| `.omc/specs/` | `.oh-no/specs/` |
| `.omc/plans/` | `.oh-no/plans/` |
| OMC company-context config files | not ported as runtime dependencies |
| `docs/company-context-interface.md` | `docs/shared/ (retired 2026-07-17) company-context-interface.md` as an advisory context shape |

## Agent Mapping

Tier-specific OMC agent names become base agent names with task scope and scrutiny level stated in the delegation prompt. Model selection follows the current platform and agent configuration.

## Runtime Policy

The bootstrap hook injects a compact native skill-loading reminder at session start. It does not embed the full `using-oh-no-harness` core body. No other hook participates in skill selection or workflow persistence.
