# Claude Code Fusion Rescue Rules

This platform overlay is source content for the generated Claude Code-facing
`fusion-rescue` runtime document, after the shared core and
`docs/platforms/claude-code-runtime.md`.

## Codex Consult Path

From Claude Code, consult Codex for a panel slot only by dispatching the
dedicated read-only consult agent `oh-no-harness:fusion-codex`. That agent
resolves the Codex companion path and runs one read-only `codex-companion.mjs`
call whose packet instructs Codex to dispatch `oh-no-fusion-rescue-analyst` for
one assigned lens and return that analyst's exact panel fields. If the companion
is unavailable or unresolvable, record it as unavailable and use current-host
analysis for the affected slot in default mode. In `require-cross-host` mode, the
run blocks unless `oh-no-harness:fusion-codex` returns the assigned panel output.

From Claude Code, the Codex consult must run synchronously and return Codex's
actual panel analysis as the panel output. The `oh-no-harness:fusion-codex` agent
runs the `codex-companion.mjs` call read-only: it omits the write flag so the
companion sandbox is read-only (best-effort, not a guarantee — see the consult
agent core), and it must omit `--background` so the call runs in the
foreground, not as a detached background job. Do not authorize write-capable edits
for an analysis-only panel.

The consult agent must require role-ownership proof that
`oh-no-fusion-rescue-analyst`, not a parent inline Codex answer, produced the
returned panel. A parent inline Codex answer is not a valid opposite-host panel
response. A response that only acknowledges a queued or background job, for
example text that says a task started in the background and points to a status
command for a job id, is not a valid opposite-host panel response. Treat such a
job-launch acknowledgment or an unproven inline answer as no Codex response: in
default mode, record the failure class and run the affected slot on the current
host; in require-cross-host mode, block and name the current-host three-panel
fallback. Do not poll status or fetch a deferred result from inside the panel to
compensate; the consult call itself must return the analysis.

## Lens Ownership And Fallback

When Codex is available, use the `oh-no-harness:fusion-codex` consult for the
`adversarial` lens unless the caller supplied a stricter lens assignment and the
synthesis records why it changed. If Codex is unavailable from Claude Code, record
`Codex adversarial unavailable` and run the adversarial lens on the current Claude
Code host.

If the Codex consult returns only a background job-launch acknowledgment instead
of analysis, or cannot prove `oh-no-fusion-rescue-analyst` role ownership, record
`Codex consult returned no analysis (background job acknowledgment only)`, treat
the slot as having no opposite-host response, and run it on the current host in
default mode.
