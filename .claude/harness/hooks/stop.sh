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

# engineering-standards on SOURCE-code work (docs-only edits are covered
# by docs-writing instead — engineering-standards firing on a pure-docs
# session is a false positive).
if state_has "$SESSION_ID" had-source-edit \
   && ! state_has "$SESSION_ID" engineering-standards-fired; then
  violations+=("Skill('engineering-standards') — confirm the six stop rules (simplicity, first-run-correctness, root-cause, clean complexity, scope, intellectual honesty) hold for your changes")
fi

# session-logging on any substantive work (the skill says: "after each
# meaningful unit of work, before wrapping up"). Pre-tool-use only gates
# the *write* of docs/sessions; if the worker skips the write entirely
# the discipline is bypassed. This gate covers that case.
if state_has "$SESSION_ID" had-edit-or-write \
   && ! state_has "$SESSION_ID" session-logging-fired; then
  violations+=("Skill('session-logging') — append today's work to docs/sessions/YYYY-MM-DD.md per its continuous-log discipline (this skill is mandatory after meaningful work, even if you didn't touch docs/sessions yet)")
fi

# verification-before-completion on SOURCE work — always demand the
# explicit Skill invocation, even if a test command already ran. Scenario
# scoring needs the strict invocation; the skill itself tells the worker
# to run the verification command, so the action still gets done. Skip on
# docs-only sessions — verification doesn't apply to prose.
if state_has "$SESSION_ID" had-source-edit \
   && ! state_has "$SESSION_ID" verification-fired; then
  violations+=("Skill('verification-before-completion') — confirm your verification command (test/build/typecheck/lint) ran in the same turn as your completion claim, AND that the body's iron-law rule was followed")
fi

# docs-writing on docs/ edits
if state_has "$SESSION_ID" had-docs-edit \
   && ! state_has "$SESSION_ID" docs-writing-fired; then
  violations+=("Skill('docs-writing') — confirm Diataxis split + frontmatter + per-folder INDEX rules apply to your docs/ changes")
fi

# repo-structure on SOURCE-code changes — docs-only edits don't change
# code layout in the way repo-structure governs.
if state_has "$SESSION_ID" had-source-edit \
   && ! state_has "$SESSION_ID" repo-structure-fired; then
  violations+=("Skill('repo-structure') — confirm the 13 measured principles (size limits, depth limits, domain-verb names, no utils/helpers dumps, feature-sliced layout) apply to your file layout")
fi

# UserPromptSubmit→Stop bridge: catches scenarios where the worker
# answered text-only without editing files, so the PreToolUse Gate 5
# bridge never fired. The prompt-suggested-X sentinel was still set by
# UserPromptSubmit, indicating the routing intent. If the suggested
# skill never fired AND no PreToolUse block already covered it, demand
# it at Stop time.
for sk in refactor-plan glossary module-map test-first; do
  if state_has "$SESSION_ID" "prompt-suggested-${sk}" \
     && ! state_has "$SESSION_ID" "${sk}-fired" \
     && ! state_has "$SESSION_ID" "pretool-blocked-${sk}"; then
    violations+=("Skill('${sk}') — your prompt's routing match said this skill applies. Even if you handled the task with text only, invoke it briefly to confirm you considered its discipline before ending the turn.")
  fi
done

# If violations remain on FIRST fire, block-once and emit the bullet list.
# After the worker pivots and (hopefully) invokes the listed skills, the
# next stop attempt re-evaluates violations from scratch.
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

# Two cases reach here:
#   (a) violations is empty → all gates pass, write completion sentinel.
#   (b) violations still present but stop-blocked-all is set → worker
#       ignored the first block (Claude Code rejects subsequent blocks
#       within the same turn anyway). Allow the stop but DO NOT write
#       last-turn-done — the run didn't satisfy the harness contract,
#       so the runner's fast-path shouldn't treat this as clean
#       completion. waitForStop falls back to the idle window.
if [[ ${#violations[@]} -gt 0 ]]; then
  exit 0
fi

# All gates satisfied — drop the completion sentinel so the benchmark
# runner's waitForStop fast-paths within ~10s instead of waiting for the
# 15-min idle window. Claude Code in interactive mode does NOT reliably
# emit agent.stop on its own when a turn ends.
state_set "$SESSION_ID" turn-done
mkdir -p runtime/.harness-state 2>/dev/null
{
  printf '{"session_id":"%s","timestamp":"%s"}\n' "$SESSION_ID" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > runtime/.harness-state/last-turn-done 2>/dev/null || true

exit 0
