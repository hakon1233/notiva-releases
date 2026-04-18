---
name: session-logging
description: Use PROACTIVELY at the start of every Claude Code session and after each meaningful unit of work. MUST BE USED when the session log is absent, when appending progress, or when wrapping up. Defines where session logs live (docs/sessions/YYYY-MM-DD.md), when to append, the entry format, and the continuous-log discipline.
last_updated: 2026-04-18
---

# Session Logging

Every Claude Code session in this repo maintains a continuous log. This is mandatory — the log is what the Obsidian vault syncs and what future-you reads.

## Where to log

`docs/sessions/YYYY-MM-DD.md` — today's date, one file per calendar day. Create the `docs/sessions/` folder if it doesn't exist.

- **File doesn't exist** → create it with a top-level heading: `# Sessions — YYYY-MM-DD`.
- **File exists** → append a `---` separator before your new entry.

## When to log

**Continuously, not at the end.** After completing a meaningful unit of work — fixing a bug, adding a feature, finishing research, making a decision — append to the log immediately. If the session dies mid-conversation, the log should already be up to date.

Meaningful units (log after each):
- A bug fix lands.
- A feature is wired end-to-end.
- A research question is answered.
- A decision is made (even without code change).
- A commit goes out.

Trivial units (skip):
- Reading files.
- A single small typo fix.
- Exploratory searches.

## Entry format

```markdown
---

## Session — HH:MM

**Objective:** one-line summary of what this session is doing

### Work log
- what you did, in plain language
- another thing you did
- keep it concise — 1 line per action

### Decisions
- any decisions made during this session (or omit if none)

### Files changed
- path/to/file.ts
- path/to/other-file.ts
```

## Rules

- Keep entries concise: 5–15 lines per session block.
- Use plain language, not function names or jargon. Future-you reads this months later.
- The **work log** section is the one you append to continuously — add lines as work completes.
- **Decisions** and **Files changed** can be written once at the end of a work block.
- One file per calendar day, multiple sessions in the same day separated by `---`.
- This folder syncs to the Obsidian vault (see `docs-governance`) — your logs will appear in the project's vault page within 5 minutes.

## When NOT to log

- Pure read-only exploration that didn't change anything and didn't reach a conclusion.
- Failed attempts you're about to retry — log the final outcome, not every dead end. (Exception: if a failed approach is worth documenting as a decision, log it under Decisions.)
