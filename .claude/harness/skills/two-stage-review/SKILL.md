---
name: two-stage-review
description: "After a worker reports completion (\"Done\") on any non-trivial task and BEFORE marking the task done in plans/orchestrator memory: invoke `Skill('two-stage-review')` to dispatch the spec-compliance then code-quality reviewer subagents — only mark the task done when both pass."
last_updated: 2026-05-02
---

# Two-Stage Subagent Review

When a worker says **"Done"** on a substantive task, you (the orchestrator) do not just believe it. You dispatch two specialist reviewer subagents in series:

1. **`spec-reviewer`** — does the code actually do what the spec / plan task asked for?
2. **`code-quality-reviewer`** — does the code meet the project's engineering standards (no lazy try/catch, no dead branches, consistent naming, tests for new branches, etc.)?

Only when both reviewers approve do you mark the task done.

## When to use

- After any worker dispatch that wrote code (Edit / Write / NotebookEdit tool calls) AND claimed completion.
- For multi-step plans: after each task in `docs/plans/*` whose checkbox you would otherwise tick.
- For fix-loop iterations: after the bug-fix worker says the reproducer is green.

## When to skip

- Trivial fixes (single typo, single rename, removing an unused import).
- Read-only / inspection workers (no code written).
- The worker explicitly produced no diff (Bash-only audit, doc-only update where you're the docs reviewer).
- The user explicitly said "skip review for this one."

If you skip, log it in the orchestrator chat ("trivial — skipping two-stage review") so the audit trail is honest.

## How to dispatch

Use the canonical `dispatch_worker` MCP tool. Both reviewers are **read-only** (`readOnly: true`); they should never write files.

### Stage 1: spec-reviewer

```
dispatch_worker:
  name: review-spec-<task-slug>
  prompt: <use .claude/agents/spec-reviewer.md as the prompt template>
  projectPath: <same as the implementer worker>
  provider: claude-code
  readOnly: true
```

Wait for completion. The reviewer returns one of:
- `APPROVED` — spec match confirmed
- `REJECTED — <reasons>` — back to the implementer with the rejection notes
- `BLOCKED — <reason>` — needs orchestrator decision (spec was ambiguous, etc.)

If REJECTED, dispatch a follow-up implementer worker with the reasons and re-enter Stage 1 when it's done. Maximum 2 retries before escalating to the user.

### Stage 2: code-quality-reviewer

Only run after Stage 1 returns APPROVED.

```
dispatch_worker:
  name: review-quality-<task-slug>
  prompt: <use .claude/agents/code-quality-reviewer.md as the prompt template>
  projectPath: <same>
  provider: claude-code
  readOnly: true
```

Same return codes; same retry policy.

### Both passed

Mark the task done in the plan / orchestrator memory. Post a brief receipt to chat: "Task X done. Spec review: APPROVED. Quality review: APPROVED. Worker: <session-name>."

## Why two stages, not one

A combined "is this good?" review collapses two genuinely different criteria into one:

- **Spec-compliance** is a binary (did it do what was asked?) and the reviewer needs the original task description + the resulting diff. It does NOT need to know your engineering standards.
- **Code-quality** is multi-criteria (style, tests, complexity, security) and the reviewer needs `engineering-standards/SKILL.md` and `repo-structure/SKILL.md`. It does NOT need to know what the spec said.

Splitting them lets each reviewer load exactly the context it needs and produces a cleaner approval/rejection signal. It also makes "I rejected because the code doesn't match spec" distinguishable from "I rejected because the test coverage is missing" — two very different fixes.

## Composition with other skills

- `verification-before-completion` — the implementer worker MUST verify before claiming Done; the reviewers verify the verification ran.
- `dispatch-worker` — the underlying tool used to spawn both reviewers.
- `engineering-standards` + `repo-structure` — what the code-quality reviewer reads.
- `test-first` — the spec-reviewer checks that the bug reproducer is green for fix tasks.

## Cost

Each reviewer is a fresh subagent context (a few thousand tokens for setup + the diff). On a typical small task, that's ~$0.02-$0.05 per review pass. The cost of a missed regression that ships to stable is much higher; the math always favors the review pass.

## Anti-patterns

- **Self-review** (the implementer reviews its own work) — banned. The implementer's context is biased toward "I did the right thing." A fresh subagent context is a feature.
- **One reviewer doing both jobs** — banned (see "why two stages" above).
- **Skipping Stage 2 because Stage 1 passed** — banned. They check different things.
- **Approving on a partial review** — if the reviewer says "looked at half the diff," dispatch again with a sharper scope. Never approve on incomplete evidence.
