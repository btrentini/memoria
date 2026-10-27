#!/usr/bin/env python3
"""Check exact staged blobs without printing captured data or suspected secrets.

Run Gitleaks and verify-vendor.py separately. This is a publication hygiene
check, not a security audit or proof that arbitrary source is harmless.
"""
from pathlib import Path, PurePosixPath
import json
import re
import subprocess

root = Path(__file__).resolve().parent.parent
entries = subprocess.check_output(['git', 'ls-files', '--stage', '-z'], cwd=root).split(b'\0')
forbidden_dirs = {'.git', '.build', '.swiftpm', 'build', 'DerivedData', 'target',
                  '__pycache__', 'xcuserdata', 'recordings', 'exports'}
forbidden_suffixes = {'.pyc', '.o', '.a', '.dylib', '.dmg', '.zip', '.gz', '.pid',
                      '.log', '.ips', '.crash', '.pem', '.key', '.p8', '.p12', '.pfx',
                      '.cer', '.mobileprovision', '.provisionprofile', '.sqlite', '.db'}
private_path = re.compile(rb'/(?:Users|home)/[A-Za-z0-9_.-]+/')
private_temp = re.compile(rb'/(?:private/)?var/folders/[A-Za-z0-9_/.-]+')
identity_keys = {'pid', 'ppid', 'parentpid', 'uid', 'bootsession', 'startseconds',
                 'startmicroseconds', 'arguments', 'environment', 'authorization'}
findings = []
count = 0

def flag(path, reason):
    findings.append({'file': str(path), 'reason': reason})

def inspect_evidence(path, value):
    if isinstance(value, dict):
        if any(key.lower() in identity_keys for key in value):
            flag(path, 'Process identity or sensitive data key in published evidence')
        for item in value.values():
            inspect_evidence(path, item)
    elif isinstance(value, list):
        for item in value:
            inspect_evidence(path, item)

process = subprocess.Popen(['git', 'cat-file', '--batch'], cwd=root,
                           stdin=subprocess.PIPE, stdout=subprocess.PIPE)
try:
    for entry in entries:
        if not entry:
            continue
        metadata, raw_path = entry.split(b'\t', 1)
        mode, object_id, stage = metadata.split()
        path = PurePosixPath(raw_path.decode())
        count += 1
        if mode not in {b'100644', b'100755'} or stage != b'0':
            flag(path, 'Symlink, submodule or unresolved index entry')
            continue
        if (any(part in forbidden_dirs or part.startswith('.build-') or part.endswith('.app')
                for part in path.parts) or path.suffix.lower() in forbidden_suffixes
                or path.name.startswith('.env') or path.name in {'.DS_Store', 'id_rsa', 'id_ed25519', 'credentials.json', 'secrets.json'}):
            flag(path, 'Prohibited local artefact or credential filename')
        process.stdin.write(object_id + b'\n')
        process.stdin.flush()
        header = process.stdout.readline().split()
        if len(header) != 3 or header[1] != b'blob':
            raise RuntimeError('Expected a staged blob')
        data = process.stdout.read(int(header[2]))
        if process.stdout.read(1) != b'\n':
            raise RuntimeError('Malformed git cat-file response')
        if private_path.search(data) or private_temp.search(data):
            flag(path, 'Personal filesystem path')
        if data[:4] in {b'\x7fELF', b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf',
                       b'\xce\xfa\xed\xfe', b'\xfe\xed\xfa\xce', b'\xca\xfe\xba\xbe', b'PK\x03\x04'}:
            flag(path, 'Compiled executable or archive')
        try:
            data.decode('utf-8')
        except UnicodeDecodeError:
            if not (path.suffix in {'.png', '.icns'} and path.parts[0] in {'App', 'Branding'}
                    or path.suffix == '.fst' and path.parts[:2] == ('Worker', 'vendor')):
                flag(path, 'Unexpected binary data')
        if path.parts[0] == 'Evidence' and path.suffix == '.json':
            inspect_evidence(path, json.loads(data))
finally:
    process.stdin.close()
    process.stdout.close()
    process.wait()
if count == 0:
    findings.append({'reason': 'No staged/tracked files to inspect'})
print(json.dumps({'stagedFiles': count, 'findings': findings}, indent=2))
raise SystemExit(1 if findings else 0)
