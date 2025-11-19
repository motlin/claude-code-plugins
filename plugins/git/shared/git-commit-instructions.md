## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

## Task

1. **File Staging**

- 📦 Stage files individually using `git add <file1> <file2> ...`
- NEVER use commands like `git add .`, `git add -A`, or `git commit -am` which stage all changes
- Only stage files that were explicitly modified for the current task

2. **Commit Message Creation**

- 🐛 If the user pasted a compiler or linter error, create a `fixup` commit using `git commit --fixup <sha>`
- Otherwise commit messages should:
- Start with a present-tense verb (Fix, Add, Implement, etc.)
- Be concise (60-120 characters)
- Be a single line
- End with a period.
- Borrow language from the original prompt
- Avoid praise adjectives (comprehensive, robust, essential, best practices)
- Echo exactly this: Running: `git commit --message "<message>"`
- 🚀 Run git commit without confirming again with the user.

3. **Pre-commit hooks**

When pre-commit hooks fail:

- Stage the files modified by the hooks individually
- Retry the commit
- Never use `git commit --no-verify`
