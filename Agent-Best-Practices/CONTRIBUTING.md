# Contributing

Thanks for contributing. This repository is driven by the rules in
[`AGENTS.md`](./AGENTS.md) — they apply to humans and AI agents alike. Read it first.

## Before you start

1. Read [`AGENTS.md`](./AGENTS.md) (the source of truth).
2. Read the living spec at [`.agent/spec/`](./.agent/spec/).
3. Read [`.agent/capabilities.md`](./.agent/capabilities.md) and
   [`.agent/learnings.md`](./.agent/learnings.md) — **reuse what exists; don't reinvent.**

## Workflow

1. **Discover before building** — search for an existing solution first (`AGENTS.md` §1).
2. **Scale rigor to the task** — pick the tier (`AGENTS.md` §2).
3. **Update the living spec** for behavioral changes (requirements → design → tasks), integrating in
   place, not appending (`AGENTS.md` §9).
4. **Implement** with resilience, observability, and security by default (standards in
   [`.agent/standards/`](./.agent/standards/)).
5. **Test** — new/changed code ships with tests meeting the coverage floor (`AGENTS.md` §3).
6. **Sync docs** — human + agent docs, capabilities, learnings (`AGENTS.md` §7).
7. **Governance** — changelog entry + version bump if releasable (`AGENTS.md` §8).
8. **Verify** — build, lint, typecheck, tests pass. Then open a PR using the template.

## Pull requests

- Branch off `main`; never push directly to `main`.
- Keep PRs focused. Fill in the PR template (what changed, what was tested, what isn't covered).
- The Definition of Done is in [`AGENTS.md`](./AGENTS.md) §10 — satisfy the items that apply to your
  tier.

## Code of conduct

By participating you agree to the [Code of Conduct](./CODE_OF_CONDUCT.md).

## Security

Do not open public issues for vulnerabilities — follow [`SECURITY.md`](./SECURITY.md).
