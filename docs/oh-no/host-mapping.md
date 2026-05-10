# Host mapping

The oh-no harness ships skills, role prompts, templates, and a
SessionStart hook. Each host (Claude Code, Codex CLI, …) wires those
artifacts in slightly different ways. This doc describes how the
harness expects a host to map them, and how to add a new host.

The five canonical skills (`clarify`, `planning`, `ralph`, `debug`,
`verify`), the artifact templates, and the role prompts under
`agents/` are the same across hosts. Only the *integration surface*
varies.

## What the harness assumes

A host is "documented" when it can do all of:

- Discover and dispatch the canonical skills (typically by reading
  `skills/<name>/SKILL.md` frontmatter and exposing them via slash
  commands or the host-equivalent invocation).
- Resolve the role prompts under `agents/*.md` either as native
  subagents (Claude `Task` / Codex custom agents) or as
  current-session role passes when native dispatch is unavailable.
- Read or accept the SessionStart bootstrap from `bootstrap/oh-no.md`
  so pre-work routing fires before the first edit.
- Honor the worktree isolation protocol (`scripts/worktree-start` or
  the manual fallback) when the plan requires it.

A host becomes "supported" only after those mapped surfaces have at
least one committed behavior transcript under
`tests/acceptance/transcripts/`. A host is "planned" when one or more
of the above is missing today but is on a roadmap. Hosts that cannot
meet the canonical-skill discovery contract are not listed; the
harness does not pretend to support them.

## Mapping concepts to a new host

When extending the harness to a new host, work outward from the
five-skill core:

1. **Skills.** The host must accept `skills/<name>/SKILL.md` as a
   workflow contract. Frontmatter (`name`, `description`,
   `when_to_use`, `argument-hint`, `arguments`) is the discovery
   surface. If the host has no slash-command equivalent, expose the
   skills as documented role prompts the user can paste in.
2. **Agents.** The host should resolve `agents/<role>.md` as either
   native subagents or markdown role prompts. If native dispatch is
   unavailable, document the fallback explicitly in the role-pass
   section of each SKILL.md (we already do).
3. **SessionStart bootstrap.** If the host supports a session-start
   hook, wire it to `bootstrap/oh-no.md`. If it does not, document
   the fallback (typically a `<repo>/AGENTS.md` or equivalent
   repository guidance file).
4. **Worktree helper.** `scripts/worktree-start` is host-agnostic.
   Hosts that need a different helper path (for example because
   `scripts/` is not on PATH) should document the alternative.
5. **Bundle materializer.** `scripts/sync-adapters` produces
   per-host bundles under `dist/<host>/`. New host directories
   should follow the existing claude/codex shape (`<host>/skills/`,
   `<host>/agents/`, optional native-agent template directory).

## Limitations and unsupported claims

The harness is explicit about what it does *not* do for each host.
Do not paper over a missing piece (for example, "Codex CLI installs
custom agents automatically") in this document; record it as a
limitation so the user knows what to set up manually.

If a host claim cannot be verified by running the relevant scenario
under `tests/acceptance/scenarios/`, mark it as "documented but
unverified" rather than "supported".

## Cross-references

- `docs/oh-no/platform-matrix.md` — the host-by-feature matrix this
  doc keeps in sync.
- `bootstrap/oh-no.md` — the tool-mapping guidance shipped to every
  session.
- `docs/oh-no-harness-design.md` — the invariants this mapping must
  preserve (no runtime daemon, no hidden state, packaging-only host
  metadata).
