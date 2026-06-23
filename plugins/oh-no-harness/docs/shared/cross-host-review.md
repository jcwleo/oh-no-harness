# Cross-Host Review

Cross-host review lets the `plan-reviewer`, `code-reviewer`, `debugger`, and
`verifier` roles run on both the current host and the opposite host in parallel
when the opposite host is available, then have the current-host main agent
synthesize the two analyses into one result (a single verdict for the review
roles, a single root-cause direction for the debugger, and a single
union/conservative merged result for the verifier). When the opposite host is
unavailable in default mode, the same synthesis runs over the Same-Host Parallel
Fallback (two same-host agents) instead of a single pass. It reuses the Fusion
Rescue cross-host mechanism; it is not a new channel, daemon, background job,
weight fusion, or hidden runtime.

This is a platform-neutral contract. For the actual invocation (how the current
host reaches the opposite host), the synchronous-response requirement, the
permission or capability preflight, and secret redaction, use the active
platform runtime document's `## Cross-Host Consult Channel` section. Do not
hard-code host binaries, plugin or capability names, or permission states here.

## When It Applies

Cross-host review applies wherever a skill dispatches `plan-reviewer`,
`code-reviewer`, `debugger`, or `verifier`:

- `plan-reviewer`: `ralplan` (consensus plan review), `ralph` (completion-
  evidence review), `ultrawork` (final validation), `systematic-debugging`
  (direction escalation).
- `code-reviewer`: `ralph` (review gate), `systematic-debugging` (post-fix),
  `verification-before-completion` (risk-gated), `ultrawork` (final validation).
- `debugger`: `systematic-debugging` (root-cause investigation). Dual-host is
  the default for the debugger, not only an escalation.
- `verifier`: `verification-before-completion` (completion-evidence
  verification), `ralph` (acceptance-evidence packaging), `ultrawork` (final
  validation), `systematic-debugging` (post-fix validation). Same default and
  require-cross-host behavior as the review roles.

It does not apply to `simplify`, which only recommends `code-reviewer` and never
dispatches it, nor to any other role. The `executor`, `explore`, `analyst`,
`planner`, and `fusion-rescue-analyst` roles are out of scope for cross-host
review.

## Activation

Default mode (auto): when the opposite host is available per the active
platform's `## Cross-Host Consult Channel` rules, run the review on BOTH the
current host and the opposite host. When the opposite host is unavailable,
unproven, or its response cannot be collected, run the Same-Host Parallel
Fallback (see below) — two same-host agents in parallel under distinct
complementary lenses, synthesized by the current-host main agent, and record a
fallback note. A host without the opposite host installed still gets a complete,
synthesized review, not a single pass.

require-cross-host mode (opt-in): when the caller or user explicitly requests
require-cross-host, the review blocks if the opposite host cannot be reached.
The blocking output names which host was required, what was attempted, the
failure class, and the next local fallback the user can approve.

Cross-host review activates only when the opposite host is actually available,
which bounds the added cost and latency to dual-host installs.

## Full Review Per Host

Each host runs the COMPLETE role review independently — not a split of lenses:

- `plan-reviewer`: both ordered passes (pass 1 architecture lens, pass 2
  quality-gate lens) on each host.
- `code-reviewer`: both lenses (correctness and maintainability first, then the
  security lens via the Safety Trigger Checklist) on each host.
- `debugger`: the full root-cause investigation (reproduce, form hypotheses,
  identify root cause, recommend the minimal fix) on each host.
- `verifier`: the full verification (map the claim to evidence, run or inspect
  the required checks, apply the scenario lens) on each host.

Do not assign one lens or one investigation step to the current host and a
different one to the opposite host; each host produces its full analysis. The
same "full role per agent" rule applies to the two agents of the Same-Host
Parallel Fallback.

## Same-Host Parallel Fallback

When the opposite host is unavailable in default mode, the review does not collapse
to a single pass. The current-host main agent instead dispatches exactly two
same-host agents of the SAME role in parallel, each running the COMPLETE role, and
synthesizes their two analyses into one result using the same judge rules as the
cross-host synthesis below. The two same-host agents differ ONLY by a stance/lens
EMPHASIS — each still runs every lens, pass, or investigation step its role
requires (the Full Review Per Host rule applies to each same-host agent). It is
same-host fan-out, not a cross-host hop (see Recursion Guard).

Stance/lens pairs (emphasis only — both agents always run the full role):

