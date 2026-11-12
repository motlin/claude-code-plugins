#!/usr/bin/env python3
"""Rank files for new tests by churn x (1 - coverage), skipping generated, vendored, test and trivial files.

Input is a normalized report from coverage_baseline.py. Churn is the number of commits that touched a
file since a git date such as `1.year`. Output is JSON: ranked targets with their uncovered lines, and
skipped files with the reason.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess

VENDORED = re.compile(r'(^|/)(vendor|vendored|third_party|node_modules)/')
GENERATED = re.compile(r'(^|/)(generated|gen|dist|build|target)/|_pb2\.py$|\.pb\.go$|_generated\.|\.min\.js$|\.g\.dart$')
TEST = re.compile(r'(^|/)(tests?|__tests__|spec)/|(^|/)test_[^/]*$|_test\.\w+$|\.(test|spec)\.\w+$|Tests?\.\w+$')


def skip_reason(path, entry, churn, min_lines):
    if VENDORED.search(path):
        return 'vendored'
    if GENERATED.search(path):
        return 'generated'
    if TEST.search(path):
        return 'test file'
    if entry['lines'] < min_lines:
        return 'trivial'
    if entry['covered'] >= entry['lines']:
        return 'fully covered'
    if not churn:
        return 'no recent churn'
    return None


def rank(coverage, churn, min_lines, limit):
    targets, skipped = [], []
    for path, entry in sorted(coverage.items()):
        commits = churn.get(path, 0)
        if reason := skip_reason(path, entry, commits, min_lines):
            skipped.append({'path': path, 'reason': reason})
            continue
        share = entry['covered'] / entry['lines']
        targets.append({'path': path, 'churn': commits, 'coverage': round(100 * share, 2),
                        'score': round(commits * (1 - share), 2), 'uncovered': entry['uncovered']})
    targets.sort(key=lambda target: (-target['score'], target['path']))
    return {'targets': targets[:limit], 'skipped': skipped}


def churn_counts(repo, since):
    log = subprocess.run(['git', 'log', f'--since={since}', '--no-renames', '--relative', '--name-only', '--format='],
                         cwd=repo, check=True, capture_output=True, text=True).stdout
    counts = {}
    for path in filter(None, log.splitlines()):
        counts[path] = counts.get(path, 0) + 1
    return counts


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('coverage', help='Normalized report from coverage_baseline.py')
    parser.add_argument('--root', default='.')
    parser.add_argument('--since', default='1.year')
    parser.add_argument('--min-lines', type=int, default=5)
    parser.add_argument('--limit', type=int, default=10)
    parser.add_argument('--paths', nargs='*', default=[], help='Only rank files under these directories')
    args = parser.parse_args(argv)

    coverage = json.loads(Path(args.coverage).read_text())
    if args.paths:
        prefixes = tuple(path.rstrip('/') + '/' for path in args.paths)
        coverage = {path: entry for path, entry in coverage.items() if path.startswith(prefixes)}
    print(json.dumps(rank(coverage, churn_counts(args.root, args.since), args.min_lines, args.limit), indent=2))


if __name__ == '__main__':
    main()
