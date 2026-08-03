# Ralph OpenCode Adapter

<ADAPTER_CONTRACT>
This adapter binds the Ralph core to OpenCode. The core owns semantic
decisions; this file owns approvals, dispatch, waits, result intake, and
handoffs. The generated core plus this adapter is self-contained.
</ADAPTER_CONTRACT>

## Role Dispatch

Use `task` with exact `subagent_type: oh-no-<role>`; direct user mentions use
`@oh-no-<role>`. An approved Ralplan handoff authorizes eligible isolated roles
without another subagent approval. Dispatch only roles whose results can change
implementation, review, verification, or the ship/block decision.

STANDARD and THOROUGH repository work-product mutation dispatches
`oh-no-executor`, including REVIEW-to-EXECUTE focused fixes, even when no
concurrent batch exists. Inline mutation is limited to the core's recorded
LIGHT-tiny or confirmed task-unavailable fallback.

Send the core packet plus exact target/revision, write ownership, result/revision
binding, evidence, output envelope, and stop conditions. Issue independent
read-only roles and disjoint executors in one assistant turn, at most five at a
time. Foreground `task` return is the wait and final result. For background
tasks, wait for automatic completion notifications; do not poll, duplicate, or
redo their scope. Capture every result and changed-file set before advancing.

## Review And Verification

A fired review or verifier trigger always dispatches a separate context. The
default review uses one full-role `oh-no-code-reviewer`. Only a core-selected
perspective pair issues two reviewer tasks in one turn, with identical packets
except the single `Assigned perspective:` line. Complete and synthesize review
before a triggered `oh-no-verifier`; after a blocking-finding fix, bind the
verifier to the fixed revision and do not dispatch a reviewer recheck.

OpenCode has no per-task model override. Configured roles use their stored
provider/model IDs; unconfigured roles inherit the primary model. Two calls to
one reviewer role prove independent contexts, not model diversity. Record a
selected pair as `same-model-perspective-pair`; strict model-diversity demand
PAUSES because this binding cannot guarantee distinct identities.

If review or verifier dispatch is unavailable, report the independent-audit
blocker and remain PAUSED where the core requires separation. Other unavailable
roles use only core-permitted recorded fallbacks.

## Questions, Skills, And Completion

Use `question` and wait whenever the core requires worktree choice, scope or
direction approval, rescope, residual-risk acceptance, or another user-owned
decision. Never treat task permission or an approved role dispatch as approval
to change the Direction Contract.

Load Ralph's internal `test-driven-development`, `simplify`,
`systematic-debugging`, `verification-before-completion`, or `fusion-rescue`
step with native `skill` when its core trigger fires, then resume Ralph with the
returned result. These are loop internals, not user-facing chaining events.
Ralph is terminal after its final report and loads no next workflow skill.
