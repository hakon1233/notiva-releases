---
name: glossary
description: Use PROACTIVELY when introducing a new entity name, action verb, or role label in code, comments, or docs. MUST BE USED when you're about to coin a term that the project hasn't used before, or when naming feels ambiguous (User vs Account vs Member, fetch vs load vs sync, owner vs admin vs root). Defines this project's ubiquitous language so every dispatched worker inherits the same vocabulary instead of re-deriving it.
last_updated: 2026-04-29
---

# Glossary — this project's ubiquitous language

Every project that grows past a few features develops a vocabulary: which thing is called `User` vs `Account`, whether actions are `fetch` or `load`, whether roles are `owner` or `admin`. The vocabulary is usually tribal — held in the heads of the people who built the early features. When agents are dispatched into the repo, they don't have that head-knowledge, so they invent new names that drift from the existing ones.

This skill exists to make the vocabulary deployable: one file every worker reads at dispatch time, with the canonical names, the actions, and the roles. The agent stops re-litigating "should this be called `addUser` or `inviteMember`?" — the glossary already answered.

## How this works

1. Every project has a `GLOSSARY.md` at its root (or a `## Glossary` section in `AGENTS.md`).
2. The glossary lists the **entities** (nouns), **actions** (verbs), and **roles** (labels) the project uses.
3. Workers consult the glossary BEFORE introducing new vocabulary. If the concept fits an existing entry, use that name. If it genuinely doesn't, the worker proposes the new term back to the orchestrator instead of just adding it.
4. The orchestrator owns updates to the glossary. Workers don't edit it unilaterally.

## Format

```markdown
# Glossary

## Entities
- **User** — the human accessing the app. Always `User`, never `Account` or `Member`.
- **Project** — the unit of work being managed. NOT `Workspace` (workspace means an agent's filesystem dir).
- **Worker** — a dispatched Claude Code / Codex session that does write work.
- **Orchestrator** — the long-running agent that dispatches workers.

## Actions
- **dispatch** — orchestrator → worker session creation. NOT `spawn`, NOT `launch`.
- **fetch** — read remote data. NOT `load` (load means from disk).
- **emit** — write a telemetry event. NOT `log` (log means stderr).

## Roles
- **owner** — the user who created a project. NOT `admin`, NOT `root`.
- **member** — additional users granted access. NOT `collaborator`.
```

Keep it short. A glossary that grows past 50 entries is a sign you have too many synonyms — collapse, don't accumulate.

## Why this matters more in the AI era

When humans are the only writers, vocabulary drift is bounded by the team's collective memory. When agents are writing code at machine speed, drift compounds at machine speed too. Three workers dispatched in the same week can each invent slightly different names for the same concept — and now the codebase has `User`, `Account`, and `Member` all referring to the same row in the same database table.

The glossary is the cheapest tool against this. One file, deployed alongside SOUL, read at every dispatch.

## When to consult

- **Before introducing any new entity name, action verb, or role label in code, comments, tests, or docs.**
- **Before renaming something** — rename through the glossary first; if the term is canonical, the rename is a project decision (escalate to orchestrator), not a worker decision.
- **When you see a name that feels off.** "Why is this `fetchUser` here but `loadAccount` there?" If the glossary has both, it should explain when each applies. If it doesn't, that's a glossary bug — flag it.

## When NOT to use new vocabulary

- If an existing entry covers your concept, use that entry's term — even if you'd phrase it differently. The cost of a slightly-suboptimal name is much lower than the cost of vocabulary drift.
- Library/framework names are exempt — `useQuery`, `Suspense`, etc. are React's vocabulary, not yours. The glossary covers domain terms.

## Updating the glossary

1. Worker proposes the new term in chat: "I want to add `Engagement` for the user-feature interaction concept. Doesn't fit `Session` (too short-lived) or `Visit` (too anonymous). OK to add?"
2. Orchestrator (or user) approves or pushes back.
3. The orchestrator owns the actual edit to `GLOSSARY.md`. Workers don't write to it.
