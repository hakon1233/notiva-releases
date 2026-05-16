---
name: module-improvement-team
description: "When the user says \"run your round\", \"work your module\", \"propose your r<N> change\", or this session is a long-lived module-improvement agent (testing-loop, bug-hunt, router-benchmarks, scenario-benchmarks, custom-benchmarks, worker-benchmarks, repo-maintenance, or any future module agent) doing analysis-then-propose work: invoke `Skill('module-improvement-team')` BEFORE writing the proposal. It owns the 7-teammate council protocol — when to dispatch which specialist, the message budget, the memory contract, and the closeout that produces `runtime/night-shift/round-<N>/<module>/proposal.md`."
---

# Module-improvement team — the 7-teammate council

> **Mechanism.** This council uses Claude Code's **built-in Agent
> Teams** feature (gated by the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
> env var, available since Feb 2026). The module session is the
> **team lead**; it spawns teammates via the team primitive and they
> reach each other directly. We do NOT roll our own messaging or
> persistence — only the agent prompts (the seven `team-*.md` files
> under `.claude/agents/`) and the operating protocol below are
> customised. Teammates are scoped to ONE team — they only talk to
> the lead and to each other inside that team, not across teams.
> Each module (bug-hunt, repo-maintenance, …) has its own
> independent team.

## Why this exists

A single LLM session writing a harness-improvement proposal tends
toward one of two failure modes: it under-thinks (ships the first
plausible hypothesis without checking alternatives) or it over-thinks
(piles speculation on speculation with no pushback). Both produce
proposals that drift between rounds.

This skill installs a small fixed council of specialists. The module
session is the **team lead**. Before writing a proposal, the lead
dispatches teammates via the `Agent` tool, collects their perspectives,
synthesizes, and writes the proposal. Each teammate is read-only and
returns a structured perspective; only the lead writes the proposal.

This is NOT the same as the harness's existing `bug-fixer` / hunter
agents. Those are tactical workers used INSIDE a benchmark trial. The
council operates ABOVE that — it improves the harness ITSELF based on
what the workers did.

## The 7 teammates

All live under `.claude/agents/team-*.md` and are dispatched via
`Agent(subagent_type='team-<name>')`. Each is read-only (no Edit/Write
tools); only the lead writes.

| Teammate | Role | Authority | When to dispatch |
|---|---|---|---|
| `team-logs-analyst` | Reads campaign data, transcripts, sub-agent JSONLs. Reports "what happened" and "what worked vs didn't" across this run + relevant prior runs. | Advisory (evidence) | Always, first |
| `team-history-librarian` | Reads prior `runtime/night-shift/round-*/<module>/proposal.md`. Reports what's been proposed, what shipped, what was deferred and why. | Advisory (precedent) | Always, second |
| `team-creative` | Wild proposals — speculative directions, unconventional rephrasings, "what if" reframings. | Advisory (brainstorm) | When the obvious move is small or unclear |
| `team-web-researcher` | OUTSIDE-the-project research only — Anthropic docs, blog posts, forums, prior art in other harness projects. Never reads this repo. | Advisory (prior art) | When the bottleneck has a name that others may have hit |
| `team-hypothesis-tester` | "Given hypotheses A/B/C, what's the cheapest experiment that distinguishes them?" Designs the diagnostic that would falsify each candidate. | Advisory (experiment design) | When 2+ hypotheses explain the data |
| `team-statistician` | Pushes back on causal claims from tiny samples. Computes confidence intervals, flags sample-size issues, recommends "run N more before shipping". | Advisory (statistical) | When the proposal hinges on a small-sample observation |
| `team-conservative` | Rule-guard. Flags "this looks like cheating", "this contradicts ADR-X", "you can't ship that without a harness bump". | Advisory; concerns MUST appear in the proposal's Risks section. | Always, last (after lead has drafted) |

**Authority model.** All teammates are **advisory**. The team lead
decides what to ship. But two of the teammates have a **declaration
right**: if `team-conservative` or `team-statistician` raise a concern,
the lead MUST acknowledge the concern explicitly in the proposal's
Risks section. Silently overriding either is the failure mode this
council exists to prevent.

## The protocol (run in this order)

### Step 1 — Load shared memory

```
mkdir -p runtime/team-memory/<MODULE>/
cat runtime/team-memory/<MODULE>/MEMORY.md 2>/dev/null
```

If `MEMORY.md` exists, read it. It's the team lead's accumulated
knowledge across rounds: what's been tried, what worked, what
patterns recur. Teammates also read this file at start of their
dispatch.

### Step 2 — Dispatch the two evidence teammates IN PARALLEL

In a single message with two tool calls:

```
Agent(subagent_type='team-logs-analyst',
      prompt='<module>, round <N>. Read campaign(s) <id> and prior
              relevant runs. Report what happened, what worked vs
              didn't, and any patterns versus prior rounds. ...')
Agent(subagent_type='team-history-librarian',
      prompt='<module>, round <N>. List what was proposed in
              rounds N-3 through N-1, what shipped, what was
              deferred and why. Flag any reproposals that need a
              fresh decision. ...')
```

Wait for both to return before doing anything else.

### Step 3 — Decide if creative + web-research + hypothesis-tester are needed

Based on logs + history:

