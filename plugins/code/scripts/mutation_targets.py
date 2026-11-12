#!/usr/bin/env python3
"""Pick lines to mutate and check that a mutation run changed only tests.

`detect` lists the mutation tools a repository has configured or installed, with a line-scoped command.
`targets` ranks files from a coverage_baseline.py report by churn and picks, in each, up to a few covered,
non-arid lines that carry a mutable operator, at most one mutant per line. `changed` lists changed files
that are not tests and exits 1 when there are any, proving every hand-written mutant was restored.
"""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from churn_rank import GENERATED, TEST, VENDORED, churn_counts  # noqa: E402

KINDS = (
    ('relational', re.compile(r'\s(===|!==|==|!=|<=|>=|<|>)\s')),
    ('logical', re.compile(r'\b(and|or|not)\b|&&|\|\||(?<![\w!=])!(?=[\w(])')),
    ('return', re.compile(r'^return\b')),
    ('arithmetic', re.compile(r'\s[-+*/%]\s')),
)
COMMENT = re.compile(r'^(#|//|/\*|\*|--)')
ARID = re.compile(r'\b(log|logger|logging|console|print|println|printf|eprintln|time|Date|datetime|now|sleep|'
                  r'deadline|timeout|clock|metrics?|counter|gauge|histogram|trace|tracing|span|reserve|'
                  r'with_capacity|ensureCapacity)\b')


def mentions(root, names, needle):
    for name in names:
        path = Path(root) / name
        if path.is_file() and needle in path.read_text(errors='replace'):
            return True
    return False


def detect(root, which=shutil.which):
    """Each mutation tool the repository has configured or installed, with its line- or file-scoped command."""
    found = []
    if mentions(root, ['package.json'], '@stryker-mutator/core'):
        found.append(('stryker', 'npx stryker run --incremental --mutate {file}:{lines}'))
    if mentions(root, ['pom.xml'], 'pitest'):
        found.append(('pit-maven', 'mvn org.pitest:pitest-maven:mutationCoverage -DtargetClasses={class}'))
    if mentions(root, ['build.gradle', 'build.gradle.kts'], 'pitest'):
        found.append(('pit-gradle', './gradlew pitest -Dpitest.targetClasses={class}'))
    if mentions(root, ['pyproject.toml', 'setup.cfg', 'requirements-dev.txt', 'requirements.txt'], 'mutmut'):
        found.append(('mutmut', 'mutmut run'))
    if (Path(root) / 'Cargo.toml').is_file() and which('cargo-mutants'):
        found.append(('cargo-mutants', 'cargo mutants --file {file}'))
    return [{'tool': tool, 'command': command} for tool, command in found]


def kind(text):
    for name, pattern in KINDS:
        if pattern.search(text):
            return name
    return None


def candidates(source, entry, per_file):
    """Up to per_file covered, non-arid lines with a mutable operator, the most productive operators first."""
    uncovered = set(entry['uncovered'])
    found = []
    for number, line in enumerate(source.splitlines(), 1):
        text = line.strip()
        if number in uncovered or not text or COMMENT.match(text) or ARID.search(text):
            continue
        if found_kind := kind(text):
            found.append({'line': number, 'kind': found_kind, 'text': text})
    priority = [name for name, _ in KINDS]
    chosen = sorted(found, key=lambda line: (priority.index(line['kind']), line['line']))[:per_file]
    return sorted(chosen, key=lambda line: line['line'])


def skip_reason(path, entry, churn):
    if VENDORED.search(path):
        return 'vendored'
    if GENERATED.search(path):
        return 'generated'
    if TEST.search(path):
        return 'test file'
    if not entry['covered']:
        return 'no covered lines'
    if not churn:
        return 'no recent churn'
    return None


def targets(root, coverage, churn, per_file, limit):
    ranked, skipped = [], []
    for path, entry in sorted(coverage.items()):
        commits = churn.get(path, 0)
        source = Path(root) / path
        reason = skip_reason(path, entry, commits) or (None if source.is_file() else 'missing source')
        lines = [] if reason else candidates(source.read_text(errors='replace'), entry, per_file)
        if not reason and not lines:
            reason = 'no mutable covered lines'
        if reason:
            skipped.append({'path': path, 'reason': reason})
        else:
            ranked.append({'path': path, 'churn': commits, 'lines': lines})
    ranked.sort(key=lambda target: (-target['churn'], target['path']))
    return {'targets': ranked[:limit], 'skipped': skipped}


def non_test_changes(root):
    """Changed or untracked files, relative to HEAD, that are not test files."""
    def git(*args):
        return subprocess.run(['git', *args], cwd=root, check=True, capture_output=True, text=True).stdout

    paths = set(git('diff', '--name-only', '-z', 'HEAD').split('\0'))
    paths |= set(git('ls-files', '--others', '--exclude-standard', '-z').split('\0'))
    return sorted(path for path in paths if path and not TEST.search(path))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--root', default='.')
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('detect', help='List configured or installed mutation tools')
    pick = commands.add_parser('targets', help='Rank files by churn and pick lines to mutate')
    pick.add_argument('coverage', help='Normalized report from coverage_baseline.py')
    pick.add_argument('--since', default='1.year')
    pick.add_argument('--per-file', type=int, default=7)
    pick.add_argument('--limit', type=int, default=10)
    pick.add_argument('--paths', nargs='*', default=[], help='Only rank files under these directories')
    commands.add_parser('changed', help='List changed files that are not tests; exit 1 if any')
    args = parser.parse_args(argv)

    if args.command == 'detect':
        print(json.dumps(detect(args.root), indent=2))
    elif args.command == 'targets':
        coverage = json.loads(Path(args.coverage).read_text())
        if args.paths:
            prefixes = tuple(path.rstrip('/') + '/' for path in args.paths)
            coverage = {path: entry for path, entry in coverage.items() if path.startswith(prefixes)}
        churn = churn_counts(args.root, args.since)
        print(json.dumps(targets(args.root, coverage, churn, args.per_file, args.limit), indent=2))
    else:
        changes = non_test_changes(args.root)
        print('\n'.join(changes))
        sys.exit(1 if changes else 0)


if __name__ == '__main__':
    main()
