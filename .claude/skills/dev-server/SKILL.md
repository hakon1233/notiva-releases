---
name: dev-server
description: Use PROACTIVELY whenever you need to start, stop, or check a long-running dev server (e.g. `npm run dev`, `next dev`, `vite`, `wrangler dev`) for THIS project. MUST BE USED when the user asks to "run the site", "open it in the browser", "start the dev server", "bring it up on port X", or when you're about to run any command that stays running indefinitely. Owns the canonical dev-server lifecycle — one named tmux session per project, never a bare `exec` / `bash` background call.
last_updated: 2026-04-22
---

# Dev Server — run it in a named tmux session, always

## The failure mode this prevents

A dev server started with `exec(..., { background: true })` or any bare
`npm run dev &` is a **child of your current agent/worker session**. When
that session ends, gets reaped, or your Bash tool call times out / gets
killed by a permission-prompt timeout, **the dev server dies with it**.

We've seen the same project hit by this chain:

1. Orchestrator runs `PORT=5733 npm run dev` with `background: true`.
2. Worker turn ends; dev server dies.
3. Next worker restarts it. Now there are two would-be owners.
4. A third worker runs `pkill -f "next dev"` to "clean up" — takes
   down the user's live session.
5. User tells the user-facing indicator flipping green → grey → green
   every couple of minutes.

Root cause: nobody owns the dev server lifetime. The fix below makes
the project's own tmux session the single owner.

## The rule

**Always run long-lived dev servers in a named, detached tmux session.**
Pattern:

```bash
SESSION="${PROJECT_NAME}-dev"   # e.g. turfkeeper-dev
# Port resolution, in order of preference:
#   1. $PORT env var (explicit override)
#   2. .ttm-dev-port at the repo root (written by scaffold-from-template.sh
#      from TTM's /api/projects/dev-port endpoint — this is the
#      deterministic port TTM's green-globe indicator probes)
#   3. Framework default — 3000 for Next.js, adjust for Vite (5173), etc.
PORT="${PORT:-$(cat .ttm-dev-port 2>/dev/null || echo 3000)}"
DIR="$(pwd)"                    # project root

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "Dev server already running in tmux session $SESSION"
  # Sanity-check it's actually serving on $PORT
  if ! curl -s -o /dev/null -m 1 "http://127.0.0.1:$PORT/"; then
    echo "Port $PORT not responding — session is stuck. Restart with:"
    echo "  tmux kill-session -t $SESSION && <re-run this block>"
  fi
else
  tmux new-session -d -s "$SESSION" -c "$DIR" "PORT=$PORT npm run dev"
  echo "Started dev server in tmux session $SESSION on port $PORT"
fi
```

Use a project-scoped session name like `<project>-dev`, not a generic
`dev`, so multiple projects don't collide.

## When you must NOT start a dev server

- If `tmux has-session -t "$SESSION"` is true AND the port is responding,
  **do nothing**. Don't "restart to be safe" — you'll interrupt the user.
- If another worker's logs show it recently started the dev server, check
  first with `tmux has-session` before acting.
- If you're about to call `pkill -f "next dev"` or similar: **stop.** It
  kills dev servers for every project, not just yours. Use
  `tmux kill-session -t "$SESSION"` instead.

## Inspecting a running dev server

```bash
# See the last N lines of output (e.g. to find an error):
tmux capture-pane -t "$SESSION" -p -S -200

# Follow live (only when attached from a human terminal — agents should
# not attach, it'll hang their tool call):
#   tmux attach -t "$SESSION"

# See all project dev sessions:
tmux list-sessions | grep -- '-dev$'
```

## Restarting cleanly

```bash
tmux kill-session -t "$SESSION" 2>/dev/null
# then re-run the "Start" block above
```

**Never** SIGKILL or `pkill` the underlying node process directly — tmux
will think the session is still alive until it notices, and the next
`has-session` check will be wrong.

## Port conventions

In TTM-managed projects, each project has a **deterministic dev port**
derived from its project ID (see `src/lib/dev-port.ts` in the
task-terminal-manager repo — `computeDevPortMap`). The TTM UI shows a
green globe icon next to "PTY Server" when that specific port is
responding; clicking it opens the dev URL. If you start the dev server
on a different port, that indicator stays grey even if your server is
running fine.

The canonical source of truth for a project is **`.ttm-dev-port`** at
the repo root — a single-line file containing just the port number.
`scripts/scaffold-from-template.sh` in the TTM repo writes it by
querying `/api/projects/dev-port` at scaffold time, so every repo
scaffolded through the standard path already has the right number.

If `.ttm-dev-port` is missing (e.g. the repo was hand-cloned, or TTM
wasn't running at scaffold time), you can regenerate it with:

```bash
curl -sf "http://127.0.0.1:4000/api/projects/dev-port?path=$(pwd)" \
  | jq -r '.port' > .ttm-dev-port
```

If `AGENTS.md` lists a **Dev port** sentence (it should, when
scaffolded with DEV_PORT substitution), trust that value and use it —
no lookup needed.

Last-resort fallback: framework default (3000 for Next.js, 5173 for
Vite, etc.) and tell the user which port you picked so they can update
the project's configuration.

## Why `background: true` in orchestrator `exec` is not enough

`background: true` tells the orchestrator's tool interface to return
control early — it does **not** detach the process from the orchestrator's
session. The process stays a child of the orchestrator's tmux pane. When
the orchestrator finishes its turn, its pane may be reaped, taking the
dev server with it. tmux `new-session -d` is the only way to give the
dev server a pane that outlives whoever started it.

## Checklist before starting a dev server

- [ ] `tmux has-session -t <project>-dev` — already running?
- [ ] If yes, does `curl -s http://127.0.0.1:$PORT/` respond? If yes, stop — don't touch it.
- [ ] If no, `tmux kill-session -t <project>-dev` first, then start fresh.
- [ ] Start with `tmux new-session -d -s <project>-dev -c "$DIR" "PORT=$PORT npm run dev"`.
- [ ] Verify with `curl` after ~2 seconds.
- [ ] Tell the user the URL + the session name (so they can attach if needed).
