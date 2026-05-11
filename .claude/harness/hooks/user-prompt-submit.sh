#!/usr/bin/env bash
# Harness UserPromptSubmit hook.
#
# As of 2026-05-11, prompt routing is owned by the skill-router subagent
# (defined in .claude/agents/skill-router.md). The PreToolUse hook gates
# the worker's first non-router tool call until the subagent has fired
# and written its sentinels. So this hook has nothing to do — the
# routing happens via subagent invocation, not via UserPromptSubmit
# context injection.
#
# Kept as an explicit no-op (rather than deleted) for two reasons:
#   1. The Claude Code settings.json wires this script as a hook target;
#      removing the file requires synchronized settings updates.
#   2. Future routing experiments may want to restore prompt-time
#      injection. Reverting this file is the cleanest opt-in.
#
# To restore the legacy keyword-grep routing for an experiment:
#   git show 4c1de45:templates/claude-project-template/.claude/harness/hooks/user-prompt-submit.sh > .../user-prompt-submit.sh
#
# Pre-routing via TTM_ENABLE_LLM_ROUTER=1 in dispatch.ts still works in
# parallel — if it writes runtime/.harness-state/prompt-suggested-*
# sentinels before the worker starts, the PreToolUse front-load loop
# picks them up automatically.

exit 0
