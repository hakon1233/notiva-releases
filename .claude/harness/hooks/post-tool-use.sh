#!/usr/bin/env bash
# Harness PostToolUse hook — consolidates hunter findings into a single
# markdown file so the main worker can Read one file instead of
# re-parsing N tool_result blocks. Also writes sentinels so the
# PreToolUse "force-read findings" + "restricted post-hunter" gates know
# when the worker has acknowledged the consolidated view.
#
# When called for `Agent` / `Task` tool calls whose subagent_type is one of
# the hunters, parses the tool_response, extracts the JSON `findings` array,
# and appends a section to `runtime/.harness-state/hunter-findings.md`.
#
# Kill switch: TTM_DISABLE_HARNESS_HOOK=1 → exit 0.
# Fail-open: any error → exit 0 (don't break the worker's flow).

set -uo pipefail

if [[ "${TTM_DISABLE_HARNESS_HOOK:-0}" == "1" ]]; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

PAYLOAD=$(cat)
[[ -z "$PAYLOAD" ]] && exit 0

TOOL_NAME=$(echo "$PAYLOAD" | jq -r '.tool_name // empty')
[[ -z "$TOOL_NAME" ]] && exit 0

# Only act on Agent/Task dispatches that match a hunter subagent_type.
case "$TOOL_NAME" in
  Agent|Task) ;;
  *) exit 0 ;;
esac

SUBAGENT=$(echo "$PAYLOAD" | jq -r '.tool_input.subagent_type // empty')
case "$SUBAGENT" in
  cross-reference-hunter|invariant-hunter|error-handling-hunter|boundary-hunter|surface-hunter) ;;
  *) exit 0 ;;
esac

# Extract the tool_response text. Claude Code passes it as either a string
# or an array of content blocks; handle both shapes.
RESPONSE=$(echo "$PAYLOAD" | jq -r '
  .tool_response
  | if type == "string" then .
    elif type == "array" then ([.[] | (.text // "")] | join("\n"))
    elif type == "object" then (.content // "" | if type == "array" then ([.[] | (.text // "")] | join("\n")) else . end)
    else ""
    end
')
[[ -z "$RESPONSE" ]] && exit 0

# Try to locate the JSON block inside the response (hunters wrap in ```json fences).
# Strategy: extract everything between the first '{' and the matching closing '}'.
# We use python for reliable balanced-brace extraction since bash regex isn't.
FINDINGS_MD=$(python3 - <<PY 2>/dev/null
import json, re, sys
text = """$RESPONSE"""
# Find a JSON object that has "lens" and "findings" keys.
# Try fenced first, then bare.
m = re.search(r'\`\`\`json\s*(\{[\s\S]*?\})\s*\`\`\`', text)
candidate = m.group(1) if m else None
if not candidate:
    # Bare JSON — find first { ... } that contains "lens" and "findings"
    depth = 0; start = None
    for i, ch in enumerate(text):
        if ch == '{':
            if depth == 0: start = i
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0 and start is not None:
                cand = text[start:i+1]
                if '"lens"' in cand and '"findings"' in cand:
                    candidate = cand
                    break
                start = None
if not candidate:
    sys.exit(0)
try:
    j = json.loads(candidate)
except Exception:
    sys.exit(0)
lens = j.get("lens", "unknown")
coverage = j.get("coverage_notes", "")
findings = j.get("findings", []) or []
if not findings:
    print(f"## {lens}\n\n_coverage: {coverage}_\n\n(no findings)\n")
    sys.exit(0)
print(f"## {lens}")
print()
print(f"_coverage: {coverage}_")
print()
for i, f in enumerate(findings, 1):
    file = f.get("file","?")
    ls = f.get("line_start", 0)
    le = f.get("line_end", 0)
    sev = f.get("severity","?")
    conf = f.get("confidence","?")
    hyp = f.get("hypothesis","?")
    ev = f.get("evidence","")
    print(f"### {lens}-{i}  [{sev}, {conf}]  {file}:{ls}-{le}")
    print()
    print(f"**Hypothesis:** {hyp}")
    print()
    if ev:
        print("```")
        print(ev)
        print("```")
    print()
PY
)

# Write to the consolidated findings file (append, headered by run timestamp on first write).
FINDINGS_FILE="runtime/.harness-state/hunter-findings.md"
mkdir -p runtime/.harness-state 2>/dev/null

if [[ ! -f "$FINDINGS_FILE" ]]; then
  cat > "$FINDINGS_FILE" <<HEADER
# Hunter findings — consolidated

This file is auto-written by the harness PostToolUse hook as each
hunter agent returns. The main worker is expected to Read this file
(once all hunters have fired) BEFORE doing additional source
exploration, and to fix findings in severity/confidence order.

The PreToolUse "force-read findings" gate will refuse Edit/Write
calls until this file has been Read in the current session.

HEADER
fi

# Append the new section (if extraction yielded anything).
if [[ -n "$FINDINGS_MD" ]]; then
  printf '\n%s\n' "$FINDINGS_MD" >> "$FINDINGS_FILE"
fi

# Also record per-hunter that the consolidation step ran successfully —
# the PreToolUse force-read gate can use this as a "is the file ready"
# signal without re-parsing.
touch "runtime/.harness-state/${SUBAGENT}-consolidated" 2>/dev/null

exit 0
