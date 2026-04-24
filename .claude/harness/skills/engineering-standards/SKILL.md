---
name: engineering-standards
description: Use PROACTIVELY before adding a file, writing a new abstraction, committing, fixing a bug, or claiming work is done. MUST BE USED when the user says "build this", "add this", "fix", "refactor", "clean up", or "ship it". Defines the six stop rules that separate stable, first-run-correct work from quick-fix rot.
last_updated: 2026-04-20
---

# Engineering Standards

Six stop rules. Each has a concrete trigger. If you can't answer "yes" to the question, stop and re-plan.

## The six rules

### 1. Simplicity before complexity

**Trigger**: you're about to add a new file, class, abstraction, helper, or layer.

**Question**: Does this have at least two concrete, already-existing callers or use cases? Or is it the simplest thing that solves the problem?

If no — inline it, or write the duplicate twice and extract later. Premature abstractions calcify wrong boundaries.

**Red flags that force a stop**:
- "I'll probably need this later."
- "This might be useful for other projects."
- "Let me make this more general."
- Three similar lines that you're about to extract into a one-use function.

### 2. First-run correctness

**Trigger**: you're about to commit, open a PR, or say "done."

**Question**: Did you actually *run* the feature / command / test — not just type-check it — and observe the expected result?

If no — run it. "Should work" is not evidence. Typecheck + lint + tests are necessary but not sufficient; the final check is running the thing.

**Red flags**:
- "The tests pass, so the feature works." (Tests test what you told them to, not what users do.)
- "`npm run build` succeeded, shipping it." (Build ≠ runtime correctness.)
- Claiming UI changes are done without opening the browser.

### 3. Root-cause fixes, not symptom silencing

**Trigger**: you're about to change an error handler, disable a check, catch an exception, add a retry, or write a workaround.

**Question**: Is this fix at the layer where the bug lives, or am I masking it elsewhere?

If masking — stop and find the real layer. Silenced bugs always come back, usually worse.

**Red flags**:
- Adding `try/catch` to make an error disappear without logging it.
- Lowering a threshold to make a flaky test pass.
- `// eslint-disable-next-line` without a comment saying why.
- Adding `as any` or `// @ts-ignore`.
- Adding a retry to "fix" a timing bug.
- `if (!x) return` to sidestep a case instead of handling it.

### 4. Add complexity cleanly

**Trigger**: rule #1 didn't apply — you actually need the abstraction.

**Question**: Does it have (a) a single clear purpose, (b) a named boundary, (c) a test or doc covering the new surface area, (d) a concrete reason for existing (not speculative)?

If no — defer until you can answer yes. Don't merge half-formed abstractions.

**Red flags**:
- A class with one method. (Just use the function.)
- A utility file with one helper. (Inline it.)
- An interface no one else implements. (Unneeded indirection.)
- "Helpers", "Utils", "Common" as file/module names. (Name what they do.)

### 5. Scope discipline

**Trigger**: during work, you notice something else that could be improved.

**Question**: Is this improvement inside the explicit scope I was asked to work on?

If no — note it, but don't do it. Unrequested drive-by refactors are how PRs become unreviewable.

**Red flags**:
- "While I'm here, let me also…"
- Reformatting files you didn't functionally change.
- Renaming things the user didn't ask to rename.
- Fixing a bug you discovered in a module unrelated to your task (log it; don't fix it).

### 6. Read blame before editing

**Trigger**: you're about to change a non-trivial line in a file someone else (or a past-you) wrote.

**Question**: Do I know *why* the current code is the way it is?

If no — run `git blame` on the lines you're changing, read the commit message for the most recent relevant commit. Two minutes of history reading prevents entire classes of regressions where you undo a fix someone landed for a reason that wasn't obvious from the code alone.

**What to do with the answer**: in your completion report's **Evidence** or **Noteworthy** section, cite the intent of the code you changed — "the timezone logic was added in commit `abc123` to handle an off-by-one in daylight savings; my fix preserves that intent while also correctly handling the locale case." This is the grounded-repair discipline from HAFixAgent (2025).

**Red flags**:
- Editing a chunk of code that has a recent, defensive-looking comment on top of it, without checking what the comment was guarding against.
- Changing constant values, timeouts, or thresholds without reading when and why they were set.
- Reverting conditionals that look "unnecessary" — they were usually added in response to a real bug you're about to re-introduce.

**Exception**: trivial edits (typos in comments, obvious local refactors within a function you just wrote, adding new code that doesn't touch existing logic) don't need blame. Use judgment — the rule is about *non-obvious* changes to existing code, not a ceremony for every edit.

## The checklist — run before committing

```
□ 1. No new abstraction without 2+ callers OR genuine simplicity win?
□ 2. Actually ran the feature / command / test (not just typechecked)?
□ 3. Every error is handled at the right layer — no silencing?
□ 4. Any new abstractions have a name, purpose, boundary, and test/doc?
□ 5. Scope matches what was asked — no drive-by changes?
□ 6. Read `git blame` on any non-trivial lines I changed in someone else's code?
```

If any box is empty, don't commit. Fix it or explicitly flag it to the user.

## What to do when a standard conflicts with the request

If the user asks for something that violates a standard:
- **Surface it** — "I can do it that way, but it would [specific concern]. Is that OK or should I [alternative]?"
- **Don't silently comply** — silently adding a quick-fix because the user asked is how you become the source of the rot.
- **Don't refuse** — this is the user's system. State the tradeoff, get consent, proceed.

## References

- Pair with `test-first/SKILL.md` for bugs (red-before-green catches many rule-3 violations).
- Pair with `commit/SKILL.md` for pre-commit verification (rule 2).
- `writing-skills/SKILL.md` enforces rule 1 for skill authoring.
