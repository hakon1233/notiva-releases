#!/bin/bash
# activate-husky.sh — Install husky + commitlint + wire the commit-msg hook.
# Idempotent: safe to re-run. Does nothing if package.json is missing.
#
# Used by:
#   - scripts/setup.sh (runs automatically on fresh clone)
#   - bootstrap-claude-template.sh (runs post-deploy on repos with package.json)
#   - Humans, directly, one-off.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [[ ! -f package.json ]]; then
  echo "activate-husky: no package.json — skipping"
  exit 0
fi

# 1. Install husky + commitlint devDeps only if missing (don't trigger unnecessary package-lock churn)
need_install=()
grep -q '"husky"' package.json || need_install+=("husky")
grep -q '"@commitlint/cli"' package.json || need_install+=("@commitlint/cli")
grep -q '"@commitlint/config-conventional"' package.json || need_install+=("@commitlint/config-conventional")

if [[ ${#need_install[@]} -gt 0 ]]; then
  echo "activate-husky: installing ${need_install[*]}"
  npm install --save-dev --silent "${need_install[@]}"
else
  echo "activate-husky: deps already present"
fi

# 2. Run husky install (sets git config core.hooksPath .husky)
echo "activate-husky: husky install"
npx --no -- husky install >/dev/null 2>&1 || npx husky >/dev/null 2>&1 || true

# 3. Deposit / refresh the commit-msg hook
mkdir -p .husky
cat > .husky/commit-msg <<'HOOK'
#!/usr/bin/env sh
# Validate commit messages against conventional commits (feat/fix/chore/docs/…).
# Installed by scripts/activate-husky.sh.
npx --no -- commitlint --edit "$1"
HOOK
chmod +x .husky/commit-msg

# 4. Ensure commitlint.config.js exists
if [[ ! -f commitlint.config.js ]]; then
  cat > commitlint.config.js <<'CONFIG'
export default {
  extends: ["@commitlint/config-conventional"],
};
CONFIG
  echo "activate-husky: wrote commitlint.config.js"
fi

echo "activate-husky: done — next commit will be validated"
