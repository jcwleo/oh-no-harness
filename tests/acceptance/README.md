# Acceptance checks

Run these from the repository root after changing harness files:

```sh
scripts/validate-skills
scripts/sync-codex-agents --check
python3 -m json.tool .codex-plugin/plugin.json >/dev/null
python3 -m json.tool .claude-plugin/plugin.json >/dev/null
python3 -m json.tool hooks/hooks.json >/dev/null
bash -n scripts/validate-skills
bash -n scripts/sync-codex-agents
bash -n scripts/sync-adapters
bash -n scripts/release
bash -n scripts/worktree-start
bash -n hooks/session-start
bash -n hooks/run-hook.cmd
hooks/session-start | python3 -m json.tool >/dev/null
git diff --check
```

Expected result: every command exits 0.

`validate-skills` also checks canonical skill names, skill argument hints and mappings, `$ARGUMENTS` intake guidance, required role prompts, skill integration gates for `clarify`/`planning`/`ralph`/`debug`/`verify`, pre-work routing guidance, worktree isolation protocol wiring, root-cause and completion-integrity rules, retrieval/sizing/resume rules, generated bundle shape, generated Codex custom-agent TOML templates, helper scripts, and the four artifact templates. It also enforces release-metadata integrity: root `LICENSE` (MIT) and `CHANGELOG.md` must exist, the manifest versions in `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` must match, the current manifest version must have a `## [<version>]` heading in `CHANGELOG.md`, and the marketplace `ref` plus the `README.md` install pin must equal `v<version>`.

Codex first-turn bootstrap injection is not assumed by this MVP. Codex validation checks skill registration, native custom-agent templates, and documentation fallback. Claude validation checks the SessionStart hook shape, root `agents/*.md` subagent metadata, and safe bootstrap lookup.

## Behavior scenarios

The structural checks above answer "do the files have the right shape?".
The scenarios under `scenarios/` answer the harder question: "does the
agent actually route the work the way the harness says it should?".

```text
scenarios/01-feature-request.md                 open-ended product/UX request
scenarios/02-failing-test-debug.md              bug investigation with evidence
scenarios/03-risky-architecture.md              public-API / migration risk
scenarios/04-completion-claim.md                "are we done?" without evidence
scenarios/05-dirty-checkout.md                  worktree isolation on dirty state
scenarios/06-planted-bug-sql-injection.md       code-reviewer catches SQL injection
scenarios/07-planted-bug-secret-logging.md      code-reviewer catches token logging
scenarios/08-planted-bug-swallowed-exception.md code-reviewer catches silent failure
```

Scenarios 01-05 exercise routing and evidence discipline across the
canonical workflow. Scenarios 06-08 exercise the `code-reviewer` agent's
severity taxonomy and security/data-loss/auth/secrets sweep.

Each scenario file declares a Prompt, Expected route, Forbidden shortcuts,
and Pass criteria. `scripts/validate-skills` verifies the file set and the
required headings exist. It also prevents the platform matrix from claiming
`supported` without a matching, non-template transcript for that host. The
scenarios themselves are still run by humans or by an evaluator agent — not
by the validator.

To record a run:

1. Pick a scenario and prepare the listed repository state.
2. Send the exact Prompt to the host you are evaluating (Claude Code,
   Codex, etc.) in a fresh session so prior context cannot bias routing.
3. Copy `transcripts/TEMPLATE.md` to
   `transcripts/<scenario-id>-<host>-<YYYY-MM-DD>.md` and fill it in,
   citing the agent's actual route, the evidence it produced, and any
   forbidden shortcut it took.
4. Set the transcript Result to PASS, FAIL, or PARTIAL with one-line
   justifications under Evaluation.

Transcripts are evidence, not policy. Failures should land back in the
canonical skill bodies or in `bootstrap/oh-no.md` rather than in
scenario edits, so the structural validator and behavior scenarios stay
independent.
