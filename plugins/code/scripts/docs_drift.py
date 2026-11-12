#!/usr/bin/env python3
"""List the docs to check for drift and extract their checkable claims.

`docs` lists README*, CLAUDE.md, AGENTS.md, SKILL.md and command files, optionally only those naming a file
changed since a git ref. `claims` checks paths and link targets against the tree and git renames, `just`
recipes and npm scripts against the justfile and package.json in both directions, `name@version` against
the manifest, and flags hard-coded counts. Statuses: `renamed` and `contradicted` with a `replacement` are
mechanical fixes, `contradicted` alone needs judgment, and `check` needs a look.
"""
import argparse
import json
import os
from pathlib import Path
import posixpath
import re
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from churn_rank import VENDORED  # noqa: E402

DOC_NAMES = {'CLAUDE.md', 'AGENTS.md', 'SKILL.md'}
LINK = re.compile(r'\[[^\]]*\]\(([^)\s]+)\)')
SPAN = re.compile(r'`([^`]+)`')
PATHLIKE = re.compile(r'^[\w.\-]+(/[\w.\-]+)+\.\w+$')
JUST = re.compile(r'\bjust\s+([A-Za-z][\w-]*)')
NPM = re.compile(r'\b(?:npm|pnpm|yarn|bun)\s+run\s+([\w:.-]+)')
RECIPE = re.compile(r'^@?([A-Za-z_][\w-]*)(?:\s[^:]*)?:(?!=)|^alias\s+([\w-]+)\s*:=')
NUMBER = r'\d+|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve'
COUNT = re.compile(rf'\b(?:{NUMBER})\s+(?:skills|plugins|commands|recipes|tracks|tests|files|scripts|agents|hooks|'
                   r'tools|rules|steps|checks)\b', re.IGNORECASE)


def git(root, *args):
    return subprocess.run(['git', *args], cwd=root, check=True, capture_output=True, text=True).stdout


def is_doc(path):
    return path.name.startswith('README') or path.name in DOC_NAMES or (
        path.parent.name == 'commands' and path.suffix == '.md')


def docs(root, paths, since=None):
    """The doc set under paths, relative to root, optionally only docs naming a file changed since a ref."""
    root = Path(root)
    found = []
    for directory, subdirs, files in os.walk(root):
        subdirs[:] = [name for name in subdirs if name != '.git']
        for name in files:
            relative = (Path(directory) / name).relative_to(root).as_posix()
            if is_doc(Path(relative)) and not VENDORED.search(relative):
                found.append(relative)
    if paths:
        prefixes = tuple(path.rstrip('/') + '/' for path in paths)
        found = [doc for doc in found if doc.startswith(prefixes) or doc in paths]
    if since is not None:
        changed = [path for path in git(root, 'diff', '--name-only', since, 'HEAD').splitlines() if path]
        found = [doc for doc in found if names_any(root, doc, changed)]
    return sorted(found)


def names_any(root, doc, changed):
    text = (Path(root) / doc).read_text(errors='replace')
    base = posixpath.dirname(doc) or '.'
    return any(path in text or posixpath.relpath(path, base) in text for path in changed)


def renames(root):
    """Old path to newest path, following chains of renames through history."""
    moves = {}
    log = subprocess.run(['git', 'log', '--diff-filter=R', '-M', '--name-status', '--format=', '--reverse'],
                         cwd=root, capture_output=True, text=True)
    for line in log.stdout.splitlines():
        parts = line.split('\t')
        if len(parts) == 3 and parts[0].startswith('R'):
            moves[parts[1]] = parts[2]
    for old in list(moves):
        seen = {old}
        while moves[old] in moves and moves[old] not in seen:
            seen.add(moves[old])
            moves[old] = moves[moves[old]]
    return moves


def bases(doc):
    """The doc's directory and every directory above it, up to the root."""
    base = posixpath.dirname(doc)
    found = [base]
    while base:
        base = posixpath.dirname(base)
        found.append(base)
    return found


def ignored(root, path):
    if path == '.git' or path.startswith('.git/'):
        return True
    return subprocess.run(['git', 'check-ignore', '-q', path], cwd=root, capture_output=True).returncode == 0


def check_path(root, doc, claim, moves):
    """None when the path exists or is gitignored, else the claim's status and replacement."""
    target = claim.split('#', 1)[0]
    candidates = [(posixpath.normpath(posixpath.join(base, target)), base) for base in bases(doc)]
    if any((Path(root) / path).exists() or ignored(root, path) for path, _ in candidates):
        return None
    for path, base in candidates:
        if path in moves and (Path(root) / moves[path]).exists():
            return {'status': 'renamed', 'replacement': posixpath.relpath(moves[path], base or '.')}
    return {'status': 'contradicted'}


