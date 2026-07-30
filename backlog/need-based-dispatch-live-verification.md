# Live verification of need-based dispatch and inline contract

**Status:** open. The four source commits landed on `main` with offline evidence
only. First deferred 2026-07-30 because the local gateway could not route
`sonnet`; after it recovered, two further attempts still produced no verdict on
the changed rules — see the attempt log below. The Codex lane is blocked by a
host-side cause unrelated to this change.

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

## First blocker (resolved)

`sonnet` failed at the gateway; `opus` on the same config succeeded:

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
the outage was declined. Routing recovered later the same day; the attempt log
below records what happened next.

## What to run

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

## 2026-07-30 attempt log

Two attempts ran; neither produced a verdict on the changed rules.

**Claude.** After the gateway recovered, 2 of 15 cases ran.
`vague requirements` initially failed on its own oracle, not on model behavior:
the oracle required a `Read`/`Glob`/`Grep` strictly after skill activation, which
encoded the retired dispatch-always rule. On a fixture whose whole repository is
a one-line README, reading it before selecting `interview` is exactly the
permitted inline lookup. Fixed in `ac508df` — the position requirement is gone,
the inspect-and-do-not-mutate constraints stay. The case then passed.

`autonomous end-to-end` hit the 900s `OH_NO_LIVE_TIMEOUT_SECONDS` after 78 tool
calls, so its oracle never ran and nothing below is a verdict. The partial log is
still worth recording, because the two halves point opposite ways:

- 2 correct `oh-no-harness:code-reviewer` dispatches — review independence held.
- 21 parent-level edits with 0 `Mutation fallback:` records and 0 `git diff`
  calls — the two things `c902b5c` requires of an inline edit. If the completed
  oracle reproduces this, the contract-inheritance paragraph is reaching the
  model as prose but not as behavior.

Raising the timeout for this one case is probably a prerequisite to getting any
verdict from it.

**Codex — blocked outside this change.** Case 1 (`vague requirements`) failed for
a host reason, and the Codex lane cannot verify these commits at all: it stops
before ever reaching `direct-edit eligible`.

Codex CLI 0.146.0 injects a developer message the repository does not contain:

```
<multi_agent_mode>Any earlier instruction enabling proactive multi-agent
delegation no longer applies. Do not spawn sub-agents unless the user or
applicable AGENTS.md/skill instructions explicitly ask for sub-agents,
delegation, or parallel agent work.</multi_agent_mode>
```

The observed trace matches that suppression exactly: 3 `sed` reads of
`interview/SKILL.md` (skill loading is fine), **0** `spawn_agent` calls, one
`wait` with `receiver_thread_ids=[]` and `agents_states={}`, **0** commands
reading `README.md` — and a final message quoting the README verbatim. The
content was not in the prompt (verified: 0 `README` occurrences in
`prompt-input.json`, and `codex debug prompt-input` in an empty temp project does
not inject it either). The model announced dispatching a read-only explorer,
never spawned it, waited for nothing, and hallucinated the report.

Ruled out as causes:

- **Config.** `~/.codex/config.toml` has `[features.multi_agent_v2]`
  (`tool_namespace = "agents"`) and `[agents] max_threads = 6 / max_depth = 2`,
  and `clone_codex_live_home` copies `config.toml` then verifies it by sha256
  (`test-codex-plugin.sh:309-315`), so a silent drop is impossible. The live
  prompt carried the multi-agent developer message and "7 available concurrency
  slots" (= `max_threads` + self). An earlier grep suggesting the clone lacked
  these settings was wrong: it hit leftover 2026-07-14..19 clone directories that
  cleanup had already emptied.
- **This change.** The failure is in read-only `explore` dispatch, and
  `interview.md:488` still makes `explore` the *default* dispatch — untouched by
  the four commits. That default is what collides with the host suppression.

Do **not** relax `test-codex-plugin.sh:2421-2426` the way the Claude oracle was
relaxed. Its position constraint is the same stale assumption, but Codex read the
README zero times, so dropping the constraint would not make the case pass — and
must not, since passing would mean accepting a hallucinated repository report.

Related but distinct: `codex-subagent-protocol-compatibility.md` covers
`agent_type` schema compatibility. Host-side `<multi_agent_mode>` suppression of
proactive delegation is a new observation and needs its own decision — most
likely whether `interview`'s dispatch-by-default survives on Codex.

## Verification tip

When checking these cores by grep, use `rg -U`. The prose wraps near column 78,
so phrases like `too small to benefit` span a line break and line-oriented
counting silently reports zero. That mistake produced three wrong findings during
this work.
