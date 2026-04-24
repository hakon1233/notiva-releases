#!/usr/bin/env bash
set -euo pipefail

# compose-workspace.sh — produces the on-disk views that Claude Code / Codex
# read from the two source layers:
#
#   .claude/harness/   ← harness team owns; regenerated on every harness
#                         version bump; LOCKED read-only between bumps
#   .claude/project/   ← project owner owns; never touched by the harness;
#                         start here when adding custom skills or rules
#
# This script writes the composed artifacts:
#
#   .claude/skills/    ← union of harness/skills + project/skills (project wins)
#   .claude/agents/    ← union of harness/agents + project/agents
#   CLAUDE.md          ← cat harness/CLAUDE.part.md + project/CLAUDE.part.md
#   AGENTS.md          ← cat harness/AGENTS.part.md + project/AGENTS.part.md
#
# Re-run after editing anything in .claude/project/. Runs automatically at the
# end of each bootstrap-claude-template.sh deploy. Idempotent — zero changes
# if sources are byte-identical.
#
# Philosophy:
#   - Harness layer is global / shared / version-bumped as a unit.
#   - Project layer is local / specific / safe from upstream churn.
#   - Composed artifacts are READ-ONLY outputs. Never hand-edit them — your
#     changes will be clobbered on the next compose. Edit the part files in
#     .claude/harness/ (for harness changes, via TTM template + version bump)
#     or .claude/project/ (for project-specific changes).
#
# Regression test: scripts/harness/test-layered-bootstrap.sh in the TTM repo
# exercises every safety claim of this script in a sandbox.

REPO_DIR="${1:-$(pwd)}"
cd "$REPO_DIR"

HARNESS=".claude/harness"
PROJECT=".claude/project"

# --- Sanity ---------------------------------------------------------------

if [[ ! -d "$HARNESS" ]]; then
  echo "[compose] no $HARNESS dir — run bootstrap-claude-template.sh first" >&2
  exit 1
fi

# Ensure project scaffold exists (bootstrap creates it, but this script must
# survive a user rm -rf of .claude/project).
if [[ ! -d "$PROJECT" ]]; then
  mkdir -p "$PROJECT/skills" "$PROJECT/agents"
  cat > "$PROJECT/README.md" <<'PROJ_README'
# .claude/project/ — YOUR editable layer

Add project-specific skills, agents, slash commands, or AGENTS.md/CLAUDE.md
additions here. Bootstrap and harness version bumps NEVER touch this directory.

- `skills/<name>/SKILL.md` — skills unique to this project
- `agents/<name>.md` — agents unique to this project
- `CLAUDE.part.md` — text appended to the repo's root `CLAUDE.md` after the harness section
- `AGENTS.part.md` — text appended to the repo's root `AGENTS.md` after the harness section

