#!/usr/bin/env bash
# Harness SessionStart hook — Layer 2 of the skill-engagement enforcement.
#
# Injects a short directive preamble into the worker's context at session
# start. Tells the worker:
#   1. The mandatory-discipline skills exist and are auto-loaded.
#   2. A PreToolUse gate enforces three of them — calling them up front
#      is the path of least resistance.
#
# This is belt-and-suspenders. The PreToolUse hook does the enforcing;
# this preamble tells the worker what's coming so it doesn't waste tool
# calls hitting denied gates.
#
# Kill switch: TTM_DISABLE_HARNESS_HOOK=1 → exit 0 (no preamble injected).

set -uo pipefail

if [[ "${TTM_DISABLE_HARNESS_HOOK:-0}" == "1" ]]; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

read -r _UNUSED_PAYLOAD <<<"$(cat)"

PREAMBLE=$(cat <<'EOF'
TTM harness preamble (auto-injected):

**FRONT-LOAD INSTRUCTION**: Before responding to the user's prompt with any work, invoke these sequentially as your first tool calls:
  1. Skill('env-bootstrap') — MANDATORY, gated. Your first call must be this.
  2. Agent(subagent_type='skill-router') — MANDATORY, gated. See "Router invocation format" below.
  3. Skill('engineering-standards') — invoke after the router, before any code/edit work.
  4. Skill('verification-before-completion') — invoke now, BEFORE doing the work.

DO NOT invoke Skill('test-first') before the router fires — on delegation prompts the router will route to bug-fixer / bug-regression-tester instead. Remaining mandatory skills (session-logging, commit, repo-structure, docs-writing) fire naturally as their PreToolUse gates trigger.

**Router invocation format**: when invoking `Agent(subagent_type='skill-router')`, you pass a `prompt` argument. There are two shapes:

- **Bare**: just the user's latest message verbatim. Use when the message is self-contained (a clear, full task description).

- **Structured**: when the user's latest message is short (under ~50 chars) OR references prior context ("go ahead", "yes", "that one", "do it", "continue", "the bug we discussed"). Pass this format:
  ```
  Latest user message: <verbatim>

  Context (recent exchanges):
  - <one-line summary of relevant prior exchange>
  - <another if needed>
  ```
  Summarize from YOUR own chat history (you have it in context). Include only exchanges the Latest references. 2-3 lines is usually enough.

If you pass a Bare prompt where Structured was needed, the router will return `INSUFFICIENT_CONTEXT: ...` and refuse to route. Re-invoke it with the Structured shape including the relevant Context.

Why front-load: there's a benchmark-runner edge case where the Stop hook's bullet-list block can get truncated before the worker finishes pivoting. Invoking these three skills upfront moves the strict-engagement signal earlier in the turn, where it can't be lost.

Bypass with TTM_DISABLE_HARNESS_HOOK=1 only when explicitly authorized.
EOF
)

jq -n --arg ctx "$PREAMBLE" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
