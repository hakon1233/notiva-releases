---
name: chrome-mcp-tab-safety
description: Use when touching Chrome MCP, Playwright, or any browser automation in this environment. Multiple agents may share a single browser — assume every tab you didn't create belongs to someone else. MUST BE USED before calling any mcp__claude-in-chrome__* tool, running `playwright` flows, or doing UI checks during multi-agent testing.
last_updated: 2026-04-19
---

# Chrome MCP Tab Safety

## When to use

Read this before:
- using any `mcp__claude-in-chrome__*` tool
- running `./scripts/ai/playwright-cli.sh` or Playwright MCP flows
- doing a UI check during a test run, fix loop, or dispatch hunter session

## Core rule

Assume any existing tab may belong to another agent unless you created it in
this run.

## Required behavior

- Never reuse, navigate, type into, or close a tab you did not create.
- If you need a URL that is already open, create a new tab anyway.
- Keep track of the tab IDs or handles you created.
- Only interact with tabs you created yourself.
- Only close tabs you created yourself.
- Prefer read-only inspection when checking status.
- If a test needs login, form submission, or navigation, do it in your own tab.
- Never log out, refresh, or repurpose a tab that another agent may be using.

## Practical safety pattern

1. Create a fresh tab.
2. Perform your checks only in that tab.
3. If you need another flow, create another new tab.
4. When done, close only the tabs you created.

## If ownership is unclear

Treat the tab as unavailable and create a new one.
