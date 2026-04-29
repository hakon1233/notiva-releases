---
name: fewer-permission-prompts
description: Use PROACTIVELY whenever a worker session keeps hitting "Claude needs your permission to use Bash" idle stalls, or when extending the per-repo Claude Code allowlist. MUST BE USED before adding new entries to `.claude/settings.local.json` or its `.template` source — explains the prioritization rule (read-only / common ops first), the three buckets (always-allow / never-allow / ask), and the deny-list invariants this repo ships with.
last_updated: 2026-04-29
---

# Fewer permission prompts — keep workers moving on read-only ops

## The failure mode this prevents

A worker that pauses on a permission prompt is a worker that **stalls until
a human responds**. The harness logs this as `agent.notification` with
`notification_type: permission_prompt`. Across the fleet, ~90% of those
prompts are **Bash** calls — almost always a read-only command (`grep`,
`rg`, `ps`, `tmux ls`, `git log`, etc.) the agent uses dozens of times
per task. Every missing allowlist entry costs one stall per use, fleet-wide.

The fix is not "approve broader patterns at runtime." It is **shipping a
prioritized allowlist in the harness template** so the prompt never fires.

## The three buckets

Every Bash pattern fits in one of these three buckets. Get the bucket right
before adding to the allowlist.

### 1. Always-allow (read-only, no side effects)

Filesystem reads, search, process inspection, version control reads, and
shell built-ins. These never modify the repo or external state.

Already shipped in the template:
- File listing/reading: `ls`, `cat`, `head`, `tail`, `wc`, `find`, `tree`,
  `file`, `stat`, `du`, `df`, `realpath`, `readlink`, `basename`, `dirname`
- Search: `grep`, `egrep`, `fgrep`, `rg`, `ag`
- Process/env: `pwd`, `whoami`, `which`, `type`, `command -v`, `env`,
  `printenv`, `ps`, `pgrep`, `uname`, `hostname`, `uptime`
- Text shaping: `sort`, `uniq`, `cut`, `awk`, `sed`, `tr`, `diff`, `comm`,
  `jq`, `yq`
- Built-ins / control: `echo`, `printf`, `date`, `true`, `false`, `test`,
  `sleep`
- Git reads: `git status`, `git diff`, `git log`, `git show`, `git branch`,
  `git fetch`, `git rev-parse`, `git ls-files`, `git blame`, `git remote`,
  `git tag`, `git describe`, `git ls-remote`, `git worktree list`,
  `git config --get`
- Tmux reads: `tmux ls`, `tmux list-sessions`, `tmux list-windows`,
  `tmux list-panes`, `tmux capture-pane`, `tmux has-session`,
  `tmux display-message`

If a top-frequency bash verb is missing from the above and is provably
read-only, **add it here** and bump the harness version (patch).

### 2. Ask-each-time (writes, but scoped)

Anything that mutates repo state, system state, or external services. These
must hit a prompt so the user can approve scope at the call site.

- Git writes that are common and scoped (`git add`, `git commit`,
  `git checkout`, `git merge`, `git rebase`, `git restore`, `git stash`)
  — already shipped wildcarded because the deny list catches the dangerous
  forms.
- Package managers (`npm`, `npx`, `pnpm`, `yarn`) — shipped wildcarded
  because most invocations are scripts; deny list blocks `publish`.
- Repo scripts (`bash scripts/*`, `./scripts/*`) — explicit per-repo paths,
  not arbitrary script dirs.

### 3. Never-allow (deny list)

Hard rules the deny list enforces regardless of approval. Don't shrink this
list — it exists because each entry is a real way a worker has caused or
could cause data loss.

- `rm -rf /*`, `rm -rf /`, `rm -rf ~*`, `rm -rf $HOME*`, `sudo rm *`
- `git push --force *`, `git push -f *`, `git reset --hard *`,
  `git clean -fdx *`
- `npm publish *`, `pnpm publish *`, `yarn publish *`

## How to add a new entry

1. **Confirm the verb is in bucket 1** (read-only). If unsure, run it once
   yourself — if it can mutate anything, it belongs in bucket 2 and
   shouldn't be wildcarded.
2. Edit `templates/claude-project-template/.claude/settings.local.json.template`
   in the source-of-truth repo (task-terminal-manager). The template is
   the canonical list — every managed repo's `.claude/settings.local.json`
   is composed from it via `scripts/compose-workspace.sh`.
3. Sort the new entry next to similar verbs (search next to search, git
   reads next to git reads). The file is intentionally grouped, not
   alphabetic.
4. Bump `harness-versions.json` (patch) so the change deploys to the fleet
   on the next autopull.
5. Run `bash scripts/harness/test-sandbox.sh` to verify the template still
   parses and composes cleanly.

## What NOT to do

- **Don't add `Bash(*)`.** The whole point of the allowlist is to keep
  bucket 3 enforceable.
- **Don't approve patterns ad-hoc at the prompt** ("always allow this
  exact command") for read-only verbs. That fix is per-machine and
  invisible to other workers — file the allowlist edit instead so the
  whole fleet benefits.
- **Don't widen a bucket-2 entry to wildcard** because it's annoying.
  `git checkout *` is already shipped; `git push *` is not, and never
  should be.

## Where the data comes from

The auditor's `find-friction-patterns.mjs` clusters
`agent.notification` events with `notification_type: permission_prompt`
into a `permission-stall:<dimension>` finding. When the dimension is
`claude-code` and the count is high, the fix is almost always a missing
bucket-1 entry. Cross-reference with `tool.call.pre` events to identify
the exact bash verbs being prompted.
