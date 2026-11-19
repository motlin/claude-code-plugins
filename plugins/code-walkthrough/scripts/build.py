"""Render a source-backed walkthrough; built with bundled Astro components."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import shutil
import subprocess
import tempfile

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


ID_CHARACTERS = set('abcdefghijklmnopqrstuvwxyz0123456789-')
HASH_LINK = re.compile(r'href="#([^"]+)"')


def check_id(identifier, kind):
    if not identifier or not set(identifier) <= ID_CHARACTERS:
        raise ValueError(f'Use lowercase letters, digits, and hyphens for {kind} IDs: {identifier}')


def page_ids(spec, sections):
    """Each preface and section's page, in reading order: a section's page is its `id`, else its first step's."""
    pages = [part['id'] for part in spec.get('preface', [])] + [section.get('id') or section['steps'][0]['id'] for section in sections]
    for page in pages:
        check_id(page, 'page')
    if len(set(pages)) != len(pages):
        raise ValueError(f'Duplicate page ID: {next(page for page in pages if pages.count(page) > 1)}')
    return pages


def relink(html, here, homes):
    """Point `#id` links at the page that holds `id` when it is not `here`."""
    def target(match):
        home = homes.get(match.group(1))
        return match.group(0) if home in (None, here) else f'href="../{home}/#{match.group(1)}"'
    return HASH_LINK.sub(target, html)


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
            check_id(identifier, 'step')
            if identifier in identifiers:
                raise ValueError(f'Duplicate step ID: {identifier}')
            identifiers.add(identifier)
            first, last, digest = resolve(source, step['start'], step.get('end'))
            steps.append(dict(step, first=first, last=last, digest=digest,
                              stale=step.get('reviewed_sha256') != digest))
        sections.append(dict(section, source=source, steps=steps))
    return sections


def paginate(preface, sections, ids):
    """Give every preface and section its own page, rewriting links that cross pages."""
    homes = {part['id']: page for part, page in zip(preface, ids)}
    for index, (section, page) in enumerate(zip(sections, ids[len(preface):])):
        homes[f'section-{index + 1}'] = page
        homes.update({step['id']: page for step in section['steps']})
        homes.update({f'lab-{experiment["id"]}': page for experiment in section['experiments']})
    for part, page in zip(preface, ids):
        part['markup'] = relink(part['markup'], page, homes)
    for section, page in zip(sections, ids[len(preface):]):
        section['steps'] = [dict(step, html=relink(step['html'], page, homes)) for step in section['steps']]
        for experiment in section['experiments']:
            experiment['html'] = relink(experiment['html'], page, homes)
            experiment['markup'] = relink(experiment['markup'], page, homes)
    kinds = [('preface', index, part['title']) for index, part in enumerate(preface)]
    kinds += [('section', index, f'{index + 1:02d} · {section["title"]}') for index, section in enumerate(sections)]
    pages = []
    for position, (page, (kind, index, label)) in enumerate(zip(ids, kinds)):
        previous = None
        if position:
            previous = f'../{ids[position - 1]}/'
            if kinds[position - 1][0] == 'section':
                previous += '#' + sections[kinds[position - 1][1]]['steps'][-1]['id']
        following = f'../{ids[position + 1]}/' if position + 1 < len(ids) else None
        pages.append(dict(id=page, kind=kind, index=index, label=label, position=position + 1, previous=previous, next=following,
                          previous_page=dict(url=f'../{ids[position - 1]}/', label=kinds[position - 1][2]) if position else dict(url='../', label='Contents'),
                          next_page=dict(url=following, label=kinds[position + 1][2]) if following else None))
    return pages, homes


