# Kiro specs → canonical spec

This project keeps **one living, tool-neutral spec** at [`.agent/spec/`](../../.agent/spec/)
(Option A in the template design). This folder exists only so Kiro users find the spec from the
familiar `.kiro/specs/` location.

- The real `requirements.md`, `design.md`, and `tasks.md` live in `.agent/spec/`.
- A symlink `.kiro/specs/main` → `../../.agent/spec` points there (created by the template; if your
  filesystem or a zip extraction dropped the symlink, recreate it with
  `ln -s ../../.agent/spec .kiro/specs/main`, or just read `.agent/spec/` directly).

**Do not create a new spec folder per feature.** Everything integrates into the single living spec
(see [`AGENTS.md`](../../AGENTS.md) §9).

> Note: because the canonical spec lives outside `.kiro/specs/`, Kiro's native spec-task runner
> treats `.agent/spec/` as plain files rather than a managed spec. That is the intended trade for
> cross-tool portability. If a specific project wants Kiro's managed task execution, move the
> canonical files into `.kiro/specs/<name>/` and point `.agent/spec` back at them instead.
