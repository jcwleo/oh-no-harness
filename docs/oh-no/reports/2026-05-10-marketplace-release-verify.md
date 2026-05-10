# Verify Report: Publish oh-no-harness v0.1.0 marketplace release

- Date: 2026-05-10
- Slug: marketplace-release
- Spec: docs/oh-no/specs/2026-05-10-marketplace-release-spec.md
- Plan: docs/oh-no/plans/2026-05-10-marketplace-release-plan.md
- Progress: docs/oh-no/runs/2026-05-10-marketplace-release-progress.md
- Verification checkout/worktree: `/Users/chanwoong.joo/Projects/oh-no-harness/.claude/worktrees/release+v0.1.0` on branch `worktree-release+v0.1.0` (pushed to origin as `release/v0.1.0`, merged into `main` as commit `958e0dc`); origin tag `v0.1.0` resolves to deref commit `958e0dc`
- Final status: VERIFIED

## Claims checked

| VR ID | Linked ID | Claim | Evidence | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| VR-001 | AC-001 | `.claude-plugin/marketplace.json` exists at repo root and parses as valid JSON | `python3 -m json.tool .claude-plugin/marketplace.json` → exit 0; `claude plugin validate .claude-plugin/marketplace.json` → `Validation passed` | VERIFIED | Both syntactic (json.tool) and semantic (claude plugin validate) checks pass |
| VR-002 | AC-002 | marketplace.json declares `name=oh-no-harness`, non-empty `description`, `owner.name=jcwleo`, length-1 `plugins` | Inline Python assert with these exact constraints → exit 0 | VERIFIED | |
| VR-003 | AC-003 | Single plugin entry has `name=oh-no-harness`, non-empty `description`, `source.ref=v0.1.0`, `source.source=url`, `source.url=https://github.com/jcwleo/oh-no-harness.git` | Same Python assert + manual file inspection | VERIFIED | DEC-005 honored; chose proven `url` form over `git-subdir`/relative-path alternatives (DEC-OQ-002 in progress log) |
| VR-004 | AC-004 | `.claude-plugin/plugin.json` has `version: 0.1.0` | `python3 -c "import json; assert json.load(open('.claude-plugin/plugin.json'))['version']=='0.1.0'"` → exit 0 | VERIFIED | |
| VR-005 | AC-005 | `.codex-plugin/plugin.json` has `version: 0.1.0` | Same check on `.codex-plugin/plugin.json` → exit 0 | VERIFIED | |
| VR-006 | AC-006 | All three JSON files round-trip cleanly through `python3 -m json.tool` | Loop over the three files → all exit 0 | VERIFIED | |
| VR-007 | AC-007 | `scripts/validate-skills` exits 0 on release branch tip | `scripts/validate-skills` → `validate-skills: OK` | VERIFIED | Same pass at baseline (worktree creation) and after T-005 |
| VR-008 | AC-008 | `git diff --check` reports nothing on release branch tip | `git diff --check` → no output, exit 0 | VERIFIED | |
| VR-009 | AC-009 | Release branch is merged into `main` and `v0.1.0` annotated tag is created from the merged commit and pushed to `origin`, with the tagged tree containing v0.1.0 plugin.json values + new marketplace.json | `gh pr view 2` → `state: MERGED, mergeCommit: 958e0dc...`; `git tag -a v0.1.0 958e0dc...`; `git push origin v0.1.0`; `git ls-remote --tags origin v0.1.0` → `3ea2662c... refs/tags/v0.1.0`; `git rev-parse 'v0.1.0^{}'` → `958e0dc...`; `git show origin/main:.claude-plugin/marketplace.json` confirms ref=v0.1.0; `git show origin/main:.claude-plugin/plugin.json` confirms version=0.1.0; same for `.codex-plugin/plugin.json` | VERIFIED | |
| VR-010 | AC-010 | Fresh-session install path works end-to-end | `claude plugin marketplace add jcwleo/oh-no-harness` → `Successfully added marketplace: oh-no-harness (declared in user settings)`; `claude plugin install oh-no-harness@oh-no-harness` → `Successfully installed plugin: oh-no-harness@oh-no-harness (scope: user)`; `~/.claude/plugins/known_marketplaces.json` shows `oh-no-harness` with `source: github / repo: jcwleo/oh-no-harness`; `~/.claude/plugins/installed_plugins.json` shows `oh-no-harness@oh-no-harness` v0.1.0 user-scope at gitCommitSha `958e0dcf...` (matches v0.1.0 deref commit) | VERIFIED | Verified via the `claude plugin` CLI subcommands (the headless equivalents of the in-session `/plugin marketplace add` and `/plugin install` slash commands). The CLI exercises the same install path. |
| VR-011 | INV-001 | `v0.0.1` tag still points to commit `e70ff29...` after release work | `git rev-parse 'v0.0.1^{}'` → `e70ff29f132bc0990b06bed39f0e3a8ad0a36adb`; `git ls-remote --tags origin v0.0.1` → `e4ff5039... refs/tags/v0.0.1` (annotated tag SHA unchanged from clarify-time snapshot); `installed_plugins.json` still shows `oh-no-harness@oh-no-v001` v0.0.1 with `gitCommitSha: e70ff29...` | VERIFIED | Tag was never moved; new v0.1.0 install coexists at a different scope rather than clobbering |
| VR-012 | INV-002 | No file under `skills/`, `agents/`, `.codex/agents/`, `bootstrap/`, `hooks/`, `templates/`, `tests/`, `scripts/`, `README.md`, `AGENTS.md`, or `docs/oh-no-harness-design.md` is modified | `git diff main...HEAD -- skills agents .codex/agents bootstrap hooks templates tests scripts README.md AGENTS.md docs/oh-no-harness-design.md` (run during T-005 against release branch) → empty diff; `git show 958e0dc --stat` shows only the four expected paths | VERIFIED | |
| VR-013 | INV-003 | `main` only receives commits via PRs (no direct pushes during this release) | `git log origin/main --first-parent --oneline -10` shows `958e0dc Merge pull request #2` and `d34c991 Merge pull request #1` as the recent additions to main — both are PR merges | VERIFIED | |
| VR-014 | INV-004 | `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` keep identical `version` strings (both 0.1.0) | `python3 -c "import json; a=json.load(open('.claude-plugin/plugin.json'))['version']; b=json.load(open('.codex-plugin/plugin.json'))['version']; assert a==b=='0.1.0'"` → exit 0 | VERIFIED | Bumped atomically in commit `04421c7` |
| VR-015 | INV-005 | `marketplace.json`'s `ref: v0.1.0` is resolvable on `origin` at the time the marketplace.json reaches users | `git ls-remote --tags origin v0.1.0` returned `3ea2662c... refs/tags/v0.1.0` immediately after `git push origin v0.1.0`; the public `claude plugin marketplace add jcwleo/oh-no-harness` immediately after that successfully cloned and validated the marketplace + tag | VERIFIED | Order of operations honored: tag pushed, then marketplace add tested |

