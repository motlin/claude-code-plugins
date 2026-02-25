---
description: Find all TODO and TASK comments and add them to the built-in task list
model: haiku
---

Find all TODO and TASK comments in the codebase and add them as tasks using `TaskCreate`.

## Steps

1. Find all occurrences of "TODO" and "TASK" in the codebase using grep/search
2. For each occurrence, gather:
   - File path
   - Line number
   - Full TODO/TASK comment text
3. Strip comment markers (`//`, `#`, `/* */`) from the TODO/TASK text
4. For each TODO or TASK, create a task using `TaskCreate` with:
   - **`subject`**: An imperative description derived from the comment (e.g., "Extract commonality in getRootNodes and getChildNodes")
   - **`activeForm`**: Present continuous form for spinner text (e.g., "Extracting commonality in getRootNodes and getChildNodes")
   - **`description`**: The full context including:
     - The original comment text
     - The absolute file path and line number where the TODO/TASK was found
     - A few lines of surrounding code context for clarity
5. Report how many tasks were created
