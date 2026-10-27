#!/usr/bin/env python3
"""SDK-explicit development build. Does not install or repair Xcode components."""
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
developer = Path(os.environ.get("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer"))
toolchain = developer/"Toolchains/XcodeDefault.xctoolchain/usr/bin"
sdk = developer/"Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
output = Path(os.environ.get("MEMORIA_BUILD_DIR",str(root/"build/direct"))).resolve()
output.mkdir(parents=True, exist_ok=True)
log = output/"build.log"
swift = toolchain/"swiftc"
flags = ["-whole-module-optimization","-swift-version","6","-target","arm64-apple-macosx26.0","-sdk",str(sdk),
         "-module-cache-path",str(Path(os.environ.get("MEMORIA_MODULE_CACHE", str(output/"module-cache")))),"-I",str(output),
         "-I",str(root/"Sources/MemoriaNative/include"),"-L",str(output),
         "-strict-concurrency=complete","-warnings-as-errors"]
if os.environ.get("MEMORIA_CONFIGURATION") == "Release":
    flags += ["-O"]
# Compiler subprocesses still inherit the session's filesystem sandbox. This
# opt-in avoids nesting Apple's macro sandbox inside an existing sandbox.
if os.environ.get("MEMORIA_NESTED_SANDBOX") == "1":
    flags.append("-disable-sandbox")
resume = os.environ.get("MEMORIA_BUILD_FROM")
skipping = bool(resume)

def run(command):
    print(" ".join(map(str,command)), flush=True)
    with log.open("a") as stream:
        stream.write("\n$ "+" ".join(map(str,command))+"\n")
        stream.flush()
        result = subprocess.run(list(map(str,command)),cwd=root,stdout=stream,stderr=subprocess.STDOUT,timeout=900)
    if result.returncode:
        print(log.read_text()[-16000:], flush=True)
        raise SystemExit(result.returncode)

if not resume:
    log.write_text("")
    run([toolchain/"clang","-target","arm64-apple-macosx26.0","-isysroot",sdk,"-Wall","-Wextra","-Werror","-I",root/"Sources/MemoriaNative/include","-c",root/"Sources/MemoriaNative/native.c","-o",output/"native.o"])
    run([toolchain/"ar","rcs",output/"libMemoriaNative.a",output/"native.o"])
for module, libraries in [
    ("MemoriaCore",[]),
    ("MemoriaLifecycle",["-framework","ServiceManagement"]),
    ("MemoriaWidgetSupport",["-application-extension"]),
    ("MemoriaCollectors",["-lMemoriaCore","-lMemoriaNative","-framework","IOKit"]),
    ("MemoriaServices",["-lMemoriaCore","-lMemoriaCollectors","-lMemoriaNative","-framework","Security","-framework","ServiceManagement"])
]:
    if skipping and module != resume:
        continue
    skipping = False
    sources = sorted((root/"Sources"/module).glob("*.swift"))
    run([swift,*flags,"-enable-testing","-parse-as-library","-emit-module","-emit-library","-module-name",module,
         "-emit-module-path",output/(module+".swiftmodule"),"-o",output/("lib"+module+".dylib"),
         "-Xlinker","-install_name","-Xlinker","@rpath/lib"+module+".dylib",*libraries,*sources])
for name,folder,links,parse in [
    ("MemoriaFixture","Fixtures",[],[]),
    ("MemoriaProbe","Probe",["-lMemoriaCore","-lMemoriaCollectors","-lMemoriaServices"],["-parse-as-library"]),
    ("MemoriaHelper","Helper",["-lMemoriaCore","-lMemoriaCollectors","-lMemoriaServices"],[]),
    ("Memoria","App",["-lMemoriaCore","-lMemoriaCollectors","-lMemoriaServices","-lMemoriaWidgetSupport","-lMemoriaLifecycle"],["-parse-as-library"]),
    ("MemoriaWidget","Widget",["-lMemoriaWidgetSupport","-application-extension","-Xlinker","-rpath","-Xlinker","@executable_path/../Frameworks"],["-parse-as-library"])
]:
    if skipping and name != resume:
        continue
    skipping = False
    run([swift,*flags,*parse,"-module-name",name,"-Xlinker","-rpath","-Xlinker","@executable_path",
         *links,*([root/"App/BrandMark.swift"] if folder=="Widget" else []),*sorted((root/folder).glob("*.swift")),"-o",output/name])
print(f"Development executables built in {output}. No signing or distribution verification is implied.")
