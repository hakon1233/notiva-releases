---
name: refactor-plan
description: Structured refactoring approach that preserves behavior and public APIs.
---

## Before you start

1. Check if `docs/sessions/$(date +%Y-%m-%d).md` exists
2. If not, create it with a session header: `## Session — HH:MM` + `**Objective:** one-line summary`
3. Log your work continuously as you go — do not wait until the end

# Refactor Plan

Before changing any code, produce a plan that covers:

## Analysis
1. Read AGENTS.md and CLAUDE.md for project conventions
2. Identify all files that will be touched
3. Map public exports and import paths that must remain stable
4. Find all tests covering the affected code

## Plan output
Produce a structured plan with:
- What's changing and why
- Files affected (with current line counts)
- Public APIs that must remain stable (or shim strategy)
- Exact validation commands to run at each step
- Sequence of changes to minimize risk (smallest safe steps)

## Execution rules
- Run validation after EACH step, not just at the end
- If a step breaks validation, revert before continuing
- Keep public import paths stable — add shims if needed
- Update tests to match new structure
- Update docs if architecture changed
