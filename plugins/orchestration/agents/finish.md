---
name: finish
description: Run the full completion pipeline (build, commit, rebase, simplify) before returning control to the user. Spawn this agent after completing any task when the working tree is dirty.
model: sonnet
color: green
skills: code:cli
---

The caller's prompt describes the commit intent. Run every step below in order. Every step is mandatory.

- Spawn a `git:commit-handler` subagent. Pass the caller's prompt as the commit intent. The agent distills it into a single-line commit message; it does not copy the prompt verbatim. Commit first — `git test run HEAD` refuses to run on a dirty tree and tests the committed HEAD, not the working tree.
- Spawn a `build:precommit-runner` subagent. It runs `git test run HEAD` which covers the build, formatters, and linters. Never skip — cached successes pass instantly.
- Spawn a `git:rebaser` subagent to fetch latest and rebase on upstream.
- Spawn a `code-simplifier:code-simplifier` subagent to review the diff for reuse, quality, and efficiency.
- If the simplifier made changes, run `git add -u && git commit --fixup=HEAD`. If working tree is clean, skip.
- Spawn a `build:precommit-runner` subagent again. Same rules — never skip.
