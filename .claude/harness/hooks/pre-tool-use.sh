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

  # Order gate: before skill-router has fired, only env-bootstrap and
  # the universal mandatory skills (engineering-standards, verification-
  # before-completion) are allowed. Test-first specifically is blocked
  # because that's the one delegation scenarios race against — the
  # router needs to decide whether to delegate to bug-fixer / bug-
  # regression-tester before the worker fires test-first themselves.
  # The other mandatory skills can fire freely as they don't conflict
  # with delegation.
  ROUTER_FIRED_FILE="runtime/.harness-state/skill-router-fired"
  if [[ "${TTM_DISABLE_SKILL_ROUTER:-0}" != "1" ]] \
     && [[ ! -f "$ROUTER_FIRED_FILE" ]] \
     && ! state_has "$SESSION_ID" skill-router-invoked \
     && [[ "$SKILL_NAME" == "test-first" ]]; then
    emit_deny "Harness gate: invoke Agent(subagent_type='skill-router') before Skill('test-first'). The router decides whether this is a fix-yourself task or a delegation task — firing test-first early races that decision."
    exit 0
  fi

  # Delegation guard: when the skill-router said this prompt requires a
  # specialist agent (bug-fixer / bug-regression-tester), the worker
  # must NOT invoke test-first / verification themselves — that's why
  # the agent exists. Use the router's suggestion (prompt-suggested-X)
  # as the signal, not the agent-fired sentinel — by the time the agent
  # actually fires, the worker may have already invoked test-first.
  # This makes the gate proactive instead of reactive.
  PRE_DIR="runtime/.harness-state"
  if [[ -f "$PRE_DIR/prompt-suggested-bug-fixer" ]] \
     || [[ -f "$PRE_DIR/prompt-suggested-bug-regression-tester" ]] \
     || state_has "$SESSION_ID" prompt-suggested-bug-fixer \
     || state_has "$SESSION_ID" prompt-suggested-bug-regression-tester; then
    case "$SKILL_NAME" in
      test-first|verification-before-completion)
        emit_deny "Harness gate: skill-router routed this prompt to a specialist agent (bug-fixer or bug-regression-tester). Do NOT invoke Skill('${SKILL_NAME}') yourself — dispatch the agent and let its work stand. The user explicitly delegated; doing the work in parallel defeats the purpose."
        exit 0
        ;;
    esac
  fi
  case "$SKILL_NAME" in
    env-bootstrap)        state_set "$SESSION_ID" env-bootstrap-fired ;;
    session-logging)      state_set "$SESSION_ID" session-logging-fired ;;
    commit)               state_set "$SESSION_ID" commit-fired ;;
    engineering-standards) state_set "$SESSION_ID" engineering-standards-fired ;;
    repo-structure)       state_set "$SESSION_ID" repo-structure-fired ;;
    module-map)           state_set "$SESSION_ID" module-map-fired ;;
    docs-writing)         state_set "$SESSION_ID" docs-writing-fired ;;
    dev-server)           state_set "$SESSION_ID" dev-server-fired ;;
    explore-beyond-the-task) state_set "$SESSION_ID" explore-beyond-the-task-fired ;;
    audit-entry-point-configs) state_set "$SESSION_ID" audit-entry-point-configs-fired ;;
    read-invariants-not-just-code) state_set "$SESSION_ID" read-invariants-not-just-code-fired ;;
    verification-before-completion)
                          state_set "$SESSION_ID" verification-fired ;;
  esac
  exit 0
fi

