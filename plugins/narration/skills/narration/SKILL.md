---
name: narration
description: Narrate text as audio with Gemini text-to-speech. Use when asked to turn text or a URL into audio, make an audiobook, or compare text-to-speech voices.
---

# Narration

Resolve `<plugin-root>` before running the bundled script: `${CLAUDE_PLUGIN_ROOT}` in Claude Code; in Codex, the plugin root containing this `skills/narration/SKILL.md`. If `GEMINI_API_KEY` is not set, ask where the key lives; never print it or write it to a file.

## Prepare the text

Extract only the prose to be read: drop navigation, bylines, footnote markers, comment sections, and subscription prompts. For a book, write a manifest with one entry per chapter:

```json
{
	"title": "The Example Book",
	"author": "Alice Author",
	"chapters": [
		{ "title": "Chapter 1", "text": "First paragraph.\n\nSecond paragraph." },
		{ "title": "Chapter 2", "text": "..." }
	]
}
```

Each chapter title is spoken before its text. A single article is a manifest with one chapter. Keep the manifest and all output out of the repository's tracked files, and keep the source text out of the conversation.

## Choose a voice on a short sample

Settle the voice and style on a few sentences before paying for a long narration:

```bash
python3 <plugin-root>/scripts/narrate.py voices \
    --text-file sample.txt --output-directory voice-samples
```

Narrow it with `--voices Charon,Kore`. Add `--style "professional audiobook narration"` before `voices` to compare a style against the neutral samples on the same page. Tell the user the path to `index.html` and let them open it themselves.

Pace words are strong: "unhurried" slowed narration about 15%, and "brisk quick pace" sped it up 11% to 24%. Neutral delivery is already close to audiobook pace, so add a pace word only when the user asks for one, in their wording.

## Narrate

Narrate one chapter first and let the user listen before narrating the rest:

```bash
python3 <plugin-root>/scripts/narrate.py --style "professional audiobook narration" book \
    --manifest manifest.json --output-directory audiobook --voice Charon --chapters 1
```

Then run the same command without `--chapters` to get every chapter's MP3 plus `book.m4b` with chapter markers. Cached chunks are not billed again. Use a separate output directory for each voice or style variant so one never overwrites another. Report the output paths and total duration, and say when a run replaces an earlier version.

## Report cost before and after

Audio has measured about 32 output tokens per second, and narration runs roughly 150 to 200 words per minute, so estimate tokens from the word count. Look up the model's current price, state the estimate, and get approval before any run bigger than a sample. Afterward, report the token totals the script printed and the cost they imply, saying which figures are measured and which are estimated.
