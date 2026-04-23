---
name: env-bootstrap
description: Use PROACTIVELY at the very start of every worker session — before any other work. MUST BE USED when a new dispatch-worker session begins, or when "continue" / "resume" is signaled. Captures a one-time environment snapshot and maintains a structured runtime/progress.json so a context reset (compaction, restart, handoff) doesn't lose where you were. Saves the 2–5 early exploration turns workers otherwise waste on `ls`, `which python3`, `apt list`.
last_updated: 2026-04-20
---

# Environment bootstrap + progress artifact

Two jobs, one skill:

1. **At session start** — capture the environment snapshot once, so you don't waste early turns discovering it by trial and error.
2. **Throughout the session** — maintain `runtime/progress.json` so any context reset picks up exactly where you left off.

Rooted in Stanford IRIS Meta-Harness (Lee et al., 2026): pre-execution environment bootstrap was the single winning edit the meta-harness discovered, saving 2–5 early exploration turns per run.

## Step 1 — One-time environment snapshot (run at session start)

Run this compound command **once**, before any other investigation:

```bash
bash -c '
echo "=== ENV SNAPSHOT ==="
echo "CWD: $(pwd)"
echo "DATE: $(date -Iseconds)"
echo "GIT BRANCH: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(not a git repo)")"
echo "GIT HEAD: $(git log -1 --oneline 2>/dev/null || echo "(no commits)")"
echo "GIT STATUS:"; git status -sb 2>/dev/null | head -30 || echo "(no git)"
echo "---"
echo "TOP-LEVEL:"; ls -la | head -25
echo "---"
echo "TOOLS:"
for t in node python3 python ruby go rustc gcc java cargo npm pnpm yarn pip pip3 bun deno; do
  if command -v "$t" >/dev/null 2>&1; then
    ver=$("$t" --version 2>&1 | head -1 || echo "?")
    printf "  %-8s %s\n" "$t" "$ver"
  fi
done
echo "---"
echo "MEMORY: $(free -h 2>/dev/null | grep Mem || vm_stat 2>/dev/null | head -3 || echo "(n/a)")"
echo "=== END SNAPSHOT ==="
'
```

The output is your ground truth for the session. You now know which languages, which tool versions, what's tracked in git, what's uncommitted, and the cwd. **Do not re-query these for the rest of the session** — you already have the answers.

If any of the above commands fails (not a git repo, no `free`, no `vm_stat`), that failure IS information; skip the section and continue.

## Step 2 — Read or create `runtime/progress.json`

**Skip Step 2 for trivial tasks.** If the task is a single-file typo fix, a comment-only change, a README edit, or anything you can finish in under 5 minutes with no branching decisions — skip the progress artifact entirely. The file is a handoff mechanism for sessions that might get compacted or resumed, and trivial tasks don't generate enough state to be worth tracking. Use judgment: if a fresh context would have nothing meaningful to pick up from your `critical_facts`, you don't need to write one.

For everything else — any bug fix, any multi-step feature, any refactor, any exploration that might get paused — write the progress artifact. Better to have it and not need it than need it and not have it. The rest of this step applies when you're writing one:

Immediately after the snapshot:

```bash
# Read existing progress (if any)
cat runtime/progress.json 2>/dev/null || echo '{"phase":"starting","completed":[],"blockers":[],"next_action":null,"critical_facts":{}}'
```

If `runtime/progress.json` exists, you are **resuming** — the file has the last session's state. Read it carefully before taking any action; the `next_action` field tells you where to pick up.

If it doesn't exist, you are **starting fresh** — create it with the initial structure shown below.

### Schema

```json
{
  "phase": "starting | exploring | executing | verifying | completing",
  "objective": "one-sentence description of what this session is for",
  "completed": [
    "short description of a finished step",
    "..."
  ],
  "blockers": [
    "what you're stuck on (empty when unblocked)"
  ],
  "next_action": "the very next concrete thing to do — always one sentence",
  "critical_facts": {
    "root_cause": "...",
    "key_files": ["src/..."],
    "test_command": "npm test -- foo",
    "... any session-specific facts that must survive a context reset"
  },
  "updated_at": "ISO-8601 timestamp"
}
```

`critical_facts` is the most load-bearing field — put anything a fresh context would need to re-derive. File paths, commit SHAs, test commands, root-cause hypotheses, decisions made. Don't duplicate the environment snapshot; duplicate the session-specific intelligence.

## Step 3 — Update `runtime/progress.json` as you work

Update the file at natural checkpoints:

- **After finishing a step**: append to `completed[]`, set `next_action` to whatever's next.
- **When you hit a blocker**: append to `blockers[]`. Clear it when resolved.
- **When you learn something load-bearing** (a root cause, a constraint, a decision): write it to `critical_facts`.
- **When you finish the session**: set `phase: "completing"`, clear `next_action` if nothing remains.

Write discipline:

```bash
# Use a small helper pattern to keep updates atomic.
python3 -c "
import json, os, datetime
p = 'runtime/progress.json'
os.makedirs('runtime', exist_ok=True)
try:
    with open(p) as f: d = json.load(f)
except FileNotFoundError:
    d = {'phase':'starting','objective':'','completed':[],'blockers':[],'next_action':None,'critical_facts':{}}
# --- your updates here, e.g.:
d['completed'].append('Fixed auth.ts timezone bug')
d['next_action'] = 'Run full test suite and verify no regressions'
d['updated_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
with open(p,'w') as f: json.dump(d, f, indent=2)
"
```

Keep the file small — a few KB max. It is not a diary; it is a scratchpad for the **next agent that inherits this context**. If it gets long, compress old entries; don't let it bloat.

## Step 4 — Progress artifact rules

- **One file per session.** Do not fork `runtime/progress.json` into per-feature files; the whole point is a single entry point.
- **Never store secrets** — tokens, API keys, credentials, passwords. Those belong in env files, not progress files.
- **Gitignore `runtime/`**. It's machine state, not source.
- **On `compact` or `resume`**: read `runtime/progress.json` BEFORE reading the conversation history. The file is fresher than anything the summary tells you.

## Failure modes to avoid

- **Running the snapshot twice in one session** — it's noise. Run it once at start.
- **Forgetting to update after a major step** — if a fresh context had to take over, what would it need? If you haven't written that down, you're one compaction away from losing it.
- **Treating progress.json as a "nice-to-have"** — once enabled, it's the load-bearing handoff artifact. Skipping it is how sessions re-discover the same root cause three times.

## Why this skill exists (one paragraph)

The Stanford IRIS Meta-Harness paper (2026) optimized the scaffolding around a fixed LLM on Terminal-Bench-2. After 6 failed attempts to rewrite prompts or restructure control flow, the meta-harness converged on one winning change: **additive pre-execution environment capture**. That single edit drove a measurable +1.7 pts on Opus 4.6 and widened the gap more on smaller models. The lesson: before you ask the model to reason, hand it the ground truth it would otherwise spend 2–5 turns re-discovering. This skill plus the progress artifact apply that principle to our workers.

## References

- Lee et al., *Meta-Harness: End-to-End Optimization of Model Harnesses*, Stanford IRIS, 2026. https://yoonholee.com/meta-harness/
- Progress-artifact pattern: Anthropic harness-design guidance + Cognition "Don't Build Multi-Agents" (June 2025).
