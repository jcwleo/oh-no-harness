# Live verification of need-based dispatch and inline contract

**Status:** open. Deferred 2026-07-30 because the local inference gateway could
not route `sonnet`; the four source commits landed on `main` with offline
evidence only.

## Why this is open

Commits `4d0bf8d`, `689bc80`, `0b7a17b`, `c902b5c` changed *behavioral*
guidance: when a role subagent is dispatched versus run inline, and what an
inline mutation owes. Static gates prove the text is internally consistent and
reachable in every composed wrapper; they cannot prove a model reads it and acts
on it. That distinction matters most here, because the change removed an
absolute rule (`regardless of size or mode`) and replaced it with a judgment
call.

Offline evidence that DID pass, and what it does not cover:

| Passed | Does not cover |
|---|---|
| `validate-plugin-files.py`, both generator `--check`s | whether a model applies the need test |
| reachability 273 (codex) / 322 (claude) | whether inline edits actually stay scoped |
| `test-review-boundary-contract.py`, incl. 12 new mutation cases | whether a fired review trigger really dispatches |
| Claude + Codex offline smoke (374 assertions) | whether manifest exit promotes to `executor` |
| SessionStart worst-case cap measured in-suite at 6600 | — |

## Blocker

`sonnet` fails at the gateway; `opus` on the same config succeeds:

```
sonnet → API Error: 502 unknown provider for model claude-sonnet-5
opus   → PROBE_OK
```

The same 502 killed an `explore` subagent earlier in the session, so it is not
specific to the test harness. Note that the live run also prints
`Ignoring 45 permissions.allow entries ... workspace has not been trusted` —
that line is benign and was NOT the cause; do not chase it.

Standing user instruction is that Claude live lanes run with
`OH_NO_TEST_MODEL=sonnet` for budget control, so switching models to work around
the outage was declined.

## What to run once the gateway routes sonnet

```sh
OH_NO_TEST_MODEL=sonnet scripts/test-claude-plugin.sh \
  --isolated-config --no-install --natural-session-start-live
```

`--natural-session-start-live` is the lane that matters — plain `--live` only
proves each SKILL.md loads. Highest-value cases, all defined in
`natural_session_start_prompt_for_skill`:

- **`direct-edit eligible`** (routing off and on) — the direct check on
  `c902b5c`. Its oracle already requires exactly one parent-level mutation to
  `notes/private-notes.md`, then a *successful* `git diff` scoped to that path,
  ordered after the mutation and before the final result. That is the runtime
  form of "confirm it with a diff scoped to the intended paths."
- **`direct-edit ineligible`** (off/on) — a runtime-consumed executable must
  route to `ralph` instead of taking the inline path.
- **`ordinary implementation`** (off/on) — still reaches `ralph`.

## Not covered by any existing lane

Two rules from `c902b5c` have no automated runtime check. Consider adding lanes,
or verify them by hand:

1. **Manifest-exit promotion.** An inline edit that grows past the Mutation
   Manifest must stop and reclassify to a dispatched `executor` before editing
   further. No fixture drives an inline edit past its manifest.
2. **Contract inheritance.** Scope trace, Test Necessity rows, and worktree
   adherence are asserted for dispatched executors but not for the inline path.

## Verification tip

When checking these cores by grep, use `rg -U`. The prose wraps near column 78,
so phrases like `too small to benefit` span a line break and line-oriented
counting silently reports zero. That mistake produced three wrong findings during
this work.
