"""Runtime install contracts: install once, skip while the pinned inputs are unchanged."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

PLUGIN = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('walkthrough_setup', PLUGIN / 'scripts/setup.py')
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)


class InstallTest(unittest.TestCase):
    def setUp(self):
        self.runtime = Path(tempfile.mkdtemp())
        self.calls = []

    def run_command(self, command, check):
        self.calls.append(command[:3])
        if command[1:3] == ['-m', 'venv']:
            (self.runtime / '.venv').mkdir(exist_ok=True)
        if command[0] == 'npm':
            (self.runtime / 'node_modules').mkdir(exist_ok=True)

    def install(self):
        self.calls = []
        setup.install(self.runtime, self.run_command)
        return [call[0] if call[0] == 'npm' else call[1:3] for call in self.calls]

    def test_installs_once_then_skips_until_inputs_change(self):
        full = ['npm', ['-m', 'venv'], ['-m', 'pip']]
        self.assertEqual(self.install(), full)
        self.assertEqual(self.install(), [])
        (self.runtime / setup.STAMP).write_text('stale')
        self.assertEqual(self.install(), full)

    def test_reinstalls_when_an_installed_directory_is_missing(self):
        self.install()
        (self.runtime / 'node_modules').rmdir()
        self.assertEqual(self.install(), ['npm', ['-m', 'venv'], ['-m', 'pip']])


if __name__ == '__main__':
    unittest.main()
