---
name: writing-skills
description: Canonical guide for authoring skills, subagents, and slash commands in this repo. Read MUST BE USED whenever creating, editing, promoting, or removing a file under .claude/{skills,agents,commands}/ — covers the frontmatter contract, routing rules, skill-vs-agent decisions, and the template propagation flow.
last_updated: 2026-04-18
---

# Writing Skills, Agents, and Commands

Canonical reference for everything under `.claude/{skills,agents,commands}/`. Other files may reference this skill — don't restate the rules elsewhere.

## The frontmatter contract (applies to all three)

Every `.claude/{skills,commands,agents}/**/*.md` file must start with YAML frontmatter:

```yaml
---
name: <slug matching the filename or directory>
description: <see "Description as routing rule" below>
last_updated: YYYY-MM-DD
---
```

Agents and skills may add optional fields (see per-kind sections). The CI validator `src/lib/__tests__/claude-manifests.test.ts` fails the build if:
- `name` or `description` is missing.
- `name` doesn't match the file/dir slug.
- `last_updated` is nice-to-have but not currently enforced.

## Description as routing rule (not label)

Claude Code decides whether to auto-load a skill — or the main Claude decides whether to invoke an agent — based almost entirely on the `description:` field. Write it as a **routing rule**, not a capability description.

**Weak**: `Security audit skill.`
**Strong**: `Use PROACTIVELY when the user mentions security, OWASP, vulnerabilities, or is about to commit changes under src/auth/ or src/api/. MUST BE USED for any code touching authentication, authorization, or session handling.`

The strong version names:
- Concrete trigger phrases (what the user says).
- Concrete scope markers (what files / contexts).
- The magic phrases **`use PROACTIVELY`** or **`MUST BE USED when …`** — these measurably raise invocation odds.

Keep it one sentence to ~3 short sentences. Think: "what would the main Claude read that would make it choose this?"

## Skill vs agent vs command — the decision rule

| Want | Pick |
|---|---|
| Guidance the main Claude should weave into the current thread | **Skill** |
| A bounded, noisy, parallelizable task that should run in its own context and return one summary | **Agent** |
| A named invocation the user types (`/foo`) to kick off a recipe | **Command** |

Concrete tests:
- If the work fits in the main conversation without drowning it, use a **skill**. Skills are knowledge.
- If the task touches 10+ files, has its own multi-step plan, or you'd rather not see the raw intermediate output in the main thread → **agent**. Agents are workers.
- If you want a user-facing entry point with a name (`/fix-loop`, `/new-repo`) → **command**. Commands usually just point at a skill/agent and pass arguments.

### When in doubt, skill

A skill that gets read but not needed costs almost nothing. An agent that gets invoked and doesn't need to exist costs a spawn + summary round-trip. Default to skill unless context-isolation is the explicit goal.

## Per-kind rules

### Skills (`.claude/skills/<name>/SKILL.md`)

- One skill per directory. The file is always `SKILL.md`.
- `name:` matches the directory name.
- Body: explain the rule / discipline / rhythm. Be crisp — under ~150 lines where possible.
- **Delegate, don't duplicate.** If another skill owns a piece of discipline, reference it: `See .claude/skills/test-first/SKILL.md for reproducer conventions.` Do not restate the reproducer conventions here.

### Agents (`.claude/agents/<name>.md`)

Frontmatter adds two important fields:

```yaml
tools: Read, Grep, Glob                # Explicit allowlist (hard constraint)
model: haiku                           # sonnet | opus | haiku | inherit (default)
```

Rules:
- **Always set `tools:`.** Default-to-all is the single most common bloat. A reviewer with `tools: Read, Grep, Glob` physically cannot write files even if the prompt tells it to.
- **Always set `model:`.** Read-only research and review → `haiku` (≈15× cheaper, fine for bounded work). Reasoning-heavy fix work → `sonnet`. Only use `opus` if you need deep reasoning and are willing to pay.
- **Job-shaped name.** `repo-explorer`, `bug-fixer`, `pr-reviewer` read better than `explorer`, `fixer`, `reviewer`. Concrete > abstract.
- **Description names at least two trigger situations** + one of `use PROACTIVELY` / `MUST BE USED when X`.
- **Body is short.** Most good agents are 20–60 lines. Long agents are usually skills that should have been delegated to.
- **Delegate to skills for discipline.** An agent's body points at the canonical skill (`Read .claude/skills/test-first/SKILL.md first`). Don't restate the skill's rules inside the agent.

