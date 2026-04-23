---
name: repo-structure
description: Use PROACTIVELY before creating a new file, moving a module, introducing a new directory, or refactoring folder layout. MUST BE USED when you're about to write "utils.ts", "helpers.ts", "common.ts", add a file over 500 lines, or nest code more than 4 levels deep. Encodes the 13 measured principles that make this codebase agent-friendly.
last_updated: 2026-04-24
---

# Repo Structure

Thirteen rules. Each one cuts a concrete class of agent mistake. If you're about to violate one, stop and re-plan.

## Size + depth

### 1. File size ≤ 300 lines soft, 500 hard
Agents are ~40% more accurate on files under 300 lines (Google ADK, Feb 2026). At 500+ they start hallucinating nearby code that doesn't exist. If a file passes 300, plan a split; if it passes 500, do not add to it — extract first.

### 2. Directory depth ≤ 4 levels from repo root
Deep paths inflate every tool call and every `ls` output. `src/a/b/c/d/e/file.ts` is a signal the domain needs a different slice, not deeper nesting.

## Naming

### 3. Domain-verb names — never utils / helpers / common / shared / misc
Files named `invoice-validator.ts` / `order-processor.ts` had **23% fewer hallucinations** than dumping-ground `utils.ts`. If you want to write `utils.ts` or `helpers.ts`, you haven't named the domain yet. Stop and name it.

### 4. Specific identifiers — no `data`, `item`, `handle*`, `process*`
Generic symbol names inflate hallucination rate. Use the noun the domain actually uses: `invoice`, `payload`, `row`, `customerId`.

## Layout

### 5. Feature-sliced (vertical) over layer-sliced
Prefer `src/invoices/{component,hook,api,test}.ts` over `src/components/Invoice.ts + src/hooks/useInvoice.ts + src/api/invoices.ts`. Co-location means retrieval returns one directory instead of three. Exception: truly cross-cutting concerns (auth, logging) may stay layered.

### 6. Co-locate tests next to source
`invoice-generator.test.ts` lives next to `invoice-generator.ts`. ~15% fewer test-related mistakes. Detached `__tests__/` dirs hide the test from the agent's line-of-sight.

### 7. One config root — not one per package
Multiple `tsconfig.json` / `eslint.config.js` with similar names cause wrong-file edits. Single root config with overrides; only split when a package genuinely needs different settings.

## API shape

### 8. Named exports only, no defaults
Agents rename defaults inconsistently across re-imports. `export function foo() {}` beats `export default function foo() {}`. Default exports are allowed only in framework-required locations (Next.js `page.tsx`, etc.).

### 9. Explicit `index.ts` at module/package boundaries — NOT deep barrels
Package entry points get an `index.ts` that enumerates the public API. Deep barrels (re-exports from every folder) break go-to-definition and inflate the import graph agents traverse. One barrel per package, not one per folder.

### 10. Acyclic import graph, cap fan-in at ~20
Files imported by more than ~20 other files become god-modules — the top source of failed agent patches in SWE-bench error analyses. Cycles are always a bug.

## Type + doc density

### 11. TypeScript strict mode, explicit return types on public functions
Agents fix typed code correctly 94% of the time vs 67% untyped (ts-bench, 2025). `strict: true` is non-negotiable; public functions get explicit return types so callers don't need to infer.

### 12. One-line JSDoc on every exported function
Documented functions are called correctly **3× more often**. One line describing *purpose* (not implementation) is enough. Skip it only for trivially-named getters.

## Scope

### 13. Scoped `AGENTS.md` / `CLAUDE.md` per non-trivial subdirectory
For any directory over ~20 files with its own conventions, add a short `AGENTS.md` describing naming, test command, and module boundaries. Nearest-file wins — local context without bloating the root.

## The checklist — run before creating or moving a file

```
□ 1. Under 300 lines? (Hard stop at 500.)
□ 2. Depth ≤ 4 from repo root?
□ 3. Name describes the domain (not utils/helpers/common)?
□ 4. Symbol names are specific, not generic?
□ 5. Feature-sliced — tests and related code live together?
□ 6. Test file co-located (.test.ts next to .ts)?
□ 7. Uses the root config (not a new tsconfig)?
□ 8. Named exports only?
□ 9. Public API behind one package-level index.ts, no deep barrels?
□ 10. No new cycle; no import fan-in over 20?
□ 11. Explicit return types on public functions?
□ 12. One-line JSDoc on exports?
□ 13. If directory now has its own conventions, does it have a scoped AGENTS.md?
```

## Anti-patterns that force stops

- Creating `lib/utils.ts` / `lib/helpers.ts` / `lib/common.ts` — name the domain instead.
- Files passing 500 lines — extract before adding.
- `src/components/feature/deeply/nested/widget/button.tsx` — collapse depth.
- Re-exporting everything from a nested `index.ts` — that's a barrel, break it.
- `export default` in application code.
- Cyclic imports — always a design bug.

## What to do when a principle conflicts with the request

- **Surface the tradeoff** — "This would push the file past 500 lines; I'd rather split it into X and Y. OK?"
- **Don't silently comply** — the rules exist because violations compound.
- **Don't refuse** — state the cost, get consent, proceed.

## References

- Pair with `engineering-standards/SKILL.md` for the six build-quality stop rules.
- Pair with `docs-writing/SKILL.md` for the parallel docs rules.
- The operations auditor's `find-friction-patterns` extractor scans the repo for violations (files >500 lines, depth >4, fan-in >20, generic names) and emits findings to `/fix-plan`.
