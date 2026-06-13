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

- Run precommit checks with the `precommit` skill when available.
- Commit with the `git-commit` skill when there are changes to commit.
- Rebase with the `git-rebase` skill after committing when appropriate.
- If additional cleanup changes are made, create a fixup commit for `HEAD`.
- Run precommit checks again when changes were made.

## No-Commit Mode

When the prompt contains `no-commit`:

- Do not commit, stage, or rebase.
- Run validation when practical.
- Leave changes for the caller.
