"""Tool detection, mutant-line selection and tests-only diff contracts for mutation_targets."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

PLUGIN = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('mutation_targets', PLUGIN / 'scripts/mutation_targets.py')
mutation_targets = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mutation_targets)


def write(root, files):
    for name, text in files.items():
        path = Path(root) / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)


def git(root, *args):
    subprocess.run(['git', '-c', 'user.name=Example', '-c', 'user.email=dev@example.com', *args],
                   cwd=root, check=True, capture_output=True)


class DetectTest(unittest.TestCase):
    def detect(self, files, installed=()):
        with tempfile.TemporaryDirectory() as root:
            write(root, files)
            return mutation_targets.detect(root, which=lambda name: name in installed)

    def test_detects_each_tool_with_its_line_scoped_command(self):
        self.assertEqual(self.detect({
            'package.json': json.dumps({'devDependencies': {'@stryker-mutator/core': '8'}}),
            'pom.xml': '<artifactId>pitest-maven</artifactId>',
            'build.gradle': "id 'info.solidsoft.pitest'",
            'pyproject.toml': '[tool.mutmut]',
            'Cargo.toml': '[package]',
        }, installed={'cargo-mutants'}), [
            {'tool': 'stryker', 'command': 'npx stryker run --incremental --mutate {file}:{lines}'},
            {'tool': 'pit-maven', 'command': 'mvn org.pitest:pitest-maven:mutationCoverage -DtargetClasses={class}'},
            {'tool': 'pit-gradle', 'command': './gradlew pitest -Dpitest.targetClasses={class}'},
            {'tool': 'mutmut', 'command': 'mutmut run'},
            {'tool': 'cargo-mutants', 'command': 'cargo mutants --file {file}'},
        ])

    def test_detects_nothing_without_a_configured_or_installed_tool(self):
        self.assertEqual(self.detect({
            'package.json': json.dumps({'devDependencies': {'vitest': '1'}}),
            'pyproject.toml': '[tool.pytest]',
            'Cargo.toml': '[package]',
        }), [])


class CandidatesTest(unittest.TestCase):
    SOURCE = '\n'.join([
        'def grade(score, bonus):',              # 1 declaration
        '    # if score > 90 the grade is A',    # 2 comment
        '    logger.info("high: %s", score > 50)',  # 3 arid: logging
        '    deadline = time.now() + 5',            # 4 arid: time
        '    if score > 90 and bonus:',          # 5 relational
        '        return "A"',                    # 6 return
        '    if score >= 80 or bonus:',          # 7 relational, uncovered
        '        return "B"',                    # 8 return, uncovered
        '    total = score + bonus',             # 9 arithmetic
        '    ready = done and checked',          # 10 logical
        '    return total',                      # 11 return
    ]) + '\n'

    def test_picks_covered_non_arid_lines_by_operator_priority_up_to_the_cap(self):
        entry = {'lines': 9, 'covered': 7, 'uncovered': [7, 8], 'partial': []}

        self.assertEqual(mutation_targets.candidates(self.SOURCE, entry, per_file=3), [
            {'line': 5, 'kind': 'relational', 'text': 'if score > 90 and bonus:'},
            {'line': 6, 'kind': 'return', 'text': 'return "A"'},
            {'line': 10, 'kind': 'logical', 'text': 'ready = done and checked'},
        ])


class TargetsTest(unittest.TestCase):
    def test_ranks_covered_files_by_churn_and_skips_with_reasons(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, {'src/hot.py': 'def f(a):\n    return a > 1\n', 'src/cold.py': 'def g(b):\n    return b < 2\n'})
            coverage = {
                'src/hot.py': {'lines': 2, 'covered': 2, 'uncovered': [], 'partial': []},
                'src/cold.py': {'lines': 2, 'covered': 2, 'uncovered': [], 'partial': []},
                'src/unrun.py': {'lines': 2, 'covered': 0, 'uncovered': [1, 2], 'partial': []},
                'src/stable.py': {'lines': 2, 'covered': 2, 'uncovered': [], 'partial': []},
                'tests/test_hot.py': {'lines': 2, 'covered': 2, 'uncovered': [], 'partial': []},
            }
            churn = {'src/hot.py': 5, 'src/cold.py': 2, 'src/unrun.py': 9, 'tests/test_hot.py': 9}

            self.assertEqual(mutation_targets.targets(root, coverage, churn, per_file=7, limit=10), {
                'targets': [
                    {'path': 'src/hot.py', 'churn': 5,
                     'lines': [{'line': 2, 'kind': 'relational', 'text': 'return a > 1'}]},
                    {'path': 'src/cold.py', 'churn': 2,
                     'lines': [{'line': 2, 'kind': 'relational', 'text': 'return b < 2'}]},
                ],
                'skipped': [
                    {'path': 'src/stable.py', 'reason': 'no recent churn'},
                    {'path': 'src/unrun.py', 'reason': 'no covered lines'},
                    {'path': 'tests/test_hot.py', 'reason': 'test file'},
                ],
            })


class ChangedTest(unittest.TestCase):
    def test_lists_changed_files_that_are_not_tests(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, {'src/a.py': 'one\n', 'tests/test_a.py': 'one\n'})
            git(root, 'init', '--quiet')
            git(root, 'add', '.')
            git(root, 'commit', '--quiet', '--message', 'one')
            write(root, {'tests/test_a.py': 'two\n', 'tests/test_b.py': 'new\n'})
            self.assertEqual(mutation_targets.non_test_changes(root), [])

            write(root, {'src/a.py': 'mutant\n', 'src/b.py': 'new\n'})
            self.assertEqual(mutation_targets.non_test_changes(root), ['src/a.py', 'src/b.py'])


if __name__ == '__main__':
    unittest.main()
