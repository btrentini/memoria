#!/usr/bin/env python3
"""Read-only build prerequisites. Never install tools or change Xcode selection."""
from pathlib import Path
import os
import platform
import re
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
problems = []

def check(condition, message):
    print(('OK   ' if condition else 'FAIL ') + message, flush=True)
    if not condition:
        problems.append(message)

def capture(command, timeout=20):
    try:
        result = subprocess.run(list(map(str, command)), capture_output=True, text=True, timeout=timeout)
        return result.returncode == 0, result.stdout + result.stderr
    except (OSError, subprocess.TimeoutExpired) as error:
        return False, str(error)

check(sys.version_info >= (3, 9), 'Python 3.9 or later')
check(platform.system() == 'Darwin', 'macOS host')
if platform.system() != 'Darwin':
    raise SystemExit('The application build requires macOS; no tools were installed.')
check(platform.machine() == 'arm64', 'Native Apple Silicon shell (arm64; avoid a Rosetta terminal)')
os_version = platform.mac_ver()[0]
check(bool(os_version) and int(os_version.split('.')[0]) >= 26, 'macOS 26 or later')
developer = Path(os.environ.get('DEVELOPER_DIR', '/Applications/Xcode.app/Contents/Developer'))
sdk = developer / 'Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk'
bin = developer / 'Toolchains/XcodeDefault.xctoolchain/usr/bin'
for name in ['swiftc', 'clang', 'ar', 'lipo', 'otool']:
    check((bin / name).is_file() and os.access(bin / name, os.X_OK), 'Xcode ' + name + ' is executable')
check(sdk.is_dir(), 'macOS SDK is present')
settings = sdk / 'SDKSettings.json'
if settings.is_file():
    import json
    version = str(json.loads(settings.read_text()).get('Version', ''))
    check(bool(version) and int(version.split('.')[0]) >= 27, 'macOS 27 SDK or later (tested SDK family)')
else:
    check(False, 'SDKSettings.json is readable')
framework = developer / 'Platforms/MacOSX.platform/Developer/Library/Frameworks/Testing.framework'
check(framework.is_dir(), 'Swift Testing framework from full Xcode')
for executable in ['/usr/bin/codesign', '/usr/bin/ditto', '/usr/bin/make', '/usr/bin/git']:
    check(os.access(executable, os.X_OK), Path(executable).name + ' is available')
if (bin / 'swiftc').is_file():
    ok, output = capture([bin / 'swiftc', '--version'], timeout=60)
    if not ok:
        print('     Compiler query failed: ' + output.strip()[:1000], flush=True)
    match = re.search(r'Swift version (\d+)', output)
    check(ok and match is not None and int(match.group(1)) >= 6, 'Swift 6 compiler')
if problems:
    raise SystemExit('Resolve the failed checks above, then run make doctor again. '
                     'A timeout does not establish that tools are missing. '
                     'For missing tools, finish full Xcode setup and check DEVELOPER_DIR.')
print('SDK build prerequisites passed. Checking the separate Xcode project launcher…', flush=True)
ok, _ = capture([developer / 'usr/bin/xcodebuild', '-list', '-project', root / 'Memoria.xcodeproj'], timeout=30)
if ok:
    print('OK   Xcode project initialisation')
else:
    print('WARN Xcode project initialisation did not pass. Open Xcode and finish its licence/component setup.\n'
          '     The SDK build prerequisites passed; make app can use that independent route.\n'
          '     Xcode project, archive and GUI acceptance are separate checks.')
