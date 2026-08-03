# Interview OpenCode Adapter

<ADAPTER_CONTRACT>
This adapter binds the Interview core to OpenCode. The core owns semantic
decisions; this file owns approvals, dispatch, waits, result intake, and
handoffs. The generated core plus this adapter is self-contained.
</ADAPTER_CONTRACT>

## Explore Dispatch

Only after the core's brownfield trigger fires, call `task` with
`subagent_type: oh-no-explore`, a short description, and a self-contained
read-only packet containing run/phase, bounded questions, owned subsystem, path
context, and required fact output. The direct user form is
`@oh-no-explore`.

Issue independent subsystem tasks in one assistant turn. Foreground task return
is the wait and final result. If background mode is available, wait for each
automatic completion notification and do not poll or duplicate work. Capture
every result before asking questions that depend on it. If the role is
unavailable, explore inline and record the fallback reason.

## Questions And Approval

Use `question` for each focused interview decision. Refine Confirmation may put
the confirmation and next interview question in one call; otherwise ask them
sequentially. Auto-confirm notices are ordinary prose, not blocking questions.

For approval Phase 1, use `question` for the free-text spec review and wait. For
Phase 2, use one `question` call with the core's four actions. After explicit
selection, load the chosen installed skill with `skill` and provide the spec
path. Under Ultrawork, return the approved spec and control after Phase 1 with no
second prompt.
