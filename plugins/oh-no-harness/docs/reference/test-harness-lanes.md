# Test Harness Lanes

This reference defines the maintainer test surface. It governs repository
maintenance only; it does not change runtime routing, skill descriptions, or
workflow behavior.

## Policy

Deterministic offline gates remain strict for manifests, generated-wrapper
freshness, hook shape, installation identity, configuration/auth immutability,
secret scanning, source-checkout containment, lifecycle, and command/result
correlation.

OpenCode has one default deterministic source-runtime lane and one default npm
package lane. The source lane loads the plugin under isolated XDG and `OH_NO_CONFIG_DIR` roots and
uses real, serial OpenCode commands without provider credentials. It has no
live, model, or dispatch option. The lane binds real host discovery to exact
generated inventories, defaults, permissions, custom-tool publication, legacy
CLI non-writing, restart behavior, and project immutability. The focused
preference test separately proves writer failure atomicity and post-publication
durability status. Raw marker-only host output remains
non-proof on its own, including the potentially truncated `debug skill` output.
The package lane creates the exact npm tarball, asserts its OpenCode-only file
inventory, installs it without lifecycle scripts, verifies package resolution
and its default export, then reruns the source lane against that installed
artifact. Registry availability remains a separate post-publish check.

Model-bearing maintainer verification is intentionally small:

- deterministically prove the exact active installed skill identity before the
  model call, including expected plugin path/inventory and generated marker;
- issue the host-native direct invocation token without requiring a separate
  model-visible wrapper Read event;
- request and check exactly two nonempty machine lines, `Skill: <name>` followed
  by `Invariant: <stable-enum>`, with no narration or third line;
- prove the read-only probe caused no project mutation.

The direct smoke does not run a workflow, create plans/specs/worktrees, dispatch
role fleets, inspect topology, summarize linked policy, or grade narration. Each
host has a separate opt-in `--dispatch-live` lane for the same minimal bounded
role-dispatch matrix; it does not enlarge or replace the direct-invariant `--live`
lane. Claude setup-skill probes present a hypothetical already-observed read-only status and do
not pass an operational argument or execute bundled helpers. Install Statusline
checks that `STATUS: installed-matching` stops without change; Configure Subagents
checks that the status-only branch reports `STATUS: matching` and stops. Actual
status/config mechanics remain covered by isolated deterministic offline fixtures.
Hard CLI, tool, permission, invocation, startup, and host categories take
precedence over provider-looking substrings. Only after those categories are
excluded may a timeout or positively recognized provider exhaustion, HTTP 429,
rate limit, cooling-down, or credit-unavailable failure be
`INCONCLUSIVE(provider-limited)`.

Codex JSON event candidates begin with `{` and must parse as JSON objects; a
malformed candidate or recognized non-object JSON value is a HARD FAIL. Other
plain-text CLI diagnostics, including the stdin prelude and timestamped internal
logs before or after events, remain in the evidence stream and may produce a
stable warning without invalidating an RC-0 run whose final JSON event is
`turn.completed`, result protocol is exact, and the installed-skill identity
preflight succeeds. A plain
diagnostic matching a hard CLI or invocation category remains a HARD FAIL. This
is candidate discrimination, not a general Codex log grammar.
Fusion Rescue model execution remains deferred because Claude-host provider credits are unavailable and is never counted as a semantic PASS. Cross-host coverage is a separate Codex-only `--cross-host-live` direct transport smoke: one Codex parent executes one harness-owned Python launcher, which invokes Claude Code once. It does not activate a skill, workflow, fallback, panel, review, or subagent path.

Ordinary changes run only affected direct skill probes when scoped invocation is
available. Full direct `--live` is for release candidates, broad shared-contract
changes, or explicit broad validation. The retired natural SessionStart routing,
deep-summary, named-agent matrix, topology, worktree, Simplify/Ralplan special,
model-diversity, and parallel-executor model suites are not maintainer gates.

