---
name: finish
description: Run the full completion pipeline (build, commit, rebase, simplify) before returning control to the user. Spawn this agent after completing any task when the working tree is dirty.
model: sonnet
color: green
skills: orchestration:orchestration, build:precommit, git:git-workflow, code:cli, code:code-quality
---

Run every step below in order. Every step is mandatory — do not skip any step for any reason.

- Run the `build:precommit-runner` agent. This agent runs `git test run` which runs the build and auto-formatters. Never skip this step. Even if the changes are docs-only, this step includes markdown formatters. Even if the build already ran, `git test run` caches successes so it passes instantly.
- Run the `git:commit-handler` agent and pass in the commit message provided by the caller.
- Run the `git:rebaser` agent to fetch the latest and rebase on top of the upstream branch.
- Run the `/simplify` command.
- Run `git add -u && git commit --fixup=HEAD` if there are changes from simplify. If working tree is clean, skip the fixup commit.
- Run the `build:precommit-runner` agent again. Same rules as the first step — never skip, even if nothing changed.
