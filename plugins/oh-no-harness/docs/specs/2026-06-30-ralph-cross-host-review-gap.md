# Ralph Cross-Host Code-Review Gate Gap

> Location rationale: this repo has no `docs/notes/` convention; `docs/specs/`
> is the documented home for design/proposal notes (plugin CONTRIBUTING.md:132),
> and the sibling `2026-06-28-verifier-dispatch-cleanup.md` is the same shape —
> a PROPOSAL drawn from a live run where an independence-dependent pass was
> folded inline. This note follows that convention.

> Status: PROPOSAL — documentation/policy analysis for a follow-up maintainer
> session. NOT a code change. No edits to skill source docs, the generator, or
> generated `skills-claude/**` wrappers were made; only this note was written.
> Author context: drafted 2026-06-30 from a live gap-king Ralph STANDARD run.

## TL;DR

Ralph's cross-host code-review obligation is real in the source
(`docs/skill-core/ralph.md` + `docs/shared/cross-host-review.md`) but
**structurally easy to skip** because (1) the operational "how" doc
(`cross-host-review.md`) is never composed into Ralph's generated runtime skill,
(2) it is missing from the Execution Loop step-1 required-reading list that the
Review Gate depends on, (3) the cross-host obligation is a soft clause scattered
across an Agent-Roles table note and Review-Gate questions rather than a
HARD-GATE, and (4) for a behavior-PRESERVING refactor the mode rules are
ambiguous about whether a dispatched review is even expected — which is exactly
the case where the cross-host requirement gets silently dropped. All four were
confirmed against the files; see evidence below.

## Symptom (observed incident)

During a gap-king Ralph STANDARD run, a behavior-preserving refactor (a WS
parser changing `json.loads` -> `orjson.loads`) had `code-reviewer` dispatched as
a **single same-host (Claude) pass only**. The opposite host (Codex) was proven
available in the same session (fusion-rescue's adversarial panel had already
returned real Codex analysis). Per Ralph's rules the dispatched `code-reviewer`
should have run as cross-host review (merge: merged findings) or, failing that,
recorded the Same-Host Parallel Fallback. Neither happened, and no
independence-mode value was recorded (corrected only after the fact).

## Root-cause analysis (each item verified against the files)

### 1. `cross-host-review.md` is never composed into Ralph's generated skill — CONFIRMED

The generator composes exactly three sources per skill and has no mechanism to
inline any `docs/shared/*` doc:

- `scripts/generate-skill-wrappers.py:127-131` — `source_paths` =
  `[core_path, platform.platform_doc, *optional_overlay_paths(...)]`, i.e.
  `docs/skill-core/<skill>.md`, the platform runtime doc, and an optional
  `docs/platforms/<prefix>-<skill>.md` overlay. Nothing else.
- `scripts/generate-skill-wrappers.py:117-119` — the only optional source is the
  platform overlay; there is no shared-doc inlining path.
- `skills-claude/ralph/SKILL.md:13-19` ("Source order") confirms the composed
  set for Ralph is exactly: `docs/skill-core/ralph.md`,
  `docs/platforms/claude-code-runtime.md`, `docs/platforms/claude-code-ralph.md`.
- `docs/reference/source-index.md:99` documents this as the intended contract:
  generated SKILL.md is "composed from `docs/skill-core/<name>.md`,
  `docs/platforms/claude-code-runtime.md`, and optional
  `docs/platforms/claude-code-<name>.md`."
- `docs/reference/source-index.md:44` confirms `cross-host-review.md` is the doc
  that owns "pairing, same-host parallel fallback, independence-mode recording,
  and the review-then-verify exception."

Result: Ralph's runtime skill carries ~12 path *references* to
`docs/shared/cross-host-review.md` (e.g. `docs/skill-core/ralph.md:126`, `:374`,
`:411`, `:432`, `:465`) but the runtime model is never handed that file's
contents. The cross-host *invocation mechanism* (`## Cross-Host Consult
Channel`) does ship, because it lives in `docs/platforms/claude-code-runtime.md`
(`claude-code-runtime.md:56`) which is composed — but the cross-host *review
procedure and the independence-mode recording rule* do not.

