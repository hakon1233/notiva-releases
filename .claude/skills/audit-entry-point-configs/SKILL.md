---
name: audit-entry-point-configs
description: "When the user's prompt is open-ended audit of a project — 'review this', 'find what's wrong', 'investigate', 'check the recent work', 'something's broken' — invoke `Skill('audit-entry-point-configs')` BEFORE deep source review. The entry-point configs (package.json, next.config.*, vite.config.*, pyproject.toml, Cargo.toml, Makefile, docker-compose, Dockerfile) hold defaults, ports, scripts, and infrastructure conventions that are the most common bug site invisible to source-only review."
---

# Audit Entry-Point Configs First

Open-ended audits often miss bugs that live in **defaults and infrastructure
conventions** — config files, not source. A source-only reviewer never
notices a wrong port default, a missing build flag, or an `engines` range
that allows broken versions. These are invisible to code review and visible
the moment you open the right config.

## Do these 5 things, then move on

1. **Cat package.json in full** (not `head -50` — that truncates).
   Read every script. Note every port literal, env-var default, pre/post
   hook, `engines` range.

2. **Open every other config that exists**: `next.config.*` / `vite.config.*`
   / `webpack.config.*` / `pyproject.toml` / `Cargo.toml` / `Makefile` /
   `Dockerfile` / `docker-compose.yml` / `.env.example` / anything in
   `.config/` or `config/`.

3. **For every magic number / default you see**, cross-check against:
   - The "live URL" / "running at" hint in your task prompt.
   - README.md / AGENTS.md / CLAUDE.md mentions.
   - Other config files in this same list.

   **Two sources disagreeing on the same fact = a bug**, regardless of which
   side is "right."

4. **Grep for the same port/url across the codebase**:
   ```
   grep -rn "127.0.0.1:[0-9]\+\|localhost:[0-9]\+" src/ server/ 2>/dev/null
   ```
   If two files hard-code different ports for the same service — bug.

5. **Stop after ~5–10 turns.** This is a scoping phase, not the whole
   audit. Then move to source review.

## Examples of the pattern

- `package.json` `dev` script says `--port ${X:-A}` but the prompt's
  documented dev URL uses port B.
- `Dockerfile` `EXPOSE` is port A but `docker-compose.yml` maps port B.
- `.env.example` lists `LOG_LEVEL=info` but the README says default is
  `debug`.
- `engines.node` says `">=20"` but the README says "requires Node 22+".

## What this skill is NOT

- Not "read every file in the repo." Just entry-point configs.
- Not "run the test suite." Separate signal.
- Not "guess at defaults." Always cross-check against an authoritative source.
