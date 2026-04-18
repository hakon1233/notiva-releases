#!/bin/bash
# setup.sh — one-command onboarding for a fresh clone.
# Installs deps, activates husky, makes scripts executable, runs a smoke check.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> Installing dependencies"
if [[ -f package.json ]]; then
  npm install
else
  echo "   (no package.json — skipping npm install)"
fi

echo "==> Installing commit tooling"
if [[ -f package.json ]]; then
  npm install --save-dev --silent husky @commitlint/cli @commitlint/config-conventional || {
    echo "   WARN: commit tooling install failed — commits won't be validated"
  }
  if command -v npx >/dev/null; then
    npx husky install 2>/dev/null || true
  fi
fi

echo "==> Marking scripts executable"
find scripts -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
find .husky -type f -not -name "*.md" -exec chmod +x {} + 2>/dev/null || true

echo "==> Smoke-checking docs governance"
if [[ -x scripts/docs/audit-stray-docs.sh ]]; then
  scripts/docs/audit-stray-docs.sh || echo "   (stray docs found — see output above)"
fi
if [[ -x scripts/docs/generate-skills-index.sh ]]; then
  scripts/docs/generate-skills-index.sh
fi

echo ""
echo "Setup complete. Next:"
echo "  - Read docs/system/how-the-system-works.md for the system overview"
echo "  - Fill in AGENTS.md and CLAUDE.md with project specifics"
echo "  - Run 'npm test' or 'npm run dev' to verify the project builds"
