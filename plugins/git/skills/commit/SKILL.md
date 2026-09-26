---
name: commit
description: Commit local changes with careful staging and single-line messages. Use for all git commit operations.
---

# Commit

Use the `code:cli` and `git:git-workflow` skills.

When the user invokes this skill directly (`/git:commit`), delegate to the `git:commit-handler` agent. When the skill is loaded as guidance for a commit you are already making, or no subagent is available (for example in Codex), follow the procedure below inline.

## Inspect Context

```bash
git status
git diff --cached
git diff
git branch --show-current
git log --oneline -10
```

## Stage Files

Stage only the files modified for the current task, individually:

```bash
git add <file1> <file2>
```

Never use `git add .`, `git add -A`, `git commit -am`, or anything else that stages unrelated changes.

## Commit Message

If the user pasted a compiler or linter error, or the task is explicitly a fixup for a known commit, use `git commit --fixup <sha>`.

Otherwise write one line following the format in `git:git-workflow`. The prompt is the intent, not the message text: borrow its language, but distill a long or multi-line prompt to one line.

Echo exactly:

```text
Running: `git commit --message "<message>"`
```

Then commit without confirming again with the user:

```bash
git commit --message "<message>"
```

If pre-commit hooks modify files, stage those files individually and retry. Never use `git commit --no-verify`.
