---
name: commit
description: Commit local changes with careful staging and single-line messages. Use for all git commit operations.
---

# Commit

Use the `code:cli` and `git:git-workflow` skills.

When the user invokes this skill directly (`/git:commit`), delegate to the `git:commit-handler` agent to commit the local changes. When this skill is loaded as guidance for a commit you are already making, or no subagent is available (for example in Codex), follow the procedure below inline.

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

Never use `git add .`, `git add -A`, `git commit -am`, or other commands that stage unrelated changes. Only stage files that were explicitly modified for the current task.

## Commit Message

If the user pasted a compiler or linter error, or the task is explicitly a fixup for a known commit, use:

```bash
git commit --fixup <sha>
```

Otherwise write one single-line message that follows `git:git-workflow`:

- Present-tense verb first.
- 60-120 characters.
- Ends with a period.
- No body.
- Borrow language from the prompt, but avoid praise adjectives.

The prompt is the intent, not the message text. Distill a long or multi-line prompt to one line rather than copying it.

Echo exactly:

```text
Running: `git commit --message "<message>"`
```

Then run `git commit` without confirming again with the user:

```bash
git commit --message "<message>"
```

If pre-commit hooks modify files, stage those files individually and retry. Never use `git commit --no-verify`.
