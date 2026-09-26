---
name: investigation-report
description: 'Produce a single self-contained HTML report that explains a command-line investigation — the commands actually run, their real output, and just enough reasoning to teach it. Use when the user asks for a walkthrough, tutorial, write-up, teaching artifact, or "show me how you did that" of a shell debugging or exploration session.'
---

# Command-Line Investigation Report

Produce a chronological command log as one HTML page: what you ran, what it printed, and enough reasoning that the reader could rerun it and understand every flag. The goal is teaching, not a status update.

Before designing it, read [Red Blob Games' Making of: Circle drawing tutorial](https://www.redblobgames.com/making-of/circle-drawing/) as the quality benchmark for teaching through an HTML page.

## Structure it as a chronological command log

Walk the investigation in the order it happened, including dead ends, wrong hypotheses, and the commands that disproved them. Do not sanitize it into a clean after-the-fact story. Each step is the command, its real output, one line of why you ran it, and, only where the evidence changed your conclusion, a short "changed my mind" note. Make those turning points stand out; they are the spine of the story.

## Show real commands and real output

- Reproduce commands verbatim. Never clean up flags or show a command you did not run.
- Paste actual output, trimmed to what matters, and mark every cut visibly (e.g. `... ~60 more lines ...`).
- For commands that revealed nothing useful, skip the output and just note what you ran and why.

## Explain unfamiliar commands and flags

- For non-obvious commands, add a breakdown with one plain-language row per flag.
- Split fused flags: `-nrk3` is `-n -r -k3`.
- Explain a pipeline inside-out, like nested parentheses: command substitution first, then the tools it feeds.
- For a likely unfamiliar tool (e.g. `pgrep`), add a short "what is X": the basics, the flags used here, and its closest sibling (`pgrep`/`pkill`).
- Let the reader's questions drive depth: skip what they know, expand what they ask about.

## Keep commentary out

Cut editorializing, "lessons learned" summaries, and meta-commentary about method unless asked. Prefer "here is what I did" over "here is what you should learn."

## End with a command reference

Close with a compact table mapping question → command → what to read from the output.

## Keep styling minimal

Emit one self-contained HTML file with no external assets, so it opens with a double-click. Keep styling minimal and do not ask the user about it.

## Deliver and open the file

Write it to a durable location (the project directory or wherever the user names, not a scratch or temp path), then `open <file>`.
