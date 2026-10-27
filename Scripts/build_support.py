"""Shared, non-secret provenance for SDK builds and preview packaging."""
from pathlib import Path
import hashlib
import json
import subprocess


def source_revision(root):
    try:
        return subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root,
                                       stderr=subprocess.DEVNULL, text=True).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def source_fingerprint(root):
    files = []
    for folder in ['App', 'Widget', 'Helper', 'Sources', 'Configuration', 'Fixtures', 'Probe']:
        files.extend(p for p in (root / folder).rglob('*') if p.is_file() and not p.is_symlink())
    files.extend(root / p for p in ['Package.swift', 'Scripts/direct-build.py',
                                   'Scripts/bundle-development.py', 'Scripts/build_support.py',
                                   'Branding/Exports/Memoria-Default.icns'])
    digest = hashlib.sha256()
    for path in sorted(set(files)):
        if path.name == '.DS_Store':
            continue
        digest.update(path.relative_to(root).as_posix().encode() + b'\0')
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def write_build_metadata(root, output, configuration, fingerprint, complete=True):
    if fingerprint != source_fingerprint(root):
        raise SystemExit('Build inputs changed during compilation. Rebuild before bundling.')
    data = {'schema': 1, 'sourceCommit': source_revision(root),
            'sourceFingerprint': fingerprint, 'configuration': configuration,
            'architecture': 'arm64', 'minimumMacOS': '26.0', 'completeBuild': complete,
            'kind': 'SDK development build; not a signed distribution release'}
    (output / 'build-metadata.json').write_text(json.dumps(data, indent=2) + '\n')
