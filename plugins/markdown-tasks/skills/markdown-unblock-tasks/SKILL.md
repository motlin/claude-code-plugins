---
name: markdown-unblock-tasks
description: Recover blocked [!] tasks from archived task lists back into .llm/todo.md. Use when the user asks to unblock, recover, retry, or resurrect blocked tasks, or wants to know what blocked work is waiting in the archives.
---

# Markdown Unblock Tasks

Use the `markdown-tasks:tasks` skill for script path rules and task semantics. `<plugin-root>` is `${CLAUDE_PLUGIN_ROOT}` in Claude Code; in Codex, it is the plugin root that contains this `skills/markdown-unblock-tasks/SKILL.md` file.

`task_get.py` skips blocked `[!]` tasks, so `markdown-tasks:do-one-task` and `markdown-tasks:do-all-tasks` never retry them, and archiving carries them forward still blocked. Recovery is the only way back, and it is always the user's decision.

## Survey First

Recovery rewrites archive files, so never run it blind:

```bash
python <plugin-root>/scripts/task_unblock.py .llm --dry-run
```

The dry run rewrites nothing. It reports the blocked count per file and the first line of each blocked task. When nothing is blocked, say so and stop.

## Confirm With the User

Show the report and ask whether to recover. The script moves every blocked task in one pass, with no per-task selection. If the user wants only some, say so; the rest can be re-blocked with `task_mark.py --marker='!' --reason='<why>'` afterward.

## Recover

```bash
python <plugin-root>/scripts/task_unblock.py .llm
```

Each task moves into `.llm/todo.md` as an open `[ ]` task with a `Recovered <yyyy-mm-dd> session <session-id>` line. Its earlier `Blocked` line stays, so the next worker sees why it failed.

Report the recovered count and the files it drew from, then offer to run `markdown-tasks:do-one-task` or `markdown-tasks:do-all-tasks`.