## Lane matrix

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
      "evidence_artifact": "offline install, active plugin identity, hook, containment, secret, parser-safety, and public-skill exposure evidence",
      "non_proofs": [
        "marker-only output",
        "live model smoke"
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
        "malformed output",
        "forensic invariant",
        "containment"
      ],
      "warnings": [],
      "evidence_artifact": "deterministic active-plugin and installed-skill identity preflight, prompt beginning with the native skill token, successful terminal event, exact Skill/Invariant fields, and unchanged project fingerprint; native skill loading need not emit a model-visible Read event",
      "non_proofs": [
        "marker-only output",
        "semantic paraphrase alone",
        "broad command success alone"
      ]
    },
    {
      "host": "codex",
      "owner": "scripts/test-codex-plugin.sh",
      "flag": "--dispatch-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load and installed identity",
        "parent/child correlation and completion",
        "unexpected or generic child",
        "nonce receipt correlation",
        "ordered Ralplan and Ralph review dispatch",
        "containment"
      ],
      "warnings": [
        "one retry for missing or wrong expected dispatch only"
      ],
      "evidence_artifact": "seven native direct parent invocations and nominal fourteen total model calls, with exact newly parent-linked role sequences, completed nonce-bearing child results and parent wait receipts, ordered Ralplan and Ralph review dispatch, Auto Routing/Simplify zero-child controls, and allowlisted versus required-success mutation proofs",
      "non_proofs": [
        "marker-only output",
        "Ralph baseline/diff SHA binding",
        "reasoning, review quality, or verdict",
        "model diversity, concurrency, waves, or capacity",
        "full workflow completion"
      ]
    },
    {
      "host": "codex",
      "owner": "scripts/test-codex-plugin.sh",
      "flag": "--cross-host-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "one parent thread and terminal completion",
        "missing, wrong, duplicate, or nonterminal launcher execution",
        "child, collaboration, workflow, or fallback activity",
        "nested Claude Read/result correlation and semantic finding",
        "workspace, checkout, Codex identity, Claude state, or credential containment"
      ],
      "warnings": [
        "one retry for missing, wrong, or duplicate exact launcher dispatch only"
      ],
      "evidence_artifact": "one safe Codex parent prompt/event/result set and its newly created parent session JSONL, proving exactly one successful execution of the harness-owned launcher plus a successful nested Claude Read of the receiver fixture and a nonce-bearing no-retry violation finding",
      "non_proofs": [
        "marker-only output",
        "Fusion Rescue or any workflow/fallback path",
        "role dispatch, subagent transport, review quality, or model diversity",
        "general cross-host orchestration"
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
      "evidence_artifact": "offline install/config isolation, hook, containment, configure-subagents transaction, and wrapper inventory evidence",
      "non_proofs": [
        "marker-only output",
        "live model smoke"
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
        "forensic invariant",
        "containment"
      ],
      "warnings": [],
      "evidence_artifact": "deterministic active-plugin and installed-skill identity preflight, one direct slash invocation, exact result event with two Skill/Invariant lines, and unchanged project fingerprint per non-Fusion public skill; native skill loading need not emit a model-visible Read event",
      "non_proofs": [
        "marker-only output",
        "semantic paraphrase alone",
        "broad command success alone"
      ]
    },
    {
      "host": "claude",
      "owner": "scripts/test-claude-plugin.sh",
      "flag": "--dispatch-live",
      "release_status": "opt-in-live",
      "hard_failures": [
        "install/load and installed identity",
        "exact Agent subagent_type sequence",
        "terminal Agent tool_result and nonce correlation",
        "ordered Ralplan and Ralph review dispatch",
        "zero-child controls",
        "mutation, Git state, isolation, secret, and canonical containment"
      ],
      "warnings": [
        "one retry for missing, wrong, or duplicate expected dispatch only"
      ],
      "evidence_artifact": "seven native direct parent invocations using Sonnet and nominal fourteen total model calls, with exact plugin-scoped Agent tool_use sequences, one successful nonce-bearing terminal tool_result per child, ordered reviewer dispatch, parent nonce receipts, zero-child controls, and allowlisted versus required-success mutation proofs in a disposable plugin copy and isolated Claude config",
      "non_proofs": [
        "marker-only output",
        "v2, SHA/revision binding, review verdict, or quality",
        "detailed trace, timing, child transcript, or model diversity",
        "topology beyond immediate Agent tool_use/result correlation",
        "full workflow completion"
      ]
    },
    {
      "host": "opencode",
      "owner": "scripts/test-opencode-plugin.sh",
      "flag": "default",
      "release_status": "release-static",
      "hard_failures": [
        "source plugin load and pinned OpenCode runtime",
        "isolated XDG and OH_NO_CONFIG_DIR containment",
        "real OpenCode agent and skill discovery",
        "exact agent, command, skill, default, host-inherited global permission, primary/role restrictive ceilings, role hard-deny/task-topology, arbitrary restriction-preservation, and custom-tool contract",
        "custom-tool publication and unconfigured/configured restart model behavior",
        "read-only status and legacy CLI apply non-writing",
        "project mutation or non-serial OpenCode command execution"
      ],
      "warnings": [],
      "evidence_artifact": "isolated OpenCode 1.18.11 path, agent-list, and raw skill-discovery output; exact generated inventory, custom-tool schema/execution, and native global plus primary/role/package resolved permission assertions; custom-tool publication, read-only status, legacy CLI non-writing, restart-consumption fixtures; and unchanged project manifest and Git status",
      "non_proofs": [
        "marker-only output",
        "installed marketplace or package behavior",
        "provider-backed skill command or agent dispatch behavior",
        "complete parseable inventory from truncated raw debug skill output",
        "concurrent OpenCode startup safety"
      ]
    },
    {
      "host": "opencode",
      "owner": "scripts/test-opencode-package.sh",
      "flag": "default",
      "release_status": "release-static",
      "hard_failures": [
        "npm pack or dependency-free install",
        "package identity, entrypoint, or OpenCode-only inventory",
        "installed package resolution or default export",
        "installed artifact OpenCode runtime contract"
      ],
      "warnings": [],
      "evidence_artifact": "npm pack JSON and exact file allow/deny assertions; lifecycle-script-free disposable install; package resolution/default-export probe; and the full isolated OpenCode 1.18.11 runtime driver against the installed artifact",
      "non_proofs": [
        "marker-only output",
        "public registry availability",
        "provider-backed skill command or agent dispatch behavior"
      ]
    },
    {
      "host": "static",
      "owner": "scripts/release",
      "flag": "default",
      "release_status": "default-static",
      "hard_failures": [
        "generated-wrapper freshness",
        "manifest/package/source assertion",
        "release default expansion"
      ],
      "warnings": [],
      "evidence_artifact": "release static phase, packed npm artifact, npm integrity guard, and isolated install commands",
      "non_proofs": [
        "marker-only output",
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
      "evidence_artifact": "validator, generation freshness, lane contract, and reachability subprocesses",
      "non_proofs": [
        "marker-only output",
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
      "evidence_artifact": "deterministic wrapper/source/handoff reachability",
      "non_proofs": [
        "marker-only output",
        "semantic correctness of all public skills"
      ]
    }
  ]
}
```

## Direct invariant table

| Skill | Stable enum | Hosts |
|---|---|---|
| Interview | `clarify-before-planning` | Claude, Codex |
| Ralplan | `wait-for-user-approval` | Claude, Codex |
| Ralph | `require-acceptance-contract` | Claude, Codex |
| Ultrawork | `wait-for-spec-approval` | Claude, Codex |
| Auto Routing | `future-session-guidance-only` | Claude, Codex |
| Test-Driven Development | `create-red-first` | Claude, Codex |
| Simplify | `lock-behavior-then-combined-scan` | Claude, Codex |
| Verification Before Completion | `withhold-completion` | Claude, Codex |
| Systematic Debugging | `reproduce-first` | Claude, Codex |
| Install Statusline | `stop-no-change` | Claude |
| Configure Subagents | `report-status-and-stop` | Claude |
| Fusion Rescue | deferred: Claude-host provider credits exhausted | Claude, Codex |
