#!/usr/bin/env bash
# Harness PreToolUse hook — Layer 1 of the skill-engagement enforcement.
#
# Mechanically gates three mandatory-discipline skills via deny/inject:
#
#   1. env-bootstrap       — first tool call MUST be Skill('env-bootstrap')
#   2. session-logging     — Edit/Write to docs/sessions/* gated on it firing
#   3. commit              — git commit / git add gated on it firing
#
# Decision flow per tool call:
#   - Read JSON payload from stdin (session_id, tool_name, tool_input).
#   - Check sentinels under runtime/.harness-state/<session_id>/.
#   - If a gate trips, emit JSON denying the call with a directive message.
#   - Otherwise update sentinels (when relevant) and allow.
#
# Kill switch: TTM_DISABLE_HARNESS_HOOK=1 in env → exit 0 immediately.
# Fail-open: if jq fails or the script errors, exit 0 → allow. Better to
# miss a gate than deadlock the worker on a malformed payload.

set -uo pipefail

if [[ "${TTM_DISABLE_HARNESS_HOOK:-0}" == "1" ]]; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  # jq missing — fail open. (Bootstrap should ensure it's available.)
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
if [[ -z "$PAYLOAD" ]]; then
  exit 0
fi

SESSION_ID=$(echo "$PAYLOAD" | jq -r '.session_id // empty')
TOOL_NAME=$(echo "$PAYLOAD" | jq -r '.tool_name // empty')
if [[ -z "$SESSION_ID" || -z "$TOOL_NAME" ]]; then
  exit 0
fi

state_init "$SESSION_ID"

emit_deny() {
  local reason="$1"
  jq -n --arg reason "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
}

# ---- Gate 1: env-bootstrap MUST be the first tool call ---------------------
# A tool call is anything except Skill('env-bootstrap') itself. Hooks fire
# even on Skill calls, so treat the env-bootstrap Skill call as the trigger
# that satisfies the gate.

if [[ "$TOOL_NAME" == "Skill" ]]; then
  SKILL_NAME=$(echo "$PAYLOAD" | jq -r '.tool_input.skill // empty')
  case "$SKILL_NAME" in
    env-bootstrap)        state_set "$SESSION_ID" env-bootstrap-fired ;;
    session-logging)      state_set "$SESSION_ID" session-logging-fired ;;
    commit)               state_set "$SESSION_ID" commit-fired ;;
    engineering-standards) state_set "$SESSION_ID" engineering-standards-fired ;;
    repo-structure)       state_set "$SESSION_ID" repo-structure-fired ;;
    module-map)           state_set "$SESSION_ID" module-map-fired ;;
    docs-writing)         state_set "$SESSION_ID" docs-writing-fired ;;
    verification-before-completion)
                          state_set "$SESSION_ID" verification-fired ;;
  esac
  exit 0
fi

