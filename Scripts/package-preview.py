#!/usr/bin/env python3
"""Create a Finder-installable experimental ZIP; never notarise or upload."""
from pathlib import Path
import argparse
import hashlib
import json
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from build_support import source_fingerprint, source_revision

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--version', default='0.1.0-preview.1')
parser.add_argument('--app', type=Path, default=root / 'build/Memoria.app')
args = parser.parse_args()
if not re.fullmatch(r'\d+\.\d+\.\d+-preview\.\d+', args.version):
    parser.error('Use a preview version such as 0.1.0-preview.1. This is not a stable-release signer.')
app = args.app.resolve()
revision = source_revision(root)
if not revision:
    parser.error('A Git checkout with a committed source revision is required.')
dirty = subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=normal'], cwd=root)
if dirty.strip():
    parser.error('Commit the reviewed source changes, then rebuild and package from a clean tree.')
try:
    metadata = json.loads((app / 'Contents/Resources/BuildManifest.json').read_text())
except (OSError, ValueError):
    parser.error('Build provenance is missing. Run make app from this checkout first.')
if (metadata.get('sourceCommit') != revision or
        metadata.get('sourceFingerprint') != source_fingerprint(root) or
        metadata.get('completeBuild') is not True):
    parser.error('The app is stale or from a partial build. Run make app without MEMORIA_BUILD_FROM.')
subprocess.run([sys.executable, root / 'Scripts/verify-app.py', app], cwd=root, check=True)
signature = subprocess.run(['/usr/bin/codesign', '-d', '--verbose=4', app], capture_output=True, text=True, check=True)
if 'Signature=adhoc' not in signature.stderr:
    parser.error('This packager labels ad-hoc previews only; use the signed distribution workflow for other signatures.')
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
if info['CFBundleShortVersionString'] != args.version.split('-preview.')[0]:
    parser.error('The preview version must match CFBundleShortVersionString before its preview suffix.')
out = root / 'build/distribution'
out.mkdir(parents=True, exist_ok=True)
name = 'Memoria-' + args.version + '-macos-arm64'
archive = out / (name + '.zip')
manifest_path = out / (name + '-manifest.json')
manifest = {'schema': 1, 'version': args.version, 'sourceCommit': revision,
            'sourceFingerprint': metadata['sourceFingerprint'], 'architecture': 'arm64',
            'minimumMacOS': '26.0', 'configuration': metadata['configuration'],
            'signature': 'ad-hoc development signature', 'notarised': False,
            'productionReady': False, 'fullGUIAcceptance': False,
            'capabilityLimits': ['No signed administrator helper', 'No validated experimental sensors',
                                 'Widget App Group delivery unavailable', 'Real login-cycle acceptance pending'],
            'checks': 'Executable permissions, ARM64 code, linkage, resources and signature integrity verified; '
                      'archive extraction and integrity checked separately from GUI/installation acceptance.'}
with tempfile.TemporaryDirectory(prefix='memoria-package-', dir=root / 'build') as temporary:
    stage = Path(temporary) / name
    stage.mkdir()
    shutil.copytree(app, stage / 'Memoria.app', symlinks=True)
    (stage / 'BUILD-MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (stage / 'READ ME - INSTALL.txt').write_text(
        'MEMORIA — EXPERIMENTAL PREVIEW\n\n'
        'Requires an Apple Silicon Mac and macOS 26 or later. No Xcode or Terminal is needed to try this download.\n\n'
        'INSTALL\n1. Drag Memoria.app into Applications (or your own Applications folder).\n'
        '2. Open it from Applications. Look for the brain in the menu bar. No Dock icon or main window opens by default.\n'
        '3. Click the brain and choose Open Memoria. Settings contains Show Memoria in the Dock and Launch Memoria at login.\n'
        '4. Closing a window keeps monitoring active. Choose Quit Memoria from the menu to stop it.\n\n'
        'STATUS\nThis build has an ad-hoc development signature, not an Apple Developer ID signature, and is not notarised. '
        'Full GUI and installation acceptance remain incomplete. Some development-environment launches have failed. '
        'Administrator tools, experimental sensors and signed widget sharing are unavailable.\n\n'
        'If you trust this download and macOS blocks it as unidentified, follow Apple’s app-specific instructions:\n'
        'https://support.apple.com/en-gb/102445\n'
        'Do not disable Gatekeeper or remove quarantine attributes. If macOS reports damage or malware, stop and report it.\n\n'
        'UPDATE / REMOVE\nTurn off launch at login, quit Memoria, then replace the app or move it to the Trash. '
        'Remove any desktop widgets separately.\n\n'
        'HELP\nhttps://github.com/btrentini/memoria\n'
        'Report bugs without real process captures, personal paths, credentials or private screenshots.\n')
    subprocess.run(['/usr/bin/ditto', '-c', '-k', '--norsrc', '--noextattr', '--keepParent', stage, archive], check=True)
    with zipfile.ZipFile(archive) as zipped:
        if zipped.testzip() is not None:
            raise SystemExit('Archive integrity failed.')
        expected = name + '/Memoria.app/Contents/MacOS/Memoria'
        if not (zipped.getinfo(expected).external_attr >> 16) & 0o111:
            raise SystemExit('Archive lost executable permissions.')
    extracted = Path(temporary) / 'extracted'
    subprocess.run(['/usr/bin/ditto', '-x', '-k', archive, extracted], check=True)
    subprocess.run([sys.executable, root / 'Scripts/verify-app.py', extracted / name / 'Memoria.app'], check=True)
manifest['archiveSHA256'] = hashlib.sha256(archive.read_bytes()).hexdigest()
manifest['archiveBytes'] = archive.stat().st_size
manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
checksums = out / 'SHA256SUMS.txt'
checksums.write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + p.name + '\n'
                             for p in [archive, manifest_path]))
print(json.dumps({'archive': archive.name, 'manifest': manifest_path.name,
                  'checksums': checksums.name, 'sourceCommit': revision, 'notarised': False}, indent=2))
