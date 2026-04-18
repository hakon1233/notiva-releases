#!/bin/bash
# audit-stray-docs.sh — Find markdown files that live outside the vault-synced
# locations. See .claude/skills/docs-governance/SKILL.md for the rule.
#
# Exit 0 if clean, 1 if any stray files found.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

# Collect every .md / .mdx file, excluding dirs that are out of scope.
# We rely on `git ls-files` so we stay consistent with what's tracked and
# automatically skip node_modules, .next, and other gitignored paths.

tracked=$(git ls-files -- '*.md' '*.mdx' 2>/dev/null || true)

stray=()
while IFS= read -r file; do
  [[ -z "$file" ]] && continue

  # In-scope (synced)
  case "$file" in
    docs/*|\
    .claude/bugs/*|\
    .claude/test-runs/*|\
    .claude/workflows.md|\
    .claude/skills/*|\
    .claude/commands/*|\
    .claude/agents/*|\
    README.md|AGENTS.md|CLAUDE.md)
      continue
      ;;
  esac

  # Out-of-scope (legitimate non-docs — ignore)
  case "$file" in
    src/*|\
    plans/*|\
    templates/*|\
    e2e/*|\
    node_modules/*|\
    .next/*|\
    .github/*)
      continue
      ;;
  esac

  # Scoped AGENTS.md (e.g. server/AGENTS.md) — legitimate, keep in place.
  if [[ "$(basename "$file")" == "AGENTS.md" && "$file" != "AGENTS.md" ]]; then
    continue
  fi

  stray+=("$file")
done <<< "$tracked"

if [[ ${#stray[@]} -eq 0 ]]; then
  echo "OK: no stray docs."
  exit 0
fi

echo "Stray docs (should be moved into a synced location):"
for f in "${stray[@]}"; do
  echo "  $f"
done
exit 1
