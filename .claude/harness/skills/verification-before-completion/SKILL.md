---
name: verification-before-completion
description: "ALWAYS invoke `Skill('verification-before-completion')` before saying \"done\", \"fixed\", \"shipped\", \"ready\", or marking any task complete. Do not claim success directly, do not rely on \"should work\" / \"looks good\" reasoning, and do not skip verification because the change feels small — use this skill first; it owns which verification command to run (test run, build, type-check, lint, manual probe) and requires that command to appear in the same assistant turn as the success claim."
last_updated: 2026-05-02
---

# Verification Before Completion

## The Iron Law

**No completion claim without fresh verification evidence in the same turn.**

If you are about to write any of these phrases, stop:

- "Done."
- "Fixed."
- "Shipped."
- "Ready."
- "All tests pass." / "Tests are green."
- "This should work."
- "I think that's it."
- "That should resolve the issue."
- "Looks good."
- "Should be good now."
- "Just push and it'll go through."

…then check: does the same assistant turn contain a tool call whose **fresh output** proves the claim?

If no, run the verification first. Then the claim. Same turn.

If the verification ran in an *earlier* turn, it doesn't count. State changes between turns: a file got edited, a dep got bumped, the user gave a new instruction, an autopull cycle pulled new code. Stale evidence is no evidence.

## Why this rule exists

Without it, the model rationalises completion claims from prior context ("the test passed three turns ago, the change since is small, it's probably fine"). Several real failure modes today were "should work" claims followed by red CI / broken prod / regressed reproducer. The cost of running the verification once more is seconds. The cost of a false-completion claim is the user trusting it and shipping.

This rule is the runtime check that backstops `engineering-standards` rule 2 ("first-run correctness"). Both must hold.

## Verification ladder — pick the cheapest sufficient evidence

| Claim | Required fresh evidence |
|---|---|
| "tests pass" / "test added" | `npx vitest run <path>` output in this turn |
| "build works" / "compiled" | `npm run build` (or `tsc --noEmit`) in this turn |
| "lint clean" | `npm run lint` (or `eslint <file>`) in this turn |
| "type-clean" | `npx tsc --noEmit` in this turn |
| "bug fixed" | the failing reproducer (red) → fix → reproducer (green), all in this turn or previous (with the green output visible) |
| "feature works" | manual probe via curl / chrome-mcp / playwright run — output in this turn |
| "deployed" | the deploy command's success output (e.g. `git push origin stable` exit 0) in this turn |
| "commit landed" | `git log -1 --format=%H` showing the SHA in this turn |
| "config changed" | `cat <file>` or `git diff --stat` showing the change in this turn |
| "service restarted" | the restart command's success output in this turn |

If you can't find a fresh verification fit for the claim, the claim is not yet justified. Don't make it.

## The rationalization table

These are the ways the rule gets violated. Recognize them before the model writes them.

| Rationalization | What's actually happening | Correction |
|---|---|---|
| "I just made a small change, the tests still pass." | Tests haven't been run since the change. | Run them. Same turn. |
| "Type-checking already passed in turn N." | Files have changed since turn N. | Re-run `tsc --noEmit`. |
| "The repro was green earlier — let me skip running it." | The repro is the *only* evidence the bug is fixed. | Run it. Without exception. |
| "It's just a docs/comment change." | Docs builds and links can break too. If you're claiming "docs updated and live," verify. | Run the docs build, or just say "wrote the doc, didn't deploy" — accurate is fine. |
| "I'll claim it works and the user can tell me if not." | Externalizing the verification cost onto the user. | The user pays you to run it. Run it. |
| "The CI will catch it." | Maybe. The user is reading your message now. | Run the relevant check locally first. |
| "This is the kind of change that doesn't need testing." | The model doesn't get to declare what doesn't need testing. The rule does. | Use the ladder above. There IS a verification for every claim. |
| "I refactored — the tests didn't change." | A refactor that broke nothing should still produce a green test run. | Run them. |

## Banned phrases without evidence

These are status-signaling phrases the model uses to *sound* done. Banned in the same message that lacks a fresh tool-call verification:

- "Great!" / "Perfect!" / "Excellent!"
- "Done." / "Fixed." / "Shipped." / "Ready."
- "All set." / "All good." / "Looks good."
- "That should do it." / "That should work."

If the verification ran and you have its fresh output in this turn, these are fine — you've earned them. If not, write what you actually did and what you didn't verify. Honest is better than performative.

## When the verification fails or can't run

State that:

- "Tried `npm run test`, 3 tests failed: <names>." → not done; back to work.
- "Build hangs in this environment, can't verify." → not done; surface the blocker, don't claim success.
- "I edited the config but I can't reach the deploy host from here." → "config changed; deploy not verified; user, please confirm."

**Honest "I can't verify" beats fake "done."** Always.

## How this composes with other skills

- **`test-first`**: produces the reproducer evidence the verification ladder needs for bug-fix claims.
- **`engineering-standards` rule 2 (first-run correctness)**: the design-time half. This skill is the runtime check.
- **`commit`**: a commit is a completion claim. Pre-commit verification (build + tests + lint) is mandatory; this skill is what enforces "ran them in this turn, not three turns ago."
- **`completion-report`** (orchestrator-side): every Done/Evidence bullet in a worker's completion report cites a fresh tool-output line. Same principle.

## Recovery from a missed verification

If you notice — mid-message, post-message, in the next turn — that you made a completion claim without fresh evidence:

1. Stop the next thing.
2. Run the verification now.
3. If it passes: a brief "verified now: <output>". If it fails: "claim was wrong, here's what's actually broken, fixing now."

No silent self-correction; no pretending the prior claim was conditional. Be visible.
