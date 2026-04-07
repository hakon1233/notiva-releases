---
name: test-first
description: Red-before-green bug fixing — write a failing test first, then fix.
---

# Test-First Bug Fixing

When fixing any bug, follow this discipline:

## Step 1: Reproduce (Red)
1. Understand the bug — what's expected vs what happens
2. Choose the smallest correct test layer:
   - Unit test (default) — for logic bugs
   - Integration test — when crossing module boundaries
   - E2E test — when the bug involves UI or multiple services
3. Write a test that FAILS, reproducing the bug
4. Run it — confirm it fails with the expected error

## Step 2: Fix (Green)
5. Implement the minimal fix
6. Run the test again — confirm it PASSES
7. Run the full test suite — confirm no regressions

## Step 3: Document
8. Update `.claude/bugs/` with fix details
9. Add regression check instructions to the bug entry
10. Move to `resolved.md` with the regression check

## Rules
- NEVER skip the failing test step
- NEVER present a bug as fixed without red → green evidence
- If you can't write a test, explain why and get user approval to proceed without one
