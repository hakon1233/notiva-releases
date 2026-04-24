---
name: test-first
description: Use PROACTIVELY for ANY bug fix, regardless of workflow. MUST BE USED when the user reports a bug, says "fix", "reproduce", "regression", "red-before-green", or when /bug-test-loop, /fix-loop, or any fix-related command runs. Canonical red-before-green discipline — reproducer file conventions, exit-code semantics (0/1/2), cross-file bug tracking, layered regression defense, BUG-NNN marker rules.
last_updated: 2026-04-24
---

> **Root-cause only.** Before fixing, read `engineering-standards` rule #3: no silencing, no `@ts-ignore`, no retries to mask timing bugs. If the simplest fix is at a different layer than the reproducer catches, fix there and update the reproducer.

# Test-First Bug-Fix Discipline

**Canonical rhythm for fixing bugs in this repo.** Other skills (`fix-loop`, `dispatch-hunter`, `bug-test-loop`) delegate here. Five questions every bug fix must answer:

1. Do I understand the bug? (Step 0)
2. Can I prove it exists today? (Step 1)
3. Can I prove the fix works? (Step 2)
4. Did I break anything else? (Step 3)
5. Will a future agent catch this if it regresses? (Steps 4–5)

If any answer is "no", the fix isn't done. **Templates + extended detail live in `docs/system/test-first-reference.md`.**

## Before you start

Ensure `docs/sessions/$(date +%Y-%m-%d).md` has a session header. Log continuously.

## Step 0 — Classify

Answer all four in the session log. If you can't, you don't understand the bug yet.