**Contrast with fusion-rescue (CONFIRMED):** fusion-rescue writes its cross-host
consult procedure directly into its own skill-core
(`docs/skill-core/fusion-rescue.md:110` `## Cross-Host Consult`, with the full
procedure across lines ~67-300), so it composes into
`skills-claude/fusion-rescue/SKILL.md` naturally. Ralph instead delegates by
reference to a shared doc that is never composed. This asymmetry is the core
structural weakness.

### 2. `cross-host-review.md` is absent from Execution Loop step-1 required reading — CONFIRMED

`docs/skill-core/ralph.md:247` (Execution Loop, step 1) lists the shared
references to read before working:
`execution-modes.md`, `worktree-isolation.md`, `agent-tiers.md`,
`verification-tiers.md`, `validation-check.md`, `ralph-subagent-policy.md`.
`cross-host-review.md` is **not** in that list — yet the Review Gate
(`ralph.md:374-384`, `:409-414`, `:431-433`) and the Agent Roles table
(`ralph.md:126`) all depend on it. So even if a maintainer fixes (1), the loop
never instructs the model to read the file up front; it only sees pointers to it
at the moment the gate fires, when context is most likely already loaded with
implementation detail.

### 3. Cross-host code-review is a soft clause, not a HARD-GATE — CONFIRMED

`docs/skill-core/ralph.md` has exactly two `<HARD-GATE>` blocks:

- Worktree Isolation Gate — `ralph.md:163-166`
- Persistence Rule — `ralph.md:536-538`

(Verified by `grep -n 'HARD-GATE'`; only these two in ralph.md.)

The cross-host code-review obligation is spread across non-gate prose:

