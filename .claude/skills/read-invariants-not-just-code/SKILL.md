---
name: read-invariants-not-just-code
description: "When auditing a file (especially one touched by a recent change) or before declaring a file 'looks clean' or 'no defects': invoke `Skill('read-invariants-not-just-code')`. File-level JSDoc, top-of-file documentation, and inline 'always / must / never / should' assertions encode invariants that drive-by edits commonly violate. The code below a JSDoc comment may have drifted from what the comment promises — the bug is the drift."
---

# Read Invariants, Not Just Code

The most reliable comments in a codebase say a thing **must** be true.
Drive-by edits leave the assertion in place while breaking the code below
it. Code-only review misses these; **a grep-first pass catches them**.

## Do these 3 things, then move on

### 1. One grep for assertion words across the whole audit surface

```
grep -rnE '\b(always|never|must|should|invariant|leftmost|rightmost|first|last|only|exactly|guaranteed|cannot|in order|sorted|ascending|descending)\b' src/ server/ 2>/dev/null
```

(Adjust `src/ server/` to whatever this repo's source roots are.)

This is the cheapest, highest-yield invariant-finder. Each hit is a
candidate to investigate.

### 2. For each candidate, read the surrounding 20 lines

The question is always: **"the comment says X — does the code below
honour X right now?"**

- If yes — invariant holds, move on.
- If no — that's the bug. The assertion is the spec; the code is wrong.

Pay special attention to JSX text nodes — a JSDoc saying "the leftmost
tab is X" with JSX text below saying "Y" is the drift.

### 3. Cross-check docs

If `docs/system/X.md`, an ADR under `docs/decisions/`, or a README says
"X must Y" and the implementation doesn't Y — that's the bug.

## What to do when you find a violation

1. Read the assertion verbatim.
2. Grep the implementation for the counter-example.
3. Fix the implementation to honour the assertion (or, if the assertion
   is genuinely stale, flag it as a code-style question — but report the
   drift either way).

## Where invariants hide

- Top-of-file JSDoc (the `/** ... */` block before the first export).
- JSDoc on the function whose behaviour is being asserted.
- Inline `// invariant: X` comments — rare but valuable.
- Type-level constraints: `as const`, exhaustive switch comments.
- README / AGENTS.md / CLAUDE.md / ADRs that say "must / never / always."
- JSX text nodes that name a "first" / "leftmost" / "default" item.

## What this skill is NOT

- Not "read every comment." Just the assertion ones.
- Not "find typos in docs." We care about code-vs-doc disagreement.
- Not "trust comments over code." When they conflict, the conflict IS
  the finding — investigate before assuming either is right.
