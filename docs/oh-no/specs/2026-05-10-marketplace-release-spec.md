# Spec: Publish oh-no-harness v0.1.0 to a self-hosted Claude + Codex marketplace

- Date: 2026-05-10
- Slug: marketplace-release
- Profile: standard
- Status: draft

## Retrieval basis

- User evidence: "이제 실제 마켓플레이스에 배포를 하고싶어." (no specific paths/logs supplied).
- Repository evidence checked:
  - `README.md`, `AGENTS.md`, `docs/oh-no-harness-design.md` — confirms root-level dual-plugin layout, GitHub Flow policy, and that "marketplace 배포를 언제 도입할 것인가?" is an explicitly deferred design question (`docs/oh-no-harness-design.md` §12).
  - `.claude-plugin/plugin.json` — `name: oh-no-harness`, `version: 0.0.1`, MIT, repo `https://github.com/jcwleo/oh-no-harness`.
  - `.codex-plugin/plugin.json` — `version: 0.0.1`, full `interface` metadata block, `skills: ./skills/`.
  - `scripts/validate-skills`, `scripts/sync-adapters` — local validation paths.
  - `git remote -v` / `git ls-remote` — `origin` is `https://github.com/jcwleo/oh-no-harness.git`; tag `v0.0.1` already exists at commit `e70ff29` ("Make the harness installable as a root plugin"). Current branch `docs/github-flow-guidelines` is one commit (`d50193c`, "Adopt GitHub Flow") ahead of `main` and is not yet merged.
  - `/tmp/oh-no-v001-marketplace/.claude-plugin/marketplace.json` — existing local-only test marketplace; name `oh-no-v001`, single plugin entry pointing to `https://github.com/jcwleo/oh-no-harness.git` ref `v0.0.1`. This is the proven shape we extend.
  - `~/.claude/plugins/known_marketplaces.json` — confirms how Claude Code resolves marketplaces by source (github / directory) and stores `installLocation`/`lastUpdated`.
- Unknowns after retrieval:
  - Whether Codex CLI ships a first-class `marketplace.json`-style aggregator equivalent to Claude's `.claude-plugin/marketplace.json`. Treated as not-required for this release per DEC-003 below.
  - Whether the GitHub repository `jcwleo/oh-no-harness` is currently public/world-readable (the remote responds to `git ls-remote`, but visibility was not explicitly verified). Captured as `OQ-001`.

## Goal

Publish `oh-no-harness` as an installable plugin via a self-hosted marketplace contained in this same repository, tagged at `v0.1.0`, so that:

- Claude Code users can run `/plugin marketplace add jcwleo/oh-no-harness` and `/plugin install oh-no-harness@oh-no-harness` to install the harness from a stable, versioned ref.
- Codex CLI users can install/use the same repo's `.codex-plugin/` layout via the existing root-level plugin shape (no new Codex-side marketplace introduced in this release).

## Non-goals

- README rewrites, install instructions, and end-user-facing docs for marketplace install commands. (Will be follow-up work; the user explicitly excluded this scope from this release.)
- Authoring a GitHub Release / CHANGELOG entry for `v0.1.0` via `gh release create`. (Tag-only; no release notes artifact in this release.)
- Submitting `oh-no-harness` to `anthropics/claude-plugins-official` or any other third-party registry.
- Introducing a Codex-only `marketplace.json`, a Codex install command shim, or any Codex registry integration.
- Adding a CHANGELOG, signing/notarization, automated release CI, or telemetry.
- Any change to skill behavior, agent prompts, hook logic, or workflow contracts.
- Force-moving the existing `v0.0.1` tag.

## User-visible behavior

- A new file `.claude-plugin/marketplace.json` exists at the repo root, declaring a single marketplace named `oh-no-harness` whose owner is `jcwleo` and which lists exactly one plugin (`oh-no-harness`) pinned to git ref `v0.1.0` of `https://github.com/jcwleo/oh-no-harness.git`.
- `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` both report `"version": "0.1.0"`.
- The remote `origin` has an annotated tag `v0.1.0` whose tip contains both the version bumps and the new `marketplace.json`, and whose ancestry includes commit `d50193c` ("Adopt GitHub Flow for repository changes") merged into `main`.
- A Claude Code session that runs `/plugin marketplace add jcwleo/oh-no-harness` followed by `/plugin install oh-no-harness@oh-no-harness` resolves the plugin from GitHub at ref `v0.1.0` without 404s, version conflicts, or schema-validation errors.
- The existing `v0.0.1` tag remains untouched and continues to point at commit `e70ff29`.

