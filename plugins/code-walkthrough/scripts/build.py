"""Render a source-backed walkthrough; requires Pygments (see requirements.txt)."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import sys

from pygments import highlight
from pygments.formatters import HtmlFormatter
from pygments.lexers import get_lexer_by_name, get_lexer_for_filename

PLUGIN = Path(__file__).resolve().parents[1]


def within(root, relative):
    path = (root / relative).resolve()
    if not path.is_relative_to(root):
        raise ValueError(f'Path escapes source root: {relative}')
    return path


def resolve(source, start, end=None):
    """Resolve unique, literal anchors to inclusive source lines."""
    for anchor in (start,) if end is None else (start, end):
        if not anchor or source.count(anchor) != 1:
            raise ValueError(f'Anchor must occur exactly once: {anchor!r}')
    begin = source.index(start)
    finish = begin + len(start) if end is None else source.index(end) + len(end)
    if end is not None and source.index(end) < begin:
        raise ValueError('End anchor precedes start anchor')
    first = source[:begin].count('\n') + 1
    last = source[:finish].rstrip('\n').count('\n') + 1
    excerpt = '\n'.join(source.splitlines()[first - 1:last])
    return first, last, hashlib.sha256(excerpt.encode()).hexdigest()


def prepare(spec, root):
    identifiers = set()
    sections = []
    if not spec['sections']:
        raise ValueError('At least one section is required')
    for section in spec['sections']:
        source = within(root, section['file']).read_text()
        if not section['steps']:
            raise ValueError(f'No explanations for {section["file"]}')
        steps = []
        for step in section['steps']:
            identifier = step['id']
            if not identifier or not all(c in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in identifier):
                raise ValueError(f'Use lowercase letters, digits, and hyphens for step IDs: {identifier}')
            if identifier in identifiers:
                raise ValueError(f'Duplicate step ID: {identifier}')
            identifiers.add(identifier)
            first, last, digest = resolve(source, step['start'], step.get('end'))
            steps.append(dict(step, first=first, last=last, digest=digest,
                              stale=step.get('reviewed_sha256') != digest))
        sections.append(dict(section, source=source, steps=steps))
    return sections


def render(spec, sections, root):
    formatter = HtmlFormatter(nowrap=True, style='native')
    panels = []
    options = []
    warnings = []
    for number, section in enumerate(sections, 1):
        path = html.escape(section['file'])
        lexer = get_lexer_by_name(section['language'], stripnl=False) if 'language' in section else get_lexer_for_filename(section['file'], stripnl=False)
        colored = highlight(section['source'], lexer, formatter).removesuffix('\n').split('\n')
        rows = ''.join(f'<span class="line" data-line="{i}"><span class="number" aria-hidden="true">{i}</span>{row}</span>' for i, row in enumerate(colored, 1))
        articles = []
        for step in section['steps']:
            title = html.escape(step['title'])
            options.append(f'<option value="{step["id"]}">{number}. {title}</option>')
            status = ''
            if step['stale']:
                warnings.append(step['id'])
                status = '<p class="warning">Source changed or explanation not yet reviewed. Check this explanation against the highlighted code.</p>'
            articles.append(f'<article class="step" id="{step["id"]}" data-first="{step["first"]}" data-last="{step["last"]}"><p class="location">{path} · <a href="#{step["id"]}">Lines {step["first"]}–{step["last"]}</a></p><h3>{title}</h3>{status}{step["html"]}</article>')
        experiment = ''
        if 'experiment' in section:
            experiment = '<section class="experiment">' + within(root, section['experiment']).read_text() + '</section>'
        panels.append(f'<section class="section"><div class="explanations"><h2>{html.escape(section["title"])}</h2>{"".join(articles)}</div><aside class="code-panel"><header><strong>{path}</strong><span>{html.escape(lexer.name)} · Complete file · {len(colored)} lines</span><output></output></header><pre class="source" tabindex="0" aria-label="Complete {path}"><code>{rows}</code></pre><footer><button class="follow" aria-pressed="true">Follow highlights: on</button></footer></aside></section>{experiment}')
    template = (PLUGIN / 'assets/template.html').read_text()
    replacements = {'TITLE': html.escape(spec['title']), 'OPTIONS': ''.join(options),
                    'SECTIONS': ''.join(panels), 'SYNTAX': formatter.get_style_defs('.source'),
                    'STATUS': f'{len(warnings)} explanations need source review.' if warnings else 'Source anchors and reviewed excerpts match.'}
    # A single substitution pass: source text cannot introduce template placeholders.
    import re
    page = re.sub(r'\{\{(TITLE|OPTIONS|SECTIONS|SYNTAX|STATUS)\}\}', lambda m: replacements[m[1]], template)
    return page, warnings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path.cwd())
    parser.add_argument('--spec', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--check', action='store_true', help='Fail on stale HTML or unreviewed excerpts; write nothing')
    parser.add_argument('--review', action='append', default=[], metavar='STEP_ID', help='Record a reviewed excerpt; repeat for specific steps, or use all after reviewing every explanation')
    args = parser.parse_args()
    if args.check and args.review:
        parser.error('--check and --review cannot be combined')
    root = args.root.resolve()
    spec = json.loads(args.spec.read_text())
    sections = prepare(spec, root)
    known = {step['id'] for section in sections for step in section['steps']}
    unknown = set(args.review) - known - {'all'}
    if unknown:
        parser.error(f'Unknown review IDs: {sorted(unknown)}')
    if args.review:
        for original, resolved in zip(spec['sections'], sections):
            for step, current in zip(original['steps'], resolved['steps']):
                if 'all' in args.review or step['id'] in args.review:
                    step['reviewed_sha256'] = current['digest']
        sections = prepare(spec, root)
    page, warnings = render(spec, sections, root)
    if args.check:
        matches = args.output.exists() and args.output.read_text() == page
        if warnings or not matches:
            print('Needs review: ' + ', '.join(warnings) if warnings else 'Rendered HTML is stale.', file=sys.stderr)
            return 1
        print('HTML matches current source and reviewed excerpts.')
        return 0
    if args.review:
        args.spec.write_text(json.dumps(spec, indent=2, ensure_ascii=False) + '\n')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(page)
    print(f'Built {args.output}: {len(sections)} complete source panels.')
    if warnings:
        print('Needs review: ' + ', '.join(warnings), file=sys.stderr)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, KeyError, OSError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(2)
