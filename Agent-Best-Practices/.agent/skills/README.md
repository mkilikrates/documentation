# Skills

> Reusable, self-contained capabilities an agent can invoke — a documented procedure plus any
> supporting scripts/resources. Skills follow the same discipline as the spec (see
> [`AGENTS.md`](../../AGENTS.md) §9):
>
> - **One living document per skill** — current-state, not a changelog.
> - **Search before you add.** Before writing a new skill, check whether an existing one covers the
>   need and extend it instead of duplicating.
> - **Reuse and improve over reinvent.**

## Layout

```
.agent/skills/
  README.md                 # this file
  <skill-name>/
    SKILL.md                # what it does, when to use it, inputs/outputs, steps
    <supporting files>      # scripts, templates, references (optional)
```

## Writing a skill

Each `SKILL.md` should answer, concisely:

1. **Name & purpose** — what the skill does.
2. **When to use / when not to use** — the trigger and the boundaries.
3. **Inputs & outputs** — what it needs and what it produces.
4. **Procedure** — the steps, deterministic where possible.
5. **Failure handling** — what to do when a step fails (align with `AGENTS.md` §4).
6. **Reuse notes** — related skills/capabilities so the next agent extends rather than forks.

Keep skills small and composable. If two skills overlap, merge them. Register broadly-useful
building blocks in [`../capabilities.md`](../capabilities.md) too.

## Tool mapping

- **Kiro** reads skills from `.kiro/skills/`; this repo keeps the canonical skills here under
  `.agent/skills/` and points Kiro at them (see the root `README.md` wiring section).
- Other agents can be pointed at this directory directly.
