"""Narrate text with Gemini text-to-speech; requires ffmpeg and GEMINI_API_KEY."""
import argparse
import base64
from collections import namedtuple
from concurrent.futures import ThreadPoolExecutor
import hashlib
import html
import io
import json
import os
from pathlib import Path
import re
import subprocess
import time
import urllib.error
import urllib.request
import wave

ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/interactions'
DEFAULT_MODEL = 'gemini-3.8-flash-tts'
SAMPLE_RATE = 24000
BYTES_PER_SECOND = SAMPLE_RATE * 2
RETRYABLE_STATUSES = (429, 500, 503)
ATTEMPTS = 4
MAXIMUM_WORDS = 700
VOICES = {
    'Zephyr': 'Bright', 'Puck': 'Upbeat', 'Charon': 'Informative', 'Kore': 'Firm', 'Fenrir': 'Excitable',
    'Leda': 'Youthful', 'Orus': 'Firm', 'Aoede': 'Breezy', 'Callirrhoe': 'Easy-going', 'Autonoe': 'Bright',
    'Enceladus': 'Breathy', 'Iapetus': 'Clear', 'Umbriel': 'Easy-going', 'Algieba': 'Smooth', 'Despina': 'Smooth',
    'Erinome': 'Clear', 'Algenib': 'Gravelly', 'Rasalgethi': 'Informative', 'Laomedeia': 'Upbeat',
    'Achernar': 'Soft', 'Alnilam': 'Firm', 'Schedar': 'Even', 'Gacrux': 'Mature', 'Pulcherrima': 'Forward',
    'Achird': 'Friendly', 'Zubenelgenubi': 'Casual', 'Vindemiatrix': 'Gentle', 'Sadachbia': 'Lively',
    'Sadaltager': 'Knowledgeable', 'Sulafat': 'Warm',
}

Settings = namedtuple('Settings', 'model voice style')
ChapterAudio = namedtuple('ChapterAudio', 'frames input_tokens output_tokens')


def split_into_chunks(text, maximum_words=MAXIMUM_WORDS):
    """Group whole paragraphs into chunks small enough for one synthesis request."""
    chunks, current, count = [], [], 0
    for paragraph in text.split('\n\n'):
        words = len(paragraph.split())
        if current and count + words > maximum_words:
            chunks.append('\n\n'.join(current))
            current, count = [], 0
        current.append(paragraph)
        count += words
    chunks.append('\n\n'.join(current))
    return chunks


def build_request(settings, text):
    """The style is an annotation; anything placed in the text is read aloud."""
    if settings.voice not in VOICES:
        raise ValueError(f'Unknown voice: {settings.voice}')
    content = {'type': 'text', 'text': text}
    if settings.style is not None:
        content['annotations'] = [{'type': 'speech_metadata', 'style': settings.style}]
    return {
        'model': settings.model,
        'input': [{'type': 'user_input', 'content': [content]}],
        'response_format': {'type': 'audio'},
        'generation_config': {'speech_config': [{'voice': settings.voice}]},
    }


def read_audio(response):
    blocks = [
        block
        for step in response['steps']
        if step['type'] == 'model_output'
        for block in step['content']
        if block['type'] == 'audio'
    ]
    with wave.open(io.BytesIO(base64.b64decode(blocks[-1]['data']))) as audio:
        audio_format = (audio.getframerate(), audio.getnchannels(), audio.getsampwidth())
        if audio_format != (SAMPLE_RATE, 1, 2):
            raise ValueError(f'Unexpected audio format: {audio_format}')
        return audio.readframes(audio.getnframes()), response['usage']


def synthesize(request):
    body = json.dumps(request).encode()
    headers = {'Content-Type': 'application/json', 'x-goog-api-key': os.environ['GEMINI_API_KEY']}
    for attempt in range(1, ATTEMPTS + 1):
        try:
            with urllib.request.urlopen(urllib.request.Request(ENDPOINT, body, headers), timeout=600) as reply:
                return json.load(reply)
        except urllib.error.HTTPError as error:
            if error.code not in RETRYABLE_STATUSES or attempt == ATTEMPTS:
                raise RuntimeError(f'{error}: {error.read().decode()}') from error
            time.sleep(15 * attempt)


def narrate_chapter(chapter, settings, parts_directory, synthesize, maximum_words=MAXIMUM_WORDS):
    """Synthesize a chapter, caching each chunk by its text and settings."""
    chunks = split_into_chunks(chapter['text'], maximum_words)
    chunks[0] = f"{chapter['title']}.\n\n{chunks[0]}"
    parts_directory.mkdir(parents=True, exist_ok=True)

    def narrate_chunk(text):
        key = hashlib.sha256(json.dumps([*settings, text]).encode()).hexdigest()[:16]
        part = parts_directory / f'{key}.pcm'
        if part.exists():
            return part.read_bytes(), 0, 0
        frames, usage = read_audio(synthesize(build_request(settings, text)))
        part.write_bytes(frames)
        return frames, usage['total_input_tokens'], usage['total_output_tokens']

    with ThreadPoolExecutor(4) as executor:
        results = list(executor.map(narrate_chunk, chunks))
    return ChapterAudio(
        b''.join(frames for frames, _, _ in results),
        sum(input_tokens for _, input_tokens, _ in results),
        sum(output_tokens for _, _, output_tokens in results),
    )


