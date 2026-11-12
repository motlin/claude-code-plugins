#!/usr/bin/env python3
"""Detect a repository's coverage tooling, run it, and normalize its report to one JSON shape.

The normalized report maps each source path, relative to the repository root, to
{"lines": N, "covered": M, "uncovered": [line, ...], "partial": [line, ...]}. A partial line ran
but left some branch untaken. Supported reports: LCOV (Jest, Vitest, cargo tarpaulin), Cobertura
XML (pytest-cov), Go coverprofiles and JaCoCo XML.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ElementTree

ECOSYSTEMS = {
    'vitest': (['npx', 'vitest', 'run', '--coverage', '--coverage.reporter=lcov'], 'coverage/lcov.info', 'lcov'),
    'jest': (['npx', 'jest', '--coverage', '--coverageReporters=lcov'], 'coverage/lcov.info', 'lcov'),
    'pytest': (['python', '-m', 'pytest', '--cov', '--cov-report=xml:coverage.xml'], 'coverage.xml', 'cobertura'),
    'go': (['go', 'test', '-coverprofile=coverage.out', './...'], 'coverage.out', 'gocover'),
    'tarpaulin': (['cargo', 'tarpaulin', '--out', 'Lcov', '--output-dir', 'target/tarpaulin'],
                  'target/tarpaulin/lcov.info', 'lcov'),
    'jacoco-maven': (['mvn', 'verify'], '**/target/site/jacoco/jacoco.xml', 'jacoco'),
    'jacoco-gradle': (['./gradlew', 'test', 'jacocoTestReport'],
                      '**/build/reports/jacoco/test/jacocoTestReport.xml', 'jacoco'),
}
PYTEST_MARKERS = {'pytest.ini': '', 'conftest.py': '', 'pyproject.toml': 'pytest', 'setup.cfg': 'pytest',
                  'tox.ini': 'pytest', 'requirements-dev.txt': 'pytest', 'requirements.txt': 'pytest'}


def read(root, name):
    path = Path(root) / name
    return path.read_text(errors='replace') if path.is_file() else None


def detect(root):
    """Each coverage ecosystem the repository uses, with the command that writes its report."""
    found = []
    package = read(root, 'package.json')
    if package is not None:
        manifest = json.loads(package)
        deps = {**manifest.get('dependencies', {}), **manifest.get('devDependencies', {})}
        found += [name for name in ('vitest', 'jest') if name in deps]
    if any((text := read(root, name)) is not None and marker in text for name, marker in PYTEST_MARKERS.items()):
        found.append('pytest')
    if read(root, 'go.mod') is not None:
        found.append('go')
    if read(root, 'Cargo.toml') is not None:
        found.append('tarpaulin')
    if 'jacoco' in (read(root, 'pom.xml') or ''):
        found.append('jacoco-maven')
    if any('jacoco' in (read(root, name) or '') for name in ('build.gradle', 'build.gradle.kts')):
        found.append('jacoco-gradle')
    return [dict(zip(('ecosystem', 'command', 'report', 'format'), (name, *ECOSYSTEMS[name]))) for name in found]


def relative(root, path):
    path = Path(path)
    if path.is_absolute():
        path = path.resolve().relative_to(Path(root).resolve())
    return path.as_posix()


class Lines:
    """Accumulates per-line hits and partial branches for each file across reports."""

    def __init__(self):
        self.hits, self.partial = {}, {}

    def add(self, path, line, hit, partial=False):
        lines = self.hits.setdefault(path, {})
        lines[line] = lines.get(line, False) or hit
        if partial:
            self.partial.setdefault(path, set()).add(line)

    def result(self):
        return {path: {'lines': len(lines),
                       'covered': sum(lines.values()),
                       'uncovered': sorted(line for line, hit in lines.items() if not hit),
                       'partial': sorted(line for line in self.partial.get(path, ()) if lines.get(line))}
                for path, lines in sorted(self.hits.items())}


def parse_lcov(report, root, lines):
    path = None
    for raw in Path(report).read_text().splitlines():
        tag, _, value = raw.partition(':')
        if tag == 'SF':
            path = relative(root, value)
        elif tag == 'DA':
            line, hits = value.split(',')[:2]
            lines.add(path, int(line), int(hits) > 0)
        elif tag == 'BRDA':
            line, _, _, taken = value.split(',')
            if taken in ('-', '0'):
                lines.add(path, int(line), False, partial=True)


def parse_cobertura(report, root, lines):
    tree = ElementTree.parse(report).getroot()
    sources = [source.text for source in tree.iter('source') if source.text] or ['.']
    for element in tree.iter('class'):
        name = element.get('filename')
        base = next((source for source in sources if (Path(root) / source / name).exists()), sources[0])
        path = relative(root, Path(base, name))
        for line in element.iter('line'):
            covered = re.search(r'\((\d+)/(\d+)\)', line.get('condition-coverage', ''))
            lines.add(path, int(line.get('number')), int(line.get('hits')) > 0,
                      partial=bool(covered) and covered[1] != covered[2])


def parse_gocover(report, root, lines):
    module = re.search(r'^module\s+(\S+)', read(root, 'go.mod') or '', re.MULTILINE)
    prefix = module[1] + '/' if module else ''
    covered = {}
    for raw in Path(report).read_text().splitlines()[1:]:
        found = re.match(r'(.+):(\d+)\.\d+,(\d+)\.\d+ \d+ (\d+)$', raw)
        if not found:
            continue
        name, start, end, count = found.groups()
        path = name.removeprefix(prefix)
        for line in range(int(start), int(end) + 1):
            covered.setdefault(path, {}).setdefault(line, False)
            covered[path][line] |= int(count) > 0
    for path, by_line in covered.items():
        for line, hit in by_line.items():
            lines.add(path, line, hit)


def parse_jacoco(report, root, lines):
    for package in ElementTree.parse(report).getroot().iter('package'):
        for source in package.iter('sourcefile'):
            suffix = f"{package.get('name')}/{source.get('name')}"
            matches = sorted(Path(root).glob(f'**/{suffix}'))
            path = relative(root, matches[0].resolve()) if len(matches) == 1 else suffix
            for line in source.iter('line'):
                missed, hit = int(line.get('mb')), int(line.get('cb'))
                lines.add(path, int(line.get('nr')), int(line.get('ci')) > 0, partial=missed > 0 and hit > 0)


PARSERS = {'lcov': parse_lcov, 'cobertura': parse_cobertura, 'gocover': parse_gocover, 'jacoco': parse_jacoco}


def parse(fmt, reports, root):
    lines = Lines()
    for report in reports:
        PARSERS[fmt](report, root, lines)
    return lines.result()


def percent(covered, total):
    return round(100 * covered / total, 2) if total else 100.0


def compare(before, after):
    """Per-file and total coverage change.

    gained is true when no line lost coverage and either more lines are covered or a partial line lost its untaken branch.
    """
    files, resolved_total = [], 0
    for path in sorted(after):
        old = before.get(path, {'lines': after[path]['lines'], 'covered': 0, 'partial': []})
        new = after[path]
        gained = new['covered'] - old['covered']
        resolved = len(set(old['partial']) - set(new['partial']) - set(new['uncovered']))
        resolved_total += resolved
        if gained or resolved or percent(old['covered'], old['lines']) != percent(new['covered'], new['lines']):
            files.append({'path': path, 'before': percent(old['covered'], old['lines']),
                          'after': percent(new['covered'], new['lines']), 'gained_lines': gained,
                          'resolved_partial': resolved})
    totals = [(sum(f['covered'] for f in side.values()), sum(f['lines'] for f in side.values()))
              for side in (before, after)]
    gained_lines = totals[1][0] - totals[0][0]
    return {'files': files,
            'total': {'before': percent(*totals[0]), 'after': percent(*totals[1]), 'gained_lines': gained_lines,
                      'resolved_partial': resolved_total},
            'gained': gained_lines >= 0 and (gained_lines > 0 or resolved_total > 0)}


def annotate(source, entry):
    """Source with line numbers, `!` on uncovered lines and `~` on partially covered ones."""
    uncovered, partial = set(entry['uncovered']), set(entry['partial'])
    return ''.join(f"{number:6} {'!' if number in uncovered else '~' if number in partial else ' '}  {text}\n"
                   for number, text in enumerate(source.splitlines(), 1))


def run(root, chosen):
    """Run each detected coverage command and merge the normalized reports."""
    merged = {}
    for ecosystem in chosen:
        result = subprocess.run(ecosystem['command'], cwd=root, stdout=sys.stderr)
        reports = sorted(Path(root).glob(ecosystem['report']))
        if result.returncode != 0 or not reports:
            sys.exit(f"{ecosystem['ecosystem']}: exit {result.returncode}, {len(reports)} report(s) found")
        merged.update(parse(ecosystem['format'], reports, root))
    return merged


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--root', default='.')
    commands = parser.add_subparsers(dest='command', required=True)

    commands.add_parser('detect', help='Print the detected ecosystems as JSON')

    run_command = commands.add_parser('run', help='Run coverage and print the normalized report')
    run_command.add_argument('--ecosystem', action='append', help='Limit to these detected ecosystems')

    parse_command = commands.add_parser('parse', help='Normalize existing report files')
    parse_command.add_argument('--format', required=True, choices=sorted(PARSERS))
    parse_command.add_argument('reports', nargs='+')

    compare_command = commands.add_parser('compare', help='Compare two normalized reports; exit 1 without a line or branch gain')
    compare_command.add_argument('before')
    compare_command.add_argument('after')

    annotate_command = commands.add_parser('annotate', help='Print a source file with its coverage tags')
    annotate_command.add_argument('coverage')
    annotate_command.add_argument('path')

    args = parser.parse_args(argv)
    root = args.root
    if args.command == 'detect':
        print(json.dumps(detect(root), indent=2))
    elif args.command == 'run':
        chosen = [e for e in detect(root) if not args.ecosystem or e['ecosystem'] in args.ecosystem]
        if not chosen:
            sys.exit('No coverage ecosystem detected')
        print(json.dumps(run(root, chosen), indent=2))
    elif args.command == 'parse':
        print(json.dumps(parse(args.format, args.reports, root), indent=2))
    elif args.command == 'compare':
        result = compare(*(json.loads(Path(path).read_text()) for path in (args.before, args.after)))
        print(json.dumps(result, indent=2))
        sys.exit(0 if result['gained'] else 1)
    elif args.command == 'annotate':
        entry = json.loads(Path(args.coverage).read_text())[args.path]
        sys.stdout.write(annotate((Path(root) / args.path).read_text(), entry))


if __name__ == '__main__':
    main()
