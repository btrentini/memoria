#!/usr/bin/env python3
"""Verify the direct app's portable bundle structure; do not claim GUI acceptance."""
from pathlib import Path
import argparse
import json
import os
import plistlib
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('bundle', type=Path)
args = parser.parse_args()
app = args.bundle.resolve()
issues = []
checks = []
developer = Path(os.environ.get('DEVELOPER_DIR', '/Applications/Xcode.app/Contents/Developer'))
toolchain = developer / 'Toolchains/XcodeDefault.xctoolchain/usr/bin'

def require(value, label):
    (checks if value else issues).append(label)

def run(command):
    try:
        return subprocess.run(list(map(str, command)), capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        issues.append('Tool failed or timed out: ' + Path(command[0]).name)
        return subprocess.CompletedProcess(command, 1, '', '')

try:
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
except (OSError, plistlib.InvalidFileException):
    parser.error('An assembled application with a readable Contents/Info.plist is required.')
require(info.get('CFBundleIdentifier') == 'fyi.trentini.memoria', 'Direct application identifier')
require(info.get('LSMinimumSystemVersion') == '26.0', 'macOS 26 deployment target')
require(info.get('LSUIElement') is True, 'Menu-bar agent by default')
executable = info.get('CFBundleExecutable', '')
require(isinstance(executable, str) and executable == 'Memoria', 'Expected main executable name')
require((app / 'Contents/MacOS/Memoria').is_file(), 'Main executable exists')
require((app / 'Contents/Resources/Memoria.icns').is_file(), 'Finder/Dock icon exists')
widget = app / 'Contents/PlugIns/MemoriaWidget.appex'
require(widget.is_dir(), 'Widget extension is embedded')
for bundle in [app, widget]:
    for name in ['BrainTemplate', 'BrainTemplate16', 'BrainTemplate24', 'BrainMark']:
        for scale in ['', '@2x']:
            require((bundle / 'Contents/Resources' / (name + scale + '.png')).is_file(),
                    bundle.name + ': template ' + name + scale)
    require(run(['/usr/bin/codesign', '--verify', '--strict', bundle]).returncode == 0,
            bundle.name + ': signature integrity')
for path in app.rglob('*'):
    if path.is_symlink():
        contained = path.resolve().is_relative_to(app)
        require(contained, 'No escaping bundle symlink: ' + str(path.relative_to(app)))
        if not contained:
            continue
    if not path.is_file() or not (path.parent.name == 'MacOS' or path.suffix == '.dylib'):
        continue
    relative = str(path.relative_to(app))
    require(os.access(path, os.X_OK), 'Executable permission: ' + relative)
    architecture = run([toolchain / 'lipo', '-archs', path])
    require(architecture.returncode == 0 and architecture.stdout.strip() == 'arm64', 'ARM64 Mach-O: ' + relative)
    require(run(['/usr/bin/codesign', '--verify', '--strict', path]).returncode == 0, 'Code integrity: ' + relative)
    linkage = run([toolchain / 'otool', '-L', path])
    require(linkage.returncode == 0, 'Readable linkage: ' + relative)
    for line in linkage.stdout.splitlines()[1:]:
        dependency = line.strip().split(' (', 1)[0]
        require(dependency.startswith(('@rpath/', '@loader_path/', '@executable_path/', '/usr/lib/', '/System/Library/')),
                'Portable dependency: ' + relative + ' → ' + dependency)
        if dependency.startswith('@rpath/libMemoria'):
            require(any(app.rglob(Path(dependency).name)), 'Bundled library: ' + Path(dependency).name)
print(json.dumps({'checksPassed': len(checks), 'issues': issues,
                  'scope': 'Permissions, ARM64 code, linkage, resources and signature integrity. '
                           'No Developer ID, notarisation, Gatekeeper or GUI pass is implied.'}, indent=2))
raise SystemExit(1 if issues else 0)
