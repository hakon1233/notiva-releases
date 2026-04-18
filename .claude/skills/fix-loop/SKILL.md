---
name: fix-loop
description: Use PROACTIVELY when the user says "fix loop", "run the fix loop", "test the X workflow", or when /fix-loop is invoked. MUST BE USED for workflow-scoped test/fix/verify runs. Owns iteration bookkeeping and stop conditions; delegates bug-fix rhythm to `test-first` and workflow creation to `workflow-management`.
last_updated: 2026-04-18
---

# Fix Loop

Run a workflow-first fix loop for a single workflow at a time.

## Delegations (read these first)

- **`.claude/skills/session-logging/SKILL.md`** — session-log discipline (auto-loads; no duplication here).
- **`.claude/skills/workflow-management/SKILL.md`** — how to create the four workflow files if they're missing. Don't invent the layout here.
- **`.claude/skills/test-first/SKILL.md`** — red-before-green rhythm for every fix. Not restated here.

## Scope rule

- Work on exactly one workflow: the workflow the user named
- Do not broaden scope to similar or related workflows unless the user explicitly asks
- An empty per-workflow bug file does not mean the workflow is clean; always read the root bug files too
- If you discover a bug during this run that clearly also affects another workflow, still log it from this run, but do not expand the fix scope to that other workflow unless the user explicitly asks

## First reply before coding

Before you make changes, give a short report that states:
- the exact workflow you will work on
- which files are the loop state for that workflow
- whether workflow artifacts already exist or must be created
- that you will use root bug files + the per-workflow bug file together
- that you will run only workflow-relevant regression checks from `resolved.md`

## Workflow setup

If the requested workflow doesn't exist yet, follow `workflow-management/SKILL.md` to create the four artifacts (registry entry + spec + bug file + slug convention) before testing. Don't improvise the layout.

The files that drive this loop:
- `.claude/workflows.md` — how to exercise the workflow (test plan).
- `docs/system/<workflow-id>.md` — what correct behavior should be (spec).
- `.claude/bugs/{agent-reported,user-reported}.md` — open issues across the repo.
- `.claude/bugs/workflows/<workflow-id>.md` — workflow-local view of the same issues.
- `.claude/bugs/resolved.md` — only the resolved bugs relevant for this workflow get regression-checked.

## Pre-flight

Read these before the first iteration:
- `.claude/workflows.md`
- `docs/system/<workflow-id>.md`
- `.claude/bugs/agent-reported.md`
- `.claude/bugs/user-reported.md`
- `.claude/bugs/resolved.md`
- `.claude/bugs/workflows/<workflow-id>.md`

Treat open user-reported bugs for the workflow as required work.
If the root bug files and the per-workflow file disagree, do not guess; reconcile them explicitly.

## Loop

Repeat up to 5 iterations:

1. Run the workflow checks from `.claude/workflows.md` for this workflow only
2. Run only the regression checks from `resolved.md` that belong to this workflow or clearly cover the same behavior
3. Triage findings into:
   - sure-fix
   - regression
   - already-known
   - needs-user-input
4. **For each sure-fix or regression, follow `.claude/skills/test-first/SKILL.md` Steps 0-6 for the full bug-fix rhythm.** That skill owns red-before-green, reproducer file conventions, the layered regression defense, cross-file bug tracking, restart discipline, and commit rules. This loop owns workflow selection and stop conditions — not the bug-fix rhythm. Do not duplicate test-first's content here; read and follow it.
5. Stop when no sure-fix issues remain and only `needs-user-input` items are left

## Bug handling rules

- Every bug must link to the workflow
- Keep root bug files and per-workflow bug file aligned
- Do not treat the per-workflow bug file as the only source of truth
- If a bug discovered in this workflow run also affects another workflow, log that cross-workflow impact explicitly, but keep the active fix loop scoped to the current workflow unless the user expands scope
- Do not silently drop old bugs just because a new run passed
- Resolved bugs must keep a regression check
- If the user reports more bugs after review, add them to the bug files and run the loop again

## Guardrails

- Never claim a fix without red-to-green evidence
- Do not refactor outside the workflow scope
- Do not close uncertain items as fixed
- Keep the loop focused on one workflow at a time
- Stop after 5 iterations max
