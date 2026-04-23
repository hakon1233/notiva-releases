---
name: docs-writing
description: Use PROACTIVELY before creating or editing any file under docs/, writing a README, writing an ADR, updating a runbook, or writing an explanatory section in a SKILL.md. MUST BE USED when you're about to write prose that explains how, why, or what. Encodes the Diataxis split + frontmatter + per-folder INDEX rules that keep docs agent-navigable.
last_updated: 2026-04-24
---

# Docs Writing

Docs that agents actually use. Ten rules, four shapes.

## Diataxis — pick the shape first

Every doc is one of four shapes. If you can't pick one, your doc is doing too many things; split it.

| Shape | Purpose | Lives in | Voice |
|-------|---------|----------|-------|
| **Tutorial** | Learning by doing (zero-to-one) | `docs/tutorials/<slug>.md` | "We'll start by…" |
| **How-to** | Solving a specific problem | `.claude/skills/<name>/SKILL.md` or `docs/how-to/<slug>.md` | "To do X, run Y" |
| **Reference** | Looking up exact facts | Generated from code (types, tests) or `docs/reference/` | Neutral, terse |
| **Explanation** | Understanding why | `docs/system/`, `docs/decisions/`, `docs/research/` | "The reason we…" |

**Never mix shapes in one file.** A SKILL.md is a how-to; if you're writing "here's why this exists" prose, it belongs in `docs/system/` or as an ADR, and the skill just links to it.

## Ten rules

### 1. Frontmatter is mandatory
Every doc file gets YAML frontmatter:

```yaml
---
name: <short slug>
description: <≤160 chars; verb-led; keywords agents would match on>
type: tutorial | how-to | reference | explanation | adr | runbook
last_reviewed: YYYY-MM-DD
---
```

The `description` is load-bearing — for Claude Code skills it determines whether the skill auto-loads. Short, keyword-rich, verb-first. Do not pad it.

### 2. ADRs go in `docs/decisions/NNNN-title.md`, immutable
Use Nygard format: Context / Decision / Consequences. Never edit a landed ADR — supersede it with a new one that links back. Reference ADRs from the code that implements them: `// See ADR-0012`.

### 3. Per-folder `README.md` acts as an INDEX
Every non-trivial `docs/` subfolder has a README listing every sibling file with a one-line description. Agents tree-walk before semantic search; a README at the folder entry is a cheap, high-recall anchor.

### 4. Runbooks: numbered steps + exact command + expected output
Agents execute literally. "Verify it worked" without a command is a skip-risk. Every step:

```markdown
### Step 3: Confirm the migration landed
Run: `npm run db:status`
Expect: `All migrations applied (7/7)`
If instead: `pending: <name>` — re-run `npm run db:migrate` and loop.
```

### 5. Living docs beat hand-written — for reference only
Point agents at types (TSDoc, TypeDoc) and test names for behavior truth. Prose drifts silently; types and tests don't. Use hand-written prose only for the *why* (explanation / ADR), never for the *what* (reference).

### 6. `last_reviewed:` drives rot detection
Docs older than 180 days with a recently-changed referenced source file fail CI. Reviewing means bumping the timestamp after a fresh read, not a blind touch.

### 7. Link to tests for behavior, to code for shape, to ADRs for why
Three canonical link targets. Prose explanations of "what the code does" are always weaker than the code itself — link, don't paraphrase.

### 8. Agent onboarding ≠ human onboarding
Humans skim. Agents need a deterministic read-order and machine-readable contracts. Keep `AGENTS.md` neutral + dense; keep `CLAUDE.md` for Claude-specific rhythms; keep `README.md` for humans. Don't merge them.

### 9. One doc, one purpose
If a file has sections for setup, troubleshooting, architecture, and changelog, split it. Four files, each one Diataxis shape, each short enough to read cold.

### 10. Keyword-dense filenames, not clever ones
Agents grep before they read. `chat-session-rotation.md` beats `clever-solutions.md`. H1 + H2 should also carry the keywords — they're the second retrieval surface.

## The checklist — run before committing a doc

```
□ 1. Picked one Diataxis shape (tutorial / how-to / reference / explanation)?
□ 2. Frontmatter complete (name, description, type, last_reviewed)?
□ 3. Description ≤ 160 chars, verb-led, keyword-rich?
□ 4. Lives in the right folder for its shape?
□ 5. If this is an ADR — immutable, linked from implementing code?
□ 6. Per-folder README updated with a one-liner for this new file?
□ 7. If runbook — every step has command + expected output + fallback?
□ 8. Links to tests/types/ADRs where appropriate (no paraphrased facts)?
□ 9. Filename + H1 + H2 are keyword-dense, not clever?
□ 10. Single-purpose — not setup+troubleshooting+architecture in one file?
```

## Folders at a glance

| Folder | Shape | What goes here |
|---|---|---|
| `docs/tutorials/` | Tutorial | Zero-to-one walkthroughs (rare; most work is how-to) |
| `docs/how-to/` | How-to | Problem-solving recipes for humans (SKILL.md for agents) |
| `docs/reference/` | Reference | Looked-up facts; prefer generated |
| `docs/system/` | Explanation | How-the-system-works; behavioral specs |
| `docs/decisions/` | ADR (reference+explanation) | Immutable architectural decisions |
| `docs/research/` | Explanation | Technical spikes, benchmark notes |
| `docs/product/` | Explanation | Competitors, users, features, ideas (per-subfolder README) |
| `docs/sessions/` | Explanation | Per-day session logs |
| `docs/meta/` | Reference | Auto-generated inventories — never hand-edit |
| `.claude/skills/` | How-to (auto-loaded) | Agent doctrine; frontmatter routing |

## Anti-patterns that force stops

- Writing prose explanation inside a SKILL.md — move it to `docs/system/` and link.
- Editing a landed ADR — supersede instead.
- A README.md that lists two files from five years ago — update on every sibling change.
- A runbook step without a command or without an expected output.
- A doc with no frontmatter — you don't know when to re-review it.
- `clever-title.md` — name it by the keywords an agent would grep for.

## References

- Pair with `repo-structure/SKILL.md` for the parallel code rules.
- `docs-governance/SKILL.md` owns the enforcement (audit stray docs, generate skills index).
- Diataxis framework: https://diataxis.fr
