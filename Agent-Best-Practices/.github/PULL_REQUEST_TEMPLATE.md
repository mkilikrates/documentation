# Pull Request

## What changed
<!-- A concise summary of the change and why. -->

## Tier (see AGENTS.md §2)
<!-- Trivial / Local / Feature / Risky -->

## Checklist (Definition of Done — AGENTS.md §10; check what applies to the tier)

- [ ] Discovery done: read spec + capabilities + learnings; searched for an existing solution.
- [ ] Reused existing capabilities where possible; new components justified and added to `.agent/capabilities.md`.
- [ ] Build, lint, typecheck, and tests pass locally.
- [ ] Tests added/updated for the change (incl. failure paths); coverage floor met.
- [ ] Resilience applied where relevant (error handling, backoff, timeouts, isolation).
- [ ] Observability added (traces/logs/metrics; no secrets).
- [ ] Security reviewed (input validation, secrets, least privilege, deps).
- [ ] Living spec updated and integrated in place (not appended) — `.agent/spec/`.
- [ ] Human + developer docs updated; stale docs self-corrected.
- [ ] `.agent/learnings.md` updated if a non-obvious decision/lesson came up.
- [ ] `CHANGELOG.md` entry added; version bumped if releasable.
- [ ] No secrets or real personal data committed.

## What was tested
<!-- Commands run, scenarios covered. -->

## Not covered / follow-ups
<!-- Anything intentionally out of scope; link tracked tasks. -->
