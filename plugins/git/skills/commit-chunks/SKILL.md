---
name: commit-chunks
description: Split local changes into multiple logical commits. Use when the user asks to commit changes in chunks or as several commits.
---

# Commit Chunks

📝 Commit the local changes to git. Analyze the local changes and propose splitting them into multiple logical commits.

ALWAYS use the `code:cli` and `git:git-workflow` skills.

## Inspect Context

Run:

```bash
git status
git diff --cached
git diff
git branch --show-current
git log --oneline -10
```

## Propose the Split

For each proposed commit, show the message and the list of files. Show all proposals at once. Wait for the user's confirmation, then commit all of them.

## File Staging

- 📦 Stage files individually using `git add <file1> <file2> ...`
- NEVER use commands like `git add .`, `git add -A`, or `git commit -am` which stage all changes
- Only stage files that were explicitly modified for the current task

## Commit Message Creation

- 🐛 If the user pasted a compiler or linter error, create a `fixup` commit using `git commit --fixup <sha>`
- Otherwise write one single-line message that follows `git:git-workflow`:
    - Start with a present-tense verb (Fix, Add, Implement, etc.)
    - Be concise (60-120 characters)
    - Be a single line
    - End with a period.
    - Borrow language from the original prompt
    - Avoid praise adjectives (comprehensive, robust, essential, best practices)
- Echo exactly this: Running: `git commit --message "<message>"`

## Pre-commit Hooks

When pre-commit hooks fail:

- Stage the files modified by the hooks individually
- Retry the commit
- Never use `git commit --no-verify`
