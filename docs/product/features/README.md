# Feature Proposals

Proposals ready enough to discuss but not yet ready to build. Lives here until promoted to a workflow / ticket / spec.

## File naming

`<feature-name>.md` — lowercase, hyphens, descriptive. Good: `bulk-import-csv.md`. Bad: `feature-001.md`.

## Suggested structure

```markdown
# Feature: <name>

- **Status:** proposed | in-discussion | accepted | rejected | shipped
- **Last updated:** YYYY-MM-DD

## Problem
<What user pain does this address? 1-2 sentences.>

## Proposed solution
<What would we build? Sketch the UX or API, not the implementation.>

## Alternatives considered
- Alternative A — why rejected
- Alternative B — why rejected

## Open questions
- Thing we don't know yet

## Risks / non-goals
- What could go wrong
- What we're explicitly NOT doing

## Links
- Related user feedback: `../users/<file>.md`
- Related competitor analysis: `../competitors/<file>.md`
```

## Lifecycle

1. **Proposed** → written, open for discussion.
2. **Accepted** → move the fact "we're doing this" into `docs/decisions/` as an ADR, then plan the work.
3. **Shipped** → add to workflow registry (`.claude/workflows.md`) if user-facing, mark status here, keep the file as historical record.
4. **Rejected** → keep the file with rationale — future-you asking "did we ever consider X?" should find the answer.
