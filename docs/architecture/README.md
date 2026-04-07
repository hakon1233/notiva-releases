# Architecture

System structure, component relationships, data flow, and integration patterns.

## What goes here

- High-level system diagrams and component maps
- Data flow descriptions (how data moves through the system)
- Integration specs (how this project connects to external services)
- Module boundaries (what owns what, dependency rules)
- Platform structure (directory layout, key abstractions)

## Format

One file per major system or component. Name files descriptively:
- `platform-structure.md` — overall project layout
- `auth-system.md` — authentication and authorization flow
- `data-pipeline.md` — how data is ingested, processed, stored

Keep these up to date when architecture changes. The spec-check skill (`.claude/skills/spec-check/`) will flag drift between these docs and the code.
