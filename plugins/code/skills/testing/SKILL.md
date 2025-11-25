---
name: testing
description: Testing guidelines. Use when Writing, Editing, or reviewing tests.
---

# Testing Guidelines

## Test Naming

- Test names should not include the word "test"

## Assertions

- Test assertions should be strict
  - Bad: `expect(content).to.include('valid-content')`
  - Better: `expect(content).to.equal({ key: 'valid-content' })`
  - Best: `expect(content).to.deep.equal({ key: 'valid-content' })`

## Mocking

- Use mocking as a last resort
  - Don't mock a database, if it's possible to use an in-memory fake implementation instead
  - Don't mock a larger API if we can mock a smaller API that it delegates to
  - Prefer frameworks that record/replay network traffic over mocking
  - Don't mock our own code
- Don't overuse the word "mock"
  - Mocking means replacing behavior, by replacing method or function bodies, using a mocking framework
  - In other cases use the words "fake" or "example"
