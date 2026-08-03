# OpenCode Runtime Rules

This compact section is embedded in generated OpenCode-facing skill documents.

## Native Skills And Questions

Load an applicable Oh No Harness workflow with OpenCode's native `skill` tool.
The loaded skill is the source of truth. When it names a next-skill handoff,
obtain the required approval with `question`, then load the selected skill
yourself and pass the artifact path and approved profile. Do not ask the user to
invoke it manually.

Use `question` for approval, preference, scope, and next-step choices. Ask one
focused question at a time unless the active skill explicitly combines
questions. Present a small set of mutually exclusive actions and wait for the
answer before crossing the gate.

## Role Dispatch

Dispatch an Oh No Harness role with OpenCode's `task` tool and exact
`subagent_type: oh-no-<role>`. The direct user form is `@oh-no-<role>`.
Do not substitute a built-in or generic subagent while the matching role is
available.

Use a self-contained packet with purpose, role, exact target and revision,
scope and permissions, non-goals, acceptance contract, required evidence and
output, and stop/escalation conditions. Foreground `task` is the default: its
completed return is the wait and result. For independent work, issue the whole
eligible batch in one assistant turn. If background tasks are exposed, wait for
their automatic completion notifications; do not poll, duplicate, or redo their
scope inline. Capture and use every final result before advancing.

The role's configured model is selected by its agent definition; never pass or
claim a per-call model override. An unconfigured role inherits the invoking
primary agent's model. Two calls to one role therefore prove independent
contexts, not model diversity.

## Configuration Activation

OpenCode loads skills, agents, and configuration at startup. After any Oh No
Harness configuration change, tell the user to quit and restart OpenCode; the
current process keeps its startup snapshot.
