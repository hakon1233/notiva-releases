# .claude/harness/ — AUTO-MANAGED, READ-ONLY

Everything in this directory is owned by the TTM harness and regenerated on
every harness version bump. After bootstrap, files are `chmod a-w` — agent
write attempts will get EACCES.

**Never edit anything here.** Your edits will be lost on the next deploy.
To customize something for this project, add it to `.claude/project/`.

To change the harness itself: edit the template in the TTM repo, bump the
harness version (`bash scripts/harness/bump-version.sh ...`), push `stable`.
The autopull + bootstrap pipeline propagates to every managed repo.
