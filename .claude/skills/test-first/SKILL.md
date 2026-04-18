---
name: test-first
description: Use PROACTIVELY for ANY bug fix, regardless of workflow. MUST BE USED when the user reports a bug, says "fix", "reproduce", "regression", "red-before-green", or when /bug-test-loop, /fix-loop, or any fix-related command runs. Canonical red-before-green discipline — reproducer file conventions, exit-code semantics (0/1/2), cross-file bug tracking, layered regression defense, BUG-NNN marker rules.
last_updated: 2026-04-18
---

# Test-First Bug-Fix Discipline

**This is the canonical rhythm for fixing bugs in this repo.** Other skills (`fix-loop`, `dispatch-hunter`, `bug-test-loop`) delegate to this one for the bug-fix rhythm and only layer their own specifics on top. If the rhythm you're reading somewhere else contradicts this file, this file wins — raise the contradiction as something to fix.

The discipline exists to answer five questions every bug fix needs to answer:
1. Do I actually understand the bug? (Step 0)
2. Can I prove it exists today? (Step 1)
3. Can I prove the fix actually fixes it? (Step 2)
4. Did I break anything else? (Step 3)
5. Will a future me / agent catch this if it regresses? (Steps 4-5)

If any of those is "no", the fix isn't done.

## Before you start

1. Check if `docs/sessions/$(date +%Y-%m-%d).md` exists
2. If not, create it with a session header: `## Session — HH:MM` + `**Objective:** one-line summary`
3. Log your work continuously as you go — do not wait until the session to end

## Step 0 — Classify before you write anything

Before you open a single file, answer these four questions out loud or in the session log. If you can't answer all four, you don't understand the bug yet — go read the symptom again, reproduce it manually, or ask the user.

1. **What does the user/agent observe?** Plain language, one sentence. Not "the `approvedBy` field is wrong" — more like "the dispatch dot stays orange after I click approve in the UI". The symptom is the invariant you're protecting.

2. **What's the classification?** One of:
   - **CONFIRMED** — reproducible 3/3 from a clean state, contradicts spec, clean reproducer exists
   - **TIMING_RACE** — reproducible under a specific race condition, not reliably 2/3 from cold. Clear code gap, needs timing control in the reproducer.
   - **STATE_DEPENDENT** — only reproducible with specific pre-existing state (stale rows, missing artifacts, leftover caches). Needs state setup in the reproducer.
   - **SPEC_GAP** — reproducible, but spec and code agree; unclear if the current behavior is correct. Defer to the user.
   - **FLAKY** — reproducible 2/3 or worse with no clear code gap. Log but don't fix without more info.
   - **MATRIX_BUG** — the test/reproducer is wrong about the expected outcome; the system is right. Fix the test, don't touch the code.
   - **NEEDS_INVESTIGATION** — observed but the bisect wasn't clean. Log as open, don't treat as confirmed.
   - **NOT_A_BUG** — behavior is as specified. Close as won't-fix.

   The classification dictates the reproducer shape. TIMING_RACE needs timing control. STATE_DEPENDENT needs pre-state setup. CONFIRMED can be as simple as a static grep.

3. **Why wasn't this caught earlier?** One sentence. "The terminal-scrape check didn't distinguish the ready prompt from a numbered-option chooser." Forces you to identify the detection gap, not just the symptom. This sentence lands in the bug entry later — don't skip it.

4. **What's the blast radius of the fix?** One sentence. "Files/functions that could be affected by the change I'm about to make." Grep for callers/imports/exports. Tell yourself what you'll re-verify after the change. Without this, scope creep and silent regressions sneak in.

## Step 1 — Reproduce (Red)

### Pick the cheapest reproducer tier

Always prefer the cheapest tier that can actually capture the bug:

| Tier | Cost | Use when |
|------|-----:|----------|
| **Static grep** | < 1s | Fix is detectable by "code does/doesn't contain X". Example: a hardcoded truncation that was removed, a marker comment added, a helper function introduced. |
| **Unit test** | < 1s | Bug lives inside a pure function or a class method that can be tested in isolation with mocks. |
| **Live behavioral** | < 60s | Bug only appears when code runs against a live PTY server / Supabase / tmux session / etc. Timing, state, IPC. |
| **Manual UI walkthrough** | > 60s | No other option works — e.g. visual rendering bug, interaction-only behavior. Last resort. |

