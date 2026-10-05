# Source-backed authoring

The plugin root contains `scripts/build.py` and `assets/astro/`. Resolve that root from this file or the loaded skill location. Do not hardcode a plugin cache version. The bundled Astro components own presentation; the project specification owns teaching order and explanations. Node 22.12 or newer and Python 3 are required. Install pinned dependencies in a project-owned runtime:

```sh
python3 /path/to/plugin/scripts/setup.py --runtime .llm/code-walkthrough
```

This leaves the plugin unchanged. The runtime contains npm dependencies and a Python virtual environment.

Keep a JSON specification in the target repository, for example `docs/walkthrough.json`. Paths inside it are relative to the `--root` directory. CLI specification and output paths are relative to the command's working directory.

```json
{
	"title": "Example program",
	"sections": [
		{
			"file": "src/main.lua",
			"title": "Frame dispatch",
			"steps": [
				{
					"id": "frame-dispatch",
					"title": "Update the active scene",
					"start": "playdate.update = SceneManager.update",
					"html": "<p>Register the scene manager as the frame callback.</p>"
				}
			]
		}
	]
}
```

## Highlight anchors

`start` must be a nonempty, unique literal substring. Without `end`, highlight all lines occupied by `start`. For a block, supply `end` as a unique substring on its last line, possibly including preceding context to distinguish a generic closing brace or `end`. Both anchors must be unique across the complete file; the end must not precede the start. A multiline exact `start` also works when it is the clearest stable anchor.

Use stable, unique, lowercase hyphenated step IDs; they become shareable URL fragments. Reordering steps does not change those links. Each section shows one complete file and may explain its lines in a different order. Repeat a file in another section when the teaching path returns to it. Pygments detects syntax by filename; set `language` to a Pygments lexer name when the extension is ambiguous. Lua is supported explicitly via `"language": "lua"`.

## Build and review

```sh
.llm/code-walkthrough/.venv/bin/python /path/to/plugin/scripts/build.py --root . \
  --spec docs/walkthrough.json --output docs/walkthrough.html
```

New or changed excerpts render with a visible review notice. Read the current code and its explanation, revise as needed, then record the reviewed step:

```sh
.llm/code-walkthrough/.venv/bin/python /path/to/plugin/scripts/build.py --root . \
  --spec docs/walkthrough.json --output docs/walkthrough.html \
  --review frame-dispatch
```

Repeat `--review` for several reviewed steps. Use `--review all` only after reviewing all explanations, such as the initial authoring pass. The command records excerpt hashes in the JSON. Moving unchanged code updates line numbers without invalidating its review. Changing code within the highlighted range flags that explanation. Missing, duplicate, or reversed anchors fail before overwriting output.

```sh
.llm/code-walkthrough/.venv/bin/python /path/to/plugin/scripts/build.py --root . \
  --spec docs/walkthrough.json --output docs/walkthrough.html --check
```

`--check` leaves the specification and output unchanged (Astro builds in disposable runtime scratch space) and fails if output is stale or excerpts need review. Add it to the project's existing validation workflow when appropriate. Reproducibility assumes the same specification, sources, renderer, and pinned Astro and Pygments dependencies. Use `--runtime` to override the default `<root>/.llm/code-walkthrough` directory. A passing check verifies source alignment, not correctness of the authored explanation.

## Experiments and trusted content

An optional section `experiments` array contains objects with `id`, `title`, explanatory `html`, and `file` (a local HTML fragment). Each appears after its source panel. Scope styles and selectors to its container. Optional root `scripts` lists local JavaScript paths to inline, and `references` supplies footer HTML. Keep the generated page self-contained; do not introduce external assets unless requested. The renderer treats explanation HTML and experiment fragments as trusted author input; it escapes source code, titles, and paths. Review authored HTML before publishing it.

## Reading layout

The Astro page synchronizes page scrolling with a sticky code panel. Desktop explanations are on the left; mobile places the code above them. Readers can turn off automatic code scrolling to inspect the full file. Step links and the selector jump to explanations; Next/Previous use the same geometry as scroll activation. Honor reduced-motion settings. Test actual navigation, not only screenshots. Browser automation that scrolls a sticky button into view may itself change the active section; check real click behavior before mistaking that for a navigation defect.
