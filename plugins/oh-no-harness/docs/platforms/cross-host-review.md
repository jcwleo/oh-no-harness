# Codex-Host Cross-Host Review

> **Codex-host mechanism document (moved from docs/shared, 2026-07-17).**
> This reference is consumed only by the Codex-host consult channel and its
> live-test fixtures. It is not composed into generated wrappers; each affected
> Codex skill adapter carries its own runtime rules. If this file and a Codex
> adapter disagree on a skill-owned rule, the adapter wins.

Cross-host review is the Codex-host escalated paired-review implementation used
only after a calling skill records a named THOROUGH risk. A review pair exists at
all only because such a named trigger fired; every pair then carries
complementary perspectives, and the trigger selects both the pair topology and
its host independence mode. Cross-host mode lets two instances of
the SAME assigned role run on Codex and Claude in parallel, then has the Codex
main agent synthesize the two analyses into one result. It does not make
dependent DIFFERENT roles eligible for the same batch. When a code-reviewer pair
runs in `ralph`'s Review Gate or `ultrawork`'s Final Validation and the calling
skill's verifier trigger predicate also fired, that triggered
`verifier` starts only after the pair is synthesized and, on blocking findings,
a single executor-owned fix manifest is captured. The verifier then binds to the
current reviewed or fixed revision; no reviewer recheck is dispatched. When the
opposite host is unavailable after the named trigger fires, the Same-Host
Parallel Fallback supplies two same-host instances.
This reuses the Fusion Rescue cross-host mechanism; it is not a new channel,
daemon, background job, weight fusion, or hidden runtime.

This is a Codex-host contract. For the actual invocation (how Codex reaches
Claude), the synchronous-response requirement, the permission or capability
preflight, and secret redaction, use the Codex platform runtime document's
`## Cross-Host Consult Channel` section. Do not hard-code host binaries, plugin
or capability names, or permission states here.

## When It Applies

A dispatched `code-reviewer` or `plan-reviewer` review is ONE full-role instance
by default and records `single-reviewer`; a compliant not-required record (for
example the STANDARD small-task carve-out or the LIGHT code-review waiver)
dispatches none. A perspective-diverse pair exists only after the calling skill
records its named high-risk or paired-review trigger. Once such a trigger fires,
the pair may run on the current host recorded `same-host-perspective-pair` —
intentional same-host review, so no fallback reason is required.
Cross-host escalation applies only when a
calling skill records a named THOROUGH trigger for `plan-reviewer`,
`code-reviewer`, or `debugger`, such as security/data/destructive risk, a public
or release-critical contract, new concurrency semantics, broad migration, or
multi-system uncertainty:

- `plan-reviewer`: `ralplan` consensus plan review only. Other workflows may
  reach this pair only by invoking or using Ralplan's planning phase; they must
  not dispatch it for their own completion, final, post-fix, or debugging review.
- `code-reviewer`: `ralph` (review gate), `systematic-debugging` (post-fix),
  `verification-before-completion` (risk-gated), `ultrawork` (final validation).
- `debugger`: `systematic-debugging` only when a named THOROUGH uncertainty or
  repeated-failure trigger selects paired root-cause investigation.

Exception — `ralph`/`ultrawork` review-then-verify order: in `ralph`'s Review
Gate and `ultrawork`'s Final Validation, run the selected perspective-diverse
code-reviewer pair first. A `verifier` is a dependent later stage that exists
only when the calling skill's named verifier trigger predicate fires — explicit
user request; stale, missing, or conflicting evidence; a named security,
data-loss, destructive, migration, recovery, or public-contract risk actually
needing independent evidence; or accepted blocking-review fix resolution. Same
authorship of the proving tests or implementation, mode, task size, and imminent
completion are explicit NON-triggers; with no trigger fired the calling skill
records its compliant `not-required (no trigger fired: <reason>)` and owns
evidence freshness. Dispatch a triggered verifier only after the pair synthesis is
captured and, when findings block,
the single executor-owned fix manifest maps every accepted finding.
Reviewer approval of the fixed revision is NOT required and MUST NOT be requested; no reviewer re-dispatch exists. A triggered `verifier` is always a
single self-host independent pass —
never a cross-host or same-host pair — because the verifier is out of cross-host
scope (see the out-of-scope note below). That single pass still delivers the
verifier's own acceptance-to-evidence and test-genuineness function, which the
code-review pair does not redundantly cover; it is simply not doubled. A
triggered verifier remains an independent dispatch (never the maker) and binds
to the reviewed revision when no fix occurred. On the fix path, the verifier pass (or accepted pass-with-residual-risk) binds to the FIXED revision with a per-finding resolution audit.
A verifier spawned before the pair completes, or before the blocking-finding fix
manifest is captured, is stale evidence for these flows and must be discarded and
rerun.

