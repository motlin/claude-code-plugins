---
description: Find all TODO and TASK comments and add them to the project task list
---

Find all TODO and TASK comments and add them to the project task list.

Search the codebase for all TODO and TASK comments and add them to `.llm/todo.md`. Each TODO or TASK found in the code will be converted to a task in the markdown task list.

## Steps

1. Find all occurrences of "TODO" in the codebase using grep/search
2. For each occurrence, gather:
   - File path
   - Line number
   - Full TODO comment text
3. Strip comment markers (`//`, `#`, `/* */`) from the TODO/TASK text
4. Add each TODO or TASK as a new task entry to `.llm/todo.md`:
   ```markdown
   - [ ] Implement TODO from src/api/client.ts:87: Extract commonality in getRootNodes and getChildNodes
   - [ ] Implement TODO from test/utils.test.ts:103: Use deep object equality rather than loose assertions
   ```
