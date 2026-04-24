---
name: commit
description: Use PROACTIVELY before any commit AND during longer tasks to commit per logical unit. MUST BE USED when the user says "commit", "ready to commit", "create a commit", "git commit", "pre-commit", or is about to run `git add`/`git commit`. Explains the atomic commit cadence (one logical unit per commit, mid-task is fine), the docs + template contract, and the two-line pre-commit check (audit-stray-docs + generate-skills-index) to run when docs or .claude/{skills,commands,agents}/ changed.
last_updated: 2026-04-20
---

# Commit Contract

Read this skill before creating any commit in this repo. It's the canonical explanation of how docs, skills, and the project template fit together, and the short checklist to run before committing.

## The contract (1 minute read)

Two canonical contracts apply to every commit:

- **Where docs live** — see `.claude/skills/docs-governance/SKILL.md` for the authoritative allowlist of synced paths. Anything outside that list is stray and must be moved.
- **Skill / command / agent frontmatter** — see `.claude/skills/writing-skills/SKILL.md` for the authoring rules (name, description-as-routing-rule, last_updated, tools, model). CI fails the build on missing frontmatter.

**The template is the source of truth for standard skills.** Files in `templates/claude-project-template/.claude/` are deployed to every project. Files only in this repo's `.claude/` are project-specific. `docs/meta/SKILLS.md` classifies each file as standard / project-specific / drifted / missing — drift is usually intentional, but worth a glance.

## Atomic commit cadence — commit per logical unit, not per task

**Commit during the task, not only at the end.** Each commit captures one logical unit of work. If a feature or bug fix spans five steps, that's often three or four commits — not one giant blob at the end.

Why this matters:
- `git diff HEAD~1` becomes the canonical "show me what you just changed" surface. The user can review a single step without reading a 500-line dump.
- If step 3 broke something, `git bisect` or a revert is one commit, not a full rollback.
- `git blame` tells a useful story — each line traces to the specific decision that introduced it.
- Aider, Devin, and SOTA coding harnesses (SWE-bench leaders) converged on this pattern for a reason: small atomic commits outperform mega-commits on every downstream maintenance metric.

When to split a commit:
- **You finished a self-contained step** — a reproducer lands, a fix lands, a refactor lands, a doc update lands. Each of those is its own commit.
- **You're about to switch concerns** — if the next edit touches a different file or subsystem than the last one, cut the commit before you start.
- **Something's reviewable on its own** — if you can write a clean one-line commit message for what you just did, commit it.

When NOT to split:
- Two edits are genuinely inseparable (e.g. a rename of a function + every call-site of that function — those must land together).
- A step that doesn't compile or breaks tests on its own. Squash it into the commit that makes it work.

**Message for mid-task commits**: same Conventional Commits convention, short subject, body optional. A 1-line subject is fine when the context is obvious from the adjacent commits.

```
fix(auth): commit the reproducer for BUG-042 (red)
fix(auth): apply fix to token refresh (green)
test(auth): verify no regressions in session-expiry suite
```

Three commits, each meaningful on its own. Not one commit called "fix auth bug".

**Hard rule — bug fixes default to one bug per commit** (per `test-first` Step 6). Don't batch unrelated bug fixes into the same commit; it breaks the `git blame` story.

## Before anything else — engineering standards check

Run the six-rule checklist in `.claude/skills/engineering-standards/SKILL.md`. If any box is empty, do **not** commit until you've fixed the issue or explicitly surfaced it to the user. Quick fixes silently committed is how repos rot.

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
