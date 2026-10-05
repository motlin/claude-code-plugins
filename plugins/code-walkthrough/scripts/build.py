"""Render a source-backed walkthrough; built with bundled Astro components."""
import argparse
import hashlib
import json
from pathlib import Path
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


def render(spec, sections, root, runtime=None):
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
    data = dict(title=spec['title'], sections=rendered,
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
        page = (project / 'dist/index.html').read_text()
    return page, warnings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path.cwd())
    parser.add_argument('--spec', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--runtime', type=Path, help='Renderer runtime installed by setup.py; defaults to ROOT/.llm/code-walkthrough')
    parser.add_argument('--check', action='store_true', help='Fail on stale HTML or unreviewed excerpts; leave specification and output unchanged')
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
    page, warnings = render(spec, sections, root, args.runtime)
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