It does not apply to `simplify`, which only recommends `code-reviewer` and never
dispatches it, nor to any other role. The `verifier`, `executor`, `explore`,
`analyst`, `planner`, and `fusion-rescue-analyst` roles are out of scope for
cross-host review. A triggered `verifier` is always a single self-host
independent pass, never cross-host and never a same-host pair; it remains a
dependent later stage that runs after the selected code-review stage (see the
Exception above) and is governed by the calling skill's named verifier trigger
predicate, not the cross-host independence-mode enum.

## Activation

Cross-host escalation default: after the named THOROUGH trigger fires, when the
opposite host is available per the active platform's
`## Cross-Host Consult Channel` rules, run the review on BOTH the current host
and the opposite host. When the opposite host is unavailable,
unproven, or its response cannot be collected, run the Same-Host Parallel
Fallback (see below) — two same-host agents in parallel under distinct
complementary lenses, synthesized by the current-host main agent, and record a
fallback note. A host without the opposite host installed still gets a complete,
synthesized review, not a single pass.

require-cross-host mode (opt-in): when the caller or user explicitly requests
require-cross-host, the review blocks if the opposite host cannot be reached.
The blocking output names which host was required, what was attempted, the
failure class, and the next local fallback the user can approve.

Without a named THOROUGH trigger, do not activate the cross-host channel. Host
availability alone never selects `cross-host`, and it never creates a pair: with
no fired trigger the ordinary dispatched review is one full-role instance
recorded `single-reviewer`.

## Full Review Per Host

Each host runs the COMPLETE role review independently — not a split of lenses:

- `plan-reviewer`: both ordered passes (pass 1 architecture lens, pass 2
  quality-gate lens) on each host.
- `code-reviewer`: both lenses (correctness and maintainability first, then the
  security lens via the Safety Trigger Checklist) on each host.
- `debugger`: the full root-cause investigation (reproduce, form hypotheses,
  identify root cause, recommend the minimal fix) on each host.

The assigned perspective is an EMPHASIS, never a split of role duties: each leg
produces its full analysis. The same full-role rule applies to cross-host,
intentional same-host, and Same-Host Parallel Fallback pairs, and to the default
single full-role instance when no pair trigger fired.

## Canonical Perspective Pairs

Every review pair uses these complementary perspective emphases while both legs
run the complete role:

| Role | Lens A | Lens B |
|---|---|---|
| `plan-reviewer` | strongest-antithesis / feasibility-risk emphasis ("why this plan fails or is infeasible") | acceptance-coverage / quality-gate completeness emphasis ("which acceptance criteria or gates are unmet") |
| `code-reviewer` | adversarial correctness + security skeptic ("what breaks or is exploitable") | maintainability + coverage completeness ("what is missing or regresses") |
| `debugger` | leading-hypothesis-A angle | competing-hypothesis-B angle (feeds the competing-hypotheses synthesis) |

For a cross-host pair, Lens A goes to the current-host leg and Lens B to the
opposite-host leg. For `same-host-perspective-pair` and
`same-host-parallel-fallback`, instance 1 receives Lens A and instance 2 receives
Lens B. The `plan-reviewer` row above assigns lenses only at the pair-bearing
topology; a `single-reviewer` plan or code review assigns no lens split and
runs the complete role in one instance. The two review legs receive redacted packets identical except the single `Assigned perspective:` line.

## Role-Owned Review Instances

Cross-host review is a role-dispatch contract, not permission for the current
main agent to perform the opposite-host role inline. The current-host main agent
is the judge, not either review instance: it prepares the exact packet, performs
only the platform preflight the runtime permits, waits for role outputs, and
synthesizes the results.

On subagent-capable hosts, the current-host role pass is owned by a spawned or
host-dispatched role agent of the same role. The opposite-host pass is likewise
owned by the platform-specific role agent or role-owned bridge that the active
runtime requires. Parent inline opposite-host consult is not a valid cross-host
review response. If the required role-owned current-host or opposite-host
receiver cannot be dispatched, default mode treats that side as unavailable and
uses the Same-Host Parallel Fallback; require-cross-host mode blocks.

Fusion Rescue panel slots keep their own panel contract. This ownership rule is
only for shared cross-host review of Ralplan's `plan-reviewer`, plus
`code-reviewer` and `debugger` in their documented workflow contexts.

