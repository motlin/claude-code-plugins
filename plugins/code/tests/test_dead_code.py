"""Detector discovery and reference-count evidence contracts for dead_code."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

PLUGIN = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('dead_code', PLUGIN / 'scripts/dead_code.py')
dead_code = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dead_code)


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
            return dead_code.detect(root, which=lambda name: name in installed)

    def test_detects_each_detector_with_its_commands(self):
        self.assertEqual(self.detect({
            'package.json': json.dumps({'devDependencies': {'knip': '5'}}),
            'pyproject.toml': '[tool.vulture]',
            'go.mod': 'module example.com/fake',
            'Cargo.toml': '[package]',
            'pom.xml': '<artifactId>rewrite-maven-plugin</artifactId>',
        }, installed={'deadcode', 'cargo-machete'}), [
            {'tool': 'knip', 'commands': ['npx knip', 'npx knip --production']},
            {'tool': 'vulture', 'commands': ['vulture {paths}']},
            {'tool': 'deadcode', 'commands': ['deadcode -test ./...', 'deadcode -test -whylive={symbol} ./...']},
            {'tool': 'cargo-machete', 'commands': ['cargo machete']},
            {'tool': 'openrewrite-maven', 'commands': [
                'mvn rewrite:dryRun -Drewrite.activeRecipes=' + ','.join(dead_code.REWRITE_RECIPES)]},
        ])

    def test_detects_an_installed_python_detector_without_config(self):
        self.assertEqual(self.detect({'pyproject.toml': '[project]'}, installed={'vulture'}),
                         [{'tool': 'vulture', 'commands': ['vulture {paths}']}])

    def test_detects_nothing_without_a_configured_or_installed_detector(self):
        self.assertEqual(self.detect({
            'package.json': json.dumps({'devDependencies': {'vitest': '1'}}),
            'go.mod': 'module example.com/fake',
            'Cargo.toml': '[package]',
        }), [])


class RefsTest(unittest.TestCase):
    def refs(self, files, symbol, definition):
        with tempfile.TemporaryDirectory() as root:
            write(root, files)
            git(root, 'init', '-q')
            git(root, 'add', '.')
            return dead_code.refs(root, symbol, definition)

    def test_a_symbol_named_only_at_its_definition_is_unreferenced(self):
        self.assertEqual(self.refs({
            'src/fake.py': 'def fake_helper():\n    return 1\n\ndef fake_helpers():\n    return 2\n',
        }, 'fake_helper', 'src/fake.py:1'), {
            'symbol': 'fake_helper', 'verdict': 'unreferenced', 'code': [], 'tests': [],
        })

    def test_a_symbol_named_only_by_tests_is_test_only(self):
        self.assertEqual(self.refs({
            'src/fake.py': 'def fake_helper():\n    return 1\n',
            'tests/test_fake.py': 'from src.fake import fake_helper\n',
        }, 'fake_helper', 'src/fake.py:1'), {
            'symbol': 'fake_helper', 'verdict': 'test-only', 'code': [],
            'tests': ['tests/test_fake.py:1:from src.fake import fake_helper'],
        })

    def test_a_string_match_in_code_counts_as_a_reference(self):
        self.assertEqual(self.refs({
            'src/fake.py': 'def fake_helper():\n    return 1\n',
            'src/registry.py': 'HANDLERS = ["fake_helper"]\n',
        }, 'fake_helper', 'src/fake.py:1'), {
            'symbol': 'fake_helper', 'verdict': 'referenced',
            'code': ['src/registry.py:1:HANDLERS = ["fake_helper"]'], 'tests': [],
        })


if __name__ == '__main__':
    unittest.main()
