# Claude Code Fusion Rescue Rules

This platform overlay is source content for the generated Claude Code-facing
`fusion-rescue` runtime document, after the shared core and
`docs/platforms/claude-code.md`.

## Codex Consult Path

From Claude Code, consult Codex only through an available and explicitly loaded
`openai/codex-plugin-cc` rescue capability, surfaced as `/codex:rescue` when
that plugin is installed. If that capability is unavailable, record it as
unavailable and use current-host analysis for the affected slot in default
mode. In `require-cross-host` mode, the run blocks unless `/codex:rescue` or
`codex:codex-rescue` returns the assigned panel output.

From Claude Code, the Codex consult must run synchronously and return Codex's
actual panel analysis as the panel output. Pass `--wait` to force foreground
execution, for example `/codex:rescue --wait`, and request read-only Codex
behavior for the consult; do not let it run as a detached background job and do
not authorize write-capable edits for an analysis-only panel.

A response that only acknowledges a queued or background job, for example text
that says a task started in the background and points to a status command for a
job id, is not a valid opposite-host panel response. Treat such a job-launch
acknowledgment as no Codex response: in default mode, record the failure class
and run the affected slot on the current host; in require-cross-host mode, block
and name the current-host three-panel fallback. Do not poll status or fetch a
deferred result from inside the panel to compensate; the consult call itself
must return the analysis.

## Lens Ownership And Fallback

When Codex is available, use the Codex consult for the `adversarial` lens unless
the caller supplied a stricter lens assignment and the synthesis records why it
changed. If Codex is unavailable from Claude Code, record
`Codex adversarial unavailable` and run the adversarial lens on the current
Claude Code host.

If the Codex consult returns only a background job-launch acknowledgment instead
of analysis, record `Codex consult returned no analysis (background job
acknowledgment only)`, treat the slot as having no opposite-host response, and
run it on the current host in default mode.
