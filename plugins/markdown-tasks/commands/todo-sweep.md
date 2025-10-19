🔍 Find all TODO comments and add them to the project todo list

Search the codebase for all TODO comments and add them to `.llm/todo.md`. Each TODO found in the code will be converted to a task in the markdown todo list with a clear description including the file location and the full TODO comment text.

## Steps

- Find all occurrences of "TODO" in the codebase using grep/search
- Gather:
   - File path
   - Line number
   - Full TODO comment text
- Strip comment markers (`//`,  `#`, `/* */`) from the TODO text for cleaner task descriptions
- Append new tasks to the existing list
- Each TODO comment becomes a single task entry
- For each TODO found, add an entry to `.llm/todo.md` in this format:
   ```markdown
   - [ ] Implement TODO from src/api/client.ts:87: Extract commonality in getRootNodes and getChildNodes
   - [ ] Implement TODO from test/utils.test.ts:103: Use deep object equality rather than loose assertions
   ```
