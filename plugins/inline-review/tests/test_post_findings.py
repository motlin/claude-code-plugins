"""Anchor validation and Plannotator payload contracts for post_findings."""
import importlib.util
from pathlib import Path
import unittest

PLUGIN = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('post_findings', PLUGIN / 'scripts/post_findings.py')
post_findings = importlib.util.module_from_spec(spec)
spec.loader.exec_module(post_findings)

PATCH = """\
diff --git a/src/app.py b/src/app.py
index 1111111..2222222 100644
--- a/src/app.py
+++ b/src/app.py
@@ -10,4 +10,5 @@ def main():
     setup()
-    run(1)
+    run(2)
+    report()
     teardown()
     return 0
diff --git a/docs/new.md b/docs/new.md
new file mode 100644
index 0000000..3333333
--- /dev/null
+++ b/docs/new.md
@@ -0,0 +1,2 @@
+# Title
+Body
diff --git a/old.txt b/renamed.txt
similarity index 100%
rename from old.txt
rename to renamed.txt
"""


class ParsePatchTest(unittest.TestCase):
    def test_collects_displayed_lines_per_side(self):
        self.assertEqual(
            post_findings.parse_patch(PATCH),
            {
                'src/app.py': {'old': {10, 11, 12, 13}, 'new': {10, 11, 12, 13, 14}},
                'docs/new.md': {'old': set(), 'new': {1, 2}},
                'renamed.txt': {'old': set(), 'new': set()},
            },
        )