| Role | Lens A (same-host agent 1) | Lens B (same-host agent 2) |
|---|---|---|
| `plan-reviewer` | strongest-antithesis / feasibility-risk emphasis ("why this plan fails or is infeasible") | acceptance-coverage / quality-gate completeness emphasis ("which acceptance criteria or gates are unmet") |
| `code-reviewer` | adversarial correctness + security skeptic ("what breaks or is exploitable") | maintainability + coverage completeness ("what is missing or regresses") |
| `debugger` | leading-hypothesis-A angle | competing-hypothesis-B angle (feeds the competing-hypotheses synthesis) |
| `verifier` | adversarial emphasis: "find how the claim is false or unmet" | coverage emphasis: "map every acceptance criterion to evidence" |

Both `verifier` agents perform the full acceptance-to-evidence mapping AND the
adversarial false-or-unmet check; Lens A and Lens B only change which one they
lead with.

## Parallel Execution And Synthesis

The current-host analysis and the opposite-host analysis run in parallel against
the same artifact or problem: the exact Planner draft for `plan-reviewer`, the
same stable diff for `code-reviewer`, the same failure, reproduction, and
evidence packet for `debugger`, or the same completion claim, acceptance
criteria, and evidence for `verifier`.

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
  for direction-level or unsalvageable failure.
- `code-reviewer`: return the merged, provenance-tagged findings to the caller.
- `debugger`: the judge synthesizes a single root-cause direction — competing
  hypotheses, the evidence that decides between them, and the smallest next
  diagnostic or fix step — and returns it to `systematic-debugging`. The
  debugger does not emit a findings-verdict; `systematic-debugging` remains
  responsible for reproduction, causal-chain closure, fix evidence, and
  verification-before-completion.
- `verifier`: the judge produces ONE merged verification result. For the merge,
  union the evidence from both verifier results into a single
  acceptance-to-evidence mapping, deduplicated per criterion, with host or
  same-host-lens provenance per evidence item. For each acceptance criterion, if
  both results agree use that judgment; if they DISAGREE, resolve conservatively —
  treat the criterion as unmet if either result says unmet — so the per-criterion
  `Acceptance criteria status` line reads `unmet`. Surface every disagreement ONLY
  on a separate top-level `Acceptance inconsistency: <criteria>` line that lists
  each criterion where the two results disagreed, and escalate; the caller does
  not silently treat an inconsistent criterion as met. The merged result keeps the
  verifier's normal output fields (tier, acceptance criteria status,
  acceptance-to-evidence mapping, residual risk) plus that one inconsistency line.
  `inconsistent` never appears on the per-criterion status line, so existing gate
  parsing is unaffected.

A cross-host finding that would change the approved direction must surface as
`requested-direction-change: yes`; it is never auto-incorporated. The
`plan-reviewer` no-replacement and Direction Preservation rules stay in force:
cross-host findings never silently override the user-approved spec, plan
direction, scope, non-goals, or acceptance criteria.

## Sequencing Preserved

Cross-host review does not change role ordering. For `ralplan`, the sequential
`Analyst -> Planner -> Plan-Reviewer` order is preserved and Plan-Reviewer still
runs only after the Planner draft exists. What is new is that the two reviewer
INSTANCES of the SAME reviewer role (current-host and opposite-host) may run
concurrently once the draft exists; this does not violate the rule that the
distinct Analyst, Planner, and Plan-Reviewer roles are not run in parallel.

## Reuse Of The Cross-Host Mechanism

The cross-host review consult reuses the Fusion Rescue mechanism via the active
platform runtime document's `## Cross-Host Consult Channel` section:

- Send a panel-style packet: the assigned work is the role's full review or
  investigation contract; the problem packet is the exact Planner draft
  (plan-reviewer), the stable diff (code-reviewer), or the failure/reproduction/
  evidence packet (debugger).
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
- A reviewer, debugger, or verifier MUST NOT make any cross-host call beyond the
  single assigned consult, and MUST NOT call back to the origin host or a third
  host. This cross-host block applies transitively: a same-host subagent — or a
  Same-Host Parallel Fallback agent — spawned by a reviewer, debugger, or verifier
  inherits the same no-further-cross-host-hop rule.
- The review consult is one cross-host hop. The current host must not call the
  opposite host and allow that host to call back into the current host or
  another host.
- Same-host read-only analysis stays non-mutating: no edits, writes, installs,
  or mutating commands from a review consult beyond producing the assigned
  review.

## Fallback Notes

Record a cross-host review fallback note whenever the opposite host is not used:
state whether it was unavailable, unproven, or returned no valid review, and that
the review ran via the Same-Host Parallel Fallback (two same-host agents
synthesized) in default mode rather than as a single current-host pass. In
require-cross-host mode, block instead of degrading and name the failure class
plus the next local fallback. Record only the failure class,
command/plugin/capability name, and path or auth status — never secret values,
config contents, or environment dumps.