# skill-router subagent invocation. Fires when the worker calls Task or
# Agent with subagent_type=skill-router. The router writes its own
# `skill-router-fired` sentinel via Bash (so the parent can detect
# completion regardless of how its tool name maps), but we ALSO write
# one here as a belt-and-suspenders signal in case the subagent crashes
# before its Bash call lands.
if [[ "$TOOL_NAME" == "Task" || "$TOOL_NAME" == "Agent" ]]; then
  SUBAGENT=$(echo "$PAYLOAD" | jq -r '.tool_input.subagent_type // empty')
  # Cross-agent guard: when the router suggested ONE agent and the worker
  # tries to dispatch a DIFFERENT specialist agent on top, that's
  # over-engagement. Only block specialist agents (bug-fixer /
  # bug-regression-tester / spec-reviewer / code-quality-reviewer) —
  # general-purpose, skill-router, and unrelated subagents pass through.
  PRE_DIR="runtime/.harness-state"
  case "$SUBAGENT" in
    bug-fixer|bug-regression-tester|spec-reviewer|code-quality-reviewer)
      ANY_ROUTED=0
      for ag in bug-fixer bug-regression-tester spec-reviewer code-quality-reviewer; do
        if [[ -f "$PRE_DIR/prompt-suggested-${ag}" ]] || state_has "$SESSION_ID" "prompt-suggested-${ag}"; then
          ANY_ROUTED=1
          break
        fi
      done
      if [[ "$ANY_ROUTED" == "1" ]] \
         && [[ ! -f "$PRE_DIR/prompt-suggested-${SUBAGENT}" ]] \
         && ! state_has "$SESSION_ID" "prompt-suggested-${SUBAGENT}"; then
        emit_deny "Harness gate: skill-router did NOT suggest Agent(subagent_type='${SUBAGENT}') for this prompt. Dispatch only the agent(s) the router named — over-dispatching specialist agents is over-engagement."
        exit 0
      fi
      # Hard mutual exclusion: bug-regression-tester (reproducer-only) and
      # bug-fixer (full fix) cannot coexist on the same prompt — the
      # reproducer-only request explicitly defers the fix. If the router
      # accidentally suggested both (model eagerness), block bug-fixer.
      if [[ "$SUBAGENT" == "bug-fixer" ]] \
         && ([[ -f "$PRE_DIR/prompt-suggested-bug-regression-tester" ]] \
             || state_has "$SESSION_ID" prompt-suggested-bug-regression-tester); then
        emit_deny "Harness gate: skill-router suggested bug-regression-tester (reproducer-only request) — bug-fixer is mutually exclusive on this prompt. The user deferred the fix; do NOT dispatch bug-fixer."
        exit 0
      fi
      ;;
  esac
  if [[ "$SUBAGENT" == "skill-router" ]]; then
    state_set "$SESSION_ID" skill-router-invoked
  fi
  case "$SUBAGENT" in
    bug-fixer)              state_set "$SESSION_ID" bug-fixer-fired ;;
    bug-regression-tester)  state_set "$SESSION_ID" bug-regression-tester-fired ;;
    spec-reviewer)          state_set "$SESSION_ID" spec-reviewer-fired ;;
    code-quality-reviewer)  state_set "$SESSION_ID" code-quality-reviewer-fired ;;
    cross-reference-hunter) state_set "$SESSION_ID" cross-reference-hunter-fired ;;
    invariant-hunter)       state_set "$SESSION_ID" invariant-hunter-fired ;;
    error-handling-hunter)  state_set "$SESSION_ID" error-handling-hunter-fired ;;
    boundary-hunter)        state_set "$SESSION_ID" boundary-hunter-fired ;;
    surface-hunter)         state_set "$SESSION_ID" surface-hunter-fired ;;
  esac
fi

# Track Read calls on the consolidated findings file (used by the
# force-read gate below). The path is set by the PostToolUse hook.
if [[ "$TOOL_NAME" == "Read" ]]; then
  FILE_PATH=$(echo "$PAYLOAD" | jq -r '.tool_input.file_path // .tool_input.path // empty')
  case "$FILE_PATH" in
    */runtime/.harness-state/hunter-findings.md|runtime/.harness-state/hunter-findings.md)
      state_set "$SESSION_ID" hunter-findings-read
      ;;
  esac
fi

