# Standards

Detailed, concrete guidance that backs the principles in [`AGENTS.md`](../../AGENTS.md). Two kinds
of file live here:

## Cross-cutting standards (always apply)

- [`resilience.md`](resilience.md) — error handling, backoff, timeouts, circuit breakers, bulkheads,
  idempotency, serialization.
- [`observability.md`](observability.md) — OpenTelemetry tracing, structured logs, RED/USE metrics,
  and agent/LLM tracing (Langfuse / OTel GenAI).
- [`security.md`](security.md) — input validation, secrets, least privilege, dependency *safety*,
  prompt-injection resistance, the review checklist.
- [`dependencies.md`](dependencies.md) — keeping code, libraries, runtimes, and base images
  *current*: update cadence, automation, breaking-change handling, deprecations, EOL tracking.
- [`documentation.md`](documentation.md) — in-code documentation: docstrings / doc comments per
  language (Google-style, TSDoc, Go doc comments, Javadoc, Rustdoc), what a doc comment must cover,
  and doc-coverage linting.

## Language standards (apply ONLY to that language's files)

**Hard rule:** a language standard applies only when you are working on files of that language.
Do not apply Python rules to TypeScript, etc. Tools enforce this where possible:

- **Kiro:** conditional steering with `inclusion: fileMatch` + `fileMatchPattern` loads the standard
  only for matching files (see each file's front-matter and the root `README.md`).
- **Other agents:** honor the "Applies to" line at the top of each language file.

Provided templates/examples:

- [`_template.md`](_template.md) — copy to add a new language.
- [`python.md`](python.md)
- [`typescript.md`](typescript.md)
- [`go.md`](go.md)

Add more as needed (`rust.md`, `java.md`, …) from the template.