## Same-Host Parallel Fallback

When a named THOROUGH trigger fires and the opposite host is unavailable in
default mode, the review does not collapse to a single pass. The current-host
main agent instead dispatches exactly two same-host agents of the SAME role in
parallel, each running the COMPLETE role under the canonical perspective pair,
and synthesizes their two analyses into one result using the same judge rules as
the cross-host synthesis below. Record `same-host-parallel-fallback` and the
required fallback reason. It is same-host fan-out, not a cross-host hop (see
Recursion Guard). The intentional `same-host-perspective-pair` uses the
same lenses but is not this fallback and requires no fallback reason.

## Parallel Execution And Synthesis

The current-host analysis and the opposite-host analysis run in parallel against
the same artifact or problem: the exact Planner draft for `plan-reviewer`, the
same stable diff for `code-reviewer`, or the same failure, reproduction, and
evidence packet for `debugger`.

The current-host main agent is the judge. It compares, decomposes, and
recombines the two reviews — it must not only concatenate them. The synthesis
records: consensus, contradictions, unique insights, blind spots, recommended
next action, and panel availability/fallback notes (which host produced which
review, or why the opposite host was unavailable).

The synthesis maps to the role's EXISTING findings-derived verdict; cross-host
review does not add a new verdict type:

- Merge the two finding sets into one, deduplicated by file/line and issue, with
  host provenance recorded on each finding.
- `plan-reviewer`: APPROVE iff zero blocking findings across the merged set;
  ITERATE iff at least one blocking finding on a salvageable draft; REJECT only
  for direction-level or unsalvageable failure. Every merged blocking finding
  retains its reviewer-owned severity and `Blocking basis: <AC ID | safety
  invariant | Direction Contract field | applicable mandatory gate>`.
- `code-reviewer`: return the merged, provenance-tagged findings in the role's
  existing exact result envelope, preserving the shared packet/run/task identity
  and reviewed revision. Re-key each source finding as `<host>:<finding-id>`
  before deduplication so the synthesized blocking IDs remain deterministic.
- `debugger`: the judge synthesizes a single root-cause direction — competing
  hypotheses, the evidence that decides between them, and the smallest next
  diagnostic or fix step — and returns it to `systematic-debugging`. The
  debugger does not emit a findings-verdict; `systematic-debugging` remains
  responsible for reproduction, causal-chain closure, fix evidence, and
  verification-before-completion.

A cross-host finding that would change the approved direction must surface as
`requested-direction-change: yes`; it is never auto-incorporated. The
`plan-reviewer` no-replacement and Direction Preservation rules stay in force:
cross-host findings never silently override the user-approved spec, plan
direction, scope, non-goals, or acceptance criteria.

## Sequencing Preserved

Cross-host review does not change role ordering or erase dependencies between
different roles. For `ralplan`, the sequential `Analyst -> Planner ->
Plan-Reviewer` order is preserved and Plan-Reviewer still runs only after the
Planner draft exists. For `ralph` and `ultrawork`, the Review-then-verify
dependency graph is:

```text
code-reviewer pair
  -> wait/capture both reviewer outputs
  -> synthesize findings
  -> if blocking: apply the single executor-owned fix and capture its mapped manifest
  -> no reviewer recheck
  -> confirming verifier binds to the reviewed or fixed revision
     (fixed path includes a per-finding resolution audit)
```

What is new is that the two reviewer INSTANCES of the SAME reviewer role
(current-host and opposite-host) may run concurrently once their artifact exists;
this does not violate the rule that dependent distinct roles are not run in
parallel.

## Reuse Of The Cross-Host Mechanism

The cross-host review consult reuses the Fusion Rescue mechanism via the Codex
platform runtime document's `## Cross-Host Consult Channel` section:

- Send a panel-style packet: the assigned work is the role's full review or
  investigation contract; the problem packet is the exact Planner draft
  (plan-reviewer), the stable diff (code-reviewer), or the failure/reproduction/
  evidence packet (debugger).
- Preserve the role-owned review instance boundary from
  `## Role-Owned Review Instances`; the platform consult runner is not allowed to
  collapse the opposite-host role into parent inline analysis.
- Redact secrets before sending (credentials, tokens, API keys, cookies, private
  keys, payment or personal data, unrelated user data); include only the minimal
  excerpts the review needs, and label secret-like values such as
  `[REDACTED_TOKEN]`.
