"""Coverage rotation, finding fingerprints, and dismissal contracts for the burn ledger."""
import importlib.util
from pathlib import Path
import unittest

PLUGIN = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('ledger', PLUGIN / 'scripts/ledger.py')
ledger = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ledger)


def finding(path, symbol, track='code-review', title='Fix the example'):
    return {'track': track, 'path': path, 'symbol': symbol, 'title': title}


class PickShardsTest(unittest.TestCase):
    def test_prefers_uncovered_paths_then_the_least_recently_covered(self):
        state = {'coverage': {'code-review': {'src/a': '2026-01-03', 'src/b': '2026-01-01'},
                              'coverage': {'src/c': '2026-01-02'}},
                 'findings': {}}

        picked = ledger.pick_shards(state, 'code-review', ['src/a', 'src/b', 'src/c', 'src/d'], 3)

        self.assertEqual(picked, ['src/c', 'src/d', 'src/b'])

    def test_an_empty_ledger_keeps_candidate_order(self):
        picked = ledger.pick_shards(ledger.empty(), 'code-review', ['src/a', 'src/b', 'src/c'], 2)

        self.assertEqual(picked, ['src/a', 'src/b'])

    def test_recording_coverage_moves_a_path_to_the_back(self):
        state = ledger.empty()
        ledger.record_coverage(state, 'code-review', ['src/a'], '2026-01-01')

        picked = ledger.pick_shards(state, 'code-review', ['src/a', 'src/b'], 2)

        self.assertEqual(picked, ['src/b', 'src/a'])
        self.assertEqual(state, {'coverage': {'code-review': {'src/a': '2026-01-01'}}, 'findings': {}})


class FingerprintTest(unittest.TestCase):
    def test_is_stable_and_ignores_title_and_line_details(self):
        first = ledger.fingerprint(finding('src/a.py', 'parse', title='Fix parse on line 10'))
        second = ledger.fingerprint(finding('src/a.py', 'parse', title='Fix parse on line 42'))

        self.assertEqual(first, second)
        self.assertEqual(first, ledger.fingerprint(finding('src/a.py', 'parse')))
        self.assertRegex(first, r'^[0-9a-f]{12}$')

    def test_differs_by_track_path_and_symbol(self):
        base = ledger.fingerprint(finding('src/a.py', 'parse'))

        self.assertNotEqual(base, ledger.fingerprint(finding('src/a.py', 'parse', track='coverage')))
        self.assertNotEqual(base, ledger.fingerprint(finding('src/b.py', 'parse')))
        self.assertNotEqual(base, ledger.fingerprint(finding('src/a.py', 'render')))


class MergeFindingsTest(unittest.TestCase):
    def test_queues_new_findings_once(self):
        state = ledger.empty()
        repeated = finding('src/a.py', 'parse')

        queued = ledger.merge_findings(state, [repeated, dict(repeated, title='Same finding again')])

        key = ledger.fingerprint(repeated)
        self.assertEqual(queued, [dict(repeated, fingerprint=key)])
        self.assertEqual(state['findings'], {key: {'track': 'code-review', 'path': 'src/a.py',
                                                   'symbol': 'parse', 'status': 'queued'}})

    def test_never_brings_back_a_dismissed_or_done_finding(self):
        state = ledger.empty()
        dismissed = finding('src/a.py', 'parse')
        done = finding('src/b.py', 'render')
        ledger.merge_findings(state, [dismissed, done])
        state['findings'][ledger.fingerprint(dismissed)]['status'] = 'dismissed'
        state['findings'][ledger.fingerprint(done)]['status'] = 'done'

        queued = ledger.merge_findings(state, [dismissed, done])

        self.assertEqual(queued, [])
        self.assertEqual(state['findings'][ledger.fingerprint(dismissed)]['status'], 'dismissed')
        self.assertEqual(state['findings'][ledger.fingerprint(done)]['status'], 'done')


class SyncTodoTest(unittest.TestCase):
    def test_deleted_task_is_dismissed_checked_task_is_done_open_task_stays_queued(self):
        state = ledger.empty()
        deleted, checked, still_open = (finding('src/a.py', 'a'), finding('src/b.py', 'b'),
                                        finding('src/c.py', 'c'))
        ledger.merge_findings(state, [deleted, checked, still_open])
        todo = (f'- [x] Fix b\n  burn: {ledger.fingerprint(checked)}\n'
                f'- [ ] Fix c\n  burn: {ledger.fingerprint(still_open)}\n')

        ledger.sync_todo(state, todo)

        statuses = {key: entry['status'] for key, entry in state['findings'].items()}
        self.assertEqual(statuses, {ledger.fingerprint(deleted): 'dismissed',
                                    ledger.fingerprint(checked): 'done',
                                    ledger.fingerprint(still_open): 'queued'})

    def test_blocked_task_stays_queued_and_settled_findings_never_change(self):
        state = ledger.empty()
        blocked, dismissed = finding('src/a.py', 'a'), finding('src/b.py', 'b')
        ledger.merge_findings(state, [blocked, dismissed])
        state['findings'][ledger.fingerprint(dismissed)]['status'] = 'dismissed'
        todo = (f'- [!] Fix a\n  burn: {ledger.fingerprint(blocked)}\n'
                f'- [ ] Fix b\n  burn: {ledger.fingerprint(dismissed)}\n')

        ledger.sync_todo(state, todo)

        self.assertEqual(state['findings'][ledger.fingerprint(blocked)]['status'], 'queued')
        self.assertEqual(state['findings'][ledger.fingerprint(dismissed)]['status'], 'dismissed')


class LoadSaveTest(unittest.TestCase):
    def test_missing_file_loads_empty_and_save_round_trips(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'burn' / 'ledger.json'
            state = ledger.load(path)
            self.assertEqual(state, ledger.empty())

            ledger.record_coverage(state, 'coverage', ['src'], '2026-01-01')
            ledger.save(path, state)

            self.assertEqual(ledger.load(path), {'coverage': {'coverage': {'src': '2026-01-01'}},
                                                 'findings': {}})


if __name__ == '__main__':
    unittest.main()
