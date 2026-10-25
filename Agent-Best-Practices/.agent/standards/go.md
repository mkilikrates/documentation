---
inclusion: fileMatch
fileMatchPattern: '**/*.go'
---

# Go Standard

> **Applies to:** Go files only (`**/*.go`). Do not apply to other languages.
> Specializes `AGENTS.md` and the cross-cutting standards — does not replace them.

## Toolchain & commands (tune per repo)

- **Go version:** `<FILL IN e.g. 1.23>` (pin in `go.mod`)
- **Modules:** Go modules; commit `go.mod` + `go.sum`. Run `go mod tidy` before committing.
- **Updates & vuln check:** `go get -u ./... && go mod tidy` for currency (see
  [`dependencies.md`](dependencies.md)); `govulncheck ./...` in CI for known vulnerabilities.
- **Build:** `go build ./...`
- **Vet + lint:** `go vet ./...` and `golangci-lint run`
- **Format:** `gofmt -l .` / `goimports` (CI fails on unformatted files)
- **Test:** `go test ./...`
- **Coverage floor:** `<FILL IN>%` via `go test -cover ./...` (`-coverprofile` in CI)

## Style & structure

- Follow Effective Go and the project layout conventions already in the repo. Small packages with
  clear responsibilities; avoid `util`/`common` grab-bags.
- Exported identifiers are documented with a comment starting with the identifier name.
- Accept interfaces, return concrete types. Keep interfaces small and defined by the consumer.
- No package-level mutable state; inject dependencies.

## Error handling

- **Return errors; don't panic** across package boundaries. `panic` only for truly unrecoverable
  programmer errors, and recover at a well-defined boundary if at all.
- **Never discard an error** (`_ = f()` only with a comment justifying why). The linter must flag
  unchecked errors (`errcheck`).
- **Wrap with context** using `fmt.Errorf("doing X: %w", err)`; inspect with `errors.Is` /
  `errors.As`. Define sentinel errors or typed errors for retryable-vs-not classification.
- Use `defer` for cleanup (close files, connections, unlock) so resources release on every path.

## Resilience

- **`context.Context` is the first parameter** of any function doing I/O; honor cancellation and
  deadlines. Set timeouts with `context.WithTimeout` and propagate — never pass `context.TODO()` in
  shipped paths.
- Reuse the shared retry/backoff helper (e.g. `cenkalti/backoff` or an in-repo helper) with
  exponential backoff + jitter + bounded attempts; do not hand-roll loops. Register it in
  `capabilities.md`.
- Configure `http.Client` with explicit timeouts (not the zero-value default client); add a circuit
  breaker (e.g. `sony/gobreaker`) around external dependencies.
- Guard goroutines: no leaks (tie lifetime to a context), bound concurrency (worker pools /
  `errgroup` with limits), and protect shared state with the race detector (`go test -race`) in CI.
- Validate decoded external payloads (JSON/proto) before use; fail closed on unknown shapes.

## Testing

- Standard `testing` package; table-driven tests. Mock boundaries behind interfaces.
- Run with `-race` in CI. Use property-based testing (`testing/quick` or `rapid`) for broad-input
  invariants.
- Cover failure paths: context cancellation/timeout, wrapped errors, malformed input.

## Observability

- OpenTelemetry Go SDK (`go.opentelemetry.io/otel`) with `otelhttp`/`otelgrpc` instrumentation;
  export via OTLP. Propagate context across calls.
- Structured logging via `log/slog` carrying trace IDs; never log secrets.
- For LLM/agent calls, use the Langfuse Go integration or OTel GenAI instrumentation.

## Documentation

- **Go doc comments** on every exported identifier: a full-sentence comment placed directly above
  it and starting with the identifier's name (e.g. `// FetchUser returns ...`). Add runnable
  `Example` functions for non-trivial APIs. See [`documentation.md`](documentation.md).
- Enforce with `revive`/`golangci-lint` (`exported` rule); view via `go doc` / pkg.go.dev.
