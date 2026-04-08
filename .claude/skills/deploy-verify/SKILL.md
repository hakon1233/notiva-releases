---
name: deploy-verify
description: Post-deployment health checks and smoke tests.
---

## Before you start

1. Check if `docs/sessions/$(date +%Y-%m-%d).md` exists
2. If not, create it with a session header: `## Session — HH:MM` + `**Objective:** one-line summary`
3. Log your work continuously as you go — do not wait until the end

# Deploy Verification

After deploying changes, verify the deployment is healthy.

## Steps
1. Read `.claude/workflows.md` for health check URLs and commands
2. For each workflow with a URL: hit it, check for 200 + expected response
3. For each workflow with a verification command: run it
4. Check application logs for errors in the last 5 minutes
5. Run regression checks from `.claude/bugs/resolved.md`

## Pass criteria
- All health endpoints return expected status
- No new errors in logs since deploy
- All regression checks pass

## On failure
- Report which checks failed with evidence
- Do NOT automatically rollback — report to the user
- Log the failure in the session log
