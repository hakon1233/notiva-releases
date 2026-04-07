# notiva-releases — Claude Guide

## Session Logging (MANDATORY)

Every Claude Code session in this repo must maintain a continuous session log.

- **Where:** `docs/sessions/YYYY-MM-DD.md` (create folder/file if they don't exist)
- **When:** After each meaningful unit of work — don't wait for the session to end
- **Format:** See `.claude/commands/session-log.md` for the full format
- **Why:** This repo's docs/ folder syncs to the Obsidian vault every 5 minutes

## Fix Loop

Run `/fix-loop` to start automated testing. Configure workflows in `.claude/workflows.md`.

Bug tracking lives in `.claude/bugs/` — agents report issues there automatically during the fix loop.