class BuildAnnotationsTest(unittest.TestCase):
    def build(self, finding):
        return post_findings.build_annotations({'findings': [finding]}, post_findings.parse_patch(PATCH))

    def test_blocking_issue_on_added_line(self):
        self.assertEqual(
            self.build({
                'label': 'issue',
                'decorations': ['blocking'],
                'file': 'src/app.py',
                'line': 11,
                'end_line': 12,
                'side': 'new',
                'title': 'Wrong argument',
                'body': '`run` expects **1**.',
                'reasoning': 'Callers pass 1 everywhere else.',
                'sources': ['code-review:bugs', 'pr-review-toolkit:code-reviewer'],
            }),
            [{
                'annotation': {
                    'source': 'inline-review',
                    'author': 'inline-review',
                    'type': 'concern',
                    'scope': 'line',
                    'filePath': 'src/app.py',
                    'lineStart': 11,
                    'lineEnd': 12,
                    'side': 'new',
                    'text': '**Wrong argument**\n\n`run` expects **1**.',
                    'severity': 'important',
                    'reasoning': 'Callers pass 1 everywhere else.',
                    'reviewProfileLabel': 'code-review:bugs, pr-review-toolkit:code-reviewer',
                },
                'patch': {'conventionalLabel': 'issue', 'decorations': ['blocking']},
            }],
        )

    def test_suggestion_with_code_on_deleted_line(self):
        self.assertEqual(
            self.build({
                'label': 'suggestion',
                'decorations': ['non-blocking'],
                'file': 'src/app.py',
                'line': 11,
                'side': 'old',
                'title': 'Keep the old call',
                'body': 'Restore it.',
                'suggested_code': 'run(1)',
                'sources': ['mattpocock:standards'],
            }),
            [{
                'annotation': {
                    'source': 'inline-review',
                    'author': 'inline-review',
                    'type': 'suggestion',
                    'scope': 'line',
                    'filePath': 'src/app.py',
                    'lineStart': 11,
                    'lineEnd': 11,
                    'side': 'old',
                    'text': '**Keep the old call**\n\nRestore it.',
                    'suggestedCode': 'run(1)',
                    'reviewProfileLabel': 'mattpocock:standards',
                },
                'patch': {'conventionalLabel': 'suggestion', 'decorations': ['non-blocking']},
            }],
        )

    def test_line_outside_hunk_becomes_file_comment(self):
        self.assertEqual(
            self.build({
                'label': 'nitpick',
                'file': 'docs/new.md',
                'line': 40,
                'side': 'new',
                'title': 'Typo far away',
                'body': 'Spelling.',
                'sources': ['inline-review:reader'],
            }),
            [{
                'annotation': {
                    'source': 'inline-review',
                    'author': 'inline-review',
                    'type': 'comment',
                    'scope': 'file',
                    'filePath': 'docs/new.md',
                    'lineStart': 0,
                    'lineEnd': 0,
                    'side': 'new',
                    'text': '**Typo far away** (line 40)\n\nSpelling.',
                    'severity': 'nit',
                    'reviewProfileLabel': 'inline-review:reader',
                },
                'patch': {'conventionalLabel': 'nitpick'},
            }],
        )

    def test_file_outside_patch_becomes_general_comment(self):
        self.assertEqual(
            self.build({
                'label': 'question',
                'file': 'src/elsewhere.py',
                'line': 5,
                'side': 'new',
                'title': 'Is this caller updated?',
                'body': 'It still passes 1.',
                'pre_existing': True,
                'sources': ['inline-review:reader'],
            }),
            [{
                'annotation': {
                    'source': 'inline-review',
                    'author': 'inline-review',
                    'type': 'comment',
                    'scope': 'general',
                    'filePath': '',
                    'lineStart': 0,
                    'lineEnd': 0,
                    'side': 'new',
                    'text': '**Is this caller updated?** (`src/elsewhere.py:5`)\n\nIt still passes 1.',
                    'severity': 'pre_existing',
                    'reviewProfileLabel': 'inline-review:reader',
                },
                'patch': {'conventionalLabel': 'question'},
            }],
        )

    def test_summary_comes_first_as_general_note(self):
        self.assertEqual(
            post_findings.build_annotations(
                {'summary': 'Adds `report()`.', 'findings': []},
                post_findings.parse_patch(PATCH),
            ),
            [{
                'annotation': {
                    'source': 'inline-review',
                    'author': 'inline-review',
                    'type': 'comment',
                    'scope': 'general',
                    'filePath': '',
                    'lineStart': 0,
                    'lineEnd': 0,
                    'side': 'new',
                    'text': '**Review summary**\n\nAdds `report()`.',
                },
                'patch': {'conventionalLabel': 'note'},
            }],
        )

    def test_rejects_unknown_label(self):
        with self.assertRaisesRegex(ValueError, r"findings\[0\]: unknown label 'bug'"):
            self.build({'label': 'bug', 'file': 'src/app.py', 'line': 11, 'side': 'new', 'title': 't', 'body': 'b'})

    def test_rejects_unknown_decoration(self):
        with self.assertRaisesRegex(ValueError, r"findings\[0\]: unknown decoration 'urgent'"):
            self.build({
                'label': 'issue', 'decorations': ['urgent'],
                'file': 'src/app.py', 'line': 11, 'side': 'new', 'title': 't', 'body': 'b',
            })


class PostTest(unittest.TestCase):
    def test_replaces_previous_run_then_posts_and_labels(self):
        calls = []

        def send(method, url, body=None):
            calls.append((method, url, body))
            if method == 'POST':
                return {'ids': ['a1', 'a2']}
            return {}

        items = [
            {'annotation': {'text': 'one'}, 'patch': {'conventionalLabel': 'note'}},
            {'annotation': {'text': 'two'}, 'patch': {'conventionalLabel': 'issue', 'decorations': ['blocking']}},
        ]
        post_findings.post(items, 'http://localhost:1234/', send)
        base = 'http://localhost:1234/api/external-annotations'
        self.assertEqual(
            calls,
            [
                ('DELETE', base + '?source=inline-review', None),
                ('POST', base, {'annotations': [{'text': 'one'}, {'text': 'two'}]}),
                ('PATCH', base + '?id=a1', {'conventionalLabel': 'note'}),
                ('PATCH', base + '?id=a2', {'conventionalLabel': 'issue', 'decorations': ['blocking']}),
            ],
        )


if __name__ == '__main__':
    unittest.main()
