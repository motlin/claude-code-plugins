---
name: finish
description: Run the full completion pipeline — build, commit, simplify, commit, build, rebase. Use this agent before returning control to the user.
model: inherit
color: green
permissionMode: acceptEdits
skills: orchestration:orchestration, build:precommit, code:cli, git:git-workflow, code:code-quality
---

Run the full completion pipeline. Every step is mandatory. Do not skip any step for any reason.

## Pipeline

1. Run the `build:precommit-runner` agent. This agent runs `git test run` which runs the build and auto-formatters. Never skip this step. Even if you only edited docs, this step includes markdown formatters. Even if you already ran the build, `git test run` caches successes so it passes instantly.
2. Run the `git:commit-handler` agent and pass in the commit message provided by the caller.
3. Run the `git:rebaser` agent to fetch the latest and rebase on top of the upstream branch.
4. Run the `/simplify` command.
5. Run `git add -u && git commit --fixup=HEAD`
6. Run the `build:precommit-runner` agent again. Same rules as step 1 — never skip, even if you think nothing changed.
