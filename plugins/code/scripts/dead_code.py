#!/usr/bin/env python3
"""Find dead-code detectors and gather reference evidence for a symbol.

`detect` lists the dead-code detectors a repository has configured or installed, with the commands to run.
`refs` greps the whole repository for a symbol as a word, string matches included, leaves out its definition,
and splits the matches into code and tests with a verdict: unreferenced, test-only or referenced.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from churn_rank import TEST  # noqa: E402

REWRITE_RECIPES = (
    'org.openrewrite.staticanalysis.RemoveUnusedPrivateMethods',
    'org.openrewrite.staticanalysis.RemoveUnusedPrivateFields',
    'org.openrewrite.staticanalysis.RemoveUnusedLocalVariables',
)


def mentions(root, names, needle):
    for name in names:
        path = Path(root) / name
        if path.is_file() and needle in path.read_text(errors='replace'):
            return True
    return False


def detect(root, which=shutil.which):
    """Each dead-code detector the repository has configured or installed, with its commands."""
    root = Path(root)
    found = []
    if mentions(root, ['package.json'], '"knip"') or (root / 'knip.json').is_file():
        found.append(('knip', ['npx knip', 'npx knip --production']))
    python = ['pyproject.toml', 'setup.cfg', 'requirements-dev.txt', 'requirements.txt']
    if mentions(root, python, 'vulture') or (any((root / name).is_file() for name in python) and which('vulture')):
        found.append(('vulture', ['vulture {paths}']))
    if (root / 'go.mod').is_file() and which('deadcode'):
        found.append(('deadcode', ['deadcode -test ./...', 'deadcode -test -whylive={symbol} ./...']))
    if (root / 'Cargo.toml').is_file() and which('cargo-machete'):
        found.append(('cargo-machete', ['cargo machete']))
    if mentions(root, ['pom.xml'], 'rewrite-maven-plugin'):
        found.append(('openrewrite-maven', ['mvn rewrite:dryRun -Drewrite.activeRecipes=' + ','.join(REWRITE_RECIPES)]))
    return [{'tool': tool, 'commands': commands} for tool, commands in found]


def refs(root, symbol, definition):
    """Every tracked line naming symbol as a word, except its definition at `file:line`, split by tests."""
    grep = subprocess.run(['git', 'grep', '-n', '-w', '-F', '-I', '-e', symbol], cwd=root, capture_output=True, text=True)
    if grep.returncode > 1:
        raise RuntimeError(grep.stderr)
    code, tests = [], []
    for match in grep.stdout.splitlines():
        path, line, _ = match.split(':', 2)
        if f'{path}:{line}' == definition:
            continue
        (tests if TEST.search(path) else code).append(match)
    verdict = 'referenced' if code else 'test-only' if tests else 'unreferenced'
    return {'symbol': symbol, 'verdict': verdict, 'code': code, 'tests': tests}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--root', default='.')
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('detect', help='List configured or installed dead-code detectors')
    find = commands.add_parser('refs', help='Grep the repository for a symbol, leaving out its definition')
    find.add_argument('symbol')
    find.add_argument('--definition', default='', help='The `file:line` that defines the symbol')
    args = parser.parse_args(argv)

    if args.command == 'detect':
        print(json.dumps(detect(args.root), indent=2))
    else:
        print(json.dumps(refs(args.root, args.symbol, args.definition), indent=2))


if __name__ == '__main__':
    main()
