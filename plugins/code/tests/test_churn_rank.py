"""Churn counting and churn x (1 - coverage) ranking contracts for churn_rank."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

PLUGIN = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('churn_rank', PLUGIN / 'scripts/churn_rank.py')
churn_rank = importlib.util.module_from_spec(spec)
spec.loader.exec_module(churn_rank)


def entry(lines, covered):
    return {'lines': lines, 'covered': covered, 'uncovered': list(range(1, lines - covered + 1)), 'partial': []}


class RankTest(unittest.TestCase):
    def test_ranks_by_churn_times_uncovered_share_and_skips_with_reasons(self):
        coverage = {
            'src/hot.py': entry(10, 5),
            'src/cold.py': entry(10, 0),
            'src/done.py': entry(10, 10),
            'src/tiny.py': entry(2, 0),
            'src/stable.py': entry(10, 0),
            'vendor/lib.py': entry(10, 0),
            'src/api_pb2.py': entry(10, 0),
            'tests/test_hot.py': entry(10, 0),
        }
        churn = {'src/hot.py': 8, 'src/cold.py': 3, 'src/done.py': 9, 'src/tiny.py': 9,
                 'vendor/lib.py': 9, 'src/api_pb2.py': 9, 'tests/test_hot.py': 9}

        self.assertEqual(churn_rank.rank(coverage, churn, min_lines=5, limit=10), {
            'targets': [
                {'path': 'src/hot.py', 'churn': 8, 'coverage': 50.0, 'score': 4.0, 'uncovered': [1, 2, 3, 4, 5]},
                {'path': 'src/cold.py', 'churn': 3, 'coverage': 0.0, 'score': 3.0,
                 'uncovered': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]},
            ],
            'skipped': [
                {'path': 'src/api_pb2.py', 'reason': 'generated'},
                {'path': 'src/done.py', 'reason': 'fully covered'},
                {'path': 'src/stable.py', 'reason': 'no recent churn'},
                {'path': 'src/tiny.py', 'reason': 'trivial'},
                {'path': 'tests/test_hot.py', 'reason': 'test file'},
                {'path': 'vendor/lib.py', 'reason': 'vendored'},
            ],
        })

    def test_limit_keeps_the_highest_scores(self):
        coverage = {'a.py': entry(10, 0), 'b.py': entry(10, 0)}

        ranked = churn_rank.rank(coverage, {'a.py': 1, 'b.py': 2}, min_lines=5, limit=1)

        self.assertEqual([target['path'] for target in ranked['targets']], ['b.py'])


class ChurnTest(unittest.TestCase):
    def test_counts_commits_touching_each_file(self):
        with tempfile.TemporaryDirectory() as root:
            def git(*args):
                subprocess.run(['git', '-c', 'user.name=Example', '-c', 'user.email=dev@example.com', *args],
                               cwd=root, check=True, capture_output=True)

            git('init', '--quiet')
            for text in ('one', 'two'):
                Path(root, 'a.py').write_text(text)
                git('add', '.')
                git('commit', '--quiet', '--message', text)
            Path(root, 'b.py').write_text('three')
            git('add', '.')
            git('commit', '--quiet', '--message', 'three')

            self.assertEqual(churn_rank.churn_counts(root, '1.year'), {'a.py': 2, 'b.py': 1})


if __name__ == '__main__':
    unittest.main()
