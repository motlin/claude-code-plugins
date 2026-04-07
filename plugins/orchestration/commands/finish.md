---
description: Run the full completion pipeline — build, commit, simplify, commit, build, rebase
argument-hint: <commit message>
---

Finish up the current work by building, committing, reviewing, and rebasing. This ensures all changes are validated, committed cleanly, and ready for the user to review.

## Commit Message

Use this commit message for the initial commit (step 2):

$ARGUMENTS

If no commit message was provided, draft one based on the changes.

## Pipeline

Run the full completion pipeline in this exact order:

1. Run the `build:precommit-runner` agent. This runs `git test run` which runs the build and auto-formatters. Never skip this step. Even if you only edited docs, this step includes markdown formatters. Even if you already ran the build, `git test run` caches successes so it passes instantly. Fix any failures before continuing.
2. Commit to git using the `git:commit-handler` agent with the commit message above
3. Run `/simplify` to review changed code for reuse, quality, and efficiency
4. If simplify made changes, create a fixup commit: `git add -u && git commit --fixup=HEAD`
5. Run the `build:precommit-runner` agent again. Same rules as step 1 — never skip, even if you think nothing changed.
6. Rebase on top of the upstream branch with the `git:rebaser` agent

Every step is mandatory. Do not skip any step for any reason:

- Simplify catches code quality issues that the build does not. It is not redundant with the build.
- The rebase ensures the branch is up to date before the user reviews.

If a step fails, fix the issue and retry that step before continuing.