# Track tool-call patterns the Stop hook needs to know about. We don't
# block here; we just record so the Stop hook can decide whether the
# session involved code changes (engineering-standards trigger), edits to
# docs/ (docs-writing trigger), or a test run (verification substitute).
case "$TOOL_NAME" in
  Edit|Write)
    state_set "$SESSION_ID" had-edit-or-write
    FILE_PATH=$(echo "$PAYLOAD" | jq -r '.tool_input.file_path // .tool_input.path // empty')
    case "$FILE_PATH" in
      */docs/*|docs/*) state_set "$SESSION_ID" had-docs-edit ;;
      *) state_set "$SESSION_ID" had-source-edit ;;
    esac
    ;;
  Bash)
    COMMAND=$(echo "$PAYLOAD" | jq -r '.tool_input.command // empty')
    # A test-runner invocation is the canonical substitute for
    # verification-before-completion. Pattern is loose on purpose —
    # better to over-credit and let the grader sort it out.
    if echo "$COMMAND" | grep -qE '(^|[[:space:]&;|`])(npm[[:space:]]+(test|run[[:space:]]+test)|yarn[[:space:]]+test|pnpm[[:space:]]+test|node[[:space:]]+--test|vitest|jest|pytest|cargo[[:space:]]+test|go[[:space:]]+test)([[:space:]]|$)'; then
      state_set "$SESSION_ID" had-test-run
    fi
    ;;
esac

if ! state_has "$SESSION_ID" env-bootstrap-fired; then
  emit_deny "Harness gate: invoke Skill('env-bootstrap') as your FIRST tool call. It captures the env snapshot and runtime/progress.json checkpoint that survives context resets. After that fires, all other tools become available."
  exit 0
fi

# ---- Gate 2: session-logging gates Edit/Write on docs/sessions/ -----------
if [[ "$TOOL_NAME" == "Edit" || "$TOOL_NAME" == "Write" ]]; then
  FILE_PATH=$(echo "$PAYLOAD" | jq -r '.tool_input.file_path // .tool_input.path // empty')
  if [[ "$FILE_PATH" == *"/docs/sessions/"*".md" || "$FILE_PATH" == "docs/sessions/"*".md" ]]; then
    if ! state_has "$SESSION_ID" session-logging-fired; then
      emit_deny "Harness gate: invoke Skill('session-logging') before editing docs/sessions/*.md. The skill owns the entry format and the continuous-log cadence — write it directly without invoking and you bypass the contract."
      exit 0
    fi
  fi
fi

# ---- Gate 3: commit gates git commit / git add ---------------------------
if [[ "$TOOL_NAME" == "Bash" ]]; then
  COMMAND=$(echo "$PAYLOAD" | jq -r '.tool_input.command // empty')
  # Match `git commit`, `git add`, optionally with leading subshells.
  if echo "$COMMAND" | grep -qE '(^|[[:space:]&;|])git[[:space:]]+(commit|add)([[:space:]]|$)'; then
    if ! state_has "$SESSION_ID" commit-fired; then
      emit_deny "Harness gate: invoke Skill('commit') before running git add or git commit. The skill owns the atomic-commit cadence and the audit-stray-docs / generate-skills-index pre-commit checks."
      exit 0
    fi
  fi
fi

# ---- Gate 5: UserPromptSubmit→PreToolUse bridge --------------------------
# When the UserPromptSubmit hook detected a routing intent (e.g. "extract"
# in the prompt → refactor-plan), it writes prompt-suggested-<skill>
# sentinels. Block the FIRST source-edit until the suggested skill has
# actually fired. Block-once per skill so the worker can proceed after
# pivoting. Bridges the soft UserPromptSubmit recommendation to a
# mechanical enforcement.
if [[ "$TOOL_NAME" == "Edit" || "$TOOL_NAME" == "Write" ]]; then
  FILE_PATH=$(echo "$PAYLOAD" | jq -r '.tool_input.file_path // .tool_input.path // empty')
  case "$FILE_PATH" in
    */runtime/*|*/.git/*|*/.claude/*|*/docs/*|docs/*) ;;
    *)
      # Only enforce on non-docs source edits.
      for skill in refactor-plan glossary module-map test-first; do
        if state_has "$SESSION_ID" "prompt-suggested-${skill}" \
           && ! state_has "$SESSION_ID" "${skill}-fired" \
           && ! state_has "$SESSION_ID" "pretool-blocked-${skill}"; then
          state_set "$SESSION_ID" "pretool-blocked-${skill}"
          emit_deny "Harness gate: your prompt's routing match ($skill) hasn't been invoked. Invoke Skill('$skill') now to confirm the discipline applies before editing source. After that fires, source edits are unblocked for this skill."
          exit 0
        fi
      done
      ;;
  esac
fi

# ---- Gate 4: repo-structure gates Write on a NEW file path ---------------
# A `Write` to a path that doesn't exist yet means the worker is creating
# a new file — exactly the trigger condition for repo-structure (size
# limits, depth limits, domain-verb names, no utils.ts/helpers.ts dumps,
# feature-sliced layout). Block-once: after the first new-file-write
# block, subsequent new-file Writes pass through (the worker pivoted
# once, that's the contract).
if [[ "$TOOL_NAME" == "Write" ]] && ! state_has "$SESSION_ID" repo-structure-fired \
   && ! state_has "$SESSION_ID" pretool-blocked-repo-structure; then
  FILE_PATH=$(echo "$PAYLOAD" | jq -r '.tool_input.file_path // .tool_input.path // empty')
  # Skip blocks for in-tree state files: runtime/, .git/, .claude/state.
  case "$FILE_PATH" in
    */runtime/*|*/.git/*|*/.claude/*) ;;
    *)
      if [[ -n "$FILE_PATH" && ! -e "$FILE_PATH" ]]; then
        state_set "$SESSION_ID" pretool-blocked-repo-structure
        emit_deny "Harness gate: you're about to create a new file ($FILE_PATH). Invoke Skill('repo-structure') first to confirm the 13 measured principles (size ≤300/500 lines, depth ≤4, domain-verb names, no utils.ts/helpers.ts dumps, feature-sliced layout, named exports). After that fires, new-file Writes are unblocked."
        exit 0
      fi
      ;;
  esac
fi

exit 0
