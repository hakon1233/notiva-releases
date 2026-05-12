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
  2. Agent(subagent_type='skill-router') — MANDATORY, gated. The router reads the user's prompt and decides which skills (and which specialist agents, if any) apply. Until it fires, the harness blocks specialist-agent dispatches and Skill('test-first') (to prevent racing the delegation decision).
  3. Skill('engineering-standards') — invoke after the router, before any code/edit work. The Stop hook will demand it later anyway; invoking now avoids a mid-pivot truncation that can lose later skill calls.
  4. Skill('verification-before-completion') — invoke now, BEFORE doing the work, not after. Same reason.

DO NOT invoke Skill('test-first') before the router fires — on delegation prompts the router will route to bug-fixer / bug-regression-tester instead. After the router returns, the remaining mandatory skills (session-logging, commit, repo-structure, docs-writing) fire naturally as their PreToolUse gates trigger on concrete actions, plus whatever the router specifically suggested.

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