## Scope boundaries

- In scope:
  - `.claude-plugin/marketplace.json` (new file).
  - `.claude-plugin/plugin.json` (`version` field only).
  - `.codex-plugin/plugin.json` (`version` field only).
  - GitHub Flow: a short-lived branch, a PR into `main`, and an annotated tag `v0.1.0` created from the merged `main`.
- Out of scope:
  - All files under `skills/`, `agents/`, `.codex/agents/`, `bootstrap/`, `hooks/`, `templates/`, `tests/`.
  - `README.md`, `AGENTS.md`, `docs/oh-no-harness-design.md` content edits (other than the spec/plan/progress artifacts this workflow itself produces under `docs/oh-no/`).
  - `scripts/validate-skills`, `scripts/sync-adapters` content (we run them; we do not modify them).
  - Any non-`main` long-lived branches.

## Constraints and assumptions

- The repository follows GitHub Flow (per `README.md` §"Development flow" and `AGENTS.md` §"Commit & Pull Request Guidelines"). All changes land via short-lived branch + PR + review before tagging.
- `main` must be releasable at all times. The `v0.1.0` tag is created **from `main` after merge**, never from a feature branch.
- The existing `v0.0.1` tag (commit `e70ff29`) is immutable in this release. We do not force-push, retag, or rewrite it. Any `v0.0.1` consumers continue to see exactly what they saw before.
- The marketplace.json schema follows Claude Code's plugin marketplace contract used by the local-only `oh-no-v001` test marketplace (top-level `name`, `description`, `owner.name`, `plugins[]` with each entry having `name`, `description`, `source.{source,url,ref}`). That is the empirically-verified shape on this user's machine.
- Plugin source model: pinned git URL + ref (not relative `.`). Reason: marketplace consumers may reference a different version than the marketplace tip; pinning matches the test-marketplace shape and isolates plugin lifecycle from marketplace lifecycle.
- Codex side does not require a separate marketplace artifact. The `.codex-plugin/plugin.json` already declares `skills: ./skills/`, `interface`, and metadata. Installing via `git`/Codex's existing plugin-install path is sufficient for this release.
- `scripts/validate-skills` and `git diff --check` are the canonical local validation gates per `README.md` §"Validate". They must pass on the release branch.
- The unmerged commit `d50193c` ("Adopt GitHub Flow for repository changes") on branch `docs/github-flow-guidelines` is a prerequisite — it must merge into `main` first (its own PR) so that `v0.1.0` includes the GitHub Flow guidelines that the rest of this work depends on. This is bookkeeping, not a scope add.

## Acceptance criteria

- AC-001: `.claude-plugin/marketplace.json` exists at the repo root and parses as valid JSON via `python3 -m json.tool .claude-plugin/marketplace.json`.
- AC-002: `.claude-plugin/marketplace.json` declares `name == "oh-no-harness"`, has a non-empty `description`, has `owner.name == "jcwleo"`, and `plugins` is a length-1 array.
- AC-003: The single plugin entry in `.claude-plugin/marketplace.json` has `name == "oh-no-harness"`, a non-empty `description`, and `source` of the form `{ "source": "github" | "url", "url"|"repo": "<github URL or owner/repo>", "ref": "v0.1.0" }`. The exact key shape matches whichever variant Claude Code's marketplace loader currently accepts on this machine; the working `/tmp/oh-no-v001-marketplace/.claude-plugin/marketplace.json` shape is the reference.
- AC-004: `.claude-plugin/plugin.json` has `"version": "0.1.0"`.
- AC-005: `.codex-plugin/plugin.json` has `"version": "0.1.0"`.
- AC-006: All three JSON files (`.claude-plugin/marketplace.json`, `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`) round-trip cleanly through `python3 -m json.tool`.
- AC-007: `scripts/validate-skills` exits 0 on the release branch tip.
- AC-008: `git diff --check` reports nothing on the release branch tip.
- AC-009: The release branch is merged into `main` via a PR (GitHub Flow), and an annotated tag `v0.1.0` is created from the merged `main` commit and pushed to `origin`. Verified by `git ls-remote --tags origin` showing `refs/tags/v0.1.0` resolving to a commit whose tree contains the v0.1.0 plugin.json values and the new marketplace.json.
- AC-010: From a fresh Claude Code session, running `/plugin marketplace add jcwleo/oh-no-harness` followed by `/plugin install oh-no-harness@oh-no-harness` succeeds end-to-end (marketplace registered, plugin installed at ref `v0.1.0`, no resolution errors). Evidence: terminal transcript or `~/.claude/plugins/known_marketplaces.json` showing a `jcwleo/oh-no-harness`-rooted entry plus `~/.claude/plugins/installed_plugins.json` (or equivalent) showing `oh-no-harness@v0.1.0`.

