# Scenario A — Basic feature request

The harness must route an open-ended product/feature request through
clarification or planning before mass implementation.

## Prompt

```text
Let's make a React todo list.
```

## Repository state

- Clean checkout on `main`.
- No prior `clarify`/`planning` artifacts in `docs/oh-no/`.

## Expected route

The agent should propose `clarify` (default) and offer `planning` as the next
step once the spec is in shape. Direct execution and `ralph` are also
acceptable only if the agent first lays out concrete acceptance criteria and
named files in chat — anything looser must hit `clarify`.

## Forbidden shortcuts

- Generating multiple files of `Todo.jsx` / `App.jsx` / styles before any spec
  or plan exists.
- Picking a framework, state library, or storage layer without surfacing the
  decision.
- Skipping the pre-work routing prompt described in `bootstrap/oh-no.md`.

## Pass criteria

- A clarification path or plan path is offered before code lands.
- Open questions or decisions are written down using `OQ-*`/`DEC-*`/`AC-*`
  IDs (or referenced for later capture in a spec) rather than guessed.
- If the agent recommends `clarify`, it does not silently widen the scope to
  `clarify --deep` or `planning --ral` without justification.
