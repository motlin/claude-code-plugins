---
allowed-tools: Task, Bash(just:*)
description: Run tests on all commits and fix failures in a loop
---

🧪 Run `just --global-justfile test-all`. Use a long timeout of at least 30 minutes.
  - If it fails, use the build-fixer-autosquash agent to fix failures.
  - Then run the command again. The command is smart and resumes from where it left off.
  - Repeat until all tests pass.
