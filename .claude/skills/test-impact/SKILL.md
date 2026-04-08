---
name: test-impact
description: Check which tests are affected by code changes before committing.
---

## Before you start

1. Check if `docs/sessions/$(date +%Y-%m-%d).md` exists
2. If not, create it with a session header: `## Session — HH:MM` + `**Objective:** one-line summary`
3. Log your work continuously as you go — do not wait until the end

# Test Impact Analysis

When you modify code, check which tests might be affected before committing.

## Steps

1. **Note what you changed** — list the files you modified or created
2. **Find related tests** — look for tests that import from changed modules, test the same feature area, or live in nearby directories
3. **Run the affected tests** — if the project has `npm run test:suggest`, use it: `npm run test:suggest -- --query "<what you changed>" --changed <files>`
4. **If any tests fail** — fix them or document why

## When to use

- Before committing any code change
- After refactoring
- When the fix-loop identifies affected tests during Phase 1
