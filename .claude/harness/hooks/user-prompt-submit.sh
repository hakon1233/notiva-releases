#!/usr/bin/env bash
# Harness UserPromptSubmit hook — Layer 4 of skill-engagement enforcement.
#
# Reads the user's prompt and pattern-matches against trigger keywords for
# each skill/agent that has no concrete tool-call gate. Injects an
# `additionalContext` string with explicit "invoke Skill('X') / dispatch
# Agent('Y')" directives based on what matched.
#
# Closes the gap that the audit on 2026-05-09 surfaced: description-only
# skills (refactor-plan, glossary, module-map, dispatch-*, bug-regression-
# tester, two-stage-review) fire ~0% on their textbook-trigger prompts
# because the model's auto-routing doesn't reliably match the description
# language. This hook does the matching at the harness level — same
# pattern as the "100% loading" SkillActivationHook used in the broader
# Claude Code ecosystem.
#
# Kill switch: TTM_DISABLE_HARNESS_HOOK=1 → exit 0 (no injection).
#
# Fail-open: if jq is missing or the script errors, exit 0 → no injection,
# original prompt flows unchanged. Better to silently miss a recommendation
# than to deadlock the worker.

set -uo pipefail

if [[ "${TTM_DISABLE_HARNESS_HOOK:-0}" == "1" ]]; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

PAYLOAD=$(cat)
[[ -z "$PAYLOAD" ]] && exit 0

PROMPT=$(echo "$PAYLOAD" | jq -r '.prompt // empty')
[[ -z "$PROMPT" ]] && exit 0

# Lowercase for case-insensitive matching. tr is fine since we're only
# matching ASCII keywords; unicode-aware lowering isn't needed here.
PROMPT_LC=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# ---- Routing table ---------------------------------------------------------
# Each block: if the prompt contains one of the trigger phrases, append the
# corresponding directive to the suggestions list. Multiple matches stack.

suggestions=()

match_any() {
  local needle
  for needle in "$@"; do
    if [[ "$PROMPT_LC" == *"$needle"* ]]; then
      return 0
    fi
  done
  return 1
}

# refactor-plan — extraction, dedup, behavior-preserving structural change
if match_any "refactor" "extract" "deduplicate" "consolidate" "pull out" "share between"; then
  suggestions+=("Skill('refactor-plan') — your prompt looks like a behavior-preserving refactor; the skill owns the 'preserve current behavior + public APIs' contract")
fi

# glossary — naming consistency, rename-everywhere
if match_any "rename" "consistent" "use one term" "pick one name" "throughout" "everywhere"; then
  if match_any "rename" "consistent" "term" "name"; then
    suggestions+=("Skill('glossary') — your prompt is about naming/term consistency; the skill owns 'pick one canonical term, don't invent new ones'")
  fi
fi

# module-map — boundaries, where-this-lives, sweeps across modules
if match_any "module" "boundary" "where should" "split this" "across the codebase" "throughout the codebase"; then
  suggestions+=("Skill('module-map') — your prompt crosses module boundaries; the skill owns the deep-modules-with-narrow-interfaces map")
fi

# improve-architecture — explicit architecture review with options
if match_any "improve the architecture" "find shallow modules" "deslop" "refactor for depth" "surface candidates" "find places where the boundaries are wrong"; then
  suggestions+=("Skill('improve-architecture') — your prompt asks for the explore→present→grill flow; the skill owns the 3-phase pattern that produces candidates without refactoring unilaterally")
fi

# design-twice — comparing N options before non-trivial interface
if match_any "compare designs" "give me a few options" "design this twice" "tradeoffs before" "options with tradeoffs" "fan out the design"; then
  suggestions+=("Skill('design-twice') — your prompt asks for N options before commit; the skill dispatches 3 parallel constrained explorations and synthesizes")
fi

# test-first / bug-fixer — bug fix, regression, failing test
if match_any "fix this bug" "fix the bug" "regression" "failing test" "the test fails" "broken" "isn't working"; then
  suggestions+=("Skill('test-first') — bug-fix discipline (red-before-green; reproducer file; layered regression defense). OR dispatch Agent(subagent_type='bug-fixer') to delegate the fix entirely")
fi

