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

The following five skills are mandatory-discipline and auto-load via the Skill tool:
  env-bootstrap, session-logging, engineering-standards, verification-before-completion, commit

A PreToolUse gate enforces THREE of them mechanically:
  - env-bootstrap MUST be your FIRST tool call (any other tool is denied until then).
  - session-logging MUST fire before editing docs/sessions/*.md.
  - commit MUST fire before `git add` / `git commit`.

The path of least resistance is to invoke Skill('env-bootstrap') before doing any other work, then Skill('engineering-standards') / Skill('verification-before-completion') as their triggers match. The remaining two (session-logging, commit) fire when their concrete actions are needed.

If a gate denies a tool call, the message will tell you which Skill to invoke. Bypass with TTM_DISABLE_HARNESS_HOOK=1 only when explicitly authorized.
EOF
)

jq -n --arg ctx "$PREAMBLE" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
