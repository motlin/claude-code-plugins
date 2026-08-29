---
name: markdown-unblock-tasks
description: Recover blocked [!] tasks from archived task lists back into .llm/todo.md. Use when the user asks to unblock, recover, retry, or resurrect blocked tasks, or wants to know what blocked work is waiting in the archives.
---

# Markdown Unblock Tasks

Use the `markdown-tasks` skill for script path rules and task semantics.

Blocked `[!]` tasks are invisible to `task_get.py`, so `do-one-task` and `do-all-tasks` skip them forever. Archiving carries them into a fresh `.llm/todo.md` still marked `[!]`, and earlier archives keep the ones that were already there. Recovery is the only way back, and it is always the user's decision.

## Survey First

Recovery rewrites historical archive files, so never run it blind:

```bash
python <plugin-root>/scripts/task_unblock.py .llm --dry-run
```

The dry run rewrites nothing. It reports the blocked count per file and the first line of each blocked task.

## Confirm With the User

Show the report and ask whether to recover. Present the whole set: the script has no per-task selection and moves everything it finds in one pass. If the user wants only some of them, say so rather than pretending otherwise — the remaining ones can be re-blocked with `task_mark.py --marker='!' --reason='<why>'` after recovery.

Stop here when nothing is blocked. Say so and do not run the script again.

## Recover

```bash
python <plugin-root>/scripts/task_unblock.py .llm
```

Each `[!]` task moves into `.llm/todo.md` with its indented context as an open `[ ]` task, stamped with an indented `Recovered <yyyy-mm-dd> session <session-id>` line. The earlier `Blocked` line survives, so the reason the task failed travels with it and the next worker does not repeat the same approach.

Recovery is a move, not a copy. The task leaves the archive it came from, so re-running the script cannot duplicate it. Emptied archive files stay on disk.

Report the recovered count and the files it drew from. Offer to run `do-one-task` or `do-all-tasks` next.
