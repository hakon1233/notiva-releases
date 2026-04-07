# Bug Tracking System

Structured tracking of bugs and issues found during testing, organized by workflow area.

## Structure

```
.claude/bugs/
├── README.md              # This file
├── agent-reported.md      # Bugs found by automated testing agents
├── user-reported.md       # Bugs reported by the user
├── resolved.md            # Archive of fixed bugs (for regression checks)
└── workflows/             # Per-workflow bug files (one per workflow in workflows.md)
```

## How it works

### Reporting
- **Agents** write to `agent-reported.md` when they find issues during testing
- **Users** tell the agent what's wrong; the agent writes to `user-reported.md`
- Each entry also gets added to the matching `workflows/*.md` file

### Entry format
```markdown
### [BUG-XXX] Short title
- **Status:** open | fixing | fixed | wont-fix | needs-user-input
- **Severity:** critical | warning | info
- **Found:** YYYY-MM-DD by agent|user
- **Fixed:** YYYY-MM-DD in commit <hash> (when resolved)
- **Workflow:** workflow-name
- **Description:** What's wrong
- **Evidence:** Log output, screenshots, or steps to reproduce
- **Root cause:** Why it happens (once known)
- **Fix:** What was done (once fixed)
```

### Lifecycle
1. Bug found → added to `agent-reported.md` or `user-reported.md` + matching `workflows/*.md`
2. Fix implemented → status changes to `fixing`, then `fixed` with commit hash
3. Fix verified → entry moves to `resolved.md` with regression check instructions
4. Every test run → agent reads `resolved.md` and verifies no regressions

### Workflow files
Create one file per workflow declared in `.claude/workflows.md`. The fix loop will reference these to track issues per area. Example:

```
workflows/
├── web-ui.md
├── api.md
└── background-jobs.md
```
