#!/usr/bin/env python3
"""Run the actual Swift Testing suite using already built local modules."""
from pathlib import Path
import os
import subprocess

root=Path(__file__).resolve().parent.parent
developer=Path(os.environ.get("DEVELOPER_DIR","/Applications/Xcode.app/Contents/Developer"))
toolchain=developer/"Toolchains/XcodeDefault.xctoolchain/usr/bin"
sdk=developer/"Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
frameworks=developer/"Platforms/MacOSX.platform/Developer/Library/Frameworks"
build=Path(os.environ.get("MEMORIA_BUILD_DIR",str(root/"build/direct"))).resolve()
command=[str(toolchain/"swiftc"),"-swift-version","6","-target","arm64-apple-macosx26.0",
         "-sdk",str(sdk),"-module-cache-path",str(build/"module-cache"),
         "-I",str(build),"-I",str(root/"Sources/MemoriaNative/include"),"-L",str(build),
         "-F",str(frameworks),"-framework","Testing","-lMemoriaCore","-lMemoriaCollectors","-lMemoriaServices","-lMemoriaWidgetSupport",
         "-parse-as-library","-strict-concurrency=complete","-warnings-as-errors",
         "-Xlinker","-rpath","-Xlinker",str(build),"-Xlinker","-rpath","-Xlinker",str(frameworks)]
command += [str(p) for p in sorted((root/"Tests/MemoriaCoreTests").glob("*.swift"))]
command += [str(root/"Scripts/TestMain.swift"),"-o",str(build/"MemoriaTests")]
command += ["-plugin-path",str(toolchain.parent/"lib/swift/host/plugins/testing")]
if os.environ.get("MEMORIA_NESTED_SANDBOX") == "1":
    command.append("-disable-sandbox")
print("Compiling Swift Testing suite.",flush=True)
subprocess.run(command,cwd=root,check=True,timeout=900)
print("Running Swift Testing suite.",flush=True)
subprocess.run([str(build/"MemoriaTests")],cwd=root,check=True,timeout=120)
