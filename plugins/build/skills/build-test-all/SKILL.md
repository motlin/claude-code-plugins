---
name: build-test-all
description: Run tests across all commits and loop on failures until all pass. Use when asked to run or fix test-all for a branch.
---

# Build Test All

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/build-test-all/SKILL.md` file.

Run:

```bash
<plugin-root>/scripts/test-all
```

Use a timeout of at least 30 minutes.

If it fails:

- Use the `build-fix` skill to fix the failure.
- Run `<plugin-root>/scripts/test-all` again.
- Repeat until all tests pass.

The script resumes from where it left off. Do not clear git-test cached results.
