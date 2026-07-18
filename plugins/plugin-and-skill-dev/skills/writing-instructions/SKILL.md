---
name: writing-instructions
description: >-
    MUST be loaded before creating, editing, or reviewing any SKILL.md, agent markdown, or
    command markdown file. Contains formatting rules that prevent common mistakes like
    numbered steps, which cause git churn, and privacy rules requiring generic placeholders
    instead of real personal data in examples. Also use when the user asks about instruction
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

## Use generic placeholders in examples, never real personal data

Examples in skill, agent, and command files must never contain real personal data: real names of people, real places or businesses lifted from private content (journals, calendars, messages, emails), phone numbers, addresses, or verbatim snippets of that content.

**Why:** These files are version-controlled and pushed to remotes. Once a real name lands in a pushed commit, removing it requires a history rewrite or repo recreation — editing the file later leaves the leak in every historical commit.

**Instead:** Recreate the example with placeholders that preserve only the _shape_ of the data:

- People: `@Alice`, `@Bob`, `@Carol`
- Places and businesses: well-known generic names (`New York`, `Central Park`) or invented ones
- Content: invented text with the same structure as the original

**The trap to watch for:** When a rule is derived from a real incident — user feedback on a specific journal entry, a bug triggered by a specific meeting title — the natural move is to paste the triggering text verbatim as the example. Stop and rewrite it with placeholders before saving. An example drawn from real data teaches nothing that a placeholder version doesn't.

Bad:

```markdown
- Ordinary mid-sentence verbs (e.g., `@<real friend's name> and I drove` keeps `drove` lowercase)
```

Good:

```markdown
- Ordinary mid-sentence verbs (e.g., `@Alice and I drove` keeps `drove` lowercase)
```

Before committing, scan the diff for names and content you did not invent.
