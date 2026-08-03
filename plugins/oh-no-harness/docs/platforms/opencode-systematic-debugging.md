# Systematic Debugging OpenCode Adapter

<ADAPTER_CONTRACT>
This adapter binds the Systematic Debugging core to OpenCode. The core owns
semantic decisions; this file owns approvals, dispatch, waits, result intake,
and handoffs. The generated core plus this adapter is self-contained.
</ADAPTER_CONTRACT>

## Dispatch And Intake

After the core trigger and hypothesis ledger exist, call `task` with exact
`subagent_type: oh-no-<role>` for `debugger`, `explore`, `executor`, `verifier`,
or `code-reviewer`; direct user mentions use `@oh-no-<role>`. Pass the
core-defined role envelope and debugging delta unchanged, including exact
reproduction, revision, scope, evidence targets, output, and stop conditions.

Issue independently testable hypothesis debuggers in one assistant turn, one
hypothesis per packet, with all other hypotheses and expected conclusions
withheld. Foreground `task` return is the wait and result. For background work,
wait for automatic completion notifications and never poll, duplicate, or redo
pending scope. Capture every final result before synthesis. If a non-review role
is unavailable, use the core's recorded inline fallback; an independently
required review or verifier remains blocked rather than becoming inline.

Confirmed fixes use `oh-no-executor` by default. Post-fix review and verifier
tasks run only when their core predicates fire and remain separate from the
maker. A selected same-role pair is issued in one turn with packets differing
only by `Assigned perspective:`. A verifier is never paired.

## Model State

OpenCode has no per-task model override. A configured role uses its stored exact
provider/model ID; an unconfigured role inherits the invoking primary model.
Same-role parallel tasks prove context independence only. Record selected pairs
as same-model perspective pairs and never claim model diversity; strict
model-diversity demand PAUSES.

## Questions And Handoffs

Use `question` when reproduction data, a direction change, rescope, or user
approval is required. When diagnostics stall and the core permits escalation,
load `fusion-rescue` with native `skill`, then return its synthesis here. Load
`test-driven-development` or `verification-before-completion` through `skill`
only at their named internal gates. After verification, return to the caller or
report the direct result; do not chain to a new workflow.
