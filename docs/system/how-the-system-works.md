# How the Testing & Workflow System Works

This document explains how workflows, bug tracking, testing, session logging, and the Obsidian vault sync all fit together. It's the source of truth for the entire system.

## The Big Picture

```
Workflows (.claude/workflows.md)
  ↓ defines what to test
Fix Loop (.claude/skills/fix-loop/)
  ↓ tests each workflow, finds bugs
Bug Tracking (.claude/bugs/)
  ↓ tracks issues per workflow
Test-First Fixing (.claude/skills/test-first/)
  ↓ fixes bugs with red→green discipline
Session Logs (docs/sessions/)
  ↓ captures everything that happened
Vault Sync (every 5 min)
  ↓ docs/ flows to Obsidian vault
Obsidian Vault
  → browse all projects' docs, sessions, bugs, workflows
```

## Workflows Are the Central Piece

A workflow is a user-facing thing that must work. It connects testing, bugs, and documentation.

### Where workflow data lives

| What | Where | Syncs to vault? |
|------|-------|-----------------|
| Test definition (how to verify) | `.claude/workflows.md` | No (repo-local) |
| Behavioral spec (what should happen) | `docs/system/<workflow-name>.md` | Yes |
| Bugs for this workflow | `.claude/bugs/workflows/<name>.md` | No (repo-local) |
| Session logs from testing | `docs/sessions/YYYY-MM-DD.md` | Yes |

### Workflow lifecycle

1. **Discover** — agent or user notices a critical user flow
2. **Define** — add it to `.claude/workflows.md` with test method and success criteria
3. **Document** — write behavioral spec in `docs/system/<workflow-name>.md`
4. **Test** — fix-loop reads workflows.md and tests each one
5. **Track** — bugs go to `.claude/bugs/workflows/<name>.md`
6. **Fix** — test-first skill ensures red→green discipline
7. **Verify** — next fix-loop run checks regression

### How to add a workflow

Add a section to `.claude/workflows.md`:
```markdown
## workflow-name

- **Description:** What this workflow does for the user
- **Test methods:** chrome-mcp | playwright | curl | bash | test-suite
- **URL:** (if browser-based)
- **Steps:**
  1. What happens first
  2. What happens next
  3. Expected result
- **What to check:** Expected behaviors
- **Test actions:** Specific commands or actions to exercise it
- **Verification command:** `npm test` or equivalent
- **Baseline success:** What "passing" looks like
- **Skip if:** When this test isn't relevant
- **Escalate if:** When to stop and ask the user
```

Then create the matching behavioral spec at `docs/system/<workflow-name>.md`.

## Bug Tracking

### Files

```
.claude/bugs/
├── README.md            — format and lifecycle rules
├── agent-reported.md    — bugs found by agents during testing
├── user-reported.md     — bugs reported by the user
├── resolved.md          — fixed bugs with regression checks
└── workflows/           — one file per workflow, tracks its bugs
    ├── web-ui.md
    ├── api.md
    └── ...
```

### Bug lifecycle

1. **Found** → added to agent-reported.md or user-reported.md + matching workflows/ file
2. **Fixing** → agent follows test-first skill, writes failing test
3. **Fixed** → test passes, status updated, commit hash recorded
4. **Resolved** → moved to resolved.md with mandatory regression check
5. **Verified** → every fix-loop run checks resolved.md for regressions

### Bug format

```markdown
### [BUG-001] Short title
- **Status:** open | fixing | fixed | wont-fix | needs-user-input
- **Severity:** critical | warning | info
- **Found:** YYYY-MM-DD by agent|user
- **Workflow:** workflow-name
- **Description:** What's wrong
- **Evidence:** Log output, screenshots, steps to reproduce
```

When resolved, add:
```markdown
- **Fixed:** YYYY-MM-DD in commit <hash>
- **Root cause:** Why it happened
- **Fix:** What was done
- **Regression check:** Exact steps to verify it hasn't come back
```

## Skills (Agents Load Automatically)

CLAUDE.md contains a skills table. Agents read it at session start and load the right skill based on context.

| Skill | When | What it does |
|-------|------|-------------|
| fix-loop | Testing bugs | Test → triage → fix → deploy → verify loop |
| test-first | Fixing bugs | Write failing test → fix → verify |
| test-impact | Before committing | Check which tests are affected by changes |
| refactor-plan | Before refactoring | Plan with validation steps |
| spec-check | After changes | Verify docs match code |
| deploy-verify | After deploying | Health checks and smoke tests |
| safety-review | Async/state code | Race conditions, state corruption |
| workflow-management | Discovering flows | Create and maintain workflow definitions |

## Session Logging

Every Claude Code session writes to `docs/sessions/YYYY-MM-DD.md` continuously. This captures:
- What was worked on
- Decisions made
- Files changed
- Bugs found and fixed

Session logs sync to the vault at `projects/<repo>/repo-docs/docs/sessions/`.

## Vault Sync

The vault sync script runs every 5 minutes on both Mac mini and MacBook:

```
Repo docs/ → rsync → Vault projects/<repo>/repo-docs/docs/
Repo README.md, AGENTS.md, CLAUDE.md → Vault projects/<repo>/repo-docs/
```

**What syncs:** Everything under `docs/` — sessions, decisions, architecture, research, runbooks, handoffs, system specs, SYSTEM_OVERVIEW.md

**What does NOT sync:** `.claude/` — skills, agents, bugs, workflows.md, commands (repo-local config)

**Why this split:** docs/ is documentation that should be browsable in Obsidian. .claude/ is agent configuration that controls behavior within the repo.

## How It All Connects

When an agent starts working in a repo:

1. Reads `CLAUDE.md` → sees skills table → knows what skills to load for different tasks
2. Reads `.claude/workflows.md` → knows what user flows exist and how to test them
3. Reads `docs/system/` → understands behavioral specs for those workflows
4. Reads `.claude/bugs/` → knows existing issues and what's been fixed
5. Works on the task, loading relevant skills as needed
6. Logs progress to `docs/sessions/` continuously
7. If it finds a bug → writes to `.claude/bugs/` and links to workflow
8. If it fixes a bug → follows test-first, updates bug status, adds regression check
9. Vault sync picks up docs/sessions/ and docs/system/ changes within 5 minutes
