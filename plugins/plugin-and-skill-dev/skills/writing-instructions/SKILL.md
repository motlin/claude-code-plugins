---
name: writing-instructions
description: >-
    Formatting and privacy rules for SKILL.md, agent, and command files. Load before creating,
    editing, or reviewing one, and pair with the skill that does the work:
    skill-creator:skill-creator, skill-extractor:skill-extractor, or
    claude-md-management:revise-claude-md / claude-md-management:claude-md-improver.
---

# Writing Instructions for Skills, Agents, and Commands

## Use descriptive headers, not numbered steps

Never number steps (`## Step 1:`, `## Step 2:`). LLMs reorder steps during edits, and numbered headers force renumbering on every insert or delete. Name the action instead: `### Run the build`, not `### Step 1: Run the build`.

When steps must be run in sequence, say so, without numbering.

## Scrub personal data

Never put real personal data in an example: names, emails, places, phone numbers, addresses, or verbatim private text.

Rebuild the example with placeholders that keep the shape: `@Alice` and `@Bob` for people, generic or popular names and places, invented text for content.

Before committing, scan the diff for names and content you did not invent.
