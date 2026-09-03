#!/usr/bin/env python3

"""Render a captured demo as a self-contained HTML page (or markdown).

Reads only what demo-capture and demo-attach wrote. Command output is copied
from the captured files verbatim, so the rendered demo cannot drift from what
actually ran.
"""

import argparse
import base64
import html
import mimetypes
import os
import sys

IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg"}
TEXT_SUFFIXES = {".txt", ".log", ".json", ".jsonl", ".sql", ".csv", ".tsv", ".md", ".yaml", ".yml", ".xml", ".ddl"}


def read(path, default=""):
    try:
        with open(path, "r", errors="replace") as handle:
            return handle.read().rstrip("\n")
    except OSError:
        return default


def read_lines(path):
    try:
        with open(path, "r", errors="replace") as handle:
            return handle.read().split("\n")
    except OSError:
        return []


def trim(lines, head, tail):
    """Trim to head+tail lines, returning (lines, omitted_count)."""
    while lines and lines[-1] == "":
        lines.pop()
    if len(lines) <= head + tail:
        return lines, 0
    omitted = len(lines) - head - tail
    return lines[:head] + [f"… {omitted:,} lines omitted …"] + lines[-tail:], omitted


def load_steps(demo_dir):
    steps_dir = os.path.join(demo_dir, "steps")
    if not os.path.isdir(steps_dir):
        sys.exit(f"demo-render: no steps in {demo_dir}")
    steps = []
    for name in sorted(os.listdir(steps_dir)):
        step_dir = os.path.join(steps_dir, name)
        if not os.path.isdir(step_dir):
            continue
        steps.append(
            {
                "id": name,
                "dir": step_dir,
                "kind": read(os.path.join(step_dir, "kind"), "command"),
                "title": read(os.path.join(step_dir, "title"), name),
                "why": read(os.path.join(step_dir, "why")),
                "look_for": read(os.path.join(step_dir, "look_for")),
                "command": read(os.path.join(step_dir, "command")),
                "cwd": read(os.path.join(step_dir, "cwd")),
                "exit": read(os.path.join(step_dir, "exit")),
                "duration": read(os.path.join(step_dir, "duration_seconds")),
                "redactions": [p for p in read(os.path.join(step_dir, "redactions")).split("\n") if p],
                "attachment": read(os.path.join(step_dir, "attachment")),
                "source_path": read(os.path.join(step_dir, "source_path")),
            }
        )
    return steps


def attachment_block_html(step, demo_dir):
    name = step["attachment"]
    path = os.path.join(step["dir"], name)
    suffix = os.path.splitext(name)[1].lower()
    relative = os.path.relpath(path, demo_dir)
    if suffix in IMAGE_SUFFIXES and os.path.isfile(path):
        mime = mimetypes.guess_type(name)[0] or "application/octet-stream"
        with open(path, "rb") as handle:
            data = base64.b64encode(handle.read()).decode("ascii")
        return f'<img alt="{html.escape(name)}" src="data:{mime};base64,{data}">\n<p class="meta">{html.escape(relative)}</p>'
    if suffix in TEXT_SUFFIXES and os.path.isfile(path):
        lines, _ = trim(read_lines(path), 40, 20)
        body = html.escape("\n".join(lines))
        return f'<p class="meta">{html.escape(relative)}</p>\n<pre>{body}</pre>'
    size = os.path.getsize(path) if os.path.isfile(path) else 0
    return f'<p class="meta">{html.escape(relative)} ({size:,} bytes)</p>'


def stream_block_html(step, stream, head, tail):
    path = os.path.join(step["dir"], stream)
    if not os.path.isfile(path) or os.path.getsize(path) == 0:
        return ""
    lines, omitted = trim(read_lines(path), head, tail)
    label = "stdout" if stream == "stdout" else "stderr"
    note = f" — full output in <code>{html.escape(path)}</code>" if omitted else ""
    body = html.escape("\n".join(lines))
    return f'<p class="meta">{label}{note}</p>\n<pre class="{stream}">{body}</pre>'


