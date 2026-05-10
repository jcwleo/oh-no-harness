# Visual clarification

This is an optional guide. The harness does not require visual
artifacts and never adds runtime daemons, servers, image stores, or
asset pipelines for them. When a UI / UX / diagram task genuinely
benefits from a sketch, this doc describes how to capture and record
that decision without growing the harness.

## When text is enough

Default to text. Most clarification work fits in `clarify` (default
mode) or `clarify --deep` with words alone:

- Behavior changes, API contracts, error handling, ordering rules.
- Naming, scope boundaries, decision drivers.
- Test shape, regression proof contracts.

If the user can pick between two options after reading a paragraph,
do not add a sketch.

## When a visual reference is worth the cost

Reach for a visual when *describing the artifact in words takes
longer than drawing it*, and when the decision actually depends on
spatial / sequential / state-machine relationships:

- Layout choices (where elements sit relative to each other).
- State machines and transitions with three or more states.
- Interaction sequences across more than two surfaces.
- Diagrams the spec must point at for an AC to be unambiguous.

If a visual aids the discussion but does not anchor an AC, treat it
as conversation and do not commit it.

## How to capture a visual

Use the lightest medium that survives a future read:

1. **ASCII / Markdown table mockup** inside the spec or plan
   artifact. Survives `git diff`, no asset pipeline.
2. **Mermaid block** inside the spec, when the host renders Mermaid
   in PR review. Still text in the repo.
3. **Linked external mockup** (Figma, Excalidraw, etc.) when only a
   real image will do. Record the link plus a one-paragraph text
   summary inside the spec so the spec is still readable when the
   external link rots. Do not download or vendor the image into the
   repo unless the team has already agreed to host visual assets.

The harness does not prescribe one tool. It requires that the
*decision* the visual captures lives as text in the spec / plan, so
artifact traceability is preserved when the visual is unavailable.

## Recording the decision

Visual choices that affect scope or behavior must land as an `AC-*`
or `DEC-*` in the spec, not as a screenshot caption:

- `AC-NNN: The dashboard sidebar collapses when the viewport is
  narrower than 768px (sketch in spec, link in DEC-002).`
- `DEC-NNN: We prefer a single-column layout on mobile because of
  pointer-target sizing (mockup attached, see [link]).`

A visual that is referenced but never tied to an AC / DEC is
conversation and should not be committed.

## What stays out

The harness avoids:

- Image servers, browser-canvas dependencies, runtime renderers.
- Vendored binary assets the agent must read.
- Diagram-as-a-service plug-ins that require credentials.
- Mockup-approval state machines that hold up clarify or planning.

If a host adds visual clarification primitives natively (for example,
inline image rendering in a chat surface), use them through the host;
do not bring them into the harness.

## Cross-references

- `skills/clarify/SKILL.md` — where visual clarification fits
  (default mode for design-shaped requests, `--deep` for high-risk
  ambiguity).
- `skills/planning/SKILL.md` — when a sketch belongs in the plan's
  file/module map.
- `docs/oh-no-harness-design.md` — the no-runtime / no-hidden-state
  invariants this guide must respect.
