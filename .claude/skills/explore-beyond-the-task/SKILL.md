---
name: explore-beyond-the-task
description: "When the user's prompt is open-ended exploration — 'review this', 'audit', 'find what's wrong', 'check the recent feature', 'investigate', 'look around' — and especially after you've already found and fixed ONE issue: invoke `Skill('explore-beyond-the-task')` and follow its enumeration discipline. Open-ended reviews almost always surface more than one finding; stopping after the first fix is the most common failure mode."
---

# Explore Beyond the Task

When the prompt is genuinely open-ended (audit, review, investigate),
you must NOT scope-discipline yourself into the narrowest reading of
"the task". One bug fixed is rarely "the task" — it's the first bug.

This sits *next to* the engineering-standards "scope discipline" rule,
not against it. Scope discipline applies when the user asks for a
specific thing. When the user asks for review, you owe them coverage.

## The rule

After each fix in an open-ended audit context, before declaring done:

1. **Don't conclude after one fix.** Non-trivial codebases almost
   always have more than one issue. Treat one finding as evidence that
   more probably exist in the same neighbourhood.

2. **Read the entry-point configs FIRST.** Before code review, open
   `package.json` / `pyproject.toml` / `Cargo.toml` / `next.config.*`
   / `vite.config.*` / Dockerfile / Makefile / equivalent. Defaults,
   ports, scripts, and infrastructure conventions live there and are
   among the most common bug sites — a bug in `package.json`'s `dev`
   script (wrong port, wrong flag, wrong path) is invisible to source
   review but breaks the running app immediately.

3. **Re-canvas the surface.** Verify you actually exercised every
   major page/feature/route, not just the ones around the bug you
   already fixed. If a dev server is running, fetch the principal
   routes and look at the rendered HTML — broken styling, wrong
   labels, missing regions, dead links jump out from HTML alone.

4. **Read recently-modified files end-to-end, including JSDoc.**
   Top-of-file comments and JSDoc on exported symbols are the most
   reliable place to find documented invariants ("X is always Y",
   "must be leftmost", "do not call from Z"). Grep the file's own
   assertions against the actual code below them. Drive-by edits
   commonly violate the JSDoc above the function they touched.

5. **Cross-check documented invariants more broadly.** Search the
   tree for `README`, `INVARIANTS`, `AGENTS.md`, ADRs (`docs/decisions/`)
   for "should never", "always", "must", "contract" — and verify the
   code still honours them.

6. **Use the running app actively.** `curl <url>` against the dev
   server, parse the HTML, check what's actually being served. If
   you have `mcp__claude-in-chrome__*` tools, browse pages and read
   the rendered output and console. Don't rely on code review alone
   to verify UI behaviour.

## When you ARE allowed to stop

You can declare an open-ended review done when:

- You've enumerated and exercised every major route / page / feature
  in the surface area you were asked to review.
- You've read every recently-modified file in the relevant subtree.
- You've grep'd for the obvious invariant violations.
- You've spent a reasonable enumeration budget (30+ tool calls)
  without finding additional issues.

Phrases that are NOT sufficient reason to stop:

- "Reviewed clean for seeded defects" — unless you've actually
  exercised the live app, this is a guess.
- "No other obvious bugs" — your guess about obviousness is exactly
  the heuristic that misses subtle bugs.
- "Out of time for now" — say so in the report, but don't pretend
  you've finished the audit.

## Why this skill exists

Audited from a 2026-05-13 Opus 4.7 bug-hunt benchmark run where the
worker fixed 1 of 6 deliberately-injected bugs, then stopped saying
"the other recently-touched files reviewed clean for seeded defects".
It had reviewed the code but not actually exercised the running app.
The other 5 bugs were all visible-in-browser symptoms (wrong colors,
broken sidebar link, mis-labelled state, renamed tab, wrong default
port). The fix is not "look harder at the code" — it's a discipline
of treating the running app as primary evidence in open-ended review.