1. **Symptom** — plain-language observation, one sentence. That's the invariant you're protecting.
2. **Classification** — one of:
   - **CONFIRMED** (3/3 from clean state, contradicts spec)
   - **TIMING_RACE** (reproducible under specific race)
   - **STATE_DEPENDENT** (needs pre-existing state in reproducer)
   - **SPEC_GAP** (spec and code agree; defer to user)
   - **FLAKY** (2/3 or worse, no clear gap — log but don't fix; 3 flakes in 14d → rewrite the test)
   - **MATRIX_BUG** (test is wrong; fix test, not code)
3. **Affected workflow** — which user-facing flow (dispatch, chat, planner, ...).
4. **Boundaries** — fan-out (what else could this touch?) + blast radius.

## Step 0.5 — Localize (file → function → edit-site)

Three tiers. Spend ≤ 5 min on each before moving on.

- **Tier 1 (file)**: grep for the symptom string + likely module path. Read top of the file + its CLAUDE.md / AGENTS.md if present.
- **Tier 2 (function)**: `git blame` the lines nearest the symptom; read the function that owns them + its tests.
- **Tier 3 (edit-site)**: identify the exact line(s) you'll change. If you can't, write the reproducer anyway — it'll pin the site.

**Red flags**: changing constants without reading why; editing a `defensive` block without reading its commit message; "while I'm here" edits outside the localized site.

**Fast-path carve-out**: trivial typo fixes, single-site edits in code you just wrote, comment changes — skip Step 0.5.

## Step 1 — Reproduce (Red)

Pick the cheapest tier that captures the bug:

| Tier | Cost | Use when |
|------|-----:|----------|
| Static grep | <1s | Fix is detectable by "code does/doesn't contain X" |
| Unit test | <1s | Bug lives in a pure function / isolated method |
| Live behavioral | <60s | Bug only appears when code runs against live services |
| Manual UI walkthrough | >60s | Last resort — rendering / interaction-only |

**Upgrade only when necessary.** Ask "if this can't be a static grep, why?" — the answer exposes which axis (state, timing, concurrency, IO) forces the escalation.

**Persist the reproducer as a file.** Path: `.claude/test-runs/reproducers/<bug-id>.sh` (bash) or a failing test in `src/lib/__tests__/` (vitest). Commit it alongside the fix.

**Exit-code semantics (hard rule):** `0` = fixed, `1` = bug present, `2` = pre-condition failed (e.g. PTY server unreachable). The `2` case is critical — without it reproducers silently pass when their environment is broken.

Full reproducer file skeleton + examples: `docs/system/test-first-reference.md`.

Run it. Confirm it exits 1 (or the test fails). **If it doesn't fail first, the reproducer doesn't prove what you think it does.**

## Step 2 — Fix (Green)

- **Push the guard to the invariant.** If the bug is "dispatch dot stays orange", the fix belongs where the dot's state is computed, not at the UI layer that reads it.
- **Minimal change.** One logical edit. If you find yourself touching 5 files, Step 0.5 wasn't deep enough.
- **Run the reproducer.** Must exit 0.
- **Mutation check.** Break the fix on purpose (comment out the one critical line). Does the reproducer go back to exit 1? If not, the reproducer doesn't actually depend on the fix — rewrite it.

## Step 3 — Verify no regressions (layered defense)

Run all five layers. Each catches what the others miss:

1. **TypeScript**: `npm run typecheck`
2. **Unit tests** for the changed code: `npx vitest run <path>`
3. **All existing reproducers**: `for f in .claude/test-runs/reproducers/*.sh; do bash "$f"; done` — every past bug IS a test
4. **Grep markers**: if the bug was structural, add a `BUG-NNN:` marker comment at the fix site + a `scripts/check-bug-markers.sh` entry
5. **Restart decision tree**: if the fix changes runtime state (hooks, daemons, env vars), decide explicitly whether to restart. Default: yes.

Full layer detail + restart tree in `docs/system/test-first-reference.md`.

## Step 4 — Document (the four bug files)

Every bug lives in **four places** so different views stay complete:

1. `.claude/bugs/workflows/<workflow>.md` — authoritative entry
2. `.claude/bugs/agent-reported.md` OR `.claude/bugs/user-reported.md` — mirror for the "all reports" view
3. `.claude/bugs/resolved.md` — archive on fix with **Resolved:** line
4. `.claude/bugs/workflows/<other>.md` — if the bug spans workflows (rare)

Bug-file entry format (Status / Classification / Reporter / Reproducer / Symptom / Root cause / Fix / Regression guards): full template in `docs/system/test-first-reference.md`.

## Step 5 — Grep marker + workflow regression check

- Add a `BUG-NNN:` comment at the fix site so future grep finds it.
- Run the workflow's full test suite if one exists (`npm run test:<workflow>` or equivalent).
- Add to `scripts/check-bug-markers.sh` if the bug is structural.

## Step 6 — Commit

**Default: one bug per commit.** Conventional Commits: `fix(scope): short description (BUG-NNN)`. Body explains root cause + layer of the fix in 2–3 sentences. Reference the reproducer path.

Push to the deploy branch. Verify autopull took it.

## Anti-patterns (refuse these)

- Flaky reproducer (2/3 or worse) — rewrite, don't ship
- Reproducer that doesn't exit 1 at bug-present — it proves nothing
- `@ts-ignore` / `as any` to silence the symptom — breaks root-cause rule
- Retry loop to mask timing — hides the race
- Skipping Step 3 because "my change is small" — every fix runs the layered defense
- Documenting the bug AFTER the commit — it's lost context by then

Extended anti-pattern list: `docs/system/test-first-reference.md`.

## Quick reference (20-second version)

1. Classify (symptom, type, workflow, boundaries)
2. Localize (file → function → edit-site)
3. Reproducer file that exits 1 now
4. Minimal root-cause fix; reproducer exits 0
5. Mutation check; 5 regression layers
6. Four bug files; commit one bug per commit

## Cross-references

- `engineering-standards/SKILL.md` rule #3 — root-cause only
- `commit/SKILL.md` — commit message + atomic-unit rule
- `fix-loop/SKILL.md` / `dispatch-hunter/SKILL.md` / `bug-test-loop/SKILL.md` — workflow-scoped loops that delegate here
- `docs/system/test-first-reference.md` — templates, extended anti-patterns, full layer detail