## Evidence-before-claims gate

- Fresh command/inspection run for each claim: yes
- Output read directly: yes
- Verification checkout/worktree confirmed: yes (`pwd` matches `/Users/chanwoong.joo/Projects/oh-no-harness/.claude/worktrees/release+v0.1.0`; `git branch --show-current` is `worktree-release+v0.1.0`; `origin/main` tip is `958e0dc`; `origin v0.1.0^{}` is `958e0dc`)
- Diff or changed-file scope reviewed: yes (`git show 958e0dc --stat` and `git diff main...HEAD --stat` both show exactly the four expected paths)
- RED/GREEN regression proof checked: not applicable — release/distribution change, no behavior change to test

## Commands run

```text
gh repo view jcwleo/oh-no-harness --json visibility,url,isPrivate,defaultBranchRef
  -> {"defaultBranchRef":{"name":"main"},"isPrivate":false,"url":"https://github.com/jcwleo/oh-no-harness","visibility":"PUBLIC"}

python3 -m json.tool ~/.claude/plugins/marketplaces/*/.claude-plugin/marketplace.json
  -> claude-plugins-official uses git-subdir+ref+sha; openai-codex uses string source; chose to keep proven url form

# T-003
python3 -c "...assert claude == codex == '0.1.0'"  -> AC-004+AC-005+INV-004 OK: 0.1.0
git diff --stat                                     -> 2 files, version-line only

# T-004
python3 -m json.tool .claude-plugin/marketplace.json  -> AC-001 OK
python3 -c "...marketplace schema asserts..."         -> AC-002 + AC-003 OK

# T-005
for f in 3 JSON files: python3 -m json.tool $f       -> all OK
scripts/validate-skills                              -> validate-skills: OK
git diff --check                                     -> clean
git diff main...HEAD -- (forbidden paths)            -> empty

# T-006
git push -u origin worktree-release+v0.1.0:release/v0.1.0  -> new branch release/v0.1.0
gh pr create --base main --head release/v0.1.0 ...         -> PR #2 OPEN
gh pr view 2 --json state,mergeCommit                       -> state=MERGED, mergeCommit=958e0dcf...

# T-007
git rev-parse 'v0.0.1^{}'                                   -> e70ff29f132bc0990b06bed39f0e3a8ad0a36adb (INV-001 unchanged)
git tag -a v0.1.0 958e0dc... -m "..."                       -> created
git push origin v0.1.0                                      -> [new tag] v0.1.0 -> v0.1.0
git ls-remote --tags origin v0.1.0                          -> 3ea2662c... refs/tags/v0.1.0
claude plugin validate .claude-plugin/marketplace.json      -> Validation passed
claude plugin marketplace add jcwleo/oh-no-harness          -> Successfully added marketplace: oh-no-harness
claude plugin install oh-no-harness@oh-no-harness           -> Successfully installed plugin: oh-no-harness@oh-no-harness (scope: user)
python3 -c "...read known_marketplaces.json[oh-no-harness]" -> source=github, repo=jcwleo/oh-no-harness, installLocation=~/.claude/plugins/marketplaces/oh-no-harness
python3 -c "...read installed_plugins[oh-no-harness@oh-no-harness]" -> version=0.1.0, scope=user, gitCommitSha=958e0dcf...
```

