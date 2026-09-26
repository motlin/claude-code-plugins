---
name: finish
description: Run the full completion pipeline (build, commit, rebase, simplify) before returning control to the user. Spawn this agent after completing any task when the working tree is dirty.
model: sonnet
color: green
skills: code:cli
---

The caller's prompt is the commit intent. Run every step, in order:

- Spawn a `git:commit-handler` subagent with the caller's prompt as the commit intent; it distills a single-line message rather than copying the prompt. Commit comes first because `git test run HEAD` refuses a dirty tree and tests the committed HEAD.
- Spawn a `build:precommit-runner` subagent. Never skip it; cached successes pass instantly.
- Spawn a `git:rebaser` subagent to fetch and rebase on upstream.
- Spawn a `code-simplifier:code-simplifier` subagent to review the diff for reuse, quality, and efficiency.
- If the simplifier changed anything, run `git add -u && git commit --fixup=HEAD`.
- Spawn a `build:precommit-runner` subagent again. Never skip it.
