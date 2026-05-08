#!/usr/bin/env bash
# Harness Stop hook — blocks turn-completion until the discipline skills
# that lack a clean tool-call gate have fired (or been explicitly waived).
#
# The PreToolUse hook gates skills with concrete tool triggers
# (env-bootstrap = first call; session-logging = docs/sessions edits;
# commit = git commit/add). The OTHER mandatory-discipline skills —
# engineering-standards, verification-before-completion — have no clean
# tool gate. The Stop hook is their enforcement point: at turn-end, if
# the worker did substantive work but skipped the skill, block the stop
# with `decision: block` and a reason the worker reads + reacts to.
#
# Block-once-per-skill: after we block on a skill, we set a sentinel so
# we don't loop. The worker is told "invoke X" — once it does, we allow
# the next stop attempt. If the worker tries to stop AGAIN without doing
# what X said, we still allow (we're not enforcing skill content, only
# the protocol step). This avoids deadlock while preserving the gate.
#
# Kill switch: TTM_DISABLE_HARNESS_HOOK=1 → exit 0 (allow stop).

set -uo pipefail

if [[ "${TTM_DISABLE_HARNESS_HOOK:-0}" == "1" ]]; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

LIB_DIR="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
if [[ -f "$LIB_DIR/state.sh" ]]; then
  # shellcheck source=lib/state.sh
  source "$LIB_DIR/state.sh"
else
  exit 0
fi

PAYLOAD=$(cat)
[[ -z "$PAYLOAD" ]] && exit 0
SESSION_ID=$(echo "$PAYLOAD" | jq -r '.session_id // empty')
[[ -z "$SESSION_ID" ]] && exit 0

emit_block() {
  local reason="$1"
  jq -n --arg reason "$reason" '{decision:"block", reason:$reason}'
}

# ---- Gate 4: engineering-standards on substantive work ---------------------
# If the worker performed any Edit or Write this session, treat that as
# substantive work (added/changed code) and require engineering-standards
# to have fired before allowing stop.
if state_has "$SESSION_ID" had-edit-or-write \
   && ! state_has "$SESSION_ID" engineering-standards-fired \
   && ! state_has "$SESSION_ID" stop-blocked-engineering-standards; then
  state_set "$SESSION_ID" stop-blocked-engineering-standards
  emit_block "Harness gate: you performed substantive code changes this session but did not invoke Skill('engineering-standards'). Invoke it now and confirm the six stop rules (simplicity-before-complexity, first-run-correctness, root-cause fixes, clean complexity, scope discipline, intellectual honesty) hold for this work, then end the turn."
  exit 0
fi

# ---- Gate 5: verification-before-completion on substantive work -------------
# If the worker did Edit/Write but neither invoked verification-before-completion
# NOR ran a recognized test command, block stop and tell them to verify.
if state_has "$SESSION_ID" had-edit-or-write \
   && ! state_has "$SESSION_ID" verification-fired \
   && ! state_has "$SESSION_ID" had-test-run \
   && ! state_has "$SESSION_ID" stop-blocked-verification; then
  state_set "$SESSION_ID" stop-blocked-verification
  emit_block "Harness gate: you changed code but did not run a verification step (test, build, type-check, lint). Invoke Skill('verification-before-completion') and run the verification it specifies — the verification command must appear in the same assistant turn as your completion claim."
  exit 0
fi

# ---- Gate 6: docs-writing on docs/ edits -----------------------------------
if state_has "$SESSION_ID" had-docs-edit \
   && ! state_has "$SESSION_ID" docs-writing-fired \
   && ! state_has "$SESSION_ID" stop-blocked-docs-writing; then
  state_set "$SESSION_ID" stop-blocked-docs-writing
  emit_block "Harness gate: you edited files under docs/ but did not invoke Skill('docs-writing'). Invoke it now and confirm Diataxis split + frontmatter + per-folder INDEX rules apply to your changes, then end the turn."
  exit 0
fi

# All gates satisfied. Drop a sentinel so external watchers (like the
# benchmark runner's waitForStop) can detect turn-completion without
# waiting for the 15-min idle window. Claude Code in interactive mode
# does NOT reliably emit agent.stop on its own when a turn ends.
#
# We touch the sentinel under the standard runtime/.harness-state dir
# AND mirror to a stable filename ($PWD/runtime/.harness-state/last-turn-done)
# so a watcher can poll a single path without knowing the session id.
state_set "$SESSION_ID" turn-done
mkdir -p runtime/.harness-state 2>/dev/null
{
  printf '{"session_id":"%s","timestamp":"%s"}\n' "$SESSION_ID" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > runtime/.harness-state/last-turn-done 2>/dev/null || true

exit 0
