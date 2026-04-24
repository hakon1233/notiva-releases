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


## Build quality (MANDATORY)

Building in this repo follows five stop rules, defined in **`.claude/skills/engineering-standards/SKILL.md`** — it auto-loads when you are about to build, fix, refactor, or commit.

1. **Simplicity before complexity** — no new abstraction without 2+ callers or a real simplicity win.
2. **First-run correctness** — actually run the thing; typecheck + tests are necessary but not sufficient.
3. **Root-cause fixes** — no silencing errors, no `@ts-ignore`, no retries to mask timing bugs.
4. **Clean complexity** — new abstractions get a name, purpose, boundary, test/doc.
5. **Scope discipline** — no drive-by refactors the user did not ask for.

If a rule conflicts with the user request, surface the tradeoff — do not silently comply with quick fixes.


## Intellectual honesty

How you think and talk matters as much as how you build:

1. **Do not just agree.** If the user approach has a better alternative, say so before complying. Surface tradeoffs. Priority is the right answer, not validating the user.
2. **Be critical, not nice.** Disagreement is useful; silent compliance is not. Push back when evidence points elsewhere.
3. **Do not skip to conclusions.** If you could not find the answer or reproduce the problem, say so and stop. No fabricated file paths, invented APIs, speculated causes, or made-up commands. Uncertainty reported honestly beats confident-sounding fiction.
4. **No stress-filling gaps.** When exploration is inconclusive, output: "here is what I found, here is what is still unknown, here is what I would do next." Not a guess dressed as a finding.
