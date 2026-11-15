"""Warning-class grouping and before/after comparison contracts for build_warnings."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest

PLUGIN = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('build_warnings', PLUGIN / 'scripts/build_warnings.py')
build_warnings = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build_warnings)

LOG = '''\
src/fake.c:12:5: warning: unused variable 'x' [-Wunused-variable]
src/fake.c:30:1: warning: unused variable 'y' [-Wunused-variable]
src/Fake.java:7: warning: [deprecation] oldCall() in FakeApi has been deprecated
warning: unused import: `std::fmt`
 --> src/fake.rs:1:5
  |
  = note: `#[warn(unused_imports)]` on by default

warning: `fake` (lib) generated 1 warning
/repo/src/fake.js
  3:1  warning  Unexpected console statement  no-console
tests/test_fake.py:4: DeprecationWarning: fake_old() is deprecated, use fake_new()
    warnings.warn("fake_old() is deprecated", DeprecationWarning)
/venv/lib/python3.12/site-packages/fakelib/core.py:88: UserWarning: fakelib default changed
(node:4242) [DEP0040] DeprecationWarning: The `punycode` module is deprecated.
npm warn deprecated inflight@1.0.6: This module is not supported
npm warn install-scripts 2 packages have install scripts not yet covered by allowScripts:
npm warn install-scripts   fakepkg@1.0.0
2.50s call     tests/test_fake.py::test_slow
0.01s call     tests/test_fake.py::test_quick
  console.log
    fake debug output
      at Object.<anonymous> (src/fake.test.js:9:13)
2026-01-01 12:00:00,000 DEBUG fake.module connecting
Build finished: 3 passed, 2 warnings in 4.1s
'''


class ClassifyTest(unittest.TestCase):
    def test_groups_each_warning_class_by_kind_and_source_with_counts(self):
        report = build_warnings.classify(LOG, '/repo', slow=1.0)
        self.assertEqual(report, {
            'total': 14,
            'kinds': {'compiler': 3, 'lint': 1, 'deprecation': 4, 'runtime': 1, 'other': 2, 'slow-test': 1,
                      'noise': 2},
            'groups': [
                {'kind': 'compiler', 'rule': '-Wunused-variable', 'source': '-Wunused-variable', 'count': 2,
                 'files': ['src/fake.c'], 'thirdParty': False,
                 'example': "src/fake.c:12:5: warning: unused variable 'x' [-Wunused-variable]"},
                {'kind': 'deprecation', 'rule': 'deprecation', 'source': 'oldCall() in FakeApi has been deprecated',
                 'count': 1, 'files': ['src/Fake.java'], 'thirdParty': False,
                 'example': 'src/Fake.java:7: warning: [deprecation] oldCall() in FakeApi has been deprecated'},
                {'kind': 'compiler', 'rule': 'unused_imports', 'source': 'unused_imports', 'count': 1,
                 'files': ['src/fake.rs'], 'thirdParty': False, 'example': 'warning: unused import: `std::fmt`'},
                {'kind': 'lint', 'rule': 'no-console', 'source': 'no-console', 'count': 1,
                 'files': ['src/fake.js'], 'thirdParty': False,
                 'example': '3:1  warning  Unexpected console statement  no-console'},
                {'kind': 'deprecation', 'rule': 'DeprecationWarning',
                 'source': 'fake_old() is deprecated, use fake_new()', 'count': 1,
                 'files': ['tests/test_fake.py'], 'thirdParty': False,
                 'example': 'tests/test_fake.py:4: DeprecationWarning: fake_old() is deprecated, use fake_new()'},
                {'kind': 'runtime', 'rule': 'UserWarning', 'source': 'fakelib default changed', 'count': 1,
                 'files': ['/venv/lib/python3.12/site-packages/fakelib/core.py'], 'thirdParty': True,
                 'example': '/venv/lib/python3.12/site-packages/fakelib/core.py:88: UserWarning: fakelib default changed'},
                {'kind': 'deprecation', 'rule': 'DEP0040', 'source': 'DEP0040', 'count': 1, 'files': [],
                 'thirdParty': False,
                 'example': '(node:4242) [DEP0040] DeprecationWarning: The `punycode` module is deprecated.'},
                {'kind': 'deprecation', 'rule': 'npm-deprecated', 'source': 'inflight', 'count': 1, 'files': [],
                 'thirdParty': False, 'example': 'npm warn deprecated inflight@1.0.6: This module is not supported'},
                {'kind': 'other', 'rule': 'install-scripts', 'source': 'npm install-scripts', 'count': 2,
                 'files': [], 'thirdParty': False,
                 'example': 'npm warn install-scripts 2 packages have install scripts not yet covered by allowScripts:'},
                {'kind': 'slow-test', 'rule': 'slow', 'source': 'tests/test_fake.py', 'count': 1,
                 'files': ['tests/test_fake.py'], 'thirdParty': False,
                 'example': '2.50s call     tests/test_fake.py::test_slow'},
                {'kind': 'noise', 'rule': 'console.log', 'source': 'src/fake.test.js', 'count': 1,
                 'files': ['src/fake.test.js'], 'thirdParty': False, 'example': 'console.log'},
                {'kind': 'noise', 'rule': 'log.DEBUG', 'source': 'log.DEBUG', 'count': 1, 'files': [],
                 'thirdParty': False, 'example': '2026-01-01 12:00:00,000 DEBUG fake.module connecting'},
            ],
        })

    def test_strips_ansi_colors_and_falls_back_to_other_for_unrecognized_warnings(self):
        self.assertEqual(build_warnings.classify('\x1b[33mWARNING: fake plugin is outdated (12 days)\x1b[0m\n', '/repo'), {
            'total': 1,
            'kinds': {'other': 1},
            'groups': [{'kind': 'other', 'rule': '', 'source': 'WARNING: fake plugin is outdated (N days)',
                        'count': 1, 'files': [], 'thirdParty': False,
                        'example': 'WARNING: fake plugin is outdated (12 days)'}],
        })


class RunTest(unittest.TestCase):
    def test_runs_the_command_once_and_saves_its_output(self):
        with tempfile.TemporaryDirectory() as root:
            log = Path(root) / 'build.log'
            command = [sys.executable, '-c', "print('src/fake.c:1:1: warning: fake [-Wfake]'); raise SystemExit(3)"]
            report = build_warnings.run(root, command, log)
            self.assertEqual((report['exitCode'], report['total'], log.read_text()),
                             (3, 1, 'src/fake.c:1:1: warning: fake [-Wfake]\n'))


class CompareTest(unittest.TestCase):
    def report(self, counts):
        return {'total': sum(counts.values()),
                'groups': [{'kind': kind, 'source': source, 'count': count} for (kind, source), count in counts.items()]}

    def test_reports_each_class_before_and_after_and_whether_the_total_fell(self):
        before = self.report({('compiler', '-Wfake'): 3, ('lint', 'no-fake'): 1})
        after = self.report({('compiler', '-Wfake'): 1, ('noise', 'log.DEBUG'): 1})
        self.assertEqual(build_warnings.compare(before, after), {
            'before': 4, 'after': 2, 'reduced': True,
            'classes': [
                {'kind': 'compiler', 'source': '-Wfake', 'before': 3, 'after': 1},
                {'kind': 'lint', 'source': 'no-fake', 'before': 1, 'after': 0},
                {'kind': 'noise', 'source': 'log.DEBUG', 'before': 0, 'after': 1},
            ],
        })

    def test_main_compare_exits_nonzero_when_the_count_did_not_fall(self):
        with tempfile.TemporaryDirectory() as root:
            same = Path(root) / 'same.json'
            same.write_text(json.dumps(self.report({('lint', 'no-fake'): 1})))
            stdout = io.StringIO()
            with self.assertRaises(SystemExit) as exit_, contextlib.redirect_stdout(stdout):
                build_warnings.main(['compare', str(same), str(same)])
            self.assertEqual((exit_.exception.code, json.loads(stdout.getvalue())), (1, {
                'before': 1, 'after': 1, 'reduced': False,
                'classes': [{'kind': 'lint', 'source': 'no-fake', 'before': 1, 'after': 1}],
            }))


if __name__ == '__main__':
    unittest.main()
