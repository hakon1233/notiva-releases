---
name: deploy-verify
description: Post-deployment health checks and smoke tests.
---

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
