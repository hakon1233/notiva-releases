---
name: design-twice
description: "When the user says \"design this twice\", \"fan out the design\", \"give me 3 options\", \"let's compare designs\", runs `/design-twice`, or is about to commit to a non-trivial interface used in many call sites: invoke `Skill('design-twice')` BEFORE writing the interface — it dispatches 3 parallel read-only workers with different constraints and returns one opinionated synthesis."
last_updated: 2026-04-30
---

# Design It Twice — parallel sub-agent fan-out

**Read `module-map/LANGUAGE.md` first** for the canonical vocabulary,
and `improve-architecture/INTERFACE-DESIGN.md` for the full version of
this pattern as it appears inside an architecture review.

This skill is the lightweight, one-shot version: dispatch 3 parallel
read-only workers, get 3 different interface shapes, synthesize one.
Use it when the cost of getting an interface wrong is high but you're
not in the middle of a full architecture review.

## When to use

- Designing a new module that will be called from 5+ sites.
- Designing the public interface for code that crosses a Bucket-3 or
  Bucket-4 dependency boundary (per `DEEPENING.md`).
- A senior reviewer would say "depends on the callers" — meaning the
  shape depends on facts that aren't crisp yet.
- The user explicitly says "let's see options" or "design it twice".

When NOT to use:
- The interface is mechanical / obvious / one-line.
- You're inside a bug fix. Bug fixes never extend the interface.
- The dispatch budget is tight (this fans out 3 workers — costs ~3×
  the dispatch overhead of a single design).

## The fan-out

3 parallel read-only workers, each with a different constraint:

| Worker | Constraint | What it optimizes |
|--------|-----------|-------------------|
| A | **Minimize interface** | Leverage — small surface, caller composes anything else |
| B | **Maximize flexibility** | Future-proofing — caller controls every knob |
| C | **Optimize common path** | Locality + caller ergonomics — common case is one line |

Optional Worker D (Bucket-3/Bucket-4 only): **Ports and adapters** —
forces the design through a port interface with two adapters and
surfaces what changes.

### Worker brief (verbatim, parameterize <module> + <constraint>)

```
Design the interface for <module>. Constraint: <A | B | C | D>.

Output exactly this shape, nothing else:

# <module> — <constraint> design

## Interface
<full interface — signatures + invariants + ordering + error modes
+ config + perf shape, per module-map/LANGUAGE.md>

## Representative call sites
1. <one realistic call>
2. <another realistic call>
3. <a third>

## Hidden complexity
<what the module swallows that the caller doesn't see>

## Adapters implied
<list — at minimum: in-memory test, production. If you propose a
port, name the second real adapter that justifies it>

## Tradeoffs
<what's worse about this design than the obvious one-pager you'd
write without the constraint>

## Deletion-test verdict
<pass / fail — if fail, this whole design is invalid>
```

Read-only is required (`dispatch_worker --readOnly true`). Workers
don't write code; they propose interfaces.

## Synthesis (the orchestrator does this)

After all 3 (or 4) workers report back:

1. Read each output as-is.
2. Reject any whose deletion-test verdict is "fail".
3. Pick the recommendation:
   - Often a hybrid — Worker C's common-path ergonomics + Worker A's
     interface minimalism, or Worker B's flexibility with Worker D's
     port boundary.
   - Sometimes Worker C wins outright (when the module has one
     dominant use case).
   - Rarely Worker B wins (we don't ship speculative flexibility).
4. Write the synthesis as a single Markdown block:

```markdown
# Design — <module>

## Recommended shape
<one paragraph or interface block>

## Why
- Vs Worker A (minimize): <what we give up>
- Vs Worker B (flexibility): <what we don't future-proof for>
- Vs Worker C (common path): <where the common path differs>

## What's still open
<missing facts, deferred decisions>

## Decision
<accept | revise (how) | reject (why)>
```

5. Surface to the user. They accept, revise, or reject.

## Recording the decision

When the user accepts:

- **Glossary** — append any new domain terms to `docs/glossary.md`.
- **ADR** — if the decision rejects a load-bearing alternative
  (commonly the "we considered the port and rejected it because…"
  case), write `docs/decisions/NNNN-<title>.md`. Link the 3 worker
  outputs as "considered alternatives".
- **Module map** — record the interface signature + invariants in
  the module's `AGENTS.md` or `MODULE_MAP.md`.
- **Implementation** — a separate dispatched task references the ADR.
  Don't merge interface design and implementation in one worker.

## Anti-patterns

- **Surveying instead of choosing.** "Here are three options, you
  pick" is not a synthesis. The orchestrator's job is to *recommend*.
- **More workers ≠ better design.** 7-worker fan-outs produce variance,
  not insight. Three constraints map to three real design axes;
  beyond that you're inviting noise.
- **Designing without the deletion test.** Every worker output must
  include the verdict. If they all fail, the module shouldn't exist.
- **Implementation creep.** Workers are read-only. If a worker writes
  code, the synthesis goes off-rails.

## Provenance

Adapted from Matt Pocock's
`improve-codebase-architecture/INTERFACE-DESIGN.md` (MIT). The
constraint shape (A/B/C/D), the synthesis discipline, and the read-
only worker dispatch are local — the upstream skill is part of the
larger architecture-review flow; this is the standalone primitive.
