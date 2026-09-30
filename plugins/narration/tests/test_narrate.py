"""Chunking, request shape, caching, and chapter-marker contracts for the narrator."""
import base64
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
import wave

PLUGIN = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('narrate', PLUGIN / 'scripts/narrate.py')
narrate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(narrate)

SETTINGS = narrate.Settings(model='gemini-3.8-flash-tts', voice='Charon', style='brisk audiobook narration')


def wav_response(seconds, sample_rate=24000):
    buffer = io.BytesIO()
    with wave.open(buffer, 'wb') as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(sample_rate)
        audio.writeframes(b'\x01\x00' * sample_rate * seconds)
    return {
        'steps': [
            {'type': 'user_input', 'content': []},
            {
                'type': 'model_output',
                'content': [{'type': 'audio', 'mime_type': 'audio/wav', 'data': base64.b64encode(buffer.getvalue()).decode()}],
            },
        ],
        'usage': {'total_input_tokens': 10, 'total_output_tokens': 32 * seconds},
    }


class SplitIntoChunks(unittest.TestCase):
    def test_breaks_only_between_paragraphs(self):
        text = 'one two three\n\nfour five\n\nsix seven eight nine\n\nten'
        self.assertEqual(
            narrate.split_into_chunks(text, maximum_words=5),
            ['one two three\n\nfour five', 'six seven eight nine\n\nten'],
        )

    def test_keeps_an_oversized_paragraph_whole(self):
        self.assertEqual(
            narrate.split_into_chunks('a b c d e f\n\ng', maximum_words=3),
            ['a b c d e f', 'g'],
        )


class BuildRequest(unittest.TestCase):
    def test_style_travels_as_an_annotation_and_never_in_the_spoken_text(self):
        self.assertEqual(
            narrate.build_request(SETTINGS, 'Hello there.'),
            {
                'model': 'gemini-3.8-flash-tts',
                'input': [
                    {
                        'type': 'user_input',
                        'content': [
                            {
                                'type': 'text',
                                'text': 'Hello there.',
                                'annotations': [{'type': 'speech_metadata', 'style': 'brisk audiobook narration'}],
                            }
                        ],
                    }
                ],
                'response_format': {'type': 'audio'},
                'generation_config': {'speech_config': [{'voice': 'Charon'}]},
            },
        )

    def test_no_style_means_no_annotation(self):
        settings = narrate.Settings(model='gemini-3.8-flash-tts', voice='Kore', style=None)
        self.assertEqual(
            narrate.build_request(settings, 'Hello there.')['input'][0]['content'],
            [{'type': 'text', 'text': 'Hello there.'}],
        )

    def test_rejects_an_unknown_voice(self):
        settings = narrate.Settings(model='gemini-3.8-flash-tts', voice='Nobody', style=None)
        with self.assertRaisesRegex(ValueError, 'Unknown voice: Nobody'):
            narrate.build_request(settings, 'Hello there.')


class ReadAudio(unittest.TestCase):
    def test_returns_frames_and_usage(self):
        frames, usage = narrate.read_audio(wav_response(seconds=2))
        self.assertEqual((len(frames), usage), (2 * 24000 * 2, {'total_input_tokens': 10, 'total_output_tokens': 64}))

    def test_rejects_an_unexpected_sample_rate(self):
        with self.assertRaisesRegex(ValueError, 'Unexpected audio format'):
            narrate.read_audio(wav_response(seconds=1, sample_rate=16000))


class NarrateChapter(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.parts = Path(self.directory.name)
        self.requests = []

    def synthesize(self, request):
        self.requests.append(request['input'][0]['content'][0]['text'])
        return wav_response(seconds=1)

    def test_speaks_the_title_first_and_concatenates_chunks_in_order(self):
        chapter = {'title': 'Chapter 1', 'text': 'one two\n\nthree four\n\nfive'}
        result = narrate.narrate_chapter(chapter, SETTINGS, self.parts, self.synthesize, maximum_words=4)
        self.assertEqual(
            (sorted(self.requests), len(result.frames), result.output_tokens),
            (['Chapter 1.\n\none two\n\nthree four', 'five'], 2 * 24000 * 2, 64),
        )

    def test_reuses_cached_parts_and_regenerates_when_the_style_changes(self):
        chapter = {'title': 'Chapter 1', 'text': 'one two'}
        narrate.narrate_chapter(chapter, SETTINGS, self.parts, self.synthesize)
        cached = narrate.narrate_chapter(chapter, SETTINGS, self.parts, self.synthesize)
        restyled = narrate.narrate_chapter(
            chapter, SETTINGS._replace(style='whispered'), self.parts, self.synthesize
        )
        self.assertEqual(
            (len(self.requests), cached.output_tokens, restyled.output_tokens, len(cached.frames)),
            (2, 0, 32, 24000 * 2),
        )


class ChapterMarkers(unittest.TestCase):
    def test_markers_are_contiguous_in_milliseconds(self):
        self.assertEqual(
            narrate.chapter_markers('The Example Book', 'Alice Author', [('Chapter 1', 1500), ('Chapter 2', 2000)]),
            ';FFMETADATA1\n'
            'title=The Example Book\n'
            'artist=Alice Author\n'
            '[CHAPTER]\nTIMEBASE=1/1000\nSTART=0\nEND=1500\ntitle=Chapter 1\n'
            '[CHAPTER]\nTIMEBASE=1/1000\nSTART=1500\nEND=3500\ntitle=Chapter 2\n',
        )


class ReadManifest(unittest.TestCase):
    def test_rejects_a_chapter_without_text(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'manifest.json'
            path.write_text(json.dumps({'title': 'T', 'author': 'A', 'chapters': [{'title': 'Chapter 1', 'text': ' '}]}))
            with self.assertRaisesRegex(ValueError, 'Chapter 1 has no text'):
                narrate.read_manifest(path)


if __name__ == '__main__':
    unittest.main()
