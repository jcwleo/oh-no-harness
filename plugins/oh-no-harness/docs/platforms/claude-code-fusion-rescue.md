# Claude Code Fusion Rescue Rules

This platform overlay is source content for the generated Claude Code-facing
`fusion-rescue` runtime document, after the shared core and
`docs/platforms/claude-code-runtime.md`.

## Model Diversity Panels

Dispatch exactly three same-role `fusion-rescue-analyst` panels in parallel
with the core's identical packet shape and distinct assigned lenses, then
synthesize all three outputs. Resolve panel models only from the session
`<OH_NO_MODEL_DIVERSITY>` block.

All three panel identities MUST be members of the block's resolved top-tier
list. A panel identity is transcript-provable only through either an explicit
NATIVE model override or, for an unoverridden panel, the declared-frontmatter
primary applied from the block's concrete stored `fusion-rescue-analyst`
primary. Never infer identity from an unknown host default.

The named `panel-default` is the declared stored `fusion-rescue-analyst`
primary when that concrete primary is a member of the top-tier list; otherwise
it is the first NATIVE entry of the top-tier list. Use the unoverridden role
only when `panel-default` is the declared-frontmatter primary. Any other
`panel-default` assignment requires an explicit NATIVE override.

Configured case — when the block contains a validated secondary top-tier model:

- assign exactly two panels the explicit NATIVE secondary override
- assign exactly one panel a distinct top-tier identity: use `panel-default`
  when it differs from the secondary; otherwise use the first NATIVE top-tier
  entry that differs from the secondary
- the distinct panel is unoverridden only when its identity is the declared-
  frontmatter primary; otherwise it carries the explicit NATIVE override

Degenerate configured case — when no dispatchable top-tier identity differs
from the secondary, the 2+1 composition is unavailable. Default mode runs all
three panels as `3 × panel-default (top-tier)` and records the degenerate
reason; this is `same-model-parallel-fallback`. `require-model-diversity`
transitions to PAUSED instead.

Unconfigured case — when the block has no validated secondary, including the
no-preferences case, run all three panels as
`3 × panel-default (top-tier)`. Use an explicit NATIVE panel-default override
or the declared-frontmatter primary for every panel as defined above, and
record `same-model-parallel-fallback`. `require-model-diversity` transitions
to PAUSED instead.

## No Opposite-Host Consult

Claude Code defines no opposite-host consult path for Fusion Rescue. Do not
attempt one. Model diversity and the documented same-model panel fallback are
the only panel-composition mechanisms on this host.
