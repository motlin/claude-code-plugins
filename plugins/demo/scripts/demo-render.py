#!/usr/bin/env python3

"""Render a Showboat demo document as one self-contained HTML page.

Showboat writes markdown; browsers, artifact hosts and static file servers want
HTML with nothing to fetch. This converts the one into the other and inlines
every referenced image, so the page survives being copied anywhere.

Nothing here touches the captured output — it only changes the wrapper around it.
"""

import argparse
import base64
import html
import mimetypes
import os
import re
import shutil
import subprocess
import sys
import tempfile

FONT_LINK = (
    '<link rel="stylesheet" '
    'href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;600'
    "&family=IBM+Plex+Sans:wght@400;600&display=swap\">"
)

# The page's material is terminal transcripts, so the mono face carries it and
# the one structural distinction worth drawing is input versus captured output.
STYLE = """
:root {
  color-scheme: light dark;
  --paper: #fbfaf8;
  --ink: #16191d;
  --muted: #69707a;
  --rule: #dcdfe3;
  --slab: #f1f0ed;
  --captured: #0f766e;
  --captured-wash: #0f766e12;
  --caveat: #b45309;
  --caveat-wash: #b4530912;
  --sans: "IBM Plex Sans", -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, sans-serif;
  --mono: "IBM Plex Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --paper: #14171a;
    --ink: #e8eaed;
    --muted: #9aa3ad;
    --rule: #2b3036;
    --slab: #1c2024;
    --captured: #5eead4;
    --captured-wash: #5eead410;
    --caveat: #fbbf24;
    --caveat-wash: #fbbf2410;
  }
}
:root[data-theme="dark"] {
  --paper: #14171a;
  --ink: #e8eaed;
  --muted: #9aa3ad;
  --rule: #2b3036;
  --slab: #1c2024;
  --captured: #5eead4;
  --captured-wash: #5eead410;
  --caveat: #fbbf24;
  --caveat-wash: #fbbf2410;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  background: var(--paper);
  color: var(--ink);
  font-family: var(--sans);
  font-size: 16px;
  line-height: 1.6;
}
.shell {
  max-width: 52rem;
  margin: 0 auto;
  padding: 3rem 1.25rem 6rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}
h1, h2, h3 { text-wrap: balance; font-weight: 600; line-height: 1.25; margin: 0; }
h1 { font-size: 1.9rem; padding-bottom: .4rem; border-bottom: 2px solid var(--ink); }
h2 { font-size: 1.3rem; margin-top: 2rem; }
h3 { font-size: 1.05rem; margin-top: 1.25rem; }
p, ul, ol { margin: 0; }
a { color: var(--captured); }
pre {
  margin: 0;
  padding: .85rem 1rem;
  border: 1px solid var(--rule);
  border-radius: 5px;
  background: var(--slab);
  overflow-x: auto;
  font-size: 13.5px;
  line-height: 1.5;
}
pre, code { font-family: var(--mono); }
pre code { background: none; padding: 0; font-size: inherit; }
code {
  padding: .12em .35em;
  border-radius: 3px;
  background: var(--slab);
  font-size: 90%;
}
/* Showboat fences captured output as ```output, so the machine's words can be
   told apart from the command that produced them. */
pre:has(code.language-output) {
  border-left: 3px solid var(--captured);
  background: var(--captured-wash);
}
blockquote {
  margin: 0;
  padding: .6rem 1rem;
  border-left: 3px solid var(--caveat);
  background: var(--caveat-wash);
}
blockquote p { margin: 0; }
img { max-width: 100%; border: 1px solid var(--rule); border-radius: 5px; }
table { border-collapse: collapse; width: 100%; font-variant-numeric: tabular-nums; }
th, td { padding: .4rem .6rem; border: 1px solid var(--rule); text-align: left; }
/* Showboat's byline sits directly under the title. */
h1 + p em { color: var(--muted); font-style: normal; font-size: .9rem; }
em { color: var(--muted); }
"""


def markdown_to_html(text):
    """Convert markdown, preferring an importable library over a subprocess."""
    try:
        from markdown_it import MarkdownIt
    except ImportError:
        pass
    else:
        return MarkdownIt("commonmark", {"html": True}).enable("table").render(text)

    # The markdown-it CLI reads a path, not stdin, so hand it one.
    if shutil.which("uvx"):
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as scratch:
            scratch.write(text)
            scratch_path = scratch.name
        try:
            done = subprocess.run(
                ["uvx", "--from", "markdown-it-py", "markdown-it", scratch_path],
                capture_output=True,
                text=True,
            )
        finally:
            os.unlink(scratch_path)
        if done.returncode == 0:
            return done.stdout
        sys.stderr.write(done.stderr)

    sys.exit(
        "demo-render: need markdown-it-py — `uv tool install markdown-it-py`, "
        "or `pip install markdown-it-py`"
    )


def inline_images(markup, base_dir):
    """Replace relative image sources with data URIs so the page stands alone."""

    def replace(match):
        src = html.unescape(match.group(1))
        if src.startswith(("http://", "https://", "data:")):
            return match.group(0)
        path = os.path.join(base_dir, src)
        if not os.path.isfile(path):
            sys.stderr.write(f"demo-render: missing image {path}\n")
            return match.group(0)
        mime = mimetypes.guess_type(path)[0] or "application/octet-stream"
        with open(path, "rb") as handle:
            data = base64.b64encode(handle.read()).decode("ascii")
        return f'src="data:{mime};base64,{data}"'

    return re.sub(r'src="([^"]+)"', replace, markup)


def first_heading(text, fallback):
    for line in text.split("\n"):
        if line.startswith("# "):
            return line[2:].strip()
    return fallback


def main():
    parser = argparse.ArgumentParser(description="Render a Showboat document as HTML.")
    parser.add_argument("document", help="Showboat markdown file, e.g. .llm/demo/notes.md")
    parser.add_argument("-o", "--output", help="Write here instead of stdout")
    parser.add_argument("--title", help="Page title. Default: the document's first heading")
    parser.add_argument(
        "--fragment",
        action="store_true",
        help="Emit head contents and body markup only, for hosts that supply their "
        "own document skeleton (Claude Artifacts)",
    )
    args = parser.parse_args()

    with open(args.document, "r", errors="replace") as handle:
        text = handle.read()

    title = args.title or first_heading(text, os.path.basename(args.document))
    body = inline_images(markdown_to_html(text), os.path.dirname(os.path.abspath(args.document)))
    head = f"<title>{html.escape(title)}</title>\n{FONT_LINK}\n<style>{STYLE}</style>"

    if args.fragment:
        page = f'{head}\n<main class="shell">\n{body}</main>\n'
    else:
        page = (
            "<!doctype html>\n"
            '<html lang="en"><head><meta charset="utf-8">\n'
            '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
            f"{head}</head><body>\n"
            f'<main class="shell">\n{body}</main>\n'
            "</body></html>\n"
        )

    if args.output:
        with open(args.output, "w") as handle:
            handle.write(page)
        print(args.output)
    else:
        sys.stdout.write(page)


if __name__ == "__main__":
    main()
