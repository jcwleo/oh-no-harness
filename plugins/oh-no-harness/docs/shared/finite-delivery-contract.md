# Finite Delivery Contract

This contract keeps Ralph and Ultrawork rigorous without turning delivery into
an unbounded confidence loop. It applies to every write-capable execution and is
source-agnostic software-development guidance.

Use it with `docs/shared/execution-modes.md`,
`docs/shared/verification-tiers.md`, and `docs/shared/ralph-subagent-policy.md`.

## Baseline Guard

Before the final claim, classify baseline evidence as `required` or
`not-applicable`.

Baseline evidence means existing tests, public contracts, docs, examples,
generated artifacts, or compatibility checks near the changed surface. It is not
external score feedback, task-name knowledge, or a local metric signal unless
that signal is explicitly tied to the approved acceptance criteria.

When baseline evidence is required:

- identify the existing contract before or during input hardening
- run the smallest credible existing regression check after behavior stabilizes
- run a broader check once when shared behavior, public APIs, generated
  artifacts, packaging, concurrency, persistence, or cross-package contracts
  could be affected
- if no executable baseline exists, inspect the public contract and record the
  residual risk instead of silently treating the guard as passed
- for standards, parsers, interpreters, serializers, protocol handlers, and
  compatibility layers, include existing fixture, example, or docs evidence
  that previously accepted syntax, dynamic expressions, unknown fields, or
  partial/legacy inputs still follow the old contract unless the approved scope
  explicitly changes that contract
- before relying on a large suite for confidence, run a cheap runtime stability
  probe when the environment is crash-prone: import/collection smoke, one
  adjacent focused test, or the smallest command that can distinguish a patch
  regression from a pre-existing segfault, OOM kill, missing service, or broken
  fixture setup

If baseline evidence fails, route to `systematic-debugging` before more fixes.
Do not present new acceptance evidence as complete while the existing public
contract is broken.

### Compatibility Baseline Guard

For parser, standard, interpreter, protocol, serialization, generated-code, or
public configuration work, the baseline guard must protect compatibility as a
first-class contract. New validation or normalization must not turn a previously
accepted dynamic or legacy input into a hard error unless that behavior change
is named in the approved scope.

Required compatibility evidence is the smallest relevant mix of:

- existing standard fixtures or conformance examples
- existing docs examples, public examples, or golden files
- focused checks for unresolved/dynamic expressions, unknown syntax,
  default behavior, and invalid input
- inspection that scopes stricter validation to the new feature path rather
  than the old public parser or interpreter path

When an existing fixture, conformance, docs, or golden-file check already
covers the touched public contract, run that existing check or record why it is
not runnable. A synthetic smoke test may supplement compatibility evidence, but
it does not replace the nearest existing public-contract fixture for standards,
parsers, interpreters, serializers, or protocol handlers.

If a stricter implementation is still necessary, record the public-contract
change and pause for approval when that change was not already approved.

### Runtime Stability Baseline

Segfaults, OOM kills, dependency import crashes, service outages, and test
collection crashes are evidence states, not ordinary assertion failures. Before
continuing a long implementation loop, classify the failure as one of:

- `patch-regression`: the failure appears only after the patch or in changed
  code paths
- `pre-existing-runtime-failure`: the same minimal probe fails before the patch
  or outside changed paths
- `environment-blocked`: the command cannot run because required services,
  dependencies, memory, credentials, or fixtures are unavailable
- `unknown`: the cause is not isolated yet and must go through
  `systematic-debugging`

Do not hide runtime instability behind a narrower green command. Use focused
checks to keep moving only after recording the classification, the smallest
probe that supports it, and the residual risk for any skipped broad evidence.

### Executable Contract Probe Gate

Any named risk that could invalidate the completion claim must be converted into
an executable contract probe unless the repository truly has no runnable path.
This applies to compatibility, state/lifecycle, stale-state leakage,
parser/standard/interpreter behavior, runtime stability, public API, generated
artifact, and baseline-public-contract risks.

An executable contract probe is the smallest focused command, test, fixture,
docs example, generated-artifact check, or manual inspection that would expose
the named risk if it were present. Broad suites are supporting evidence, but
they do not replace the focused probe for a risk the agent already identified.

For change tracking, audit logs, event streams, telemetry, counters, caches, and
lifecycle hooks, the probe must cover both the positive event that should be
observable and the negative/noise case that should not be observable. Internal
initialization, cleanup, cache invalidation, retry, or framework lifecycle work
must not leak into a public change log unless the public contract says it
should.

Record each probe as:

- named risk and protected contract
- probe command, test, artifact check, or inspection target
- expected result and why it detects that risk
- actual result and exit code when a command ran
- status: `passed`, `failed`, or `not-runnable`
- residual risk and compensating inspection when `not-runnable`

If a required probe fails or is missing, route to `systematic-debugging` or
report `failed_verification`. Do not claim completion from unrelated green tests
after a named compatibility, lifecycle, runtime, or public-contract risk remains
unprobed.

