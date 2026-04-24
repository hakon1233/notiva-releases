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
| Test impact | Before committing changes | `.claude/skills/test-impact/SKILL.md` |
| Workflow mgmt | Discovering critical user flows | `.claude/skills/workflow-management/SKILL.md` |

Bug tracking lives in `.claude/bugs/`. Document decisions in `docs/decisions/`.


## Workflows

Workflows define the critical user flows that must always work. They connect testing, bug tracking, and documentation.

- **Definitions:** `.claude/workflows.md` (what to test and how)
- **Behavioral specs:** `docs/system/<workflow-name>.md` (what should happen — synced to vault)
- **Bug tracking:** `.claude/bugs/workflows/<name>.md` (issues per workflow)
- **How it all fits:** `docs/system/how-the-system-works.md`

## Product research (competitors, users, features, ideas)

When the conversation touches product/market intelligence — **not technical research** — route to `docs/product/`:

| If the user / session is about… | Go here | Template |
|---|---|---|
| A competitor | `docs/product/competitors/<name>.md` | `docs/product/competitors/README.md` |
| User interviews / feedback / personas | `docs/product/users/<YYYY-MM-DD-topic>.md` | `docs/product/users/README.md` |
| A structured feature proposal | `docs/product/features/<feature-name>.md` | `docs/product/features/README.md` |
| A half-baked idea | `docs/product/ideas/<slug>.md` | `docs/product/ideas/README.md` |

Distinct from `docs/research/` (technical spikes) and `docs/decisions/` (ADRs).


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
