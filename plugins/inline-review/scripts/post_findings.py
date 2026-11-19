#!/usr/bin/env python3
"""Validate review findings against a patch and post them into a Plannotator review session.

Each finding becomes a Plannotator external annotation. Plannotator's POST ignores
Conventional Comments fields, so each created annotation is then PATCHed with its
label and decorations. A rerun first deletes the annotations of the previous run.
"""
import argparse
import json
from pathlib import Path
import re
import sys
import urllib.request

SOURCE = 'inline-review'
LABELS = {
    'praise', 'nitpick', 'suggestion', 'issue', 'todo', 'question',
    'thought', 'chore', 'note', 'typo', 'polish',
}
DECORATIONS = {'blocking', 'non-blocking', 'if-minor'}
NIT_LABELS = {'nitpick', 'typo', 'polish'}
SIDES = {'old', 'new'}

HUNK = re.compile(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@')


def parse_patch(text):
    """Map each file's new path to the line numbers its hunks display on each side."""
    files = {}
    current = None
    old_line = new_line = 0
    in_hunk = False
    for line in text.splitlines():
        if line.startswith('diff --git '):
            current = line.rsplit(' b/', 1)[1]
            files[current] = {'old': set(), 'new': set()}
            in_hunk = False
            continue
        if current is None:
            continue
        if line.startswith('rename to '):
            files[line[len('rename to '):]] = files.pop(current)
            current = line[len('rename to '):]
            continue
        match = HUNK.match(line)
        if match:
            old_line, new_line = int(match[1]), int(match[2])
            in_hunk = True
            continue
        if not in_hunk:
            continue
        if line.startswith('-'):
            files[current]['old'].add(old_line)
            old_line += 1
        elif line.startswith('+'):
            files[current]['new'].add(new_line)
            new_line += 1
        elif line.startswith(' ') or line == '':
            files[current]['old'].add(old_line)
            files[current]['new'].add(new_line)
            old_line += 1
            new_line += 1
    return files


def _validate(index, finding):
    label = finding.get('label')
    if label not in LABELS:
        raise ValueError(f'findings[{index}]: unknown label {label!r}')
    for decoration in finding.get('decorations', []):
        if decoration not in DECORATIONS:
            raise ValueError(f'findings[{index}]: unknown decoration {decoration!r}')
    if finding.get('side', 'new') not in SIDES:
        raise ValueError(f"findings[{index}]: side must be 'old' or 'new'")
    for field in ('title', 'body'):
        if not isinstance(finding.get(field), str) or not finding[field].strip():
            raise ValueError(f'findings[{index}]: missing {field}')


def _severity(finding):
    if finding.get('pre_existing'):
        return 'pre_existing'
    if finding['label'] == 'issue' and 'blocking' in finding.get('decorations', []):
        return 'important'
    if finding['label'] in NIT_LABELS:
        return 'nit'
    return None


def _placement(finding, files):
    """Return (scope, filePath, lineStart, lineEnd, location note for the text)."""
    path = finding.get('file') or ''
    line = finding.get('line')
    end = finding.get('end_line') or line
    side = finding.get('side', 'new')
    if path not in files:
        note = f' (`{path}:{line}`)' if path and line else (f' (`{path}`)' if path else '')
        return 'general', '', 0, 0, note
    if line is None:
        return 'file', path, 0, 0, ''
    shown = files[path][side]
    if all(n in shown for n in range(line, end + 1)):
        return 'line', path, line, end, ''
    span = f'lines {line}-{end}' if end != line else f'line {line}'
    return 'file', path, 0, 0, f' ({span})'


def _annotation(finding, files):
    scope, path, start, end, note = _placement(finding, files)
    if finding.get('suggested_code'):
        kind = 'suggestion'
    elif finding['label'] == 'issue':
        kind = 'concern'
    else:
        kind = 'comment'
    annotation = {
        'source': SOURCE,
        'author': SOURCE,
        'type': kind,
        'scope': scope,
        'filePath': path,
        'lineStart': start,
        'lineEnd': end,
        'side': finding.get('side', 'new'),
        'text': f"**{finding['title']}**{note}\n\n{finding['body']}",
    }
    if finding.get('suggested_code'):
        annotation['suggestedCode'] = finding['suggested_code']
    severity = _severity(finding)
    if severity:
        annotation['severity'] = severity
    if finding.get('reasoning'):
        annotation['reasoning'] = finding['reasoning']
    if finding.get('sources'):
        annotation['reviewProfileLabel'] = ', '.join(finding['sources'])
    patch = {'conventionalLabel': finding['label']}
    if finding.get('decorations'):
        patch['decorations'] = list(finding['decorations'])
    return {'annotation': annotation, 'patch': patch}


def build_annotations(review, files):
    """Turn a review document ({summary?, findings}) into annotation/patch pairs."""
    items = []
    if review.get('summary'):
        items.append({
            'annotation': {
                'source': SOURCE,
                'author': SOURCE,
                'type': 'comment',
                'scope': 'general',
                'filePath': '',
                'lineStart': 0,
                'lineEnd': 0,
                'side': 'new',
                'text': f"**Review summary**\n\n{review['summary']}",
            },
            'patch': {'conventionalLabel': 'note'},
        })
    for index, finding in enumerate(review.get('findings', [])):
        _validate(index, finding)
        items.append(_annotation(finding, files))
    return items


def http_send(method, url, body=None):
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(url, data=data, method=method, headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(request) as response:
        raw = response.read()
    return json.loads(raw) if raw else {}


def post(items, session_url, send=http_send):
    base = session_url.rstrip('/') + '/api/external-annotations'
    send('DELETE', f'{base}?source={SOURCE}')
    if not items:
        return []
    created = send('POST', base, {'annotations': [item['annotation'] for item in items]})
    ids = created['ids']
    for annotation_id, item in zip(ids, items):
        send('PATCH', f'{base}?id={annotation_id}', item['patch'])
    return ids


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--findings', required=True, type=Path, help='review JSON: {summary?, findings: [...]}')
    parser.add_argument('--diff', required=True, type=Path, help='patch the findings refer to')
    parser.add_argument('--url', help='Plannotator session URL; omit to print the payload only')
    args = parser.parse_args(argv)

    review = json.loads(args.findings.read_text())
    try:
        items = build_annotations(review, parse_patch(args.diff.read_text()))
    except ValueError as error:
        print(f'error: {error}', file=sys.stderr)
        return 2
    if not args.url:
        json.dump(items, sys.stdout, indent=2)
        print()
        return 0
    ids = post(items, args.url)
    scopes = {}
    for item in items:
        scope = item['annotation']['scope']
        scopes[scope] = scopes.get(scope, 0) + 1
    print(f'posted {len(ids)} annotations to {args.url} ({", ".join(f"{n} {s}" for s, n in sorted(scopes.items()))})')
    return 0


if __name__ == '__main__':
    sys.exit(main())
