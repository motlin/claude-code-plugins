---
name: plan-tasks
description: Capture conversation planning into self-contained tasks at end of discussion
---

# Plan Tasks

Transform conversation planning and requirements into a markdown task list where each task is completely self-contained with all necessary context inline.

@../skills/tasks/task-format.md

## When to Use

Use this command at the **end of a planning conversation** when you have discussed requirements, approaches, and implementation details but have not started coding yet. This captures the conversation context into actionable tasks in `.llm/todo.md`.

## Input

The input is the current conversation where planning and requirements have been discussed. Transform the plans, ideas, and requirements from the discussion into self-contained tasks in a markdown checklist format, appended to `.llm/todo.md`.

## Task Writing Guidelines

Each task should be written so it can be read independently from `- [ ]` to the next `- [ ]` and contain:

1. **Full absolute paths** - Never use relative paths
2. **Exact class/function names** - Specify exact names of code elements
3. **Analogies to existing code** - Reference similar existing implementations
4. **Specific implementation details** - List concrete methods or operations
5. **Module/package context** - State which module or package the work belongs to
6. **Dependencies and prerequisites** - Note what needs to exist or be imported
7. **Expected outcomes** - Describe what success looks like

## Example

```markdown
- [ ] Create a new test class `SynchronizedBagTest` at `/Users/craig/projects/eclipse-collections/unit-tests-thread-safety/src/test/java/org/eclipse/collections/impl/bag/mutable/SynchronizedBagTest.java` to test thread-safety of `org.eclipse.collections.impl.bag.mutable.SynchronizedBag`. Similar to how `SynchronizedMutableListTest` covers `SynchronizedMutableList`, this should extend `SynchronizedTestTrait` and implement test traits like `SynchronizedCollectionTestTrait`, `SynchronizedMutableIterableTestTrait`, and `SynchronizedRichIterableTestTrait`. The test should verify that all public methods of SynchronizedBag properly synchronize on the lock object using the `assertSynchronized()` method. Include tests for bag-specific methods like `addOccurrences()`, `removeOccurrences()`, `occurrencesOf()`, `forEachWithOccurrences()`, and `toMapOfItemToCount()`.
```
