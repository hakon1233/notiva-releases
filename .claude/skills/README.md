# Skills Index

One-page inventory of every skill in this project. Scan this first when looking for the right skill to apply.

**Rule:** if you find yourself re-inventing a rhythm that feels like it should be documented, check here before writing it.

## Core discipline skills

| Skill | Purpose | Referenced by |
|---|---|---|
| **[test-first](test-first/SKILL.md)** | **Canonical bug-fix discipline.** Red-before-green, reproducer file conventions, exit codes, cross-file bug tracking, layered regression defense, restart decision tree. Use for ANY bug fix. | `fix-loop`, `bug-fixer` agent |
| [fix-loop](fix-loop/SKILL.md) | Workflow-scoped fix cycle. Scoped to one workflow at a time. Delegates to `test-first` for the bug-fix rhythm. | `bug-fixer` agent |
| [commit](commit/SKILL.md) | Read before any commit. Delegates to `docs-governance` + `writing-skills` for the rules. | — |
| [session-logging](session-logging/SKILL.md) | Mandatory continuous session log — where, when, and format. | — |
| [docs-governance](docs-governance/SKILL.md) | **Canonical home for the doc allowlist.** Stray-doc auditor + skills inventory. | `commit` |
| [writing-skills](writing-skills/SKILL.md) | **Canonical home for skill/agent/command authoring rules.** Frontmatter, routing descriptions, skill-vs-agent decisions, promotion flow. | `commit` |
| [workflow-management](workflow-management/SKILL.md) | **Canonical home for the four-file workflow contract.** Creating, maintaining, retiring workflows. | `fix-loop` |

## Adding a new skill

Read `writing-skills/SKILL.md` — it's the canonical authoring guide. It covers frontmatter rules, how to write a description that auto-routes, when to use a skill vs an agent vs a command, and the promotion path from project-specific to template-standard.

After creating a new skill, add an entry to this README and to `CLAUDE.md`'s skills table.

## Project-specific skills

Skills unique to this project (not part of the standard template) go here. They won't exist in the template's `templates/claude-project-template/.claude/skills/` — that's what makes them project-specific.

Examples of skills a project might add:
- `deploy-verify` — post-deployment health checks (if the project has a deploy pipeline).
- `refactor-plan` — structured refactor workflow (if the project does big refactors frequently).
- `safety-review` — async/race/state-corruption review (if the project has concurrent code paths).

Add them when you actually need them; don't scaffold aspirationally.

## Bug-fix discipline

All bug fixes go through `test-first`. See `.claude/skills/test-first/SKILL.md` — that's the canonical rhythm for red-before-green, reproducer files, regression defense, and the four-file bug-tracking flow.
