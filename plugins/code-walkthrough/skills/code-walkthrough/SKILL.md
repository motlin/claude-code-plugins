---
name: code-walkthrough
description: Create and maintain an HTML codebase walkthrough with ordered explanations, scroll-linked source highlights, and an iterative learning and review workflow. Use for guided source tours, not chronological shell investigation reports.
---

# Code Walkthrough

Build a reading experience around the actual source: concise explanations on the left, sticky syntax-highlighted code on the right. Scrolling selects the corresponding lines. Use the bundled renderer; keep the walkthrough specification in the target repository. Read [authoring.md](../../references/authoring.md) for the format and rebuild commands.

## Choose the teaching order

Start with what the program does and its entry point, then follow a concrete execution path from coordination into algorithms and representation. Do not use directory order as the syllabus. Adapt depth and vocabulary to the reader; ask only for missing context that materially changes the tour.

Explain the current highlight before tracing where its dependencies come from. Use a short transition when a forward reference needs one. Keep each explanation attached to the lines it discusses; split sections when the relevant code is in another file.

Get to code quickly. Use descriptive headings, concrete names, and concise prose. Omit cute introductions, chapter-count marketing, and announcements of what the tutorial will teach. Explain unfamiliar language syntax where it appears. Keep complete source paths and line ranges visible.

The renderer embeds complete files. If adapting it to excerpts, showing at least half of a file means showing the entire file. Never present rewritten examples as real source. Optional interactive experiments should illuminate a particular algorithm; label models and simplifications, and keep them separate from the actual implementation.

## Discuss, review, and revise

Treat reader questions as guidance for teaching order and missing explanations. When asked to revise the tutorial, answer in place and rebuild. When asked to discuss a design, answer in chat. Do not silently turn a question into a code change.

Investigate inconsistencies exposed by the discussion. Distinguish a confirmed bug from a design preference or an unfamiliar idiom. Trace state ownership: constructors and ordinary name references are not automatically problematic dependencies. Check outside writes and returned mutable storage before claiming an encapsulation problem.

Make authorized code changes with appropriate verification, or record tasks when asked. Revisit related explanations, paths, and anchors after refactoring. Teaching should reflect the final code, not the history of abandoned designs.

## Rebuild and inspect

Resolve highlights from unique start/end source anchors, not stored line numbers or fixed line counts. Rebuild source listings deterministically. A changed excerpt must trigger editorial review; do not accept a new digest merely to silence a warning. Source outside the highlighted excerpt can also change its meaning: review related behavior and tests rather than treating a matching digest as semantic proof.

Use the dark template with a separate line-number gutter and mobile layout. Verify repeated Next/Previous navigation, deep links, wrapping, and highlight visibility at a phone width and a short desktop viewport. Keep full files readable without JavaScript.

Use ordinary conversation for questions. Do not add in-page submission boxes or a chat backend by default. A source path and stable step link supply the discussion context. Deliver the generated file and rebuild command. If hosting is requested, use the user's chosen environment and verify its URL; do not assume localhost is reachable from a phone.
