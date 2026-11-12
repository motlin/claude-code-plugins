"""Doc-set discovery and claim-checking contracts for docs_drift."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

PLUGIN = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('docs_drift', PLUGIN / 'scripts/docs_drift.py')
docs_drift = importlib.util.module_from_spec(spec)
spec.loader.exec_module(docs_drift)


def write(root, files):
    for name, text in files.items():
        path = Path(root) / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)


def git(root, *args):
    subprocess.run(['git', '-c', 'user.name=Example', '-c', 'user.email=dev@example.com', *args],
                   cwd=root, check=True, capture_output=True)


def commit(root, message):
    git(root, 'add', '-A')
    git(root, 'commit', '-q', '-m', message)


class DocsTest(unittest.TestCase):
    def test_lists_the_doc_set_under_the_paths(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, {
                'README.md': '', 'CLAUDE.md': '', 'AGENTS.md': '', 'notes.md': '',
                'plugins/fake/README.md': '', 'plugins/fake/skills/one/SKILL.md': '',
                'plugins/fake/commands/run.md': '', 'node_modules/dep/README.md': '',
            })
            self.assertEqual(docs_drift.docs(root, []), [
                'AGENTS.md', 'CLAUDE.md', 'README.md', 'plugins/fake/README.md',
                'plugins/fake/commands/run.md', 'plugins/fake/skills/one/SKILL.md',
            ])
            self.assertEqual(docs_drift.docs(root, ['plugins/fake/skills']), ['plugins/fake/skills/one/SKILL.md'])

    def test_since_keeps_only_docs_that_name_a_changed_file(self):
        with tempfile.TemporaryDirectory() as root:
            write(root, {
                'README.md': 'See `src/fake.py`.\n', 'CLAUDE.md': 'See `src/other.py`.\n',
                'src/fake.py': '', 'src/other.py': '',
            })
            git(root, 'init', '-q')
            commit(root, 'base')
            write(root, {'src/fake.py': 'changed = True\n'})
            commit(root, 'change')
            self.assertEqual(docs_drift.docs(root, [], since='HEAD~1'), ['README.md'])


class ClaimsTest(unittest.TestCase):
    def claims(self, files, doc, history=()):
        with tempfile.TemporaryDirectory() as root:
            git(root, 'init', '-q')
            for step in history:
                for name, text in step.items():
                    if text is None:
                        git(root, 'mv', *name)
                    else:
                        write(root, {name: text})
                commit(root, 'step')
            write(root, files)
            return docs_drift.claims(root, [doc])

    def test_a_link_or_path_to_a_renamed_file_names_its_replacement(self):
        self.assertEqual(self.claims({
            'README.md': 'Read [the guide](docs/old.md) and run `scripts/old.sh`.\n',
        }, 'README.md', history=[
            {'docs/old.md': 'guide\n', 'scripts/old.sh': 'echo fake\n'},
            {('docs/old.md', 'docs/new.md'): None},
            {('scripts/old.sh', 'scripts/new.sh'): None},
        ]), [
            {'doc': 'README.md', 'line': 1, 'kind': 'path', 'claim': 'docs/old.md',
             'status': 'renamed', 'replacement': 'docs/new.md'},
            {'doc': 'README.md', 'line': 1, 'kind': 'path', 'claim': 'scripts/old.sh',
             'status': 'renamed', 'replacement': 'scripts/new.sh'},
        ])

    def test_a_missing_path_without_a_rename_is_contradicted(self):
        self.assertEqual(self.claims({
            'README.md': '[ok](docs/here.md#usage) [gone](docs/gone.md) [web](https://example.com/x.md)\n',
            'docs/here.md': '',
        }, 'README.md'), [
            {'doc': 'README.md', 'line': 1, 'kind': 'path', 'claim': 'docs/gone.md', 'status': 'contradicted'},
        ])

    def test_paths_resolve_against_the_doc_directory_or_the_root(self):
        self.assertEqual(self.claims({
            'plugins/fake/README.md': 'See [skill](skills/one/SKILL.md) and `plugins/fake/skills/one/SKILL.md`.\n',
            'plugins/fake/skills/one/SKILL.md': '',
        }, 'plugins/fake/README.md'), [])

    def test_paths_resolve_against_any_directory_above_the_doc(self):
        self.assertEqual(self.claims({
            'plugins/fake/skills/one/SKILL.md': 'The plugin root contains this `skills/one/SKILL.md` file.\n',
        }, 'plugins/fake/skills/one/SKILL.md'), [])

    def test_placeholder_and_ignored_paths_are_not_claims(self):
        self.assertEqual(self.claims({
            '.gitignore': '.llm/\n',
            'README.md': 'Run `<plugin-root>/scripts/x.py`, `${ROOT}/a/b.sh`, `src/*.py` or `~/.claude/x.md`.\n'
                         'Write `.llm/fake/ledger.json`, never `.git/index.lock`; see [the page](URL).\n',
        }, 'README.md'), [])

    def test_recipes_and_scripts_are_checked_both_ways(self):
        self.assertEqual(self.claims({
            'README.md': 'Run `just test`, `just deploy`, `npm run build` and `npm run lint`.\n',
            'justfile': 'set shell := ["bash"]\nroot := "x"\ndefault:\n    @just --list\n\n# Run tests\ntest quick="": install\n    ./run\n\nrelease VERSION:\n    ./r\n',
            'package.json': json.dumps({'scripts': {'build': 'tsc', 'watch': 'tsc -w'}}),
        }, 'README.md'), [
            {'doc': 'README.md', 'line': 1, 'kind': 'recipe', 'claim': 'just deploy', 'status': 'contradicted'},
            {'doc': 'README.md', 'line': 1, 'kind': 'recipe', 'claim': 'npm run lint', 'status': 'contradicted'},
            {'doc': None, 'line': None, 'kind': 'undocumented', 'claim': 'just release', 'status': 'check'},
            {'doc': None, 'line': None, 'kind': 'undocumented', 'claim': 'npm run watch', 'status': 'check'},
        ])

    def test_a_stale_manifest_version_is_contradicted(self):
        self.assertEqual(self.claims({
            'README.md': 'Install fake-tool@1.2.0, or fake-tool@2.0.0 for the latest.\n',
            'package.json': json.dumps({'name': 'fake-tool', 'version': '2.0.0'}),
        }, 'README.md'), [
            {'doc': 'README.md', 'line': 1, 'kind': 'version', 'claim': 'fake-tool@1.2.0',
             'status': 'contradicted', 'replacement': 'fake-tool@2.0.0'},
        ])

    def test_hard_coded_counts_are_flagged_for_checking(self):
        self.assertEqual(self.claims({
            'README.md': 'This repo has 12 plugins and three skills.\nIt took 2 days.\n',
        }, 'README.md'), [
            {'doc': 'README.md', 'line': 1, 'kind': 'count', 'claim': '12 plugins', 'status': 'check'},
            {'doc': 'README.md', 'line': 1, 'kind': 'count', 'claim': 'three skills', 'status': 'check'},
        ])


class MainTest(unittest.TestCase):
    def test_strict_exits_1_while_a_renamed_path_remains(self):
        with tempfile.TemporaryDirectory() as root:
            git(root, 'init', '-q')
            write(root, {'docs/old.md': 'guide\n'})
            commit(root, 'base')
            git(root, 'mv', 'docs/old.md', 'docs/new.md')
            commit(root, 'rename')
            write(root, {'README.md': '[x](docs/old.md)\n'})
            with self.assertRaises(SystemExit) as stopped:
                docs_drift.main(['--root', root, 'claims', '--strict', 'README.md'])
            self.assertEqual(stopped.exception.code, 1)
            write(root, {'README.md': '[x](docs/new.md)\n'})
            with self.assertRaises(SystemExit) as stopped:
                docs_drift.main(['--root', root, 'claims', '--strict', 'README.md'])
            self.assertEqual(stopped.exception.code, 0)


if __name__ == '__main__':
    unittest.main()
