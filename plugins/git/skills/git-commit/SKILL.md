---
name: git-commit
description: Commit local changes with careful staging and single-line messages. Use for all git commit operations.
---

# Git Commit

Use the `code:cli` and `git-workflow` skills.

## Inspect Context

Run:

```bash
git status
git diff --cached
git diff
git branch --show-current
git log --oneline -10
```

## Stage Files

Stage files individually:

```bash
git add <file1> <file2>
```

Never use `git add .`, `git add -A`, `git commit -am`, or other commands that stage unrelated changes.

## Commit Message

If the task is explicitly a fixup for a known commit, use:

```bash
git commit --fixup <sha>
```

Otherwise write one single-line message that follows `git-workflow`:

- Present-tense verb first.
- 60-120 characters.
- Ends with a period.
- No body.
- No praise adjectives.

Echo exactly:

```text
Running: `git commit --message "<message>"`
```

Then run:

```bash
git commit --message "<message>"
```

If pre-commit hooks modify files, stage those files individually and retry. Never use `git commit --no-verify`.
