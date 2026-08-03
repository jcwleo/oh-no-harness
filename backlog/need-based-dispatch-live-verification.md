# Retired natural dispatch verification and deferred host-crossing work

**Status:** natural maintainer coverage retired; two independent host-crossing
follow-ups remain deferred.

Task #51 removed the model-bearing natural SessionStart routing suite, its prompt
matrix, role/topology instrumentation, and specialized Ralplan, Parallel,
Simplify, worktree, and exhaustive-agent live paths. Those tests were expensive,
brittle, and duplicated the smaller direct proof now used by the maintainer
harness: direct skill invocation, wrapper identity/read evidence, one exact core
invariant, and no project mutation.

This is a test-design retirement only. Runtime natural routing, SessionStart
bootstrap behavior, skill descriptions, role guidance, Fusion Rescue behavior,
and M88 launcher-recognition semantics were not removed or changed.

## Historical findings no longer carried as runtime defects

The old natural suite produced several failures and corrections:

- Claude's stale post-activation read-position requirement was an oracle defect
  fixed by `ac508df`.
- Codex child activity lives in parent-linked rollout files rather than the
  parent `exec --json` stream; the receiver/parent metadata and child-command
  parser correction in `467ca98` remains valid shared evidence handling.
- The earlier claim that Codex hallucinated a repository read, or that
  `<multi_agent_mode>` suppression prevented dispatch, was retracted after the
  child transcript proved the spawn and read.
- Natural Simplify typed-role/3+1 scheduling, Parallel role-label ambiguity,
  Ralplan parent-finalization timeout, and the broad natural prompt matrix are
  retired with the removed topology/narration test design. They are not tracked
  as product/runtime defects.
- Old exact packet shapes, heading checks, marker bags, trace ordering, and
  performance/capacity assertions are likewise retired as maintainer gates.

The removed `--natural-session-start-live`, `--deep-live`, `--parallel-live`,
`--ralplan-live`, `--named-agents-live`, `--simplify-live`, `--worktree-live`,
`--model-diversity-live`, `--parallel-executor-live`, and `--live-hook-only`
commands must not be restored as compatibility aliases.

## Deterministic evidence retained

- static plugin/manifests and public-skill inventory;
- source/generated freshness and skill reachability;
- hook exact-set and platform separation;
- active installed-plugin identity and lifecycle;
- cloned Codex home, config/auth immutability, and source-checkout containment;
- credential/secret scanning;
- command/result correlation and parser safety needed by the remaining direct or
  deferred paths;
- offline configure-subagents transaction and isolation checks.

## Open deferred work

### Cross-host substantive-read evidence

The Cross-host fallback transport/parser surface remains explicit and opt-in,
but is not expanded or run while Claude-host credits are unavailable. A future
bounded task may verify that each reviewer performs and retains a substantive
read tied to the exact target and that the parent synthesis consumes it. This is
not a request to restore the natural routing or topology suite.

### Fusion Rescue provider-credit validation

Fusion Rescue runtime behavior remains, but there is no maintainer CLI path to
launch it. The provider-limited classifier, permission fallback, secret scan,
correlation, and M88 semantic launcher recognition remain as deterministic source
coverage. A semantic live verdict is deferred because Claude-host provider credits
are exhausted. Deferred evidence is never reported as an ordinary skill PASS.

## Current maintainer direction

Use deterministic gates for ordinary changes. If model evidence is applicable,
invoke only the affected public skill directly and request its single stable
`Invariant:` enum. Full direct `--live` is reserved for release candidates,
broad shared-contract changes, or explicit broad validation. Do not recreate
plans, specs, worktrees, subagent fleets, or natural routing scenarios in a
maintainer smoke.
