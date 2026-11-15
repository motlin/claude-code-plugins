#!/usr/bin/env python3
"""Run a build once and group the warnings in its output into classes with counts.

`run` executes the build and test command once, saves its combined output, and classifies it.
`classify` groups the warning lines of a saved log. Each group has a kind (compiler, lint, deprecation,
runtime, slow-test, noise or other), the rule id or deprecated API it shares, its count, the files it names,
and whether every file lies outside the repository's control. `compare` reads two reports from the same
command and prints each class's count before and after, exiting 1 unless the total fell.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess

ANSI = re.compile(r'\x1b\[[0-9;]*[A-Za-z]')
THIRD_PARTY = {'node_modules', 'site-packages', 'dist-packages', 'vendor', '.venv', 'venv', '.m2', '.cargo', '.gradle'}

PYTHON = re.compile(r'^\s*(?P<file>[^\s:][^:]*?):(?P<line>\d+):\s*(?P<cat>\w*Warning):\s*(?P<msg>.*)$')
NODE = re.compile(r'^\(node:\d+\)\s+(?:\[(?P<code>[\w-]+)\]\s+)?(?P<cat>\w*Warning):\s*(?P<msg>.*)$')
NPM = re.compile(r'^npm (?:warn|WARN)\s+deprecated\s+(?P<pkg>@?[^@\s:]+)(?:@[^\s:]+)?:\s*(?P<msg>.*)$')
NPM_WARN = re.compile(r'^npm (?:warn|WARN)\s+(?P<category>[\w-]+)\b')
COMPILER = re.compile(r'^\s*(?P<file>[^\s:][^:]*?):(?P<line>\d+)(?::\d+)?:\s*warning:\s*(?P<msg>.*)$')
MAVEN = re.compile(r'^\[WARNING\]\s+(?P<file>\S+?):\[\d+,\d+\]\s+(?P<msg>.*)$')
RUST = re.compile(r'^warning:\s*(?P<msg>.*)$')
RUST_SUMMARY = re.compile(r'generated \d+ warnings?|\d+ warnings? emitted')
RUST_FILE = re.compile(r'^\s*-->\s*(?P<file>[^:\s]+):\d+')
RUST_RULE = re.compile(r'#\[warn\((?P<rule>[\w:]+)\)\]')
ESLINT_FILE = re.compile(r'^(?P<file>\S+\.\w+)$')
ESLINT = re.compile(r'^\s+\d+:\d+\s+warning\s+(?P<msg>.+?)\s{2,}(?P<rule>[\w@/-]+)$')
PYTEST_DURATION = re.compile(r'^(?P<secs>\d+(?:\.\d+)?)s\s+(?:call|setup|teardown)\s+(?P<test>\S+)')
JS_DURATION = re.compile(r'^\s*[✓✔√]\s+(?P<name>.+?)\s+\(?(?P<ms>\d+)\s?ms\)?$')
CONSOLE = re.compile(r'^\s*console\.(?P<level>log|info|debug|warn|error)$')
STACK_FILE = re.compile(r'\bat (?:.*\()?(?P<file>[^\s():]+):\d+:\d+\)?')
LOG_LINE = re.compile(r'^\[?\d{4}-\d\d-\d\d[T ][\d:.,]+\]?\s+\[?(?P<level>TRACE|DEBUG|INFO|WARN|WARNING)\]?\s')
FALLBACK = re.compile(r'(?i)\bwarn(?:ing)?\b\s*[:\]]')


def normalize(message):
    return re.sub(r'\d+', 'N', ' '.join(message.split()))[:200]


def compiler_warning(file, message):
    rule = re.search(r'\[(-W[\w-]+)\]\s*$', message) or re.match(r'\[(\w+)\]\s*', message)
    rule = rule.group(1) if rule else ''
    if rule in ('deprecation', 'removal') or 'deprecat' in message.lower():
        text = re.sub(r'^\[\w+\]\s*', '', message)
        return 'deprecation', rule, normalize(text), file
    return 'compiler', rule, rule or file, file


def lookahead(lines, start, pattern, stop_at_blank=True, limit=12):
    for line in lines[start + 1:start + 1 + limit]:
        if stop_at_blank and not line.strip():
            return None
        match = pattern.search(line)
        if match:
            return match
    return None


def warnings(lines, slow):
    """Yield (kind, rule, source, file, line) for each warning line."""
    eslint_file = ''
    for index, line in enumerate(lines):
        if match := PYTHON.match(line):
            deprecated = 'Deprecat' in match['cat']
            yield ('deprecation' if deprecated else 'runtime', match['cat'], normalize(match['msg']), match['file'], line)
        elif match := NODE.match(line):
            kind = 'deprecation' if match['cat'].startswith('Deprecation') else 'runtime'
            yield kind, match['code'] or match['cat'], match['code'] or normalize(match['msg']), '', line
        elif match := NPM.match(line):
            yield 'deprecation', 'npm-deprecated', match['pkg'], '', line
        elif match := NPM_WARN.match(line):
            yield 'other', match['category'], f'npm {match["category"]}', '', line
        elif (match := COMPILER.match(line)) or (match := MAVEN.match(line)):
            yield (*compiler_warning(match['file'], match['msg']), line)
        elif match := RUST.match(line):
            if RUST_SUMMARY.search(match['msg']):
                continue
            file = lookahead(lines, index, RUST_FILE)
            rule = lookahead(lines, index, RUST_RULE)
            rule = rule['rule'] if rule else ''
            file = file['file'] if file else ''
            if 'deprecated' in match['msg']:
                yield 'deprecation', rule or 'deprecated', normalize(match['msg']), file, line
            else:
                yield 'lint' if rule.startswith('clippy::') else 'compiler', rule, rule or normalize(match['msg']), file, line
        elif match := ESLINT_FILE.match(line):
            eslint_file = match['file']
        elif (match := ESLINT.match(line)) and eslint_file:
            yield 'lint', match['rule'], match['rule'], eslint_file, line
        elif match := PYTEST_DURATION.match(line):
            if float(match['secs']) >= slow:
                file = match['test'].split('::')[0]
                yield 'slow-test', 'slow', file, file, line
        elif match := JS_DURATION.match(line):
            if int(match['ms']) / 1000 >= slow:
                name = re.sub(r'\s*\(\d+ tests?\)', '', match['name'])
                yield 'slow-test', 'slow', name, '', line
        elif match := CONSOLE.match(line):
            stack = lookahead(lines, index, STACK_FILE, stop_at_blank=False, limit=8)
            rule = f'console.{match["level"]}'
            yield 'noise', rule, stack['file'] if stack else rule, stack['file'] if stack else '', line
        elif match := LOG_LINE.match(line):
            rule = f'log.{match["level"]}'
            yield 'runtime' if match['level'].startswith('WARN') else 'noise', rule, rule, '', line
        elif FALLBACK.search(line):
            text = line.strip()
            kind = 'deprecation' if 'deprecat' in text.lower() else 'other'
            yield kind, '', normalize(text), '', line


def relative(root, file):
    if not file:
        return ''
    path = Path(file)
    if path.is_absolute():
        try:
            return path.relative_to(root).as_posix()
        except ValueError:
            return file
    return path.as_posix()


def third_party(files):
    return bool(files) and all(Path(file).is_absolute() or THIRD_PARTY & set(Path(file).parts) for file in files)


def classify(text, root, slow=1.0):
    """Group the warning lines of a build log by kind and source, in order of first appearance."""
    lines = [ANSI.sub('', line) for line in text.splitlines()]
    groups = {}
    for kind, rule, source, file, line in warnings(lines, slow):
        file = relative(root, file)
        group = groups.setdefault((kind, rule, source), {
            'kind': kind, 'rule': rule, 'source': source, 'count': 0, 'files': [], 'example': line.strip()})
        group['count'] += 1
        if file and file not in group['files']:
            group['files'].append(file)
    kinds = {}
    for group in groups.values():
        group['files'].sort()
        group['thirdParty'] = third_party(group['files'])
        kinds[group['kind']] = kinds.get(group['kind'], 0) + group['count']
    return {'total': sum(kinds.values()), 'kinds': kinds, 'groups': list(groups.values())}


def run(root, command, log=None, slow=1.0):
    """Run the build once in root, save its combined output to log, and classify it."""
    shell = len(command) == 1
    result = subprocess.run(command[0] if shell else command, shell=shell, cwd=root,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors='replace')
    if log:
        Path(log).write_text(result.stdout)
    return {'command': command, 'exitCode': result.returncode, **classify(result.stdout, root, slow)}


def compare(before, after):
    """Each class's count in two reports from the same command, and whether the total fell."""
    counts = {}
    for side, report in (('before', before), ('after', after)):
        for group in report['groups']:
            entry = counts.setdefault((group['kind'], group['source']),
                                      {'kind': group['kind'], 'source': group['source'], 'before': 0, 'after': 0})
            entry[side] += group['count']
    return {'before': before['total'], 'after': after['total'], 'reduced': after['total'] < before['total'],
            'classes': list(counts.values())}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--root', default='.')
    parser.add_argument('--slow', type=float, default=1.0, help='Seconds at which a test counts as slow')
    commands = parser.add_subparsers(dest='command', required=True)
    run_parser = commands.add_parser('run', help='Run the build once and classify its output')
    run_parser.add_argument('--log', help='Where to save the combined output')
    run_parser.add_argument('build', nargs=argparse.REMAINDER, help='The command, after --; one argument runs in a shell')
    classify_parser = commands.add_parser('classify', help='Classify a saved build log')
    classify_parser.add_argument('log')
    compare_parser = commands.add_parser('compare', help='Compare two reports; exit 1 unless the total fell')
    compare_parser.add_argument('before')
    compare_parser.add_argument('after')
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    if args.command == 'run':
        build = args.build[1:] if args.build[:1] == ['--'] else args.build
        if not build:
            parser.error('run needs a command after --')
        print(json.dumps(run(root, build, args.log, args.slow), indent=2))
    elif args.command == 'classify':
        print(json.dumps(classify(Path(args.log).read_text(errors='replace'), root, args.slow), indent=2))
    else:
        result = compare(*(json.loads(Path(path).read_text()) for path in (args.before, args.after)))
        print(json.dumps(result, indent=2))
        if not result['reduced']:
            raise SystemExit(1)


if __name__ == '__main__':
    main()