- Agent Roles table note — `ralph.md:126` ("When the opposite host is available,
  run the dispatched review/verification roles as cross-host review ...
  otherwise use the Same-Host Parallel Fallback").
- Review Gate question bullet — `ralph.md:409-414` ("When the opposite host was
  available, were ... run as cross-host review ... or was the Same-Host Parallel
  Fallback recorded?").
- Review loop budget — `ralph.md:431-433` ("Record each pass's independence mode
  per `docs/shared/cross-host-review.md` `## Recording the Independence Mode`").

The Persistence Rule HARD-GATE (`ralph.md:537`) enumerates "the required
reviewer pass, the independent verifier pass, simplify, and
verification-before-completion" — it requires that the reviewer pass *happened*,
but it does **not** name the review's *independence mode* (cross-host /
same-host-parallel-fallback / inline-fallback+reason) as a required ledger
entry. So a single same-host pass with no independence-mode value satisfies the
HARD-GATE's literal wording, even though `cross-host-review.md:215-225` defines
an unlabelled single inline pass as "a gap, not a pass."

### 4. Behavior-preserving refactors sit in an ambiguity gap — CONFIRMED

`docs/shared/execution-modes.md`:
- `:108` lists "refactors" as a typical STANDARD signal.
- `:134` narrows dispatched review to "use `verifier` or `code-reviewer` for
  **behavior-affecting or workflow changes** where independent evidence is
  useful."

`docs/skill-core/ralph.md:371` (Review Gate) repeats the same framing: "STANDARD
uses targeted review for **behavior-affecting or workflow changes**."

A behavior-PRESERVING refactor (json.loads -> orjson.loads) is, by definition,
not "behavior-affecting." So the mode language is ambiguous about whether a
dispatched review is even expected for it. And the cross-host requirement only
binds *once you have decided to dispatch* (`ralph.md:126`: "run the dispatched
review/verification roles as cross-host"). The result is a double-discretion
gap: "do I even dispatch?" is fuzzy for a behavior-preserving refactor, and that
fuzziness then masks "if I dispatched, must it be cross-host?" This is precisely
where the incident landed.

## Recommended fixes (priority order — proposals only; do not apply here)

1. **(Highest leverage) Compose `cross-host-review.md` into review-gated
   generated skills.** Extend `scripts/generate-skill-wrappers.py` so skills
   with a review/verify gate (at minimum `ralph`; consider `ultrawork`,
   `ralplan`, `verification-before-completion`, `systematic-debugging`) inline
   `cross-host-review.md` (or a compact operational excerpt of it) into their
   generated SKILL.md, the same way `claude-code-runtime.md` is composed. This
   removes the structural cause in (1) and mirrors how fusion-rescue ships its
   cross-host procedure. Mechanically this is a new per-skill shared-source list
   (analogous to the existing platform overlay), regenerated via
   `--write`; the validator (`scripts/validate-plugin-files.py`) mirrors the
   generator so keep both in sync.

2. **Add `cross-host-review.md` to Execution Loop step-1 required reading**
   (`docs/skill-core/ralph.md:247`). Cheap, and fixes (2). Lower-cost stopgap if
   (1) is deferred, but weaker — a path reference is not composed content.

3. **Promote independence-mode recording into the Persistence Rule HARD-GATE**
   (`docs/skill-core/ralph.md:536-538`). Make the reviewer/verifier completion
   criteria explicitly require a recorded independence mode
   (`cross-host` / `same-host-parallel-fallback` / `inline-fallback`+reason) for
   each dispatched review or verification pass, so a single unlabelled same-host
   pass is a named ledger gap, not a pass. This aligns the HARD-GATE with
   `cross-host-review.md:215-225` and closes (3).

4. **Disambiguate behavior-preserving refactors in the STANDARD review rule**
   (`docs/shared/execution-modes.md:134` and `docs/skill-core/ralph.md:371`).
   State explicitly whether a behavior-preserving refactor that touches a
   risk-bearing surface (parser, protocol, concurrency, hot path) warrants a
   dispatched review, and that **if** it is dispatched the cross-host /
   fallback / independence-mode rule applies unconditionally. Closes (4).

5. **(Host-side option, not a source fix)** A Skill-tool PreToolUse hook that
   force-injects the referenced shared docs (incl. `cross-host-review.md`) into
   context when a review-gated skill loads. Mentioned only as a host-side
   backstop; the source-level fix (1) is preferred because it keeps the
   contract self-contained in the generated artifact rather than depending on a
   runtime hook.

## Not verified / residual uncertainty

- **Codex availability at the incident moment was not re-checked from this
  repo.** The "Codex was proven available" claim comes from the gap-king run
  narrative (fusion-rescue had returned real Codex analysis), not from anything
  inspectable here. The structural gaps above hold regardless of whether the
  opposite host was actually reachable — in default mode an unavailable opposite
  host still requires the recorded Same-Host Parallel Fallback
  (`cross-host-review.md:59-66`), which also did not happen.
- **Fix (1) feasibility / blast radius not prototyped.** Composing
  `cross-host-review.md` (~244 lines) into multiple gated skills enlarges every
  affected generated SKILL.md and may warrant a compact excerpt rather than the
  full doc; the right granularity is a maintainer decision and was not designed
  here. The generator/validator parity requirement (generator and
  `scripts/validate-plugin-files.py` must agree) was noted but not exercised.
- **Whether `ultrawork`/`ralplan`/`verification-before-completion`/
  `systematic-debugging` share the identical step-1-omission and
  HARD-GATE-omission shape was not fully audited.** Only `ralph.md` was read in
  full. `cross-host-review.md:227-232` notes that
  `verification-before-completion` and `systematic-debugging` already require an
  explicit inline-fallback reason via their own per-role recording, so their
  exposure to (3) may differ; this was not independently confirmed in their
  skill-core files.
- **No claim is made that any single fix alone is sufficient.** The four causes
  are layered (compose -> read -> gate -> disambiguate); fixing only one (e.g.
  only adding the file to step-1 reading) leaves the others as live skip paths.
