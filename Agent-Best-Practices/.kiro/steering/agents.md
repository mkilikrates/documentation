---
inclusion: always
---

# Agent rules (Kiro entry point)

The single source of truth for how to work in this repository is **[`AGENTS.md`](../../AGENTS.md)**
at the repo root. Read it first and follow it for every task. This file only wires it into Kiro; it
does not restate or override the rules.

#[[file:AGENTS.md]]

## Kiro-specific notes

- **Living spec:** the canonical spec is at [`.agent/spec/`](../../.agent/spec/) (tool-neutral,
  Option A). The Kiro spec location under `.kiro/specs/` points at it — see
  [`.kiro/specs/README.md`](../specs/README.md). Do **not** create a new spec folder per feature
  (`AGENTS.md` §9).
- **Skills:** canonical skills live at [`.agent/skills/`](../../.agent/skills/). Kiro's
  `.kiro/skills/` points there.
- **Language standards load by file type.** The standards in `.agent/standards/` carry
  `inclusion: fileMatch` front-matter so, e.g., the Python rules only load when you touch `**/*.py`.
  That is deliberate — don't apply one language's rules to another.
- **Hooks:** if a project hook fires (tests, guardrails, doc-sync reminders), follow it. Don't
  disable project hooks to land a change.
