# Product

Product and market intelligence for this project. Separate from `docs/research/` (which is scoped to technical research: library comparisons, API spikes, performance benchmarks).

## What goes here

| Subfolder | Purpose |
|---|---|
| `competitors/` | Per-competitor analysis — pricing, features, strengths, weaknesses, screenshots, lessons worth stealing. |
| `users/` | Interview notes, feedback patterns, support-ticket themes, personas. |
| `features/` | Structured feature proposals: problem, proposed solution, alternatives considered, risks, open questions. Proposals that graduate become tickets. |
| `ideas/` | Half-baked thoughts, shower ideas, "what if we did X" — anything worth capturing before it's fully formed. |

## Where this is NOT for

- **Industry news, market trends, general inspiration** — those are cross-project and live in the Obsidian vault root, not in any single project's repo.
- **Technical research** — that's `docs/research/`.
- **Architecture decisions** — that's `docs/decisions/` (ADRs).
- **Runbooks** — that's `docs/runbooks/`.

## When to promote

- **Idea → feature proposal**: when the idea is specific enough to describe as "here's what we'd build and why", move or rewrite it in `features/`.
- **Feature proposal → ticket / workflow**: when the feature is ready to build, create a workflow entry (see `workflow-management/SKILL.md`), file bugs if it breaks existing flows, and archive or delete the proposal.
- **Competitor insight → decision**: if a competitor's approach changes your direction, capture it in a decision record (`docs/decisions/`) so future-you knows why.

Content here syncs to the Obsidian vault. Edit either side; the 5-minute sync pulls it back.
