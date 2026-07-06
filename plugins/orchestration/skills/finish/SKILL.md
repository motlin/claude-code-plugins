---
name: finish
description: This skill should be used after completing any task, before returning control to the user. Always run this skill — it handles the case where there's nothing to do.
---

# Finish Workflow

Run the completion pipeline before returning control to the user. If the working tree is clean and there is nothing to verify, report that there is nothing to finish.

In Claude Code, this may spawn the `orchestration:finish` agent. In Codex, run the equivalent workflow directly unless the user explicitly asks for subagents.

Use the caller's prompt as the commit intent.

When the caller must not commit (for example `/build:fix`, which leaves changes uncommitted), include `no-commit` in the prompt.

## Standard Mode

Run every applicable step below in order. Commit before precommit because `git test run HEAD` refuses to run on a dirty tree and tests the committed `HEAD`, not the working tree.

- Commit first with the `git-commit` skill when there are changes to commit. Pass the caller's prompt as the commit intent; distill it into a single-line commit message instead of copying it verbatim.
- Run precommit checks with the `precommit` skill. It runs `git test run HEAD` on the now-clean tree and cached successes pass quickly.
- Rebase with the `git-rebase` skill after committing.
- Review the committed diff for reuse, quality, and efficiency. Make cleanup changes when warranted.
- If cleanup changes were made, create a fixup commit for `HEAD`.
- Run precommit checks again. Same rule: use `git test run HEAD` through the `precommit` skill.

## No-Commit Mode

When the prompt contains `no-commit`:

- Do not commit, stage, or rebase.
- Run validation when practical.
- Leave changes for the caller.
