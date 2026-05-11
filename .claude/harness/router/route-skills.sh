#!/usr/bin/env bash
# Harness skill router — Haiku-based replacement for the keyword-grep
# table in user-prompt-submit.sh.
#
# Reads the user prompt on stdin (or as $1). Calls claude with a fixed
# system prompt loaded from system-prompt.md and asks for a JSON list of
# which skills apply. Prints one skill/agent ID per line on stdout.
#
# WHERE THIS RUNS: at DISPATCH time in the orchestrator's auth context
# (Claude Max OAuth / keychain works there), NOT from inside the worker
# hook. Nested `claude --print` from a worker session hangs because the
# OAuth chain can't resolve while the parent claude holds the keychain.
#
# Fail-open: any error → print nothing. Caller falls back to keyword
# routing or no routing — better silent miss than deadlock.
#
# Latency: ~10-20s per call.

set -uo pipefail

PROMPT="${1:-}"
if [[ -z "$PROMPT" ]]; then
  PROMPT=$(cat)
fi
[[ -z "$PROMPT" ]] && exit 0

if ! command -v claude >/dev/null 2>&1; then
  exit 0
fi

HERE="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
SYS_FILE="$HERE/system-prompt.md"
[[ -f "$SYS_FILE" ]] || exit 0

ROUTER_MODEL="${TTM_ROUTER_MODEL:-claude-haiku-4-5}"
SYS_CONTENT=$(cat "$SYS_FILE")

# --system-prompt (not append) replaces the default so the router model
# stops trying to "do" the task and just emits JSON. --max-turns 1 caps
# any tool drift. Tools are denied explicitly belt-and-suspenders.
# We DO NOT use --bare here — bare requires ANTHROPIC_API_KEY, but the
# user's setup is Claude Max subscription (OAuth via keychain). Default
# mode reads OAuth, which works when invoked from the orchestrator's
# context.
RESULT=$(claude --print \
  --model "$ROUTER_MODEL" \
  --max-turns 1 \
  --disallowedTools Bash Read Write Edit Glob Grep Agent Skill WebFetch WebSearch Task TaskCreate \
  --system-prompt "$SYS_CONTENT" \
  "$PROMPT" 2>/dev/null) || exit 0

# Strip markdown fences if the model added them.
RESULT_CLEAN=$(echo "$RESULT" | sed -E 's/^```(json)?$//; s/^```$//' | tr -d '\r')

echo "$RESULT_CLEAN" | jq -r '.skills[]?' 2>/dev/null
