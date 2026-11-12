"""Ecosystem detection, report parsing, comparison, and annotation contracts for coverage_baseline."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

PLUGIN = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('coverage_baseline', PLUGIN / 'scripts/coverage_baseline.py')
coverage_baseline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(coverage_baseline)


def write(root, files):
    for name, text in files.items():
        path = Path(root) / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)


class DetectTest(unittest.TestCase):
    def detect(self, files):
        with tempfile.TemporaryDirectory() as root:
            write(root, files)
            return coverage_baseline.detect(root)

    def test_detects_each_ecosystem_with_its_command_and_report(self):
        self.assertEqual(self.detect({'package.json': json.dumps({'devDependencies': {'vitest': '1'}})}), [{
            'ecosystem': 'vitest',
            'command': ['npx', 'vitest', 'run', '--coverage', '--coverage.reporter=lcov'],
            'report': 'coverage/lcov.info',
            'format': 'lcov',
        }])
        self.assertEqual(self.detect({'package.json': json.dumps({'devDependencies': {'jest': '1'}})}), [{
            'ecosystem': 'jest',
            'command': ['npx', 'jest', '--coverage', '--coverageReporters=lcov'],
            'report': 'coverage/lcov.info',
            'format': 'lcov',
        }])
        self.assertEqual(self.detect({'pyproject.toml': '[tool.pytest.ini_options]\n'}), [{
            'ecosystem': 'pytest',
            'command': ['python', '-m', 'pytest', '--cov', '--cov-report=xml:coverage.xml'],
            'report': 'coverage.xml',
            'format': 'cobertura',
        }])
        self.assertEqual(self.detect({'go.mod': 'module example.com/demo\n'}), [{
            'ecosystem': 'go',
            'command': ['go', 'test', '-coverprofile=coverage.out', './...'],
            'report': 'coverage.out',
            'format': 'gocover',
        }])
        self.assertEqual(self.detect({'Cargo.toml': '[package]\n'}), [{
            'ecosystem': 'tarpaulin',
            'command': ['cargo', 'tarpaulin', '--out', 'Lcov', '--output-dir', 'target/tarpaulin'],
            'report': 'target/tarpaulin/lcov.info',
            'format': 'lcov',
        }])
        self.assertEqual(self.detect({'pom.xml': '<artifactId>jacoco-maven-plugin</artifactId>'}), [{
            'ecosystem': 'jacoco-maven',
            'command': ['mvn', 'verify'],
            'report': '**/target/site/jacoco/jacoco.xml',
            'format': 'jacoco',
        }])
        self.assertEqual(self.detect({'build.gradle.kts': 'plugins { jacoco }'}), [{
            'ecosystem': 'jacoco-gradle',
            'command': ['./gradlew', 'test', 'jacocoTestReport'],
            'report': '**/build/reports/jacoco/test/jacocoTestReport.xml',
            'format': 'jacoco',
        }])

    def test_detects_nothing_without_a_known_test_framework(self):
        self.assertEqual(self.detect({'package.json': json.dumps({'dependencies': {'left-pad': '1'}}),
                                      'pom.xml': '<project/>'}), [])


class ParseTest(unittest.TestCase):
    def parse(self, fmt, files, report):
        with tempfile.TemporaryDirectory() as root:
            write(root, files)
            return coverage_baseline.parse(fmt, sorted(Path(root).glob(report)), root)

    def test_parses_lcov_with_absolute_paths_and_partial_branches(self):
        lcov = ('SF:{root}/src/a.js\nDA:1,1\nDA:2,0\nDA:3,4\nBRDA:3,0,0,1\nBRDA:3,0,1,0\n'
                'end_of_record\nSF:src/b.js\nDA:1,0\nend_of_record\n')
        with tempfile.TemporaryDirectory() as root:
            write(root, {'coverage/lcov.info': lcov.format(root=Path(root).resolve())})
            parsed = coverage_baseline.parse('lcov', [Path(root) / 'coverage/lcov.info'], root)

        self.assertEqual(parsed, {
            'src/a.js': {'lines': 3, 'covered': 2, 'uncovered': [2], 'partial': [3]},
            'src/b.js': {'lines': 1, 'covered': 0, 'uncovered': [1], 'partial': []},
        })

    def test_parses_cobertura_relative_to_its_source(self):
        xml = ('<coverage><sources><source>src</source></sources><packages><package><classes>'
               '<class filename="pkg/a.py"><lines><line number="1" hits="1"/>'
               '<line number="2" hits="1" branch="true" condition-coverage="50% (1/2)"/>'
               '<line number="5" hits="0"/></lines></class>'
               '</classes></package></packages></coverage>')

        self.assertEqual(self.parse('cobertura', {'coverage.xml': xml}, 'coverage.xml'), {
            'src/pkg/a.py': {'lines': 3, 'covered': 2, 'uncovered': [5], 'partial': [2]},
        })

    def test_parses_go_blocks_against_the_module_path(self):
        profile = ('mode: set\n'
                   'example.com/demo/calc/add.go:3.20,5.2 1 1\n'
                   'example.com/demo/calc/add.go:7.20,9.2 2 0\n'
                   'example.com/demo/calc/add.go:5.2,7.3 1 0\n')

        self.assertEqual(self.parse('gocover', {'go.mod': 'module example.com/demo\n', 'coverage.out': profile},
                                    'coverage.out'), {
            'calc/add.go': {'lines': 7, 'covered': 3, 'uncovered': [6, 7, 8, 9], 'partial': []},
        })

    def test_parses_jacoco_reports_and_finds_their_source_files(self):
        xml = ('<report name="demo"><package name="com/example"><sourcefile name="Calc.java">'
               '<line nr="3" mi="0" ci="2" mb="0" cb="0"/><line nr="4" mi="0" ci="1" mb="1" cb="1"/>'
               '<line nr="6" mi="3" ci="0" mb="0" cb="0"/></sourcefile></package></report>')
        files = {'core/target/site/jacoco/jacoco.xml': xml, 'core/src/main/java/com/example/Calc.java': ''}

        self.assertEqual(self.parse('jacoco', files, '**/target/site/jacoco/jacoco.xml'), {
            'core/src/main/java/com/example/Calc.java': {'lines': 3, 'covered': 2, 'uncovered': [6], 'partial': [4]},
        })


class RunTest(unittest.TestCase):
    def test_keeps_the_test_command_output_out_of_the_report(self):
        writer = "print('noisy test output'); open('lcov.info', 'w').write('SF:a.py\\nDA:1,1\\nend_of_record\\n')"
        driver = ('import importlib.util, json, sys\n'
                  f"spec = importlib.util.spec_from_file_location('m', {str(PLUGIN / 'scripts/coverage_baseline.py')!r})\n"
                  'm = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)\n'
                  f"print(json.dumps(m.run('.', [{{'ecosystem': 'fake', 'command': [sys.executable, '-c', {writer!r}],"
                  " 'report': 'lcov.info', 'format': 'lcov'}])))\n")
        with tempfile.TemporaryDirectory() as root:
            result = subprocess.run([sys.executable, '-c', driver], cwd=root, capture_output=True, text=True, check=True)

        self.assertEqual(json.loads(result.stdout), {'a.py': {'lines': 1, 'covered': 1, 'uncovered': [], 'partial': []}})
        self.assertEqual(result.stderr, 'noisy test output\n')


class CompareTest(unittest.TestCase):
    def test_reports_per_file_and_total_change_in_lines_and_branches(self):
        before = {'a.py': {'lines': 10, 'covered': 5, 'uncovered': [1, 2, 3, 4, 5], 'partial': []},
                  'b.py': {'lines': 4, 'covered': 4, 'uncovered': [], 'partial': []},
                  'c.py': {'lines': 4, 'covered': 4, 'uncovered': [], 'partial': [2, 3]}}
        after = {'a.py': {'lines': 10, 'covered': 8, 'uncovered': [1, 2], 'partial': []},
                 'b.py': {'lines': 4, 'covered': 4, 'uncovered': [], 'partial': []},
                 'c.py': {'lines': 4, 'covered': 4, 'uncovered': [], 'partial': [3]}}

        self.assertEqual(coverage_baseline.compare(before, after), {
            'files': [{'path': 'a.py', 'before': 50.0, 'after': 80.0, 'gained_lines': 3, 'resolved_partial': 0},
                      {'path': 'c.py', 'before': 100.0, 'after': 100.0, 'gained_lines': 0, 'resolved_partial': 1}],
            'total': {'before': 72.22, 'after': 88.89, 'gained_lines': 3, 'resolved_partial': 1},
            'gained': True,
        })

    def test_a_resolved_partial_line_alone_is_a_gain(self):
        before = {'a.py': {'lines': 2, 'covered': 2, 'uncovered': [], 'partial': [1]}}
        after = {'a.py': {'lines': 2, 'covered': 2, 'uncovered': [], 'partial': []}}

        self.assertEqual(coverage_baseline.compare(before, after)['gained'], True)

    def test_no_gain_when_nothing_newly_covered(self):
        same = {'a.py': {'lines': 2, 'covered': 1, 'uncovered': [2], 'partial': []}}

        self.assertEqual(coverage_baseline.compare(same, same), {
            'files': [],
            'total': {'before': 50.0, 'after': 50.0, 'gained_lines': 0, 'resolved_partial': 0},
            'gained': False,
        })


class AnnotateTest(unittest.TestCase):
    def test_tags_uncovered_and_partial_lines_with_their_numbers(self):
        entry = {'lines': 3, 'covered': 2, 'uncovered': [2], 'partial': [3]}

        self.assertEqual(coverage_baseline.annotate('def f(x):\n    return 1\n    if x: pass\n', entry),
                         '     1    def f(x):\n     2 !      return 1\n     3 ~      if x: pass\n')


if __name__ == '__main__':
    unittest.main()
