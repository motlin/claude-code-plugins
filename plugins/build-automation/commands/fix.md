---
allowed-tools: Bash(just:*)
description: Run just precommit and fix failures without committing
---

🔧 Run `just precommit` and fix any failures that occur.
  - Use a timeout of at least 10 minutes.
  - If it fails, analyze the errors and fix them directly.
  - Do not commit the changes when done.
