#!/usr/bin/env python3
"""Bundle already compiled development binaries. This is not a release signer."""
from pathlib import Path
import os
import plistlib
import shutil
import subprocess

root=Path(__file__).resolve().parent.parent
source=Path(os.environ.get("MEMORIA_BUILD_DIR",str(root/"build/direct"))).resolve()
app=root/"build/Memoria.app"
# This generated path contains no user data. Start clean so removed extensions
# or libraries cannot survive from an earlier development build.
if app.exists():
    shutil.rmtree(app)
binary=app/"Contents/MacOS"
binary.mkdir(parents=True,exist_ok=True)
for name in ["Memoria","MemoriaHelper","libMemoriaCore.dylib","libMemoriaCollectors.dylib","libMemoriaServices.dylib","libMemoriaWidgetSupport.dylib","libMemoriaLifecycle.dylib"]:
    shutil.copy2(source/name,binary/name)
def info(filename, executable, identifier):
    data=plistlib.loads((root/"Configuration"/filename).read_bytes())
    replacements={"$(EXECUTABLE_NAME)":executable,"$(PRODUCT_NAME)":executable,
                  "$(PRODUCT_BUNDLE_IDENTIFIER)":identifier,"$(CURRENT_PROJECT_VERSION)":"1","$(MARKETING_VERSION)":"0.1.0",
                  "$(DEVELOPMENT_TEAM)":"","$(TeamIdentifierPrefix)":""}
    def expand(value):
        if isinstance(value,dict):return {key:expand(v) for key,v in value.items()}
        if isinstance(value,list):return [expand(v) for v in value]
        if isinstance(value,str):
            for key,replacement in replacements.items():value=value.replace(key,replacement)
        return value
    data=expand(data)
    data["MemoriaAppGroup"]=""  # No shared-container access in an unsigned-team build.
    return data
plist=info("Memoria-Info.plist","Memoria","fyi.trentini.memoria")
# The SDK-explicit fallback has no Assets.car. It uses the conventional .icns;
# Xcode builds instead compile the layered Icon Composer document.
plist["CFBundleIconFile"]="Memoria.icns"
plist.pop("CFBundleIconName",None)
(app/"Contents/Info.plist").write_bytes(plistlib.dumps(plist))
resources=app/"Contents/Resources"
resources.mkdir(parents=True,exist_ok=True)
shutil.copy2(root/"Branding/Exports/Memoria-Default.icns",resources/"Memoria.icns")
for name in sorted(p.name for p in (root/"App/Resources").glob("*.png")):
    shutil.copy2(root/"App/Resources"/name,resources/name)
launch=app/"Contents/Library/LaunchDaemons"
launch.mkdir(parents=True,exist_ok=True)
shutil.copy2(root/"Configuration/fyi.trentini.memoria.helper.plist",launch)
widget=app/"Contents/PlugIns/MemoriaWidget.appex"
widget_binary=widget/"Contents/MacOS"
widget_frameworks=widget/"Contents/Frameworks"
widget_binary.mkdir(parents=True,exist_ok=True);widget_frameworks.mkdir(parents=True,exist_ok=True)
shutil.copy2(source/"MemoriaWidget",widget_binary/"MemoriaWidget")
shutil.copy2(source/"libMemoriaWidgetSupport.dylib",widget_frameworks)
(widget/"Contents/Info.plist").write_bytes(plistlib.dumps(info("MemoriaWidget-Info.plist","MemoriaWidget","fyi.trentini.memoria.widget")))
widget_resources=widget/"Contents/Resources"
widget_resources.mkdir(parents=True,exist_ok=True)
for name in sorted(p.name for p in (root/"App/Resources").glob("*.png")):
    shutil.copy2(root/"App/Resources"/name,widget_resources/name)
widget_entitlements=root/"build/widget-development.entitlements"
widget_entitlements.write_bytes(plistlib.dumps({"com.apple.security.app-sandbox":True}))
subprocess.run(["/usr/bin/codesign","--force","--sign","-","--timestamp=none",str(widget_frameworks/"libMemoriaWidgetSupport.dylib")],check=True)
subprocess.run(["/usr/bin/codesign","--force","--sign","-","--timestamp=none","--entitlements",str(widget_entitlements),str(widget)],check=True)
subprocess.run(["/usr/bin/codesign","--verify","--strict",str(widget)],check=True)
# The linker's ad-hoc executable signature predates Info.plist. Re-sign the
# assembled bundle locally so its resources are consistent; no identity is used.
for name in ["libMemoriaCore.dylib","libMemoriaCollectors.dylib","libMemoriaServices.dylib","libMemoriaWidgetSupport.dylib","libMemoriaLifecycle.dylib","MemoriaHelper"]:
    subprocess.run(["/usr/bin/codesign","--force","--sign","-","--timestamp=none",str(binary/name)],check=True)
subprocess.run(["/usr/bin/codesign","--force","--sign","-","--timestamp=none","--identifier","fyi.trentini.memoria",str(app)],check=True)
subprocess.run(["/usr/bin/codesign","--verify","--strict",str(app)],check=True)
print(f"{app} — ad-hoc development bundle; no Developer ID/notarisation; privileged and experimental capabilities disabled; widget App Group activation requires signed distribution.")
