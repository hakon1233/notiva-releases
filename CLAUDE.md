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

## Skills (loaded automatically based on context)

| Skill | When to use | Path |
|-------|-------------|------|
| Fix loop | Testing and fixing bugs | `.claude/skills/fix-loop/SKILL.md` |
| Test-first | Fixing any bug | `.claude/skills/test-first/SKILL.md` |
| Refactor plan | Before refactoring code | `.claude/skills/refactor-plan/SKILL.md` |
| Spec check | After significant changes | `.claude/skills/spec-check/SKILL.md` |
| Deploy verify | After deploying | `.claude/skills/deploy-verify/SKILL.md` |
| Safety review | Touching async/state code | `.claude/skills/safety-review/SKILL.md` |

Bug tracking lives in `.claude/bugs/`. Document decisions in `docs/decisions/`.


## Workflows

Workflows define the critical user flows that must always work. They connect testing, bug tracking, and documentation.

- **Definitions:** `.claude/workflows.md` (what to test and how)
- **Behavioral specs:** `docs/system/<workflow-name>.md` (what should happen — synced to vault)
- **Bug tracking:** `.claude/bugs/workflows/<name>.md` (issues per workflow)
- **How it all fits:** `docs/system/how-the-system-works.md`
