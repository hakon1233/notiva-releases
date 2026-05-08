---
name: improve-architecture
description: "When the user says \"improve the architecture\", \"deslop the codebase\", \"refactor for depth\", \"improve modules\", \"find shallow modules\", or runs `/improve-architecture`: invoke `Skill('improve-architecture')` and run its three-phase explore → present → grill flow — it never refactors unilaterally; output is a candidate interface design recorded in CONTEXT.md / ADRs after user approval."
last_updated: 2026-04-30
---

# Improve Codebase Architecture

A deliberate, qualitative review pass. Adopted from
`mattpocock/skills/skills/engineering/improve-codebase-architecture/`
(MIT, vendored), adapted to our orchestrator/worker harness.

## What this skill is NOT

- It is not an automatic refactor tool. It does not write code.
- It does not measure file sizes or grep for code smells (the
  operations-auditor's `find-friction-patterns` extractor already does
  that and lands findings on `/fix-plan`).
- It does not produce diffs. It produces *design conversations* and
  side-effects in CONTEXT.md / ADRs.

## What it does

Runs a three-phase loop, with the user as the decision maker. Each
phase has a clear stop point and a clear handoff to the next.

| Phase | Who | Output |
|-------|-----|--------|
| 1. Explore | Sub-agent (read-only) | Numbered list of refactor candidates |
| 2. Present | Orchestrator | Same list, surfaced for user pick |
| 3. Grill | Orchestrator + user | Designed interface for chosen candidate, recorded in CONTEXT.md / ADR |

**Read `LANGUAGE.md` (in `module-map/`) before using this skill.** Every
proposal must use the canonical vocabulary (module / interface / seam /
adapter / depth-as-leverage / locality). Substitute words are banned.

**Read `DEEPENING.md` (sibling file)** before proposing any port or
adapter — it encodes when ports are justified by dependency category.

**Read `INTERFACE-DESIGN.md` (sibling file)** when the chosen candidate
needs interface design — describes the "design it twice" sub-agent
fan-out pattern and when to use the `/design-twice` skill instead.

---

## Phase 1 — Explore

The orchestrator dispatches **one read-only worker** with this brief:

> Walk the codebase organically. Apply the deletion test (see
> `module-map/LANGUAGE.md`) to any module you suspect is shallow. Look
> for: shallow modules, pure functions extracted only for testability,
> leaky seams (callers reaching into internals), interfaces that
> require the test to inspect private state, generic-named files
> (util/helper/common — they always fail the deletion test).
>
> Read `docs/glossary.md` (or `CONTEXT.md`) and `docs/decisions/` BEFORE
> walking. If a candidate would conflict with an existing ADR, surface
> the conflict explicitly — only escalate if the friction is real.
>
> Do NOT propose interfaces. Do NOT propose code. Just identify
> candidates.

The worker is dispatched read-only (`ttm-worker-readonly.sh` —
configured by `dispatch_worker --readOnly true`). Read-only is
load-bearing: the explorer must NOT start refactoring; that's a Phase 3
decision after the user picks.

**Worker output format** — exactly this shape, nothing else:

```markdown
# Architecture review — <repo>, <date>

## Candidate 1: <short title>
- **Files:** <2-5 paths>
- **Problem:** <1-2 sentences in canonical vocabulary>
- **Solution:** <high-level direction, 1-2 sentences>
- **Benefits:** <leverage and locality this would buy>
- **Deletion-test verdict:** <pass/fail and one-line reason>

## Candidate 2: …
```

Capped at 8 candidates. Beyond 8 means the worker found too many; it
should rank and surface only the top 8 by leverage-locality combined
score.

---

## Phase 2 — Present

The orchestrator surfaces the worker's list to the user *as-is* — no
editorializing, no automatic fan-out into the next phase.

User picks 1 to 3 candidates to grill. Other candidates are recorded in
the auditor's findings index with status:`open` so they don't get lost.

If the user picks zero, the skill exits cleanly. The list itself is
valuable; "we looked, and here's what we saw" is a complete output.

---

## Phase 3 — Grill (per chosen candidate)

This is where interface design happens. For each candidate the user
picked:

1. **State the module** in canonical vocabulary. What is it? What's
   its public interface? What's the seam?
2. **Run the deletion test out loud.** Walk through what callers would
   do without it. Confirm pass/fail.
3. **Identify dependencies.** Use the `DEEPENING.md` taxonomy
   (in-process / local-substitutable / remote-owned / true-external).
   Ports only for true-external. Two-adapter rule applies.
4. **Design the interface.** If it's a non-trivial decision, invoke
   the `design-twice` skill — fan out 3 parallel workers with different
   constraint shapes, then synthesize.
5. **Record decisions inline.**
   - New domain terms → append to `docs/glossary.md` (or `CONTEXT.md`).
   - Load-bearing rejection ("we considered X and rejected it because
     Y") → propose a new ADR under `docs/decisions/`.
   - Interface signature → record in the affected module's
     `AGENTS.md` or in `MODULE_MAP.md`.

**Do NOT write the implementation in this phase.** Phase 3's output is
the *contract*. Implementation is a separate dispatched task that
references the contract.

---

## Layered tests rule

When grilling reveals that the existing implementation has tests that
poke at internals (Phase 3 step 1 will surface these), **replace, don't
layer**. Adding new tests at the new interface AND keeping the old
internal tests is a code smell — it reports that the new interface is
the wrong shape OR the old tests were never meaningful. Decide which.

This is one of the few places we delete tests deliberately.

---

## When to use this skill

- **User explicitly asks** ("improve architecture", "deslop", "find
  shallow modules", "review the codebase", "what should I refactor?")
- **Fix-plan has accumulated** structural findings (file-too-large,
  too-deep) and a sweep is overdue
- **A new feature touches multiple modules** and there's no obvious
  home — the right discussion is "where should this live?", not "let
  me just create another module"

When NOT to use:

- The user wants a specific bug fixed → use `test-first` instead.
- The user wants a specific refactor done → just dispatch a worker
  with a clear brief; don't over-engineer the design conversation.
- The codebase is genuinely small (<10k LOC) — overhead is too high.

---

## Provenance

Adapted from Matt Pocock's
`improve-codebase-architecture/SKILL.md` (MIT). Local extensions:

- Phase 1 dispatches a *read-only* worker rather than a generic
  Explore subagent (our harness has the right primitive).
- The "auditor's findings index" integration so unchosen candidates
  are persisted for later review.
- Glossary + ADR side-effects use our existing `docs/glossary.md` /
  `docs/decisions/` conventions, not Matt's `CONTEXT.md`.
