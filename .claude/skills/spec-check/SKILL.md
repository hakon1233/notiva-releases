---
name: spec-check
description: Verify code changes are consistent with project documentation and specs.
---

# Spec Check

After making significant changes, verify documentation is in sync.

## What to check
1. Read `docs/` for system specs, architecture docs, ADRs
2. Read `AGENTS.md` for project conventions and rules
3. Read `docs/decisions/` for past architectural decisions

## Verify
- New behavior is documented (or flag it as needing docs)
- Changed behavior matches what docs describe (or update docs)
- No contradictions between code and documentation
- Past ADR decisions are respected (not accidentally reversed)
- README is still accurate

## Report
List: what's covered, what's missing documentation, what contradicts existing docs.
If you find drift, fix the docs as part of your current work — don't leave it for later.
