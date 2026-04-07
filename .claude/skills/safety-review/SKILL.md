---
name: safety-review
description: Review code for async safety, race conditions, and state corruption.
---

# Runtime Safety Review

When reviewing or writing code that involves async operations, shared state, or concurrency:

## Check for
1. **State mutations** — writes outside proper channels (direct mutation vs setter/dispatch)
2. **Stale closures** — callbacks capturing old values instead of current state
3. **Race conditions** — parallel operations competing for shared resources
4. **Missing error handling** — unhandled promise rejections, missing try/catch on async
5. **Resource leaks** — timers, subscriptions, connections not cleaned up on unmount/close
6. **Concurrent writes** — multiple writers to the same file/record without coordination

## For each finding
- Rate severity: critical (data loss/corruption), warning (intermittent failure), info (code smell)
- Show the specific code path
- Suggest the fix

## When to use
- Any PR touching async code, state management, or event handlers
- After refactoring code that manages lifecycle (mount/unmount, open/close)
- When debugging intermittent or timing-dependent bugs
