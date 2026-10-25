# Dependency & Code Freshness Standard

Concrete backing for keeping code and its libraries current, safe, and maintainable. Complements
[`security.md`](security.md) (which covers the *safety* of dependencies — pinning, vuln scanning,
typosquats, supply-chain integrity); this file covers the *currency* discipline: staying up to date
without breaking things.

**Goal:** dependencies drift toward out-of-date, unsupported, and vulnerable unless actively
maintained. Treat updates as routine, small, and continuous — not a rare, risky big-bang.

## Principles

- **Pin, then update deliberately.** Lockfiles pin exact versions for reproducible builds
  (`security.md`); manifests express the *allowed* range. Updating is a conscious, reviewed change —
  never an automatic floating resolve at build time.
- **Small and frequent beats large and rare.** Many small upgrades are each easy to review and
  revert. A once-a-year mega-upgrade is where breakage and regressions hide.
- **Tests are the safety net.** An upgrade is only safe if the suite (unit + integration) passes.
  This is why the coverage floor in `AGENTS.md` §3 matters for upgrades too.
- **Currency is a Local-tier change by default** (`AGENTS.md` §2), but a major-version bump or a
  framework/runtime upgrade is a **Feature** or **Risky** change — scope it accordingly.

## Classify every update (semver)

- **Patch** (`x.y.Z`): bug/security fixes. Low risk — adopt quickly, ideally automated.
- **Minor** (`x.Y.z`): backward-compatible features. Low/medium — batch and review weekly.
- **Major** (`X.y.z`): breaking changes. Medium/high — read the changelog/migration guide, do it in
  its own PR, update call sites, run the full suite. Never bundle a major bump with unrelated work.

## Cadence & automation

- **Automate discovery** with a bot (Dependabot / Renovate / equivalent) that opens PRs for updates.
  Configure it to:
  - Group low-risk updates (patch/minor of dev dependencies) into batched PRs.
  - Open **security** updates immediately and label them.
  - Raise major-version bumps as **separate** PRs so they get individual review.
- **Review cadence:** triage dependency PRs on a regular cycle (e.g. weekly); don't let them pile
  up. Security updates jump the queue.
- **Every dependency PR still obeys the Definition of Done** — tests pass, changelog entry if it
  affects behavior, no secrets.

## Handling breaking changes & deprecations

- **Read the release notes / migration guide** before a major bump. Don't guess.
- **Act on deprecation warnings when they appear**, not when the feature is removed. A deprecation
  is a dated invitation to migrate; log a task in `.agent/spec/tasks.md` if it can't be done
  immediately.
- **Upgrade one major dependency per PR** so a regression is easy to bisect and revert.
- Record non-obvious migration gotchas in [`../learnings.md`](../learnings.md) so the next upgrade
  is cheaper.

## Runtime, language, and toolchain currency

- Keep the **language runtime / SDK** on a supported release; plan the move off a version before it
  reaches end-of-life. Track EOL dates for runtimes, frameworks, OS base images, and databases.
- Pin runtime versions in the repo (`.tool-versions`, `go.mod`, `engines`, `pyproject.toml`) and
  bump them deliberately like any other dependency.
- Rebuild and re-pin **container base images** regularly so OS-level CVEs get patched; prefer
  minimal, digest-pinned base images.

## Health & hygiene

- **Prune unused dependencies** (`depcheck`, `pip-autoremove`, `go mod tidy`, etc.). The smallest
  dependency set is the easiest to keep current and the smallest attack surface.
- **Watch for unmaintained / abandoned packages** (no releases, archived repo, unpatched CVEs).
  Plan a replacement before it becomes a liability; note the decision in `learnings.md`.
- **Keep the lockfile honest:** regenerate it with the manifest change in the same commit; CI should
  fail if the lockfile is stale relative to the manifest.
- **Reproducible installs in CI** (`npm ci`, `pip install` from a locked file, `go mod verify`) —
  never let CI resolve floating versions.

## Automation configs provided

This template ships both options — **enable exactly one**:

- `.github/dependabot.yml` — GitHub-native, zero extra setup.
- `renovate.json` — more grouping/scheduling control (requires the Renovate app/CI).

Both are preconfigured to batch low-risk updates, raise majors as individual PRs, and fast-track
security updates.

## CI gates (wire these up)

- Scheduled dependency-update PRs (bot — Dependabot or Renovate above).
- Vulnerability + license scan on every PR (shared with `security.md`).
- A check that the lockfile matches the manifest.
- The full test suite runs on every dependency PR before merge.

## Per-language specifics

The exact tools live in each language standard:

- Python → [`python.md`](python.md) (`uv`/`poetry`, `pip-audit`, lockfile)
- TypeScript → [`typescript.md`](typescript.md) (`npm/pnpm`, `npm audit`, lockfile)
- Go → [`go.md`](go.md) (`go get -u`, `go mod tidy`, `govulncheck`)

## Checklist (per dependency change)

- [ ] Change classified (patch/minor/major) and scoped to the right tier.
- [ ] Major bumps are in their own PR, with the migration guide read and call sites updated.
- [ ] Lockfile regenerated and committed alongside the manifest.
- [ ] Full test suite passes; vuln + license scan clean.
- [ ] Deprecation warnings addressed or tracked as tasks.
- [ ] Unused dependencies pruned.
- [ ] Changelog entry if behavior changed; non-obvious migration notes in `learnings.md`.
