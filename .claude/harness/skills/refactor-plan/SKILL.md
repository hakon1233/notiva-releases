---
name: refactor-plan
description: "Before pulling duplicated logic into a shared helper, extracting a function, splitting a class, or any cross-file dedup/restructure that preserves behavior: invoke `Skill('refactor-plan')` BEFORE editing — it owns the discipline of identifying the seams, planning the move, keeping the public API stable, and verifying no behavior change. Trigger phrases: 'extract this into a helper', 'pull the duplicated logic out', 'dedup these', 'split this module', 'restructure this'."
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