def render_html(demo_dir, steps, head, tail):
    title = read(os.path.join(demo_dir, "title"), os.path.basename(demo_dir.rstrip("/")))
    created = read(os.path.join(demo_dir, "created"))
    commit = read(os.path.join(demo_dir, "git_commit"))
    dirty = read(os.path.join(demo_dir, "git_dirty"))
    host = read(os.path.join(demo_dir, "host"))
    cwd = read(os.path.join(demo_dir, "cwd"))

    provenance = []
    if created:
        provenance.append(f"captured {html.escape(created)}")
    if commit:
        label = html.escape(commit[:12]) + (" (working tree dirty)" if dirty else "")
        provenance.append(f"commit {label}")
    if host:
        provenance.append(f"on {html.escape(host)}")
    if cwd:
        provenance.append(f"in <code>{html.escape(cwd)}</code>")

    parts = [
        "<!doctype html>",
        '<html lang="en"><head><meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        f"<title>{html.escape(title)}</title>",
        "<style>",
        ":root{color-scheme:light dark}",
        "body{font:15px/1.55 -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;max-width:60rem;margin:2rem auto;padding:0 1rem}",
        "h1{margin-bottom:.25rem}",
        "h2{margin-top:2.5rem;border-bottom:1px solid #8884;padding-bottom:.25rem}",
        "pre{background:#8881;padding:.75rem;border-radius:4px;overflow-x:auto;font-size:13px;line-height:1.4}",
        "pre.stderr{border-left:3px solid #c66}",
        "code{font-size:13px}",
        ".meta{color:#8a8a8a;font-size:13px;margin:.5rem 0 .25rem}",
        ".why{margin:.25rem 0 .75rem}",
        ".look{background:#ffd7001a;border-left:3px solid #d4a72c;padding:.5rem .75rem;margin:.75rem 0}",
        ".fail{color:#c33;font-weight:600}",
        ".banner{background:#8881;padding:.75rem 1rem;border-radius:4px;font-size:13px}",
        "img{max-width:100%;border:1px solid #8884;border-radius:4px}",
        "ol.toc{color:#8a8a8a}",
        "</style></head><body>",
        f"<h1>{html.escape(title)}</h1>",
        f'<p class="meta">{" &middot; ".join(provenance)}</p>' if provenance else "",
        '<p class="banner">Every command and every byte of output below was recorded by '
        "<code>demo-capture</code> as it ran. Nothing here was typed by hand.</p>",
        '<ol class="toc">',
    ]
    for step in steps:
        parts.append(f'<li><a href="#{step["id"]}">{html.escape(step["title"])}</a></li>')
    parts.append("</ol>")

    for step in steps:
        parts.append(f'<h2 id="{step["id"]}">{html.escape(step["title"])}</h2>')
        if step["why"]:
            parts.append(f'<p class="why">{html.escape(step["why"])}</p>')
        if step["kind"] == "command":
            parts.append(f'<pre class="cmd">$ {html.escape(step["command"])}</pre>')
            details = []
            if step["cwd"]:
                details.append(f'in <code>{html.escape(step["cwd"])}</code>')
            if step["duration"]:
                details.append(f'{step["duration"]}s')
            if step["exit"] and step["exit"] != "0":
                details.append(f'<span class="fail">exit {html.escape(step["exit"])}</span>')
            if step["redactions"]:
                patterns = ", ".join(f"<code>{html.escape(p)}</code>" for p in step["redactions"])
                details.append(f"redacted: {patterns}")
            if details:
                parts.append(f'<p class="meta">{" &middot; ".join(details)}</p>')
            parts.append(stream_block_html(step, "stdout", head, tail))
            parts.append(stream_block_html(step, "stderr", head, tail))
        elif step["attachment"]:
            parts.append(attachment_block_html(step, demo_dir))
        if step["look_for"]:
            parts.append(f'<p class="look">{html.escape(step["look_for"])}</p>')

    parts.append("</body></html>")
    return "\n".join(part for part in parts if part)


def render_markdown(demo_dir, steps, head, tail):
    title = read(os.path.join(demo_dir, "title"), os.path.basename(demo_dir.rstrip("/")))
    commit = read(os.path.join(demo_dir, "git_commit"))
    created = read(os.path.join(demo_dir, "created"))
    out = [f"# {title}", ""]
    if created or commit:
        out.append(f"Captured {created} at commit {commit[:12]}." if commit else f"Captured {created}.")
        out.append("")
    out.append("Every command and its output below was recorded by `demo-capture` as it ran.")
    out.append("")
    for step in steps:
        out.append(f"## {step['title']}")
        out.append("")
        if step["why"]:
            out.extend([step["why"], ""])
        if step["kind"] == "command":
            out.extend(["```console", f"$ {step['command']}"])
            for stream in ("stdout", "stderr"):
                path = os.path.join(step["dir"], stream)
                if os.path.isfile(path) and os.path.getsize(path) > 0:
                    lines, _ = trim(read_lines(path), head, tail)
                    out.extend(lines)
            out.extend(["```", ""])
            if step["exit"] and step["exit"] != "0":
                out.extend([f"Exit status {step['exit']}.", ""])
        elif step["attachment"]:
            out.extend([f"![{step['title']}]({os.path.relpath(os.path.join(step['dir'], step['attachment']), demo_dir)})", ""])
        if step["look_for"]:
            out.extend([f"> {step['look_for']}", ""])
    return "\n".join(out)


def main():
    parser = argparse.ArgumentParser(description="Render a captured demo.")
    parser.add_argument("demo_dir", help="Demo directory, e.g. .llm/demo/import-pipeline")
    parser.add_argument("-o", "--output", help="Write here instead of stdout")
    parser.add_argument("--format", choices=("html", "md"), default="html")
    parser.add_argument("--head", type=int, default=40, help="Leading output lines kept per stream")
    parser.add_argument("--tail", type=int, default=20, help="Trailing output lines kept per stream")
    args = parser.parse_args()

    demo_dir = args.demo_dir.rstrip("/")
    steps = load_steps(demo_dir)
    if args.format == "html":
        text = render_html(demo_dir, steps, args.head, args.tail)
    else:
        text = render_markdown(demo_dir, steps, args.head, args.tail)

    if args.output:
        with open(args.output, "w") as handle:
            handle.write(text + "\n")
        print(args.output)
    else:
        print(text)


if __name__ == "__main__":
    main()
