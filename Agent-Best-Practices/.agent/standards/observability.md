# Observability Standard

Concrete backing for [`AGENTS.md`](../../AGENTS.md) §5. Instrument in the **same change** that adds
the behavior — observability is not a later task.

## Principles

- **Vendor-neutral instrumentation.** Instrument with open standards (OpenTelemetry); choose the
  backend (Jaeger, Tempo, Prometheus, a vendor) at deploy time. The code should not hardcode a
  vendor.
- **Three signals, correlated:** traces, metrics, logs share trace/correlation IDs so you can pivot
  between them.
- **No secrets in telemetry.** Never put credentials, tokens, or unredacted PII in logs, span
  attributes, or metric labels.

## Tracing (OpenTelemetry)

- Create a **span around every I/O boundary and meaningful unit of work.** Name spans by operation.
- Attach attributes: operation, target dependency, outcome, retry count, and (redacted) key inputs.
- **Propagate context** across service calls and async boundaries (W3C `traceparent`); never start a
  disconnected trace mid-flow.
- Record exceptions on the span and set span status on failure.
- Export via **OTLP**. Sampling is a deployment config, not a code decision.

## Metrics (RED + USE)

- **RED** per endpoint/dependency: **R**ate, **E**rrors, **D**uration (histogram, not just average).
- **USE** per resource: **U**tilization, **S**aturation, **E**rrors (pools, queues, memory).
- **Resilience signals as first-class metrics:** retry count, timeout rate, circuit-breaker state
  transitions, rate-limit rejections, queue depth. These are how you verify §4 is actually working.
- Keep label cardinality bounded (no user IDs / unbounded values as labels).

## Logging

- **Structured** (JSON / key-value), consistent levels (`debug/info/warn/error`).
- Every log line carries the trace/correlation ID.
- Log *decisions and transitions* (retry scheduled, breaker opened, degraded path taken), not noise.
- **Redact** secrets and PII at the logging boundary, centrally — don't rely on every call site.

## AI / agent observability

When the system calls LLMs or runs agents, make the chain fully observable and reproducible:

- **Trace the full call:** prompt (redacted), model + version, parameters, token usage (in/out),
  latency, cost, tool/function calls, and final outcome.
- **Span per step** of a multi-step agent run, nested under one trace, so you can see the whole
  reasoning/tool chain.
- **Use an agent-observability layer:** **Langfuse** (or the **OpenTelemetry GenAI semantic
  conventions**) so traces are portable and comparable. Tag each call with the operation, session,
  and a stable request ID.
- **Capture inputs/outputs with PII redaction** for debugging and evals; make prompts reproducible
  (log the exact rendered prompt, not just the template).
- Track **quality/eval signals** where applicable (success rate, groundedness, user feedback) so
  regressions are visible.

## Health & readiness

- **Liveness:** the process is up.
- **Readiness:** dependencies this instance needs are reachable — so orchestrators route away from a
  sick instance instead of letting it fail requests (ties into the isolation goal in §4).

## Setup pointers (fill per repo)

- OTel SDK + exporter: `<FILL IN>`
- Metrics backend: `<FILL IN>`
- Log aggregation: `<FILL IN>`
- Agent tracing (Langfuse/OTel GenAI): `<FILL IN keys via secret manager, never committed>`