**Upgrade only when necessary.** If you can write a static grep that proves the fix is in place, that's better than a unit test. If a unit test covers it, don't write a live behavioral reproducer. The cheapest tier runs on every change without friction, which is exactly what you want for long-term regression coverage.

The question "**if this can't be a static grep, why?**" forces you to identify which axis of the bug requires a live run — state, timing, concurrency, IO, UI. Sometimes answering it reveals the bug is simpler than you thought and a grep actually works.

### Persist the reproducer as a file

**Rule:** the reproducer is a committed file on disk, not a thought in your head.

- **Path:** `.claude/test-runs/reproducers/<bug-id>.sh` (bash) or a failing test added to `src/lib/__tests__/` (vitest).
- **Commit it alongside the fix.** The reproducer lives in the repo forever. Future agents run it as part of the layered regression defense (see Step 3).

### Exit-code semantics (hard rule)

Bash reproducers use exactly these codes:

- **`0` = fix is in place** (bug is gone, everything verified)
- **`1` = bug is present** (the reproducer detected the failure it's guarding against)
- **`2` = pre-condition/environment wrong** (test can't prove anything either way — e.g. PTY server not reachable, Supabase unreachable, test project directory missing)

The `2` case is critical. Without it, reproducers get false greens when the starting state is wrong. Always check pre-conditions explicitly and exit 2 if they're not met.

### File structure skeleton

Every bash reproducer follows this shape. Copy from `.claude/test-runs/reproducers/bug-034-codex-update-prompt.sh` or `bug-035-duplicate-permission-prompts.sh` for static checks, or `dispatch-cache-stale-after-ui-approve.sh` for live behavioral checks.

```bash
#!/usr/bin/env bash
# Reproducer: [BUG-NNN] short title
#
# What it tests: 2-3 sentences on the symptom.
# Exit code: 0 if fixed, 1 if bug present, 2 if pre-condition fails.

set -euo pipefail

cd "$(dirname "$0")/../../.."

# Load env only if the reproducer needs Supabase / PTY / etc.
# (Not needed for static grep reproducers.)
set -a; . ./.env.local; set +a

NAME="<test-session-prefix>-$(date +%s)"
# Per-bug parameters here

cleanup() {
  # Always clean up state the reproducer created.
  # For live reproducers: delete Supabase rows, kill tmux sessions, rm temp files.
}
trap cleanup EXIT

cleanup
sleep 1

# === PRE-CONDITION CHECK ===
# Verify required state; exit 2 if not met.
if ! <check>; then
  echo "PRE-CONDITION FAILED: <why>" >&2
  exit 2
fi

# === TEST BODY ===
# Either: grep the source for markers that MUST be present / absent,
# or: run the live flow and observe the outcome.

# === VERIFICATION ===
if [ "$RESULT" = "expected" ]; then
  echo "PASS — <one-line success message>"
  exit 0
fi
echo "FAIL — <one-line failure message>" >&2
exit 1
```

**Key discipline:**

- **Idempotent** — safe to run multiple times. Cleanup at start AND at exit via `trap`.
- **Self-contained** — no manual setup steps outside the reproducer.
- **Clear pass/fail output** — exactly one `PASS — ...` or `FAIL — ...` line so the caller can parse it.
- **Pre-condition check with `exit 2`** — guards against false greens when the starting state is wrong. This is the defensive move that caught the BUG-032 false-green attempt.

### Run it. Confirm red.

Before writing a single line of fix code, run the reproducer and verify it exits 1. If it doesn't:

- **Exits 0 (green already):** your reproducer isn't testing what you think it is, OR you misread the bug. Re-read the symptom, reproduce it manually, fix the reproducer.
- **Exits 2 (pre-condition failed):** fix the environment or the pre-condition check, then re-run.
- **Exits with some other code / crashes:** the reproducer has a bug of its own. Fix it before proceeding.

**Do not start fixing code with a green or ambiguous reproducer.** The entire value of this discipline evaporates if you skip this step.

## Step 2 — Fix (Green)

### "Push the guard to the invariant"

Fix at the narrowest point where the rule must hold, not at every call site.

**Example.** BUG-035 had 6 different code paths calling `notifyOrchestratorOfPrompt` without dedup. The wrong fix is to add a dedup guard to each of the 6 call sites. The right fix is to move the guard *inside* `notifyOrchestratorOfPrompt` itself. One change, one place, catches the current 6 callers AND any future 7th caller that gets added without the author knowing about the invariant.

The general rule: **the fix should live as close to the invariant as possible**. If you're about to copy-paste the same guard into multiple places, that's a signal to push it down to a shared entry point.

### Minimal change

No refactoring. No "while I'm here" cleanup. No extracting helpers that aren't strictly necessary for the fix. The smallest diff that flips the reproducer to green is the right one.

The rationale: bigger diffs have bigger blast radius. Bigger blast radius means more surface area for silent regressions. Minimal changes are easier to review, easier to revert, and easier to reason about.

If you notice something that should be refactored — write it down in the session log as follow-up work, not as part of this fix.

### Run the reproducer. Confirm green.

Exit 0 is the only acceptable outcome. If it's still red, your fix is wrong — revert it, re-read the bug, and think again. Do not "almost fix" the bug — a partial fix now becomes a hard-to-diagnose regression later.

### Mutation check

**This step catches the most dangerous failure mode: a reproducer that tests the wrong thing.**

After the reproducer flips to green, revert one line of the fix (comment it out or change a critical character), re-run the reproducer, and verify it goes red again. Then restore the fix.

If the mutated-fix reproducer doesn't go red, the reproducer wasn't actually detecting the bug — it was only detecting some unrelated side effect of your change. Rewrite the reproducer so it actually fails in the mutated state, then re-verify the real fix.

This is cheap (< 30s) and catches a class of mistake that otherwise lands in production undetected.

## Step 3 — Verify no regressions (the layered defense)

Run these in order. Every layer must be green before the fix is considered done.

### Layer 1 — TypeScript
```bash
npx tsc --noEmit
```
Catches interface-wide regressions like a missing field after a rename, a method signature mismatch, or a removed export. Fast (a few seconds).

### Layer 2 — Unit tests for the changed code
```bash
npx vitest run <path to nearest __tests__ file>
```
Start with the test file nearest the code you changed, then broaden to anything that imports it. Fast (< 1s for typical suites).

### Layer 3 — ALL existing reproducers

**The critical layer.** Walk through every file in `.claude/test-runs/reproducers/*.sh` and run each one. Even if your change seems unrelated to their bug, run them.

```bash
for f in .claude/test-runs/reproducers/*.sh; do
  echo "--- $(basename $f) ---"
  bash "$f" || echo "!!! $(basename $f) FAILED !!!"
done
```

If any flips red, your fix collided with another. Revert, investigate, and either adjust your fix or fix the collision. **This layer is the safety net against cross-bug regressions** — the one that catches "I fixed BUG-N but broke BUG-M in a way I didn't notice".

Observed in practice: has prevented multiple cross-file collisions in this session. Not optional.

### Layer 4 — Grep-marker sweep

Every previously-fixed bug has a `BUG-NNN` marker embedded in source (see Step 5). Run the per-workflow grep checks from `.claude/workflows.md` Test actions lines:

```bash
grep -q "BUG-011" server/execution-monitor.ts && echo "BUG-011 OK"
grep -q "BUG-031" server/execution-monitor.ts && echo "BUG-031 OK"
grep -q "BUG-034" server/lib/agent-terminal-detection.ts && echo "BUG-034 OK"
# ... etc
```

Any missing marker is a silent regression — the fix got deleted or commented out. Investigate before continuing.

### Layer 5 — Restart decision tree (explicit, not from memory)

After every change, decide explicitly which processes need to be restarted. Do not rely on memory — ask yourself every time:

- **Touched `server/*`?** → **restart PTY:**
  ```bash
  pgrep -f "tsx server/pty-server.ts" | xargs -I {} sudo kill -9 {}
  # launchd respawns automatically — verify new PID with:
  pgrep -f "tsx server/pty-server.ts" | xargs -I {} ps -p {} -o pid,lstart
  ```
  The `ttm-service.sh restart pty` command is known-unreliable; `kill -9` + launchd respawn is the safe path.

- **Touched `src/*` client code?** → **rebuild + restart Next.js:**
  The production web server (`npm run start`) loads the `.next/` bundle at startup and does NOT pick up rebuilds automatically. After a client-side fix, autopull builds but nothing serves the new bundle until the web process restarts:
  ```bash
  pgrep -f "next-server" | xargs -I {} sudo kill -9 {}
  ```
  Then hard-refresh the browser (Cmd+Shift+R) to bust any cached JS.

- **Touched only bash scripts?** → no restart needed. Scripts are read from disk per invocation.

- **Touched only `.claude/*` or `docs/*`?** → no restart needed.

**This step has been missed multiple times in past sessions.** A fix that compiles, passes tests, and reports green in the reproducer can still be invisible in production if the running process is serving an older bundle.

Do not mark the bug fixed until every layer in this step is green.

## Step 4 — Document (the four bug files)

Every bug lives in exactly **two** canonical places plus a cross-reference and an archive. The four-file flow:

### File 1 — `.claude/bugs/workflows/<workflow>.md` (authoritative entry)

The full details. Template to copy-paste:

```markdown
### [BUG-NNN] One-line title
- **Status:** fixed (YYYY-MM-DD) | needs-user-input | open
- **Severity:** critical | major | minor | warning | info
- **Classification:** CONFIRMED | TIMING_RACE | STATE_DEPENDENT | ...
- **Found:** YYYY-MM-DD by [agent|user] (context/session name)
- **Description:** 2-4 sentences on the symptom, the root cause, and the user-facing impact. Start with what the user observes.
- **Root cause:** one sentence. (Why the old code was wrong.)
- **Why it wasn't caught earlier:** one sentence. (Detection gap.)
- **Fix:** what changed, with file:line citations. Summarize the mechanism.
- **Files touched:** bullet list.
- **Reproducer:** `.claude/test-runs/reproducers/bug-NNN.sh` — short description of what it checks.
- **Verified:** red-to-green results, unit test count, regression sweep summary.
- **Regression check:** exact mechanically-runnable bash one-liner.
```

### File 2 — `.claude/bugs/agent-reported.md` OR `.claude/bugs/user-reported.md`

Thin cross-reference (5-8 lines) with `One-liner:` + `Full entry:` link. Which file depends on who found it. Template:

```markdown
### [BUG-NNN] One-line title
- **Status:** fixed (YYYY-MM-DD)
- **Severity:** major
- **Classification:** CONFIRMED
- **Found:** YYYY-MM-DD by [agent|user]
- **Fixed:** YYYY-MM-DD in `file/path` — brief fix description
- **Workflow:** workflow-name
- **One-liner:** <120-char symptom + fix description>
- **Full entry:** see `.claude/bugs/workflows/workflow-name.md#bug-NNN`
- **Reproducer:** `.claude/test-runs/reproducers/bug-NNN.sh`
```

Bump `<!-- Next ID: BUG-NNN -->` in `agent-reported.md` when you claim an ID.

### File 3 — `.claude/bugs/resolved.md` (archive with regression check)

Short archive entry with the mechanically-runnable check. Template:

```markdown
### [BUG-NNN] One-line title
- **Classification:** CONFIRMED
- **Workflow:** workflow-name
- **Symptom:** What the user/agent saw, with specifics (numbers, quoted text, DB counts).
- **Fix:** What code changed, where.
- **Why it was broken:** one-sentence root cause.
- **Regression check:** `bash .claude/test-runs/reproducers/bug-NNN.sh` — must exit 0. Or grep: `grep -q "BUG-NNN" <file> && echo "OK"`.
```

The `Regression check:` line is the load-bearing part — `fix-loop`, `dispatch-hunter`, and any other skill that runs a regression sweep grabs this command and executes it.

### File 4 (conditional) — `.claude/bugs/workflows/<other-workflow>.md`

If the bug genuinely spans two workflows, add a cross-reference in the second workflow file pointing at the authoritative entry in File 1. Don't duplicate — just link.

## Step 5 — Grep marker + workflow regression check

This is what wires the fix into the regression sweep permanently.

1. **Embed a `BUG-NNN` string in the touched source code.** Usually inside a comment next to the fix, or in a log line that will show up when the code path runs. The string just has to be greppable — that's it. Examples:
   ```ts
   // BUG-035 fix: move dedup guard here
   console.log(`[execution-monitor] Skipping duplicate permission prompt (BUG-035)`);
   ```

2. **Add a Test actions entry to the matching workflow** in `.claude/workflows.md`:
   ```markdown
   - `grep -q "BUG-NNN" <file> && echo "BUG-NNN OK"`
   - `bash .claude/test-runs/reproducers/bug-NNN.sh`
   ```

3. **If the bug surfaces a new failure mode, add a matrix cell** to any hunt skill that covers this area (`.claude/skills/<hunt-skill>/test-matrix.md`). Matrix cells get exercised during exploratory runs, not just targeted hunts. Only the hunt skills use matrix cells — fix-loop and bug-test-loop don't.

## Step 6 — Commit

### Default: one bug per commit

Makes `git blame` cleanly tell the story of each fix. Future you (or a future agent) reading `git blame` on a single line should see exactly why that line was introduced. Batching multiple unrelated fixes breaks that story.

**Batch only when** two fixes share overlapping verification infrastructure AND touch deeply overlapping code. Example from this session: BUG-034 and BUG-035 landed in one commit because they both touched `server/execution-monitor.ts` heavily and their reproducers shared environment setup. BUG-031 and BUG-032 landed as separate commits even though they're in the same file, because they have independent blast radii.

### Commit message template

```
fix(<scope>): <one-line symptom and cause> (BUG-NNN)

<short paragraph explaining the symptom the user saw>

<short paragraph explaining the root cause — why the old code was wrong>

<short paragraph explaining the fix — what changed and how it addresses the root cause>

Verified:
- reproducer red before fix, green after
- npx tsc --noEmit clean
- <unit test suite> N/N pass
- all existing reproducers still green
- grep markers BUG-<list> all present
- PTY restarted (if server-side) / web restarted (if client-side)

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
```

### Push to the deploy branch

In this repo: `git push origin stable`. Different branches in different projects — check `CLAUDE.md` or `AGENTS.md` for the deploy branch if unsure.

## Failure modes to avoid (anti-patterns)

Observed in past sessions. Each one has cost real hours of re-diagnosing. Don't repeat them.

- **False green from a stale reproducer** — you fixed the symptom but the reproducer never actually detected it. *Fix:* Step 2 mutation check, always.

- **Committed without restarting PTY / Next.js** — the fix is on disk but the running process is serving an older bundle. Production looks unchanged. *Fix:* Step 3 Layer 5 decision tree, always.

- **Reproducer without pre-condition check** — test starts in the wrong state, reports PASS, hides the bug. *Fix:* always add the `exit 2` guard.

- **Fix at every call site instead of at the invariant** — scales quadratically, misses future call sites, creates a maintenance burden. *Fix:* Step 2 "push to the invariant" rule.

- **Skipped the "all existing reproducers" step** — lets cross-bug collisions through silently. *Fix:* Step 3 Layer 3, always.

- **Committed multiple unrelated bugs together** — `git blame` stops telling a useful story. Debugging later is painful. *Fix:* Step 6 one-bug-per-commit default.

- **Described the fix in the bug entry's symptom field** — the entry is for the observer (future user / agent who sees the symptom), not the fixer. If the symptom reads like a code diff, it's wrong. *Fix:* write the symptom in plain user-facing language.

- **Skipped the "why wasn't it caught earlier?" question** — lets detection gaps accumulate. You fix the symptom but the next similar bug will surface the same way. *Fix:* Step 0 Question 3, always.

- **Committed the reproducer but not the grep marker** — regression sweep can't find the fix in the source. *Fix:* Step 5, always.

## Cross-references (how other skills build on this)

- **`fix-loop`** — workflow-scoped fix cycle. Follows Steps 0-6 for each bug found in a loop iteration. The loop itself owns workflow selection and stop conditions; this skill owns the bug-fix rhythm.

- **`dispatch-hunter`** — exploratory bug hunter for the Claude + Codex worker dispatch pipeline. Phase 6 of dispatch-hunter = Steps 0-6 of this skill + dispatch-specific extras (PTY restart is mandatory, re-run affected matrix cells from `test-matrix.md`, append fix entry to the run-state file).

- **`bug-test-loop`** (slash command) — loads this skill first, then executes the targeted fix loop.

- **`system-test-loop`** — broader cross-workflow test. Still delegates to this skill for individual fixes found during the sweep.

If you find yourself inside one of those skills with a bug to fix, come here for the rhythm.

## Quick reference (the 20-second version)

For experienced agents who know the discipline and just want a checklist:

```
Step 0: classify (symptom, type, detection gap, blast radius)
Step 1: reproducer as file, exit codes 0/1/2, trap cleanup, pre-condition check, RED confirmed
Step 2: push to invariant, minimal, GREEN confirmed, mutation check
Step 3: tsc → vitest → ALL reproducers → grep markers → restart decision
Step 4: 4 files (workflow / agent or user / resolved / bump Next ID)
Step 5: grep marker in source + workflow Test actions line + matrix cell if new failure mode
Step 6: one bug per commit, template message, push to deploy branch
```

**If you're skipping a step, you're not done.**
