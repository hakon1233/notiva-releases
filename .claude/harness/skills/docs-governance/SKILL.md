---
name: docs-governance
description: Use PROACTIVELY when any `.md` file is created, renamed, or moved outside `src/`. MUST BE USED when the user says "stray docs", "docs governance", "where should this doc live", or runs the stray-doc auditor. Canonical home for the vault-synced allowlist and the filename-heuristic table that maps stray docs to their correct location.
last_updated: 2026-04-18
---

## Before you start

1. Check if `docs/sessions/$(date +%Y-%m-%d).md` exists
2. If not, create it with a session header: `## Session — HH:MM` + `**Objective:** one-line summary`
3. Log your work continuously as you go — do not wait until the end

# Docs Governance

Every piece of non-code documentation in this repo must live in a path that the Obsidian vault-sync agent mirrors. That way anyone browsing the vault, or the in-app "Vault Docs" tab, sees the full picture. Stray `.md` files are a bug.

## The rule

Documentation lives in one of these locations (authoritative list — sync script mirrors each of them):

| Location | Purpose |
|---|---|
| `docs/**` | Long-form docs, decisions, system specs, session logs, research |
| `.claude/bugs/**` | Bug tracker (agent-reported, user-reported, per-workflow) |
| `.claude/test-runs/**` | Fix-loop test-run artifacts |
| `.claude/workflows.md` | Workflow registry |
| `.claude/skills/**` | Claude skills (SKILL.md files) |
| `.claude/commands/**` | Slash-command definitions |
| `.claude/agents/**` | Subagent definitions |
| `README.md`, `AGENTS.md`, `CLAUDE.md` (root only) | Top-level entry points |

Anything else that is "documentation" (not code, not generated, not vendored) is **stray** and must be moved into one of those paths.

## Not in scope

- `src/**` — inline code comments are not docs
- `plans/**`, `templates/**` — separate systems
- `node_modules/**`, `.next/**`, build artifacts
- Scoped `AGENTS.md` files (e.g. `server/AGENTS.md`) — legitimate, keep in place
- Tool-specific configs like `.github/copilot-instructions.md`
- `tests/e2e-*.md` test runbooks — judgment call: move to `docs/testing/` unless the test runner reads them

## Detection

Run the auditor:

```bash
scripts/docs/audit-stray-docs.sh
```

It globs every `*.md` in the repo, subtracts the in-scope and out-of-scope lists above, and prints what's left. Exit code 0 if clean, 1 if any stray docs remain.

## Prompt-to-fix flow

For each stray file the auditor reports:

1. Read the first ~40 lines to understand what it is.
2. Propose a target under the allowlist using these filename heuristics (apply the **first** that matches):

| Pattern / content signal | Target |
|---|---|
| `*_RUNBOOK*.md`, `*PRODUCTION*.md`, "how to deploy", "rollback", "oncall" | `docs/runbooks/` |
| `*_BLUEPRINT*.md`, `*DESIGN*.md`, "architecture", "system diagram" | `docs/architecture/` |
| `ADR-*`, `*DECISION*.md`, "we chose X because" | `docs/decisions/` |
| `*HANDOFF*.md`, "what's next", "picking up from" | `docs/handoffs/` |
| `*SPIKE*.md`, `*RESEARCH*.md`, `*_NOTES.md`, technical option analysis | `docs/research/` |
| `*COMPETITOR*.md`, `*COMPARISON*.md`, competitor analysis | `docs/product/competitors/` |
| `*INTERVIEW*.md`, `*FEEDBACK*.md`, `*PERSONA*.md`, user research | `docs/product/users/` |
| `*FEATURE*.md`, `*PROPOSAL*.md`, "feature request", "proposal" | `docs/product/features/` |
| `*IDEA*.md`, `ideas*.md`, half-baked thoughts | `docs/product/ideas/` |
| `*POLICIES*.md`, `*GOVERNANCE*.md`, permissions/RBAC | `docs/system/` |
| `*_OVERVIEW.md` at root | `docs/SYSTEM_OVERVIEW.md` (if project's overview is empty, merge; otherwise `docs/architecture/`) |
| Anything else doc-shaped | `docs/` (root) — let the user pick a subdir |

3. **Ask the user before moving** — one confirmation per file, or a batched `"move all to <target>"` if several share the same target.
4. `git mv` the file (preserves history). Update any internal links that referenced the old path — grep the repo for the old basename first.
5. Wait for next vault-sync cycle (up to 5 min) — the old vault copy clears via `rsync --delete`.

Do not auto-move without confirmation. Stray files often encode history that's worth glancing at — and sometimes the right answer is "delete it," not "move it."

## Skills inventory

The same principle applies to skills, commands, and agents. To see the current inventory classified as **standard** (present in `templates/claude-project-template/.claude/`) vs **project-specific** (only in this repo), regenerate the index:

```bash
scripts/docs/generate-skills-index.sh
```

This writes `docs/meta/SKILLS.md`. The file is committed and auto-syncs to the vault, so it's browsable from the Vault Docs tab. Regenerate it whenever you add, remove, or rename a skill / command / agent.

### Classification rules the generator applies

- **standard** — filename exists in the template at the same relative path.
- **project-specific** — exists in this repo, not in the template.
- **drifted** — exists in both but content differs (informational only; drift is often intentional).
- **missing** — exists in template, not in this repo (flag for review).

## When to run this skill

- After creating any `.md` outside the allowlist (the file watchers in editors don't enforce it).
- Before cutting a release, as part of the pre-commit walk.
- After adding / renaming / removing a skill, command, or agent.
- Periodically, as part of the `/session-log` housekeeping (~monthly).

## Template propagation

This skill is part of the standard project template. When it changes, also update:

- `templates/claude-project-template/.claude/skills/docs-governance/SKILL.md`

…so `/new-repo` inherits the current version.
