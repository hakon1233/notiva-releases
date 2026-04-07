# Session Log

Maintain a continuous session log for this repo. This is mandatory for every Claude Code session.

## Where to log

Write to `docs/sessions/YYYY-MM-DD.md` (today's date). Create the `docs/sessions/` folder if it doesn't exist.

- If the file doesn't exist, create it with a top-level heading: `# Sessions — YYYY-MM-DD`
- If it already exists, append a `---` separator before your entry

## When to log

Log **continuously** as you work. After completing a meaningful unit of work (fixing a bug, adding a feature, finishing research, making a decision), immediately append to the session log. Do not wait for the session to end.

If the session ends abruptly, the log should already be up to date.

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

- Keep entries concise: 5-15 lines per session block
- Use plain language, not function names or jargon
- The work log section is the one you append to continuously — add lines as work completes
- Decisions and files changed can be written once at the end of a work block
- One file per calendar day, multiple sessions separated by `---`
- This folder syncs to the Obsidian vault — your logs will be visible in the project's vault page
