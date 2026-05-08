# Interface Design — design it twice

When `improve-architecture` Phase 3 reaches the interface-design step
and the decision is non-trivial, **design it twice (or more).** Don't
commit to the first interface that looks plausible.

This skill describes the *full* design-twice flow as it applies inside
an architecture review. For the lighter standalone primitive (one-shot
parallel sub-agent fan-out for a specific interface decision outside an
architecture review), use `design-twice/SKILL.md` instead.

## When to use

- The interface has more than one obvious shape and they make different
  callers pay different costs.
- A senior reviewer would say "it depends on how the callers use it" —
  meaning the design depends on facts you don't yet have crisply.
- The cost of getting the interface wrong is high (it'll appear in
  many call sites, or it crosses a Bucket-3 / Bucket-4 boundary per
  `DEEPENING.md`).

When NOT to use:
- The interface is mechanical — one obvious signature, callers
  uncontroversial. Just write it.
- You're inside a bug fix. Bug fixes never extend the interface; they
  push the guard to the invariant (see `test-first/SKILL.md` Step 2).

## The fan-out

Dispatch **3 parallel workers**, each read-only, each with a different
constraint shape. Constraints are not random — they map to known design
axes:

| Worker | Constraint | What it optimizes |
|--------|-----------|-------------------|
| A | **Minimize the interface.** Smallest possible surface; caller pays for any non-default behavior with explicit options. | Leverage |
| B | **Maximize flexibility.** Caller controls every knob; the module makes few assumptions. | Future-proofing |
| C | **Optimize the common path.** The common-case caller writes one line; uncommon callers compose adapters. | Locality + caller ergonomics |

(Optional 4th worker, when the dependency is Bucket 3 or 4: **Ports
and adapters.** Force the design through a `Port` interface with two
adapters, and surface what changes.)

Each worker's brief is identical except for the constraint:

> Design the interface for `<module name>` under the constraint:
> `<one of A/B/C above>`. Output:
>
> 1. The interface (full — signatures + invariants + ordering + error
>    modes + perf shape, per `module-map/LANGUAGE.md`).
> 2. 3 representative call sites — what does each look like?
> 3. The hidden complexity inside the module (what does the module
>    swallow that the caller doesn't see?).
> 4. The adapters this design implies (in-memory test + production —
>    minimum). If you propose a port, name the second real adapter.
> 5. Tradeoffs: what's worse about this design than the obvious
>    one-pager you'd write without the constraint?

Workers run in parallel via worktrees (the harness supports this; see
`dispatch-worker.sh --readOnly`).

## Synthesis

The orchestrator reads all three (or four) outputs and writes ONE
combined recommendation:

```markdown
# Interface design — <module>

## Recommended shape
<one paragraph — typically a hybrid of the three workers' outputs, or
one of them taken outright>

## Why
- Vs Worker A (minimize): … (what the recommendation gives up)
- Vs Worker B (flexibility): … (what we're not future-proofing for)
- Vs Worker C (common path): … (where the common path differs)

## What's still open
<one paragraph if any decision is still pending — typically because
a fact is missing (e.g. "we don't know if there will be a 2nd vendor
adapter; defer the port until we do")>

## Decision
<accept | revise (and how) | reject (and why)>
```

The recommendation is **opinionated**. "Here are three options, you
pick" is a Phase 2 output (candidate ranking); Phase 3 is supposed to
narrow.

## Recording the decision

Once the user accepts the recommendation:

1. **Glossary** — append any new domain terms to `docs/glossary.md`.
2. **ADR** — write a new `docs/decisions/NNNN-<title>.md` if the
   decision rejects a load-bearing alternative. Link the rejected
   workers' outputs in the ADR's "Considered alternatives" section.
3. **Module map** — update the affected module's `AGENTS.md` or the
   project `MODULE_MAP.md` with the new interface signature + invariants.
4. **Findings index** — if this candidate came from `/fix-plan`, mark
   the corresponding finding `status:fixed` with a `close_reason`
   pointing at the ADR.

Implementation is a separate dispatched task. It references the ADR.
Don't merge interface design and implementation in one worker — workers
do their best work when the interface is fixed BEFORE they start.

## What this is NOT

- Not a vote. The orchestrator/user picks; majority of workers doesn't
  win automatically.
- Not a survey. We don't dispatch 7 workers "to see what the design
  space looks like." Three constraints, sometimes four — that's it.
- Not a substitute for taste. Workers under constraint produce
  predictable output; the human/orchestrator's job is to pick the
  *right* tradeoff for this codebase, this team, this moment.

## Provenance

Adapted from Matt Pocock's
`improve-codebase-architecture/INTERFACE-DESIGN.md` (MIT). Local
extensions: the "Worker D = ports & adapters" branch is specific to
our `DEEPENING.md` taxonomy; the worker-dispatch mechanics are ours.
