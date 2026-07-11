# Mandatory Gate Inventory

This maintenance registry supplies one complete governance row per existing
`<HARD-GATE>`. The proposal schema and runtime policy remain canonically owned
by `docs/shared/execution-modes.md`; runtime skills do not preload this registry.

| Gate ID | Canonical owner | Trigger | Modes | Added cost | Evidence benefit | Not-applicable path | Retirement / merge | Duplicate check |
|---|---|---|---|---|---|---|---|---|
| HG-interview-handoff | interview | spec written | all | one user choice | prevents silent workflow chaining | none | merge if handoff owner replaces it | unique |
| HG-ralplan-handoff | ralplan | plan presented | all | approval plus next-step choice | prevents unapproved execution | ultrawork owns automatic approval | merge if handoff owner replaces it | unique |
| HG-ralph-worktree | ralph | write-capable task | all | one recorded decision | protects user checkout | read-only task | merge into host isolation gate | unique |
| HG-ralph-persistence | ralph | completion claim | STANDARD, THOROUGH | ledger audit | prevents missing completion evidence | LIGHT not-required records | merge into VBC when session ownership converges | unique |
| HG-ultrawork-report | ultrawork | final report | all | phase-ledger audit | prevents skipped orchestration phases | none | merge into Ralph when no orchestration delta exists | unique |
| HG-vbc-evidence | verification-before-completion | completion claim | all | fresh evidence pass | prevents stale or unmapped claims | none | canonical completion owner | unique |
| HG-debug-output | systematic-debugging | investigation output | STANDARD, THOROUGH | topology record | prevents unlabeled review evidence | no review dispatched | merge into caller completion gate for mid-loop use | unique |
