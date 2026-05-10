# Behavior evaluations

The harness has two independent gates:

1. **Structural validation** — `scripts/validate-skills`. Answers "do
   the files have the right shape, the right tokens, and the right
   metadata?".
2. **Behavior validation** — fresh-session scenarios under
   `tests/acceptance/scenarios/`. Answers "does the agent actually
   route the work the way the harness says it should?".

Structural validation runs locally and in CI. Behavior validation runs
manually against a real host (Claude Code, Codex, …) and produces a
human-readable transcript. Both are required to claim a meaningful
change to skill behavior.

## When to run a behavior eval

Run a behavior eval whenever you change anything an agent reads at
routing time:

- A canonical SKILL.md frontmatter field (`description`, `when_to_use`,
  `argument-hint`, `arguments`).
- The body of a canonical SKILL.md, especially section headings, mode
  rules, or routing language.
- `bootstrap/oh-no.md`, including the pre-work routing prompt or the
  worktree isolation protocol.
- Role prompts under `agents/` that the canonical skills delegate to.

Pure structural cleanups (typos, link rewrites, doc-only changes that
do not affect routing wording) do not need a behavior eval. When in
doubt, run one.

## Running a scenario

```text
1. Pick a scenario from tests/acceptance/scenarios/.
2. Open a fresh host session (Claude Code or Codex) so prior context
   cannot bias routing.
3. Prepare the listed Repository state. For Scenario E (dirty checkout)
   that means actually staging or leaving uncommitted changes; do not
   simulate it in prose.
4. Send the scenario's Prompt verbatim. Do not add hints.
5. Let the agent run far enough to choose a route and surface its
   reasoning. Stop before any irreversible action.
6. Copy tests/acceptance/transcripts/TEMPLATE.md into a new file named
   <scenario-id>-<host>-<YYYY-MM-DD>.md and fill in every field.
```

## Recording a transcript

The transcript is the evidence. It must:

- Quote the agent's actual route, not your interpretation.
- Trim only what is irrelevant. Mark omissions with `[...]`. Never
  re-order events.
- Mark Result as **PASS**, **FAIL**, or **PARTIAL** with one-line
  justifications under Evaluation:
  - **PASS** — the agent picked the expected route, honored every
    Pass criterion, and avoided every Forbidden shortcut.
  - **PARTIAL** — the agent reached the expected route but skipped a
    Pass criterion (e.g. went straight to the fix without naming a
    hypothesis). Quote the gap.
  - **FAIL** — the agent picked the wrong route or hit a Forbidden
    shortcut. Quote the line.

Transcripts are part of the repo's history of behavior, not part of
its policy. They live alongside scenarios but they do not change the
scenario contract. If a scenario is wrong, fix the scenario in a
separate change.

## Triaging a behavior failure

A FAIL transcript is a real bug, not a flake. Possible root causes:

- The skill body's wording lets the agent pick a shortcut that the
  scenario forbids. Fix it in the SKILL.md, not in the scenario.
- `bootstrap/oh-no.md` does not surface the routing rule clearly
  enough at session start. Tighten the bootstrap prompt.
- The host did not inject the bootstrap (Codex first-turn injection is
  not assumed). Note this in the transcript and run a second pass with
  manual bootstrap context.
- The model is regressing on a behavior that earlier model versions
  honored. Note model version in the transcript Metadata and check
  whether the new model needs sharper wording.

Do not weaken the scenario or the validator to make a transcript turn
green.

## Adding a new scenario

Add a new file under `tests/acceptance/scenarios/`. It must declare:

- `## Prompt`
- `## Repository state`
- `## Expected route`
- `## Forbidden shortcuts`
- `## Pass criteria`

`scripts/validate-skills` checks every scenario in the configured set
for those headings. When you add a new scenario, also add it to the
`acceptance_scenarios` array in `scripts/validate-skills` so it
becomes part of the structural gate.

A good scenario is:

- **Self-contained.** A reader can run it without scrolling other
  files.
- **Minimal.** It exercises one routing or evidence rule, not five.
- **Falsifiable.** "Forbidden shortcuts" lists concrete behaviors that
  could plausibly happen, not motherhood statements.

If you find yourself wanting to add a sixth scenario that overlaps an
existing one, edit the existing scenario instead.

## Behavior-eval cadence

There is no fixed cadence. Run scenarios when:

- A canonical skill or `bootstrap/oh-no.md` changes.
- A new model version is being qualified for harness use.
- A user reports a routing bug (run the matching scenario, file the
  transcript).

The harness does not currently auto-run scenarios. Treat them as a
release-and-incident tool, not as a CI gate.