### Baseline Evidence Record

When the baseline guard is `required`, the final evidence must include a
baseline evidence record before any completion claim. A completion claim without
this record is `failed_verification`, not a weaker form of success.

Required fields:

- baseline contract or existing behavior being protected
- command, inspection, or generated-artifact check used as evidence
- why that evidence is adjacent to the changed surface
- result and exit code when a command ran
- whether the evidence is `passed`, `failed`, or `not-runnable`
- risk-specific evidence status when applicable: compatibility baseline,
  runtime stability classification, and executable contract probe status
- residual risk when the evidence is `not-runnable`

New acceptance tests, external score outcomes, task-specific metric signals, or
the absence of obvious failures do not satisfy this record. For library,
framework, agent, plugin, public API, generated-artifact, packaging, or workflow
changes, at least one existing public-contract check or documented inspection
must be named in addition to any new tests.

## Review Loop Budget

Record the review-loop budget before dispatching final review roles.

Default budget:

- one required review pass when the selected mode or risk requires review
- one narrow re-review for blocking findings after a meaningful fix
- optional cleanup, style, or preference findings become residual risk or
  follow-up work; they do not force another loop

A third review or broader re-review requires an explicit escalation reason:
security, data loss, public API or packaging risk, architecture direction
conflict, repeated failed fixes, or user-approved broader scope.

If blocking findings remain after the budget is exhausted, report
`failed_verification` or `blocked` with the remaining blocker. Do not keep
reviewing just to seek more confidence.

### Patch-Change Rerun Gate

After a broad suite, final review, or cleanup pass succeeds, do not rerun the
same broad command or spawn another optional review unless a meaningful patch
change could affect that evidence. A meaningful patch change is one that touches
runtime behavior, generated artifacts, public contracts, tests, configuration,
or the code that the previous evidence exercised.

Cosmetic edits, report wording, session artifact updates, or confidence seeking
do not justify another broad rerun. Record them as residual risk or follow-up
when they are not required by the selected mode or a blocking finding.

### Expensive Broad Evidence Reuse

If an expensive broad command already passed in the execution checkout and the
patch is integrated byte-for-byte into the final checkout, do not repeat that
same expensive broad command only to make the evidence feel fresher. Instead,
record a patch identity check plus a smaller post-integration smoke or focused
semantic check that proves the final checkout is running the integrated patch.

Repeat the broad command only when integration changed the patch, generated
artifacts were rebuilt differently, dependencies or environment changed, the
previous command was not adjacent to the final deliverable, or the selected mode
explicitly requires final-checkout broad evidence.

## Dispatch Gate

Dispatch subagents only when their output is required by the selected execution
mode, risk, approved plan, or finite delivery contract, and when the result can
be integrated before the stop condition.

Do not spawn late optional review, cleanup, or verification agents after the
ship gate is already satisfied. Record the optional follow-up instead.

If a required role cannot be dispatched, keep the role boundary inline and
record the fallback reason.

## Deliverable Diff Hygiene

Before the ship gate, inspect the deliverable diff and status. Transient Oh No
Harness artifacts under `.oh-no/sessions/`, `.oh-no/plans/`,
`.oh-no/specs/`, `.oh-no/test-runs/`, and `.oh-no/worktrees/` are workflow
state, not deliverable source, unless the user explicitly requested that those
artifacts be versioned.

Use a status command that includes untracked files:

```sh
git status --short --untracked-files=all
```

If transient harness artifacts appear in the deliverable diff, remove them from
the deliverable, add `.oh-no/` to the local repository exclude file, or record a
blocker. Do not present a patch as complete while session notes, run logs,
worktrees, or other transient harness artifacts would be shipped to the
target project unintentionally.

## Ship Gate

Stop and report when all of these are true:

- acceptance criteria have direct, indirect, manual, or explicitly missing
  evidence mapped honestly
- the baseline guard is passed or explicitly `not-applicable`
- the baseline evidence record exists when the baseline guard is `required`
- required executable contract probes are passed, or explicitly
  `not-runnable` with a blocker or residual-risk downgrade
- deliverable diff hygiene passed or the user explicitly approved versioning the
  relevant `.oh-no` artifacts
- required TDD, validation-check, risk-check, review, cleanup, and verification
  gates for the selected mode are satisfied or have an explicit blocker
- there are no unresolved blocking reviewer findings
- `verification-before-completion` has run for the final completion claim

After the ship gate is satisfied, do not continue because of metric movement,
hidden-check guessing, confidence seeking, optional cleanup, or another review
that is not tied to a blocker.

## Failure States

Use `systematic-debugging` for failed baseline or acceptance evidence with an
unknown root cause.

Use `failed_verification` when the implementation is complete enough to judge
but required evidence still fails.

Use `blocked` when required evidence, environment access, user approval, or
scope authority is missing.
