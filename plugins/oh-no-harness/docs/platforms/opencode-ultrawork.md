# Ultrawork OpenCode Adapter

<ADAPTER_CONTRACT>
This adapter binds the Ultrawork core to OpenCode. The core owns semantic
decisions; this file owns approvals, dispatch, waits, result intake, and
handoffs. The generated core plus this adapter is self-contained.
</ADAPTER_CONTRACT>

## Skill Chain

Load `interview`, `ralplan`, and `ralph` through native `skill` with the current
artifact path and phase delta. Their loaded documents are source of truth; do
not restate them in the handoff packet. Ultrawork suppresses between-phase
next-skill questions, not Interview's content approval or any named pause gate.
Use `question` for those approvals and for direction or scope changes, then wait
for the answer.

## Phase Roles

When a phase trigger fires, dispatch with `task` and exact
`subagent_type: oh-no-<role>`; the direct user form is `@oh-no-<role>`. Pass the
core role envelope and phase delta, including target/revision, ownership,
acceptance, evidence, output, and stop conditions. STANDARD and THOROUGH
mutation uses `oh-no-executor`; independent review and audit never run inline.

Issue each independent batch in one assistant turn, up to five tasks.
Foreground task return is the wait and final result. If background tasks are
available, wait for their automatic completion notifications and do not poll,
duplicate, or redo their work. Capture each result and changed-file set before
the dependent gate. Record a core-permitted fallback on unavailable optional
roles; required independent roles block.

## Final Validation Models

The default Final Validation review uses one full-role
`oh-no-code-reviewer`. A core-selected perspective pair issues two reviewer
tasks in one turn with identical packets except `Assigned perspective:`, then
synthesizes both before any triggered verifier.

OpenCode has no per-task model override. A configured reviewer uses its stored
provider/model ID; an unconfigured reviewer inherits the primary model.
Same-role tasks are not model-diversity evidence. Record
`same-model-perspective-pair`; strict model-diversity demand PAUSES rather than
making a false diversity claim.

## Worktrees And Activation

Use ordinary `git worktree add .oh-no/worktrees/<task-slug> -b <branch>` from
the integration checkout and inspect with
`git -C .oh-no/worktrees/<task-slug> status`. Remove the worktree only after
integration and post-merge verification. OpenCode configuration changed during
the run takes effect only after quitting and restarting OpenCode.
