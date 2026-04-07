Run the fix loop: read `.claude/skills/fix-loop/SKILL.md` and `.claude/workflows.md`, then execute the full test-fix-verify cycle.

1. Read `.claude/skills/fix-loop/SKILL.md` for the complete workflow
2. Read `.claude/workflows.md` for testable workflows
3. Run pre-flight checks (bug files, system readiness, current commit)
4. Execute the loop: test each workflow → triage → fix sure things → deploy → verify → repeat
5. Stop when no more "sure fix" items remain
6. Report results: what was fixed, what needs user input, regression status
