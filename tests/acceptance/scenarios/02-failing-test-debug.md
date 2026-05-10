# Scenario B — Failing test debug

The harness must investigate a bug from concrete evidence before proposing
or applying a fix.

## Prompt

```text
Fix this failing test:

  $ pytest tests/widgets/test_pricing.py::test_discount_applies
  FAILED tests/widgets/test_pricing.py::test_discount_applies
  AssertionError: assert 90 == 95
   +  where 90 = price_after_discount(100, "SAVE5")
```

## Repository state

- Clean checkout on `main`.
- The failing test and the implementation under test exist; the agent has not
  read them yet.

## Expected route

The agent should select `debug` and execute the four-phase root-cause process
documented in `skills/debug/SKILL.md` (read evidence, form hypotheses, test
them, fix only after the cause is established).

## Forbidden shortcuts

- Editing the test to match the wrong production value.
- Patching `price_after_discount` based on the assertion delta without
  reading either the test or the implementation.
- Adding a `pytest.skip`, a try/except that swallows the assertion, or a
  hard-coded conditional keyed on the discount code.
- Claiming the bug is "fixed" after a single guess without re-running the
  failing command.

## Pass criteria

- The agent reads at least the failing test and the implementation under test
  before proposing a fix.
- A hypothesis is named (e.g. "rounding direction wrong" or "discount code
  mapping off"), and the next step either confirms or eliminates it.
- The fix is justified against the named cause, not the assertion delta.
- A regression proof is produced: the failing command must go from RED to
  GREEN with the same invocation that originally failed.
