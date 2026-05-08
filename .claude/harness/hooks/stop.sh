#!/usr/bin/env bash
# Harness Stop hook — blocks turn-completion until the discipline skills
# that lack a clean tool-call gate have all fired (or been waived).
#
# IMPORTANT: Claude Code only respects ONE Stop-hook `decision: block` per
# turn cycle. Subsequent blocks in the same turn are silently ignored to
# prevent infinite loops. This means the hook can't sequentially block
# missing skills one-by-one — it has to list ALL violations in a single
# block message on the first fire. The worker reads the list, invokes
# every missing skill, and on the next stop attempt all gates pass.
#
# Block-once via stop-blocked-all sentinel.
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

# ---- Aggregate every missing skill into one violation list ----------------
# Each entry is a one-line directive the worker reads + acts on.
violations=()

# engineering-standards on substantive work
if state_has "$SESSION_ID" had-edit-or-write \
   && ! state_has "$SESSION_ID" engineering-standards-fired; then
  violations+=("Skill('engineering-standards') — confirm the six stop rules (simplicity, first-run-correctness, root-cause, clean complexity, scope, intellectual honesty) hold for your changes")
fi

# verification-before-completion on substantive work (test run substitutes)
if state_has "$SESSION_ID" had-edit-or-write \
   && ! state_has "$SESSION_ID" verification-fired \
   && ! state_has "$SESSION_ID" had-test-run; then
  violations+=("Skill('verification-before-completion') — run a verification command (test/build/typecheck/lint) in the same turn as your completion claim")
fi

# docs-writing on docs/ edits
if state_has "$SESSION_ID" had-docs-edit \
   && ! state_has "$SESSION_ID" docs-writing-fired; then
  violations+=("Skill('docs-writing') — confirm Diataxis split + frontmatter + per-folder INDEX rules apply to your docs/ changes")
fi

# repo-structure on substantive code changes
if state_has "$SESSION_ID" had-edit-or-write \
   && ! state_has "$SESSION_ID" repo-structure-fired; then
  violations+=("Skill('repo-structure') — confirm the 13 measured principles (size limits, depth limits, domain-verb names, no utils/helpers dumps, feature-sliced layout) apply to your file layout")
fi

# Block ONCE per session if any violations remain. After the worker pivots
# and invokes the listed skills, the next stop attempt will find all gates
# satisfied and we fall through to the allow path.
if [[ ${#violations[@]} -gt 0 ]] && ! state_has "$SESSION_ID" stop-blocked-all; then
  state_set "$SESSION_ID" stop-blocked-all
  reason="Harness gate: before ending this turn you must invoke the following skills (Claude Code allows only one Stop-hook block per turn so this is your single chance):"$'\n'
  for v in "${violations[@]}"; do
    reason+="  • ${v}"$'\n'
  done
  reason+="Invoke them now, then end the turn."
  emit_block "$reason"
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
