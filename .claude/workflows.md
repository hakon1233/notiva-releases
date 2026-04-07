# Project Workflows

Testable workflows for the fix loop. Each entry describes what to test and how.

<!--
  The fix loop reads this file to generate test plans.
  Add one section per workflow area in your project.

  Supported test methods:
  - chrome-mcp    — Browser automation via Chrome MCP (visual testing, UI flows)
  - playwright    — Playwright CLI or test suite (e2e, cross-browser)
  - curl          — HTTP requests to APIs
  - bash          — Shell commands (logs, process checks, file state)
  - test-suite    — Run existing test files (jest, vitest, pytest, etc.)

  You can combine methods for a single workflow.
-->

## Example: web-ui

- **Description:** Main web application UI
- **Test methods:** chrome-mcp, bash
- **URL:** https://your-app-url.example.com
- **What to check:**
  - Pages load without errors
  - Navigation works between routes
  - Forms submit correctly
  - No JavaScript console errors
  - Responsive layout renders properly
- **Test actions:**
  - Navigate to each main page and screenshot
  - Submit a test form with valid data
  - Check browser console for errors via `read_console_messages`
- **Verification command:** `npm run test`

## Example: api

- **Description:** REST API endpoints
- **Test methods:** curl, test-suite
- **Base URL:** http://localhost:3000/api
- **What to check:**
  - Health endpoint returns 200
  - CRUD operations work correctly
  - Error responses have proper status codes
  - Auth-protected routes reject unauthenticated requests
- **Test actions:**
  - `curl -s http://localhost:3000/api/health`
  - `curl -s http://localhost:3000/api/users | python3 -m json.tool`
- **Verification command:** `npm run test:api`

## Example: background-jobs

- **Description:** Background workers and scheduled tasks
- **Test methods:** bash
- **What to check:**
  - Worker processes are running
  - Jobs complete without errors
  - Logs show no stuck/failed jobs
- **Test actions:**
  - `ps aux | grep worker`
  - `tail -20 /var/log/worker.log`
  - Check job queue depth
- **Verification command:** `npm run test:workers`

<!--
  DELETE THE EXAMPLES ABOVE and add your actual project workflows.
  The fix loop will test each workflow listed here.
-->
