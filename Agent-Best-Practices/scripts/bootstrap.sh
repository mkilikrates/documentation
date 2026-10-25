#!/usr/bin/env bash
# Bootstrap the agent best-practices template after copying it into a project root.
#
# Run this once from the template root (the directory containing AGENTS.md). It is idempotent and
# self-heals the two pointer symlinks, which can be lost when the template is copied via a ZIP
# download or a filesystem that doesn't preserve symlinks (git clone and `cp -a` preserve them, so
# this is only needed as a safety net).
#
#   cd <your-template-root> && bash scripts/bootstrap.sh
#
# What it does:
#   - Ensures .kiro/specs/main -> ../../.agent/spec
#   - Ensures .kiro/skills     -> ../.agent/skills
#   - Reports the remaining manual setup steps.
set -euo pipefail

# Resolve the template root as the parent of this script's directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT}"

if [ ! -f "AGENTS.md" ]; then
  echo "error: AGENTS.md not found in ${ROOT}." >&2
  echo "Run this from the template root (copy the template to your project root first)." >&2
  exit 1
fi

# ensure_symlink <link-path> <target>
ensure_symlink() {
  local link="$1" target="$2"
  mkdir -p "$(dirname "${link}")"
  if [ -L "${link}" ]; then
    local current; current="$(readlink "${link}")"
    if [ "${current}" = "${target}" ]; then
      echo "ok:   ${link} -> ${target}"
      return
    fi
    echo "fix:  ${link} (was -> ${current})"
    rm -f "${link}"
  elif [ -e "${link}" ]; then
    # A real file/dir is sitting where the symlink should be (e.g. ZIP turned the link into a text
    # file, or a copy duplicated the directory). Replace it with the symlink.
    echo "fix:  ${link} (replacing non-symlink)"
    rm -rf "${link}"
  else
    echo "new:  ${link} -> ${target}"
  fi
  ln -s "${target}" "${link}"
}

ensure_symlink ".kiro/specs/main" "../../.agent/spec"
ensure_symlink ".kiro/skills" "../.agent/skills"

echo
echo "Symlinks are in place. Verifying they resolve:"
for l in ".kiro/specs/main" ".kiro/skills"; do
  if [ -e "${l}" ]; then echo "  resolves: ${l}"; else echo "  BROKEN:   ${l} (target missing?)" >&2; fi
done

echo
echo "Next steps (manual):"
echo "  1. Fill in placeholders:   grep -rn '<FILL IN>' ."
echo "  2. Keep the language standards you use in .agent/standards/, add others from _template.md."
echo "  3. Seed .agent/spec/ with your real requirements/design/tasks."
echo "  4. Wire CI in .github/workflows/ci.yml; enable ONE of .github/dependabot.yml or renovate.json."
echo "  5. Read AGENTS.md — it is the source of truth."
