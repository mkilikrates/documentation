# Code Documentation Standard

Concrete backing for in-code documentation — docstrings, API comments, and generated reference docs.
Complements [`AGENTS.md`](../../AGENTS.md) §7, which covers the *living documents* (spec,
capabilities, learnings, human guides); this file covers **documentation that lives in the source**.

**Goal:** a reader (human or agent) understands how to *use* a public symbol from its doc comment
without reading its body, and understands *why* non-obvious code exists from its inline comments.

## Principles

- **Document the contract, in the code.** Every exported/public symbol (module, package, class,
  function, method, constant, type) has a doc comment describing what it does, its parameters,
  return value, and the errors/exceptions it can raise.
- **Explain *why*, not *what*.** Inline comments justify non-obvious decisions, trade-offs, and
  workarounds. Do not narrate what the code plainly says. If code needs a *what* comment to be
  understood, prefer making the code clearer.
- **Docs are part of the change** (`AGENTS.md` §7). Update the doc comment in the same change as the
  code. A stale doc comment is worse than none — fix or delete it.
- **Use the ecosystem's standard format** so IDEs and doc generators parse it (see per-language
  below). Consistency within the repo beats personal preference.
- **Keep examples runnable and correct.** A doc example that doesn't compile/run is a bug; where the
  language supports it (Go examples, Python doctest, Rust doctest), test them in CI.
- **No secrets or real PII in comments or examples** — use placeholders (`AGENTS.md` §6).
- **Document the public surface thoroughly; keep internals lighter.** Private helpers need a doc
  comment only when their behavior is non-obvious.

## What a good doc comment covers

- **Summary:** one line, imperative or descriptive, stating what it does.
- **Parameters:** name, meaning, constraints (units, ranges, nullability).
- **Returns:** what it produces and under what conditions.
- **Errors/exceptions:** what it raises/returns on failure and when (ties to `resilience.md`).
- **Side effects & concurrency:** I/O, mutation, thread/goroutine safety, blocking/timeout behavior.
- **Example:** for non-trivial public APIs.
- **Deprecation:** mark deprecated symbols with the standard annotation and the replacement
  (ties to `dependencies.md`).

## Per-language conventions

Pick the idiomatic format; CI should lint for missing docs on the public surface.

| Language | Doc format | Generator | Lint for coverage |
|---|---|---|---|
| **Python** | **PEP 257 docstrings**, **Google style** sections (`Args:`, `Returns:`, `Raises:`) — or NumPy style, repo-consistent | Sphinx (napoleon) / mkdocstrings | `ruff` (`D` rules / pydocstyle), `interrogate` |
| **TypeScript/JS** | **TSDoc / JSDoc** (`@param`, `@returns`, `@throws`, `@example`) | TypeDoc | `eslint-plugin-jsdoc` |
| **Go** | **Go doc comments** (comment directly above the symbol, starting with its name; full sentences) | `go doc` / pkg.go.dev | `revive` (`exported` rule) / `golangci-lint` |
| **Java** | **Javadoc** (`@param`, `@return`, `@throws`) | `javadoc` | checkstyle (JavadocMethod) |
| **Rust** | **Rustdoc** (`///` outer, `//!` inner, Markdown, `# Examples`/`# Errors`/`# Panics`) | `cargo doc` | `missing_docs` lint, `cargo test` (doctests) |

Each language standard in this folder names the exact tools and coverage threshold; set the "docs on
public API" lint as a CI gate where the ecosystem supports it.

### Examples

Python (Google style):
```python
def fetch_user(user_id: str, *, timeout: float = 5.0) -> User:
    """Fetch a user by ID.

    Args:
        user_id: Stable identifier of the user.
        timeout: Per-attempt network timeout in seconds.

    Returns:
        The hydrated User.

    Raises:
        NotFoundError: If no user has that ID.
        TimeoutError: If the request exceeds `timeout`.
    """
```

Go (doc comment starts with the symbol name):
```go
// FetchUser returns the user with the given id. It applies the deadline from ctx
// and returns ErrNotFound if no such user exists.
func FetchUser(ctx context.Context, id string) (*User, error) {
```

TypeScript (TSDoc):
```ts
/**
 * Fetch a user by ID.
 * @param userId - Stable identifier of the user.
 * @param timeoutMs - Per-attempt network timeout in milliseconds.
 * @returns The hydrated user.
 * @throws NotFoundError when no user has that ID.
 */
```

## Checklist (per change)

- [ ] Every new/changed public symbol has a doc comment in the ecosystem's standard format.
- [ ] Parameters, returns, and errors/exceptions documented.
- [ ] Non-obvious decisions explained with *why* comments; no redundant *what* comments.
- [ ] Examples compile/run (and are tested where the language supports it).
- [ ] Deprecations annotated with the replacement.
- [ ] No secrets/PII in comments or examples.
- [ ] Stale comments updated or removed.
