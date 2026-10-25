# Resilience & Availability Standard

Concrete backing for [`AGENTS.md`](../../AGENTS.md) §4. Language-agnostic; tune the numbers per repo.

**Core goal:** one failing dependency must never take down the whole system. Isolate, bound, and
degrade — never cascade.

## Error handling

- **No swallowed errors.** No empty catch, no ignored error return. Handle, wrap-with-context, or
  propagate — explicitly.
- **Classify errors:**
  - *Programmer errors* (broken invariants, bad state) → fail fast, surface loudly, don't retry.
  - *Operational errors* (dependency slow/down, transient) → handle gracefully, maybe retry/degrade.
- **Retryable vs non-retryable:** retry only transient failures (connection reset, timeout, HTTP
  429/502/503). Never retry validation (4xx) or auth failures.
- **Wrap at boundaries** with structured context (operation, redacted inputs, cause). Never leak
  secrets or internals to end users; map to safe messages + an error ID that ties to a trace.

## Retries — exponential backoff with full jitter

- Retry only **idempotent / retryable** operations.
- **Full jitter** is the default (avoids thundering-herd): `sleep = random(0, min(cap, base * 2^n))`.
- **Bounds (tune per repo):** `base = <FILL IN e.g. 200ms>`, `factor = 2`, `maxAttempts = <FILL IN
  e.g. 5>`, `cap = <FILL IN e.g. 20s>`, **overall deadline = `<FILL IN e.g. 60s>`**.
- Honor server `Retry-After`.
- Never nest retry loops (retry at exactly one layer per logical operation).

Pseudocode:

```
attempt = 0
deadline = now + OVERALL_DEADLINE
while true:
    try:
        return call()            # has its own per-attempt timeout
    except err:
        if not retryable(err) or attempt >= MAX_ATTEMPTS or now >= deadline:
            raise wrap(err, context)
        delay = min(CAP, BASE * 2**attempt)
        delay = random(0, delay)              # full jitter
        delay = max(delay, retry_after(err))  # honor server hint
        sleep(delay); attempt += 1
```

## Timeouts

- **Every I/O call has an explicit timeout.** No unbounded waits anywhere.
- Set per-attempt timeouts *and* an overall operation deadline; propagate the deadline (cancellation
  token / context) down the call chain so inner calls cannot outlive the outer budget.
- Connection, read, and write timeouts are all set — not just one.

## Isolation — the anti-cascade toolkit

- **Circuit breaker** per external dependency: `closed → open` after a failure threshold, serve
  fast-failures while `open`, `half-open` probes for recovery. Expose breaker state as a metric.
- **Bulkheads:** separate connection pools / worker pools / queues per dependency so exhaustion in
  one cannot starve the rest.
- **Rate limiting + backpressure:** bound inbound concurrency and outbound call rate; shed or queue
  excess load rather than collapsing. Reject early with a clear signal when overloaded.
- **Fallback / graceful degradation:** define the reduced-but-working path (cache, default, queued
  retry, partial result) for when a dependency is unavailable. A degraded answer beats an outage.

## Idempotency & consistency

- Make writes **idempotent** (idempotency keys, conditional/compare-and-set writes, upserts) so a
  retry cannot double-apply.
- Multi-step work is **atomic or resumable**, with compensating actions for partial failure (saga
  pattern where distributed transactions aren't available).
- **Always release resources** (connections, locks, file handles, temp files) on every exit path,
  including errors and cancellations.

## Serialization & boundary data

- **Validate every deserialized / external payload** against an explicit schema before use. Treat
  all boundary data (network, file, queue, user, model output) as untrusted.
- **Version serialized formats** (a `schemaVersion` field); keep deserialization
  backward-compatible or provide an explicit migration. Reject unknown/unsafe shapes (fail closed).
- Guarantee **lossless round-trip** for anything persisted and re-read.
- Avoid formats/settings prone to unsafe deserialization (no arbitrary object instantiation from
  untrusted input).

## Checklist (per change touching I/O)

- [ ] Timeout on every call + overall deadline propagated.
- [ ] Retry only retryable + idempotent, with backoff + full jitter + bounds.
- [ ] Circuit breaker / bulkhead around the dependency.
- [ ] Explicit degraded behavior when the dependency is down.
- [ ] Resources released on all paths.
- [ ] Boundary data validated and version-checked.
- [ ] Failure paths covered by tests (timeout, 5xx, malformed payload, partial failure).