## Invariants and regression guards

- INV-001: The `v0.0.1` git tag continues to point to commit `e70ff29` after this work. No force-push, no retag.
- INV-002: No file under `skills/`, `agents/`, `.codex/agents/`, `bootstrap/`, `hooks/`, `templates/`, or `tests/` is modified by this release. Only `.claude-plugin/marketplace.json` (added), `.claude-plugin/plugin.json` (version), `.codex-plugin/plugin.json` (version), and artifacts under `docs/oh-no/` change.
- INV-003: `main` remains releasable: every commit landed via PR + validation; no direct pushes to `main`.
- INV-004: `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` keep identical `version` strings (both `0.1.0`). Drift between the two would silently mislead one host's installer.
- INV-005: The plugin entry's `ref` in `.claude-plugin/marketplace.json` references a git ref that actually exists on `origin` at install time (i.e., the tag is pushed before the marketplace.json that references it is announced).

## Decisions

- DEC-001: Use a self-hosted marketplace co-located in the same repo (`.claude-plugin/marketplace.json`), not a separate `oh-no-marketplace` repository. Rationale: confirmed by user; mirrors the working `/tmp/oh-no-v001-marketplace` shape; lowest moving parts.
- DEC-002: Marketplace `name` field is `oh-no-harness` (not the throwaway `oh-no-v001` used in the local test). Rationale: production identity should match the plugin and repo name; `oh-no-v001` was scoped to local v0.0.1 smoke testing.
- DEC-003: Codex distribution in this release reuses the existing `.codex-plugin/plugin.json` only. No Codex-side `marketplace.json` is introduced. Rationale: confirmed by user; Codex CLI's marketplace conventions are not stable enough to commit to in this release; the design notes (`docs/oh-no-harness-design.md` §5, §12) already model this as best-effort.
- DEC-004: First public marketplace release is `v0.1.0`. Rationale: confirmed by user; `v0.0.1` was the "installable prototype" tag at commit `e70ff29` and is left immutable; the new tag bundles GitHub Flow guidelines + marketplace.json + version bump in one stable cut.
- DEC-005: Plugin entry `source` pins to ref `v0.1.0` (not a moving branch like `main`, not relative `.`). Rationale: matches the proven `/tmp/oh-no-v001-marketplace` shape, decouples plugin install version from marketplace tip, and keeps end-user installs reproducible.
- DEC-006: GitHub Release notes / `gh release create`, README install-instructions update, and external-registry submission are deferred to follow-up work. Rationale: explicitly excluded from scope by user.
- DEC-007: The unmerged `docs/github-flow-guidelines` branch (commit `d50193c`) is treated as an independent PR, not a prerequisite. The marketplace-release work proceeds in parallel from a worktree cut at `origin/main` (= `e70ff29`). Both PRs may land in either order; the `v0.1.0` tag is cut from `main` only after both are merged. Rationale: user preference (2026-05-10) — keeps the worktree isolated from `docs/github-flow-guidelines`'s in-progress local edits and lets each PR be reviewed on its own merits.

## Open questions

