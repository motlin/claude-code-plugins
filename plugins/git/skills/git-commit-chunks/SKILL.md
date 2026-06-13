---
name: git-commit-chunks
description: Split local changes into multiple logical commits. Use when the user asks to commit changes in chunks.
---

# Git Commit Chunks

Use the `code:cli` and `git-workflow` skills.

Inspect local state:

```bash
git status
git diff --cached
git diff
git branch --show-current
git log --oneline -10
```

Analyze the changes and propose multiple logical commits. Show all proposed commit messages and file lists at once, then wait for confirmation before committing.

For each approved commit:

- Stage files individually with `git add <file1> <file2>`.
- Never use `git add .`, `git add -A`, or `git commit -am`.
- Commit with a single-line message following `git-workflow`.
- If hooks modify files, stage those files individually and retry.
- Never use `git commit --no-verify`.
