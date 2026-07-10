# Test Harness Lanes

This reference is the deterministic contract for Oh No Harness local smoke,
live, deep-live, release/static, validator, and reachability lanes. It defines
what each lane owns, which failures are hard, which model-output differences are
non-gating warnings, and which signals are evidence limitations rather than
proof.

The JSON matrix below is parsed by `scripts/test-harness-lane-contract.py` and
`scripts/validate-plugin-files.py`.

```json
{
  "schema_version": 1,
  "lanes": [
    {
      "host": "codex",
      "owner": "scripts/test-codex-plugin.sh",
      "flag": "default",
      "release_status": "release-static",
      "hard_failures": [
        "install/load",
        "manifest/source assertion",
        "generated-wrapper freshness",
        "hook policy"
      ],
      "warnings": [],
      "evidence_artifact": "Codex marketplace install, manifest validation, generated-wrapper checks, prompt exposure, hook/static output",
      "non_proofs": [
        "marker-only output",
        "live model smoke",
        "reachability count alone"
      ]
    },
    {
      "host": "codex",
      "owner": "scripts/test-codex-plugin.sh",
      "flag": "--live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "malformed output"
      ],
      "warnings": [],
      "evidence_artifact": "codex exec output and last-message artifact for public skill smoke prompts",
      "non_proofs": [
        "marker-only output",
        "semantic paraphrase alone",
        "broad command success alone"
      ]
    },
    {
      "host": "codex",
      "owner": "scripts/test-codex-plugin.sh",
      "flag": "--deep-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "malformed output",
        "manifest/source assertion"
      ],
      "warnings": [
        "model paraphrase variance",
        "semantic marker variance"
      ],
      "evidence_artifact": "deep-live last-message artifact plus deterministic reachability/static support checks",
      "non_proofs": [
        "marker-only output",
        "exact semantic marker alone",
        "reachability count alone"
      ]
    },
    {
      "host": "codex",
      "owner": "scripts/test-codex-plugin.sh",
      "flag": "--parallel-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [],
      "evidence_artifact": "Codex JSON event stream proving spawn, wait, capture, and close lifecycle",
      "non_proofs": [
        "marker-only output",
        "model self-report alone",
        "broad command success alone"
      ]
    },
    {
      "host": "codex",
      "owner": "scripts/test-codex-plugin.sh",
      "flag": "--ralplan-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [],
      "evidence_artifact": "Codex JSON event stream proving Analyst to Planner to Plan-Reviewer sequencing",
      "non_proofs": [
        "marker-only output",
        "model self-report alone",
        "broad command success alone"
      ]
    },
    {
      "host": "codex",
      "owner": "scripts/test-codex-plugin.sh",
      "flag": "--named-agents-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [
        "post-completion observation gap"
      ],
      "evidence_artifact": "Codex JSON event stream proving agent_type=oh-no-* dispatch and lifecycle",
      "non_proofs": [
        "marker-only output",
        "post-completion text alone",
        "model self-report alone"
      ]
    },
    {
      "host": "codex",
      "owner": "scripts/test-codex-plugin.sh",
      "flag": "--fusion-rescue-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "host-boundary",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [],
      "evidence_artifact": "Codex JSON event stream plus role-owned Claude consult argv and returned panel marker",
      "non_proofs": [
        "marker-only output",
        "parent inline opposite-host answer",
        "launch notice without synchronous review"
      ]
    },
    {
      "host": "codex",
      "owner": "scripts/test-codex-plugin.sh",
      "flag": "--cross-host-fallback-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "host-boundary",
        "containment",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [],
      "evidence_artifact": "Codex JSON event stream proving opposite-host unavailable default and two same-host reviewer instances",
      "non_proofs": [
        "marker-only output",
        "single current-host pass",
        "parent inline opposite-host answer"
      ]
    },
    {
      "host": "codex",
      "owner": "scripts/test-codex-plugin.sh",
      "flag": "--simplify-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [],
      "evidence_artifact": "Codex JSON event stream proving four cleanup-angle subagents or compliant fallback blocks",
      "non_proofs": [
        "marker-only output",
        "single generic cleanup review",
        "model self-report alone"
      ]
    },
    {
      "host": "codex",
      "owner": "scripts/test-codex-plugin.sh",
      "flag": "--natural-session-start-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "hook policy",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [
        "auto-routing model echo"
      ],
      "evidence_artifact": "Codex JSON event stream with SessionStart role-worker dispatch and lifecycle evidence",
      "non_proofs": [
        "marker-only output",
        "SessionStart text echo alone",
        "model self-report alone"
      ]
    },
    {
      "host": "codex",
      "owner": "scripts/test-codex-plugin.sh",
      "flag": "--worktree-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "worktree",
        "containment",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [],
      "evidence_artifact": "Disposable-repo Git worktree list, output file evidence, and original checkout containment check",
      "non_proofs": [
        "marker-only output",
        "mkdir-only directory",
        "plain clone",
        "parent-directory sibling worktree"
      ]
    },
    {
      "host": "claude",
      "owner": "scripts/test-claude-plugin.sh",
      "flag": "default",
      "release_status": "release-static",
      "hard_failures": [
        "install/load",
        "manifest/source assertion",
        "generated-wrapper freshness",
        "hook policy"
      ],
      "warnings": [],
      "evidence_artifact": "Claude plugin install/update, manifest validation, generated-wrapper checks, command and hook/static output",
      "non_proofs": [
        "marker-only output",
        "live model smoke",
        "reachability count alone"
      ]
    },
    {
      "host": "claude",
      "owner": "scripts/test-claude-plugin.sh",
      "flag": "--live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "malformed output",
        "hook policy"
      ],
      "warnings": [
        "AskUserQuestion tool-list exposure",
        "auto-routing model echo"
      ],
      "evidence_artifact": "Claude JSON or stream-json output for public slash-command and hook-policy smoke prompts",
      "non_proofs": [
        "marker-only output",
        "semantic paraphrase alone",
        "broad command success alone"
      ]
    },
    {
      "host": "claude",
      "owner": "scripts/test-claude-plugin.sh",
      "flag": "--deep-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "malformed output",
        "manifest/source assertion"
      ],
      "warnings": [
        "model paraphrase variance",
        "semantic marker variance"
      ],
      "evidence_artifact": "Claude deep-live JSON artifact plus deterministic reachability/static support checks",
      "non_proofs": [
        "marker-only output",
        "exact semantic marker alone",
        "reachability count alone"
      ]
    },
    {
      "host": "claude",
      "owner": "scripts/test-claude-plugin.sh",
      "flag": "--parallel-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [],
      "evidence_artifact": "Claude stream-json event output proving Task/Agent dispatch, wait, capture, and cleanup",
      "non_proofs": [
        "marker-only output",
        "model self-report alone",
        "broad command success alone"
      ]
    },
    {
      "host": "claude",
      "owner": "scripts/test-claude-plugin.sh",
      "flag": "--ralplan-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [],
      "evidence_artifact": "Claude stream-json output proving Analyst to Planner to Plan-Reviewer sequencing",
      "non_proofs": [
        "marker-only output",
        "model self-report alone",
        "broad command success alone"
      ]
    },
    {
      "host": "claude",
      "owner": "scripts/test-claude-plugin.sh",
      "flag": "--fusion-rescue-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "host-boundary",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [],
      "evidence_artifact": "Claude stream-json output plus role-owned Codex rescue capability evidence",
      "non_proofs": [
        "marker-only output",
        "parent inline opposite-host answer",
        "launch notice without synchronous review"
      ]
    },
    {
      "host": "claude",
      "owner": "scripts/test-claude-plugin.sh",
      "flag": "--cross-host-fallback-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "host-boundary",
        "containment",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [],
      "evidence_artifact": "Claude stream-json output proving opposite-host unavailable default and two same-host reviewer instances",
      "non_proofs": [
        "marker-only output",
        "single current-host pass",
        "parent inline opposite-host answer"
      ]
    },
    {
      "host": "claude",
      "owner": "scripts/test-claude-plugin.sh",
      "flag": "--cross-host-review-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "host-boundary",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [],
      "evidence_artifact": "Claude stream-json output proving the opposite-host-available cross-host code-review pair: current-host oh-no-harness:code-reviewer plus opposite-host oh-no-harness:code-reviewer-codex dispatched concurrently, one read-only foreground codex-companion call, role-owned oh-no-code-reviewer, and one synthesized verdict",
      "non_proofs": [
        "marker-only output",
        "sequential (non-concurrent) reviewer dispatch",
        "parent inline opposite-host answer",
        "launch notice without synchronous review"
      ]
    },
    {
      "host": "claude",
      "owner": "scripts/test-claude-plugin.sh",
      "flag": "--ralplan-xhost-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "host-boundary",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [],
      "evidence_artifact": "Claude stream-json output proving the real ralplan flow dispatches the planner first, then the cross-host plan-review pair: current-host oh-no-harness:plan-reviewer plus opposite-host oh-no-harness:plan-reviewer-codex, one read-only foreground codex-companion call, role-owned oh-no-plan-reviewer, and one synthesized verdict",
      "non_proofs": [
        "marker-only output",
        "plan-review pair without the preceding planner",
        "parent inline opposite-host answer",
        "launch notice without synchronous review"
      ]
    },
    {
      "host": "claude",
      "owner": "scripts/test-claude-plugin.sh",
      "flag": "--vbc-xhost-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "host-boundary",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [],
      "evidence_artifact": "Claude stream-json output proving the real verification-before-completion flow dispatches the cross-host code-review pair (current-host oh-no-harness:code-reviewer plus opposite-host oh-no-harness:code-reviewer-codex, one read-only foreground codex-companion call, role-owned oh-no-code-reviewer) then exactly one self-host oh-no-harness:verifier with zero verifier-codex and zero cross-host verifier delegation",
      "non_proofs": [
        "marker-only output",
        "verifier dispatched as a cross-host pair or before the reviewer pair",
        "parent inline opposite-host answer",
        "launch notice without synchronous review"
      ]
    },
    {
      "host": "claude",
      "owner": "scripts/test-claude-plugin.sh",
      "flag": "--sysdebug-xhost-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "host-boundary",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [],
      "evidence_artifact": "Claude stream-json output proving the real systematic-debugging flow dispatches the cross-host debugger pair: current-host oh-no-harness:debugger plus opposite-host oh-no-harness:debugger-codex, one read-only foreground codex-companion call, role-owned oh-no-debugger, and one synthesized root-cause direction",
      "non_proofs": [
        "marker-only output",
        "single-host debugger without the opposite-host pair",
        "parent inline opposite-host answer",
        "launch notice without synchronous review"
      ]
    },
    {
      "host": "claude",
      "owner": "scripts/test-claude-plugin.sh",
      "flag": "--parallel-executor-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "containment",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [],
      "evidence_artifact": "Claude stream-json output plus disposable repo diff proving disjoint executor batch and per-executor scope check",
      "non_proofs": [
        "marker-only output",
        "model self-report alone",
        "broad command success alone"
      ]
    },
    {
      "host": "claude",
      "owner": "scripts/test-claude-plugin.sh",
      "flag": "--codex-executor-delegation-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "containment",
        "worktree",
        "host-boundary",
        "forensic invariant"
      ],
      "warnings": [],
      "evidence_artifact": "Claude stream-json output plus caller-owned integration-checkout and ignored-.oh-no escape-guard snapshots and a caller-derived worktree diff proving thin executor-codex delegation, raw companion output, caller guard clean, RED->GREEN with an unchanged RED file, executor-only negative+positive, sequential dispatch, and caller-mediated degrade fallback",
      "non_proofs": [
        "marker-only output",
        "model self-report alone",
        "positive-only writes-exist-in-worktree claim without a caller-owned escape guard",
        "caller escape guard relying only on git-status blind to the ignored .oh-no/ subtree"
      ]
    },
    {
      "host": "claude",
      "owner": "scripts/test-claude-plugin.sh",
      "flag": "--simplify-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [],
      "evidence_artifact": "Claude stream-json output proving four cleanup-angle subagents or compliant fallback blocks",
      "non_proofs": [
        "marker-only output",
        "single generic cleanup review",
        "model self-report alone"
      ]
    },
    {
      "host": "claude",
      "owner": "scripts/test-claude-plugin.sh",
      "flag": "--natural-session-start-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "hook policy",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [
        "auto-routing model echo"
      ],
      "evidence_artifact": "Claude stream-json output with SessionStart natural role-worker dispatch and lifecycle evidence",
      "non_proofs": [
        "marker-only output",
        "SessionStart text echo alone",
        "model self-report alone"
      ]
    },
    {
      "host": "claude",
      "owner": "scripts/test-claude-plugin.sh",
      "flag": "--live-hook-only",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "hook policy",
        "malformed output"
      ],
      "warnings": [
        "AskUserQuestion tool-list exposure",
        "auto-routing model echo"
      ],
      "evidence_artifact": "Claude stream-json hook-event output for SessionStart hook policy and auto-routing checks",
      "non_proofs": [
        "marker-only output",
        "hook text echo alone",
        "semantic paraphrase alone"
      ]
    },
    {
      "host": "static",
      "owner": "scripts/release",
      "flag": "default",
      "release_status": "default-static",
      "hard_failures": [
        "generated-wrapper freshness",
        "manifest/source assertion",
        "release default expansion"
      ],
      "warnings": [],
      "evidence_artifact": "release script static phase: generator checks, validator, manifest/version diff, and install tests when not skipped",
      "non_proofs": [
        "marker-only output",
        "live model smoke",
        "opt-in live lane success"
      ]
    },
    {
      "host": "static",
      "owner": "scripts/validate-plugin-files.py",
      "flag": "default",
      "release_status": "default-static",
      "hard_failures": [
        "generated-wrapper freshness",
        "manifest/source assertion",
        "reachability-contract",
        "hook policy"
      ],
      "warnings": [],
      "evidence_artifact": "validator stdout plus subprocess checks for generated wrappers and skill reachability",
      "non_proofs": [
        "marker-only output",
        "reachability count alone",
        "live model smoke"
      ]
    },
    {
      "host": "static",
      "owner": "scripts/check-skill-reachability.py",
      "flag": "default",
      "release_status": "default-static",
      "hard_failures": [
        "reachability-contract",
        "manifest/source assertion"
      ],
      "warnings": [],
      "evidence_artifact": "explicit wrapper plus shared-doc plus handoff graph text-bag reachability output",
      "non_proofs": [
        "marker-only output",
        "reachability count alone",
        "semantic correctness of all public skills"
      ]
    }
  ]
}
```

