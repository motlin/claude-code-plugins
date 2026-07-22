---
description: Check configured strictness ratchets without changing their baselines
arguments:
    - name: tool
      description: Stable tool identifier to check (optional)
      required: false
---

Use the ratchet skill to inspect the repository's checked-in ratchet configuration and run its read-only check.

- If `$ARGUMENTS` names a tool, check only that tool with `just ratchet $ARGUMENTS`.
- If `$ARGUMENTS` is empty, check every configured tool with `just ratchet`.
- Report regressions, required acceptance, required promotion, and infrastructure failures separately.
- Do not edit or accept a baseline while checking it.
