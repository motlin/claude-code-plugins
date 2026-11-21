# Source-backed authoring

The plugin root contains `scripts/build.py` and `assets/astro/`. Resolve that root from this file or the loaded skill location. Do not hardcode a plugin cache version. The bundled Astro components own presentation; the project specification owns teaching order and explanations. Node 22.12 or newer and Python 3 are required. Install pinned dependencies in a project-owned runtime:

```sh
python3 /path/to/plugin/scripts/setup.py --runtime .llm/code-walkthrough
```

This leaves the plugin unchanged. The runtime contains npm dependencies and a Python virtual environment.

Keep a JSON specification in the target repository, by default the untracked `.llm/walkthrough/walkthrough.json` (see the skill for when to commit it instead). Paths inside it are relative to the `--root` directory. CLI specification and output paths are relative to the command's working directory.

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

Use stable, unique, lowercase hyphenated step IDs; they become shareable URL fragments. The build writes one page per preface and section, so a large codebase does not load as one huge page: `site/index.html` is the contents page, and each section lives at `site/<id>/`, where `<id>` is the section's optional `id` or else its first step's ID. Give a section an explicit `id` to keep its URL when its first step changes. The arrows turn to the neighbouring page past a section's first and last step, links written as `#step-id` are rewritten to the page that holds that step, and the contents page redirects an old single-page link such as `#step-id` to its page. Readers can press `→`/`j` and `←`/`k` for the next and previous explanation, `]` and `[` for the next and previous page, `g` for the contents, and `?` for this list. Pass `--single-page` with an `.html` output path to get the whole walkthrough as one file, which suits small codebases. Reordering steps does not change those links. Each section shows one complete file and may explain its lines in a different order. Repeat a file in another section when the teaching path returns to it. Pygments detects syntax by filename; set `language` to a Pygments lexer name when the extension is ambiguous. Lua is supported explicitly via `"language": "lua"`.

For a language Pygments lacks, write a Pygments lexer class (usually a `RegexLexer` subclass with `aliases` and `filenames`) in a Python file in the project and list it in an optional root `lexers` array: `"lexers": [{"module": ".llm/walkthrough/toy_lexer.py", "class": "ToyLexer"}]`. `module` is relative to `--root` like other paths. Spec lexers are consulted first, in order: a section's `language` matches a lexer's `aliases`, and without `language` its file name matches a lexer's `filenames` patterns; otherwise Pygments' built-in lexers apply. Use standard Pygments token types so the page's syntax colors apply. The build runs the file as trusted code.

## Build and review

```sh
.llm/code-walkthrough/.venv/bin/python /path/to/plugin/scripts/build.py --root . \
  --spec .llm/walkthrough/walkthrough.json --output .llm/walkthrough/site
```

New or changed excerpts render with a visible review notice. Read the current code and its explanation, revise as needed, then record the reviewed step:

```sh
.llm/code-walkthrough/.venv/bin/python /path/to/plugin/scripts/build.py --root . \
  --spec .llm/walkthrough/walkthrough.json --output .llm/walkthrough/site \
  --review frame-dispatch
```

Repeat `--review` for several reviewed steps. Use `--review all` only after reviewing all explanations, such as the initial authoring pass. The command records excerpt hashes in the JSON. Moving unchanged code updates line numbers without invalidating its review. Changing code within the highlighted range flags that explanation. Missing, duplicate, or reversed anchors fail before overwriting output.

```sh
.llm/code-walkthrough/.venv/bin/python /path/to/plugin/scripts/build.py --root . \
  --spec .llm/walkthrough/walkthrough.json --output .llm/walkthrough/site --check
```

`--check` leaves the specification and output unchanged (Astro builds in disposable runtime scratch space) and fails if output is stale or excerpts need review. When the specification is committed, add it to the project's existing validation workflow so stale explanations fail the build. Reproducibility assumes the same specification, sources, renderer, and pinned Astro and Pygments dependencies. Use `--runtime` to override the default `<root>/.llm/code-walkthrough` directory. A passing check verifies source alignment, not correctness of the authored explanation.

## Experiments and trusted content

An optional section `experiments` array contains objects with `id`, `title`, explanatory `html`, and `file` (a local HTML fragment). Each appears after its source panel. Scope styles and selectors to its container. An optional root `preface` array holds prose sections shown before the first source section, such as a captured CLI demo or background the reader needs first: objects with a unique `id` (its URL fragment), a `title`, and `file` (a local HTML fragment, for example a Showboat demo from the `demo:demo` skill, with its styles scoped to the section's `id`). Preface sections have no source panel. In pages mode each gets its own page and selector entry; in a single page they are not in the selector, so link to them from their own contents. Optional root `scripts` lists local JavaScript paths to inline, and `references` supplies footer HTML. Keep the generated page self-contained; do not introduce external assets unless requested. The renderer treats explanation HTML and experiment fragments as trusted author input; it escapes source code, titles, and paths. Review authored HTML before publishing it.

## Reading layout

The Astro page synchronizes page scrolling with a sticky code panel. Desktop explanations are on the left; mobile places the code above them. Readers can turn off automatic code scrolling to inspect the full file. Step links and the selector jump to explanations; Next/Previous use the same geometry as scroll activation. Honor reduced-motion settings. Test actual navigation, not only screenshots. Browser automation that scrolls a sticky button into view may itself change the active section; check real click behavior before mistaking that for a navigation defect.
