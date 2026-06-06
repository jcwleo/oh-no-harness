# Validation Check

Measurable evidence is useful, but it is not the same as satisfying acceptance
criteria.

Use this check whenever a task, plan, prompt change, harness change, or
completion claim is influenced by a signal that is easier to measure than the
actual user, maintainer, operator, or public contract outcome.

Examples of measurable evidence include local command success, broad suite
results, snapshot output, lint or typecheck status, dashboard numbers, log
counters, synthetic scenarios, sampled traces, mock-only tests, generated
markers, or any other convenient stand-in for the intended behavior.

## Principle

Improve the recurring software engineering behavior behind the evidence gap. Do
not optimize for one observed local check.

The improvement should address a recurring software engineering failure mode:
requirements mismatch, weak acceptance evidence, hidden regression, broad-suite
overconfidence, untraceable scope growth, fragile tests, public contract drift,
state or persistence mistakes, concurrency risk, error-handling gaps, unsafe
operations, or maintainability debt.

## Forbidden Patterns

Do not add:

- task-name, fixture-name, dataset-label, issue-id, or environment-specific
  solution hints
- prompts that instruct the agent to guess unseen checks
- validation that approves work from metric movement without checking the
  acceptance criteria
- hard-coded repository, fixture, label, or case identifiers as behavioral
  guidance
- broad process inflation whose only justification is a better local check

Measurable evidence may identify a failure category. It must not become the
definition of success.

## Validation Check

Before approving an evidence-informed improvement, record:

```text
Validation check:
- Evidence used:
- Acceptance criteria or user outcome it supports:
- What the evidence proves:
- What the evidence does not prove:
- Regression or maintainability risk addressed:
- Why this should apply to similar work:
- Case-specific details deliberately excluded:
- Added process cost or risk:
- Completion claim:
```

The completion claim should be one of:

- validated against acceptance criteria with direct evidence
- plausibly valid with explicit residual risk
- only supported by local checks and not acceptable as a harness improvement

## Evidence Expectations

For workflow, prompt, or harness changes:

- Map the change to a category-level software engineering failure mode.
- Preserve the user's, maintainer's, operator's, or public contract's success
  signal as the acceptance criteria.
- Prefer evidence that would still make sense on a similar repository, feature,
  bug, review scenario, or operational incident.
- Treat repeated measurable checks as regression diagnostics and comparative
  evidence, not as proof that the harness is better for real development.
- Report cost, latency, verbosity, or over-process risk introduced by the
  change.

## Similar-Work Expectation

If a change cannot be explained without naming the exact fixture, case, label,
or observed check that motivated it, it is probably only supported by local
checks. Keep the improvement or reject it based on the recurring software
engineering failure mode it handles, not on the local check movement it
produced.