- OQ-001: Is the GitHub repository `jcwleo/oh-no-harness` currently public/world-readable? Marketplace install via `/plugin marketplace add jcwleo/oh-no-harness` requires it. If private, AC-010 cannot pass; the release plan must include a "make public" step or switch to an authenticated source. Recommended verification: `gh repo view jcwleo/oh-no-harness --json visibility` or visiting the repo URL while logged out.
- OQ-002: Should the plugin entry's `source` use Claude Code's `"source": "github"` shorthand (with `repo: "jcwleo/oh-no-harness"`) or the explicit `"source": "url"` + full git URL form (matching the `/tmp/oh-no-v001-marketplace` test). The `url`/`ref` form is empirically known-good on this user's machine; the `github` shorthand has not been verified end-to-end here. Default plan: keep the proven `url` form unless validation reveals otherwise.

## Affected files or modules

- `.claude-plugin/marketplace.json` — new file.
- `.claude-plugin/plugin.json` — `version` field bump only.
- `.codex-plugin/plugin.json` — `version` field bump only.
- New artifacts under `docs/oh-no/` produced by the workflow itself (this spec, the plan, the progress log, the verify report).

## Verification matrix

| ID | How to verify | Evidence target |
| --- | --- | --- |
| AC-001 | `python3 -m json.tool .claude-plugin/marketplace.json >/dev/null` | exit 0 |
| AC-002 | `python3 -c "import json; m=json.load(open('.claude-plugin/marketplace.json')); assert m['name']=='oh-no-harness' and m['owner']['name']=='jcwleo' and m['description'] and len(m['plugins'])==1"` | exit 0 |
| AC-003 | `python3 -c "import json; p=json.load(open('.claude-plugin/marketplace.json'))['plugins'][0]; assert p['name']=='oh-no-harness' and p['description'] and p['source']['ref']=='v0.1.0'"` | exit 0 |
| AC-004 | `python3 -c "import json; assert json.load(open('.claude-plugin/plugin.json'))['version']=='0.1.0'"` | exit 0 |
| AC-005 | `python3 -c "import json; assert json.load(open('.codex-plugin/plugin.json'))['version']=='0.1.0'"` | exit 0 |
| AC-006 | `for f in .claude-plugin/marketplace.json .claude-plugin/plugin.json .codex-plugin/plugin.json; do python3 -m json.tool "$f" >/dev/null; done` | exit 0 for each |
| AC-007 | `scripts/validate-skills` | exit 0 |
| AC-008 | `git diff --check` on release branch tip | no output, exit 0 |
| AC-009 | `git ls-remote --tags origin v0.1.0` and inspect tagged tree for the three changed files | tag resolves; tree contains v0.1.0 values and new marketplace.json |
| AC-010 | Fresh Claude Code session: `/plugin marketplace add jcwleo/oh-no-harness` then `/plugin install oh-no-harness@oh-no-harness` | both succeed; `~/.claude/plugins/known_marketplaces.json` and installed-plugin records show v0.1.0 from `jcwleo/oh-no-harness` |
| INV-001 | `git rev-parse v0.0.1` before and after release | unchanged, equals `e70ff29...` |
| INV-002 | `git diff main...release-branch -- skills agents .codex/agents bootstrap hooks templates tests` | empty diff |
| INV-003 | `git log main --first-parent --oneline` since the release work began | only PR-merge commits, no direct pushes |
| INV-004 | `python3 -c "import json; a=json.load(open('.claude-plugin/plugin.json'))['version']; b=json.load(open('.codex-plugin/plugin.json'))['version']; assert a==b=='0.1.0'"` | exit 0 |
| INV-005 | `git ls-remote --tags origin v0.1.0` runs cleanly **before** any user is asked to add the marketplace | tag resolves on origin |

## Decision log

- 2026-05-10: Spec drafted. User confirmed: target both Claude + Codex marketplaces with this repo as self-hosted marketplace; bump to v0.1.0; Codex side reuses `.codex-plugin/` only; release scope limited to marketplace.json + version bumps + tag (README/Release notes/external registry deferred).
- 2026-05-10: DEC-007 revised. `docs/github-flow-guidelines` is no longer a hard prerequisite; marketplace work proceeds in an isolated worktree (`.claude/worktrees/release+v0.1.0`, branch `worktree-release+v0.1.0`) cut from `origin/main`. Both PRs are independent; v0.1.0 tag is only cut after both have merged into `main`.