### Commands (`.claude/commands/<name>.md`)

- Frontmatter same as skills (name, description, last_updated).
- Body: a short recipe the agent follows step by step.
- Almost always points at a skill (`Read .claude/skills/<name>/SKILL.md, then …`). Commands are thin.

## Where does it live? Project-specific vs template-standard

Every `.claude/{skills,commands,agents}/` file is one of two things:

- **Standard** — lives in `templates/claude-project-template/.claude/<kind>/<name>` in this repo. Shipped to every project via `/new-repo` and `bootstrap-claude-template.sh`. Use for rules that apply to every project.
- **Project-specific** — lives only in the individual repo's `.claude/<kind>/<name>`. Use for rules specific to this project's domain (e.g. orchestrator-specific, domain-specific validators).

The skills-index generator (`scripts/docs/generate-skills-index.sh`) classifies every entry as **standard / project-specific / drifted / missing** against the template and writes `docs/meta/SKILLS.md`. Regenerate after any add / rename / remove.

## Promoting a project-specific skill → standard

When a project-specific skill proves useful across projects:

1. `git mv .claude/skills/<name> templates/claude-project-template/.claude/skills/<name>` in the TTM repo.
2. Ensure frontmatter is complete and generic (no project-specific paths, no hardcoded IDs).
3. Regenerate `docs/meta/SKILLS.md`.
4. Commit with a clear "promote" message explaining why it earned its place in every project.
5. Next `bootstrap-claude-template.sh` run propagates to all existing repos.

Don't promote silently. A promotion commit is a contract change — it adds mandatory content to every future-scaffolded repo.

## Removing a skill / agent / command

1. Grep for references across `.claude/`, `docs/`, `src/`, `CLAUDE.md`, `AGENTS.md`, `templates/`. Fix dangling mentions.
2. If it's referenced from an agent's body (e.g. `Read X/SKILL.md first`) — pick a replacement or inline the minimum.
3. Delete the file (`git rm`).
4. Regenerate `docs/meta/SKILLS.md`.
5. Check `scripts/generate-skills-index.sh` classification — removed-from-template entries move from "Standard" to "Missing" or disappear, as expected.

## Smoke tests before committing a new skill / agent

```bash
# 1. Frontmatter validator
npx vitest run src/lib/__tests__/claude-manifests.test.ts

# 2. Classification update
./scripts/docs/generate-skills-index.sh

# 3. Eyeball the routing description
# Ask yourself: if I were the main Claude reading this description,
# under what user prompt would I load this skill / invoke this agent?
# If you can't answer in one sentence, the description is too weak.
```

## Two "skill" systems — don't confuse them

The word "skill" means two different things in this repo's broader ecosystem. This skill only governs the first:

| System | Location | Audience | Written in |
|---|---|---|---|
| **Worker skills** (what this skill governs) | `.claude/skills/<name>/SKILL.md` in any repo | Claude Code workers dispatched into the repo — auto-loaded by the harness | Markdown with YAML frontmatter |
| **Orchestrator skills** | `~/.openclaw/workspace-<agent>/skills/*.md` (deployed from TypeScript) | OpenClaw orchestrator agents on the Mac mini | TypeScript factory functions in `src/lib/openclaw/skill-definitions.ts` |

They share no runtime. A worker never reads an orchestrator skill, and vice versa. If you want to change **orchestrator behavior** (how it dispatches, plans, reports), edit `src/lib/openclaw/skill-definitions.ts` and run `scripts/update-openclaw-souls.sh`. This skill doesn't apply there.

See `docs/system/instruction-hierarchy.md` for the full map of who reads what.

## Further reading

- [Claude Code sub-agents docs](https://code.claude.com/docs/en/sub-agents) — canonical frontmatter fields + tool restriction syntax.
- [Anthropic blog on subagents](https://claude.com/blog/subagents-in-claude-code) — skills vs subagents distinction.
- `.claude/skills/commit/SKILL.md` — pre-commit contract (uses this skill's rules).
- `.claude/skills/docs-governance/SKILL.md` — canonical home for the doc-location allowlist.
- `docs/system/instruction-hierarchy.md` — full map of SOUL / skills / CLAUDE.md / AGENTS.md and who reads which.
