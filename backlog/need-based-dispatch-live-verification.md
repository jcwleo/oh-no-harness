# Live verification of need-based dispatch and inline contract

**Status:** open. The four source commits landed on `main` with offline evidence
only. First deferred 2026-07-30 because the local gateway could not route
`sonnet`; after it recovered, further attempts still produced no verdict on the
changed rules — see the attempt log below. Two blocking test defects have since
been fixed (`ac508df` Claude, `467ca98` Codex), so the next run should get
further; `autonomous end-to-end` still needs a raised timeout.

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

OH_NO_MARKETPLACE_NAME=oh-no-harness scripts/test-codex-plugin.sh \
  --codex-home "$(mktemp -d)" --natural-session-start-live </dev/null
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

**Codex — was a test defect, fixed in `467ca98`.** Case 1
(`vague requirements`) failed, but neither the harness nor the model was at
fault. A live probe reproduced the run and showed Codex behaved correctly:

- it spawned a child with `agent_role: oh-no-explore`,
  `task_name: interview_explore_discovery_1`, `fork_turns: none` (recorded in
  plaintext in the parent rollout, `agent_path /root/interview_explore_discovery_1`)
- the child ran `nl -ba README.md` and `pwd; rg --files ...; git status`
- it reported the contents accurately

Three oracle defects stacked, and measurement showed all three had to be fixed
together — `nl` alone still failed, inner-`cmd` extraction alone still failed,
both together passed:

1. `command_text_from_event` only handled `function_call`/`exec_command`, while a
   child records shell work as `custom_tool_call` named `exec` whose `input` is a
   JS snippet wrapping `tools.exec_command({"cmd": ...})` — **0 of 2** real child
   commands parsed.
2. The child-transcript walk kept only `wrapper_reads` hits and discarded every
   other child command.
3. `read_tool_pattern` lacked `nl`, and its anchor cannot match inside the JS
   wrapper, so even `cat` failed without first recovering the embedded `cmd`.

`run_no_skill_readonly_session_start_live_test` had the same blindness and did not
even receive `live_home`, so it could not see child transcripts at all.

### Corrections to the previous entry

Two claims committed in `7036109` were wrong and are retracted:

- **"Hallucinated the report" — false.** The child genuinely read the file. The
  parent's `wait` showing `receiver_thread_ids=[]` / `agents_states={}` is normal:
  codex-cli ≥ 0.144 stops emitting child activity in the `exec --json` stream, a
  fact the harness already documents at `test-codex-plugin.sh:4440-4442`. Child
  work lives in a separate rollout file linked by `parent_thread_id`.
- **"`<multi_agent_mode>` suppression caused it" — false.** The block is real and
  host-injected, but our authorization wins: the parent rollout shows the
  suppression at line 4 and
  `CODEX_ONLY_OH_NO_SUBAGENT_STANDING_AUTHORIZATION` ("use sub-agents, delegation,
  and parallel agent work proactively. This is the explicit user request") at
  line 8, and the spawn succeeded. The earlier evidence for its absence —
  0 hook blocks in `prompt-input.json` — was a tool artifact:
  `codex debug prompt-input` does not fire the SessionStart hook (verified in an
  empty temp project: `OH_NO_BOOTSTRAP` 0, `multi_agent_mode` 1).

The config ruling-out still stands: `[features.multi_agent_v2]` and
`[agents] max_threads = 6 / max_depth = 2` are present, and
`clone_codex_live_home` verifies `config.toml` by sha256
(`test-codex-plugin.sh:309-315`). An earlier grep suggesting the clone lacked them
hit leftover 2026-07-14..19 clone directories that cleanup had already emptied.

### Remaining oracle-strictness gap (not fixed, needs its own scope)

`467ca98` deliberately covered only the two blocked lanes. The same parent-only
blindness remains in every other positive-evidence oracle, and an audit of
`assert_codex_natural_activation_smoke` found:

- `explicit test-first`, `known-cause fix`, `unknown-cause failure` — the test
  runs and production mutations they require are legitimately child-side work
  (`executor`, `verifier`, `debugger`), so a dispatching run fails.
- `plan-only/pending approval` — plan artifacts under `.oh-no/plans` are
  legitimately written by a dispatched `planner`. Its `production` containment
  check is the inverse risk: a child mutating production before approval is
  invisible and passes silently.
- `autonomous end-to-end`, `ordinary implementation` — no dedicated branch at all,
  so the labels with the *most* child usage assert the least.

Do not fix these by widening them the way the two lanes were widened. Two reasons:

1. **Mechanical.** All three ordering checks compare event indices, and the parent
   `exec --json` stream carries **no timestamp** (keys are `item`, `thread_id`,
   `type`, `usage`). Only the rollout files have timestamps, so a unified sequence
   means replacing the evidence source, which destabilizes checks that pass today.
2. **Design.** These oracles assert tool-use minutiae, not design compliance:
   `explicit test-first` demands exactly `tests/timeout_test.sh` in a given order
   with a given exit code. An LLM satisfies the same design many ways, so this is
   over-strict. The right follow-up is relaxing them toward the design property
   ("a failing focused test preceded the production change"), regardless of who ran
   it, since `natural_payload_changes` and
   `natural_source_checkout_fingerprint` already verify final on-disk state
   independently of the stream.

Related but distinct: `codex-subagent-protocol-compatibility.md` covers
`agent_type` schema compatibility.

## Verification tip

**`codex exec` needs stdin closed.** Run it with `</dev/null`. Without that, a
backgrounded invocation hangs at `Reading additional input from stdin...`
indefinitely (19 minutes observed, 0 bytes of output). The failed live run's
`.err` contains that same line.

**Child activity is not in the `exec --json` stream.** codex-cli ≥ 0.144 records
child subagent work only in a separate `sessions/**/rollout-*.jsonl` linked by
`parent_thread_id`; the parent stream shows an empty `wait`. Reading the parent
alone makes a correct dispatch look like it never happened.

When checking these cores by grep, use `rg -U`. The prose wraps near column 78,
so phrases like `too small to benefit` span a line break and line-oriented
counting silently reports zero. That mistake produced three wrong findings during
this work.
