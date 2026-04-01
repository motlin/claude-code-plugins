---
description: Run the full completion pipeline — build, commit, simplify, rebuild, commit, rebase
---

Run the full completion pipeline in this exact order:

1. Verify the build passes using the `build:precommit-runner` agent
2. Commit to git using the `git:commit-handler` agent
3. Run `/simplify` to review changed code for reuse, quality, and efficiency
4. Verify the build passes again using the `build:precommit-runner` agent
5. Commit to git again using the `git:commit-handler` agent
6. Rebase on top of the upstream branch with the `git:rebaser` agent

Do not skip any steps. If a step fails, fix the issue and retry that step before continuing.
