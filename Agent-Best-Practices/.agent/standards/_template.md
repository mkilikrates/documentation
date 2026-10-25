---
# Kiro conditional steering: load this standard ONLY for matching files.
inclusion: fileMatch
fileMatchPattern: '**/*.<ext>'
---

# <Language> Standard

> **Applies to:** `<language>` source files only (`**/*.<ext>`). Do not apply these rules to other
> languages (see [`AGENTS.md`](../../AGENTS.md) §standards rule).

Fill in the project-specific concretes. Everything here specializes the language-agnostic rules in
`AGENTS.md` and the cross-cutting standards; it does not replace them.

## Toolchain & commands

- **Version / runtime:** `<FILL IN>`
- **Package manager:** `<FILL IN>`
- **Build:** `<FILL IN>`
- **Lint:** `<FILL IN>`
- **Format:** `<FILL IN>`
- **Typecheck:** `<FILL IN>`
- **Test:** `<FILL IN>`
- **Coverage floor:** `<FILL IN>%`

## Style & structure

- `<FILL IN: naming, module layout, public API conventions>`

## Error handling (language-specific)

- `<FILL IN: idiomatic error type/mechanism; how to wrap and propagate; what "no swallowed error"
  looks like here>`

## Resilience (language-specific)

- `<FILL IN: the retry/backoff utility to reuse, timeout/cancellation mechanism, HTTP client>`

## Testing (language-specific)

- `<FILL IN: test framework, mocking approach, property-based testing library>`

## Observability (language-specific)

- `<FILL IN: OTel SDK, structured logger, how traces/metrics are wired>`

## Documentation (language-specific)

- `<FILL IN: idiomatic doc-comment format, doc generator, doc-coverage linter — see documentation.md>`
