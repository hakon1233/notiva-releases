---
name: workflow-management
description: Use PROACTIVELY when discovering, creating, renaming, or removing workflow definitions. MUST BE USED when adding a new user-facing flow that needs testing, or when the user asks for workflow changes. Owns the four-file workflow contract (registry + spec + bug file + fix-loop binding).
last_updated: 2026-04-18
---

# Workflow Management

Workflows are the unit of testable user-facing behavior. Each workflow touches four files that together form one system; this skill owns the rules for creating, maintaining, and retiring them.

## The four-file workflow contract

| Role | File | Owner skill |
|---|---|---|
| Registry (how to test) | `.claude/workflows.md` — one entry per workflow | this skill |
| Behavioral spec (what it should do) | `docs/system/<workflow-name>.md` | this skill |
| Bug tracker (per-workflow) | `.claude/bugs/workflows/<workflow-name>.md` | `test-first` + `fix-loop` |
| Fix-loop rhythm | `.claude/skills/fix-loop/SKILL.md` | `fix-loop` |

All four live inside the vault-synced allowlist (see `docs-governance`), so vault/Obsidian always sees the full state.

## When to create a workflow

Signals that something should become a workflow:

1. **User-facing flows** — sign up, log in, create/edit/delete, checkout, upload.
2. **Integration points** — API calls, webhook handlers, third-party service interactions.
3. **Background processes** — job queues, scheduled tasks, sync operations.
4. **Admin operations** — user management, configuration, deployments.
5. **Critical paths** — anything where failure means the user can't complete their goal.

Rule of thumb: *if it broke, would a user notice?* If yes, it's a workflow.

## Creating a workflow — three steps

### 1. Add an entry to `.claude/workflows.md`

```markdown
## <workflow-name>

- **Description:** One-line user-facing summary.
- **Test methods:** chrome-mcp | playwright | curl | bash | test-suite
- **URL:** (if browser-based)
- **Steps:**
  1. First thing that happens
  2. Next thing
  3. Expected result
- **What to check:**
  - Expected behavior A
  - Expected behavior B
  - No errors in console/logs
- **Test actions:**
  - Specific commands or UI actions to exercise the flow
- **Verification command:** `npm test` or a workflow-specific command
- **Baseline success:** What "passing" looks like, one sentence
- **Skip if:** When this test isn't relevant (e.g. "dev server not running")
- **Escalate if:** When to stop and ask the user (e.g. "auth provider changed")
```

### 2. Create the behavioral spec at `docs/system/<workflow-name>.md`

```markdown
# Workflow: <Name>

## What it does
Describe the flow from the user's perspective.

## Steps
1. User does X
2. System responds with Y
3. User sees Z

## Rules
- Must complete within <time>
- Invalid input shows inline errors, doesn't clear form
- Requires authentication

## Edge cases
- What happens with empty input?
- What happens with very large input?
- What happens if a dependency is down?

## Last verified
YYYY-MM-DD — passed / failed (link to session log)
```

### 3. Create the empty bug file at `.claude/bugs/workflows/<workflow-name>.md`

```markdown
# Bugs: <workflow-name>

Per-workflow view of bugs. Entries also live in the root bug files
(`.claude/bugs/{agent-reported,user-reported,resolved}.md`).

*No bugs tracked yet.*
```

The `bug-fixer` agent and `fix-loop` skill both read this file as part of their loop.

## Naming rules

- Lowercase, hyphens, no spaces: `checkout-flow`, `user-signup`, `background-jobs`.
- Short enough to be memorable: ≤3 words where possible.
- Same slug across all four files.
- Don't prefix with the project name — the repo context is implicit.

## Maintaining workflows

After each fix-loop run or significant change:

1. Update `Last verified` in `docs/system/<workflow>.md`.
2. Add any newly discovered bugs to the matching `bugs/workflows/<name>.md`.
3. Keep root bug files (`agent-reported.md`, `user-reported.md`, `resolved.md`) and the per-workflow file in sync — `fix-loop` enforces this.
4. **Split large workflows** if they cover more than ~7 steps or multiple personas. Each workflow should exercise one coherent slice.
5. **Retire stale workflows** when a feature is removed — delete all four artifacts in one commit, grep for references first.

## Connecting workflows to other skills

- `fix-loop` reads `.claude/workflows.md` to pick targets. Delegates the bug-fix rhythm to `test-first`.
- `bug-fixer` agent reads the per-workflow bug file before any fix.
- `docs-governance` ensures all four file locations stay in the synced allowlist.
- `writing-skills` owns frontmatter rules for any new skills related to workflows.

## When to skip creating a workflow

- The code is exploratory/throwaway and you don't plan to keep it.
- It's pure refactoring with no user-visible behavior change.
- It's a one-off script (cron, migration) — those belong in `docs/runbooks/`, not as a workflow.
