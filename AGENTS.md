# notiva-releases

Primary contract for AI coding agents (Claude Code, Codex, Copilot, Cursor, Aider, Gemini, etc.). Tool-specific extensions live in `CLAUDE.md` and `~/.claude/skills/` — this file is the neutral baseline every AI reads.

## What is this

<!-- One paragraph: what the project does, who it's for, what shape it has. -->

## Tech stack

<!-- List runtime, framework, package manager, key libraries. -->

## Development

<!-- Commands for dev, test, build, deploy. Keep it copy-paste-runnable. -->

```bash
npm install            # Install deps
npm run dev            # Dev server
npm test               # Run tests
npm run build          # Production build
```

## Project structure

<!-- Brief map of top-level directories. Don't duplicate what a listing would show — focus on non-obvious boundaries. -->

- `src/` — application code
- `docs/` — non-code docs (synced to Obsidian vault every 5 minutes)
- `.claude/` — Claude Code config: skills, commands, agents, bug tracker

## Conventions

- **Commits**: [Conventional Commits](https://www.conventionalcommits.org) with scope: `feat(api):`, `fix(ui):`, `refactor(db):`, `docs:`, `chore:`.
- **Docs location**: every non-code `*.md` lives under `docs/**`, `.claude/bugs/**`, `.claude/skills/**`, `.claude/commands/**`, `.claude/agents/**`, or is one of `README.md` / `AGENTS.md` / `CLAUDE.md` at the root. Run `./scripts/docs/audit-stray-docs.sh` to enforce.
- **Bug fixes**: red-before-green — a failing reproducer first, then the fix. See `.claude/skills/test-first/SKILL.md`.
- **Session logs**: every agent session appends to `docs/sessions/$(date +%Y-%m-%d).md` continuously (not at the end).

## Verification before commit

```bash
npm test
./scripts/docs/audit-stray-docs.sh
./scripts/docs/generate-skills-index.sh   # only if .claude/{skills,commands,agents}/ changed
```

## For Claude Code specifically

Read `CLAUDE.md` for Claude-specific rhythms. The canonical skill inventory is at `.claude/skills/README.md` and the classified version is at `docs/meta/SKILLS.md`.

## For other AI tools

If your tool reads a different rules file, symlink it to this one:

```bash
ln -s AGENTS.md CLAUDE.md                      # Claude Code (if you prefer one source)
ln -s AGENTS.md .github/copilot-instructions.md
ln -s AGENTS.md GEMINI.md
```

This keeps every agent on the same contract.
