---
name: plan-tasks
description: Convert a planning discussion into self-contained tasks in .llm/todo.md. Use at the end of a planning conversation, before any implementation starts.
---

# Plan Tasks

Turn the requirements, approaches, and implementation details discussed in this conversation into tasks appended to `.llm/todo.md`. Use this after planning and before any coding.

Use the `markdown-tasks:tasks` skill for task format and script path rules, including archiving any plan file under `.llm/plans/` and putting its path in each task. `<plugin-root>` is `${CLAUDE_PLUGIN_ROOT}` in Claude Code; in Codex, it is the plugin root that contains this `skills/plan-tasks/SKILL.md` file.

Each task must be readable on its own, from its `- [ ]` to the next one, and include:

- Absolute file paths, never relative ones.
- Exact class, function, or command names.
- Existing patterns to follow, with analogies to similar code.
- The specific methods or operations involved.
- The module or package the work belongs to.
- Dependencies and prerequisites.
- The expected outcome.

Compose every task first, then add the batch in one shell command, chaining one call per task with `&&` so concurrent sessions are unlikely to interleave their tasks:

```bash
python <plugin-root>/scripts/task_add.py .llm/todo.md "Task description
  Context line 1
  Context line 2" && \
python <plugin-root>/scripts/task_add.py .llm/todo.md "Another task
  Standalone context"
```

## Example

```markdown
- [ ] Create a new test class `SynchronizedBagTest` at `/workspace/project/unit-tests-thread-safety/src/test/java/com/example/collections/bag/mutable/SynchronizedBagTest.java` to test thread-safety of `com.example.collections.bag.mutable.SynchronizedBag`. Similar to how `SynchronizedMutableListTest` covers `SynchronizedMutableList`, this should extend `SynchronizedTestTrait` and implement test traits like `SynchronizedCollectionTestTrait`, `SynchronizedMutableIterableTestTrait`, and `SynchronizedRichIterableTestTrait`. The test should verify that all public methods of SynchronizedBag properly synchronize on the lock object using the `assertSynchronized()` method. Include tests for bag-specific methods like `addOccurrences()`, `removeOccurrences()`, `occurrencesOf()`, `forEachWithOccurrences()`, and `toMapOfItemToCount()`.
```

Report how many tasks were created.
