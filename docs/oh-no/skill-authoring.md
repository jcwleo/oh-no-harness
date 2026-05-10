# Skill authoring

This is the contract for editing the canonical SKILL.md files
(`clarify`, `planning`, `ralph`, `debug`, `verify`). The harness asserts
behavior through Markdown text, so every word in a SKILL.md is part of
the contract — not a description of one.

## Frontmatter rules

```yaml
---
name: <skill>                # must equal the directory name
description: <trigger>       # ONE sentence. Trigger only — see below.
when_to_use: <trigger>       # WHEN to invoke. Includes mode hints (--deep, --ral).
argument-hint: <hint>        # Claude Code autocomplete; matches positional args.
arguments: [...]             # Named args, optional first if the flag is optional.
---
```

`scripts/validate-skills` enforces presence of every field above and the
`name` ↔ directory match. It also rejects process-summary phrases inside
`description`.

## Trigger-only `description`

`description` is a *discovery trigger*. The host (Claude Code, Codex,
etc.) reads it to decide whether to invoke the skill at all. If it
already summarizes the skill's process, the agent will sometimes act on
the description without reading the body — and the body is where the
actual rules live.

Good (trigger):

```yaml
description: "Investigate a bug, failing test, regression, or runtime error from concrete evidence before proposing or applying a fix."
```

Bad (process summary):

```yaml
description: "Investigate a bug from concrete evidence. Uses a systematic four-phase root-cause process across pattern analysis, hypothesis, testing, and fix."
```

The two examples describe the same skill. The first tells the host
*when* to fire it. The second explains *how* it works internally and
gives the agent enough surface to skip the body.

### Anti-patterns the validator flags

`scripts/validate-skills` fails the build if any `description:` field
contains the following case-sensitive fragments — each of them only
appears in process narration, never in a real trigger:

- `Uses a ` / `Integrates ` / `Combines ` — process narration.
- `four-phase`, `basic mode and --ral mode`, `default clarification
  mode plus --deep` — internal mode counts and phase counts.

Single-sentence shape is recommended but not enforced. A
two-sentence description with two trigger conditions
(e.g. "Use when X. Use --deep when Y.") is acceptable; a
two-sentence description with a process summary is not — the
keyword filters above will catch it.

### Where process detail goes instead

Move it to one of these locations, in order of preference:

1. **`when_to_use`** — if the detail is itself a *trigger condition*,
   such as "use `--deep` for high-risk or high-ambiguity work."
2. **The skill body** — under a heading like "Mode", "Phases", or
   "Process". This is where the agent reads it once it has decided the
   skill is the right route.
3. **`bootstrap/oh-no.md`** — only if it cuts across multiple skills,
   e.g. the worktree isolation protocol or the role-pass matrix.

## Editing a SKILL.md safely

Treat every change as a behavior change. Before merging:

1. **Read the validator** — `scripts/validate-skills` requires specific
   tokens for each canonical skill (e.g. `RALPLAN-DR`, `Architect`,
   `RED -> GREEN -> REFACTOR`, `Resume and context-window protocol`).
   Removing or renaming a required token breaks the build. Search the
   validator for the file you touched before assuming a rename is safe.
2. **Pick a baseline scenario** from `tests/acceptance/scenarios/` that
   exercises the skill you are editing.
3. **Run the scenario before the change** in a fresh host session.
   Record the transcript using
   `tests/acceptance/transcripts/TEMPLATE.md`.
4. **Make the change.** Keep the diff focused. Do not couple a
   description tweak with an unrelated body rewrite.
5. **Run the scenario again** in another fresh session. Compare the
   transcripts. The expected route, forbidden-shortcut behavior, and
   evidence discipline should not regress.
6. **Run `scripts/validate-skills`.** If it fails, fix the underlying
   issue. Do not weaken the validator to make a change land.

If you cannot get a clean before/after pair (no host access, no fresh
session), say so in the PR description rather than claiming behavior
parity.

## Adding new tokens to the contract

Adding a required phrase (e.g. a new section heading the agent must
honor) is a public-API change for the skill. Update in this order:

1. The skill body, with the new heading and the rule it asserts.
2. `scripts/validate-skills`, with a `require_grep` for the new token.
3. `docs/oh-no-harness-design.md`, if the rule is an invariant.
4. The relevant `tests/acceptance/scenarios/` entry, if the new rule
   changes a routing or shortcut decision.

Do not add a new top-level skill. The five-skill canonical surface is
locked by `scripts/validate-skills` and called out in
`docs/oh-no-harness-design.md`. New work fits inside an existing skill,
its role prompts, or `bootstrap/oh-no.md`.

## Common review checks

- Does the SKILL.md still mention root-cause discipline AND completion
  integrity? The validator's bottom loop enforces both for every
  `skills/*/SKILL.md` and `agents/*.md`.
- Does the description survive the trigger test ("would a host pick
  this skill from the description alone, without reading the body, in a
  way that matches `when_to_use`?")? If yes, the description is
  trigger-shaped.
- Did the change widen scope (more triggers, broader applicability) or
  narrow it (fewer triggers, more conditions)? Both are valid; both
  need a recorded behavior pass.
