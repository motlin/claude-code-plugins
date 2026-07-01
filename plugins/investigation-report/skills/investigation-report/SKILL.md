---
name: investigation-report
description: 'Produce a single self-contained HTML report that explains a command-line investigation — the commands actually run, their real output, and just enough reasoning to teach it. Use when the user asks for a walkthrough, tutorial, write-up, teaching artifact, or "show me how you did that" of a shell debugging or exploration session.'
---

# Command-Line Investigation Report

When asked to explain or document a command-line investigation, produce a chronological command log as a single HTML page: what you ran, what it printed, and enough reasoning that the reader could rerun it and understand every flag. The goal is teaching, not a status update.

## Structure it as a chronological command log

Walk the investigation in the order it actually happened — including dead ends, wrong hypotheses, and the command that disproved them. Do not sanitize it into a clean after-the-fact story; the wrong turns are where the learning is. Each step is: the command, its real output, one line of why you ran it, and — only where the evidence changed your conclusion — a short "changed my mind" note.

## Show real commands and real output

- Reproduce commands verbatim. Never invent flags, clean them up, or show a command you didn't run.
- Paste the actual output, trimmed to what's relevant.
- When you trim output, mark the cut visibly (e.g. `... ~60 more lines ...`). Silent truncation reads as "this was the whole output" — always show that something was removed.
- Skip output entirely for commands that revealed nothing useful; just note what you ran and why.

## Explain unfamiliar commands and flags

- For any command or flag that isn't obvious, add a breakdown: one row per flag, in plain language.
- Split fused flags apart — e.g. `-nrk3` is `-n -r -k3`.
- Explain a pipeline inside-out, like nested parentheses (command substitution first, then the tools it feeds).
- When a whole tool is likely unfamiliar (e.g. `pgrep`), add a short "what is X" explainer: the basics, the flags used here, and its closest sibling (`pgrep`/`pkill`).
- Pitch explanations at the reader. Let their questions drive which breakdowns to add — skip what they already know, expand what they ask about, and add detail on request rather than up front.

## Keep reasoning short; mark the turning points

- One line of "why I ran this" per command is plenty.
- Reserve emphasis for the moments where evidence changed the conclusion. Those turning points are the spine of the story — make them stand out.
- Cut editorializing, "lessons learned" summaries, and meta-commentary about method unless asked. Prefer "here is what I did" over "here is what you should learn."

## End with a command reference

Close with a compact table mapping question → command → what to read from the output. This is the reusable cheat-sheet the reader keeps after the specific incident fades.

## Styling is not the point

Emit one self-contained HTML file with no external assets, so it opens with a double-click. Keep visual styling minimal and out of the way — the content is the command log, not the design. Don't spend effort on elaborate CSS, and don't ask the user to weigh in on it.

## Deliver and open the file

Write it to a durable location (the project directory, or wherever the user names — not a scratch/temp path they'll lose). Then open it (`open <file>` on macOS) so the user can read it right away.
