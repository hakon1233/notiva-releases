---
name: module-map
description: "Before creating a new module, splitting an existing one, scoping a worker task, planning where a feature lives, or making an Edit that crosses multiple subsystems: invoke `Skill('module-map')` and use its deep-modules-with-narrow-interfaces map (plus `LANGUAGE.md` vocabulary contract) to scope to one well-bounded unit."
last_updated: 2026-04-30
---

# Module Map — what lives where, with what interface

**Read `LANGUAGE.md` (sibling file) BEFORE proposing any architecture
change.** It is the vocabulary contract: which words are canonical
("module / interface / seam / adapter / depth-as-leverage / locality")
and which are banned ("boundary / API / service / util / wrapper /
port-without-two-adapters"). Coherent vocabulary is load-bearing —
when it drifts, the design under it is usually wrong too.

A "deep module" is one with a narrow public interface and substantial behavior behind it. Workers operate best on deep modules: the interface is small enough to fit in context, the behavior is rich enough to do useful work, and tests at the interface level catch regressions cleanly. Depth here means **leverage** — what the caller gets to *not* think about — not the lines-of-implementation ratio.

A "shallow module" has the inverse — wide public surface, thin behavior. It costs an agent the same context to load but returns less leverage per turn. Shallow modules are why workers grep across the whole repo: they can't tell where the actual logic lives.

This skill is the project's deliberate map of major modules: their public interface, their internal seams, and the rules for when a worker should treat a task as scoped to one module vs spanning many.

## The deletion test

Before designing or accepting any module, run the deletion test:

> Mentally delete the module. Walk through what happens to its callers.
> If the complexity vanishes — if the callers don't need the work the
> module was doing — the module was a pass-through. Inline it.

This is the cheapest architecture review you can do; run it BEFORE
designing the interface. See `LANGUAGE.md` for examples + how it
combines with the "interface is the test surface" rule and the
"two adapters or no port" rule.

## How this works

1. Every project has a `MODULE_MAP.md` at its root (or a `## Module map` section in `AGENTS.md`).
2. For each major module, the map lists: directory, public exports (the narrow interface), internal sub-modules (the deep behavior), and one-sentence purpose.
3. Workers consult the map BEFORE planning a task. If the task fits inside one module's public interface, scope to that module. If it requires crossing modules, escalate to the orchestrator before writing code.
4. The orchestrator owns the map. Workers don't add modules without escalation; renaming or restructuring a module is always an orchestrator decision.

## Format

```markdown
# Module Map

## src/lib/openclaw/
**Purpose:** every interaction with the openclaw agent runtime.
**Public interface:** `chatSend`, `dispatchWorker`, `restartAgent`.
**Behind it:** SOUL templates, skill catalog, gateway client, retry/failover.
**Worker scope:** changes here are orchestrator-side; never touched from a worker dispatched into a managed project.

## src/lib/events/
**Purpose:** telemetry — capture, ingest, query.
**Public interface:** `emitEvent`, `writeEvent`, `readEvents`, `EventEnvelope`.
**Behind it:** schema, paths resolution, harness-version tagging, daily JSONL files.
**Worker scope:** if you're adding an event type, it's safe to scope here. Crossing to the consumer (find-friction-patterns or fix-plan UI) is a separate task.
```

## When to consult

- **Before planning a task** — is this one module's responsibility, or does it cross? If it crosses, the task probably needs to be split.
- **Before introducing a new module** — does the new behavior actually fit existing modules? Most "I need a new module" cases are actually "this concept needs to live deeper inside an existing module."
- **Before changing a public interface** — that's an orchestrator-level decision. The map shows what's public; if you'd be widening the public surface, escalate.

## Deep vs shallow — concrete signals

Deep:
- Public interface is < 5 exports.
- Each export does one substantial thing (returns useful objects, not just thin wrappers).
- Internal sub-modules are private — callers don't reach into them.
- Tests at the public interface cover the module's behavior.

Shallow (avoid):
- Public interface is > 20 exports.
- Exports are mostly type aliases or re-exports.
- Internal sub-modules are routinely imported from outside (the public interface isn't load-bearing).
- Tests are scattered across files because the module has no clear seam.

## Anti-patterns this skill rules out

- **`utils.ts` / `helpers.ts` / `common.ts`** — these are by definition shallow and grow without bound. Repo-structure skill already forbids these names; this skill explains why: they're the opposite of deep modules.
- **Reaching into internals** — importing from `src/lib/openclaw/internal/foo` instead of using `src/lib/openclaw`'s public interface. If the public interface doesn't expose what you need, that's a design conversation with the orchestrator, not a unilateral fix.
- **Cross-module Edits in one task** — a worker's diff touching three subsystems is a sign the task wasn't scoped right. Pause, escalate, get the task split.

## Updating the map

1. Worker proposes the new module / boundary change in chat: "I want to split `src/lib/openclaw/` into `chat/`, `dispatch/`, `agents/` because chatSend has grown 800 lines. The public interface stays the same; this is internal-only."
2. Orchestrator (or user) approves the boundary.
3. The orchestrator owns the actual edit to `MODULE_MAP.md`. Workers don't write to it.