- The consult must return the actual review synchronously. A launch notice,
  queued-job message, background acknowledgement, or status pointer is not a
  valid opposite-host review; treat such a non-response as the opposite host
  being unavailable and degrade (default) or block (require-cross-host).

## Recursion Guard (Cross-Host Hop Scope)

The recursion guard restricts CROSS-HOST hops, not same-host work:

- A reviewer, debugger, or verifier, and any subagent it spawns, MAY use
  same-host read-only subagents and read-only tools to form its analysis.
  Same-host fan-out is allowed. The Same-Host Parallel Fallback's two same-host
  agents are this kind of same-host fan-out: they do NOT consume a cross-host hop.
- A reviewer or debugger MUST NOT make any cross-host call beyond the single
  assigned consult, and MUST NOT call back to the origin host or a third host. The
  single self-host `verifier` has ZERO assigned cross-host consults — it never
  runs as a cross-host pair — and likewise MUST NOT make any cross-host call to the
  opposite, origin, or a third host. This cross-host block applies transitively: a
  same-host subagent — or a Same-Host Parallel Fallback agent — spawned by a
  reviewer, debugger, or verifier inherits the same no-further-cross-host-hop rule.
- The review consult is one cross-host hop. The current host must not call the
  opposite host and allow that host to call back into the current host or
  another host.
- Same-host read-only analysis stays non-mutating: no edits, writes, installs,
  or mutating commands — git state mutation (`checkout`, `restore`, `reset`,
  `stash`, `commit`, `clean`) included — from a review consult beyond producing
  the assigned review.

## Recording the Independence Mode

A skill records how each dispatched cross-host-eligible review pass
(`plan-reviewer`, `code-reviewer`, `debugger`) ran using exactly one
independence-mode value:

- `single-reviewer`: the default ONE full-role instance when no named pair
  trigger fired; no fallback reason is required.
- `same-host-perspective-pair`: the intentional same-host pair after a named pair
  trigger fired; no fallback reason is required.
- `cross-host`: the synthesized current-host + opposite-host pair selected after
  a named THOROUGH trigger fires.
- `same-host-parallel-fallback`: the two-same-host-agent fallback above,
  synthesized only when a named THOROUGH trigger fired and the opposite host was
  unavailable; a fallback reason is required.
- `inline-fallback`: a single inline pass — compliant only when the active skill
  allows inline substitution and records an explicit subagent-unavailable or
  unsafe-to-isolate reason. It never satisfies Ralplan's required Plan-Reviewer
  pass. An unlabelled single inline pass is a gap, not a pass.

The `verifier` is not part of this enum. It is dispatched only on a named trigger
from the calling skill's verifier trigger predicate, and is then always a single
self-host independent pass, governed by that predicate and the dispatch-ownership
rules in (`docs/skill-core/ralph.md`, `## Mode-Gated Agent Dispatch`) plus the
`verifier started after reviewer completion` sequencing field — not by a
cross-host independence-mode value.

The calling skill owns the consequence of a missing or non-compliant mode, and
every in-scope dispatcher records the independence mode through its own
completion gate so an unlabelled single inline pass is a named ledger gap, not a
pass:

- `ralph`: the Review Gate plus the Persistence Rule `<HARD-GATE>`.
- `ultrawork`: Final Validation plus the Phase 5 Report `<HARD-GATE>`.
- `ralplan`: the Findings Ledger Gate — its `Plan review topology` field plus
  the invalidation rule for a missing topology or a non-compliant triggered
  pair (an invalidation rule, not a `<HARD-GATE>` block).
- `verification-before-completion`: the Required Gate `<HARD-GATE>`.
- `systematic-debugging`: the Output Gate `<HARD-GATE>` (single STANDARD
  `debugger`; a dispatched post-fix `code-reviewer` is `single-reviewer` by
  default; a named high-risk or THOROUGH trigger selects the reviewer pair,
  debugger pairing, or cross-host escalation).

## Fallback Notes

After a named THOROUGH trigger fires, record a cross-host review fallback note
when the opposite host is not used: state whether it was unavailable, unproven,
or returned no valid review, and that the review ran via
`same-host-parallel-fallback` (two same-host agents synthesized) in default mode
rather than as a single current-host pass. The intentional
`same-host-perspective-pair` requires no fallback note, and the default
`single-reviewer` path (no pair trigger fired) needs none either. In require-cross-host
mode, block instead of degrading and name the failure class plus the next local
fallback. Record only the failure class, command/plugin/capability name, and path
or auth status — never secret values, config contents, or environment dumps.