## Root-cause and instrumentation check

- Root cause fixed rather than symptom masked: not applicable (release/distribution work, not a bug fix).
- Temporary workaround present: no.
- Diagnostic logging/tracing/assertions: not used.

## Retrieval and evidence gaps

- Searched/checked:
  - All AC-001..AC-010 verification commands listed above.
  - All INV-001..INV-005 guards listed above.
  - PR #2 state via `gh pr view`.
  - Both `~/.claude/plugins/known_marketplaces.json` and `~/.claude/plugins/installed_plugins.json` for AC-010.
- Could not verify:
  - Spec AC-010 phrasing literally requires "from a fresh Claude Code session" using slash commands. Verified with `claude plugin marketplace add` / `claude plugin install` CLI subcommands instead, which are the documented headless equivalents (per `claude plugin --help`). The install path exercised is the same; the only thing not directly tested is the in-session `/plugin ...` slash UI affordance. If desired, a fresh in-session run can be done by the user as a no-cost confirmation.
  - The spec's revised DEC-007 said the docs PR may merge in any order; in fact PR #1 (`docs/github-flow-guidelines`) and PR #2 both merged before the v0.1.0 tag was cut, so `v0.1.0` includes both. Not a gap, just an observation worth recording.

## Completion decision

- Safe to claim complete: yes
- Remaining risks: none for the in-scope work. Out-of-scope follow-ups carried forward (per DEC-006): README install instructions for end users, `gh release create v0.1.0` notes, external registry submission (`anthropics/claude-plugins-official`), and a future Codex-side marketplace artifact if/when Codex CLI standardizes one (DEC-003). The local `oh-no-v001` test marketplace at `/tmp/oh-no-v001-marketplace` can be removed at the user's discretion since the public v0.1.0 supersedes it.
