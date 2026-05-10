# Condition-based waiting

The harness avoids sleep-based waits in tests, hooks, and
orchestration code. They mask races and rot under load.

## Rule

Wait for the observable condition that proves readiness, not for a
duration.

```text
Bad:
  sleep 5
  curl http://localhost:8080/health

Good:
  for i in $(seq 1 60); do
    curl -fs http://localhost:8080/health && break
    sleep 1
  done
  if [ "$i" = 60 ]; then
    echo "service did not become healthy in 60s" >&2
    exit 1
  fi
```

## Required pieces

- A predicate that proves readiness (HTTP 2xx, log line, file marker,
  state column, return code).
- A timeout with a clear failure message including what was waited
  for.
- A polling step that does not melt the system. Typical 1–5s. Do not
  busy-loop.

## Acceptable use of sleep

- A bounded sleep *between* checks of an observable condition.
- A documented backoff inside a retry loop with a maximum and a
  reason.
- Tests of code that itself measures elapsed time, where the sleep is
  the system under test.

## How the harness responds

- `debug` does not "fix" a flaky test by raising the sleep duration;
  see `docs/oh-no/techniques/root-cause-tracing.md`.
- `code-reviewer` tags long unconditional sleeps in tests or
  orchestration as IMPORTANT, and BLOCKER on auth/money/data paths.
- `verify` records test runtimes that grew under "fixes" as a
  regression-proof gap.
