---
inclusion: fileMatch
fileMatchPattern: '**/*.py'
---

# Python Standard

> **Applies to:** Python files only (`**/*.py`). Do not apply to other languages.
> Specializes `AGENTS.md` and the cross-cutting standards — does not replace them.

## Toolchain & commands (tune per repo)

- **Python:** `<FILL IN e.g. 3.12>` (pin in `pyproject.toml` / `.tool-versions`)
- **Package/dep manager:** `uv` or `poetry` or `pip-tools` — `<FILL IN>` (commit a lockfile)
- **Lint + format:** `ruff check` and `ruff format` (or `black` + `flake8`)
- **Typecheck:** `mypy` (or `pyright`) in strict mode where feasible
- **Test:** `pytest`
- **Coverage floor:** `<FILL IN>%` via `pytest --cov`

## Style & structure

- Type-hint all public functions; prefer dataclasses / `pydantic` models for structured data.
- Small modules, explicit `__all__` for public surface; avoid import-time side effects.
- Use `pathlib`, f-strings, and context managers (`with`) for resource lifetimes.

## Error handling

- Catch **specific** exceptions, never bare `except:`. No silent `except Exception: pass`.
- Raise domain exceptions; chain with `raise NewError(...) from err` to preserve context.
- Use `try/finally` or context managers so resources release on every path.

## Resilience

- Reuse the shared retry helper (e.g. `tenacity` with exponential backoff + jitter + stop-after);
  do not hand-roll retry loops. Register it in `capabilities.md`.
- Set explicit timeouts on every network call (`httpx`/`requests` `timeout=`); propagate
  cancellation via `asyncio` timeouts for async code.
- Validate external payloads with `pydantic` (or an explicit schema) before use.

## Testing

- `pytest` + fixtures; mock boundaries with `unittest.mock` / `respx` (HTTP) / fake clocks.
- Property-based tests with `hypothesis` for broad-input invariants.
- Test failure paths: raised exceptions, timeouts, malformed input.

## Observability

- `opentelemetry-sdk` + instrumentation libraries for the frameworks in use; export via OTLP.
- Structured logging via `structlog` (or stdlib `logging` with a JSON formatter) carrying trace IDs.
- For LLM/agent calls, use the Langfuse SDK or OTel GenAI instrumentation.

## Documentation

- **PEP 257 docstrings, Google style** (`Args:` / `Returns:` / `Raises:`) on every public module,
  class, and function — or NumPy style if the repo already uses it; be consistent. See
  [`documentation.md`](documentation.md).
- Lint doc coverage with `ruff` pydocstyle (`D`) rules and/or `interrogate`; generate with Sphinx
  (napoleon) or mkdocstrings. Use `doctest` for runnable examples.
