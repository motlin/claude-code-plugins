"""Every track file declares the frontmatter the burn Workflow needs, with allowed values."""
from pathlib import Path
import unittest

TRACKS = Path(__file__).resolve().parents[1] / 'skills/burn/references/tracks'
KEYS = {'name', 'applies', 'shard', 'invokes', 'evidence'}
APPLIES = {'any', 'has-tests', 'has-coverage-tool', 'has-mutation-tool'}
SHARDS = {'directory', 'file-set', 'whole-repo'}


def parse(path):
    """Split a track file into its flat `key: value` frontmatter and its body."""
    _, frontmatter, body = path.read_text().split('---\n', 2)
    keys = {}
    for line in frontmatter.splitlines():
        key, value = line.split(':', 1)
        keys[key.strip()] = value.strip().strip('"')
    return keys, body.strip()


class TrackFilesTest(unittest.TestCase):
    def test_the_core_tracks_exist(self):
        self.assertLessEqual({'code-review', 'coverage', 'mutation', 'test-speed', 'test-assertions'},
                             {path.stem for path in TRACKS.glob('*.md')})

    def test_each_track_declares_every_key_with_an_allowed_value(self):
        for path in sorted(TRACKS.glob('*.md')):
            with self.subTest(track=path.stem):
                keys, body = parse(path)
                self.assertEqual(set(keys), KEYS)
                self.assertEqual(keys['name'], path.stem)
                self.assertIn(keys['applies'], APPLIES)
                self.assertIn(keys['shard'], SHARDS)
                self.assertIn('{paths}', keys['invokes'])
                self.assertTrue(keys['evidence'])
                self.assertTrue(body)


if __name__ == '__main__':
    unittest.main()
