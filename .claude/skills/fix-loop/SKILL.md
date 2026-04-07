---
name: fix-loop
description: Automated test-fix-verify loop. Tests project workflows, fixes obvious bugs, tracks issues, and reports uncertain items for user review.
---

# Fix Loop

Automated test → triage → fix → deploy → verify cycle for any project. Reads workflow definitions from `.claude/workflows.md` and tracks bugs in `.claude/bugs/`.

## Pre-flight

Before starting the loop:

1. **Read the bug tracking system:**
   - `.claude/bugs/resolved.md` — previously fixed bugs with regression checks
   - `.claude/bugs/agent-reported.md` — known open bugs
   - `.claude/bugs/user-reported.md` — user-reported issues
   - `.claude/bugs/workflows/*.md` — per-workflow status

2. **Read workflow definitions:**
   - `.claude/workflows.md` — what to test and how

3. **Check system readiness:**
   - Run each workflow's verification command (if defined) to get a baseline
   - Verify any required services are running
   - Verify any required URLs are reachable

4. **Note the current state:**
   - `git log --oneline -1` — current commit
   - `git status` — any uncommitted changes

## The Loop

Repeat until done (max 5 iterations, or fewer if nothing left to fix):

### Phase 1: Test

For each workflow in `.claude/workflows.md`, launch a subagent with the appropriate test method:

#### chrome-mcp workflows
- Create a tab, navigate to the workflow's URL
- Execute the test actions described in the workflow
- Screenshot at key moments
- Check browser console for errors via `read_console_messages` with pattern `error|Error|ERR`
- Report what worked and what failed

#### playwright workflows
- Run playwright tests or use the playwright CLI
- Capture screenshots and trace files
- Report failures with error details

#### curl workflows
- Execute each curl command
- Check response status codes and bodies
- Compare against expected behavior

#### bash workflows
- Run each bash command
- Check process state, log files, file contents
- Look for errors, warnings, stuck processes

#### test-suite workflows
- Run the specified test command
- Report failures with file paths and error messages

#### Regression checks
- Read `.claude/bugs/resolved.md`
- For each resolved bug, run its regression check
- Flag any regressions as CRITICAL

### Phase 2: Triage

Categorize each finding:

| Category | Criteria | Action |
|----------|----------|--------|
| **Sure fix** | Obviously broken, clear root cause, safe to fix | Fix it |
| **Needs user input** | Unclear intent, risky change, design decision | Log for user |
| **Regression** | Previously fixed bug reappeared | Fix immediately (CRITICAL) |
| **Already known** | Matches an open bug in the tracking system | Update status |
| **Working** | Expected behavior confirmed | Note as verified |

### Phase 3: Fix

For each "sure fix" and "regression":

1. Implement the fix (directly or via subagent)
2. Run the project's verification command (from the workflow definition or `npm run verify:changed` or `npm test`)
3. Update bug tracking files:
   - Add new bugs to `.claude/bugs/agent-reported.md` and matching `workflows/*.md`
   - Update status of fixed bugs to `fixing` → `fixed`
   - Add fix details: commit hash, root cause, regression check

### Phase 4: Deploy

1. Commit changes with a descriptive message
2. Push to the deploy branch
3. Run any deploy commands defined in workflows (service restarts, builds, etc.)
4. Wait for deploy to complete

### Phase 5: Decide — continue or stop

**Stop if:**
- No new "sure fix" bugs were found in Phase 2
- All regressions are resolved
- Only "needs user input" items remain

**Continue if:**
- Fixes were deployed and need verification
- New issues might have been introduced by fixes

### Phase 6: Report

When the loop ends, produce:

```markdown
## Fix Loop Results

### Completed: N iterations

### Fixed this run:
- [BUG-XXX] Description → commit hash
- [BUG-XXX] Description → commit hash

### Needs your input:
- Description — why it needs user decision
- Description — why it needs user decision

### Verified working:
- Workflow A ✓
- Workflow B ✓

### Regression status:
- N previously fixed bugs checked, N still fixed, N regressed
```

## Bug entry format

When adding bugs to the tracking files, use:

```markdown
### [BUG-XXX] Short title
- **Status:** open | fixing | fixed | wont-fix | needs-user-input
- **Severity:** critical | warning | info
- **Found:** YYYY-MM-DD by agent|user
- **Fixed:** YYYY-MM-DD in commit <hash>
- **Workflow:** workflow-name
- **Description:** What's wrong
- **Evidence:** Log output, error messages, or steps to reproduce
- **Root cause:** Why it happens
- **Fix:** What was done
```

When moving to `resolved.md`, add:
```markdown
- **Regression check:** How to verify this bug hasn't come back
```

## Guardrails

- **Never skip verification** — run tests before committing
- **Don't fix uncertain items** — log them for user review instead
- **Sequential subagents for Chrome MCP** — parallel agents fight over shared tabs
- **Rotate test targets** across iterations for broader coverage
- **Update bug files** after every fix, not in batches at the end
- **Stop after 5 iterations max** — if the loop hasn't converged, something deeper is wrong
