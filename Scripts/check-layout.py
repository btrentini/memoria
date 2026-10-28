#!/usr/bin/env python3
"""Compile and run production-window resize checks in a disposable native app."""
from pathlib import Path
import argparse
import json
import os
import plistlib
import subprocess
import shlex
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--prepare-only', action='store_true', help='Build the test bundle and print its launch command without running GUI checks.')
options = parser.parse_args()
root = Path(__file__).resolve().parent.parent
build = Path(os.environ.get('MEMORIA_BUILD_DIR', str(root / 'build/direct'))).resolve()
if not (build / 'libMemoriaCore.dylib').exists():
    raise SystemExit('Build the application first: make app')
developer = Path(os.environ.get('DEVELOPER_DIR', '/Applications/Xcode.app/Contents/Developer'))
work = Path(tempfile.mkdtemp(prefix='layout-', dir=root / 'build'))
# LaunchServices needs to traverse the bundle's parent. Only generated code and
# synthetic layout captures are written here; no live process data is collected.
work.chmod(0o755)
bundle = work / 'MemoriaLayoutTest.app' / 'Contents'
(bundle / 'MacOS').mkdir(parents=True)
(bundle / 'Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'fyi.trentini.memoria.' + work.name,
    'CFBundleName': 'Memoria Layout Test', 'CFBundleExecutable': 'LayoutTest',
    'CFBundlePackageType': 'APPL', 'LSUIElement': True,
}))
command = [str(developer / 'Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc'),
           '-whole-module-optimization', '-swift-version', '6', '-target', 'arm64-apple-macosx26.0',
           '-sdk', str(developer / 'Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk'),
           '-module-cache-path', os.environ.get('MEMORIA_MODULE_CACHE', str(build / 'module-cache')),
           '-I', str(build), '-I', str(root / 'Sources/MemoriaNative/include'), '-L', str(build),
           '-lMemoriaCore', '-lMemoriaCollectors', '-lMemoriaServices', '-lMemoriaWidgetSupport', '-lMemoriaLifecycle',
           '-Xlinker', '-rpath', '-Xlinker', str(build), '-parse-as-library',
           '-warnings-as-errors', '-strict-concurrency=complete']
if os.environ.get('MEMORIA_NESTED_SANDBOX') == '1':
    command.append('-disable-sandbox')
command += [str(p) for p in sorted((root / 'App').glob('*.swift')) if p.name != 'MemoriaApp.swift']
command += [str(root / 'Tests/LayoutSmoke/LayoutSmoke.swift'), '-o', str(bundle / 'MacOS/LayoutTest')]
subprocess.run(command, cwd=root, check=True, timeout=900)
launch = ['open', '-n', str(bundle.parent), '--args', '-layoutOutput', str(work)]
if options.prepare_only:
    print('Prepared only; GUI checks have not run. Launch with:')
    print(shlex.join(launch))
    print('Check failures and the check count in:', work / 'result.json')
    raise SystemExit(0)
print('Opening the disposable layout-test window. No collectors or process actions are started.', flush=True)
try:
    subprocess.run(launch, check=True, timeout=15)
except subprocess.CalledProcessError as error:
    raise SystemExit('GUI launch failed; no layout pass. In a restricted session, launch the prepared bundle with: ' + shlex.join(launch)) from error
result = work / 'result.json'
deadline = time.monotonic() + 90
while not result.exists() and time.monotonic() < deadline:
    time.sleep(0.5)
if not result.exists():
    raise SystemExit('No layout result. A logged-in macOS GUI session is required; inspect the test app for a launch failure.')
data = json.loads(result.read_text())
print(json.dumps(data, indent=2))
print('Synthetic layout captures:', work)
if data.get('failures') or data.get('checks', 0) == 0:
    raise SystemExit(1)
