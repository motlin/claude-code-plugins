"""Install the pinned renderer runtime outside the plugin, in a project-owned directory."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys

PLUGIN = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--runtime', type=Path, default=Path('.llm/code-walkthrough'))
args = parser.parse_args()
runtime = args.runtime.resolve()
runtime.mkdir(parents=True, exist_ok=True)
for name in ('package.json', 'package-lock.json'):
    shutil.copyfile(PLUGIN / 'assets/astro' / name, runtime / name)
subprocess.run(['npm', 'ci', '--prefix', str(runtime)], check=True)
subprocess.run([sys.executable, '-m', 'venv', str(runtime / '.venv')], check=True)
subprocess.run([str(runtime / '.venv/bin/python'), '-m', 'pip', 'install', '-r', str(PLUGIN / 'scripts/requirements.txt')], check=True)
print(f'Runtime ready: {runtime}')
