#!/usr/bin/env python3
"""The burn ledger: which paths each track covered, and the status of every queued finding.

The ledger lives at `.llm/burn/ledger.json`. Coverage maps track -> path -> ISO date. Findings
map a fingerprint (track, path, symbol; never a line number) to its status: queued, dismissed or
done. A queued finding's task in `.llm/todo.md` carries a `burn: <fingerprint>` line, which is
how deleted tasks are recognized as dismissed.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

SETTLED = ('dismissed', 'done')
TASK = re.compile(r'^- \[(.)\]')
TASK_FINGERPRINT = re.compile(r'^\s+burn: ([0-9a-f]{12})\s*$')


def empty():
    return {'coverage': {}, 'findings': {}}


def load(path):
    path = Path(path)
    if not path.exists():
        return empty()
    state = json.loads(path.read_text())
    return {'coverage': state.get('coverage', {}), 'findings': state.get('findings', {})}


def save(path, state):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, indent=2, sort_keys=True) + '\n')


def pick_shards(state, track, candidates, count):
    """Uncovered candidates first, in their given order, then the least recently covered."""
    covered = state['coverage'].get(track, {})
    order = {path: index for index, path in enumerate(candidates)}
    ranked = sorted(candidates, key=lambda path: (path in covered, covered.get(path, ''), order[path]))
    return ranked[:count]


def record_coverage(state, track, paths, date):
    state['coverage'].setdefault(track, {}).update({path: date for path in paths})


def fingerprint(finding):
    key = '\0'.join((finding['track'], finding['path'], finding['symbol']))
    return hashlib.sha256(key.encode()).hexdigest()[:12]


def merge_findings(state, findings):
    """Record new findings as queued and return them; known fingerprints are never re-queued."""
    queued = []
    for finding in findings:
        key = fingerprint(finding)
        if key in state['findings']:
            continue
        state['findings'][key] = {'track': finding['track'], 'path': finding['path'],
                                  'symbol': finding['symbol'], 'status': 'queued'}
        queued.append(dict(finding, fingerprint=key))
    return queued


def sync_todo(state, todo_text):
    """A queued finding whose task is checked is done; one whose task is gone is dismissed."""
    marks, mark = {}, None
    for line in todo_text.splitlines():
        if task := TASK.match(line):
            mark = task[1]
        elif (found := TASK_FINGERPRINT.match(line)) and mark is not None:
            marks[found[1]] = mark
    for key, entry in state['findings'].items():
        if entry['status'] in SETTLED:
            continue
        if key not in marks:
            entry['status'] = 'dismissed'
        elif marks[key] == 'x':
            entry['status'] = 'done'


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--ledger', default='.llm/burn/ledger.json')
    commands = parser.add_subparsers(dest='command', required=True)

    pick = commands.add_parser('pick', help='Print the next shards for a track, one per line')
    pick.add_argument('--track', required=True)
    pick.add_argument('--count', type=int, required=True)
    pick.add_argument('candidates', nargs='+')

    record = commands.add_parser('record', help='Record that a track covered these paths')
    record.add_argument('--track', required=True)
    record.add_argument('--date', required=True)
    record.add_argument('paths', nargs='+')

    commands.add_parser('merge', help='Read findings as a JSON list on stdin; print the new ones')

    sync = commands.add_parser('sync-todo', help='Mark findings done or dismissed from the task list')
    sync.add_argument('--todo', default='.llm/todo.md')

    commands.add_parser('dismissed', help='Print dismissed findings as JSON')

    args = parser.parse_args(argv)
    state = load(args.ledger)

    if args.command == 'pick':
        print('\n'.join(pick_shards(state, args.track, args.candidates, args.count)))
        return
    if args.command == 'dismissed':
        print(json.dumps({key: entry for key, entry in state['findings'].items()
                          if entry['status'] == 'dismissed'}, indent=2, sort_keys=True))
        return
    if args.command == 'record':
        record_coverage(state, args.track, args.paths, args.date)
    elif args.command == 'merge':
        print(json.dumps(merge_findings(state, json.load(sys.stdin)), indent=2))
    elif args.command == 'sync-todo':
        todo = Path(args.todo)
        sync_todo(state, todo.read_text() if todo.exists() else '')
    save(args.ledger, state)


if __name__ == '__main__':
    main()
