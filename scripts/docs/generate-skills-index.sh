#!/bin/bash
# generate-skills-index.sh — Writes docs/meta/SKILLS.md classifying every
# skill, command, and agent in this repo against the project template.
#
# Classification:
#   standard         — filename exists in templates/claude-project-template/.claude/<kind>/ at the same relative path, content identical
#   project-specific — exists in this repo, not in the template
#   drifted          — exists in both but content differs
#   missing          — exists in template, not in this repo
#
# Usage: scripts/docs/generate-skills-index.sh

set -eo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEMPLATE_ROOT="$REPO_ROOT/templates/claude-project-template"
OUT_DIR="$REPO_ROOT/docs/meta"
OUT_FILE="$OUT_DIR/SKILLS.md"

mkdir -p "$OUT_DIR"

repo_name="$(basename "$REPO_ROOT")"
generated_at="$(date '+%Y-%m-%d %H:%M')"

describe() {
  local file="$1"
  local desc=""
  if [[ -f "$file" ]]; then
    desc=$(awk '
      BEGIN { in_fm=0 }
      /^---$/ { in_fm = !in_fm; next }
      in_fm && /^description:/ {
        sub(/^description:[[:space:]]*/, "")
        sub(/^"/, ""); sub(/"$/, "")
        print
        exit
      }
    ' "$file")
    if [[ -z "$desc" ]]; then
      desc=$(awk '/^# / { sub(/^# /, ""); print; exit }' "$file")
    fi
  fi
  [[ -z "$desc" ]] && desc="(no description)"
  printf '%s' "$desc"
}

# file_for KIND NAME ROOT
file_for() {
  case "$1" in
    skills) printf '%s/%s/SKILL.md' "$3" "$2" ;;
    commands|agents) printf '%s/%s.md' "$3" "$2" ;;
  esac
}

# list_names KIND ROOT — prints one name per line
list_names() {
  local kind="$1" root="$2"
  [[ -d "$root" ]] || return 0
  case "$kind" in
    skills)
      find "$root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while read -r d; do
        [[ -f "$d/SKILL.md" ]] && basename "$d"
      done | sort -u
      ;;
    commands|agents)
      find "$root" -mindepth 1 -maxdepth 1 -type f -name '*.md' 2>/dev/null | while read -r f; do
        local n
        n="$(basename "$f" .md)"
        [[ "$n" == "README" ]] && continue
        echo "$n"
      done | sort -u
      ;;
  esac
}

print_list() {
  local header="$1" empty_msg="$2"
  shift 2
  printf '\n### %s\n\n' "$header"
  if [[ $# -eq 0 ]]; then
    printf '%s\n' "$empty_msg"
    return
  fi
  for entry in "$@"; do
    printf -- '- %s\n' "$entry"
  done
}

classify_section() {
  local kind="$1" label="$2" repo_sub="$3" tmpl_sub="$4"
  local repo_dir="$REPO_ROOT/$repo_sub"
  local tmpl_dir="$TEMPLATE_ROOT/$tmpl_sub"

  local repo_names tmpl_names
  repo_names="$(list_names "$kind" "$repo_dir")"
  tmpl_names="$(list_names "$kind" "$tmpl_dir")"

  local standard=() project_specific=() drifted=() missing=()
  local name repo_file tmpl_file desc entry

  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    repo_file="$(file_for "$kind" "$name" "$repo_dir")"
    tmpl_file="$(file_for "$kind" "$name" "$tmpl_dir")"
    desc="$(describe "$repo_file")"
    entry="**$name** — $desc"
    if [[ -f "$tmpl_file" ]]; then
      if diff -q "$repo_file" "$tmpl_file" >/dev/null 2>&1; then
        standard+=("$entry")
      else
        drifted+=("$entry")
      fi
    else
      project_specific+=("$entry")
    fi
  done <<< "$repo_names"

  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    repo_file="$(file_for "$kind" "$name" "$repo_dir")"
    if [[ ! -f "$repo_file" ]]; then
      missing+=("**$name** — expected per template; add or consciously skip")
    fi
  done <<< "$tmpl_names"

  printf '\n## %s (`%s`)\n' "$label" "$repo_sub"
  print_list "Standard (matches template exactly)" "_None._" "${standard[@]}"
  print_list "Project-specific (not in template)"  "_None._" "${project_specific[@]}"
  print_list "Drifted (present in both, content differs)" "_None._" "${drifted[@]}"
  print_list "Missing (in template but not in this repo)" "_None._" "${missing[@]}"
}

{
  cat <<HEADER
# Skills Inventory — $repo_name

_Generated $generated_at by \`scripts/docs/generate-skills-index.sh\`. Do not edit by hand._

This file classifies every skill, slash command, and subagent definition in this repo against the project template at \`templates/claude-project-template/.claude/\`. Regenerate after any skill / command / agent is added, removed, or renamed.

- **Standard** — present in the template, content identical → safe default, maintained centrally.
- **Project-specific** — only exists in this repo.
- **Drifted** — present in both, content differs. Drift is often intentional.
- **Missing** — template has it, this repo doesn't. Flag for review.
HEADER

  classify_section "skills"   "Skills"   ".claude/skills"   ".claude/skills"
  classify_section "commands" "Commands" ".claude/commands" ".claude/commands"
  classify_section "agents"   "Agents"   ".claude/agents"   ".claude/agents"

  printf '\n'
} > "$OUT_FILE"

echo "Wrote $OUT_FILE"
