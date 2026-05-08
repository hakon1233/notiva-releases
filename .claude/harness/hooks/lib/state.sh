#!/usr/bin/env bash
# Sentinel state shared by harness hooks within one Claude Code session.
# Each session_id gets its own dir under runtime/.harness-state/. Sentinels
# are tiny (empty files); cleanup happens lazily next time the same session
# id is reused, which never happens in practice — it's safe to leave them
# until the runtime/ tree is cleaned.
#
# Usage:
#   source "$(dirname "$0")/lib/state.sh"
#   state_init "$SESSION_ID"
#   if state_has env-bootstrap; then ... fi
#   state_set env-bootstrap

state_dir_for() {
  local session_id="$1"
  echo "runtime/.harness-state/${session_id}"
}

state_init() {
  local session_id="$1"
  mkdir -p "$(state_dir_for "$session_id")"
}

state_has() {
  local session_id="$1" sentinel="$2"
  test -f "$(state_dir_for "$session_id")/${sentinel}"
}

state_set() {
  local session_id="$1" sentinel="$2"
  touch "$(state_dir_for "$session_id")/${sentinel}"
}
