# Test Harness Lanes

This reference is the deterministic contract for Oh No Harness local smoke,
live, deep-live, release/static, validator, and reachability lanes. It defines
what each lane owns, which failures are hard, which model-output differences are
non-gating warnings, and which signals are evidence limitations rather than
proof.

Codex live lanes that create a disposable `CODEX_HOME` must begin by cloning
the active runtime configuration: `config.toml`, available authentication/config
JSON, and the complete `agents/*.toml` directory. Plugin installation, agent
freshness updates, proof instrumentation, and session creation then occur only
inside the clone. Do not synthesize a reduced positive-test config because that
changes selector and custom-role behavior. An explicit negative control may
remove one copied capability inside its clone after this baseline is created;
it must not mutate the active home.

This is the default for every present and future isolated Codex live lane, not a
Ralplan-only exception. `clone_codex_live_home` verifies the copied config files
and complete agents tree against the active source before the lane may mutate
the clone. The clone must be physically independent and symlink-free; its
provenance records the active source manifest without copying secret values into
test evidence. Every isolated live-test function is registered in
`ISOLATED_CODEX_LIVE_FUNCTIONS`, may launch commands only through
`run_in_verified_codex_live_home`, and rechecks the active config/agent manifest
before and after each command. The static lane contract rejects direct
`CODEX_HOME=...` assignments regardless of quoting or variable-expansion form
across every model-launch helper whose name contains `live` and `test`, not just
registered isolated lanes or functions ending exactly in `_live_test`.
Non-isolated live launches use `run_codex_live_command`, which permits only the
initially selected active home or a clone carrying verified provenance; an
unregistered future-lane mutation and an unverified-home runtime fixture guard this boundary.
Fixture-only installer/unit tests that do not launch a live Codex model remain
synthetic by design.

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
      "evidence_artifact": "Codex JSON event stream plus private typed-role payload proof demonstrating exact Planner handoff into one single-round mode-selected Plan-Reviewer topology from a disposable CODEX_HOME cloned from the active config and agent TOMLs; the instrumented path records `same-host-perspective-pair`, while the natural path permits 1-2 typed Plan-Reviewer sessions only and proves two parallel typed legs with parent pair synthesis, one typed leg plus opposite-host review evidence with parent pair synthesis, or one typed leg under a recorded STANDARD `single-reviewer` topology; an unrecorded lone reviewer still fails, and on ITERATE the per-blocker finding→fix mapping is read from the parent Plan Approval Brief mapping section for the relocated `Applied change` and `Body section pointer` fields while `Disposition` and `Blocking basis` remain bound to the v2 plan body; cleanup outcome is recorded, with legacy lifecycle proof retained when those events are visible",
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
      "evidence_artifact": "Codex JSON event stream proving a named THOROUGH broad-diff trigger expands the combined cleanup default into four cleanup-angle subagents or compliant fallback blocks",
      "non_proofs": [
        "marker-only output",
        "single generic cleanup review without a recorded combined-default or expansion trigger",
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
        "containment",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [
        "auto-routing model echo"
      ],
      "evidence_artifact": "Codex wrapper activation/read, workflow-specific first gate, adjacent-route negatives, and mutation/approval boundaries",
      "non_proofs": [
        "marker-only output",
        "SessionStart text echo alone",
        "model self-report alone",
        "exact worker sequence alone"
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
      "evidence_artifact": "Claude plugin install/update, manifest validation, generated-wrapper checks, command and hook/static output, and the deterministic configure-subagents transaction/fault, lock-serialization, journal-trust, byte-exact, and SessionStart-reapply suite run offline by scripts/test-configure-subagents.sh",
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
      "evidence_artifact": "Claude stream-json output proving exact Planner handoff into one single-round THOROUGH perspective-diverse Plan-Reviewer pair: the planner leg completes before both typed `plan-reviewer` legs are dispatched in one parallel batch ahead of either result, all three role payloads carry the same Active plan contract block, both reviewer packets carry the exact captured Planner draft and differ only on their two distinct `Assigned perspective` lens lines, each reviewer output anchors one reviewed draft id back to that captured draft, and the caller closes with the single-round success marker; the lane hard-fails on anything other than exactly two Plan-Reviewer packet bodies, so it does not cover the STANDARD `single-reviewer` topology, and it exercises only the non-blocking-only v1 approval path with no Planner revision, so it proves no per-blocker finding→fix mapping",
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
        "hook policy",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [],
      "evidence_artifact": "Claude stream-json output proving three parallel fusion-rescue-analyst panels use identities resolved from the injected model-diversity block: a configured native secondary takes exactly two explicit override slots, the third slot uses a distinct top-tier identity through an explicit native override or the declared-frontmatter primary, all panels return results, and the host synthesizes them",
      "non_proofs": [
        "marker-only output",
        "model self-report alone",
        "panel count without model-assignment proof",
        "identity inferred from an unknown host default"
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
        "hook policy",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [],
      "evidence_artifact": "Claude stream-json output proving that no valid secondary model yields exactly two independent same-model code-reviewer instances with same-model-parallel-fallback recorded, while require-model-diversity transitions to PAUSED instead of falling back",
      "non_proofs": [
        "marker-only output",
        "single reviewer pass",
        "model self-report alone",
        "two dispatches without fallback-ledger and strict-mode proof"
      ]
    },
    {
      "host": "claude",
      "owner": "scripts/test-claude-plugin.sh",
      "flag": "--model-diversity-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load",
        "command invocation",
        "tool/permission",
        "lifecycle",
        "hook policy",
        "containment",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [
        "live-model concurrency compliance"
      ],
      "evidence_artifact": "Claude stream-json output proving the real isolated-preferences to canonical resolver to SessionStart model-diversity block to Ralph Review Gate path: exactly two same-role code-reviewer dispatches receive raw packets with two distinct role-appropriate `Assigned perspective:` values and no divergence beyond that line, then compare equal after normalizing the `Assigned perspective:` line, model override, leg-identity labels, and dispatch-meta lines; the declared stored primary leg is unoverridden, the distinct native secondary leg has an explicit override, both return results, model-diversity-pair is recorded, and the caller emits a substantive synthesized verdict; lifecycle overlap is recorded as an advisory, non-gating live-model concurrency signal",
      "non_proofs": [
        "marker-only output",
        "model self-report alone",
        "two serial reviewer dispatches",
        "pair output without injected-block, packet-equality, override, ledger, and synthesis proof"
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
      "evidence_artifact": "Claude stream-json output plus disposable repo diff proving AC-OVERLAP-1 and its no-new-scheduler/state-machine/protocol/oracle non-goals survive executor packets and final summary while the existing disjoint executor eligibility owner drives overlap and per-executor scope checks",
      "non_proofs": [
        "marker-only output",
        "model self-report alone",
        "broad command success alone"
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
      "evidence_artifact": "Claude stream-json output proving a named THOROUGH broad-diff trigger expands the combined cleanup default into four cleanup-angle subagents or compliant fallback blocks",
      "non_proofs": [
        "marker-only output",
        "single generic cleanup review without a recorded combined-default or expansion trigger",
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
        "containment",
        "malformed output",
        "forensic invariant"
      ],
      "warnings": [
        "auto-routing model echo"
      ],
      "evidence_artifact": "Claude wrapper activation/read, workflow-specific first gate, adjacent-route negatives, and mutation/approval boundaries",
      "non_proofs": [
        "marker-only output",
        "SessionStart text echo alone",
        "model self-report alone",
        "exact worker sequence alone"
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
warning. The `--model-diversity-live` lifecycle-overlap observation is advisory
live-model concurrency compliance and does not waive its other lifecycle or
forensic gates. `VARIANCE` is a subset of `WARN`, limited to model paraphrase
variance, semantic marker variance, AskUserQuestion tool-list exposure,
auto-routing model echo, or a post-completion observation gap after stronger
lifecycle evidence has already passed.

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
