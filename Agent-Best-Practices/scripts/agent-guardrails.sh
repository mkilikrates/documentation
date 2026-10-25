#!/usr/bin/env bash
# Mechanical enforcement of the non-negotiable process rules in AGENTS.md.
# Usage: scripts/agent-guardrails.sh <base-ref>
# Exits non-zero (fails the PR) when a rule is violated. Tune the globs/thresholds per repo.
set -euo pipefail

BASE="${1:-origin/main}"
echo "Guardrails: diffing against ${BASE}"

# Files changed in this PR.
CHANGED="$(git diff --name-only "${BASE}"...HEAD || true)"
if [ -z "${CHANGED}" ]; then
  echo "No changed files detected; skipping."
  exit 0
fi
echo "Changed files:"; echo "${CHANGED}" | sed 's/^/  - /'

fail=0
note() { echo "::error::$1"; fail=1; }

# --- Rule 1: code changes must touch CHANGELOG.md (AGENTS.md §8) ---
# Tune CODE_GLOB to your source dirs/extensions.
CODE_GLOB='^(src/|lib/|app/|.*\.(py|ts|tsx|js|jsx|go|rs|java|rb))'
if echo "${CHANGED}" | grep -Eq "${CODE_GLOB}"; then
  if ! echo "${CHANGED}" | grep -q '^CHANGELOG.md$'; then
    note "Code changed but CHANGELOG.md was not updated (AGENTS.md §8)."
  fi
fi

# --- Rule 2: no new spec folder per feature (AGENTS.md §9) ---
# The single living spec is .agent/spec/. Flag any newly added spec folder elsewhere.
if echo "${CHANGED}" | grep -Eq '^\.kiro/specs/[^/]+/' ; then
  # allow the pointer symlink/README only
  if echo "${CHANGED}" | grep -Ev '^\.kiro/specs/(README\.md|main)$' | grep -Eq '^\.kiro/specs/[^/]+/'; then
    note "A new .kiro/specs/<feature>/ folder was added. Use the single living spec at .agent/spec/ (AGENTS.md §9)."
  fi
fi

# --- Rule 3: obvious committed-secret patterns (AGENTS.md §6) ---
# Lightweight heuristic; replace with gitleaks/trufflehog for real coverage.
SECRET_REGEX='(AKIA[0-9A-Z]{16}|-----BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY-----|xox[baprs]-[0-9A-Za-z-]+|ghp_[0-9A-Za-z]{36})'
if git diff "${BASE}"...HEAD | grep -nE "^\+" | grep -Eq "${SECRET_REGEX}"; then
  note "Possible secret detected in the diff (AGENTS.md §6). Remove it and rotate the credential."
fi

# --- Rule 4: AGENTS.md is the single source of truth — tool pointers must not duplicate rules ---
# (Advisory) Warn if a pointer file grew large, suggesting rules were copied in.
for f in CLAUDE.md GEMINI.md .github/copilot-instructions.md; do
  if [ -f "$f" ]; then
    lines=$(wc -l < "$f")
    if [ "$lines" -gt 40 ]; then
      echo "::warning::$f has ${lines} lines — pointer files should stay thin and reference AGENTS.md, not restate it."
    fi
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "Guardrails failed. See errors above."
  exit 1
fi
echo "Guardrails passed."
