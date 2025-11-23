---
name: code-quality
description: Code quality guidelines for comment cleanup and code style. Use when reviewing code, removing redundant comments, or improving code clarity.
---

# Code Quality Guidelines

This skill provides best practices for maintaining clean, high-quality code by managing comments appropriately.

## Comment Removal Rules

🧹 Remove obvious and redundant comments to keep code clean and maintainable.

### Comments to Remove

Look for and remove these types of comments:

1. **Commented out code**
   - Delete code that's been commented out instead of keeping it
   - Version control preserves history, so there's no need to keep old code as comments

2. **Edit descriptions**
   - Remove comments that describe edits like "added", "removed", or "changed" something
   - Example to remove: `// Added error handling here`
   - These comments describe the process of editing rather than explaining the current state

3. **Obvious explanations**
   - Remove comments that are obvious because they're close to method names or self-explanatory code
   - Example to remove: `// Get user name` above a function called `getUserName()`

### Comments to Keep

Do not delete these comments:

1. **TODO comments**
   - Keep comments that start with TODO
   - These track future work and are intentional markers

2. **Comments preventing empty blocks**
   - Don't remove comments if doing so would make a scope empty
   - Examples: empty catch blocks, empty else blocks
   - These comments explain why the block is intentionally empty

3. **Linter/formatter directives**
   - Don't remove comments that suppress linters or formatters
   - Examples: `// prettier-ignore`, `// eslint-disable-next-line`, `// @ts-ignore`

### Comment Position

If you find any end-of-line comments, move them above the code they describe:

❌ Bad:
```typescript
const result = transform(data); // Apply transformation
```

✅ Good:
```typescript
// Apply transformation
const result = transform(data);
```

Comments should go on their own lines for better readability.

## Scope of Changes

### For Uncommitted Changes Only

📍 When cleaning up comments in uncommitted code:
- Only consider and edit local code changes that are not yet committed to git
- Use `git diff` to identify which files have uncommitted changes
- Focus only on those files

### For Entire Codebase

When cleaning up comments across the entire codebase:
- Apply the same rules to all files
- Use appropriate tools like `Glob` and `Grep` to find files that need cleanup
- Be systematic and thorough
