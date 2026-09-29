---
name: markdown-authoring
description: Write merge-friendly Markdown. Use when writing or editing Markdown files.
---

# Markdown Authoring

Write each paragraph and list item on one line and let the renderer wrap it. Hard wraps make diffs noisy, since rewording one sentence reflows the whole paragraph, and they paste badly into GitHub text boxes. Code blocks, headings, and table rows keep their own line breaks.

Use `-` bullets instead of numbered lists, because numbers need renumbering on every insert or delete. When order matters, say so in the sentence before the list.
