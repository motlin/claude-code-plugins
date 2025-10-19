---
name: split-tasks
description: Split a big plan into small, self-contained tasks in a markdown checklist
---

# Split Tasks

Transform a high-level plan or complex project into a markdown task list where each task is completely self-contained with all necessary context inline.

## Input

The input is the current conversation where planning and requirements have been discussed. You'll take the plans, ideas, and requirements from the discussion and transform them into self-contained tasks in a markdown checklist format, typically saved (appended) to `.llm/todo.md`.

## Task Writing Guidelines

Each task should be written so it can be read independently from `- [ ]` to the next `- [ ]` and contain:

1. **Full absolute paths** - Never use relative paths, always include complete file paths
2. **Exact class/function names** - Specify the exact names of code elements being worked on
3. **Analogies to existing code** - Reference similar existing implementations as examples (e.g., "Similar to how X works in Y...")
4. **Specific implementation details** - List concrete methods, functions, or operations to implement
5. **Module/package context** - Explicitly state which module or package the work belongs to
6. **Dependencies and prerequisites** - Note what needs to exist or be imported
7. **Expected outcomes** - Describe what success looks like for this task

## Example Format

```markdown
- [ ] Create a new test class `SynchronizedBagTest` at `/Users/craig/projects/eclipse-collections/unit-tests-thread-safety/src/test/java/org/eclipse/collections/impl/bag/mutable/SynchronizedBagTest.java` to test thread-safety of `org.eclipse.collections.impl.bag.mutable.SynchronizedBag`. Similar to how `SynchronizedMutableListTest` covers `SynchronizedMutableList`, this should extend `SynchronizedTestTrait` and implement test traits like `SynchronizedCollectionTestTrait`, `SynchronizedMutableIterableTestTrait`, and `SynchronizedRichIterableTestTrait`. The test should verify that all public methods of SynchronizedBag properly synchronize on the lock object using the `assertSynchronized()` method. Include tests for bag-specific methods like `addOccurrences()`, `removeOccurrences()`, `occurrencesOf()`, `forEachWithOccurrences()`, and `toMapOfItemToCount()`.
```

