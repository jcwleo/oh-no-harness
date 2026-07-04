# Codex Auto Routing Rules

This platform overlay is source content for the generated Codex-facing
`auto-routing` runtime document, after the shared core and
`docs/platforms/codex-runtime.md`.

Codex native skill loading remains the primary routing surface. The
`auto-routing` skill can preserve the config file shape and explain the
preference, but it does not add forced routing to Codex SessionStart.

If a Codex-facing SessionStart hook runs, it must stay compact and must not
embed full skill core bodies.

The `codexExecutor` toggle behaves the same way as auto-routing on Codex: its
state is stored and explained here, but it adds NO Codex SessionStart block.
Codex native skill loading is unchanged, and on the Codex host the delegated
executor role behaves as the native `oh-no-executor` — delegation-to-Codex is a
no-op there. The `oh-no-config codex-executor on|off|status` verbs still read and
write the stored preference for portability, but they do not inject a delegation
block on Codex.
