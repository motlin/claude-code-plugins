---
name: orchestration
description: Core orchestration guidelines for conversation style, code style, testing, tool conventions, and workflow automation. Always use this skill - it coordinates when to invoke other agents and provides foundational context.
---

# Orchestration Guidelines

**Core Skills:** Always invoke these skills to get domain-specific guidelines:

- Git operations: Use `@git:git-workflow` skill for all git operations
- Build validation: Use `@build:precommit` skill before running builds or tests
- Code editing: Use `@code:code-quality` skill before editing code

## Conversation Style

- If the user asks a question, only answer the question, do not edit code
- Never compliment the user
  - Criticize the user's ideas
  - Ask clarifying questions
- Don't say:
  - "You're right"
  - "You're absolutely right"
  - "I apologize"
  - "I'm sorry"
  - "Let me explain"
  - any other introduction or transition
- Immediately get to the point

## Code Style

### General Philosophy

- Don't write forgiving code
  - Don't permit multiple input formats
    - In TypeScript, this means avoiding Union Type (the `|` in types)
  - Use preconditions
    - Use schema libraries
    - Assert that inputs match expected formats
    - When expectations are violated, throw, don't log
  - Don't add defensive try/catch blocks
    - Usually we let exceptions propagate out
- Don't use abbreviations or acronyms
  - Choose `number` instead of `num` and `greaterThan` instead of `gt`
- Emoji and unicode characters are welcome
  - Use them at the beginning of comments, commit messages, and in headers in docs

### Comments

- Use comments sparingly
- Don't comment out code
  - Remove it instead
- Don't add comments that describe the process of changing code
  - Comments should not include past tense verbs like added, removed, or changed
  - Example: `this.timeout(10_000); // Increase timeout for API calls`
  - This is bad because a reader doesn't know what the timeout was increased from, and doesn't care about the old behavior
- Don't add comments that emphasize different versions of the code, like "this code now handles"
- Do not use end-of-line comments
  - Place comments above the code they describe

### File Management

- Prefer editing an existing file to creating a new one
- Never create documentation files (`*.md` or README)
  - Only create documentation files if explicitly requested by the user

## Testing Philosophy

- Test names should not include the word "test"
- Test assertions should be strict
  - Bad: `expect(content).to.include('valid-content')`
  - Better: `expect(content).to.equal({ key: 'valid-content' })`
  - Best: `expect(content).to.deep.equal({ key: 'valid-content' })`
- Use mocking as a last resort
  - Don't mock a database, if it's possible to use an in-memory fake implementation instead
  - Don't mock a larger API if we can mock a smaller API that it delegates to
  - Prefer frameworks that record/replay network traffic over mocking
  - Don't mock our own code
- Don't overuse the word "mock"
  - Mocking means replacing behavior, by replacing method or function bodies, using a mocking framework
  - In other cases use the words "fake" or "example"

## Tool Conventions

- I replaced `cd` with `zoxide`. Use `command cd` to change directories
  - This is the only command that needs to be prefixed with `command`
  - Don't prefix `git` with `command git`
- Try not to use `cd` or `zoxide` at all. It's usually not necessary with CLI commands
  - Don't run `cd <dir> && git <subcommand>`
  - Prefer `git -C <dir> <subcommand>`

## LLM Context

- Extra context for LLMs may be stored in the `.llm/` directory
  - If `.llm/` exists, it will be at the root directory of the git repository
  - `.git/info/exclude` includes `/.llm`, so don't `git add` its contents
- Editable context:
  - If `.llm/todo.md` exists, it is the task list we are working on
  - As you complete tasks, mark the checkboxes as complete, like `- [x] The task`
  - As we work on an implementation, plans will change. Feel free to edit the task list to keep it relevant and in sync with your plans
- Read-only context:
  - Everything else in the `.llm/` directory is read-only context for your reference
  - It contains entire git clones for tools we use
  - It contains saved documentation

## Workflow Orchestration

When a code change is ready, and we are about to return control to the user, do these things in order:

1. Verify the build passes using the `@build:precommit-runner` agent
2. Commit to git using the `@git:commit-handler` agent
3. Rebase on top of the upstream branch with the `@git:rebaser` agent

Don't run long-lived processes like development servers or file watchers:

- Don't run `npm run dev`
- Echo copy/pasteable commands and ask the user to run it instead

Use long flag names when using the Bash tool:

- Don't run `git commit -m`
- Run `git commit --message` instead
