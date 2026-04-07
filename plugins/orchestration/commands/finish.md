---
description: Run the full completion pipeline — build, commit, simplify, commit, build, rebase
---

Run the full completion pipeline in this exact order:

1. Verify the build passes using the `build:precommit-runner` agent
2. Commit to git using the `git:commit-handler` agent
3. Run `/simplify` to review changed code for reuse, quality, and efficiency
4. Commit to git again using the `git:commit-handler` agent
5. Verify the build passes using the `build:precommit-runner` agent
6. Rebase on top of the upstream branch with the `git:rebaser` agent

Every step is mandatory. Do not skip any step for any reason:

- The build runs linters, formatters, and tests on every commit — including for docs and markdown. There is no type of change that can skip the build.
- Simplify catches code quality issues that the build does not. It is not redundant with the build.
- The second build verifies that simplify's changes did not break anything.
- The rebase ensures the branch is up to date before the user reviews.

If a step fails, fix the issue and retry that step before continuing.
