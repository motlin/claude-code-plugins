---
name: writing-instructions
description: Guidelines for writing skills, agents, and commands that remain stable over time
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
