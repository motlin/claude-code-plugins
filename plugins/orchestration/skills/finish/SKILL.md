---
name: finish
description: This skill should be used after completing any task, before returning control to the user. Always run this skill — it handles the case where there's nothing to do.
---

Spawn the `orchestration:finish` agent to run the full completion pipeline. Pass along the commit message provided by the caller. Do not run any pipeline steps inline — delegate everything to the finish agent.
