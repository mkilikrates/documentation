# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Every behavior change, bug fix, or feature **must** add an entry under `[Unreleased]` in the
appropriate section (Added / Changed / Fixed / Removed / Security). On release, rename
`[Unreleased]` to the new version with a date.

## [Unreleased]

### Added
- Initial reusable agent best-practices template: tool-agnostic `AGENTS.md` as the single source of
  truth; `.agent/` home for the living spec, capabilities inventory, learnings log, skills, and
  standards (resilience, observability, security, per-language); thin tool pointers for Kiro,
  Claude, Cursor, Copilot, Gemini, Codex; git governance files; and CI guardrails.
- Go language standard (`.agent/standards/go.md`), scoped to `**/*.go`.
- Dependency & code freshness standard (`.agent/standards/dependencies.md`) covering update cadence,
  automation, breaking-change handling, deprecations, and EOL tracking; wired into `AGENTS.md` §6,
  the language standards, CI, and a `.github/dependabot.yml` for automated update PRs.
- Renovate config (`renovate.json`) as an alternative to Dependabot for automated dependency PRs.
- Code documentation standard (`.agent/standards/documentation.md`): per-language docstring/doc-comment
  conventions (Google-style, TSDoc/JSDoc, Go doc comments, Javadoc, Rustdoc), doc-comment contract,
  and doc-coverage linting; wired into `AGENTS.md` §7 and the Python/TypeScript/Go standards.
- `scripts/bootstrap.sh` — idempotent setup script that self-heals the pointer symlinks
  (`.kiro/specs/main`, `.kiro/skills`) after copying the template, so adoption works regardless of
  the copy method (including ZIP downloads). Referenced from the adoption steps in the README.
