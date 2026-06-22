---
description: Find all TODO comments and add them to the project task list
model: haiku
---

Find all TODO comments and add them to the project task list.

Search the codebase for all TODO comments and add them to `.llm/todo.md`. Each TODO found in the code will be converted to a task in the markdown task list.

## Steps

1. Find all occurrences of "TODO" in the codebase using grep/search
2. For each occurrence, gather:
    - File path
    - Line number
    - Full TODO comment text
3. Strip comment markers (`//`, `#`, `/* */`) from the TODO text
4. Add every TODO to `.llm/todo.md` in a single bash command that chains one `task_add.py` call per TODO with `&&`:

    ```bash
    python ${CLAUDE_PLUGIN_ROOT}/scripts/task_add.py .llm/todo.md "Implement TODO from src/api/client.ts:87: Extract commonality in getRootNodes and getChildNodes" && \
    python ${CLAUDE_PLUGIN_ROOT}/scripts/task_add.py .llm/todo.md "Implement TODO from test/utils.test.ts:103: Use deep object equality rather than loose assertions"
    ```

    Running the whole batch as one command keeps the write window to `.llm/todo.md` extremely short, so concurrent sessions are far less likely to interleave their tasks. Never add the TODOs across separate commands.
