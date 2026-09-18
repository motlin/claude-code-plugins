---
name: plan-tasks
description: Convert a planning discussion into self-contained tasks in .llm/todo.md. Use at the end of a planning conversation, before any implementation starts.
---

# Plan Tasks

Capture conversation planning into self-contained tasks at the end of the discussion.

Use at the **end of a planning conversation** when you have discussed requirements, approaches, and implementation details but have not started coding yet. The input is the current conversation; transform the plans, ideas, and requirements from the discussion into tasks appended to `.llm/todo.md`.

Use the `markdown-tasks:tasks` skill for task format and script path rules, including archiving any plan file under `.llm/plans/` before adding tasks and putting the archived path in each task.

Resolve `<plugin-root>` before running plugin scripts:

- In Claude Code, use `${CLAUDE_PLUGIN_ROOT}`.
- In Codex, use the plugin root that contains this `skills/plan-tasks/SKILL.md` file.

Create tasks that are fully self-contained, readable independently from `- [ ]` to the next `- [ ]`. Each task should include:

- Absolute file paths; never relative paths.
- Exact class, function, or command names.
- Existing patterns to follow, with analogies to similar code.
- Concrete implementation details: the specific methods or operations involved.
- Module/package context: which module or package the work belongs to.
- Dependencies and prerequisites: what needs to exist or be imported.
- Expected outcome: what success looks like.

Compose every task before writing. Add the complete batch in one shell command by chaining one call per task with `&&`:

```bash
python <plugin-root>/scripts/task_add.py .llm/todo.md "Task description
  Context line 1
  Context line 2" && \
python <plugin-root>/scripts/task_add.py .llm/todo.md "Another task
  Standalone context"
```

Never add a multi-task batch across separate shell commands. Keeping the writes together reduces the chance that concurrent sessions interleave their tasks.

## Example

```markdown
- [ ] Create a new test class `SynchronizedBagTest` at `/workspace/project/unit-tests-thread-safety/src/test/java/com/example/collections/bag/mutable/SynchronizedBagTest.java` to test thread-safety of `com.example.collections.bag.mutable.SynchronizedBag`. Similar to how `SynchronizedMutableListTest` covers `SynchronizedMutableList`, this should extend `SynchronizedTestTrait` and implement test traits like `SynchronizedCollectionTestTrait`, `SynchronizedMutableIterableTestTrait`, and `SynchronizedRichIterableTestTrait`. The test should verify that all public methods of SynchronizedBag properly synchronize on the lock object using the `assertSynchronized()` method. Include tests for bag-specific methods like `addOccurrences()`, `removeOccurrences()`, `occurrencesOf()`, `forEachWithOccurrences()`, and `toMapOfItemToCount()`.
```

Report how many tasks were created.
