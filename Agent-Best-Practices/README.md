# Agent Best Practices — reusable template

A drop-in, tool-agnostic system for making AI coding agents (Kiro, Claude Code, Cursor, Codex,
Copilot, Gemini, …) produce **high-quality, resilient, well-documented, reuse-first** code in any
repository.

The whole thing rests on one idea: **one source of truth, pointed at by every tool, and enforced by
automation where it matters.**

## What's in here

```
AGENTS.md                      # THE source of truth — rules for every agent and human
.agent/                        # tool-neutral canonical home for living docs
  spec/                        # ONE living spec (requirements, design, tasks) — not one-per-feature
  capabilities.md              # reuse inventory: "these exist, reuse them" (anti-reinvention)
  learnings.md                 # read before starting, append when done (the learning loop)
  skills/                      # reusable skills, same single-living-doc discipline
  standards/                   # resilience, observability, security + per-language (scoped by file)
.kiro/                         # Kiro wiring: steering includes AGENTS.md; specs/skills point to .agent/
  steering/agents.md           #   inclusion: always → includes AGENTS.md
  specs/main -> ../../.agent/spec   # symlink pointer (Option A)
  skills   -> ../.agent/skills      # symlink pointer
  hooks/                       #   doc-sync reminder hook
CLAUDE.md / GEMINI.md / .cursor/rules/agents.mdc / .github/copilot-instructions.md  # thin pointers
.github/                       # CI, guardrails, issue/PR templates
scripts/agent-guardrails.sh    # mechanical enforcement of the non-negotiable process rules
CHANGELOG.md CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md LICENSE .gitignore
```

## Core ideas

- **Single source of truth.** `AGENTS.md` holds all rules. Every tool's rules file is a thin pointer
  — no rule is ever duplicated (so nothing drifts). Codex reads `AGENTS.md` natively.
- **Discover before building → reuse over reinvent.** Agents reinvent whatever they don't know
  exists. The living spec + `.agent/capabilities.md` make existing context unavoidable before new
  code is written.
- **One living spec, not one-per-feature.** A fresh spec folder reads as greenfield and triggers
  reinvention. A single current-state spec forces reuse. Works only alongside the "integrate, don't
  append" rule (`AGENTS.md` §9).
- **Scale rigor to the task.** Trivial / Local / Feature / Risky tiers so a typo fix isn't buried in
  ceremony (`AGENTS.md` §2).
- **Resilience, observability, security by default.** Backoff + timeouts + circuit breakers so one
  dependency can't sink the system; OTel + Langfuse-style agent tracing; input validation, secrets
  hygiene, least privilege (`.agent/standards/`).
- **Keep everything in sync, in the same change** — and **self-correct stale docs.**
- **Enforce what you can mechanically.** CI + a guardrails script + a Kiro hook back the rules that
  would otherwise rely on memory.

## Using this template in a new project

1. **Copy the template to your new project's root** (so the dot-folders and `AGENTS.md` sit at the
   repo root, where tools look for them). Use a symlink-preserving copy:
   ```bash
   cp -a Agent-Best-Practices/. /path/to/your/project/    # or: rsync -a, or git clone
   ```
   Avoid copying via a GitHub **ZIP download** — it turns the two symlinks into plain text files.
   If you do, step 2 repairs them.
2. **Run bootstrap** from your project root once. It self-heals the pointer symlinks (idempotent)
   and prints the remaining setup steps:
   ```bash
   bash scripts/bootstrap.sh
   ```
3. **Fill in the `<FILL IN>` placeholders** — search for them:
   ```bash
   grep -rn "<FILL IN>" .
   ```
   They cover: license holder/year, security contact, coverage floor, backoff numbers, toolchain
   commands, and CI steps.
4. Keep the language standards you use (`.agent/standards/python.md`, `typescript.md`, …), add
   others from `_template.md`, and delete the rest.
5. Seed `.agent/spec/` with your real requirements/design/tasks, and start the capabilities
   inventory as you build.
6. Wire CI: fill in `.github/workflows/ci.yml` with your real build/test/lint commands; the
   guardrails workflow works as-is (tune the globs in `scripts/agent-guardrails.sh`). Enable **one**
   of `.github/dependabot.yml` or `renovate.json` for automated dependency updates.

> Symlinks: `git clone`, `cp -a`, and `rsync -a` preserve them, so step 2 is just a safety net.
> `scripts/bootstrap.sh` recreates `.kiro/specs/main -> ../../.agent/spec` and
> `.kiro/skills -> ../.agent/skills` if a copy method dropped them.

## Option A vs B (spec home)

This template uses **Option A**: the canonical spec lives in the tool-neutral `.agent/spec/`, and
`.kiro/specs/` points to it. Maximum portability across tools; the trade is that Kiro's *managed*
spec-task runner treats it as plain files. If a project wants Kiro's managed task execution, move
the canonical files into `.kiro/specs/<name>/` and point `.agent/spec` back at them (Option B). See
[`.kiro/specs/README.md`](.kiro/specs/README.md).

## Start here

Read [`AGENTS.md`](./AGENTS.md).