def just_recipes(root):
    path = Path(root) / 'justfile'
    if not path.is_file():
        return None
    names = set()
    for line in path.read_text(errors='replace').splitlines():
        if match := RECIPE.match(line):
            names.add(match.group(1) or match.group(2))
    return names


def npm_scripts(root):
    path = Path(root) / 'package.json'
    if not path.is_file():
        return None
    return set(json.loads(path.read_text()).get('scripts', {}))


def manifest(root):
    """The project's (name, version), from package.json, Cargo.toml or pyproject.toml."""
    package = Path(root) / 'package.json'
    if package.is_file():
        data = json.loads(package.read_text())
        if data.get('name') and data.get('version'):
            return data['name'], data['version']
    for name in ('Cargo.toml', 'pyproject.toml'):
        path = Path(root) / name
        if path.is_file():
            text = path.read_text(errors='replace')
            found = re.search(r'^name\s*=\s*"([^"]+)"', text, re.M), re.search(r'^version\s*=\s*"([^"]+)"', text, re.M)
            if all(found):
                return found[0].group(1), found[1].group(1)
    return None


def code_text(line, in_fence):
    return line if in_fence else ' '.join(SPAN.findall(line))


def claims(root, doc_paths):
    moves = renames(root)
    recipes, scripts, project = just_recipes(root), npm_scripts(root), manifest(root)
    found, used_recipes, used_scripts = [], set(), set()

    def add(doc, number, kind, claim, result):
        entry = {'doc': doc, 'line': number, 'kind': kind, 'claim': claim, **result}
        if entry not in found:
            found.append(entry)

    for doc in doc_paths:
        in_fence = False
        for number, line in enumerate((Path(root) / doc).read_text(errors='replace').splitlines(), 1):
            if line.lstrip().startswith(('```', '~~~')):
                in_fence = not in_fence
                continue
            code = code_text(line, in_fence)
            spans = [] if in_fence else SPAN.findall(line)
            targets = [target for target in LINK.findall(line)
                       if re.search(r'[./]', target) and not re.match(r'^(\w+:|#)', target)]
            targets += [span for span in spans if PATHLIKE.match(span)]
            for target in targets:
                if result := check_path(root, doc, target, moves):
                    add(doc, number, 'path', target.split('#', 1)[0], result)
            for name in JUST.findall(code):
                used_recipes.add(name)
                if recipes is not None and name not in recipes:
                    add(doc, number, 'recipe', f'just {name}', {'status': 'contradicted'})
            for name in NPM.findall(code):
                used_scripts.add(name)
                if scripts is not None and name not in scripts:
                    add(doc, number, 'recipe', f'npm run {name}', {'status': 'contradicted'})
            if project:
                for version in re.findall(rf'\b{re.escape(project[0])}@v?(\d+\.\d+\.\d+)', line):
                    if version != project[1]:
                        add(doc, number, 'version', f'{project[0]}@{version}',
                            {'status': 'contradicted', 'replacement': f'{project[0]}@{project[1]}'})
            for count in COUNT.findall(line):
                add(doc, number, 'count', count, {'status': 'check'})

    for name in sorted((recipes or set()) - used_recipes):
        if name != 'default' and not name.startswith('_'):
            add(None, None, 'undocumented', f'just {name}', {'status': 'check'})
    for name in sorted((scripts or set()) - used_scripts):
        add(None, None, 'undocumented', f'npm run {name}', {'status': 'check'})
    return found


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--root', default='.')
    commands = parser.add_subparsers(dest='command', required=True)
    listing = commands.add_parser('docs', help='List the doc set')
    listing.add_argument('--since', help='Only docs naming a file changed since this git ref')
    listing.add_argument('paths', nargs='*', help='Only docs under these directories')
    check = commands.add_parser('claims', help='Check the claims in these docs')
    check.add_argument('--strict', action='store_true', help='Exit 1 while any mechanical fix remains')
    check.add_argument('docs', nargs='+')
    args = parser.parse_args(argv)

    if args.command == 'docs':
        print('\n'.join(docs(args.root, args.paths, args.since)))
        return
    found = claims(args.root, args.docs)
    print(json.dumps(found, indent=2))
    sys.exit(1 if args.strict and any('replacement' in entry for entry in found) else 0)


if __name__ == '__main__':
    main()
