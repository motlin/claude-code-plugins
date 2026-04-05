---
name: writing-instructions
description: >-
    MUST be loaded before creating, editing, or reviewing any SKILL.md, agent markdown, or
    command markdown file. Contains formatting rules that prevent common mistakes like
    numbered steps, which cause git churn. Also use when the user asks about instruction
    formatting best practices, header structure, or how to avoid unnecessary diffs.
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
