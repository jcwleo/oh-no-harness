# TODO: Subagent Dispatch Model Fidelity

- Status: **OPEN — 3 of 4 scope items closed** by `14e833e` on local `main` (not
  pushed, not released). Items 1, 3, and 4 are delivered. **Item 2 remains open**;
  see [Remaining work](#remaining-work).
- Platform: **Claude Code only** (the per-call `model` override is a Claude Code
  Agent/Task parameter). Codex was checked and needs no parallel work — see item 4.
- Backlog: `backlog/`
- Related: [Subagent dispatch type-selection safety](./subagent-dispatch-type-safety.md)
  — same failure family (a dispatch silently running on the wrong model), but that
  item is about the *selector* (`subagent_type` omitted → generic agent + parent
  model), and this item is about the *model parameter* (selector correct, but the
  caller supplies a model value the role was never configured with).

## Rule to enforce

A role dispatch uses **exactly the model value configured for that role** — the
`model:` frontmatter of `agents/<role>.md` as written by
`/oh-no-harness:configure-subagents`. The caller must not substitute any other
model value, not even a "better" or "equivalent" one.

**Single exception:** a **prescribed model-diversity leg or panel**. There the
secondary model MUST be supplied as an explicit override, because that is the
only mechanism that produces model diversity. The exception is already specified
per skill (`model-diversity-pair`: primary leg dispatched *without* an override so
it uses the declared frontmatter primary; diversity leg carries an explicit
NATIVE override for the validated secondary top-tier model from
`<OH_NO_MODEL_DIVERSITY>`).

So the rule is narrow and checkable: **no per-call `model` value except a
prescribed model-diversity leg or panel.**

> **Do not re-narrow this carve-out to review pairs.** An earlier revision of this
> file said the exception was "the diversity leg of a parallel review pair". Plan
> review caught that as blocker A1: it is **false**. Prescribed overrides also
> exist on Fusion Rescue's three **panels**
> (`docs/platforms/claude-code-fusion-rescue.md`), which are not a pair, and on the
> named THOROUGH paired **`debugger`**
> (`docs/platforms/claude-code-systematic-debugging.md`), which is a pair but not a
> review. A pair-only rule would make both of those violations of the very rule
> this item exists to enforce. The shipped wording says "leg or panel" precisely to
> cover every prescribed-override site. Regression test **T7** in
> `scripts/test-review-boundary-contract.py` now rejects exactly this re-narrowing:
> it mutates the shipped clause back to "the sole exception is the diversity leg of
> a review pair" and asserts `assert_hook_contract` fails.

## Observed gap (as filed — now largely closed)

> **Historical.** The sentence quoted below **no longer exists**; AC-2 of `14e833e`
> replaced it. Do not cite it as current state. What stands at
> `hooks/session-start:226` today is the all-roles rule reproduced under
> [What shipped](#what-shipped).

The "do not override per call" instruction existed in exactly one place at filing
time — one line of the Claude orchestration block, and only for `executor`:

> Every executor dispatch, including LIGHT, uses the configured executor agent
> model; never override it per call.

Nothing stated it for the other eight roles (`planner`, `plan-reviewer`,
`code-reviewer`, `verifier`, `debugger`, `analyst`, `explore`,
`fusion-rescue-analyst`). The per-skill `model-diversity-pair` bullets describe
what the *diversity* leg does, but never say that a **single** (non-pair)
dispatch must carry no override at all. A caller reading only those bullets can
reasonably conclude that supplying a model is normal practice.

This matters more than it looks because the current configured state is
heterogeneous — `agents/*.md` today: `analyst: opus`, `executor: opus`,
`explore: sonnet`, and six roles on `inherit`. An `inherit` role picks up the
parent model, so a stray override on such a role is invisible in the diff between
"configured" and "actual" and is only caught by watching the statusline.

## What shipped

`14e833e`, AC-2 and AC-5. The executor-only sentence was **replaced** in the
Claude-only orchestration block by:

> Model fidelity: every role dispatch, including every executor and LIGHT
> dispatch, runs on the model configured for that role and carries no per-call
> model value; the sole exception is a prescribed model-diversity leg or panel,
> which MUST carry the explicit NATIVE override.

Pinned by four verbatim markers in `assert_hook_contract`
(`scripts/validate-plugin-files.py`) and three mutation cases in
`scripts/test-review-boundary-contract.py`: **T5** rejects narrowing back to
executor-only, **T6** rejects flipping `carries no per-call model value` to
`may carry any`, and **T7** rejects re-narrowing the carve-out to review pairs.

## Scope status

1. **CLOSED.** Hook rule generalized from executor-only to all roles, in place in
   the Claude-only orchestration block, with the carve-out named inline.
2. **OPEN.** See [Remaining work](#remaining-work).
3. **CLOSED.** Validator pin warranted and added: four markers in
   `assert_hook_contract` plus the three `test-review-boundary-contract.py`
   mutation cases above.
4. **CLOSED.** Codex exposes no per-call model at all — `spawn_agent` takes no
   model argument, and each role's model is fixed at install time in its generated
   agent TOML, so model fidelity is structural there rather than instructional.
   Recorded in `docs/platforms/codex.md` under `## Role Dispatch` (AC-5).

## Remaining work

**Scope item 2 only.** The five per-skill Claude overlays —
`plugins/oh-no-harness/docs/platforms/claude-code-{ralplan,ralph,ultrawork,systematic-debugging,verification-before-completion}.md`
— still only *describe* the primary leg's behavior:

> `model-diversity-pair`: the primary leg is dispatched without a model override
> and therefore uses the concrete declared-frontmatter primary; …

That is a description of what happens, not a requirement that it must. A caller
reading only these bullets still gets no statement that a single, non-diverse
dispatch must carry no override.

This is a **disclosed scope boundary, not an oversight**: the `14e833e` plan
excluded those overlays deliberately and shipped the hook rule instead, on the
reasoning that the hook block is injected every session and therefore reaches
every dispatch, whereas the overlays are per-skill. The gap is narrower than at
filing time — the rule now exists and is pinned — but the overlay wording was
left as-is on purpose and remains the residue of this item.

Closing it means restating the primary-leg rule as an obligation in those five
overlays (and deciding whether `docs/platforms/claude-code-runtime.md` should
carry it once instead of five times). Both generators must be re-run afterwards.

## Non-goals

- Changing which model any role is configured with. This is about **fidelity to
  the configured value**, not about the values themselves.
- Removing or weakening the prescribed diversity-leg-or-panel override. It is the
  one legitimate per-call model value and stays. Narrowing it — to review pairs,
  or to anything short of every prescribed-override site — is equally out of
  bounds, and T7 now fails if it is attempted.
- A hard host-level enforcement mechanism. As with the type-safety item, Claude
  Code offers no way to reject a dispatch's model parameter from plugin text
  alone; the realistic ceiling is unambiguous instruction plus a regression pin.

## Open question

Whether `inherit` should remain an accepted configured value for review roles. It
makes "the configured model" indistinguishable from "the parent model" at dispatch
time, which is precisely what defeats detection here. Out of scope to decide, but
it belongs in this item's write-up because it bounds how well any instruction can
be verified after the fact.
