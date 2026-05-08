# Harness hooks

Auto-managed by `bootstrap-claude-template.sh`. Do **not** edit per project — changes here propagate to every TTM-managed repo on the next harness bump.

| Hook | Event | Purpose |
|---|---|---|
| `pre-tool-use.sh` | `PreToolUse` | Layer 1 — mechanically gates `env-bootstrap`, `session-logging`, `commit` via `permissionDecision: "deny"` + injected reason. Worker pivots to invoke the right Skill. |
| `session-start.sh` | `SessionStart` | Layer 2 — injects a short directive preamble explaining which skills are auto-loaded and which are gated. |
| `lib/state.sh` | (sourced) | Per-session sentinel files under `runtime/.harness-state/<session_id>/`. |

## Kill switch

Set `TTM_DISABLE_HARNESS_HOOK=1` in the worker's env to bypass both hooks. Used by:
- Tests that need to run workers without harness gating.
- Custom-benchmarks A/B comparisons (off vs on).

## Why this layer exists

Catalog-only skill descriptions don't reliably bind workers — even with directive ("ALWAYS invoke X. Do not Y directly.") language, Claude Opus 4.7's training-time priority ranks "complete the task efficiently" above "follow harness protocol." Empirical baseline: 2/23 strict skill engagements on substantive tasks.

PreToolUse `deny` is the only mechanism the harness can use without shipping global config. The hook fires before every tool call, and Claude immediately pivots when it sees the deny + reason. The pattern is described in [Skill Hook: 100% Loading](https://claudefa.st/blog/tools/hooks/skill-activation-hook): *"Claude can't forget because it never had to remember."*

## What gets gated

Three skills with concrete tool-call triggers:

1. **env-bootstrap** — sentinel: any non-`Skill('env-bootstrap')` first tool call → deny.
2. **session-logging** — sentinel: `Edit` / `Write` on a path matching `docs/sessions/*.md` without prior fire → deny.
3. **commit** — sentinel: `Bash` command containing `git commit` or `git add` without prior fire → deny.

The other two mandatory-discipline skills (`engineering-standards`, `verification-before-completion`) don't have a clean tool-call gate and stay description-only. The grader judges them on substituted behavior.

## Fail-open

If `jq` is missing, the hook script errors, or the JSON payload is malformed — the hook exits 0 (allow). Better to silently miss a gate than to deadlock the worker.