# Track tool-call patterns the Stop hook needs to know about. We don't
# block here; we just record so the Stop hook can decide whether the
# session involved code changes (engineering-standards trigger), edits to
# docs/ (docs-writing trigger), or a test run (verification substitute).
case "$TOOL_NAME" in
  Edit|Write|MultiEdit)
    state_set "$SESSION_ID" had-edit-or-write
    FILE_PATH=$(echo "$PAYLOAD" | jq -r '.tool_input.file_path // .tool_input.path // empty')
    case "$FILE_PATH" in
      */docs/*|docs/*) state_set "$SESSION_ID" had-docs-edit ;;
      *) state_set "$SESSION_ID" had-source-edit ;;
    esac
    # r28: record every Edit/Write/MultiEdit file path so stop.sh can verify
    # HIGH-signature (f) findings had an Edit attempt before session-end.
    if [[ -n "$FILE_PATH" ]]; then
      # Sentinel name uses sha1 to keep filename safe on any path.
      path_hash=$(printf '%s' "$FILE_PATH" | shasum | awk '{print $1}')
      state_set "$SESSION_ID" "edit-attempted-$path_hash"
    fi
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

# skill-router subagent gate. After env-bootstrap, the worker MUST invoke
# Agent(subagent_type='skill-router') before any other tool call. The
# router reads the user's prompt, decides which prompt-routed skills
# apply, writes prompt-suggested-* sentinels, and returns a brief
# recommendation. Skip when:
#   - TTM_DISABLE_SKILL_ROUTER=1 (legacy keyword routing or no routing)
#   - the file runtime/.harness-state/skill-router-fired exists (router
#     completed its Bash sentinel write — happens after the subagent
#     returns)
#   - the worker is currently invoking the router itself (Task/Agent
#     with subagent_type=skill-router). Any other Task/Agent call
#     before the router fires is denied to keep ordering deterministic.
if [[ "${TTM_DISABLE_SKILL_ROUTER:-0}" != "1" ]]; then
  ROUTER_FIRED_FILE="runtime/.harness-state/skill-router-fired"
  if [[ ! -f "$ROUTER_FIRED_FILE" ]] && ! state_has "$SESSION_ID" skill-router-invoked; then
    # Allow the router invocation itself through.
    if [[ "$TOOL_NAME" == "Task" || "$TOOL_NAME" == "Agent" ]]; then
      SUBAGENT=$(echo "$PAYLOAD" | jq -r '.tool_input.subagent_type // empty')
      if [[ "$SUBAGENT" == "skill-router" ]]; then
        state_set "$SESSION_ID" skill-router-invoked
      else
        emit_deny "Harness gate: invoke Agent(subagent_type='skill-router') BEFORE any other subagent. The router reads the user prompt, decides which skills you must invoke, and writes the sentinels the PreToolUse + Stop hooks enforce."
        exit 0
      fi
    else
      emit_deny "Harness gate: invoke Agent(subagent_type='skill-router') as your second tool call (after env-bootstrap, before anything else). It reads the prompt and tells you which skills to load. After it returns, all other tools become available."
      exit 0
    fi
  fi
fi

# After env-bootstrap + skill-router, front-load any router-suggested
# skills BEFORE any other tool call. The router writes prompt-suggested-*
# files; this loop reads them (filesystem, not state lib because the
# subagent writes from a different working dir context) and converts
# them to state sentinels for the rest of the gates to enforce.
PRE_DIR="runtime/.harness-state"
if [[ -d "$PRE_DIR" ]]; then
  for sk in refactor-plan glossary module-map test-first explore-beyond-the-task audit-entry-point-configs read-invariants-not-just-code; do
    if [[ -f "$PRE_DIR/prompt-suggested-${sk}" ]] \
       && ! state_has "$SESSION_ID" "prompt-suggested-${sk}"; then
      state_set "$SESSION_ID" "prompt-suggested-${sk}"
    fi
  done
  # Promote router-suggested AGENTS too. The agent gate wording differs
  # (dispatch the agent, don't invoke a skill) so it has its own loop below.
  for ag in bug-fixer bug-regression-tester spec-reviewer code-quality-reviewer \
            cross-reference-hunter invariant-hunter error-handling-hunter boundary-hunter surface-hunter; do
    if [[ -f "$PRE_DIR/prompt-suggested-${ag}" ]] \
       && ! state_has "$SESSION_ID" "prompt-suggested-${ag}"; then
      state_set "$SESSION_ID" "prompt-suggested-${ag}"
    fi
  done
fi

# ---- Hunter-coordination + forced-read + restricted-mode gates ------------
# Compute hunter state once:
HUNTER_PENDING=0
HUNTER_ALL_FIRED=1
for hunter in cross-reference-hunter invariant-hunter error-handling-hunter boundary-hunter surface-hunter; do
  if state_has "$SESSION_ID" "prompt-suggested-${hunter}"; then
    HUNTER_PENDING=1
    if ! state_has "$SESSION_ID" "${hunter}-fired"; then
      HUNTER_ALL_FIRED=0
    fi
  fi
done

# Gate A — coordination (during hunter dispatch):
# Hunters pending and not all fired → block every non-Agent tool. Forces the
# worker to finish dispatching all 5 hunters before any other action.
if [[ "$HUNTER_PENDING" == "1" && "$HUNTER_ALL_FIRED" == "0" ]]; then
  case "$TOOL_NAME" in
    Agent|Task) ;;  # let dispatch through
    *)
      emit_deny "Harness gate (hunter dispatch): not all hunter agents have fired yet. Dispatch the remaining hunter via Agent(subagent_type='<hunter>') BEFORE any other tool call. The PostToolUse hook will consolidate their findings into runtime/.harness-state/hunter-findings.md once they all return."
      exit 0
      ;;
  esac
fi

# Gate B — force-read consolidated findings (after dispatch, before editing):
# All hunters fired, hunter-findings.md exists, but worker hasn't Read it yet.
# Block Edit/Write/Grep/Glob/Bash (with grep|find|curl) until it does.
if [[ "$HUNTER_PENDING" == "1" && "$HUNTER_ALL_FIRED" == "1" ]] \
   && [[ -f "runtime/.harness-state/hunter-findings.md" ]] \
   && ! state_has "$SESSION_ID" hunter-findings-read; then
  case "$TOOL_NAME" in
    Read|Skill|Agent|Task) ;;  # let the worker Read the findings (and others) through
    *)
      emit_deny "Harness gate (force-read findings): all hunters fired and their findings were consolidated into runtime/.harness-state/hunter-findings.md by the PostToolUse hook. Read that file BEFORE any Edit / Write / Grep / Glob / Bash. The file contains every finding with file:line:evidence — you do NOT need to re-explore. Read it, then start fixing the highest-severity findings."
      exit 0
      ;;
  esac
fi

# Gate C (restricted post-hunter exploration) was REMOVED in 0.15.3 — the
# previous version's tight restriction on Grep/Glob/Bash after hunters fired
# was strangling the worker's baseline exploration that catches BH-005,
# BH-012, BH-014, BH-017. Hybrid design: hunters AUGMENT baseline
# exploration; they do NOT replace it. After findings are Read the worker
# is back to normal mode.
for sk in refactor-plan glossary module-map test-first explore-beyond-the-task audit-entry-point-configs read-invariants-not-just-code; do
  if state_has "$SESSION_ID" "prompt-suggested-${sk}" \
     && ! state_has "$SESSION_ID" "${sk}-fired" \
     && ! state_has "$SESSION_ID" "pretool-blocked-${sk}-frontload"; then
    state_set "$SESSION_ID" "pretool-blocked-${sk}-frontload"
    emit_deny "Harness gate: skill-router said your prompt requires Skill('${sk}'). Invoke it now BEFORE any other tool call. After that fires, other tools are unblocked."
    exit 0
  fi
done
# Agent-dispatch front-load. When the router suggested a specialist
# agent, the worker must DISPATCH that agent (not do the work itself).
# Block once per agent; allow the Task/Agent invocation through.
for ag in bug-fixer bug-regression-tester spec-reviewer code-quality-reviewer; do
  if state_has "$SESSION_ID" "prompt-suggested-${ag}" \
     && ! state_has "$SESSION_ID" "${ag}-fired" \
     && ! state_has "$SESSION_ID" "pretool-blocked-${ag}-frontload"; then
    # Allow Task/Agent invocation of THIS agent through.
    if [[ "$TOOL_NAME" == "Task" || "$TOOL_NAME" == "Agent" ]]; then
      SUBAGENT=$(echo "$PAYLOAD" | jq -r '.tool_input.subagent_type // empty')
      if [[ "$SUBAGENT" == "$ag" ]]; then
        continue  # let it through; the tracker above will set ${ag}-fired
      fi
    fi
    state_set "$SESSION_ID" "pretool-blocked-${ag}-frontload"
    emit_deny "Harness gate: skill-router said your prompt requires Agent(subagent_type='${ag}'). Dispatch that agent now BEFORE any other tool call — the user explicitly delegated this work. Do NOT do it yourself."
    exit 0
  fi
done

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

# ---- Gate 6: dev-server gates long-lived dev-server invocations ----------
# Prevents the foreground-exec / background-sleep-kill anti-pattern that
# leaves orphaned next-server / vite processes holding ports while the
# parent shell hangs on `wait`. The dev-server skill owns the named
# tmux session lifecycle; everything else must route through it.
#
# Match `next dev`, `npx next dev`, `npm/yarn/pnpm run dev`, `npm/yarn/pnpm
# dev`, bare `vite`, `wrangler dev`. Allow when:
#   - dev-server-fired sentinel is set (skill has been invoked), OR
#   - the same command line contains `tmux new-session` or `tmux send-keys`
#     (the skill's own pattern — running the dev command inside tmux).
# Block-once: after the first block, allow to pass so the worker can
# pivot to invoking the skill and not get re-blocked.
if [[ "$TOOL_NAME" == "Bash" ]] \
   && ! state_has "$SESSION_ID" dev-server-fired \
   && ! state_has "$SESSION_ID" pretool-blocked-dev-server; then
  COMMAND=$(echo "$PAYLOAD" | jq -r '.tool_input.command // empty')
  if echo "$COMMAND" | grep -qE '(^|[^a-zA-Z0-9_-])(npx[[:space:]]+next[[:space:]]+dev|next[[:space:]]+dev|(npm|yarn|pnpm)[[:space:]]+(run[[:space:]]+)?dev|vite|wrangler[[:space:]]+dev)($|[^a-zA-Z0-9_-])'; then
    if ! echo "$COMMAND" | grep -qE 'tmux[[:space:]]+(new-session|send-keys)'; then
      state_set "$SESSION_ID" pretool-blocked-dev-server
      emit_deny "Harness gate: long-lived dev servers (next dev / npm run dev / vite / wrangler dev) must run inside a named tmux session owned by Skill('dev-server'). Invoke that skill instead — it owns the tmux-session lifecycle (project-scoped name, idempotent has-session check) and prevents the orphaned-next-server / immortal-curl-poll failure mode from 2026-05-13. After it fires, dev-server commands are unblocked."
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
      for skill in refactor-plan glossary module-map test-first explore-beyond-the-task audit-entry-point-configs read-invariants-not-just-code; do
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
