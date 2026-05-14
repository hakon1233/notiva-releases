---
name: plain-closeout
description: "Invoke `Skill('plain-closeout')` when closing out **substantial multi-step work** — after completing a feature, refactor, or bug fix that touched multiple files or required design decisions. Fire for 'done', 'shipped', 'ready' on work that took 2+ turns or crossed multiple concerns. Skip for quick Q&A, single-turn clarifications, follow-ups, or acknowledgements ('got it', 'starting now'). It owns the Understanding Card — plain-language summary proving you grasped the real problem and it works."
last_updated: 2026-05-13
---

# Plain Closeout — the Understanding Card

A non-technical reader (founder, manager, the user of this repo) should be able to read your closeout in 30 seconds and answer two questions:

1. **Did the worker understand what I actually wanted?**
2. **Is it working, and is there anything I need to know?**

Build-log style replies — file lists, route counts, package renames, SHAs, "typecheck ✓ build ✓" — fail at both. They prove activity, not understanding. This skill replaces them.

## When this skill fires

**Use the card for:**

- Closeout of a multi-step task ("done", "shipped", "ready") — work that touched multiple files or concerns.
- Status update mid-task that wraps up a phase of work (not quick replies or single-turn acknowledgements).
- Handoff or goodnight messages to siblings or the user when the session has completed a substantial unit.

**Do NOT use the card for:**

- Quick Q&A ("what's the exact command", "show me the file", "paste the diff").
- Single-turn acknowledgements ("got it", "on it", "starting now").
- Follow-up clarifications or quick follow-on questions.
- Simple status checks ("still running?") — these are one-liners.

**Signal that you should use it:** If your reply would be more than 2–3 sentences AND involves explaining what you understood about the real problem, use the card. If it's a single sentence or a command, skip it.


## The card — six fields, all mandatory

Copy this shape verbatim. Every field must be present, in this order, with these labels. Nothing is optional. If a field has nothing to say, say "no caveats" or "nothing hidden" — do not omit it.

```
**What I built**
<one plain-English sentence — the conceptual thing, not the files>

**What it does for you**
<1–2 sentences — what's now possible or different in your day-to-day>

**What I understood the problem to be**
<2–3 sentences — the real problem inside, in plain language. This is
where the user checks whether you actually got it. Name the why, not
the what.>

**What I'm hiding from you**
<one sentence — the mechanical mess that lives in the code or the
session log. Point to where it lives if relevant; do not paste it.>

**Status**
Working | Half-built | Broken — <1–2 sentences honest assessment>

**What to watch for**
<1–2 sentences — caveats, surprises, side-discoveries, or "no caveats">
```

Target length: 150–250 words total. Long enough to verify comprehension, short enough to read at a glance.

## Banned in the card (and in chat generally)

These belong in the session log, never in chat:

- Absolute paths (`/Users/...`, `~/.openclaw/...`).
- Package identifiers with `@` (`@mh/ui`, `@mh/router-benchmarks`).
- Tool / framework / config names without a one-sentence gloss (no bare `tmux`, `cron`, `RSC`, `MCP`, `jq`, `yaml`, `tsx`).
- Unexpanded acronyms (`ADR`, `LLM`, `API`, `JSONL`, `RSC`, `MCP`, `TTM`) — expand on first use or use a plain-English equivalent.
- File counts ("49 files", "9 routes"), SHAs, byte sizes, version numbers — unless that number is literally the point.
- Phrases like "typecheck clean", "build green", "load-bearing", "diff anchor", "answer-key leak", "fixture", "harness", "delta", "trace", "tool_call".

If a technical term is genuinely the clearest word, use it and add a one-clause gloss: "the autopull pipeline (the bit on the Mac mini that picks up new code every minute)."

## Where the mechanical detail goes

The displaced content does not disappear — it goes to **`docs/sessions/YYYY-MM-DD.md`**, which is already mandatory in this repo (see `session-logging` skill). The card does not need to remind the user that the session log was updated; assume it was.

Other persistent artifacts you can point at without quoting:

- `runtime/progress.json` for current state.
- `.claude/bugs/` for bugs found / fixed.
- `bug-hunt/findings/` for real-defect writeups.

## Worked example — admin landing-shell migration

Real work the sibling session shipped on 2026-05-13: rebuilt every admin module's landing page on a shared layout shell, caught a real model-attribution bug mid-flight, fixed it, deployed.

Build-log style (what was actually sent — scattered across roughly twelve turns):

> "All 11 routes compile clean. Type-check ✓ build ✓. Pushed. Now waiting for autopull → debounce → build → swap → smoke. Bug 1 (model attribution): `normalizeModelId(undefined)` returns `DEFAULT_MODEL_ID`. Fixing now. Two safety nets armed: background watcher checking `~/.openclaw/state/mh-admin/last-deployed-sha`, plus ScheduleWakeup at 20:02."

Card style (what should have been sent):

> **What I built**
> A consistent layout shell for all the admin landing pages.
>
> **What it does for you**
> Every benchmark module's landing page now looks and behaves the same way — same header, same card style, same filter controls — so you can move between modules without re-learning each surface. The five goal pages got the same treatment.
>
> **What I understood the problem to be**
> Each module's landing used to be hand-rolled, so every new module was a one-off design exercise and basic filters (like "show only Opus 4.7 runs") got reimplemented from scratch each time. You wanted a single shared shape so adding the sixth module is a half-day instead of a week, and so your eye doesn't have to re-orient between modules.
>
> **What I'm hiding from you**
> Which files moved where, the eleven route paths, and the shared component names — all in today's session log.
>
> **Status**
> Working — all eleven pages render, and the deploy is live in production. I checked the live site against the dev preview and they matched.
>
> **What to watch for**
> Mid-flight I noticed a real bug: runs from before we started recording the model name were being labelled "Opus 4.7" by mistake. I fixed that in the same deploy, so if you see a sudden drop in the Opus 4.7 count on the leaderboard, that's the correction — not a regression.

## Why this shape

- **"What I understood the problem to be"** is the load-bearing field. It is the only one that catches the failure mode where the worker built the right shape for the wrong reason. If that paragraph reads like a thin paraphrase of the task, push back before the user commits deeper.
- **"What I'm hiding from you"** is honest about abstraction. The user sees *that* mechanical detail exists, just not its content. That's the deep-module contract (Ousterhout): simple interface, hidden complexity, but the hiding is visible.
- **"What to watch for"** is where side-discoveries surface. Yesterday's model-attribution bug got buried in deploy-watching prose; under this template it gets its own line and the user actually sees it.
- The fields **prevent drift back to build-log style** because there is no field called "Files changed", "Verify", or "Decisions". Those belong in the log.

## Failure modes to avoid

- **Padding the "understood" field with restated requirements.** "You asked me to migrate the landings, so I migrated the landings" is not understanding; it is paraphrase. Name the *why* — the underlying problem the request was a proxy for.
- **Saying "Working" when it isn't.** If the deploy hasn't landed, status is "Half-built". If you didn't visually verify, say so in "What to watch for". Honesty over polish.
- **Quoting the mechanical detail in the "hidden" field.** "What I'm hiding: I refactored `apps/admin/src/components/...`" defeats the field. Point at the log; don't paste it.
- **Skipping the card on a small task.** The card is short. If the work is small the fields are short. The discipline applies; the verbosity adjusts.

## One-line escape hatch

If the entire card would honestly be one sentence — the task was that small — collapse to:

> *<one sentence: what is now true that wasn't before>. <one sentence: the one thing you should know>.*

Anything bigger than that gets the full six-field card.
