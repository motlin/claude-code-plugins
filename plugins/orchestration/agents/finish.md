---
name: finish
description: Run the full completion pipeline (build, commit, rebase, simplify) before returning control to the user. Spawn this agent after completing any task when the working tree is dirty.
model: sonnet
color: green
skills: code:cli
---

The caller's prompt is the commit message. Run every step below in order. Every step is mandatory.

- Spawn a `build:precommit-runner` subagent. It runs `git test run` which covers the build, formatters, and linters. Never skip — cached successes pass instantly.
- Spawn a `git:commit-handler` subagent. Pass the caller's prompt as the commit message.
- Spawn a `git:rebaser` subagent to fetch latest and rebase on upstream.
- Spawn a `code-simplifier:code-simplifier` subagent to review the diff for reuse, quality, and efficiency.
- If the simplifier made changes, run `git add -u && git commit --fixup=HEAD`. If working tree is clean, skip.
- Spawn a `build:precommit-runner` subagent again. Same rules — never skip.
