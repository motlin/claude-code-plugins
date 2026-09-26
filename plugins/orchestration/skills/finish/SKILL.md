---
name: finish
description: Run the completion pipeline (commit, precommit, rebase, simplify) after completing any task, before returning control to the user. Always run this skill; it handles the case where there's nothing to do.
---

# Finish Workflow

If the working tree is clean and there is nothing to verify, report that there is nothing to finish.

In Claude Code, this may spawn the `orchestration:finish` agent. In Codex, run the workflow directly unless the user asks for subagents.

Use the caller's prompt as the commit intent. Run every applicable step, in order:

- Commit with the `git:commit` skill, distilling the caller's prompt into a single-line message. Commit before precommit because `git test run HEAD` refuses a dirty tree and tests the committed `HEAD`.
- Run the `build:precommit` skill. Cached successes pass quickly.
- Rebase with the `git:git-rebase` skill.
- Review the committed diff for reuse, quality, and efficiency, and make cleanup changes when warranted.
- If cleanup changed anything, create a fixup commit for `HEAD`.
- Run the `build:precommit` skill again.
