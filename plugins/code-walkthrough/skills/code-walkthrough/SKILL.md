---
name: code-walkthrough
description: Create and maintain an HTML codebase walkthrough with ordered explanations, scroll-linked source highlights, and an iterative learning and review workflow. Use for guided source tours, not chronological shell investigation reports.
---

# Code Walkthrough

Build a reading experience around the actual source: concise explanations on the left, sticky syntax-highlighted code on the right. Scrolling selects the corresponding lines. Use the bundled Astro components and pinned build dependencies; do not recreate the layout for each codebase. Read [authoring.md](../../references/authoring.md) for the format and rebuild commands.

## Choose where the walkthrough lives

Keep the walkthrough untracked by default: put the specification and the generated pages in the target repository's `.llm/walkthrough/` directory, as `walkthrough.json` and the `site/` directory. Confirm that `.llm/` is gitignored, and add it to `.gitignore` if not.

Put the walkthrough in version control only when the user wants it there. Then commit only the JSON specification (for example `docs/walkthrough.json`) and gitignore the generated HTML. Never commit the HTML: it embeds every source file it shows, so each rebuild adds megabytes of duplicated source to history and noisy diffs to review.

## Choose the teaching order

Start with what the program does and its entry point, then follow a concrete execution path from coordination into algorithms and representation. Do not use directory order as the syllabus. Adapt depth and vocabulary to the reader; ask only for missing context that materially changes the tour.

Explain the current highlight before tracing where its dependencies come from. Use a short transition when a forward reference needs one. Keep each explanation attached to the lines it discusses; split sections when the relevant code is in another file.

Get to code quickly. Use descriptive headings, concrete names, and concise prose. Omit cute introductions, chapter-count marketing, and announcements of what the tutorial will teach. Explain unfamiliar language syntax where it appears. Keep complete source paths and line ranges visible.

When the reader should see the program run before reading its source, or needs domain background the code assumes, put it in a `preface` section before the first source section. Capture a program demo with the `demo:demo` skill and embed its rendered fragment; never retype command output into the preface.

The renderer embeds complete files. If adapting it to excerpts, showing at least half of a file means showing the entire file. Never present rewritten examples as real source. Optional interactive experiments should illuminate a particular algorithm; label models and simplifications, and keep them separate from the actual implementation.

## Discuss, review, and revise

Treat reader questions as guidance for teaching order and missing explanations. When asked to revise the tutorial, answer in place and rebuild. When asked to discuss a design, answer in chat. Do not silently turn a question into a code change.

Investigate inconsistencies exposed by the discussion. Distinguish a confirmed bug from a design preference or an unfamiliar idiom. Trace state ownership: constructors and ordinary name references are not automatically problematic dependencies. Check outside writes and returned mutable storage before claiming an encapsulation problem.

Make authorized code changes with appropriate verification, or record tasks when asked. Revisit related explanations, paths, and anchors after refactoring. Teaching should reflect the final code, not the history of abandoned designs.

## Rebuild and inspect

Resolve highlights from unique start/end source anchors, not stored line numbers or fixed line counts. Rebuild source listings deterministically. A changed excerpt must trigger editorial review; do not accept a new digest merely to silence a warning. Source outside the highlighted excerpt can also change its meaning: review related behavior and tests rather than treating a matching digest as semantic proof.

Use the bundled dark Astro layout, bright syntax colors, separate line-number gutter, and mobile layout. Preserve full-height blank code rows (`min-height: 1.8em`) and the opaque amber selected-line background (`#584820`); keep surrounding code at full brightness. Verify repeated Next/Previous navigation, deep links, wrapping, and highlight visibility at a phone width and a short desktop viewport. Keep full files readable without JavaScript.

Use ordinary conversation for questions. Do not add in-page submission boxes or a chat backend by default. A source path and stable step link supply the discussion context. Deliver the generated file and rebuild command. If hosting is requested, use the user's chosen environment and verify its URL; do not assume localhost is reachable from a phone.