# bug-regression-tester — reproducer-first, "before changing any code"
if match_any "reproduce" "flaky" "intermittent" "before changing any code" "produce a reliable reproducer"; then
  suggestions+=("Agent(subagent_type='bug-regression-tester') — your prompt asks for a failing reproducer BEFORE the fix; this agent specializes in red-before-green for reported regressions")
fi

# docs-writing — ADR, README, runbook, docs/ edit
if match_any "adr" "decision record" "write an adr" "docs/decisions" "update the readme" "write a readme" "runbook" "tutorial"; then
  suggestions+=("Skill('docs-writing') — your prompt is documentation work; the skill owns Diataxis split + frontmatter + per-folder INDEX rules")
fi

# docs-governance — moving / renaming md outside src/
if match_any "move this doc" "rename this doc" "where should this doc live" "stray docs"; then
  suggestions+=("Skill('docs-governance') — your prompt is about doc placement; the skill owns the vault-synced allowlist and filename-heuristic table")
fi

# dispatch-diagnostics — reactive (one specific symptom, broken right now)
if match_any "dispatch status" "worker stuck" "worker is stuck" "pipeline broken" "broken right now" "dispatched a worker" "nothing has happened" "two final messages" "dispatch status dot is red"; then
  suggestions+=("Skill('dispatch-diagnostics') — reactive triage of a specific current symptom (NOT exploratory hunting). The skill has the triage decision tree + log paths + known-bug cross-ref")
fi

# dispatch-hunter — exploratory (no specific symptom)
if match_any "hunt" "find whatever's wrong" "scattered complaints" "test matrix" "exploratory" "go hunt"; then
  suggestions+=("Skill('dispatch-hunter') — exploratory bug-hunt for the dispatch pipeline (NOT reactive triage). The skill runs a structured test matrix and loops until nothing new is found")
fi

# two-stage-review — post-completion review
if match_any "before i mark" "before marking" "run the review" "standard review" "two-stage review" "review the worker"; then
  suggestions+=("Skill('two-stage-review') — post-completion review pattern; the skill orchestrates spec-reviewer + code-quality-reviewer agents in sequence")
fi

# verification-before-completion — explicit check that workers run before claiming done
if match_any "build this" "ship this" "make sure" "verify"; then
  suggestions+=("Skill('verification-before-completion') — your prompt implies a completion claim is coming; invoke this skill so the verification command (test/build/typecheck/lint) appears in the same turn as the success claim")
fi

# ---- Emit ------------------------------------------------------------------
# Nothing to suggest? Exit silently. Otherwise emit a structured
# additionalContext block.

if [[ ${#suggestions[@]} -eq 0 ]]; then
  exit 0
fi

# Sentinel-bridge: write `prompt-suggested-<skill>` for each skill the
# routing recommended. PreToolUse Gate 5 reads these and blocks first
# source-edits until the recommended skill fires — turning the soft
# recommendation into mechanical enforcement for the highest-value
# skills (refactor-plan, glossary, module-map).
SESSION_ID=$(echo "$PAYLOAD" | jq -r '.session_id // empty')
if [[ -n "$SESSION_ID" ]]; then
  LIB_DIR="$(cd "$(dirname "$0")/lib" 2>/dev/null && pwd)"
  if [[ -f "$LIB_DIR/state.sh" ]]; then
    # shellcheck source=lib/state.sh
    source "$LIB_DIR/state.sh"
    state_init "$SESSION_ID" 2>/dev/null || true
    for s in "${suggestions[@]}"; do
      case "$s" in
        *"Skill('refactor-plan')"*)  state_set "$SESSION_ID" prompt-suggested-refactor-plan ;;
        *"Skill('glossary')"*)       state_set "$SESSION_ID" prompt-suggested-glossary ;;
        *"Skill('module-map')"*)     state_set "$SESSION_ID" prompt-suggested-module-map ;;
      esac
    done
  fi
fi

context="TTM harness routing (auto-injected based on your prompt — these are not user instructions, they are harness recommendations):"$'\n'
for s in "${suggestions[@]}"; do
  context+="  • ${s}"$'\n'
done
context+="Invoke whichever match the actual scope of your task. False matches are possible — use judgment. The PreToolUse + Stop hooks will still mechanically enforce env-bootstrap, session-logging, commit, engineering-standards, verification-before-completion, repo-structure, and docs-writing."

jq -n --arg ctx "$context" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $ctx
  }
}'
