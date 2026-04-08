---
name: workflow-management
description: Discover, create, and maintain workflow definitions. Use when you notice repeating user flows or critical paths that should be tested.
---

## Before you start

1. Check if `docs/sessions/$(date +%Y-%m-%d).md` exists
2. If not, create it with a session header: `## Session — HH:MM` + `**Objective:** one-line summary`
3. Log your work continuously as you go — do not wait until the end

# Workflow Management

Workflows are the central piece connecting testing, bug tracking, and documentation. This skill helps you discover, create, and maintain them.

## When to use

- You notice a repeating user flow that's important
- You're building a new feature and realize it needs a testable workflow
- You're fixing a bug and there's no workflow covering that area
- The user asks you to add a workflow
- You're reviewing the project and see gaps in workflow coverage

## Discovering workflows

Look for these signals that something should be a workflow:

1. **User-facing flows** — sign up, log in, create/edit/delete content, checkout, upload
2. **Integration points** — API calls, webhook handlers, third-party service interactions
3. **Background processes** — job queues, scheduled tasks, sync operations
4. **Admin operations** — user management, configuration, deployments
5. **Critical paths** — anything where failure means the user can't complete their goal

Ask yourself: "If this broke, would a user notice?" If yes, it needs a workflow.

## Creating a workflow

### Step 1: Add to .claude/workflows.md

```markdown
## workflow-name

- **Description:** One line explaining what this does for the user
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
- **Verification command:** `npm test` or `npm run test:specific`
- **Baseline success:** What "passing" looks like in one sentence
- **Skip if:** When this test isn't relevant
- **Escalate if:** When to stop and ask the user
```

### Step 2: Create behavioral spec in docs/system/

Create `docs/system/<workflow-name>.md`:

```markdown
# Workflow: <Name>

## What it does
Describe the workflow from the user's perspective.

## Steps
1. User does X
2. System responds with Y
3. User sees Z

## Rules
- Rule 1 (e.g., "must complete within 5 seconds")
- Rule 2 (e.g., "invalid input shows inline errors, doesn't clear form")
- Rule 3 (e.g., "requires authentication")

## Edge cases
- What happens with empty input?
- What happens with very large input?
- What happens if the service is down?

## Last verified
YYYY-MM-DD — passed / failed (link to session log)
```

### Step 3: Create workflow bug file

Create `.claude/bugs/workflows/<workflow-name>.md`:

```markdown
# Bugs: <workflow-name>

Tracking file for bugs related to this workflow.
Linked from `.claude/bugs/agent-reported.md` and `user-reported.md`.

*No bugs tracked yet.*
```

## Maintaining workflows

After each fix-loop run or significant change:

1. **Update "Last verified"** in `docs/system/<workflow>.md`
2. **Add new bugs** to the matching `workflows/<name>.md` file
3. **Remove stale workflows** if a feature is removed
4. **Split large workflows** if they cover too many steps (keep each to 3-7 steps)

## Connecting workflows to everything else

- **Fix-loop** reads `.claude/workflows.md` to know what to test
- **Bugs** link to workflows via the `Workflow:` field in bug entries
- **Behavioral specs** in `docs/system/` are the detailed source of truth
- **Session logs** in `docs/sessions/` capture test results
- **Vault sync** picks up `docs/system/` and `docs/sessions/` every 5 minutes
