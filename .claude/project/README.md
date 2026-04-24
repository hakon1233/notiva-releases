# .claude/project/ — YOUR editable layer

Everything here is owned by this project. The harness never touches it.
Add your custom skills, agents, or AGENTS.md/CLAUDE.md additions here —
they survive every harness version bump.

## What goes where

- `skills/<name>/SKILL.md` — project-specific skills (same Claude Code skill format as `.claude/harness/skills/`). Project skills override harness skills on name collision.
- `agents/<name>.md` — project-specific subagents.
- `CLAUDE.part.md` — appended below the harness section of `CLAUDE.md`. On conflict, this section wins (later text has higher precedence).
- `AGENTS.part.md` — same, but for `AGENTS.md`.

## How updates work

After you edit anything here, run `bash scripts/compose-workspace.sh` to
rebuild the composed files (`.claude/skills/`, `.claude/agents/`, root
`CLAUDE.md`, root `AGENTS.md`). The next bootstrap deploy also runs compose
automatically.
