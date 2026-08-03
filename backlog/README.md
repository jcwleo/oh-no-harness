# Oh No Harness Backlog

Deferred improvements that should be planned and implemented independently from
the current feature work.

## TODOs

- [Codex subagent protocol compatibility](./codex-subagent-protocol-compatibility.md)
  - Support both local custom-agent and hosted task-agent collaboration schemas
    without false role-ownership claims.
- [Direction-preserving review and complexity budgets](./harness-direction-and-review-budget.md)
  - Keep workflow validation proportional to the requested change through
    direction locks, complexity budgets, reduced review topology, and stop rules.
- [Subagent dispatch type-selection safety (Claude Code adapter)](./subagent-dispatch-type-safety.md)
  - Claude-Code-only: stop role dispatches from silently landing on a generic
    agent / parent model when `subagent_type` is omitted; reframe the Claude
    adapter's `OH_NO_SUBAGENT_ROLE_LABEL` / orchestration blocks (type-first) or
    add a Claude-only `PreToolUse` guard. Codex `spawn_agent` is unaffected.
- [Subagent dispatch model fidelity](./dispatch-model-fidelity.md)
  - **Open, 3 of 4 closed by `14e833e`.** A role dispatch must use exactly its
    configured `model:` value and never a substituted one; the sole exception is
    a prescribed model-diversity leg or panel, which must carry the explicit
    NATIVE override. Do not narrow that carve-out to review pairs — Fusion
    Rescue's panels and the paired `debugger` are neither. The rule now covers
    all nine roles and is pinned. Remaining: item 2, the five
    `claude-code-<skill>.md` overlays that still only describe the primary leg's
    no-override behavior instead of requiring it.
- [Ralplan reduction coverage gaps](./ralplan-reduction-coverage-gaps.md)
  - **Closed by `14e833e`.** Two reviewer-found, caller-reproduced durability
    gaps from the ralplan Opus 5 reduction, plus two unguarded AC-4 sub-changes.
    All four are now additive `BOTH` anchors in `REQUIRED["ralplan"]`; the board
    moved to codex 240 / claude 287. Kept as the historical record; the follow-up
    lives in the pin-depth item below.
- [Pin-depth gaps from the 2026-07-29 follow-up run](./pin-depth-gaps-20260729.md)
  - Four durability gaps the review round on `14e833e` reproduced with actual
    mutation probes: Claude-only clause placement is ungated, AC-5's `codex.md`
    paragraph is unguarded, AC-3's anchor pins the topic sentence rather than the
    `Worktree decision` carve-out, and nothing prevents re-adding the duplication
    AC-4 removed. None is a defect in what shipped. The first three are one
    additive string each; the fourth needs a real detector.
- [Retired natural dispatch verification and deferred host-crossing work](./need-based-dispatch-live-verification.md)
  - **Natural model-suite coverage retired by task #51.** Historical failures in
    natural routing, role topology, Simplify scheduling, and Ralplan finalization
    belonged to the removed maintainer test design and are not runtime defect
    claims. Static/reachability and direct-invocation invariant checks remain.
    Still open only where independently substantive: Cross-host reviewer
    substantive-read evidence and Fusion Rescue provider-credit validation.
- [Review packet lightening](./review-packet-lightening.md)
  - Stop review packets from converting a bounded requirements question into an
    unbounded search: drop investigation-path instructions, role-core duplicates,
    and constraint restatements; keep incident context. Covers both plan review
    and code review.

Each backlog item is a proposal only. Moving an item into implementation should
start with a fresh scope decision and must not silently join unrelated active
work.
