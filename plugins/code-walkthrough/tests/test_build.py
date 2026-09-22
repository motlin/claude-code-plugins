"""Source alignment and reproducibility contracts for the walkthrough renderer."""
import hashlib
from html.parser import HTMLParser
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

PLUGIN = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('walkthrough_build', PLUGIN / 'scripts/build.py')
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class CodeText(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_code = False
        self.in_number = False
        self.lines = []

    def handle_starttag(self, tag, attributes):
        attributes = dict(attributes)
        if tag == 'code':
            self.in_code = True
        if self.in_code and attributes.get('class') == 'line':
            self.lines.append('')
        if attributes.get('class') == 'number':
            self.in_number = True

    def handle_endtag(self, tag):
        if tag == 'code':
            self.in_code = False
        if tag == 'span':
            self.in_number = False

    def handle_data(self, value):
        if self.in_code and not self.in_number:
            self.lines[-1] += value


class RendererTests(unittest.TestCase):
    def setUp(self):
        scratch = PLUGIN.parents[1] / '.llm'
        scratch.mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=scratch)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = 'local x = 1\nfunction tick()\n    return x\nend -- tick\n'
        (self.root / 'sample.lua').write_text(self.source)
        self.spec = {'title': 'Example', 'sections': [{'file': 'sample.lua', 'title': 'Frame', 'steps': [
            {'id': 'tick', 'title': 'Read x', 'start': 'function tick()', 'end': 'end -- tick', 'html': '<p>Return x.</p>'}
        ]}]}
        self.spec_path = self.root / 'walkthrough.json'
        self.output = self.root / 'walkthrough.html'
        self.spec_path.write_text(json.dumps(self.spec))

    def cli(self, *arguments):
        return subprocess.run([sys.executable, str(PLUGIN / 'scripts/build.py'), '--root', str(self.root), '--spec', str(self.spec_path), '--output', str(self.output), *arguments], capture_output=True, text=True)

    def test_anchor_range_and_review_survive_line_insertion(self):
        first, last, digest = build.resolve(self.source, 'function tick()', 'end -- tick')
        shifted = build.resolve('-- extra\n' + self.source, 'function tick()', 'end -- tick')
        self.assertEqual((first, last, digest, shifted), (2, 4, hashlib.sha256(b'function tick()\n    return x\nend -- tick').hexdigest(), (3, 5, digest)))

    def test_ambiguous_missing_and_reversed_anchors_fail(self):
        cases = [('x', None, "Anchor must occur exactly once: 'x'"), ('missing', None, "Anchor must occur exactly once: 'missing'"), ('end -- tick', 'function tick()', 'End anchor precedes start anchor')]
        for start, end, message in cases:
            with self.subTest(start=start):
                with self.assertRaises(ValueError) as error:
                    build.resolve(self.source, start, end)
                self.assertEqual(str(error.exception), message)

    def test_complete_listing_preserves_code_and_escapes_html(self):
        source = '\n\nlocal text = "<script>alert(1)</script> & {{TITLE}}"\nreturn text\n\n'
        (self.root / 'sample.lua').write_text(source)
        self.spec['sections'][0]['steps'][0].update(start='return text', end='return text')
        sections = build.prepare(self.spec, self.root)
        page, warnings = build.render(self.spec, sections, self.root)
        parser = CodeText()
        parser.feed(page)
        self.assertEqual((parser.lines, warnings), (source.splitlines(), ['tick']))

    def test_changed_excerpt_requires_review_but_relocation_does_not(self):
        self.assertEqual(self.cli('--review', 'tick').returncode, 0)
        (self.root / 'sample.lua').write_text('-- extra\n' + self.source)
        self.assertEqual((self.cli().returncode, self.cli('--check').returncode), (0, 0))
        (self.root / 'sample.lua').write_text(self.source.replace('return x', 'return x + 1'))
        self.assertEqual((self.cli().stderr, self.cli('--check').returncode), ('Needs review: tick\n', 1))

    def test_check_is_read_only_and_rebuild_is_deterministic(self):
        self.assertEqual(self.cli('--review', 'all').returncode, 0)
        before = (self.spec_path.read_bytes(), self.output.read_bytes())
        self.assertEqual((self.cli('--check').returncode, self.cli().returncode), (0, 0))
        self.assertEqual((self.spec_path.read_bytes(), self.output.read_bytes()), before)
        self.output.write_text('stale output')
        self.assertEqual((self.cli('--check').returncode, self.output.read_text()), (1, 'stale output'))

    def test_invalid_anchor_does_not_overwrite_existing_output(self):
        self.output.write_text('previous output')
        (self.root / 'sample.lua').write_text('return 1\n')
        result = self.cli('--review', 'all')
        self.assertEqual((result.returncode, result.stderr, self.output.read_text(), self.spec_path.read_text()), (2, "Anchor must occur exactly once: 'function tick()'\n", 'previous output', json.dumps(self.spec)))

    def test_duplicate_ids_and_escape_paths_fail(self):
        self.spec['sections'][0]['steps'] *= 2
        with self.assertRaises(ValueError) as error:
            build.prepare(self.spec, self.root)
        self.assertEqual(str(error.exception), 'Duplicate step ID: tick')
        with self.assertRaises(ValueError) as error:
            build.within(self.root, '../outside.lua')
        self.assertEqual(str(error.exception), 'Path escapes source root: ../outside.lua')

    def test_review_only_accepts_selected_steps(self):
        self.spec['sections'][0]['steps'].append({'id': 'setup', 'title': 'Initialize x', 'start': 'local x = 1', 'html': '<p>Start at one.</p>'})
        self.spec_path.write_text(json.dumps(self.spec))
        self.assertEqual(self.cli('--review', 'tick').returncode, 0)
        resolved = build.prepare(json.loads(self.spec_path.read_text()), self.root)
        self.assertEqual([(s['id'], s['stale']) for s in resolved[0]['steps']], [('tick', False), ('setup', True)])


if __name__ == '__main__':
    unittest.main()