- **Creative**: dispatch when the obvious next move is small, when
  prior rounds tried the obvious moves, or when the team is in
  steady-state and needs a new angle.
- **Web-research**: dispatch when the bottleneck has a name a stranger
  might have hit ("Anthropic 5-hour rate limit handling", "SIGTERM
  at 10min CLI"). Skip when the issue is local to this codebase.
- **Hypothesis-tester**: dispatch when 2+ explanations for the data
  exist and you don't know how to choose. Skip when there's only one
  hypothesis on the table.

Dispatch the chosen ones in parallel (same-message multiple tool calls).

### Step 4 — Lead drafts the proposal

Synthesize the perspectives. The proposal goes to
`runtime/night-shift/round-<N>/<module>/proposal.md` with the
structure:

```markdown
# Round-N proposal — <module>

## TL;DR — headline + 2-3 bullets

## What I observed
... (from team-logs-analyst + your own reading)

## What I propose to change
... (the actual diff)

## Why this should help
... (mechanism)

## Risks
... (team-conservative + team-statistician concerns, even if you
disagree — explicitly acknowledge what they flagged)

## Alternatives considered
... (team-creative's wilder options, why you didn't pick them)

## Experimental plan (if applicable)
... (team-hypothesis-tester's diagnostic)
```

### Step 5 — Dispatch team-statistician + team-conservative AFTER drafting

These two read your draft, NOT just your data. They flag issues with
the SHIP DECISION:

```
Agent(subagent_type='team-statistician',
      prompt='Read runtime/night-shift/round-<N>/<module>/proposal.md.
              Is the causal claim supported by the sample? What
              minimum-sample-size would make the claim robust?')
Agent(subagent_type='team-conservative',
      prompt='Read runtime/night-shift/round-<N>/<module>/proposal.md.
              Does this respect the anti-cheating rules? ADRs?
              Module boundaries? Existing skill / agent contracts?')
```

If they raise concerns, append to the Risks section. **If you disagree
with their concern, write WHY in the Risks section** — don't silently
override.

### Step 6 — Lead updates shared memory

```
runtime/team-memory/<MODULE>/MEMORY.md
```

Append a section for this round. Recommended template:

```markdown
## Round <N> — <one-line headline>

**Shipped:** <yes / no / partial — what>
**Key finding:** <what the team learned>
**Tried & rejected:** <what creative or hypothesis-tester offered that wasn't taken>
**For next round to remember:** <state that must survive round boundaries>
```

Keep the file under ~5KB total. Compress old entries when it grows.

## Turn budget — quality over conservation

**No hard cap.** Producing a well-reasoned proposal is more valuable
than minimising tokens. Use whatever the team needs, including many
follow-up dispatches if specialists want to ask each other questions.

Sane defaults the lead should aim for:

- 1 logs-analyst (always)
- 1 history-librarian (always)
- 0–1 creative (when an obvious move isn't clear)
- 0–1 web-researcher (when the bottleneck has a name others may have hit)
- 0–1 hypothesis-tester (when 2+ explanations compete)
- 1 statistician (always, post-draft)
- 1 conservative (always, post-draft)
- + as many follow-up dispatches as the conversation needs

**Stop conditions** — what tells the lead the team has converged:

- All specialists have reported and the lead can write the proposal
  without further open questions.
- The remaining open questions can't be answered from data the team
  has access to (e.g. needs a new campaign run, or orchestrator-
  level diagnosis the lead can't perform).
- The proposal has been drafted and both declarative-authority
  teammates (statistician + conservative) have reviewed it.

**Don't stop early** just because the team has dispatched a lot. If
the work isn't done, keep going. Council-spiral (teammates re-asking
each other the same question) IS a failure mode worth catching, but
that's distinct from "lots of dispatches because the work is hard".
The lead can call a halt if the same question recurs >3 times — that
means the question has no answer from the available data, and the
proposal should record that explicitly rather than burn more
dispatches.

## When NOT to convene the full council

Trivial rounds (router at 100% steady-state, scenario dispatcher-still-
gapped, etc.) only need logs-analyst + history-librarian, both
confirming "nothing changed". Skip the rest, write a 3-line "empty
round" proposal, append "Round N — empty" to MEMORY.md.

## Recursive teams (for hard tasks)

Long benchmark trials that test multi-step worker behavior CAN use the
same pattern recursively — a worker session dispatched by the runner
may itself convene a smaller council (e.g. logs-analyst +
hypothesis-tester) before deciding what to fix in the victim repo.
This is opt-in per benchmark and should be documented in the
benchmark's worker-prompt. Don't make it the default — most benchmarks
want a single-worker baseline.

## Anti-cheating boundaries

- Teammates are read-only. Only the lead writes.
- No teammate may write to `templates/claude-project-template/`,
  `harness-versions.json`, `.meta-harness/`, or any source-of-truth
  file. The PreToolUse harness gate enforces this.
- `team-conservative` is the canary; if it stops flagging anything
  for 3+ rounds, audit it — likely it has drifted into
  yes-and-ing the lead.

## Memory hygiene

`runtime/team-memory/<MODULE>/MEMORY.md` is the only persistent state.
Do not write per-teammate memory files; the lead is the single writer.

The file is gitignored (under `runtime/`); it's machine state, not
source. Sync to the vault if useful for review, but it lives outside
the harness contract.
