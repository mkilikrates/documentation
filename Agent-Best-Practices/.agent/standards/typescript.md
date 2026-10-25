---
inclusion: fileMatch
fileMatchPattern: '**/*.{ts,tsx}'
---

# TypeScript Standard

> **Applies to:** TypeScript files only (`**/*.ts`, `**/*.tsx`). Do not apply to other languages.
> Specializes `AGENTS.md` and the cross-cutting standards — does not replace them.

## Toolchain & commands (tune per repo)

- **Runtime:** `<FILL IN e.g. Node 22>` (pin in `.tool-versions` / `engines`)
- **Package manager:** `<FILL IN: npm / pnpm / yarn>` (commit the lockfile)
- **Build:** `<FILL IN e.g. tsc / vite build>`
- **Lint + format:** `eslint` + `prettier`
- **Typecheck:** `tsc --noEmit` with `strict: true`
- **Test:** `<FILL IN e.g. vitest / jest>`
- **Coverage floor:** `<FILL IN>%`

## Style & structure

- `strict` TypeScript; avoid `any` — use `unknown` + narrowing. No non-null `!` to silence the
  compiler.
- Prefer discriminated unions and exhaustive `switch` (with `never` checks) over loose objects.
- Narrow public API surface; keep domain logic framework-agnostic and inject adapters.

## Error handling

- No empty `catch`. Catch, add context, rethrow a typed error, or handle explicitly.
- Model expected failures as a `Result`/`Either` type or typed error classes, not thrown strings.
- Always `await` promises; no floating promises (enable the lint rule). Use `try/finally` for
  cleanup.

## Resilience

- Reuse the shared retry/backoff utility (e.g. `p-retry` / `cockatiel` for retry + circuit breaker);
  do not hand-roll. Register it in `capabilities.md`.
- Every `fetch`/client call uses `AbortController` + timeout; propagate the signal down the chain.
- Validate external payloads with `zod` (or similar) at the boundary before use.

## Testing

- `<vitest/jest>` with mocked boundaries (`msw` for HTTP, fake timers for clocks).
- Property-based tests with `fast-check` for broad-input invariants.
- Cover failure paths: rejected promises, aborts/timeouts, invalid payloads.

## Observability

- `@opentelemetry/*` SDK + auto-instrumentations; export via OTLP.
- Structured logging (e.g. `pino`) with trace-ID correlation; never log secrets.
- For LLM/agent calls, use the Langfuse SDK or OTel GenAI instrumentation.

## Documentation

- **TSDoc/JSDoc** (`@param`, `@returns`, `@throws`, `@example`) on every exported symbol. Types
  carry much of the contract — document the behavior and the error cases types can't express. See
  [`documentation.md`](documentation.md).
- Lint with `eslint-plugin-jsdoc`; generate reference docs with TypeDoc.
