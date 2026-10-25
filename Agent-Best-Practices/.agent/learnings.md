# Learnings Log

> **The learning loop (from [`AGENTS.md`](../AGENTS.md) §7):**
> - **Read this file before starting** a non-trivial task, so you do not repeat a past mistake or
>   re-litigate a settled decision.
> - **Append an entry when you finish** such a task, or whenever you hit a non-obvious problem and
>   resolved it.
>
> This is the one place the agent records what it *learned* so the knowledge compounds across
> sessions and across different tools/agents working in the repo.

## What makes a good entry

- **Context:** what you were doing and what surprised you.
- **Decision or lesson:** what you concluded, and why.
- **Consequence:** what future agents should do (or avoid) because of it.

Keep entries flat and durable. If a decision changes a rule or a shared pattern, also update the
relevant living document (`AGENTS.md`, `capabilities.md`, `standards/`, the spec) — the log records
*why*, the living documents record *what is true now*.

## Entries (newest first)

<!--
Template — copy, fill, place at the top of the list:

### YYYY-MM-DD — <short title>
- **Context:** …
- **Lesson / decision:** …
- **For future agents:** …
-->

### YYYY-MM-DD — Template repository initialized
- **Context:** This repo is a reusable agent best-practices template.
- **Lesson / decision:** The canonical rules live in `AGENTS.md`; the living spec and these logs
  live under `.agent/`; tool-specific files are thin pointers (Option A — tool-neutral canonical).
- **For future agents:** Edit the canonical file, not the pointers. Keep this log current.
