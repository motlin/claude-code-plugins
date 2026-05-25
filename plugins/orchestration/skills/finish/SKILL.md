---
name: finish
description: This skill should be used after completing any task, before returning control to the user. Always run this skill — it handles the case where there's nothing to do.
---

The caller's prompt describes the commit intent. Run every step below in order. Every step is mandatory.

- Use the `@build:precommit-runner` agent — runs `git test run` for build/formatters/linters. Never skip — cached successes pass instantly.
- Use the `@git:commit-handler` agent — pass the caller's prompt as the commit intent. The agent distills it into a single-line commit message; it does not copy the prompt verbatim.
- Use the `@git:rebaser` agent — fetch latest and rebase on upstream.
- Use the `@code-simplifier:code-simplifier` agent — review the diff for reuse, quality, and efficiency.
- If the simplifier made changes, run `git add -u && git commit --fixup=HEAD`. If working tree is clean, skip.
- Use the `@build:precommit-runner` agent again. Same rules — never skip.
