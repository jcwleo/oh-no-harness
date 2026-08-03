# OpenCode Fusion Rescue Rules

This overlay follows the shared Fusion Rescue core and the OpenCode runtime.

## Panels

Issue exactly three `task` calls in one assistant turn with
`subagent_type: oh-no-fusion-rescue-analyst`. Each receives the same redacted,
read-only packet and exactly one distinct assigned lens: primary, adversarial,
or pragmatic. The direct user form is `@oh-no-fusion-rescue-analyst`.

Foreground task returns are the waits and final panel results. If background
mode is available, rely on automatic completion notifications; do not poll,
duplicate, or synthesize before all three results are captured. The main agent
is the judge and must use every panel result.

## Configuration State

OpenCode provides no per-task model override. When the role is configured, all
three panels use its one stored exact provider/model ID. When unconfigured, all
three inherit the invoking primary model. Neither case proves model diversity;
independent sessions and different lenses are perspective diversity only.

Record `same-model-parallel-fallback` and the applicable reason (`single
configured role model` or `unconfigured role inherited primary model`). Never
claim a model-diversity panel. If the caller requires model diversity, transition
to PAUSED and state that distinct runtime model identities cannot be guaranteed
by this binding.

No opposite-host consult is defined. Every packet retains the core recursion
guard, read-only boundary, and `fusion depth: 1`.
