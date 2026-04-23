---
name: finish
description: This skill should be used after completing any task, before returning control to the user. Always run this skill — it handles the case where there's nothing to do.
---

Spawn the `orchestration:finish` agent. Pass only the commit message as the prompt — no preamble, no instructions. Do not run any pipeline steps inline.
