---
name: writing-instructions
description: >-
  This skill should be used when writing, reviewing, or editing SKILL.md files, agent
  instructions, or command definitions. Use when the user asks about best practices for
  instruction formatting, how to avoid unnecessary git churn in markdown instructions,
  whether to use numbered steps, or how to structure headers in skills and agents.
---

# Writing Instructions for Skills, Agents, and Commands

## Use descriptive headers, not numbered steps

Never use numbered steps (e.g., `## Step 1:`, `## Step 2:`) in skill, agent, or command instructions.

**Why:** LLMs reorder steps during routine edits, creating unnecessary git churn. Numbered headers force renumbering on every insertion or deletion, generating large diffs with no meaningful change.

**Instead:** Use headers that name the action or outcome.

Bad:

```markdown
### Step 1: Run the build

### Step 2: Extract errors

### Step 3: Check for auto-formatted changes
```

Good:

```markdown
### Run the build

### Extract errors

### Check for auto-formatted changes
```

When order matters, the document's top-to-bottom flow communicates sequence. When order does not matter, descriptive headers make each section independently understandable.
