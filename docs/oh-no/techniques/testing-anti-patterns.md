# Testing anti-patterns

Patterns the harness flags during code review, debugging, and
verification. Each one looks like progress and isn't.

## Tests that always pass

- A test that asserts on shape but never on value.
- A test wrapped in `pytest.skip` / `xfail` (or equivalent) without a
  written reason and a follow-up task.
- A test that catches its own assertion to "be lenient".

## Tests that mock the thing under test

- A bug fix in `process_payment` that mocks `process_payment` itself.
- Integration tests that mock the database the migration is supposed
  to verify.
- Unit tests where the System Under Test is replaced by a fake that
  returns the expected output unconditionally.

## Tests that drift with the code

- Snapshot tests regenerated on every diff without inspection.
- Inline expected values copied from the actual run output, with no
  reasoning behind why those values are correct.
- Tests whose only job is to "lock in" the current implementation,
  changing whenever the implementation changes.

## Tests that hide flakiness

- Wide retries (`pytest-rerunfailures`, `flaky`, retry-on-failure
  hooks) on tests that fail deterministically under load.
- Sleep-based waits that grow over time. See
  `docs/oh-no/techniques/condition-based-waiting.md`.
- `tearDown`/`afterEach` that swallows fixture errors.

## Tests that bypass the contract

- Tests that read private fields directly to assert state instead of
  exercising public behavior.
- Tests that monkeypatch a single branch of the SUT to skip a
  precondition.
- Tests with a hard-coded "obviously safe" path that does not
  exercise the failure modes the code is supposed to handle.

## How the harness responds

- `code-reviewer` flags these as IMPORTANT or BLOCKER depending on
  the surface (money/auth paths escalate per
  `agents/code-reviewer.md`).
- `verify` records them as evidence gaps even when the test suite
  reports green.
- `debug` does not "fix" a flaky test by widening retries; it traces
  the underlying race or shared state.
