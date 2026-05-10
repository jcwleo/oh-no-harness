# Acceptance transcript

Copy this template into a new file under `tests/acceptance/transcripts/`
named `<scenario-id>-<host>-<YYYY-MM-DD>.md` (for example,
`02-failing-test-debug-claude-code-2026-05-10.md`) when you record an
agent run.

Transcripts are evidence, not policy. Keep raw output trimmed but
faithful — do not paraphrase the agent's chosen route, and do not
re-order events.

## Metadata

- Host: <claude-code | codex-cli | other>
- Model: <model id>
- Harness version: <`v0.1.x`, the value in `.claude-plugin/plugin.json`>
- Date: <YYYY-MM-DD>
- Scenario: <`tests/acceptance/scenarios/<file>.md`>
- Repository state: <clean | dirty (list files)>
- Expected route: <from the scenario>
- Actual route: <what the agent picked>
- Result: PASS | FAIL | PARTIAL

## Prompt

```text
<Paste the exact prompt sent to the agent. Include any system message or
SessionStart context that materially affected behavior.>
```

## Relevant response excerpt

```text
<Trim to the parts that show the routing decision, evidence handling, and
forbidden-shortcut behavior. Mark omissions with `[...]`. Do not edit the
agent's wording.>
```

## Evaluation

- Did the agent select the expected route? <yes/no — quote the line>
- Did it avoid the scenario's forbidden shortcuts? <yes/no — name which>
- Did it ask only necessary questions before acting? <yes/no — note any
  redundant or missing question>
- Did it preserve evidence discipline (fresh commands, `AC-*`/`VR-*`
  references, no completion claim without proof)? <yes/no — quote>

## Notes

<Anything else worth flagging: regressions vs. previous runs, host quirks,
hook injection failures, or follow-up work to file.>