def render(spec, sections, root, runtime=None, single=False):
    runtime = (runtime or root / '.llm/code-walkthrough').resolve()
    cli = runtime / 'node_modules/astro/bin/astro.mjs'
    if not cli.exists():
        raise ValueError(f'Run scripts/setup.py --runtime {runtime} before building')
    formatter = HtmlFormatter(nowrap=True, style='native')
    warnings = []
    rendered = []
    for section in sections:
        lexer = get_lexer_by_name(section['language'], stripnl=False) if 'language' in section else get_lexer_for_filename(section['file'], stripnl=False)
        lines = highlight(section['source'], lexer, formatter).removesuffix('\n').split('\n')
        experiments = [dict(experiment, markup=within(root, experiment['file']).read_text())
                       for experiment in section.get('experiments', [])]
        rendered.append(dict(section, language=lexer.name, lines=lines, experiments=experiments))
        warnings.extend(step['id'] for step in section['steps'] if step['stale'])
    preface = [dict(part, markup=within(root, part['file']).read_text()) for part in spec.get('preface', [])]
    pages, homes = ([], {}) if single else paginate(preface, rendered, page_ids(spec, sections))
    data = dict(title=spec['title'], preface=preface, sections=rendered, pages=pages, moved=homes,
                scripts=[within(root, path).read_text() for path in spec.get('scripts', [])],
                references=spec.get('references', ''),
                status=f'{len(warnings)} explanations need source review.' if warnings else 'Source anchors and reviewed excerpts match.')
    with tempfile.TemporaryDirectory(prefix='build-', dir=runtime) as temporary:
        project = Path(temporary)
        shutil.copytree(PLUGIN / 'assets/astro', project, dirs_exist_ok=True)
        (project / 'node_modules').symlink_to(runtime / 'node_modules', target_is_directory=True)
        (project / 'src/data.json').write_text(json.dumps(data, ensure_ascii=False))
        (project / 'src/styles/syntax.css').write_text(formatter.get_style_defs('.source'))
        result = subprocess.run(['node', str(cli), 'build'], cwd=project, capture_output=True, text=True)
        if result.returncode:
            raise ValueError(f'Astro build failed:\n{result.stdout}\n{result.stderr}')
        dist = project / 'dist'
        files = {path.relative_to(dist).as_posix(): path.read_text() for path in sorted(dist.rglob('*')) if path.is_file()}
    return files, warnings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path.cwd())
    parser.add_argument('--spec', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True, help='Directory for the contents page and one page per preface and section; with --single-page, the HTML file')
    parser.add_argument('--single-page', action='store_true', help='Write the whole walkthrough as one HTML file, for small codebases')
    parser.add_argument('--runtime', type=Path, help='Renderer runtime installed by setup.py; defaults to ROOT/.llm/code-walkthrough')
    parser.add_argument('--check', action='store_true', help='Fail on stale HTML or unreviewed excerpts; leave specification and output unchanged')
    parser.add_argument('--review', action='append', default=[], metavar='STEP_ID', help='Record a reviewed excerpt; repeat for specific steps, or use all after reviewing every explanation')
    args = parser.parse_args()
    if args.check and args.review:
        parser.error('--check and --review cannot be combined')
    if not args.single_page and args.output.suffix == '.html':
        raise ValueError(f'Pages are written to a directory; pass --single-page for one HTML file: {args.output}')
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
    files, warnings = render(spec, sections, root, args.runtime, single=args.single_page)
    if args.single_page:
        files = {'': files['index.html']}
    if args.check:
        matches = all((args.output / name).is_file() and (args.output / name).read_text() == text for name, text in files.items())
        if warnings or not matches:
            print('Needs review: ' + ', '.join(warnings) if warnings else 'Rendered HTML is stale.', file=sys.stderr)
            return 1
        print('HTML matches current source and reviewed excerpts.')
        return 0
    if args.review:
        args.spec.write_text(json.dumps(spec, indent=2, ensure_ascii=False) + '\n')
    for name, text in files.items():
        (args.output / name).parent.mkdir(parents=True, exist_ok=True)
        (args.output / name).write_text(text)
    pages = '' if args.single_page else f' in {len(files)} pages'
    print(f'Built {args.output}: {len(sections)} complete source panels{pages}.')
    if warnings:
        print('Needs review: ' + ', '.join(warnings), file=sys.stderr)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, KeyError, OSError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(2)
