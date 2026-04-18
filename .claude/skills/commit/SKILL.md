---
name: commit
description: Use PROACTIVELY before any commit. MUST BE USED when the user says "commit", "ready to commit", "create a commit", "git commit", "pre-commit", or is about to run `git add`/`git commit`. Explains the docs + template contract and the two-line pre-commit check (audit-stray-docs + generate-skills-index) to run when docs or .claude/{skills,commands,agents}/ changed.
last_updated: 2026-04-18
---

# Commit Contract

Read this skill before creating any commit in this repo. It's the canonical explanation of how docs, skills, and the project template fit together, and the short checklist to run before committing.

## The contract (1 minute read)

Two canonical contracts apply to every commit:

- **Where docs live** — see `.claude/skills/docs-governance/SKILL.md` for the authoritative allowlist of synced paths. Anything outside that list is stray and must be moved.
- **Skill / command / agent frontmatter** — see `.claude/skills/writing-skills/SKILL.md` for the authoring rules (name, description-as-routing-rule, last_updated, tools, model). CI fails the build on missing frontmatter.

**The template is the source of truth for standard skills.** Files in `templates/claude-project-template/.claude/` are deployed to every project. Files only in this repo's `.claude/` are project-specific. `docs/meta/SKILLS.md` classifies each file as standard / project-specific / drifted / missing — drift is usually intentional, but worth a glance.

## Pre-commit checklist

Run these only if your commit **touched the relevant surface** — don't run blindly on every commit.

### If you added, renamed, or removed any `*.md` file outside `src/`:
```bash
./scripts/docs/audit-stray-docs.sh
```
Exits 1 if any doc lives outside the synced allowlist. Fix by `git mv`-ing the offender into the right directory.

### If you added, renamed, or removed a skill / command / agent:
```bash
./scripts/docs/generate-skills-index.sh
git add docs/meta/SKILLS.md
```
This regenerates the classified inventory. Commit the regenerated file alongside your change.

### If you changed a skill / command / agent file:
Update its `last_updated:` frontmatter to today's date.

### If the change lives inside `templates/claude-project-template/`:
You're editing the **template for every repo on the Mac mini**. After commit + push, someone will need to run `bash ~/projects/obsidian-vault-v2/scripts/bootstrap-claude-template.sh` to propagate. Mention this in the commit body if it's non-trivial.

## What NOT to do

- **Don't** add a `.md` under a new top-level path just because it "seems documentation-adjacent." Pick one of the allowed locations from `docs-governance`.
- **Don't** promote a skill from project-specific → standard silently. See `writing-skills/SKILL.md` for the promotion flow — a dedicated commit with rationale, never a drive-by.
- **Don't** skip routing-rule descriptions on new skills/agents. `writing-skills` explains why and how.
- **Don't** edit `.claude/template-version.json` by hand — it's written by the bootstrap script.

## Why this exists

Two problems we're defending against:
1. **Docs drift** — notes get written wherever's convenient, vault doesn't see them, someone re-invents the same doc six months later.
2. **Skill opacity** — skills exist but no one knows which are standard vs local, which are stale, which drifted from the template.

`docs/meta/SKILLS.md` + the template + this skill together close both gaps.

## References

- **Docs rules** (allowlist, scope, auditor): `.claude/skills/docs-governance/SKILL.md`
- **Authoring rules** (frontmatter, routing, skill/agent/command decisions): `.claude/skills/writing-skills/SKILL.md`
- **Template viewer page**: `/project-template` in the app.
- **Skills inventory**: `docs/meta/SKILLS.md` (regenerate via `./scripts/docs/generate-skills-index.sh`).
- **Stray-doc auditor**: `./scripts/docs/audit-stray-docs.sh`.
- **Bootstrap script**: `~/projects/obsidian-vault-v2/scripts/bootstrap-claude-template.sh` (supports `--check` and `--diff`).
