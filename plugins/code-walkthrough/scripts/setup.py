"""Install the pinned renderer runtime outside the plugin, in a project-owned directory."""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys

PLUGIN = Path(__file__).resolve().parents[1]
INPUTS = (PLUGIN / 'assets/astro/package.json', PLUGIN / 'assets/astro/package-lock.json', PLUGIN / 'scripts/requirements.txt')
STAMP = '.installed'


def fingerprint():
    digest = hashlib.sha256(sys.executable.encode())
    for path in INPUTS:
        digest.update(path.read_bytes())
    return digest.hexdigest()


def install(runtime, run=subprocess.run):
    """Install unless the stamp shows this runtime already matches the pinned inputs."""
    stamp = runtime / STAMP
    expected = fingerprint()
    installed = all((runtime / name).is_dir() for name in ('node_modules', '.venv'))
    if installed and stamp.is_file() and stamp.read_text() == expected:
        return False
    runtime.mkdir(parents=True, exist_ok=True)
    stamp.unlink(missing_ok=True)
    for name in ('package.json', 'package-lock.json'):
        shutil.copyfile(PLUGIN / 'assets/astro' / name, runtime / name)
    run(['npm', 'ci', '--prefix', str(runtime)], check=True)
    run([sys.executable, '-m', 'venv', '--upgrade-deps', str(runtime / '.venv')], check=True)
    run([str(runtime / '.venv/bin/python'), '-m', 'pip', 'install', '-r', str(PLUGIN / 'scripts/requirements.txt')], check=True)
    stamp.write_text(expected)
    return True


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime', type=Path, default=Path('.llm/code-walkthrough'))
    runtime = parser.parse_args().runtime.resolve()
    print(f"Runtime {'installed' if install(runtime) else 'already current'}: {runtime}")
