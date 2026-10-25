# Capabilities Inventory

> **Read this before writing new code.** It lists the shared services, utilities, and patterns that
> already exist in this repository. The rule from [`AGENTS.md`](../AGENTS.md) §1 is: **reuse these;
> do not duplicate them.** When you add a new shared capability, add a row here in the same change
> so the next agent reuses it instead of writing a third copy.
>
> This is a **current-state** document (not a changelog). Keep each entry describing what exists now.

## How to use this file

1. Before adding anything, search this table for the concept (e.g. "retry", "http client", "auth").
2. If it exists → reuse or extend it. Do not create a parallel implementation.
3. If it does not exist and nothing fits → create it, then add a row here.
4. If you find two implementations of one concept → that is a defect; consolidate them and note it
   in [`learnings.md`](learnings.md).

## Shared capabilities

| Capability | What it does | Where (module / path) | Reuse notes |
|---|---|---|---|
| _example: Retry policy_ | Exponential backoff + full jitter, bounded attempts | `<FILL IN>` | Use for all retryable I/O; do not write ad-hoc retry loops. |
| _example: HTTP client_ | Shared client with timeouts + circuit breaker | `<FILL IN>` | All outbound calls go through this; never import a raw client directly. |
| _example: Input validation_ | Schema validation at boundaries | `<FILL IN>` | Validate every deserialized/external payload here. |
| _example: Logger_ | Structured logging + trace-ID propagation | `<FILL IN>` | Use this; never `print`/`console.log` in shipped code. |
| _example: Error types_ | Retryable vs non-retryable error taxonomy | `<FILL IN>` | Wrap boundary errors in these types. |
| _(add rows as the project grows — delete the examples once real entries exist)_ | | | |

## Cross-cutting patterns in use

- **Resilience:** timeouts + backoff + circuit breaker on every external dependency (`AGENTS.md` §4).
- **Observability:** OpenTelemetry tracing + structured logs; Langfoose/OTel-GenAI for agent calls
  (`AGENTS.md` §5).
- **Security:** input validation, parameterized queries, least-privilege secrets (`AGENTS.md` §6).

_(Record project-specific conventions here as they are established.)_
