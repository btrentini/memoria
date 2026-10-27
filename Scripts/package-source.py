#!/usr/bin/env python3
"""Archive the committed source tree only; never include untracked local evidence."""
from pathlib import Path
import hashlib
import json
import subprocess

root = Path(__file__).resolve().parent.parent
if subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=no'], cwd=root).strip():
    raise SystemExit('Commit or review tracked changes before packaging source.')
commit = subprocess.check_output(['git', 'rev-parse', '--verify', 'HEAD'], cwd=root, text=True).strip()
destination = root.parent / 'memoria-source.tar.gz'
subprocess.run(['git', 'archive', '--format=tar.gz', '--prefix=memoria/',
                '--output', str(destination), commit], cwd=root, check=True)
print(json.dumps({'archive': destination.name, 'commit': commit,
                  'bytes': destination.stat().st_size,
                  'sha256': hashlib.sha256(destination.read_bytes()).hexdigest()}, indent=2))
