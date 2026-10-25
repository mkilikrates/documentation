# Design

> **Single living design document** (see [`AGENTS.md`](../../AGENTS.md) §9). Write it so someone
> reading it fresh understands the architecture **as it is today** — not its history. When the
> design changes, rewrite the affected section in place. Every design decision should map back to a
> numbered requirement in [`requirements.md`](requirements.md).

## Overview

`<FILL IN: what the system is, its key constraints, and the principles that run through it.>`

## Architectural principles

- **Separation of core and boundaries.** Domain logic is framework-agnostic; I/O, storage, network,
  and UI are thin, swappable adapters.
- **Resilience by construction.** Every external dependency is wrapped with timeout + bounded retry
  (exponential backoff + jitter) + circuit breaker, so one failing dependency cannot cascade
  (`AGENTS.md` §4).
- **Observability is not optional.** Spans, structured logs, and metrics are part of each component,
  not bolted on (`AGENTS.md` §5).
- **Security by construction.** Input validated at boundaries; secrets out of code; least privilege
  (`AGENTS.md` §6).
- **Reuse over reinvention.** Shared capabilities live in canonical locations and are listed in
  [`../capabilities.md`](../capabilities.md). New components are justified against that inventory.

## Components

`<FILL IN: one subsection per component — responsibility, interface, dependencies, failure modes.>`

### `<Component>`
- **Responsibility:** …
- **Interface:** …
- **Dependencies:** … (and how each is isolated/wrapped per §4)
- **Failure modes & handling:** what happens when each dependency times out / errors / is down.
- **Observability:** which spans/metrics/logs it emits.
- **Implements requirements:** `<R-numbers>`

## Data & serialization

`<FILL IN: schemas, versioning strategy, validation rules, round-trip guarantees (AGENTS.md §4).>`

## Cross-cutting concerns

Reference the standards rather than re-specifying them: resilience
([`../standards/resilience.md`](../standards/resilience.md)), observability
([`../standards/observability.md`](../standards/observability.md)), security
([`../standards/security.md`](../standards/security.md)).