def chapter_markers(title, author, chapters):
    """ffmpeg metadata with one marker per (title, milliseconds) chapter."""
    lines = [';FFMETADATA1', f'title={title}', f'artist={author}']
    start = 0
    for chapter_title, milliseconds in chapters:
        lines += ['[CHAPTER]', 'TIMEBASE=1/1000', f'START={start}', f'END={start + milliseconds}', f'title={chapter_title}']
        start += milliseconds
    return '\n'.join(lines) + '\n'


def read_manifest(path):
    manifest = json.loads(path.read_text())
    for chapter in manifest['chapters']:
        if not chapter['text'].strip():
            raise ValueError(f"{chapter['title']} has no text")
    return manifest


def encode(frames, output, *options):
    raw_input = ['-f', 's16le', '-ar', str(SAMPLE_RATE), '-ac', '1', '-i', '-']
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', *raw_input, *options, str(output)], input=frames, check=True)


def narrate_book(arguments):
    manifest = read_manifest(arguments.manifest)
    settings = Settings(arguments.model, arguments.voice, arguments.style)
    output = arguments.output_directory
    numbers = arguments.chapters or range(1, len(manifest['chapters']) + 1)
    narrated = []
    for number in numbers:
        chapter = manifest['chapters'][number - 1]
        audio = narrate_chapter(chapter, settings, output / 'parts', synthesize)
        tags = [f"title={chapter['title']}", f"artist={manifest['author']}", f"album={manifest['title']}"]
        metadata = [option for tag in tags for option in ('-metadata', tag)]
        encode(audio.frames, output / f'chapter-{number:02d}.mp3', '-b:a', '64k', *metadata)
        narrated.append((chapter['title'], audio))
        seconds = len(audio.frames) // BYTES_PER_SECOND
        print(f"{chapter['title']}: {seconds}s, {audio.input_tokens} input tokens, {audio.output_tokens} audio output tokens")
    if arguments.chapters is None:
        markers = output / 'chapters.ffmetadata'
        markers.write_text(
            chapter_markers(
                manifest['title'],
                manifest['author'],
                [(title, len(audio.frames) * 1000 // BYTES_PER_SECOND) for title, audio in narrated],
            )
        )
        frames = b''.join(audio.frames for _, audio in narrated)
        encode(frames, output / 'book.m4b', '-i', str(markers), '-map', '0', '-map_metadata', '1', '-c:a', 'aac', '-b:a', '64k')
    print(f'Total: {sum(audio.output_tokens for _, audio in narrated)} audio output tokens billed by this run')


def sample_voices(arguments):
    text = arguments.text_file.read_text()
    output = arguments.output_directory
    output.mkdir(parents=True, exist_ok=True)
    suffix = '' if arguments.style is None else '-' + re.sub(r'[^a-z0-9]+', '-', arguments.style.lower()).strip('-')

    def sample(voice):
        frames, usage = read_audio(synthesize(build_request(Settings(arguments.model, voice, arguments.style), text)))
        encode(frames, output / f'{voice}{suffix}.mp3', '-b:a', '96k')
        return usage['total_output_tokens']

    with ThreadPoolExecutor(6) as executor:
        output_tokens = sum(executor.map(sample, arguments.voices or VOICES))
    rows = ''.join(
        f'<p><b>{html.escape(path.stem)}</b> {VOICES[path.stem.split("-")[0]]}<br>'
        f'<audio controls preload="none" src="{html.escape(path.name)}"></audio></p>'
        for path in sorted(output.glob('*.mp3'))
    )
    (output / 'index.html').write_text(
        '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
        '<title>Voice samples</title><style>body{font:16px system-ui;max-width:40rem;margin:2rem auto;padding:0 1rem;'
        f'color-scheme:light dark}}audio{{width:100%}}</style><h1>Voice samples</h1>{rows}'
        '<script>document.addEventListener("play",event=>document.querySelectorAll("audio")'
        '.forEach(audio=>audio!==event.target&&audio.pause()),true)</script>'
    )
    print(f'{output / "index.html"}: {output_tokens} audio output tokens billed by this run')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model', default=DEFAULT_MODEL)
    parser.add_argument('--style', help='Delivery direction, sent as speech metadata and never spoken')
    commands = parser.add_subparsers(required=True)

    voices = commands.add_parser('voices', help='Sample voices on a short text and build a comparison page')
    voices.add_argument('--text-file', type=Path, required=True)
    voices.add_argument('--output-directory', type=Path, required=True)
    voices.add_argument('--voices', type=lambda value: value.split(','), help='Comma-separated; default is every voice')
    voices.set_defaults(run=sample_voices)

    book = commands.add_parser('book', help='Narrate manifest chapters to MP3, plus an M4B when narrating them all')
    book.add_argument('--manifest', type=Path, required=True)
    book.add_argument('--output-directory', type=Path, required=True)
    book.add_argument('--voice', required=True)
    book.add_argument('--chapters', type=lambda value: [int(number) for number in value.split(',')])
    book.set_defaults(run=narrate_book)

    arguments = parser.parse_args()
    arguments.run(arguments)


if __name__ == '__main__':
    main()