## Classification Semantics

`HARD` means nonzero exit or release blocker. Hard classes include install/load,
command invocation/resolution, tool/permission, lifecycle, malformed output,
host-boundary, containment, worktree, forensic invariant, hook policy,
generated-wrapper freshness, manifest/source assertion, reachability-contract,
and release default expansion.

`WARN` means exit 0 is allowed only when the lane row explicitly lists the
warning. `VARIANCE` is a subset of `WARN`, limited to model paraphrase variance,
semantic marker variance, AskUserQuestion tool-list exposure, auto-routing model
echo, or a post-completion observation gap after stronger lifecycle evidence has
already passed.

`NON_PROOF` means an evidence limitation. It must never upgrade a lane to proof:
marker-only output, exact semantic markers alone, broad command success alone,
live model smoke, and reachability count alone are not sufficient evidence for
hard-lane success.

## Reachability Boundary

Deterministically checked:

- Generated wrapper freshness.
- Explicit handoff graph references.
- Selected workflow rules reachable through source, manifest, generator, and
  wrapper paths.
- Validator assertions for public wrappers and manifests.

Intentionally excluded:

- Semantic correctness of all public skills.
- All natural-language routes.
- Incidental mentions.
- Opposite-host availability.
- Live model reliability.
- Full public support for every PUBLIC_SKILLS entry.

Requires user approval to expand:

- Making reachability cover every public skill.
- Adding new live lanes.
- Making live smoke release-default.
- Changing public support claims in docs, README, or marketplace manifests.
