---
name: narration
description: Narrate text as audio with Gemini text-to-speech. Use when asked to turn text or a URL into audio, make an audiobook, or compare text-to-speech voices.
---

# Narration

Turn text into narrated audio with the bundled `scripts/narrate.py`. It calls the Gemini interactions endpoint, caches every synthesized chunk, and encodes with `ffmpeg`. Resolve `<plugin-root>` before running it: `${CLAUDE_PLUGIN_ROOT}` in Claude Code; in Codex, the plugin root containing this `skills/narration/SKILL.md`.

The script needs `ffmpeg` on the path and `GEMINI_API_KEY` in the environment. If the key is missing, ask where it lives; never print it or write it to a file.

## Pass directions with `--style`

Everything in the text is read aloud. Pass delivery directions through `--style`, which the script sends as speech metadata, and omit it for the voice's neutral delivery.

Pace words are strong. "Unhurried" made a narration about 15% slower than neutral, and "brisk quick pace" made it 11% to 24% faster. Neutral delivery is already close to a typical audiobook pace, so add a pace word only when the user asks for one, and use their wording.

## Prepare the text

Fetch the source and extract only the prose to be read: drop navigation, bylines, footnote markers, comment sections, and subscription prompts. Separate paragraphs with a blank line; the script breaks chunks only between paragraphs.

For a book, write a manifest with one entry per chapter:

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

Each chapter title is spoken before its text. A single article is a manifest with one chapter. Keep the manifest and all scratch output out of the repository's tracked files. Do not paste the source text into the conversation.

## Choose a voice on a short sample

Settle the voice and style on a few sentences before paying for a long narration. Put the sample text in a file and build a comparison page:

```bash
python3 <plugin-root>/scripts/narrate.py voices \
    --text-file sample.txt --output-directory voice-samples
```

This samples every voice and writes `index.html` with one player per file. Narrow it with `--voices Charon,Kore`. Add `--style "professional audiobook narration"` before `voices` to hear a style; styled samples are written beside the neutral ones as `<Voice>-<style>.mp3`, so the page compares them.

Tell the user the path to `index.html` and let them open it. Do not launch an audio player for them. Voice names such as `Charon` are Google's own names, so the user can share them; the same name can sound different on another model.

## Narrate

Narrate one chapter first, in the settled voice and style, and let the user listen before narrating the rest:

```bash
python3 <plugin-root>/scripts/narrate.py --style "professional audiobook narration" book \
    --manifest manifest.json --output-directory audiobook --voice Charon --chapters 1
```

Then run the same command without `--chapters`. It writes `chapter-NN.mp3` for every chapter and `book.m4b` with chapter markers. Chunks are cached under `parts/` by text, voice, style, and model, so finished chapters are not billed again, an interrupted run resumes, and changing the style or voice regenerates everything it affects.

Use a separate output directory for each voice or style variant the user wants to compare, so one never overwrites another.

A long narration takes minutes. Run it in the background and report when it finishes rather than blocking.

## Report cost before and after

Each run prints the audio output tokens it was billed for. Audio has measured about 32 output tokens per second, and narration runs roughly 150 to 200 words per minute, so estimate tokens from the word count before a long run. Look up the current per-token price for the model rather than quoting one from memory, state the estimate, and get the user's approval before any run that costs more than a sample. Afterward, report the printed token totals and the cost they imply, and say which figures are measured and which are estimated.

## Verify before delivering

Confirm the run printed every chapter and that `book.m4b` lists one marker per chapter with `ffprobe -show_chapters`. After changing the model, the endpoint, or how directions are passed, also confirm nothing but the text is spoken: transcribe the first seconds of two or three chunks with a Gemini text model and check that each begins with the chapter's own words.

Report the output paths, total duration, and cost. When a run replaces an earlier version, say so.
