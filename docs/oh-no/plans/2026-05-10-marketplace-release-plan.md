# Plan: Publish oh-no-harness v0.1.0 marketplace release

- Date: 2026-05-10
- Slug: marketplace-release
- Source spec: docs/oh-no/specs/2026-05-10-marketplace-release-spec.md
- Mode: basic
- Size: artifact-plan
- Status: draft

## Retrieval basis

- Explicit inputs checked:
  - `docs/oh-no/specs/2026-05-10-marketplace-release-spec.md` (this plan's source of truth: AC-001..AC-010, INV-001..INV-005, DEC-001..DEC-007, OQ-001..OQ-002).
  - `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json` (current `version: 0.0.1`).
  - `/tmp/oh-no-v001-marketplace/.claude-plugin/marketplace.json` (proven marketplace.json shape).
  - `git remote -v`, `git tag --list`, `git ls-remote --heads --tags origin` (origin URL, existing v0.0.1 tag at `e70ff29`, branch state of `docs/github-flow-guidelines` vs `main`).
  - `~/.claude/plugins/known_marketplaces.json` (how Claude Code records marketplace installs).
  - `README.md` §Validate (validation commands), `AGENTS.md` §Commit & Pull Request Guidelines (GitHub Flow contract).
- Searches run: none beyond the spec's retrieval basis; spec already enumerated the relevant evidence.
- Evidence gaps:
  - OQ-001: GitHub repo public visibility — unverified, blocks AC-010. T-001 closes this.
  - OQ-002: Whether `source: github` shorthand is accepted by the installed Claude Code marketplace loader — unverified. T-001 closes this; default fallback is the proven `url` form.

## Requirements summary

Ship `oh-no-harness` v0.1.0 as an installable plugin via a self-hosted `.claude-plugin/marketplace.json` in this same repo, behind GitHub Flow + an annotated `v0.1.0` tag, while leaving the existing `v0.0.1` tag and all skill/agent/hook/template content untouched.

- Adds: `.claude-plugin/marketplace.json` (AC-001, AC-002, AC-003).
- Bumps: `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` to `0.1.0` together (AC-004, AC-005, INV-004).
- Validates: `python3 -m json.tool` on three JSON files (AC-006), `scripts/validate-skills` (AC-007), `git diff --check` (AC-008).
- Releases via GitHub Flow (INV-003) with `v0.1.0` tag from merged `main` (AC-009, INV-005).
- Preserves: `v0.0.1` tag (INV-001) and all source under `skills/`, `agents/`, `.codex/agents/`, `bootstrap/`, `hooks/`, `templates/`, `tests/` (INV-002).
- End-to-end install proof from a fresh Claude Code session (AC-010).

## Sizing decision

- Why this is not overplanned: All seven tasks correspond to a discrete spec ID or a hard prerequisite (OQ resolution, prerequisite PR merge, version bumps, marketplace.json, validation, release PR + tag, install verification). No `--ral` because there are no architectural tradeoffs, no skill/agent/hook surface changes, and the design pattern is already prototyped under `/tmp/oh-no-v001-marketplace`.
- Why this is not underplanned: Each task owns its files, links to AC/INV IDs, and has a concrete verification command. The ordering is load-bearing — version bumps must precede the marketplace.json that references the new tag, and the tag must exist on `origin` before AC-010 can be tested.
- If more than 7 tasks, milestone split: not needed (exactly 7 tasks). T-001 → T-002 form a "pre-release prep" phase; T-003 → T-006 form a "release branch" phase; T-007 is the post-tag verification.

## File and module map

- `.claude-plugin/marketplace.json` — added (T-004).
- `.claude-plugin/plugin.json` — `version` field only (T-003).
- `.codex-plugin/plugin.json` — `version` field only (T-003).
- `docs/oh-no/runs/2026-05-10-marketplace-release-progress.md` — created/updated by `ralph` execution (out-of-scope for this plan but tracked).
- All other paths (`skills/`, `agents/`, `.codex/agents/`, `bootstrap/`, `hooks/`, `templates/`, `tests/`, `README.md`, `AGENTS.md`, `docs/oh-no-harness-design.md`) — must NOT change (INV-002).

## Task list

### T-001: Resolve open questions (repo visibility + marketplace source shape)

- Linked IDs: OQ-001, OQ-002, AC-010, INV-005
- Owned files/modules: none (read-only investigation; no source mutation)
- Objective: Close OQ-001 by verifying `jcwleo/oh-no-harness` is publicly readable so AC-010 can pass without auth. Close OQ-002 by deciding whether to use `source: "github"` shorthand or the proven `source: "url" + url + ref` form for the plugin entry.
- Implementation notes:
  - OQ-001: run `gh repo view jcwleo/oh-no-harness --json visibility,url` (preferred) or `git ls-remote https://github.com/jcwleo/oh-no-harness.git` from a session without GitHub credentials.
  - OQ-002: inspect `/tmp/oh-no-v001-marketplace/.claude-plugin/marketplace.json` (already known: uses `{"source":"url","url":"...","ref":"v0.0.1"}`), and skim Claude Code's installed marketplace examples under `~/.claude/plugins/marketplaces/*/.claude-plugin/marketplace.json` to confirm what shapes are in production use. Default decision: stick with the proven `url` form (DEC-005), only switching to `github` shorthand if the user explicitly prefers it.
- TDD or verification-first step: alternate verification — record the visibility result and the chosen `source` shape in the progress log (`docs/oh-no/runs/2026-05-10-marketplace-release-progress.md`) before any file is edited.
- Commands/checks:
  - `gh repo view jcwleo/oh-no-harness --json visibility,url`
  - `git ls-remote https://github.com/jcwleo/oh-no-harness.git HEAD`
  - `cat /tmp/oh-no-v001-marketplace/.claude-plugin/marketplace.json`
  - `ls ~/.claude/plugins/marketplaces/*/.claude-plugin/marketplace.json`
- Dependencies: none.
- Stop condition: if OQ-001 reveals the repo is private, halt the plan and surface the blocker — `make repo public` is a user-owned decision and not part of this scope.

### T-002: Track `docs/github-flow-guidelines` as an independent parallel PR (no longer a prerequisite)

- Linked IDs: DEC-007 (revised), INV-003
- Owned files/modules: none in this worktree.
- Objective: Per the revised DEC-007, the `docs/github-flow-guidelines` branch is handled in a separate session/worktree by the user. This task only coordinates: T-007 (tag) is the point at which we want both PRs visible on `main`.
- Implementation notes:
  - No work happens in this worktree for T-002. The user owns the docs PR lifecycle.
  - Before T-007 tags `v0.1.0`, run `git fetch origin && git log origin/main --oneline -10` (or `gh pr list --search "head:docs/github-flow-guidelines"`) to check whether the docs PR is merged. If yes, the v0.1.0 tag will include both. If not, the v0.1.0 tag proceeds anyway — the two PRs are independent.
- TDD or verification-first step: not applicable (no code/files change here).
- Commands/checks:
  - `git fetch origin && git log origin/main --oneline -10`
  - Optional: `gh pr list --search "head:docs/github-flow-guidelines" --json state,title,mergedAt`
- Dependencies: none. (Removed dependency on T-001 — T-002 no longer affects the work order.)

### T-003: Create release branch and bump versions to 0.1.0

- Linked IDs: AC-004, AC-005, INV-004, INV-002
- Owned files/modules: `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`. Branch: `release/v0.1.0` (or similar short-lived name) cut from updated `main`.
- Objective: On a fresh release branch off updated `main`, change the `version` string in both plugin.json files from `"0.0.1"` to `"0.1.0"`. Touch nothing else.
- Implementation notes:
  - `git checkout -b release/v0.1.0 main`
  - Edit `.claude-plugin/plugin.json`: `"version": "0.0.1"` → `"version": "0.1.0"`. Preserve trailing newline and indentation.
  - Edit `.codex-plugin/plugin.json`: same change.
  - Do not reorder keys, do not reformat unrelated fields.
- TDD or verification-first step: alternate verification — inline check immediately after edits:
  - `python3 -c "import json; assert json.load(open('.claude-plugin/plugin.json'))['version']=='0.1.0' and json.load(open('.codex-plugin/plugin.json'))['version']=='0.1.0'"` exits 0.
  - `git diff --stat` shows exactly two files touched.
- Commands/checks:
  - `git status` (clean before branch cut)
  - `python3 -m json.tool .claude-plugin/plugin.json >/dev/null && python3 -m json.tool .codex-plugin/plugin.json >/dev/null`
  - The Python `assert` one-liner above.
  - `git diff --stat` (two files, version-line only).
- Dependencies: T-001. (No longer depends on T-002 per revised DEC-007.)

### T-004: Add `.claude-plugin/marketplace.json`

- Linked IDs: AC-001, AC-002, AC-003, DEC-001, DEC-002, DEC-005
- Owned files/modules: `.claude-plugin/marketplace.json` (new).
- Objective: Create the marketplace manifest declaring exactly one plugin (`oh-no-harness`) pinned to git ref `v0.1.0`, using the `source` shape resolved in T-001 (default: the proven `url` form).
- Implementation notes:
  - Use the working `/tmp/oh-no-v001-marketplace/.claude-plugin/marketplace.json` as the structural template.
  - Required fields:
    - `name`: `"oh-no-harness"` (DEC-002, NOT `oh-no-v001`).
    - `description`: a short string describing the marketplace contents.
    - `owner.name`: `"jcwleo"`.
    - `plugins`: length-1 array.
    - `plugins[0].name`: `"oh-no-harness"`.
    - `plugins[0].description`: short plugin description (can mirror or reuse `.claude-plugin/plugin.json` description).
    - `plugins[0].source`: the form chosen in T-001. Default:
      ```json
      { "source": "url", "url": "https://github.com/jcwleo/oh-no-harness.git", "ref": "v0.1.0" }
      ```
  - Trailing newline, two-space indent (match the existing `plugin.json` style).
- TDD or verification-first step: alternate verification — immediately after writing the file:
  - `python3 -m json.tool .claude-plugin/marketplace.json >/dev/null` (AC-001).
  - `python3 -c "import json; m=json.load(open('.claude-plugin/marketplace.json')); assert m['name']=='oh-no-harness' and m['owner']['name']=='jcwleo' and m['description'] and len(m['plugins'])==1; p=m['plugins'][0]; assert p['name']=='oh-no-harness' and p['description'] and p['source']['ref']=='v0.1.0'"` (AC-002 + AC-003).
- Commands/checks: as above plus `git diff --stat` showing this is the only new file in the change set.
- Dependencies: T-003 (so the marketplace.json's `ref: v0.1.0` and the plugin.json `version: 0.1.0` ship in the same commit/PR — they are mutually load-bearing for INV-005).

### T-005: Run all local validation gates

- Linked IDs: AC-006, AC-007, AC-008, INV-002
- Owned files/modules: none (read-only verification).
- Objective: Confirm that the release branch tip passes every local gate listed in `README.md` §Validate plus the spec's verification matrix entries that don't require the tag to exist yet.
- Implementation notes:
  - JSON validity for all three files (AC-006).
  - `scripts/validate-skills` exits 0 (AC-007). If it fails on the new marketplace.json, inspect the script — but **do not** modify the script; instead surface the failure as a blocker because INV-002 forbids touching `scripts/`.
  - `git diff --check` exits 0 (AC-008).
  - Confirm INV-002 by running `git diff main...HEAD -- skills agents .codex/agents bootstrap hooks templates tests` and asserting empty output.
- TDD or verification-first step: alternate verification — exit-code-driven; capture each command's output in the progress log.
- Commands/checks:
  - `for f in .claude-plugin/marketplace.json .claude-plugin/plugin.json .codex-plugin/plugin.json; do python3 -m json.tool "$f" >/dev/null; done`
  - `scripts/validate-skills`
  - `git diff --check`
  - `git diff main...HEAD -- skills agents .codex/agents bootstrap hooks templates tests`
- Dependencies: T-003, T-004.

### T-006: Open release PR, review/merge into `main`

- Linked IDs: AC-009 (partial — pre-tag half), INV-003
- Owned files/modules: branch `release/v0.1.0` (or chosen name); no source edits.
- Objective: Land the release branch into `main` via PR per GitHub Flow. Do NOT tag yet — tagging happens from the merged `main` commit in T-007.
- Implementation notes:
  - `git push -u origin release/v0.1.0`.
  - `gh pr create --base main --head release/v0.1.0 --title "Release v0.1.0: self-hosted marketplace" --body "<body referencing this spec/plan; lists changed files; lists validation evidence>"`.
  - PR body must explicitly call out: (a) version bumped to 0.1.0 in both plugin.json files; (b) new `.claude-plugin/marketplace.json` added; (c) no skill/agent/hook/template/script changes (INV-002); (d) v0.0.1 tag is left untouched (INV-001).
  - After approval, `gh pr merge <PR#> --squash --delete-branch` (consistent with T-002).
  - `git checkout main && git pull --ff-only origin main`.
- TDD or verification-first step: alternate verification — `git log main --oneline -5` shows the squash-merge commit; `git show main -- .claude-plugin/marketplace.json .claude-plugin/plugin.json .codex-plugin/plugin.json` shows the v0.1.0 content.
- Commands/checks:
  - `git push -u origin release/v0.1.0`
  - `gh pr create ...`
  - `gh pr merge <PR#> --squash --delete-branch`
  - `git checkout main && git pull --ff-only origin main`
  - `git log main --first-parent --oneline -10` (sanity: only PR-merge commits, INV-003).
- Dependencies: T-005.

### T-007: Tag `v0.1.0` from `main`, push, and run end-to-end install verification

- Linked IDs: AC-009 (tag half), AC-010, INV-001, INV-005
- Owned files/modules: git refs only.
- Objective: Create the annotated `v0.1.0` tag from the merged `main` tip and push it; then verify end-to-end install in a fresh Claude Code session.
- Implementation notes:
  - Sanity-check INV-001 first: `git rev-parse v0.0.1` must still equal `e70ff29...` exactly. If not, halt and investigate.
  - `git tag -a v0.1.0 -m "v0.1.0: self-hosted marketplace release"` from current `main`.
  - `git push origin v0.1.0`.
  - Confirm `git ls-remote --tags origin v0.1.0` resolves to the same SHA as local `main`.
  - End-to-end install (AC-010):
    - In a fresh Claude Code session: `/plugin marketplace add jcwleo/oh-no-harness`.
    - Then: `/plugin install oh-no-harness@oh-no-harness`.
    - Inspect `~/.claude/plugins/known_marketplaces.json` for a new entry with `source.source == "github"` (or equivalent) and `source.repo == "jcwleo/oh-no-harness"`.
    - Inspect installed-plugin records (`~/.claude/plugins/installed_plugins.json` or equivalent) for `oh-no-harness@v0.1.0`.
- TDD or verification-first step: alternate verification — install transcript + the two JSON state files captured in the progress log.
- Commands/checks:
  - `git rev-parse v0.0.1` (must equal `e70ff29...` — INV-001 guard).
  - `git tag -a v0.1.0 -m "..."`
  - `git push origin v0.1.0`
  - `git ls-remote --tags origin v0.1.0`
  - `/plugin marketplace add jcwleo/oh-no-harness` (in fresh session)
  - `/plugin install oh-no-harness@oh-no-harness` (in fresh session)
  - `python3 -m json.tool ~/.claude/plugins/known_marketplaces.json | head -40`
- Dependencies: T-006.

## Risks and mitigations

- Risk: `jcwleo/oh-no-harness` repo turns out to be private (OQ-001). Mitigation: T-001 verifies first; if private, halt with a clear blocker — making the repo public is a user-owned decision, not part of this scope.
- Risk: Claude Code's marketplace loader rejects the `source` shape from `/tmp/oh-no-v001-marketplace`. Mitigation: T-001 also surveys other installed marketplaces under `~/.claude/plugins/marketplaces/` and adapts. If both shapes fail, surface as a blocker; do not paper over with workaround.
- Risk: `scripts/validate-skills` fails on the new marketplace.json because it has no awareness of the file. Mitigation: per INV-002, do not edit the script in this release. If the script fails, file the gap as a follow-up and decide with the user whether to (a) accept a documented exception, or (b) widen scope to update the script in a separate small PR.
- Risk: `gh pr merge --squash --delete-branch` rebases away the original tag-target SHAs, but the v0.0.1 tag is annotated and pinned to a fixed commit, so it cannot be moved by squash. INV-001 stays safe.
- Risk: The release tag is pushed before the marketplace.json's referenced ref exists at the moment of marketplace add. Mitigation: tag-then-verify ordering in T-007 — push `v0.1.0` to origin and confirm with `git ls-remote --tags` BEFORE running `/plugin marketplace add ...`.
- Risk: A user (including the operator) installs from the marketplace mid-release while `v0.1.0` is partially landed. Mitigation: marketplace.json is only added in the release PR itself; until that PR is merged into `main`, no consumer of the public repo can resolve it.
- Risk: Schema drift between `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` versions (INV-004). Mitigation: T-003 bumps both atomically in one commit and T-005's verification matrix includes the cross-file `assert a == b == "0.1.0"` check.

## Root-cause plan, if applicable

Not applicable — this is a release/distribution change, not a bug investigation.

## RALPLAN-DR, if `--ral`

Not applicable — basic mode. No security/auth, migrations, public API breakage, architectural boundary moves, or data-loss risk. The design pattern (self-hosted marketplace.json pointing at a tagged ref) is already prototyped under `/tmp/oh-no-v001-marketplace`.

## Handoff

- Hand off to `ralph` with:
  - Spec path: `docs/oh-no/specs/2026-05-10-marketplace-release-spec.md`
  - Plan path: `docs/oh-no/plans/2026-05-10-marketplace-release-plan.md`
  - Progress log: `docs/oh-no/runs/2026-05-10-marketplace-release-progress.md` (to be created on first ralph turn)
  - Verify report (later): `docs/oh-no/reports/2026-05-10-marketplace-release-verify.md`
  - Remaining open questions: OQ-001 (repo visibility), OQ-002 (source shape) — both closed by T-001 before any source change.
  - Hard guards: INV-001 (do not move `v0.0.1` tag), INV-002 (do not modify skills/agents/hooks/templates/scripts/tests), INV-003 (no direct push to `main`).
  - Verification commands: see each task's "Commands/checks" plus the spec's Verification Matrix.
  - Stop conditions: any failure of `scripts/validate-skills`, `git diff --check`, JSON parse, or the `v0.0.1` SHA guard in T-007 halts execution and is surfaced as a blocker rather than worked around.
