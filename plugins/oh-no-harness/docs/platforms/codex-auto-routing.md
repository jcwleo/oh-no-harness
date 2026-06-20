# Codex Auto Routing Rules

This platform overlay is source content for the generated Codex-facing
`auto-routing` runtime document, after the shared core and
`docs/platforms/codex-runtime.md`.

Codex native skill loading remains the primary routing surface. The
`auto-routing` skill can preserve the config file shape and explain the
preference, but it does not add forced routing to Codex SessionStart.

If a Codex-facing SessionStart hook runs, it must stay compact and must not
embed full skill core bodies.
