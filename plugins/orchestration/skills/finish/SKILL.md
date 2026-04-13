---
name: finish
description: This skill should be used after completing any task, before returning control to the user. Always run this skill — it handles the case where there's nothing to do.
---

Spawn a sub-agent to run the full completion pipeline. Pass the entire pipeline section below as the agent's prompt, along with the commit message provided by the caller. Do not run any of these steps inline — delegate all of them to the sub-agent.

## Pipeline

- Run the `build:precommit-runner` agent. This agent runs `git test run` which runs the build and auto-formatters. Never skip this step. Even if you only edited docs, this step includes markdown formatters. Even if you already ran the build, `git test run` caches successes so it passes instantly.
- Run the `git:commit-handler` agent and pass in the commit message provided by the caller.
- Run the `git:rebaser` agent to fetch the latest and rebase on top of the upstream branch.
- Run the `/simplify` command.
- Run `git add -u && git commit --fixup=HEAD`
- Run the `build:precommit-runner` agent again. Same rules as the first step — never skip, even if you think nothing changed.

Every step is mandatory. Do not skip any step for any reason.