After editing anything here, run: `bash scripts/compose-workspace.sh`
(or it's already done for you on every bootstrap / session start).
PROJ_README
  : > "$PROJECT/CLAUDE.part.md"
  : > "$PROJECT/AGENTS.part.md"
  touch "$PROJECT/skills/.gitkeep" "$PROJECT/agents/.gitkeep"
fi

# --- Skills composition ----------------------------------------------------
#
# Rebuild .claude/skills/ as a flat dir that Claude Code reads natively. Union
# of harness/skills/ and project/skills/. Project wins on name collision (and
# a stderr warning is printed so the project owner is aware).

compose_dir() {
  local layer_name="$1"   # "skills" or "agents"
  local composed_dir=".claude/$layer_name"

  # Unlock the composed dir if it was previously locked.
  [[ -d "$composed_dir" ]] && chmod -R u+w "$composed_dir" 2>/dev/null || true
  rm -rf "$composed_dir"
  mkdir -p "$composed_dir"

  # Harness layer first (will be overwritten by project on collision).
  if [[ -d "$HARNESS/$layer_name" ]]; then
    for src in "$HARNESS/$layer_name"/*; do
      [[ -e "$src" ]] || continue
      local name; name="$(basename "$src")"
      if [[ -d "$src" ]]; then
        cp -R "$src" "$composed_dir/$name"
      elif [[ -f "$src" ]]; then
        cp "$src" "$composed_dir/$name"
      fi
    done
  fi

  # Project layer second — overlays onto harness.
  if [[ -d "$PROJECT/$layer_name" ]]; then
    for src in "$PROJECT/$layer_name"/*; do
      [[ -e "$src" ]] || continue
      local name; name="$(basename "$src")"
      if [[ "$name" == ".gitkeep" ]]; then continue; fi
      if [[ -e "$composed_dir/$name" ]]; then
        echo "[compose] $layer_name/$name: project overrides harness" >&2
        rm -rf "$composed_dir/$name"
      fi
      if [[ -d "$src" ]]; then
        cp -R "$src" "$composed_dir/$name"
      elif [[ -f "$src" ]]; then
        cp "$src" "$composed_dir/$name"
      fi
    done
  fi

  # Lock the composed dir read-only — it's a generated output. Users should
  # edit harness/ (via TTM + bump) or project/ (direct), not the composed view.
  chmod -R a-w "$composed_dir" 2>/dev/null || true
}

compose_dir "skills"
compose_dir "agents"

# --- Root file composition -------------------------------------------------
#
# CLAUDE.md and AGENTS.md at repo root = harness part + project part, with a
# clear visible divider + a machine-written do-not-edit banner at the top.

compose_root_file() {
  local layer_name="$1"   # "CLAUDE" or "AGENTS"
  local out=".claude/.compose.$layer_name.tmp.$$"
  local final="$(echo "$layer_name" | tr '[:lower:]' '[:upper:]').md"
  # Handle the actual filename case (CLAUDE.md, AGENTS.md).
  final="$layer_name.md"

  # Terse header — one line. The verbose design-rationale banner used to eat
  # ~450 chars from the bootstrap-char budget, pushing SOULs over the 12000
  # default cap. Design doc lives on /harness-research#two-layer.
  cat > "$out" <<EOF
<!-- auto-generated by scripts/compose-workspace.sh from .claude/harness/$layer_name.part.md + .claude/project/$layer_name.part.md — do not hand-edit -->

EOF

  if [[ -f "$HARNESS/$layer_name.part.md" ]]; then
    cat "$HARNESS/$layer_name.part.md" >> "$out"
  fi

  # Compact separator — only emitted when there's actually project content.
  # Precedence (project wins on conflict) is documented globally, not here.
  if [[ -s "$PROJECT/$layer_name.part.md" ]]; then
    cat >> "$out" <<'SEPARATOR'


<!-- project overrides follow -->

SEPARATOR
    cat "$PROJECT/$layer_name.part.md" >> "$out"
  fi

  # Atomically replace. If the final is locked, unlock first.
  [[ -f "$final" ]] && chmod u+w "$final" 2>/dev/null || true
  mv "$out" "$final"
  chmod a-w "$final" 2>/dev/null || true
}

compose_root_file "CLAUDE"
compose_root_file "AGENTS"

# --- Lock the harness layer ------------------------------------------------
#
# Agents that try to edit anything under .claude/harness/ will get EACCES.
# Bootstrap unlocks, writes, re-locks. No file watcher / daemon needed.

chmod -R a-w "$HARNESS" 2>/dev/null || true

echo "[compose] OK — .claude/skills ($(ls -1 .claude/skills 2>/dev/null | wc -l | tr -d ' ') dirs), .claude/agents ($(ls -1 .claude/agents 2>/dev/null | wc -l | tr -d ' ') files), CLAUDE.md ($(wc -l < CLAUDE.md | tr -d ' ') lines), AGENTS.md ($(wc -l < AGENTS.md | tr -d ' ') lines)"
